// 回归补充：跨模式刷分 + timeLimit 下发 + 服务端计时基准
const WebSocket = require('./mp_ws');
const URL = process.env.MP_URL || 'ws://127.0.0.1:3999';
const sleep = ms => new Promise(r => setTimeout(r, ms));
let pass = 0, fail = 0;
function check(n, ok, d) { if (ok) { pass++; console.log('  [PASS] ' + n); } else { fail++; console.log('  [FAIL] ' + n + (d ? ' -- ' + d : '')); } }
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
      if (Date.now() - t0 > ms) { clearInterval(t); no(new Error(name + ' wait ' + act + ' timeout')); } }, 20); }); };
    c.tryWait = (act, ms = 3000) => c.wait(act, ms).catch(() => null);
    c.reset = () => { c.cur = c.seen.length; };
    c.close = () => { try { ws.close(); } catch (_) {} };
    return c;
  });
}
async function room(mode, opts, songCount) {
  const h = await mk('h');
  h.send('initialize', { nickname: '房主' }); await h.wait('initialized');
  h.send('create_room', Object.assign({ gameType: mode, maxPlayers: 2, timeLimit: 30, maxGuesses: 30, totalRounds: 3,
    selectedVersions: [], masterMinDx: 1.0, masterMaxDx: 15.0, selectedGenres: [], blurLevel: 50,
    playDuration: 5, songCount: songCount, nonEnglishCharThreshold: 0 }, opts || {}));
  const cr = await h.wait('room_created'); const r = cr.payload.room;
  const g = await mk('g');
  g.send('initialize', { nickname: '玩家1' }); await g.wait('initialized');
  g.send('join_room', { roomId: r.id, nickname: '玩家1' }); await g.wait('room_joined');
  h.send('update_ready', { ready: true }); g.send('update_ready', { ready: true });
  await sleep(300); h.reset(); h.send('start_game', {});
  const rs = await h.wait('round_start', 9000);
  return { h, g, rs, room: r };
}
(async () => {
  console.log('=== A. letters 重复猜同一首不再刷分（含 3 首上限）===');
  {
    const { h, g, rs } = await room('letters', {}, 3);
    const targets = rs.payload.gameState.targetSongs;
    for (let i = 0; i < 3; i++) { h.reset(); h.send('submit_guess', { songId: String(targets[0].id), songName: targets[0].title }); await h.wait('guess_received', 6000); await sleep(80); }
    for (let i = 1; i < targets.length; i++) { h.reset(); h.send('submit_guess', { songId: String(targets[i].id), songName: targets[i].title }); await h.wait('guess_received', 6000); }
    const ro = await h.wait('round_over', 9000);
    const me = ro.payload.gameState.players.find(p => p.nickname === '房主');
    check('letters 重复猜同一首只计一次分', me.score <= targets.length * 100, 'score=' + me.score + ' 上限=' + targets.length * 100);
    check('letters 正常猜完仍能拿到分', me.score >= targets.length * 10, 'score=' + me.score);
    h.close(); g.close(); await sleep(150);
  }

  console.log('=== B. timeLimit 随 round_start 下发（倒计时不再固定 60）===');
  for (const mode of ['info', 'letters']) {
    const { h, g, rs } = await room(mode, { timeLimit: 30 }, mode === 'letters' ? 3 : 1);
    const gs = rs.payload.gameState;
    check(mode + ': gameState.timeLimit = 房间设置 30', gs.timeLimit === 30, 'timeLimit=' + gs.timeLimit);
    check(mode + ': timeRemaining 在 (0, 30] 内', gs.timeRemaining > 0 && gs.timeRemaining <= 30, 'timeRemaining=' + gs.timeRemaining);
    h.close(); g.close(); await sleep(150);
  }

  console.log('=== C. 服务端计时基准真实（timeSpent 不再恒为 0）===');
  {
    const { h, g, rs } = await room('info', {}, 1);
    const t = rs.payload.gameState.currentSong;
    await sleep(3000);
    h.reset(); h.send('submit_guess', { songId: String(t.id), songName: t.title });
    const gr = await h.wait('guess_received', 6000);
    const spent = gr.payload.guess.timeSpent;
    check('等待 3 秒后 timeSpent ≥ 2.5', spent >= 2.5, 'timeSpent=' + spent);
    check('得分随耗时下降（<100）', gr.payload.guess.score < 100, 'score=' + gr.payload.guess.score);
    h.close(); g.close(); await sleep(150);
  }

  console.log('=== D. 非 letters 模式猜中即结束，不会漏结算 ===');
  {
    const { h, g, rs } = await room('info', {}, 1);
    const t = rs.payload.gameState.currentSong;
    h.reset(); h.send('submit_guess', { songId: String(t.id), songName: t.title });
    await h.wait('guess_received', 6000);
    const ro = await h.wait('round_over', 9000);
    const me = ro.payload.gameState.players.find(p => p.nickname === '房主');
    check('info 猜中后回合结束且有分', ro.payload.gameState.isRoundOver === true && me.score > 0, 'score=' + me.score);
    h.close(); g.close(); await sleep(150);
  }
  console.log('=== E. 结算后必须补发 room_updated（排行榜分数不再慢一回合）===');
  {
    // 起因：服务端是先广播 room_updated 再 endRound()，结算结果只随 round_over
    // 下发。客户端排行榜读的是 room.players，于是永远落后一回合 —— 真机表现为
    // 「答对了! +62分」下面排行榜还停在上一回合。修复后端上这两条必须一致：
    // round_over 之后要再有一条 room_updated，且分数等于 gameState.players 的值。
    const { h, g, rs } = await room('info', {}, 1);
    const t = rs.payload.gameState.currentSong;
    h.reset();
    h.send('submit_guess', { songId: String(t.id), songName: t.title });
    await h.wait('guess_received', 6000);
    const ro = await h.wait('round_over', 9000);

    // 等一小会，让补发的 room_updated 到达
    let after = null;
    for (let i = 0; i < 30 && !after; i++) {
      after = h.seen.slice(h.cur).find(m => m.action === 'room_updated');
      if (!after) await sleep(100);
    }

    const gsScore = ro.payload.gameState.players.find(p => p.nickname === '房主').score;
    const roomScore = after
      ? after.payload.room.players.find(p => p.nickname === '房主').score
      : null;

    check('round_over 之后仍会收到 room_updated', after != null,
      after ? '收到' : '未收到（结算结果没有随 room 状态下发）');
    check('补发的 room_updated 分数已包含本回合结算',
      roomScore === gsScore,
      'room=' + roomScore + ' gameState=' + gsScore);
    check('补发的 room_updated 分数大于 0', roomScore != null && roomScore > 0,
      'roomScore=' + roomScore);

    h.close(); g.close(); await sleep(150);
  }

  console.log('\n================ 汇总: ' + pass + ' 通过 / ' + fail + ' 失败 ================');
  process.exit(fail === 0 ? 0 : 1);
})().catch(e => { console.error('异常:', e.message); process.exit(1); });
