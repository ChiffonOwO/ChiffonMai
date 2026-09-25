import 'package:flutter/material.dart';

import '../service/SyncStatsService.dart';
import '../utils/SyncRouteNotifier.dart';
import 'SyncStatsView.dart';

/// **只有「近 100 次统计」**的同步页脚（点它开详情）。
///
/// 与 [SyncRouteFooter] 的区别：这个不带线路切换器，给**没有线路可选**的入口用
/// ——目前的唯一使用者是「同步成绩到 AWMC NET」（机台二维码直传）。
///
/// 取数口径（加载中 / 不可用 / 数据新鲜度 tooltip / 点击开详情）全部收在
/// [line] 里，两个页脚共用一份，免得三套文案在两处各写一遍然后走歪。
class SyncStatsFooter extends StatelessWidget {
  /// 统计行作为 `HubActionTile.footer` 时的**推荐上提量**。
  ///
  /// 两行 tile 的底部本来就空着约 23px（副标题下面那一截），而统计行只有一行
  /// 小字，不收紧的话会显得「离按钮有点远」。按这个值上提后，实测副标题到统计行
  /// 约 15.8px（原来 25.8px）；再大就贴死了，系统字体调大后还会和副标题打架。
  static const double footerLift = 10;

  /// 统计槽位（见 [SyncStatsService.slotOf] / [SyncStatsService.allSlots]）。
  final (SyncLine, SyncPlatform) slot;

  const SyncStatsFooter({super.key, required this.slot});

  /// 统计摘要行本身（**不订阅**，由调用方的 builder 决定何时重建）。
  ///
  /// 单独暴露出来是因为 [SyncRouteFooter] 已经在自己的 `ListenableBuilder` 里
  /// 重建整块了，再嵌一层订阅纯属多余。
  static Widget line(BuildContext context, {required SyncSlot slot}) {
    final notifier = SyncRouteNotifier.instance;
    return SyncStatsView.summaryLine(
      context,
      stats: notifier.statsOf(slot.$1, slot.$2),
      loading: notifier.statsLoading,
      // 长按/悬停看数据新鲜度（那行字本身必须够短，塞不下）
      tooltip: notifier.statsRefreshFailed
          ? '${notifier.statsAgeText} · 上次刷新失败，显示的是旧数据'
          : notifier.statsAgeText,
      onTap: () => SyncStatsView.showDetail(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SyncRouteNotifier.instance,
      builder: (context, _) => line(context, slot: slot),
    );
  }
}
