import 'dart:async';
import 'package:flutter/foundation.dart';

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
  StreamController<MultiplayerEvent>? _eventController;
  
  final Map<String, RoomEntity> _rooms = {};

  StreamController<MultiplayerEvent> get _controller {
    if (_eventController == null || _eventController!.isClosed) {
      _eventController = StreamController.broadcast();
    }
    return _eventController!;
  }

  String? currentPlayerId;
  String? currentNickname;
  String? currentRoomId;
  String? _envId;

  Stream<MultiplayerEvent> get events => _controller.stream;

  Future<void> initialize({
    required String envId,
    String? nickname,
  }) async {
    debugPrint('[DEBUG][CloudService] initialize 方法被调用');
    debugPrint('[DEBUG][CloudService] 当前 currentPlayerId: $currentPlayerId');
    debugPrint('[DEBUG][CloudService] 当前 WebSocket 连接状态: ${_wsBroadcast.isConnected}');
    
    // 保存 envId 以便后续使用
    _envId = envId;
    
    debugPrint('[DEBUG][CloudService] 开始初始化流程...');
    
    try {
      String cachedNickname = await PlayerEntity.getCachedNickname();
      debugPrint('[DEBUG][CloudService] 缓存中的昵称: "$cachedNickname"');
      
      String? finalNickname = nickname ?? (cachedNickname.isEmpty || cachedNickname == '玩家' ? null : cachedNickname);
      currentNickname = finalNickname;
      
      await _wsBroadcast.initialize(host: envId);
      debugPrint('[DEBUG][CloudService] WebSocket 连接成功');
      
      _setupMessageHandler();
      
      // 无论之前是否连接，都需要重新发送初始化消息
      // WebSocket重连后服务器会分配新的玩家ID，必须重新初始化
      debugPrint('[DEBUG][CloudService] 发送初始化消息获取玩家ID...');
      await _wsBroadcast.sendInitialize(finalNickname);
      debugPrint('[DEBUG][CloudService] 等待初始化响应...');
      await _waitForInitialization();
      
    } catch (e, stackTrace) {
      debugPrint('[DEBUG][CloudService] 初始化失败 $e');
      debugPrint('[DEBUG][CloudService] 堆栈跟踪: $stackTrace');
      _controller.add(MultiplayerEvent.connectionError(error: e));
    }
  }
  
  Future<void> _waitForInitialization() async {
    Completer<void> completer = Completer();
    StreamSubscription? subscription;
    
    subscription = events.listen((event) {
      if (event.type == MultiplayerEventType.initialized) {
        debugPrint('[DEBUG][CloudService] 收到初始化响应，playerId: $currentPlayerId');
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
        
        debugPrint('[DEBUG][CloudService] 收到服务器消息: $action');
        
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
          case 'game_state_updated':
            _handleGameStateUpdated(data['payload']);
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
            debugPrint('[DEBUG][CloudService] 未知消息类型: $action');
        }
      } catch (e) {
        debugPrint('[DEBUG][CloudService] 消息处理错误: $e');
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
    
    debugPrint('[DEBUG][CloudService] 初始化完成，玩家ID: $currentPlayerId');
    debugPrint('[DEBUG][CloudService] 当前玩家昵称: $currentNickname');
    
    _controller.add(MultiplayerEvent.initialized());
  }

  void _handleRoomCreated(Map<String, dynamic> payload) {
    RoomEntity room = RoomEntity.fromJson(payload['room']);
    String? previousRoomId = currentRoomId;
    currentRoomId = room.roomId;
    
    debugPrint('[DEBUG][CloudService] ====== 房间创建 ======');
    debugPrint('[DEBUG][CloudService] 房间ID: ${room.roomId}');
    debugPrint('[DEBUG][CloudService] 房间码: ${room.roomCode}');
    debugPrint('[DEBUG][CloudService] 之前的房间ID: $previousRoomId');
    debugPrint('[DEBUG][CloudService] 房间创建者ID: ${room.creatorId}');
    debugPrint('[DEBUG][CloudService] 当前玩家ID: $currentPlayerId');
    
    // 当前玩家发起创建房间请求，就应该是房主
    // 即使服务器返回的creatorId与当前玩家ID不匹配（例如WebSocket重连后分配了新ID）
    // 也应该将当前玩家标记为房主
    bool shouldBeHost = currentPlayerId != null;
    
    debugPrint('[DEBUG][CloudService] 当前玩家是否应该是房主: $shouldBeHost');
    
    if (shouldBeHost) {
      debugPrint('[DEBUG][CloudService] 玩家列表: ${room.players.map((p) => '${p.nickname} (${p.playerId}, isHost=${p.isHost})').join(', ')}');
      
      List<PlayerEntity> updatedPlayers = [];
      bool needsUpdate = false;
      bool foundCurrentPlayer = false;
      
      for (var player in room.players) {
        debugPrint('[DEBUG][CloudService] 检查玩家 ${player.nickname}, playerId=${player.playerId}, currentPlayerId=$currentPlayerId, isHost=${player.isHost}');
        
        if (player.playerId == currentPlayerId) {
          foundCurrentPlayer = true;
          if (!player.isHost) {
            debugPrint('[DEBUG][CloudService] 修正创建者的房主状态 ${player.nickname}');
            updatedPlayers.add(player.copyWith(isHost: true));
            needsUpdate = true;
          } else {
            debugPrint('[DEBUG][CloudService] 玩家已是房主，无需修改: ${player.nickname}');
            updatedPlayers.add(player);
          }
        } else {
          // 如果找到不匹配的玩家（可能是服务器创建的默认玩家），暂时保留，稍后处理
          updatedPlayers.add(player);
        }
      }
      
      // 如果玩家列表中没有当前玩家，替换第一个非房主玩家为当前玩家并设为房主
      if (!foundCurrentPlayer && currentPlayerId != null) {
        debugPrint('[DEBUG][CloudService] 玩家列表中未找到当前玩家，替换僵尸玩家');
        
        // 查找并替换第一个非房主玩家
        bool replaced = false;
        for (int i = 0; i < updatedPlayers.length; i++) {
          if (!updatedPlayers[i].isHost) {
            debugPrint('[DEBUG][CloudService] 替换僵尸玩家: ${updatedPlayers[i].nickname} (${updatedPlayers[i].playerId})');
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
          debugPrint('[DEBUG][CloudService] 没有找到可替换的玩家，添加当前玩家');
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
        debugPrint('[DEBUG][CloudService] 已更新房主状态');
      } else {
        debugPrint('[DEBUG][CloudService] 无需更新房主状态');
      }
    }
    
    // 将房间保存到缓存
    _rooms[room.roomId] = room;
    debugPrint('[DEBUG][CloudService] 房间已保存到缓存: ${room.roomId}');
    
    _controller.add(MultiplayerEvent.roomCreated(room: room));
  }

  void _handleRoomJoined(Map<String, dynamic> payload) {
    RoomEntity room = RoomEntity.fromJson(payload['room']);
    PlayerEntity player = PlayerEntity.fromJson(payload['player']);
    String? previousRoomId = currentRoomId;
    currentRoomId = room.roomId;
    
    debugPrint('[DEBUG][CloudService] ====== 加入房间 ======');
    debugPrint('[DEBUG][CloudService] 房间ID: ${room.roomId}');
    debugPrint('[DEBUG][CloudService] 房间码: ${room.roomCode}');
    debugPrint('[DEBUG][CloudService] 之前的房间ID: $previousRoomId');
    debugPrint('[DEBUG][CloudService] 当前玩家ID: ${player.playerId}');
    debugPrint('[DEBUG][CloudService] 当前玩家昵称: ${player.nickname}');
    
    _controller.add(MultiplayerEvent.roomJoined(room: room, player: player));
  }

  void _handleJoinFailed(Map<String, dynamic> payload) {
    String reason = payload['reason'] ?? 'unknown';
    debugPrint('[DEBUG][CloudService] 加入房间失败: $reason');
    _controller.add(MultiplayerEvent.joinFailed(reason: reason));
  }

  void _handleRoomUpdated(Map<String, dynamic> payload) {
    RoomEntity room = RoomEntity.fromJson(payload['room']);
    
    debugPrint('[DEBUG][CloudService] ====== 房间更新 ======');
    debugPrint('[DEBUG][CloudService] 收到更新的房间ID: ${room.roomId}');
    debugPrint('[DEBUG][CloudService] 当前房间ID: $currentRoomId');
    debugPrint('[DEBUG][CloudService] 房间码: ${room.roomCode}');
    
    // 验证房间ID是否有效且与当前房间匹配
    if (room.roomId.isEmpty) {
      debugPrint('[DEBUG][CloudService] 房间更新失败：房间ID为空');
      return;
    }
    
    // 如果当前有房间，验证更新的房间是否匹配
    if (currentRoomId != null && room.roomId != currentRoomId) {
      debugPrint('[DEBUG][CloudService] 房间更新失败：房间ID不匹配，当前房间: $currentRoomId，更新房间: ${room.roomId}');
      return;
    }
    
    // 更新缓存中的房间数据
    _rooms[room.roomId] = room;
    debugPrint('[DEBUG][CloudService] 缓存已更新房间: ${room.roomId}');
    // 打印玩家准备状态信息
    String playerStatus = room.players.map((p) => '${p.nickname}: isReady=${p.isReady}, isHost=${p.isHost}, isSurrendered=${p.isSurrendered}').join(', ');
    debugPrint('[DEBUG][CloudService] 房间玩家状态: $playerStatus');
    _controller.add(MultiplayerEvent.roomUpdated(room: room));
  }

  void _handlePlayerJoined(Map<String, dynamic> payload) {
    PlayerEntity player = PlayerEntity.fromJson(payload['player']);
    _controller.add(MultiplayerEvent.playerJoined(player: player));
  }

  void _handlePlayerLeft(Map<String, dynamic> payload) {
    String playerId = payload['playerId'];
    _controller.add(MultiplayerEvent.playerLeft(playerId: playerId));
    
    // 主动更新本地缓存的房间数据，移除离开的玩家
    if (currentRoomId != null && _rooms.containsKey(currentRoomId)) {
      RoomEntity room = _rooms[currentRoomId]!;
      List<PlayerEntity> updatedPlayers = room.players.where((p) => p.playerId != playerId).toList();
      
      if (updatedPlayers.length != room.players.length) {
        RoomEntity updatedRoom = room.copyWith(players: updatedPlayers);
        _rooms[currentRoomId!] = updatedRoom;
        debugPrint('[DEBUG][CloudService] 玩家离开，更新房间玩家列表: ${updatedRoom.players.map((p) => p.nickname).join(', ')}');
        _controller.add(MultiplayerEvent.roomUpdated(room: updatedRoom));
      }
    }
  }

  void _handlePlayerReady(Map<String, dynamic> payload) {
    String playerId = payload['playerId'];
    bool ready = payload['ready'] ?? false;
    _controller.add(MultiplayerEvent.playerReady(playerId: playerId, ready: ready));
  }

  void _handleGuessReceived(Map<String, dynamic> payload) {
    GuessRecord guess = GuessRecord.fromJson(payload['guess']);
    _controller.add(MultiplayerEvent.guessResult(guess: guess));
  }

  void _handleRoundOver(Map<String, dynamic> payload) {
    GameStateEntity gameState = GameStateEntity.fromJson(payload['gameState']);
    _controller.add(MultiplayerEvent.roundOver(gameState: gameState));
  }

  void _handleGameOver(Map<String, dynamic> payload) {
    GameStateEntity gameState = GameStateEntity.fromJson(payload['gameState']);
    _controller.add(MultiplayerEvent.gameOver(gameState: gameState));
  }

  void _handleError(Map<String, dynamic> payload) {
    String message = payload['message'] ?? '未知错误';
    _controller.add(MultiplayerEvent.error(message: message));
  }

  void _handleLeftRoom(Map<String, dynamic> payload) {
    currentRoomId = null;
    _controller.add(MultiplayerEvent.leftRoom());
  }

  Future<void> createRoom({
    required GameType gameType,
    int maxPlayers = 4,
    int timeLimit = 60,
    int maxGuesses = 10,
    int totalRounds = 5,
    List<String> selectedVersions = const [],
    double masterMinDx = 1.0,
    double masterMaxDx = 15.0,
    List<String> selectedGenres = const [],
  }) async {
    try {
      debugPrint('[DEBUG][CloudService] 开始创建房间...');
      
      // 如果当前没有玩家ID或WebSocket刚重连，需要重新初始化获取新的玩家ID
      if (currentPlayerId == null || !_wsBroadcast.isConnected) {
        debugPrint('[DEBUG][CloudService] 当前没有玩家ID或连接断开，尝试重新初始化...');
        if (_envId == null) {
          _controller.add(MultiplayerEvent.error(message: '创建房间失败: 环境ID未设置'));
          return;
        }
        // 清除旧的玩家ID，确保重新初始化能获取新的ID
        currentPlayerId = null;
        await initialize(envId: _envId!, nickname: currentNickname);
      }
      
      if (currentPlayerId == null) {
        _controller.add(MultiplayerEvent.error(message: '创建房间失败: 用户未登录'));
        return;
      }
      
      await _wsBroadcast.sendCreateRoom({
        'gameType': gameType.name,
        'maxPlayers': maxPlayers,
        'timeLimit': timeLimit,
        'maxGuesses': maxGuesses,
        'totalRounds': totalRounds,
        'nickname': currentNickname,
        'selectedVersions': selectedVersions,
        'masterMinDx': masterMinDx,
        'masterMaxDx': masterMaxDx,
        'selectedGenres': selectedGenres,
      });
      
    } catch (e) {
      _controller.add(MultiplayerEvent.error(message: '创建房间失败: $e'));
    }
  }
  
  Future<void> joinRoom(String roomId) async {
    try {
      if (currentPlayerId == null) {
        _controller.add(MultiplayerEvent.joinFailed(reason: 'not_initialized'));
        return;
      }
      
      // 判断是否6位数字房间码
      if (roomId.length == 6 && RegExp(r'^\d{6}$').hasMatch(roomId)) {
        debugPrint('[DEBUG][CloudService] 收到房间码 $roomId，正在查询房间列表');
        
        // 使用 Completer 等待房间列表响应
        Completer<void> completer = Completer<void>();
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
          // 500ms检查一次缓存
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
            debugPrint('[DEBUG][CloudService] 找到匹配的房间 ${room.roomId}');
            break;
          }
        }
        
        if (actualRoomId != null) {
          await _wsBroadcast.sendJoinRoom(actualRoomId, currentNickname);
        } else {
          debugPrint('[DEBUG][CloudService] 未找到匹配房间码的房间');
          _controller.add(MultiplayerEvent.joinFailed(reason: '房间不存在'));
        }
      } else {
        // 直接使用房间ID加入
        await _wsBroadcast.sendJoinRoom(roomId, currentNickname);
      }
      
    } catch (e) {
      _controller.add(MultiplayerEvent.error(message: '加入房间失败: $e'));
    }
  }

  Future<void> leaveRoom() async {
    try {
      if (currentRoomId == null) return;
      
      await _wsBroadcast.sendLeaveRoom();
      // 清除房间相关状态
      _rooms.remove(currentRoomId);
      currentRoomId = null;
      // 清除玩家ID，确保下次创建房间时重新初始化
      currentPlayerId = null;
      
    } catch (e) {
      _controller.add(MultiplayerEvent.error(message: '离开房间失败: $e'));
    }
  }

  Future<void> setReady(bool ready) async {
    try {
      if (currentRoomId == null) return;
      
      await _wsBroadcast.sendUpdateReady(ready);
      
    } catch (e) {
      _controller.add(MultiplayerEvent.error(message: '设置准备状态失败: $e'));
    }
  }

  Future<void> setSurrendered(bool surrendered) async {
    try {
      if (currentPlayerId == null || currentRoomId == null) return;
      
      await _wsBroadcast.sendSurrender();
      _controller.add(MultiplayerEvent.playerSurrender(playerId: currentPlayerId!, surrendered: surrendered));
    } catch (e) {
      _controller.add(MultiplayerEvent.error(message: '设置投降状态失败: $e'));
    }
  }

  Future<void> startGame() async {
    try {
      if (currentRoomId == null) return;
      
      await _wsBroadcast.sendStartGame();
      
    } catch (e) {
      _controller.add(MultiplayerEvent.error(message: '开始游戏失败: $e'));
    }
  }

  Future<void> startNextRound() async {
    try {
      if (currentRoomId == null) return;
      
      await _wsBroadcast.sendStartNextRound();
      
    } catch (e) {
      _controller.add(MultiplayerEvent.error(message: '开始下一回合失败: $e'));
    }
  }

  Future<void> submitGuess(String songId, String songName) async {
    try {
      if (currentPlayerId == null || currentRoomId == null) return;
      
      await _wsBroadcast.sendGuess(songId, songName);
      
    } catch (e) {
      _controller.add(MultiplayerEvent.error(message: '提交猜测失败: $e'));
    }
  }

  void startListeningToRoom(String roomId) {
    debugPrint('[DEBUG][CloudService] 开始监听房间: $roomId');
  }

  StreamSubscription listen(void Function(MultiplayerEvent) onEvent) {
    return events.listen(onEvent);
  }

  void dispose() {
    _wsBroadcast.disconnect();
    _controller.close();
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
    _controller.add(MultiplayerEvent.playerSurrender(playerId: playerId, surrendered: surrendered));
  }
  
  void _handleHostChanged(Map<String, dynamic> payload) {
    String newHostNickname = payload['newHostNickname'] ?? '';
    _controller.add(MultiplayerEvent.hostChanged(newHostNickname: newHostNickname));
  }
  
  void _handleRoundStart(Map<String, dynamic> payload) {
    GameStateEntity gameState = GameStateEntity.fromJson(payload['gameState']);
    _controller.add(MultiplayerEvent.roundStart(gameState: gameState));
  }
  
  void _handleGameStateUpdated(Map<String, dynamic> payload) {
    GameStateEntity gameState = GameStateEntity.fromJson(payload['gameState']);
    _controller.add(MultiplayerEvent.gameStateUpdated(gameState: gameState));
  }
  
  void _handleReadyUpdated(Map<String, dynamic> payload) {
    bool success = payload['success'] ?? false;
    bool ready = payload['ready'] ?? false;
    _controller.add(MultiplayerEvent.readyUpdated(success: success, ready: ready));
  }
  
  void _handleRoomInfo(Map<String, dynamic> payload) {
    RoomEntity room = RoomEntity.fromJson(payload['room']);
    
    if (room.roomId.isEmpty) {
      debugPrint('[DEBUG][CloudService] 房间信息更新失败：房间ID为空');
      return;
    }
    
    _rooms[room.roomId] = room;
    _controller.add(MultiplayerEvent.roomUpdated(room: room));
  }
  
  void _handleHeartbeat(Map<String, dynamic> payload) {
    debugPrint('[DEBUG][CloudService] 收到心跳响应');
  }
  
  void _handleUploadSongsResponse(Map<String, dynamic> payload) {
    bool success = payload['success'] ?? false;
    String message = payload['message'] ?? '';
    int totalSongs = payload['totalSongs'] ?? 0;
    debugPrint('[DEBUG][CloudService] 歌曲上传响应: success=$success, message=$message, totalSongs=$totalSongs');
  }
  
  void _handleSongCountResponse(Map<String, dynamic> payload) {
    int count = payload['count'] ?? 0;
    debugPrint('[DEBUG][CloudService] 服务器歌曲数量: $count');
  }
  
  Future<void> surrender() async {
    try {
      if (currentPlayerId == null || currentRoomId == null) return;
      
      await _wsBroadcast.sendSurrender();
      
    } catch (e) {
      _controller.add(MultiplayerEvent.error(message: '投降失败: $e'));
    }
  }
  
  // 上传歌曲数据到服务器
  Future<void> uploadSongs(List<Map<String, dynamic>> songs) async {
    try {
      await _wsBroadcast.sendUploadSongs(songs);
      debugPrint('[DEBUG][CloudService] 已发送上传歌曲请求，数量: ${songs.length}');
    } catch (e) {
      _controller.add(MultiplayerEvent.error(message: '上传歌曲失败: $e'));
    }
  }
  
  // 获取服务器歌曲数量
  Future<void> getSongCount() async {
    try {
      await _wsBroadcast.sendGetSongCount();
    } catch (e) {
      _controller.add(MultiplayerEvent.error(message: '获取歌曲数量失败: $e'));
    }
  }
}