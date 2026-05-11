import 'dart:async';

import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:flutter/services.dart';
import 'package:my_first_flutter_app/entity/GuessSong.dart';
import 'package:my_first_flutter_app/entity/Song.dart';
import 'package:my_first_flutter_app/manager/SongAliasManager.dart';
import 'package:my_first_flutter_app/service/GuessChartGame/GuessChartByAliaService.dart';
import 'package:my_first_flutter_app/service/GuessChartGame/GuessChartCommonSettingsService.dart';
import 'package:my_first_flutter_app/utils/CoverUtil.dart';
import 'package:my_first_flutter_app/utils/CommonCacheUtil.dart';
import 'package:my_first_flutter_app/utils/StringUtil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:my_first_flutter_app/page/SongInfoPage.dart';

class GuessChartByAliaPage extends StatefulWidget {
  const GuessChartByAliaPage({super.key});

  @override
  State<GuessChartByAliaPage> createState() => _GuessChartByAliaPageState();
}

class _GuessChartByAliaPageState extends State<GuessChartByAliaPage> {
  // 游戏状态
  bool _isGameStarted = false;
  Song? _targetSong;
  String? _targetAlias;
  List<GuessSong> _guessHistory = [];
  int _guessCount = 0;
  int _maxGuesses = 10; // 从设置中加载
  int _timeLimit = 0; // 从设置中加载，0表示无限制
  bool _isGameOver = false;
  bool _isWon = false;
  
  // 倒计时相关
  int _remainingTime = 0;
  Timer? _countdownTimer;

  // 搜索状态
  TextEditingController _searchController = TextEditingController();
  List<Song> _searchResults = [];
  bool _isSearching = false;
  Timer? _searchTimer;
  static const Duration _searchDelay = Duration(milliseconds: 800);
  bool _showSearchResults = false;

  // 排序状态
  bool _isAscending = true; // true: 顺序, false: 逆序

