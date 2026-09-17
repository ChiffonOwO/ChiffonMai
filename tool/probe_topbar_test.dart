// ===========================================================================
// 顶部标题栏的离屏渲染对照探针（深色模式）
//
// 背景：48 个页面各自抄了一份标题栏，且是**完全透明**的（标题直接浮在页面背景上，
// 「没有底」）。现在统一走 `lib/widgets/PageTopBar.dart`，默认给一块实心底
// （`colorScheme.surface` + `outlineVariant` 细线），也就是 AWMC 网关页
// （Material AppBar）那种观感。
//
// 这个探针把几种样式都出图，便于挑：
//   tool/shots/topbar_about.png         真实页面 AboutAppPage（现在 = 有底 + 居中）
//   tool/shots/topbar_favorites.png     真实页面 FavoriteFolderPage
//   tool/shots/topbar_bar_center.png    宿主页：有底 + 标题居中
//   tool/shots/topbar_bar_start.png     宿主页：有底 + 标题靠左（AWMC / AppBar 风）
//   tool/shots/topbar_bar_plain.png     宿主页：透明无底（迁移前的旧观感，作对照）
//   tool/shots/topbar_*_before.png      迁移前的真实页面（上一次运行留下的）
//
// 用法：flutter test tool/probe_topbar_test.dart --update-goldens
//
// ⚠️ 刻意放在 tool/ 而不是 test/：`flutter test` 默认会把 `test/` 下的隐藏文件
// 也一起跑，而这个探针要读系统字体、还要跟 golden 比对，不适合进默认测试套件。
// tool/ 不在 analyzer 的测试目录白名单里，这两条 lint 在这里是误报：
// ignore_for_file: avoid_print, invalid_use_of_visible_for_testing_member
// ===========================================================================
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_first_flutter_app/page/AboutAppPage.dart';
import 'package:my_first_flutter_app/page/FavoriteFolderPage.dart';
import 'package:my_first_flutter_app/page/RankingList/RatingRankListPage.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:my_first_flutter_app/widgets/PageTopBar.dart';

/// 加载中文字体 / 图标字体，否则测试环境渲染成方块
///
/// ⚠️ 除了测试环境默认的 `Roboto`，还要把中文顶到 google_fonts 的**按字重族名**上：
/// 真机上 `NotoSansSC_700` 这类族由 google_fonts 从网络加载，测试环境里没有任何
/// 网络字体，标题栏（`PageTopBar` 走 `AppTheme.font`）就会渲染成方块。
Future<void> loadFonts() async {
  // 让 AppTheme.font 走「本地族名」旁路：测试环境没法联网取思源黑体，
  // 而 google_fonts 的加载失败会冒到 Zone 把探针判失败。
  AppTheme.debugLocalFontFamily = true;

  Future<void> load(String family, List<String> candidates) async {
    for (final path in candidates) {
      final f = File(path);
      if (!f.existsSync()) continue;
      try {
        final bytes = await f.readAsBytes();
        final loader = FontLoader(family);
        loader.addFont(Future.value(ByteData.view(bytes.buffer)));
        await loader.load();
        print('[RENDER] 字体 $family ← $path');
        return;
      } catch (e) {
        print('[RENDER] 字体加载失败 $path: $e');
      }
    }
    print('[RENDER] 警告：$family 没找到可用字体');
  }

  // 中文：同一个文件顶到多个族名（测试环境里没有网络字体）
  for (final family in [
    'Roboto', // 测试环境默认族（主题 textTheme 被钉到它）
    'NotoSansSC_regular', // google_fonts：w400
    'NotoSansSC_500', // google_fonts：w500
    'NotoSansSC_700', // google_fonts：w700（标题栏用的就是这份）
  ]) {
    await load(family, [
      r'C:\Windows\Fonts\msyh.ttc',
      r'C:\Windows\Fonts\simhei.ttf',
      r'C:\Windows\Fonts\Deng.ttf',
      r'C:\Windows\Fonts\seguiemj.ttf', // emoji
    ]);
  }
  await load('MaterialIcons', [
    r'D:\flutter\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf',
  ]);
}

/// 宿主页：把标题栏单独放一页，用来对比三种样式（内容区是空的，看 bar 就够）
class _BarHost extends StatelessWidget {
  final PageTopBarTitleAlign align;
  final bool solid;
  const _BarHost({required this.align, required this.solid});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground(Brightness.dark),
      body: Column(children: [
        PageTopBar(
          title: '歌曲详情',
          fontSize: align == PageTopBarTitleAlign.start ? null : 24,
          titleAlign: align,
          barBackground: solid ? null : Colors.transparent,
          showDivider: solid,
          actions: [
            IconButton(
              icon: const Icon(Icons.image_outlined),
              tooltip: '导出歌曲信息',
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.calculate_outlined),
              tooltip: '计算工具',
              onPressed: () {},
            ),
          ],
        ),
        const Expanded(
          child: Center(
            child: Text('（内容区）', style: TextStyle(color: Color(0xFFB0C4C4))),
          ),
        ),
      ]),
    );
  }
}

/// 探针用的深色主题：把字体统一钉到 'Roboto'（我们在 loadFonts 里把它换成了微软雅黑），
/// 否则 AppBar 的 titleTextStyle 会落到测试环境的桩字体上、中文渲染成方块。
ThemeData probeTheme() {
  final base = AppTheme.darkTheme();
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Roboto'),
    appBarTheme: base.appBarTheme.copyWith(
      titleTextStyle:
          base.appBarTheme.titleTextStyle?.copyWith(fontFamily: 'Roboto'),
    ),
  );
}

void main() {
  final cases = <String, Widget Function()>{
    // 样式基准：Rating 排行榜页（真的 Material AppBar）
    'rating_ref': () => const RatingRankListPage(),
    'about': () => const AboutAppPage(),
    'favorites': () => const FavoriteFolderPage(),
    'bar_center': () =>
        const _BarHost(align: PageTopBarTitleAlign.center, solid: true),
    'bar_start': () =>
        const _BarHost(align: PageTopBarTitleAlign.start, solid: true),
    'bar_plain': () =>
        const _BarHost(align: PageTopBarTitleAlign.center, solid: false),
  };

  cases.forEach((name, build) {
    testWidgets('$name 深色模式标题栏', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(loadFonts);

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: probeTheme(),
        home: build(),
      ));
      // 页面里的异步初始化/定时器：只泵有限帧，不用 pumpAndSettle（会挂）
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 80));
      }

      await tester.runAsync(() async {
        for (final element in find.byType(Image).evaluate()) {
          final image = (element.widget as Image).image;
          try {
            await precacheImage(image, element);
          } catch (_) {}
        }
      });
      await tester.pump();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('shots/topbar_$name.png'),
      );
      print('[RENDER] 已出图: tool/shots/topbar_$name.png');

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump(const Duration(seconds: 1));
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
