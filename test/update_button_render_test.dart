// 「检查更新 → 发现新版本」按钮的渲染测试。
//
// 这里刻意**不渲染整个 SystemHubPage** —— 那个页面在 initState 里会去拉收藏品、
// 读缓存、起同步统计轮询，widget 测试里全是网络副作用。所以只测真正变化的部分：
// HubActionTile 在两种更新状态下的文案、颜色与图标。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_flutter_app/page/HubComponents.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:my_first_flutter_app/utils/UpdateNotifier.dart';

/// 按 SystemHubPage 里的写法渲染那个按钮。
Widget _tile(UpdateAvailability? update, {VoidCallback? onTap}) {
  if (update == null) {
    return HubActionTile(
      title: UpdateNotifier.idleTitle,
      subtitle: UpdateNotifier.idleSubtitle,
      icon: Icons.system_update_alt_outlined,
      isFavorited: false,
      onToggleFavorite: () {},
      onTap: onTap ?? () {},
    );
  }
  return HubActionTile(
    title: UpdateNotifier.titleFor(update),
    subtitle:
        UpdateNotifier.subtitleFor(update, UpdateNotifier.idleSubtitle),
    icon: Icons.arrow_upward_rounded,
    titleColor: UpdateAvailableIcon.green,
    leading: const UpdateAvailableIcon(),
    isFavorited: false,
    onToggleFavorite: () {},
    onTap: onTap ?? () {},
  );
}

Future<void> _pump(WidgetTester tester, Widget child, {bool dark = false}) async {
  await tester.pumpWidget(MaterialApp(
    theme: dark ? AppTheme.darkTheme() : AppTheme.lightTheme(),
    home: Scaffold(body: child),
  ));
  await tester.pumpAndSettle();
}

UpdateAvailability _available() => const UpdateAvailability(
      latestVersion: '2.2.0',
      latestBuild: 2038,
      updateLog: '更新内容',
    );

void main() {
  testWidgets('无更新时是「检查更新」+ 系统更新图标，没有绿色箭头', (tester) async {
    await _pump(tester, _tile(null));

    expect(find.text('检查更新'), findsOneWidget);
    expect(find.text('检查应用是否有新版本'), findsOneWidget);
    expect(find.text('发现新版本'), findsNothing);
    expect(find.byType(UpdateAvailableIcon), findsNothing);
    final icon = tester.widget<Icon>(find.byIcon(Icons.system_update_alt_outlined));
    expect(icon.color, isNot(UpdateAvailableIcon.green));
  });

  testWidgets('有更新时变成「发现新版本」+ 绿色圆环箭头', (tester) async {
    await _pump(tester, _tile(_available()));

    expect(find.text('发现新版本'), findsOneWidget);
    expect(find.text('检查更新'), findsNothing);
    expect(find.textContaining('v2.2.0'), findsOneWidget);

    // 绿色圆环箭头（自绘组件）必须出现
    expect(find.byType(UpdateAvailableIcon), findsOneWidget);
    // 箭头是向上的
    expect(
      find.descendant(
        of: find.byType(UpdateAvailableIcon),
        matching: find.byIcon(Icons.arrow_upward_rounded),
      ),
      findsOneWidget,
    );
    // 且真的是绿色
    final arrow = tester.widget<Icon>(
      find.descendant(
        of: find.byType(UpdateAvailableIcon),
        matching: find.byIcon(Icons.arrow_upward_rounded),
      ),
    );
    expect(arrow.color, UpdateAvailableIcon.green);

    // 标题也染成绿色（和图标呼应）
    final title = tester.widget<Text>(find.text('发现新版本'));
    expect(title.style?.color, UpdateAvailableIcon.green);
  });

  testWidgets('两种状态下点击行为都还在（需求：点击逻辑不变）', (tester) async {
    var taps = 0;
    await _pump(tester, _tile(null, onTap: () => taps++));
    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();
    expect(taps, 1);

    await _pump(tester, _tile(_available(), onTap: () => taps++));
    await tester.tap(find.text('发现新版本'));
    await tester.pumpAndSettle();
    expect(taps, 2);
  });

  testWidgets('深色主题下同样是绿色（不跟随主题色）', (tester) async {
    await _pump(tester, _tile(_available()), dark: true);
    final arrow = tester.widget<Icon>(
      find.descendant(
        of: find.byType(UpdateAvailableIcon),
        matching: find.byIcon(Icons.arrow_upward_rounded),
      ),
    );
    expect(arrow.color, UpdateAvailableIcon.green);
  });

  testWidgets('绿色是对比度足够的状态色（浅底/深底都能看清）', (tester) async {
    // 这条断言的意义：绿色是写死的，不跟随用户自定义主题色。
    // 如果以后有人把它改成 scheme.primary，「发现新版本」就不再是绿色的了。
    expect(UpdateAvailableIcon.green, const Color(0xFF1B9E4B));
    final luminance = UpdateAvailableIcon.green.computeLuminance();
    // 对浅色底（白 1.0）对比度 ≈ 3.4，对深色底（黑 0.0）≈ 6.2
    final contrastOnWhite = (1.0 + 0.05) / (luminance + 0.05);
    final contrastOnBlack = (luminance + 0.05) / (0.0 + 0.05);
    expect(contrastOnWhite, greaterThan(3.0));
    expect(contrastOnBlack, greaterThan(3.0));
  });
}
