import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:media_scanner/media_scanner.dart';
import 'package:my_first_flutter_app/utils/CoverUtil.dart';
import 'package:my_first_flutter_app/utils/StringUtil.dart';
import 'package:my_first_flutter_app/utils/ColorUtil.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';

/// 歌曲信息导出为图片服务
/// 将歌曲的完整信息（曲绘、歌名、所有难度的物量和绝赞统计）渲染为图片
class SongInfoExportToImgService {
  /// 导出为图片的主方法
  static Future<File?> convertToImage(
    BuildContext context, {
    required String songId,
    required Map<String, dynamic> basicInfo,
    required List<dynamic> charts,
    required List<dynamic> levels,
    required List<dynamic> ds,
    required String songType,
    required List<dynamic>? diffData,
    required Map<int, List<int>> maidataNoteCounts,
    required Map<int, List<int>> maidataBreakCounts,
    required bool maidataDecodedSuccessfully,
  }) async {
    OverlayEntry? overlayEntry;
    try {
      debugPrint('=== SongInfoExport: STARTING IMAGE CONVERSION ===');

      // 请求存储权限
      final status = await _requestStoragePermission();
      debugPrint('Storage permission: $status');

      // 创建GlobalKey用于截图
      GlobalKey globalKey = GlobalKey();

      // 构建导出Widget
      Widget imageWidget = RepaintBoundary(
        key: globalKey,
        child: _buildExportWidget(
          context: context,
          songId: songId,
          basicInfo: basicInfo,
          charts: charts,
          levels: levels,
          ds: ds,
          songType: songType,
          diffData: diffData,
          maidataNoteCounts: maidataNoteCounts,
          maidataBreakCounts: maidataBreakCounts,
          maidataDecodedSuccessfully: maidataDecodedSuccessfully,
        ),
      );

      // 创建离屏OverlayEntry
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

      // 插入到Overlay并等待渲染
      Overlay.of(context).insert(overlayEntry);
      await _waitForRender();

      // 捕获为图片
      final boundary = globalKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        debugPrint('SongInfoExport: RenderRepaintBoundary not found');
        overlayEntry.remove();
        return null;
      }

      // 动态计算 pixelRatio，避免超过 GPU 最大纹理尺寸限制
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
      debugPrint('SongInfoExport: Widget size: ${widgetWidth}x$widgetHeight, pixelRatio: $pixelRatio');

      ui.Image image;
      try {
        image = await boundary.toImage(pixelRatio: pixelRatio);
      } catch (e) {
        debugPrint('SongInfoExport: First capture failed: $e');
        await Future.delayed(Duration(milliseconds: 200));
        image = await boundary.toImage(pixelRatio: pixelRatio);
      }

      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        debugPrint('SongInfoExport: ByteData is null');
        overlayEntry.remove();
        image.dispose();
        return null;
      }

      Uint8List pngBytes = byteData.buffer.asUint8List();
      image.dispose();
      overlayEntry.remove();

