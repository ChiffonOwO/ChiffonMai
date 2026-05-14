// lib/service/GuessChartGame/MultiplayerGameService.dart
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/io.dart';
import 'package:my_first_flutter_app/api/ApiUrls.dart';
import 'package:my_first_flutter_app/entity/Multiplayer/RoomEntity.dart';
import 'package:my_first_flutter_app/entity/Multiplayer/PlayerEntity.dart';
import 'package:my_first_flutter_app/entity/Multiplayer/GameStateEntity.dart';
import 'package:my_first_flutter_app/entity/Multiplayer/GuessRecord.dart';
import 'package:my_first_flutter_app/entity/GameType.dart';

enum MultiplayerEventType {
  connected,
  disconnected,
  connectionError,
  roomCreated,
  roomJoined,
  joinFailed,
  playerJoined,
  playerLeft,
  playerReady,
  playerSurrender,
  gameStart,
  roundStart,
  guessResult,
  guessUpdate,
  roundEnd,
  roundOver,
  gameEnd,
  gameOver,
  gameStateUpdated,
  hostChanged,
  error,
  initialized,
  roomUpdated,
  leftRoom,
  readyUpdated,
}

/// 多人游戏WebSocket服务
class MultiplayerGameService {
  static const String _defaultUrl = ApiUrls.MultiplayerGameServerUrl;
  
  IOWebSocketChannel? _channel;
  StreamSubscription? _subscription;
  
  /// 连接状态
  bool get isConnected => _channel != null && _channel!.closeCode == null;
  
  /// 事件回调
  final StreamController<MultiplayerEvent> _eventController = StreamController.broadcast();
  Stream<MultiplayerEvent> get events => _eventController.stream;
  
  /// 当前玩家ID
  String? currentPlayerId;
  
  /// 当前玩家昵称
  String? currentNickname;

  /// 连接到服务器
  Future<void> connect({String url = _defaultUrl}) async {
    try {
      _channel = IOWebSocketChannel.connect(url);
      
      _subscription = _channel!.stream.listen(
        (message) => _handleMessage(message),
        onError: (error) => _eventController.add(MultiplayerEvent.connectionError(error: error)),
        onDone: () => _eventController.add(MultiplayerEvent.disconnected()),
      );
      
      _eventController.add(MultiplayerEvent.connected());
    } catch (e) {
      _eventController.add(MultiplayerEvent.connectionError(error: e));
    }
  }

