// 抓取服务端真实报文，供 Dart 侧解析测试使用
const WebSocket = require('./mp_ws');
const fs = require('fs');
const URL = process.argv[2] || 'ws://127.0.0.1:3999';

function mk(name) {
  return new Promise((res, rej) => {
    const ws = new WebSocket(URL);
    const c = { name, ws, seen: [], cur: 0 };
    ws.on('open', () => res(c));
    ws.on('message', d => c.seen.push(JSON.parse(d)));
    ws.on('error', rej);
    c.send = (a, p = {}) => ws.send(JSON.stringify({ action: a, payload: p }));
    c.wait = (act, ms = 12000) => { const t0 = Date.now(); return new Promise((ok, no) => { const t = setInterval(() => {
      for (; c.cur < c.seen.length; c.cur++) { if (c.seen[c.cur].action === act) { clearInterval(t); const m = c.seen[c.cur]; c.cur++; return ok(m); } }
      if (Date.now() - t0 > ms) { clearInterval(t); no(new Error(name + ' wait ' + act + ' timeout')); } }, 20); }); };
    return c;
  });
}
const sleep = ms => new Promise(r => setTimeout(r, ms));

(async () => {
  const out = {};

  for (const mode of ['info', 'cover', 'blurred', 'audio', 'alia', 'letters', 'flash', 'tileReveal', 'chartPeek']) {
    const h = await mk('h');
    h.send('initialize', { nickname: '报文采集' }); await h.wait('initialized');
    h.send('create_room', {
      gameType: mode, maxPlayers: 4, timeLimit: 40, maxGuesses: 10, totalRounds: 2,
      selectedVersions: [], masterMinDx: 1.0, masterMaxDx: 15.0, selectedGenres: [],
      blurLevel: 60, playDuration: 8, songCount: 3, nonEnglishCharThreshold: 50,
      flashDurationMs: 800, tileCount: 1600, tileRevealIntervalMs: 900,
      peekDurationSeconds: 12, peekDifficulties: ['3', '4'],
    });
    const cr = await h.wait('room_created');
    const r = cr.payload.room;

    const g = await mk('g');
    g.send('initialize', { nickname: '采集2' }); await g.wait('initialized');
    g.send('join_room', { roomId: r.id, nickname: '采集2' });
    const rj = await g.wait('room_joined');

    h.send('update_ready', { ready: true }); g.send('update_ready', { ready: true });
    await sleep(400);
    h.send('start_game', {});

    const rs = await h.wait('round_start', 12000);
    out[mode] = {
      room_created: cr.payload,
      room_joined: rj.payload,
      round_start: rs.payload,
    };

    if (mode === 'letters') {
      const targets = rs.payload.gameState.targetSongs;
      h.send('open_letter', { letter: targets[0].title[0] });
      out.letters_letter_opened = await h.wait('letter_opened', 8000);
      out.letters_after_open = await h.wait('game_state_updated', 8000);
      // 猜中一首
      h.send('submit_guess', { songId: String(targets[0].id), songName: targets[0].title });
      out.letters_guess = await h.wait('guess_received', 8000);
      out.letters_after_guess = await h.wait('game_state_updated', 8000);
    } else {
      const t = rs.payload.gameState.currentSong;
      h.send('submit_guess', { songId: '__wrong__', songName: '___不存在___' });
      out[mode + '_wrong_guess'] = await h.wait('guess_received', 8000);
      h.send('submit_guess', { songId: String(t.id), songName: t.title });
      out[mode + '_right_guess'] = await h.wait('guess_received', 8000);
      out[mode + '_round_over'] = await h.wait('round_over', 8000);
    }

    h.send('leave_room', {}); g.send('leave_room', {});
    await sleep(300);
    h.ws.close(); g.ws.close();
    await sleep(200);
  }

  fs.writeFileSync('test/fixtures/mp_payloads.json', JSON.stringify(out, null, 2), 'utf8');
  console.log('已写入 test/fixtures/mp_payloads.json');
  console.log('顶层键:', Object.keys(out).join(', '));
  process.exit(0);
})().catch(e => { console.error('采集失败:', e.message); process.exit(1); });
