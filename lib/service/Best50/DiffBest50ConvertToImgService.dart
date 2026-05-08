import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:media_scanner/media_scanner.dart';
import 'package:my_first_flutter_app/utils/CoverUtil.dart';

class DiffBest50ConvertToImg {
  // 全局Key，用于获取widget的渲染对象
  // ignore: unused_field
  static GlobalKey _globalKey = GlobalKey();

  // 导出为图片的方法
  static Future<File?> convertToImage(BuildContext context, Map<String, dynamic>? diffBest50Data, List<Map<String, dynamic>> diffSongs, List<dynamic>? maimaiMusicData) async {
    try {
      // 创建一个GlobalKey
      GlobalKey globalKey = GlobalKey();

      // 创建一个Widget，用于生成图片
      Widget imageWidget = RepaintBoundary(
        key: globalKey,
        child: _buildExportImageWidget(context, diffBest50Data, diffSongs, maimaiMusicData),
      );

      // 创建一个OverlayEntry
      OverlayEntry overlayEntry = OverlayEntry(
        builder: (context) => Material(
          type: MaterialType.canvas,
          child: Stack(
            children: [
              // 临时添加到widget树中，位置设为屏幕外
              Positioned(
                left: -10000,
                top: -10000,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: 1200,
                    maxWidth: 1200,
                  ),
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
      await Future.delayed(Duration(milliseconds: 300)); // 增加延迟时间

      // 创建一个RenderRepaintBoundary
      final RenderRepaintBoundary? boundary = globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        print('Error: RenderRepaintBoundary not found');
        overlayEntry.remove();
        return null;
      }

      // 获取图片数据
      ui.Image image = await boundary.toImage(pixelRatio: 2.0); // 降低像素比，减少内存使用
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        print('Error: ByteData is null');
        overlayEntry.remove();
        return null;
      }

      // 将图片数据写入文件
      Uint8List pngBytes = byteData.buffer.asUint8List();
      
      // 尝试获取存储权限
      PermissionStatus status;
      
      // 对于 Android 13+，使用 photos 权限
      if (Platform.isAndroid) {
        print('Android platform detected, using photos permission');
        status = await Permission.photos.status;
        print('Initial photos permission status: $status');
        
        if (!status.isGranted) {
          print('Requesting photos permission...');
          status = await Permission.photos.request();
          print('Photos permission request result: $status');
        }
      } else {
        // 对于其他平台，使用 storage 权限
        print('Non-Android platform detected, using storage permission');
        status = await Permission.storage.status;
        print('Initial storage permission status: $status');
        
        if (!status.isGranted) {
          print('Requesting storage permission...');
          status = await Permission.storage.request();
          print('Storage permission request result: $status');
        }
      }
      
      if (status.isGranted) {
        print('Permission granted');
      } else if (status.isDenied) {
        print('Permission denied');
      } else if (status.isPermanentlyDenied) {
        print('Permission permanently denied');
      } else if (status.isRestricted) {
        print('Permission restricted');
      } else if (status.isLimited) {
        print('Permission limited');
      }
      
      // 优先使用相册目录（需要存储权限）
      Directory? directory;
      if (status.isGranted) {
        try {
          // 直接使用标准的相册目录路径
          String picturesPath = '/storage/emulated/0/Pictures';
          directory = Directory(picturesPath);
          print('Using pictures directory: $picturesPath');
          
          // 确保相册目录存在
          if (!directory.existsSync()) {
            directory.createSync(recursive: true);
            print('Created pictures directory: $picturesPath');
          }
        } catch (e) {
          print('Error getting pictures directory: $e');
        }
      }
      
      // 如果相册目录获取失败或没有权限，使用应用文档目录
      if (directory == null) {
        print('Using app documents directory');
        try {
          directory = await getApplicationDocumentsDirectory();
        } catch (e) {
          print('Error getting application documents directory: $e');
          // 备选方案：使用外部存储目录
          directory = await getExternalStorageDirectory();
        }
      }
      
      if (directory == null) {
        print('Error: No storage directory found');
        overlayEntry.remove();
        return null;
      }

      // 确保目录存在
      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }

      final file = File('${directory.path}/diff_b50_export_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes);
      print('Image saved to: ${file.path}');

      // 调用媒体扫描器，通知系统有新文件
      if (Platform.isAndroid) {
        await MediaScanner.loadMedia(path: file.path);
        print('Media scanner called for: ${file.path}');
      }

      // 移除OverlayEntry
      overlayEntry.remove();

      return file;
    } catch (e) {
      print('Error converting to image: $e');
      return null;
    }
  }

  // 构建用于导出的Widget
  static Widget _buildExportImageWidget(BuildContext context, Map<String, dynamic>? diffBest50Data, List<Map<String, dynamic>> diffSongs, List<dynamic>? maimaiMusicData) {
    // 计算各项指标
    int diffRatingSum = diffBest50Data?['diffRatingSum'] ?? 0;
    int best50Diff = diffBest50Data?['best50Diff'] ?? 0;
    double diffRatingAverage = diffSongs.isNotEmpty ? diffRatingSum / diffSongs.length : 0.0;

    // 计算平均达成率
    double achievementsSum = diffSongs.fold(0.0,
        (sum, song) => sum + (double.tryParse(song['achievements'].toString()) ?? 0.0));
    double diffBest50AchievementAverage = 
        diffSongs.isNotEmpty ? achievementsSum / diffSongs.length : 0.0;

    // 计算平均scoreRate
    double scoreRateSum = diffSongs.fold(0.0, (sum, song) {
      int songId = song['song_id'] ?? 0;
      int levelIndex = song['level_index'] ?? 0;
      int score = song['dxScore'] ?? 0;
      return sum + _calculateScoreRate(songId, levelIndex, score, maimaiMusicData);
    });

    double diffBest50ScoreRateAverage = diffSongs.isNotEmpty 
        ? scoreRateSum / diffSongs.length 
        : 0.0;

    // 创建一个容器，设置固定宽度以确保布局一致
    double containerWidth = 1200; // 适合5列布局的宽度

    return Container(
      width: containerWidth,
      decoration: BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 评分区域
                _buildRatingSection(context, diffRatingSum, diffRatingAverage, best50Diff, diffBest50AchievementAverage, diffBest50ScoreRateAverage),
                SizedBox(height: 20.0),

                // 基于拟合难度的Best50 标题区域
                _buildSectionTitle(context, '基于拟合难度的Best50'),
                SizedBox(height: 16.0),

                // 基于拟合难度的Best50 卡片网格 (5列)
                _buildDataCardGrid(context, diffSongs, 1.8, 5, maimaiMusicData),
                SizedBox(height: 20.0),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 构建评分区域
  static Widget _buildRatingSection(BuildContext context, int diffRatingSum, double diffRatingAverage, int best50Diff, double diffBest50AchievementAverage, double diffBest50ScoreRateAverage) {
    // 获取屏幕尺寸
    final screenWidth = MediaQuery.of(context).size.width;
    
    // 根据屏幕宽度计算字体大小
    double titleFontSize = screenWidth * 0.044; // 22.0 / 500
    double mainFontSize = screenWidth * 0.04; // 20.0 / 500
    double subFontSize = screenWidth * 0.032; // 16.0 / 500
    double sectionTitleFontSize = screenWidth * 0.04; // 20.0 / 500 (增大右侧标题字体)
    
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
                  '拟合总Rating',
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 8.0),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: diffRatingSum.toString(),
                        style: TextStyle(
                          fontSize: mainFontSize,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontFamily: "Source Han Sans",
                        ),
                      ),
                      TextSpan(
                        text: '(平均${diffRatingAverage.toStringAsFixed(1)})',
                        style: TextStyle(
                          fontSize: subFontSize,
                          color: Colors.black,
                          fontFamily: "Source Han Sans",
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12.0),
                Text(
                  '与Best50差值',
                  style: TextStyle(
                    fontSize: mainFontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Text(
                  '${best50Diff > 0 ? '+' : ''}$best50Diff',
                  style: TextStyle(
                    fontSize: mainFontSize,
                    color: best50Diff >= 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontFamily: "Source Han Sans",
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
                    fontSize: sectionTitleFontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                _buildDualDecimalText(context, diffBest50AchievementAverage, diffBest50ScoreRateAverage * 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 构建区域标题
  static Widget _buildSectionTitle(BuildContext context, String title) {
    // 获取屏幕尺寸
    final screenWidth = MediaQuery.of(context).size.width;
    
    // 根据屏幕宽度计算字体大小
    double fontSize = screenWidth * 0.04; // 20.0 / 500
    
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
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  // 构建游戏卡片
  static Widget _buildGameCard({
    required BuildContext context,
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
    // 获取屏幕尺寸
    final screenWidth = MediaQuery.of(context).size.width;
    
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
          double baseFontSize = screenWidth * 0.032; // 基础字体大小
          double songNameFontSize = maxWidth > 160
              ? baseFontSize * 1.25
              : maxWidth > 140
                  ? baseFontSize * 1.17
                  : baseFontSize * 1.1;
          double decimalMainFontSize = maxWidth > 160
              ? baseFontSize * 1.4
              : maxWidth > 140
                  ? baseFontSize * 1.33
                  : baseFontSize * 1.25;
          double decimalSmallFontSize = maxWidth > 160
              ? baseFontSize * 1.1
              : maxWidth > 140
                  ? baseFontSize * 1.03
                  : baseFontSize * 0.94;
          double otherFontSize = maxWidth > 160
              ? baseFontSize * 0.94
              : maxWidth > 140
                  ? baseFontSize * 0.86
                  : baseFontSize * 0.78;
          double gradeFontSize = maxWidth > 160
              ? baseFontSize * 0.86
              : maxWidth > 140
                  ? baseFontSize * 0.82
                  : baseFontSize * 0.78;
          double dxFontSize = maxWidth > 160
              ? baseFontSize * 0.94
              : maxWidth > 140
                  ? baseFontSize * 0.86
                  : baseFontSize * 0.78;

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
                        ? CoverUtil.buildCoverWidgetWithContext(context, songId.toString(), coverSize)
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
                            color: Colors.blue.shade300,
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
                            difficulty.toStringAsFixed(2).split('.')[0],
                            style: TextStyle(
                              fontSize: decimalMainFontSize * 0.9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: "Source Han Sans",
                            ),
                          ),
                          Text(
                            '.${difficulty.toStringAsFixed(2).split('.')[1]}',
                            style: TextStyle(
                              fontSize: decimalSmallFontSize * 0.9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: "Source Han Sans",
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
                            fontFamily: "Source Han Sans",
                          ),
                        ),
                        Text(
                          '.${achievementRate.toStringAsFixed(4).split('.')[1]}%',
                          style: TextStyle(
                            fontSize: decimalSmallFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: "Source Han Sans",
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
                            fontFamily: "Source Han Sans",
                          ),
                        ),
                        Text(
                          stars,
                          style: TextStyle(
                            fontSize: otherFontSize,
                            color: starsColor,
                            fontWeight: FontWeight.bold,
                            fontFamily: "Source Han Sans",
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
                        fontFamily: "Source Han Sans",
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
  static Widget _buildDecimalText(BuildContext context, double value, {
    bool isPercentage = false,
    int decimalPlaces = 4,
    Color color = Colors.white,
  }) {
    // 获取屏幕尺寸
    final screenWidth = MediaQuery.of(context).size.width;
    
    // 根据屏幕宽度计算字体大小
    double mainFontSize = screenWidth * 0.04; // 20.0 / 500 (增大数字字体)
    double subFontSize = screenWidth * 0.032; // 16.0 / 500 (增大小数部分字体)
    
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
            fontSize: mainFontSize,
            fontWeight: FontWeight.bold,
            color: color,
            fontFamily: "Source Han Sans",
          ),
        ),
        // 小数部分和百分号
        Text(
          '$decimalPart$percentageSymbol',
          style: TextStyle(
            fontSize: subFontSize,
            fontWeight: FontWeight.bold,
            color: color,
            fontFamily: "Source Han Sans",
          ),
        ),
      ],
    );
  }

  // 构建双小数文本
  static Widget _buildDualDecimalText(BuildContext context, double value1, double value2, {
    int decimalPlaces1 = 4, 
    int decimalPlaces2 = 2, 
    Color color = Colors.black,
  }) {
    // 获取屏幕尺寸
    final screenWidth = MediaQuery.of(context).size.width;
    
    // 根据屏幕宽度计算字体大小
    double fontSize = screenWidth * 0.036; // 18.0 / 500 (增大分隔符字体)
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDecimalText(context, value1,
            decimalPlaces: decimalPlaces1, color: color),
        Text(
          '/',
          style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: color,
                fontFamily: "Source Han Sans",
              ),
        ),
        _buildDecimalText(context, value2,
            decimalPlaces: decimalPlaces2, color: color),
      ],
    );
  }

  // 构建数据驱动的卡片网格
  static Widget _buildDataCardGrid(
      BuildContext context, List<Map<String, dynamic>> songs, double childAspectRatio, int crossAxisCount, List<dynamic>? maimaiMusicData) {
    return Container(
      width: 1200,
      child: GridView.builder(
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
          return _buildDataGameCard(context, songs[index], maimaiMusicData);
        },
      ),
    );
  }

  // 根据数据构建游戏卡片
  static Widget _buildDataGameCard(BuildContext context, Map<String, dynamic> songData, List<dynamic>? maimaiMusicData) {
    // 解析数据
    double achievementRate = double.tryParse(songData['achievements'].toString()) ?? 0.0;
    int score = songData['dxScore'] ?? 0;
    String fc = songData['fc'] ?? '';
    String fs = songData['fs'] ?? '';
    double difficulty = double.tryParse(songData['fit_diff'].toString()) ?? 0.0;
    String rate = songData['rate'] ?? '';
    int levelIndex = songData['level_index'] ?? 0;
    int rating = songData['diffRating'] ?? 0;
    String type = songData['type'] ?? '';
    String title = songData['title'] ?? '未知歌曲';
    int songId = songData['song_id'] ?? 0;
    
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
      context: context,
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
      Colors.purple.shade400, // level_index 3
      Colors.purple.shade200, // level_index 4
    ];
    return colors[levelIndex.clamp(0, 4)];
  }
  
  // 计算scoreRate
  static double _calculateScoreRate(int songId, int levelIndex, int score, List<dynamic>? maimaiMusicData) {
    try {
      if (maimaiMusicData == null) return 0.0;

      // 查找对应的歌曲
      dynamic songData;
      try {
        songData = maimaiMusicData.firstWhere(
          (item) => item['id'] == songId.toString(),
        );
      } catch (e) {
        // 如果找不到歌曲，返回0.0
        return 0.0;
      }

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
    } catch (e) {
      print('Error calculating score rate: $e');
      return 0.0;
    }
  }

  // 计算星星等级
  static String _calculateStars(int songId, int levelIndex, int score, List<dynamic>? maimaiMusicData) {
    double scoreRate = _calculateScoreRate(songId, levelIndex, score, maimaiMusicData);

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
  static Color _getStarsColor(String stars) {
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
}