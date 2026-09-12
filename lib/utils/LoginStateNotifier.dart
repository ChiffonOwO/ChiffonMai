import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constant/CacheKeyConstant.dart';

/// 水鱼账号登录态：跨页面共享的实时状态。
///
/// 所有页面（首页 / 我的页 / 分类页等）通过 [LoginStateNotifier.instance]
/// 监听同一个 ValueNotifier，因此登录 / 登出后各处按钮（"登录水鱼" ↔ "登出账号"）
/// 的 UI 能够即时切换。
class LoginStateNotifier {
  static final ValueNotifier<bool> instance = ValueNotifier<bool>(false);

  /// 从 SharedPreferences 加载登录状态（应用启动时调用一次）。
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jwt = prefs.getString(CacheKeyConstant.probeDivingFishToken) ?? '';
    _publish(jwt.isNotEmpty);
  }

  /// 主动覆盖当前内存中的登录状态（一般在写入 / 清除 JWT 之后调用）。
  static void setLoggedIn(bool value) {
    _publish(value);
  }

  static void _publish(bool next) {
    if (instance.value != next) {
      instance.value = next;
    }
  }
}