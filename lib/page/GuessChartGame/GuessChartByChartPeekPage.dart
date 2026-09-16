import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simai_flutter/simai_flutter.dart';
import 'package:my_first_flutter_app/entity/DivingFish/Song.dart';
import 'package:my_first_flutter_app/entity/GuessChartGame/GuessSong.dart';
import 'package:my_first_flutter_app/manager/MaidataManager.dart';
import 'package:my_first_flutter_app/manager/SongAliasManager.dart';
import 'package:my_first_flutter_app/service/GuessChartGame/GuessChartByInfoService.dart';
import 'package:my_first_flutter_app/service/GuessChartGame/GuessChartCommonSettingsService.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:my_first_flutter_app/utils/CoverUtil.dart';
import 'package:my_first_flutter_app/utils/CommonCacheUtil.dart';
import 'package:my_first_flutter_app/utils/StringUtil.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:my_first_flutter_app/utils/LuoXueSongUtil.dart';
import 'package:my_first_flutter_app/utils/PlayerThemeScope.dart';
import 'package:my_first_flutter_app/utils/RefreshRateUtil.dart';
import 'package:my_first_flutter_app/page/SongInfoPage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:my_first_flutter_app/constant/VersionListConstant.dart';

/// 谱面片段猜歌（看谱猜歌）：从已缓存 maidata 的曲库中随机选一首，
/// 随机截取一段 N 秒的谱面片段，**无声**播放谱面动画，凭「看谱」猜出歌名。
///
/// 防剧透设计：不使用 SimaiPlayerPage（带标题栏 / 进度条 / 设置抽屉，
/// 标题会直接把答案写在脸上），而是用裸的 [SimaiPlayer]（谱面渲染层）+
/// 自制的播放/暂停/复播控件。整个片段窗口内无法拖动进度。
class GuessChartByChartPeekPage extends StatefulWidget {
  const GuessChartByChartPeekPage({super.key});

  /// 定数范围筛选的**纯函数**核心（不依赖 maidata 缓存，便于单测）。
  ///
  /// 本模式按「难度随机池」抽谱，定数范围作用于**池内各难度自己的定数**，
  /// 而不是 MASTER 的定数 —— 池子可能只选了 EXPERT，拿 MASTER 定数筛
  /// 会与实际抽谱行为对不上。
  ///
  /// 定数下标：`ds[inote - 2]`。ds 数组 0..4 依次是 BASIC..Re:MASTER，
  /// 也就是 inote 2..6 各减 2（`ds[3]` = MASTER，已由
  /// GuessChartByInfoService 的 `ds.length > 3 ? ds[3] : ''` 用法证实）。
  ///
  /// [hasInote] 判断该难度是否真的有谱面；传回调而非缓存，方便单测构造场景。
  static List<String> eligibleInotesFor({
    required Song song,
    required List<String> pool,
    required double masterMinDx,
    required double masterMaxDx,
    required bool Function(String inote) hasInote,
  }) {
    final result = <String>[];
    for (final inote in pool) {
      // 该难度必须真的有谱面，否则选了也播不出来
      if (!hasInote(inote)) continue;
      final inoteNum = int.tryParse(inote);
      if (inoteNum == null) continue;
      final dsIndex = inoteNum - 2;
      if (dsIndex < 0 || dsIndex >= song.ds.length) continue;
      final dx = song.ds[dsIndex];
      if (dx >= masterMinDx && dx <= masterMaxDx) result.add(inote);
    }
    return result;
  }

  /// 建一个「只有谱面」的播放器控制器。
  ///
  /// 本页是猜歌题面，除了谱面之外的一切叠加信息都属于**剧透**，必须关掉：
  /// - `showCornerInfo`（四角）：BPM / 时间 / COMBO / BREAK 等状态文字。
  ///   其中 BPM、BREAK 数量、总物量都能反推曲目，留在题面上等于送答案。
  /// - `showAchievementRate`（中间）：达成率大数字（`centerDisplayMode`
  ///   默认是 achievement）。关掉后中间整块不再渲染。
  ///
  /// 顺带对齐官方做法：包的 gameplay 模式同样是
  /// `showAchievementRate: false, showCornerInfo: false`（见其 gameplay_pages）。
  ///
  /// 注意这两个是**控制器 setter**，不是构造参数，所以必须建完再赋值；
  /// 而对局中与答案模式会各建一次控制器，因此收敛到这个工厂，
  /// 避免只改一处、另一处又漏出叠加信息。
  static SimaiPlayerController buildChartOnlyController({
    required MaiChart chart,
    required double initialChartTime,
    String? audioFilePath,
  }) {
    final controller = SimaiPlayerController(
      chart: chart,
      audioFilePath: audioFilePath,
      initialChartTime: initialChartTime,
    );
    controller.showCornerInfo = false;
    controller.showAchievementRate = false;
    return controller;
  }

  @override
  State<GuessChartByChartPeekPage> createState() =>
      _GuessChartByChartPeekPageState();
}

class _GuessChartByChartPeekPageState extends State<GuessChartByChartPeekPage> {
  // 游戏状态
  bool _isGameStarted = false;
  Song? _targetSong;
  List<GuessSong> _guessHistory = [];
  int _guessCount = 0;
  int _maxGuesses = 10;
  int _timeLimit = 0; // 0 表示无限制
  bool _isGameOver = false;
  bool _isWon = false;

  // 倒计时相关
  int _remainingTime = 0;
  Timer? _countdownTimer;

  // 谱面片段相关
  int _peekDurationSeconds = 8; // 片段时长（从设置中加载）
  List<String> _peekDifficulties = ['4']; // 难度随机池（inote 编号，从设置中加载）
  String? _resolvedDifficulty; // 本局实际播放的难度（inote 编号）
  String _unavailableReason = ''; // 谱面区不可用时的提示文案
  static const Map<String, String> _difficultyNames = {
    '2': 'BASIC',
    '3': 'ADVANCED',
    '4': 'EXPERT',
    '5': 'MASTER',
    '6': 'Re:MASTER',
  };
  // 难度标签底色（与 SongMaidataPageService.inoteColorMap 同一套值）
  static const Map<String, Color> _difficultyColors = {
    '2': Color(0xFF4CAF50), // BASIC - 绿色
    '3': Color(0xFFFF9800), // ADVANCED - 橙色
    '4': Color(0xFFF44336), // EXPERT - 红色
    '5': Color(0xFF9C27B0), // MASTER - 紫色
    '6': Color(0xFFCE93D8), // Re:MASTER - 淡紫色
  };
  static const int _maxReplays = 3; // 复播次数上限
  int _replaysLeft = _maxReplays;
  bool _clipFinished = false; // 片段是否已播放完毕
  bool _clipStarted = false; // 片段是否已开始过（首次显示「播放」）
  double _clipStart = 0.0; // 片段起点（谱面时间，秒）
  double _clipEnd = 0.0; // 片段终点
  String _maidataContent = '';
  SimaiPlayerController? _playerController;
  // 游戏结束后把播放器换成带音频的实例（复用同一份谱面），
  // 复播时可以听着音乐对答案；音频尚未就绪前保持无声
  MaiChart? _answerChart;
  bool _answerAudioReady = false;
  bool _answerAudioFailed = false;
  String? _answerAudioPath;

