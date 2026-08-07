import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constant/CacheKeyConstant.dart';

/// 主题状态管理器（单例）
/// 负责主题偏好的持久化与运行时切换
class ThemeManager {
  static final ThemeManager _instance = ThemeManager._internal();
  factory ThemeManager() => _instance;
  ThemeManager._internal();

  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;

  /// 通知 UI 主题变化
  final ValueNotifier<ThemeMode> notifier = ValueNotifier(ThemeMode.light);

  /// 纯黑模式（仅深色模式生效）
  bool _pureBlackEnabled = false;
  bool get pureBlackEnabled => _pureBlackEnabled;

  /// 通知 UI 纯黑模式变化
  final ValueNotifier<bool> pureBlackNotifier = ValueNotifier(false);

  /// 背景覆层不透明度（0.0 ~ 1.0，浅色/深色模式共用）
  /// 浅色模式：白色覆层，数值越高背景越淡，默认 0.55
  /// 深色模式：暗色覆层，数值越高背景越暗
  double _lightOverlayOpacity = 0.55;
  double get lightOverlayOpacity => _lightOverlayOpacity;

  /// 通知 UI 覆层透明度变化
  final ValueNotifier<double> lightOverlayNotifier = ValueNotifier(0.55);

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  /// 从 SharedPreferences 加载主题偏好
  Future<void> loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(CacheKeyConstant.themeMode) ?? 'light';
      _themeMode = _parseThemeMode(value);
      notifier.value = _themeMode;

      _pureBlackEnabled = prefs.getBool(CacheKeyConstant.pureBlackEnabled) ?? false;
      pureBlackNotifier.value = _pureBlackEnabled;

      _lightOverlayOpacity = prefs.getDouble(CacheKeyConstant.lightOverlayOpacity) ?? 0.55;
      lightOverlayNotifier.value = _lightOverlayOpacity;

      _isLoaded = true;
    } catch (e) {
      debugPrint('加载主题偏好失败: $e');
      _themeMode = ThemeMode.light;
      notifier.value = ThemeMode.light;
      _pureBlackEnabled = false;
      pureBlackNotifier.value = false;
      _lightOverlayOpacity = 0.55;
      lightOverlayNotifier.value = 0.55;
      _isLoaded = true;
    }
  }

  /// 设置并持久化主题模式
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifier.value = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(CacheKeyConstant.themeMode, _themeModeToString(mode));
    } catch (e) {
      debugPrint('保存主题偏好失败: $e');
    }
  }

  /// 切换纯黑模式
  Future<void> setPureBlackEnabled(bool enabled) async {
    _pureBlackEnabled = enabled;
    pureBlackNotifier.value = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(CacheKeyConstant.pureBlackEnabled, enabled);
    } catch (e) {
      debugPrint('保存纯黑模式偏好失败: $e');
    }
  }

  /// 设置背景覆层不透明度（浅色/深色模式共用）
  Future<void> setLightOverlayOpacity(double opacity) async {
    _lightOverlayOpacity = opacity.clamp(0.0, 1.0);
    lightOverlayNotifier.value = _lightOverlayOpacity;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(CacheKeyConstant.lightOverlayOpacity, _lightOverlayOpacity);
    } catch (e) {
      debugPrint('保存覆层透明度失败: $e');
    }
  }

  /// 切换主题（浅色 → 暗色 → 跟随系统 → 浅色）
  Future<void> cycleTheme() async {
    switch (_themeMode) {
      case ThemeMode.light:
        await setThemeMode(ThemeMode.dark);
        break;
      case ThemeMode.dark:
        await setThemeMode(ThemeMode.system);
        break;
      case ThemeMode.system:
        await setThemeMode(ThemeMode.light);
        break;
    }
  }

  /// 获取当前主题对应的 Brightness（用于 Apple 体系）
  Brightness get brightness {
    switch (_themeMode) {
      case ThemeMode.dark:
        return Brightness.dark;
      case ThemeMode.light:
        return Brightness.light;
      case ThemeMode.system:
        // 回退到浅色（实际由 MaterialApp 的 themeMode 处理）
        return Brightness.light;
    }
  }

  ThemeMode _parseThemeMode(String value) {
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      case 'light':
        return ThemeMode.light;
    }
    return ThemeMode.light;
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
      case ThemeMode.light:
        return 'light';
    }
  }
}
