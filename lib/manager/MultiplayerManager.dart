import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:my_first_flutter_app/entity/Multiplayer/RoomEntity.dart';
import 'package:my_first_flutter_app/entity/Multiplayer/PlayerEntity.dart';
import 'package:my_first_flutter_app/entity/Multiplayer/GameStateEntity.dart';
import 'package:my_first_flutter_app/entity/Multiplayer/GuessRecord.dart';
import 'package:my_first_flutter_app/entity/GameType.dart';
import 'package:my_first_flutter_app/api/ApiUrls.dart';
import 'package:my_first_flutter_app/service/GuessChartGame/MultiplayerCloudBaseService.dart';
import 'package:my_first_flutter_app/service/GuessChartGame/MultiplayerGameService.dart';

class MultiplayerManager {
  static final MultiplayerManager _instance = MultiplayerManager._internal();
  factory MultiplayerManager() => _instance;
  MultiplayerManager._internal();

  final MultiplayerCloudBaseService _cloudService = MultiplayerCloudBaseService();
  StreamSubscription? _eventSubscription;

  String? _currentRoomId;
  PlayerEntity? _currentPlayer;
  GameStateEntity? _currentGameState;  // 本地缓存游戏状态
  DateTime? _newRoundStartTime;  // 新回合开始时间，用于过滤旧回合的延迟猜测
  
  final StreamController<RoomEntity?> _roomController = StreamController.broadcast();
  final StreamController<GameStateEntity?> _gameStateController = StreamController.broadcast();
  final StreamController<List<RoomEntity>> _roomListController = StreamController.broadcast();
  final StreamController<String> _errorMessageController = StreamController.broadcast();

  Stream<RoomEntity?> get roomStream => _roomController.stream;
  Stream<GameStateEntity?> get gameStateStream => _gameStateController.stream;
  Stream<List<RoomEntity>> get roomListStream => _roomListController.stream;
  Stream<String> get errorMessageStream => _errorMessageController.stream;
  
  String? get currentPlayerId => _cloudService.currentPlayerId;

  Future<void> initialize({String? nickname}) async {
    debugPrint('[DEBUG][Manager] 开始初始化...');
    debugPrint('[DEBUG][Manager] 传入昵称: $nickname');
    
    try {
      await _cloudService.initialize(
        envId: ApiUrls.MultiplayerServerUrl,
        nickname: nickname,
      );
      debugPrint('[DEBUG][Manager] CloudService 初始化完成');
      debugPrint('[DEBUG][Manager] 当前玩家ID: ${_cloudService.currentPlayerId}');
      debugPrint('[DEBUG][Manager] 当前玩家昵称: ${_cloudService.currentNickname}');
      
      if (_eventSubscription == null) {
        debugPrint('[DEBUG][Manager] 创建事件订阅...');
        _eventSubscription = _cloudService.listen(_handleCloudEvent);
        debugPrint('[DEBUG][Manager] 事件订阅创建完成');
      }
    } catch (e) {
      debugPrint('[DEBUG][Manager] 初始化异常: $e');
    }
  }