  // 设置相关
  List<String> _selectedVersions = [];
  double _masterMinDx = 1.0;
  double _masterMaxDx = 15.0;
  List<String> _selectedGenres = [];
  late GuessChartCommonSettingsService _settingsService;

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
    _loadSettings();
    _initCache();
    _initGame();
  }
  
  // 初始化缓存
  Future<void> _initCache() async {
    await _cacheUtil.initCache('4');
    await _loadStats();
  }
  
  // 加载统计数据
  Future<void> _loadStats() async {
    // 直接获取最新统计数据，不需要重置数据
    final stats = await _cacheUtil.getStats('4');
    setState(() {
      _stats = Map.from(stats); // 创建新的Map实例，确保触发重新构建
    });
  }
  
  // 重置并刷新统计数据
  Future<void> _resetAndRefreshStats() async {
    // 先重置数据，然后获取最新统计数据
    await _cacheUtil.resetStats('4');
    final stats = await _cacheUtil.getStats('4');
    setState(() {
      _stats = Map.from(stats); // 创建新的Map实例，确保触发重新构建
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
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
    });
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
    
    // 加载最新的设置
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
      _remainingTime = _timeLimit; // 重置倒计时
      _gameStartTime = DateTime.now(); // 记录游戏开始时间
    });

    // 随机选择目标歌曲（使用设置的筛选条件）
    _targetSong = await GuessChartByAliaService.randomSelectSong(
      selectedVersions: _selectedVersions,
      masterMinDx: _masterMinDx,
      masterMaxDx: _masterMaxDx,
      selectedGenres: _selectedGenres,
    );
    if (_targetSong != null) {
      // 获取随机别名
      _targetAlias = GuessChartByAliaService.getRandomAlias(_targetSong!);
      
      setState(() {
        _isGameStarted = true;
      });
      
      // 启动倒计时
      _startCountdown();
    }
  }
  
  // 启动倒计时
  void _startCountdown() {
    if (_timeLimit <= 0) return; // 无时间限制
    
    // 先取消之前可能存在的倒计时
    _countdownTimer?.cancel();
    
    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (_isGameOver) {
          // 游戏已结束，取消倒计时
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

  // 处理搜索输入
  void _handleSearchInput(String value) {
    // 取消之前的定时器
    _searchTimer?.cancel();

    if (value.isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }

    // 设置新的定时器
    _searchTimer = Timer(_searchDelay, () async {
      if (value.isEmpty) return;

      setState(() {
        _isSearching = true;
      });

      // 加载所有歌曲
      final allSongs = await GuessChartByAliaService.loadAllSongs();
      if (allSongs != null) {
        // 搜索歌曲（支持原曲名和别名）
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

  // 计算两个字符串的字符符合数百分比
  double _calculateMatchPercentage(String query, String target) {
    if (target.isEmpty) return 0.0;
    
    query = query.toLowerCase();
    target = target.toLowerCase();
    
    int matchCount = 0;
    for (int i = 0; i < query.length; i++) {
      if (target.contains(query[i])) {
        matchCount++;
      }
    }
    
    return (matchCount / target.length) * 100;
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
        // 检查别名
        final songId = song.id;
        final aliases = _songAliasManager.aliases[songId];
        if (aliases != null &&
            aliases.any((alias) => alias.toLowerCase().contains(query))) {
          results.add(song);
        }
      }
    }

    // 只有当搜索词与目标别名的字符符合数≥30%时，才剔除本局答案
    if (_targetSong != null && _targetAlias != null) {
      double matchPercentage = _calculateMatchPercentage(query, _targetAlias!);
      if (matchPercentage >= 30) {
        results = results.where((song) => song.id != _targetSong!.id).toList();
      }
    }

    // 限制结果数量
    return results.take(20).toList();
  }

  // 处理猜测
  Future<void> _handleGuess(Song guessedSong) async {
    if (_isGameOver) return;

    // 检查是否已经猜过这首歌
    bool hasGuessed = _guessHistory.any((guess) => guess.songId == int.parse(guessedSong.id));
    if (hasGuessed) {
      // 显示提示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已经猜过这首歌了！'),
          duration: Duration(seconds: 2),
        ),
      );
      // 清空输入框
      _searchController.clear();
      _searchResults = [];
      _showSearchResults = false;
      return;
    }

    // 构建猜测实体
    var guessSong = await GuessChartByAliaService.buildGuessSongEntity(guessedSong);
    // 计算猜测结果
    guessSong = await GuessChartByAliaService.calculateGuessResult(
        guessSong, _targetSong!);

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
      // 记录成功
      await _recordGameResult(true);
    } else if (_maxGuesses > 0 && _guessCount >= _maxGuesses) {
      // 猜测次数用完，游戏结束
      _countdownTimer?.cancel();
      setState(() {
        _isGameOver = true;
        _isWon = false;
      });
      // 记录失败
      await _recordGameResult(false);
    }
  }
  
  // 记录游戏结果
  Future<void> _recordGameResult(bool isWon) async {
    if (_gameStartTime == null) return;
    
    // 计算游戏用时
    final gameTime = DateTime.now().difference(_gameStartTime!).inSeconds;
    
    // 记录结果
    if (isWon) {
      await _cacheUtil.recordSuccess('4');
    } else {
      await _cacheUtil.recordFailure('4');
    }
    
    // 结算游戏
    await _cacheUtil.settleGame('4', gameTime);
    
    // 重新加载统计数据
    await _loadStats();
  }

  // 构建搜索结果项
  Widget _buildSearchResultItem(Song song) {
    // 获取别名
    final aliases = _songAliasManager.aliases[song.id] ?? [];
    String aliasText = aliases.isNotEmpty ? aliases.join('、') : '';

    return GestureDetector(
      onTap: () {
        _handleGuess(song);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
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
                        song.type == 'SD' ? 'ST' : song.type,
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
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // 别名
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

  // 构建猜测历史项
  Widget _buildGuessHistoryItem(
      GuessSong guessSong, int index, Song? guessedSong) {
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
            offset: Offset(0, 2),
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
              // 方形曲绘
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
                      Text(
                        '曲师',
                        style:
                            const TextStyle(fontSize: 10, color: Colors.white),
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
                      Text(
                        'ReMaster谱师',
                        style:
                            const TextStyle(fontSize: 10, color: Colors.white),
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
                      Text(
                        '版本',
                        style:
                            const TextStyle(fontSize: 10, color: Colors.white),
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
          const SizedBox(height: 8),

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
          const SizedBox(height: 12),
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
                const Text('设计思路借鉴：'),
                GestureDetector(
                  onTap: () async {
                    final url = Uri.parse('https://maimai.yukineko2233.top/');
                    // 1. 检查是否能打开该链接
                    if (await canLaunchUrl(url)) {
                      // 2. 指定跳转到外部浏览器（关键：mode 参数）
                      await launchUrl(
                        url,
                        mode: LaunchMode.externalApplication, // 强制跳浏览器
                      );
                    } else {
                      // 提示用户无法打开
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('无法打开该链接')),
                      );
                    }
                  },
                  child: const Text(
                    'https://maimai.yukineko2233.top/',
                    style: TextStyle(
                      color: Colors.blue,
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
  
  // 显示设置对话框
  void _showSettingsDialog() async {
    // 加载最新的设置
    await _loadSettings();
    
    // 加载所有版本和流派
    final allSongs = await GuessChartByAliaService.loadAllSongs();
    Set<String> versions = {};
    Set<String> genres = {};
    
    if (allSongs != null) {
      for (var song in allSongs) {
        versions.add(song.basicInfo.from);
        genres.add(song.basicInfo.genre);
      }
    }
    
    // 按照游戏发布顺序排序版本
    List<String> allVersions = versions.toList()..sort((a, b) {
      // 定义版本顺序映射
      final Map<String, int> versionOrder = {
        'maimai': 1,
        'maimai PLUS': 2,
        'maimai GreeN': 3,
        'maimai GreeN PLUS': 4,
        'maimai ORANGE': 5,
        'maimai ORANGE PLUS': 6,
        'maimai PiNK': 7,
        'maimai PiNK PLUS': 8,
        'maimai MURASAKi': 9,
        'maimai MURASAKi PLUS': 10,
        'maimai MiLK': 11,
        'MiLK PLUS': 12,
        'maimai FiNALE': 13,
        'maimai でらっくす': 14,
        'maimai でらっくす Splash': 15,
        'maimai でらっくす UNiVERSE': 16,
        'maimai でらっくす FESTiVAL': 17,
        'maimai でらっくす BUDDiES': 18,
        'maimai でらっくす PRiSM': 19,
      };
      
      int orderA = versionOrder[a] ?? 999;
      int orderB = versionOrder[b] ?? 999;
      return orderA.compareTo(orderB);
    });
    // 移除宴会场选项
    genres.remove('宴会场');
    List<String> allGenres = genres.toList();
    
    // 临时变量用于存储设置
    List<String> tempSelectedVersions = List.from(_selectedVersions);
    double tempMasterMinDx = _masterMinDx;
    double tempMasterMaxDx = _masterMaxDx;
    List<String> tempSelectedGenres = List.from(_selectedGenres);
    int tempMaxGuesses = _maxGuesses;
    int tempTimeLimit = _timeLimit;
    bool showNoSongsError = false;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('设置'),
          contentPadding: EdgeInsets.all(8.0), // 减小对话框内边距
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
                          showNoSongsError = false; // 重置错误提示
                        });
                      },
                      (min, max) {
                        setState(() {
                          tempMasterMinDx = min;
                          tempMasterMaxDx = max;
                          showNoSongsError = false; // 重置错误提示
                        });
                      },
                      (genres) {
                        setState(() {
                          tempSelectedGenres = genres;
                          showNoSongsError = false; // 重置错误提示
                        });
                      },
                      (guesses) {
                        setState(() {
                          tempMaxGuesses = guesses;
                          showNoSongsError = false; // 重置错误提示
                        });
                      },
                      (time) {
                        setState(() {
                          tempTimeLimit = time;
                          showNoSongsError = false; // 重置错误提示
                        });
                      },
                      () {
                        setState(() {
                          tempSelectedVersions = [];
                          tempMasterMinDx = 1.0;
                          tempMasterMaxDx = 15.0;
                          tempSelectedGenres = [];
                          tempMaxGuesses = 10;
                          tempTimeLimit = 0;
                          showNoSongsError = false; // 重置错误提示
                        });
                      },
                    ),
                    // 重置按钮
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              tempSelectedVersions = [];
                              tempMasterMinDx = 1.0;
                              tempMasterMaxDx = 15.0;
                              tempSelectedGenres = [];
                              tempMaxGuesses = 10;
                              tempTimeLimit = 0;
                              showNoSongsError = false; // 重置错误提示
                            });
                          },
                          child: Text('重置所有设置'),
                        ),
                      ),
                    ),
                    // 显示错误提示
                    if (showNoSongsError)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          '没有找到符合条件的乐曲！请检查设置！',
                          style: TextStyle(color: Colors.red, fontSize: 14),
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
                // 检查是否有符合条件的乐曲
                final testSong = await GuessChartByAliaService.randomSelectSong(
                  selectedVersions: tempSelectedVersions,
                  masterMinDx: tempMasterMinDx,
                  masterMaxDx: tempMasterMaxDx,
                  selectedGenres: tempSelectedGenres,
                );
                
                if (testSong == null) {
                  // 没有找到符合条件的乐曲，显示错误提示
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('提示'),
                        content: const Text('没有找到符合条件的乐曲！请检查设置！'),
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
                  return;
                }
                
                // 保存设置到持久化存储
                await _settingsService.saveSettings(
                  selectedVersions: tempSelectedVersions,
                  masterMinDx: tempMasterMinDx,
                  masterMaxDx: tempMasterMaxDx,
                  selectedGenres: tempSelectedGenres,
                  maxGuesses: tempMaxGuesses,
                  timeLimit: tempTimeLimit,
                );
                
                Navigator.of(context).pop();
                
                // 提示设置已保存，将在下局生效
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('设置已保存，将在下局游戏生效')),
                );
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }



  // 显示别名
  Widget _buildAliasDisplay() {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Center(
        child: Text(
          _targetAlias ?? '加载中...',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 获取屏幕尺寸
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // 自定义常量
    final Color textPrimaryColor = Color.fromARGB(255, 84, 97, 97);
    final double borderRadiusSmall = 8.0;
    final BoxShadow defaultShadow = BoxShadow(
      color: Colors.black12,
      blurRadius: 5.0,
      offset: Offset(2.0, 2.0),
    );

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
              Container(
                padding: EdgeInsets.fromLTRB(16, 48, 16, 8),
                child: Row(
                  children: [
                    // 返回按钮
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: textPrimaryColor),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    // 标题
                    Expanded(
                      child: Center(
                        child: Text(
                          '猜歌（歌曲别名）',
                          style: TextStyle(
                            color: textPrimaryColor,
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

              // 主内容区域
              Expanded(
                child: Container(
                  margin: EdgeInsets.fromLTRB(8, 0, 8, 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(borderRadiusSmall),
                    boxShadow: [defaultShadow],
                  ),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _showSearchResults = false;
                      });
                    },
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
                                              color: Colors.blue[50],
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
                                                    '剩余时间: ${_remainingTime}秒',
                                                    style: TextStyle(
                                                        fontSize:
                                                            screenWidth * 0.04,
                                                        color: _remainingTime / _timeLimit <= 0.3 ? Colors.red : null),
                                                  ),
                                                // 统计数据
                                                Container(
                                                  margin: const EdgeInsets.only(top: 8),
                                                  child: Row(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              '今日统计: 正确${_stats['correct']} | 错误${_stats['wrong']}',
                                                              style: TextStyle(
                                                                  fontSize: screenWidth * 0.04,
                                                                  color: Colors.black
                                                              ),
                                                            ),
                                                            Text(
                                                              '正确率${_stats['accuracy'].toStringAsFixed(1)}% | 平均用时${_stats['avgTime'].toStringAsFixed(1)}秒',
                                                              style: TextStyle(
                                                                  fontSize: screenWidth * 0.04,
                                                                  color: Colors.black
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      IconButton(
                                                        padding: EdgeInsets.zero,
                                                        icon: const Icon(
                                                            Icons.refresh,
                                                            color: Color.fromARGB(255, 84, 97, 97),
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
                                                      fontWeight: FontWeight.bold,
                                                      color: _isWon
                                                          ? Colors.green
                                                          : Colors.red,
                                                    ),
                                                  ),
                                                if (_isGameOver && !_isWon)
                                                  Text(
                                                    '正确答案: ${_targetSong?.basicInfo.title}',
                                                    style: TextStyle(
                                                      fontSize:
                                                          screenWidth * 0.04,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 20),

                                          // 别名展示
                                          if (_targetSong != null)
                                            Center(
                                              child: _buildAliasDisplay(),
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
                                                        color: Colors.grey[300]!),
                                                  ),
                                                  child: TextField(
                                                    controller: _searchController,
                                                    onChanged: _handleSearchInput,
                                                    enabled: !_isGameOver,
                                                    decoration: const InputDecoration(
                                                      hintText: '输入歌曲名称或别名',
                                                      border: InputBorder.none,
                                                      contentPadding:
                                                          EdgeInsets.all(12),
                                                    ),
                                                  ),
                                                ),
                                                // 搜索结果
                                                if (_showSearchResults && _searchResults.isNotEmpty)
                                                  Container(
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: Colors.grey[300]!),
                                                      color: Colors.white,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black.withOpacity(0.2),
                                                          blurRadius: 10,
                                                          offset: Offset(0, 5),
                                                        ),
                                                      ],
                                                    ),
                                                    constraints: BoxConstraints(maxHeight: screenHeight * 0.3),
                                                    child: ListView.builder(
                                                      itemCount: _searchResults.length,
                                                      itemBuilder: (context, index) {
                                                        return _buildSearchResultItem(_searchResults[index]);
                                                      },
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),

                                          // 搜索中状态
                                          if (_isSearching)
                                            Container(
                                              margin:
                                                  const EdgeInsets.only(top: 8),
                                              padding: const EdgeInsets.all(16),
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
                                                // 规则按钮
                                                IconButton(
                                                  icon: const Icon(
                                                      Icons.info_outline,
                                                      color: Color.fromARGB(
                                                          255, 84, 97, 97),
                                                      size: 24),
                                                  onPressed: _showRulesDialog,
                                                ),
                                                const SizedBox(width: 8),
                                                // 设置按钮
                                                IconButton(
                                                  icon: const Icon(
                                                      Icons.settings,
                                                      color: Color.fromARGB(
                                                          255, 84, 97, 97),
                                                      size: 24),
                                                  onPressed: _showSettingsDialog,
                                                ),
                                                const SizedBox(width: 8),
                                                // 刷新按钮
                                                IconButton(
                                                  icon: const Icon(Icons.refresh,
                                                      color: Color.fromARGB(
                                                          255, 84, 97, 97),
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
                                                    color: Color.fromARGB(
                                                        255, 84, 97, 97),
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
                                                      // 投降时取消倒计时
                                                      _countdownTimer?.cancel();
                                                      setState(() {
                                                        _isGameOver = true;
                                                        _isWon = false;
                                                      });
                                                      // 记录失败
                                                      await _recordGameResult(false);
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
                                          ),

                                          // 游戏结果显示
                                          if (_isGameOver)
                                            GestureDetector(
                                              onTap: () {
                                                if (_targetSong != null) {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => SongInfoPage(
                                                        songId: _targetSong!.id,
                                                      ),
                                                    ),
                                                  );
                                                }
                                              },
                                              child: Container(
                                                margin:
                                                    const EdgeInsets.only(top: 20),
                                                padding: const EdgeInsets.all(16),
                                                decoration: BoxDecoration(
                                                  color: Colors.green[50],
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      _isWon ? '恭喜你猜对了！' : '本局答案',
                                                      style: TextStyle(
                                                        fontSize:
                                                            screenWidth * 0.04,
                                                        fontWeight: FontWeight.bold,
                                                        color: _isWon
                                                            ? Colors.green
                                                            : Colors.blue,
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
                                                              child: CoverUtil.buildCoverWidgetWithContext(context, _targetSong!.id, 60),
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
                                                                      _targetSong!.type == 'SD' ? 'ST' : _targetSong!.type,
                                                                      style: TextStyle(
                                                                        fontSize: screenWidth * 0.035,
                                                                        fontWeight: FontWeight.bold,
                                                                        color: _targetSong!.type == 'SD' ? Colors.blue : Colors.orange,
                                                                      ),
                                                                    ),
                                                                    SizedBox(width: 8),
                                                                    Expanded(
                                                                      child: Text(
                                                                        _targetSong!.basicInfo.title,
                                                                        style: TextStyle(
                                                                          fontSize: screenWidth * 0.035,
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
                                                                    fontSize: screenWidth * 0.03,
                                                                    color: Colors.grey,
                                                                  ),
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
                                                                // 第三行：masterDs | remasterDs | version
                                                              Text(
                                                                '${_targetSong!.ds.length > 3 ? _targetSong!.ds[3].toString() : '-'} | ${_targetSong!.ds.length > 4 ? _targetSong!.ds[4].toString() : '-'} | ${StringUtil.formatVersion2(_targetSong!.basicInfo.from)}',
                                                                style: TextStyle(
                                                                  fontSize: screenWidth * 0.03,
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
                                                ),
                                              ),
                                            ),

                                          const SizedBox(height: 20),

                                          // 猜测历史
                                          if (_guessHistory.isNotEmpty)
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                Text(
                                                  '猜测历史',
                                                  style: TextStyle(
                                                    fontSize: screenWidth * 0.05,
                                                    fontWeight: FontWeight.bold,
                                                    color: textPrimaryColor,
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                                ...(() {
                                                  // 根据排序状态处理猜测历史
                                                  List<MapEntry<int, GuessSong>> entries = _guessHistory.asMap().entries.toList();
                                                  if (!_isAscending) {
                                                    // 逆序排序
                                                    entries = entries.reversed.toList();
                                                  }
                                                  return entries.map((entry) {
                                                    int index = entry.key;
                                                    GuessSong guessSong = entry.value;
                                                    return _buildGuessHistoryItem(
                                                        guessSong, index, null);
                                                  }).toList();
                                                })(),
                                              ],
                                            ),
                                        ])
                                        : Container(
                                            padding: const EdgeInsets.all(16),
                                            child: const Center(
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
              ),
            ],
          ),
        ],
      ),
    );
  }
}