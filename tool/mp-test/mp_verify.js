// ===========================================================================
// 多人猜歌游戏 —— 服务端修复验证（协议级端到端）
// 用法：node .mp_verify.js [ws url]     默认 ws://127.0.0.1:3999
// ===========================================================================
const WebSocket = require('./mp_ws');
const URL = process.argv[2] || process.env.MP_URL || 'ws://127.0.0.1:3999';

let pass = 0, fail = 0;
const failures = [];
function check(name, ok, detail) {
  if (ok) { pass++; console.log('  [PASS] ' + name); }
  else { fail++; failures.push(name + (detail ? ' -- ' + detail : '')); console.log('  [FAIL] ' + name + (detail ? ' -- ' + detail : '')); }
}
const note = m => console.log('  [note] ' + m);
const sleep = ms => new Promise(r => setTimeout(r, ms));

// 游标式客户端：每次 wait 只向后看，避免读到历史消息造成假阳性
function mk(name) {
  return new Promise((res, rej) => {
    const ws = new WebSocket(URL);
    const c = { name, ws, seen: [], cur: 0 };
    ws.on('open', () => res(c));
    ws.on('message', d => c.seen.push(JSON.parse(d)));
    ws.on('error', rej);
    c.send = (a, p = {}) => ws.send(JSON.stringify({ action: a, payload: p }));
    c.wait = (act, ms = 9000) => { const t0 = Date.now(); return new Promise((ok, no) => { const t = setInterval(() => {
      for (; c.cur < c.seen.length; c.cur++) { if (c.seen[c.cur].action === act) { clearInterval(t); const m = c.seen[c.cur]; c.cur++; return ok(m); } }
      if (Date.now() - t0 > ms) { clearInterval(t); no(new Error(name + ' 等待 ' + act + ' 超时')); } }, 20); }); };
    c.tryWait = (act, ms = 2500) => c.wait(act, ms).catch(() => null);
    c.waitAny = (acts, ms = 9000) => { const t0 = Date.now(); return new Promise((ok, no) => { const t = setInterval(() => {
      for (; c.cur < c.seen.length; c.cur++) { if (acts.includes(c.seen[c.cur].action)) { clearInterval(t); const m = c.seen[c.cur]; c.cur++; return ok(m); } }
      if (Date.now() - t0 > ms) { clearInterval(t); no(new Error(name + ' waitAny timeout')); } }, 20); }); };
    c.reset = () => { c.cur = c.seen.length; };
    c.close = () => { try { ws.close(); } catch (_) {} };
    return c;
  });
}

async function room(mode, opts = {}, n = 2) {
  const h = await mk('host');
  h.send('initialize', { nickname: '房主' }); await h.wait('initialized');
  h.send('create_room', Object.assign({
    gameType: mode, maxPlayers: 4, timeLimit: 30, maxGuesses: 10, totalRounds: 2,
    selectedVersions: [], masterMinDx: 1.0, masterMaxDx: 15.0, selectedGenres: [],
    blurLevel: 50, playDuration: 5, songCount: 3, nonEnglishCharThreshold: 50,
  }, opts));
  const cr = await h.wait('room_created');
  const r = cr.payload.room;
  const gs = [];
  for (let i = 0; i < n - 1; i++) {
    const g = await mk('guest' + i);
    g.send('initialize', { nickname: '玩家' + i }); await g.wait('initialized');
    g.send('join_room', { roomId: r.id, nickname: '玩家' + i }); await g.wait('room_joined');
    gs.push(g);
  }
  h.send('update_ready', { ready: true });
  for (const g of gs) g.send('update_ready', { ready: true });
  await sleep(350);
  h.reset();
  h.send('start_game', {});
  return { h, gs, room: r };
}
async function teardown(h, gs) {
  try { h.send('leave_room', {}); } catch (_) {}
  for (const g of gs || []) { try { g.send('leave_room', {}); } catch (_) {} }
  await sleep(250);
  h.close(); (gs || []).forEach(g => g.close());
}

