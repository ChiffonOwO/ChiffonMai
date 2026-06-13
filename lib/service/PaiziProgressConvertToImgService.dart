import 'dart:async';
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
import 'package:my_first_flutter_app/utils/ColorUtil.dart';
import 'package:my_first_flutter_app/entity/LuoXue/Collection.dart';
import 'package:my_first_flutter_app/entity/DivingFish/Song.dart';

class PaiziProgressConvertToImg {
  static GlobalKey _globalKey = GlobalKey();

  static Future<File?> convertToImage(
    BuildContext context, {
    required Collection? currentPlate,
    required List<Map<String, dynamic>>? cachedSongsWithStatus,
    required String? selectedFirstChar,
    required String? selectedTitleType,
    required int? selectedDifficulty,
    required bool useLevelDisplay,
    required String filterMode,
    required String Function(int) getDifficultyName,
    required String Function(double) getLevelDisplay,
    required double Function(int, int) getSongAchievement,
    void Function(String message, double progress)? onProgress,
  }) async {
    OverlayEntry? overlayEntry;
    try {
      debugPrint('=== STARTING PAIZI PROGRESS IMAGE CONVERSION ===');
      debugPrint('Current platform: ${Platform.operatingSystem} ${Platform.version}');

      onProgress?.call('请求存储权限...', 0.0);
      debugPrint('Step 1: Requesting storage permission...');
      PermissionStatus status = await _requestStoragePermission();
      debugPrint('Step 1 completed: Storage permission status: $status');
      debugPrint('Is granted: ${status.isGranted}');

      GlobalKey globalKey = GlobalKey();

      onProgress?.call('正在构建导出内容...', 0.1);

      Widget imageWidget = RepaintBoundary(
        key: globalKey,
        child: _buildExportImageWidget(
          currentPlate: currentPlate,
          cachedSongsWithStatus: cachedSongsWithStatus,
          selectedFirstChar: selectedFirstChar,
          selectedTitleType: selectedTitleType,
          selectedDifficulty: selectedDifficulty,
          useLevelDisplay: useLevelDisplay,
          filterMode: filterMode,
          getDifficultyName: getDifficultyName,
          getLevelDisplay: getLevelDisplay,
          getSongAchievement: getSongAchievement,
        ),
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

      await _preloadImages();
      debugPrint('Images preloaded');

      onProgress?.call('正在预加载图片...', 0.2);

      Overlay.of(context).insert(overlayEntry);
      debugPrint('Overlay entry inserted');

      onProgress?.call('正在渲染导出内容...', 0.3);

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

      onProgress?.call('正在生成图片...', 0.5);

      debugPrint('Starting image capture...');
      
      // 动态计算 pixelRatio，避免超过 GPU 最大纹理尺寸限制（16384）
      final double maxTextureSize = 16000.0;
      final double widgetWidth = boundary.size.width;
      final double widgetHeight = boundary.size.height;
      
      double pixelRatio = 3.0;
      if (widgetWidth * pixelRatio > maxTextureSize) {
        pixelRatio = maxTextureSize / widgetWidth;
      }
      if (widgetHeight * pixelRatio > maxTextureSize) {
        pixelRatio = maxTextureSize / widgetHeight;
      }
      pixelRatio = pixelRatio.clamp(1.0, 3.0);
      
      debugPrint('Widget size: ${widgetWidth}x$widgetHeight, calculated pixelRatio: $pixelRatio');

      ui.Image image;
      try {
        image = await boundary.toImage(pixelRatio: pixelRatio);
        debugPrint('Image captured successfully at pixelRatio: $pixelRatio');
      } catch (e) {
        debugPrint('First capture failed: $e');
        await Future.delayed(Duration(milliseconds: 200));
        image = await boundary.toImage(pixelRatio: pixelRatio);
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

      Uint8List pngBytes = byteData.buffer.asUint8List();

      image.dispose();

      overlayEntry.remove();

      onProgress?.call('正在保存图片...', 0.8);

      Directory? directory;
      debugPrint('Step 4: Saving image. Permission granted: ${status.isGranted}');

      if (status.isGranted) {
        debugPrint('Step 4a: Permission granted, trying to use Pictures directory');
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
        debugPrint('Step 4b: Using fallback directory');
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
        debugPrint('Step 5: Trying to save via MediaStore API...');
        String? galleryPath = await _saveImageToGallery(pngBytes, 'paizi_progress_export_${DateTime.now().millisecondsSinceEpoch}.png');
        if (galleryPath != null) {
          debugPrint('Image saved to gallery via MediaStore: $galleryPath');
          await _notifySystemGallery(galleryPath);
          onProgress?.call('导出完成', 1.0);
          return File(galleryPath);
        }
        debugPrint('MediaStore API failed, falling back to file system');
      }

      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }

      final file = File('${directory.path}/paizi_progress_export_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes);
      debugPrint('Image saved to: ${file.path}');

      if (Platform.isAndroid) {
        await _notifySystemGallery(file.path);
        debugPrint('Media scanner completed for: ${file.path}');
      }

      onProgress?.call('导出完成', 1.0);
      return file;
    } catch (e) {
      debugPrint('Error converting to image: $e');
      overlayEntry?.remove();
      return null;
    }
  }

  static Widget _buildExportImageWidget({
    required Collection? currentPlate,
    required List<Map<String, dynamic>>? cachedSongsWithStatus,
    required String? selectedFirstChar,
    required String? selectedTitleType,
    required int? selectedDifficulty,
    required bool useLevelDisplay,
    required String filterMode,
    required String Function(int) getDifficultyName,
    required String Function(double) getLevelDisplay,
    required double Function(int, int) getSongAchievement,
  }) {
    const double containerWidth = 1200.0;

    if (currentPlate == null || cachedSongsWithStatus == null || cachedSongsWithStatus.isEmpty) {
      return Container(
        width: containerWidth,
        height: 400,
        color: Colors.white,
        child: Center(
          child: Text(
            '暂无数据',
            style: TextStyle(fontSize: 36, color: Colors.grey),
          ),
        ),
      );
    }

    List<Map<String, dynamic>> songsWithStatus = cachedSongsWithStatus;

    if (filterMode == 'completed') {
      songsWithStatus = songsWithStatus.where((item) => item['completed'] as bool).toList();
    } else if (filterMode == 'uncompleted') {
      songsWithStatus = songsWithStatus.where((item) => !(item['completed'] as bool)).toList();
    }

    final totalCount = songsWithStatus.length;
    final completedCount = songsWithStatus.where((item) => item['completed'] as bool).length;
    final completionRate = totalCount > 0 ? (completedCount / totalCount * 100) : 0;

    // 统计各难度完成情况（仅在 ALL 模式下使用）
    final difficultyNames = ['BASIC', 'ADVANCED', 'EXPERT', 'MASTER', 'RE:MASTER'];
    List<Map<String, dynamic>> difficultyStats = [];
    for (int d = 0; d < difficultyNames.length; d++) {
      final diffSongs = songsWithStatus.where((item) => (item['difficulty'] as int) == d).toList();
      if (diffSongs.isNotEmpty) {
        final diffTotal = diffSongs.length;
        final diffCompleted = diffSongs.where((item) => item['completed'] as bool).length;
        difficultyStats.add({
          'name': difficultyNames[d],
          'total': diffTotal,
          'completed': diffCompleted,
          'rate': diffTotal > 0 ? diffCompleted / diffTotal : 0.0,
        });
      }
    }

    double totalAchievement = 0.0;
    for (final item in songsWithStatus) {
      final dynamic song = item['song'];
      final diff = item['difficulty'] as int;
      if (song is Song) {
        totalAchievement += getSongAchievement(int.parse(song.id), diff);
      }
    }
    final averageAchievement = totalCount > 0 ? totalAchievement / totalCount : 0.0;

    Map<String, List<Map<String, dynamic>>> groupedSongs = {};
    for (final item in songsWithStatus) {
      final dynamic song = item['song'];
      final diffIndex = item['difficulty'] as int;
      String levelKey = '未知';
      if (song is Song) {
        if (song.ds != null && song.ds.length > diffIndex) {
          final ds = song.ds[diffIndex];
          levelKey = useLevelDisplay ? getLevelDisplay(ds) : ds.toStringAsFixed(1);
        }
      }
      if (!groupedSongs.containsKey(levelKey)) {
        groupedSongs[levelKey] = [];
      }
      groupedSongs[levelKey]!.add(item);
    }

    final sortedLevelKeys = groupedSongs.keys.toList()
      ..sort((a, b) {
        double parseLevel(String level) {
          if (useLevelDisplay) {
            if (level == '15') return 15.0;
            if (level.endsWith('+')) {
              return double.parse(level.substring(0, level.length - 1)) + 0.5;
            }
            return double.tryParse(level) ?? 0.0;
          } else {
            return double.tryParse(level) ?? 0.0;
          }
        }
        return parseLevel(b).compareTo(parseLevel(a));
      });

    double titleFontSize = containerWidth * 0.035;
    double sectionTitleFontSize = containerWidth * 0.03;
    double statFontSize = containerWidth * 0.022;
    double statValueFontSize = containerWidth * 0.028;
    double coverSize = containerWidth * 0.083;
    double sectionNameFontSize = containerWidth * 0.022;

    return Container(
      width: containerWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        image: DecorationImage(
          image: AssetImage('assets/bg/b50_bg.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 2.0),
                borderRadius: BorderRadius.circular(8.0),
                color: Colors.grey[200],
              ),
              padding: EdgeInsets.all(14.0),
              child: Center(
                child: Text(
                  '牌子进度 - ${selectedFirstChar ?? ''}${selectedTitleType ?? ''}(${getDifficultyName(selectedDifficulty ?? -1)})',
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            SizedBox(height: 16.0),

            // 统计区域
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 2.0),
                borderRadius: BorderRadius.circular(8.0),
                color: Colors.white,
              ),
              padding: EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${selectedFirstChar ?? ''}${selectedTitleType ?? ''}(${getDifficultyName(selectedDifficulty ?? -1)})统计',
                    style: TextStyle(
                      fontSize: sectionTitleFontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 10.0),
                  Row(
                    children: [
                      _buildStatColumn('总歌曲数', '$totalCount', statFontSize, statValueFontSize),
                      _buildStatColumn('已完成', '$completedCount', statFontSize, statValueFontSize),
                      _buildStatColumn('未完成', '${totalCount - completedCount}', statFontSize, statValueFontSize),
                      _buildStatColumn('完成率', '${completionRate.toStringAsFixed(1)}%', statFontSize, statValueFontSize),
                      _buildStatColumn('平均达成率', '${averageAchievement.toStringAsFixed(2)}%', statFontSize, statValueFontSize),
                    ],
                  ),
                  // ALL模式下添加各难度完成进度条
                  if (filterMode == 'all' && difficultyStats.isNotEmpty) ...[
                    SizedBox(height: 12.0),
                    Divider(color: Colors.grey[300], thickness: 1.0),
                    SizedBox(height: 8.0),
                    ...difficultyStats.map((stat) {
                      final diffIndex = difficultyNames.indexOf(stat['name'] as String);
                      final barColor = ColorUtil.getCoverBorderColor(diffIndex);
                      return Padding(
                        padding: EdgeInsets.only(bottom: 6.0),
                        child: Row(
                          children: [
                            SizedBox(
                              width: containerWidth * 0.12,
                              child: Text(
                                stat['name'] as String,
                                style: TextStyle(
                                  fontSize: statFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: barColor,
                                ),
                              ),
                            ),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4.0),
                                child: LinearProgressIndicator(
                                  value: stat['rate'] as double,
                                  backgroundColor: Colors.grey[200],
                                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                                  minHeight: 14.0,
                                ),
                              ),
                            ),
                            SizedBox(width: 8.0),
                            SizedBox(
                              width: containerWidth * 0.1,
                              child: Text(
                                '${stat['completed']}/${stat['total']}',
                                style: TextStyle(
                                  fontSize: statFontSize,
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
            SizedBox(height: 16.0),

            // 歌曲列表
            ...sortedLevelKeys.map((levelKey) {
              final levelSongs = groupedSongs[levelKey]!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 定数分隔线
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200]!,
                      border: Border.all(color: Colors.black, width: 1.0),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 14.0),
                    margin: EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      '${useLevelDisplay ? 'Lv.' : ''}${levelKey} | 共 ${levelSongs.length} 首歌曲',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: sectionNameFontSize,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // 歌曲网格
                  GridView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 12,
                      crossAxisSpacing: 8.0,
                      mainAxisSpacing: 8.0,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: levelSongs.length,
                    itemBuilder: (context, index) {
                      final item = levelSongs[index];
                      final dynamic song = item['song'];
                      final isCompleted = item['completed'] as bool;
                      final diffIndex = item['difficulty'] as int;

                      String songId = '';
                      if (song is Song) {
                        songId = song.id;
                      } else if (song is CollectionRequiredSong) {
                        songId = song.id.toString();
                      }

                      return Center(
                        child: SizedBox(
                          width: coverSize,
                          height: coverSize,
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: CoverUtil.buildCoverWidgetWithContext(
                                  _globalKey.currentContext ?? context,
                                  songId,
                                  coverSize,
                                ),
                              ),
                              if (isCompleted)
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                      size: coverSize * 0.4,
                                    ),
                                  ),
                                ),
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: ColorUtil.getCoverBorderColor(diffIndex),
                                    width: 2.0,
                                  ),
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 16.0),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  static Widget _buildStatColumn(String label, String value, double labelFontSize, double valueFontSize) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: labelFontSize,
              color: Colors.black,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: valueFontSize,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _preloadImages() async {
    try {
      debugPrint('Paizi progress: preloading images...');
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

  static Future<PermissionStatus> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      debugPrint('Android platform detected');

      PermissionStatus storageStatus = await Permission.storage.status;
      PermissionStatus photosStatus = await Permission.photos.status;
      PermissionStatus videosStatus = await Permission.videos.status;

      debugPrint('Storage status: $storageStatus');
      debugPrint('Photos status: $photosStatus');
      debugPrint('Videos status: $videosStatus');

      if (storageStatus.isGranted || photosStatus.isGranted || videosStatus.isGranted) {
        debugPrint('At least one permission already granted');
        return PermissionStatus.granted;
      }

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
      debugPrint('Non-Android platform detected, requesting storage permission');
      PermissionStatus status = await Permission.storage.request();
      debugPrint('Storage permission result: $status');
      return status;
    }
  }
}