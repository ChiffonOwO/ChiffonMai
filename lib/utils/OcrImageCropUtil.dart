import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;

/// 裁剪页的图片处理放到后台 isolate，避免大图解码、裁剪和 JPEG 编码冻结 UI。
class OcrImageCropUtil {
  const OcrImageCropUtil._();

  static Future<Uint8List?> cropAndEncodeAsync({
    required Uint8List bytes,
    required double left,
    required double top,
    required double width,
    required double height,
    int quality = 92,
    int maxOutputDimension = 2560,
  }) {
    return compute(_cropAndEncodeWorker, <String, dynamic>{
      'bytes': bytes,
      'left': left,
      'top': top,
      'width': width,
      'height': height,
      'quality': quality,
      'maxOutputDimension': maxOutputDimension,
    });
  }
}

Uint8List? _cropAndEncodeWorker(Map<String, dynamic> args) {
  final decoded = img.decodeImage(args['bytes'] as Uint8List);
  if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
    return null;
  }

  double finiteOr(double value, double fallback) =>
      value.isFinite ? value : fallback;
  final left = finiteOr(args['left'] as double, 0).clamp(0.0, 1.0).toDouble();
  final top = finiteOr(args['top'] as double, 0).clamp(0.0, 1.0).toDouble();
  final width = finiteOr(args['width'] as double, 1).clamp(0.0, 1.0).toDouble();
  final height =
      finiteOr(args['height'] as double, 1).clamp(0.0, 1.0).toDouble();

  final x = (left * decoded.width).round().clamp(0, decoded.width - 1);
  final y = (top * decoded.height).round().clamp(0, decoded.height - 1);
  final maxWidth = decoded.width - x;
  final maxHeight = decoded.height - y;
  final cropWidth = (width * decoded.width).round().clamp(1, maxWidth);
  final cropHeight = (height * decoded.height).round().clamp(1, maxHeight);

  var cropped = img.copyCrop(
    decoded,
    x: x,
    y: y,
    width: cropWidth,
    height: cropHeight,
  );
  final maxDimension = args['maxOutputDimension'] as int;
  if (maxDimension > 0 &&
      math.max(cropped.width, cropped.height) > maxDimension) {
    cropped = img.copyResize(
      cropped,
      width: cropped.width >= cropped.height ? maxDimension : null,
      height: cropped.height > cropped.width ? maxDimension : null,
    );
  }

  return Uint8List.fromList(
    img.encodeJpg(cropped, quality: args['quality'] as int),
  );
}
