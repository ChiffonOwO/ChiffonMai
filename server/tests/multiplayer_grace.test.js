// 多人游戏「切后台退房间」修复的本地验证 harness。
//
// 为什么需要它：这次的改动是**跨端协议**（服务端宽限期 + 客户端 resumePlayerId），
// 而手边没有真机也没法随手连线上服务器。这个脚本把 server.js 拉起来（MySQL/Redis
// 用桩替掉，**不碰任何线上数据**），用两个真实 ws 客户端把整条链路跑一遍：
//
//   1. A 建房、B 加入（2 人房）
//   2. B 的 socket 被**粗暴掐断**（等价于切后台被系统掐掉）
//      → 期望：A 收到 player_offline，房间还在、B 的座位还在（connected:false），
//              且**没有** player_left
//   3. B 用新 socket 带 resumePlayerId 重连
//      → 期望：initialized.resumed=true 且 playerId 不变、收到 room_joined
//              （座位/分数/房主身份原样）、A 收到 player_online
//   4. B 再断线一次，等宽限期到期（用 MP_OFFLINE_GRACE_MS 调短）
//      → 期望：这时才收到 player_left（老的踢人逻辑仍然有效）
//
// 运行：node server/tests/multiplayer_grace.test.js
const path = require('path');
const Module = require('module');

// ---------- 把 MySQL / Redis 换成桩（必须在 require server.js 之前） ----------
const stubConnection = {
  execute: async () => [[], []],
  query: async () => [[], []],
  release: () => {},
};
const stubPool = {
  getConnection: async () => stubConnection,
  execute: async () => [[], []],
  query: async () => [[], []],
  end: async () => {},
};
const stubRedis = {
  on: () => stubRedis,
  connect: async () => stubRedis,
  isOpen: false,
  get: async () => null,
  set: async () => 'OK',
  setEx: async () => 'OK',
  del: async () => 0,
  keys: async () => [],
  quit: async () => {},
};

const origLoad = Module._load;
Module._load = function (request, parent, isMain) {
  if (request === 'mysql2/promise') return { createPool: () => stubPool };
  if (request === 'redis') return { createClient: () => stubRedis };
  return origLoad.apply(this, arguments);
};

// 宽限期调短，好在几秒内验证「到期才真踢」
process.env.MP_OFFLINE_GRACE_MS = process.env.MP_OFFLINE_GRACE_MS || '2000';

const WebSocket = require(path.join(__dirname, '..', 'node_modules', 'ws'));
const SERVER_PATH = path.join(__dirname, '..', 'server.js');

