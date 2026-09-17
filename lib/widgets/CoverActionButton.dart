import 'package:flutter/material.dart';

/// 曲绘识别页那一排操作按钮（开始识别 / 重新识别 / 重新裁剪 / 重选 / 再选一张）。
///
/// 为什么单独抽成组件：配色踩过坑 ——
/// 底色用的是页面的强调色 `accent`（= `colorScheme.onSurface`，
/// 深色模式下是**近白色**），文字却写死 `Colors.white`，
/// 于是深色模式下「开始识别 / 重新识别」成了**白底白字**，完全看不清
/// （浅色模式下 onSurface 是黑色，白字正常，所以一直没被发现）。
///
/// 现在：
///   * primary：底色 = [accent]，前景 = `colorScheme.surface`
///     （onSurface 与 surface 是天然成对的一对，明暗两种模式都必然有对比度，
///     效果就是「浅色模式黑底白字 / 深色模式白底黑字」的反色主按钮）；
///   * 次要：底色 = `colorScheme.surface`，前景 = [accent]；
///   * 转圈（[loading]）的颜色与前景一致，不再写死白色。
///
/// `test/cover_action_button_test.dart` 用 WCAG 对比度（≥ 4.5:1）把这件事钉住了。
class CoverActionButton extends StatelessWidget {
  /// 图标（[loading] 时换成转圈）。
  final IconData icon;

  /// 按钮文字。
  final String label;

  /// 点击回调；null = 禁用（如「识别中...」）。
  final VoidCallback? onPressed;

  /// 是否是主按钮（反色实心）；false = 描边次要按钮。
  final bool primary;

  /// 是否显示转圈（用于「识别中...」）。
  final bool loading;

  /// 页面强调色（通常传 `Theme.of(context).colorScheme.onSurface`）。
  final Color accent;

  /// 尺寸基准（页面里的 `sw`），用于按屏宽缩放字号 / 内边距。
  final double scale;

  const CoverActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.accent,
    required this.scale,
    this.primary = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // ⚠️ 前景必须是 accent 的「反色」：accent 是 onSurface，所以用它配套的 surface。
    // 曾经这里写死 Colors.white → 深色模式白底白字。
    final background = primary ? accent : scheme.surface;
    final foreground = primary ? scheme.surface : accent;

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: loading && onPressed == null
          ? SizedBox(
              width: scale * 0.035,
              height: scale * 0.035,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: foreground,
              ),
            )
          : Icon(icon, size: scale * 0.042),
      label: Text(label, style: TextStyle(fontSize: scale * 0.032)),
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        padding: EdgeInsets.symmetric(
            horizontal: scale * 0.05, vertical: scale * 0.028),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: primary ? accent : accent.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        elevation: primary ? 2 : 0,
      ),
    );
  }
}
