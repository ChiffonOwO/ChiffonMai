import 'package:flutter/material.dart';

import '../service/SyncStatsService.dart';

/// 同步统计的展示组件。
///
/// 显示位置（线路1 / 线路2 都有）：
///   * 「系统 → 同步成绩到水鱼 / 落雪」每个 tile 的线路切换器下面一行小字：
///     `近 100 次 · 平均 12.3s · 成功率 96%`，点它打开详情；
///   * 详情弹窗并排比较 4 个组合（线路1/线路2 × 水鱼/落雪）；
///   * 「系统 → AWMC 网关 → 连通性与用量」里也有一行入口。
class SyncStatsView {
  SyncStatsView._();

  /// 一行统计摘要（未加载 / 无数据 / Redis 不可用都有对应文案）。
  ///
  /// 注意**必须够短**：这一行放在 tile footer 里，左边有图标、右边有箭头，
  /// 窄屏（360dp）可用宽度只有 300dp 左右。早先用「·」分隔 + 全角文字会顶出边界，
  /// 所以这里统一用 `/` 分隔并把「近 100 次」压成「近100次」。
  ///
  /// [tooltip] 是长按/悬停才显示的补充信息（例如「12 秒前更新」）——
  /// 统计是定时刷新的，用户需要一个不占地方的办法确认"这数字是刚拉的"。
  static Widget summaryLine(
    BuildContext context, {
    required SyncStats? stats,
    required VoidCallback onTap,
    bool loading = false,
    String? tooltip,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final String text;
    if (loading) {
      text = '统计加载中…';
    } else if (stats == null) {
      text = '统计不可用';
    } else if (!stats.hasData) {
      text = '近100次 / 暂无记录';
    } else {
      text = '近100次 / ${stats.count}样本 / 平均${stats.avgText} / '
          '成功${stats.successRateText}';
    }

    final line = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
        child: Row(
          children: [
            Icon(Icons.insights_outlined, size: 14, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
              ),
            ),
            Icon(Icons.chevron_right, size: 14, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
    if (tooltip == null || tooltip.isEmpty) return line;
    return Tooltip(message: tooltip, child: line);
  }

  /// 详情弹窗：4 个组合的耗时与成功率。
  static Future<void> showDetail(BuildContext context) async {
    final queries = <(SyncLine, SyncPlatform)>[
      for (final line in SyncLine.values)
        for (final platform in SyncPlatform.values) (line, platform),
    ];
    final stats = await SyncStatsService.loadMany(queries);
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('同步统计'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '记录最近 ${SyncStatsService.windowSize} 次同步的耗时与成败'
                  '（所有使用者共享，仅含耗时/成败，不含二维码与账号信息）。',
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                for (final line in SyncLine.values) ...[
                  Text(
                    line.label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  for (final platform in SyncPlatform.values)
                    _row(
                      ctx,
                      platform.label,
                      stats['${line.key}:${platform.key}'],
                    ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  static Widget _row(BuildContext context, String name, SyncStats? stats) {
    final scheme = Theme.of(context).colorScheme;
    final s = stats ?? SyncStats.empty;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(name, style: const TextStyle(fontSize: 12.5)),
          ),
          Expanded(
            child: Text(
              s.hasData
                  ? '平均 ${s.avgText} · 成功率 ${s.successRateText}'
                      '（${s.successCount}/${s.count}）'
                  : (stats == null ? '不可用' : '暂无记录'),
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
          ),
          if (s.hasData)
            Text(
              '最近 ${s.lastText}',
              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}