// ---------- 迷你断言 ----------
let passed = 0;
const failures = [];
function check(name, ok, extra) {
  if (ok) {
    passed++;
    console.log(`  ✓ ${name}`);
  } else {
    failures.push(name);
    console.log(`  ✗ ${name}${extra ? ' — ' + extra : ''}`);
  }
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ---------- 一个会记录所有收到消息的测试客户端 ----------
class TestClient {
  constructor(label) {
    this.label = label;
    this.ws = null;
    this.received = [];
    this.playerId = null;
  }

  async connect(port) {
    this.ws = new WebSocket(`ws://127.0.0.1:${port}`);
    await new Promise((resolve, reject) => {
      this.ws.on('open', resolve);
      this.ws.on('error', reject);
    });
    this.ws.on('message', (raw) => {
      let msg;
      try {
        msg = JSON.parse(raw.toString());
      } catch (_) {
        return;
      }
      this.received.push(msg);
    });
    return this;
  }

  send(action, payload = {}) {
    this.ws.send(JSON.stringify({ action, payload }));
  }

  /** 等到收到某个 action（或超时） */
  async waitFor(action, timeoutMs = 3000) {
    const deadline = Date.now() + timeoutMs;
    while (Date.now() < deadline) {
      const hit = this.received.find((m) => m.action === action);
      if (hit) return hit;
      await sleep(20);
    }
    return null;
  }

  /** 等一段时间，收集期间的消息 */
  async settle(ms = 400) {
    await sleep(ms);
  }

  actions() {
    return this.received.map((m) => m.action);
  }

  lastRoom() {
    for (let i = this.received.length - 1; i >= 0; i--) {
      const m = this.received[i];
      if (m.payload && m.payload.room) return m.payload.room;
    }
    return null;
  }

  /** 粗暴掐断：不做 close 握手，等价于进程被系统冻死/杀掉 */
  kill() {
    this.ws.terminate();
  }

  async close() {
    try {
      this.ws.close();
    } catch (_) {}
  }
}

async function main() {
  // 拉起服务端（会 listen 3000；桩掉的 DB/Redis 不会真连）
  require(SERVER_PATH);
  await sleep(2500); // 等 startServer() 完成并 listen

  const PORT = 3000;
  console.log('\n[1] A 建房、B 加入');
  const a = await new TestClient('A').connect(PORT);
  a.send('initialize', { nickname: 'Alice' });
  const initA = await a.waitFor('initialized');
  check('A 拿到 playerId', !!(initA && initA.payload.playerId));
  const aId = initA.payload.playerId;

  a.send('create_room', { gameType: 'info', maxPlayers: 4 });
  const created = await a.waitFor('room_created');
  check('A 建房成功', !!created);
  const roomId = created.payload.room.id;

  const b = await new TestClient('B').connect(PORT);
  b.send('initialize', { nickname: 'Bob' });
  const initB = await b.waitFor('initialized');
  const bId = initB.payload.playerId;
  check('B 拿到 playerId', !!bId && bId !== aId);

  b.send('join_room', { roomId });
  const joined = await b.waitFor('room_joined');
  check('B 加入成功', !!joined && joined.payload.room.id === roomId);
  await a.settle(300);
  check('A 看到 2 人', (a.lastRoom()?.players || []).length === 2);

  console.log('\n[2] B 的 socket 被粗暴掐断（= 切后台被系统掐掉）');
  a.received.length = 0;
  b.kill();
  const offline = await a.waitFor('player_offline');
  await a.settle(300);
  check('A 收到 player_offline（而不是 player_left）', !!offline);
  check('全程没有 player_left', !a.actions().includes('player_left'),
      'actions=' + a.actions().join(','));
  const roomAfterKill = a.lastRoom();
  check('房间还在且仍是 2 人（座位保留）',
      !!roomAfterKill && roomAfterKill.players.length === 2);
  const bSeat = roomAfterKill?.players.find((p) => p.id === bId);
  check('B 的座位标记为掉线 connected:false',
      !!bSeat && bSeat.connected === false);
  check('房主身份没被转移', roomAfterKill?.hostId === aId);

  console.log('\n[3] B 用新 socket 带 resumePlayerId 重连');
  const b2 = await new TestClient('B2').connect(PORT);
  b2.send('initialize', { nickname: 'Bob', resumePlayerId: bId });
  const initB2 = await b2.waitFor('initialized');
  check('服务端确认复位 resumed:true', initB2?.payload?.resumed === true,
      JSON.stringify(initB2?.payload));
  check('playerId 与原来一致（不是新身份）', initB2?.payload?.playerId === bId);
  const rejoined = await b2.waitFor('room_joined');
  check('补发了 room_joined（房间状态回来了）', !!rejoined);
  const bSeat2 = rejoined?.payload?.room?.players?.find((p) => p.id === bId);
  check('B 仍在房间里、已恢复在线', !!bSeat2 && bSeat2.connected !== false);
  check('补发了 game_state_updated（对局状态）',
      !!(await b2.waitFor('game_state_updated')));
  const online = await a.waitFor('player_online');
  check('A 收到 player_online', !!online);

  console.log('\n[4] 宽限期到期才真正踢人（老逻辑仍然有效）');
  a.received.length = 0;
  b2.kill();
  await a.waitFor('player_offline');
  const left = await a.waitFor('player_left', 6000);
  check('宽限期到期后收到 player_left', !!left);
  await a.settle(300);
  const roomAfterExpire = a.lastRoom();
  check('房间只剩 A 一人', (roomAfterExpire?.players || []).length === 1,
      JSON.stringify(roomAfterExpire?.players?.map((p) => p.nickname)));

  console.log('\n[5] 宽限期内主动退房：立刻释放座位，不能被 resume 顶回来');
  b2.ws = null;
  const c = await new TestClient('C').connect(PORT);
  c.send('initialize', { nickname: 'Carol' });
  const initC = await c.waitFor('initialized');
  const cId = initC.payload.playerId;
  c.send('join_room', { roomId });
  await c.waitFor('room_joined');
  c.send('leave_room');
  const leftC = await c.waitFor('left_room');
  check('C 收到 left_room', !!leftC);
  const c2 = await new TestClient('C2').connect(PORT);
  c2.send('initialize', { nickname: 'Carol', resumePlayerId: cId });
  const initC2 = await c2.waitFor('initialized');
  check('主动退房后不会被复位（resumed 不为 true）',
      initC2?.payload?.resumed !== true, JSON.stringify(initC2?.payload));

  await a.close();
  await c.close();
  await c2.close();

  console.log(`\n通过 ${passed} 项${failures.length ? '，失败 ' + failures.length + ' 项：' + failures.join(' / ') : '，全部通过 ✅'}`);
  process.exit(failures.length ? 1 : 0);
}

main().catch((err) => {
  console.error('harness 异常:', err);
  process.exit(1);
});
