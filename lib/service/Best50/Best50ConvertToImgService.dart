import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:media_scanner/media_scanner.dart';
import 'package:my_first_flutter_app/utils/CoverUtil.dart';
import 'package:my_first_flutter_app/utils/TextStyleUtil.dart';
import 'package:my_first_flutter_app/utils/ColorUtil.dart';
import 'package:my_first_flutter_app/utils/StringUtil.dart';
import 'package:my_first_flutter_app/constant/CacheKeyConstant.dart';

class B50ConvertToImg {
  // 全局Key，用于获取widget的渲染对象
  // ignore: unused_field
  static GlobalKey _globalKey = GlobalKey();

  // 导出为图片的方法
  static Future<File?> convertToImage(BuildContext context, Map<String, dynamic>? b50Data, List<Map<String, dynamic>> sdSongs, List<Map<String, dynamic>> dxSongs, List<dynamic>? maimaiMusicData, {bool isTheoreticalMode = false}) async {
    OverlayEntry? overlayEntry;
    try {
      debugPrint('=== STARTING IMAGE CONVERSION ===');
      debugPrint('Current platform: ${Platform.operatingSystem} ${Platform.version}');
      
      // 首先请求存储权限（在导出前请求）
      debugPrint('Step 1: Requesting storage permission...');
      PermissionStatus status = await _requestStoragePermission();
      debugPrint('Step 1 completed: Storage permission status: $status');
      debugPrint('Is granted: ${status.isGranted}');
      
      // 创建一个GlobalKey
      GlobalKey globalKey = GlobalKey();

      // 创建一个Widget，用于生成图片
      Widget imageWidget = RepaintBoundary(
        key: globalKey,
        child: await _buildExportImageWidget(context, b50Data, sdSongs, dxSongs, maimaiMusicData, isTheoreticalMode: isTheoreticalMode),
      );

      // 创建一个屏幕外的OverlayEntry，避免影响主UI
      // 使用Positioned将Widget定位到屏幕外，确保它被渲染但不可见
      overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          left: -9999, // 移到屏幕外
          top: -9999,
          width: 1200,
          child: Material(
            type: MaterialType.transparency,
            child: imageWidget,
          ),
        ),
      );

      // 预加载图片资源
      await _preloadImages(context);
      debugPrint('Images preloaded');

      // 将OverlayEntry添加到widget树中
      Overlay.of(context).insert(overlayEntry);
      debugPrint('Overlay entry inserted');

      // 等待渲染完成（使用WidgetsBinding确保所有帧都已处理）
      await _waitForRender();
      debugPrint('Render wait completed');

