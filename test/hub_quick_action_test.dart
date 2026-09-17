import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_flutter_app/page/HubComponents.dart';

/// 首页「快捷入口」四个小按钮的回归测试。
///
/// 两个曾经的问题：
///   1. 上下滑动（Android 的拉伸回弹 `StretchingOverscrollIndicator`）时
///      **只有文字被拉伸、按钮不动**：底色/描边原来画在 `Ink` 上，
///      而 `Ink` 是交给最近的 Material（滚动页里就是 Scaffold 那层）的 ink 层画的，
///      那一层在 Scrollable 的滚动/拉伸变换之外。改成自带一层 [Material]。
///   2. `Best50` 的副标题「Rating 构成」在窄屏每格只有 ~40dp 可用宽度，
///      直接被压成省略号。
void main() {
  /// 按首页「快捷入口」的真实布局渲染四个按钮。
  ///
  /// 默认 320dp 是最紧的情况；注意测试环境用的是等宽方块字体
  /// （每个字形都占满 fontSize），所以「Best50」这种 6 字符的拉丁标题
  /// 在窄屏下必然超宽 —— 标题的排版要在宽视口下单独验证。
  Future<void> pumpQuickActions(
    WidgetTester tester, {
    double width = 320,
    void Function(String title)? onTap,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const items = [
      (Icons.score_outlined, '查成绩', '游玩记录'),
      (Icons.leaderboard_outlined, 'Best50', '评分构成'),
      (Icons.search, '查歌曲', '曲库搜索'),
      (Icons.today_outlined, '每日推荐', '今日选曲'),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              for (final (icon, title, subtitle) in items) ...[
                Expanded(
                  child: HubQuickAction(
                    icon: icon,
                    title: title,
                    subtitle: subtitle,
                    onTap: () => onTap?.call(title),
                  ),
                ),
                if (title != '每日推荐') const SizedBox(width: 12),
              ],
            ],
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets('底色/描边画在自己的 Material 上（不再交给祖先 ink 层）',
      (tester) async {
    await pumpQuickActions(tester);

    // 关键：不用 Ink（Ink 的 decoration 画在祖先 Material 的 ink 层，
    // 那一层在滚动/拉伸变换之外 —— 就是「文字被拉伸、按钮不动」的根因）
    expect(find.byType(Ink), findsNothing);

    final materials = tester.widgetList<Material>(find.descendant(
      of: find.byType(HubQuickAction),
      matching: find.byType(Material),
    ));
    expect(materials, isNotEmpty);
    final card = materials.firstWhere(
      (m) => m.shape is RoundedRectangleBorder,
      orElse: () => throw StateError('按钮底色应画在自带的 Material 上'),
    );
    final shape = card.shape! as RoundedRectangleBorder;
    expect(shape.side.color, isNot(Colors.transparent), reason: '描边也要跟着一起动');
    expect(card.clipBehavior, Clip.antiAlias, reason: '水波纹裁在圆角内');
  });

  testWidgets('320dp 窄屏下四个副标题都不被省略', (tester) async {
    await pumpQuickActions(tester, width: 320);

    for (final subtitle in ['游玩记录', '评分构成', '曲库搜索', '今日选曲']) {
      final paragraph =
          tester.renderObject<RenderParagraph>(find.text(subtitle));
      expect(paragraph.didExceedMaxLines, isFalse,
          reason: '「$subtitle」在窄屏被压成省略号了，副标题要统一四个字');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('标题不被省略 + 点击回调正常', (tester) async {
    String? tapped;
    // 宽视口：测试环境用的是等宽方块字体（每个字形都占满 fontSize），
    // 6 个字符的「Best50」在窄屏必然超宽，这里只验证标题本身能完整排版 + 回调
    await pumpQuickActions(tester, width: 600, onTap: (t) => tapped = t);

    for (final title in ['查成绩', 'Best50', '查歌曲', '每日推荐']) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(title));
      expect(paragraph.didExceedMaxLines, isFalse, reason: '「$title」被省略号截断了');
    }

    await tester.tap(find.text('Best50'));
    await tester.pump();
    expect(tapped, 'Best50');
  });
}
