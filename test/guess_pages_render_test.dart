// 9 个单人猜歌页的构建冒烟测试。
//
// 为什么需要它：这些页面的设置对话框结构高度相似、且长期被批量修改
// （改默认值来源、改保存顺序、删死代码……），机械替换很容易把括号删错。
// `flutter analyze` 只保证语法/类型正确，这里额外保证**真的能构建出页面**。
// 本轮改动后它就是靠这个测试确认 9 个页面都还完好的。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_first_flutter_app/page/RecommendByTagsPage.dart';
import 'package:my_first_flutter_app/page/GuessChartGame/GuessChartByAliaPage.dart';
import 'package:my_first_flutter_app/page/GuessChartGame/GuessChartByBlurredCoverPage.dart';
import 'package:my_first_flutter_app/page/GuessChartGame/GuessChartByChartPeekPage.dart';
import 'package:my_first_flutter_app/page/GuessChartGame/GuessChartByCoverPage.dart';
import 'package:my_first_flutter_app/page/GuessChartGame/GuessChartByFlashCoverPage.dart';
import 'package:my_first_flutter_app/page/GuessChartGame/GuessChartByInfoPage.dart';
import 'package:my_first_flutter_app/page/GuessChartGame/GuessChartBySongExcerptPage.dart';
import 'package:my_first_flutter_app/page/GuessChartGame/GuessChartByTileRevealPage.dart';
import 'package:my_first_flutter_app/page/GuessChartGame/GuessSongByOpenLettersPage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final pages = <String, Widget Function()>{
    'InfoPage': () => const GuessChartByInfoPage(),
    'CoverPage': () => const GuessChartByCoverPage(),
    'BlurredCoverPage': () => const GuessChartByBlurredCoverPage(),
    'AliaPage': () => const GuessChartByAliaPage(),
    'FlashCoverPage': () => const GuessChartByFlashCoverPage(),
    'SongExcerptPage': () => const GuessChartBySongExcerptPage(),
    'OpenLettersPage': () => const GuessSongByOpenLettersPage(),
    'TileRevealPage': () => const GuessChartByTileRevealPage(),
    'ChartPeekPage': () => const GuessChartByChartPeekPage(),
  };

  pages.forEach((name, build) {
    testWidgets('$name 可以构建（不抛异常）', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(MaterialApp(home: build()));
      await tester.pump(const Duration(milliseconds: 50));

      // 构建期是否抛异常（这是我们要验的：括号/结构有没有被机械替换改坏）
      final buildError = tester.takeException();
      expect(buildError, isNull, reason: '构建期不应抛异常');

      // 页面确实渲染出了内容（Scaffold 存在）
      expect(find.byType(Scaffold), findsWidgets, reason: '应渲染出页面骨架');

      // 拆掉 widget 树，避免页面里的倒计时/音频定时器留到测试结束触发
      // 「A Timer is still pending」——那是测试环境特性，不是页面缺陷。
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump(const Duration(seconds: 1));
    });
  });

  // ---------------------------------------------------------------------
  // 加载提示定时器泄漏回归。
  //
  // LoadingTipsConstant 用的是**全局静态** Timer.periodic + 广播流，多个页面
  // 共用。页面只「start」不「stop」的话，关掉页面后定时器会一直跑到进程结束。
  // 原先 GuessChartBySongExcerptPage 与 RecommendByTagsPage 就是这样。
  //
  // 这里不手动 stop，故意让 flutter_test 自带的「A Timer is still pending」
  // 检查去发现泄漏 —— 它正是当初抓出这个 bug 的机制。
  // ---------------------------------------------------------------------
  group('加载提示定时器不泄漏', () {
    testWidgets('SongExcerptPage dispose 后不再有周期定时器', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
          const MaterialApp(home: GuessChartBySongExcerptPage()));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump(const Duration(seconds: 1));
      // 若 dispose 里没 stopAutoSwitch()，测试结束时会因仍有 pending timer 失败
    });

    testWidgets('RecommendByTagsPage dispose 后不再有周期定时器', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
          const MaterialApp(home: RecommendByTags()));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
