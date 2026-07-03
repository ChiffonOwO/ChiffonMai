import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import '../entity/FavoriteFolder.dart';
import '../entity/DivingFish/Song.dart';
import '../utils/CoverUtil.dart';
import '../utils/StringUtil.dart';

/// 收藏夹导出为图片的服务
class FavoriteExportService {
  static final FavoriteExportService _instance = FavoriteExportService._internal();
  factory FavoriteExportService() => _instance;
  FavoriteExportService._internal();

  /// 导出需要配合 UI 层完成——在页面中使用 GlobalKey + RepaintBoundary 捕获，
  /// 然后调用 [saveImageBytes] 保存到本地文件
  Future<String?> saveImageBytes({
    required List<int> pngBytes,
    required String folderName,
  }) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'favorites_${folderName}_$timestamp.png';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(pngBytes);
      debugPrint('收藏夹图片已保存到: ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('保存收藏夹图片失败: $e');
      return null;
    }
  }

  Widget _buildExportWidget(
    String folderName,
    List<FavoriteChart> charts,
    Map<String, Song> songMap,
  ) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Text(
              folderName,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF546161),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '共 ${charts.length} 个谱面',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6D7D7D),
              ),
            ),
            const Divider(height: 24),
            // 谱面列表
            ...charts.map((chart) {
              final song = songMap[chart.songId];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    // 曲绘缩略图
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: CoverUtil.buildCoverWidget(chart.songId, 50),
                    ),
                    const SizedBox(width: 12),
                    // 信息
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            chart.songTitle,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${chart.ds.toStringAsFixed(1)} | ${StringUtil.formatVersion2(song?.basicInfo.from ?? '')} | ${song?.basicInfo.genre ?? ''}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 难度级别
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getLevelColor(chart.levelIndex),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        chart.level,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const Divider(height: 24),
            // 水印
            Center(
              child: Text(
                'ChiffonMai',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getLevelColor(int levelIndex) {
    switch (levelIndex) {
      case 0:
        return Colors.green;
      case 1:
        return Colors.orange;
      case 2:
        return Colors.red;
      case 3:
        return Colors.purple;
      case 4:
        return Colors.deepPurple;
      default:
        return Colors.grey;
    }
  }

  /// 从给定的 GlobalKey（必须挂载在 RepaintBoundary 上）捕获图片
  Future<List<int>> renderFromKey(GlobalKey key) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw Exception('无法获取 RepaintBoundary');
    }
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}
