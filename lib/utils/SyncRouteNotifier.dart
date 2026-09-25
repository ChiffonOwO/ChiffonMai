import 'dart:async';

import 'package:flutter/widgets.dart';

import '../service/SyncRouteStore.dart';
import '../service/SyncStatsService.dart';

/// 「同步成绩到水鱼 / 落雪」这两个入口的**共享状态**：当前线路 + 近 100 次统计。
///
/// 为什么要有它：这两个入口会同时出现在「系统」hub 页和首页的「收藏的功能」区，
/// 如果各自持一份 `int _route` 与 `Map _stats`，用户在一边切了线路、另一边还显示
/// 旧值（甚至按旧线路执行），统计也要各拉一遍。
/// 收敛到这里之后：
///   * **线路**：内存里只有一份，落盘仍走 [SyncRouteStore]（同一套 prefs 键），
///     两个页面读写同一份记忆；
///   * **统计**：所有槽位（[SyncStatsService.allSlots]，含 AWMC NET 二维码直传）
///     只拉一次，谁先加载完另一边直接复用。
///
/// 统计是**所有使用者共享**的聚合（Redis 里近 100 次），别处的同步随时会改变它，
/// 所以这里还会**定时重拉**把 UI 刷新到最新：
///   * 有 UI 订阅时才轮询（[addListener] 启动、最后一个 [removeListener] 停掉），
///     没人看就不连 Redis；
///   * 间隔 [statsRefreshInterval]（默认 60s）；
///   * 回到前台**立刻**重拉一次，不必等下一个周期；
///   * 轮询是**静默**的：不会让那一行每隔一分钟闪一次「统计加载中…」；
///   * 整批拉取失败时**保留上一次的好数据**（只标记「这次没刷上」），
///     不能因为一次抖动就把已经显示出来的数字降级成「统计不可用」。
class SyncRouteNotifier extends ChangeNotifier {
  SyncRouteNotifier._();

  static final SyncRouteNotifier instance = SyncRouteNotifier._();

  /// 统计轮询间隔。
  ///
  /// 60s：这组数字是「近 100 次」的聚合，本来就不会秒级变化；而每次拉取都要
  /// 开一条 Redis 连接，再密并不划算。要调就改这一个常量。
  static const Duration statsRefreshInterval = Duration(seconds: 60);

  /// 仅供测试：覆盖轮询间隔（null = 用 [statsRefreshInterval]）。
  @visibleForTesting
  static Duration? debugStatsRefreshInterval;

  /// 仅供测试：置 true 后不再启动轮询。
  ///
  /// 需要它是因为 `testWidgets` 在测试结束时会因为「还有 Timer 挂着」而失败，
  /// 而只读一行统计的 widget 测试不该被迫去管轮询。
  @visibleForTesting
  static bool debugDisableStatsPolling = false;

  int _divingFishRoute = SyncRouteStore.routeScoreHub;
  int _luoXueRoute = SyncRouteStore.routeScoreHub;

  /// key = `'<lineKey>:<platformKey>'`（见 [SyncStatsService.keyFor]）。
  Map<String, SyncStats?> _stats = const {};

  bool _statsLoading = false;
  bool _statsLoaded = false;
  bool _loading = false;
  bool _loaded = false;

  Timer? _statsTimer;
  AppLifecycleListener? _lifecycle;

  /// App 是否在前台（后台不轮询：既省电也省连接）。
  bool _appActive = true;

  /// 上一次**成功**拉到统计的时间（毫秒；0 = 还没成功过）。
  int _statsUpdatedAtMs = 0;

  /// 最近一次拉取是否整批失败（UI 可据此提示「刚才是旧数据」）。
  bool _statsRefreshFailed = false;

  /// 是否已经读过一次 prefs。
  bool get isLoaded => _loaded;

  /// 统计是否正在加载（首次加载与手动刷新都算；静默轮询不算）。
  bool get statsLoading => _statsLoading;

  /// 上一次成功拉取的时间（毫秒；0 = 还没成功过）。
  int get statsUpdatedAtMs => _statsUpdatedAtMs;

  /// 最近一次拉取是否失败（失败时会保留上一次的数据）。
  bool get statsRefreshFailed => _statsRefreshFailed;

  /// 数据新鲜度的可读文案，例如「刚刚 / 12 秒前 / 3 分钟前」。
  String get statsAgeText {
    if (_statsUpdatedAtMs <= 0) return '尚未更新';
    final seconds =
        (DateTime.now().millisecondsSinceEpoch - _statsUpdatedAtMs) ~/ 1000;
    if (seconds < 5) return '刚刚更新';
    if (seconds < 60) return '$seconds 秒前更新';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '$minutes 分钟前更新';
    return '${minutes ~/ 60} 小时前更新';
  }

