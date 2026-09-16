// 回归测试：曲库缓存为空时，单人猜歌页**不能**永久停在加载转圈上。
//
// 真实故障：所有单人猜歌页原先都是
//
// ```dart
// _targetSong = await XxxService.randomSelectSong(...);
// if (_targetSong != null) { setState(() => _isGameStarted = true); }
// ```
//
// **没有 else 分支**。曲库缓存为空（恢复备份后 prefs 被清空、首次拉取失败、
// 首页 7 天冷却期挡掉自动初始化……）时 randomSelectSong 返回 null，
// 页面就永久停在 CircularProgressIndicator：没有报错、没有重试，只能杀进程。
//
// 唯一的例外是谱面片段猜歌 —— 它每条失败路径都会置 _isGameStarted=true 并显示原因。
//
// 现在的契约统一到谱面片段猜歌那套思路：**抽不到曲也照常进入游戏界面**，
// 只把题面区（曲绘 / 别名 / 音频 / 遮蔽曲名）换成原因说明 ——
// 于是搜索框、规则 / 设置 / 刷新 / 排序 / 投降 5 个按钮都还在，
// 用户不用退出页面就能改设置、重抽。这里锁住这件事。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_first_flutter_app/page/GuessChartGame/GuessChartByAliaPage.dart';
import 'package:my_first_flutter_app/page/GuessChartGame/GuessChartByBlurredCoverPage.dart';
import 'package:my_first_flutter_app/page/GuessChartGame/GuessChartByCoverPage.dart';
import 'package:my_first_flutter_app/page/GuessChartGame/GuessChartByFlashCoverPage.dart';
import 'package:my_first_flutter_app/page/GuessChartGame/GuessChartByInfoPage.dart';
import 'package:my_first_flutter_app/page/GuessChartGame/GuessChartBySongExcerptPage.dart';
import 'package:my_first_flutter_app/page/GuessChartGame/GuessChartByTileRevealPage.dart';
import 'package:my_first_flutter_app/page/GuessChartGame/GuessChartLoadingView.dart';
import 'package:my_first_flutter_app/page/GuessChartGame/GuessSongByOpenLettersPage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 注意：所有这些页面共用 MaimaiMusicDataManager 单例与 SharedPreferences，
  // 而 `compute()` 会把宿主 test zone 弄脏（同一文件里的第二个 testWidgets
  // 会卡在第一个 await 上不再返回）。所以 9 个页面的真实路径校验必须在
  // **同一个** testWidgets 里顺序做完，每换一页先把上一页拆掉。
  final pages = <String, Widget Function()>{
    '无提示猜歌': () => const GuessChartByInfoPage(),
    '部分曲绘猜歌': () => const GuessChartByCoverPage(),
    '模糊曲绘猜歌': () => const GuessChartByBlurredCoverPage(),
    '别名猜歌': () => const GuessChartByAliaPage(),
    '曲绘快闪猜歌': () => const GuessChartByFlashCoverPage(),
    '歌曲片段猜歌': () => const GuessChartBySongExcerptPage(),
    '曲绘拼图猜歌': () => const GuessChartByTileRevealPage(),
    '舞萌开字母': () => const GuessSongByOpenLettersPage(),
  };

  testWidgets('抽不到曲时每个单人猜歌页都照常进入游戏界面（题面区给原因 + 搜索框 + 5 个按钮）',
      (tester) async {
    for (final entry in pages.entries) {
      final name = entry.key;

      // **不**预置 cachedSongs：模拟曲库缓存为空的冷启动
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(MaterialApp(home: entry.value()));
      // 让 _initGame / _loadSettings / randomSelectSong 的 Future 全部落地
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // 与谱面片段猜歌同一思路：不进加载态，而是照常进游戏界面，
      // 只在题面区（曲绘 / 别名 / 音频 / 遮蔽曲名）给出原因。
      expect(
        find.text(GuessChartLoadingView.emptyLibraryMessage),
        findsOneWidget,
        reason: '$name 抽不到曲时必须在题面区说明原因',
      );
      expect(
        find.text('输入歌曲名称或别名'),
        findsOneWidget,
        reason: '$name 的搜索框必须还在（用户要能自己搜歌/看清当前状态）',
      );
      // 5 个操作按钮：规则 / 设置 / 刷新 / 排序 / 投降
      expect(find.byIcon(Icons.info_outline), findsOneWidget,
          reason: '$name 缺「规则」按钮');
      expect(find.byIcon(Icons.settings), findsOneWidget,
          reason: '$name 缺「设置」按钮（否则没法放宽筛选条件）');
      expect(find.byIcon(Icons.refresh), findsWidgets,
          reason: '$name 缺「刷新/重抽」按钮');
      expect(
        find.byWidgetPredicate((w) =>
            w is Icon &&
            (w.icon == Icons.sort_by_alpha ||
                w.icon == Icons.sort_by_alpha_outlined)),
        findsOneWidget,
        reason: '$name 缺「排序」按钮',
      );
      expect(find.widgetWithText(TextButton, '投降'), findsOneWidget,
          reason: '$name 缺「投降」按钮');
      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: '$name 失败态不该继续转圈（会让人误以为「再等等就好」）',
      );
      // 空 target 下构建不应抛异常（题面区与答案卡片都要 null-safe）
      expect(tester.takeException(), isNull, reason: '$name 构建期不应抛异常');

      // 拆掉这一页，避免倒计时 / 音频定时器留到下一轮或测试结束
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump(const Duration(seconds: 1));
    }
  });

  testWidgets('加载中（还没失败）时只转圈，不给重试按钮', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: GuessChartLoadingView(message: '')),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('重新拉取曲库'), findsNothing);
  });

  testWidgets('筛选过严的提示同样带重试按钮', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GuessChartLoadingView(
            message: GuessChartLoadingView.filterTooStrictMessage,
            onRetry: _neverRetry,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(GuessChartLoadingView.filterTooStrictMessage),
        findsOneWidget);
    expect(find.text('重新拉取曲库'), findsOneWidget);
  });
}

Future<bool> _neverRetry() async => false;
