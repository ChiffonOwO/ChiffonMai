import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

class B50ConvertToImg {
  // 全局Key，用于获取widget的渲染对象
  static GlobalKey _globalKey = GlobalKey();

  // 导出为图片的方法
  static Future<File?> convertToImage(BuildContext context, Map<String, dynamic>? b50Data, List<Map<String, dynamic>> sdSongs, List<Map<String, dynamic>> dxSongs, List<dynamic>? maimaiMusicData) async {
    try {
      // 创建一个GlobalKey
      GlobalKey globalKey = GlobalKey();

      // 创建一个Widget，用于生成图片
      Widget imageWidget = RepaintBoundary(
        key: globalKey,
        child: _buildExportImageWidget(context, b50Data, sdSongs, dxSongs, maimaiMusicData),
      );

      // 创建一个OverlayEntry
      OverlayEntry overlayEntry = OverlayEntry(
        builder: (context) => Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              // 临时添加到widget树中，位置设为屏幕外
              Positioned(
                left: -10000,
                top: -10000,
                child: SizedBox(
                  width: 1200,
                  height: 2000,
                  child: imageWidget,
                ),
              ),
            ],
          ),
        ),
      );

      // 将OverlayEntry添加到widget树中
      Overlay.of(context).insert(overlayEntry);

      // 等待下一帧，确保widget已经渲染完成
      await Future.delayed(Duration(milliseconds: 100));

      // 创建一个RenderRepaintBoundary
      final RenderRepaintBoundary? boundary = globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        print('Error: RenderRepaintBoundary not found');
        overlayEntry.remove();
        return null;
      }

      // 获取图片数据
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        print('Error: ByteData is null');
        overlayEntry.remove();
        return null;
      }

      // 将图片数据写入文件
      Uint8List pngBytes = byteData.buffer.asUint8List();
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        print('Error: External storage directory not found');
        overlayEntry.remove();
        return null;
      }

      final file = File('${directory.path}/b50_export_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes);
      print('Image saved to: ${file.path}');

      // 移除OverlayEntry
      overlayEntry.remove();

      return file;
    } catch (e) {
      print('Error converting to image: $e');
      return null;
    }
  }

  // 构建用于导出的Widget
  static Widget _buildExportImageWidget(BuildContext context, Map<String, dynamic>? b50Data, List<Map<String, dynamic>> sdSongs, List<Map<String, dynamic>> dxSongs, List<dynamic>? maimaiMusicData) {
    // 计算各项指标
    int rating = b50Data?['rating'] ?? 0;
    
    // 计算Best35相关指标
    int best35Sum = sdSongs.fold(0, (sum, song) => sum + ((song['ra'] ?? 0) as int));
    double best35Average = sdSongs.isNotEmpty ? best35Sum / sdSongs.length : 0.0;
    
    // 计算Best15相关指标
    int best15Sum = dxSongs.fold(0, (sum, song) => sum + ((song['ra'] ?? 0) as int));
    double best15Average = dxSongs.isNotEmpty ? best15Sum / dxSongs.length : 0.0;
    
    // 计算rating平均值
    double ratingAverage = (best35Sum + best15Sum) / 50;
    
    // 计算平均达成率
    double sdAchievementsSum = sdSongs.fold(0.0, (sum, song) => sum + (double.parse(song['achievements'].toString())));
    double dxAchievementsSum = dxSongs.fold(0.0, (sum, song) => sum + (double.parse(song['achievements'].toString())));
    
    double best50AchievementAverage = (sdAchievementsSum + dxAchievementsSum) / 50;
    double best35AchievementAverage = sdSongs.isNotEmpty ? sdAchievementsSum / sdSongs.length : 0.0;
    double best15AchievementAverage = dxSongs.isNotEmpty ? dxAchievementsSum / dxSongs.length : 0.0;
    
    // 计算DX分达成率
    double sdScoreRateSum = sdSongs.fold(0.0, (sum, song) {
      int songId = song['song_id'];
      int levelIndex = song['level_index'];
      int score = song['dxScore'];
      return sum + _calculateScoreRate(songId, levelIndex, score, maimaiMusicData);
    });
    
    double dxScoreRateSum = dxSongs.fold(0.0, (sum, song) {
      int songId = song['song_id'];
      int levelIndex = song['level_index'];
      int score = song['dxScore'];
      return sum + _calculateScoreRate(songId, levelIndex, score, maimaiMusicData);
    });
    
    double best50ScoreRateAverage = (sdSongs.length + dxSongs.length) > 0 
        ? (sdScoreRateSum + dxScoreRateSum) / (sdSongs.length + dxSongs.length) 
        : 0.0;
    
    double best35ScoreRateAverage = sdSongs.isNotEmpty ? sdScoreRateSum / sdSongs.length : 0.0;
    double best15ScoreRateAverage = dxSongs.isNotEmpty ? dxScoreRateSum / dxSongs.length : 0.0;

    // 创建一个容器，设置固定宽度以确保布局一致
    double containerWidth = 1200; // 适合5列布局的宽度

    return Container(
      width: containerWidth,
      color: Colors.white,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 评分区域
            _buildRatingSection(rating, ratingAverage, best35Sum, best35Average, best15Sum, best15Average, best50AchievementAverage, best35AchievementAverage, best15AchievementAverage, best50ScoreRateAverage, best35ScoreRateAverage, best15ScoreRateAverage),
            SizedBox(height: 20.0),

            // Best35 标题区域
            _buildSectionTitle('Best35 | 非当前版本最好成绩'),
            SizedBox(height: 16.0),

            // Best35 卡片网格 (5列)
            _buildDataCardGrid(sdSongs, 1.8, 5, b50Data, maimaiMusicData),
            SizedBox(height: 24.0),

            // Best15 标题区域
            _buildSectionTitle('Best15 | 当前版本最好成绩'),
            SizedBox(height: 16.0),

            // Best15 卡片网格 (5列)
            _buildDataCardGrid(dxSongs, 1.8, 5, b50Data, maimaiMusicData),
            SizedBox(height: 20.0),
          ],
        ),
      ),
    );
  }

  // 构建评分区域
  static Widget _buildRatingSection(int rating, double ratingAverage, int best35Sum, double best35Average, int best15Sum, double best15Average, double best50AchievementAverage, double best35AchievementAverage, double best15AchievementAverage, double best50ScoreRateAverage, double best35ScoreRateAverage, double best15ScoreRateAverage) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 2.0),
        borderRadius: BorderRadius.circular(8.0),
      ),
      padding: EdgeInsets.all(16.0),
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
                    fontSize: 22.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 8.0),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: rating.toString(),
                        style: TextStyle(
                          fontSize: 20.0,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: '(平均${ratingAverage.toStringAsFixed(1)})',
                        style: TextStyle(
                          fontSize: 16.0,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12.0),
                Text(
                  'Best 35',
                  style: TextStyle(
                    fontSize: 20.0,
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
                          fontSize: 20.0,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: '(平均${best35Average.toStringAsFixed(1)})',
                        style: TextStyle(
                          fontSize: 16.0,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12.0),
                Text(
                  'Best 15',
                  style: TextStyle(
                    fontSize: 20.0,
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
                          fontSize: 20.0,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: '(平均${best15Average.toStringAsFixed(1)})',
                        style: TextStyle(
                          fontSize: 16.0,
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
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                _buildDualDecimalText(best50AchievementAverage, best50ScoreRateAverage * 100),
                SizedBox(height: 12.0),
                Text(
                  'Best 35 平均达成率/DX分达成率',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                _buildDualDecimalText(best35AchievementAverage, best35ScoreRateAverage * 100),
                SizedBox(height: 12.0),
                Text(
                  'Best 15平均达成率/DX分达成率',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                _buildDualDecimalText(best15AchievementAverage, best15ScoreRateAverage * 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 构建区域标题
  static Widget _buildSectionTitle(String title) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 2.0),
        borderRadius: BorderRadius.circular(8.0),
        color: Colors.grey[200],
      ),
      padding: EdgeInsets.all(14.0),
      child: Center(
        child: Text(
          title,
          style: TextStyle(
            fontSize: 20.0,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  // 构建游戏卡片
  static Widget _buildGameCard({
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
      padding: EdgeInsets.all(10.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          double maxWidth = constraints.maxWidth;

          // 根据宽度动态调整字体大小（增大字体）
          double songNameFontSize = maxWidth > 160
              ? 16.0
              : maxWidth > 140
                  ? 15.0
                  : 14.0;
          double decimalMainFontSize = maxWidth > 160
              ? 18.0
              : maxWidth > 140
                  ? 17.0
                  : 16.0;
          double decimalSmallFontSize = maxWidth > 160
              ? 14.0
              : maxWidth > 140
                  ? 13.0
                  : 12.0;
          double otherFontSize = maxWidth > 160
              ? 12.0
              : maxWidth > 140
                  ? 11.0
                  : 10.0;
          double gradeFontSize = maxWidth > 160
              ? 11.0
              : maxWidth > 140
                  ? 10.5
                  : 10.0;
          double dxFontSize = maxWidth > 160
              ? 12.0
              : maxWidth > 140
                  ? 11.0
                  : 10.0;

          double coverSize = maxWidth > 160
              ? 60.0
              : maxWidth > 140
                  ? 55.0
                  : 50.0;

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
                        ? Image.asset(
                            'assets/cover/${songId.toString()}.webp',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Text('曲绘',
                                    style: TextStyle(fontSize: coverSize * 0.24)),
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
                      // 难度显示
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
                          if (difficulty.toString().split('.').length > 1)
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
                    // 歌曲名称
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

                    // 达成率
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

                    // 评级、分数、星数
                    Row(
                      children: [
                        Text(
                          '$rating | $score | ',
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

                    // 等级
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

  // 构建小数文本
  static Widget _buildDecimalText(double value, {
    bool isPercentage = false,
    int decimalPlaces = 4,
    Color color = Colors.white,
  }) {
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

  // 构建双小数文本
  static Widget _buildDualDecimalText(double value1, double value2, {
    int decimalPlaces1 = 4, 
    int decimalPlaces2 = 2, 
    Color color = Colors.black,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDecimalText(value1,
            decimalPlaces: decimalPlaces1, color: color),
        Text(
          '/',
          style: TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        _buildDecimalText(value2,
            decimalPlaces: decimalPlaces2, color: color),
      ],
    );
  }

  // 构建数据驱动的卡片网格
  static Widget _buildDataCardGrid(
      List<Map<String, dynamic>> songs, double childAspectRatio, int crossAxisCount, Map<String, dynamic>? b50Data, List<dynamic>? maimaiMusicData) {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 6.0,
        mainAxisSpacing: 6.0,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: songs.length,
      itemBuilder: (context, index) {
        return _buildDataGameCard(songs[index], b50Data, maimaiMusicData);
      },
    );
  }

  // 根据数据构建游戏卡片
  static Widget _buildDataGameCard(Map<String, dynamic> songData, Map<String, dynamic>? b50Data, List<dynamic>? maimaiMusicData) {
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
    
    // 计算星星等级
    String stars = _calculateStars(songId, levelIndex, score, maimaiMusicData);
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

    return _buildGameCard(
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
    );
  }

  // 根据level_index获取卡片颜色
  static Color _getCardColor(int levelIndex) {
    List<Color> colors = [
      Colors.green, // level_index 0
      Colors.yellow, // level_index 1
      Colors.red, // level_index 2
      Colors.purple, // level_index 3
      Colors.purple.shade300, // level_index 4
    ];
    return colors[levelIndex.clamp(0, 4)];
  }
  
  // 计算scoreRate
  static double _calculateScoreRate(int songId, int levelIndex, int score, List<dynamic>? maimaiMusicData) {
    if (maimaiMusicData == null) return 0.0;

    // 查找对应的歌曲
    dynamic songData = maimaiMusicData.firstWhere(
      (item) => item['id'] == songId.toString(),
      orElse: () => null,
    );

    if (songData == null || songData['charts'] == null) return 0.0;

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
  static String _calculateStars(int songId, int levelIndex, int score, List<dynamic>? maimaiMusicData) {
    double scoreRate = _calculateScoreRate(songId, levelIndex, score, maimaiMusicData);

    // 确定星星等级
    if (scoreRate >= 0.97) {
      return '※5';
    } else if (scoreRate >= 0.95) {
      return '※4';
    } else if (scoreRate >= 0.93) {
      return '※3';
    } else if (scoreRate >= 0.90) {
      return '※2';
    } else if (scoreRate >= 0.85) {
      return '※1';
    } else {
      return '※0';
    }
  }
  
  // 获取星星颜色
  static Color _getStarsColor(String stars) {
    switch (stars) {
      case '※5':
        return Colors.yellow;
      case '※4':
      case '※3':
        return Colors.orange;
      case '※2':
      case '※1':
        return Colors.green.shade300;
      default:
        return Colors.white;
    }
  }
}