import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 纯矢量鱼形图标（不用字体/字符，24×24 设计稿按 [size] 等比缩放）。
///
/// Material Icons 里没有 `Icons.fish`，最接近的 `set_meal` 是「鱼+盘子」，
/// 所以这里用 CustomPainter 画一条侧视鱼：椭圆身体 + 三角尾 + 抠出眼睛。
class FishIcon extends StatelessWidget {
  final double size;
  final Color color;

  const FishIcon({super.key, this.size = 24, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _FishPainter(color)),
    );
  }
}

class _FishPainter extends CustomPainter {
  final Color color;

  _FishPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / 24.0;
    canvas.scale(s, s);

    // 身体：右侧为鱼头，左侧收拢接尾
    final body = Path()
      ..moveTo(22.0, 12.0)
      ..cubicTo(18.0, 5.2, 10.0, 5.2, 6.2, 12.0)
      ..cubicTo(10.0, 18.8, 18.0, 18.8, 22.0, 12.0)
      ..close();

    // 尾巴
    final tail = Path()
      ..moveTo(6.6, 12.0)
      ..lineTo(2.0, 7.0)
      ..lineTo(2.0, 17.0)
      ..close();

    // 眼睛：从身体里抠出一个圆
    final eye = Path()
      ..addOval(Rect.fromCircle(
        center: const Offset(17.6, 10.6),
        radius: 1.3,
      ));

    final fish = Path.combine(ui.PathOperation.union, body, tail);
    final withEye = Path.combine(ui.PathOperation.difference, fish, eye);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawPath(withEye, paint);
  }

  @override
  bool shouldRepaint(covariant _FishPainter oldDelegate) =>
      oldDelegate.color != color;
}
