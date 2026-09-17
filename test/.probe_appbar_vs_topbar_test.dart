import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:my_first_flutter_app/widgets/PageTopBar.dart';

/// 临时探针：量 AppBar（Rating 排行榜页写法）与 PageTopBar 的真实几何 +
/// 系统状态栏 overlay 样式。跑完即删。
void main() {
  const statusBarPhysical = 72.0; // 24dp * 3

  testWidgets('probe geometry + overlay', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    tester.view.padding = const FakeViewPadding(top: statusBarPhysical);
    addTearDown(tester.view.reset);

    final lightTheme = AppTheme.lightTheme();
    final darkTheme = AppTheme.darkTheme();

    // ============ 1. Rating 排行榜页的 AppBar（浅色主题） ============
    await tester.pumpWidget(MaterialApp(
      theme: lightTheme,
      home: Scaffold(
        backgroundColor: AppColors.cardBackground(Brightness.light),
        appBar: AppBar(
          title: const Text('Rating 排行榜'),
          centerTitle: true,
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: () {}),
          ],
        ),
        body: ListView.builder(
          itemCount: 50,
          itemBuilder: (_, i) => SizedBox(height: 72, child: Text('row $i')),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final appBarHeight = tester.getSize(find.byType(AppBar)).height;
    debugPrint('PROBE appBarTheme.backgroundColor = '
        '${lightTheme.appBarTheme.backgroundColor}');
    debugPrint('PROBE appBarTheme.toolbarHeight = '
        '${lightTheme.appBarTheme.toolbarHeight}');
    debugPrint('PROBE estimateBrightnessForColor(transparent) = '
        '${ThemeData.estimateBrightnessForColor(Colors.transparent)}');
    debugPrint('PROBE estimateBrightnessForColor(white) = '
        '${ThemeData.estimateBrightnessForColor(Colors.white)}');
    debugPrint('PROBE AppBar 总高 = $appBarHeight '
        '(状态栏 24 → toolbar = ${appBarHeight - 24})');
    debugPrint('PROBE kToolbarHeight = 56');

    final appBarRegions = tester
        .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.byType(AnnotatedRegion<SystemUiOverlayStyle>))
        .toList();
    debugPrint('PROBE AppBar 页 AnnotatedRegion 数量 = ${appBarRegions.length}');
    for (final r in appBarRegions) {
      debugPrint('PROBE   statusBarIconBrightness = '
          '${r.value.statusBarIconBrightness}, statusBarColor = '
          '${r.value.statusBarColor}, statusBarBrightness = '
          '${r.value.statusBarBrightness}');
    }

    // 滚动一下，看 scrolledUnder 是否改变高度/底色
    await tester.drag(find.byType(ListView), const Offset(0, -50));
    await tester.pumpAndSettle();

    // ============ 2. 同样配置跑一次深色主题 ============
    await tester.pumpWidget(MaterialApp(
      theme: darkTheme,
      home: Scaffold(
        backgroundColor: AppColors.cardBackground(Brightness.dark),
        appBar: AppBar(title: const Text('Rating 排行榜'), centerTitle: true),
      ),
    ));
    await tester.pumpAndSettle();
    debugPrint('PROBE 深色 AppBar 总高 = '
        '${tester.getSize(find.byType(AppBar)).height}');
    for (final r in tester
        .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.byType(AnnotatedRegion<SystemUiOverlayStyle>))) {
      debugPrint('PROBE 深色 statusBarIconBrightness = '
          '${r.value.statusBarIconBrightness}');
    }

    // ============ 3. PageTopBar 页（浅色主题） ============
    await tester.pumpWidget(MaterialApp(
      theme: lightTheme,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            PageTopBar(
              title: '歌曲详情',
              actions: [
                IconButton(icon: const Icon(Icons.refresh), onPressed: () {}),
              ],
            ),
            const Expanded(child: SizedBox()),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final topBarHeight = tester.getSize(find.byType(PageTopBar)).height;
    debugPrint('PROBE PageTopBar 总高 = $topBarHeight '
        '(48 顶部补偿 + 48 按钮 + 8 底)');
    final topBarRegions = find.descendant(
      of: find.byType(PageTopBar),
      matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
    );
    debugPrint('PROBE PageTopBar 内 AnnotatedRegion 数量 = '
        '${tester.widgetList(topBarRegions).length}');
    final wholePageRegions = tester
        .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.byType(AnnotatedRegion<SystemUiOverlayStyle>))
        .toList();
    debugPrint('PROBE PageTopBar 页整屏 AnnotatedRegion 数量 = '
        '${wholePageRegions.length}');

    // ============ 4. 长标题溢出策略 ============
    await tester.pumpWidget(MaterialApp(
      theme: lightTheme,
      home: Scaffold(
        backgroundColor: AppColors.cardBackground(Brightness.light),
        appBar: AppBar(
          title: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('拟合总Rating排行榜'),
          ),
          centerTitle: true,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    debugPrint('PROBE AppBar(FittedBox) 标题宽 = '
        '${tester.getSize(find.text('拟合总Rating排行榜')).width}');

    await tester.pumpWidget(MaterialApp(
      theme: lightTheme,
      home: Scaffold(
        body: PageTopBar(title: '拟合总Rating排行榜'),
      ),
    ));
    await tester.pumpAndSettle();
    final textWidget =
        tester.widget<Text>(find.text('拟合总Rating排行榜'));
    debugPrint('PROBE PageTopBar 标题 overflow = ${textWidget.overflow}, '
        'maxLines = ${textWidget.maxLines}');

    expect(appBarHeight, greaterThan(0));
    expect(topBarHeight, greaterThan(0));
  });
}
