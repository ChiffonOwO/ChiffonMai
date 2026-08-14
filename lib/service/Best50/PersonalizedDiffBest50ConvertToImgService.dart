import 'dart:async';
import 'package:my_first_flutter_app/utils/ExportUserInfoWidget.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:media_scanner/media_scanner.dart';
import 'package:my_first_flutter_app/utils/CoverUtil.dart';
import 'package:my_first_flutter_app/utils/TextStyleUtil.dart';
import 'package:my_first_flutter_app/utils/ColorUtil.dart';
import 'package:my_first_flutter_app/utils/StringUtil.dart';
import 'package:my_first_flutter_app/utils/ImageEncodeUtil.dart';

class PersonalizedDiffBest50ConvertToImg {
  static GlobalKey _globalKey = GlobalKey();

  // 导出为图片的方法
  static Future<File?> convertToImage(BuildContext context, String title, Map<String, dynamic>? diffBest50Data, List<Map<String, dynamic>> diffSongs, List<dynamic>? maimaiMusicData, {int? jpegQuality}) async {
    OverlayEntry? overlayEntry;
    try {
      debugPrint('=== STARTING PERSONALIZED DIFF B50 IMAGE CONVERSION ===');
      debugPrint('Current platform: ${Platform.operatingSystem} ${Platform.version}');

      PermissionStatus status = await _requestStoragePermission();
      debugPrint('Storage permission status: $status');

      GlobalKey globalKey = GlobalKey();

      Widget imageWidget = RepaintBoundary(
        key: globalKey,
        child: await _buildExportImageWidget(context, title, diffBest50Data, diffSongs, maimaiMusicData),
      );

      overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          left: -9999,
          top: -9999,
          width: 1200,
          child: Material(
            type: MaterialType.transparency,
            child: imageWidget,
          ),
        ),
      );

      await _preloadImages(context);
      debugPrint('Images preloaded');

      Overlay.of(context).insert(overlayEntry);
      debugPrint('Overlay entry inserted');

      await _waitForRender();
      debugPrint('Render wait completed');

