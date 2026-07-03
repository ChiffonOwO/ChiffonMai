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

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  /// 从 SharedPreferences 加载主题偏好
  Future<void> loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(CacheKeyConstant.themeMode) ?? 'light';
      _themeMode = _parseThemeMode(value);
      notifier.value = _themeMode;
      _isLoaded = true;
    } catch (e) {
      debugPrint('加载主题偏好失败: $e');
      _themeMode = ThemeMode.light;
      notifier.value = ThemeMode.light;
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