  /// 仅供测试：轮询是否正在跑。
  @visibleForTesting
  bool get debugPollingActive => _statsTimer != null;

  // ==================== 轮询的启停 ====================

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    // 有人在看统计了 → 开始定时刷新
    _startStatsPolling();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    // 没人看了 → 停掉，别在后台空转连 Redis
    if (!hasListeners) _stopStatsPolling();
  }

  void _startStatsPolling() {
    if (debugDisableStatsPolling) return;
    if (_statsTimer != null) return;

    _attachLifecycleListener();
    final interval = debugStatsRefreshInterval ?? statsRefreshInterval;
    _statsTimer = Timer.periodic(interval, (_) {
      if (!_appActive || !hasListeners) return;
      // 静默：不要把已经显示出来的数字换成「统计加载中…」
      unawaited(refreshStats(silent: true));
    });
  }

  void _stopStatsPolling() {
    _statsTimer?.cancel();
    _statsTimer = null;
  }

  void _attachLifecycleListener() {
    if (_lifecycle != null) return;
    try {
      _lifecycle = AppLifecycleListener(
        onStateChange: (state) {
          switch (state) {
            case AppLifecycleState.resumed:
              // 回前台立刻拉一次：不然最长要等一个完整周期，数字还是旧的
              _appActive = true;
              if (hasListeners) unawaited(refreshStats(silent: true));
              break;
            case AppLifecycleState.inactive:
            case AppLifecycleState.hidden:
            case AppLifecycleState.paused:
            case AppLifecycleState.detached:
              _appActive = false;
              break;
          }
        },
      );
    } catch (e) {
      // 纯 Dart 单测里没有 WidgetsBinding，创建不了生命周期监听：
      // 退化成「一直轮询」，不影响生产行为
      debugPrint('[SyncRoute] 生命周期监听不可用（忽略）: $e');
    }
  }

  /// 某平台的当前线路（[SyncRouteStore.routeScoreHub] / [SyncRouteStore.routeAwmc]）。
  ///
  /// ⚠️ **没有线路可选的平台**（[SyncPlatform.awmc] 只有二维码直传）会抛
  /// [ArgumentError]：与其悄悄返回「落雪那条线路」这种错值，不如当场叫停 ——
  /// 给 AWMC NET 画线路切换器本身就是调用方的 bug。
  int routeOf(SyncPlatform platform) => switch (platform) {
        SyncPlatform.divingFish => _divingFishRoute,
        SyncPlatform.luoXue => _luoXueRoute,
        SyncPlatform.awmc => throw ArgumentError.value(
            platform,
            'platform',
            'AWMC NET 只有二维码直传，没有线路可选（统计槽位见 SyncLine.direct）',
          ),
      };

  /// 平台对应的**统计线路**。
  ///
  /// 水鱼 / 落雪看用户选的线路；AWMC NET 恒为 [SyncLine.direct]。
  SyncLine lineOf(SyncPlatform platform) {
    if (platform == SyncPlatform.awmc) return SyncLine.direct;
    return routeOf(platform) == SyncRouteStore.routeAwmc
        ? SyncLine.awmc
        : SyncLine.scoreHub;
  }

  /// 某平台**当前所选线路**的统计；Redis 不可用时为 null（UI 显示「统计不可用」）。
  SyncStats? statsFor(SyncPlatform platform) =>
      statsOf(lineOf(platform), platform);

  /// 某个「线路 + 平台」组合的统计（详情弹窗用）。
  SyncStats? statsOf(SyncLine line, SyncPlatform platform) =>
      _stats[SyncStatsService.slotOf(line, platform)];

  /// 首次进入时调用：读线路 + 拉统计。重复调用安全（幂等）。
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    if (_loading) return;
    _loading = true;
    try {
      _divingFishRoute = await SyncRouteStore.load(isDivingFish: true);
      _luoXueRoute = await SyncRouteStore.load(isDivingFish: false);
      _loaded = true;
      notifyListeners();
      await refreshStats();
    } finally {
      _loading = false;
    }
  }

  /// 切换线路并落盘（两个页面共用，谁切都生效）。
  Future<void> setRoute(SyncPlatform platform, int route) async {
    // 先在这儿拦一道：给没有线路的平台切线路是调用方 bug，
    // 别等落盘了才发现记了个永远不会被读到的值。
    if (platform == SyncPlatform.awmc) {
      throw ArgumentError.value(
        platform,
        'platform',
        'AWMC NET 只有二维码直传，不需要线路',
      );
    }
    if (platform == SyncPlatform.divingFish) {
      _divingFishRoute = route;
    } else {
      _luoXueRoute = route;
    }
    notifyListeners();
    try {
      await SyncRouteStore.save(
        isDivingFish: platform == SyncPlatform.divingFish,
        route: route,
      );
    } catch (e) {
      debugPrint('[SyncRoute] 保存线路失败: $e');
    }
  }

  /// 拉取全部槽位的统计（一次 Redis 连接）。
  ///
  /// [silent] = true 时是**定时轮询**用的静默刷新：不改「加载中」状态、
  /// 不提前 notify，只在数据真正回来后刷一次 UI —— 否则那一行会每隔一分钟
  /// 闪一下「统计加载中…」。
  Future<void> refreshStats({bool silent = false}) async {
    if (_statsLoading) return;
    if (!silent) {
      _statsLoading = true;
      notifyListeners();
    }
    try {
      final queries = SyncStatsService.allSlots;
      final loader = debugStatsLoader;
      final next = loader != null
          ? await loader(queries)
          : await SyncStatsService.loadMany(queries);
      _applyStats(next);
    } catch (e) {
      debugPrint('[SyncRoute] 统计加载失败: $e');
      _statsRefreshFailed = true;
    } finally {
      _statsLoading = false;
      notifyListeners();
    }
  }

  /// 写入新拉到的统计。
  ///
  /// 关键取舍：**整批为 null 视为「这次没拉到」**，此时保留上一次的好数据。
  /// 否则一次网络抖动就会把已经显示出来的「平均 12.3s / 成功 96%」
  /// 降级成「统计不可用」—— 那比显示旧数字更糟（用户会以为统计坏了）。
  void _applyStats(Map<String, SyncStats?> next) {
    final hasAnyValue = next.values.any((s) => s != null);
    final hadData = _stats.values.any((s) => s != null);

    if (!hasAnyValue && hadData) {
      // 之前有数据、这次整批失败：留着旧值，只标记「刚才是旧数据」
      _statsRefreshFailed = true;
      debugPrint('[SyncRoute] 统计刷新失败，保留上一次的数据（$_statsUpdatedAtMs）');
      return;
    }

    _stats = next;
    // 跑完一次就算「加载过」（哪怕是空结果）：详情弹窗据此决定要不要转圈
    _statsLoaded = true;
    _statsRefreshFailed = !hasAnyValue;
    if (hasAnyValue) {
      _statsUpdatedAtMs = DateTime.now().millisecondsSinceEpoch;
    }
  }

  /// 同步刚结束：等 Redis 写入落地再刷新，避免刚同步完还显示旧数字。
  void refreshStatsSoon() {
    Future.delayed(const Duration(milliseconds: 1200), () {
      refreshStats();
    });
  }

  /// 是否已成功拉过统计（详情弹窗据此决定要不要先转圈）。
  bool get statsLoaded => _statsLoaded;

  /// 仅供测试：注入统计数据（跳过 Redis）。
  @visibleForTesting
  void debugSetStats(Map<String, SyncStats?> stats) {
    _stats = stats;
    _statsLoaded = true;
    notifyListeners();
  }

  /// 仅供测试：替换统计读取实现，避免单测真的去连 Redis。
  ///
  /// 为 null 时走 [SyncStatsService.loadMany]（生产路径）。
  @visibleForTesting
  Future<Map<String, SyncStats?>> Function(
    List<(SyncLine, SyncPlatform)> queries,
  )? debugStatsLoader;

  /// 仅供测试：把线路与加载标志复位（不动 prefs）。
  @visibleForTesting
  void debugResetForTest() {
    _divingFishRoute = SyncRouteStore.routeScoreHub;
    _luoXueRoute = SyncRouteStore.routeScoreHub;
    _stats = const {};
    _statsLoading = false;
    _statsLoaded = false;
    _loading = false;
    _loaded = false;
    _statsUpdatedAtMs = 0;
    _statsRefreshFailed = false;
    _appActive = true;
    _stopStatsPolling();
    _lifecycle?.dispose();
    _lifecycle = null;
    debugStatsLoader = null;
    debugStatsRefreshInterval = null;
    debugDisableStatsPolling = false;
  }
}