  void _handleCloudEvent(MultiplayerEvent event) {
    switch (event.type) {
      case MultiplayerEventType.connected:
        break;
      case MultiplayerEventType.roomCreated:
        if (event is RoomCreatedEvent && event.room != null) {
          _currentRoomId = event.room.roomId;
          _roomController.add(event.room);
          _refreshRoomList();
        }
        break;
      case MultiplayerEventType.roomJoined:
        if (event is RoomJoinedEvent) {
          _currentRoomId = event.room.roomId;
          _currentPlayer = event.player;
          _roomController.add(event.room);
          _refreshRoomList();
        }
        break;
      case MultiplayerEventType.playerJoined:
        _refreshRoom();
        break;
      case MultiplayerEventType.playerLeft:
        _refreshRoom();
        break;
      case MultiplayerEventType.playerReady:
        _refreshRoom();
        break;
      case MultiplayerEventType.playerSurrender:
        _refreshRoom();
        break;
      case MultiplayerEventType.roundStart:
        if (event is RoundStartEvent) {
          _currentGameState = event.gameState;
          _gameStateController.add(event.gameState);
        }
        break;
      case MultiplayerEventType.roundEnd:
        _refreshRoom();
        break;
      case MultiplayerEventType.roundOver:
        if (event is RoundOverEvent) {
          _currentGameState = event.gameState;
          _gameStateController.add(event.gameState);
        }
        break;
      case MultiplayerEventType.gameEnd:
        if (event is GameEndEvent) {
          _currentGameState = event.gameState;
          _gameStateController.add(event.gameState);
        }
        break;
      case MultiplayerEventType.gameOver:
        if (event is GameOverEvent) {
          _currentGameState = event.gameState;
          _gameStateController.add(event.gameState);
        }
        break;
      case MultiplayerEventType.gameStateUpdated:
        if (event is GameStateUpdatedEvent) {
          _currentGameState = event.gameState;
          _gameStateController.add(event.gameState);
        }
        break;
      case MultiplayerEventType.gameStart:
        if (event is GameStartEvent) {
          bool isNewRound = _currentGameState == null || 
              _currentGameState!.currentRound != event.gameState.currentRound;
          
          List<GuessRecord> combinedGuesses = [];
          
          if (event.gameState.guesses.isNotEmpty) {
            combinedGuesses.addAll(event.gameState.guesses);
          }
          
          if (!isNewRound && event.gameState.guesses.isEmpty && _currentGameState != null) {
            combinedGuesses.addAll(_currentGameState!.guesses);
          }
          
          Map<String, GuessRecord> uniqueGuesses = {};
          for (var guess in combinedGuesses) {
            String key = '${guess.playerId}_${guess.songId}_${guess.guessedAt.millisecondsSinceEpoch}';
            uniqueGuesses[key] = guess;
          }
          
          _currentGameState = GameStateEntity(
            currentRound: event.gameState.currentRound,
            totalRounds: event.gameState.totalRounds,
            targetSong: event.gameState.targetSong,
            guesses: uniqueGuesses.values.toList(),
            timeRemaining: event.gameState.timeRemaining,
            isGameOver: event.gameState.isGameOver,
            isRoundOver: event.gameState.isRoundOver,
            maxGuesses: event.gameState.maxGuesses,
            currentGuesses: isNewRound ? 0 : event.gameState.currentGuesses,
          );
          
          if (isNewRound) {
            _newRoundStartTime = DateTime.now();
          }
          
          _gameStateController.add(_currentGameState);
        }
        break;
      case MultiplayerEventType.guessResult:
        if (event is GuessResultEvent) {
          debugPrint('[DEBUG][Manager] guessResult event: isCorrect=${event.guess.isCorrect}, player=${event.guess.playerNickname}');
          
          if (_newRoundStartTime != null && event.guess.guessedAt.isBefore(_newRoundStartTime!)) {
            debugPrint('[DEBUG][Manager] Ignoring guessResult - belongs to previous round');
            _refreshRoom();
            break;
          }
          
          if (_currentPlayer != null && event.guess.playerId == _currentPlayer!.playerId) {
            _currentPlayer = _currentPlayer!.copyWith(
              score: _currentPlayer!.score + (event.guess.isCorrect ? event.guess.score : 0),
            );
            debugPrint('[DEBUG][Manager] Updated current player score: ${_currentPlayer!.score}');
          }
          if (_currentGameState != null) {
            List<GuessRecord> updatedGuesses = List.from(_currentGameState!.guesses);
            updatedGuesses.add(event.guess);
            
            bool isRoundOver = event.guess.isCorrect;
            debugPrint('[DEBUG][Manager] Setting isRoundOver=$isRoundOver');
            
            _currentGameState = _currentGameState!.copyWith(
              guesses: updatedGuesses,
              isRoundOver: isRoundOver,
            );
            _gameStateController.add(_currentGameState);
            debugPrint('[DEBUG][Manager] Game state updated and added to controller');
          } else {
            debugPrint('[DEBUG][Manager] _currentGameState is null');
          }
          _refreshRoom();
        }
        break;
      case MultiplayerEventType.guessUpdate:
        if (event is GuessUpdateEvent) {
          debugPrint('[DEBUG][Manager] guessUpdate event received');
          _currentGameState = event.gameState;
          _gameStateController.add(event.gameState);
        }
        break;
      case MultiplayerEventType.disconnected:
        _currentRoomId = null;
        _currentPlayer = null;
        _roomController.add(null);
        _gameStateController.add(null);
        break;
      case MultiplayerEventType.error:
        if (event is ErrorEvent) {
          _errorMessageController.add(event.message);
        }
        break;
      case MultiplayerEventType.joinFailed:
        break;
      case MultiplayerEventType.connectionError:
        break;
      case MultiplayerEventType.hostChanged:
        _refreshRoom();
        break;
      case MultiplayerEventType.initialized:
        break;
      case MultiplayerEventType.roomUpdated:
        if (event is RoomUpdatedEvent) {
          debugPrint('[DEBUG][Manager] 收到 roomUpdated 事件，发送到 roomController');
          _roomController.add(event.room);
        }
        break;
      case MultiplayerEventType.leftRoom:
        _currentRoomId = null;
        _currentPlayer = null;
        _roomController.add(null);
        _gameStateController.add(null);
        break;
      case MultiplayerEventType.readyUpdated:
        _refreshRoom();
        break;
    }
  }

