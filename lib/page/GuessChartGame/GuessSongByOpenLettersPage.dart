import 'dart:async';

import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:flutter/services.dart';
import 'package:my_first_flutter_app/entity/Song.dart';
import 'package:my_first_flutter_app/manager/SongAliasManager.dart';
import 'package:my_first_flutter_app/service/GuessSongByOpenLettersService.dart';
import 'package:my_first_flutter_app/service/GuessChartGame/GuessChartCommonSettingsService.dart';
import 'package:my_first_flutter_app/utils/CoverUtil.dart';
import 'package:my_first_flutter_app/utils/StringUtil.dart';
import 'package:my_first_flutter_app/utils/CommonCacheUtil.dart';

class GuessSongByOpenLettersPage extends StatefulWidget {
  const GuessSongByOpenLettersPage({super.key});

  @override
  State<GuessSongByOpenLettersPage> createState() => _GuessSongByOpenLettersPageState();
}

class _GuessSongByOpenLettersPageState extends State<GuessSongByOpenLettersPage> {
  // 游戏状态
  bool _isGameStarted = false;
  List<Song> _targetSongs = [];
  Map<String, String> _maskedTitles = {};
  List<String> _guessedSongs = [];
  List<Song> _guessHistory = [];
  bool _isGameOver = false;
  bool _isWon = false;
  int _maxGuesses = 10; // 从设置中加载
  int _timeLimit = 0; // 从设置中加载，0表示无限制
  int _songCount = 3; // 每次抽取的歌曲数，默认3首
  
  // 倒计时相关
  int _remainingTime = 0;
  Timer? _countdownTimer;
  
  // 设置相关
  List<String> _selectedVersions = [];
  double _masterMinDx = 1.0;
  double _masterMaxDx = 15.0;
  List<String> _selectedGenres = [];
  int _nonEnglishCharThreshold = 50; // 非英文字符占比阈值，默认50%
  late GuessChartCommonSettingsService _settingsService;

  // 排序状态
  bool _isAscending = true; // true: 顺序, false: 逆序

  // 输入状态
  TextEditingController _openLetterController = TextEditingController();
  TextEditingController _answerController = TextEditingController();

  // 搜索状态
  List<Song> _searchResults = [];
  bool _isSearching = false;
  Timer? _searchTimer;
  static const Duration _searchDelay = Duration(milliseconds: 800);
  bool _showSearchResults = false;

  // 缓存工具
  final _cacheUtil = CommonCacheUtil();
  
  // 游戏时间记录
  DateTime? _gameStartTime;

  // 统计数据
  Map<String, dynamic> _stats = {
    'correct': 0,
    'wrong': 0,
    'accuracy': 0.0,
    'avgTime': 0.0,
  };

