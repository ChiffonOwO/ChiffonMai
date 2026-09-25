import 'dart:async';
import 'package:my_first_flutter_app/utils/ExportUserInfoWidget.dart';
import 'package:my_first_flutter_app/widgets/B50GameCardWidget.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:media_scanner/media_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_first_flutter_app/constant/AppLinks.dart';
import 'package:my_first_flutter_app/constant/CacheKeyConstant.dart';
import 'package:my_first_flutter_app/utils/TextStyleUtil.dart';
import 'package:my_first_flutter_app/utils/ColorUtil.dart';
import 'package:my_first_flutter_app/utils/StringUtil.dart';
import 'package:my_first_flutter_app/utils/ImageEncodeUtil.dart';
import 'package:my_first_flutter_app/utils/CurrentDataSourceNotifier.dart';

class B50ConvertToImg {
  // 全局Key，用于获取widget的渲染对象
  // ignore: unused_field
  static GlobalKey _globalKey = GlobalKey();

  // 导出为图片的方法
  static Future<File?> convertToImage(BuildContext context, Map<String, dynamic>? b50Data, List<Map<String, dynamic>> sdSongs, List<Map<String, dynamic>> dxSongs, List<dynamic>? maimaiMusicData, {bool isTheoreticalMode = false, int? jpegQuality, int? selectedPlateId}) async {
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
        child: await _buildExportImageWidget(context, b50Data, sdSongs, dxSongs, maimaiMusicData, isTheoreticalMode: isTheoreticalMode, selectedPlateId: selectedPlateId),
      );

