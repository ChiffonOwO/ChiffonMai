// 探针：量 AppBar / PageTopBar 标题**实际生效**的字体族。
//
// 背景：全 App 的思源黑体（google_fonts 运行时从网络获取）是在 main.dart 里
// 通过「替换 textTheme + 根部 DefaultTextStyle」注入的；而 AppBar 会在标题外面
// 套一层自己的 `DefaultTextStyle(style: appBarTheme.titleTextStyle)`，
// 那层样式如果没带 fontFamily，就会把全局字体顶掉。
//
// 这里读的是 `RenderParagraph.text.style`（= Text 合并 DefaultTextStyle 之后的
// **真正用于绘制**的样式），所以能直接看出字体族到底有没有被顶掉。
//
// 运行：flutter test tool/probe_appbar_font_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:my_first_flutter_app/utils/TextStyleUtil.dart';
import 'package:my_first_flutter_app/widgets/PageTopBar.dart';

/// 复刻 main.dart 里注入全局字体的方式（同一个入口）。
ThemeData withGlobalFonts(ThemeData base) => AppTheme.withGlobalFonts(base);

void main() {
  testWidgets('AppBar 标题实际使用的字体族', (tester) async {
    final theme = withGlobalFonts(AppTheme.darkTheme());

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        builder: (context, child) => DefaultTextStyle(
          style: GoogleFonts.notoSansSc(),
          child: child!,
        ),
        home: Column(
          children: [
            PageTopBar(title: 'PAGE_TOPBAR'),
            Expanded(
              child: Scaffold(
                appBar: AppBar(title: const Text('PLAIN_APPBAR')),
                bottomNavigationBar: NavigationBar(
                  selectedIndex: 0,
                  destinations: const [
                    NavigationDestination(
                        icon: Icon(Icons.home), label: 'NAV_LABEL'),
                    NavigationDestination(
                        icon: Icon(Icons.search), label: 'NAV_LABEL_2'),
                  ],
                ),
                body: Column(
                  children: [
                    const Text('BODY_TEXT'),
                    Text('UTIL_TEXT', style: TextStyleUtil.headlineSmall),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    String describe(Finder finder) {
      final rp = tester.renderObject<RenderParagraph>(finder);
      final style = (rp.text as TextSpan).style;
      return 'family=${style?.fontFamily}  fallback=${style?.fontFamilyFallback}  '
          'size=${style?.fontSize}  weight=${style?.fontWeight}';
    }

    debugPrint('--- 全局字体（google_fonts 运行时获取）---');
    final ref = GoogleFonts.notoSansSc();
    debugPrint('  GoogleFonts.notoSansSc() -> family=${ref.fontFamily} '
        'fallback=${ref.fontFamilyFallback}');
    debugPrint('--- 实测（渲染对象里真正生效的样式）---');
    debugPrint('  body 无样式文字  : ${describe(find.text('BODY_TEXT'))}');
    debugPrint('  TextStyleUtil    : ${describe(find.text('UTIL_TEXT'))}');
    debugPrint('  Material AppBar  : ${describe(find.text('PLAIN_APPBAR'))}');
    debugPrint('  PageTopBar 标题  : ${describe(find.text('PAGE_TOPBAR'))}');
    debugPrint('  NavigationBar 标签: ${describe(find.text('NAV_LABEL'))}');
    debugPrint('--- appBarTheme.titleTextStyle ---');
    debugPrint('  ${theme.appBarTheme.titleTextStyle}');

    // 断言：标题字体必须与全局字体同族（标题是 bold → 对应 _700 那份文件）
    final globalFamily = ref.fontFamily;
    final boldFamily = GoogleFonts.notoSansSc(fontWeight: FontWeight.bold).fontFamily;
    debugPrint('  期望：标题族名 = $boldFamily（正文 = $globalFamily）');
    for (final entry in {
      'Material AppBar': find.text('PLAIN_APPBAR'),
      'PageTopBar': find.text('PAGE_TOPBAR'),
    }.entries) {
      final rp = tester.renderObject<RenderParagraph>(entry.value);
      final style = (rp.text as TextSpan).style;
      expect(style?.fontFamily, isNotNull,
          reason: '${entry.key} 标题没有字体族（退回系统 Roboto）');
      expect(style?.fontFamily, boldFamily,
          reason: '${entry.key} 标题没有用全局字体（实际 ${style?.fontFamily}）');
    }
  });
}
