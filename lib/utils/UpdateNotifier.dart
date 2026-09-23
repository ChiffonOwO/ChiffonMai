/*
 * 「有没有新版本」的全局状态。
 *
 * 由来：需求要求「App 进入时检查到更新，就把系统页的『检查更新』按钮变成
 * 『发现新版本』并加绿色圆环箭头」。
 *
 * 为什么需要一个独立的 notifier，而不是让 `SystemHubPage` 自己查一次：
 *   1. 系统页在 `IndexedStack` 里，**首次切到该 tab 之前不会 initState**，
 *      而「进入 App 时检查」的时机远早于此 —— 页面起来时必须能直接读到结果；
 *   2. 首页也会查更新（`HomePage._autoCheckUpdate`），两边各查一次会白打网络
 *      （已在 `LZYCheckUpdateManager.checkUpdate` 里做了请求去重）。
 *
 * 所以：`main.dart` 启动时查一次并写入这里，任何页面监听它即可。
 */
import 'package:flutter/foundation.dart';

/// 一次更新检查的结果（只保留 UI 需要的字段）。
@immutable
class UpdateAvailability {
  /// 云端最新版本号，如 `2.1.0`。
  final String latestVersion;

  /// 云端最新 build 号。
  final int latestBuild;

  /// 更新说明（可能很长，UI 需要自己滚动/截断）。
  final String updateLog;

  const UpdateAvailability({
    required this.latestVersion,
    required this.latestBuild,
    required this.updateLog,
  });

  /// 从 `LZYCheckUpdateManager.checkUpdate()` 的返回 Map 构造。
  /// 没有更新（或检查失败）时返回 null。
  static UpdateAvailability? fromCheckResult(Map<String, dynamic> info) {
    if (info['hasUpdate'] != true) return null;
    return UpdateAvailability(
      latestVersion: '${info['latestVersion'] ?? ''}',
      latestBuild: info['latestBuild'] is int
          ? info['latestBuild'] as int
          : int.tryParse('${info['latestBuild']}') ?? 0,
      updateLog: '${info['updateLog'] ?? ''}',
    );
  }
}

class UpdateNotifier {
  UpdateNotifier._();

  /// 有可用更新时非 null。UI 监听它来切换按钮形态。
  static final ValueNotifier<UpdateAvailability?> available =
      ValueNotifier<UpdateAvailability?>(null);

  /// 本次会话是否已经查过一次（避免重复查；结果为「无更新」时也要记住）。
  static bool get checked => _checked;
  static bool _checked = false;

  static void setResult(Map<String, dynamic>? info) {
    _checked = true;
    available.value = info == null ? null : UpdateAvailability.fromCheckResult(info);
  }

  /// 仅供测试：复位。
  @visibleForTesting
  static void debugReset() {
    _checked = false;
    available.value = null;
  }

  // ── 按钮形态 ────────────────────────────────────────────────────────────
  //
  // 「检查更新」这个入口在 App 里有 3 个渲染点（系统 Hub 页 / 首页「收藏的功能」
  // 列表 / 分类页的功能网格），形态必须一致。文案集中在这里，
  // 避免以后改文案要同时改三处。

  /// 无更新时的按钮标题。**收藏列表里存的名字也是它**，所以不要改。
  static const String idleTitle = '检查更新';

  /// 无更新时的按钮副标题。
  static const String idleSubtitle = '检查应用是否有新版本';

  /// 有更新时这个条目的**显示标题**。
  static String titleFor(UpdateAvailability? update) =>
      update == null ? idleTitle : '发现新版本';

  /// 有更新时这个条目的**显示副标题**（带最新版本号）。
  static String subtitleFor(UpdateAvailability? update, String fallback) {
    if (update == null) return fallback;
    final version =
        update.latestVersion.isEmpty ? '新版本' : 'v${update.latestVersion}';
    return '$version 已发布，点击查看更新内容';
  }

  /// 这个名字是不是「检查更新」入口。
  ///
  /// 收藏列表里存的是 [idleTitle]，所以按钮标题已经变成「发现新版本」之后，
  /// 仍然要用这个名字去匹配收藏项。
  static bool isUpdateEntry(String? title) => title == idleTitle;
}
