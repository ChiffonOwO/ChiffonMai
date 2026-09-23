// 测试用的本机多人游戏服务端（真实 WebSocket，dart:io）。
//
// 用于验证客户端的协议行为：initialize 是否带 resumePlayerId、断线后是否
// 重放 initialize、服务端回 resumed:true 时客户端会不会乱 joinRoom，
// 以及大厅「你还在房间 XXXXXX 里」的入口。
//
// 服务端那一半（宽限期 / 座位复位）在 `server/tests/multiplayer_grace.test.js`。
import 'dart:convert';
import 'dart:io';

import 'package:my_first_flutter_app/entity/Multiplayer/RoomEntity.dart';

class FakeMultiplayerServer {
  FakeMultiplayerServer._(this._server);

  final HttpServer _server;
  final List<Map<String, dynamic>> received = [];
  final List<WebSocket> sockets = [];

  /// `initialized` 里是否回 `resumed: true`（表示服务端把我们接回了原座位）。
  bool resumed = false;

  /// 复位后是否补发 `room_joined`（真服务端会补发）。
  bool sendRoomJoinedOnResume = false;

  /// 补发的房间（与 server.js 的 `room.getState()` 同结构）。
  Map<String, dynamic>? roomJson;

  String playerId = 'player-1';

  static Future<FakeMultiplayerServer> start() async {
    final httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = FakeMultiplayerServer._(httpServer);
    httpServer.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      fake.sockets.add(socket);
      socket.listen((data) {
        final msg = json.decode(data as String) as Map<String, dynamic>;
        fake.received.add(msg);
        final payload = msg['payload'];
        switch (msg['action']) {
          case 'initialize':
            socket.add(json.encode({
              'action': 'initialized',
              'payload': {
                'playerId': fake.playerId,
                'nickname': payload is Map ? payload['nickname'] : null,
                if (fake.resumed) 'resumed': true,
              },
            }));
            if (fake.resumed && fake.sendRoomJoinedOnResume) {
              socket.add(json.encode({
                'action': 'room_joined',
                'payload': {
                  'room': fake.roomJson,
                  'player': {
                    'id': fake.playerId,
                    'nickname': '小明',
                    'ready': false,
                    'score': 0,
                    'surrendered': false,
                  },
                },
              }));
            }
            break;
          default:
            break;
        }
      }, onDone: () {}, onError: (_) {});
    });
    return fake;
  }

  int get port => _server.port;

  String get url => 'ws://127.0.0.1:$port';

  /// 掐断所有连接（模拟「切后台被系统掐掉」）。
  Future<void> dropAllSockets() async {
    for (final s in List<WebSocket>.from(sockets)) {
      try {
        await s.close().timeout(const Duration(milliseconds: 500));
      } catch (_) {
        // 对端已经没了 / 关闭握手迟迟不结束：直接放弃，别把测试拖住
      }
    }
    sockets.clear();
  }

  List<Map<String, dynamic>> ofAction(String action) =>
      received.where((m) => m['action'] == action).toList();

  Future<void> stop() async {
    await dropAllSockets();
    await _server.close(force: true);
  }
}

/// 测试用的房间实体（解析自 [fakeRoomJson]，字段与 server.js 对齐）。
class RoomEntityForTest {
  RoomEntityForTest._();

  /// 一个「等待中」的房间：房主是自己，共 2 人。
  static RoomEntity waitingRoom({String code = '638086'}) =>
      RoomEntity.fromJson(fakeRoomJson(code: code));
}

Map<String, dynamic> fakeRoomJson({
  String id = 'room-uuid-1',
  String code = '638086',
  String gameType = 'info',
  int playerCount = 2,
}) =>
    {
      'id': id,
      'code': code,
      'gameType': gameType,
      'maxPlayers': 4,
      'timeLimit': 60,
      'maxGuesses': 10,
      'totalRounds': 5,
      'players': [
        for (var i = 0; i < playerCount; i++)
          {
            'id': i == 0 ? 'player-1' : 'player-$i',
            'nickname': i == 0 ? '小明' : '路人$i',
            'ready': false,
            'score': 0,
            'surrendered': false,
            'host': i == 0,
            'connected': true,
            'currentGuesses': 0,
          },
      ],
      'hostId': 'player-1',
      'status': 'waiting',
      'currentRound': 0,
      'createdAt': 1789743343018,
      'lastActivityAt': 1789743343018,
      'selectedVersions': <String>[],
      'masterMinDx': 1.0,
      'masterMaxDx': 15.0,
      'selectedGenres': <String>[],
      'blurLevel': 50,
      'playDuration': 5,
      'songCount': 3,
      'nonEnglishCharThreshold': 50,
      'flashDurationMs': 300,
      'tileCount': 1000,
      'tileRevealIntervalMs': 1500,
      'peekDurationSeconds': 8,
      'peekDifficulties': ['4'],
    };
