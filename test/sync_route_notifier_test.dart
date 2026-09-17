import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_first_flutter_app/constant/CacheKeyConstant.dart';
import 'package:my_first_flutter_app/service/SyncRouteStore.dart';
import 'package:my_first_flutter_app/service/SyncStatsService.dart';
import 'package:my_first_flutter_app/utils/SyncRouteNotifier.dart';
import 'package:my_first_flutter_app/widgets/SyncRouteFooter.dart';

/// 「同步成绩」入口的共享状态：线路切换 + 统计。
///
/// 需求来源：这两个入口同时出现在「系统」hub 页和首页「收藏的功能」区，
/// 要求**两边显示一致、记忆一致**。这里钉住三件事：
///   1. 线路读写走同一套 prefs 键（[SyncRouteStore]）；
///   2. 同一个 notifier 的多个 footer（两个页面各一个）自动同步；
///   3. 统计按「当前线路 + 平台」取，取不到就是 null（UI 显示统计不可用）。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SyncRouteNotifier.instance.debugResetForTest();
    // 单测不连 Redis：ensureLoaded() 里的统计读取换成空结果。
    SyncRouteNotifier.instance.debugStatsLoader = (_) async => {};
  });

  group('线路记忆', () {
    test('初次加载读 prefs，默认线路1', () async {
      await SyncRouteNotifier.instance.ensureLoaded();
      expect(SyncRouteNotifier.instance.routeOf(SyncPlatform.divingFish),
          SyncRouteStore.routeScoreHub);
      expect(SyncRouteNotifier.instance.routeOf(SyncPlatform.luoXue),
          SyncRouteStore.routeScoreHub);
    });

    test('用户上次选过线路2 → 加载时读回来', () async {
      SharedPreferences.setMockInitialValues({
        CacheKeyConstant.syncRouteDivingFish: 1,
      });
      SyncRouteNotifier.instance.debugResetForTest();
      SyncRouteNotifier.instance.debugStatsLoader = (_) async => {};
      await SyncRouteNotifier.instance.ensureLoaded();
      expect(SyncRouteNotifier.instance.routeOf(SyncPlatform.divingFish),
          SyncRouteStore.routeAwmc);
      // 落雪没存过 → 仍是线路1（两条线路各自记忆）
      expect(SyncRouteNotifier.instance.routeOf(SyncPlatform.luoXue),
          SyncRouteStore.routeScoreHub);
    });

    test('切换线路会落盘 + 通知监听者', () async {
      var notified = 0;
      void listener() => notified++;
      SyncRouteNotifier.instance.addListener(listener);
      addTearDown(() => SyncRouteNotifier.instance.removeListener(listener));

      await SyncRouteNotifier.instance
          .setRoute(SyncPlatform.divingFish, SyncRouteStore.routeAwmc);

      expect(SyncRouteNotifier.instance.routeOf(SyncPlatform.divingFish),
          SyncRouteStore.routeAwmc);
      expect(notified, greaterThan(0));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(CacheKeyConstant.syncRouteDivingFish), 1,
          reason: '两个页面读的是同一份 prefs，必须落盘');
      expect(prefs.getInt(CacheKeyConstant.syncRouteLuoXue), isNull,
          reason: '切水鱼不该动落雪的记忆');
    });
  });

  group('统计按「当前线路 + 平台」取', () {
    test('没有统计数据时为 null（UI 显示统计不可用）', () async {
      await SyncRouteNotifier.instance.ensureLoaded();
      expect(SyncRouteNotifier.instance.statsFor(SyncPlatform.divingFish), isNull);
      expect(SyncRouteNotifier.instance.statsLoaded, isTrue,
          reason: '加载过（哪怕是空结果）也要标记，详情弹窗才能不转圈');
    });

    test('ensureLoaded 一次读 4 个组合，重复调用不重复拉', () async {
      var calls = 0;
      List<(SyncLine, SyncPlatform)>? seen;
      SyncRouteNotifier.instance.debugStatsLoader = (queries) async {
        calls++;
        seen = queries;
        return {
          for (final (line, platform) in queries)
            '${line.key}:${platform.key}': const SyncStats(
              count: 3,
              successCount: 3,
              avgMs: 2000,
              minMs: 1000,
              maxMs: 3000,
              lastMs: 1500,
              lastOk: true,
              lastAtMs: 1,
            ),
        };
      };

      await SyncRouteNotifier.instance.ensureLoaded();
      await SyncRouteNotifier.instance.ensureLoaded(); // 幂等

      expect(calls, 1, reason: '两个页面各自 ensureLoaded 也只拉一次');
      expect(seen!.length, 4);
      final stats = SyncRouteNotifier.instance.statsFor(SyncPlatform.divingFish);
      expect(stats!.count, 3);
      expect(stats.avgText, '2.0s');
    });

    test('切到线路2 后取的是 AWMC 那一份统计', () async {
      const hubStats = SyncStats(
        count: 10,
        successCount: 9,
        avgMs: 1000,
        minMs: 500,
        maxMs: 2000,
        lastMs: 800,
        lastOk: true,
        lastAtMs: 1,
      );
      const awmcStats = SyncStats(
        count: 20,
        successCount: 20,
        avgMs: 5000,
        minMs: 4000,
        maxMs: 6000,
        lastMs: 4500,
        lastOk: true,
        lastAtMs: 2,
      );
      SyncRouteNotifier.instance.debugSetStats({
        '${SyncLine.scoreHub.key}:${SyncPlatform.divingFish.key}': hubStats,
        '${SyncLine.awmc.key}:${SyncPlatform.divingFish.key}': awmcStats,
      });

      // 默认线路1 → 看到 Score Hub 的统计
      expect(SyncRouteNotifier.instance.statsFor(SyncPlatform.divingFish)!.count,
          10);

      await SyncRouteNotifier.instance
          .setRoute(SyncPlatform.divingFish, SyncRouteStore.routeAwmc);
      expect(SyncRouteNotifier.instance.statsFor(SyncPlatform.divingFish)!.count,
          20);
      // 落雪不在这个 map 里 → null
      expect(SyncRouteNotifier.instance.statsFor(SyncPlatform.luoXue), isNull);
    });
  });

  group('两个页面的 footer 共用同一份状态', () {
    testWidgets('在一处切线路，另一处立刻跟着变', (tester) async {
      // 模拟「系统 hub」与「首页收藏区」各渲染一个 footer
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(
            children: const [
              SyncRouteFooter(platform: SyncPlatform.divingFish),
              SyncRouteFooter(platform: SyncPlatform.luoXue),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('maimai Score Hub'), findsNWidgets(2));
      // 水鱼那个切到线路2
      await tester.tap(find.text('线路2').first);
      await tester.pumpAndSettle();

      // 两个 footer 里水鱼那个变成 AWMC 网关，落雪仍是 maimai Score Hub
      expect(find.text('AWMC 网关'), findsOneWidget);
      expect(find.text('maimai Score Hub'), findsOneWidget);
      expect(SyncRouteNotifier.instance.routeOf(SyncPlatform.divingFish),
          SyncRouteStore.routeAwmc);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(CacheKeyConstant.syncRouteDivingFish), 1);
      expect(prefs.getInt(CacheKeyConstant.syncRouteLuoXue), isNull);
    });

    testWidgets('统计行随线路切换更新（同一条 footer）', (tester) async {
      const hubStats = SyncStats(
        count: 10,
        successCount: 9,
        avgMs: 12345,
        minMs: 1,
        maxMs: 2,
        lastMs: 1,
        lastOk: true,
        lastAtMs: 1,
      );
      const awmcStats = SyncStats(
        count: 20,
        successCount: 10,
        avgMs: 5000,
        minMs: 1,
        maxMs: 2,
        lastMs: 1,
        lastOk: true,
        lastAtMs: 1,
      );
      SyncRouteNotifier.instance.debugSetStats({
        '${SyncLine.scoreHub.key}:${SyncPlatform.divingFish.key}': hubStats,
        '${SyncLine.awmc.key}:${SyncPlatform.divingFish.key}': awmcStats,
      });

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SyncRouteFooter(platform: SyncPlatform.divingFish),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('10样本'), findsOneWidget);
      expect(find.textContaining('平均12.3s'), findsOneWidget);

      await tester.tap(find.text('线路2'));
      await tester.pumpAndSettle();

      expect(find.textContaining('20样本'), findsOneWidget);
      expect(find.textContaining('平均5.0s'), findsOneWidget);
      expect(find.textContaining('成功50%'), findsOneWidget);
    });
  });
}