      final RenderRepaintBoundary? boundary = globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        debugPrint('Error: RenderRepaintBoundary not found');
        overlayEntry.remove();
        return null;
      }
      debugPrint('RenderRepaintBoundary found successfully');

      await Future.delayed(Duration(milliseconds: 100));

      debugPrint('Starting image capture...');
      ui.Image image;
      try {
        image = await boundary.toImage(pixelRatio: 3.0);
        debugPrint('Image captured successfully');
      } catch (e) {
        debugPrint('First capture failed: $e');
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

      Uint8List pngBytes = byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);

      Uint8List finalBytes;
      String extension;
      if (jpegQuality != null) {
        finalBytes = ImageEncodeUtil.pngToJpeg(pngBytes, quality: jpegQuality);
        extension = 'jpg';
      } else {
        finalBytes = pngBytes;
        extension = 'png';
      }

      image.dispose();

      overlayEntry.remove();

      Directory? directory;

      if (status.isGranted) {
        try {
          String picturesPath = '/storage/emulated/0/Pictures';
          directory = Directory(picturesPath);
          debugPrint('Pictures directory path: $picturesPath');

          bool exists = directory.existsSync();
          debugPrint('Pictures directory exists: $exists');

          if (!exists) {
            debugPrint('Creating Pictures directory...');
            directory.createSync(recursive: true);
            debugPrint('Created Pictures directory successfully');
          }

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

      if (directory == null) {
        try {
          directory = await getApplicationDocumentsDirectory();
          debugPrint('Using app documents directory: ${directory.path}');
        } catch (e) {
          debugPrint('Error getting application documents directory: $e');
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

      if (Platform.isAndroid && status.isGranted) {
        debugPrint('Trying to save via MediaStore API...');
        String? galleryPath = await _saveImageToGallery(finalBytes, 'personalized_diff_b50_export_${DateTime.now().millisecondsSinceEpoch}.$extension');
        if (galleryPath != null) {
          debugPrint('Image saved to gallery via MediaStore: $galleryPath');
          await _notifySystemGallery(galleryPath);
          return File(galleryPath);
        }
        debugPrint('MediaStore API failed, falling back to file system');
      }

      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }

      final file = File('${directory.path}/personalized_diff_b50_export_${DateTime.now().millisecondsSinceEpoch}.$extension');
      await file.writeAsBytes(finalBytes);
      debugPrint('Image saved to: ${file.path}');

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
  static Future<Widget> _buildExportImageWidget(BuildContext context, String title, Map<String, dynamic>? diffBest50Data, List<Map<String, dynamic>> diffSongs, List<dynamic>? maimaiMusicData) async {
    int diffRatingSum = diffBest50Data?['diffRatingSum'] ?? 0;
    double diffRatingAverage = diffSongs.isNotEmpty ? diffRatingSum / diffSongs.length : 0.0;

    double achievementsSum = diffSongs.fold(0.0,
        (sum, song) => sum + (double.tryParse(song['achievements'].toString()) ?? 0.0));
    double averageAchievement = diffSongs.isNotEmpty ? achievementsSum / diffSongs.length : 0.0;

    double scoreRateSum = diffSongs.fold(0.0, (sum, song) {
      int songId = song['song_id'] ?? 0;
      int levelIndex = song['level_index'] ?? 0;
      int score = song['dxScore'] ?? 0;
      return sum + _calculateScoreRate(songId, levelIndex, score, maimaiMusicData);
    });
    double averageScoreRate = diffSongs.isNotEmpty ? scoreRateSum / diffSongs.length : 0.0;

    const double containerWidth = 1200.0;

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
                ExportUserInfoWidget.buildUserInfoSection(context),
                SizedBox(height: 16.0),

                _buildRatingSection(context, title, diffRatingSum, diffRatingAverage, averageAchievement, averageScoreRate),
                SizedBox(height: 20.0),

                _buildSectionTitle(context, title),
                SizedBox(height: 16.0),

                _buildDataCardGrid(context, diffSongs, 2.0, 5, maimaiMusicData),
                SizedBox(height: 20.0),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 构建评分区域
  static Widget _buildRatingSection(BuildContext context, String title, int diffRatingSum, double diffRatingAverage, double averageAchievement, double averageScoreRate) {
    const double containerWidth = 1200.0;

    double mainFontSize = containerWidth * 0.032;
    double subFontSize = containerWidth * 0.025;
    double sectionTitleFontSize = containerWidth * 0.03;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2.0),
        borderRadius: BorderRadius.circular(8.0),
      ),
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '拟合总Rating',
                      style: TextStyle(
                        fontSize: mainFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 8.0),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextStyleUtil.span(
                            diffRatingSum.toString(),
                            TextStyle(
                              fontSize: mainFontSize,
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextStyleUtil.span(
                            '(平均${diffRatingAverage.toStringAsFixed(1)})',
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

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '平均达成率/DX分达成率',
                      style: TextStyle(
                        fontSize: sectionTitleFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    _buildDualDecimalText(context, averageAchievement, averageScoreRate * 100),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 构建区域标题
  static Widget _buildSectionTitle(BuildContext context, String title) {
    const double containerWidth = 1200.0;
    double fontSize = containerWidth * 0.03;

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
                        child: Text('曲绘', style: TextStyle(fontSize: coverSize * 0.24)),
                      ),
              ),
              SizedBox(height: smallSpacing),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isUtage)
                    Text('UT', style: TextStyle(fontSize: dxFontSize, fontWeight: FontWeight.bold, color: Colors.red)),
                  if (dxMode && !isUtage)
                    Text('DX', style: TextStyle(fontSize: dxFontSize, fontWeight: FontWeight.bold, color: Colors.orange)),
                  if (!dxMode && !isUtage)
                    Text('ST', style: TextStyle(fontSize: dxFontSize, fontWeight: FontWeight.bold, color: Colors.blue.shade300)),
                  SizedBox(width: smallSpacing),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        difficulty.toStringAsFixed(2).split('.')[0],
                        style: TextStyle(fontSize: decimalMainFontSize * 0.75, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        '.${difficulty.toStringAsFixed(2).split('.')[1]}',
                        style: TextStyle(fontSize: decimalSmallFontSize * 0.75, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          SizedBox(width: spacing),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  songName,
                  style: TextStyle(fontSize: songNameFontSize, fontWeight: FontWeight.w900, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                SizedBox(height: containerWidth * 0.002),

                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      achievementRate.toStringAsFixed(4).split('.')[0],
                      style: TextStyle(fontSize: decimalMainFontSize, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      '.${achievementRate.toStringAsFixed(4).split('.')[1]}%',
                      style: TextStyle(fontSize: decimalSmallFontSize, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),

                Row(
                  children: [
                    Text(
                      'RA: $rating | $score / $maxScore | ',
                      style: TextStyle(fontSize: otherFontSize, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      stars,
                      style: TextStyle(fontSize: otherFontSize, color: starsColor, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),

                Text(
                  grade,
                  style: TextStyle(fontSize: gradeFontSize, fontWeight: FontWeight.bold, color: Colors.white),
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
    const double containerWidth = 1200.0;
    double mainFontSize = containerWidth * 0.032;
    double subFontSize = containerWidth * 0.025;

    String text = value.toStringAsFixed(decimalPlaces);
    List<String> parts = text.split('.');
    String integerPart = parts[0];
    String decimalPart = parts.length > 1 ? '.${parts[1]}' : '';
    String percentageSymbol = isPercentage ? '%' : '';

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          integerPart,
          style: TextStyle(fontSize: mainFontSize, fontWeight: FontWeight.bold, color: color),
        ),
        Text(
          '$decimalPart$percentageSymbol',
          style: TextStyle(fontSize: subFontSize, fontWeight: FontWeight.bold, color: color),
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
    const double containerWidth = 1200.0;
    double fontSize = containerWidth * 0.03;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDecimalText(context, value1, decimalPlaces: decimalPlaces1, color: color),
        Text('/', style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: color)),
        _buildDecimalText(context, value2, decimalPlaces: decimalPlaces2, color: color),
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

    double scoreRate = _calculateScoreRate(songId, levelIndex, score, maimaiMusicData);
    String stars = StringUtil.formatStars(scoreRate);
    Color starsColor = ColorUtil.getStarsColor(stars);

    int maxScore = _calculateMaxScore(songId, levelIndex, maimaiMusicData);

    String fcText = fc.isNotEmpty ? StringUtil.formatFC(fc) : '-';
    String fsText = fs.isNotEmpty ? StringUtil.formatFS(fs) : '-';
    String rateText = StringUtil.formatRate(rate);

    String grade = '$rateText | $fcText | $fsText';

    Color cardColor;
    if (songId.toString().length == 6) {
      cardColor = Color(0xFFFFB3D1);
    } else {
      cardColor = ColorUtil.getCardColor(levelIndex);
    }

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

  static int _calculateMaxScore(int songId, int levelIndex, List<dynamic>? maimaiMusicData) {
    try {
      if (maimaiMusicData == null || maimaiMusicData.isEmpty) return 0;

      dynamic songData;
      try {
        songData = maimaiMusicData.firstWhere(
          (song) => song['id'] == songId.toString(),
        );
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

  static double _calculateScoreRate(int songId, int levelIndex, int score, List<dynamic>? maimaiMusicData) {
    try {
      if (maimaiMusicData == null) return 0.0;

      dynamic songData;
      try {
        songData = maimaiMusicData.firstWhere(
          (item) => item['id'] == songId.toString(),
        );
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

  static Future<void> _preloadImages(BuildContext context) async {
    try {
      final bgImageProvider = AssetImage('assets/bg/b50_bg.png');
      await precacheImage(bgImageProvider, context);
      debugPrint('Background image preloaded');
    } catch (e) {
      debugPrint('Error preloading images: $e');
    }
  }

  static Future<void> _waitForRender() async {
    Completer<void> frameCompleter = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      frameCompleter.complete();
    });
    await frameCompleter.future;

    Completer<void> frameCompleter2 = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      frameCompleter2.complete();
    });
    await frameCompleter2.future;

    await Future.delayed(Duration(milliseconds: 500));
    debugPrint('Render wait completed');
  }

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

  static Future<bool> _checkDirectoryWritable(Directory directory) async {
    try {
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

  static Future<void> _sendMediaScanBroadcast(String filePath) async {
    try {
      const MethodChannel channel = MethodChannel('com.example.app/media_scan');
      await channel.invokeMethod('scanFile', {'path': filePath});
      debugPrint('Broadcast sent for: $filePath');
    } catch (e) {
      debugPrint('Error sending broadcast: $e');
    }
  }

  static Future<void> _notifySystemGallery(String filePath) async {
    try {
      await MediaScanner.loadMedia(path: filePath);
      debugPrint('MediaScanner.loadMedia succeeded for: $filePath');
    } catch (e) {
      debugPrint('MediaScanner.loadMedia failed: $e');
    }

    await _sendMediaScanBroadcast(filePath);

    try {
      const MethodChannel channel = MethodChannel('com.example.app/media_scan');
      await channel.invokeMethod('scanImage', {'path': filePath});
      debugPrint('MediaStore scan succeeded for: $filePath');
    } catch (e) {
      debugPrint('MediaStore scan failed: $e');
    }
  }

  static Future<PermissionStatus> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      PermissionStatus storageStatus = await Permission.storage.status;
      PermissionStatus photosStatus = await Permission.photos.status;
      PermissionStatus videosStatus = await Permission.videos.status;

      if (storageStatus.isGranted || photosStatus.isGranted || videosStatus.isGranted) {
        return PermissionStatus.granted;
      }

      Map<Permission, PermissionStatus> statuses = await [
        Permission.storage,
        Permission.photos,
        Permission.videos,
      ].request();

      bool storageGranted = statuses[Permission.storage]?.isGranted ?? false;
      bool photosGranted = statuses[Permission.photos]?.isGranted ?? false;
      bool videosGranted = statuses[Permission.videos]?.isGranted ?? false;

      return (storageGranted || photosGranted || videosGranted)
          ? PermissionStatus.granted
          : PermissionStatus.denied;
    } else {
      PermissionStatus status = await Permission.storage.request();
      return status;
    }
  }
}
