// ignore: file_names
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';

import 'package:flutter/services.dart';
import '../service/DiffBest50Service.dart';
import '../service/DiffBest50ConvertToImgService.dart';
import '../manager/MaimaiMusicDataManager.dart';
import 'SongInfoPage.dart';
import '../utils/CoverPathUtil.dart';

class DiffBest50Page extends StatefulWidget {
  const DiffBest50Page({super.key});

  @override
  _DiffBest50PageState createState() => _DiffBest50PageState();
}

class _DiffBest50PageState extends State<DiffBest50Page> {
  Map<String, dynamic>? _diffBest50Data;
  List<dynamic>? _maimaiMusicData;
  List<Map<String, dynamic>> _diffSongs = [];
  bool _isLoading = true;
  
  // 尺寸相关变量
  late double screenWidth;
  late double screenHeight;
  late double cardPadding;
  late double fontSizeBase;

  @override
  void initState() {
    super.initState();
    _loadDiffBest50Data();
  }

  Future<void> _loadDiffBest50Data() async {
    try {
      // 加载maimai音乐数据
      // 优先使用缓存的API数据
      if (await MaimaiMusicDataManager().hasCachedData()) {
        final songs = await MaimaiMusicDataManager().getCachedSongs();
        if (songs != null) {
          setState(() {
            _maimaiMusicData = songs.map((song) => {
              'id': song.id,
              'title': song.title,
              'type': song.type,
              'ds': song.ds,
              'level': song.level,
              'cids': song.cids,
              'charts': song.charts.map((chart) => {
                'notes': chart.notes,
                'charter': chart.charter
              }).toList(),
              'basic_info': {
                'title': song.basicInfo.title,
                'artist': song.basicInfo.artist,
                'genre': song.basicInfo.genre,
                'bpm': song.basicInfo.bpm,
                'release_date': song.basicInfo.releaseDate,
                'from': song.basicInfo.from,
                'is_new': song.basicInfo.isNew
              }
            }).toList();
          });
        }
      } else {
        // 如果API数据不存在，尝试从资产文件加载JSON数据作为 fallback
        final maimaiContents = 
            await rootBundle.loadString('assets/maimai_music_data.json');
        final maimaiJsonData = json.decode(maimaiContents);

        setState(() {
          _maimaiMusicData = maimaiJsonData;
        });
      }

      // 计算DiffBest50数据
      final diffBest50Service = DiffBest50Service();
      final diffBest50Data = await diffBest50Service.calculateDiffBest50();
      
      setState(() {
        _diffBest50Data = diffBest50Data;
        _diffSongs = List<Map<String, dynamic>>.from(diffBest50Data['diffBest50'] ?? []);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 初始化尺寸相关变量
    screenWidth = MediaQuery.of(context).size.width;
    screenHeight = MediaQuery.of(context).size.height;
    cardPadding = screenWidth * 0.02;
    fontSizeBase = screenWidth * 0.035;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // 如果没有数据，显示空状态
    if (_diffBest50Data == null || _diffSongs.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.transparent,
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

            // 页面标题
            const Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  "拟合Best50查询",
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
              top: 40,
              left: 10,
              child: IconButton(
                icon: const Icon(Icons.arrow_back,
                    color: Color.fromARGB(255, 84, 97, 97), size: 24),
                onPressed: () {
                  Navigator.pop(context); // 返回到主页
                },
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

            // 浅白色背景区域
            Positioned(
              top: MediaQuery.of(context).size.height * 0.12,
              left: MediaQuery.of(context).size.width * 0.02,
              right: MediaQuery.of(context).size.width * 0.02,
              bottom: MediaQuery.of(context).size.height * 0.03,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8.0,
                      offset: Offset(2.0, 2.0),
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.refresh,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        '暂无拟合Best50数据',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '请返回首页点击"刷新数据"按钮获取',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

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

          // 页面标题
          const Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "拟合Best50查询",
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
            top: 40,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_back,
                  color: Color.fromARGB(255, 84, 97, 97), size: 24),
              onPressed: () {
                Navigator.pop(context); // 返回到主页
              },
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

          // 浅白色背景区域
          Positioned(
            top: MediaQuery.of(context).size.height * 0.12,
            left: MediaQuery.of(context).size.width * 0.02,
            right: MediaQuery.of(context).size.width * 0.02,
            bottom: MediaQuery.of(context).size.height * 0.03,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8.0,
                    offset: Offset(2.0, 2.0),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.03),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 评分区域
                    _buildRatingSection(),
                    SizedBox(height: 12.0),

                    // 导出按钮
                    _buildExportButton(),
                    SizedBox(height: 12.0),

                    // 基于拟合难度的Best50 标题区域
                    _buildSectionTitle( '基于拟合难度的Best50', context),

                    SizedBox(
                        height: MediaQuery.of(context).size.height * 0.015),

                    // 基于拟合难度的Best50 卡片网格
                    _buildDataCardGrid(_diffSongs,
                        MediaQuery.of(context).size.width > 600 ? 1.7 : 1.5),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 构建评分区域
  Widget _buildRatingSection() {
    // 计算各项指标
    int diffRatingSum = _diffBest50Data?['diffRatingSum'] ?? 0;
    int best50Diff = _diffBest50Data?['best50Diff'] ?? 0;
    double diffRatingAverage = _diffSongs.isNotEmpty ? diffRatingSum / _diffSongs.length : 0.0;

    // 计算平均达成率
    double achievementsSum = _diffSongs.fold(0.0,
        (sum, song) => sum + (double.parse(song['achievements'].toString())));
    double diffBest50AchievementAverage = 
        _diffSongs.isNotEmpty ? achievementsSum / _diffSongs.length : 0.0;

    // 计算平均scoreRate
    double scoreRateSum = _diffSongs.fold(0.0, (sum, song) {
      int songId = song['song_id'];
      int levelIndex = song['level_index'];
      int score = song['dxScore'];
      return sum + _calculateScoreRate(songId, levelIndex, score);
    });

    double diffBest50ScoreRateAverage = _diffSongs.isNotEmpty 
        ? scoreRateSum / _diffSongs.length 
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 2.0),
        borderRadius: BorderRadius.circular(8.0),
      ),
      padding: EdgeInsets.all(12.0),
      child: Row(
        children: [
          // 左侧评分
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '拟合总Rating',
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width * 0.045,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 4.0),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: diffRatingSum.toString(),
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width * 0.045,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: '(平均${diffRatingAverage.toStringAsFixed(1)})',
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width * 0.03,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8.0),
                Text(
                  '与Best50差值',
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width * 0.04,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Text(
                  '${best50Diff > 0 ? '+' : ''}$best50Diff',
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width * 0.04,
                    color: best50Diff >= 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // 右侧达成率
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '拟合Best50 平均达成率/DX分达成率',
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width * 0.035,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                _buildDualDecimalText(
                    diffBest50AchievementAverage, diffBest50ScoreRateAverage * 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 构建区域标题
  Widget _buildSectionTitle(String title, BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 2.0),
        borderRadius: BorderRadius.circular(8.0),
        color: Colors.grey[200],
      ),
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.02),
      child: Center(
        child: Text(
          title,
          style: TextStyle(
            fontSize: MediaQuery.of(context).size.width * 0.04,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  // 构建游戏卡片（支持多参数传入，确保响应式显示）
  Widget _buildGameCard({
    required Color cardColor,
    String songName = '未知歌曲',
    double achievementRate = 0.0,
    double difficulty = 0.0,
    bool dxMode = false,
    int score = 0,
    int rating = 0,
    String stars = '',
    String grade = '',
    int? songId,
    Color starsColor = Colors.white,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        border: Border.all(color: Colors.black, width: 2.0),
        borderRadius: BorderRadius.circular(8.0),
      ),
      padding: EdgeInsets.all(cardPadding),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 根据宽度动态调整字体大小（3个断点）
          double songNameFontSize = fontSizeBase;
          double decimalMainFontSize = screenWidth * 0.04;
          double decimalSmallFontSize = screenWidth * 0.03;
          double otherFontSize = screenWidth * 0.025;
          double gradeFontSize = screenWidth * 0.022;
          double dxFontSize = screenWidth * 0.025;

          double coverSize = screenWidth * 0.12;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 曲绘和难度
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: coverSize,
                    height: coverSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.black, width: 1.0),
                    ),
                    child: songId != null
                        ? CoverPathUtil.buildCoverWidgetWithContext(context, songId.toString(), coverSize)
                        : Center(
                            child: Text('曲绘',
                                style: TextStyle(fontSize: coverSize * 0.24)),
                          ),
                  ),
                  SizedBox(height: screenWidth * 0.01),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (dxMode)
                        Text(
                          'DX',
                          style: TextStyle(
                            fontSize: dxFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      if (dxMode == false)
                        Text(
                          'ST',
                          style: TextStyle(
                            fontSize: dxFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade300,
                          ),
                        ),
                      SizedBox(width: screenWidth * 0.01),
                      // 难度显示（使用动态字体大小）- 增大整体字号
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            difficulty.toStringAsFixed(2).split('.')[0],
                            style: TextStyle(
                              fontSize: decimalMainFontSize * 0.9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '.${difficulty.toStringAsFixed(2).split('.')[1]}',
                            style: TextStyle(
                              fontSize: decimalSmallFontSize * 0.9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(width: screenWidth * 0.02),

              // 右侧信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 歌曲名称：字数过多时显示省略号
                    Text(
                      songName,
                      style: TextStyle(
                        fontSize: songNameFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    SizedBox(height: screenWidth * 0.007),

                    // 达成率：使用动态字体大小
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          achievementRate.toStringAsFixed(4).split('.')[0],
                          style: TextStyle(
                            fontSize: decimalMainFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '.${achievementRate.toStringAsFixed(4).split('.')[1]}%',
                          style: TextStyle(
                            fontSize: decimalSmallFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),

                    // 评级、分数、星数：缩小字体完全显示
                    Row(
                      children: [
                        Text(
                          '$rating | $score |',
                          style: TextStyle(
                            fontSize: otherFontSize,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          stars,
                          style: TextStyle(
                            fontSize: otherFontSize,
                            color: starsColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    // 等级：缩小字体完全显示
                    Text(
                      grade,
                      style: TextStyle(
                        fontSize: gradeFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // 构建小数文本，整数部分字号大，小数部分和百分号字号小且底部对齐
  Widget _buildDecimalText(double value, BuildContext context,
      {bool isPercentage = false,
      int decimalPlaces = 4,
      Color color = Colors.white}) {
    String text = value.toStringAsFixed(decimalPlaces);

    // 分割整数部分和小数部分
    List<String> parts = text.split('.');
    String integerPart = parts[0];
    String decimalPart = parts.length > 1 ? '.${parts[1]}' : '';
    String percentageSymbol = isPercentage ? '%' : '';

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        // 整数部分
        Text(
          integerPart,
          style: TextStyle(
            fontSize: MediaQuery.of(context).size.width * 0.04,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        // 小数部分和百分号
        Text(
          '$decimalPart$percentageSymbol',
          style: TextStyle(
            fontSize: MediaQuery.of(context).size.width * 0.03,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // 构建双小数文本，如 "100.1234/97.54"
  Widget _buildDualDecimalText(double value1, double value2,
      {int decimalPlaces1 = 4,
      int decimalPlaces2 = 2,
      Color color = Colors.black}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double fontSize = MediaQuery.of(context).size.width * 0.04;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDecimalText(value1, context,
                decimalPlaces: decimalPlaces1, color: color),
            Text(
              '/',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            _buildDecimalText(value2, context,
                decimalPlaces: decimalPlaces2, color: color),
          ],
        );
      },
    );
  }

  // 构建数据驱动的卡片网格
  Widget _buildDataCardGrid(
      List<Map<String, dynamic>> songs, double childAspectRatio) {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero, // 移除默认padding
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: MediaQuery.of(context).size.width * 0.01,
        mainAxisSpacing: MediaQuery.of(context).size.width * 0.01,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: songs.length,
      itemBuilder: (context, index) {
        return _buildDataGameCard(songs[index]);
      },
    );
  }

  // 根据数据构建游戏卡片
  Widget _buildDataGameCard(Map<String, dynamic> songData) {
    // 解析数据
    double achievementRate = double.parse(songData['achievements'].toString());
    int score = songData['dxScore'];
    String fc = songData['fc'] ?? '';
    String fs = songData['fs'] ?? '';
    double difficulty = double.parse(songData['fit_diff'].toString());
    String rate = songData['rate'];
    int levelIndex = songData['level_index'];
    int rating = songData['diffRating'];
    String type = songData['type'];
    String title = songData['title'];
    int songId = songData['song_id'];

    // 计算星星等级
    String stars = _calculateStars(songId, levelIndex, score);
    Color starsColor = _getStarsColor(stars);

    // 映射FC属性
    String fcText = '-';
    if (fc.isNotEmpty) {
      if (fc == 'fcp') {
        fcText = 'FC+';
      } else if (fc == 'fc') {
        fcText = 'FC';
      } else if (fc == 'ap') {
        fcText = 'AP';
      } else if (fc == 'app') {
        fcText = 'AP+';
      }
    }

    // 映射FS属性
    String fsText = '-';
    if (fs.isNotEmpty) {
      if (fs == 'fsd') {
        fsText = 'FDX';
      } else if (fs == 'fsp') {
        fsText = 'FS+';
      } else if (fs == 'fs') {
        fsText = 'FS';
      } else if (fs == 'sync') {
        fsText = 'SC';
      } else if (fs == 'fsdp') {
        fsText = 'FDX+';
      }
    }
    // 映射Rate属性
    String rateText = rate;
    if (rateText == 'sssp') {
      rateText = 'SSS+';
    } else if (rateText == 'sss') {
      rateText = 'SSS';
    } else if (rateText == 'ssp') {
      rateText = 'SS+';
    } else if (rateText == 'ss') {
      rateText = 'SS';
    } else if (rateText == 'sp') {
      rateText = 'S+';
    } else if (rateText == 's') {
      rateText = 'S';
    } else if (rateText == 'aaa') {
      rateText = 'AAA';
    } else if (rateText == 'aa') {
      rateText = 'AA';
    } else if (rateText == 'a') {
      rateText = 'A';
    } else if (rateText == 'bbb') {
      rateText = 'BBB';
    } else if (rateText == 'bb') {
      rateText = 'BB';
    } else if (rateText == 'b') {
      rateText = 'B';
    } else if (rateText == 'c') {
      rateText = 'C';
    } else if (rateText == 'd') {
      rateText = 'D';
    }

    // 构建完整grade
    String grade = '$rateText | $fcText | $fsText';

    // 获取卡片颜色
    Color cardColor = _getCardColor(levelIndex);

    // 判断是否为DX模式
    bool dxMode = type == 'DX';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SongInfoPage(
              songId: songId.toString(),
              initialLevelIndex: levelIndex,
            ),
          ),
        );
      },
      child: _buildGameCard(
        cardColor: cardColor,
        songName: title,
        achievementRate: achievementRate,
        difficulty: difficulty,
        dxMode: dxMode,
        score: score,
        rating: rating,
        stars: stars,
        grade: grade,
        songId: songId,
        starsColor: starsColor,
      ),
    );
  }

  // 根据level_index获取卡片颜色
  Color _getCardColor(int levelIndex) {
    List<Color> colors = [
      Colors.green, // level_index 0
      Colors.yellow, // level_index 1
      Colors.red, // level_index 2
      Colors.purple.shade400, // level_index 3
      Colors.purple.shade200, // level_index 4
    ];
    return colors[levelIndex.clamp(0, 4)];
  }

  // 计算scoreRate
  double _calculateScoreRate(int songId, int levelIndex, int score) {
    if (_maimaiMusicData == null) return 0.0;

    // 查找对应的歌曲
    int songIndex = _maimaiMusicData!.indexWhere(
      (item) => item['id'] == songId.toString(),
    );

    if (songIndex == -1) return 0.0;
    dynamic songData = _maimaiMusicData![songIndex];

    if (songData['charts'] == null) return 0.0;

    // 查找对应的charts
    List<dynamic> charts = songData['charts'];
    if (levelIndex < 0 || levelIndex >= charts.length) return 0.0;

    dynamic chart = charts[levelIndex];
    if (chart['notes'] == null) return 0.0;

    // 计算maxScore
    List<dynamic> notes = chart['notes'];
    int notesSum = notes.fold(0, (sum, note) => sum + (note as int));
    int maxScore = notesSum * 3;

    // 计算scoreRate
    return maxScore > 0 ? score / maxScore : 0.0;
  }

  // 计算星星等级
  String _calculateStars(int songId, int levelIndex, int score) {
    double scoreRate = _calculateScoreRate(songId, levelIndex, score);

    // 确定星星等级
    if (scoreRate >= 0.97) {
      return '\u27265';
    } else if (scoreRate >= 0.95) {
      return '\u27264';
    } else if (scoreRate >= 0.93) {
      return '\u27263';
    } else if (scoreRate >= 0.90) {
      return '\u27262';
    } else if (scoreRate >= 0.85) {
      return '\u27261';
    } else {
      return '\u27260';
    }
  }

  // 获取星星颜色
  Color _getStarsColor(String stars) {
    switch (stars) {
      case '\u27265':
        return Colors.yellow;
      case '\u27264':
      case '\u27263':
        return Colors.orange;
      case '\u27262':
      case '\u27261':
        return Colors.green.shade300;
      default:
        return Colors.white;
    }
  }

  // 构建导出按钮
  Widget _buildExportButton() {
    return ElevatedButton(
      onPressed: _exportToImage,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        padding: EdgeInsets.symmetric(vertical: 12.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image, color: Colors.white),
          SizedBox(width: 8.0),
          Text(
            '导出为图片',
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.width * 0.04,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // 导出为图片
  Future<void> _exportToImage() async {
    try {
      // 显示加载指示器
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('导出中'),
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16.0),
              Text('正在生成图片...'),
            ],
          ),
        ),
      );

      // 调用导出方法
      final file = await DiffBest50ConvertToImg.convertToImage(
        context,
        _diffBest50Data,
        _diffSongs,
        _maimaiMusicData,
      );

      // 关闭加载指示器
      Navigator.pop(context);

      // 显示导出结果
      if (file != null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('导出成功'),
            content: Text('图片已保存到：\n${file.path}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('确定'),
              ),
            ],
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('导出失败'),
            content: Text('图片导出失败，请重试'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('确定'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // 关闭加载指示器
      Navigator.pop(context);
      
      // 显示错误信息
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('导出失败'),
          content: Text('导出过程中出现错误：\n$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('确定'),
            ),
          ],
        ),
      );
    }
  }
}