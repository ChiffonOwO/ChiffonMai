// 探查：回合结算后，客户端拿到的房间分数是否已更新
// 起因：真机截图里「答对了! +62分」与排行榜「57 分」对不上
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
    c.close = () => { try { ws.close(); } catch (_) {} };
    return c;
  });
}

(async () => {
  const h = await mk('host');
  h.send('initialize', { nickname: '房主' }); await h.wait('initialized');
  h.send('create_room', {
    gameType: 'info', maxPlayers: 2, timeLimit: 60, maxGuesses: 40, totalRounds: 3,
    selectedVersions: [], masterMinDx: 1.0, masterMaxDx: 15.0, selectedGenres: [],
    blurLevel: 50, playDuration: 5, songCount: 3, nonEnglishCharThreshold: 0,
  });
  const cr = await h.wait('room_created');
  const room = cr.payload.room;
  const g = await mk('guest');
  g.send('initialize', { nickname: '玩家1' }); await g.wait('initialized');
  g.send('join_room', { roomId: room.id, nickname: '玩家1' }); await g.wait('room_joined');
  h.send('update_ready', { ready: true });
  g.send('update_ready', { ready: true });
  await sleep(300);

  for (let rnd = 1; rnd <= 3; rnd++) {
    h.seen.length = 0; h.cur = 0;
    h.send(rnd === 1 ? 'start_game' : 'start_next_round', {});
    const rs = await h.wait('round_start', 9000);
    const song = rs.payload.gameState.currentSong;

    await sleep(1500); // 让得分明显小于满分，便于分辨
    h.send('submit_guess', { songId: String(song.id), songName: song.title });
    const gr = await h.wait('guess_received', 6000);
    let over = null;
    for (let i = 0; i < 40 && !over; i++) {
      over = h.seen.find(m => m.action === 'round_over' || m.action === 'game_over');
      if (!over) await sleep(150);
    }
    const idx = h.seen.indexOf(over);
    const before = h.seen.slice(0, idx).filter(m => m.action === 'room_updated').pop();
    const gsPlayers = over.payload.gameState.players || [];
    console.log(`--- 第 ${rnd} 回合 ---`);
    console.log(`  本次答对得分 guess.score = ${gr.payload.guess.score} (耗时 ${gr.payload.guess.timeSpent.toFixed(2)}s)`);
    console.log(`  round_over 之前最后一条 room_updated 里房主分数 = ${before ? before.payload.room.players.find(p => p.nickname === '房主').score : '(无)'}`);
    console.log(`  round_over 的 gameState.players 里房主分数 = ${gsPlayers.find(p => p.nickname === '房主') ? gsPlayers.find(p => p.nickname === '房主').score : '(未下发)'}`);
    console.log(`  round_over 之后是否还有 room_updated = ${h.seen.slice(idx + 1).some(m => m.action === 'room_updated')}`);
    await sleep(400);
  }
  h.close(); g.close();
  await sleep(200);
})();