  /// 断开连接
  void disconnect() {
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  /// 创建房间
  void createRoom({
    required GameType gameType,
    int maxPlayers = 4,
    int timeLimit = 60,
    int maxGuesses = 10,
    int totalRounds = 5,
    List<String> selectedVersions = const [],
    double masterMinDx = 1.0,
    double masterMaxDx = 15.0,
    List<String> selectedGenres = const [],
  }) {
    _sendMessage({
      'action': 'create_room',
      'payload': {
        'gameType': gameType.name,
        'maxPlayers': maxPlayers,
        'timeLimit': timeLimit,
        'maxGuesses': maxGuesses,
        'totalRounds': totalRounds,
        'selectedVersions': selectedVersions,
        'masterMinDx': masterMinDx,
        'masterMaxDx': masterMaxDx,
        'selectedGenres': selectedGenres,
      },
    });
  }

  /// 加入房间
  void joinRoom(String roomId) {
    _sendMessage({
      'action': 'join_room',
      'payload': {'roomId': roomId},
    });
  }

  /// 离开房间
  void leaveRoom() {
    _sendMessage({'action': 'leave_room'});
  }

  /// 准备/取消准备
  void setReady(bool ready) {
    _sendMessage({'action': 'update_ready', 'payload': {'ready': ready}});
  }

  /// 开始游戏
  void startGame() {
    _sendMessage({'action': 'start_game'});
  }

  /// 提交猜测
  void submitGuess(String songId, String songName) {
    _sendMessage({
      'action': 'submit_guess',
      'payload': {'songId': songId, 'songName': songName},
    });
  }

  /// 发送消息
  void _sendMessage(Map<String, dynamic> message) {
    if (isConnected) {
      _channel!.sink.add(jsonEncode(message));
    }
  }

  /// 初始化连接
  void initialize({String? nickname}) {
    _sendMessage({
      'action': 'initialize',
      'payload': {'nickname': nickname},
    });
  }

  /// 处理消息
  void _handleMessage(dynamic message) {
    try {
      Map<String, dynamic> data = jsonDecode(message);
      String action = data['action'] ?? '';
      Map<String, dynamic>? payload = data['payload'] != null ? Map<String, dynamic>.from(data['payload']) : null;
      
      switch (action) {
        case 'initialized':
          currentPlayerId = payload?['playerId'];
          currentNickname = payload?['nickname'];
          _eventController.add(MultiplayerEvent.initialized());
          break;
        case 'room_created':
          _eventController.add(MultiplayerEvent.roomCreated(
            room: RoomEntity.fromJson(payload?['room'] ?? {}),
          ));
          break;
        case 'room_joined':
          _eventController.add(MultiplayerEvent.roomJoined(
            room: RoomEntity.fromJson(payload?['room'] ?? {}),
            player: PlayerEntity.fromJson(payload?['player'] ?? {}),
          ));
          break;
        case 'join_failed':
          _eventController.add(MultiplayerEvent.joinFailed(
            reason: payload?['reason'] ?? '',
          ));
          break;
        case 'player_joined':
          _eventController.add(MultiplayerEvent.playerJoined(
            player: PlayerEntity.fromJson(payload?['player'] ?? {}),
          ));
          break;
        case 'player_left':
          _eventController.add(MultiplayerEvent.playerLeft(
            playerId: payload?['playerId'] ?? '',
          ));
          break;
        case 'player_ready':
          _eventController.add(MultiplayerEvent.playerReady(
            playerId: payload?['playerId'] ?? '',
            ready: payload?['ready'] ?? false,
          ));
          break;
        case 'player_surrendered':
          _eventController.add(MultiplayerEvent.playerSurrender(
            playerId: payload?['playerId'] ?? '',
            surrendered: payload?['surrendered'] ?? false,
          ));
          break;
        case 'game_started':
          _eventController.add(MultiplayerEvent.gameStart(
            gameState: GameStateEntity.fromJson(payload?['gameState'] ?? {}),
          ));
          break;
        case 'round_start':
          _eventController.add(MultiplayerEvent.roundStart(
            gameState: GameStateEntity.fromJson(payload?['gameState'] ?? {}),
          ));
          break;
        case 'round_over':
          _eventController.add(MultiplayerEvent.roundOver(
            gameState: GameStateEntity.fromJson(payload?['gameState'] ?? {}),
          ));
          break;
        case 'game_over':
          _eventController.add(MultiplayerEvent.gameOver(
            gameState: GameStateEntity.fromJson(payload?['gameState'] ?? {}),
          ));
          break;
        case 'guess_received':
          _eventController.add(MultiplayerEvent.guessResult(
            guess: GuessRecord.fromJson(payload?['guess'] ?? {}),
          ));
          break;
        case 'room_updated':
          _eventController.add(MultiplayerEvent.roomUpdated(
            room: RoomEntity.fromJson(payload?['room'] ?? {}),
          ));
          break;
        case 'game_state_updated':
          _eventController.add(MultiplayerEvent.gameStateUpdated(
            gameState: GameStateEntity.fromJson(payload?['gameState'] ?? {}),
          ));
          break;
        case 'left_room':
          _eventController.add(MultiplayerEvent.leftRoom());
          break;
        case 'error':
          _eventController.add(MultiplayerEvent.error(
            message: payload?['message'] ?? '',
          ));
          break;
        case 'heartbeat':
          break;
        default:
          break;
      }
    } catch (e) {
      _eventController.add(MultiplayerEvent.error(message: '消息解析失败: $e'));
    }
  }

  /// 注册事件监听
  StreamSubscription listen(void Function(MultiplayerEvent) onEvent) {
    return events.listen(onEvent);
  }

  void dispose() {
    disconnect();
    _eventController.close();
  }
}

/// 多人游戏事件类
sealed class MultiplayerEvent {
  const MultiplayerEvent();
  
  MultiplayerEventType get type;
  
  /// 连接成功
  factory MultiplayerEvent.connected() = ConnectedEvent;
  
  /// 连接断开
  factory MultiplayerEvent.disconnected() = DisconnectedEvent;
  
  /// 连接错误
  factory MultiplayerEvent.connectionError({required Object error}) = ConnectionErrorEvent;
  
  /// 房间创建成功
  factory MultiplayerEvent.roomCreated({required RoomEntity room}) = RoomCreatedEvent;
  