      // 保存图片
      final songTitle = basicInfo['title'] ?? '';
      return await _saveImage(pngBytes, songTitle, status.isGranted);
    } catch (e) {
      debugPrint('SongInfoExport: Error: $e');
      overlayEntry?.remove();
      return null;
    }
  }

  /// 构建导出Widget
  static Widget _buildExportWidget({
    required BuildContext context,
    required String songId,
    required Map<String, dynamic> basicInfo,
    required List<dynamic> charts,
    required List<dynamic> levels,
    required List<dynamic> ds,
    required String songType,
    required List<dynamic>? diffData,
    required Map<int, List<int>> maidataNoteCounts,
    required Map<int, List<int>> maidataBreakCounts,
    required bool maidataDecodedSuccessfully,
  }) {
    final bool isUtage = songId.length == 6;
    final String songTitle = basicInfo['title'] ?? '';
    final String artist = basicInfo['artist'] ?? '';
    final String genre = basicInfo['genre'] ?? '';
    final int bpm = (basicInfo['bpm'] is int)
        ? basicInfo['bpm']
        : int.tryParse(basicInfo['bpm']?.toString() ?? '0') ?? 0;
    final String from = basicInfo['from'] ?? '';
    final String typeLabel = isUtage ? 'UTAGE' : StringUtil.formatSongType(songType);

    // 难度名称
    final diffNames = ['Basic', 'Advanced', 'Expert', 'Master', 'Re:Master'];

    // 获取第一个有效难度的强调色（用于公共区域）
    final int primaryDiffIndex = levels.isNotEmpty ? (levels.length - 1).clamp(0, 4) : 3;
    final Color headerAccentColor =
        isUtage ? AppColors.utageAccent() : ColorUtil.getCardColor(primaryDiffIndex);

    return Container(
      width: 1200,
      color: Colors.white,
      padding: const EdgeInsets.all(36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ==================== HEADER SECTION ====================
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 曲绘封面
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    border: Border.all(color: headerAccentColor, width: 4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: CoverUtil.buildCoverWidgetWithContext(context, songId, 240),
                ),
              ),
              const SizedBox(width: 28),

              // 歌曲名称 + 标签
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    // 歌曲标题
                    Text(
                      songTitle,
                      style: const TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    // 艺术家
                    Text(
                      artist,
                      style: TextStyle(
                        fontSize: 26,
                        color: const Color(0xFF546161).withAlpha(200),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 类型标签
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildInfoChip(
                          typeLabel,
                          isUtage
                              ? AppColors.utageTag()
                              : (songType == 'SD' ? Colors.blue : Colors.orange),
                          filled: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // ==================== COMMON INFO ROW ====================
          // 类别 + BPM + 曲师 + 版本（公共信息，不随难度变化）
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _buildStatItem('类别', genre),
                _buildStatDivider(),
                _buildStatItem('BPM', bpm.toString()),
                _buildStatDivider(),
                _buildStatItem('曲师', artist.split('/').last),
                _buildStatDivider(),
                _buildStatItem('版本', StringUtil.formatVersion2(from)),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ==================== DIFFICULTY SECTIONS ====================
          for (int i = 0; i < levels.length; i++)
            _buildDifficultySection(
              context: context,
              songId: songId,
              diffIndex: i,
              diffName: i < diffNames.length ? diffNames[i] : 'Lv.$i',
              levelStr: levels[i].toString(),
              dsValue: (i < ds.length) ? (ds[i] is double ? ds[i] as double : double.tryParse(ds[i].toString()) ?? 0.0) : 0.0,
              basicInfo: basicInfo,
              charts: charts,
              diffData: diffData,
              maidataNoteCounts: maidataNoteCounts,
              maidataBreakCounts: maidataBreakCounts,
              maidataDecodedSuccessfully: maidataDecodedSuccessfully,
              isUtage: isUtage,
            ),

          const SizedBox(height: 24),

          // ==================== FOOTER ====================
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.music_note_rounded,
                    size: 22, color: headerAccentColor.withAlpha(150)),
                const SizedBox(width: 8),
                Text(
                  'ChiffonMai',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: headerAccentColor.withAlpha(150),
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// 构建单个难度区域
  static Widget _buildDifficultySection({
    required BuildContext context,
    required String songId,
    required int diffIndex,
    required String diffName,
    required String levelStr,
    required double dsValue,
    required Map<String, dynamic> basicInfo,
    required List<dynamic> charts,
    required List<dynamic>? diffData,
    required Map<int, List<int>> maidataNoteCounts,
    required Map<int, List<int>> maidataBreakCounts,
    required bool maidataDecodedSuccessfully,
    required bool isUtage,
  }) {
    final Color accentColor = isUtage
        ? AppColors.utageAccent()
        : ColorUtil.getCardColor(diffIndex);

    // 获取谱面信息
    Map<String, dynamic>? chart;
    if (diffIndex < charts.length) {
      chart = charts[diffIndex] as Map<String, dynamic>?;
    }
    final String charter = chart?['charter'] ?? '-';

    // 获取 diffData（拟合定数、平均达成）
    dynamic currentDiffData;
    if (diffData != null && diffData.length > diffIndex) {
      currentDiffData = diffData[diffIndex];
    }

    // 获取物量
    List<int> noteCounts = _getNoteCounts(
      diffIndex: diffIndex,
      charts: charts,
      maidataNoteCounts: maidataNoteCounts,
    );

    // 获取绝赞统计
    List<String> breakCounts = _getBreakCounts(
      diffIndex: diffIndex,
      charts: charts,
      songType: basicInfo['type'] ?? '',
      maidataBreakCounts: maidataBreakCounts,
      maidataDecodedSuccessfully: maidataDecodedSuccessfully,
    );

    // 计算最大DX分（用于显示）
    int maxDxScore = _calculateMaxScore(noteCounts);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: accentColor, width: 5),
        ),
        color: const Color(0xFFFCFCFC),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 难度标题栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _getDifficultyBgColor(diffIndex, isUtage),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Text(
                  isUtage ? 'UTAGE' : diffName,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: isUtage ? AppColors.utageAccent() : _getDifficultyFgColor(diffIndex),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$levelStr (定数 ${dsValue.toStringAsFixed(1)})',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: isUtage ? AppColors.utageAccent() : _getDifficultyFgColor(diffIndex),
                  ),
                ),
                const Spacer(),
                Text(
                  'Max: $maxDxScore',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 信息行1: 官方定数 + 拟合定数 + 定数差值
          Row(
            children: [
              Expanded(child: _buildStatItem('官方定数', dsValue.toStringAsFixed(1))),
              _buildStatDivider(),
              Expanded(
                child: _buildStatItem(
                  '拟合定数',
                  currentDiffData != null
                      ? _parseFitDiff(currentDiffData).toStringAsFixed(2)
                      : '-',
                ),
              ),
              _buildStatDivider(),
              Expanded(
                child: () {
                  if (currentDiffData == null) {
                    return _buildStatItem('定数差值', '-');
                  }
                  final fd = _parseFitDiff(currentDiffData);
                  final diff = fd - dsValue;
                  return _buildStatItem(
                    '定数差值',
                    '${diff >= 0 ? "+" : ""}${diff.toStringAsFixed(2)}',
                    valueColor: diff < 0 ? Colors.green : Colors.red,
                  );
                }(),
              ),
              _buildStatDivider(),
              Expanded(
                child: _buildStatItem(
                  '平均达成',
                  currentDiffData != null
                      ? '${_parseAvg(currentDiffData).toStringAsFixed(2)}%'
                      : '-',
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 信息行2: 谱面谱师
          Row(
            children: [
              _buildStatItem('谱面谱师', charter),
            ],
          ),

          const SizedBox(height: 16),

          // 分隔线
          Divider(color: Colors.grey.shade200, height: 1),

          const SizedBox(height: 12),

          // 物量行
          Text(
            '物量统计',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildNoteItem('总计', noteCounts.fold<int>(0, (sum, n) => sum + n).toString(), accentColor)),
              const SizedBox(width: 6),
              Expanded(child: _buildNoteItem('TAP', noteCounts[0].toString(), accentColor)),
              const SizedBox(width: 6),
              Expanded(child: _buildNoteItem('HOLD', noteCounts[1].toString(), accentColor)),
              const SizedBox(width: 6),
              Expanded(child: _buildNoteItem('SLIDE', noteCounts[2].toString(), accentColor)),
              const SizedBox(width: 6),
              Expanded(child: _buildNoteItem('TOUCH', noteCounts[3].toString(), accentColor)),
              const SizedBox(width: 6),
              Expanded(child: _buildNoteItem('BREAK', noteCounts[4].toString(), accentColor)),
            ],
          ),

          const SizedBox(height: 16),

          // 绝赞统计行
          Text(
            '绝赞统计',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildBreakItem('真绝赞TAP', breakCounts[0], const Color(0xFFEF5350))),
              const SizedBox(width: 6),
              Expanded(child: _buildBreakItem('真绝赞HOLD', breakCounts[1], const Color(0xFFFF6B6B))),
              const SizedBox(width: 6),
              Expanded(child: _buildBreakItem('保护套绝赞', breakCounts[2], const Color(0xFF64B5F6))),
              const SizedBox(width: 6),
              Expanded(child: _buildBreakItem('绝赞星星', breakCounts[3], const Color(0xFFFBC02D))),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== 数据解析辅助方法 ====================

  /// 获取物量统计，优先使用 maidata 解析结果，fallback 到 charts notes
  static List<int> _getNoteCounts({
    required int diffIndex,
    required List<dynamic> charts,
    required Map<int, List<int>> maidataNoteCounts,
  }) {
    // 优先使用Maidata解析的物量统计
    if (maidataNoteCounts.containsKey(diffIndex)) {
      List<int> counts = maidataNoteCounts[diffIndex]!;
      bool allZero = counts.every((count) => count == 0);
      if (!allZero) {
        return counts;
      }
    }

    // Fallback: 使用默认的notes数据
    List<int> notes = List.filled(5, 0);
    if (diffIndex >= charts.length) return notes;

    final chart = charts[diffIndex] as Map<String, dynamic>?;
    if (chart == null || chart['notes'] == null) return notes;

    List<dynamic> chartNotes = chart['notes'];
    notes[0] = chartNotes.length > 0 ? _parseInt(chartNotes[0]) : 0;
    notes[1] = chartNotes.length > 1 ? _parseInt(chartNotes[1]) : 0;
    notes[2] = chartNotes.length > 2 ? _parseInt(chartNotes[2]) : 0;
    if (chartNotes.length > 4) {
      // DX谱面: notes = [tap, hold, slide, touch, break]
      notes[3] = _parseInt(chartNotes[3]);
      notes[4] = _parseInt(chartNotes[4]);
    } else if (chartNotes.length > 3) {
      // ST谱面: notes = [tap, hold, slide, break]
      notes[4] = _parseInt(chartNotes[3]);
    }
    return notes;
  }

  /// 获取绝赞统计，优先使用 maidata 解析结果，fallback 到兜底逻辑
  static List<String> _getBreakCounts({
    required int diffIndex,
    required List<dynamic> charts,
    required String songType,
    required Map<int, List<int>> maidataBreakCounts,
    required bool maidataDecodedSuccessfully,
  }) {
    // 优先使用 maidata 解析结果
    if (maidataDecodedSuccessfully && maidataBreakCounts.containsKey(diffIndex)) {
      List<int> counts = maidataBreakCounts[diffIndex]!;
      bool allZero = counts.every((count) => count == 0);
      if (!allZero && counts.length >= 4) {
        return counts.map((c) => c.toString()).toList();
      }
    }

    // 兜底方案
    // ST谱面（SD类型）：真绝赞TAP = 总绝赞数量，其余为0
    if (songType == 'SD') {
      int breakCount = 0;
      if (diffIndex < charts.length) {
        final chart = charts[diffIndex] as Map<String, dynamic>?;
        if (chart != null && chart['notes'] != null) {
          List<dynamic> notes = chart['notes'];
          int breakIndex = notes.length >= 5 ? 4 : 3;
          if (notes.length > breakIndex) {
            breakCount = _parseInt(notes[breakIndex]);
          }
        }
      }
      return [breakCount.toString(), '0', '0', '0'];
    }

    // DX谱面无maidata时返回'-'
    return ['-', '-', '-', '-'];
  }

  /// 计算最大DX分
  static int _calculateMaxScore(List<int> noteCounts) {
    int totalNotes = noteCounts.fold(0, (sum, n) => sum + n);
    return totalNotes * 3;
  }

  /// 安全解析 int
  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// 解析拟合定数（兼容 DiffData 对象和 Map）
  static double _parseFitDiff(dynamic diffData) {
    if (diffData == null) return 0.0;
    try {
      // DiffData 对象
      final fitDiff = diffData.fitDiff;
      if (fitDiff != null) {
        if (fitDiff is num) return fitDiff.toDouble();
        return double.tryParse(fitDiff.toString()) ?? 0.0;
      }
    } catch (_) {}
    try {
      // Map 对象
      final fd = diffData['fit_diff'];
      if (fd != null) {
        if (fd is num) return fd.toDouble();
        return double.tryParse(fd.toString()) ?? 0.0;
      }
    } catch (_) {}
    return 0.0;
  }

  /// 解析平均达成（兼容 DiffData 对象和 Map）
  static double _parseAvg(dynamic diffData) {
    if (diffData == null) return 0.0;
    try {
      final avg = diffData.avg;
      if (avg != null) {
        if (avg is num) return avg.toDouble();
        return double.tryParse(avg.toString()) ?? 0.0;
      }
    } catch (_) {}
    try {
      final a = diffData['avg'];
      if (a != null) {
        if (a is num) return a.toDouble();
        return double.tryParse(a.toString()) ?? 0.0;
      }
    } catch (_) {}
    return 0.0;
  }

  // ==================== UI 组件构建方法 ====================

  /// 构建信息标签
  static Widget _buildInfoChip(String text, Color color, {bool filled = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? color : Colors.transparent,
        border: filled ? null : Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: filled ? Colors.white : color,
        ),
      ),
    );
  }

  /// 构建统计项
  static Widget _buildStatItem(String label, String value, {Color? valueColor}) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 18,
              color: const Color(0xFF546161).withAlpha(180),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: valueColor ?? const Color(0xFF2C3E50),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// 统计项分隔线
  static Widget _buildStatDivider() {
    return Container(
      width: 2,
      height: 50,
      color: const Color(0xFF546161).withAlpha(30),
    );
  }

  /// 构建物量项
  static Widget _buildNoteItem(String type, String count, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            type,
            style: const TextStyle(
              fontSize: 20,
              color: Color(0xFF6D7D7D),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            count,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建绝赞统计项
  static Widget _buildBreakItem(String type, String count, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            type,
            style: const TextStyle(
              fontSize: 20,
              color: Color(0xFF6D7D7D),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            count,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 渲染和保存管线 ====================

  static Future<void> _waitForRender() async {
    Completer<void> completer1 = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) => completer1.complete());
    await completer1.future;

    Completer<void> completer2 = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) => completer2.complete());
    await completer2.future;

    await Future.delayed(const Duration(milliseconds: 500));
    debugPrint('SongInfoExport: Render wait completed');
  }

  static Future<PermissionStatus> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      final storageStatus = await Permission.storage.status;
      final photosStatus = await Permission.photos.status;
      final videosStatus = await Permission.videos.status;

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
      final status = await Permission.storage.request();
      return status;
    }
  }

  static Future<File?> _saveImage(
    Uint8List pngBytes,
    String songTitle,
    bool hasPermission,
  ) async {
    Directory? directory;

    if (hasPermission) {
      try {
        String picturesPath = '/storage/emulated/0/Pictures';
        directory = Directory(picturesPath);
        if (!directory.existsSync()) {
          directory.createSync(recursive: true);
        }
        bool canWrite = await _checkDirectoryWritable(directory);
        if (!canWrite) {
          directory = null;
        }
      } catch (e) {
        debugPrint('SongInfoExport: Pictures dir error: $e');
        directory = null;
      }
    }

    if (directory == null) {
      try {
        directory = await getApplicationDocumentsDirectory();
      } catch (e) {
        try {
          directory = await getExternalStorageDirectory();
        } catch (e2) {
          debugPrint('SongInfoExport: No storage dir found');
          return null;
        }
      }
    }

    if (directory == null) return null;

    // Android: 尝试 MediaStore API
    if (Platform.isAndroid && hasPermission) {
      String? galleryPath = await _saveImageToGallery(
        pngBytes,
        'chiffonmai_songinfo_${_sanitizeFileName(songTitle)}_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      if (galleryPath != null) {
        await _notifySystemGallery(galleryPath);
        return File(galleryPath);
      }
    }

    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }

    final file = File(
      '${directory.path}/chiffonmai_songinfo_${_sanitizeFileName(songTitle)}_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(pngBytes);

    if (Platform.isAndroid) {
      await _notifySystemGallery(file.path);
    }

    return file;
  }

  static String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').replaceAll(' ', '_');
  }

  static Future<String?> _saveImageToGallery(
    Uint8List imageBytes,
    String fileName,
  ) async {
    try {
      const MethodChannel channel = MethodChannel('com.example.app/media_store');
      final String? result = await channel.invokeMethod('saveImage', {
        'imageBytes': imageBytes,
        'fileName': fileName,
      });
      return result;
    } catch (e) {
      debugPrint('SongInfoExport: MediaStore error: $e');
      return null;
    }
  }

  static Future<void> _notifySystemGallery(String filePath) async {
    try {
      await MediaScanner.loadMedia(path: filePath);
    } catch (e) {
      debugPrint('SongInfoExport: MediaScanner error: $e');
    }
    try {
      const MethodChannel channel = MethodChannel('com.example.app/media_scan');
      await channel.invokeMethod('scanFile', {'path': filePath});
    } catch (e) {
      debugPrint('SongInfoExport: scanFile error: $e');
    }
    try {
      const MethodChannel channel = MethodChannel('com.example.app/media_scan');
      await channel.invokeMethod('scanImage', {'path': filePath});
    } catch (e) {
      debugPrint('SongInfoExport: scanImage error: $e');
    }
  }

  static Future<bool> _checkDirectoryWritable(Directory directory) async {
    try {
      String testFileName =
          'test_write_${DateTime.now().millisecondsSinceEpoch}.tmp';
      File testFile = File('${directory.path}/$testFileName');
      await testFile.writeAsString('test');
      await testFile.delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== 颜色辅助 ====================

  /// 获取难度前景色（标签/文字颜色）
  static Color _getDifficultyFgColor(int diffIndex) {
    switch (diffIndex) {
      case 0:
        return const Color(0xFF4CAF50);
      case 1:
        return const Color(0xFFFF9800);
      case 2:
        return const Color(0xFFE91E63);
      case 3:
        return const Color(0xFF9966CC);
      case 4:
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFF9966CC);
    }
  }

  /// 获取难度背景色
  static Color _getDifficultyBgColor(int diffIndex, bool isUtage) {
    if (isUtage) return const Color(0xFFFFE6F0);
    switch (diffIndex) {
      case 0:
        return const Color(0xFFE8F5E8);
      case 1:
        return const Color(0xFFFFF8E1);
      case 2:
        return const Color(0xFFFCE4EC);
      case 3:
        return const Color(0xFFE9D8FF);
      case 4:
        return const Color(0xFFF3E5F5);
      default:
        return const Color(0xFFE9D8FF);
    }
  }
}