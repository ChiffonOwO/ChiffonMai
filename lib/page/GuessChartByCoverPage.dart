import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_first_flutter_app/entity/GuessSong.dart';
import 'package:my_first_flutter_app/entity/Song.dart';
import 'package:my_first_flutter_app/manager/SongAliasManager.dart';
import 'package:my_first_flutter_app/service/GuessChartByCoverService.dart';
import 'package:my_first_flutter_app/utils/CoverUtil.dart';
import 'package:url_launcher/url_launcher.dart';

class GuessChartByCoverPage extends StatefulWidget {
  const GuessChartByCoverPage({super.key});

  @override
  State<GuessChartByCoverPage> createState() => _GuessChartByCoverPageState();
}

class _GuessChartByCoverPageState extends State<GuessChartByCoverPage> {
  // 游戏状态
  bool _isGameStarted = false;
  Song? _targetSong;
  List<GuessSong> _guessHistory = [];
  int _guessCount = 0;
  static const int _maxGuesses = 10;
  bool _isGameOver = false;
  bool _isWon = false;
  
  // 曲绘截取参数
  double? _cropX1;
  double? _cropY1;
  double? _cropX2;
  double? _cropY2;

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
    _initGame();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  // 初始化游戏
  Future<void> _initGame() async {
    await _songAliasManager.init();
    await _startNewGame();
  }

  // 开始新游戏
  Future<void> _startNewGame() async {
    setState(() {
      _isGameStarted = false;
      _isGameOver = false;
      _isWon = false;
      _guessHistory = [];
      _guessCount = 0;
      _searchController.clear();
      _searchResults = [];
      _showSearchResults = false;
      
      // 生成新的随机截取位置
      _generateRandomCropPosition();
    });

    // 随机选择目标歌曲
    _targetSong = await GuessChartByCoverService.randomSelectSong();
    if (_targetSong != null) {
      
      setState(() {
        _isGameStarted = true;
      });
    }
  }

  // 生成随机截取位置
  void _generateRandomCropPosition() {
    // 随机生成起始点和终点
    // 确保截取区域在0-1范围内
    double x1 = (DateTime.now().millisecondsSinceEpoch % 80) / 100.0;
    double y1 = ((DateTime.now().millisecondsSinceEpoch + 100) % 80) / 100.0;
    double x2 = x1 + (10 + (DateTime.now().millisecondsSinceEpoch % 30)) / 100.0; // 宽度随机
    double y2 = y1 + (10 + ((DateTime.now().millisecondsSinceEpoch + 200) % 30)) / 100.0; // 高度随机

    // 确保x2和y2不超过1
    x2 = x2 > 1 ? 1 : x2;
    y2 = y2 > 1 ? 1 : y2;

    // 保存截取参数，用于游戏结束时显示红框
    _cropX1 = x1;
    _cropY1 = y1;
    _cropX2 = x2;
    _cropY2 = y2;
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
      final allSongs = await GuessChartByCoverService.loadAllSongs();
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
    var guessSong = await GuessChartByCoverService.buildGuessSongEntity(guessedSong);
    // 计算猜测结果
    guessSong = await GuessChartByCoverService.calculateGuessResult(
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
      setState(() {
        _isGameOver = true;
        _isWon = true;
      });
    } else if (_guessCount >= _maxGuesses) {
      setState(() {
        _isGameOver = true;
        _isWon = false;
      });
    }
  }