  /// 加入房间成功
  factory MultiplayerEvent.roomJoined({required RoomEntity room, required PlayerEntity player}) = RoomJoinedEvent;
  
  /// 加入房间失败
  factory MultiplayerEvent.joinFailed({required String reason}) = JoinFailedEvent;
  
  /// 玩家加入
  factory MultiplayerEvent.playerJoined({required PlayerEntity player}) = PlayerJoinedEvent;
  
  /// 玩家离开
  factory MultiplayerEvent.playerLeft({required String playerId}) = PlayerLeftEvent;
  
  /// 玩家准备状态变更
  factory MultiplayerEvent.playerReady({required String playerId, required bool ready}) = PlayerReadyEvent;
  
  /// 游戏开始
  factory MultiplayerEvent.gameStart({required GameStateEntity gameState}) = GameStartEvent;
  
  /// 回合开始
  factory MultiplayerEvent.roundStart({required GameStateEntity gameState}) = RoundStartEvent;
  
  /// 猜测结果
  factory MultiplayerEvent.guessResult({required GuessRecord guess}) = GuessResultEvent;
  
  /// 猜测更新
  factory MultiplayerEvent.guessUpdate({required GameStateEntity gameState}) = GuessUpdateEvent;
  
  /// 回合结束
  factory MultiplayerEvent.roundEnd({required GameStateEntity gameState}) = RoundEndEvent;
  
  /// 游戏结束
  factory MultiplayerEvent.gameEnd({required GameStateEntity gameState, required List<PlayerEntity> rankings}) = GameEndEvent;
  
  /// 房主变更
  factory MultiplayerEvent.hostChanged({required String newHostNickname}) = HostChangedEvent;
  
  /// 错误
  factory MultiplayerEvent.error({required String message}) = ErrorEvent;
  
  /// 初始化完成
  factory MultiplayerEvent.initialized() = InitializedEvent;
  
  /// 房间更新
  factory MultiplayerEvent.roomUpdated({required RoomEntity room}) = RoomUpdatedEvent;
  
  /// 玩家投降
  factory MultiplayerEvent.playerSurrender({required String playerId, required bool surrendered}) = PlayerSurrenderEvent;
  
  /// 回合结束
  factory MultiplayerEvent.roundOver({required GameStateEntity gameState}) = RoundOverEvent;
  
  /// 游戏结束
  factory MultiplayerEvent.gameOver({required GameStateEntity gameState}) = GameOverEvent;
  
  /// 游戏状态更新
  factory MultiplayerEvent.gameStateUpdated({required GameStateEntity gameState}) = GameStateUpdatedEvent;
  
  /// 离开房间
  factory MultiplayerEvent.leftRoom() = LeftRoomEvent;
  
  /// 准备状态更新成功
  factory MultiplayerEvent.readyUpdated({required bool success, required bool ready}) = ReadyUpdatedEvent;
}

class ConnectedEvent extends MultiplayerEvent {
  const ConnectedEvent();
  
  @override
  MultiplayerEventType get type => MultiplayerEventType.connected;
}

class DisconnectedEvent extends MultiplayerEvent {
  const DisconnectedEvent();
  
  @override
  MultiplayerEventType get type => MultiplayerEventType.disconnected;
}

class ConnectionErrorEvent extends MultiplayerEvent {
  final Object error;
  const ConnectionErrorEvent({required this.error});
  
  @override
  MultiplayerEventType get type => MultiplayerEventType.connectionError;
}

class RoomCreatedEvent extends MultiplayerEvent {
  final RoomEntity room;
  const RoomCreatedEvent({required this.room});
  
  @override
  MultiplayerEventType get type => MultiplayerEventType.roomCreated;
}

class RoomJoinedEvent extends MultiplayerEvent {
  final RoomEntity room;
  final PlayerEntity player;
  const RoomJoinedEvent({required this.room, required this.player});
  
  @override
  MultiplayerEventType get type => MultiplayerEventType.roomJoined;
}

class JoinFailedEvent extends MultiplayerEvent {
  final String reason;
  const JoinFailedEvent({required this.reason});
  
  @override
  MultiplayerEventType get type => MultiplayerEventType.joinFailed;
}

class PlayerJoinedEvent extends MultiplayerEvent {
  final PlayerEntity player;
  const PlayerJoinedEvent({required this.player});
  
