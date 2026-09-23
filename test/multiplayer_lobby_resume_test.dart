// 大厅「你还在房间 XXXXXX 里，点击返回」的回归测试。
//
// 分工说明（避免重复造轮子）：
//   * 协议那一半（initialize 带 resumePlayerId、断线后重发、resumed 时不再 joinRoom）
//     由 `test/multiplayer_resume_test.dart` 用**真实本机 WebSocket** 覆盖；
//   * 服务端那一半（120s 宽限期、座位复位、到期才踢）由
//     `server/tests/multiplayer_grace.test.js` 端到端覆盖（20 项断言）。
// 这里只测 UI：有房间要显示入口、点击进房、房间没了要收掉、没房间时不显示。
//
// 注入一个不联网的假 manager：真 manager 的 initialize() 会连 WebSocket 并留下
// 心跳 / 重连 / 超时定时器，widget test 的 fake async 收不掉它们（会报
// 「A Timer is still pending」）。
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_flutter_app/entity/Multiplayer/RoomEntity.dart';
import 'package:my_first_flutter_app/manager/MultiplayerManager.dart';
import 'package:my_first_flutter_app/page/Multiplayer/GameRoomPage.dart';
import 'package:my_first_flutter_app/page/Multiplayer/MultiplayerLobbyPage.dart';

import 'support/fake_multiplayer_server.dart';

/// 只实现大厅真正用到的那几项，其余一律 noSuchMethod。
class FakeMultiplayerManager implements MultiplayerManager {
  final StreamController<RoomEntity?> _roomController =
      StreamController<RoomEntity?>.broadcast();

  RoomEntity? _room;
  int initializeCalls = 0;
  int leaveRoomCalls = 0;

  @override
  RoomEntity? get currentRoom => _room;

  @override
  Stream<RoomEntity?> get roomStream => _roomController.stream;

  @override
  Future<void> initialize({String? nickname}) async {
    initializeCalls++;
  }

  @override
  Future<void> leaveRoom() async {
    leaveRoomCalls++;
    setRoom(null);
  }

  void setRoom(RoomEntity? room) {
    _room = room;
    _roomController.add(room);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeMultiplayerManager manager;

  setUp(() {
    manager = FakeMultiplayerManager();
  });

  tearDown(() {
    MultiplayerManager.debugServerUrlOverride = null;
  });

  Future<void> pumpLobby(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MultiplayerLobbyPage(manager: manager),
    ));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('还在房间时显示「你还在房间 XXXXXX 里」，点击进房间', (tester) async {
    await pumpLobby(tester);
    expect(find.textContaining('你还在房间'), findsNothing,
        reason: '一开始没房间，不该有入口');
    expect(manager.initializeCalls, 1,
        reason: '进页面要主动连一次（否则接不回宽限期内的座位）');

    manager.setRoom(RoomEntityForTest.waitingRoom());
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('你还在房间 638086 里'), findsOneWidget);
    expect(find.textContaining('2 人'), findsOneWidget);

    await tester.tap(find.textContaining('你还在房间 638086 里'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(GameRoomPage), findsOneWidget,
        reason: '点入口应直接回到原房间');

    // 立刻拆掉：GameRoomPage 会起定时器 / 音频 / 网络订阅，
    // 留在树上继续跑会把测试拖住
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('房间没了（宽限期过了 / 被解散）：入口要收掉', (tester) async {
    manager.setRoom(RoomEntityForTest.waitingRoom());
    await pumpLobby(tester);
    expect(find.textContaining('你还在房间 638086 里'), findsOneWidget);

    manager.setRoom(null);
    // 流事件比当前这一帧晚一步送达，所以要 pump 两次（真机上是下一帧，无感）
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('你还在房间'), findsNothing);
  });

  testWidgets('不在房间里：照常显示创建 / 加入两个入口', (tester) async {
    await pumpLobby(tester);
    expect(find.text('创建房间'), findsOneWidget);
    expect(find.text('加入房间'), findsOneWidget);
    expect(find.textContaining('你还在房间'), findsNothing);
  });

  // ---- 源码守卫：这条接线在 widget test 里不好验，只能钉住 ----
  //
  // 大厅进页面必须主动连一次（`initialize` 会带上本机身份去找回座位）；
  // 少了这一步，冷启动后服务端留着座位也没人来坐，「回到房间」永远不会出现。
  test('大厅进页面会主动连一次，并监听房间变化', () {
    final src = File('lib/page/Multiplayer/MultiplayerLobbyPage.dart')
        .readAsStringSync();
    expect(src, contains('_manager.initialize()'),
        reason: 'initState 里必须主动 initialize，否则接不回原座位');
    expect(src, contains('roomStream.listen'),
        reason: '要监听房间变化：出现时显示入口、消失时收掉');
    expect(src, contains('_manager.currentRoom'),
        reason: '入口的显示条件必须是「当前有房间」');
  });
}
