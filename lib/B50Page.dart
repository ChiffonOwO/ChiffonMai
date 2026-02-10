import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';

import 'package:flutter/services.dart';

class B50Page extends StatefulWidget {
  @override
  _B50PageState createState() => _B50PageState();
}

class _B50PageState extends State<B50Page> {
  Map<String, dynamic>? _b50Data;
  List<Map<String, dynamic>> _dxSongs = [];
  List<Map<String, dynamic>> _sdSongs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadB50Data();
  }

  Future<void> _loadB50Data() async {
    try {
      // 加载JSON文件
      final contents = await rootBundle.loadString('assets/b50testdata.json');
      final jsonData = json.decode(contents);

      setState(() {
        _b50Data = jsonData;
        // 增加空值判断，避免解析失败
        _dxSongs = jsonData['charts']?['dx'] != null
            ? List<Map<String, dynamic>>.from(jsonData['charts']['dx'])
            : [];
        _sdSongs = jsonData['charts']?['sd'] != null
            ? List<Map<String, dynamic>>.from(jsonData['charts']['sd'])
            : [];
        _isLoading = false;
      });

    } catch (e) {
      print('Error loading B50 data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: CircularProgressIndicator(),
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
            top: 20.0,
            left: 5.0,
            right: 5.0,
            bottom: 20.0,
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
                padding: EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 评分区域
                    _buildRatingSection(),
                    SizedBox(height: 12.0),

                    // Best35 标题区域
                    _buildSectionTitle('Best35 | 非当前版本最好成绩'),

                    SizedBox(height: 12.0),

                    // Best35 卡片网格 (sd数组)
                    _buildDataCardGrid(_sdSongs, 1.65),
                    SizedBox(height: 16.0),

                    // Best15 标题区域
                    _buildSectionTitle('Best15 | 当前版本最好成绩'),

                    SizedBox(height: 12.0),

                    // Best15 卡片网格 (dx数组)
                    _buildDataCardGrid(_dxSongs, 1.65),
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
    int rating = _b50Data?['rating'] ?? 0;
    
    // 计算Best35相关指标
    int best35Sum = _sdSongs.fold(0, (sum, song) => sum + ((song['ra'] ?? 0) as int));
    double best35Average = _sdSongs.isNotEmpty ? best35Sum / _sdSongs.length : 0.0;
    
    // 计算Best15相关指标
    int best15Sum = _dxSongs.fold(0, (sum, song) => sum + ((song['ra'] ?? 0) as int));
    double best15Average = _dxSongs.isNotEmpty ? best15Sum / _dxSongs.length : 0.0;
    
    // 计算rating平均值
    double ratingAverage = (best35Sum + best15Sum) / 50;
    
    // 计算平均达成率
    double sdAchievementsSum = _sdSongs.fold(0.0, (sum, song) => sum + (double.parse(song['achievements'].toString())));
    double dxAchievementsSum = _dxSongs.fold(0.0, (sum, song) => sum + (double.parse(song['achievements'].toString())));
    
    double best50AchievementAverage = (sdAchievementsSum + dxAchievementsSum) / 50;
    double best35AchievementAverage = _sdSongs.isNotEmpty ? sdAchievementsSum / _sdSongs.length : 0.0;
    double best15AchievementAverage = _dxSongs.isNotEmpty ? dxAchievementsSum / _dxSongs.length : 0.0;
    
    // 计算DX分达成率（保留四位小数）
    double dxScoreSum = _sdSongs.fold(0.0, (sum, song) => sum + ((song['dxScore'] ?? 0) as int)) + 
                       _dxSongs.fold(0.0, (sum, song) => sum + ((song['dxScore'] ?? 0) as int));
    double best50DxScoreAverage = _sdSongs.length + _dxSongs.length > 0 ? dxScoreSum / (_sdSongs.length + _dxSongs.length) : 0.0;
    
    double best35DxScoreSum = _sdSongs.fold(0.0, (sum, song) => sum + ((song['dxScore'] ?? 0) as int));
    double best35DxScoreAverage = _sdSongs.isNotEmpty ? best35DxScoreSum / _sdSongs.length : 0.0;
    
    double best15DxScoreSum = _dxSongs.fold(0.0, (sum, song) => sum + ((song['dxScore'] ?? 0) as int));
    double best15DxScoreAverage = _dxSongs.isNotEmpty ? best15DxScoreSum / _dxSongs.length : 0.0;

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
                  'Rating',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 4.0),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: rating.toString(),
                        style: TextStyle(
                          fontSize: 16.0,
                          color: Colors.black,
                        ),
                      ),
                      TextSpan(
                        text: '(平均${ratingAverage.toStringAsFixed(1)})',
                        style: TextStyle(
                          fontSize: 12.0,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8.0),
                Text(
                  'Best 35',
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: best35Sum.toString(),
                        style: TextStyle(
                          fontSize: 16.0,
                          color: Colors.black,
                        ),
                      ),
                      TextSpan(
                        text: '(平均${best35Average.toStringAsFixed(1)})',
                        style: TextStyle(
                          fontSize: 12.0,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8.0),
                Text(
                  'Best 15',
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: best15Sum.toString(),
                        style: TextStyle(
                          fontSize: 16.0,
                          color: Colors.black,
                        ),
                      ),
                      TextSpan(
                        text: '(平均${best15Average.toStringAsFixed(1)})',
                        style: TextStyle(
                          fontSize: 12.0,
                          color: Colors.black,
                        ),
                      ),
                    ],
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
                  'Best 50 平均达成率/DX分达成率',
                  style: TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                _buildDualDecimalText(best50AchievementAverage, best50DxScoreAverage),
                SizedBox(height: 8.0),
                Text(
                  'Best 35 平均达成率/DX分达成率',
                  style: TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                _buildDualDecimalText(best35AchievementAverage, best35DxScoreAverage),
                SizedBox(height: 8.0),
                Text(
                  'Best 15平均达成率/DX分达成率',
                  style: TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                _buildDualDecimalText(best15AchievementAverage, best15DxScoreAverage),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 构建区域标题
  Widget _buildSectionTitle(String title) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 2.0),
        borderRadius: BorderRadius.circular(8.0),
        color: Colors.grey[200],
      ),
      padding: EdgeInsets.all(8.0),
      child: Center(
        child: Text(
          title,
          style: TextStyle(
            fontSize: 16.0,
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
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        border: Border.all(color: Colors.black, width: 2.0),
        borderRadius: BorderRadius.circular(8.0),
      ),
      padding: EdgeInsets.all(8.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          double maxWidth = constraints.maxWidth;

          // 根据宽度动态调整字体大小（3个断点）
          double songNameFontSize = maxWidth > 160
              ? 14.0
              : maxWidth > 140
                  ? 13.0
                  : 12.0;
          double decimalMainFontSize = maxWidth > 160
              ? 16.0
              : maxWidth > 140
                  ? 15.0
                  : 14.0;
          double decimalSmallFontSize = maxWidth > 160
              ? 12.0
              : maxWidth > 140
                  ? 11.0
                  : 10.0;
          double otherFontSize = maxWidth > 160
              ? 10.0
              : maxWidth > 140
                  ? 9.0
                  : 8.0;
          double gradeFontSize = maxWidth > 160
              ? 9.0
              : maxWidth > 140
                  ? 8.5
                  : 8.0;
          double dxFontSize = maxWidth > 160
              ? 10.0
              : maxWidth > 140
                  ? 9.0
                  : 8.0;

          double coverSize = maxWidth > 160
              ? 50.0
              : maxWidth > 140
                  ? 45.0
                  : 40.0;

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
                        ? Image.network(
                            'https://www.diving-fish.com/covers/${songId.toString().padLeft(5, '0')}.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Text('曲绘',
                                    style:
                                        TextStyle(fontSize: coverSize * 0.24)),
                              );
                            },
                          )
                        : Center(
                            child: Text('曲绘',
                                style: TextStyle(fontSize: coverSize * 0.24)),
                          ),
                  ),
                  SizedBox(height: 4.0),
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
                            color: Colors.blue.shade600,
                          ),
                        ),
                      SizedBox(width: 4.0),
                      // 难度显示（使用动态字体大小）- 增大整体字号
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            difficulty.toString().split('.')[0],
                            style: TextStyle(
                              fontSize: decimalMainFontSize * 0.9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '.${difficulty.toString().split('.')[1]}',
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
              SizedBox(width: 8.0),

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
                    SizedBox(height: 3.0),

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
                    Text(
                      '$rating | $score | $stars',
                      style: TextStyle(
                        fontSize: otherFontSize,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
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
  Widget _buildDecimalText(double value,
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
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        // 小数部分和百分号
        Text(
          '$decimalPart$percentageSymbol',
          style: TextStyle(
            fontSize: 12.0,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // 构建双小数文本，如 "100.1234/97.54"
  Widget _buildDualDecimalText(double value1, double value2,
      {int decimalPlaces1 = 4, int decimalPlaces2 = 2, Color color = Colors.black}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double fontSize = constraints.maxWidth > 180 ? 16.0 : 14.0;
        double smallFontSize = constraints.maxWidth > 180 ? 12.0 : 10.0;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDecimalText(value1,
                decimalPlaces: decimalPlaces1, color: color),
            Text(
              '/',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            _buildDecimalText(value2,
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
        crossAxisSpacing: 4.0,
        mainAxisSpacing: 4.0,
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
    double difficulty = double.parse(songData['ds'].toString());
    String rate = songData['rate'];
    int levelIndex = songData['level_index'];
    int rating = songData['ra'];
    String type = songData['type'];
    String title = songData['title'];
    int songId = songData['song_id'];

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

    return _buildGameCard(
      cardColor: cardColor,
      songName: title,
      achievementRate: achievementRate,
      difficulty: difficulty,
      dxMode: dxMode,
      score: score,
      rating: rating,
      stars: '',
      grade: grade,
      songId: songId,
    );
  }

  // 根据level_index获取卡片颜色
  Color _getCardColor(int levelIndex) {
    List<Color> colors = [
      Colors.green, // level_index 0
      Colors.yellow, // level_index 1
      Colors.red, // level_index 2
      Colors.purple, // level_index 3
      Colors.purple.shade300, // level_index 4
    ];
    return colors[levelIndex.clamp(0, 4)];
  }
}