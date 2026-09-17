import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:my_first_flutter_app/widgets/CoverActionButton.dart';

/// 曲绘识别页操作按钮的配色测试。
///
/// 真实 bug：「开始识别 / 重新识别」在深色模式下**白底白字**，完全看不清 ——
/// 底色取的是页面强调色 `colorScheme.onSurface`（深色模式下近白），
/// 文字却写死 `Colors.white`。浅色模式下 onSurface 是黑色，白字正常，
/// 所以这个 bug 只在深色模式暴露。
///
/// 这里不靠「肉眼觉得行」，而是直接算 **WCAG 对比度**，四种主题各测一遍：
/// 正文级对比度要求 ≥ 4.5:1。
void main() {
  /// 相对亮度（WCAG 2.x）：Color.r/g/b 在 Flutter 里是 0~1 的 double。
  double luminance(Color c) {
    double channel(double v) =>
        v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * channel(c.r) +
        0.7152 * channel(c.g) +
        0.0722 * channel(c.b);
  }

  double contrastRatio(Color a, Color b) {
    final la = luminance(a);
    final lb = luminance(b);
    final hi = math.max(la, lb);
    final lo = math.min(la, lb);
    return (hi + 0.05) / (lo + 0.05);
  }

  /// 渲染一个按钮并取回 (底色, 前景色)
  Future<({Color background, Color foreground, Color spinner})> render(
    WidgetTester tester,
    ThemeData theme, {
    required bool primary,
    bool loading = false,
  }) async {
    final scheme = theme.colorScheme;
    await tester.pumpWidget(MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Builder(
          builder: (context) => CoverActionButton(
            icon: Icons.search,
            label: loading ? '识别中...' : '开始识别',
            onPressed: loading ? null : () {},
            // 页面里传的就是 onSurface
            accent: scheme.onSurface,
            scale: 360,
            primary: primary,
            loading: loading,
          ),
        ),
      ),
    ));
    await tester.pump();

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    final style = button.style!;
    final background = style.backgroundColor!.resolve({});
    final foreground = style.foregroundColor!.resolve({})!;
    Color spinner = foreground;
    if (loading) {
      spinner = tester
          .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator))
          .color!;
    }
    return (background: background!, foreground: foreground, spinner: spinner);
  }

  final themes = <String, ThemeData>{
    '浅色': AppTheme.lightTheme(),
    '深色': AppTheme.darkTheme(),
    '纯黑': AppTheme.pureBlackTheme(),
  };

  for (final entry in themes.entries) {
    final name = entry.key;
    final theme = entry.value;

    testWidgets('$name 模式：主按钮（开始识别 / 重新识别）文字看得清', (tester) async {
      final r = await render(tester, theme, primary: true);

      // 深色模式的底色就是 onSurface（近白），前景必须是 surface（深色）——
      // 这正是原来写死 Colors.white 的地方
      expect(r.background, theme.colorScheme.onSurface);
      expect(r.foreground, theme.colorScheme.surface);
      expect(contrastRatio(r.background, r.foreground), greaterThanOrEqualTo(4.5),
          reason: '$name：主按钮对比度不足（${r.background} / ${r.foreground}）');
    });

    testWidgets('$name 模式：次要按钮文字看得清', (tester) async {
      final r = await render(tester, theme, primary: false);

      expect(r.background, theme.colorScheme.surface);
      expect(r.foreground, theme.colorScheme.onSurface);
      expect(contrastRatio(r.background, r.foreground), greaterThanOrEqualTo(4.5),
          reason: '$name：次要按钮对比度不足');
    });

    testWidgets('$name 模式：转圈颜色 = 前景色（原来写死白色）', (tester) async {
      final r = await render(tester, theme, primary: true, loading: true);
      expect(r.spinner, r.foreground);
      expect(contrastRatio(r.background, r.spinner), greaterThanOrEqualTo(4.5),
          reason: '$name：「识别中...」的转圈在底色上看不见');
    });
  }
}
