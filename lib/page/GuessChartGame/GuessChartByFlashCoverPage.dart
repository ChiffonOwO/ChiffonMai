import 'dart:async';

import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:flutter/services.dart';
import 'package:my_first_flutter_app/entity/GuessChartGame/GuessSong.dart';
import 'package:my_first_flutter_app/entity/DivingFish/Song.dart';
import 'package:my_first_flutter_app/manager/SongAliasManager.dart';
import 'package:my_first_flutter_app/service/GuessChartGame/GuessChartByInfoService.dart';
import 'package:my_first_flutter_app/service/GuessChartGame/GuessChartCommonSettingsService.dart';
import 'package:my_first_flutter_app/utils/CoverUtil.dart';
import 'package:my_first_flutter_app/utils/CommonCacheUtil.dart';
import 'package:my_first_flutter_app/utils/StringUtil.dart';
import 'package:my_first_flutter_app/utils/SongFilterUtil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:my_first_flutter_app/page/SongInfoPage.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:my_first_flutter_app/page/GuessChartGame/GuessChartLoadingView.dart';
import '../../widgets/PageTopBar.dart';

/// 曲绘快闪猜歌：曲绘只在开局瞬间显示一小段时间（可设置，默认 0.3s），
/// 之后消失，凭记忆在和无提示猜歌相同的交互页面中猜歌。
class GuessChartByFlashCoverPage extends StatefulWidget {
  const GuessChartByFlashCoverPage({super.key});

  @override
  State<GuessChartByFlashCoverPage> createState() =>
      _GuessChartByFlashCoverPageState();
}

