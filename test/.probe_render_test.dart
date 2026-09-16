// ===========================================================================
// GameRoomPage 离屏渲染探针
//
// 目的：本项目开发环境无法真机验证（设备锁屏 / 无 VS 工具链），但判断
// 「房间内页面好不好看」必须真的看到页面。这里用 tester.runAsync 打通真实
// WebSocket（已实测：testWidgets 的 fake async 会卡死真实 socket，runAsync 不会），
// 让真实页面连本地测试服打一局，再截图。
//
// 用法：先起测试服 node tool/mp-test/mp_harness.js，然后
//   flutter test test/.probe_render_test.dart --update-goldens
// ===========================================================================
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:my_first_flutter_app/entity/Multiplayer/GameType.dart';
import 'package:my_first_flutter_app/entity/Multiplayer/RoomEntity.dart';
import 'package:my_first_flutter_app/entity/Multiplayer/PlayerEntity.dart';
import 'package:my_first_flutter_app/page/Multiplayer/GameRoomPage.dart';

const String kTestServer = 'ws://127.0.0.1:3999';

/// 极简 WS 客户端：只做「发动作 / 等某个 action」两件事
class ProbeClient {
  final String name;
  final WebSocket _ws;
  final List<Map<String, dynamic>> _seen = [];
  int _cur = 0;

  ProbeClient._(this.name, this._ws);

  static Future<ProbeClient> connect(String name) async {
    final ws = await WebSocket.connect(kTestServer).timeout(const Duration(seconds: 10));
    final c = ProbeClient._(name, ws);
    ws.listen((msg) {
      try {
        c._seen.add(json.decode(msg.toString()) as Map<String, dynamic>);
      } catch (_) {}
    }, onError: (_) {}, onDone: () {});
    return c;
  }

  void send(String action, [Map<String, dynamic> payload = const {}]) {
    _ws.add(json.encode({'action': action, 'payload': payload}));
  }

  Future<Map<String, dynamic>> wait(String action, {Duration timeout = const Duration(seconds: 10)}) async {
    final t0 = DateTime.now();
    while (DateTime.now().difference(t0) < timeout) {
      while (_cur < _seen.length) {
        final m = _seen[_cur++];
        if (m['action'] == action) return m;
      }
      await Future.delayed(const Duration(milliseconds: 25));
    }
    throw StateError('$name 等待 $action 超时');
  }

  void reset() => _cur = _seen.length;

  Future<void> close() async {
    try { await _ws.close(); } catch (_) {}
  }
}

/// 加载中文字体，否则测试环境把中文渲染成方块（□），没法判断美观
Future<void> loadChineseFonts() async {
  const candidates = [
    r'C:\Windows\Fonts\msyh.ttc',
    r'C:\Windows\Fonts\simhei.ttf',
    r'C:\Windows\Fonts\Deng.ttf',
  ];
  for (final path in candidates) {
    final f = File(path);
    if (!f.existsSync()) continue;
    try {
      final bytes = await f.readAsBytes();
      final loader = FontLoader('Roboto');
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
      print('[RENDER] 已加载中文字体: $path');
      return;
    } catch (e) {
      print('[RENDER] 字体加载失败 $path: $e');
    }
  }
  print('[RENDER] 警告：未找到中文字体，中文会渲染成方块');
}

void main() {
  testWidgets('渲染 GameRoomPage：真实对局 + 浅色/暗色', (tester) async {
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({'userNickname': 'Chiffon'});
    await loadChineseFonts();

    tester.view.physicalSize = const Size(1080, 2372);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    // 绑定真实的时间/IO：runAsync 里才能连上本地测试服
    late RoomEntity joinedRoom;

    await tester.runAsync(() async {
      final host = await ProbeClient.connect('host');
      host.send('initialize', {'nickname': '房主'});
      await host.wait('initialized');

      host.send('create_room', {
        'gameType': 'letters',
        'maxPlayers': 2,
        'timeLimit': 60,
        'maxGuesses': 20,
        'totalRounds': 3,
        'selectedVersions': <String>[],
        'masterMinDx': 1.0,
        'masterMaxDx': 15.0,
        'selectedGenres': <String>[],
        'blurLevel': 50,
        'playDuration': 5,
        'songCount': 3,
        'nonEnglishCharThreshold': 0,
      });
      final created = await host.wait('room_created');
      final roomJson = Map<String, dynamic>.from(created['payload']['room'] as Map);
      print('[RENDER] 房间已创建: ${roomJson['code']}');

      final guest = await ProbeClient.connect('guest');
      guest.send('initialize', {'nickname': '玩家甲'});
      await guest.wait('initialized');
      guest.send('join_room', {'roomId': roomJson['id'], 'nickname': '玩家甲'});
      final joined = await guest.wait('room_joined');

      // 用「服务端真实下发的房间报文」构造页面入参，保证字段口径一致
      joinedRoom = RoomEntity.fromJson(
          Map<String, dynamic>.from(joined['payload']['room'] as Map));

      // 两个人都准备 + 房主开局
      host.send('update_ready', {'ready': true});
      guest.send('update_ready', {'ready': true});
      await Future.delayed(const Duration(milliseconds: 400));
      host.reset();
      host.send('start_game');
      final rs = await host.wait('round_start');
      final gs = Map<String, dynamic>.from(rs['payload']['gameState'] as Map);
      print('[RENDER] 开局成功，目标曲数=${(gs['targetSongs'] as List).length}');

      // 开一个字母，让 letters 面板出现「已开: x」
      final targets = gs['targetSongs'] as List;
      final firstTitle = (targets.first as Map)['title'].toString();
      final letter = RegExp(r'[A-Za-z]').firstMatch(firstTitle)?.group(0) ?? 'a';
      guest.send('open_letter', {'letter': letter});
      await guest.wait('letter_opened');
      print('[RENDER] 已开字母: $letter');

      // 房主猜错一次，让猜测历史里同时有「错」的记录（更接近真实观感）
      host.send('submit_guess', {'songId': '0', 'songName': '不存在的曲子'});
      await host.wait('guess_received');

      await Future.delayed(const Duration(milliseconds: 600));
      addTearDown(() async {
        await host.close();
        await guest.close();
      });
    });

    print('[RENDER] 即将渲染 GameRoomPage，房间码=${joinedRoom.roomCode}');

    Future<void> shoot(String themeName, ThemeData theme) async {
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: GameRoomPage(room: joinedRoom),
      ));
      // 页面 initState 里有异步初始化 + 每秒倒计时，多 pump 几轮把状态走稳
      for (int i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('shots/room_$themeName.png'),
      );
      print('[RENDER] 已出图: shots/room_$themeName.png');
    }

    await shoot('light', AppTheme.lightTheme());
    await shoot('dark', AppTheme.darkTheme());

    // 收尾：把页面摘掉，触发 dispose 取消定时器与连接
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });
}