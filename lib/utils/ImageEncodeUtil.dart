import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// 图片编码工具类
/// 提供 PNG ↔ JPEG 转码、文件大小预估等功能
class ImageEncodeUtil {
  /// 根据 JPEG 质量计算缩放因子。
  ///
  /// JPEG 对 UI 截图（纯色块 + 文字）压缩效率有限，
  /// 通过降分辨率来真正减小文件体积：缩放因子 s 会让像素数减少 s²。
  /// - quality 95 → 85% 宽度（72% 像素）
  /// - quality 85 → 65% 宽度（42% 像素）
  /// - quality 70 → 50% 宽度（25% 像素）
  static double _scaleForQuality(int quality) {
    if (quality >= 95) return 0.85;
    if (quality >= 90) return 0.75;
    if (quality >= 85) return 0.65;
    if (quality >= 80) return 0.58;
    if (quality >= 70) return 0.50;
    return 0.42;
  }

  /// 将 PNG 字节转为 JPEG 字节，并根据质量自动缩放以减小文件体积。
  /// [pngBytes] 原始 PNG 数据
  /// [quality] JPEG 质量 (0-100)，同时决定缩放程度
  static Uint8List pngToJpeg(Uint8List pngBytes, {required int quality}) {
    final decoded = img.decodePng(pngBytes);
    if (decoded == null) {
      throw Exception('无法解码 PNG 数据');
    }

    // 根据质量缩放图片，这是减小 UI 截图文件体积的关键手段
    final scale = _scaleForQuality(quality);
    final targetWidth = (decoded.width * scale).round();
    final resized = img.copyResize(decoded, width: targetWidth);

    final jpegBytes = img.encodeJpg(resized, quality: quality);
    return Uint8List.fromList(jpegBytes);
  }

  /// 根据 PNG 预估大小和 JPEG quality 估算 JPEG 文件大小。
  ///
  /// 估算同时考虑两个因素：
  /// 1. **缩放**：降分辨率使像素数减少 scale²
  /// 2. **JPEG 编码**：在缩放后的基础上进一步压缩
  ///
  /// [pngSize] 是 [estimatePngSize] 的返回值（已含 PNG 压缩比 ~18% of raw）
  static int estimateJpegSize(int pngSize, int quality) {
    final scale = _scaleForQuality(quality);
    // 面积随线性缩放平方减少
    final scaleFactor = scale * scale;

    // JPEG 编码在缩放后基础上的进一步压缩比
    double jpegRatio;
    if (quality >= 95) {
      jpegRatio = 0.70;
    } else if (quality >= 90) {
      jpegRatio = 0.60;
    } else if (quality >= 85) {
      jpegRatio = 0.50;
    } else if (quality >= 80) {
      jpegRatio = 0.48;
    } else if (quality >= 70) {
      jpegRatio = 0.42;
    } else {
      jpegRatio = 0.38;
    }
    return (pngSize * scaleFactor * jpegRatio).round();
  }

  /// 根据数据条目数和渲染参数预估 PNG 文件大小
  ///
  /// 基于实际渲染参数计算：
  /// - 容器宽度: 1200 逻辑像素
  /// - 默认 pixelRatio: 3.0（与导出代码 toImage(pixelRatio: 3.0) 一致）
  /// - 物理宽度 = 1200 × pixelRatio = 3600px
  /// - 5 列布局卡片较大（含曲绘），每卡约 240×240 逻辑 px → 720×720 物理 px
  /// - 12 列布局卡片较小（纯文字），每卡约 100×60 逻辑 px → 300×180 物理 px
  /// - PNG 对 UI 混合内容（纯色+文字+曲绘）的压缩比约 18%
  ///
  /// [songCount] 歌曲/数据条目数量
  /// [hasHeader] 是否有标题/评分区域
  /// [hasUserInfo] 是否有用户信息区域
  /// [cardsPerRow] 每行卡片数（默认5列B50布局，牌子/成绩页为12列）
  /// [pixelRatio] 设备像素比（默认3.0，与导出代码 toImage(pixelRatio: 3.0) 一致）
  static int estimatePngSize({
    required int songCount,
    bool hasHeader = true,
    bool hasUserInfo = true,
    double cardsPerRow = 5,
    double pixelRatio = 3.0,
  }) {
    const double containerWidth = 1200.0; // 导出容器固定宽度
    const double pngCompressionRatio = 0.18; // PNG 对 UI 混合内容的典型压缩比

    final physicalWidth = containerWidth * pixelRatio;

    // 每张卡片的物理像素尺寸
    final cardPhysicalWidth = physicalWidth / cardsPerRow;
    // 卡片宽高比：单列详情页较高，多列卡片依布局而定
    // 12列曲绘网格为正方形(childAspectRatio:1.0)，5列列表含曲绘约0.85
    final cardAspectRatio = cardsPerRow <= 1 ? 1.5 : (cardsPerRow <= 5 ? 0.85 : 1.0);
    final cardPhysicalHeight = cardPhysicalWidth * cardAspectRatio;
    // 单卡原始 RGBA 字节数
    final rawBytesPerCard = (cardPhysicalWidth * cardPhysicalHeight * 4).round();
    // 单卡 PNG 压缩后字节数
    final pngBytesPerCard = (rawBytesPerCard * pngCompressionRatio).round();

    // 基础开销：顶部/底部 padding + 背景（约 80 逻辑 px 高）
    final baseHeight = 80 * pixelRatio;
    final baseBytes = (physicalWidth * baseHeight * 4 * pngCompressionRatio).round();

    // Header 区域（标题 + 评分统计，约 350 逻辑 px 高）
    int headerBytes = 0;
    if (hasHeader) {
      final headerHeight = 350 * pixelRatio;
      headerBytes = (physicalWidth * headerHeight * 4 * pngCompressionRatio).round();
    }

    // 用户信息区域（头像 + 昵称 + 元信息，约 80 逻辑 px 高）
    int userInfoBytes = 0;
    if (hasUserInfo) {
      final userInfoHeight = 80 * pixelRatio;
      userInfoBytes = (physicalWidth * userInfoHeight * 4 * pngCompressionRatio).round();
    }

    // 行间距（每行约 12 逻辑 px 的间距）
    final rows = (songCount / cardsPerRow).ceil();
    final rowSpacingHeight = 12 * pixelRatio;
    final spacingBytes = rows * (physicalWidth * rowSpacingHeight * 4 * pngCompressionRatio).round();

    return baseBytes + headerBytes + userInfoBytes + spacingBytes + (songCount * pngBytesPerCard);
  }

  /// 格式化文件大小为可读字符串
  /// 例如：1024 → "1.00 KB", 1048576 → "1.00 MB"
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
  }
}