      // 创建一个RenderRepaintBoundary
      final RenderRepaintBoundary? boundary = globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        debugPrint('Error: RenderRepaintBoundary not found');
        overlayEntry.remove();
        return null;
      }
      debugPrint('RenderRepaintBoundary found successfully');
      
      // 额外等待确保边界框已准备好
      await Future.delayed(Duration(milliseconds: 100));

      // 获取图片数据（异步执行，避免阻塞主线程）
      debugPrint('Starting image capture...');
      ui.Image image;
      try {
        // 尝试直接捕获图片，使用更高的pixelRatio提高清晰度
        image = await boundary.toImage(pixelRatio: 3.0);
        debugPrint('Image captured successfully');
      } catch (e) {
        debugPrint('First capture failed: $e');
        // 重试一次
        await Future.delayed(Duration(milliseconds: 200));
        image = await boundary.toImage(pixelRatio: 3.0);
        debugPrint('Image captured on retry');
      }
      
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        debugPrint('Error: ByteData is null');
        overlayEntry.remove();
        image.dispose();
        return null;
      }
      debugPrint('ByteData conversion successful');

      // 将图片数据写入文件
      Uint8List pngBytes = byteData.buffer.asUint8List();
      
      // 释放图片资源
      image.dispose();
      
      // 立即移除Overlay，避免占用资源
      overlayEntry.remove();
      
      // 优先使用相册目录（需要存储权限）
      Directory? directory;
      debugPrint('Step 4: Saving image. Permission granted: ${status.isGranted}');
      
      if (status.isGranted) {
        debugPrint('Step 4a: Permission granted, trying to use Pictures directory');
        try {
          // 直接使用标准的相册目录路径
          String picturesPath = '/storage/emulated/0/Pictures';
          directory = Directory(picturesPath);
          debugPrint('Pictures directory path: $picturesPath');
          
          // 检查目录是否存在
          bool exists = directory.existsSync();
          debugPrint('Pictures directory exists: $exists');
          
          // 确保相册目录存在
          if (!exists) {
            debugPrint('Creating Pictures directory...');
            directory.createSync(recursive: true);
            debugPrint('Created Pictures directory successfully');
          }
          
          // 验证目录是否可写
          bool canWrite = await _checkDirectoryWritable(directory);
          debugPrint('Pictures directory writable: $canWrite');
          
          if (!canWrite) {
            debugPrint('Warning: Pictures directory is not writable, will fall back');
            directory = null;
          }
        } catch (e) {
          debugPrint('Error getting pictures directory: $e');
          directory = null;
        }
      }
      
      // 如果相册目录获取失败或没有权限，使用应用文档目录
      if (directory == null) {
        debugPrint('Step 4b: Using fallback directory');
        try {
          directory = await getApplicationDocumentsDirectory();
          debugPrint('Using app documents directory: ${directory.path}');
        } catch (e) {
          debugPrint('Error getting application documents directory: $e');
          // 备选方案：使用外部存储目录
          try {
            directory = await getExternalStorageDirectory();
            debugPrint('Using external storage directory: ${directory?.path}');
          } catch (e2) {
            debugPrint('Error getting external storage directory: $e2');
          }
        }
      }
      
      if (directory == null) {
        debugPrint('Error: No storage directory found');
        overlayEntry.remove();
        return null;
      }
      
      debugPrint('Selected directory: ${directory.path}');

      // 尝试使用 MediaStore API 保存到相册（Android 13+）
      if (Platform.isAndroid && status.isGranted) {
        debugPrint('Step 5: Trying to save via MediaStore API...');
        String? galleryPath = await _saveImageToGallery(pngBytes, 'b50_export_${DateTime.now().millisecondsSinceEpoch}.png');
        if (galleryPath != null) {
          debugPrint('Image saved to gallery via MediaStore: $galleryPath');
          // 调用媒体扫描器
          await _notifySystemGallery(galleryPath);
          return File(galleryPath);
        }
        debugPrint('MediaStore API failed, falling back to file system');
      }

      // 确保目录存在
      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }

      final file = File('${directory.path}/b50_export_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes);
      debugPrint('Image saved to: ${file.path}');

      // 调用媒体扫描器，通知系统有新文件（多重保障）
      if (Platform.isAndroid) {
        await _notifySystemGallery(file.path);
        debugPrint('Media scanner completed for: ${file.path}');
      }

      return file;
    } catch (e) {
      debugPrint('Error converting to image: $e');
      overlayEntry?.remove();
      return null;
    }
  }

  // 构建用于导出的Widget
  static Future<Widget> _buildExportImageWidget(BuildContext context, Map<String, dynamic>? b50Data, List<Map<String, dynamic>> sdSongs, List<Map<String, dynamic>> dxSongs, List<dynamic>? maimaiMusicData, {bool isTheoreticalMode = false}) async {
    // 计算各项指标
    // 计算Best35相关指标
    int best35Sum = sdSongs.fold(0, (sum, song) => sum + ((song['ra'] ?? 0) as int));
    double best35Average = sdSongs.isNotEmpty ? best35Sum / sdSongs.length : 0.0;
    
    // 计算Best15相关指标
    int best15Sum = dxSongs.fold(0, (sum, song) => sum + ((song['ra'] ?? 0) as int));
    double best15Average = dxSongs.isNotEmpty ? best15Sum / dxSongs.length : 0.0;
    
    // 计算rating（理论模式下使用计算值）
    int rating = isTheoreticalMode ? best35Sum + best15Sum : (b50Data?['rating'] ?? 0);
    
    // 计算rating平均值
    double ratingAverage = (best35Sum + best15Sum) / 50;
    
    // 计算平均达成率（理论模式下固定为101.0）
    double best50AchievementAverage;
    double best35AchievementAverage;
    double best15AchievementAverage;
    
    if (isTheoreticalMode) {
      best50AchievementAverage = 101.0;
      best35AchievementAverage = 101.0;
      best15AchievementAverage = 101.0;
    } else {
      double sdAchievementsSum = sdSongs.fold(0.0, (sum, song) => sum + (double.tryParse(song['achievements'].toString()) ?? 0.0));
      double dxAchievementsSum = dxSongs.fold(0.0, (sum, song) => sum + (double.tryParse(song['achievements'].toString()) ?? 0.0));
      
      best50AchievementAverage = (sdAchievementsSum + dxAchievementsSum) / 50;
      best35AchievementAverage = sdSongs.isNotEmpty ? sdAchievementsSum / sdSongs.length : 0.0;
      best15AchievementAverage = dxSongs.isNotEmpty ? dxAchievementsSum / dxSongs.length : 0.0;
    }
    
    // 计算DX分达成率
    double sdScoreRateSum = sdSongs.fold(0.0, (sum, song) {
      int songId = song['song_id'] ?? 0;
      int levelIndex = song['level_index'] ?? 0;
      int score = song['dxScore'] ?? 0;
      return sum + _calculateScoreRate(songId, levelIndex, score, maimaiMusicData);
    });
    
    double dxScoreRateSum = dxSongs.fold(0.0, (sum, song) {
      int songId = song['song_id'] ?? 0;
      int levelIndex = song['level_index'] ?? 0;
      int score = song['dxScore'] ?? 0;
      return sum + _calculateScoreRate(songId, levelIndex, score, maimaiMusicData);
    });
    
    double best50ScoreRateAverage = (sdSongs.length + dxSongs.length) > 0 
        ? (sdScoreRateSum + dxScoreRateSum) / (sdSongs.length + dxSongs.length) 
        : 0.0;
    
    double best35ScoreRateAverage = sdSongs.isNotEmpty ? sdScoreRateSum / sdSongs.length : 0.0;
    double best15ScoreRateAverage = dxSongs.isNotEmpty ? dxScoreRateSum / dxSongs.length : 0.0;

    // 创建一个容器，设置固定宽度以确保布局一致
    double containerWidth = 1200; // 适合5列布局的宽度

    // 获取用户信息（非理论模式下）
    String nickname = '';
    String dataSource = '水鱼';
    if (!isTheoreticalMode) {
      final userInfo = await _getUserInfo();
      nickname = userInfo['nickname'] ?? '';
      dataSource = userInfo['dataSource'] ?? '水鱼';
    }

    return Container(
      width: containerWidth,
      decoration: BoxDecoration(
        color: Colors.white, // 添加白色背景作为兜底
        image: DecorationImage(
          image: AssetImage('assets/bg/b50_bg.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 用户信息区域（非理论模式下显示）
                if (!isTheoreticalMode) ...[
                  _buildUserInfoSection(context, nickname, dataSource),
                  SizedBox(height: 16.0),
                ],
                
                // 评分区域
                _buildRatingSection(context, rating, ratingAverage, best35Sum, best35Average, best15Sum, best15Average, best50AchievementAverage, best35AchievementAverage, best15AchievementAverage, best50ScoreRateAverage, best35ScoreRateAverage, best15ScoreRateAverage),
                SizedBox(height: 20.0),

                // Best35 标题区域
                _buildSectionTitle(context, isTheoreticalMode ? '理论Best35 | 非当前版本最高定数' : 'Best35 | 非当前版本最好成绩'),
                SizedBox(height: 16.0),

                // Best35 卡片网格 (5列)
                _buildDataCardGrid(context, sdSongs, 2.0, 5, b50Data, maimaiMusicData),
                SizedBox(height: 24.0),

                // Best15 标题区域
                _buildSectionTitle(context, isTheoreticalMode ? '理论Best15 | 当前版本最高定数' : 'Best15 | 当前版本最好成绩'),
                SizedBox(height: 16.0),

                // Best15 卡片网格 (5列)
                _buildDataCardGrid(context, dxSongs, 2.0, 5, b50Data, maimaiMusicData),
                SizedBox(height: 20.0),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 构建评分区域
  static Widget _buildRatingSection(BuildContext context, int rating, double ratingAverage, int best35Sum, double best35Average, int best15Sum, double best15Average, double best50AchievementAverage, double best35AchievementAverage, double best15AchievementAverage, double best50ScoreRateAverage, double best35ScoreRateAverage, double best15ScoreRateAverage) {
    // 图片容器固定宽度为1200，以此为基准计算字体大小
    const double containerWidth = 1200.0;
    
    // 根据容器宽度计算字体大小（与App观感一致）
    double titleFontSize = containerWidth * 0.035; // 约42px
    double mainFontSize = containerWidth * 0.032; // 约38px
    double subFontSize = containerWidth * 0.025; // 约30px
    double sectionTitleFontSize = containerWidth * 0.03; // 约36px
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
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
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 8.0),
                RichText(
                  text: TextSpan(
                    children: [
                      TextStyleUtil.span(
                        rating.toString(),
                        TextStyle(
                          fontSize: mainFontSize,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextStyleUtil.span(
                        '(平均${ratingAverage.toStringAsFixed(1)})',
                        TextStyle(
                          fontSize: subFontSize,
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
                    fontSize: mainFontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    
                  ),
                ),
                RichText(
                  text: TextSpan(
                    children: [
                      TextStyleUtil.span(
                        best35Sum.toString(),
                        TextStyle(
                          fontSize: mainFontSize,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextStyleUtil.span(
                        '(平均${best35Average.toStringAsFixed(1)})',
                        TextStyle(
                          fontSize: subFontSize,
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
                    fontSize: mainFontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    
                  ),
                ),
                RichText(
                  text: TextSpan(
                    children: [
                      TextStyleUtil.span(
                        best15Sum.toString(),
                        TextStyle(
                          fontSize: mainFontSize,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextStyleUtil.span(
                        '(平均${best15Average.toStringAsFixed(1)})',
                        TextStyle(
                          fontSize: subFontSize,
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
                    fontSize: sectionTitleFontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                _buildDualDecimalText(context, best50AchievementAverage, best50ScoreRateAverage * 100),
                SizedBox(height: 12.0),
                Text(
                  'Best 35 平均达成率/DX分达成率',
                  style: TextStyle(
                    fontSize: sectionTitleFontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                _buildDualDecimalText(context, best35AchievementAverage, best35ScoreRateAverage * 100),
                SizedBox(height: 12.0),
                Text(
                  'Best 15 平均达成率/DX分达成率',
                  style: TextStyle(
                    fontSize: sectionTitleFontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                _buildDualDecimalText(context, best15AchievementAverage, best15ScoreRateAverage * 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 构建区域标题
  static Widget _buildSectionTitle(BuildContext context, String title) {
    // 图片容器固定宽度为1200，以此为基准计算字体大小
    const double containerWidth = 1200.0;
    
    // 根据容器宽度计算字体大小
    double fontSize = containerWidth * 0.03; // 约36px
    
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
    bool isUtage = false,
    int score = 0,
    int maxScore = 0,
    int rating = 0,
    String stars = '',
    String grade = '',
    int? songId,
    Color starsColor = Colors.white,
  }) {
    // 与Best50Page一致的卡片布局
    const double containerWidth = 1200.0;
    
    // 降低60%缩放倍率后的尺寸计算（保持原始值的40%）
    double songNameFontSize = containerWidth * 0.014;
    double decimalMainFontSize = containerWidth * 0.021;
    double decimalSmallFontSize = containerWidth * 0.016;
    double otherFontSize = containerWidth * 0.009;
    double gradeFontSize = containerWidth * 0.008;
    double dxFontSize = containerWidth * 0.009;
    double coverSize = containerWidth * 0.048;
    double spacing = containerWidth * 0.006;
    double smallSpacing = containerWidth * 0.003;
    
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        border: Border.all(color: Colors.black, width: 2.0),
        borderRadius: BorderRadius.circular(8.0),
      ),
      padding: EdgeInsets.all(spacing),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 左侧：曲绘和难度信息
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 曲绘
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
                        child: Text('曲绘', style: TextStyle(fontSize: coverSize * 0.24)),
                      ),
              ),
              SizedBox(height: smallSpacing),
              // DX/ST/UT标签和难度
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // DX/ST/UT标签
                  if (isUtage)
                    Text(
                      'UT',
                      style: TextStyle(
                        fontSize: dxFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  if (dxMode && !isUtage)
                    Text(
                      'DX',
                      style: TextStyle(
                        fontSize: dxFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  if (!dxMode && !isUtage)
                    Text(
                      'ST',
                      style: TextStyle(
                        fontSize: dxFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade300,
                      ),
                    ),
                  SizedBox(width: smallSpacing),
                  // 难度显示
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        difficulty.toString().split('.')[0],
                        style: TextStyle(
                          fontSize: decimalMainFontSize * 0.75,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (difficulty.toString().split('.').length > 1)
                        Text(
                          '.${difficulty.toString().split('.')[1]}',
                          style: TextStyle(
                            fontSize: decimalSmallFontSize * 0.75,
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
          SizedBox(width: spacing),
          
          // 右侧：歌曲信息
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
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                SizedBox(height: containerWidth * 0.002),
                
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
                
                // 评级、分数、星星
                Row(
                  children: [
                    Text(
                      'RA: $rating | $score / $maxScore | ',
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
      ),
    );
  }

  // 构建小数文本
  static Widget _buildDecimalText(BuildContext context, double value, {
    bool isPercentage = false,
    int decimalPlaces = 4,
    Color color = Colors.white,
  }) {
    // 图片容器固定宽度为1200，以此为基准计算字体大小
    const double containerWidth = 1200.0;
    
    // 根据容器宽度计算字体大小（与App观感一致）
    double mainFontSize = containerWidth * 0.032; // 约38px
    double subFontSize = containerWidth * 0.025; // 约30px
    
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
            
          ),
        ),
        // 小数部分和百分号
        Text(
          '$decimalPart$percentageSymbol',
          style: TextStyle(
            fontSize: subFontSize,
            fontWeight: FontWeight.bold,
            color: color,
            
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
    // 图片容器固定宽度为1200，以此为基准计算字体大小
    const double containerWidth = 1200.0;
    
    // 根据容器宽度计算字体大小（与App观感一致）
    double fontSize = containerWidth * 0.03; // 约36px
    
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
                
              ),
        ),
        _buildDecimalText(context, value2,
            decimalPlaces: decimalPlaces2, color: color),
      ],
    );
  }

  // 构建数据驱动的卡片网格
  static Widget _buildDataCardGrid(
      BuildContext context, List<Map<String, dynamic>> songs, double childAspectRatio, int crossAxisCount, Map<String, dynamic>? b50Data, List<dynamic>? maimaiMusicData) {
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
          return _buildDataGameCard(context, songs[index], b50Data, maimaiMusicData);
        },
      ),
    );
  }

  // 根据数据构建游戏卡片
  static Widget _buildDataGameCard(BuildContext context, Map<String, dynamic> songData, Map<String, dynamic>? b50Data, List<dynamic>? maimaiMusicData) {
    // 解析数据
    double achievementRate = double.tryParse(songData['achievements'].toString()) ?? 0.0;
    int score = songData['dxScore'] ?? 0;
    String fc = songData['fc'] ?? '';
    String fs = songData['fs'] ?? '';
    double difficulty = double.tryParse(songData['ds'].toString()) ?? 0.0;
    String rate = songData['rate'] ?? '';
    int levelIndex = songData['level_index'] ?? 0;
    int rating = songData['ra'] ?? 0;
    String type = songData['type'] ?? '';
    String title = songData['title'] ?? '未知歌曲';
    int songId = songData['song_id'] ?? 0;
    
    // 计算星星等级（使用与App相同的StringUtil）
    double scoreRate = _calculateScoreRate(songId, levelIndex, score, maimaiMusicData);
    String stars = StringUtil.formatStars(scoreRate);
    Color starsColor = ColorUtil.getStarsColor(stars);

    // 计算maxScore
    int maxScore = _calculateMaxScore(songId, levelIndex, maimaiMusicData);

    // 映射FC属性（使用与App相同的StringUtil）
    String fcText = fc.isNotEmpty ? StringUtil.formatFC(fc) : '-';

    // 映射FS属性（使用与App相同的StringUtil）
    String fsText = fs.isNotEmpty ? StringUtil.formatFS(fs) : '-';

    // 映射Rate属性（使用与App相同的StringUtil）
    String rateText = StringUtil.formatRate(rate);

    // 构建完整grade
    String grade = '$rateText | $fcText | $fsText';

    // 获取卡片颜色（与App一致，包括宴会场粉色）
    Color cardColor;
    if (songId.toString().length == 6) {
      cardColor = Color(0xFFFFB3D1); // 宴会场粉色
    } else {
      cardColor = ColorUtil.getCardColor(levelIndex);
    }

    // 判断是否为DX模式或UT模式
    bool dxMode = type == 'DX';
    bool isUtage = songId.toString().length == 6;

    return _buildGameCard(
      context: context,
      cardColor: cardColor,
      songName: title,
      achievementRate: achievementRate,
      difficulty: difficulty,
      dxMode: dxMode,
      isUtage: isUtage,
      score: score,
      maxScore: maxScore,
      rating: rating,
      stars: stars,
      grade: grade,
      songId: songId,
      starsColor: starsColor,
    );
  }

  // 计算maxScore
  static int _calculateMaxScore(int songId, int levelIndex, List<dynamic>? maimaiMusicData) {
    try {
      if (maimaiMusicData == null || maimaiMusicData.isEmpty) {
        return 0;
      }

      // 查找对应的歌曲数据
      dynamic songData;
      try {
        songData = maimaiMusicData.firstWhere(
          (song) => song['id'] == songId.toString(),
        );
      } catch (_) {
        // 如果找不到歌曲，返回0
        return 0;
      }

      if (songData['charts'] == null) return 0;

      // 查找对应的charts
      List<dynamic> charts = songData['charts'];
      if (levelIndex < 0 || levelIndex >= charts.length) return 0;

      dynamic chart = charts[levelIndex];
      if (chart['notes'] == null) return 0;

      // 计算maxScore
      List<dynamic> notes = chart['notes'];
      int notesSum = notes.fold(0, (sum, note) => sum + (note as int));
      return notesSum * 3;
    } catch (e) {
      debugPrint('Error calculating max score: $e');
      return 0;
    }
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
      debugPrint('Error calculating score rate: $e');
      return 0.0;
    }
  }

  // 预加载所有需要的图片资源
  static Future<void> _preloadImages(BuildContext context) async {
    try {
      // 预加载背景图片
      final bgImageProvider = AssetImage('assets/bg/b50_bg.png');
      await precacheImage(bgImageProvider, context);
      debugPrint('Background image preloaded');
    } catch (e) {
      debugPrint('Error preloading images: $e');
    }
  }

  // 等待渲染完成（使用WidgetsBinding确保所有帧都已处理）
  static Future<void> _waitForRender() async {
    // 使用addPostFrameCallback等待帧渲染完成
    Completer<void> frameCompleter = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      frameCompleter.complete();
    });
    await frameCompleter.future;

    // 再等待一帧确保渲染稳定
    Completer<void> frameCompleter2 = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      frameCompleter2.complete();
    });
    await frameCompleter2.future;

    // 额外等待一段时间确保所有异步操作完成（如图像加载）
    await Future.delayed(Duration(milliseconds: 500));
    debugPrint('Render wait completed');
  }

  // 发送Android系统广播，通知相册刷新
  static Future<void> _sendMediaScanBroadcast(String filePath) async {
    try {
      const MethodChannel channel = MethodChannel('com.example.app/media_scan');
      await channel.invokeMethod('scanFile', {'path': filePath});
      debugPrint('Broadcast sent for: $filePath');
    } catch (e) {
      debugPrint('Error sending broadcast: $e');
    }
  }

  // 通知系统刷新媒体库（多重保障）
  static Future<void> _notifySystemGallery(String filePath) async {
    // 方法1：使用media_scanner库
    try {
      await MediaScanner.loadMedia(path: filePath);
      debugPrint('MediaScanner.loadMedia succeeded for: $filePath');
    } catch (e) {
      debugPrint('MediaScanner.loadMedia failed: $e');
    }

    // 方法2：发送系统广播
    await _sendMediaScanBroadcast(filePath);

    // 方法3：尝试使用MediaStore API（Android 10+）
    try {
      const MethodChannel channel = MethodChannel('com.example.app/media_scan');
      await channel.invokeMethod('scanImage', {'path': filePath});
      debugPrint('MediaStore scan succeeded for: $filePath');
    } catch (e) {
      debugPrint('MediaStore scan failed: $e');
    }
  }

  // 使用 MediaStore API 将图片保存到系统相册（Android 13+）
  static Future<String?> _saveImageToGallery(Uint8List imageBytes, String fileName) async {
    try {
      const MethodChannel channel = MethodChannel('com.example.app/media_store');
      final String? result = await channel.invokeMethod('saveImage', {
        'imageBytes': imageBytes,
        'fileName': fileName,
      });
      debugPrint('MediaStore save result: $result');
      return result;
    } catch (e) {
      debugPrint('Error saving image via MediaStore: $e');
      return null;
    }
  }

  // 检查目录是否可写
  static Future<bool> _checkDirectoryWritable(Directory directory) async {
    try {
      // 创建一个临时文件来测试写入权限
      String testFileName = 'test_write_permission_${DateTime.now().millisecondsSinceEpoch}.tmp';
      File testFile = File('${directory.path}/$testFileName');
      
      await testFile.writeAsString('test');
      await testFile.delete();
      
      debugPrint('Directory writable test passed: ${directory.path}');
      return true;
    } catch (e) {
      debugPrint('Directory writable test failed: $e');
      return false;
    }
  }

  // 请求存储权限（图片与视频）
  static Future<PermissionStatus> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      debugPrint('Android platform detected');
      
      // 策略：同时请求 storage、photos 和 videos 权限
      // 这样可以覆盖所有 Android 版本，不需要检测 API 级别
      
      // 先检查已有权限状态
      PermissionStatus storageStatus = await Permission.storage.status;
      PermissionStatus photosStatus = await Permission.photos.status;
      PermissionStatus videosStatus = await Permission.videos.status;
      
      debugPrint('Storage status: $storageStatus');
      debugPrint('Photos status: $photosStatus');
      debugPrint('Videos status: $videosStatus');
      
      // 如果任何一个权限已授予，直接返回成功
      if (storageStatus.isGranted || photosStatus.isGranted || videosStatus.isGranted) {
        debugPrint('At least one permission already granted');
        return PermissionStatus.granted;
      }
      
      // 请求权限：同时请求 storage、photos 和 videos
      debugPrint('Requesting storage, photos and videos permissions...');
      Map<Permission, PermissionStatus> statuses = await [
        Permission.storage,
        Permission.photos,
        Permission.videos,
      ].request();
      
      bool storageGranted = statuses[Permission.storage]?.isGranted ?? false;
      bool photosGranted = statuses[Permission.photos]?.isGranted ?? false;
      bool videosGranted = statuses[Permission.videos]?.isGranted ?? false;
      
      debugPrint('Storage granted: $storageGranted');
      debugPrint('Photos granted: $photosGranted');
      debugPrint('Videos granted: $videosGranted');
      
      return (storageGranted || photosGranted || videosGranted) 
          ? PermissionStatus.granted 
          : PermissionStatus.denied;
    } else {
      // 对于其他平台，使用 storage 权限
      debugPrint('Non-Android platform detected, requesting storage permission');
      PermissionStatus status = await Permission.storage.request();
      debugPrint('Storage permission result: $status');
      return status;
    }
  }

  // 获取用户信息（昵称和数据源）
  static Future<Map<String, String>> _getUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 获取用户游玩数据
      String? userPlayDataStr = prefs.getString(CacheKeyConstant.userPlayData);
      String nickname = '';
      String dataSource = 'shuiyu'; // 默认水鱼
      
      if (userPlayDataStr != null) {
        try {
          Map<String, dynamic> userPlayData = jsonDecode(userPlayDataStr);
          nickname = userPlayData['nickname']?.toString() ?? '';
          
          // 根据数据特征判断数据源
          // 水鱼数据源的特征：有非空的nickname字段
          // 落雪数据源的特征：nickname为空或为'', records字段存在且非空
          if (nickname.isNotEmpty && nickname != '') {
            // 有水鱼格式的昵称，是水鱼数据源
            dataSource = 'shuiyu';
          } else if (userPlayData.containsKey('records') && userPlayData['records'] is List && (userPlayData['records'] as List).isNotEmpty) {
            // 有records但没有有效昵称，是落雪数据源
            dataSource = 'luoxue';
          }
        } catch (e) {
          debugPrint('Error parsing user play data: $e');
        }
      }
      
      return {
        'nickname': nickname,
        'dataSource': dataSource,
      };
    } catch (e) {
      debugPrint('Error getting user info: $e');
      return {
        'nickname': '',
        'dataSource': 'shuiyu',
      };
    }
  }

  // 构建用户信息区域
  static Widget _buildUserInfoSection(BuildContext context, String nickname, String dataSource) {
    // 将数据源转换为中文显示
    String displayDataSource = _convertDataSourceToChinese(dataSource);
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2.0),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${nickname.isNotEmpty ? '玩家: $nickname' : '玩家: 未知'} | 数据源: $displayDataSource',
            style: TextStyle(
              fontSize: 32.0,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  // 将数据源转换为中文显示
  static String _convertDataSourceToChinese(String dataSource) {
    switch (dataSource.toLowerCase()) {
      case 'luoxue':
        return '落雪';
      case 'shuiyu':
        return '水鱼';
      default:
        return dataSource;
    }
  }
}