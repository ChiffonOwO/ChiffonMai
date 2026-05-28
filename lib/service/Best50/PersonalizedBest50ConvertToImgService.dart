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

class PersonalizedB50ConvertToImg {
  // 全局Key，用于获取widget的渲染对象
  // ignore: unused_field
  static GlobalKey _globalKey = GlobalKey();

  // 导出为图片的方法
  static Future<File?> convertToImage(BuildContext context, String title, List<Map<String, dynamic>> personalizedSongs, List<dynamic>? maimaiMusicData) async {
    OverlayEntry? overlayEntry;
    try {
      debugPrint('=== STARTING PERSONALIZED B50 IMAGE CONVERSION ===');
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
        child: await _buildExportImageWidget(context, title, personalizedSongs, maimaiMusicData),
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

      Uint8List pngBytes = byteData.buffer.asUint8List();
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
        String? galleryPath = await _saveImageToGallery(pngBytes, 'personalized_b50_${DateTime.now().millisecondsSinceEpoch}.png');
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

      final file = File('${directory.path}/personalized_b50_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes);
      debugPrint('Image saved to file system: ${file.path}');

      // 调用媒体扫描器（对于保存到文件系统的图片）
      if (Platform.isAndroid) {
        await _notifySystemGallery(file.path);
      }

      return file;
    } catch (e) {
      debugPrint('Error converting to image: $e');
      overlayEntry?.remove();
      return null;
    }
  }

  // 构建用于导出的Widget
  static Future<Widget> _buildExportImageWidget(BuildContext context, String title, List<Map<String, dynamic>> personalizedSongs, List<dynamic>? maimaiMusicData) async {
    // 获取用户信息
    final userInfo = await _getUserInfo();
    final String nickname = userInfo['nickname'] ?? '';
    final String dataSource = userInfo['dataSource'] ?? '水鱼';

    double containerWidth = 1200;

    return Container(
      width: containerWidth,
      decoration: BoxDecoration(
        color: Colors.white,
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
                // 用户信息区域
                _buildUserInfoSection(context, nickname, dataSource),
                SizedBox(height: 16.0),
                
                // 标题区域
                _buildSectionTitle(context, title),
                SizedBox(height: 16.0),

                // 统计区域
                _buildStatsSection(context, personalizedSongs),
                SizedBox(height: 16.0),

                // 歌曲卡片网格
                _buildDataCardGrid(context, personalizedSongs, 2.0, 5, maimaiMusicData),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 构建区域标题
  static Widget _buildSectionTitle(BuildContext context, String title) {
    const double containerWidth = 1200.0;
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

  // 构建统计区域
  static Widget _buildStatsSection(BuildContext context, List<Map<String, dynamic>> songs) {
    const double containerWidth = 1200.0;
    
    double titleFontSize = containerWidth * 0.025; // 约30px
    double mainFontSize = containerWidth * 0.03; // 约36px
    double subFontSize = containerWidth * 0.02; // 约24px

    int totalSongs = songs.length;
    int totalRa = songs.fold(0, (sum, song) => sum + ((song['ra'] ?? 0) as int));
    double avgRa = totalSongs > 0 ? totalRa / totalSongs : 0.0;
    double totalAchievement = songs.fold(0.0, (sum, song) => sum + (double.tryParse(song['achievements'].toString()) ?? 0.0));
    double avgAchievement = totalSongs > 0 ? totalAchievement / totalSongs : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2.0),
        borderRadius: BorderRadius.circular(8.0),
      ),
      padding: EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            children: [
              Text(
                '歌曲数',
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 8.0),
              Text(
                '$totalSongs',
                style: TextStyle(
                  fontSize: mainFontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          Column(
            children: [
              Text(
                '总RA',
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 8.0),
              Text(
                '$totalRa',
                style: TextStyle(
                  fontSize: mainFontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          Column(
            children: [
              Text(
                '平均RA',
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
                      avgRa.toStringAsFixed(1),
                      TextStyle(
                        fontSize: mainFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Column(
            children: [
              Text(
                '平均达成率',
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 8.0),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    avgAchievement.toStringAsFixed(4).split('.')[0],
                    style: TextStyle(
                      fontSize: mainFontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    '.${avgAchievement.toStringAsFixed(4).split('.')[1]}%',
                    style: TextStyle(
                      fontSize: subFontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 构建卡片网格
  static Widget _buildDataCardGrid(BuildContext context, List<Map<String, dynamic>> songs, double aspectRatio, int crossAxisCount, List<dynamic>? maimaiMusicData) {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: aspectRatio,
        mainAxisSpacing: 8.0,
        crossAxisSpacing: 8.0,
      ),
      itemCount: songs.length,
      itemBuilder: (context, index) {
        return _buildGameCard(
          context: context,
          songData: songs[index],
          maimaiMusicData: maimaiMusicData,
          index: index,
        );
      },
    );
  }

  // 构建游戏卡片
  static Widget _buildGameCard({
    required BuildContext context,
    required Map<String, dynamic> songData,
    List<dynamic>? maimaiMusicData,
    int index = 0,
  }) {
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

    // 计算maxScore
    int maxScore = _calculateMaxScore(songId, levelIndex, maimaiMusicData);

    // 计算星星等级
    double scoreRate = _calculateScoreRate(songId, levelIndex, score, maimaiMusicData);
    String stars = StringUtil.formatStars(scoreRate);
    Color starsColor = ColorUtil.getStarsColor(stars);

    // 映射FC/FS/Rate属性
    String fcText = fc.isNotEmpty ? StringUtil.formatFC(fc) : '-';
    String fsText = fs.isNotEmpty ? StringUtil.formatFS(fs) : '-';
    String rateText = StringUtil.formatRate(rate);
    String grade = '$rateText | $fcText | $fsText';

    // 获取卡片颜色
    Color cardColor;
    if (songId.toString().length == 6) {
      cardColor = Color(0xFFFFB3D1);
    } else {
      cardColor = ColorUtil.getCardColor(levelIndex);
    }

    bool dxMode = type == 'DX';
    bool isUtage = songId.toString().length == 6;

    const double containerWidth = 1200.0;
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
                  title,
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

                // RA、分数、星星
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

  // 计算maxScore
  static int _calculateMaxScore(int songId, int levelIndex, List<dynamic>? maimaiMusicData) {
    try {
      if (maimaiMusicData == null || maimaiMusicData.isEmpty) return 0;

      dynamic songData;
      try {
        songData = maimaiMusicData.firstWhere((song) => song['id'] == songId.toString());
      } catch (_) {
        return 0;
      }

      if (songData['charts'] == null) return 0;

      List<dynamic> charts = songData['charts'];
      if (levelIndex < 0 || levelIndex >= charts.length) return 0;

      dynamic chart = charts[levelIndex];
      if (chart['notes'] == null) return 0;

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

      dynamic songData;
      try {
        songData = maimaiMusicData.firstWhere((item) => item['id'] == songId.toString());
      } catch (e) {
        return 0.0;
      }

      if (songData == null || songData['charts'] == null) return 0.0;

      List<dynamic> charts = songData['charts'];
      if (levelIndex < 0 || levelIndex >= charts.length) return 0.0;

      dynamic chart = charts[levelIndex];
      if (chart['notes'] == null) return 0.0;

      List<dynamic> notes = chart['notes'];
      int notesSum = notes.fold(0, (sum, note) => sum + (note as int));
      int maxScore = notesSum * 3;

      return maxScore > 0 ? score / maxScore : 0.0;
    } catch (e) {
      debugPrint('Error calculating score rate: $e');
      return 0.0;
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

  // 使用 MediaStore API 将图片保存到系统相册（Android 13+）
  static Future<String?> _saveImageToGallery(Uint8List imageBytes, String fileName) async {
    try {
      const MethodChannel channel = MethodChannel('com.example.app/media_store');
      final String? result = await channel.invokeMethod('saveImage', {
        'imageBytes': imageBytes,
        'fileName': fileName,
      });
      return result;
    } catch (e) {
      debugPrint('Error saving image via MediaStore: $e');
      return null;
    }
  }

  // 通知系统相册
  static Future<void> _notifySystemGallery(String filePath) async {
    try {
      await MediaScanner.loadMedia(path: filePath);
    } catch (e) {
      debugPrint('Error sending broadcast: $e');
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