  // 设置相关
  List<String> _selectedVersions = [];
  double _masterMinDx = 1.0;
  double _masterMaxDx = 15.0;
  List<String> _selectedGenres = [];
  late GuessChartCommonSettingsService _settingsService;

  // 搜索状态
  TextEditingController _searchController = TextEditingController();
  List<Song> _searchResults = [];
  bool _isSearching = false;
  Timer? _searchTimer;
  static const Duration _searchDelay = Duration(milliseconds: 800);
  bool _showSearchResults = false;

  // 排序状态
  bool _isAscending = true;

  // 歌曲别名管理器
  late SongAliasManager _songAliasManager;

  // 统计数据
  Map<String, dynamic> _stats = {
    'correct': 0,
    'wrong': 0,
    'accuracy': 0.0,
    'avgTime': 0.0,
  };

  // 缓存工具
  final _cacheUtil = CommonCacheUtil();

  // 游戏时间记录
  DateTime? _gameStartTime;

  @override
  void initState() {
    super.initState();
    _songAliasManager = SongAliasManager.instance;
    _settingsService = GuessChartCommonSettingsService();
    // 谱面渲染是黑底，沿用播放页的深色主题强制，避免闪一帧浅色
    PlayerThemeScope.forceDarkTheme.value = true;
    // 谱面滚动对帧率敏感
    RefreshRateUtil.requestMax();
    _loadSettings();
    _initCache();
    _initGame();
  }

  // 初始化缓存
  Future<void> _initCache() async {
    await _cacheUtil.initCache('9');
    await _loadStats();
  }

  // 加载统计数据
  Future<void> _loadStats() async {
    final stats = await _cacheUtil.getStats('9');
    setState(() {
      _stats = Map.from(stats);
    });
  }

  // 重置并刷新统计数据
  Future<void> _resetAndRefreshStats() async {
    await _cacheUtil.resetStats('9');
    final stats = await _cacheUtil.getStats('9');
    setState(() {
      _stats = Map.from(stats);
    });
  }

  // 加载设置
  Future<void> _loadSettings() async {
    final settings = await _settingsService.loadSettings();
    setState(() {
      _selectedVersions = settings['selectedVersions'] ?? [];
      _masterMinDx = settings['masterMinDx'] ?? 1.0;
      _masterMaxDx = settings['masterMaxDx'] ?? 15.0;
      _selectedGenres = settings['selectedGenres'] ?? [];
      _maxGuesses = settings['maxGuesses'] ?? 10;
      _timeLimit = settings['timeLimit'] ?? 0;
      _peekDurationSeconds = settings['peekDurationSeconds'] ?? 8;
      final loadedDifficulties =
          (settings['peekDifficulties'] as List?)?.cast<String>() ?? ['4'];
      // 过滤非法值，且池子为空时退回默认，保证每局都能抽到难度
      _peekDifficulties = loadedDifficulties
          .where((d) => _difficultyNames.containsKey(d))
          .toList();
      if (_peekDifficulties.isEmpty) _peekDifficulties = ['4'];
    });
  }

  @override
  void dispose() {
    PlayerThemeScope.forceDarkTheme.value = false;
    RefreshRateUtil.restore();
    _searchController.dispose();
    _searchTimer?.cancel();
    _countdownTimer?.cancel();
    _playerController?.removeListener(_onChartTimeChanged);
    _playerController?.removeListener(_scheduleNothing);
    _playerController?.dispose();
    super.dispose();
  }

  // 控制器监听占位：SimaiPlayerController 是 ChangeNotifier，
  // 我们不基于 setter 的 notifyListeners 做任何事（片段边界用 timeNotifier），
  // 这里仅声明一个可移除的监听引用；真正生效的是 _onChartTimeChanged。
  void _scheduleNothing() {}

  // 初始化游戏
  Future<void> _initGame() async {
    await _songAliasManager.init();
    await MaidataManager().initialize();
    await _startNewGame();
  }

  // 开始新游戏：随机选一首「曲库中有谱面缓存」的歌
  Future<void> _startNewGame() async {
    _countdownTimer?.cancel();

    await _loadSettings();

    setState(() {
      _isGameStarted = false;
      _isGameOver = false;
      _isWon = false;
      _guessHistory = [];
      _guessCount = 0;
      _searchController.clear();
      _searchResults = [];
      _showSearchResults = false;
      _remainingTime = _timeLimit;
      _gameStartTime = DateTime.now();
      _clipFinished = false;
      _clipStarted = false;
      _replaysLeft = _maxReplays;
      _resolvedDifficulty = null;
      _unavailableReason = '';
      _answerChart = null;
      _answerAudioReady = false;
      _answerAudioFailed = false;
      _answerAudioPath = null;
      _maidataContent = '';
      _eligibleInotesForRound = [];
    });

    _teardownPlayer();

    // 曲池：全曲库（非宴会场、非 extra）∩ 已缓存 maidata 谱面
    // ∩ 难度池内存在谱面 **且该难度定数落在设置范围内**
    final maidataManager = MaidataManager();
    if (!maidataManager.isCacheReady) {
      if (mounted) {
        setState(() {
          _isGameStarted = true;
          _unavailableReason = '谱面缓存为空，请先在谱面库中缓存 maidata';
        });
      }
      return;
    }

    final candidates = (await _collectCandidates(
      selectedVersions: _selectedVersions,
      selectedGenres: _selectedGenres,
      pool: _peekDifficulties,
      masterMinDx: _masterMinDx,
      masterMaxDx: _masterMaxDx,
    ))
      ..shuffle(Random());

    _targetSong = candidates.isEmpty ? null : candidates.first;
    if (_targetSong == null) {
      if (mounted) {
        setState(() {
          _isGameStarted = true;
          _unavailableReason = '没有符合当前筛选条件（难度池 / 定数范围）且有谱面缓存的歌曲';
        });
      }
      return;
    }

    // 定下本局可用难度，供 _buildClip 随机挑选（与抽歌判定同源）
    _eligibleInotesForRound = _eligibleInotes(
      maidataManager: maidataManager,
      song: _targetSong!,
      pool: _peekDifficulties,
      masterMinDx: _masterMinDx,
      masterMaxDx: _masterMaxDx,
    );

    _maidataContent =
        maidataManager.getMaidata(_targetSong!.id) ?? '';

    if (_maidataContent.isEmpty) {
      if (mounted) {
        setState(() {
          _isGameStarted = true;
          _unavailableReason = '未能读取该歌曲的谱面内容';
        });
      }
      return;
    }

    if (!mounted) return;
    await _buildClip();
  }

