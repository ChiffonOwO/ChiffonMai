// ===========================================================================
// 首页背景层离屏渲染探针（深色 + 亮背景）
//
// 目的：背景「那块纯黑」是纯视觉问题，光靠 widget 断言看不出观感。
// 这里把真实的 ThemeAwareBackground 渲染成 PNG 对照修复前/后：
//   tool/shots/home_bg_before.png   ← 修复前的写法（装饰图上铺 (8,8,20) 矩形）
//   tool/shots/home_bg_after.png    ← 现在的写法（只画装饰图）
//   tool/shots/home_bg_chiffon.png  ← 现在的写法 + 装饰图打开（0.5）
//
// 实测结论（采样 x=20 一列的亮度，0~255）：「修复前」从顶部一直到 y≈2300
// （屏高 2400）都比「修复后」暗 20~50，y≥2320 起两张图完全一致 —— 那块覆层
// 正好停在离底边约 100px（≈33dp）处，留下一条硬边，就是「主体区域那块纯黑边界」。
// 对照图里还能看到：装饰图 0.5 时角色照常显示，周围不再有黑框。
//
// ⚠️ 刻意放在 tool/ 而不是 test/：`flutter test` 默认会把 `test/` 下的隐藏文件
// 也一起跑，而这个探针要读 C:\Windows\Fonts 的字体、还要跟 golden 比对，
// 不适合塞进默认测试套件。
//
// 用法：flutter test tool/probe_home_bg_test.dart --update-goldens
// ===========================================================================
// tool/ 不在 analyzer 的「测试目录」白名单里，所以这两条 lint 在这里是误报：
//   * print —— 探针的输出就是给人看的
//   * setMockInitialValues —— 它本来就是 test 专用 API
// ignore_for_file: avoid_print, invalid_use_of_visible_for_testing_member
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:my_first_flutter_app/utils/ThemeManager.dart';
import 'package:my_first_flutter_app/widgets/ThemeAwareBackground.dart';

/// 加载中文字体，否则测试环境把中文渲染成方块（□），没法判断观感
Future<void> loadChineseFonts() async {
  const candidates = [
    r'C:\Windows\Fonts\msyh.ttc',
    r'C:\Windows\Fonts\simhei.ttf',
    r'C:\Windows\Fonts\Deng.ttf',
  ];
  for (final path in candidates) {
    final f = File(path);
    if (!f.existsSync()) continue;
    try {
      final bytes = await f.readAsBytes();
      final loader = FontLoader('Roboto');
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
      print('[RENDER] 已加载中文字体: $path');
      return;
    } catch (e) {
      print('[RENDER] 字体加载失败 $path: $e');
    }
  }
  print('[RENDER] 警告：未找到中文字体，中文会渲染成方块');
}

/// 修复前 `_ChiffonImage` 的写法：装饰图上再铺一层 (8,8,20) 的矩形覆层。
/// 装饰图是透明底的整屏图，覆层却是实心矩形 —— 就是「那块纯黑」。
class _OldChiffonLayer extends StatelessWidget {
  const _OldChiffonLayer();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlayAlpha =
        (ThemeManager().lightOverlayOpacity * 255).round().clamp(0, 255);
    return Center(
      child: Transform.translate(
        offset: const Offset(0, -30),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.asset(
              'assets/chiffon2.png',
              fit: BoxFit.contain,
              gaplessPlayback: true,
              opacity: AlwaysStoppedAnimation(ThemeManager().chiffonOpacity),
            ),
            if (isDark)
              Positioned.fill(
                child: ColoredBox(
                  color: Color.fromARGB(overlayAlpha, 8, 8, 20),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 模拟首页主体：标题 + 总览卡 + 四个快捷入口 + 一张收藏卡
class _FakeHomeBody extends StatelessWidget {
  const _FakeHomeBody();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget card({required double height, Widget? child}) => Container(
          height: height,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          alignment: Alignment.center,
          child: child,
        );

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          Text('ChiffonMai',
              style: TextStyle(
                  color: scheme.primary,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('欢迎回来，Chiffon',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 22),
          Container(
            height: 150,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [scheme.primary, scheme.secondary],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            alignment: Alignment.center,
            child: const Text('PLAYER OVERVIEW / TOTAL RATING',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 28),
          const Text('快捷入口',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final label in ['查成绩', 'Best50', '查歌曲', '每日推荐']) ...[
                Expanded(
                  child: card(
                    height: 86,
                    child: Text(label,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ),
                if (label != '每日推荐') const SizedBox(width: 12),
              ],
            ],
          ),
          const SizedBox(height: 28),
          const Text('收藏的功能',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          card(height: 220),
        ],
      ),
    );
  }
}

void main() {
  testWidgets('首页背景：修复前 / 修复后 / 装饰图打开', (tester) async {
    SharedPreferences.setMockInitialValues({});
    // ⚠️ 真实文件 IO / 字体加载必须在 runAsync 里，否则 testWidgets 的 fake async
    // 永远等不到 Future 完成（表现就是整个用例无声卡死）
    await tester.runAsync(loadChineseFonts);
    // 亮背景：把「背景透明度」调低，让背景图透出来（抱怨的场景）
    await ThemeManager().setLightOverlayOpacity(0.35);
    await ThemeManager().setPureBlackEnabled(false);
    await ThemeManager().setChiffonOpacity(0.0);

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    Future<void> settleImages() async {
      await tester.runAsync(() async {
        for (final element in find.byType(Image).evaluate()) {
          final image = (element.widget as Image).image;
          await precacheImage(image, element);
        }
      });
      await tester.pumpAndSettle();
    }

    Future<void> shoot(
      String name, {
      Widget Function(Widget child)? wrap,
    }) async {
      final body = const _FakeHomeBody();
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme(),
        home: ThemeAwareBackground(
          child: wrap == null
              ? body
              : Stack(fit: StackFit.expand, children: [
                  body,
                  IgnorePointer(child: wrap(const SizedBox.expand())),
                ]),
        ),
      ));
      await tester.pump();
      await settleImages();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('shots/home_bg_$name.png'),
      );
      print('[RENDER] 已出图: tool/shots/home_bg_$name.png');
    }

    // 修复前：底层背景 + 旧的装饰图层
    await shoot('before', wrap: (_) => const _OldChiffonLayer());

    // 修复后（装饰图隐藏，默认）
    await shoot('after');

    // 修复后 + 装饰图 0.5（用户真的想看装饰图时）
    await ThemeManager().setChiffonOpacity(0.5);
    await shoot('chiffon');

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
