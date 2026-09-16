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
    c.tryWait = (act, ms = 2500) => c.wait(act, ms).catch(() => null);
    c.reset = () => { c.cur = c.seen.length; };
    c.close = () => { try { ws.close(); } catch (_) {} };
    return c;
  });
}
(async () => {
  console.log('=== A. letters：两个玩家猜同一首，是否都得分？===');
  {
    const h = await mk('h');
    h.send('initialize', { nickname: '房主' }); await h.wait('initialized');
    h.send('create_room', { gameType: 'letters', maxPlayers: 2, timeLimit: 60, maxGuesses: 40, totalRounds: 2,
      selectedVersions: [], masterMinDx: 1.0, masterMaxDx: 15.0, selectedGenres: [], blurLevel: 50, playDuration: 5, songCount: 3, nonEnglishCharThreshold: 0 });
    const cr = await h.wait('room_created'); const r = cr.payload.room;
    const g = await mk('g');
    g.send('initialize', { nickname: '玩家1' }); await g.wait('initialized');
    g.send('join_room', { roomId: r.id, nickname: '玩家1' }); await g.wait('room_joined');
    h.send('update_ready', { ready: true }); g.send('update_ready', { ready: true });
    await sleep(300); h.reset(); h.send('start_game', {});
    const rs = await h.wait('round_start', 9000);
    const t0 = rs.payload.gameState.targetSongs[0];

    h.reset(); h.send('submit_guess', { songId: String(t0.id), songName: t0.title });
    const g1 = await h.wait('guess_received', 6000);
    console.log(`  房主猜中「${t0.title}」→ score=${g1.payload.guess.score}`);

    g.reset(); g.send('submit_guess', { songId: String(t0.id), songName: t0.title });
    const g2 = await g.tryWait('guess_received', 6000);
    console.log(`  玩家1 随后猜中【同一首】→ score=${g2 ? g2.payload.guess.score : '(被拒)'}`);

    // 猜完剩下的，让回合结束
    for (let i = 1; i < rs.payload.gameState.targetSongs.length; i++) {
      const t = rs.payload.gameState.targetSongs[i];
      h.reset(); h.send('submit_guess', { songId: String(t.id), songName: t.title });
      await h.wait('guess_received', 6000);
    }
    const ro = await h.wait('round_over', 9000);
    ro.payload.gameState.players.forEach(p => console.log(`  回合结束 → ${p.nickname}: ${p.score} 分`));
    h.close(); g.close(); await sleep(200);
  }

  console.log('\n=== B. 猜测次数是「全房间共享」还是「每人独立」？===');
  {
    const h = await mk('h');
    h.send('initialize', { nickname: '房主' }); await h.wait('initialized');
    h.send('create_room', { gameType: 'info', maxPlayers: 2, timeLimit: 60, maxGuesses: 4, totalRounds: 2,
      selectedVersions: [], masterMinDx: 1.0, masterMaxDx: 15.0, selectedGenres: [], blurLevel: 50, playDuration: 5, songCount: 3, nonEnglishCharThreshold: 0 });
    const cr = await h.wait('room_created'); const r = cr.payload.room;
    const g = await mk('g');
    g.send('initialize', { nickname: '玩家1' }); await g.wait('initialized');
    g.send('join_room', { roomId: r.id, nickname: '玩家1' }); await g.wait('room_joined');
    h.send('update_ready', { ready: true }); g.send('update_ready', { ready: true });
    await sleep(300); h.reset(); h.send('start_game', {});
    await h.wait('round_start', 9000);
    console.log('  房间 maxGuesses=4，房主连猜 3 次错，玩家1 再猜 2 次错...');
    for (let i = 1; i <= 3; i++) {
      h.reset(); h.send('submit_guess', { songId: '90000' + i, songName: '__错' + i + '__' });
      const gr = await h.tryWait('guess_received', 4000);
      const st = await h.tryWait('game_state_updated', 1200);
      console.log(`    房主第 ${i} 次错猜: 收到=${!!gr} 房间已猜次数=${st ? st.payload.gameState.currentGuesses + '/' + st.payload.gameState.maxGuesses : '?'}`);
    }
    for (let i = 1; i <= 2; i++) {
      g.reset(); g.send('submit_guess', { songId: '80000' + i, songName: '__错b' + i + '__' });
      const gr = await g.tryWait('guess_received', 4000);
      const err = await g.tryWait('error', 1200);
      const st = await g.tryWait('game_state_updated', 1200);
      console.log(`    玩家1 第 ${i} 次错猜: 收到=${!!gr} 错误=${err ? err.payload.message : '-'} 房间已猜次数=${st ? st.payload.gameState.currentGuesses : '?'}`);
    }
    h.close(); g.close(); await sleep(200);
  }
  process.exit(0);
})().catch(e => { console.error('异常:', e.message); process.exit(1); });