const MODES = ['info', 'cover', 'blurred', 'audio', 'alia', 'letters', 'flash', 'tileReveal', 'chartPeek'];

async function main() {
  // ---------------------------------------------------------------
  // 1. MASTER 定数筛选（原先因 ds[0] 取错索引而全部退化成「ヒバナ」）
  // ---------------------------------------------------------------
  console.log('\n=== 1. MASTER 定数筛选（ds[3]）===');
  {
    const { h, gs } = await room('info', { masterMinDx: 14.0, masterMaxDx: 14.5 });
    const rs = await h.wait('round_start', 9000);
    const song = rs.payload.gameState.currentSong;
    const ds3 = song.ds && song.ds.length > 3 ? Number(song.ds[3]) : null;
    note('抽到: ' + song.id + ' 「' + song.title + '」 ds=' + JSON.stringify(song.ds));
    check('定数筛选：不再退化成默认曲 ヒバナ', song.title !== 'ヒバナ', 'title=' + song.title);
    check('定数筛选：MASTER 定数落在 [14.0, 14.5]', ds3 !== null && ds3 >= 14.0 && ds3 <= 14.5, 'ds3=' + ds3);
    await teardown(h, gs);
  }
  {
    // 极端筛选：应当明确失败而不是伪造题目
    const { h, gs } = await room('info', { masterMinDx: 99.0, masterMaxDx: 99.5 });
    const err = await h.tryWait('error', 5000);
    check('无匹配曲时明确报错（不伪造题目）', !!err && /没有符合条件/.test(err.payload.message), err ? err.payload.message : '(无错误)');
    await teardown(h, gs);
  }

  // ---------------------------------------------------------------
  // 2. 猜对判定：精确匹配，不再子串命中
  // ---------------------------------------------------------------
  console.log('\n=== 2. 猜对判定（精确匹配）===');
  {
    const { h, gs } = await room('info', {});
    const rs = await h.wait('round_start', 9000);
    const t = rs.payload.gameState.currentSong;

    // 2a 伪造 songId + 子串曲名 → 必须判错
    h.send('submit_guess', { songId: '424242', songName: t.title + ' XXXX' });
    let gr = await h.wait('guess_received', 6000);
    check('子串+伪造 id 不被判对', gr.payload.guess.correct === false, 'correct=' + gr.payload.guess.correct);

    // 2b 正确 songId → 判对
    h.send('submit_guess', { songId: String(t.id), songName: t.title });
    gr = await h.wait('guess_received', 6000);
    check('正确 songId 判对', gr.payload.guess.correct === true, 'correct=' + gr.payload.guess.correct);
    check('guess 带 score 字段', typeof gr.payload.guess.score === 'number', 'score=' + gr.payload.guess.score);
    await teardown(h, gs);
  }
  {
    // 2c 曲名精确相等（大小写/空白归一化）也判对
    const { h, gs } = await room('info', {});
    const rs = await h.wait('round_start', 9000);
    const t = rs.payload.gameState.currentSong;
    h.send('submit_guess', { songId: 'not-a-real-id', songName: '  ' + t.title.toUpperCase() + '  ' });
    const gr = await h.wait('guess_received', 6000);
    check('曲名精确匹配（忽略大小写/首尾空格）判对', gr.payload.guess.correct === true, 'correct=' + gr.payload.guess.correct);
    await teardown(h, gs);
  }

  // ---------------------------------------------------------------
  // 3. 计时与得分：耗时真实、快答分更高
  // ---------------------------------------------------------------
  console.log('\n=== 3. 计时与得分 ===');
  {
    const { h, gs } = await room('info', { timeLimit: 30, totalRounds: 2 });
    let rs = await h.wait('round_start', 9000);
    let t = rs.payload.gameState.currentSong;
    h.send('submit_guess', { songId: String(t.id), songName: t.title });
    let gr = await h.wait('guess_received', 6000);
    let ro = await h.wait('round_over', 6000);
    const fastScore = ro.payload.gameState.players.find(p => p.nickname === '房主').score;
    note('立即答对: timeSpent=' + gr.payload.guess.timeSpent.toFixed(2) + 's, score=' + gr.payload.guess.score);
    check('快速作答 timeSpent 接近 0', gr.payload.guess.timeSpent < 2, 'timeSpent=' + gr.payload.guess.timeSpent);

    h.reset();
    h.send('start_next_round', {});
    rs = await h.wait('round_start', 9000);
    t = rs.payload.gameState.currentSong;
    note('等待 6 秒后作答...');
    await sleep(6000);
    h.send('submit_guess', { songId: String(t.id), songName: t.title });
    gr = await h.wait('guess_received', 6000);
    ro = await h.waitAny(['round_over', 'game_over'], 6000);
    const slowRound = ro.payload.gameState.players.find(p => p.nickname === '房主').score - fastScore;
    note('等待后答对: timeSpent=' + gr.payload.guess.timeSpent.toFixed(2) + 's, 本回合得分=' + slowRound);
    check('慢答 timeSpent 反映真实等待', gr.payload.guess.timeSpent >= 5, 'timeSpent=' + gr.payload.guess.timeSpent);
    check('快答得分高于慢答（速度奖励生效）', fastScore > slowRound, '快=' + fastScore + ' 慢=' + slowRound);
    check('慢答得分不低于下限 10', slowRound >= 10, 'slowRound=' + slowRound);
    await teardown(h, gs);
  }

  // ---------------------------------------------------------------
  // 4. 回合结束后拒绝重复提交（原先能刷分）
  // ---------------------------------------------------------------
  console.log('\n=== 4. 回合结束后拒绝重复提交 ===');
  {
    const { h, gs } = await room('info', { totalRounds: 3 }, 3);
    const rs = await h.wait('round_start', 9000);
    const t = rs.payload.gameState.currentSong;
    const B = gs[0];

    h.send('submit_guess', { songId: String(t.id), songName: t.title });
    await h.wait('guess_received', 6000);
    const ro1 = await h.wait('round_over', 6000);
    const scoreA1 = ro1.payload.gameState.players.find(p => p.nickname === '房主').score;
    note('回合结束，房主分数=' + scoreA1);

    // 回合已结束，B 再提交正确答案
    B.reset(); h.reset();
    B.send('submit_guess', { songId: String(t.id), songName: t.title });
    const err = await B.tryWait('error', 4000);
    check('回合结束后提交被拒绝', !!err && /本回合已结束/.test(err.payload.message), err ? err.payload.message : '(无错误)');

    const ro2 = await h.tryWait('round_over', 2500);
    check('回合结束后不再重复广播 round_over', !ro2);
    const scoreNow = h.seen.filter(m => m.payload && m.payload.gameState)
      .map(m => m.payload.gameState.players.find(p => p.nickname === '房主').score).pop();
    check('房主分数未被重复累加', scoreNow === scoreA1, 'now=' + scoreNow + ' was=' + scoreA1);
    await teardown(h, gs);
  }

  // ---------------------------------------------------------------
  // 5. 倒计时：timeRemaining 随房间设置下发
  // ---------------------------------------------------------------
  console.log('\n=== 5. 倒计时 timeRemaining ===');
  {
    const { h, gs } = await room('info', { timeLimit: 45 });
    const rs = await h.wait('round_start', 9000);
    const gsPayload = rs.payload.gameState;
    check('gameState 下发 timeRemaining', typeof gsPayload.timeRemaining === 'number', 'value=' + gsPayload.timeRemaining);
    check('timeRemaining 与房间 timeLimit(45) 一致', gsPayload.timeRemaining === 45, 'value=' + gsPayload.timeRemaining);
    await sleep(2500);
    h.reset(); h.send('submit_guess', { songId: '__x__', songName: '__x__' });
    const gsu = await h.wait('game_state_updated', 6000);
    const tr = gsu.payload.gameState.timeRemaining;
    note('2.5 秒后 timeRemaining=' + tr);
    check('timeRemaining 随时间递减', tr < 45 && tr >= 41, 'value=' + tr);
    await teardown(h, gs);
  }

  // ---------------------------------------------------------------
  // 6. 重开新一轮（原先报「游戏已开始」）
  // ---------------------------------------------------------------
  console.log('\n=== 6. 结束后重开新一轮 ===');
  {
    const { h, gs } = await room('info', { totalRounds: 1 });
    const rs = await h.wait('round_start', 9000);
    const t = rs.payload.gameState.currentSong;
    h.send('submit_guess', { songId: String(t.id), songName: t.title });
    await h.wait('guess_received', 6000);
    const over = await h.wait('game_over', 6000);
    const finalScore = over.payload.gameState.players.find(p => p.nickname === '房主').score;
    note('单回合结束，房主最终分数=' + finalScore + ', status=' + over.payload.gameState.status);
    check('游戏结束 status=ended', over.payload.gameState.status === 'ended', over.payload.gameState.status);

    h.reset();
    h.send('start_game', {});
    // 注意：必须用 waitAny，先等 error 会推过游标把 round_start 吃掉
    const first = await h.waitAny(['error', 'round_start'], 6000);
    const err = first.action === 'error' ? first : null;
    const rs2 = first.action === 'round_start' ? first : null;
    check('结束后可重开新一轮', !!rs2 && !err, err ? ('错误=' + err.payload.message) : (rs2 ? 'ok' : '无 round_start'));
    if (rs2) {
      check('重开后回合数从 1 开始', rs2.payload.gameState.currentRound === 1, 'round=' + rs2.payload.gameState.currentRound);
      check('重开后分数清零', rs2.payload.gameState.players.every(p => p.score === 0), JSON.stringify(rs2.payload.gameState.players.map(p => p.nickname + ':' + p.score)));
    }
    await teardown(h, gs);
  }

  // ---------------------------------------------------------------
  // 7. letters（开字母）：多曲 + 掩码 + 服务端开字母
  // ---------------------------------------------------------------
  console.log('\n=== 7. letters 开字母模式 ===');
  {
    const { h, gs } = await room('letters', { songCount: 4, nonEnglishCharThreshold: 0, totalRounds: 2 });
    const rs = await h.wait('round_start', 9000);
    const gsPayload = rs.payload.gameState;
    const targets = gsPayload.targetSongs;
    check('letters 下发 targetSongs 数组', Array.isArray(targets), 'type=' + typeof targets);
    check('letters 抽取数量 = songCount(4)', Array.isArray(targets) && targets.length === 4, 'len=' + (targets || []).length);
    check('letters targetSongs 无重复曲目', Array.isArray(targets) && new Set(targets.map(s => String(s.id))).size === targets.length);
    check('letters 下发 maskedTitles', !!gsPayload.maskedTitles, 'undefined');
    if (gsPayload.maskedTitles) {
      const first = Object.values(gsPayload.maskedTitles)[0];
      note('初始掩码示例: ' + first);
      check('初始掩码为 □（未开字母）', !/[^□ ]/.test(first) || first.includes(' ') === false, 'mask=' + first);
    }

    // 开字母：“开字母”由服务端共享
    h.reset(); gs[0].reset();
    const letter = targets[0].title[0];
    h.send('open_letter', { letter });
    const lo = await h.tryWait('letter_opened', 5000);
    check('open_letter 返回 letter_opened', !!lo, lo ? 'ok' : '无回执');
    const gsu = await gs[0].tryWait('game_state_updated', 5000);
    check('开字母结果广播给其他玩家', !!gsu);
    if (gsu) {
      const opened = gsu.payload.gameState.openedLetters;
      check('openedLetters 记录已开字母', Array.isArray(opened) && opened.includes(letter), JSON.stringify(opened));
      const maskForTarget = gsu.payload.gameState.maskedTitles[String(targets[0].id)];
      note('开「' + letter + '」后掩码: ' + maskForTarget);
      const expected = [...targets[0].title].map(c => (c === ' ' || c.toLowerCase() === letter.toLowerCase()) ? c : '□').join('');
      check('掩码按所开字母正确揭示', maskForTarget === expected, 'got=' + maskForTarget + ' want=' + expected);
    }

    // 重复开同一字母 → 拒绝
    gs[0].reset();
    gs[0].send('open_letter', { letter });
    const dup = await gs[0].tryWait('error', 4000);
    check('重复开同一字母被拒绝', !!dup && /已经开过/.test(dup.payload.message), dup ? dup.payload.message : '(无错误)');

    // 猜中 1 首：回合不应结束（还有 3 首）
    h.reset();
    h.send('submit_guess', { songId: String(targets[0].id), songName: targets[0].title });
    const gr = await h.wait('guess_received', 6000);
    check('letters 猜中第一首判对', gr.payload.guess.correct === true, 'correct=' + gr.payload.guess.correct);
    const earlyOver = await h.tryWait('round_over', 2500);
    check('letters 只猜中 1 首时回合不结束', !earlyOver, earlyOver ? '提前结束了' : 'ok');

    // 猜中其余 → 回合结束
    for (let i = 1; i < targets.length; i++) {
      h.send('submit_guess', { songId: String(targets[i].id), songName: targets[i].title });
      await h.wait('guess_received', 6000);
    }
    const done = await h.wait('round_over', 6000);
    check('letters 全部猜中后回合结束', !!done);
    if (done) {
      const gsF = done.payload.gameState;
      check('letters 结束时 foundSongIds 覆盖全部目标', (gsF.foundSongIds || []).length === targets.length,
        JSON.stringify(gsF.foundSongIds));
      const masked = Object.values(gsF.maskedTitles || {});
      check('letters 结束后掩码全部公开', masked.every(m => !m.includes('□')), JSON.stringify(masked));
      const scores = gsF.players.map(p => p.score);
      check('letters 全部猜中者拿到分数', scores.some(s => s > 0), JSON.stringify(scores));
    }
    await teardown(h, gs);
  }

  // ---------------------------------------------------------------
  // 8. 九个模式端到端冒烟
  // ---------------------------------------------------------------
  console.log('\n=== 8. 九模式端到端冒烟 ===');
  for (const mode of MODES) {
    let h = null, gs = [];
    try {
      const r = await room(mode, {}, 2);
      h = r.h; gs = r.gs;
      const rs = await h.wait('round_start', 9000);
      const st = rs.payload.gameState;
      const songs = (st.targetSongs && st.targetSongs.length) ? st.targetSongs : [st.currentSong];
      const t = songs[0];
      check(mode + ': 开局并下发题目', !!t && !!t.id, JSON.stringify(st.currentSong && st.currentSong.id));
      const guestStart = await gs[0].tryWait('round_start', 5000);
      check(mode + ': 对手也收到 round_start', !!guestStart);

      // 猜错不结束
      h.send('submit_guess', { songId: '__wrong__', songName: '___绝对不存在的曲名___' });
      const gWrong = await h.wait('guess_received', 6000);
      check(mode + ': 猜错判 false 且不回结束回合', gWrong.payload.guess.correct === false);

      // 猜对 → 结束
      if (mode === 'letters') {
        for (const s of songs) {
          h.send('submit_guess', { songId: String(s.id), songName: s.title });
          await h.wait('guess_received', 6000);
        }
      } else {
        h.send('submit_guess', { songId: String(t.id), songName: t.title });
        await h.wait('guess_received', 6000);
      }
      const over = await h.waitAny(['round_over', 'game_over'], 6000);
      check(mode + ': 答对后回合结束', !!over);
      const winner = over.payload.gameState.players.find(p => p.score > 0);
      check(mode + ': 答对者得分', !!winner, JSON.stringify(over.payload.gameState.players.map(p => p.nickname + ':' + p.score)));
    } catch (e) {
      check(mode + ': 端到端', false, e.message);
    } finally {
      if (h) await teardown(h, gs);
    }
  }

  // ---------------------------------------------------------------
  // 9. 模式专属参数回传
  // ---------------------------------------------------------------
  console.log('\n=== 9. 模式专属参数 ===');
  {
    const { h, gs } = await room('blurred', { blurLevel: 88 }, 2);
    const rs = await h.wait('round_start', 9000);
    note('blurred blurLevel 已在开局前回传=' + h.seen.map(m => m.payload && m.payload.room && m.payload.room.blurLevel).filter(Boolean).pop());
    check('blurred: 玩法参数生效（能正常开局）', !!rs.payload.gameState.currentSong.id);
    await teardown(h, gs);
  }
  {
    const { h, gs } = await room('audio', { playDuration: 25 }, 2);
    const rs = await h.wait('round_start', 9000);
    check('audio: 玩法参数生效（能正常开局）', !!rs.payload.gameState.currentSong.id);
    await teardown(h, gs);
  }
  // flash / tileReveal / chartPeek：参数必须原样回传给所有客户端
  {
    const { h, gs, room: r } = await room('flash', { flashDurationMs: 900 }, 2);
    const rs = await h.wait('round_start', 9000);
    check('flash: flashDurationMs=900 回传', r.flashDurationMs === 900, 'got=' + r.flashDurationMs);
    check('flash: 能正常开局', !!rs.payload.gameState.currentSong.id);
    await teardown(h, gs);
  }
  {
    const { h, gs, room: r } = await room('tileReveal', { tileCount: 2500, tileRevealIntervalMs: 700 }, 2);
    const rs = await h.wait('round_start', 9000);
    check('tileReveal: tileCount / 揭示间隔回传', r.tileCount === 2500 && r.tileRevealIntervalMs === 700,
      'tileCount=' + r.tileCount + ', interval=' + r.tileRevealIntervalMs);
    check('tileReveal: 能正常开局', !!rs.payload.gameState.currentSong.id);
    await teardown(h, gs);
  }
  {
    const { h, gs, room: r } = await room('chartPeek', { peekDurationSeconds: 20, peekDifficulties: ['3', '5'] }, 2);
    const rs = await h.wait('round_start', 9000);
    check('chartPeek: 片段时长 / 难度池回传',
      r.peekDurationSeconds === 20 && JSON.stringify(r.peekDifficulties) === JSON.stringify(['3', '5']),
      'peek=' + r.peekDurationSeconds + ', pool=' + JSON.stringify(r.peekDifficulties));
    check('chartPeek: 能正常开局', !!rs.payload.gameState.currentSong.id);
    await teardown(h, gs);
  }
  // 越界 / 非法参数必须被服务端夹住或清洗（客户端不可信：
  // tileCount=0 会让拼图瞬间全揭示，非法难度编号会让别人抽不到谱面）
  {
    const { h, gs, room: r } = await room('tileReveal', { tileCount: 0, tileRevealIntervalMs: 999999 }, 2);
    check('tileReveal: tileCount=0 被夹到 100', r.tileCount === 100, 'got=' + r.tileCount);
    check('tileReveal: 揭示间隔被夹到 10000', r.tileRevealIntervalMs === 10000, 'got=' + r.tileRevealIntervalMs);
    await teardown(h, gs);
  }
  {
    const { h, gs, room: r } = await room('chartPeek', { peekDurationSeconds: 999, peekDifficulties: ['9', '1'] }, 2);
    check('chartPeek: 片段时长被夹到 60', r.peekDurationSeconds === 60, 'got=' + r.peekDurationSeconds);
    check('chartPeek: 非法难度池回退 [4]', JSON.stringify(r.peekDifficulties) === JSON.stringify(['4']),
      'got=' + JSON.stringify(r.peekDifficulties));
    await teardown(h, gs);
  }

  console.log('\n================ 汇总: ' + pass + ' 通过 / ' + fail + ' 失败 ================');
  if (failures.length) { console.log('失败项:'); failures.forEach(f => console.log('  - ' + f)); }
  process.exit(fail === 0 ? 0 : 1);
}

main().catch(e => { console.error('测试脚本异常:', e); process.exit(2); });
