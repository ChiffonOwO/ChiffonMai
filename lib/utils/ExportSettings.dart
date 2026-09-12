import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 导出相关的用户偏好（目前只有收藏夹自定义后缀）。
///
/// 用 [ValueNotifier] 暴露，方便设置页做完修改后直接驱动 UI 刷新。
class ExportSettings {
  ExportSettings._();

  static const String _keyFavoriteExtension = 'export_favorite_extension';

  /// 默认后缀：ChiffonMai Favorite。
  static const String defaultFavoriteExtension = 'cmf';

  /// 后缀长度上限（不含前导点）。
  static const int maxExtensionLength = 12;

  /// 当前收藏夹导出后缀（不含前导点，例如 `cmf`）。
  static final ValueNotifier<String> favoriteExtension =
      ValueNotifier<String>(defaultFavoriteExtension);

  static bool _loaded = false;

  /// 从本地读取设置。应用启动时调用一次即可。
  static Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyFavoriteExtension);
      favoriteExtension.value = normalize(raw) ?? defaultFavoriteExtension;
    } catch (e) {
      debugPrint('[ExportSettings] 读取导出设置失败: $e');
      favoriteExtension.value = defaultFavoriteExtension;
    }
    _loaded = true;
  }

  /// 保存后缀。传入非法值时返回 false 且不落盘。
  static Future<bool> setFavoriteExtension(String raw) async {
    final normalized = normalize(raw);
    if (normalized == null) return false;
    favoriteExtension.value = normalized;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyFavoriteExtension, normalized);
      return true;
    } catch (e) {
      debugPrint('[ExportSettings] 保存导出设置失败: $e');
      return false;
    }
  }

  /// 当前后缀的「带点」形式，例如 `.cmf`。
  static String get favoriteExtensionWithDot => '.${favoriteExtension.value}';

  /// 规范化用户输入的后缀；非法时返回 null。
  ///
  /// 规则：去掉前导点与空白 → 小写 → 只允许 `a-z0-9_-` → 长度 1..12。
  /// 这样能挡掉 `../../etc/passwd`、`a/b`、`*` 之类的输入被拼进文件名。
  static String? normalize(String? raw) {
    if (raw == null) return null;
    var value = raw.trim();
    while (value.startsWith('.')) {
      value = value.substring(1);
    }
    value = value.toLowerCase();
    if (value.isEmpty || value.length > maxExtensionLength) return null;
    if (!RegExp(r'^[a-z0-9_-]+$').hasMatch(value)) return null;
    return value;
  }

  /// 后缀是否合法（供设置页做输入校验提示）。
  static bool isValid(String? raw) => normalize(raw) != null;
}
