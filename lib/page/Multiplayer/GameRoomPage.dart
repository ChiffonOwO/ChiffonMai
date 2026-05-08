import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_first_flutter_app/entity/Multiplayer/RoomEntity.dart';
import 'package:my_first_flutter_app/entity/Multiplayer/GameStateEntity.dart';
import 'package:my_first_flutter_app/entity/Multiplayer/PlayerEntity.dart';
import 'package:my_first_flutter_app/entity/Multiplayer/GuessRecord.dart';
import 'package:my_first_flutter_app/entity/Song.dart';
import 'package:my_first_flutter_app/entity/GuessSong.dart';
import 'package:my_first_flutter_app/manager/MultiplayerManager.dart';
import 'package:my_first_flutter_app/manager/SongAliasManager.dart';
import 'package:my_first_flutter_app/service/GuessChartGame/GuessChartByInfoService.dart';
import 'package:my_first_flutter_app/utils/StringUtil.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:my_first_flutter_app/utils/CoverUtil.dart';

class GameRoomPage extends StatefulWidget {
  final RoomEntity room;

  const GameRoomPage({super.key, required this.room});

  @override
  State<GameRoomPage> createState() => _GameRoomPageState();
}

class _GameRoomPageState extends State<GameRoomPage> {
  final MultiplayerManager _manager = MultiplayerManager();
  RoomEntity? _currentRoom;
  GameStateEntity? _gameState;
  PlayerEntity? _currentPlayer;
  
  // 搜索相关
  TextEditingController _searchController = TextEditingController();
  List<Song> _searchResults = [];
  bool _isSearching = false;
  Timer? _searchTimer;
  static const Duration _searchDelay = Duration(milliseconds: 800);
  bool _showSearchResults = false;
  
  // 猜测历史
  List<GuessSong> _guessHistory = [];
  bool _isSubmitting = false;
  
  // 歌曲别名管理器
  late SongAliasManager _songAliasManager;
  
  // 目标歌曲（用于本地判定）
  Song? _targetSong;
  
  // 倒计时相关
  int _remainingTime = 0;
  Timer? _countdownTimer;
  
  // 回合结束原因
  bool _isRoundOverByTimeout = false;
  bool _isRoundOverBySurrender = false;
  
  // 当前玩家是否已投降
  bool _hasSurrendered = false;
  
  // 房主变更提示消息
  String? _hostChangeMessage;

  // 获取玩家显示名称（处理重复昵称）
  String _getPlayerDisplayName(PlayerEntity player) {
    if (_currentRoom == null) return player.nickname;
    
    // 检查是否有重复昵称
    int nicknameCount = _currentRoom!.players
        .where((p) => p.nickname == player.nickname)
        .length;
    
    if (nicknameCount > 1) {
      // 有重复昵称，显示昵称+ID后缀
      String idSuffix = player.playerId.substring(0, 4).toUpperCase();
      return '${player.nickname}($idSuffix)';
    }
    
    return player.nickname;
  }

  // 检查是否所有玩家都投降了
  bool _isAllPlayersSurrendered() {
    if (_currentRoom == null) return false;
    return _currentRoom!.players.every((p) => p.isSurrendered);
  }

  // 检查当前回合是否有人答对
  bool _hasCorrectGuess() {
    if (_gameState?.guesses.isEmpty ?? true) return false;
    return _gameState!.guesses.any((g) => g.isCorrect);
  }

