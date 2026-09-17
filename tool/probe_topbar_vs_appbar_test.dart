// ===========================================================================
// 「手写的 PageTopBar」 vs 「标准 Material AppBar」逐项量化对比
//
// 用途：把两者的差别用**数字**说清楚（不靠肉眼），必要时可以照着补差距。
//   * 高度 / 状态栏处理      → tester.view.padding 模拟 32dp 状态栏
//   * 标题位置（居中/夹紧）  → 长标题 + 两个 action 时会不会压到按钮
//   * 无障碍语义            → SemanticsFlag.isHeader
//   * 标题样式 / 底色        → 直接读 TextStyle / BoxDecoration
//
// 用法：flutter test tool/probe_topbar_vs_appbar_test.dart
// tool/ 不在 analyzer 的测试目录白名单里，这条 lint 在这里是误报：
// ignore_for_file: avoid_print
// ===========================================================================
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsFlag;
import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:my_first_flutter_app/widgets/PageTopBar.dart';

/// 模拟一台「状态栏 32dp」的手机（AppBar 会自己让开，手写组件不会）
const double kStatusBar = 32;

void setPhone(WidgetTester tester, {double statusBar = kStatusBar}) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  tester.view.padding = FakeViewPadding(top: statusBar * 3);
  tester.view.viewPadding = FakeViewPadding(top: statusBar * 3);
  addTearDown(tester.view.reset);
}

Widget appBarHost({
  required String title,
  List<Widget> actions = const [],
}) =>
    Scaffold(
      backgroundColor: AppColors.cardBackground(Brightness.dark),
      appBar: AppBar(
        title: Text(title),
        centerTitle: true, // Rating 排行榜页就是这么写的
        actions: actions,
      ),
      body: const SizedBox.expand(),
    );

Widget pageTopBarHost({
  required String title,
  List<Widget> actions = const [],
}) =>
    Scaffold(
      backgroundColor: AppColors.scaffoldBackground(Brightness.dark),
      body: Column(children: [
        PageTopBar(title: title, actions: actions),
        const Expanded(child: SizedBox.expand()),
      ]),
    );

IconButton refresh() =>
    IconButton(icon: const Icon(Icons.refresh), onPressed: () {});
IconButton search() =>
    IconButton(icon: const Icon(Icons.search), onPressed: () {});

Future<void> report(
  WidgetTester tester,
  String label,
  Widget host,
  String title,
) async {
  await tester.pumpWidget(MaterialApp(theme: AppTheme.darkTheme(), home: host));
  await tester.pumpAndSettle();

  final titleFinder = find.text(title);
  final titleRect = tester.getRect(titleFinder);
  final text = tester.widget<Text>(titleFinder);
  final screen = tester.getSize(find.byType(MaterialApp));

  print('[$label]');
  print('  视口        : ${screen.width} × ${screen.height}（状态栏 $kStatusBar）');
  print('  标题 rect   : left=${titleRect.left.toStringAsFixed(1)} '
      'top=${titleRect.top.toStringAsFixed(1)} '
      'w=${titleRect.width.toStringAsFixed(1)} '
      'h=${titleRect.height.toStringAsFixed(1)}');
  print('  标题中心 x  : ${(titleRect.left + titleRect.width / 2).toStringAsFixed(1)}'
      '（屏宽一半 = ${(screen.width / 2).toStringAsFixed(1)}）');
  print('  标题样式    : size=${text.style?.fontSize} weight=${text.style?.fontWeight} '
      'color=${text.style?.color}');
  if (find.byIcon(Icons.arrow_back).evaluate().isNotEmpty) {
    final back = tester.getRect(find.byIcon(Icons.arrow_back));
    print('  返回图标    : left=${back.left.toStringAsFixed(1)} '
        'top=${back.top.toStringAsFixed(1)} size=${back.width.toStringAsFixed(1)}');
  } else {
    print('  返回图标    : （无）');
  }
  for (final icon in [Icons.refresh, Icons.search]) {
    if (find.byIcon(icon).evaluate().isEmpty) continue;
    final r = tester.getRect(find.byIcon(icon));
    print('  $icon : left=${r.left.toStringAsFixed(1)} '
        'right=${r.right.toStringAsFixed(1)} top=${r.top.toStringAsFixed(1)}');
  }
  // 语义：是不是 header
  final node = tester.getSemantics(titleFinder);
  print('  语义 header : ${node.hasFlag(SemanticsFlag.isHeader)}');
  print('');
}

void main() {
  testWidgets('AppBar（基准）', (tester) async {
    setPhone(tester);
    await report(tester, 'AppBar', appBarHost(title: 'Rating 排行榜', actions: [refresh()]), 'Rating 排行榜');
  });

  testWidgets('PageTopBar（手写）', (tester) async {
    setPhone(tester);
    await report(tester, 'PageTopBar', pageTopBarHost(title: 'Rating 排行榜', actions: [refresh()]), 'Rating 排行榜');
  });

  testWidgets('长标题 + 两个 action：会不会压到按钮', (tester) async {
    setPhone(tester);
    const long = '这是一个非常非常长的页面标题用来测夹紧行为';

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme(),
      home: appBarHost(title: long, actions: [refresh(), search()]),
    ));
    await tester.pumpAndSettle();
    final appBarTitle = tester.getRect(find.text(long));
    final appBarFirstAction = tester.getRect(find.byIcon(Icons.refresh));
    print('[AppBar · 长标题 + 2 action]');
    print('  标题 right=${appBarTitle.right.toStringAsFixed(1)} '
        '第一个 action left=${appBarFirstAction.left.toStringAsFixed(1)} '
        '→ ${appBarTitle.right <= appBarFirstAction.left ? "不重叠 ✓" : "重叠 ✗"}');

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme(),
      home: pageTopBarHost(title: long, actions: [refresh(), search()]),
    ));
    await tester.pumpAndSettle();
    final myTitle = tester.getRect(find.text(long));
    final myFirstAction = tester.getRect(find.byIcon(Icons.refresh));
    print('[PageTopBar · 长标题 + 2 action]');
    print('  标题 right=${myTitle.right.toStringAsFixed(1)} '
        '第一个 action left=${myFirstAction.left.toStringAsFixed(1)} '
        '→ ${myTitle.right <= myFirstAction.left ? "不重叠 ✓" : "重叠 ✗"}');
  });

  testWidgets('有没有状态栏：AppBar 自适应，PageTopBar 不会', (tester) async {
    for (final statusBar in [0.0, kStatusBar]) {
      setPhone(tester, statusBar: statusBar);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme(),
        home: appBarHost(title: 'X', actions: [refresh()]),
      ));
      await tester.pumpAndSettle();
      final appBarIcon = tester.getRect(find.byIcon(Icons.refresh));
      print('[AppBar] 状态栏=$statusBar → 图标 top=${appBarIcon.top.toStringAsFixed(1)}');

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme(),
        home: pageTopBarHost(title: 'X', actions: [refresh()]),
      ));
      await tester.pumpAndSettle();
      final myIcon = tester.getRect(find.byIcon(Icons.refresh));
      print('[PageTopBar] 状态栏=$statusBar → 图标 top=${myIcon.top.toStringAsFixed(1)}');
    }
  });
}
