import 'dart:async';
import 'dart:convert';
import '../WebSocketBroadcastService.dart';
import 'MultiplayerGameService.dart';
import '../../entity/Multiplayer/RoomEntity.dart';
import '../../entity/Multiplayer/PlayerEntity.dart';
import '../../entity/Multiplayer/GameStateEntity.dart';
import '../../entity/Multiplayer/GuessRecord.dart';
import '../../entity/GameType.dart';

class MultiplayerCloudBaseService {
  static final MultiplayerCloudBaseService _instance = MultiplayerCloudBaseService._internal();
  factory MultiplayerCloudBaseService() => _instance;
  MultiplayerCloudBaseService._internal();

  final WebSocketBroadcastService _wsBroadcast = WebSocketBroadcastService();
  final StreamController<MultiplayerEvent> _eventController = StreamController.broadcast();
  
  final Map<String, RoomEntity> _rooms = {};

  String? currentPlayerId;
  String? currentNickname;
  String? currentRoomId;

  Stream<MultiplayerEvent> get events => _eventController.stream;

  Future<void> initialize({
    required String envId,
    String? nickname,
  }) async {
    print('[DEBUG][CloudService] initialize 方法被调用');
    print('[DEBUG][CloudService] 当前 currentPlayerId: $currentPlayerId');
    print('[DEBUG][CloudService] 当前 WebSocket 连接状态: ${_wsBroadcast.isConnected}');
    
    // 如果已初始化且 WebSocket 仍连接，则跳过
    if (currentPlayerId != null && _wsBroadcast.isConnected) {
      print('[DEBUG][CloudService] 已初始化且连接正常，跳过');
      return;
    }
    
    // 如果有 currentPlayerId 但 WebSocket 未连接，需要重新连接
    if (currentPlayerId != null && !_wsBroadcast.isConnected) {
      print('[DEBUG][CloudService] 玩家ID存在但连接断开，重新连接...');
    }
    
    print('[DEBUG][CloudService] 开始初始化流程...');
    
    try {
      String cachedNickname = await PlayerEntity.getCachedNickname();
      print('[DEBUG][CloudService] 缓存中的昵称: "$cachedNickname"');
      
      String? finalNickname = nickname ?? (cachedNickname.isEmpty || cachedNickname == '玩家' ? null : cachedNickname);
      currentNickname = finalNickname;
      
      bool wasConnected = _wsBroadcast.isConnected;
      bool hadPlayerId = currentPlayerId != null;
      
      await _wsBroadcast.initialize(host: envId);
      print('[DEBUG][CloudService] WebSocket 连接成功');
      
      _setupMessageHandler();
      
      // 如果之前未连接，需要发送初始化消息
      if (!wasConnected) {
        await _wsBroadcast.sendInitialize(finalNickname);
        print('[DEBUG][CloudService] 已发送初始化消息');
        
        // 如果之前没有玩家ID，需要等待初始化响应；如果已有玩家ID（重新连接），不需要等待
        if (!hadPlayerId) {
          await _waitForInitialization();
        } else {
          print('[DEBUG][CloudService] 重新连接，已有玩家ID，跳过等待初始化响应');
        }
      } else if (currentPlayerId == null) {
        // WebSocket已连接但没有玩家ID，发送初始化并等待响应
        await _wsBroadcast.sendInitialize(finalNickname);
        print('[DEBUG][CloudService] 已发送初始化消息');
        await _waitForInitialization();
      }
      
    } catch (e, stackTrace) {
      print('[DEBUG][CloudService] 初始化失败: $e');
      print('[DEBUG][CloudService] 堆栈跟踪: $stackTrace');
      _eventController.add(MultiplayerEvent.connectionError(error: e));
    }
  }
  
