import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主导航栏与系统栏的交互偏好。
///
/// 由 AppShell 和首页设置弹窗共同监听，保证修改后
/// 不需要重启应用就能立即看到效果。
class NavigationPreferences extends ChangeNotifier {
  NavigationPreferences._();

  static final NavigationPreferences instance = NavigationPreferences._();

  static const _transitionKey = 'navigation_transition_enabled';
  static const _swipeKey = 'navigation_swipe_enabled';
  static const _liquidGlassKey = 'navigation_liquid_glass_enabled';
  static const _immersiveStatusBarKey = 'immersive_status_bar_enabled';
  static const _systemUiChannel = MethodChannel('com.example.app/system_ui');

  bool _transitionEnabled = true;
  bool _swipeEnabled = true;
  bool _liquidGlassEnabled = false;
  bool _immersiveStatusBarEnabled = false;
  bool _loaded = false;

  bool get transitionEnabled => _transitionEnabled;
  bool get swipeEnabled => _swipeEnabled;
  bool get liquidGlassEnabled => _liquidGlassEnabled;
  bool get immersiveStatusBarEnabled => _immersiveStatusBarEnabled;
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _transitionEnabled = prefs.getBool(_transitionKey) ?? true;
      _swipeEnabled = prefs.getBool(_swipeKey) ?? true;
      _liquidGlassEnabled = prefs.getBool(_liquidGlassKey) ?? false;
      _immersiveStatusBarEnabled =
          prefs.getBool(_immersiveStatusBarKey) ?? false;
      await applySystemUiMode();
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

  Future<void> setLiquidGlassEnabled(bool value) async {
    if (_liquidGlassEnabled == value) return;
    _liquidGlassEnabled = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_liquidGlassKey, value);
    } catch (_) {
      // 内存中的开关仍然生效，下次启动按已保存的值恢复。
    }
  }

  /// 应用当前的系统栏模式。
  ///
  /// 只隐藏顶部状态栏，保留底部系统导航，避免 immersiveSticky 抢走返回手势。
  /// targetSdk 36 下 Flutter 的 manual 模式不会生效，Android 由原生窗口
  /// 通道单独控制状态栏；其它平台保留原有系统栏行为。
  Future<void> applySystemUiMode() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await _systemUiChannel.invokeMethod<void>(
        'setStatusBarHidden',
        {'hidden': _immersiveStatusBarEnabled},
      );
    } catch (error) {
      debugPrint('[SystemUI] 状态栏模式应用失败：$error');
    }
  }

  Future<void> setImmersiveStatusBarEnabled(bool value) async {
    _immersiveStatusBarEnabled = value;
    notifyListeners();
    await applySystemUiMode();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_immersiveStatusBarKey, value);
    } catch (_) {
      // 内存中的开关仍然生效，下次启动会回到默认值。
    }
  }
}
