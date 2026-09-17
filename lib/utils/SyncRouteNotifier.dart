import 'package:flutter/foundation.dart';

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
///   * **统计**：4 个组合只拉一次，谁先加载完另一边直接复用。
class SyncRouteNotifier extends ChangeNotifier {
  SyncRouteNotifier._();

  static final SyncRouteNotifier instance = SyncRouteNotifier._();

  int _divingFishRoute = SyncRouteStore.routeScoreHub;
  int _luoXueRoute = SyncRouteStore.routeScoreHub;

  /// key = `'<lineKey>:<platformKey>'`（见 [SyncStatsService.keyFor]）。
  Map<String, SyncStats?> _stats = const {};

  bool _statsLoading = false;
  bool _statsLoaded = false;
  bool _loading = false;
  bool _loaded = false;

  /// 是否已经读过一次 prefs。
  bool get isLoaded => _loaded;

  /// 统计是否正在加载（首次加载与手动刷新都算）。
  bool get statsLoading => _statsLoading;

  /// 某平台的当前线路（[SyncRouteStore.routeScoreHub] / [SyncRouteStore.routeAwmc]）。
  int routeOf(SyncPlatform platform) =>
      platform == SyncPlatform.divingFish ? _divingFishRoute : _luoXueRoute;

  /// 某平台**当前所选线路**的统计；Redis 不可用时为 null（UI 显示「统计不可用」）。
  SyncStats? statsFor(SyncPlatform platform) {
    final line = routeOf(platform) == SyncRouteStore.routeAwmc
        ? SyncLine.awmc
        : SyncLine.scoreHub;
    return _stats['${line.key}:${platform.key}'];
  }

  /// 某个「线路 + 平台」组合的统计（详情弹窗用）。
  SyncStats? statsOf(SyncLine line, SyncPlatform platform) =>
      _stats['${line.key}:${platform.key}'];

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

  /// 拉取 4 个组合的统计（一次 Redis 连接）。
  Future<void> refreshStats() async {
    if (_statsLoading) return;
    _statsLoading = true;
    notifyListeners();
    try {
      final queries = <(SyncLine, SyncPlatform)>[
        for (final line in SyncLine.values)
          for (final platform in SyncPlatform.values) (line, platform),
      ];
      final loader = debugStatsLoader;
      _stats = loader != null
          ? await loader(queries)
          : await SyncStatsService.loadMany(queries);
      _statsLoaded = true;
    } catch (e) {
      debugPrint('[SyncRoute] 统计加载失败: $e');
    } finally {
      _statsLoading = false;
      notifyListeners();
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
    debugStatsLoader = null;
  }
}
