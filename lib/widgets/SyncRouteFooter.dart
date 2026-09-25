import 'package:flutter/material.dart';

import '../service/SyncStatsService.dart';
import '../utils/SyncRouteNotifier.dart';
import 'SyncRouteSwitcher.dart';
import 'SyncStatsFooter.dart';

/// 「同步成绩到水鱼 / 落雪」入口下方的统一附加区：**线路切换 + 近 100 次统计**。
///
/// 「系统」hub 页与首页「收藏的功能」区都用它，组件内部自己订阅
/// [SyncRouteNotifier]，所以：
///   * 两边显示的线路与统计永远一致（同一份内存状态 + 同一套 prefs 键）；
///   * 在哪边切线路，另一边立刻跟着变；
///   * 统计只拉一次，不用两个页面各拉一遍。
///
/// 统计那一行的文案/取数在 [SyncStatsFooter.line]，与 AWMC NET 那个
/// 无线路的页脚共用。
class SyncRouteFooter extends StatelessWidget {
  /// 这个入口对应的平台（水鱼 / 落雪）。
  final SyncPlatform platform;

  /// 同步进行中时置 false：只禁用切换，不隐藏。
  final bool enabled;

  /// 自定义切换回调；不给时直接写 [SyncRouteNotifier]（推荐）。
  final ValueChanged<int>? onRouteChanged;

  const SyncRouteFooter({
    super.key,
    required this.platform,
    this.enabled = true,
    this.onRouteChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SyncRouteNotifier.instance,
      builder: (context, _) {
        final notifier = SyncRouteNotifier.instance;
        final route = notifier.routeOf(platform);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SyncRouteSwitcher(
              value: route,
              enabled: enabled,
              onChanged: onRouteChanged ??
                  (value) => notifier.setRoute(platform, value),
            ),
            const SizedBox(height: 4),
            // 统计跟着**当前线路**走，所以 slot 在这里现算（不能提到 build 外面）
            SyncStatsFooter.line(
              context,
              slot: (notifier.lineOf(platform), platform),
            ),
          ],
        );
      },
    );
  }
}