  /// 取一首歌「难度池内、有谱面、且定数落在设置范围内」的 inote 列表。
  ///
  /// 本模式的定数范围作用于**难度池里的每个难度各自的定数**，而不是
  /// MASTER 的定数 —— 池子是用户自己挑的（可能只选 EXPERT + MASTER），
  /// 拿 MASTER 定数去筛会与「按池抽谱」的实际行为对不上。
  ///
  /// 定数下标：`ds[inote - 2]`。ds 数组 0..4 依次是 BASIC..Re:MASTER，
  /// 即 inote 2..6 各减 2（`ds[3]` = MASTER 已被 GuessChartByInfoService
  /// 等处的 `ds.length > 3 ? ds[3] : ''` 用法证实）。
  ///
  /// 参数显式传入，好让「抽歌」与「设置校验」用同一套判定，
  /// 避免出现「校验说能抽到、开局却抽不到」。
  static List<String> _eligibleInotes({
    required MaidataManager maidataManager,
    required Song song,
    required List<String> pool,
    required double masterMinDx,
    required double masterMaxDx,
  }) {
    final content = maidataManager.getMaidata(song.id);
    if (content == null || content.isEmpty) return const [];
    return GuessChartByChartPeekPage.eligibleInotesFor(
      song: song,
      pool: pool,
      masterMinDx: masterMinDx,
      masterMaxDx: masterMaxDx,
      hasInote: (inote) => content.contains('&inote_$inote'),
    );
  }

  /// 按给定条件算一次曲池：全曲库（非宴会场、非 extra）∩ 版本 ∩ 流派
  /// ∩ 难度池内存在且定数在范围内。抽歌与设置校验共用。
  static Future<List<Song>> _collectCandidates({
    required List<String> selectedVersions,
    required List<String> selectedGenres,
    required List<String> pool,
    required double masterMinDx,
    required double masterMaxDx,
  }) async {
    final maidataManager = MaidataManager();
    final songs = await GuessChartByInfoService.loadAllSongs();
    if (songs == null || songs.isEmpty || !maidataManager.isCacheReady) {
      return const [];
    }
    return songs
        .where((song) =>
            song.id.length != 6 &&
            !song.isExtra &&
            song.basicInfo.title.isNotEmpty &&
            maidataManager.hasCachedMaidata(song.id) &&
            (selectedVersions.isEmpty ||
                selectedVersions.contains(song.basicInfo.from)) &&
            (selectedGenres.isEmpty ||
                selectedGenres.contains(song.basicInfo.genre)) &&
            _eligibleInotes(
              maidataManager: maidataManager,
              song: song,
              pool: pool,
              masterMinDx: masterMinDx,
              masterMaxDx: masterMaxDx,
            ).isNotEmpty)
        .toList();
  }

  /// 本局可用的 inote（选定曲目后算出），`_buildClip` 从中随机挑一个难度。
  List<String> _eligibleInotesForRound = [];

  // 解析谱面、随机截取片段并创建播放器
  Future<void> _buildClip() async {
    try {
      final simaiFile = SimaiFile(_maidataContent);

      // 从「难度池 ∩ 定数范围内」随机挑一个难度。
      // 抽歌环节已保证该集合非空（_eligibleInotes），
      // 这里**不做**池外/范围外回退——回退会静默播放用户没选的难度。
      final pool = List<String>.from(_eligibleInotesForRound)
        ..shuffle(Random());
      String? chartText;
      String? resolvedInote;
      for (final inoteNum in pool) {
        chartText = simaiFile.getValue('inote_$inoteNum');
        if (chartText != null) {
          resolvedInote = inoteNum;
          break;
        }
      }
      if (chartText == null) {
        debugPrint('[ChartPeek] 歌曲没有难度池内的谱面（应为不可能路径）');
        if (mounted) {
          setState(() {
            _isGameStarted = true;
            _unavailableReason = '该歌曲没有难度池内的谱面';
          });
        }
        return;
      }
      debugPrint('[ChartPeek] 使用难度 inote_$resolvedInote 播放片段');

      final chart = SimaiConvert.deserialize(chartText);
      // 留一份谱面引用，游戏结束后重建带音频的播放器用
      _answerChart = chart;

      // 谱面内容结束时间（与 SimaiPlayerController 内部同口径）
      double totalDuration = chart.finishTiming ?? 0.0;
      for (final collection in chart.noteCollections) {
        if (collection.time.isFinite) {
          totalDuration = max(totalDuration, collection.time);
        }
        for (final note in collection) {
          final holdEnd = collection.time + (note.length ?? 0.0);
          if (holdEnd.isFinite) totalDuration = max(totalDuration, holdEnd);
          for (final slide in note.slidePaths) {
            final slideEnd =
                collection.time + slide.delay + slide.duration;
            if (slideEnd.isFinite) totalDuration = max(totalDuration, slideEnd);
          }
        }
      }

      if (totalDuration <= 1.0) {
        debugPrint('[ChartPeek] 谱面过短，无法截取片段');
        if (mounted) {
          setState(() {
            _isGameStarted = true;
            _unavailableReason = '谱面过短，无法截取片段';
          });
        }
        return;
      }

      // 随机截取片段窗口；片段长度不超过谱面长度
      final double clipLength =
          min(_peekDurationSeconds.toDouble(), max(totalDuration - 1.0, 0.5));
      final double latestStart = max(totalDuration - clipLength, 0.0);
      _clipStart = latestStart <= 0 ? 0.0 : Random().nextDouble() * latestStart;
      _clipEnd = min(_clipStart + clipLength, totalDuration);

      // 无音频：走帧时钟，天然无声；且只保留谱面（关掉四角与中间信息）
      final controller =
          GuessChartByChartPeekPage.buildChartOnlyController(
        chart: chart,
        initialChartTime: _clipStart,
      );

      if (!mounted) {
        controller.dispose();
        return;
      }

      setState(() {
        _playerController = controller;
        _resolvedDifficulty = resolvedInote;
        _isGameStarted = true;
      });

      // 监听谱面时间：到达片段终点自动暂停（不依赖音频时钟）
      controller.timeNotifier.addListener(_onChartTimeChanged);

      // 游戏正式开始，启动倒计时
      _startCountdown();
    } catch (e) {
      debugPrint('[ChartPeek] 构建片段失败: $e');
      if (mounted) {
        setState(() {
          _isGameStarted = true;
          _unavailableReason = '谱面解析失败';
        });
      }
    }
  }

