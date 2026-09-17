import 'package:shared_preferences/shared_preferences.dart';

import '../constant/CacheKeyConstant.dart';

/// 「同步成绩」的线路选择持久化。
///
/// 两个同步入口（水鱼 / 落雪）各自独立记忆：
///   * **线路1** = maimai Score Hub（原有 scorehub 探针流程，走 chiffonmai.cloud）；
///   * **线路2** = AWMC 网关（机台二维码 + `gw_` 令牌直连 api.wmc.pub）。
///
/// 存 prefs，键见 [CacheKeyConstant.syncRouteDivingFish] /
/// [CacheKeyConstant.syncRouteLuoXue]；任何异常都回落到线路1，
/// 因为线路1 是不依赖额外凭据的默认路径。
class SyncRouteStore {
  SyncRouteStore._();

  /// 线路1：maimai Score Hub（scorehub）。
  static const int routeScoreHub = 0;

  /// 线路2：AWMC 网关。
  static const int routeAwmc = 1;

  static String _key({required bool isDivingFish}) => isDivingFish
      ? CacheKeyConstant.syncRouteDivingFish
      : CacheKeyConstant.syncRouteLuoXue;

  /// 读取线路（缺省 / 非法值一律回落到 [routeScoreHub]）。
  static Future<int> load({required bool isDivingFish}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getInt(_key(isDivingFish: isDivingFish));
      return raw == routeAwmc ? routeAwmc : routeScoreHub;
    } catch (_) {
      return routeScoreHub;
    }
  }

  static Future<void> save({
    required bool isDivingFish,
    required int route,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _key(isDivingFish: isDivingFish),
      route == routeAwmc ? routeAwmc : routeScoreHub,
    );
  }

  /// 线路显示名（显示在切换器右侧）。
  static String routeName(int route) =>
      route == routeAwmc ? 'AWMC 网关' : 'maimai Score Hub';
}
