import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../utils/ExportPathUtil.dart';
import '../utils/ImageEncodeUtil.dart';

/// 收藏夹导出为图片的服务
class FavoriteExportService {
  static final FavoriteExportService _instance = FavoriteExportService._internal();
  factory FavoriteExportService() => _instance;
  FavoriteExportService._internal();

  /// 导出需要配合 UI 层完成——在页面中使用 GlobalKey + RepaintBoundary 捕获，
  /// 然后调用 [saveImageBytes] 保存到本地文件
  ///
  /// 落盘位置与其它导出保持一致：`Download/ChiffonMai/收藏夹/`，
  /// 文件管理器可以直接找到（公开目录不可写时自动退化为应用文档目录）。
  Future<String?> saveImageBytes({
    required List<int> pngBytes,
    required String folderName,
  }) async {
    try {
      final safeName =
          ExportPathUtil.sanitizeFileName(folderName, fallback: 'favorites');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = await ExportPathUtil.writeExportFile(
        fileName: 'favorites_${safeName}_$timestamp.png',
        bytes: pngBytes,
        subDir: '收藏夹',
      );
      debugPrint('收藏夹图片已保存到: ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('保存收藏夹图片失败: $e');
      return null;
    }
  }

  /// 从给定的 GlobalKey（必须挂载在 RepaintBoundary 上）捕获图片
  Future<List<int>> renderFromKey(GlobalKey key) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw Exception('无法获取 RepaintBoundary');
    }
    final image = await boundary.toImage(pixelRatio: ImageEncodeUtil.safeCapturePixelRatio(boundary.size.width, boundary.size.height));
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    // 立刻释放 ui.Image（上百 MB 的原生位图），别等 GC
    image.dispose();
    return byteData!.buffer.asUint8List();
  }
}
