import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsFlag;
import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:my_first_flutter_app/widgets/PageTopBar.dart';

/// `PageTopBar` 的行为测试。
///
/// 实现已经换成**真正的 Material `AppBar`**（放在 body 的 `Column` 里，见组件注释），
/// 所以这里钉的是「它确实是标准 AppBar + 我们约定的那几项参数」：
///   1. 渲染出 `AppBar`，高度 = 状态栏 + `kToolbarHeight`；
///   2. 底色 `AppColors.cardBackground`、无阴影，与「Rating 排行榜」页同款；
///   3. 标题 `primary` / 20 / bold / 居中，且带 `Semantics(header)`；
///   4. 返回键默认是标准 `BackButton`（可关、可换成自定义回调）；
///   5. `showDivider` / `toolbarHeight` / `bottom` 等参数按预期生效。
void main() {
  /// 渲染到一台「状态栏 32dp」的手机上
  Future<void> pumpBar(
    WidgetTester tester, {
    required ThemeData theme,
    List<Widget> actions = const [],
    bool showBack = true,
    double? fontSize,
    VoidCallback? onBack,
    bool showDivider = false,
    double? toolbarHeight,
    PreferredSizeWidget? bottom,
    PageTopBarTitleAlign titleAlign = PageTopBarTitleAlign.center,
    double statusBar = 32,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    tester.view.padding = FakeViewPadding(top: statusBar * 3);
    tester.view.viewPadding = FakeViewPadding(top: statusBar * 3);
    addTearDown(tester.view.reset);
    await tester.pump();
    await tester.pumpWidget(MaterialApp(
      theme: theme,
      home: Scaffold(
        // ⚠️ 关键：bar 在 body 里（各页面就是这样用的），不是 Scaffold.appBar
        body: Column(children: [
          PageTopBar(
            title: '歌曲详情',
            actions: actions,
            showBack: showBack,
            fontSize: fontSize,
            onBack: onBack,
            showDivider: showDivider,
            toolbarHeight: toolbarHeight,
            bottom: bottom,
            titleAlign: titleAlign,
          ),
          const Expanded(child: Center(child: Text('内容区'))),
        ]),
      ),
    ));
    // 主题切换有 200ms 过渡动画，等它结束再断言颜色
    await tester.pumpAndSettle();
  }

  final dark = AppTheme.darkTheme();

  testWidgets('withGlobalFonts 给标准 AppBar 的标题补上全局字体族', (tester) async {
    for (final theme in [
      AppTheme.lightTheme(),
      AppTheme.darkTheme(),
      AppTheme.pureBlackTheme(),
    ]) {
      // 主题构造期不能碰 google_fonts（要 ServicesBinding），所以裸主题里没有族名，
      // 运行时由 main.dart 调 withGlobalFonts 补上。
      expect(theme.appBarTheme.titleTextStyle?.fontFamily, isNull);

      final style = AppTheme.withGlobalFonts(theme).appBarTheme.titleTextStyle;
      expect(style?.fontFamily, isNotNull,
          reason: '${theme.brightness} 主题的 AppBar 标题会退回系统字体');
      expect(style?.fontFamily, startsWith('NotoSansSC'),
          reason: '${theme.brightness} 主题没接上全局网络字体');
      expect(style?.fontFamily,
          AppTheme.font(fontWeight: FontWeight.bold).fontFamily,
          reason: 'bold 标题必须用 _700 那份字体文件');
      // 其余样式不能被顺手改掉
      expect(style?.fontSize, 20);
      expect(style?.fontWeight, FontWeight.bold);
      expect(style?.color, theme.colorScheme.primary);
    }
  });

  testWidgets('就是标准 AppBar：渲染出 AppBar 且高度 = 状态栏 + kToolbarHeight',
      (tester) async {
    await pumpBar(tester, theme: dark);

    expect(find.byType(AppBar), findsOneWidget);
    final barRect = tester.getRect(find.byType(AppBar));
    expect(barRect.height, closeTo(32 + kToolbarHeight, 0.5),
        reason: 'AppBar 自己处理状态栏（不用再写死 48dp）');
    expect(barRect.width, closeTo(360, 0.5));
  });

  group('样式（与 Rating 排行榜页同款）', () {
    testWidgets('底色 = AppColors.cardBackground、无阴影', (tester) async {
      await pumpBar(tester, theme: dark);
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, AppColors.cardBackground(Brightness.dark));
      expect(appBar.elevation, 0);
      expect(appBar.scrolledUnderElevation, 0);
    });

    testWidgets('标题：primary / 20 / bold / centerTitle', (tester) async {
      await pumpBar(tester, theme: dark);

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.centerTitle, isTrue);
      final text = tester.widget<Text>(find.text('歌曲详情'));
      expect(text.style?.fontSize, 20);
      expect(text.style?.fontWeight, FontWeight.bold);
      expect(text.style?.color, dark.colorScheme.primary);
      // 与 appBarTheme.titleTextStyle 同口径
      expect(text.style?.fontSize, dark.appBarTheme.titleTextStyle?.fontSize);
    });

    testWidgets('三种主题都有底、标题用各自的 primary', (tester) async {
      for (final theme in [
        AppTheme.lightTheme(),
        AppTheme.darkTheme(),
        AppTheme.pureBlackTheme(),
      ]) {
        await pumpBar(tester, theme: theme);
        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.backgroundColor, AppColors.cardBackground(theme.brightness));
        expect(tester.widget<Text>(find.text('歌曲详情')).style?.color,
            theme.colorScheme.primary);
      }
    });

    testWidgets('标题用全局网络字体（不是系统默认 Roboto）', (tester) async {
      await pumpBar(tester, theme: dark);

      // 防回归：AppBar 会给标题另套一层 `DefaultTextStyle(style: titleTextStyle)`，
      // 裸 TextStyle（不带 fontFamily）会顶掉 main.dart 注入的全局字体。
      // google_fonts 的族名按字重分文件（NotoSansSC_regular / NotoSansSC_700 …）。
      final style = tester.widget<Text>(find.text('歌曲详情')).style;
      expect(style?.fontFamily, isNotNull,
          reason: '标题没有字体族 → 会退回系统默认字体');
      expect(style?.fontFamily, startsWith('NotoSansSC'),
          reason: '标题必须与全 App 正文同族（思源黑体，运行时从网络获取）');
      expect(style?.fontFamily, AppTheme.font(fontWeight: FontWeight.bold).fontFamily,
          reason: '字重 bold 必须取 _700 那份字体文件，不能拿族名再 copyWith');
    });

    testWidgets('覆盖 fontSize 时字体族不丢', (tester) async {
      await pumpBar(tester, theme: dark, fontSize: 17);
      final style = tester.widget<Text>(find.text('歌曲详情')).style;
      expect(style?.fontSize, 17);
      expect(style?.fontFamily, startsWith('NotoSansSC'));
    });

    testWidgets('showDivider 打开时给 bar 加 outlineVariant 下边线', (tester) async {
      await pumpBar(tester, theme: dark, showDivider: true);
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      final border = appBar.shape! as Border;
      expect(border.bottom.color, dark.colorScheme.outlineVariant);
    });

    testWidgets('barBackground 可以覆盖（含透明）', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: dark,
        home: const Scaffold(
          body: Column(children: [
            PageTopBar(title: '歌曲详情', barBackground: Colors.transparent),
            Expanded(child: SizedBox.expand()),
          ]),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
          Colors.transparent);
    });
  });

  group('排布与无障碍', () {
    testWidgets('默认居中；靠左时 centerTitle=false', (tester) async {
      await pumpBar(tester, theme: dark);
      expect(tester.widget<AppBar>(find.byType(AppBar)).centerTitle, isTrue);

      await pumpBar(tester, theme: dark,
          titleAlign: PageTopBarTitleAlign.start);
      expect(tester.widget<AppBar>(find.byType(AppBar)).centerTitle, isFalse);
    });

    testWidgets('标题带 header 语义（AppBar 自带）', (tester) async {
      await pumpBar(tester, theme: dark);
      final node = tester.getSemantics(find.text('歌曲详情'));
      expect(node.hasFlag(SemanticsFlag.isHeader), isTrue);
    });

    testWidgets('多 action 时标题不会被压到按钮上（AppBar 的夹紧）', (tester) async {
      const long = '这是一个非常非常长的页面标题用来测夹紧行为';
      await pumpBar(
        tester,
        theme: dark,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () {}),
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
        ],
      );
      // 上面 pumpBar 里的标题是固定的，这里再单独渲染长标题
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      tester.view.padding = const FakeViewPadding(top: 32 * 3);
      tester.view.viewPadding = const FakeViewPadding(top: 32 * 3);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: dark,
        home: Scaffold(
          body: Column(children: [
            PageTopBar(
              title: long,
              actions: [
                IconButton(icon: const Icon(Icons.refresh), onPressed: () {}),
                IconButton(icon: const Icon(Icons.search), onPressed: () {}),
              ],
            ),
            const Expanded(child: SizedBox.expand()),
          ]),
        ),
      ));
      await tester.pumpAndSettle();

      final titleRect = tester.getRect(find.text(long));
      final firstAction = tester.getRect(find.byIcon(Icons.refresh));
      expect(titleRect.right, lessThanOrEqualTo(firstAction.left));
    });
  });

  group('返回键', () {
    testWidgets('默认是标准 BackButton', (tester) async {
      await pumpBar(tester, theme: dark);
      expect(find.byType(BackButton), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('showBack=false 时不显示', (tester) async {
      await pumpBar(tester, theme: dark, showBack: false);
      expect(find.byType(BackButton), findsNothing);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });

    testWidgets('传 onBack 时换成自定义回调（如播放页要先停播放）', (tester) async {
      var tapped = 0;
      await pumpBar(tester, theme: dark, onBack: () => tapped++);

      expect(find.byType(BackButton), findsNothing,
          reason: '自定义回调时用普通 IconButton');
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();
      expect(tapped, 1);
    });
  });

  testWidgets('toolbarHeight / bottom 槽可用（AppBar 的能力）', (tester) async {
    await pumpBar(
      tester,
      theme: dark,
      toolbarHeight: 40,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(10),
        child: SizedBox(height: 10),
      ),
    );

    expect(tester.getRect(find.byType(AppBar)).height,
        closeTo(32 + 40 + 10, 0.5));
    final bar = tester.widget<PageTopBar>(find.byType(PageTopBar));
    expect(bar.preferredSize.height, 40 + 10);
  });

  testWidgets('statusBar=0（平板/无状态栏）时高度自然变矮 —— 不再写死 48dp',
      (tester) async {
    await pumpBar(tester, theme: dark, statusBar: 0);
    expect(tester.getRect(find.byType(AppBar)).height,
        closeTo(kToolbarHeight, 0.5));
  });
}
