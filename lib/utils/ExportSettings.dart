import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 导出相关的常量。
///
/// **收藏夹导出后缀是固定的 `.cmf`，不提供用户自定义。**
///
/// 历史：早期版本允许用户在设置页把它改成任意后缀（`export_favorite_extension`）。
/// 这个口子的问题很严重 —— 用户一旦把后缀改成 `.json` / `.zip` / `.png` / `.txt`
/// 这类**常见后缀**，系统就会把「用本 App 打开该类型文件」记成默认/首要备选，
/// 等于**劫持了这些后缀的打开方式**：之后在文件管理器里点任何一个 `.json`，
/// 弹出来的首选都是 ChiffonMai，别的 App 反而要点「更多」才找得到。
/// 而 `.cmf` 是本应用专有后缀，不会与任何常见格式冲突，所以固定下来。
///
/// 注意：**导入不受影响**。导入按文件内容（JSON 里的 `format` 字段）识别，
/// 既不校验后缀也不用后缀过滤文件选择器，所以用户以前用自定义后缀导出的
/// 备份文件依然能原样导回来。
class ExportSettings {
  ExportSettings._();

  /// 旧版本存放自定义后缀的 key，**只用于启动时清理**（见 [load]）。
  static const String _legacyKeyFavoriteExtension = 'export_favorite_extension';

  /// 收藏夹导出后缀（不含前导点）：ChiffonMai Favorite。
  static const String favoriteExtension = 'cmf';

  /// 后缀的「带点」形式，例如 `.cmf`。
  static const String favoriteExtensionWithDot = '.$favoriteExtension';

  /// 应用启动时调用一次：把历史版本残留的自定义后缀设置擦掉。
  ///
  /// 后缀现在由代码写死，这个 key 已经没有任何读取方；留着只会让
  /// 「用户设过什么」变成一份永远不生效的幽灵配置，所以启动时顺手删除。
  /// 失败不影响任何功能（读写 SharedPreferences 失败都已经吞掉）。
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_legacyKeyFavoriteExtension)) {
        await prefs.remove(_legacyKeyFavoriteExtension);
        debugPrint('[ExportSettings] 已清理历史遗留的自定义后缀设置');
      }
    } catch (e) {
      debugPrint('[ExportSettings] 清理历史导出设置失败（忽略）: $e');
    }
  }
}
