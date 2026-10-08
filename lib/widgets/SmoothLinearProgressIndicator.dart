import 'package:flutter/material.dart';

/// 让离散进度回调之间的数值连续过渡，避免进度条突然跳跃。
class SmoothLinearProgressIndicator extends StatelessWidget {
  final double? value;
  final Color? color;
  final Animation<Color?>? valueColor;
  final Color? backgroundColor;
  final double minHeight;
  final BorderRadiusGeometry? borderRadius;
  final bool animate;

  const SmoothLinearProgressIndicator(
      {super.key,
      this.value,
      this.color,
      this.valueColor,
      this.backgroundColor,
      this.minHeight = 4,
      this.borderRadius,
      this.animate = true});

  @override
  Widget build(BuildContext context) {
    final target = value;
    // `value == null` 是「不确定进度」（那条来回跑、不知道百分比的）。
    // ⚠️ 这种情况**必须**直接交给原生指示器：`TweenAnimationBuilder` 明确要求
    // `tween.end` 非空，喂 null 会直接断言崩 —— 「同步成绩 → 正在检查 AWMC 网关」
    // 那个阶段没有百分比，就是这么崩的（见 HubComponents 里传的
    // `progressValue?.clamp(...)`）。
    if (!animate || target == null) {
      return LinearProgressIndicator(
        value: target,
        color: color,
        valueColor: valueColor,
        backgroundColor: backgroundColor,
        minHeight: minHeight,
        borderRadius: borderRadius ?? BorderRadius.circular(minHeight),
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: target, end: target),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      builder: (context, animated, _) => LinearProgressIndicator(
        value: animated,
        color: color,
        valueColor: valueColor,
        backgroundColor: backgroundColor,
        minHeight: minHeight,
        borderRadius: borderRadius ?? BorderRadius.circular(minHeight),
      ),
    );
  }
}
