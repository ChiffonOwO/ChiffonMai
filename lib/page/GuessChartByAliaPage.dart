import 'dart:async';

import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:flutter/services.dart';
import 'package:my_first_flutter_app/entity/GuessSong.dart';
import 'package:my_first_flutter_app/entity/Song.dart';
import 'package:my_first_flutter_app/manager/SongAliasManager.dart';
import 'package:my_first_flutter_app/service/GuessChartByAliaService.dart';
import 'package:my_first_flutter_app/utils/CoverUtil.dart';
import 'package:url_launcher/url_launcher.dart';

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
  static const int _maxGuesses = 10;
  bool _isGameOver = false;
  bool _isWon = false;

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
    });

    // 随机选择目标歌曲
    _targetSong = await GuessChartByAliaService.randomSelectSong();
    if (_targetSong != null) {
      // 获取随机别名
      _targetAlias = GuessChartByAliaService.getRandomAlias(_targetSong!);
      
      setState(() {
        _isGameStarted = true;
      });
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

    // 剔除本局答案（目标歌曲）
    if (_targetSong != null) {
      results = results.where((song) => song.id != _targetSong!.id).toList();
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