class _GuessChartByFlashCoverPageState
    extends State<GuessChartByFlashCoverPage> {
  // 游戏状态
  bool _isGameStarted = false;
  Song? _targetSong;
  List<GuessSong> _guessHistory = [];
  int _guessCount = 0;
  int _maxGuesses = 10; // 从设置中加载
  int _timeLimit = 0; // 从设置中加载，0表示无限制
  bool _isGameOver = false;
  bool _isWon = false;
  String _loadFailureMessage = ''; // 开局取曲失败时的提示（空 = 没失败）

  // 游戏时间记录
  DateTime? _gameStartTime;

  // 统计数据
  Map<String, dynamic> _stats = {
    'correct': 0,
    'wrong': 0,
    'accuracy': 0.0,
    'avgTime': 0.0,
  };

  // 缓存工具
  final _cacheUtil = CommonCacheUtil();

  // 倒计时相关
  int _remainingTime = 0;
  Timer? _countdownTimer;

  // 设置相关
  List<String> _selectedVersions = [];
  double _masterMinDx = 1.0;
  double _masterMaxDx = 15.0;
  List<String> _selectedGenres = [];
  int _flashDurationMs = 300; // 曲绘快闪时长
  late GuessChartCommonSettingsService _settingsService;

  // 快闪相关
  bool _showFlashCover = false;
  Timer? _flashTimer;

  // 搜索状态
  TextEditingController _searchController = TextEditingController();
  List<Song> _searchResults = [];
  bool _isSearching = false;
  Timer? _searchTimer;
  static const Duration _searchDelay = Duration(milliseconds: 800);
  bool _showSearchResults = false;

  // 排序状态
  bool _isAscending = true; // true: 顺序, false: 逆序

  // 歌曲别名管理器
  late SongAliasManager _songAliasManager;

  @override
  void initState() {
    super.initState();
    _songAliasManager = SongAliasManager.instance;
    _settingsService = GuessChartCommonSettingsService();
    _loadSettings();
    _initCache();
    _initGame();
  }

  // 初始化缓存
  Future<void> _initCache() async {
    await _cacheUtil.initCache('7');
    await _loadStats();
  }

  // 加载统计数据
  Future<void> _loadStats() async {
    final stats = await _cacheUtil.getStats('7');
    setState(() {
      _stats = Map.from(stats);
    });
  }

  // 重置并刷新统计数据
  Future<void> _resetAndRefreshStats() async {
    await _cacheUtil.resetStats('7');
    final stats = await _cacheUtil.getStats('7');
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
      _flashDurationMs = settings['flashDurationMs'] ?? 300;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchTimer?.cancel();
    _countdownTimer?.cancel();
    _flashTimer?.cancel();
    super.dispose();
  }

  // 初始化游戏
  Future<void> _initGame() async {
    await _songAliasManager.init();
    await _startNewGame();
  }

  // 开始新游戏
  Future<void> _startNewGame() async {
    // 取消之前的倒计时
    _countdownTimer?.cancel();
    _flashTimer?.cancel();

    // 加载最新的设置
    await _loadSettings();

    setState(() {
      _isGameStarted = false;
      _isGameOver = false;
      _isWon = false;
      _loadFailureMessage = '';
      _guessHistory = [];
      _guessCount = 0;
      _searchController.clear();
      _searchResults = [];
      _showSearchResults = false;
      _remainingTime = _timeLimit; // 重置倒计时
      _gameStartTime = DateTime.now(); // 记录游戏开始时间
      _showFlashCover = false;
    });

    // 随机选择目标歌曲（使用设置的筛选条件）
    _targetSong = await GuessChartByInfoService.randomSelectSong(
      selectedVersions: _selectedVersions,
      masterMinDx: _masterMinDx,
      masterMaxDx: _masterMaxDx,
      selectedGenres: _selectedGenres,
    );
    if (_targetSong != null) {
      setState(() {
        _isGameStarted = true;
        _loadFailureMessage = '';
      });

      // 快闪曲绘
      _startFlashCover();
      // 启动倒计时
      _startCountdown();
      return;
    }

    // 抽曲失败：**绝不能**就此留在加载态（详见 GuessChartLoadingView 注释）。
    // 原先这里没有 else 分支，曲库缓存为空时页面会永久转圈。
    final libraryEmpty = await GuessChartLoadingView.isSongLibraryEmpty();
    if (!mounted) return;
    setState(() {
      // 与谱面片段猜歌同一思路：照常进入游戏界面，只把题面区换成原因说明。
      // 停在 _isGameStarted == false 的话设置齿轮就点不到，用户只能退出去重进。
      _isGameStarted = true;
      _loadFailureMessage = libraryEmpty
          ? GuessChartLoadingView.emptyLibraryMessage
          : GuessChartLoadingView.filterTooStrictMessage;
    });
  }

  /// 失败态下的「重新拉取曲库」：先把曲库缓存拉回来，再重开一局。
  /// 返回 true 表示这局已经成功进入游戏。
  Future<bool> _retryStartGame() async {
    await GuessChartLoadingView.refreshSongLibrary();
    if (!mounted) return false;
    await _startNewGame();
    return mounted && _targetSong != null;
  }

  /// 失败态下的「打开设置」：弹设置对话框，用户关掉后立刻重开一局。
  ///
  /// 为什么要有它：设置入口（齿轮）长在游戏内容里，抽不到曲时页面停在失败态，
  /// 那句「请在设置中放宽条件」指向的按钮根本点不到，用户只能退出去重进。
  /// 返回 true 表示这局已经成功进入游戏（失败视图会因此被替换掉）。
  Future<bool> _openSettingsAndRestart() async {
    await _showSettingsDialog();
    if (!mounted) return false;
    await _startNewGame();
    return mounted && _targetSong != null;
  }

  // 快闪展示曲绘：显示 flashDurationMs 后自动隐藏
  void _startFlashCover() {
    _flashTimer?.cancel();
    setState(() {
      _showFlashCover = true;
    });
    _flashTimer = Timer(Duration(milliseconds: _flashDurationMs), () {
      if (!mounted) return;
      setState(() {
        _showFlashCover = false;
      });
    });
  }

  // 启动倒计时
  void _startCountdown() {
    if (_timeLimit <= 0) return; // 无时间限制
    _countdownTimer?.cancel();

    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (_isGameOver) {
          _countdownTimer?.cancel();
        } else if (_remainingTime > 0) {
          _remainingTime--;
        } else {
          // 时间到，游戏结束
          _countdownTimer?.cancel();
          _isGameOver = true;
          _isWon = false;
          // 记录失败
          _recordGameResult(false);
        }
      });
    });
  }

  // 记录游戏结果
  Future<void> _recordGameResult(bool isWon) async {
    if (_gameStartTime == null) return;

    // 计算游戏用时
    final gameTime = DateTime.now().difference(_gameStartTime!).inSeconds;

    // 记录结果
    if (isWon) {
      await _cacheUtil.recordSuccess('7');
    } else {
      await _cacheUtil.recordFailure('7');
    }

    // 结算游戏
    await _cacheUtil.settleGame('7', gameTime);

    // 重新加载统计数据
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
    // 抽不到曲时整页仍然可用（题面区显示原因），但猜是空操作
    if (_isGameOver || _targetSong == null) return;

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
      _searchController.clear();
      _searchResults = [];
      _showSearchResults = false;
      return;
    }

    // 构建猜测实体
    var guessSong =
        await GuessChartByInfoService.buildGuessSongEntity(guessedSong);
    // 计算猜测结果
    guessSong = await GuessChartByInfoService.calculateGuessResult(
        guessSong, _targetSong!, Theme.of(context).brightness);

    // 更新猜测历史
    setState(() {
      _guessHistory.add(guessSong);
      _guessCount++;
      _searchController.clear();
      _searchResults = [];
      _showSearchResults = false;
    });

    // 检查游戏是否结束
    if (guessedSong.basicInfo.title == _targetSong!.basicInfo.title) {
      // 猜对了，游戏结束
      _countdownTimer?.cancel();
      setState(() {
        _isGameOver = true;
        _isWon = true;
      });
      await _recordGameResult(true);
    } else if (_maxGuesses > 0 && _guessCount >= _maxGuesses) {
      // 猜测次数用完，游戏结束
      _countdownTimer?.cancel();
      setState(() {
        _isGameOver = true;
        _isWon = false;
      });
      await _recordGameResult(false);
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
              bottom:
                  BorderSide(color: AppColors.tableBorder(Theme.of(context).brightness))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 方形曲绘
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
            // 右侧信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题
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
                  // 作者
                  Text(
                    song.basicInfo.artist,
                    style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // 别名
                  if (aliasText.isNotEmpty)
                    Text(
                      aliasText,
                      style: TextStyle(
                          fontSize: 14,
                          color: AppColors.linkBlue(Theme.of(context).brightness)),
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
                  child:
                      CoverUtil.buildCoverWidgetWithContext(context, guessSong.songId.toString(), 60),
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
                child: _buildInfoItem('类型', guessSong.type == 'SD' ? 'ST' : guessSong.type,
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
                    guessSong.remasterDs.isNotEmpty ? guessSong.remasterDs : '-',
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
                  children: List.generate(guessSong.masterTags?.length ?? 0, (i) {
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
                const Text('开局时曲绘会闪现一瞬间（时长可在设置中调整），随后消失。'),
                const SizedBox(height: 8),
                const Text('凭记忆在下方搜索并猜出这首歌曲。'),
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
                const Text('设计思路借鉴：'),
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
  }) async {
    // 先取好 messenger：下面 await 之后再用 context 会踩
    // use_build_context_synchronously
    final messenger = ScaffoldMessenger.of(context);
    try {
      final testSong = await GuessChartByInfoService.randomSelectSong(
        selectedVersions: selectedVersions,
        masterMinDx: masterMinDx,
        masterMaxDx: masterMaxDx,
        selectedGenres: selectedGenres,
      );
      if (testSong != null || !mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('当前筛选条件抽不到曲目，请放宽筛选条件'),
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      debugPrint('校验筛选条件失败: $e');
    }
  }

  // 显示设置对话框
  Future<void> _showSettingsDialog() async {
    await _loadSettings();

    // 加载所有版本和流派
    final allSongs = await GuessChartByInfoService.loadAllSongs();
    // 可选版本 / 可选流派统一走 SongFilterUtil.selectableFilters：
    // 它先剔除非正曲（SongFilterUtil.isExtra：宴会场 / maidata 追加 / union 独有），
    // 再单独挡掉「宴会场」流派，最后把版本过一遍官方世代白名单并按世代排序。
    // 口径必须与抽曲池一致，否则列表里会出现「勾了也永远抽不到」的选项。
    final SongFilterOptions filterOptions =
        SongFilterUtil.selectableFilters(allSongs ?? const <Song>[]);
    final List<String> allVersions = filterOptions.versions;
    final List<String> allGenres = filterOptions.genres;

    // 临时变量用于存储设置
    List<String> tempSelectedVersions = List.from(_selectedVersions);
    double tempMasterMinDx = _masterMinDx;
    double tempMasterMaxDx = _masterMaxDx;
    List<String> tempSelectedGenres = List.from(_selectedGenres);
    int tempMaxGuesses = _maxGuesses;
    int tempTimeLimit = _timeLimit;
    int tempFlashDurationMs = _flashDurationMs;

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
      tempFlashDurationMs = defaults['flashDurationMs'] as int;
    }


    await showDialog(
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
                    ),
                    // 快闪时长设置
                    Container(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '快闪时长',
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
                                value: tempFlashDurationMs.toDouble(),
                                min: 100,
                                max: 3000,
                                divisions: 58, // 100ms 步进
                                label: '${(tempFlashDurationMs / 1000).toStringAsFixed(1)} 秒',
                                onChanged: (value) {
                                  setState(() {
                                    tempFlashDurationMs = value.toInt();
                                  });
                                },
                              ),
                              Text(
                                  '${(tempFlashDurationMs / 1000).toStringAsFixed(1)} 秒'),
                            ],
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
                // 鍦?await 涔嬪墠鍙栧ソ Navigator / ScaffoldMessenger
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
                  flashDurationMs: tempFlashDurationMs,
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
                );
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    // 获取屏幕尺寸
    final screenWidth = MediaQuery.of(context).size.width;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    // 自定义常量
    final double borderRadiusSmall = 8.0;
    final BoxShadow defaultShadow = AppColors.defaultShadow(brightness);

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false, // 防止键盘弹出时挤压背景
      body: Stack(
        children: [
          // 背景
          CommonWidgetUtil.buildCommonBgWidget(),
          CommonWidgetUtil.buildCommonChiffonBgWidget(context),

          // 页面内容
          Column(
            children: [
              // 标题栏
              PageTopBar(
                title: '猜歌（曲绘快闪）',
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
                      // 边距
                      double padding = screenWidth * 0.04;

                      return Column(
                        children: [
                          // 主要内容
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
                                                  // 统计数据
                                                  Container(
                                                    margin: const EdgeInsets.only(top: 8),
                                                    child: Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment.start,
                                                      children: [
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment.start,
                                                            children: [
                                                              Text(
                                                                '今日统计: 正确${_stats['correct']} | 错误${_stats['wrong']}',
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        screenWidth * 0.04,
                                                                    color: Theme.of(context)
                                                                        .colorScheme
                                                                        .onSurface),
                                                              ),
                                                              Text(
                                                                '正确率${_stats['accuracy'].toStringAsFixed(1)}% | 平均用时${_stats['avgTime'].toStringAsFixed(1)}秒',
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        screenWidth * 0.04,
                                                                    color: Theme.of(context)
                                                                        .colorScheme
                                                                        .onSurface),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        IconButton(
                                                          padding: EdgeInsets.zero,
                                                          icon: Icon(
                                                              Icons.refresh,
                                                              color: Theme.of(context)
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

                                            // 快闪曲绘展示区：只在闪现的瞬间渲染，
                                            // 闪现结束后整块消失，布局与无提示猜歌一致
                                            // 抽不到曲：题面区给出原因（整页仍照常可用）
                                            if (_targetSong == null)
                                              GuessChartNoSongNotice(
                                                message: _loadFailureMessage,
                                                height: 200,
                                              )
                                            else if (!_isGameOver &&
                                                _showFlashCover)
                                              Center(
                                                child: Container(
                                                  width: 200,
                                                  height: 200,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(12),
                                                    border: Border.all(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .outlineVariant,
                                                      width: 2,
                                                    ),
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(10),
                                                    child:
                                                        CoverUtil.buildCoverWidgetWithContext(
                                                            context,
                                                            _targetSong!.id,
                                                            200),
                                                  ),
                                                ),
                                              ),
                                            if (_isGameOver && _targetSong != null)
                                              Center(
                                                child: Container(
                                                  width: 200,
                                                  height: 200,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(12),
                                                    border: Border.all(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .outlineVariant,
                                                      width: 2,
                                                    ),
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(10),
                                                    child:
                                                        CoverUtil.buildCoverWidgetWithContext(
                                                            context,
                                                            _targetSong!.id,
                                                            200),
                                                  ),
                                                ),
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
                                                          color: AppColors.tableBorder(
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
                                                  // 搜索结果
                                                  if (_showSearchResults &&
                                                      _searchResults.isNotEmpty)
                                                    Container(
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius.circular(8),
                                                        border: Border.all(
                                                            color: AppColors.tableBorder(
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
                                                        // 去掉 ListView 默认把状态栏安全区算进列表顶部的空白
                                                        padding: EdgeInsets.zero,
                                                        itemCount:
                                                            _searchResults.length,
                                                        itemBuilder: (context, index) {
                                                          return _buildSearchResultItem(
                                                              _searchResults[index]);
                                                        },
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),

                                            // 搜索中状态
                                            if (_isSearching)
                                              Container(
                                                margin: const EdgeInsets.only(top: 8),
                                                padding: const EdgeInsets.all(16),
                                                child: const Center(
                                                  child:
                                                      CircularProgressIndicator(),
                                                ),
                                              ),

                                            // 按钮区域
                                            Container(
                                              margin: const EdgeInsets.only(top: 12),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      // 规则按钮
                                                      IconButton(
                                                        icon: Icon(
                                                            Icons.info_outline,
                                                            color: Theme.of(context)
                                                                .colorScheme
                                                                .onSurface,
                                                            size: 24),
                                                        onPressed: _showRulesDialog,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      // 设置按钮
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
                                                      // 刷新按钮
                                                      IconButton(
                                                        icon: Icon(Icons.refresh,
                                                            color: Theme.of(context)
                                                                .colorScheme
                                                                .onSurface,
                                                            size: 24),
                                                        onPressed: _startNewGame,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      // 排序按钮
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
                                                      // 投降按钮
                                                      if (!_isGameOver)
                                                        TextButton(
                                                          onPressed: () async {
                                                            _countdownTimer?.cancel();
                                                            _flashTimer?.cancel();
                                                            setState(() {
                                                              _isGameOver = true;
                                                              _isWon = false;
                                                            });
                                                            await _recordGameResult(
                                                                false);
                                                          },
                                                          child: const Text('投降'),
                                                        ),
                                                      // 开始新游戏按钮
                                                      if (_isGameOver)
                                                        ElevatedButton(
                                                          onPressed: _startNewGame,
                                                          child: const Text('新游戏'),
                                                        ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // 游戏结果显示（抽不到曲时没有答案卡片）
                                            if (_isGameOver && _targetSong != null)
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
                                                  margin:
                                                      const EdgeInsets.only(top: 20),
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
                                                              ? AppColors.successGreen(
                                                                  brightness)
                                                              : AppColors.linkBlue(
                                                                  brightness),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      if (_targetSong != null)
                                                        Row(
                                                          children: [
                                                            // 曲绘
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
                                                            const SizedBox(width: 12),
                                                            Expanded(
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  // 第一行：类型 曲名
                                                                  Row(
                                                                    children: [
                                                                      Text(
                                                                        _targetSong!.type ==
                                                                                'SD'
                                                                            ? 'ST'
                                                                            : _targetSong!
                                                                                .type,
                                                                        style: TextStyle(
                                                                          fontSize:
                                                                              screenWidth * 0.035,
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                          color: _targetSong!.type ==
                                                                                  'SD'
                                                                              ? Colors.blue
                                                                              : Colors.orange,
                                                                        ),
                                                                      ),
                                                                      SizedBox(width: 8),
                                                                      Expanded(
                                                                        child: Text(
                                                                          _targetSong!
                                                                              .basicInfo
                                                                              .title,
                                                                          style: TextStyle(
                                                                            fontSize:
                                                                                screenWidth * 0.035,
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                          ),
                                                                          overflow:
                                                                              TextOverflow.ellipsis,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  // 第二行：曲师 | 流派
                                                                  Text(
                                                                    '${_targetSong!.basicInfo.artist} | ${_targetSong!.basicInfo.genre}',
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          screenWidth *
                                                                              0.03,
                                                                      color: Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .onSurfaceVariant,
                                                                    ),
                                                                    overflow:
                                                                        TextOverflow.ellipsis,
                                                                  ),
                                                                  // 第三行：masterDs | remasterDs | version
                                                                  Text(
                                                                    '${_targetSong!.ds.length > 3 ? _targetSong!.ds[3].toString() : '-'} | ${_targetSong!.ds.length > 4 ? _targetSong!.ds[4].toString() : '-'} | ${StringUtil.formatVersion2WithFlag(_targetSong!.basicInfo.from, _targetSong!.isExtra)}',
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          screenWidth *
                                                                              0.03,
                                                                      color: Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .onSurfaceVariant,
                                                                    ),
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
                                                    int displayIndex = _isAscending
                                                        ? entry.key
                                                        : _guessHistory.length -
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
                                      : GuessChartLoadingView(
                                          message: _loadFailureMessage,
                                          onOpenSettings: _openSettingsAndRestart,
                                          // 只有「曲库真的没数据」才给重拉按钮：
                                          // 筛选太严时该做的是去设置里放宽条件。
                                          onRetry: _loadFailureMessage ==
                                                  GuessChartLoadingView
                                                      .emptyLibraryMessage
                                              ? _retryStartGame
                                              : null,
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