  Future<void> _waitForInitialization() async {
    Completer<void> completer = Completer();
    StreamSubscription? subscription;
    
    subscription = events.listen((event) {
      if (event.type == MultiplayerEventType.initialized) {
        print('[DEBUG][CloudService] 收到初始化响应，playerId: $currentPlayerId');
        completer.complete();
        subscription?.cancel();
      } else if (event.type == MultiplayerEventType.error) {
        if (event is ErrorEvent) {
          completer.completeError(Exception(event.message));
        } else {
          completer.completeError(Exception('初始化失败'));
        }
        subscription?.cancel();
      }
    });
    
    // 设置超时
    Future.delayed(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        completer.completeError(Exception('初始化超时'));
        subscription?.cancel();
      }
    });
    
    await completer.future;
  }

  void _setupMessageHandler() {
    _wsBroadcast.subscribe(channel: 'global', onMessage: (Map<String, dynamic> data) {
      try {
        String action = data['action'] ?? '';
        
        print('[DEBUG][CloudService] 收到服务器消息: $action');
        
        switch (action) {
          case 'initialized':
            _handleInitialized(data['payload']);
            break;
          case 'room_created':
            _handleRoomCreated(data['payload']);
            break;
          case 'room_joined':
            _handleRoomJoined(data['payload']);
            break;
          case 'join_failed':
            _handleJoinFailed(data['payload']);
            break;
          case 'room_updated':
            _handleRoomUpdated(data['payload']);
            break;
          case 'player_joined':
            _handlePlayerJoined(data['payload']);
            break;
          case 'player_left':
            _handlePlayerLeft(data['payload']);
            break;
          case 'player_ready':
            _handlePlayerReady(data['payload']);
            break;
          case 'player_surrendered':
            _handlePlayerSurrendered(data['payload']);
            break;
          case 'host_changed':
            _handleHostChanged(data['payload']);
            break;
          case 'round_start':
            _handleRoundStart(data['payload']);
            break;
          case 'round_over':
            _handleRoundOver(data['payload']);
            break;
          case 'game_over':
            _handleGameOver(data['payload']);
            break;
          case 'guess_received':
            _handleGuessReceived(data['payload']);
            break;
          case 'ready_updated':
            _handleReadyUpdated(data['payload']);
            break;
          case 'error':
            _handleError(data['payload']);
            break;
          case 'left_room':
            _handleLeftRoom(data['payload']);
            break;
          case 'rooms_list':
            _handleRoomList(data['payload']);
            break;
          case 'room_info':
            _handleRoomInfo(data['payload']);
            break;
          case 'heartbeat':
            _handleHeartbeat(data['payload']);
            break;
          case 'upload_songs_response':
            _handleUploadSongsResponse(data['payload']);
            break;
          case 'song_count_response':
            _handleSongCountResponse(data['payload']);
            break;
          default:
            print('[DEBUG][CloudService] 未知消息类型: $action');
        }
      } catch (e) {
        print('[DEBUG][CloudService] 消息处理错误: $e');
      }
    });
  }
  
  void _handleRoomList(Map<String, dynamic> payload) {
    List<RoomEntity> rooms = (payload['rooms'] as List).map((e) => RoomEntity.fromJson(e)).toList();
    _rooms.clear();
    for (var room in rooms) {
      _rooms[room.roomId] = room;
    }
  }

  void _handleInitialized(Map<String, dynamic> payload) {
    currentPlayerId = payload['playerId'];
    currentNickname = payload['nickname'] ?? currentNickname;
    
    print('[DEBUG][CloudService] 初始化完成，玩家ID: $currentPlayerId');
    print('[DEBUG][CloudService] 当前玩家昵称: $currentNickname');
    
    _eventController.add(MultiplayerEvent.initialized());
  }

  void _handleRoomCreated(Map<String, dynamic> payload) {
    RoomEntity room = RoomEntity.fromJson(payload['room']);
    currentRoomId = room.roomId;
    
    print('[DEBUG][CloudService] 房间创建成功: ${room.roomId}');
    print('[DEBUG][CloudService] 房间创建者ID: ${room.creatorId}');
    print('[DEBUG][CloudService] 当前玩家ID: $currentPlayerId');
    
    // 确定创建者：
    // 1. 如果服务器返回了 creatorId，使用 creatorId
    // 2. 如果没有返回 creatorId，当前玩家就是创建者（因为是当前玩家调用的创建房间）
    bool shouldBeHost = false;
    if (room.creatorId.isNotEmpty) {
      shouldBeHost = room.creatorId == currentPlayerId && currentPlayerId != null;
    } else {
      // 服务器没有返回创建者信息，当前玩家就是创建者
      shouldBeHost = currentPlayerId != null;
    }
    
    print('[DEBUG][CloudService] 当前玩家是否应该是房主: $shouldBeHost');
    
    if (shouldBeHost) {
      print('[DEBUG][CloudService] 玩家列表: ${room.players.map((p) => '${p.nickname} (${p.playerId}, isHost=${p.isHost})').join(', ')}');
      
      List<PlayerEntity> updatedPlayers = [];
      bool needsUpdate = false;
      bool foundCurrentPlayer = false;
      
      for (var player in room.players) {
        print('[DEBUG][CloudService] 检查玩家: ${player.nickname}, playerId=${player.playerId}, currentPlayerId=$currentPlayerId, isHost=${player.isHost}');
        
        if (player.playerId == currentPlayerId) {
          foundCurrentPlayer = true;
          if (!player.isHost) {
            print('[DEBUG][CloudService] 修正创建者的房主状态: ${player.nickname}');
            updatedPlayers.add(player.copyWith(isHost: true));
            needsUpdate = true;
          } else {
            print('[DEBUG][CloudService] 玩家已是房主，无需修改: ${player.nickname}');
            updatedPlayers.add(player);
          }
        } else {
          // 如果找到不匹配的玩家（可能是服务器创建的默认玩家），暂时保留，稍后处理
          updatedPlayers.add(player);
        }
      }
      
      // 如果玩家列表中没有当前玩家，替换第一个非房主玩家为当前玩家并设为房主
      if (!foundCurrentPlayer && currentPlayerId != null) {
        print('[DEBUG][CloudService] 玩家列表中未找到当前玩家，替换僵尸玩家');
        
        // 查找并替换第一个非房主玩家
        bool replaced = false;
        for (int i = 0; i < updatedPlayers.length; i++) {
          if (!updatedPlayers[i].isHost) {
            print('[DEBUG][CloudService] 替换僵尸玩家: ${updatedPlayers[i].nickname} (${updatedPlayers[i].playerId})');
            updatedPlayers[i] = PlayerEntity(
              playerId: currentPlayerId!,
              nickname: currentNickname ?? '玩家',
              isHost: true,
              isReady: false,
            );
            replaced = true;
            break;
          }
        }
        
        // 如果没有找到可替换的玩家，添加新玩家
        if (!replaced) {
          print('[DEBUG][CloudService] 没有找到可替换的玩家，添加当前玩家');
          updatedPlayers.add(PlayerEntity(
            playerId: currentPlayerId!,
            nickname: currentNickname ?? '玩家',
            isHost: true,
            isReady: false,
          ));
        }
        
        needsUpdate = true;
      }
      
      if (needsUpdate) {
        room = room.copyWith(players: updatedPlayers);
        print('[DEBUG][CloudService] 已更新房主状态');
      } else {
        print('[DEBUG][CloudService] 无需更新房主状态');
      }
    }
    
    _eventController.add(MultiplayerEvent.roomCreated(room: room));
  }

  void _handleRoomJoined(Map<String, dynamic> payload) {
    RoomEntity room = RoomEntity.fromJson(payload['room']);
    PlayerEntity player = PlayerEntity.fromJson(payload['player']);
    currentRoomId = room.roomId;
    
    print('[DEBUG][CloudService] 成功加入房间: ${room.roomId}');
    
    _eventController.add(MultiplayerEvent.roomJoined(room: room, player: player));
  }

  void _handleJoinFailed(Map<String, dynamic> payload) {
    String reason = payload['reason'] ?? 'unknown';
    print('[DEBUG][CloudService] 加入房间失败: $reason');
    _eventController.add(MultiplayerEvent.joinFailed(reason: reason));
  }

  void _handleRoomUpdated(Map<String, dynamic> payload) {
    RoomEntity room = RoomEntity.fromJson(payload['room']);
    
    // 更新缓存中的房间数据
    _rooms[room.roomId] = room;
    print('[DEBUG][CloudService] 缓存已更新房间: ${room.roomId}');
    // 打印玩家准备状态信息
    String playerStatus = room.players.map((p) => '${p.nickname}: isReady=${p.isReady}, isHost=${p.isHost}, isSurrendered=${p.isSurrendered}').join(', ');
    print('[DEBUG][CloudService] 房间玩家状态: $playerStatus');
    _eventController.add(MultiplayerEvent.roomUpdated(room: room));
  }

  void _handlePlayerJoined(Map<String, dynamic> payload) {
    PlayerEntity player = PlayerEntity.fromJson(payload['player']);
    _eventController.add(MultiplayerEvent.playerJoined(player: player));
  }

  void _handlePlayerLeft(Map<String, dynamic> payload) {
    String playerId = payload['playerId'];
    _eventController.add(MultiplayerEvent.playerLeft(playerId: playerId));
    
    // 主动更新本地缓存的房间数据，移除离开的玩家
    if (currentRoomId != null && _rooms.containsKey(currentRoomId)) {
      RoomEntity room = _rooms[currentRoomId]!;
      List<PlayerEntity> updatedPlayers = room.players.where((p) => p.playerId != playerId).toList();
      
      if (updatedPlayers.length != room.players.length) {
        RoomEntity updatedRoom = room.copyWith(players: updatedPlayers);
        _rooms[currentRoomId!] = updatedRoom;
        print('[DEBUG][CloudService] 玩家离开，更新房间玩家列表: ${updatedRoom.players.map((p) => p.nickname).join(', ')}');
        _eventController.add(MultiplayerEvent.roomUpdated(room: updatedRoom));
      }
    }
  }

  void _handlePlayerReady(Map<String, dynamic> payload) {
    String playerId = payload['playerId'];
    bool ready = payload['ready'] ?? false;
    _eventController.add(MultiplayerEvent.playerReady(playerId: playerId, ready: ready));
  }

  void _handleGameStarted(Map<String, dynamic> payload) {
    GameStateEntity gameState = GameStateEntity.fromJson(payload['gameState']);
    _eventController.add(MultiplayerEvent.gameStart(gameState: gameState));
  }

  void _handleGuessReceived(Map<String, dynamic> payload) {
    GuessRecord guess = GuessRecord.fromJson(payload['guess']);
    _eventController.add(MultiplayerEvent.guessResult(guess: guess));
  }

  void _handleRoundOver(Map<String, dynamic> payload) {
    GameStateEntity gameState = GameStateEntity.fromJson(payload['gameState']);
    _eventController.add(MultiplayerEvent.roundOver(gameState: gameState));
  }

  void _handleGameOver(Map<String, dynamic> payload) {
    GameStateEntity gameState = GameStateEntity.fromJson(payload['gameState']);
    _eventController.add(MultiplayerEvent.gameOver(gameState: gameState));
  }

  void _handleError(Map<String, dynamic> payload) {
    String message = payload['message'] ?? '未知错误';
    _eventController.add(MultiplayerEvent.error(message: message));
  }

  void _handleLeftRoom(Map<String, dynamic> payload) {
    currentRoomId = null;
    _eventController.add(MultiplayerEvent.leftRoom());
  }

  Future<void> createRoom({
    required GameType gameType,
    int maxPlayers = 4,
    int timeLimit = 60,
    int maxGuesses = 10,
    int totalRounds = 5,
  }) async {
    try {
      print('[DEBUG][CloudService] 开始创建房间...');
      
      if (currentPlayerId == null) {
        _eventController.add(MultiplayerEvent.error(message: '创建房间失败: 用户未登录'));
        return;
      }
      
      await _wsBroadcast.sendCreateRoom({
        'gameType': gameType.name,
        'maxPlayers': maxPlayers,
        'timeLimit': timeLimit,
        'maxGuesses': maxGuesses,
        'totalRounds': totalRounds,
        'nickname': currentNickname,
      });
      
    } catch (e) {
      _eventController.add(MultiplayerEvent.error(message: '创建房间失败: $e'));
    }
  }

  Future<void> joinRoom(String roomId) async {
    try {
      if (currentPlayerId == null) {
        _eventController.add(MultiplayerEvent.joinFailed(reason: 'not_initialized'));
        return;
      }
      
      // 判断是否是6位数字房间码
      if (roomId.length == 6 && RegExp(r'^\d{6}$').hasMatch(roomId)) {
        print('[DEBUG][CloudService] 收到房间码: $roomId，正在查询房间列表');
        
        // 使用 Completer 等待房间列表响应
        Completer<void> completer = Completer();
        StreamSubscription? sub;
        int timeoutCount = 0;
        
        // 设置超时机制
        Timer.periodic(const Duration(milliseconds: 500), (timer) {
          timeoutCount++;
          if (timeoutCount >= 8) { // 4秒超时
            timer.cancel();
            if (!completer.isCompleted) {
              completer.complete();
            }
          }
          // 每500ms检查一次缓存
          if (!completer.isCompleted && _rooms.isNotEmpty) {
            for (var room in _rooms.values) {
              if (room.roomCode == roomId) {
                timer.cancel();
                completer.complete();
                break;
              }
            }
          }
        });
        
        // 获取房间列表
        await _wsBroadcast.sendGetRooms();
        
        // 等待响应
        await completer.future;
        
        // 在缓存中查找匹配的房间
        String? actualRoomId;
        for (var room in _rooms.values) {
          if (room.roomCode == roomId) {
            actualRoomId = room.roomId;
            print('[DEBUG][CloudService] 找到匹配的房间: ${room.roomId}');
            break;
          }
        }
        
        if (actualRoomId != null) {
          await _wsBroadcast.sendJoinRoom(actualRoomId, currentNickname);
        } else {
          print('[DEBUG][CloudService] 未找到匹配房间码的房间');
          _eventController.add(MultiplayerEvent.joinFailed(reason: '房间不存在'));
        }
      } else {
        // 直接使用房间ID加入
        await _wsBroadcast.sendJoinRoom(roomId, currentNickname);
      }
      
    } catch (e) {
      _eventController.add(MultiplayerEvent.error(message: '加入房间失败: $e'));
    }
  }

  Future<void> leaveRoom() async {
    try {
      if (currentRoomId == null) return;
      
      await _wsBroadcast.sendLeaveRoom();
      currentRoomId = null;
      
    } catch (e) {
      _eventController.add(MultiplayerEvent.error(message: '离开房间失败: $e'));
    }
  }

  Future<void> setReady(bool ready) async {
    try {
      if (currentRoomId == null) return;
      
      await _wsBroadcast.sendUpdateReady(ready);
      
    } catch (e) {
      _eventController.add(MultiplayerEvent.error(message: '设置准备状态失败: $e'));
    }
  }

  Future<void> setSurrendered(bool surrendered) async {
    try {
      _eventController.add(MultiplayerEvent.playerSurrender(playerId: currentPlayerId!, surrendered: surrendered));
    } catch (e) {
      _eventController.add(MultiplayerEvent.error(message: '设置投降状态失败: $e'));
    }
  }

  Future<void> startGame() async {
    try {
      if (currentRoomId == null) return;
      
      await _wsBroadcast.sendStartGame();
      
    } catch (e) {
      _eventController.add(MultiplayerEvent.error(message: '开始游戏失败: $e'));
    }
  }

  Future<void> submitGuess(String songId, String songName) async {
    try {
      if (currentPlayerId == null || currentRoomId == null) return;
      
      await _wsBroadcast.sendGuess(songId, songName);
      
    } catch (e) {
      _eventController.add(MultiplayerEvent.error(message: '提交猜测失败: $e'));
    }
  }

  void startListeningToRoom(String roomId) {
    print('[DEBUG][CloudService] 开始监听房间: $roomId');
  }

  StreamSubscription listen(void Function(MultiplayerEvent) onEvent) {
    return events.listen(onEvent);
  }

  void dispose() {
    _wsBroadcast.disconnect();
    _eventController.close();
  }
  
  List<RoomEntity> getWaitingRooms() {
    return _rooms.values.where((room) => room.status == 'waiting').toList();
  }
  
  RoomEntity? getRoomById(String roomId) {
    return _rooms[roomId];
  }
  
  void _handlePlayerSurrendered(Map<String, dynamic> payload) {
    String playerId = payload['playerId'] ?? '';
    bool surrendered = payload['surrendered'] ?? false;
    _eventController.add(MultiplayerEvent.playerSurrender(playerId: playerId, surrendered: surrendered));
  }
  
  void _handleHostChanged(Map<String, dynamic> payload) {
    String newHostNickname = payload['newHostNickname'] ?? '';
    _eventController.add(MultiplayerEvent.hostChanged(newHostNickname: newHostNickname));
  }
  
  void _handleRoundStart(Map<String, dynamic> payload) {
    GameStateEntity gameState = GameStateEntity.fromJson(payload['gameState']);
    _eventController.add(MultiplayerEvent.roundStart(gameState: gameState));
  }
  
  void _handleReadyUpdated(Map<String, dynamic> payload) {
    bool success = payload['success'] ?? false;
    bool ready = payload['ready'] ?? false;
    _eventController.add(MultiplayerEvent.readyUpdated(success: success, ready: ready));
  }
  
  void _handleRoomInfo(Map<String, dynamic> payload) {
    RoomEntity room = RoomEntity.fromJson(payload['room']);
    _rooms[room.roomId] = room;
    _eventController.add(MultiplayerEvent.roomUpdated(room: room));
  }
  
  void _handleHeartbeat(Map<String, dynamic> payload) {
    print('[DEBUG][CloudService] 收到心跳响应');
  }
  
  void _handleUploadSongsResponse(Map<String, dynamic> payload) {
    bool success = payload['success'] ?? false;
    String message = payload['message'] ?? '';
    int totalSongs = payload['totalSongs'] ?? 0;
    print('[DEBUG][CloudService] 歌曲上传响应: success=$success, message=$message, totalSongs=$totalSongs');
  }
  
  void _handleSongCountResponse(Map<String, dynamic> payload) {
    int count = payload['count'] ?? 0;
    print('[DEBUG][CloudService] 服务器歌曲数量: $count');
  }
  
  Future<void> surrender() async {
    try {
      if (currentPlayerId == null || currentRoomId == null) return;
      
      await _wsBroadcast.sendSurrender();
      
    } catch (e) {
      _eventController.add(MultiplayerEvent.error(message: '投降失败: $e'));
    }
  }
  
  // 上传歌曲数据到服务器
  Future<void> uploadSongs(List<Map<String, dynamic>> songs) async {
    try {
      await _wsBroadcast.sendUploadSongs(songs);
      print('[DEBUG][CloudService] 已发送上传歌曲请求，数量: ${songs.length}');
    } catch (e) {
      _eventController.add(MultiplayerEvent.error(message: '上传歌曲失败: $e'));
    }
  }
  
  // 获取服务器歌曲数量
  Future<void> getSongCount() async {
    try {
      await _wsBroadcast.sendGetSongCount();
    } catch (e) {
      _eventController.add(MultiplayerEvent.error(message: '获取歌曲数量失败: $e'));
    }
  }
}