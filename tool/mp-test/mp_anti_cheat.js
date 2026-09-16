const WebSocket = require('./mp_ws');
const URL = process.env.MP_URL || 'ws://127.0.0.1:3999';
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
      if (Date.now() - t0 > ms) { clearInterval(t); no(new Error(name + ' wait ' + act + ' timeout')); } }, 20); }); };
    c.tryWait = (act, ms = 3000) => c.wait(act, ms).catch(() => null);
    c.reset = () => { c.cur = c.seen.length; };
    c.close = () => { try { ws.close(); } catch (_) {} };
    return c;
  });
}
(async () => {
  const h = await mk('host');
  h.send('initialize', { nickname: '房主' }); await h.wait('initialized');
  h.send('create_room', { gameType: 'letters', maxPlayers: 2, timeLimit: 60, maxGuesses: 30, totalRounds: 2,
    selectedVersions: [], masterMinDx: 1.0, masterMaxDx: 15.0, selectedGenres: [], blurLevel: 50, playDuration: 5, songCount: 3, nonEnglishCharThreshold: 0 });
  const cr = await h.wait('room_created'); const r = cr.payload.room;
  const g = await mk('guest');
  g.send('initialize', { nickname: '玩家1' }); await g.wait('initialized');
  g.send('join_room', { roomId: r.id, nickname: '玩家1' }); await g.wait('room_joined');
  h.send('update_ready', { ready: true }); g.send('update_ready', { ready: true });
  await sleep(300); h.reset(); h.send('start_game', {});
  const rs = await h.wait('round_start', 9000);
  const targets = rs.payload.gameState.targetSongs;

  // 第一首连猜 3 次（作弊），再正常猜完剩下两首 → 结束回合
  for (let i = 0; i < 3; i++) {
    h.reset(); h.send('submit_guess', { songId: String(targets[0].id), songName: targets[0].title });
    await h.wait('guess_received', 6000);
    await sleep(100);
  }
  for (let i = 1; i < targets.length; i++) {
    h.reset(); h.send('submit_guess', { songId: String(targets[i].id), songName: targets[i].title });
    await h.wait('guess_received', 6000);
  }
  const ro = await h.wait('round_over', 9000);
  const me = ro.payload.gameState.players.find(p => p.nickname === '房主');
  console.log('房主本回合得分 = ' + me.score);
  console.log('正常上限 = ' + (targets.length * 100) + '（每首一个满分）；作弊把同一首算了 3 遍。');
  h.close(); g.close();
  process.exit(0);
})().catch(e => { console.error('异常:', e.message); process.exit(1); });