  // 构建搜索结果项
  Widget _buildSearchResultItem(Song song) {
    // 曲绘将使用CoverPathUtil工具类加载

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
                        song.type,
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
    // 曲绘将使用CoverPathUtil工具类加载

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
                    '类型', guessSong.type, guessSong.typeBgColor ?? Colors.grey),
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
                child: _buildInfoItem('流派', guessSong.genre,
                    guessSong.genreBgColor ?? Colors.grey),
              ),
              const SizedBox(width: 8),
              Expanded(
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
                              _formatVersion(guessSong.version),
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

  // 格式化版本
  String _formatVersion(String version) {
    if (version == 'maimai') {
      return 'maimai';
    }
    if (version == 'maimai PLUS') {
      return 'maimai+';
    }
    if (version == 'maimai \u3067\u3089\u3063\u304f\u3059') {
      return 'DX 2020';
    }
    if (version == 'maimai \u3067\u3089\u3063\u304f\u3059 Splash') {
      return 'DX 2021';
    }
    if (version == 'maimai \u3067\u3089\u3063\u304f\u3059 UNiVERSE') {
      return 'DX 2022';
    }
    if (version == 'maimai \u3067\u3089\u3063\u304f\u3059 FESTiVAL') {
      return 'DX 2023';
    }
    if (version == 'maimai \u3067\u3089\u3063\u304f\u3059 BUDDiES') {
      return 'DX 2024';
    }
    if (version == 'maimai \u3067\u3089\u3063\u304f\u3059 PRiSM') {
      return 'DX 2025';
    }
    if (version.contains(' PLUS')) {
      version = version.replaceFirst(' PLUS', '+');
    }
    if (version.contains('maimai') && version != 'maimai') {
      version = version.replaceFirst('maimai ', '');
    }
    if (version.contains('\u3067\u3089\u3063\u304f\u3059')) {
      version = version.replaceFirst('\u3067\u3089\u3063\u304f\u3059 ', '');
    }
    return version;
  }

  // 裁剪曲绘，随机显示曲绘的一部分
  Widget _buildCroppedCover(String songId) {

    // 确保截取参数已生成
    if (_cropX1 == null || _cropY1 == null || _cropX2 == null || _cropY2 == null) {
      _generateRandomCropPosition();
    }

    double x1 = _cropX1!;
    double y1 = _cropY1!;
    double x2 = _cropX2!;
    double y2 = _cropY2!;

    return Container(
      width: 200, // 增大为原来的2倍 (100 -> 200)
      height: 200, // 增大为原来的2倍 (100 -> 200)
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 完整显示曲绘
            CoverUtil.buildCoverWidgetWithContext(context, songId, 200),
            // 顶部遮盖
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: y1 * 200,
              child: Container(color: Colors.black),
            ),
            // 底部遮盖
            Positioned(
              top: y2 * 200,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(color: Colors.black),
            ),
            // 左侧遮盖
            Positioned(
              top: y1 * 200,
              left: 0,
              width: x1 * 200,
              height: (y2 - y1) * 200,
              child: Container(color: Colors.black),
            ),
            // 右侧遮盖
            Positioned(
              top: y1 * 200,
              left: x2 * 200,
              right: 0,
              height: (y2 - y1) * 200,
              child: Container(color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 获取屏幕尺寸
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false, // 防止键盘弹出时挤压背景
      body: Stack(
        children: [
          // 层级1：基础背景图 - 占满整个屏幕，作为页面最底层背景
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background.png'), // 背景图资源
                fit: BoxFit.cover, // 覆盖整个容器，拉伸/裁剪适配
                opacity: 1.0, // 不透明
              ),
            ),
          ),

          // 层级2：第一张虚化装饰图 - 居中显示，轻微向上偏移
          Center(
            child: Transform.translate(
              offset: const Offset(0, -20), // 垂直向上偏移20px
              child: Transform.scale(
                scale: 1, // 不缩放
                child: Image.asset(
                  'assets/chiffon2.png',
                  fit: BoxFit.cover,
                  opacity: const AlwaysStoppedAnimation(1), // 固定不透明
                ),
              ),
            ),
          ),

          // 页面标题
          const Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "猜歌（曲绘）",
                style: TextStyle(
                  color: Color.fromARGB(255, 84, 97, 97),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),

          // 返回按钮
          Positioned(
            top: 20,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_back,
                  color: Color.fromARGB(255, 84, 97, 97), size: 24),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),

          // 主要内容区域
          Positioned(
            top: 80,
            left: 10,
            right: 10,
            bottom: 40,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showSearchResults = false;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8.0),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 5.0,
                      offset: Offset(2.0, 2.0),
                    ),
                  ],
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
                                              color: Colors.blue[50],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '猜测次数: $_guessCount/$_maxGuesses',
                                                  style: TextStyle(
                                                      fontSize:
                                                          screenWidth * 0.04),
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

                                          // 曲绘展示
                                          if (!_isGameOver && _targetSong != null)
                                            Center(
                                              child: _buildCroppedCover(_targetSong!.id),
                                            ),
                                          if (_isGameOver && _targetSong != null)
                                            Center(
                                              child: Container(
                                                width: 200, // 减小为原来的2/3 (300 -> 200)
                                                height: 200, // 减小为原来的2/3 (300 -> 200)
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(12),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withOpacity(0.2),
                                                      blurRadius: 10,
                                                      offset: Offset(0, 5),
                                                    ),
                                                  ],
                                                ),
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(12),
                                                  child: Stack(
                                                    fit: StackFit.expand,
                                                    children: [
                                                      CoverUtil.buildCoverWidgetWithContext(context, _targetSong!.id, 200),
                                                      // 红框框选出本轮截取的区域
                                                      if (_cropX1 != null && _cropY1 != null && _cropX2 != null && _cropY2 != null)
                                                        Positioned(
                                                          left: _cropX1! * 200,
                                                          top: _cropY1! * 200,
                                                          width: (_cropX2! - _cropX1!) * 200,
                                                          height: (_cropY2! - _cropY1!) * 200,
                                                          child: Container(
                                                            decoration: BoxDecoration(
                                                              border: Border.all(
                                                                color: Colors.red,
                                                                width: 2,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
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
                                                const SizedBox(width: 16),
                                                // 刷新按钮
                                                IconButton(
                                                  icon: const Icon(Icons.refresh,
                                                      color: Color.fromARGB(
                                                          255, 84, 97, 97),
                                                      size: 24),
                                                  onPressed: _startNewGame,
                                                ),
                                                const SizedBox(width: 16),
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
                                                const SizedBox(width: 16),
                                                // 投降按钮
                                                if (!_isGameOver)
                                                  TextButton(
                                                    onPressed: () {
                                                      setState(() {
                                                        _isGameOver = true;
                                                        _isWon = false;
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

                                          // 游戏结果显示
                                          if (_isGameOver)
                                            Container(
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
                                                                '${_targetSong!.ds.length > 3 ? _targetSong!.ds[3].toString() : '-'} | ${_targetSong!.ds.length > 4 ? _targetSong!.ds[4].toString() : '-'} | ${_formatVersion(_targetSong!.basicInfo.from)}',
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
                                                    fontSize: screenWidth * 0.045,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                                ...(_isAscending
                                                        ? _guessHistory
                                                        : _guessHistory.reversed.toList())
                                                    .asMap()
                                                    .entries
                                                    .map((entry) {
                                                  // 这里需要根据猜测历史的索引获取对应的歌曲，暂时使用null
                                                  int displayIndex = _isAscending
                                                      ? entry.key
                                                      : _guessHistory.length -
                                                          1 -
                                                          entry.key;
                                                  return _buildGuessHistoryItem(
                                                      entry.value,
                                                      displayIndex,
                                                      null);
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
          ),
        ],
      ),
    );
  }
}