  // 片段时间监听：无论对局中还是游戏结束后，越过片段终点都暂停并标记结束
  // （答案模式的复播也只播本局截取的片段，不播到谱面结尾）
  void _onChartTimeChanged() {
    final time = _playerController?.timeNotifier.value ?? 0.0;
    if (_clipFinished) return;
    if (time >= _clipEnd) {
      _clipFinished = true;
      _playerController?.pause();
      if (mounted) setState(() {});
    }
  }

  // 播放 / 暂停片段。
  // 对局中：复播最多 _maxReplays 次（回卷到片段起点，无声）。
  // 游戏结束后：无限次复播，同样只播本局截取的片段；音频就绪时先重建带音频的播放器再播放。
  Future<void> _togglePlayPause() async {
    final controller = _playerController;
    if (controller == null) return;

    if (controller.isPlaying) {
      await controller.pause();
      if (mounted) setState(() {});
      return;
    }

    // 片段播完后的重播：回卷到片段起点
    if (_clipFinished || controller.chartTime >= _clipEnd) {
      if (_isGameOver) {
        // 答案模式：无限复播
        _clipFinished = false;
        if (_answerAudioReady && _answerAudioPath != null) {
          // 重建带音频的播放器并定位到片段起点；
          // 音频尚未定位好时短暂等待，避免带着 position 0 开播
          await _rebuildPlayerWithAudio();
        } else {
          await controller.seek(_clipStart);
        }
      } else {
        if (_replaysLeft <= 0) return;
        _replaysLeft--;
        _clipFinished = false;
        await controller.seek(_clipStart);
      }
    }

    _clipStarted = true;
    await _playerController?.play();
    if (mounted) setState(() {});
  }

  // 复播剩余次数的显示文案
  String get _replayLabel => _replaysLeft > 0 ? '（还可复播 $_replaysLeft 次）' : '（复播次数已用完）';

