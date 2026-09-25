import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;

/// GPU 单边纹理尺寸的安全上限。
///
/// 各机型实际值常见为 4096 / 8192 / 16384，取 16000 是在 16384 上留余量。
/// 超过它的 `toImage` 会给出**空白/黑图**，正是「导出图片黑屏」的成因。
const double kMaxCaptureTextureSize = 16000.0;

/// 允许压到的最小 pixelRatio。
///
/// **不是 1.0**：如果下限取 1.0，那张「逻辑高度本身就超过上限」的图会被
/// clamp 顶回超限值，保护等于失效（原来的三份内联实现都是这个毛病）。
/// 宁可出一张略缩的图，也不要黑屏。实际导出（宽 1200/1700、高几千）远够不到
/// 这个下限，只有病态尺寸才会碰到。
const double kMinCapturePixelRatio = 0.5;

/// [compute] 的 worker。**必须是顶层函数**（闭包不能跨 isolate 传递）。
Uint8List _pngToJpegWorker(Map<String, dynamic> args) {
  return ImageEncodeUtil.pngToJpeg(
    args['bytes'] as Uint8List,
    quality: args['quality'] as int,
  );
}

/// 图片编码工具类
/// 提供 PNG ↔ JPEG 转码、文件大小预估等功能
class ImageEncodeUtil {
  /// 把 [pngToJpeg] 挪到后台 isolate 执行。
  ///
  /// 为什么必须挪：`package:image` 的 `decodePng` / `copyResize` / `encodeJpg`
  /// 都是**纯 Dart 同步**实现。B50 导出图约 3600×7400（≈27 MP），三个步骤
  /// 串起来要十几秒，全跑在 UI isolate 上就是**界面完全冻住** ——
  /// 用户报的「导出卡死」就是它（只有选了 JPEG 的用户会中，所以他们
  /// 反馈两极分化）。输入输出都是 `Uint8List`，可以安全跨 isolate 传递。
  static Future<Uint8List> pngToJpegAsync(
    Uint8List pngBytes, {
    required int quality,
  }) {
    return compute(_pngToJpegWorker, <String, dynamic>{
      'bytes': pngBytes,
      'quality': quality,
    });
  }

  /// 导出截图该用的 pixelRatio：优先 [preferred]，但**保证物理尺寸不超过
  /// [kMaxCaptureTextureSize]**。
  ///
  /// 为什么必须有这道闸：B50 导出图很高（50 行，约 3600×7400 @3.0），
  /// 物理边长一旦超过机型 GPU 的最大纹理尺寸，`toImage` 就会返回**空白/黑图**
  /// —— 这就是「部分用户导出黑屏」；而同一次分配的位图可达上百 MB，
  /// 又会把 App 拖死。机型越差越容易中，所以表现为「有人有问题有人没有」。
  ///
  /// 已经有 3 个导出服务（PaiziProgress / SongInfo / PersonalizedScore）
  /// 各自内联过同一段逻辑，这里收成一份，别再抄第 7 份。
  static double safeCapturePixelRatio(
    double width,
    double height, {
    double preferred = 3.0,
  }) {
    if (width <= 0 || height <= 0) return preferred;
    var ratio = preferred;
    if (width * ratio > kMaxCaptureTextureSize) {
      ratio = kMaxCaptureTextureSize / width;
    }
    if (height * ratio > kMaxCaptureTextureSize) {
      ratio = kMaxCaptureTextureSize / height;
    }
    // 下限刻意低于 1.0：见 [kMinCapturePixelRatio] 的注释
    return ratio.clamp(kMinCapturePixelRatio, preferred);
  }

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