  @override
  MultiplayerEventType get type => MultiplayerEventType.playerJoined;
}

class PlayerLeftEvent extends MultiplayerEvent {
  final String playerId;
  const PlayerLeftEvent({required this.playerId});
  
  @override
  MultiplayerEventType get type => MultiplayerEventType.playerLeft;
}

class PlayerReadyEvent extends MultiplayerEvent {
  final String playerId;
  final bool ready;
  const PlayerReadyEvent({required this.playerId, required this.ready});
  
  @override
  MultiplayerEventType get type => MultiplayerEventType.playerReady;
}

class GameStartEvent extends MultiplayerEvent {
  final GameStateEntity gameState;
  const GameStartEvent({required this.gameState});
  
  @override
  MultiplayerEventType get type => MultiplayerEventType.gameStart;
}

class RoundStartEvent extends MultiplayerEvent {
  final GameStateEntity gameState;
  const RoundStartEvent({required this.gameState});
  
  @override
  MultiplayerEventType get type => MultiplayerEventType.roundStart;
}

class GuessResultEvent extends MultiplayerEvent {
  final GuessRecord guess;
  const GuessResultEvent({required this.guess});
  
  @override
  MultiplayerEventType get type => MultiplayerEventType.guessResult;
}

class GuessUpdateEvent extends MultiplayerEvent {
  final GameStateEntity gameState;
  const GuessUpdateEvent({required this.gameState});
  
  @override
  MultiplayerEventType get type => MultiplayerEventType.guessUpdate;
}

class GameStateUpdatedEvent extends MultiplayerEvent {
  final GameStateEntity gameState;
  const GameStateUpdatedEvent({required this.gameState});
  
  @override
  MultiplayerEventType get type => MultiplayerEventType.gameStateUpdated;
}

class RoundEndEvent extends MultiplayerEvent {
  final GameStateEntity gameState;
  const RoundEndEvent({required this.gameState});
  
  @override
  MultiplayerEventType get type => MultiplayerEventType.roundEnd;
}

class GameEndEvent extends MultiplayerEvent {
  final GameStateEntity gameState;
  final List<PlayerEntity> rankings;
  const GameEndEvent({required this.gameState, required this.rankings});
  
  @override
  MultiplayerEventType get type => MultiplayerEventType.gameEnd;
}

class ErrorEvent extends MultiplayerEvent {
  final String message;
  const ErrorEvent({required this.message});
  
  @override
  MultiplayerEventType get type => MultiplayerEventType.error;
}

class HostChangedEvent extends MultiplayerEvent {
  final String newHostNickname;
  const HostChangedEvent({required this.newHostNickname});
  
  @override
  MultiplayerEventType get type => MultiplayerEventType.hostChanged;
}

class InitializedEvent extends MultiplayerEvent {
  const InitializedEvent();
  
  @override
  MultiplayerEventType get type => MultiplayerEventType.initialized;
}

class RoomUpdatedEvent extends MultiplayerEvent {
  final RoomEntity room;
  const RoomUpdatedEvent({required this.room});
  
  @override
  MultiplayerEventType get type => MultiplayerEventType.roomUpdated;
}

class PlayerSurrenderEvent extends MultiplayerEvent {
  final String playerId;
  final bool surrendered;
  const PlayerSurrenderEvent({required this.playerId, required this.surrendered});
  
  @override
  MultiplayerEventType get type => MultiplayerEventType.playerSurrender;
}

class RoundOverEvent extends MultiplayerEvent {
  final GameStateEntity gameState;
  const RoundOverEvent({required this.gameState});
  
  @override
  MultiplayerEventType get type => MultiplayerEventType.roundOver;
}

class GameOverEvent extends MultiplayerEvent {
  final GameStateEntity gameState;
  const GameOverEvent({required this.gameState});
  
  @override
  MultiplayerEventType get type => MultiplayerEventType.gameOver;
}

class LeftRoomEvent extends MultiplayerEvent {
  const LeftRoomEvent();
  
  @override
  MultiplayerEventType get type => MultiplayerEventType.leftRoom;
}

class ReadyUpdatedEvent extends MultiplayerEvent {
  final bool success;
  final bool ready;
  const ReadyUpdatedEvent({required this.success, required this.ready});
  
  @override
  MultiplayerEventType get type => MultiplayerEventType.readyUpdated;
}