  // 音频就绪后重建播放器：停在片段开头等待用户播放。
  // SimaiPlayer 检测到新 controller 实例会重建内部 game，
  // 新实例以 audioFilePath 初始化，播放即带音频。
  //
  // 对齐原理：包内音频时钟满足 chartTime = audioPosition + offset，
  // 其中 offset = initialChartTime + musicOffsetMs/1000。
  // 答案播放器把 initialChartTime 设为 0（offset = 0），随后
  // seek(_clipStart) 会同时把谱面时间与音频位置都放到 _clipStart——
  // 音频正好从片段对应的原曲位置开始播。
  // 若沿用 initialChartTime = _clipStart，音频 position 0 就对应
  // chartTime = _clipStart，播出来的是整首歌的开头而不是片段。
  Future<void> _rebuildPlayerWithAudio() async {
    final chart = _answerChart;
    final path = _answerAudioPath;
    if (chart == null || path == null || !mounted) return;

    _playerController?.removeListener(_onChartTimeChanged);
    _playerController?.removeListener(_scheduleNothing);
    _playerController?.dispose();

    // 答案模式同样只保留谱面（关掉四角与中间信息）
    final controller = GuessChartByChartPeekPage.buildChartOnlyController(
      chart: chart,
      audioFilePath: path,
      initialChartTime: 0,
    );
    setState(() {
      _playerController = controller;
      _clipFinished = false;
      _clipStarted = false;
    });
    controller.timeNotifier.addListener(_onChartTimeChanged);

    // 把谱面时间与音频位置一起定位到片段起点。
    // 音频文件刚交给 game 还在异步加载，so 先等 game 就绪再 seek，
    // 否则 seek 的同步音频分支会因 _hasAudio 时 handle 未建而丢位置。
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted || !identical(_playerController, controller)) return;
    await controller.seek(_clipStart);
  }

  // 启动倒计时
  void _startCountdown() {
    if (_timeLimit <= 0) return;

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isGameOver) {
        timer.cancel();
        return;
      }
      if (_remainingTime > 0) {
        setState(() {
          _remainingTime--;
        });
        return;
      }
      // 超时：同样要走 _endRound（原先这里只置 _isGameOver，
      // 漏了 _enterAnswerMode → 答案模式复播没声音）
      timer.cancel();
      unawaited(_endRound(isWon: false));
    });
  }

  // 记录游戏结果
  Future<void> _recordGameResult(bool isWon) async {
    if (_gameStartTime == null) return;
    final gameTime = DateTime.now().difference(_gameStartTime!).inSeconds;

    if (isWon) {
      await _cacheUtil.recordSuccess('9');
    } else {
      await _cacheUtil.recordFailure('9');
    }
    await _cacheUtil.settleGame('9', gameTime);
    await _loadStats();
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

    var filteredSongs = songs
        .where((song) => !song.isExtra && !_isMaidataSong(song))
        .toList();

    results.addAll(filteredSongs
        .where((song) => song.basicInfo.title.toLowerCase().contains(query)));

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
    if (_isGameOver || _targetSong == null) return;

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
      _searchController.clear();
      _searchResults = [];
      _showSearchResults = false;
      return;
    }

    var guessSong =
        await GuessChartByInfoService.buildGuessSongEntity(guessedSong);
    guessSong = await GuessChartByInfoService.calculateGuessResult(
        guessSong, _targetSong!, Theme.of(context).brightness);

    setState(() {
      _guessHistory.add(guessSong);
      _guessCount++;
      _searchController.clear();
      _searchResults = [];
      _showSearchResults = false;
    });

    if (guessedSong.basicInfo.title == _targetSong!.basicInfo.title) {
      await _endRound(isWon: true);
    } else if (_maxGuesses > 0 && _guessCount >= _maxGuesses) {
      await _endRound(isWon: false);
    }
  }

  // 游戏结束后的「答案模式」：复播不再限次，时间监听不再自动暂停——
  // 可以完整播放到谱面结尾。音频通过落雪音源异步准备（LuoXueSongUtil 自带
  // 磁盘缓存）：就绪前谱面照常无声播放（帧时钟），就绪后重建带音频的
  // 播放器（音频 position 0 与片段起点对齐），下载失败则保持无声。
  Future<void> _enterAnswerMode() async {
    final controller = _playerController;
    await controller?.pause();
    final song = _targetSong;
    if (song == null || _answerChart == null) return;

    // 异步取音频，不阻塞答案展示
    unawaited(_prepareAnswerAudio(song));
  }

  /// 统一的「结束本局」入口：置结束标记 + 进入答案模式（准备音频）+ 记成绩。
  ///
  /// 为什么要有这个函数：结束对局的路径原本分散在多处，各自只写了
  /// `_isGameOver = true` + 记成绩，**只有「猜对 / 用完次数」那条调了
  /// `_enterAnswerMode()`**，于是
  /// - 点「投降」结束
  /// - 倒计时归零超时结束
  /// 都不会去准备音频，答案模式的复播自然就只有谱面、没有声音。
  /// 收敛到这里之后，任何新增的结束路径都不容易再漏。
  ///
  /// [isWon] 仅用于记成绩（猜对为 true）。
  Future<void> _endRound({required bool isWon}) async {
    _countdownTimer?.cancel();
    if (!mounted) return;
    // 先置结束标记再准备音频：_prepareAnswerAudio 里有 `!_isGameOver 就放弃`
    // 的守卫（用于中途重开时丢弃过期结果），置位顺序反了会因竞态丢音频。
    setState(() {
      _isGameOver = true;
      _isWon = isWon;
    });
    await _enterAnswerMode();
    await _recordGameResult(isWon);
  }

  Future<void> _prepareAnswerAudio(Song song) async {
    try {
      final int musicId = LuoXueSongUtil.toLxnsMusicId(song.id);
      if (musicId <= 0) {
        debugPrint('[ChartPeek] 歌曲 id 异常，答案模式保持无声: ${song.id}');
        if (mounted) setState(() => _answerAudioFailed = true);
        return;
      }
      final file = await LuoXueSongUtil().getMusicFile(musicId.toString());
      if (!mounted || !_isGameOver) return;
      if (file == null) {
        setState(() => _answerAudioFailed = true);
        return;
      }
      _answerAudioPath = file.path;
      setState(() => _answerAudioReady = true);
    } catch (e) {
      debugPrint('[ChartPeek] 答案模式音频获取失败: $e');
      if (mounted) setState(() => _answerAudioFailed = true);
    }
  }

  // 构建搜索结果项
  Widget _buildSearchResultItem(Song song) {
    final aliases = _songAliasManager.aliases[song.title] ?? [];
    String aliasText = aliases.isNotEmpty ? aliases.join('、') : '';

    return GestureDetector(
      onTap: () {
        _handleGuess(song);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
                  color: AppColors.tableBorder(Theme.of(context).brightness))),
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
                child:
                    CoverUtil.buildCoverWidgetWithContext(context, song.id, 60),
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
                          color:
                              song.type == 'SD' ? Colors.blue : Colors.orange,
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
                    style: TextStyle(
                        fontSize: 14,
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (aliasText.isNotEmpty)
                    Text(
                      aliasText,
                      style: TextStyle(
                          fontSize: 14,
                          color:
                              AppColors.linkBlue(Theme.of(context).brightness)),
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

  // 构建猜测历史项
  Widget _buildGuessHistoryItem(GuessSong guessSong, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [AppColors.defaultShadow(Theme.of(context).brightness)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '猜测 #${index + 1}',
            style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                  child: CoverUtil.buildCoverWidgetWithContext(
                      context, guessSong.songId.toString(), 60),
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
                    '类型',
                    guessSong.type == 'SD' ? 'ST' : guessSong.type,
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
  Widget _buildInfoItem(String label, String value, Color color,
      {String? arrow}) {
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
              children: [
                const Text('从你已缓存谱面的曲库中随机选一首，随机播放一段无声的谱面动画片段。'),
                const SizedBox(height: 8),
                const Text('仔细观察物量密度、键型与出张方式，猜出这是哪首歌。'),
                const Text('片段最多可复播 $_maxReplays 次。'),
                const SizedBox(height: 16),
                const Text('绿色 - 该属性与你猜的完全一致。'),
                const SizedBox(height: 8),
                const Text('黄色 - 该属性与你猜的"接近"：'),
                const SizedBox(height: 4),
                const Text('灰色 - 该属性与你猜的"差距较大"：'),
                const SizedBox(height: 8),
                const Text('BPM 相差在 ±20 范围内；'),
                const Text('Master 难度或 Re:Master 难度相差在 ±0.4范围内；'),
                const Text('版本相差一个世代（例如 maimai ← maimai PLUS → maimai GreeN）。'),
                const SizedBox(height: 16),
                const Text('箭头：'),
                const SizedBox(height: 4),
                const Text('↑ - 目标值比你猜的更高'),
                const Text('↓ - 目标值比你猜的更低'),
                const SizedBox(height: 16),
                const Text('标签：'),
                const SizedBox(height: 4),
                const Text('显示您猜测的曲目的 Master 难度的配置、难度和评价标签。'),
                const Text('当一个标签与目标曲目的属性一致时，该标签会变为绿色。'),
                const Text('注意，有些曲目可能未添加标签。'),
                const SizedBox(height: 16),
                const Text('设计思路借鉴：'),
                GestureDetector(
                  onTap: () async {
                    final url = Uri.parse('https://maimai.yukineko2233.top/');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(
                        url,
                        mode: LaunchMode.externalApplication,
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('无法打开该链接')),
                      );
                    }
                  },
                  child: Text(
                    'https://maimai.yukineko2233.top/',
                    style: TextStyle(
                      color: AppColors.linkBlue(Theme.of(context).brightness),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
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

  /// 后台校验「当前筛选条件是否还能抽到曲」，抽不到就用 SnackBar 提醒。
  ///
  /// 放在保存**之后**异步执行：设置已经落盘、用户也已看到「已保存」，
  /// 这里慢一点不会让人干等。校验意义在于尽早发现「条件过严导致开局空转」，
  /// 而不是阻止保存。
  Future<void> _warnIfNoSongMatches({
    required List<String> selectedVersions,
    required double masterMinDx,
    required double masterMaxDx,
    required List<String> selectedGenres,
    required List<String> pool,
  }) async {
    // 先取好 messenger：下面 await 之后再用 context 会踩
    // use_build_context_synchronously
    final messenger = ScaffoldMessenger.of(context);
    try {
      // 必须用本页自己的曲池判定（版本 ∩ 流派 ∩ 难度池 ∩ 定数范围）。
      // 原先这里借用了 GuessChartByInfoService.randomSelectSong —— 那是
      // **按 MASTER 定数**筛选的另一个口径，与本页「按难度池抽谱」不是一回事，
      // 会出现「校验通过但开局抽不到」或反过来的误导。
      final candidates = await _collectCandidates(
        selectedVersions: selectedVersions,
        selectedGenres: selectedGenres,
        pool: pool,
        masterMinDx: masterMinDx,
        masterMaxDx: masterMaxDx,
      );
      if (candidates.isNotEmpty || !mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('当前筛选条件抽不到曲目，请放宽难度池 / 定数范围或筛选条件'),
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      debugPrint('校验筛选条件失败: $e');
    }
  }

  // 显示设置对话框
  void _showSettingsDialog() async {
    await _loadSettings();

    final allSongs = await GuessChartByInfoService.loadAllSongs();
    Set<String> versions = {};
    Set<String> genres = {};

    if (allSongs != null) {
      for (var song in allSongs) {
        versions.add(song.basicInfo.from);
        genres.add(song.basicInfo.genre);
      }
    }

    versions =
        versions.where((v) => VersionListConstant.standardVersions.contains(v)).toSet();

    List<String> allVersions = versions.toList()
      ..sort((a, b) {
        int orderA = VersionListConstant.versionOrderMap[a] ?? 999;
        int orderB = VersionListConstant.versionOrderMap[b] ?? 999;
        return orderA.compareTo(orderB);
      });
    genres.remove('宴会场');
    List<String> allGenres = genres.toList();

    List<String> tempSelectedVersions = List.from(_selectedVersions);
    double tempMasterMinDx = _masterMinDx;
    double tempMasterMaxDx = _masterMaxDx;
    List<String> tempSelectedGenres = List.from(_selectedGenres);
    int tempMaxGuesses = _maxGuesses;
    int tempTimeLimit = _timeLimit;
    int tempPeekDurationSeconds = _peekDurationSeconds;
    List<String> tempPeekDifficulties = List.from(_peekDifficulties);

    // 「重置所有设置」用：默认值统一取自设置服务，页面不再手写字面量。
    void applySettingsDefaults() {
      final defaults = _settingsService.defaultSettings();
      tempSelectedVersions =
          List<String>.from(defaults['selectedVersions'] as List);
      tempMasterMinDx = (defaults['masterMinDx'] as num).toDouble();
      tempMasterMaxDx = (defaults['masterMaxDx'] as num).toDouble();
      tempSelectedGenres = List<String>.from(defaults['selectedGenres'] as List);
      tempMaxGuesses = defaults['maxGuesses'] as int;
      tempTimeLimit = defaults['timeLimit'] as int;
      tempPeekDurationSeconds = defaults['peekDurationSeconds'] as int;
      tempPeekDifficulties =
          List<String>.from(defaults['peekDifficulties'] as List);
    }


    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('设置'),
          contentPadding: EdgeInsets.all(8.0),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CommonWidgetUtil.buildGuessChartSettingsWidget(
                      context,
                      allVersions,
                      allGenres,
                      tempSelectedVersions,
                      tempMasterMinDx,
                      tempMasterMaxDx,
                      tempSelectedGenres,
                      tempMaxGuesses,
                      tempTimeLimit,
                      (versions) {
                        setState(() {
                          tempSelectedVersions = versions;
                        });
                      },
                      (min, max) {
                        setState(() {
                          tempMasterMinDx = min;
                          tempMasterMaxDx = max;
                        });
                      },
                      (genres) {
                        setState(() {
                          tempSelectedGenres = genres;
                        });
                      },
                      (guesses) {
                        setState(() {
                          tempMaxGuesses = guesses;
                        });
                      },
                      (time) {
                        setState(() {
                          tempTimeLimit = time;
                        });
                      },
                      // 本页按「难度随机池」抽谱，定数范围作用于池内各难度
                      // 自己的定数，而不是 MASTER 的定数。
                      dxRangeTitle: '定数范围',
                      dxRangeHint: '按「难度随机池」里各难度自己的定数筛选'
                          '（例如只选 EXPERT 时看 EXPERT 的定数，'
                          '选 EXPERT+MASTER 时两者任一落在范围内即可），'
                          '不是按 MASTER 定数。',
                    ),
                    // 片段时长设置
                    Container(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '片段时长',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          SizedBox(height: 20),
                          Column(
                            children: [
                              Slider(
                                value: tempPeekDurationSeconds.toDouble(),
                                min: 3,
                                max: 60,
                                divisions: 57,
                                label: '$tempPeekDurationSeconds 秒',
                                onChanged: (value) {
                                  setState(() {
                                    tempPeekDurationSeconds = value.toInt();
                                  });
                                },
                              ),
                              Text('$tempPeekDurationSeconds 秒'),
                            ],
                          ),
                          SizedBox(height: 16),
                          Text(
                            '难度随机池',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          SizedBox(height: 8),
                          // 每局从勾选的难度中随机抽一个播放
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _difficultyNames.entries.map((entry) {
                              final String inote = entry.key;
                              final String label = entry.value;
                              final bool selected =
                                  tempPeekDifficulties.contains(inote);
                              return FilterChip(
                                label: Text(label),
                                selected: selected,
                                onSelected: (value) {
                                  setState(() {
                                    if (value) {
                                      tempPeekDifficulties.add(inote);
                                    } else {
                                      tempPeekDifficulties.remove(inote);
                                      // 至少保留一个难度
                                      if (tempPeekDifficulties.isEmpty) {
                                        tempPeekDifficulties.add('4');
                                      }
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    // 重置按钮
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(applySettingsDefaults);
                          },
                          child: Text('重置所有设置'),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                // 在 await 之前取好 Navigator / ScaffoldMessenger
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);

                // 先落盘并立刻反馈：saveSettings 只要 2ms，而抽曲校验要遍历
                // 整份曲库（冷启动含读盘解析），是秒级操作。原先「先校验、
                // 通过才保存」会让用户点完「确定」干等数秒。校验只用于提示
                // 「这组条件抽不到曲」，不影响该不该保存，故挪到保存之后。
                await _settingsService.saveSettings(
                  selectedVersions: tempSelectedVersions,
                  masterMinDx: tempMasterMinDx,
                  masterMaxDx: tempMasterMaxDx,
                  selectedGenres: tempSelectedGenres,
                  maxGuesses: tempMaxGuesses,
                  timeLimit: tempTimeLimit,
                  peekDurationSeconds: tempPeekDurationSeconds,
                  peekDifficulties: tempPeekDifficulties,
                );

                if (!navigator.mounted) return;
                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('设置已保存，将在下局游戏生效')),
                );

                _warnIfNoSongMatches(
                  selectedVersions: tempSelectedVersions,
                  masterMinDx: tempMasterMinDx,
                  masterMaxDx: tempMasterMaxDx,
                  selectedGenres: tempSelectedGenres,
                  pool: tempPeekDifficulties,
                );
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  // 释放播放器
  void _teardownPlayer() {
    _playerController?.removeListener(_onChartTimeChanged);
    _playerController?.removeListener(_scheduleNothing);
    _playerController?.dispose();
    _playerController = null;
  }

  // 构建谱面片段区（裸 SimaiPlayer，无标题/进度条/设置）
  Widget _buildChartClipArea() {
    final controller = _playerController;
    if (controller == null) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _unavailableReason.isNotEmpty
              ? _unavailableReason
              : '没有可用的谱面，请先在谱面库中缓存 maidata',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 220,
        child: Stack(
          fit: StackFit.expand,
          children: [
            SimaiPlayer(controller: controller),
            // 片段结束后的半透明遮罩提示；答案模式下不遮挡（可点击复播按钮）
            if (_clipFinished && !_isGameOver)
              IgnorePointer(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.45),
                  alignment: Alignment.center,
                  child: const Text(
                    '片段播放完毕',
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final screenWidth = MediaQuery.of(context).size.width;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    final double borderRadiusSmall = 8.0;
    final BoxShadow defaultShadow = AppColors.defaultShadow(brightness);

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          CommonWidgetUtil.buildCommonBgWidget(),
          CommonWidgetUtil.buildCommonChiffonBgWidget(context),

          Column(
            children: [
              // 标题栏
              Container(
                padding: EdgeInsets.fromLTRB(16, 48, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back,
                          color: Theme.of(context).colorScheme.onSurface),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '猜歌（谱面片段）',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: screenWidth * 0.06,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 48),
                  ],
                ),
              ),

              // 主内容区域
              Expanded(
                child: Container(
                  margin: EdgeInsets.fromLTRB(4, 0, 4, 10 + safeBottom),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(borderRadiusSmall),
                    boxShadow: [defaultShadow],
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      double padding = screenWidth * 0.04;

                      return Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              padding: EdgeInsets.all(padding),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _isGameStarted
                                      ? Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            // 游戏状态
                                            Container(
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .surfaceContainerHighest,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '猜测次数: $_guessCount/${_maxGuesses > 0 ? _maxGuesses : '无限制'}',
                                                    style: TextStyle(
                                                        fontSize:
                                                            screenWidth * 0.04),
                                                  ),
                                                  if (_timeLimit > 0)
                                                    Text(
                                                      '剩余时间: ${_remainingTime > 0 ? _remainingTime : 0}秒',
                                                      style: TextStyle(
                                                          fontSize:
                                                              screenWidth * 0.04,
                                                          color: _remainingTime /
                                                                      _timeLimit <=
                                                                  0.3
                                                              ? Colors.red
                                                              : null),
                                                    ),
                                                  Container(
                                                    margin: const EdgeInsets.only(
                                                        top: 8),
                                                    child: Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment.start,
                                                      children: [
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                '今日统计: 正确${_stats['correct']} | 错误${_stats['wrong']}',
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        screenWidth *
                                                                            0.04,
                                                                    color: Theme.of(
                                                                            context)
                                                                        .colorScheme
                                                                        .onSurface),
                                                              ),
                                                              Text(
                                                                '正确率${_stats['accuracy'].toStringAsFixed(1)}% | 平均用时${_stats['avgTime'].toStringAsFixed(1)}秒',
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        screenWidth *
                                                                            0.04,
                                                                    color: Theme.of(
                                                                            context)
                                                                        .colorScheme
                                                                        .onSurface),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        IconButton(
                                                          padding:
                                                              EdgeInsets.zero,
                                                          icon: Icon(
                                                              Icons.refresh,
                                                              color: Theme.of(
                                                                      context)
                                                                  .colorScheme
                                                                  .onSurface,
                                                              size: 20),
                                                          onPressed: () async {
                                                            await _resetAndRefreshStats();
                                                          },
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  if (_isGameOver)
                                                    Text(
                                                      _isWon
                                                          ? '恭喜你猜对了！'
                                                          : '游戏结束，你没有猜对',
                                                      style: TextStyle(
                                                        fontSize:
                                                            screenWidth * 0.04,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: _isWon
                                                            ? AppColors.successGreen(
                                                                brightness)
                                                            : AppColors.errorRed(
                                                                brightness),
                                                      ),
                                                    ),
                                                  if (_isGameOver && !_isWon)
                                                    Text(
                                                      '正确答案: ${_targetSong?.basicInfo.title}',
                                                      style: TextStyle(
                                                        fontSize:
                                                            screenWidth * 0.04,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 20),

                                            // 谱面片段区（裸谱面 + 自制控件）
                                            // 游戏结束后保留：可无限复播且带音频对答案
                                            _buildChartClipArea(),
                                            const SizedBox(height: 10),
                                            // 播放控制行
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                // 本局播放难度的标签（带难度底色）
                                                if (_resolvedDifficulty !=
                                                        null &&
                                                    _difficultyNames
                                                        .containsKey(
                                                            _resolvedDifficulty))
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 10,
                                                        vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: _difficultyColors[
                                                              _resolvedDifficulty] ??
                                                          Colors.grey,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    child: Text(
                                                      _difficultyNames[
                                                              _resolvedDifficulty!] ??
                                                          '',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                const SizedBox(width: 10),
                                                // 播放/暂停/复播
                                                ElevatedButton.icon(
                                                  onPressed:
                                                      (!_isGameOver &&
                                                              _clipFinished &&
                                                              _replaysLeft <= 0)
                                                          ? null
                                                          : _togglePlayPause,
                                                  icon: Icon(
                                                    (_clipFinished ||
                                                            (_isGameOver &&
                                                                !_answerAudioFailed))
                                                        ? Icons.replay
                                                        : Icons.play_arrow,
                                                    size: 20,
                                                  ),
                                                  label: Text(
                                                    _isGameOver
                                                        ? (_answerAudioFailed
                                                            ? '复播片段（音频不可用）'
                                                            : (_answerAudioReady
                                                                ? '复播片段（带音频）'
                                                                : '复播片段'))
                                                        : (!_clipStarted
                                                            ? '播放片段'
                                                            : (_clipFinished
                                                                ? '复播$_replayLabel'
                                                                : '暂停')),
                                                  ),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 16),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 20),

                                            // 搜索输入框和结果
                                            Container(
                                              child: Column(
                                                children: [
                                                  Container(
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(8),
                                                      border: Border.all(
                                                          color: AppColors
                                                              .tableBorder(
                                                                  brightness)),
                                                    ),
                                                    child: TextField(
                                                      controller: _searchController,
                                                      onChanged: _handleSearchInput,
                                                      enabled: !_isGameOver,
                                                      decoration:
                                                          const InputDecoration(
                                                        hintText: '输入歌曲名称或别名',
                                                        border: InputBorder.none,
                                                        contentPadding:
                                                            EdgeInsets.all(12),
                                                      ),
                                                    ),
                                                  ),
                                                  if (_showSearchResults &&
                                                      _searchResults.isNotEmpty)
                                                    Container(
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius.circular(8),
                                                        border: Border.all(
                                                            color: AppColors
                                                                .tableBorder(
                                                                    brightness)),
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .surface,
                                                        boxShadow: [
                                                          AppColors.defaultShadow(
                                                              brightness)
                                                        ],
                                                      ),
                                                      constraints: BoxConstraints(
                                                          maxHeight:
                                                              screenHeight * 0.3),
                                                      child: ListView.builder(
                                                        padding: EdgeInsets.zero,
                                                        itemCount:
                                                            _searchResults.length,
                                                        itemBuilder:
                                                            (context, index) {
                                                          return _buildSearchResultItem(
                                                              _searchResults[
                                                                  index]);
                                                        },
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),

                                            if (_isSearching)
                                              Container(
                                                margin:
                                                    const EdgeInsets.only(top: 8),
                                                padding:
                                                    const EdgeInsets.all(16),
                                                child: const Center(
                                                  child:
                                                      CircularProgressIndicator(),
                                                ),
                                              ),

                                            // 按钮区域
                                            Container(
                                              margin:
                                                  const EdgeInsets.only(top: 12),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      IconButton(
                                                        icon: Icon(
                                                            Icons.info_outline,
                                                            color: Theme.of(context)
                                                                .colorScheme
                                                                .onSurface,
                                                            size: 24),
                                                        onPressed:
                                                            _showRulesDialog,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      IconButton(
                                                        icon: Icon(
                                                            Icons.settings,
                                                            color: Theme.of(context)
                                                                .colorScheme
                                                                .onSurface,
                                                            size: 24),
                                                        onPressed:
                                                            _showSettingsDialog,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      IconButton(
                                                        icon: Icon(Icons.refresh,
                                                            color: Theme.of(context)
                                                                .colorScheme
                                                                .onSurface,
                                                            size: 24),
                                                        onPressed: _startNewGame,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      IconButton(
                                                        icon: Icon(
                                                          _isAscending
                                                              ? Icons.sort_by_alpha
                                                              : Icons
                                                                  .sort_by_alpha_outlined,
                                                          color: Theme.of(context)
                                                              .colorScheme
                                                              .onSurface,
                                                          size: 24,
                                                        ),
                                                        onPressed: () {
                                                          setState(() {
                                                            _isAscending =
                                                                !_isAscending;
                                                          });
                                                        },
                                                      ),
                                                      const SizedBox(width: 8),
                                                      if (!_isGameOver)
                                                        TextButton(
                                                          onPressed: () async {
                                                            _playerController
                                                                ?.pause();
                                                            // 走统一入口：置结束标记
                                                            // + 准备答案音频（否则复播无声）
                                                            await _endRound(
                                                                isWon: false);
                                                          },
                                                          child: const Text('投降'),
                                                        ),
                                                      if (_isGameOver)
                                                        ElevatedButton(
                                                          onPressed: _startNewGame,
                                                          child:
                                                              const Text('新游戏'),
                                                        ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // 游戏结果显示
                                            if (_isGameOver)
                                              GestureDetector(
                                                onTap: () {
                                                  if (_targetSong != null) {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            SongInfoPage(
                                                          songId:
                                                              _targetSong!.id,
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                },
                                                child: Container(
                                                  margin: const EdgeInsets.only(
                                                      top: 20),
                                                  padding:
                                                      const EdgeInsets.all(16),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        AppColors.guessAnswerCardBg(
                                                            brightness),
                                                    borderRadius:
                                                        BorderRadius.circular(8),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        _isWon
                                                            ? '恭喜你猜对了！'
                                                            : '本局答案',
                                                        style: TextStyle(
                                                          fontSize:
                                                              screenWidth * 0.04,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: _isWon
                                                              ? AppColors
                                                                  .successGreen(
                                                                      brightness)
                                                              : AppColors.linkBlue(
                                                                  brightness),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      if (_targetSong != null)
                                                        Row(
                                                          children: [
                                                            Container(
                                                              width: 60,
                                                              height: 60,
                                                              decoration:
                                                                  BoxDecoration(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(4),
                                                              ),
                                                              child: ClipRRect(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(4),
                                                                child: CoverUtil
                                                                    .buildCoverWidgetWithContext(
                                                                        context,
                                                                        _targetSong!
                                                                            .id,
                                                                        60),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                width: 12),
                                                            Expanded(
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Row(
                                                                    children: [
                                                                      Text(
                                                                        _targetSong!.type ==
                                                                                'SD'
                                                                            ? 'ST'
                                                                            : _targetSong!
                                                                                .type,
                                                                        style:
                                                                            TextStyle(
                                                                          fontSize:
                                                                              screenWidth *
                                                                                  0.035,
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                          color: _targetSong!.type ==
                                                                                  'SD'
                                                                              ? Colors.blue
                                                                              : Colors.orange,
                                                                        ),
                                                                      ),
                                                                      SizedBox(
                                                                          width: 8),
                                                                      Expanded(
                                                                        child:
                                                                            Text(
                                                                          _targetSong!
                                                                              .basicInfo
                                                                              .title,
                                                                          style: TextStyle(
                                                                              fontSize: screenWidth *
                                                                                  0.035,
                                                                              fontWeight:
                                                                                  FontWeight.bold),
                                                                          overflow:
                                                                              TextOverflow.ellipsis,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  Text(
                                                                    '${_targetSong!.basicInfo.artist} | ${_targetSong!.basicInfo.genre}',
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            screenWidth *
                                                                                0.03,
                                                                        color: Theme.of(context)
                                                                            .colorScheme
                                                                            .onSurfaceVariant),
                                                                    overflow:
                                                                        TextOverflow.ellipsis,
                                                                  ),
                                                                  Text(
                                                                    '${_targetSong!.ds.length > 3 ? _targetSong!.ds[3].toString() : '-'} | ${_targetSong!.ds.length > 4 ? _targetSong!.ds[4].toString() : '-'} | ${StringUtil.formatVersion2WithFlag(_targetSong!.basicInfo.from, _targetSong!.isExtra)}',
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            screenWidth *
                                                                                0.03,
                                                                        color: Theme.of(context)
                                                                            .colorScheme
                                                                            .onSurfaceVariant),
                                                                    overflow:
                                                                        TextOverflow.ellipsis,
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ),

                                            const SizedBox(height: 20),

                                            // 猜测历史
                                            if (_guessHistory.isNotEmpty)
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '猜测历史',
                                                    style: TextStyle(
                                                      fontSize:
                                                          screenWidth * 0.045,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  ...(_isAscending
                                                          ? _guessHistory
                                                          : _guessHistory
                                                              .reversed
                                                              .toList())
                                                      .asMap()
                                                      .entries
                                                      .map((entry) {
                                                    int displayIndex =
                                                        _isAscending
                                                            ? entry.key
                                                            : _guessHistory
                                                                    .length -
                                                                1 -
                                                                entry.key;
                                                    return _buildGuessHistoryItem(
                                                        entry.value,
                                                        displayIndex);
                                                  }),
                                                ],
                                              ),
                                          ],
                                        )
                                      : Center(
                                          child: Padding(
                                            padding:
                                                EdgeInsets.all(screenHeight * 0.1),
                                            child: CircularProgressIndicator(),
                                          ),
                                        ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
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