  @override
  void initState() {
    super.initState();
    _settingsService = GuessChartCommonSettingsService();
    _loadSettings();
    _initGame();
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
      _songCount = settings['songCount'] ?? 3;
      _nonEnglishCharThreshold = settings['nonEnglishCharThreshold'] ?? 50;
    });
  }
  
  // 加载统计数据
  Future<void> _loadStats() async {
    // 直接获取最新统计数据，不需要重置数据
    final stats = await _cacheUtil.getStats('6');
    setState(() {
      _stats = Map.from(stats); // 创建新的Map实例，确保触发重新构建
    });
  }
  
  // 记录游戏结果
  Future<void> _recordGameResult(bool isWon) async {
    if (_gameStartTime == null) return;
    
    // 计算游戏用时
    final gameTime = DateTime.now().difference(_gameStartTime!).inSeconds;
    
    // 记录结果
    if (isWon) {
      await _cacheUtil.recordSuccess('6');
    } else {
      await _cacheUtil.recordFailure('6');
    }
    
    // 结算游戏
    await _cacheUtil.settleGame('6', gameTime);
    
    // 重新加载统计数据
    await _loadStats();
  }

  @override
  void dispose() {
    _openLetterController.dispose();
    _answerController.dispose();
    _searchTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // 初始化游戏
  Future<void> _initGame() async {
    // 初始化缓存
    await _cacheUtil.initCache('6');
    await _loadStats();
    // 初始化歌曲别名管理器
    await SongAliasManager.instance.init();
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
      _targetSongs = [];
      _maskedTitles = {};
      _guessedSongs = [];
      _guessHistory = [];
      _openLetterController.clear();
      _answerController.clear();
      _searchResults = [];
      _showSearchResults = false;
      _remainingTime = _timeLimit; // 重置倒计时
      _gameStartTime = DateTime.now(); // 记录游戏开始时间
    });

    // 随机选择目标歌曲（使用设置的筛选条件和歌曲数量）
    _targetSongs = await GuessSongByOpenLettersService.randomSelectSongs(
      _songCount,
      selectedVersions: _selectedVersions,
      masterMinDx: _masterMinDx,
      masterMaxDx: _masterMaxDx,
      selectedGenres: _selectedGenres,
      nonEnglishCharThreshold: _nonEnglishCharThreshold,
    );
    if (_targetSongs.isNotEmpty) {
      // 初始化掩码
      for (var song in _targetSongs) {
        _maskedTitles[song.id] = _maskTitle(song.basicInfo.title);
      }
      
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

  // 生成初始掩码
  String _maskTitle(String title) {
    String result = '';
    for (int i = 0; i < title.length; i++) {
      if (title[i] == ' ') {
        result += ' ';
      } else {
        result += '□';
      }
    }
    return result;
  }

  // 处理开字母
  void _handleOpenLetter() {
    if (_isGameOver) return;
    
    String letter = _openLetterController.text.trim();
    if (letter.isEmpty || letter.length > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入一个字符！'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // 处理开字母请求（传递当前掩码状态以实现累积进度）
    Map<String, String> newMaskedTitles = GuessSongByOpenLettersService.openLetter(letter, _targetSongs, _maskedTitles);
    
    setState(() {
      _maskedTitles = newMaskedTitles;
      _openLetterController.clear();
    });
  }

  // 处理猜曲
  void _handleAnswer(String answer) async {
    if (_isGameOver) return;
    
    if (answer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入歌曲名称！'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // 检查答案
    bool isCorrect = GuessSongByOpenLettersService.checkAnswer(answer, _targetSongs);
    
    if (isCorrect) {
      // 找到猜对的歌曲
      Song? guessedSong = _targetSongs.firstWhere(
        (song) => song.basicInfo.title == answer,
      );
      
      setState(() {
        _guessedSongs.add(guessedSong.id);
        _guessHistory.add(guessedSong);
        _maskedTitles[guessedSong.id] = guessedSong.basicInfo.title; // 显示完整曲名
        _answerController.clear();
        _searchResults = [];
        _showSearchResults = false;
        
        // 检查是否猜中所有歌曲
        if (_guessedSongs.length == _targetSongs.length) {
          _isGameOver = true;
          _isWon = true;
          // 记录成功
          _recordGameResult(true);
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('猜对了！'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      // 找到猜错的歌曲
      Song? guessedSong = null;
      try {
        // 尝试从所有歌曲中找到匹配的歌曲
        final allSongs = await GuessSongByOpenLettersService.loadAllSongs();
        if (allSongs != null && allSongs.isNotEmpty) {
          // 先尝试通过标题匹配
          try {
            guessedSong = allSongs.firstWhere(
              (song) => song.basicInfo.title == answer,
            );
          } catch (e) {
            // 如果标题不匹配，尝试通过别名匹配
            for (var song in allSongs) {
              final aliases = SongAliasManager.instance.aliases[song.id] ?? [];
              if (aliases.contains(answer)) {
                guessedSong = song;
                break;
              }
            }
          }
        }
      } catch (e) {
        print('查找猜错的歌曲失败: $e');
      }
      
      // 将猜错的歌曲添加到猜测历史
      if (guessedSong != null) {
        setState(() {
          _guessHistory.add(guessedSong!);
          _answerController.clear();
          _searchResults = [];
          _showSearchResults = false;
        });
      }
      

    }
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

      // 搜索歌曲（支持原曲名和别名）
      final results = await GuessSongByOpenLettersService.searchSongs(value);
      
      setState(() {
        _searchResults = results;
        _showSearchResults = results.isNotEmpty;
        _isSearching = false;
      });
    });
  }

  // 从搜索结果选择歌曲
  void _selectSongFromSearch(Song song) {
    _handleAnswer(song.basicInfo.title);
  }

  // 构建搜索结果项
  Widget _buildSearchResultItem(Song song) {
    return GestureDetector(
      onTap: () {
        _selectSongFromSearch(song);
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建歌曲掩码显示
  Widget _buildSongMaskDisplay() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _targetSongs.map((song) {
        bool isGuessed = _guessedSongs.contains(song.id);
        
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isGuessed ? Colors.green[50] : Colors.white,
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
              // 曲绘和曲名
              Row(
                children: [
                  // 方形曲绘（投降后或猜中后显示）
                  if (_isGameOver || isGuessed)
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: CoverUtil.buildCoverWidgetWithContext(context, song.id, 60),
                      ),
                    ),
                  if (_isGameOver || isGuessed)
                    const SizedBox(width: 12),
                  // 曲名掩码
                  Expanded(
                    child: Text(
                      _maskedTitles[song.id] ?? '',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: isGuessed ? FontWeight.bold : FontWeight.normal,
                        color: isGuessed ? Colors.green : Colors.black,
                      ),
                      textAlign: _isGameOver || isGuessed ? TextAlign.left : TextAlign.center,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // 构建猜测历史项
  Widget _buildGuessHistoryItem(Song song, int originalIndex) {
    final screenWidth = MediaQuery.of(context).size.width;
    
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
            '猜测 #${originalIndex + 1}',
            style: TextStyle(
              fontSize: screenWidth * 0.035,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
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
                  child: CoverUtil.buildCoverWidgetWithContext(context, song.id, 60),
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
                          song.type == 'SD' ? 'ST' : song.type,
                          style: TextStyle(
                            fontSize: screenWidth * 0.035,
                            fontWeight: FontWeight.bold,
                            color: song.type == 'SD' ? Colors.blue : Colors.orange,
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            song.basicInfo.title,
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
                      '${song.basicInfo.artist} | ${song.basicInfo.genre}',
                      style: TextStyle(
                        fontSize: screenWidth * 0.03,
                        color: Colors.grey,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    // 第三行：masterDs | remasterDs | version
                    Text(
                      '${song.ds.length > 3 ? song.ds[3].toString() : '-'} | ${song.ds.length > 4 ? song.ds[4].toString() : '-'} | ${StringUtil.formatVersion2(song.basicInfo.from)}',
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
                Text('1. 游戏开始时，系统会随机从舞萌曲库中抽取${_songCount}首歌曲。'),
                const SizedBox(height: 8),
                const Text('2. 玩家可以发送 "开字母 X"（X 为任意汉字、日文、数字或符号，只能输入一个字符）。'),
                const SizedBox(height: 8),
                const Text('3. 若某首歌曲名包含该字，则揭示该字在歌名中的位置。'),
                const SizedBox(height: 8),
                const Text('4. 若不包含，则无提示。'),
                const SizedBox(height: 8),
                const Text('5. 玩家根据揭示的文字碎片，推理完整曲名，发送 "回答 曲名/别名" 作答。'),
                const SizedBox(height: 8),
                const Text('6. 猜中所有歌曲或点击投降结束游戏，会公布游戏结果。'),
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
    final allSongs = await GuessSongByOpenLettersService.loadAllSongs();
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
    int tempSongCount = _songCount;
    int tempNonEnglishCharThreshold = _nonEnglishCharThreshold;
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
                          tempSongCount = 3;
                          tempNonEnglishCharThreshold = 50;
                          showNoSongsError = false; // 重置错误提示
                        });
                      },
                    ),
                    // 歌曲数量设置
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '每次抽取歌曲数',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color.fromARGB(255, 84, 97, 97),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Column(
                            children: [
                              Slider(
                                value: tempSongCount.toDouble(),
                                min: 1,
                                max: 10,
                                divisions: 9,
                                label: '$tempSongCount 首',
                                onChanged: (value) {
                                  setState(() {
                                    tempSongCount = value.toInt();
                                  });
                                },
                              ),
                              Text('$tempSongCount 首'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 非英文字符占比阈值设置
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '非英文字符过滤百分比',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color.fromARGB(255, 84, 97, 97),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Column(
                            children: [
                              Slider(
                                value: tempNonEnglishCharThreshold.toDouble(),
                                min: 0,
                                max: 100,
                                divisions: 100,
                                label: '$tempNonEnglishCharThreshold%',
                                onChanged: (value) {
                                  setState(() {
                                    tempNonEnglishCharThreshold = value.toInt();
                                  });
                                },
                              ),
                              Text('$tempNonEnglishCharThreshold%'),
                              const SizedBox(height: 8),
                              Text(
                                '过滤日语+除空格以外的非英文字符在歌名中的占比大于等于此值的歌曲',
                                style: TextStyle(fontSize: 14, color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
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
                            setState(() {
                              tempSelectedVersions = [];
                              tempMasterMinDx = 1.0;
                              tempMasterMaxDx = 15.0;
                              tempSelectedGenres = [];
                              tempMaxGuesses = 10;
                              tempTimeLimit = 0;
                              tempSongCount = 3;
                              tempNonEnglishCharThreshold = 50;
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
                final testSongs = await GuessSongByOpenLettersService.randomSelectSongs(
                  tempSongCount,
                  selectedVersions: tempSelectedVersions,
                  masterMinDx: tempMasterMinDx,
                  masterMaxDx: tempMasterMaxDx,
                  selectedGenres: tempSelectedGenres,
                  nonEnglishCharThreshold: tempNonEnglishCharThreshold,
                );
                
                if (testSongs.isEmpty) {
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
                  songCount: tempSongCount,
                  nonEnglishCharThreshold: tempNonEnglishCharThreshold,
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

  @override
  Widget build(BuildContext context) {
    // 获取屏幕尺寸
    final screenWidth = MediaQuery.of(context).size.width;

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
                          '猜歌（开字母）',
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
                                                  '剩余歌曲: ${_targetSongs.length - _guessedSongs.length}/${_targetSongs.length}',
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
                                                          await _cacheUtil.resetStats('6');
                                                          await _loadStats();
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (_isGameOver)
                                                  Text(
                                                    _isWon
                                                        ? '恭喜你猜对了所有歌曲！'
                                                        : '游戏结束',
                                                    style: TextStyle(
                                                      fontSize:
                                                          screenWidth * 0.04,
                                                      fontWeight: FontWeight.bold,
                                                      color: _isWon
                                                          ? Colors.green
                                                          : Colors.red,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 20),

                                          // 歌曲掩码显示
                                          _buildSongMaskDisplay(),
                                          
                                          const SizedBox(height: 20),

                                          // 开字母输入
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
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: TextField(
                                                          controller: _openLetterController,
                                                          enabled: !_isGameOver,
                                                          decoration: const InputDecoration(
                                                            hintText: '输入一个字符',
                                                            border: InputBorder.none,
                                                            contentPadding:
                                                                EdgeInsets.all(12),
                                                          ),
                                                          inputFormatters: [
                                                            LengthLimitingTextInputFormatter(1),
                                                          ],
                                                        ),
                                                      ),
                                                      ElevatedButton(
                                                        onPressed: _isGameOver ? null : _handleOpenLetter,
                                                        child: const Text('开字母'),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          const SizedBox(height: 20),

                                          // 猜曲输入框和结果
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
                                                    controller: _answerController,
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
                                                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.3),
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
                                                      _isAscending = !_isAscending;
                                                    });
                                                  },
                                                ),
                                                const SizedBox(width: 8),
                                                // 投降按钮
                                                if (!_isGameOver)
                                                  TextButton(
                                                    onPressed: () {
                                                      // 显示所有未显示的字符
                                                      for (var song in _targetSongs) {
                                                        _maskedTitles[song.id] = song.basicInfo.title;
                                                      }
                                                      
                                                      setState(() {
                                                        _isGameOver = true;
                                                        _isWon = false;
                                                        // 记录失败
                                                        _recordGameResult(false);
                                                      });
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

                                          // 猜测历史
                                          if (_guessHistory.isNotEmpty)
                                            Container(
                                              margin: const EdgeInsets.only(top: 20),
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                                              decoration: BoxDecoration(
                                                color: Colors.grey[50],
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '猜测历史',
                                                    style: TextStyle(
                                                      fontSize: screenWidth * 0.04,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  ..._guessHistory.asMap().entries
                                                      .map((entry) => {
                                                        'song': entry.value,
                                                        'index': entry.key
                                                      })
                                                      .toList()
                                                      .asMap()
                                                      .entries
                                                      .map((entry) {
                                                        // 获取当前显示的歌曲
                                                        Song song = _isAscending 
                                                          ? _guessHistory[entry.key] 
                                                          : _guessHistory[_guessHistory.length - 1 - entry.key];
                                                        // 找到歌曲在原始列表中的索引
                                                        int originalIndex = _guessHistory.indexOf(song);
                                                        return _buildGuessHistoryItem(song, originalIndex);
                                                      })
                                                      .toList(),
                                                ],
                                              ),
                                            ),


                                        ])
                                        : const Center(
                                            child: CircularProgressIndicator(),
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