  Future<RoomEntity?> createRoom({
    required GameType gameType,
    int maxPlayers = 4,
    int timeLimit = 60,
    int maxGuesses = 10,
    List<String> selectedVersions = const [],
    double masterMinDx = 1.0,
    double masterMaxDx = 15.0,
    List<String> selectedGenres = const [],
  }) async {
    debugPrint('[DEBUG][Manager] 开始创建房间请求...');
    debugPrint('[DEBUG][Manager] 参数: gameType=${gameType.name}, maxPlayers=$maxPlayers, timeLimit=$timeLimit, maxGuesses=$maxGuesses');
    debugPrint('[DEBUG][Manager] 歌曲筛选参数: selectedVersions=$selectedVersions, masterMinDx=$masterMinDx, masterMaxDx=$masterMaxDx, selectedGenres=$selectedGenres');
    
    await initialize();
    debugPrint('[DEBUG][Manager] 初始化完成');
    
    Completer<RoomEntity?> completer = Completer();
    bool completed = false;
    
    StreamSubscription? sub;
    sub = _cloudService.events.listen((event) {
      if (!completed) {
        debugPrint('[DEBUG][Manager] 收到事件: ${event.type}');
        
        if (event is RoomCreatedEvent) {
          completed = true;
          debugPrint('[DEBUG][Manager] 房间创建成功: ${event.room.roomId}');
          completer.complete(event.room);
          sub?.cancel();
        } else if (event is ErrorEvent) {
          completed = true;
          debugPrint('[DEBUG][Manager] 房间创建失败: ${event.message}');
          completer.complete(null);
          sub?.cancel();
        }
      }
    });
    
    debugPrint('[DEBUG][Manager] 调用 CloudService.createRoom...');
    await _cloudService.createRoom(
      gameType: gameType,
      maxPlayers: maxPlayers,
      timeLimit: timeLimit,
      maxGuesses: maxGuesses,
      selectedVersions: selectedVersions,
      masterMinDx: masterMinDx,
      masterMaxDx: masterMaxDx,
      selectedGenres: selectedGenres,
    );
    
    debugPrint('[DEBUG][Manager] 等待房间创建结果...');
    return completer.future;
  }

  Future<RoomEntity?> joinRoom(String roomId) async {
    debugPrint('[DEBUG][Manager] joinRoom called with roomId: "$roomId"');
    await initialize();
    
    Completer<RoomEntity?> completer = Completer();
    bool completed = false;
    
    StreamSubscription? sub;
    sub = _cloudService.events.listen((event) {
      if (!completed) {
        debugPrint('[DEBUG][Manager] joinRoom event received: ${event.type}');
        if (event is RoomJoinedEvent) {
          completed = true;
          debugPrint('[DEBUG][Manager] Room joined successfully');
          completer.complete(event.room);
          sub?.cancel();
        } else if (event is JoinFailedEvent) {
          completed = true;
          debugPrint('[DEBUG][Manager] Join failed: ${event.reason}');
          completer.complete(null);
          sub?.cancel();
        } else if (event is ErrorEvent) {
          completed = true;
          debugPrint('[DEBUG][Manager] Error occurred: ${event.message}');
          completer.complete(null);
          sub?.cancel();
        }
      }
    });
    
    debugPrint('[DEBUG][Manager] Calling cloudService.joinRoom...');
    await _cloudService.joinRoom(roomId);
    
    debugPrint('[DEBUG][Manager] Waiting for join result...');
    return completer.future;
  }

  Future<void> leaveRoom() async {
    await _cloudService.leaveRoom();
    _currentRoomId = null;
    _currentPlayer = null;
  }

  Future<void> updatePlayerReady(bool isReady) async {
    await _cloudService.setReady(isReady);
    if (_currentPlayer != null) {
      _currentPlayer = _currentPlayer!.copyWith(isReady: isReady);
    }
  }

  Future<void> updatePlayerSurrendered(bool surrendered) async {
    await _cloudService.setSurrendered(surrendered);
    if (_currentPlayer != null) {
      _currentPlayer = _currentPlayer!.copyWith(isSurrendered: surrendered);
    }
  }

  Future<void> startGame() async {
    await _cloudService.startGame();
  }

  Future<void> startNextRound() async {
    await _cloudService.startNextRound();
  }

  Future<void> submitGuess(String songId, String songName) async {
    await _cloudService.submitGuess(songId, songName);
  }

  Future<List<RoomEntity>> getRoomList() async {
    await initialize();
    
    try {
      return _cloudService.getWaitingRooms();
    } catch (e) {
      debugPrint('获取房间列表失败: $e');
    }
    
    return [];
  }

  void _refreshRoomList() async {
    final rooms = await getRoomList();
    _roomListController.add(rooms);
  }

  void _refreshRoom() async {
    if (_currentRoomId == null) return;
    
    try {
      final room = _cloudService.getRoomById(_currentRoomId!);
      
      if (room != null) {
        _roomController.add(room);
      }
    } catch (e) {
      debugPrint('刷新房间状态失败: $e');
    }
  }

  void startListeningToRoom(String roomId) {
    _currentRoomId = roomId;
    _refreshRoom();
  }

  void stopListening() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _cloudService.dispose();
  }
}