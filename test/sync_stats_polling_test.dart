// 「同步统计」定时刷新（轮询）的测试。
//
// 背景：统计是**所有使用者共享**的聚合（Redis 里近 100 次同步），别处随时会改变它。
// 如果只在进页面时拉一次，用户把页面开着 → 数字会一直停在旧值。
// 所以 SyncRouteNotifier 会在**有 UI 订阅时**按间隔重拉，并把结果推给 UI。
//
// 这里钉住的四条口径：
//   1. 有订阅才轮询；最后一个订阅移除后必须停（别在后台空转连 Redis）；
//   2. 轮询是**静默**的：不闪「统计加载中…」；
//   3. 整批拉取失败时**保留上一次的数据**，不能降级成「统计不可用」；
//   4. 回到前台**立刻**重拉一次（不等一个完整周期）。
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_first_flutter_app/service/SyncStatsService.dart';
import 'package:my_first_flutter_app/utils/SyncRouteNotifier.dart';

const SyncStats _sample = SyncStats(
  count: 7,
  successCount: 6,
  avgMs: 12300,
  minMs: 8000,
  maxMs: 20000,
  lastMs: 9000,
  lastOk: true,
  lastAtMs: 1,
);

Map<String, SyncStats?> _allWith(SyncStats? stats) => {
      for (final line in SyncLine.values)
        for (final platform in SyncPlatform.values)
          '${line.key}:${platform.key}': stats,
    };

/// 走真实的 lifecycle 通道，与平台行为一致。
Future<void> _sendLifecycle(WidgetTester tester, String state) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/lifecycle',
    const StringCodec().encodeMessage(state),
    (_) {},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SyncRouteNotifier.instance.debugResetForTest();
  });

  tearDown(() {
    // 必须复位：静态的间隔/开关会串到别的测试
    SyncRouteNotifier.instance.debugResetForTest();
  });

  test('有订阅才轮询；最后一个订阅移除后立刻停', () async {
    SyncRouteNotifier.debugStatsRefreshInterval =
        const Duration(milliseconds: 60);
    var calls = 0;
    SyncRouteNotifier.instance.debugStatsLoader = (queries) async {
      calls++;
      return _allWith(_sample);
    };

    void listener() {}
    SyncRouteNotifier.instance.addListener(listener);
    expect(SyncRouteNotifier.instance.debugPollingActive, isTrue,
        reason: '有人订阅就该开始轮询');

    await Future<void>.delayed(const Duration(milliseconds: 220));
    expect(calls, greaterThanOrEqualTo(2), reason: '应当按间隔重拉');

    SyncRouteNotifier.instance.removeListener(listener);
    expect(SyncRouteNotifier.instance.debugPollingActive, isFalse,
        reason: '没人看了就不该继续连 Redis');
    final afterRemove = calls;
    await Future<void>.delayed(const Duration(milliseconds: 180));
    expect(calls, afterRemove, reason: '停了之后不能再拉');
  });

  test('轮询是静默的：不会闪「统计加载中…」', () async {
    SyncRouteNotifier.debugStatsRefreshInterval =
        const Duration(milliseconds: 40);
    final notifier = SyncRouteNotifier.instance;
    notifier.debugStatsLoader = (queries) async {
      // 慢一点，好让「加载中」有机会被观察到
      await Future<void>.delayed(const Duration(milliseconds: 25));
      return _allWith(_sample);
    };

    void listener() {}
    notifier.addListener(listener);
    await notifier.refreshStats(); // 首次（非静默）：这一步出现「加载中」是正常的

    var sawLoadingDuringPolling = false;
    void watcher() {
      if (notifier.statsLoading) sawLoadingDuringPolling = true;
    }

    notifier.addListener(watcher);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    notifier.removeListener(watcher);
    notifier.removeListener(listener);

    expect(sawLoadingDuringPolling, isFalse,
        reason: '轮询刷新不能把已经显示的数字换成「统计加载中…」');
    expect(notifier.statsFor(SyncPlatform.divingFish)!.count, 7,
        reason: '静默刷新照样要把数据更新进来');
  });

  test('整批拉取失败：保留上一次的数据，只标记「这次没刷上」', () async {
    final notifier = SyncRouteNotifier.instance;
    notifier.debugStatsLoader = (queries) async => _allWith(_sample);
    await notifier.refreshStats();

    expect(notifier.statsFor(SyncPlatform.divingFish)!.count, 7);
    expect(notifier.statsRefreshFailed, isFalse);
    final updatedAt = notifier.statsUpdatedAtMs;
    expect(updatedAt, greaterThan(0));

    // 下一次整批失败（Redis 不可用 → loadMany 4 个组合全 null）
    notifier.debugStatsLoader = (queries) async => _allWith(null);
    await notifier.refreshStats(silent: true);

    expect(notifier.statsFor(SyncPlatform.divingFish)!.count, 7,
        reason: '一次抖动不能把已经显示的数字抹掉');
    expect(notifier.statsRefreshFailed, isTrue, reason: '但要如实标记没刷上');
    expect(notifier.statsUpdatedAtMs, updatedAt,
        reason: '没成功就不能把「更新时间」往前推');
  });

  test('从没拉到过数据时如实显示「统计不可用」', () async {
    final notifier = SyncRouteNotifier.instance;
    notifier.debugStatsLoader = (queries) async => _allWith(null);
    await notifier.refreshStats();

    expect(notifier.statsFor(SyncPlatform.divingFish), isNull);
    expect(notifier.statsLoaded, isTrue, reason: '跑过一次就算加载过（详情弹窗不转圈）');
    expect(notifier.statsRefreshFailed, isTrue);
  });

  testWidgets('回到前台立刻重拉一次（不等一个完整周期）', (tester) async {
    // 周期设成 10 分钟：测试期间绝不会由定时器触发，只可能是「回前台」触发的
    SyncRouteNotifier.debugStatsRefreshInterval = const Duration(minutes: 10);
    var calls = 0;
    final notifier = SyncRouteNotifier.instance;
    notifier.debugStatsLoader = (queries) async {
      calls++;
      return _allWith(_sample);
    };

    void listener() {}
    notifier.addListener(listener);
    await notifier.refreshStats();
    final before = calls;

    await _sendLifecycle(tester, 'AppLifecycleState.paused');
    await tester.pump();
    await _sendLifecycle(tester, 'AppLifecycleState.resumed');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(calls, greaterThan(before), reason: '回前台要立刻刷新，否则最长要等一个周期');

    // 收尾：移除订阅 → 停掉轮询（否则测试结束时会因为 Timer 还挂着而失败）
    notifier.removeListener(listener);
    expect(notifier.debugPollingActive, isFalse);
  });

  testWidgets('后台期间不轮询（省电也省连接）', (tester) async {
    SyncRouteNotifier.debugStatsRefreshInterval =
        const Duration(milliseconds: 40);
    var calls = 0;
    final notifier = SyncRouteNotifier.instance;
    notifier.debugStatsLoader = (queries) async {
      calls++;
      return _allWith(_sample);
    };

    void listener() {}
    notifier.addListener(listener);
    await _sendLifecycle(tester, 'AppLifecycleState.paused');
    await tester.pump();
    final afterPause = calls;

    // 在「后台」待够好几个周期
    await tester.pump(const Duration(milliseconds: 300));
    expect(calls, afterPause, reason: '切到后台就不该继续拉统计');

    notifier.removeListener(listener);
  });
}
