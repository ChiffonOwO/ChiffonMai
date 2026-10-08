import 'package:shared_preferences/shared_preferences.dart';

import '../constant/CacheKeyConstant.dart';

/// 「同步成绩」的线路选择持久化。
///
/// 两个同步入口（水鱼 / 落雪）各自独立记忆：
///   * **线路1** = AWMC 网关（机台二维码 + 用户平台凭据，开发者密钥由服务端代理注入）；
///   * **线路2** = maimai Score Hub（原有流程，走 maimai.bakapiano.com）。
///
/// 存 prefs，键见 [CacheKeyConstant.syncRouteDivingFish] /
/// [CacheKeyConstant.syncRouteLuoXue]。读取口径：
///   * 存过 [routeScoreHub]（0）→ 原样返回，**不算「未选」**（老用户的选择）；
///   * 其余（未设置 / 存过 [routeAwmc] / 非法值 / 读异常）→ [routeAwmc]，
///     即默认的线路1 AWMC。
///
/// ⚠️ **整数值的历史包袱**：
///   * [routeScoreHub] = 0、[routeAwmc] = 1 是历史命名（创建时先写 maimai Score Hub）。
///   * 后来的 UI 重排把 AWMC 摆到了「线路1」位置，但**故意没换整数**，否则
///     升级时老用户 prefs 里存的 0/1 会被解释成相反的线路，体验很怪。
///   * 所以"线路1"是显示位（AWMC），[routeAwmc]=1 是它的值。
class SyncRouteStore {
  SyncRouteStore._();

  /// 线路1 位置的底层值：AWMC 网关。
  static const int routeAwmc = 1;

  /// 线路2 位置的底层值：maimai Score Hub。
  static const int routeScoreHub = 0;

  static String _key({required bool isDivingFish}) => isDivingFish
      ? CacheKeyConstant.syncRouteDivingFish
      : CacheKeyConstant.syncRouteLuoXue;

  /// 读取线路：未设置 / 非法值 / 读异常一律回到 [routeAwmc]（线路1 AWMC）。
  ///
  /// ⚠️ **显式存过的 [routeScoreHub]（0）必须原样读回** —— 它是历史合法值
  /// （老用户选过 maimai Score Hub），不能当成「未设置」再默认到 AWMC。
  /// 未选过的新用户（prefs 里没有这个键）才拿到默认的线路1。
  ///
  /// 为什么默认是 AWMC：换过显示位后 AWMC 就是线路1（UI 第一个选项），
  /// 且默认选中第一个选项才不会让新用户看着「高亮在第 2 个」发懵。
  static Future<int> load({required bool isDivingFish}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getInt(_key(isDivingFish: isDivingFish));
      // 0 → maimai Score Hub（历史显式值）；null / 1 / 非法值 → AWMC（默认线路1）。
      return raw == routeScoreHub ? routeScoreHub : routeAwmc;
    } catch (_) {
      return routeAwmc;
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
  ///
  /// 只显示通道名，**不带「线路N · 」前缀**——前缀由切换器上的 segment 自己
  /// 渲染，再拼一份就在右侧重复了。
  static String routeName(int route) =>
      route == routeAwmc ? 'AWMC 网关' : 'maimai Score Hub';
}