      // 创建一个屏幕外的OverlayEntry，避免影响主UI
      // 使用Positioned将Widget定位到屏幕外，确保它被渲染但不可见
      overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          left: -9999, // 移到屏幕外
          top: -9999,
          width: 1700, // 2.5× 姓名框 1150 + 16 gap + metaRow 534 ≈ 1700
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
        image = await boundary.toImage(pixelRatio: ImageEncodeUtil.safeCapturePixelRatio(boundary.size.width, boundary.size.height));
        debugPrint('Image captured successfully');
      } catch (e) {
        debugPrint('First capture failed: $e');
        // 重试一次
        await Future.delayed(Duration(milliseconds: 200));
        image = await boundary.toImage(pixelRatio: ImageEncodeUtil.safeCapturePixelRatio(boundary.size.width, boundary.size.height));
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
      Uint8List pngBytes = byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
      // 立刻释放 ui.Image：它本身也是上百 MB 的原生位图，而下面的 JPEG
      // 转码还要再分配上百 MB（decodePng + copyResize）。等转码完再释放，
      // 峰值内存会白白多一份 —— 低内存机就是这样被 OOM 掉的。
      // 转码只用得到 pngBytes，用不到这个 image。
      image.dispose();

      // 根据质量参数决定最终格式
      Uint8List finalBytes;
      String extension;
      if (jpegQuality != null) {
        finalBytes = await ImageEncodeUtil.pngToJpegAsync(pngBytes, quality: jpegQuality);
        extension = 'jpg';
      } else {
        finalBytes = pngBytes;
        extension = 'png';
      }
      
      // 释放图片资源

      
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
        String? galleryPath = await _saveImageToGallery(finalBytes, 'b50_export_${DateTime.now().millisecondsSinceEpoch}.$extension');
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

      final file = File('${directory.path}/b50_export_${DateTime.now().millisecondsSinceEpoch}.$extension');
      await file.writeAsBytes(finalBytes);
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
  static Future<Widget> _buildExportImageWidget(BuildContext context, Map<String, dynamic>? b50Data, List<Map<String, dynamic>> sdSongs, List<Map<String, dynamic>> dxSongs, List<dynamic>? maimaiMusicData, {bool isTheoreticalMode = false, int? selectedPlateId}) async {
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
    
    // 计算DX分数达成率
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
    double containerWidth = 1700; // 适合5列布局的宽度

    // 计算谱面 ID 对齐宽度：若 50 首中存在 6 位 ID 则按 6 位对齐，否则按 5 位
    int maxIdLength = 5;
    for (final song in [...sdSongs, ...dxSongs]) {
      final id = (song['song_id'] ?? 0).toString();
      if (id.length == 6) {
        maxIdLength = 6;
        break;
      }
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
      // 用 Stack 让元信息（数据源 / 导出时间 / Generated by / 交流群）作为悬浮卡片
      // 固定在图片右上角，不再挤占统计区空间
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 用户信息区域 + metaRow 横排：姓名框在左，metaRow 紧挨右侧独立成块
                // 姓名框 2.5× 宽度放大到 1150（高度保持 230），metaRow 高度同样 230 让两者视觉等高。
                // metaRow 重构为 4 行垂直布局（数据源 / 导出时间 / Generated by / 交流群），
                // 交流群单独成行（第 4 行），宽度 = 最宽子行（导出时间 ≈ 385 + padding ≈ 413）。
                // 容器宽度 1700 - 外层 Padding 20×2 = 1660，减去姓名框 1150 + gap 16 = 1166，
                // 剩余 = 494 作为 metaRow 卡片宽度（填满 SizedBox，右侧无空缺）。
                // 不用 Row(crossAxisAlignment: stretch) + Center：会形成循环依赖
                // （Center 依赖 Row 高度，Row 高度依赖 Center 高度），导致 infinite height 异常。
                // 改用 SizedBox(height: 230) + Align(center) 显式给 metaRow 固定 230 高度。
                if (!isTheoreticalMode) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ExportUserInfoWidget.buildUserInfoSection(context, selectedPlateId: selectedPlateId),
                      const SizedBox(width: 16),
                      SizedBox(
                        height: 230,
                        child: Align(
                          alignment: Alignment.center,
                          child: _buildMetaRow(),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.0),
                ],

                // 评分区域
                _buildRatingSection(context, rating, ratingAverage, best35Sum, best35Average, best15Sum, best15Average, best50AchievementAverage, best35AchievementAverage, best15AchievementAverage, best50ScoreRateAverage, best35ScoreRateAverage, best15ScoreRateAverage, sdSongs, dxSongs),
                SizedBox(height: 20.0),

                // Best35 标题区域
                _buildSectionTitle(context, isTheoreticalMode ? '理论Best35 | 非当前版本最高定数' : 'Best35 | 非当前版本最好成绩'),
                SizedBox(height: 16.0),

                // Best35 卡片网格 (5列)
                _buildDataCardGrid(context, sdSongs, 1.85, 5, b50Data, maimaiMusicData, maxIdLength),
                SizedBox(height: 24.0),

                // Best15 标题区域
                _buildSectionTitle(context, isTheoreticalMode ? '理论Best15 | 当前版本最高定数' : 'Best15 | 当前版本最好成绩'),
                SizedBox(height: 16.0),

                // Best15 卡片网格 (5列)
                _buildDataCardGrid(context, dxSongs, 1.85, 5, b50Data, maimaiMusicData, maxIdLength),
                SizedBox(height: 20.0),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 构建元数据行（数据源 / 导出时间 / Generated by ChiffonMai / 交流群号）
  // 悬浮在图片右上角。用纯白背景 + 黑边框 + 圆角，与下方统计区域样式一致，
  // 让 metaRow 视觉上是一块独立的"信息卡片"，避免与左侧姓名框视觉混淆。
  static Widget _buildMetaRow() {
    return FutureBuilder<Map<String, String>>(
      future: _loadMetaInfo(),
      builder: (context, snapshot) {
        final dataSource = snapshot.data?['dataSource'] ?? '';
        final exportTime = snapshot.data?['exportTime'] ?? '';
        return Container(
          // 固定宽度填满 SizedBox 的可用空间。
          // 计算：Positioned width 1700 - 外层 Padding 20×2 = 1660；
          //       姓名框 1150 + gap 16 = 1166；剩余 = 1660 - 1166 = 494。
          // 之前误算成 534（没扣外层 Padding 20×2 = 40），导致 metaRow 右侧出界 40 像素。
          width: 494,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black, width: 2.0),
            borderRadius: BorderRadius.circular(8.0),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            // 4 行垂直布局（每行右对齐）：
            //   1. 数据源
            //   2. 导出时间
            //   3. Generated by ChiffonMai
            //   4. 交流群（单独成行，不再和数据源/导出时间并列）
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMetaLine(
                icon: Icons.storage_rounded,
                label: '数据源',
                value: dataSource.isNotEmpty ? dataSource : '未知',
              ),
              const SizedBox(height: 8),
              _buildMetaLine(
                icon: Icons.schedule_rounded,
                label: '导出时间',
                value: exportTime,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.auto_awesome,
                      size: 20, color: Color(0xFF1F4FA5)),
                  SizedBox(width: 6),
                  Text(
                    'Generated by ',
                    style: TextStyle(
                      fontSize: 20,
                      color: Color(0xFF1F4FA5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'ChiffonMai',
                    style: TextStyle(
                      fontSize: 22,
                      color: Color(0xFF1F4FA5),
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 第 4 行：交流群单独成行（图标 + 标签 + 群号）
              _buildQqGroupChip(),
            ],
          ),
        );
      },
    );
  }

  // 交流群号 — 纯文本展示（无背景框），跟其他 metaRow 文字风格一致
  // 单行布局：💬图标 + 「交流群」+ 群号 291826702，全部在一行内显示
  static Widget _buildQqGroupChip() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        Icon(Icons.chat_bubble_outline,
            size: 22, color: Color(0xFF1F4FA5)),
        SizedBox(width: 6),
        Text(
          '交流群',
          style: TextStyle(
            fontSize: 22,
            color: Color(0xFF1F4FA5),
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(width: 10),
        Text(
          AppLinks.qqGroupNumber,
          style: TextStyle(
            fontSize: 28,
            color: Color(0xFF1F4FA5),
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  // 单行元数据：图标 + 标签 + 值
  static Widget _buildMetaLine({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF555555)),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 22,
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              color: Colors.black,
              fontWeight: FontWeight.w900,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  // 异步加载元数据信息（数据源 + 导出时间）
  static Future<Map<String, String>> _loadMetaInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataSource = RefreshDataSource.displayNameOfKey(
          prefs.getString(CacheKeyConstant.lastDataSource));
      final now = DateTime.now();
      final exportTime =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      return {
        'dataSource': dataSource,
        'exportTime': exportTime,
      };
    } catch (e) {
      return {'dataSource': '', 'exportTime': ''};
    }
  }

  // 单行：标题 + 数值（标题与数值之间留 4px，行内紧凑；标题 widget 由调用方提供以保留原样式）
  // 用于统计区 Row 内子块（块1 Rating / 块2 达成率），统一布局节奏
  // [crossAxisAlignment] 默认 start；块1/块2 居中时传 center，让 title/value 在块内水平居中
  static Widget _buildStatRow({
    required Widget title,
    required Widget value,
    double titleValueGap = 4.0,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start,
  }) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        title,
        SizedBox(height: titleValueGap),
        value,
      ],
    );
  }

  // Rating/Best 35/Best 15 数值：主值 + 括号内平均（粗体黑字 + 常规黑字）
  // 仅复用布局，不动字号字重
  static Widget _buildRatingValue(
    int sum,
    double average, {
    required double mainFontSize,
    required double subFontSize,
  }) {
    return RichText(
      text: TextSpan(
        children: [
          TextStyleUtil.span(
            sum.toString(),
            TextStyle(
              fontSize: mainFontSize,
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextStyleUtil.span(
            '(平均${average.toStringAsFixed(1)})',
            TextStyle(
              fontSize: subFontSize,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  // 单行统计项：用于块1/块2底部填充（Best35/Best15 定数区间、SSS+/SSS 数量）。
  // 文本水平居中，超过块宽时自动缩小字号以保持单行。
  static Widget _buildSimpleStat({
    required String label,
    required String value,
    required double labelFontSize,
    required double valueFontSize,
  }) {
    return Align(
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$label: ',
              style: TextStyle(
                fontSize: labelFontSize,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: valueFontSize,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF4DA8FF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 计算给定歌曲集合的定数区间，格式为 "max ~ min"（保留 1 位小数）。
  // 空集合或无有效 ds 字段时返回 "-"。
  static String _computeDsRange(List<Map<String, dynamic>> songs) {
    if (songs.isEmpty) return '-';
    double? minDs;
    double? maxDs;
    for (final song in songs) {
      final raw = song['ds'];
      double? ds;
      if (raw is num) {
        ds = raw.toDouble();
      } else if (raw is String) {
        ds = double.tryParse(raw);
      }
      if (ds == null) continue;
      if (minDs == null || ds < minDs) minDs = ds;
      if (maxDs == null || ds > maxDs) maxDs = ds;
    }
    if (minDs == null || maxDs == null) return '-';
    return '${maxDs.toStringAsFixed(1)} ~ ${minDs.toStringAsFixed(1)}';
  }

  // 统计给定歌曲集合中指定 rating 的数量（如 'sssp'、'sss'）。
  static int _countRate(List<Map<String, dynamic>> songs, String rate) {
    int count = 0;
    for (final song in songs) {
      if ((song['rate'] as String?) == rate) count++;
    }
    return count;
  }

  // 构建评分区域
  // 块1（Rating 总和）和块2（达成率）文本水平+垂直居中；
  // 块1 底部合并入 Best15 定数区间 + Best35 定数区间（间距小，Best15 在前）；
  // 块2 底部合并入 50首 SSS+ 数量 + 50首 SSS 数量（间距小，SSS+ 在前）；
  // 块2 平均达成率/DX分数达成率 行间 20，比块1 12 更舒展；
  // 元信息（数据源/导出时间/Generated by/交流群）已由调用方叠加在右上角，此处不再渲染。
  static Widget _buildRatingSection(BuildContext context, int rating, double ratingAverage, int best35Sum, double best35Average, int best15Sum, double best15Average, double best50AchievementAverage, double best35AchievementAverage, double best15AchievementAverage, double best50ScoreRateAverage, double best35ScoreRateAverage, double best15ScoreRateAverage, List<Map<String, dynamic>> sdSongs, List<Map<String, dynamic>> dxSongs) {
    // 图片容器固定宽度为1200，以此为基准计算字体大小
    const double containerWidth = 1200.0;

    // 根据容器宽度计算字体大小（与App观感一致）
    double mainFontSize = containerWidth * 0.032; // 约38px
    double subFontSize = containerWidth * 0.025; // 约30px
    double sectionTitleFontSize = containerWidth * 0.03; // 约36px

    // 计算填充用的统计量：
    //   - Best35/Best15 定数区间（最大值 ~ 最小值）
    //   - 50首中 SSS+ 与 SSS 数量（sdSongs + dxSongs 合计）
    final String best35DsRange = _computeDsRange(sdSongs);
    final String best15DsRange = _computeDsRange(dxSongs);
    final int totalSssPlusCount =
        _countRate(sdSongs, 'sssp') + _countRate(dxSongs, 'sssp');
    final int totalSssCount =
        _countRate(sdSongs, 'sss') + _countRate(dxSongs, 'sss');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2.0),
        borderRadius: BorderRadius.circular(8.0),
      ),
      padding: EdgeInsets.all(16.0),
      // 用 IntrinsicHeight 让三个块按最高子节点对齐高度，
      // 同时不依赖父级有限高度约束（Row 默认是横向 flex，stretch 会要求外部 h 有限）
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 块1：Rating 总和 — 文本水平居中、垂直居中
            // 下方留白用于追加 Best35 定数区间 + 50首 SSS+ 数量（合并入块1，间距小）
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStatRow(
                    title: Align(
                      alignment: Alignment.center,
                      child: Text(
                        'Rating',
                        style: TextStyle(
                          fontSize: sectionTitleFontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    value: Align(
                      alignment: Alignment.center,
                      child: _buildRatingValue(
                        rating,
                        ratingAverage,
                        mainFontSize: mainFontSize,
                        subFontSize: subFontSize,
                      ),
                    ),
                    crossAxisAlignment: CrossAxisAlignment.center,
                  ),
                  const SizedBox(height: 12),
                  _buildStatRow(
                    title: Align(
                      alignment: Alignment.center,
                      child: Text(
                        'Best 35',
                        style: TextStyle(
                          fontSize: mainFontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    value: Align(
                      alignment: Alignment.center,
                      child: _buildRatingValue(
                        best35Sum,
                        best35Average,
                        mainFontSize: mainFontSize,
                        subFontSize: subFontSize,
                      ),
                    ),
                    crossAxisAlignment: CrossAxisAlignment.center,
                  ),
                  const SizedBox(height: 12),
                  _buildStatRow(
                    title: Align(
                      alignment: Alignment.center,
                      child: Text(
                        'Best 15',
                        style: TextStyle(
                          fontSize: mainFontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    value: Align(
                      alignment: Alignment.center,
                      child: _buildRatingValue(
                        best15Sum,
                        best15Average,
                        mainFontSize: mainFontSize,
                        subFontSize: subFontSize,
                      ),
                    ),
                    crossAxisAlignment: CrossAxisAlignment.center,
                  ),
                  const SizedBox(height: 8),
                  // 填充 1：Best35 定数区间（最大值 ~ 最小值，来自 sdSongs）
                  _buildSimpleStat(
                    label: 'Best35 定数区间',
                    value: best35DsRange,
                    labelFontSize: sectionTitleFontSize * 0.9,
                    valueFontSize: mainFontSize,
                  ),
                  const SizedBox(height: 4),
                  // 填充 2：Best15 定数区间（最大值 ~ 最小值，来自 dxSongs）
                  _buildSimpleStat(
                    label: 'Best15 定数区间',
                    value: best15DsRange,
                    labelFontSize: sectionTitleFontSize * 0.9,
                    valueFontSize: mainFontSize,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // 块2：达成率 — 文本水平居中、垂直居中
            // 下方留白用于追加 Best15 定数区间 + 50首 SSS 数量（合并入块2，间距小）
            // 平均达成率/DX分数达成率 行间距拉到 20，让块2 视觉密度更舒展
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStatRow(
                    title: _buildSectionTitleText(
                        context, 'Best 50 平均达成率/DX分数达成率', sectionTitleFontSize,
                        alignment: Alignment.center),
                    value: Align(
                      alignment: Alignment.center,
                      child: _buildDualDecimalText(
                          context, best50AchievementAverage, best50ScoreRateAverage * 100,
                          scoreRate: best50ScoreRateAverage),
                    ),
                    crossAxisAlignment: CrossAxisAlignment.center,
                  ),
                  const SizedBox(height: 20),
                  _buildStatRow(
                    title: _buildSectionTitleText(
                        context, 'Best 35 平均达成率/DX分数达成率', sectionTitleFontSize,
                        alignment: Alignment.center),
                    value: Align(
                      alignment: Alignment.center,
                      child: _buildDualDecimalText(
                          context, best35AchievementAverage, best35ScoreRateAverage * 100,
                          scoreRate: best35ScoreRateAverage),
                    ),
                    crossAxisAlignment: CrossAxisAlignment.center,
                  ),
                  const SizedBox(height: 20),
                  _buildStatRow(
                    title: _buildSectionTitleText(
                        context, 'Best 15 平均达成率/DX分数达成率', sectionTitleFontSize,
                        alignment: Alignment.center),
                    value: Align(
                      alignment: Alignment.center,
                      child: _buildDualDecimalText(
                          context, best15AchievementAverage, best15ScoreRateAverage * 100,
                          scoreRate: best15ScoreRateAverage),
                    ),
                    crossAxisAlignment: CrossAxisAlignment.center,
                  ),
                  const SizedBox(height: 8),
                  // 填充 1：50首 SSS+ 数量（sdSongs + dxSongs 合计）
                  _buildSimpleStat(
                    label: '50首 SSS+ 数量',
                    value: totalSssPlusCount.toString(),
                    labelFontSize: sectionTitleFontSize * 0.9,
                    valueFontSize: mainFontSize,
                  ),
                  const SizedBox(height: 4),
                  // 填充 2：50首 SSS 数量（sdSongs + dxSongs 合计）
                  _buildSimpleStat(
                    label: '50首 SSS 数量',
                    value: totalSssCount.toString(),
                    labelFontSize: sectionTitleFontSize * 0.9,
                    valueFontSize: mainFontSize,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // 块3：可提升定数 RA 对照表（保持原左对齐）
            Expanded(
              flex: 5,
              child: _buildImprovableRatingTable(context, sdSongs, dxSongs),
            ),
          ],
        ),
      ),
    );
  }

  // 构建可提升定数 RA 对照表（Best35 + Best15 两个子表）
  static Widget _buildImprovableRatingTable(BuildContext context, List<Map<String, dynamic>> sdSongs, List<Map<String, dynamic>> dxSongs) {
    const double containerWidth = 1200.0;
    final double titleFontSize = containerWidth * 0.024; // ~28.8
    final double subTitleFontSize = containerWidth * 0.020; // ~24
    final double cellFontSize = containerWidth * 0.020; // ~24
    final double headerIconSize = containerWidth * 0.030; // ~36

    const tiers = ['sssp', 'sss', 'ssp', 'ss', 'sp'];
    const completions = [100.5, 100.0, 99.5, 99.0, 97.0];

    final best35MinRa = _computeMinRa(sdSongs);
    final best15MinRa = _computeMinRa(dxSongs);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '可提升定数 RA 对照',
          style: TextStyle(
            fontSize: titleFontSize,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 6),
        // Best35 子表：1 表头 + 5 数据 = 6 行
        Expanded(
          flex: 6,
          child: _buildRatingSubTable(
            context: context,
            label: 'Best35',
            diffList: _computeTargetDiffList(sdSongs, 5),
            tiers: tiers,
            completions: completions,
            subTitleFontSize: subTitleFontSize,
            cellFontSize: cellFontSize,
            headerIconSize: headerIconSize,
            minRa: best35MinRa,
          ),
        ),
        const SizedBox(height: 8),
        // Best15 子表：1 表头 + 2 数据 = 3 行
        Expanded(
          flex: 3,
          child: _buildRatingSubTable(
            context: context,
            label: 'Best15',
            diffList: _computeTargetDiffList(dxSongs, 2),
            tiers: tiers,
            completions: completions,
            subTitleFontSize: subTitleFontSize,
            cellFontSize: cellFontSize,
            headerIconSize: headerIconSize,
            minRa: best15MinRa,
          ),
        ),
      ],
    );
  }

  // 构建单个定数 RA 对照子表
  static Widget _buildRatingSubTable({
    required BuildContext context,
    required String label,
    required List<double> diffList,
    required List<String> tiers,
    required List<double> completions,
    required double subTitleFontSize,
    required double cellFontSize,
    required double headerIconSize,
    int? minRa,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: subTitleFontSize,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Table(
            border: TableBorder(
              horizontalInside:
                  BorderSide(color: const Color(0xFFCCCCCC), width: 1),
              verticalInside:
                  BorderSide(color: const Color(0xFFCCCCCC), width: 1),
              top: BorderSide(color: Colors.black, width: 1.5),
              bottom: BorderSide(color: Colors.black, width: 1.5),
              left: BorderSide(color: Colors.black, width: 1.5),
              right: BorderSide(color: Colors.black, width: 1.5),
            ),
            columnWidths: const {
              0: FlexColumnWidth(2.0),
              1: FlexColumnWidth(1.6),
              2: FlexColumnWidth(1.6),
              3: FlexColumnWidth(1.6),
              4: FlexColumnWidth(1.6),
              5: FlexColumnWidth(1.6),
            },
            children: [
              // 表头：定数 + 5 个评级图标
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFFEFEFEF)),
                children: [
                  _buildHeaderCell('定数', cellFontSize, bold: true),
                  for (final t in tiers) _buildTierIconCell(t, headerIconSize),
                ],
              ),
              // 数据行
              for (int i = 0; i < diffList.length; i++)
                TableRow(
                  decoration: BoxDecoration(
                    color: i.isEven
                        ? Colors.white
                        : const Color(0xFFF7F7F7),
                  ),
                  children: [
                    _buildHeaderCell(diffList[i].toStringAsFixed(1),
                        cellFontSize, bold: true),
                    for (int t = 0; t < tiers.length; t++)
                      () {
                        // 计算本格 RA：>_computeMinRa 才显示数字+提升值
                        final ra = _raAt(diffList[i], completions[t]);
                        final showRa = minRa == null || ra > minRa;
                        return _buildDataCell(
                          showRa ? ra.toString() : '',
                          cellFontSize,
                          // 提升值 = RA - 池子最低 RA（仅在有数据时显示）
                          improvement: showRa && minRa != null
                              ? ra - minRa
                              : null,
                        );
                      }(),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  // 计算池子中最低的单曲 ra
  static int? _computeMinRa(List<Map<String, dynamic>> songs) {
    int? minRa;
    for (final song in songs) {
      final ra = (song['ra'] as num?)?.toInt() ?? 0;
      if (ra <= 0) continue;
      if (minRa == null || ra < minRa) {
        minRa = ra;
      }
    }
    return minRa;
  }

  // 单行标题文字：超出块宽时自动缩小（scaleDown），永远保持单行不换行
  // [alignment] 默认 centerLeft；块2 居中时传 center，让标题字符在块内水平居中
  static Widget _buildSectionTitleText(BuildContext context, String text, double fontSize, {Alignment alignment = Alignment.centerLeft}) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }

  // 表头文字 cell
  static Widget _buildHeaderCell(String text, double fontSize, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.bold : FontWeight.w600,
          color: Colors.black,
        ),
      ),
    );
  }

  // 评级图标 cell（表头）
  static Widget _buildTierIconCell(String tier, double size) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Image.asset(
        'assets/gamrank/$tier.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Text(
          tier.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: size * 0.35,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  // 数据 cell（RA 数字 + 可选提升值）
  // [improvement] 若非空，在 RA 数字右侧追加绿色小字「▲xx」表示该 RA 相对池子最低 RA 的提升量。
  // 用 Row + baseline 对齐：RA 主字号，提升值小一号、绿色（▲ 实心三角），整行不换行。
  static Widget _buildDataCell(String text, double fontSize, {int? improvement}) {
    final mainStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      color: Colors.black,
    );
    final gainStyle = TextStyle(
      fontSize: fontSize * 0.7,
      color: const Color(0xFF00A800), // 绿色
      fontWeight: FontWeight.bold,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: mainStyle,
          ),
          if (improvement != null && improvement > 0) ...[
            const SizedBox(width: 3),
            Text(
              '▲$improvement',
              textAlign: TextAlign.center,
              style: gainStyle,
            ),
          ],
        ],
      ),
    );
  }

  // 计算 RA 在指定定数与达成率下（与 DiffBest50Service.calculateSingleRating 等价）
  static int _raAt(double ds, double completion) {
    const table = <Map<String, dynamic>>[
      {"completion": 100.5, "rating": "SSS+", "multiplier": 0.224},
      {"completion": 100.0, "rating": "SSS", "multiplier": 0.216},
      {"completion": 99.5, "rating": "SS+", "multiplier": 0.211},
      {"completion": 99.0, "rating": "SS", "multiplier": 0.208},
      {"completion": 98.0, "rating": "S+", "multiplier": 0.203},
      {"completion": 97.0, "rating": "S", "multiplier": 0.200},
      {"completion": 96.9999, "rating": "AAA", "multiplier": 0.176},
      {"completion": 94.0, "rating": "AAA", "multiplier": 0.168},
      {"completion": 90.0, "rating": "AA", "multiplier": 0.152},
      {"completion": 80.0, "rating": "A", "multiplier": 0.136},
      {"completion": 79.9999, "rating": "BBB", "multiplier": 0.128},
      {"completion": 75.0, "rating": "BBB", "multiplier": 0.120},
      {"completion": 70.0, "rating": "BB", "multiplier": 0.112},
      {"completion": 60.0, "rating": "B", "multiplier": 0.096},
      {"completion": 50.0, "rating": "C", "multiplier": 0.080},
      {"completion": 40.0, "rating": "D", "multiplier": 0.064},
      {"completion": 30.0, "rating": "D", "multiplier": 0.048},
      {"completion": 20.0, "rating": "D", "multiplier": 0.032},
      {"completion": 10.0, "rating": "D", "multiplier": 0.016},
    ];
    double adj = completion > 100.5 ? 100.5 : completion;
    Map<String, dynamic>? selected;
    for (final row in table) {
      if (adj >= (row['completion'] as num).toDouble()) {
        selected = row;
        break;
      }
    }
    selected ??= const {"rating": "D", "multiplier": 0.016};
    return (ds * (selected['multiplier'] as num).toDouble() * completion)
        .floor();
  }

  // 计算指定数量的定数列表（步长按 minDs 分段：<10 用 0.5、≤14 用 0.2、>14 用 0.1，上限 15.0）
  // 算法：先找池子中最低单曲 ra，再找最小 ds 使 floor(ds*0.224*100.5) > minRa
  static List<double> _computeTargetDiffList(
      List<Map<String, dynamic>> songs, int count) {
    // 找池子中最低的单曲 ra
    int? minRa;
    for (final song in songs) {
      final ra = (song['ra'] as num?)?.toInt() ?? 0;
      if (ra <= 0) continue;
      if (minRa == null || ra < minRa) {
        minRa = ra;
      }
    }

    // 找最小 ds（0.1 粒度）使 floor(ds * 0.224 * 100.5) > minRa
    double? minDsAt01;
    if (minRa != null) {
      for (int i = 10; i <= 150; i++) {
        // i/10 表示 ds，从 1.0 到 15.0
        final ds = i / 10.0;
        if ((ds * 0.224 * 100.5).floor() > minRa) {
          minDsAt01 = ds;
          break;
        }
      }
    }

    // minDs 保持 0.1 粒度的精确最小值
    double? minDs = minDsAt01;

    // 兜底：找不到或超过 15.0 上限则用 13.0
    minDs ??= 13.0;
    if (minDs > 15.0) minDs = 13.0;

    // 步长规则：
    //   - minDs <  10.0 → 0.5（高定数区间密集显示）
    //   - minDs <= 14.0 → 0.2
    //   - minDs >  14.0 → 0.1（超过 14 的高定数更细分）
    final double step;
    if (minDs < 10.0) {
      step = 0.5;
    } else if (minDs <= 14.0) {
      step = 0.2;
    } else {
      step = 0.1;
    }
    final List<double> result = [];
    for (int i = 0; i < count; i++) {
      final v = minDs + step * i;
      if (v > 15.0 + 1e-9) break;
      result.add(double.parse(v.toStringAsFixed(1)));
    }
    return result;
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

  // 构建游戏卡片（导出版）：scale=1.0，与导出图片同源。
  // 实际渲染委托给通用 B50GameCardWidget。
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
    String fc = '',
    String fs = '',
    String rate = '',
    int? songId,
    Color starsColor = Colors.white,
    int maxIdLength = 5,
  }) {
    return B50GameCardWidget(
      cardColor: cardColor,
      songName: songName,
      achievementRate: achievementRate,
      difficulty: difficulty,
      dxMode: dxMode,
      isUtage: isUtage,
      score: score,
      maxScore: maxScore,
      rating: rating,
      stars: stars,
      fc: fc,
      fs: fs,
      rate: rate,
      songId: songId ?? 0,
      starsColor: starsColor,
      maxIdLength: maxIdLength,
      scale: 1.0,
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
    double? scoreRate,
  }) {
    // 图片容器固定宽度为1200，以此为基准计算字体大小
    const double containerWidth = 1200.0;

    // 根据容器宽度计算字体大小（与App观感一致）
    double fontSize = containerWidth * 0.03; // 约36px

    final starsText = scoreRate != null ? StringUtil.formatStars(scoreRate) : null;
    final starsColor =
        scoreRate != null ? ColorUtil.getStarsColor(starsText!) : null;

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
        // DX 分达成率右侧添加星级（achievement / dxScore% / ✦x）
        if (starsText != null) ...[
          Text(
            '/',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            starsText,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: starsColor,
            ),
          ),
        ],
      ],
    );
  }

  // 构建数据驱动的卡片网格
  static Widget _buildDataCardGrid(
      BuildContext context, List<Map<String, dynamic>> songs, double childAspectRatio, int crossAxisCount, Map<String, dynamic>? b50Data, List<dynamic>? maimaiMusicData, int maxIdLength) {
    return Container(
      width: 1700,
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
          return _buildDataGameCard(context, songs[index], b50Data, maimaiMusicData, maxIdLength);
        },
      ),
    );
  }

  // 根据数据构建游戏卡片
  static Widget _buildDataGameCard(BuildContext context, Map<String, dynamic> songData, Map<String, dynamic>? b50Data, List<dynamic>? maimaiMusicData, int maxIdLength) {
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
    // String fcText = fc.isNotEmpty ? StringUtil.formatFC(fc) : '-';

    // 映射FS属性（使用与App相同的StringUtil）
    // String fsText = fs.isNotEmpty ? StringUtil.formatFS(fs) : '-';

    // 映射Rate属性（使用与App相同的StringUtil）
    // String rateText = StringUtil.formatRate(rate);

    // 构建完整grade（暂时注释，用 assets/grade/ 下的图片代替）
    // String grade = '评级:$rateText | 连击:$fcText | 同步:$fsText';

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
      fc: fc,
      fs: fs,
      rate: rate,
      songId: songId,
      starsColor: starsColor,
      maxIdLength: maxIdLength,
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
}