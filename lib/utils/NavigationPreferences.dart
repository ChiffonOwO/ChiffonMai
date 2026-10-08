import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主导航栏的交互偏好。
///
/// 由 AppShell 和首页设置弹窗共同监听，保证修改后
/// 不需要重启应用就能立即看到效果。
class NavigationPreferences extends ChangeNotifier {
  NavigationPreferences._();

  static final NavigationPreferences instance = NavigationPreferences._();

  static const _transitionKey = 'navigation_transition_enabled';
  static const _swipeKey = 'navigation_swipe_enabled';

  bool _transitionEnabled = true;
  bool _swipeEnabled = true;
  bool _loaded = false;

  bool get transitionEnabled => _transitionEnabled;
  bool get swipeEnabled => _swipeEnabled;
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _transitionEnabled = prefs.getBool(_transitionKey) ?? true;
      _swipeEnabled = prefs.getBool(_swipeKey) ?? true;
    } catch (_) {
      // 读取失败时保留默认值，不影响主界面启动。
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> setTransitionEnabled(bool value) async {
    _transitionEnabled = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_transitionKey, value);
    } catch (_) {
      // 内存中的开关仍然生效，下次启动会回到默认值。
    }
  }

  Future<void> setSwipeEnabled(bool value) async {
    _swipeEnabled = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_swipeKey, value);
    } catch (_) {
      // 内存中的开关仍然生效，下次启动会回到默认值。
    }
  }
}
