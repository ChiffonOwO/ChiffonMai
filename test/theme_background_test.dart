import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:my_first_flutter_app/utils/ThemeManager.dart';
import 'package:my_first_flutter_app/widgets/ThemeAwareBackground.dart';

/// 背景层（`ThemeAwareBackground`）的回归测试。
///
/// 修的是「深色（非纯黑）下主体区域有一块纯黑」：上层 chiffon 装饰图
/// （`chiffon2.png`，1179×2556 的整屏图，`BoxFit.contain` 居中后几乎占满主体区域）
/// 上面原来还铺了一层 `Positioned.fill(ColoredBox((8,8,20)))` 的矩形覆层。
/// 它跟装饰图自己的透明度无关 —— 装饰图默认就是 0（隐藏），覆层却照样画，
/// 于是「什么都没开」也能看到一整块漆黑 + 一条纯黑边界；
/// 背景图越亮（「背景透明度」调得越低）越刺眼，纯黑模式反而看不到
/// （那条分支直接 return 了）。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // ThemeManager 是单例，会跨用例留着上一次的值，这里显式复位
    ThemeManager().setLightOverlayOpacity(1.0);
    ThemeManager().setChiffonOpacity(0.0);
    ThemeManager().setPureBlackEnabled(false);
  });

  /// 装饰层里**不该**出现任何实心矩形：装饰图那层覆层用过的颜色。
  ///
  /// 除了点名 (8,8,20)（`ThemeAwareBackground`）之外，这里还统一断言
  /// 「整棵树里除了背景图自己的那层覆层，没有别的 ColoredBox」——
  /// 各页面用的 `buildCommonChiffonBgWidget` 里那层是 (10,10,25)，
  /// 换成别的颜色也会被这条拦住。
  const chiffonOverlayRgb = (r: 8, g: 8, b: 20);

  /// Color 的 ARGB 分量（`Color.r/g/b/a` 是 0~1 的 double，别直接比大小）。
  (int, int, int, int) argb(Color c) {
    final v = c.toARGB32();
    return ((v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF);
  }

  bool isChiffonOverlay(Color c) {
    final (_, r, g, b) = argb(c);
    return r == chiffonOverlayRgb.r &&
        g == chiffonOverlayRgb.g &&
        b == chiffonOverlayRgb.b;
  }

  Finder chiffonImage() => find.byWidgetPredicate((w) =>
      w is Image &&
      w.image is AssetImage &&
      (w.image as AssetImage).assetName == 'assets/chiffon2.png');

  /// 当前树里所有**真的会画出来**的 ColoredBox 颜色（全透明的忽略：
  /// Scaffold 之类会带一层透明 ColoredBox，它画不出任何东西）。
  List<Color> coloredBoxes(WidgetTester tester) => tester
      .widgetList<ColoredBox>(find.byType(ColoredBox))
      .map((w) => w.color)
      .where((c) => ((c.toARGB32() >> 24) & 0xFF) != 0)
      .toList();

  Future<void> pumpBackground(
    WidgetTester tester, {
    required Brightness brightness,
    bool pureBlack = false,
  }) async {
    await ThemeManager().setPureBlackEnabled(pureBlack);
    await tester.pumpWidget(MaterialApp(
      theme: brightness == Brightness.dark
          ? AppTheme.darkTheme()
          : AppTheme.lightTheme(),
      home: const ThemeAwareBackground(child: SizedBox.expand()),
    ));
    await tester.pump();
  }

  testWidgets('装饰图隐藏（默认）时不留任何纯黑覆层', (tester) async {
    await pumpBackground(tester, brightness: Brightness.dark);

    expect(chiffonImage(), findsNothing, reason: '装饰图 opacity=0，不该占位');
    final colors = coloredBoxes(tester);
    expect(colors, hasLength(1),
        reason: '整棵树里只该有背景图那层覆层，多出来的就是那块纯黑：$colors');
    for (final c in colors) {
      expect(isChiffonOverlay(c), isFalse,
          reason: '装饰图隐藏时还画 (8,8,20) 的矩形 = 那块纯黑');
    }
  });

  testWidgets('装饰图开启时只画图本身，不再铺一层黑矩形', (tester) async {
    await ThemeManager().setChiffonOpacity(0.5);
    await pumpBackground(tester, brightness: Brightness.dark);

    expect(chiffonImage(), findsOneWidget);
    final image = tester.widget<Image>(chiffonImage());
    expect(image.opacity?.value, 0.5, reason: '浓淡只由装饰图自己的滑杆控制');
    final colors = coloredBoxes(tester);
    expect(colors, hasLength(1), reason: '装饰层不该再铺矩形：$colors');
    for (final c in colors) {
      expect(isChiffonOverlay(c), isFalse,
          reason: '装饰图是透明底的整屏图，铺矩形就会变成一块黑');
    }
  });

  testWidgets('浅色模式同样只画装饰图', (tester) async {
    await ThemeManager().setChiffonOpacity(0.4);
    await pumpBackground(tester, brightness: Brightness.light);

    expect(chiffonImage(), findsOneWidget);
    final colors = coloredBoxes(tester);
    expect(colors, hasLength(1), reason: '浅色模式只有白色覆层：$colors');
    for (final c in colors) {
      expect(isChiffonOverlay(c), isFalse);
    }
  });

  testWidgets('纯黑模式：既没有装饰图，也没有黑矩形', (tester) async {
    await ThemeManager().setChiffonOpacity(1.0);
    await pumpBackground(tester, brightness: Brightness.dark, pureBlack: true);

    expect(chiffonImage(), findsNothing);
    // 纯黑模式下背景层就是一块纯黑底，这里只要求装饰层不再多铺矩形
    final colors = coloredBoxes(tester);
    expect(colors, hasLength(1), reason: '只该有纯黑底色：$colors');
  });

  testWidgets('背景图自身的覆层仍然在（满屏，跟「背景透明度」联动）', (tester) async {
    await ThemeManager().setLightOverlayOpacity(0.5);
    await pumpBackground(tester, brightness: Brightness.dark);

    final colors = coloredBoxes(tester);
    expect(
      colors.any((c) {
        final (a, r, g, b) = argb(c);
        return r == 15 && g == 15 && b == 28 && a == 128;
      }),
      isTrue,
      reason: '深色模式背景覆层仍是 (15,15,28)×透明度',
    );
  });

  group('各页面用的 buildCommonChiffonBgWidget 是同一个 bug', () {
    Future<void> pumpCommon(
      WidgetTester tester, {
      required Brightness brightness,
      bool pureBlack = false,
    }) async {
      await ThemeManager().setPureBlackEnabled(pureBlack);
      await tester.pumpWidget(MaterialApp(
        theme: brightness == Brightness.dark
            ? AppTheme.darkTheme()
            : AppTheme.lightTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => CommonWidgetUtil.buildCommonChiffonBgWidget(context),
          ),
        ),
      ));
      await tester.pump();
    }

    testWidgets('隐藏时不留纯黑覆层；开启时只画装饰图', (tester) async {
      await pumpCommon(tester, brightness: Brightness.dark);
      expect(chiffonImage(), findsNothing);
      expect(coloredBoxes(tester), isEmpty,
          reason: '这一层只该有装饰图，不该有任何矩形覆层');

      await ThemeManager().setChiffonOpacity(0.6);
      await pumpCommon(tester, brightness: Brightness.dark);
      expect(chiffonImage(), findsOneWidget);
      expect(coloredBoxes(tester), isEmpty,
          reason: 'BoxFit.cover 下那层矩形就是铺满全屏的纯黑');
    });
  });
}
