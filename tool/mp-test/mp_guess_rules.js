// ===========================================================================
// 多人猜歌 —— 计分 / 结算规则回归测试
// 用法：node tool/mp-test/mp_guess_rules.js [ws url]   默认 ws://127.0.0.1:3999
//
// 覆盖三处「规则说得通、实现说不通」的缺陷：
//   1. 投降玩家仍能提交猜测并消耗全房间共享的猜测次数池
//   2. 共享次数池用尽后回合不结束（规则写明「用完本回合即结束」）
//   3. letters 模式下同一首曲目被多人猜中时**人人都计分**，
//      先猜中者反而只领先一两分（猜中即公开完整曲名，等于送答案）
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
      if (Date.now() - t0 > ms) { clearInterval(t); no(new Error(name + ' waitAny(' + acts.join('/') + ') 超时')); } }, 20); }); };
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

async function main() {
  // -------------------------------------------------------------------
  console.log('\n=== 1. 投降玩家：不能再提交、不消耗共享次数池、不计分 ===');
  {
    const { h, gs } = await room('info', { maxGuesses: 10, timeLimit: 60 });
    const g = gs[0];
    const rs = await h.wait('round_start', 9000);
    const target = rs.payload.gameState.currentSong;

    g.send('surrender', {});
    await g.wait('player_surrendered', 5000);

    // 投降后提交：不应被接受，也不应消耗共享次数池
    g.reset(); h.reset();
    g.send('submit_guess', { songId: '__x__', songName: '投降后的试探' });
    const gr = await g.tryWait('guess_received', 2500);
    check('投降后提交猜测被拒绝', !gr, gr ? '仍被接受(correct=' + gr.payload.guess.correct + ')' : 'ok');

    // 房主视角看共享次数池：应仍为 0
    h.send('submit_guess', { songId: '__probe__', songName: '占用一次以获取最新状态' });
    await h.wait('guess_received', 6000);
    const gsu = await h.wait('game_state_updated', 6000);
    check('投降者的提交不消耗共享次数池', gsu.payload.gameState.currentGuesses === 1,
      'currentGuesses=' + gsu.payload.gameState.currentGuesses + '（应为 1，即只有这次探测提交）');

    // 房主答对 → 回合结束 → 投降者应 0 分
    h.reset();
    h.send('submit_guess', { songId: String(target.id), songName: target.title });
    await h.wait('guess_received', 6000);
    const over = await h.waitAny(['round_over', 'game_over'], 8000);
    const players = over.payload.gameState.players;
    const me = players.find(p => p.nickname === '房主');
    const quitter = players.find(p => p.nickname === '玩家0');
    check('投降者本回合 0 分', quitter.score === 0, '玩家0=' + quitter.score);
    check('未投降的答对者得分', me.score > 0, '房主=' + me.score);
    await teardown(h, gs);
  }

  // -------------------------------------------------------------------
  console.log('\n=== 2. 共享次数池用尽 → 本回合结束 ===');
  {
    const { h, gs } = await room('info', { maxGuesses: 2, timeLimit: 120 });
    await h.wait('round_start', 9000);

    h.send('submit_guess', { songId: '__w1__', songName: '故意猜错一' });
    await h.wait('guess_received', 6000);
    h.send('submit_guess', { songId: '__w2__', songName: '故意猜错二' });
    await h.wait('guess_received', 6000);
    note('已用尽 maxGuesses=2（timeLimit=120，远未超时）');

    // 注意：不能先 reset()，round_over 紧跟 guess_received 广播，reset 会把它丢掉
    const over = await h.tryWait('round_over', 6000);
    check('次数用尽后回合自动结束', !!over, over ? 'ok' : '回合仍挂着，只能等超时');
    if (over) {
      check('结束时 isRoundOver=true', over.payload.gameState.isRoundOver === true,
        'isRoundOver=' + over.payload.gameState.isRoundOver);
    }

    // 对手也应收到回合结束，房主才能推进
    const guestOver = await gs[0].tryWait('round_over', 6000);
    check('对手也收到 round_over', !!guestOver);
    await teardown(h, gs);
  }

  // -------------------------------------------------------------------
  console.log('\n=== 3. letters：同一首曲目只有最先猜中者得分 ===');
  {
    const { h, gs } = await room('letters', { songCount: 3, maxGuesses: 30, nonEnglishCharThreshold: 0, totalRounds: 1 });
    const g = gs[0];
    const rs = await h.wait('round_start', 9000);
    const targets = rs.payload.gameState.targetSongs;
    note('目标 ' + targets.length + ' 首，首曲：「' + targets[0].title + '」');

    // 房主先猜中第 1 首
    h.send('submit_guess', { songId: String(targets[0].id), songName: targets[0].title });
    const first = await h.wait('guess_received', 6000);
    check('先猜中者判对', first.payload.guess.correct === true);

    // 对手照抄（掩码此时已公开完整曲名）——不应得分
    await sleep(1100);
    g.reset();
    g.send('submit_guess', { songId: String(targets[0].id), songName: targets[0].title });
    const copy = await g.wait('guess_received', 6000);
    check('抄答案仍判对（判定口径不变）', copy.payload.guess.correct === true);

    // 房主猜完剩余两首 → 回合结束
    for (let i = 1; i < targets.length; i++) {
      h.send('submit_guess', { songId: String(targets[i].id), songName: targets[i].title });
      await h.wait('guess_received', 6000);
    }
    const over = await h.waitAny(['round_over', 'game_over'], 9000);
    const players = over.payload.gameState.players;
    const host = players.find(p => p.nickname === '房主');
    const copier = players.find(p => p.nickname === '玩家0');
    note('房主=' + host.score + ' 玩家0=' + copier.score);
    check('先猜中者拿到该曲分数', host.score > 0, '房主=' + host.score);
    check('照抄者在该曲上 0 分', copier.score === 0, '玩家0=' + copier.score);
    check('单回合总分不超过 曲目数×100', host.score <= targets.length * 100,
      '房主=' + host.score + ' 上限=' + (targets.length * 100));
    await teardown(h, gs);
  }

  // -------------------------------------------------------------------
  console.log('\n=== 4. letters：同一首重复提交不重复计分 ===');
  {
    const { h, gs } = await room('letters', { songCount: 2, maxGuesses: 30, nonEnglishCharThreshold: 0, totalRounds: 1 });
    const rs = await h.wait('round_start', 9000);
    const targets = rs.payload.gameState.targetSongs;

    // 同一首连猜 3 次，再猜另一首
    for (let i = 0; i < 3; i++) {
      h.send('submit_guess', { songId: String(targets[0].id), songName: targets[0].title });
      await h.wait('guess_received', 6000);
    }
    for (let i = 1; i < targets.length; i++) {
      h.send('submit_guess', { songId: String(targets[i].id), songName: targets[i].title });
      await h.wait('guess_received', 6000);
    }
    const over = await h.waitAny(['round_over', 'game_over'], 9000);
    const host = over.payload.gameState.players.find(p => p.nickname === '房主');
    note('2 首曲目、首曲猜 3 次，实得 ' + host.score + '（上限 200）');
    check('重复提交同一首不重复计分', host.score <= targets.length * 100,
      '房主=' + host.score + ' 上限=' + (targets.length * 100));
    await teardown(h, gs);
  }

  // -------------------------------------------------------------------
  console.log('\n=== 5. 非 letters 模式：先答对者独占本题 ===');
  {
    const { h, gs } = await room('info', { maxGuesses: 10 });
    const g = gs[0];
    const rs = await h.wait('round_start', 9000);
    const t = rs.payload.gameState.currentSong;

    h.send('submit_guess', { songId: String(t.id), songName: t.title });
    await h.wait('guess_received', 6000);
    const over = await h.waitAny(['round_over', 'game_over'], 9000);
    const players = over.payload.gameState.players;
    const host = players.find(p => p.nickname === '房主');
    const other = players.find(p => p.nickname === '玩家0');
    check('先答对者得分', host.score > 0, '房主=' + host.score);
    check('未答对者 0 分', other.score === 0, '玩家0=' + other.score);
    await teardown(h, gs);
  }

  // -------------------------------------------------------------------
  console.log('\n=== 6. 胜负判定：服务端下发 winners ===');
  {
    // 房主一路答对、对手不动 → 房主包揽全部回合
    const { h, gs } = await room('info', { maxGuesses: 30, totalRounds: 2 });
    let last = null;
    let finalState = null;
    for (let r = 0; r < 2; r++) {
      const rs = await h.wait('round_start', 9000);
      const t = rs.payload.gameState.currentSong;
      h.send('submit_guess', { songId: String(t.id), songName: t.title });
      await h.wait('guess_received', 6000);
      last = await h.waitAny(['round_over', 'game_over'], 9000);
      if (r === 0) {
        // 回合中途不应下发 winners（避免提前弹「获胜」）
        check('回合进行中不下发 winners', last.payload.gameState.winners === undefined,
          'winners=' + JSON.stringify(last.payload.gameState.winners));
        h.send('start_next_round', {});
      } else {
        // 最后一回合：waitAny 可能已经消费掉 game_over，直接复用这条报文
        finalState = last.payload.gameState;
      }
    }
    const st = finalState || (await h.wait('game_over', 9000)).payload.gameState;
    check('终局 isGameOver=true', st.isGameOver === true, 'isGameOver=' + st.isGameOver);
    const players = st.players;
    const host = players.find(p => p.nickname === '房主');
    const other = players.find(p => p.nickname === '玩家0');
    check('终局下发 winners 数组', Array.isArray(st.winners), 'winners=' + JSON.stringify(st.winners));
    check('winners 恰为 1 人', Array.isArray(st.winners) && st.winners.length === 1,
      JSON.stringify(st.winners));
    check('winners 是最高分玩家', Array.isArray(st.winners) && st.winners[0] === host.id,
      'winners=' + JSON.stringify(st.winners) + ' 房主=' + host.id + ' 分=' + host.score);
    note('房主=' + host.score + ' 玩家0=' + other.score);
    await teardown(h, gs);
  }

  // -------------------------------------------------------------------
  console.log('\n=== 7. 胜负判定：同分并列 / 全场 0 分平局 ===');
  {
    // 两人都不得分（一直不猜，靠超时结束）→ 平局（winners 为空）
    const { h, gs } = await room('info', { maxGuesses: 10, timeLimit: 3, totalRounds: 1 });
    await h.wait('round_start', 9000);
    const done = await h.wait('game_over', 15000);
    const st = done.payload.gameState;
    check('全场 0 分时 winners 为空（平局）',
      Array.isArray(st.winners) && st.winners.length === 0,
      'winners=' + JSON.stringify(st.winners) + ' scores=' + JSON.stringify(st.players.map(p => p.score)));
    await teardown(h, gs);
  }

  // -------------------------------------------------------------------
  console.log('\n=== 8. 胜负判定：同分并列（两人各赢一个回合）===');
  {
    // 非 letters 模式每回合只有「最先答对者」得分，所以让两人各赢一个回合、
    // 且都在回合开始后 1 秒内作答（floor(spent)=0 → 各得 100），总分必然相等。
    const { h, gs, room: r } = await room('info', { maxGuesses: 30, totalRounds: 2 });
    const g = gs[0];

    // 回合1：房主秒答 → 100，玩家0 不动 → 0
    const rs1 = await h.wait('round_start', 9000);
    const t1 = rs1.payload.gameState.currentSong;
    h.send('submit_guess', { songId: String(t1.id), songName: t1.title });
    await h.wait('guess_received', 6000);
    const over1 = await h.wait('round_over', 9000);
    const s1 = over1.payload.gameState.players;
    note('回合1 后 房主=' + s1.find(p => p.nickname === '房主').score +
         ' 玩家0=' + s1.find(p => p.nickname === '玩家0').score);

    // 回合2：玩家0 秒答 → 100，房主不动 → 总分打平
    // 注意：房主这边的游标停在 round_over 之后，若不在发指令前对齐，
    // 会把回合1 的残留报文当成回合2 的（这里 guest 的游标才是权威）。
    h.reset(); g.reset();
    h.send('start_next_round', {});
    const rs2 = await g.wait('round_start', 9000);
    const t2 = rs2.payload.gameState.currentSong;
    g.send('submit_guess', { songId: String(t2.id), songName: t2.title });
    await g.wait('guess_received', 6000);

    // 第二回合是最后一回合 → 直接进终局（房主侧此刻应有的下一条就是 game_over）
    const done = await h.wait('game_over', 12000);
    const st = done.payload.gameState;
    const host = st.players.find(p => p.nickname === '房主');
    const guest = st.players.find(p => p.nickname === '玩家0');
    note('终局 房主=' + host.score + ' 玩家0=' + guest.score);
    check('两人总分确实相等（构造成功）', host.score === guest.score && host.score > 0,
      '房主=' + host.score + ' 玩家0=' + guest.score);
    check('同分时 winners 同时包含两人',
      Array.isArray(st.winners) && st.winners.length === 2 &&
      st.winners.includes(host.id) && st.winners.includes(guest.id),
      'winners=' + JSON.stringify(st.winners) + ' host=' + host.id + ' guest=' + guest.id);
    await teardown(h, gs);
  }

  console.log('\n================ 汇总: ' + pass + ' 通过 / ' + fail + ' 失败 ================');
  if (failures.length) { console.log('失败项:'); failures.forEach(f => console.log('  - ' + f)); }
  process.exit(fail ? 1 : 0);
}

main().catch(e => { console.error('测试异常:', e.message); process.exit(1); });
