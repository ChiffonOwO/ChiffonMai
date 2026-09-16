// 首轮真实流程回归：创建→加入→准备→开局→多轮→结算→重开
// 重点验证「客户端会走的确切动作序列」都能被服务端正确处理
const WebSocket = require('./mp_ws');
const URL = process.env.MP_URL || 'ws://127.0.0.1:3999';
const sleep = ms => new Promise(r => setTimeout(r, ms));
let pass = 0, fail = 0;
function check(name, ok, detail) {
  if (ok) { pass++; console.log('  [PASS] ' + name); }
  else { fail++; console.log('  [FAIL] ' + name + (detail ? ' -- ' + detail : '')); }
}
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
    c.reset = () => { c.cur = c.seen.length; };
    c.close = () => { try { ws.close(); } catch (_) {} };
    return c;
  });
}

(async () => {
  console.log('=== 完整对局生命周期（letters，含重开）===');
  const h = await mk('host');
  h.send('initialize', { nickname: '房主' }); await h.wait('initialized');
  h.send('create_room', {
    gameType: process.env.MP_MODE || 'letters', maxPlayers: 2, timeLimit: 30, maxGuesses: 20, totalRounds: 2,
    selectedVersions: [], masterMinDx: 1.0, masterMaxDx: 15.0, selectedGenres: [],
    blurLevel: 50, playDuration: 5, songCount: 3, nonEnglishCharThreshold: 50,
  });
  const cr = await h.wait('room_created');
  const r = cr.payload.room;

  const g = await mk('guest');
  g.send('initialize', { nickname: '玩家1' }); await g.wait('initialized');
  g.send('join_room', { roomId: r.id, nickname: '玩家1' }); await g.wait('room_joined');

  h.send('update_ready', { ready: true }); g.send('update_ready', { ready: true });
  await sleep(300);
  h.reset(); g.reset(); h.send('start_game', {});
  let rs = await h.wait('round_start', 9000);

  const MODE = process.env.MP_MODE || 'letters';
  const targets = rs.payload.gameState.targetSongs;
  if (MODE === 'letters') {
    check('letters 抽到 3 首目标曲', targets.length === 3, 'len=' + targets.length);
    check('每首都有掩码', Object.keys(rs.payload.gameState.maskedTitles || {}).length === 3);
  } else {
    check(MODE + ': 下发 1 首目标曲', targets.length === 1, 'len=' + targets.length);
  }

  // 对手也收到同一份报文
  const rsGuest = await g.wait('round_start', 9000);
  if (MODE === 'letters') {
    check('对手收到相同掩码',
      JSON.stringify(rsGuest.payload.gameState.maskedTitles) === JSON.stringify(rs.payload.gameState.maskedTitles));
  } else {
    check('对手收到相同题目', String(rsGuest.payload.gameState.currentSong.id) === String(targets[0].id));
  }

  if (MODE === 'letters') {
    // 对手开一个字母
    const firstLetter = targets[0].title.replace(/[^A-Za-z]/g, '')[0] || 'a';
    g.send('open_letter', { letter: firstLetter });
    const lo = await g.wait('letter_opened', 6000);
    check('开字母回执 success', lo.payload.success === true);
    check('回执带 openedLetters', Array.isArray(lo.payload.openedLetters) && lo.payload.openedLetters.length === 1);

    const upd = await h.wait('game_state_updated', 6000);
    const masked = upd.payload.gameState.maskedTitles[String(targets[0].id)];
    check('发起者之外的人也能看到开了字', masked.includes(firstLetter), 'masked=' + masked);

    // 重复开同一字母 → 应被拒
    g.send('open_letter', { letter: firstLetter });
    const err = await g.tryWait('error', 4000);
    check('重复开同一字母被拒', !!err && /已经开过/.test(err.payload.message), err ? err.payload.message : '(无错误)');
  } else {
    // 非 letters 模式不接受开字母
    g.send('open_letter', { letter: 'A' });
    const err = await g.tryWait('error', 4000);
    check('非 letters 模式开字母被拒', !!err && /不支持/.test(err.payload.message), err ? err.payload.message : '(无错误)');
  }

  // 逐个猜中全部 3 首
  for (let i = 0; i < targets.length; i++) {
    h.reset(); h.send('submit_guess', { songId: String(targets[i].id), songName: targets[i].title });
    const gr = await h.wait('guess_received', 6000);
    check('第' + (i + 1) + '首判对', gr.payload.guess.correct === true);
    if (i < targets.length - 1) {
      const after = await h.wait('game_state_updated', 6000);
      check('猜中第' + (i + 1) + '首后回合未结束', after.payload.gameState.isRoundOver === false);
      const foundId = after.payload.gameState.foundSongIds;
      check('  foundSongIds 已记录', foundId.length === i + 1, 'len=' + foundId.length);
    }
  }
  const ro = await h.wait('round_over', 9000);
  check('全部猜中后回合结束', ro.payload.gameState.isRoundOver === true);
  if (MODE === 'letters') {
    check('回合结束时掩码全公开',
      Object.values(ro.payload.gameState.maskedTitles || {}).every(m => !String(m).includes('□')));
  }

  // 第二回合
  h.reset(); h.send('start_next_round', {});
  rs = await h.wait('round_start', 9000);
  check('第二回合开始', rs.payload.gameState.currentRound === 2);
  if (MODE === 'letters') {
    check('新回合掩码已重置', Object.values(rs.payload.gameState.maskedTitles).every(m => String(m).includes('□')));
    check('新回合 openedLetters 清空', (rs.payload.gameState.openedLetters || []).length === 0);
    check('新回合 foundSongIds 清空', (rs.payload.gameState.foundSongIds || []).length === 0);
  }

  // 第二回合：猜完 3 首 → 回合数用尽 → game_over
  for (let i = 0; i < targets.length; i++) {
    const t2 = rs.payload.gameState.targetSongs[i];
    h.reset(); h.send('submit_guess', { songId: String(t2.id), songName: t2.title });
    await h.wait('guess_received', 6000);
  }
  const gameOver = await h.wait('game_over', 9000);
  const st = gameOver.payload.gameState;
  check('回合数用尽后游戏结束', st.isGameOver === true, 'isGameOver=' + st.isGameOver);

  // ★ 重开新一轮（原先服务端会报「游戏已开始」）
  h.reset();
  h.send('start_game', {});
  const restarted = await h.tryWait('round_start', 9000);
  const restartErr = await h.tryWait('error', 1500);
  check('游戏结束后可以重开新一轮', !!restarted, restartErr ? '错误=' + restartErr.payload.message : '(无 round_start)');
  if (restarted) {
    check('重开后回到第 1 回合', restarted.payload.gameState.currentRound === 1);
    check('重开后分数已清零',
      (restarted.payload.gameState.players || []).every(p => p.score === 0),
      JSON.stringify((restarted.payload.gameState.players || []).map(p => p.score)));
  }

  h.close(); g.close();
  await sleep(200);
  console.log('\n================ 汇总: ' + pass + ' 通过 / ' + fail + ' 失败 ================');
  process.exit(fail === 0 ? 0 : 1);
})().catch(e => { console.error('异常:', e.message); process.exit(1); });