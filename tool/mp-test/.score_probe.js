// 实测各模式得分机制
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
async function room(mode, opts) {
  const h = await mk('h');
  h.send('initialize', { nickname: '房主' }); await h.wait('initialized');
  h.send('create_room', Object.assign({ gameType: mode, maxPlayers: 2, timeLimit: 60, maxGuesses: 40, totalRounds: 5,
    selectedVersions: [], masterMinDx: 1.0, masterMaxDx: 15.0, selectedGenres: [], blurLevel: 50, playDuration: 5, songCount: 3, nonEnglishCharThreshold: 0 }, opts || {}));
  const cr = await h.wait('room_created'); const r = cr.payload.room;
  const g = await mk('g');
  g.send('initialize', { nickname: '玩家1' }); await g.wait('initialized');
  g.send('join_room', { roomId: r.id, nickname: '玩家1' }); await g.wait('room_joined');
  h.send('update_ready', { ready: true }); g.send('update_ready', { ready: true });
  await sleep(300); h.reset(); h.send('start_game', {});
  const rs = await h.wait('round_start', 9000);
  return { h, g, rs };
}
(async () => {
  console.log('=== 1. 单题模式：得分 vs 作答耗时 ===');
  console.log('（同一房间连续多回合，每回合等不同时长再答）');
  {
    const { h, g, rs } = await room('info', { totalRounds: 5 });
    let cur = rs;
    for (const waitSec of [0, 2, 5, 10, 20]) {
      if (waitSec > 0) { h.reset(); h.send('start_next_round', {}); cur = await h.wait('round_start', 9000); }
      const t = cur.payload.gameState.currentSong;
      if (waitSec > 0) await sleep(waitSec * 1000);
      h.reset(); h.send('submit_guess', { songId: String(t.id), songName: t.title });
      const gr = await h.wait('guess_received', 6000);
      const ro = await h.tryWait('round_over', 6000) || await h.tryWait('game_over', 6000);
      const me = ro ? ro.payload.gameState.players.find(p => p.nickname === '房主') : null;
      console.log(`  等待 ${String(waitSec).padStart(2)} 秒 → guess.score=${String(gr.payload.guess.score).padStart(3)}  timeSpent=${gr.payload.guess.timeSpent.toFixed(2)}  累计分=${me ? me.score : '?'}`);
    }
    h.close(); g.close(); await sleep(200);
  }

  console.log('\n=== 2. letters：3 首，逐首猜中各自的得分 ===');
  {
    const { h, g, rs } = await room('letters', { totalRounds: 2, songCount: 3 });
    const targets = rs.payload.gameState.targetSongs;
    let acc = 0;
    for (let i = 0; i < targets.length; i++) {
      await sleep(1500); // 每首之间隔 1.5 秒，制造耗时差异
      h.reset(); h.send('submit_guess', { songId: String(targets[i].id), songName: targets[i].title });
      const gr = await h.wait('guess_received', 6000);
      console.log(`  第 ${i + 1} 首「${targets[i].title}」→ score=${String(gr.payload.guess.score).padStart(3)} timeSpent=${gr.payload.guess.timeSpent.toFixed(2)}`);
      acc += gr.payload.guess.score;
    }
    const ro = await h.wait('round_over', 9000);
    const me = ro.payload.gameState.players.find(p => p.nickname === '房主');
    console.log(`  三首 score 相加 = ${acc}，服务端结算后总分 = ${me.score}`);
    h.close(); g.close(); await sleep(200);
  }

  console.log('\n=== 3. letters：猜错一首会不会扣分？===');
  {
    const { h, g, rs } = await room('letters', { totalRounds: 2, songCount: 3 });
    const targets = rs.payload.gameState.targetSongs;
    h.reset(); h.send('submit_guess', { songId: '999999', songName: '___绝对猜不中___' });
    const wrong = await h.wait('guess_received', 6000);
    console.log(`  猜错一条 → correct=${wrong.payload.guess.correct} score=${wrong.payload.guess.score}`);
    h.reset(); h.send('submit_guess', { songId: String(targets[0].id), songName: targets[0].title });
    const right = await h.wait('guess_received', 6000);
    console.log(`  再猜对第一首 → score=${right.payload.guess.score}（看猜错是否拖累了它）`);
    const st = await h.tryWait('game_state_updated', 3000);
    console.log(`  当前猜错+猜对后，本回合猜测次数 = ${st ? st.payload.gameState.currentGuesses : '?'}`);
    h.close(); g.close(); await sleep(200);
  }

  console.log('\n=== 4. 超时未猜中：本回合分数 ===');
  {
    const { h, g, rs } = await room('info', { totalRounds: 3, timeLimit: 5 });
    const t = rs.payload.gameState.currentSong;
    console.log(`  题目「${t.title}」，等 7 秒让回合超时...`);
    const ro = await h.tryWait('round_over', 12000) || await h.tryWait('game_over', 12000);
    const me = ro ? ro.payload.gameState.players.find(p => p.nickname === '房主') : null;
    console.log(`  超时结束后房主分 = ${me ? me.score : '(未拿到)'} （预期 0）`);
    h.close(); g.close(); await sleep(200);
  }

  console.log('\n=== 5. 投降后猜中还能不能得分？===');
  {
    const { h, g, rs } = await room('info', { totalRounds: 2 });
    const t = rs.payload.gameState.currentSong;
    h.send('update_player_surrendered', { surrendered: true });
    await sleep(400);
    h.reset(); h.send('submit_guess', { songId: String(t.id), songName: t.title });
    const gr = await h.tryWait('guess_received', 5000);
    const err = await h.tryWait('error', 1000);
    const ro = await h.tryWait('round_over', 6000);
    const me = ro ? ro.payload.gameState.players.find(p => p.nickname === '房主') : null;
    console.log(`  投降后提交 → guess_received=${!!gr} error=${err ? err.payload.message : '-'}`);
    console.log(`  回合结束后房主分 = ${me ? me.score : '(未拿到)'} （预期 0，投降者不计分）`);
    h.close(); g.close(); await sleep(200);
  }

  process.exit(0);
})().catch(e => { console.error('异常:', e.message); process.exit(1); });