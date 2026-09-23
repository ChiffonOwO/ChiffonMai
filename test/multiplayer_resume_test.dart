// 多人游戏「断线复位」的客户端协议测试。
//
// 配套的服务端改动见 server/server.js 的 PLAYER_OFFLINE_GRACE_MS /
// resumePlayerConnection，端到端验证跑 `node server/tests/multiplayer_grace.test.js`。
// 这里只钉客户端这一半：
//   1. `initialize` 要带上 resumePlayerId（服务端才认得出我们）；
//   2. 断线自动重连后**必须重放 initialize**，否则服务端只看到陌生连接，
//      原座位还锁在断线宽限期里没人坐；
//   3. 服务端回了 `resumed: true` 时不要再 joinRoom（会被拒「您已在房间中」）。
//
// 用真实的本机 WebSocket 服务端（dart:io，见 test/support），不用桩。
// 注意：这些是**普通 test**（不是 testWidgets）—— fake async 会困住 socket 回调。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_flutter_app/service/GuessChartGame/MultiplayerCloudBaseService.dart';
import 'package:my_first_flutter_app/service/Multiplayer/WebSocketBroadcastService.dart';

import 'support/fake_multiplayer_server.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  HttpOverrides? savedOverrides;

  setUp(() {
    // flutter_test 默认把 HttpClient 换成桩，真连本机 socket 要先摘掉
    savedOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
  });

  tearDown(() {
    HttpOverrides.global = savedOverrides;
  });

  test('initialize 带上 resumePlayerId（服务端据此复位座位）', () async {
    final server = await FakeMultiplayerServer.start();
    final ws = WebSocketBroadcastService();
    addTearDown(() async {
      ws.disconnect();
      await server.stop();
    });

    await ws.initialize(host: server.url);
    await ws.sendInitialize('小明', resumePlayerId: 'old-player-id');
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final inits = server.ofAction('initialize');
    expect(inits, isNotEmpty, reason: '应当发出 initialize');
    expect(inits.last['payload']['nickname'], '小明');
    expect(inits.last['payload']['resumePlayerId'], 'old-player-id');
  });

  test('断线重连后自动重放 initialize（且仍带 resumePlayerId）', () async {
    final server = await FakeMultiplayerServer.start();
    final ws = WebSocketBroadcastService();
    addTearDown(() async {
      ws.disconnect();
      await server.stop();
    });

    await ws.initialize(host: server.url);
    await ws.sendInitialize('小明', resumePlayerId: 'old-player-id');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(server.ofAction('initialize').length, 1);

    // 掐断 → 客户端应重连（退避 2^0=1~2 秒）并重放 initialize
    await server.dropAllSockets();
    final deadline = DateTime.now().add(const Duration(seconds: 12));
    while (DateTime.now().isBefore(deadline) &&
        server.ofAction('initialize').length < 2) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }

    final inits = server.ofAction('initialize');
    expect(inits.length, greaterThanOrEqualTo(2),
        reason: '重连后必须重放 initialize，否则座位复位不了');
    expect(inits.last['payload']['resumePlayerId'], 'old-player-id',
        reason: '重放时也要带原身份');
    expect(ws.isConnected, isTrue);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('服务端回了 resumed:true 时不再 joinRoom', () async {
    final server = await FakeMultiplayerServer.start();
    server.resumed = true;
    final service = MultiplayerCloudBaseService();
    addTearDown(() async {
      WebSocketBroadcastService().disconnect();
      await server.stop();
    });

    await service.initialize(envId: server.url, nickname: '小明');
    // 伪造「我在房间里」：否则 restoreStateAfterReconnect 会提前返回，测不到分支
    service.currentRoomId = 'room-1';

    await service.restoreStateAfterReconnect();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(server.ofAction('join_room'), isEmpty,
        reason: '服务端已经把我们接回原座位，再 joinRoom 会被拒「您已在房间中」');
  }, timeout: const Timeout(Duration(seconds: 30)));
}
