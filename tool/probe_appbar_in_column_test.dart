// 验证：Material AppBar 能不能直接放在 body 的 Column 里（而不是 Scaffold.appBar）
//
// 如果能，PageTopBar 就可以改成「薄薄一层 AppBar 包装」：保留各页面原有的
// `Column(children: [bar, Expanded(content)])` 结构，零结构改动拿到标准观感。
//
// 用法：flutter test tool/probe_appbar_in_column_test.dart
// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_flutter_app/utils/AppTheme.dart';

void main() {
  testWidgets('AppBar 放进 body 的 Column：高度/安全区/背景是否正常', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    tester.view.padding = const FakeViewPadding(top: 32 * 3);
    tester.view.viewPadding = const FakeViewPadding(top: 32 * 3);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme(),
      home: Scaffold(
        backgroundColor: AppColors.scaffoldBackground(Brightness.dark),
        // ⚠️ 关键：AppBar 不放在 Scaffold.appBar，而是 body 的 Column 里
        body: Column(children: [
          AppBar(
            backgroundColor: AppColors.cardBackground(Brightness.dark),
            elevation: 0,
            title: const Text('放进 Column 的 AppBar'),
            centerTitle: true,
            actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: () {})],
          ),
          const Expanded(
            child: Center(child: Text('内容区')),
          ),
        ]),
      ),
    ));
    await tester.pumpAndSettle();

    final barRect = tester.getRect(find.byType(AppBar));
    final titleRect = tester.getRect(find.text('放进 Column 的 AppBar'));
    final iconRect = tester.getRect(find.byIcon(Icons.refresh));
    final bodyRect = tester.getRect(find.text('内容区'));

    print('[AppBar in Column]');
    print('  AppBar rect : $barRect（期望高度 = 状态栏 32 + 56 = 88）');
    print('  标题 rect   : $titleRect  中心x=${titleRect.center.dx}');
    print('  刷新图标    : top=${iconRect.top}');
    print('  内容区中心  : ${bodyRect.center}');
    print('  是否有返回键: ${find.byType(BackButton).evaluate().isNotEmpty}'
        '（首屏不可 pop，按标准行为不显示）');

    expect(barRect.height, closeTo(88, 0.5), reason: 'AppBar 在 Column 里也应保持 状态栏+56');
    expect(barRect.width, closeTo(360, 0.5), reason: '应铺满宽度');
  });
}