  // 构建回合获胜者显示组件（只有当有人答对时才显示）
  Widget _buildRoundWinner() {
    // 如果是时间用完导致的回合结束，不显示答对提示
    if (_isRoundOverByTimeout) {
      return const SizedBox.shrink();
    }
    
    if (_gameState?.guesses.isEmpty ?? true) {
      return const SizedBox.shrink();
    }
    
    final correctGuesses = _gameState!.guesses.where((g) => g.isCorrect).toList();
    if (correctGuesses.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // 只显示最新的答对记录（当前回合的）
    final latestGuess = correctGuesses.last;
    
    // 检查这个答对记录是否是当前回合的
    // 通过检查时间戳，只有在回合结束前较短时间内的答对才显示
    // 这是一个简单的判断方法，假设回合时间不会太短
    if (_gameState != null && _gameState!.isRoundOver) {
      // 检查是否有任何猜测是在当前回合的时间范围内
      // 由于我们无法区分回合，这里检查最新的正确猜测是否足够新
      DateTime now = DateTime.now();
      if (latestGuess.guessedAt.isBefore(now.subtract(const Duration(minutes: 2)))) {
        // 如果答对记录太旧，说明是上一回合的，不显示
        return const SizedBox.shrink();
      }
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.green[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '🎉 ${_getGuessPlayerDisplayName(latestGuess.playerId, latestGuess.playerNickname)} 答对了! +${latestGuess.score}分', 
        style: const TextStyle(
          color: Colors.green,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // 获取猜测记录中玩家的显示名称
  String _getGuessPlayerDisplayName(String playerId, String playerNickname) {
    if (_currentRoom == null) return playerNickname;
    
    // 查找对应的玩家
    PlayerEntity? player = _currentRoom!.players
        .firstWhereOrNull((p) => p.playerId == playerId);
    
    if (player != null) {
      return _getPlayerDisplayName(player);
    }
    
    // 如果找不到玩家，检查是否有重复昵称
    int nicknameCount = _currentRoom!.players
        .where((p) => p.nickname == playerNickname)
        .length;
    
    if (nicknameCount > 1) {
      // 有重复昵称，显示昵称+ID后缀
      String idSuffix = playerId.substring(0, 4).toUpperCase();
      return '${playerNickname}($idSuffix)';
    }
    
    return playerNickname;
  }
  
  // 排序状态
  bool _isAscending = true;
  
  // Stream订阅
  StreamSubscription? _roomSubscription;
  StreamSubscription? _gameStateSubscription;

  @override
  void initState() {
    super.initState();
    _songAliasManager = SongAliasManager.instance;
    _initRoom();
  }

  Future<void> _initRoom() async {
    await _songAliasManager.init();
    
    // 确保 MultiplayerManager 已初始化（建立事件订阅）
    await _manager.initialize();
    
    setState(() {
      _currentRoom = widget.room;
      // 初始化时就从房间信息中获取当前玩家
      if (widget.room.players.isNotEmpty) {
        _currentPlayer = widget.room.players.firstWhere(
          (p) => p.playerId == _manager.currentPlayerId,
          orElse: () => widget.room.players.first,
        );
      }
    });
    
    _manager.startListeningToRoom(widget.room.roomId);
    
    _roomSubscription = _manager.roomStream.listen((room) {
      print('[DEBUG][GameRoomPage] 收到 roomStream 更新: ${room?.roomId}');
      if (!mounted) return;
      
      // 强制创建新的房间对象，确保 Flutter 检测到变化
      RoomEntity? newRoom = room != null ? RoomEntity(
        roomId: room.roomId,
        gameType: room.gameType,
        players: List.from(room.players),
        status: room.status,
        maxPlayers: room.maxPlayers,
        creatorId: room.creatorId,
        timeLimit: room.timeLimit,
        maxGuesses: room.maxGuesses,
        totalRounds: room.totalRounds,
        createdAt: room.createdAt,
        lastActivityAt: room.lastActivityAt,
      ) : null;
      
      setState(() {
        // 检测房主变更
        if (_currentRoom != null && newRoom != null) {
          String? oldHostName = _currentRoom!.players.firstWhere((p) => p.isHost, orElse: () => PlayerEntity(playerId: '', nickname: '', score: 0, isHost: false, isReady: false, isOnline: false, isSurrendered: false)).nickname;
          String? newHostName = newRoom.players.firstWhere((p) => p.isHost, orElse: () => PlayerEntity(playerId: '', nickname: '', score: 0, isHost: false, isReady: false, isOnline: false, isSurrendered: false)).nickname;
          
          // 如果房主变更了且不是同一个人
          if (oldHostName != null && newHostName != null && oldHostName != newHostName) {
            _hostChangeMessage = '$newHostName 成为了房主';
            // 3秒后清除提示
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) {
                setState(() {
                  _hostChangeMessage = null;
                });
              }
            });
          }
        }
        
        _currentRoom = newRoom;
        // 每次收到房间更新都更新当前玩家信息，确保状态同步
        if (newRoom != null) {
          _currentPlayer = newRoom.players.firstWhere(
            (p) => p.playerId == _manager.currentPlayerId,
            orElse: () => newRoom.players.first,
          );
        }
        
        // 检查是否所有人都投降了，如果是，结束当前回合
        if (_gameState != null && !_gameState!.isRoundOver && _isAllPlayersSurrendered()) {
          _gameState = _gameState!.copyWith(isRoundOver: true);
          _countdownTimer?.cancel();
          // 设置标记表示回合因投降结束
          _isRoundOverBySurrender = true;
        }
      });
    });

    _gameStateSubscription = _manager.gameStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        if (state != null) {
          // 检查是否是新回合
          bool isNewRound = _gameState == null || _gameState!.currentRound != state.currentRound;
          
          // 在覆盖之前保存本地状态
          int? localCurrentGuesses = _gameState?.currentGuesses;
          bool wasRoundOver = _gameState?.isRoundOver ?? false;
          
          if (isNewRound) {
            _remainingTime = state.timeRemaining;
            // 重置投降状态
            _hasSurrendered = false;
            // 重置回合结束原因（重要：防止显示上一回合的获胜者）
            _isRoundOverByTimeout = false;
            _isRoundOverBySurrender = false;
            
            // 新回合开始时，使用服务器状态并强制清空猜测历史
            _gameState = state.copyWith(guesses: []);
          } else {
            // 同一回合内，合并服务器和本地的猜测历史
            // 服务器返回的猜测可能延迟，所以保留本地已有的猜测
            List<GuessRecord> combinedGuesses = [];
            
            // 添加服务器返回的猜测
            if (state.guesses.isNotEmpty) {
              combinedGuesses.addAll(state.guesses);
            }
            
            // 如果服务器返回的猜测为空，但本地有猜测，保留本地猜测
            // 这可以防止服务器延迟导致猜测记录消失
            List<GuessRecord> localGuesses = _gameState?.guesses ?? [];
            if (state.guesses.isEmpty && localGuesses.isNotEmpty) {
              combinedGuesses.addAll(localGuesses);
            }
            
            // 去重：根据playerId、songId和guessedAt组合去重
            Map<String, GuessRecord> uniqueGuesses = {};
            for (var guess in combinedGuesses) {
              String key = '${guess.playerId}_${guess.songId}_${guess.guessedAt.millisecondsSinceEpoch}';
              uniqueGuesses[key] = guess;
            }
            
            _gameState = state.copyWith(guesses: uniqueGuesses.values.toList());
            
            // 保留本地更新的猜测次数（避免服务器延迟导致的覆盖）
            if (localCurrentGuesses != null && localCurrentGuesses > _gameState!.currentGuesses) {
              _gameState = _gameState!.copyWith(currentGuesses: localCurrentGuesses);
            }
          }
          
          // 如果回合已经结束（无论是因为投降还是答对），保持结束状态
          // 这可以防止服务器延迟导致的界面闪烁
          // 但新回合开始时不保留上一回合的结束状态
          if (wasRoundOver && !isNewRound) {
            _gameState = _gameState!.copyWith(isRoundOver: true);
          }
          
          // 只有在回合未结束或新回合开始时才加载目标歌曲
          if (state.targetSong != null && (!wasRoundOver || isNewRound)) {
            _loadTargetSong(state.targetSong!);
          }
          // 如果游戏开始且未结束，启动倒计时
          if (!state.isGameOver && !_gameState!.isRoundOver) {
            _startCountdown();
          } else {
            _countdownTimer?.cancel();
          }
        } else {
          _gameState = null;
        }
      });
    });
  }

  Future<void> _loadTargetSong(String targetSongId) async {
    try {
      final allSongs = await GuessChartByInfoService.loadAllSongs();
      if (allSongs != null && allSongs.isNotEmpty) {
        // 根据歌曲ID查找目标歌曲
        _targetSong = allSongs.firstWhere(
          (song) => song.id == targetSongId,
          orElse: () => allSongs.first,
        );
        
        // 添加调试日志
        if (_targetSong != null) {
          print('[DEBUG][GameRoom] 加载到目标歌曲:');
          print('[DEBUG][GameRoom]   歌曲ID: ${_targetSong!.id}');
          print('[DEBUG][GameRoom]   歌曲名: ${_targetSong!.basicInfo.title}');
          print('[DEBUG][GameRoom]   艺术家: ${_targetSong!.basicInfo.artist}');
          print('[DEBUG][GameRoom]   BPM: ${_targetSong!.basicInfo.bpm}');
          print('[DEBUG][GameRoom]   类型: ${_targetSong!.type}');
          print('[DEBUG][GameRoom]   Master定数: ${_targetSong!.ds.length > 0 ? _targetSong!.ds[0] : "-"}');
          print('[DEBUG][GameRoom]   版本: ${_targetSong!.basicInfo.from}');
        }
      }
    } catch (e) {
      print('[DEBUG][GameRoom] 加载目标歌曲失败: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchTimer?.cancel();
    _countdownTimer?.cancel();
    _roomSubscription?.cancel();
    _gameStateSubscription?.cancel();
    super.dispose();
  }

  void _handleReady() {
    if (_currentRoom != null) {
      _manager.updatePlayerReady(!(_currentPlayer?.isReady ?? false));
    }
  }

  void _handleStartGame() {
    _manager.startGame();
  }
  
  // 启动倒计时
  void _startCountdown() {
    _countdownTimer?.cancel();
    
    if (_remainingTime <= 0) return;
    
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_remainingTime > 0) {
          _remainingTime--;
        } else {
          _countdownTimer?.cancel();
          // 倒计时结束，设置回合结束（标记为时间用完）
          _isRoundOverByTimeout = true;
          _gameState = _gameState?.copyWith(isRoundOver: true);
        }
      });
    });
  }
  
  // 投降
  void _handleSurrender() {
    _countdownTimer?.cancel();
    _manager.updatePlayerSurrendered(true);
    setState(() {
      // 投降后不结束回合，只标记投降状态
      _hasSurrendered = true;
    });
  }
  
  // 显示规则说明对话框
  void _showRulesDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('规则说明'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('绿色 - 该属性与你猜的完全一致。'),
                SizedBox(height: 8),
                Text('黄色 - 该属性与你猜的"接近"：'),
                SizedBox(height: 4),
                Text('灰色 - 该属性与你猜的"差距较大"：'),
                SizedBox(height: 8),
                Text('BPM 相差在 ±20 范围内；'),
                Text('Master 难度或 Re:Master 难度相差在 ±0.4范围内；'),
                Text('版本相差一个世代（例如 maimai ← maimai PLUS → maimai GreeN）。'),
                SizedBox(height: 16),
                Text('箭头：'),
                SizedBox(height: 4),
                Text('↑ - 目标值比你猜的更高'),
                Text('↓ - 目标值比你猜的更低'),
                SizedBox(height: 16),
                Text('标签：'),
                SizedBox(height: 4),
                Text('显示您猜测的曲目的 Master 难度的配置、难度和评价标签。'),
                Text('当一个标签与目标曲目的属性一致时，该标签会变为绿色。'),
                Text('注意，有些曲目可能未添加标签。'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  // 处理搜索输入
  void _handleSearchInput(String value) {
    _searchTimer?.cancel();

    if (value.isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }

    _searchTimer = Timer(_searchDelay, () async {
      if (value.isEmpty) return;

      setState(() {
        _isSearching = true;
      });

      final allSongs = await GuessChartByInfoService.loadAllSongs();
      if (allSongs != null) {
        final results = await _searchSongs(allSongs, value);
        setState(() {
          _searchResults = results;
          _showSearchResults = results.isNotEmpty;
          _isSearching = false;
        });
      } else {
        setState(() {
          _isSearching = false;
        });
      }
    });
  }

  // 搜索歌曲（支持原曲名和别名）
  Future<List<Song>> _searchSongs(List<Song> songs, String query) async {
    List<Song> results = [];
    query = query.toLowerCase();

    // 搜索原曲名
    results.addAll(songs
        .where((song) => song.basicInfo.title.toLowerCase().contains(query)));

    // 搜索别名
    for (var song in songs) {
      if (!results.contains(song)) {
        final songId = song.id;
        final aliases = _songAliasManager.aliases[songId];
        if (aliases != null &&
            aliases.any((alias) => alias.toLowerCase().contains(query))) {
          results.add(song);
        }
      }
    }

    return results.take(20).toList();
  }

  // 处理猜测
  Future<void> _handleGuess(Song guessedSong) async {
    if (_isSubmitting) return;
    
    // 检查是否已经猜过这首歌
    bool hasGuessed =
        _guessHistory.any((guess) => guess.songId == int.parse(guessedSong.id));
    if (hasGuessed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已经猜过这首歌了！'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    _isSubmitting = true;
    
    try {
      // 构建猜测实体
      var guessSong = await GuessChartByInfoService.buildGuessSongEntity(guessedSong);
      
      // 计算猜测结果（本地判定）
      bool isCorrect = false;
      if (_targetSong != null) {
        guessSong = await GuessChartByInfoService.calculateGuessResult(
            guessSong, _targetSong!);
        // 检查是否答对（所有属性都正确）
        isCorrect = guessSong.titleBgColor == Colors.green &&
            guessSong.typeBgColor == Colors.green &&
            guessSong.bpmBgColor == Colors.green &&
            guessSong.artistBgColor == Colors.green &&
            guessSong.masterLevelBgColor == Colors.green &&
            guessSong.masterCharterBgColor == Colors.green &&
            guessSong.genreBgColor == Colors.green &&
            guessSong.versionBgColor == Colors.green;
      }

      // 更新本地UI状态
      setState(() {
        _searchController.clear();
        _searchResults = [];
        _showSearchResults = false;
        
        // 立即更新本地猜测次数（服务器会推送确认）
        if (_gameState != null) {
          _gameState = _gameState!.copyWith(
            currentGuesses: _gameState!.currentGuesses + 1,
          );
        }
        
        // 如果答对了，结束当前回合
        if (isCorrect) {
          _countdownTimer?.cancel();
          if (_gameState != null) {
            _gameState = _gameState!.copyWith(isRoundOver: true);
          }
        }
      });

      // 提交猜测到服务器（服务器会推送更新，包括猜测历史）
      await _manager.submitGuess(guessedSong.id, guessedSong.basicInfo.title);
    } finally {
      _isSubmitting = false;
    }
  }

  void _handleNextRound() {
    setState(() {
      _guessHistory.clear();
      // 重置回合结束原因
      _isRoundOverByTimeout = false;
      _isRoundOverBySurrender = false;
    });
  }

  void _handleRestartGame() {
    // 开始新一轮游戏
    setState(() {
      _guessHistory.clear();
    });
    _manager.startGame();
  }

  void _handleSettleGame() {
    // 结算游戏，保持游戏结束状态，不再进行新回合
    // 可以添加一些结算逻辑，比如更新最终分数等
    print('[DEBUG][GameRoom] 游戏已结算');
  }

  void _showLeaveRoomConfirmDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('确认离开'),
          content: const Text('是否离开当前房间？'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleLeaveRoom();
              },
              child: const Text('离开'),
            ),
          ],
        );
      },
    );
  }

  void _handleLeaveRoom() async {
    await _manager.leaveRoom();
    Navigator.pop(context);
  }

  Widget _buildPlayerList() {
    if (_currentRoom == null) return const SizedBox();
    
    return Column(
      children: _currentRoom!.players.map((player) {
        bool isCurrentPlayer = player.playerId == _manager.currentPlayerId;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isCurrentPlayer ? Colors.green[100] : (player.isHost ? Colors.blue[100] : Colors.grey[100]),
            borderRadius: BorderRadius.circular(8),
            border: isCurrentPlayer ? Border.all(color: Colors.green, width: 2) : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _getPlayerDisplayName(player),
                          style: TextStyle(
                            fontWeight: player.isHost ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        if (isCurrentPlayer)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Text('(我)', style: TextStyle(fontSize: 12, color: Colors.green)),
                          ),
                        if (player.isHost)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Text('(房主)', style: TextStyle(fontSize: 12, color: Colors.blue)),
                          ),
                      ],
                    ),
                    Row(
                      children: [
                        Text('分数: ${player.score}', style: const TextStyle(fontSize: 12)),
                        // 显示投降状态（红色）
                        if (player.isSurrendered) ...[
                          const SizedBox(width: 16),
                          const Text(
                            '已投降',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ] else if (_gameState == null) ...[
                          // 游戏未开始时显示准备状态
                          const SizedBox(width: 16),
                          Text(
                            player.isReady ? '已准备' : '未准备',
                            style: TextStyle(
                              fontSize: 12,
                              color: player.isReady ? Colors.green : Colors.orange,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // 游戏未开始时显示准备复选框
              if (_gameState == null && _currentPlayer?.playerId == player.playerId)
                Checkbox(
                  value: player.isReady,
                  onChanged: (value) => _handleReady(),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGameArea() {
    if (_gameState == null) {
      return const Center(child: Text('等待游戏开始...'));
    }

    if (_gameState!.isGameOver) {
      return Column(
        children: [
          const Text('游戏结束!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          
          // 显示答案区域（绿色背景）
          if (_targetSong != null)
            Container(
              margin: const EdgeInsets.only(top: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: _buildAnswerDisplay(),
            ),
          
          const SizedBox(height: 16),
          _buildScoreboard(),
          
          // 房主操作按钮
          if (_currentPlayer?.isHost == true)
            Container(
              margin: const EdgeInsets.only(top: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _handleRestartGame,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 84, 97, 97),
                    ),
                    child: const Text('开始新一轮', style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _handleSettleGame,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                    ),
                    child: const Text('结算游戏', style: TextStyle(color: Colors.black)),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    if (_gameState!.isRoundOver) {
      return Column(
        children: [
          const Text('回合结束!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          
          // 显示当前回合答对的玩家（只显示最新的答对记录）
          _buildRoundWinner(),
          
          // 显示答案区域（绿色背景）
          if (_targetSong != null)
            Container(
              margin: const EdgeInsets.only(top: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: _buildAnswerDisplay(),
            ),
          
          const SizedBox(height: 16),
          
          // 显示排行榜（放在下一轮按钮之前）
          _buildScoreboard(),
          
          const SizedBox(height: 16),
          
          // 只有房主可以控制下一轮（当时间用完、所有人都投降或有人答对时）
          if (_currentPlayer?.isHost == true && (_isRoundOverByTimeout || _isAllPlayersSurrendered() || _hasCorrectGuess()))
            ElevatedButton(
              onPressed: _handleNextRound,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 84, 97, 97),
              ),
              child: const Text('下一轮', style: TextStyle(color: Colors.white)),
            ),
        ],
      );
    }

    // 如果当前玩家已投降，显示等待提示
    if (_hasSurrendered) {
      return Column(
        children: [
          const SizedBox(height: 16),
          const Text(
            '请等待其他玩家操作……',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          
          // 显示剩余时间（给投降玩家看）
          if (_remainingTime > 0)
            Text(
              '⏱️ 剩余时间: ${_remainingTime}秒',
              style: TextStyle(fontSize: 16),
            ),
          
          const SizedBox(height: 16),
          
          // 猜测历史（从游戏状态获取，实时更新）
          if (_gameState != null && _gameState!.guesses.isNotEmpty)
            _buildGuessHistory(),
        ],
      );
    }

    return Column(
      children: [
        const SizedBox(height: 16),
        const Text(
          '🎵 无提示猜歌',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        
        // 倒计时显示
        if (_remainingTime > 0)
          Text(
            '⏱️ 剩余时间: ${_remainingTime}秒',
            style: TextStyle(
              fontSize: 16, 
              fontWeight: FontWeight.bold,
              color: _remainingTime <= 10 ? Colors.red : Colors.black,
            ),
          ),
        
        // 剩余猜测次数
        if (_gameState != null)
          Text(
            '🔢 剩余猜测次数: ${_gameState!.maxGuesses - _gameState!.currentGuesses}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: (_gameState!.maxGuesses - _gameState!.currentGuesses) <= 3 ? Colors.orange : Colors.black,
            ),
          ),
        
        const SizedBox(height: 16),
        
        // 搜索框
        _buildSearchField(),
        
        const SizedBox(height: 16),
        
        // 搜索结果
        if (_showSearchResults && _searchResults.isNotEmpty)
          _buildSearchResults(),
        
        // 按钮区域
        Container(
          margin: const EdgeInsets.only(top: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 规则按钮
                  IconButton(
                    icon: const Icon(
                        Icons.info_outline,
                        color: Color.fromARGB(
                            255, 84, 97, 97),
                        size: 24),
                    onPressed: _showRulesDialog,
                  ),
                  const SizedBox(width: 4),
                  // 排序按钮
                  IconButton(
                    icon: Icon(
                      _isAscending
                          ? Icons.sort_by_alpha
                          : Icons.sort_by_alpha_outlined,
                      color: const Color.fromARGB(
                          255, 84, 97, 97),
                      size: 24,
                    ),
                    onPressed: () {
                      setState(() {
                        _isAscending = !_isAscending;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  // 投降按钮
                  TextButton(
                    onPressed: _handleSurrender,
                    child: const Text('投降',
                        style: TextStyle(
                            color: Color.fromARGB(
                                255, 84, 97, 97))),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // 猜测历史（从游戏状态获取，实时更新）
        if (_gameState != null && _gameState!.guesses.isNotEmpty)
          _buildGuessHistory(),
      ],
    );
  }

  Widget _buildSongInfoCard() {
    return Column(
      children: [
        const Icon(Icons.music_note, size: 64, color: Colors.white),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(flex: 1, child: Text('艺术家', style: TextStyle(color: Colors.grey[300]))),
            Expanded(flex: 2, child: const Text('未知艺术家', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(flex: 1, child: Text('BPM', style: TextStyle(color: Colors.grey[300]))),
            Expanded(flex: 2, child: const Text('???', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(flex: 1, child: Text('难度', style: TextStyle(color: Colors.grey[300]))),
            Expanded(flex: 2, child: const Text('???', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(flex: 1, child: Text('流派', style: TextStyle(color: Colors.grey[300]))),
            Expanded(flex: 2, child: const Text('???', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: '输入歌曲名搜索',
              border: OutlineInputBorder(),
            ),
            onChanged: _handleSearchInput,
          ),
        ),
        const SizedBox(width: 8),
        if (_searchController.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              setState(() {
                _searchController.clear();
                _searchResults = [];
                _showSearchResults = false;
              });
            },
          ),
      ],
    );
  }

  Widget _buildSearchResults() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      constraints: const BoxConstraints(maxHeight: 300),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          return _buildSearchResultItem(_searchResults[index]);
        },
      ),
    );
  }

  Widget _buildSearchResultItem(Song song) {
    final aliases = _songAliasManager.aliases[song.id] ?? [];
    String aliasText = aliases.isNotEmpty ? aliases.join('、') : '';

    return GestureDetector(
      onTap: () => _handleGuess(song),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CoverUtil.buildCoverWidgetWithContext(context, song.id, 60),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        song.type == 'SD' ? 'ST' : 'DX',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: song.type == 'SD' ? Colors.blue : Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          song.basicInfo.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    song.basicInfo.artist,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (aliasText.isNotEmpty)
                    Text(
                      aliasText,
                      style: TextStyle(fontSize: 14, color: Colors.blue),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuessHistory() {
    if (_gameState == null || _gameState!.guesses.isEmpty) {
      return const SizedBox.shrink();
    }
    
    List<GuessRecord> guesses = List.from(_gameState!.guesses);
    
    // 去重：根据playerId、songId和guessedAt组合去重
    Map<String, GuessRecord> uniqueGuesses = {};
    for (var guess in guesses) {
      String key = '${guess.playerId}_${guess.songId}_${guess.guessedAt.millisecondsSinceEpoch}';
      uniqueGuesses[key] = guess;
    }
    guesses = uniqueGuesses.values.toList();
    
    // 先按时间排序确定实际提交顺序
    List<GuessRecord> timeSortedGuesses = List.from(guesses);
    timeSortedGuesses.sort((a, b) => a.guessedAt.compareTo(b.guessedAt));
    
    // 创建猜测序号映射
    Map<String, int> guessOrderMap = {};
    for (int i = 0; i < timeSortedGuesses.length; i++) {
      String key = '${timeSortedGuesses[i].playerId}_${timeSortedGuesses[i].songId}_${timeSortedGuesses[i].guessedAt.millisecondsSinceEpoch}';
      guessOrderMap[key] = i + 1;
    }
    
    // 根据排序状态排序显示顺序
    if (_isAscending) {
      guesses.sort((a, b) => a.guessedAt.compareTo(b.guessedAt));
    } else {
      guesses.sort((a, b) => b.guessedAt.compareTo(a.guessedAt));
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('猜测历史:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...guesses.map((guess) {
          String key = '${guess.playerId}_${guess.songId}_${guess.guessedAt.millisecondsSinceEpoch}';
          int guessNumber = guessOrderMap[key] ?? 1;
          return _buildGuessHistoryItemFromRecord(guess, guessNumber);
        }),
      ],
    );
  }

  Widget _buildGuessHistoryItemFromRecord(GuessRecord guess, int guessNumber) {
    return FutureBuilder<GuessSong?>(
      future: _buildGuessSongForRecord(guess),
      builder: (context, snapshot) {
        GuessSong? guessSong = snapshot.data;
        
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左上角显示提交者信息
              Text(
                '${guess.playerNickname}提交了第$guessNumber个猜测结果',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 12),

              // 第一行：曲绘，曲名
              Row(
                children: [
                  // 方形曲绘
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: CoverUtil.buildCoverWidgetWithContext(context, guess.songId, 60),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoItem('曲名', 
                        guessSong?.title ?? guess.songName, 
                        guessSong?.titleBgColor ?? Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 第二行：类型，BPM，曲师
              if (guessSong != null)
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: _buildInfoItem(
                          '类型', guessSong.type == 'SD' ? 'ST' : guessSong.type, 
                          guessSong.typeBgColor ?? Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: _buildInfoItem('BPM', guessSong.bpm.toString(),
                          guessSong.bpmBgColor ?? Colors.grey,
                          arrow: guessSong.bpmArrow),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: guessSong.artistBgColor ?? Colors.grey,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '曲师',
                              style: TextStyle(fontSize: 10, color: Colors.white),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              guessSong.artist,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),

              // 第三行：Master定数，Master谱师
              if (guessSong != null)
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildInfoItem('Master定数', guessSong.masterDs,
                          guessSong.masterLevelBgColor ?? Colors.grey,
                          arrow: guessSong.masterLevelArrow),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: _buildInfoItem('Master谱师', guessSong.masterCharter,
                          guessSong.masterCharterBgColor ?? Colors.grey),
                    ),
                  ],
                ),
              const SizedBox(height: 8),

              // 第四行：ReMaster定数，ReMaster谱师
              if (guessSong != null)
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildInfoItem(
                          'ReMaster定数',
                          guessSong.remasterDs.isNotEmpty
                              ? guessSong.remasterDs
                              : '-',
                          guessSong.remasterLevelBgColor ?? Colors.grey,
                          arrow: guessSong.remasterLevelArrow),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: guessSong.remasterCharterBgColor ?? Colors.grey,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ReMaster谱师',
                              style: TextStyle(fontSize: 10, color: Colors.white),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              guessSong.remasterCharter.isNotEmpty
                                  ? guessSong.remasterCharter
                                  : '-',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),

              // 第五行：流派，版本
              if (guessSong != null)
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildInfoItem('流派', guessSong.genre,
                          guessSong.genreBgColor ?? Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: guessSong.versionBgColor ?? Colors.grey,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '版本',
                              style: TextStyle(fontSize: 10, color: Colors.white),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    StringUtil.formatVersion2(guessSong.version),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (guessSong.versionArrow != null)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: Text(
                                      guessSong.versionArrow!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: guessSong.versionArrow == '↑'
                                            ? Colors.blue
                                            : Colors.red,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 8),

              // 第六行：Master标签
              if (guessSong?.masterTags?.isNotEmpty ?? false)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Master标签',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          List.generate(guessSong!.masterTags?.length ?? 0, (i) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: guessSong!.tagBgColors?[i] ?? Colors.grey,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            guessSong!.masterTags?[i] ?? '',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),

              
            ],
          ),
        );
      },
    );
  }

  Future<GuessSong?> _buildGuessSongForRecord(GuessRecord guess) async {
    try {
      final songs = await GuessChartByInfoService.loadAllSongs();
      if (songs == null || songs.isEmpty) return null;
      
      Song? song = songs.firstWhereOrNull((s) => s.id == guess.songId);
      if (song == null) return null;
      
      GuessSong guessSong = await GuessChartByInfoService.buildGuessSongEntity(song);
      
      if (_targetSong != null) {
        guessSong = await GuessChartByInfoService.calculateGuessResult(
            guessSong, _targetSong!);
      }
      
      return guessSong;
    } catch (e) {
      return null;
    }
  }

  Widget _buildGuessHistoryItem(GuessSong guessSong, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '猜测 #${index + 1}',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 12),

          // 第一行：曲绘，曲名
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CoverUtil.buildCoverWidgetWithContext(context, guessSong.songId.toString(), 60),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoItem('曲名', guessSong.title,
                    guessSong.titleBgColor ?? Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 第二行：类型，BPM，曲师
          Row(
            children: [
              Expanded(
                flex: 1,
                child: _buildInfoItem(
                    '类型', guessSong.type == 'SD' ? 'ST' : guessSong.type, guessSong.typeBgColor ?? Colors.grey),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: _buildInfoItem('BPM', guessSong.bpm.toString(),
                    guessSong.bpmBgColor ?? Colors.grey,
                    arrow: guessSong.bpmArrow),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: guessSong.artistBgColor ?? Colors.grey,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '曲师',
                        style: TextStyle(fontSize: 10, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        guessSong.artist,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 第三行：Master定数，Master谱师
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildInfoItem('Master定数', guessSong.masterDs,
                    guessSong.masterLevelBgColor ?? Colors.grey,
                    arrow: guessSong.masterLevelArrow),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: _buildInfoItem('Master谱师', guessSong.masterCharter,
                    guessSong.masterCharterBgColor ?? Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 第四行：ReMaster定数，ReMaster谱师
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildInfoItem(
                    'ReMaster定数',
                    guessSong.remasterDs.isNotEmpty
                        ? guessSong.remasterDs
                        : '-',
                    guessSong.remasterLevelBgColor ?? Colors.grey,
                    arrow: guessSong.remasterLevelArrow),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: guessSong.remasterCharterBgColor ?? Colors.grey,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ReMaster谱师',
                        style: TextStyle(fontSize: 10, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        guessSong.remasterCharter.isNotEmpty
                            ? guessSong.remasterCharter
                            : '-',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 第五行：流派，版本
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildInfoItem('流派', guessSong.genre,
                    guessSong.genreBgColor ?? Colors.grey),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: guessSong.versionBgColor ?? Colors.grey,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '版本',
                        style: TextStyle(fontSize: 10, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              StringUtil.formatVersion2(guessSong.version),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (guessSong.versionArrow != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Text(
                                guessSong.versionArrow!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: guessSong.versionArrow == '↑'
                                      ? Colors.blue
                                      : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 第六行：Master标签
          if (guessSong.masterTags?.isNotEmpty ?? false)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Master标签',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      List.generate(guessSong.masterTags?.length ?? 0, (i) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: guessSong.tagBgColors?[i] ?? Colors.grey,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        guessSong.masterTags?[i] ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
        ],
      ),
    );
  }
  
  // 构建信息项
  Widget _buildInfoItem(String label, String value, Color color, {String? arrow}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.white),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (arrow != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    arrow,
                    style: TextStyle(
                      fontSize: 12,
                      color: arrow == '↑' ? Colors.blue : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // 构建答案显示区域
  Widget _buildAnswerDisplay() {
    if (_targetSong == null) return const SizedBox();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
        const Text(
          '本局答案',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 8),
        
        // 曲绘和信息
        Row(
          children: [
            // 曲绘
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CoverUtil.buildCoverWidgetWithContext(context, _targetSong!.id, 60),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 第一行：类型 曲名
                  Row(
                    children: [
                      Text(
                        _targetSong!.type == 'SD' ? 'ST' : _targetSong!.type,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _targetSong!.type == 'SD' ? Colors.blue : Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _targetSong!.basicInfo.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  // 第二行：曲师 | 流派
                  Text(
                    '${_targetSong!.basicInfo.artist} | ${_targetSong!.basicInfo.genre}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  // 第三行：masterDs | remasterDs | version
                  Text(
                    '${_targetSong!.ds.length > 3 ? _targetSong!.ds[3].toString() : '-'} | ${_targetSong!.ds.length > 4 ? _targetSong!.ds[4].toString() : '-'} | ${StringUtil.formatVersion2(_targetSong!.basicInfo.from)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildScoreboard() {
    if (_currentRoom == null) return const SizedBox();
    
    List<PlayerEntity> sortedPlayers = [..._currentRoom!.players]
      ..sort((a, b) => b.score.compareTo(a.score));
    
    return Column(
      children: [
        const Text('🏆 排行榜', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...sortedPlayers.asMap().entries.map((entry) {
          int index = entry.key;
          PlayerEntity player = entry.value;
          String medal = index == 0 ? '🥇' : index == 1 ? '🥈' : index == 2 ? '🥉' : '${index + 1}';
          
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: index < 3 ? Colors.yellow[50] : Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Text(medal, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(child: Text(_getPlayerDisplayName(player))),
                Text('${player.score} 分', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scaleFactor = screenWidth / 375.0;
    final paddingS = 8.0 * scaleFactor;
    final paddingM = 12.0 * scaleFactor;
    final paddingL = 16.0 * scaleFactor;
    final borderRadiusSmall = 8.0 * scaleFactor;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 背景
          CommonWidgetUtil.buildCommonBgWidget(),
          CommonWidgetUtil.buildCommonChiffonBgWidget(context),

          // 页面内容
          Column(
            children: [
              // 标题栏
              Container(
                padding: EdgeInsets.fromLTRB(paddingM, 48, paddingM, paddingS),
                child: Row(
                  children: [
                    // 返回按钮
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Color.fromARGB(255, 84, 97, 97)),
                      onPressed: _showLeaveRoomConfirmDialog,
                    ),
                    // 标题
                    Expanded(
                      child: Center(
                        child: Text(
                          '多人猜歌游戏',
                          style: TextStyle(
                            color: Color.fromARGB(255, 84, 97, 97),
                            fontSize: screenWidth * 0.06,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // 占位，保持标题居中
                    SizedBox(width: 48),
                  ],
                ),
              ),

              // 房主变更提示
              if (_hostChangeMessage != null)
                Container(
                  padding: EdgeInsets.symmetric(vertical: paddingS, horizontal: paddingM),
                  margin: EdgeInsets.symmetric(horizontal: paddingM, vertical: paddingS),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(borderRadiusSmall),
                    border: Border.all(color: Colors.blue, width: 1),
                  ),
                  child: Center(
                    child: Text(
                      _hostChangeMessage!,
                      style: TextStyle(
                        color: Colors.blue[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // 主内容区域
              Expanded(
                child: Container(
                  margin: EdgeInsets.fromLTRB(paddingS, 0, paddingS, paddingL),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(borderRadiusSmall),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 5.0 * scaleFactor,
                        offset: Offset(2.0 * scaleFactor, 2.0 * scaleFactor),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(paddingM),
                    child: Padding(
                      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + paddingL),
                      child: Column(
                        children: [
                          // 房间码显示
                          Container(
                            padding: EdgeInsets.symmetric(vertical: paddingS, horizontal: paddingM),
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 84, 97, 97),
                              borderRadius: BorderRadius.circular(borderRadiusSmall),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.key, color: Colors.white, size: 16),
                                    const SizedBox(width: 8),
                                    const Text(
                                      '房间码:',
                                      style: TextStyle(color: Colors.white, fontSize: 14),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _currentRoom?.roomCode ?? '-',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                // 当前人数/房间人数上限
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.people, color: Colors.white, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${_currentRoom?.players.length ?? 0}/${_currentRoom?.maxPlayers ?? 4}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: paddingL),
                          _buildPlayerList(),
                          SizedBox(height: paddingL * 1.5),
                          // 只有在等待状态且游戏未开始时显示开始按钮
                          if (_currentRoom?.status == RoomStatus.waiting && 
                              _currentPlayer?.isHost == true &&
                              _gameState == null)
                            ElevatedButton(
                              onPressed: _handleStartGame,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color.fromARGB(255, 84, 97, 97),
                              ),
                              child: const Text('开始游戏', style: TextStyle(color: Colors.white)),
                            ),
                          SizedBox(height: paddingL * 1.5),
                          _buildGameArea(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}