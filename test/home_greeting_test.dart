import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_flutter_app/page/HomePage.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';

/// 首页页头「欢迎回来，xxx」的排版回归。
///
/// 起因（真机反馈）：昵称一长，这一行就换行，把下面的仪表盘整体顶下去。
/// 根因是**宽度不够**而不是「文字太多」：360dp 屏上页头只有约 272px
/// （左右各 20px 页边距 + 右侧主题按钮 48px），24px 的「欢迎回来，」就占掉 120px
/// —— 实测 8 字昵称（机台昵称上限）正好排成两行。
///
/// 现在的做法：**整行同字号**，放不下就整行等比缩小（下限 [HomeGreetingText.minFontSize]），
/// 再放不下才省略号。这里钉住：
///   1. 昵称不长时字号**和以前完全一样**（不要为了塞得下就把问候语做小）；
///   2. 长昵称只缩不换行；
///   3. 页头高度恒定（换行/缩字都不该顶到下面的仪表盘）。
void main() {
  /// 复刻首页页头的宽度约束：页边距 20 + 右侧主题按钮 48。
  Widget header(String nickname, {double scale = 1.0}) => MaterialApp(
        theme: AppTheme.lightTheme(),
        builder: (ctx, child) => MediaQuery(
          data:
              MediaQuery.of(ctx).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
              child: Row(
                children: [
                  Expanded(child: HomeGreetingText(nickname: nickname)),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.brightness_6_outlined),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  /// ⚠️ 必须限定在这个组件内部找：Scaffold / IconButton 那边也有 RichText。
  Finder richTextFinder() => find.descendant(
        of: find.byType(HomeGreetingText),
        matching: find.byType(RichText),
      );

  RenderParagraph paragraphOf(WidgetTester tester) =>
      tester.renderObject<RenderParagraph>(richTextFinder());

  /// 实际渲染用的字号（从段落里取，避免只验证了 widget 上的配置）。
  double fontSizeOf(WidgetTester tester) {
    final rich = tester.widget<RichText>(richTextFinder());
    final span = rich.text as TextSpan;
    final spanSize = span.style?.fontSize;
    if (spanSize != null) return spanSize;
    final child = span.children!.single as TextSpan;
    return child.style!.fontSize!;
  }

  double baseFontSize(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(HomeGreetingText)))
          .textTheme
          .headlineSmall!
          .fontSize!;

  testWidgets('短昵称：字号和以前一模一样（没有被做小）', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // ⚠️ 测试环境里每个字形都是 1em 宽的方块（Ahem），拉丁字母不会比汉字窄。
    // 所以这里必须挑一个**在测试字体下**也放得下的昵称，才谈得上「没被缩小」。
    await tester.pumpWidget(header('短名'));
    await tester.pump();

    expect(fontSizeOf(tester), baseFontSize(tester),
        reason: '放得下就必须用原字号 —— 问候语和昵称同字号是这次的硬要求');
  });

  testWidgets('360dp + 8 字机台昵称：单行、不截断，只是整行略缩', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // maimai 机台昵称最长 8 个字，这是最坏情况
    await tester.pumpWidget(header('ＣｈｉＦＦｏＮ'));
    await tester.pump();

    final para = paragraphOf(tester);
    expect(para.didExceedMaxLines, isFalse,
        reason: '8 字昵称必须完整显示（一个字都不能截）');
    expect(fontSizeOf(tester), lessThanOrEqualTo(baseFontSize(tester)));
    expect(fontSizeOf(tester), greaterThanOrEqualTo(HomeGreetingText.minFontSize),
        reason: '缩也要有个下限');
    expect(tester.takeException(), isNull, reason: '不该有 RenderFlex 溢出');
  });

  testWidgets('超长昵称：缩到下限后用省略号，绝不换行', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(header('这是一个特别特别特别长的昵称不该换行'));
    await tester.pump();

    final para = paragraphOf(tester);
    expect(fontSizeOf(tester), HomeGreetingText.minFontSize);
    expect(para.didExceedMaxLines, isTrue, reason: '放到下限还放不下就用省略号收尾');
    expect(tester.takeException(), isNull);
  });

  testWidgets('页头高度恒定：短名 / 8 字 / 超长名都不变', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final heights = <double>[];
    for (final name in ['短名', 'ＣｈｉＦＦｏＮ', '这是一个特别特别特别长的昵称']) {
      await tester.pumpWidget(header(name));
      await tester.pump();
      heights.add(tester.getSize(find.byType(HomeGreetingText)).height);
    }

    expect(heights[0], greaterThan(0));
    for (final h in heights) {
      expect(h, closeTo(heights[0], 0.5),
          reason: '页头高度必须恒定，否则昵称长短会顶到下面的仪表盘（$heights）');
    }
  });

  testWidgets('大字体（1.5x）下同样只有一行', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(header('短名', scale: 1.5));
    await tester.pump();
    // 量控件本身（预留的行高），不是段落：段落高度会跟着缩小的字号变
    final oneLine = tester.getSize(find.byType(HomeGreetingText)).height;

    await tester.pumpWidget(header('这是一个特别特别特别长的昵称', scale: 1.5));
    await tester.pump();
    expect(tester.getSize(find.byType(HomeGreetingText)).height,
        closeTo(oneLine, 0.5),
        reason: '系统字体调大后依然不能换行');
    expect(tester.takeException(), isNull);
  });

  testWidgets('没登录时显示「请登录水鱼账号」', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(header(''));
    await tester.pump();

    expect(find.textContaining('请登录水鱼账号'), findsOneWidget);
    expect(find.textContaining('欢迎回来'), findsNothing);
  });
}
