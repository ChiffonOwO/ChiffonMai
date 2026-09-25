import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:simai_flutter/simai_flutter.dart';
import 'package:my_first_flutter_app/entity/Multiplayer/RoomEntity.dart';
import 'package:my_first_flutter_app/entity/Multiplayer/GameStateEntity.dart';
import 'package:my_first_flutter_app/entity/Multiplayer/PlayerEntity.dart';
import 'package:my_first_flutter_app/entity/Multiplayer/GuessRecord.dart';
import 'package:my_first_flutter_app/entity/Multiplayer/GameType.dart';
import 'package:my_first_flutter_app/entity/DivingFish/Song.dart';
import 'package:my_first_flutter_app/entity/GuessChartGame/GuessSong.dart';
import 'package:my_first_flutter_app/manager/MaidataManager.dart';
import 'package:my_first_flutter_app/manager/MultiplayerManager.dart';
import 'package:my_first_flutter_app/manager/SongAliasManager.dart';
import 'package:my_first_flutter_app/page/GuessChartGame/GuessChartByChartPeekPage.dart';
import 'package:my_first_flutter_app/service/GuessChartGame/GuessChartByInfoService.dart';
import 'package:my_first_flutter_app/utils/StringUtil.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:my_first_flutter_app/utils/AppConstants.dart';
import 'package:my_first_flutter_app/utils/CoverUtil.dart';
import 'package:my_first_flutter_app/utils/GameSeedUtil.dart';
import 'package:my_first_flutter_app/utils/LuoXueSongUtil.dart';
import 'package:my_first_flutter_app/widgets/TileRevealImage.dart';

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
  final TextEditingController _searchController = TextEditingController();
  List<Song> _searchResults = [];
  Timer? _searchTimer;
  static const Duration _searchDelay = Duration(milliseconds: 800);
  bool _showSearchResults = false;
  
  // 猜测历史
  final List<GuessSong> _guessHistory = [];
  bool _isSubmitting = false;

  // 搜索中状态（与单人猜歌页一致，用于显示转圈提示）
  bool _isSearching = false;
  
  // 歌曲别名管理器
  late SongAliasManager _songAliasManager;
  
  // 目标歌曲（用于本地判定）
  Song? _targetSong;
  
  // 倒计时相关
  int _remainingTime = 0;
  Timer? _countdownTimer;
  
  // 回合结束原因
  bool _isRoundOverByTimeout = false;
  
  // 当前玩家是否已投降
  bool _hasSurrendered = false;
  
  // 房主变更提示消息
  String? _hostChangeMessage;
  
  // 游戏是否已结算（房主点击结算后变为true）
  bool _isGameSettled = false;

  // ==================== 模式专属状态 ====================
  // 开字母输入（letters 模式，房间共享进度）
  final TextEditingController _openLetterController = TextEditingController();

  // 曲绘截取参数 (cover 模式，基于种子确定性生成)
  CropRect? _cropRect;

  // 音频播放相关 (audio 模式)
  bool _isPlaying = false;
  bool _hasPlayed = false;
  int? _audioStartTime;
  double _currentPosition = 0.0;
  double _totalDuration = 0.0;
  Timer? _playbackTimer;
  AudioPlayer? _audioPlayer;
  StreamSubscription<Duration>? _positionSubscription;

  // 曲绘快闪相关 (flash 模式)
  bool _flashVisible = false;
  Timer? _flashTimer;

  // 曲绘拼图相关 (tileReveal 模式)
  // 揭示顺序由确定性种子生成，所有玩家看到同一批块被揭示。
  List<int> _tileRevealOrder = const [];
  int _revealedTileCount = 0;
  Timer? _tileRevealTimer;
  bool _tileRevealPaused = false;

  // 谱面片段相关 (chartPeek 模式)
  // 与单人谱面片段猜歌同一套口径：难度池 ∩ 房间定数范围 → 确定性挑一个难度，
  // 片段窗口也用确定性种子，保证所有玩家看到同一段谱面。
  SimaiPlayerController? _peekController;
  double _peekClipStart = 0.0;
  double _peekClipEnd = 0.0;
  bool _peekPlaying = false;
  bool _peekPreparing = false;
  bool _peekClipFinished = false;
  String? _peekUnavailableReason;
  /// 本回合实际播放的难度（inote 编号），用于显示与单人一致的难度标签。
  String? _peekResolvedInote;
  /// 本回合谱面（回合结束后重建带音频的播放器要用同一份谱面）。
  MaiChart? _peekChart;
  /// 答案模式（回合结束后）：
  /// 音频就绪后把播放器换成带音频实例，可无限复播对答案。
  bool _peekAnswerModeEntered = false;
  bool _peekAnswerAudioReady = false;
  bool _peekAnswerAudioFailed = false;
  bool _peekAudioAttached = false;
  String? _peekAnswerAudioPath;
  /// 手动复播次数（自动播放那一次不计）。**每人独立计数**。
  int _peekReplaysLeft = kPeekMaxReplays;
  static const int kPeekMaxReplays = 3; // 与单人谱面片段猜歌一致

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

  // 当前是否处于 letters（开字母）模式
  bool get _isLettersMode =>
      (_currentRoom?.gameType ?? widget.room.gameType) == GameType.letters;

  // 判断一条猜测是否命中本回合的目标曲。
  //
  // letters 一回合有多首目标曲（服务端 gameState.targetSongs），要逐首比对；
  // 其它模式目标曲只有一首，取 targetSongs[0] 或 _targetSong 均可。
  bool _isGuessCorrectForCurrentRound(String guessedTitle) {
    final titles = <String>[];
    for (final song in _gameState?.targetSongs ?? const []) {
      if (song is Map) {
        final t = song['title'] ?? song['basic_info']?['title'];
        if (t != null) titles.add(t.toString());
      }
    }
    if (titles.isEmpty && _targetSong != null) {
      titles.add(_targetSong!.basicInfo.title);
    }
    if (titles.isEmpty) return false;
    // 服务端用「归一化后完全相等」判定，这里保持同一口径
    final String target = _normalizeTitle(guessedTitle);
    return titles.any((t) => _normalizeTitle(t) == target);
  }

  // 与服务端 normalizeTitle 同口径：去首尾空白、转小写、连续空白折叠成单个空格。
  // 注意是「折叠」不是「删除」——服务端用的就是 `\s+ -> ' '`，
  // 写成删除会让「A B」和「AB」在本地被当成同一首，与服务端判定不一致。
  static String _normalizeTitle(String title) => title
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ');

  /// 终局横幅：显示本局获胜者（并列则列出所有人），无人得分时显示平局。
  ///
  /// 胜负由服务端 `winners` 下发，客户端不自己排序取第一名：
  /// Dart 的 `List.sort` 不保证稳定，同分玩家名次会随刷新跳动；而且同分本应
  /// 并列获胜，用排序先后决定赢家是错的。
  Widget _buildGameResultBanner(Brightness brightness) {
    final state = _gameState;
    if (state == null || !state.isGameOver) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final List<String> winnerIds = state.winners;

    // 拿不到玩家名册就没法把 id 翻译成人名，此时不硬猜，交给排行榜展示分数
    final players = state.players.isNotEmpty
        ? state.players
        : (_currentRoom?.players ?? const <PlayerEntity>[]);
    if (players.isEmpty) return const SizedBox.shrink();

    final bool isDraw = winnerIds.isEmpty;
    final List<String> winnerNames = isDraw
        ? const []
        : [
            for (final id in winnerIds)
              _getPlayerDisplayName(
                players.firstWhere(
                  (p) => p.playerId == id,
                  orElse: () => PlayerEntity(playerId: id, nickname: '玩家'),
                ),
              ),
          ];

    // 全场 0 分（例如全员投降 / 一题都没答出来）算平局，不写「获胜」
    final bool iAmWinner = !isDraw && winnerIds.contains(_manager.currentPlayerId);
    final String headline = isDraw
        ? '🤝 平局'
        : (winnerIds.length > 1
            ? '🤝 并列获胜'
            : (iAmWinner ? '🏆 你赢了！' : '🏆 ${winnerNames.first} 获胜'));
    final String? subline = (!isDraw && winnerIds.length > 1)
        ? winnerNames.join('、')
        : (isDraw ? '本局无人得分' : null);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: isDraw
            ? scheme.surfaceContainerHighest
            : AppColors.successSurface(brightness),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDraw
              ? scheme.outlineVariant
              : AppColors.successForeground(brightness).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            headline,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDraw
                  ? scheme.onSurface
                  : AppColors.successForeground(brightness),
            ),
          ),
          if (subline != null) ...[
            const SizedBox(height: 4),
            Text(
              subline,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDraw
                    ? scheme.onSurfaceVariant
                    : AppColors.successForeground(brightness),
              ),
            ),
          ],
        ],
      ),
    );
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
        color: AppColors.successSurface(Theme.of(context).brightness),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '🎉 ${_getGuessPlayerDisplayName(latestGuess.playerId, latestGuess.playerNickname)} 答对了! +${latestGuess.score}分', 
        style: TextStyle(
          color: AppColors.successForeground(Theme.of(context).brightness),
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
    PlayerEntity? player;
    for (var p in _currentRoom!.players) {
      if (p.playerId == playerId) {
        player = p;
        break;
      }
    }
    
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

  /// 取玩家的「已结算」分数。
  ///
  /// room.players 的分数永远慢一回合：服务端 endRoundHandler 是先
  /// room.endRound() 结算、再广播 round_over，而结算前那条 room_updated
  /// 早就发出去了，之后也不会补发。所以只要 gameState 里有该玩家的分数
  /// 快照（服务端 getGameState 会带 players），就以它为准。
  int _settledScoreOf(PlayerEntity player) {
    for (final p in _gameState?.players ?? const <PlayerEntity>[]) {
      if (p.playerId == player.playerId) return p.score;
    }
    return player.score;
  }
  
  // 排序状态
  bool _isAscending = true;
  
  // Stream订阅
  StreamSubscription? _roomSubscription;
  StreamSubscription? _gameStateSubscription;
  StreamSubscription? _errorMessageSubscription;

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

    debugPrint('[DEBUG][GameRoomPage] 初始化房间 - gameType: ${widget.room.gameType.name} (${widget.room.gameType.description})');
    debugPrint('[DEBUG][GameRoomPage] 房间码: ${widget.room.roomCode}, 房间ID: ${widget.room.roomId}');
    
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
      debugPrint('[DEBUG][GameRoomPage] 收到 roomStream 更新: ${room?.roomId}');
      if (!mounted) return;
      
      // 打印玩家投降状态（调试）
      if (room != null) {
        room.players.forEach((p) {
          debugPrint('[DEBUG][GameRoomPage] 玩家 ${p.nickname} - 投降: ${p.isSurrendered}');
        });
      }
      
      // 强制创建新的房间对象，确保 Flutter 检测到变化。
      //
      // ⚠️ 这里**必须用 copyWith()**，不要手写字段列表：以前是逐字段 new 一个
      // RoomEntity，结果新增的模式设置（flashDurationMs / tileCount /
      // tileRevealIntervalMs / peekDurationSeconds / peekDifficulties）没被带上，
      // 服务器一推房间状态就被覆盖成默认值——表现就是「自定义切块数量/揭示间隔
      // 进游戏后又变回 1000 块 / 1.5s」。
      //
      // 再用 withModeSettingsFallback 兜一层：万一某条房间事件没带这些字段
      // （fromJson 会退回默认值），就沿用本机已知的值（房间创建后这些设置不可改）。
      RoomEntity? newRoom = room
          ?.copyWith(players: List.from(room.players))
          .withModeSettingsFallback(_currentRoom ?? widget.room);
      
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
            // 调试信息
            debugPrint('[DEBUG][GameRoomPage] 新回合开始:');
            debugPrint('  - 当前回合: ${state.currentRound}/${state.totalRounds}');
            debugPrint('  - 共享猜测次数: ${state.currentGuesses}/${state.maxGuesses}');
            debugPrint('  - 本地投降状态已重置: _hasSurrendered=$_hasSurrendered');

            // 以服务端下发的剩余秒数为准；服务端未带时退化为房间设置
            // （GameStateEntity.timeRemaining 缺省 60，房间设 30 秒时倒计时会从 60 开始）
            _remainingTime = state.timeRemaining > 0
                ? state.timeRemaining
                : (state.timeLimit > 0
                    ? state.timeLimit
                    : (_currentRoom?.timeLimit ?? 60));
            // 重置投降状态
            _hasSurrendered = false;
            // 重置回合结束原因（重要：防止显示上一回合的获胜者）
            _isRoundOverByTimeout = false;
            // 重置模式专属状态（曲绘截取、音频起始时间等）
            _resetModeSpecificState();
            // 清空搜索框 / 搜索结果：
            // 输入框里残留着上一回合的文字时，新回合的搜索列表会被旧关键字过滤，
            // 玩家看着像「搜不到歌」而错过抢答（也让「输入即匹配」的判定失效）。
            _clearSearchInput();
            
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

            // 同回合内也用服务端剩余秒数对齐，避免本地 tick 与服务端计时漂移
            if (state.timeRemaining > 0 &&
                !state.isRoundOver &&
                !state.isGameOver) {
              _remainingTime = state.timeRemaining;
            }
            
            // 保留本地更新的猜测次数（避免服务器延迟导致的覆盖）
            if (localCurrentGuesses != null && localCurrentGuesses > _gameState!.currentGuesses) {
              _gameState = _gameState!.copyWith(currentGuesses: localCurrentGuesses);
            }
            
            // 调试信息
            debugPrint('[DEBUG][GameRoomPage] 游戏状态更新:');
            debugPrint('  - 当前回合: ${state.currentRound}');
            debugPrint('  - 服务器猜测次数: ${state.currentGuesses}');
            debugPrint('  - 本地猜测次数: ${_gameState!.currentGuesses}');
            debugPrint('  - 最大猜测次数: ${state.maxGuesses}');
            debugPrint('  - 剩余猜测次数: ${state.maxGuesses - _gameState!.currentGuesses}');
          }
          
          // 如果回合已经结束（无论是因为投降还是答对），保持结束状态
          // 这可以防止服务器延迟导致的界面闪烁
          // 但新回合开始时不保留上一回合的结束状态
          if (wasRoundOver && !isNewRound) {
            _gameState = _gameState!.copyWith(isRoundOver: true);
          }
          
          // 如果本地已经因为超时结束回合，强制保持结束状态
          // 这可以防止服务器延迟导致的按钮消失
          if (_isRoundOverByTimeout) {
            _gameState = _gameState!.copyWith(isRoundOver: true);
          }

          // 回合/游戏结束时停掉本地倒计时（否则会残留一个不动的秒数）
          if (_gameState!.isRoundOver || _gameState!.isGameOver) {
            _countdownTimer?.cancel();
            // chartPeek：回合结束后进入「答案模式」（照搬单人谱面片段猜歌）——
            // 备好带音频的片段，之后可无限复播对答案
            _enterPeekAnswerModeIfNeeded();
          }
          
          // 只有在回合未结束或新回合开始时才加载目标歌曲
          if (state.targetSong != null && (!wasRoundOver || isNewRound)) {
            _loadTargetSong(state.targetSong!);
          }
          // 如果游戏开始且未结束，启动倒计时
          // 只在没有在跑的倒计时时启动：每次 state 更新都重建 Timer 会把 1 秒的
          // 计时相位不断重置，更新足够频繁时倒计时看起来就是卡住不动的。
          if (!state.isGameOver && !_gameState!.isRoundOver) {
            if (_countdownTimer?.isActive != true) {
              _startCountdown();
            }
          } else {
            _countdownTimer?.cancel();
          }
        } else {
          _gameState = null;
        }
      });
    });

    // 监听服务器错误消息
    _errorMessageSubscription = _manager.errorMessageStream.listen((message) {
      Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    });
  }

  Future<void> _loadTargetSong(dynamic targetSongData) async {
    try {
      final allSongs = await GuessChartByInfoService.loadAllSongs();
      if (allSongs == null || allSongs.isEmpty) return;
      
      String targetSongId;
      
      // 处理两种情况：字符串ID或歌曲对象
      if (targetSongData is String) {
        targetSongId = targetSongData;
      } else if (targetSongData is Map) {
        targetSongId = targetSongData['id']?.toString() ?? '';
      } else {
        debugPrint('[DEBUG][GameRoom] 无法解析目标歌曲数据');
        return;
      }
      
      if (targetSongId.isEmpty) {
        debugPrint('[DEBUG][GameRoom] 目标歌曲ID为空');
        return;
      }
      
      // 根据歌曲ID查找目标歌曲
      _targetSong = allSongs.firstWhere(
        (song) => song.id == targetSongId,
        orElse: () => allSongs.first,
      );
      
      // 添加调试日志
      if (_targetSong != null) {
        debugPrint('[DEBUG][GameRoom] 加载到目标歌曲:');
        debugPrint('[DEBUG][GameRoom]   歌曲ID: ${_targetSong!.id}');
        debugPrint('[DEBUG][GameRoom]   歌曲名: ${_targetSong!.basicInfo.title}');
        debugPrint('[DEBUG][GameRoom]   艺术家: ${_targetSong!.basicInfo.artist}');
        debugPrint('[DEBUG][GameRoom]   BPM: ${_targetSong!.basicInfo.bpm}');
        debugPrint('[DEBUG][GameRoom]   类型: ${_targetSong!.type}');
        debugPrint('[DEBUG][GameRoom]   Master定数: ${_targetSong!.ds.length > 0 ? _targetSong!.ds[0] : "-"}');
        debugPrint('[DEBUG][GameRoom]   版本: ${_targetSong!.basicInfo.from}');
      }
    } catch (e) {
      debugPrint('[DEBUG][GameRoom] 加载目标歌曲失败: $e');
    }
  }

  @override
  void dispose() {
    debugPrint('[DEBUG][GameRoomPage] dispose - 用户离开页面，取消所有订阅');

    // 取消搜索控制器和定时器
    _searchController.dispose();
    _openLetterController.dispose();
    _searchTimer?.cancel();
    _countdownTimer?.cancel();

    // 取消房间和游戏状态订阅
    _roomSubscription?.cancel();
    _gameStateSubscription?.cancel();
    _errorMessageSubscription?.cancel();

    // 清理音频资源
    _playbackTimer?.cancel();
    _positionSubscription?.cancel();
    _audioPlayer?.dispose();

    // 清理 flash / tileReveal / chartPeek 的模式专属资源
    _flashTimer?.cancel();
    _tileRevealTimer?.cancel();
    _peekController?.timeNotifier.removeListener(_onPeekTimeChanged);
    _peekController?.dispose();
    _peekController = null;

    // 通知管理器停止监听房间
    _manager.stopListening();

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
      if (_isRoundOverByTimeout) {
        // chartPeek：超时同样要进入答案模式（否则复播没声音）
        _enterPeekAnswerModeIfNeeded();
      }
    });
  }
  
  // 投降
  void _handleSurrender() {
    _manager.updatePlayerSurrendered(true);
    
    // 调试信息
    debugPrint('[DEBUG][GameRoomPage] 玩家发起投降:');
    debugPrint('  - 当前回合: ${_gameState?.currentRound}');
    debugPrint('  - 投降前状态: _hasSurrendered=$_hasSurrendered');
    
    setState(() {
      // 投降后不结束回合，只标记投降状态
      _hasSurrendered = true;
    });
    
    // 调试信息
    debugPrint('  - 投降后状态: _hasSurrendered=$_hasSurrendered');
  }
  
  // 显示规则说明对话框
  void _showRulesDialog() {
    final brightness = Theme.of(context).brightness;
    final scheme = Theme.of(context).colorScheme;
    final gameType = _currentRoom?.gameType ?? widget.room.gameType;

    // 小标题：把长文分段，否则一整屏文字没人看
    Widget sectionTitle(String text) => Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 6),
          child: Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: scheme.primary,
            ),
          ),
        );

    Widget bullet(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text('· $text'),
        );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.menu_book_outlined, size: 20, color: scheme.primary),
              const SizedBox(width: 8),
              const Text('规则说明'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---------- 得分机制 ----------
                // 原先的规则弹窗只讲颜色、完全没提怎么算分，
                // 「为什么我猜中了分数却不高」这类疑问在游戏内无从查证。
                sectionTitle('得分机制'),
                bullet('答对得分 = 100 − 从回合开始经过的秒数，最低 10 分；答错 0 分。'),
                bullet('也就是越快猜中分数越高：秒答接近 100 分，拖到最后也有 10 分保底。'),
                bullet('同一首曲目只按你在这首上最好的一次计分，重复提交不会刷分。'),
                bullet('每一首曲目只给最先猜中的人计分，其余人这首拿 0 分。'),
                bullet('猜错不扣分，不用怕猜错拖累总分。'),
                if (gameType == GameType.letters) ...[
                  // letters 单回合有多首目标曲，计分口径与其它模式不同
                  bullet('开字母一回合有多首曲目，每首独立计分，'
                      '单回合满分 = 曲目数 × 100。'),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.warningOrange(brightness)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.warningOrange(brightness)
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        // 玩家最容易误解的一点，单独点出来
                        '注意：计时是从「回合开始」算的，不是从「猜中上一首」算的。'
                        '所以后面几首天然比第一首慢 —— 不是你的错觉。',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.warningOrange(brightness),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
                ],

                // ---------- 颜色 ----------
                sectionTitle('颜色含义'),
                bullet('绿色 - 该属性与你猜的完全一致。'),
                bullet('黄色 - 该属性与你猜的接近：BPM 相差 ±20 以内；'
                    'Master / Re:Master 难度相差 ±0.4 以内；'
                    '版本相差一个世代（maimai ← maimai PLUS → maimai GreeN）。'),
                bullet('灰色 - 该属性与你猜的差距较大。'),

                // ---------- 箭头 ----------
                sectionTitle('箭头'),
                bullet('↑ - 目标值比你猜的更高'),
                bullet('↓ - 目标值比你猜的更低'),

                // ---------- 标签 ----------
                sectionTitle('标签'),
                bullet('显示你猜的曲目在 Master 难度下的配置、难度和评价标签。'),
                bullet('当某个标签与目标曲目一致时，该标签会变绿。'),
                bullet('注意：有些曲目可能未添加标签。'),

                // ---------- 开字母 ----------
                if (gameType == GameType.letters) ...[
                  sectionTitle('开字母玩法'),
                  bullet('本回合曲名以 □ 遮蔽，每人可开字母逐字揭示，开出的字母全房间可见。'),
                  bullet('同一个字母只能开一次。'),
                  bullet('猜中某首后，该曲名会对全房间公开完整名称。'),
                  bullet('抢先猜中可能要「送答案」，但每首只给最先猜中的人计分，先猜中仍然划算。'),
                  bullet('把所有曲名都猜中，本回合才结束。'),
                ],

                // ---------- 房间规则 ----------
                sectionTitle('房间规则'),
                bullet('剩余猜测次数是全房间共享的，谁先猜都消耗同一个池子，'
                    '用完本回合即结束。'),
                bullet('投降后本回合不再计分，也无法再提交猜测；但仍可围观其他人继续。'),

                // ---------- 胜负 ----------
                sectionTitle('胜负判定'),
                bullet('全部回合结束后，总分最高的人获胜。'),
                bullet('同分则并列获胜；全场无人得分时算平局。'),
                bullet('分数在每回合结束时结算，排行榜显示的就是结算后的总分。'),
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
  // 处理搜索输入（与单人猜歌页同款：800ms 防抖 + 搜索中状态）
  void _handleSearchInput(String value) {
    _searchTimer?.cancel();

    if (value.isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
        _isSearching = false;
      });
      return;
    }

    _searchTimer = Timer(_searchDelay, () async {
      if (value.isEmpty) return;

      setState(() {
        _isSearching = true;
      });

      final allSongs = await GuessChartByInfoService.loadAllSongs();
      if (!mounted) return;
      if (allSongs != null) {
        final results = await _searchSongs(allSongs, value);
        if (!mounted) return;
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

    // 过滤掉从maidata追加的歌曲（cids全为0表示从maidata解析）
    var filteredSongs = songs.where((song) => !_isMaidataSong(song)).toList();

    // 搜索原曲名
    results.addAll(filteredSongs
        .where((song) => song.basicInfo.title.toLowerCase().contains(query)));

    // 搜索别名
    for (var song in filteredSongs) {
      if (!results.contains(song)) {
        final aliases = _songAliasManager.aliases[song.title];
        if (aliases != null &&
            aliases.any((alias) => alias.toLowerCase().contains(query))) {
          results.add(song);
        }
      }
    }

    return results.take(20).toList();
  }

  // 判断是否是从maidata追加的歌曲（cids全为0表示从maidata解析），或union独有的歌曲
  bool _isMaidataSong(Song song) {
    if (song.isExtra) return true;
    if (song.cids.isEmpty) return false;
    return song.cids.every((cid) => cid == 0);
  }

  // 处理猜测
  Future<void> _handleGuess(Song guessedSong) async {
    if (_isSubmitting) return;
    
    // 检查是否已经猜过这首歌（用 id 字符串比对：宴会场 id 或异常数据下
    // int.parse 会直接抛异常，导致点选即崩）
    final int? guessedId = int.tryParse(guessedSong.id);
    bool hasGuessed = guessedId != null &&
        _guessHistory.any((guess) => guess.songId == guessedId);
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
            guessSong, _targetSong!, Theme.of(context).brightness);
        // 检查是否答对。
        // letters 模式一回合有 songCount 首目标曲（targetSongs），只比对
        // _targetSong（=第一首）会让「猜中第二首」被判成错的；而且猜中任意
        // 一首就把回合标记结束也是错的——letters 要**全部猜中**才结束回合，
        // 且下面的合并逻辑会把本地的 isRoundOver 状态粘住，导致服务端说
        // 「还在继续」时界面上输入框已经消失。
        isCorrect = _isGuessCorrectForCurrentRound(guessedSong.basicInfo.title);
      }

      // 更新本地UI状态
      setState(() {
        // 提交后清空搜索框，让下一次猜测从空输入开始
        _clearSearchInput();

        // 猜测次数以服务端 game_state_updated 为准。原先本地先 +1，再在合并时
        // 与服务端值取较大值，导致「提交被拒绝」时次数也会虚高且无法回退。
        
        // 如果答对了：非 letters 模式本回合就此结束；letters 模式要等
        // 全部猜中，服务端会在最后一首猜中时广播 isRoundOver。
        if (isCorrect && !_isLettersMode) {
          _countdownTimer?.cancel();
          if (_gameState != null) {
            _gameState = _gameState!.copyWith(isRoundOver: true);
          }
        }
      });
      // 猜对即本回合结束：chartPeek 要立刻进入答案模式（等服务器广播会慢一拍）
      if (isCorrect && !_isLettersMode) {
        _enterPeekAnswerModeIfNeeded();
      }

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
      // 上一回合的搜索关键字不能带到下一回合
      _clearSearchInput();
    });
    _resetModeSpecificState();
    _manager.startNextRound();
  }

  void _handleRestartGame() {
    // 开始新一轮游戏
    setState(() {
      _guessHistory.clear();
      _clearSearchInput();
    });
    _resetModeSpecificState();
    _manager.startGame();
  }

  void _handleSettleGame() {
    // 结算游戏，保持游戏结束状态，不再进行新回合
    // 可以添加一些结算逻辑，比如更新最终分数等
    setState(() {
      _isGameSettled = true;
    });
    debugPrint('[DEBUG][GameRoom] 游戏已结算');
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
    final brightness = Theme.of(context).brightness;

    return Column(
      children: _currentRoom!.players.map((player) {
        bool isCurrentPlayer = player.playerId == _manager.currentPlayerId;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isCurrentPlayer
                ? AppColors.successSurface(brightness)
                : (player.isHost
                    ? AppColors.infoSurface(brightness)
                    : Theme.of(context).colorScheme.surfaceContainerHighest),
            borderRadius: BorderRadius.circular(8),
            border: isCurrentPlayer
                ? Border.all(color: AppColors.successGreen(brightness), width: 2)
                : Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _getPlayerDisplayName(player),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: player.isHost ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (isCurrentPlayer) ...[
                          const SizedBox(width: 6),
                          _buildRoleChip('我', AppColors.successForeground(brightness)),
                        ],
                        if (player.isHost) ...[
                          const SizedBox(width: 6),
                          _buildRoleChip('房主', AppColors.infoForeground(brightness)),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        Text('分数: ${_settledScoreOf(player)}',
                            style: const TextStyle(fontSize: 12)),
                        // 显示投降状态（红色）
                        if (player.isSurrendered) ...[
                          const SizedBox(width: 16),
                          Text(
                            '已投降',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.errorRed(brightness),
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
                              color: player.isReady
                                  ? AppColors.successForeground(brightness)
                                  : AppColors.warningOrange(brightness),
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

  // 玩家列表里的「我 / 房主」小徽章
  Widget _buildRoleChip(String label, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: foreground.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: foreground,
        ),
      ),
    );
  }

  Widget _buildGameArea(Brightness brightness) {
    if (_gameState == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sports_esports_outlined,
              size: 44,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              '等待游戏开始...',
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (_gameState!.isGameOver) {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emoji_events, size: 26, color: AppColors.warningOrange(brightness)),
              const SizedBox(width: 8),
              const Text('游戏结束!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          _buildGameResultBanner(brightness),
          const SizedBox(height: 16),
          
          // 显示答案区域（绿色背景）
          if (_targetSong != null)
            Container(
              margin: const EdgeInsets.only(top: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.guessAnswerCardBg(brightness),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _buildAnswerDisplay(),
            ),
          
          const SizedBox(height: 16),
          _buildScoreboard(),
          
          // 游戏未结算时显示房主操作按钮
          if (_currentPlayer?.isHost == true && !_isGameSettled)
            Container(
              margin: const EdgeInsets.only(top: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _handleRestartGame,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    child: const Text('开始新一轮'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _handleSettleGame,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    child: Text('结算游戏', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.flag, size: 22, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              const Text('回合结束!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          
          // 显示当前回合答对的玩家（只显示最新的答对记录）
          _buildRoundWinner(),
          
          // 显示答案区域（绿色背景）
          if (_targetSong != null)
            Container(
              margin: const EdgeInsets.only(top: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.guessAnswerCardBg(brightness),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _buildAnswerDisplay(),
            ),
          
          const SizedBox(height: 16),
          
          // 显示排行榜（放在下一轮按钮之前）
          _buildScoreboard(),
          
          const SizedBox(height: 16),
          
          // 只有房主可以控制下一轮。
          //
          // 只要走到这个分支，就说明回合已经结束了（isRoundOver 为 true），
          // 所以这里**不再**额外要求「超时 / 全投降 / 有人答对」三选一。
          // 原先那三个条件会漏掉「共享猜测次数用完」这种结束方式：服务端已经
          // 结束回合并广播了 isRoundOver，但三个条件一个都不成立，于是房主看不到
          // 「下一轮」按钮（local _isRoundOverByTimeout 只在本地倒计时归零时才置位，
          // 而回合结束后倒计时已被取消，永远不会归零）—— 全房间卡死，谁也走不了。
          // 中途重连/后进房间同理：服务端下发的 timeRemaining 若已是 0，
          // 本地倒计时压根不会启动。
          if (_currentPlayer?.isHost == true)
            ElevatedButton(
              onPressed: _handleNextRound,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              child: const Text('下一轮'),
            ),
        ],
      );
    }

    // 如果当前玩家已投降，显示等待提示
    if (_hasSurrendered) {
      return Column(
        children: [
          const SizedBox(height: 16),
          Icon(
            Icons.hourglass_empty,
            size: 40,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          const Text(
            '已投降，请等待其他玩家……',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 12),

          // 显示剩余时间（给投降玩家看）
          if (_remainingTime > 0)
            Text(
              '⏱️ 剩余时间: $_remainingTime 秒',
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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
        // 回合进度：模式名已由顶栏展示，这里只显示「第几回合/共几回合」。
        if (_gameState != null)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '第 ${_gameState!.currentRound} / ${_gameState!.totalRounds} 回合',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),

        // 模式专属提示（曲绘截取/模糊曲绘/音频播放器）
        _buildModeSpecificHint(),

        // 状态徽章行：倒计时 + 剩余次数。
        // 原先这两条是两行裸文字，和模式提示、搜索框混在一起没有视觉分组，
        // 玩家扫一眼看不到「还剩多少时间/几次机会」。改成带图标的徽章，
        // 并用底色表达危险程度（时间紧迫 / 次数将尽）。
        _buildStatusBadges(brightness),
        
        const SizedBox(height: 16),
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
                    tooltip: '规则说明',
                    icon: Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 24),
                    onPressed: _showRulesDialog,
                  ),
                  const SizedBox(width: 4),
                  // 排序按钮
                  IconButton(
                    tooltip: _isAscending ? '当前：正序，点按切换为倒序' : '当前：倒序，点按切换为正序',
                    icon: Icon(
                      _isAscending
                          ? Icons.sort_by_alpha
                          : Icons.sort_by_alpha_outlined,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                  OutlinedButton(
                    onPressed: _handleSurrender,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('投降'),
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

  Widget _buildSearchField() {
    // 搜索框加一个前置图标，避免它和上面的模式提示糊成一团
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '输入歌曲名称或别名',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchResults = [];
                              _showSearchResults = false;
                              _isSearching = false;
                            });
                          },
                        ),
                ),
                onChanged: _handleSearchInput,
              ),
            ),
          ],
        ),
        // 搜索中状态（与单人猜歌页一致）
        if (_isSearching)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(16),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  /// 状态徽章行：剩余时间 + 剩余猜测次数（房间共享）。
  ///
  /// 两者都是「一眼要知道」的读数，用同一种徽章形态并排显示；进入危险区间
  /// （时间 ≤10 秒 / 次数 ≤3）时整块变底色，比只改文字颜色更容易被注意到。
  Widget _buildStatusBadges(Brightness brightness) {
    final int? guessesLeft = _gameState == null
        ? null
        : _gameState!.maxGuesses - _gameState!.currentGuesses;

    final List<Widget> badges = [];

    if (_remainingTime > 0) {
      final bool urgent = _remainingTime <= 10;
      badges.add(_buildStatusBadge(
        icon: Icons.timer_outlined,
        label: '剩余时间',
        value: '$_remainingTime 秒',
        accent: urgent
            ? AppColors.errorRed(brightness)
            : Theme.of(context).colorScheme.primary,
        background: urgent
            ? AppColors.errorRed(brightness).withValues(alpha: 0.12)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
      ));
    }

    if (guessesLeft != null) {
      final bool low = guessesLeft <= 3;
      badges.add(_buildStatusBadge(
        icon: Icons.search_outlined,
        label: '剩余次数',
        value: '$guessesLeft 次',
        accent: low
            ? AppColors.warningOrange(brightness)
            : Theme.of(context).colorScheme.primary,
        background: low
            ? AppColors.warningOrange(brightness).withValues(alpha: 0.12)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
      ));
    }

    if (badges.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < badges.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Flexible(child: badges[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      constraints: const BoxConstraints(maxHeight: 300),
      child: ListView.builder(
        // ListView 默认会把 MediaQuery 的 viewPadding 当成第一项前的 padding
        // （等于状态栏高度），导致搜索结果顶部多出约半张卡片高的空白
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          return _buildSearchResultItem(_searchResults[index]);
        },
      ),
    );
  }

  Widget _buildSearchResultItem(Song song) {
    final aliases = _songAliasManager.aliases[song.title] ?? [];
    String aliasText = aliases.isNotEmpty ? aliases.join('、') : '';

    return GestureDetector(
      onTap: () => _handleGuess(song),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
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
                    style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (aliasText.isNotEmpty)
                    Text(
                      aliasText,
                      style: TextStyle(fontSize: 14, color: AppColors.linkBlue(Theme.of(context).brightness)),
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
        Text(
          '猜测历史 (${guesses.length})',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
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
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 提交者信息行：把序号做成小圆点，一眼能数出是第几次猜测
              Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$guessNumber',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      guess.playerNickname,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

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
                            color: guessSong.tagBgColors?[i] ?? Colors.grey,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            guessSong.masterTags?[i] ?? '',
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
      
      Song? song;
      for (var s in songs) {
        if (s.id == guess.songId) {
          song = s;
          break;
        }
      }
      if (song == null) return null;
      
      GuessSong guessSong = await GuessChartByInfoService.buildGuessSongEntity(song);
      
      if (_targetSong != null) {
        guessSong = await GuessChartByInfoService.calculateGuessResult(
            guessSong, _targetSong!, Theme.of(context).brightness);
      }
      
      return guessSong;
    } catch (e) {
      return null;
    }
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
        Row(
          children: [
            Icon(Icons.check_circle, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              '本局答案',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
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
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  // 第三行：masterDs | remasterDs | version
                  Text(
                    '${_targetSong!.ds.length > 3 ? _targetSong!.ds[3].toString() : '-'} | ${_targetSong!.ds.length > 4 ? _targetSong!.ds[4].toString() : '-'} | ${StringUtil.formatVersion2WithFlag(_targetSong!.basicInfo.from, _targetSong!.isExtra)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    final brightness = Theme.of(context).brightness;
    final scheme = Theme.of(context).colorScheme;

    // 分数以服务端结算结果为准。
    //
    // 服务端 endRound() 结算分数**之后**只广播 round_over，而 round_over 之前那条
    // room_updated 是在结算前发的（见 server.js 的 endRoundHandler）。也就是说
    // _currentRoom.players 里的分数**永远慢一回合** —— 真机上表现为
    // 「答对了! +62分」横幅下面，排行榜还停在上一回合的 57 分。
    // gameState.players 是结算后的快照，优先用它。
    final Map<String, int> settledScores = {
      for (final p in _gameState?.players ?? const <PlayerEntity>[])
        p.playerId: p.score,
    };
    final Map<String, int> roundGains = _roundScoresByPlayer();

    List<PlayerEntity> sortedPlayers = _currentRoom!.players.map((p) {
      final int? settled = settledScores[p.playerId];
      return settled != null ? p.copyWith(score: settled) : p;
    }).toList()
      // 同分时必须有一个稳定的次序，否则每次重建（倒计时每秒都会触发）
      // 同分玩家的名次会来回跳。Dart 的 List.sort 不保证稳定，
      // 所以显式用「昵称 → playerId」兜底，保证名次固定。
      ..sort((a, b) {
        final int byScore = b.score.compareTo(a.score);
        if (byScore != 0) return byScore;
        final int byName = a.nickname.compareTo(b.nickname);
        if (byName != 0) return byName;
        return a.playerId.compareTo(b.playerId);
      });

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_outlined, size: 20, color: scheme.primary),
            const SizedBox(width: 6),
            Text(
              '排行榜',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...sortedPlayers.asMap().entries.map((entry) {
          final int index = entry.key;
          final PlayerEntity player = entry.value;
          final bool isMe = player.playerId == _manager.currentPlayerId;
          final int gain = roundGains[player.playerId] ?? 0;

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            margin: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: index < 3
                  ? AppColors.podiumSurface(brightness)
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              border: isMe
                  ? Border.all(color: scheme.primary, width: 1.5)
                  : Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                // 名次徽章：前三名用奖牌，其余用序号
                SizedBox(
                  width: 30,
                  child: index < 3
                      ? Text(
                          const ['🥇', '🥈', '🥉'][index],
                          style: const TextStyle(fontSize: 17),
                          textAlign: TextAlign.center,
                        )
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _getPlayerDisplayName(player),
                    style: TextStyle(
                      fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // 本回合增量：让「得分怎么来的」一眼可见
                if (gain > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.successSurface(brightness),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '+$gain',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.successForeground(brightness),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  '${player.score} 分',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  /// 统计本回合每位玩家的得分。
  ///
  /// 口径与服务端 endRound() 保持一致：**每名玩家、每道题只计一次，取最高分**。
  /// 同一首曲子可以被反复提交（letters 模式玩家会重试），直接累加会重复计分；
  /// 服务端正是按 (playerId, matchedSongId) 去重取最大值的，这里按
  /// (playerId, songId) 复刻同一套逻辑，保证界面上的增量之和与总分对得上。
  Map<String, int> _roundScoresByPlayer() {
    final Map<String, int> best = {};
    for (final guess in _gameState?.guesses ?? const <GuessRecord>[]) {
      if (!guess.isCorrect) continue;
      final String key = '${guess.playerId}\u0000${guess.songId}';
      final int prev = best[key] ?? -1;
      if (guess.score > prev) best[key] = guess.score;
    }
    final Map<String, int> totals = {};
    best.forEach((key, score) {
      final String playerId = key.split('\u0000').first;
      totals[playerId] = (totals[playerId] ?? 0) + score;
    });
    return totals;
  }

  // ==================== 模式专属构建器 ====================

  /// 构建别名猜歌提示（alia 模式）
  Widget _buildAliaHint() {
    if (_targetSong == null) return const SizedBox.shrink();

    final aliases = _songAliasManager.findAliasesBySongName(_targetSong!.title);
    final bool isGameOver = _gameState?.isGameOver ?? false;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 图标+标题并排一行，比上下堆叠省一截高度
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.white, size: 20),
                SizedBox(width: 6),
                Text(
                  '别名提示',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (aliases != null && aliases.isNotEmpty) ...[
              // 游戏未结束时只显示别名数量，结束后显示全部别名
              if (!isGameOver) ...[
                Text(
                  '该歌曲共有 ${aliases.length} 个别名',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                // 随机显示1-2个别名作为提示
                ..._getRandomAliasHints(aliases),
              ] else ...[
                // 游戏结束后显示全部别名
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: aliases.map((alias) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      alias,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )).toList(),
                ),
              ],
            ] else
              const Text(
                '暂无别名数据，请根据歌曲信息猜歌',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 从别名列表中随机选取1-2个作为提示（使用确定性种子保证所有玩家一致）
  List<Widget> _getRandomAliasHints(List<String> aliases) {
    if (aliases.isEmpty) return [];

    final roomId = _currentRoom?.roomId ?? '';
    final roundNumber = _gameState?.currentRound ?? 1;
    final targetSongId = _targetSong?.id ?? '';

    final seed = GameSeedUtil.generateSeed(
      roomId: roomId,
      roundNumber: roundNumber,
      targetSongId: targetSongId,
    );
    final random = GameSeedUtil.createRandom(seed);

    // 随机选1-2个别名
    final hintCount = aliases.length == 1 ? 1 : (1 + random.nextInt(2.clamp(1, aliases.length)));
    final shuffled = List<String>.from(aliases)..shuffle(random);
    final hints = shuffled.take(hintCount).toList();

    return hints.map((alias) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.25),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
        ),
        child: Text(
          alias,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    )).toList();
  }

  /// 构建开字母提示（letters 模式）
  ///
  /// 规则（与单机版 GuessSongByOpenLettersPage 一致）：
  /// 开局随机抽取 songCount 首曲目，曲名以 □ 遮蔽；玩家可以「开字母」逐字揭示，
  /// 全部猜中才结束回合。开字母进度由服务端保存并广播，保证所有玩家看到的掩码一致。
  Widget _buildLettersHint() {
    if (_gameState == null) return const SizedBox.shrink();

    final bool isGameOver = _gameState!.isGameOver;
    final bool isRoundOver = _gameState!.isRoundOver;

    // 目标曲目：优先用服务端下发的 targetSongs；旧版服务端只给 currentSong
    final List<dynamic> rawSongs =
        _gameState!.targetSongs.isNotEmpty ? _gameState!.targetSongs : [_targetSong];
    final List<dynamic> targetSongs = rawSongs.where((e) => e != null).toList();
    if (targetSongs.isEmpty) return const SizedBox.shrink();

    final int foundCount = _gameState!.foundSongIds.length;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE17055), Color(0xFFFDCB6E)],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 图标+标题并排一行，比上下堆叠省一截高度
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.text_fields, color: Colors.white, size: 20),
                SizedBox(width: 6),
                Text(
                  '开字母',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // 进度做成白色药丸徽章，比裸文字更醒目
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isGameOver || isRoundOver
                    ? '本回合已结束'
                    : '剩余 ${targetSongs.length - foundCount} / ${targetSongs.length} 首',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),

            // 各曲目的掩码
            ...targetSongs.map((song) {
              // 服务端下发的 targetSongs 是歌曲对象；容错一下，避免结构异常
              // （例如只给了 id 字符串）时整块提示直接抛异常。
              final Map<String, dynamic> map = song is Map
                  ? Map<String, dynamic>.from(song)
                  : <String, dynamic>{'id': song.toString()};
              final String id = (map['id'] ?? '').toString();
              final String title =
                  (map['title'] ?? (map['basic_info']?['title'] ?? '')).toString();
              // 未结束时用服务端掩码；结束后直接显示完整曲名
              final String display = (isGameOver || isRoundOver)
                  ? title
                  : (_gameState!.maskedTitles[id] ??
                      List.filled(title.length, '□').join());
              final bool found = _gameState!.foundSongIds.contains(id);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (found) ...[
                      const Icon(Icons.check_circle,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        display,
                        textAlign: TextAlign.center,
                        // 已猜中的曲名降一档透明度，视觉重心留在还没猜出的掩码上
                        style: TextStyle(
                          color: found ? Colors.white70 : Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

            // 已开字母 + 开字母输入
            if (!isGameOver && !isRoundOver) ...[
              const SizedBox(height: 12),
              if (_gameState!.openedLetters.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        '已开:',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      ..._gameState!.openedLetters.map((letter) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              letter,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )),
                    ],
                  ),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 64,
                    child: TextField(
                      controller: _openLetterController,
                      maxLength: 1,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      decoration: const InputDecoration(
                        counterText: '',
                        isDense: true,
                        hintText: '字',
                        hintStyle: TextStyle(color: Colors.white54),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white54),
                        ),
                      ),
                      onSubmitted: (_) => _handleOpenLetter(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _handleOpenLetter,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFE17055),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('开字母'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 提交开字母（交给服务端判定并广播，保证各端掩码一致）
  void _handleOpenLetter() {
    final String letter = _openLetterController.text.trim();
    if (letter.isEmpty) return;
    if (_manager.currentPlayerId == null) return;

    _manager.openLetter(letter);
    _openLetterController.clear();
  }

  /// 构建模式专属的提示区域（曲绘截取、模糊曲绘、音频播放器）
  Widget _buildModeSpecificHint() {
    if (_targetSong == null || _gameState == null) return const SizedBox.shrink();

    final gameType = _currentRoom?.gameType;
    final roomId = _currentRoom?.roomId ?? '';
    final roundNumber = _gameState!.currentRound;
    final targetSongId = _targetSong!.id;

    switch (gameType) {
      case GameType.cover:
        return _buildCroppedCoverHint(roomId, roundNumber, targetSongId);

      case GameType.blurred:
        return _buildBlurredCoverHint(roomId, roundNumber, targetSongId);

      case GameType.audio:
        return _buildAudioPlayerHint(roomId, roundNumber, targetSongId);

      case GameType.alia:
        return _buildAliaHint();

      case GameType.letters:
        return _buildLettersHint();

      case GameType.flash:
        return _buildFlashCoverHint(targetSongId);

      case GameType.tileReveal:
        return _buildTileRevealHint(roomId, roundNumber, targetSongId);

      case GameType.chartPeek:
        return _buildChartPeekHint(roomId, roundNumber, targetSongId);

      default:
        return const SizedBox.shrink();
    }
  }

  /// 构建曲绘快闪提示（flash 模式）
  ///
  /// 回合开始时整张曲绘显示 flashDurationMs（房间设置，各端一致），随后消失，
  /// 之后只能凭记忆猜 —— 与单人「曲绘快闪猜歌」同一套规则。
  Widget _buildFlashCoverHint(String targetSongId) {
    final bool isGameOver = _gameState?.isGameOver ?? false;
    final bool showCover = isGameOver || _flashVisible;
    final Brightness brightness = Theme.of(context).brightness;

    return Center(
      child: Column(
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isGameOver
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: showCover
                  ? CoverUtil.buildCoverWidgetWithContext(
                      context, targetSongId, 200)
                  : Container(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.visibility_off_outlined,
                        size: 36,
                        color: AppColors.greyHint(brightness),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isGameOver
                ? '本局答案'
                : (_flashVisible ? '快闪中……记住它！' : '曲绘已消失，凭记忆猜歌名'),
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建曲绘拼图提示（tileReveal 模式）
  ///
  /// 揭示顺序用确定性种子（房间 + 回合 + 曲目）生成，所以每个玩家看到的
  /// 已揭示块完全一致；切块数与揭示间隔来自房间设置。
  Widget _buildTileRevealHint(
      String roomId, int roundNumber, String targetSongId) {
    final int tileCount = _currentRoom?.tileCount ?? 1000;
    final bool isGameOver = _gameState?.isGameOver ?? false;

    // 游戏结束：直接给完整曲绘对答案
    if (isGameOver) {
      return Center(
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CoverUtil.buildCoverWidgetWithContext(
                context, targetSongId, 200),
          ),
        ),
      );
    }

    // 本回合首次构建：按确定性种子生成揭示顺序并启动定时揭示
    if (_tileRevealOrder.isEmpty) {
      _tileRevealOrder = GameSeedUtil.generateTileRevealOrder(
        roomId: roomId,
        roundNumber: roundNumber,
        targetSongId: targetSongId,
        tileCount: tileCount,
      );
      _revealedTileCount = 20.clamp(0, tileCount);
      _startTileRevealTimer(tileCount);
    }

    final Set<int> revealedTiles =
        _tileRevealOrder.take(_revealedTileCount).toSet();
    final bool allRevealed = _revealedTileCount >= tileCount;

    return Center(
      child: Column(
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: TileRevealImage(
                songId: targetSongId,
                size: 200,
                tileCount: tileCount,
                revealedTiles: revealedTiles,
                emptyColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '已揭示 $_revealedTileCount / $tileCount 块'
            '${_tileRevealPaused ? '（已暂停）' : ''}',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (!allRevealed)
            TextButton.icon(
              onPressed: _toggleTileRevealPause,
              icon: Icon(
                _tileRevealPaused ? Icons.play_arrow : Icons.pause,
                size: 18,
              ),
              label: Text(_tileRevealPaused ? '继续揭示' : '暂停揭示'),
            ),
        ],
      ),
    );
  }

  /// 启动拼图定时揭示（间隔来自房间设置）
  void _startTileRevealTimer(int tileCount) {
    _tileRevealTimer?.cancel();
    final int intervalMs = _currentRoom?.tileRevealIntervalMs ?? 1500;
    final int batchSize =
        tileCount > 200 ? max(1, (tileCount / 40).round()) : 5;

    _tileRevealTimer = Timer.periodic(Duration(milliseconds: intervalMs), (t) {
      if (!mounted || (_gameState?.isGameOver ?? false)) {
        t.cancel();
        return;
      }
      if (_tileRevealPaused || _revealedTileCount >= tileCount) return;
      setState(() {
        _revealedTileCount =
            (_revealedTileCount + batchSize).clamp(0, tileCount);
      });
      if (_revealedTileCount >= tileCount) t.cancel();
    });
  }

  /// 暂停 / 继续揭示（只影响本机观感，不影响判定）
  void _toggleTileRevealPause() {
    setState(() {
      _tileRevealPaused = !_tileRevealPaused;
    });
  }

  /// 构建谱面片段提示（chartPeek 模式）
  ///
  /// 谱面取自本机 maidata 缓存（没有就按需拉一次），难度池 ∩ 房间定数范围
  /// 用确定性种子挑一个难度，片段窗口同样是确定性种子 —— 三种随机量都加盐隔离，
  /// 保证所有玩家看到同一段谱面。进回合自动播一次，之后可手动复播（每人独立计数）。
  Widget _buildChartPeekHint(
      String roomId, int roundNumber, String targetSongId) {
    final bool isGameOver = _gameState?.isGameOver ?? false;
    final bool isRoundOver = _gameState?.isRoundOver ?? false;
    // 回合结束后进入「答案模式」：与单人一致，可无限复播（音频就绪后带声音）
    final bool answerMode = isGameOver || isRoundOver;

    if (_peekUnavailableReason != null) {
      return Center(
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: Text(
            _peekUnavailableReason!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final SimaiPlayerController? controller = _peekController;
    if (controller == null) {
      // 本回合还没准备好谱面：触发一次（幂等，靠 _peekPreparing 防重入）
      if (!_peekPreparing) {
        _prepareChartPeek(roomId, roundNumber, targetSongId);
      }
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: 12),
            Text(
              '正在准备谱面片段…',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final bool canReplay = answerMode || _peekReplaysLeft > 0;

    // 复播按钮文案（与单人谱面片段猜歌同一套说法）
    final String replayLabel;
    if (_peekPlaying) {
      replayLabel = '暂停';
    } else if (answerMode) {
      if (_peekAnswerAudioFailed) {
        replayLabel = '复播片段（音频不可用）';
      } else if (_peekAnswerAudioReady) {
        replayLabel = '复播片段（带音频）';
      } else {
        replayLabel = '复播片段（音频准备中）';
      }
    } else {
      replayLabel = '复播片段（还可复播 $_peekReplaysLeft 次）';
    }

    final String hintText;
    if (answerMode) {
      hintText = _peekAnswerAudioFailed
          ? '本局答案：片段可无限复播（音频不可用，仅有谱面）'
          : (_peekAnswerAudioReady
              ? '本局答案：片段可无限复播，带音频'
              : '本局答案：片段可无限复播（正在准备音频…）');
    } else {
      hintText = '片段播完会自动停在结尾';
    }

    return Center(
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 220,
              child: SimaiPlayer(controller: controller),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 本回合播放难度的标签（与单人同一套名字与底色）
              if (_peekResolvedInote != null &&
                  GuessChartByChartPeekPage
                      .difficultyNames.containsKey(_peekResolvedInote))
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: GuessChartByChartPeekPage
                            .difficultyColors[_peekResolvedInote] ??
                        Colors.grey,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    GuessChartByChartPeekPage
                            .difficultyNames[_peekResolvedInote] ??
                        '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: canReplay
                    ? (_peekPlaying ? _pausePeek : _replayPeek)
                    : null,
                icon: Icon(
                  (_peekClipFinished || (answerMode && !_peekAnswerAudioFailed))
                      ? Icons.replay
                      : Icons.play_arrow,
                  size: 18,
                ),
                label: Text(replayLabel),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            hintText,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 准备本回合的谱面片段（缓存优先，缺失则按需拉取）
  Future<void> _prepareChartPeek(
      String roomId, int roundNumber, String targetSongId) async {
    _peekPreparing = true;
    try {
      final manager = MaidataManager();
      await manager.initialize();

      String? content = manager.getMaidata(targetSongId);
      if (content == null || content.isEmpty) {
        // 多人抽曲由服务端决定，本机不一定缓存了这首 → 按需拉一次
        await manager.fetchMaidataForSongIds([targetSongId]);
        content = manager.getMaidata(targetSongId);
      }
      if (!mounted) return;
      if (content == null || content.isEmpty) {
        setState(() => _peekUnavailableReason = '本机没有该曲的谱面缓存，自动拉取也没拿到');
        return;
      }

      final simaiFile = SimaiFile(content);
      final Song? song = _targetSong;
      final List<String> pool = _currentRoom?.peekDifficulties ?? const ['4'];
      final List<String> eligible = song == null
          ? const <String>[]
          : GuessChartByChartPeekPage.eligibleInotesFor(
              song: song,
              pool: pool,
              masterMinDx: _currentRoom?.masterMinDx ?? 1.0,
              masterMaxDx: _currentRoom?.masterMaxDx ?? 15.0,
              hasInote: (inote) => content!.contains('&inote_$inote'),
            );
      final String? inote = GameSeedUtil.pickDeterministic(
        roomId: roomId,
        roundNumber: roundNumber,
        targetSongId: targetSongId,
        candidates: eligible,
        salt: 'chartPeekDifficulty',
      );
      if (inote == null) {
        setState(() =>
            _peekUnavailableReason = '这首曲没有符合难度池 / 定数范围的谱面');
        return;
      }

      final String? chartText = simaiFile.getValue('inote_$inote');
      if (chartText == null) {
        setState(() => _peekUnavailableReason = '未能读取该曲 inote_$inote 谱面');
        return;
      }

      final chart = SimaiConvert.deserialize(chartText);

      // 谱面总时长（与单人谱面片段猜歌同口径）
      double totalDuration = chart.finishTiming ?? 0.0;
      for (final collection in chart.noteCollections) {
        if (collection.time.isFinite) {
          totalDuration = max(totalDuration, collection.time);
        }
        for (final note in collection) {
          final holdEnd = collection.time + (note.length ?? 0.0);
          if (holdEnd.isFinite) totalDuration = max(totalDuration, holdEnd);
          for (final slide in note.slidePaths) {
            final slideEnd = collection.time + slide.delay + slide.duration;
            if (slideEnd.isFinite) totalDuration = max(totalDuration, slideEnd);
          }
        }
      }
      if (totalDuration <= 1.0) {
        setState(() => _peekUnavailableReason = '谱面过短，无法截取片段');
        return;
      }

      final double clipLength = min(
        (_currentRoom?.peekDurationSeconds ?? 8).toDouble(),
        max(totalDuration - 1.0, 0.5),
      );
      final ClipWindow window = GameSeedUtil.generateClipWindow(
        roomId: roomId,
        roundNumber: roundNumber,
        targetSongId: targetSongId,
        totalDuration: totalDuration,
        clipLength: clipLength,
      );

      final controller = GuessChartByChartPeekPage.buildChartOnlyController(
        chart: chart,
        initialChartTime: window.start,
      );
      controller.timeNotifier.addListener(_onPeekTimeChanged);
      if (!mounted) {
        controller.dispose();
        return;
      }

      setState(() {
        _peekController = controller;
        _peekClipStart = window.start;
        _peekClipEnd = window.end;
        _peekPlaying = false;
        _peekClipFinished = false;
        _peekResolvedInote = inote;
        _peekChart = chart;
        // 进回合自动播放一次（不计入复播次数）
        _peekReplaysLeft = kPeekMaxReplays;
      });
      _autoPlayPeek();
    } catch (e) {
      debugPrint('[GameRoomPage] chartPeek 准备失败: $e');
      if (mounted) {
        setState(() => _peekUnavailableReason = '谱面解析失败');
      }
    } finally {
      _peekPreparing = false;
    }
  }

  /// 片段到点后自动暂停（停在结尾）
  void _onPeekTimeChanged() {
    final controller = _peekController;
    if (controller == null) return;
    if (controller.chartTime >= _peekClipEnd) {
      controller.pause();
      _peekClipFinished = true;
      if (mounted && _peekPlaying) {
        setState(() => _peekPlaying = false);
      }
    }
  }

  /// 进回合自动播放一次片段
  Future<void> _autoPlayPeek() async {
    final controller = _peekController;
    if (controller == null) return;
    await controller.seek(_peekClipStart);
    await controller.play();
    if (mounted) setState(() => _peekPlaying = true);
  }

  // ==================== chartPeek：回合结束后的答案模式 ====================
  //
  // 照搬单人「谱面片段猜歌」：
  //   1. 回合结束 → 异步取该曲音频（LuoXueSongUtil，自带磁盘缓存）；
  //   2. 用户点复播时，把播放器换成带音频的新实例（音频 position 0 与片段
  //      起点对齐），此后可**无限次**复播，边听边对答案；
  //   3. 音频拿不到就保持无声，界面上如实说明。

  /// 回合结束只进入一次答案模式（服务端多次推送回合结束 / 本地抢先置位都安全）。
  void _enterPeekAnswerModeIfNeeded() {
    if (_peekAnswerModeEntered) return;
    final gameType = _currentRoom?.gameType ?? widget.room.gameType;
    if (gameType != GameType.chartPeek) return;
    _peekAnswerModeEntered = true;
    unawaited(_enterPeekAnswerMode());
  }

  Future<void> _enterPeekAnswerMode() async {
    await _peekController?.pause();
    if (mounted) setState(() => _peekPlaying = false);
    final song = _targetSong;
    if (song == null || _peekChart == null) return;
    // 异步取音频，不阻塞答案展示
    unawaited(_preparePeekAnswerAudio(song));
  }

  Future<void> _preparePeekAnswerAudio(Song song) async {
    try {
      final int musicId = LuoXueSongUtil.toLxnsMusicId(song.id);
      if (musicId <= 0) {
        debugPrint('[GameRoomPage] chartPeek 歌曲 id 异常，答案模式保持无声: ${song.id}');
        if (mounted) setState(() => _peekAnswerAudioFailed = true);
        return;
      }
      final file = await LuoXueSongUtil().getMusicFile(musicId.toString());
      if (!mounted || !_peekAnswerModeEntered) return;
      if (file == null) {
        setState(() => _peekAnswerAudioFailed = true);
        return;
      }
      _peekAnswerAudioPath = file.path;
      setState(() => _peekAnswerAudioReady = true);
      debugPrint('[GameRoomPage] chartPeek 答案音频就绪: ${file.path}');
    } catch (e) {
      debugPrint('[GameRoomPage] chartPeek 答案音频获取失败: $e');
      if (mounted) setState(() => _peekAnswerAudioFailed = true);
    }
  }

  /// 把片段播放器换成带音频的实例并定位到片段起点。
  ///
  /// 对齐原理（与单人一致）：包内音频时钟满足 chartTime = audioPosition + offset，
  /// offset = initialChartTime + musicOffsetMs/1000。答案播放器把 initialChartTime
  /// 设为 0（offset = 0），随后 seek(_clipStart) 会把谱面时间与音频位置一起放到
  /// 片段起点；若沿用 initialChartTime = _clipStart，播出来的是整首歌的开头。
  Future<void> _rebuildPeekPlayerWithAudio() async {
    final chart = _peekChart;
    final path = _peekAnswerAudioPath;
    if (chart == null || path == null || !mounted) return;

    _peekController?.removeListener(_onPeekTimeChanged);
    _peekController?.dispose();

    final controller = GuessChartByChartPeekPage.buildChartOnlyController(
      chart: chart,
      audioFilePath: path,
      initialChartTime: 0,
    );
    setState(() {
      _peekController = controller;
      _peekClipFinished = false;
      _peekAudioAttached = true;
    });
    controller.timeNotifier.addListener(_onPeekTimeChanged);

    // 音频刚交给 game 还在异步加载，等 game 就绪再 seek，
    // 否则 seek 的同步音频分支会因 handle 未建而丢位置。
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted || !identical(_peekController, controller)) return;
    await controller.seek(_peekClipStart);
  }

  /// 手动复播（对局中消耗复播次数；结束后不限次）
  Future<void> _replayPeek() async {
    final controller = _peekController;
    if (controller == null) return;
    final bool isGameOver = _gameState?.isGameOver ?? false;
    final bool isRoundOver = _gameState?.isRoundOver ?? false;
    final bool answerMode = isGameOver || isRoundOver;
    if (!answerMode && _peekReplaysLeft <= 0) {
      Fluttertoast.showToast(msg: '复播次数已用完');
      return;
    }
    if (!answerMode) {
      setState(() => _peekReplaysLeft--);
    }

    if (answerMode && _peekAnswerAudioReady && _peekAnswerAudioPath != null) {
      // 答案模式：第一次复播时换成带音频的播放器（之后复用，不再重建）
      if (!_peekAudioAttached) {
        await _rebuildPeekPlayerWithAudio();
      } else {
        await _peekController?.seek(_peekClipStart);
      }
    } else {
      await controller.seek(_peekClipStart);
    }
    await _peekController?.play();
    if (mounted) setState(() => _peekPlaying = true);
  }

  /// 暂停片段播放
  Future<void> _pausePeek() async {
    await _peekController?.pause();
    if (mounted) setState(() => _peekPlaying = false);
  }

  /// 构建曲绘截取提示（cover 模式）
  Widget _buildCroppedCoverHint(String roomId, int roundNumber, String targetSongId) {
    // 使用确定性种子生成截取区域，确保所有玩家看到相同的截取
    if (_cropRect == null) {
      _cropRect = GameSeedUtil.generateCropRect(
        roomId: roomId,
        roundNumber: roundNumber,
        targetSongId: targetSongId,
      );
    }

    final rect = _cropRect!;
    final double size = 200.0;
    final bool isGameOver = _gameState?.isGameOver ?? false;

    return Center(
      child: Column(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isGameOver
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 完整曲绘
                  CoverUtil.buildCoverWidgetWithContext(context, targetSongId, size),
                  // 游戏未结束时用黑色遮盖非截取区域
                  if (!isGameOver) ...[
                    // 顶部遮盖
                    Positioned(
                      top: 0, left: 0, right: 0,
                      height: rect.y1 * size,
                      child: Container(color: Colors.black),
                    ),
                    // 底部遮盖
                    Positioned(
                      top: rect.y2 * size, left: 0, right: 0, bottom: 0,
                      child: Container(color: Colors.black),
                    ),
                    // 左侧遮盖
                    Positioned(
                      top: rect.y1 * size, left: 0,
                      width: rect.x1 * size,
                      height: (rect.y2 - rect.y1) * size,
                      child: Container(color: Colors.black),
                    ),
                    // 右侧遮盖
                    Positioned(
                      top: rect.y1 * size,
                      left: rect.x2 * size, right: 0,
                      height: (rect.y2 - rect.y1) * size,
                      child: Container(color: Colors.black),
                    ),
                  ],
                  // 游戏结束后用红框标示截取区域
                  if (isGameOver)
                    Positioned(
                      left: rect.x1 * size,
                      top: rect.y1 * size,
                      width: rect.width * size,
                      height: rect.height * size,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.red, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (!isGameOver)
            Text(
              '根据截取的曲绘部分猜歌名',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  /// 构建模糊曲绘提示（blurred 模式）
  Widget _buildBlurredCoverHint(String roomId, int roundNumber, String targetSongId) {
    final int blurLevel = _currentRoom?.blurLevel ?? 50;
    final bool isGameOver = _gameState?.isGameOver ?? false;

    // 使用确定性种子微调模糊程度，确保所有玩家一致
    final int effectiveBlur = GameSeedUtil.generateBlurLevel(
      roomId: roomId,
      roundNumber: roundNumber,
      targetSongId: targetSongId,
      baseBlurLevel: blurLevel,
    );

    return Center(
      child: Column(
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isGameOver
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: isGameOver
                  ? CoverUtil.buildCoverWidgetWithContext(context, targetSongId, 200)
                  : ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(
                        sigmaX: effectiveBlur / 3,
                        sigmaY: effectiveBlur / 3,
                      ),
                      child: CoverUtil.buildCoverWidgetWithContext(context, targetSongId, 200),
                    ),
            ),
          ),
          if (!isGameOver) ...[
            const SizedBox(height: 8),
            Text(
              '模糊程度: $effectiveBlur%',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建音频播放器提示（audio 模式）
  Widget _buildAudioPlayerHint(String roomId, int roundNumber, String targetSongId) {
    final int playDuration = _currentRoom?.playDuration ?? 5;
    final bool isGameOver = _gameState?.isGameOver ?? false;

    return Center(
      child: Container(
        width: 280,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2979FF), Color(0xFF7C4DFF)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 进度条（拖动仅预览位置；音频以服务端种子的起始点整段播放，
            // 不支持 seek 到任意位置——只是把拖动反馈做得更平滑）
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: _currentPosition.clamp(0.0, _totalDuration > 0 ? _totalDuration : playDuration.toDouble()),
                min: 0.0,
                max: _totalDuration > 0 ? _totalDuration : playDuration.toDouble(),
                onChanged: (value) {
                  setState(() {
                    _currentPosition = value;
                  });
                },
                activeColor: Colors.white,
                inactiveColor: Colors.white.withValues(alpha: 0.4),
              ),
            ),
            // 时间显示
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_currentPosition.toStringAsFixed(1)} 秒',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                Text(
                  '${_totalDuration > 0 ? _totalDuration : playDuration} 秒',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 播放/暂停按钮
            ElevatedButton.icon(
              onPressed: isGameOver
                  ? null
                  : (_isPlaying ? _pausePlayback : () => _playSongExcerpt(roomId, roundNumber, targetSongId)),
              icon: Icon(
                isGameOver ? Icons.block : (_isPlaying ? Icons.pause : Icons.play_arrow),
                size: 20,
              ),
              label: Text(
                isGameOver
                    ? '游戏已结束'
                    : (_isPlaying
                        ? '暂停'
                        : (_hasPlayed ? '重新播放' : '播放歌曲片段')),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF2979FF),
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.5),
                disabledForegroundColor: Colors.white54,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 播放歌曲片段（使用确定性起始时间）
  Future<void> _playSongExcerpt(String roomId, int roundNumber, String targetSongId) async {
    if (_targetSong == null) return;

    final int playDuration = _currentRoom?.playDuration ?? 5;

    try {
      setState(() {
        _isPlaying = true;
        _totalDuration = playDuration.toDouble();
        _currentPosition = 0.0;
      });

      // 停止之前的播放
      _playbackTimer?.cancel();
      _positionSubscription?.cancel();
      await _audioPlayer?.stop();
      await _audioPlayer?.dispose();
      _audioPlayer = null;

      // 尝试通过落雪获取音乐文件（id 必须先转成落雪体系，否则 DX 曲 404）
      final luoXueSongUtil = LuoXueSongUtil();
      final int musicId = LuoXueSongUtil.toLxnsMusicId(targetSongId);
      if (musicId <= 0) {
        debugPrint('[GameRoomPage] 歌曲 id 异常，跳过音频播放: $targetSongId');
        return;
      }
      final file = await luoXueSongUtil.getMusicFile(musicId.toString());

      if (file != null) {
        // 获取歌曲时长
        final duration = await luoXueSongUtil.getSongDuration(musicId.toString());
        int totalSongDuration = duration?.inSeconds ?? 180;

        // 使用确定性种子生成音频起始时间，确保所有玩家听到相同的片段
        if (_audioStartTime == null) {
          _audioStartTime = GameSeedUtil.generateAudioStartTime(
            roomId: roomId,
            roundNumber: roundNumber,
            targetSongId: targetSongId,
            totalDuration: totalSongDuration,
            playDuration: playDuration,
          );
        }

        _audioPlayer = AudioPlayer();
        await _audioPlayer!.setSource(DeviceFileSource(file.path));
        await _audioPlayer!.seek(Duration(seconds: _audioStartTime!));
        await _audioPlayer!.play(DeviceFileSource(file.path));

        final playStartTime = DateTime.now();

        _playbackTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
          if (!_isPlaying) {
            timer.cancel();
            return;
          }
          final elapsed = DateTime.now().difference(playStartTime).inMilliseconds / 1000;
          setState(() {
            _currentPosition = elapsed;
          });
          if (elapsed >= playDuration) {
            timer.cancel();
            _handlePlaybackComplete();
          }
        });
      } else {
        // 没有音频文件，模拟播放（仅显示进度条动画）
        debugPrint('[GameRoomPage] 未找到歌曲音频文件，使用模拟播放');
        final playStartTime = DateTime.now();

        _playbackTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
          if (!_isPlaying) {
            timer.cancel();
            return;
          }
          final elapsed = DateTime.now().difference(playStartTime).inMilliseconds / 1000;
          setState(() {
            _currentPosition = elapsed;
          });
          if (elapsed >= playDuration) {
            timer.cancel();
            _handlePlaybackComplete();
          }
        });
      }
    } catch (e) {
      debugPrint('[GameRoomPage] 播放歌曲失败: $e');
      _handlePlaybackComplete();
    }
  }

  void _handlePlaybackComplete() {
    _playbackTimer?.cancel();
    _positionSubscription?.cancel();
    _audioPlayer?.stop();
    setState(() {
      _isPlaying = false;
      _hasPlayed = true;
      _currentPosition = _totalDuration;
    });
  }

  void _pausePlayback() {
    _playbackTimer?.cancel();
    _positionSubscription?.cancel();
    _audioPlayer?.pause();
    setState(() {
      _isPlaying = false;
    });
  }

  /// 在新回合开始时重置模式专属状态
  /// 清空搜索框与搜索结果（换回合 / 开始新游戏时调用）。
  ///
  /// 为什么必须清：输入框里留着上一回合的关键字时，新回合的候选列表会被旧
  /// 关键字过滤，玩家看到「搜不出歌」，或者以为要重新输入而耽误抢答——
  /// 结果就是白白丢掉一次获胜机会。
  void _clearSearchInput() {
    if (_searchController.text.isNotEmpty) {
      _searchController.clear();
    }
    _searchResults = [];
    _showSearchResults = false;
  }

  void _resetModeSpecificState() {
    _openLetterController.clear();
    _cropRect = null;
    _audioStartTime = null;
    _isPlaying = false;
    _hasPlayed = false;
    _currentPosition = 0.0;
    _totalDuration = 0.0;
    _playbackTimer?.cancel();
    _positionSubscription?.cancel();
    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    _audioPlayer = null;

    // flash：回合开始就闪现一次（时长来自房间设置，各端一致）
    _flashTimer?.cancel();
    _flashVisible = false;
    _startFlashCover();

    // tileReveal：顺序/进度由题面构建时按确定性种子惰性初始化
    _tileRevealTimer?.cancel();
    _tileRevealOrder = const [];
    _revealedTileCount = 0;
    _tileRevealPaused = false;

    // chartPeek：谱面片段（控制器、窗口、复播次数、答案模式）
    _peekController?.timeNotifier.removeListener(_onPeekTimeChanged);
    _peekController?.dispose();
    _peekController = null;
    _peekClipStart = 0.0;
    _peekClipEnd = 0.0;
    _peekPlaying = false;
    _peekPreparing = false;
    _peekClipFinished = false;
    _peekUnavailableReason = null;
    _peekReplaysLeft = kPeekMaxReplays;
    _peekResolvedInote = null;
    _peekChart = null;
    _peekAnswerModeEntered = false;
    _peekAnswerAudioReady = false;
    _peekAnswerAudioFailed = false;
    _peekAudioAttached = false;
    _peekAnswerAudioPath = null;
  }

  /// 回合开始时的曲绘快闪：先显示，flashDurationMs 之后消失。
  void _startFlashCover() {
    final GameType gameType = _currentRoom?.gameType ?? widget.room.gameType;
    if (gameType != GameType.flash) return;

    final int flashDurationMs = _currentRoom?.flashDurationMs ?? 300;
    _flashVisible = true;
    _flashTimer = Timer(Duration(milliseconds: flashDurationMs), () {
      if (!mounted) return;
      setState(() => _flashVisible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final screenWidth = MediaQuery.of(context).size.width;
    final scaleFactor = screenWidth / 375.0;
    final paddingS = 4.0 * scaleFactor;
    final paddingM = 12.0 * scaleFactor;
    final paddingL = 10.0 * scaleFactor;
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
                      tooltip: '离开房间',
                      icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
                      onPressed: _showLeaveRoomConfirmDialog,
                    ),
                    // 标题
                    Expanded(
                      child: Center(
                        child: Text(
                          _currentRoom?.gameType.name ?? '多人猜歌',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: screenWidth * 0.05,
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
                    color: AppColors.infoSurface(brightness),
                    borderRadius: BorderRadius.circular(borderRadiusSmall),
                    border: Border.all(color: AppColors.infoForeground(brightness), width: 1),
                  ),
                  child: Center(
                    child: Text(
                      _hostChangeMessage!,
                      style: TextStyle(
                        color: AppColors.infoForeground(brightness),
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
                    color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(borderRadiusSmall),
                    boxShadow: [AppConstants.defaultShadow(brightness)],
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(paddingM),
                    child: Padding(
                      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + paddingL),
                      child: Column(
                        children: [
                          // 房间码显示
                          // 注意：底色不要用 colorScheme.onSurface。
                          // 暗色主题下 onSurface 是近白色，配下面这组白色文字就是
                          // 「白底白字」，房间码完全读不出来。改用 primary/onPrimary
                          // 这一对，浅色与暗色主题都有保证的对比度。
                          Container(
                            padding: EdgeInsets.symmetric(vertical: paddingS, horizontal: paddingM),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(borderRadiusSmall),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.key,
                                        color: Theme.of(context).colorScheme.onPrimary,
                                        size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      '房间码:',
                                      style: TextStyle(
                                          color: Theme.of(context).colorScheme.onPrimary,
                                          fontSize: 14),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _currentRoom?.roomCode ?? '-',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onPrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                                // 当前人数/房间人数上限
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimary
                                        .withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.people,
                                          color: Theme.of(context).colorScheme.onPrimary,
                                          size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${_currentRoom?.players.length ?? 0}/${_currentRoom?.maxPlayers ?? 4}',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onPrimary,
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
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              ),
                              child: const Text('开始游戏'),
                            ),
                          SizedBox(height: paddingL * 1.5),
                          _buildGameArea(brightness),
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
