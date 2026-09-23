import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../service/History/ChartHistoryCore.dart';
import '../../service/History/ChartHistoryStore.dart';
import '../../utils/AppTheme.dart';
import '../../utils/CommonWidgetUtil.dart';
import '../../utils/CurrentDataSourceNotifier.dart';
import '../../widgets/HistoryLineChart.dart';
import '../../widgets/PageTopBar.dart';

/// Rating 历史曲线。
///
/// 数据来自本机采集（`ChartHistoryStore`）：每次「刷新数据」拿到成绩、以及每次
/// 落盘 Rating 时，顺手记一笔；同一天只留一个点（以当天最后一次为准）。
///
/// ⚠️ 一个必须说清楚的事实：**没有任何公开接口能回填历史**。
/// 水鱼/落雪只给"当前成绩"，所以这条曲线只能从「开始记录」那天算起 ——
/// 页面上要如实写明起始日，别让用户以为数据丢了。
class RatingHistoryPage extends StatefulWidget {
  const RatingHistoryPage({super.key});

  @override
  State<RatingHistoryPage> createState() => _RatingHistoryPageState();
}

class _RatingHistoryPageState extends State<RatingHistoryPage> {
  /// 0 = 全部。
  int _rangeDays = 90;

  bool _loading = true;
  List<RatingPoint> _all = const [];
  ChartHistorySummary? _summary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final series = await ChartHistoryStore.instance.ratingSeries();
      final summary = await ChartHistoryStore.instance.summary();
      if (!mounted) return;
      setState(() {
        _all = series;
        _summary = summary;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[RatingHistory] 读取失败: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// 按时间范围裁剪（0 = 全部）。
  List<RatingPoint> get _visible {
    if (_rangeDays <= 0 || _all.isEmpty) return _all;
    final cutoff = DateTime.now()
        .subtract(Duration(days: _rangeDays))
        .millisecondsSinceEpoch;
    final filtered =
        _all.where((p) => p.tMs >= cutoff).toList(growable: false);
    // 范围里只剩一个点时，把范围前最后一个点也带上，曲线才有起点可比
    if (filtered.length == 1) {
      final idx = _all.indexOf(filtered.first);
      if (idx > 0) return [ _all[idx - 1], filtered.first ];
    }
    return filtered.isEmpty ? _all.sublist(_all.length - 1) : filtered;
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          CommonWidgetUtil.buildCommonBgWidget(),
          CommonWidgetUtil.buildCommonChiffonBgWidget(context),
          Column(
            children: [
              const PageTopBar(title: 'Rating 历史'),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  child: _loading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 80),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildSourceBar(brightness),
                            const SizedBox(height: 12),
                            if (_all.isEmpty)
                              _buildEmpty(brightness)
                            else ...[
                              _buildRangeSelector(),
                              const SizedBox(height: 12),
                              _buildStatsRow(brightness),
                              const SizedBox(height: 12),
                              _buildChartCard(brightness),
                              const SizedBox(height: 12),
                              _buildPointList(brightness),
                            ],
                          ],
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSourceBar(Brightness brightness) {
    final source = CurrentDataSourceNotifier.instance.value;
    final summary = _summary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground(brightness),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline_rounded,
                  size: 16, color: AppColors.primaryText(brightness)),
              const SizedBox(width: 6),
              Text(
                '当前数据源：${source.displayName}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryText(brightness),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (summary != null && summary.chartCount > 0)
            Text(
              '已记录 ${summary.chartCount} 张谱面的成绩基线'
              ' · ${summary.eventCount} 次成绩变化'
              '（曲目详情页里，单谱的达成率 / DX 曲线就画在这些变化上）',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.secondaryText(brightness),
              ),
            ),
          const SizedBox(height: 4),
          Text(
            '水鱼 / 落雪 各记各的历史，切换账号不会串。'
            '${summary?.firstRecordedText ?? ''}'
            '（历史只能从现在开始攒：水鱼与落雪都不提供历史成绩接口）',
            style: TextStyle(
              fontSize: 11.5,
              color: AppColors.secondaryText(brightness),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeSelector() {
    const options = <int, String>{30: '近 30 天', 90: '近 90 天', 0: '全部'};
    return Row(
      children: [
        for (final entry in options.entries)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(entry.value, style: const TextStyle(fontSize: 12)),
              selected: _rangeDays == entry.key,
              onSelected: (_) => setState(() => _rangeDays = entry.key),
            ),
          ),
      ],
    );
  }

  Widget _buildStatsRow(Brightness brightness) {
    final visible = _visible;
    if (visible.isEmpty) return const SizedBox.shrink();
    final current = visible.last;
    final best = visible.reduce((a, b) => a.rating >= b.rating ? a : b);
    final delta = visible.length >= 2
        ? visible.last.rating - visible.first.rating
        : 0;

    Widget cell(String label, String value, {Color? color}) => Expanded(
          child: Column(
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.secondaryText(brightness))),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color ?? AppColors.primaryText(brightness),
                  )),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground(brightness),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          cell('当前', '${current.rating}'),
          cell('最高', '${best.rating}'),
          cell(
            _rangeDays == 0 ? '总变化' : '近 $_rangeDays 天',
            '${delta >= 0 ? '+' : ''}$delta',
            color: delta > 0
                ? AppColors.successGreen(brightness)
                : (delta < 0 ? AppColors.errorRed(brightness) : null),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(Brightness brightness) {
    final visible = _visible;

    if (visible.length < 2) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardBackground(brightness),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(Icons.show_chart_rounded,
                size: 36, color: AppColors.greyHint(brightness)),
            const SizedBox(height: 8),
            Text(
              '目前只有 1 个记录点，再刷新一次成绩就能看到曲线',
              style: TextStyle(
                  fontSize: 13, color: AppColors.secondaryText(brightness)),
            ),
          ],
        ),
      );
    }

    final firstMs = visible.first.tMs;
    const dayMs = 24 * 3600 * 1000;
    double x(RatingPoint p) => (p.tMs - firstMs) / dayMs;

    final ratings = visible.map((p) => p.rating).toList();
    final minR = ratings.reduce((a, b) => a < b ? a : b).toDouble();
    final maxR = ratings.reduce((a, b) => a > b ? a : b).toDouble();
    // 范围与刻度都对齐到整数档，避免轴上出现 16956 这种读数
    final axis = niceAxisRange(minR, maxR);

    final spots = [for (final p in visible) FlSpot(x(p), p.rating.toDouble())];
    final bestIdx =
        visible.indexWhere((p) => p.rating == ratings.reduce((a, b) => a > b ? a : b));

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground(brightness),
        borderRadius: BorderRadius.circular(10),
      ),
      child: HistoryLineChart(
        spots: spots,
        height: 220,
        minY: axis.min,
        maxY: axis.max,
        leftInterval: axis.interval,
        highlightIndex: bestIdx,
        interval: (x(visible.last) / 3).clamp(1, 9999),
        bottomLabel: (value) {
          final ms = firstMs + (value * dayMs).round();
          final d = DateTime.fromMillisecondsSinceEpoch(ms);
          return '${d.month}/${d.day}';
        },
        tooltipLabel: (index) {
          final p = visible[index.clamp(0, visible.length - 1)];
          final d = DateTime.fromMillisecondsSinceEpoch(p.tMs);
          return '${d.year}/${d.month}/${d.day}\n'
              'Rating ${p.rating}'
              '${p.best35 > 0 ? '\nB35 ${p.best35} / B15 ${p.best15}' : ''}';
        },
      ),
    );
  }

  Widget _buildPointList(Brightness brightness) {
    final visible = _visible.reversed.toList(growable: false);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground(brightness),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('记录点',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryText(brightness))),
          const SizedBox(height: 8),
          for (final p in visible.take(30))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 84,
                    child: Text(
                      _formatDate(p.tMs),
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.secondaryText(brightness)),
                    ),
                  ),
                  SizedBox(
                    width: 56,
                    child: Text('${p.rating}',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryText(brightness))),
                  ),
                  // 窄屏（360dp）上这一行会被挤爆，必须让它可省略而不是溢出
                  Expanded(
                    child: Text(
                      p.best35 > 0 ? 'B35 ${p.best35} / B15 ${p.best15}' : '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.secondaryText(brightness)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmpty(Brightness brightness) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground(brightness),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(Icons.insights_rounded,
              size: 42, color: AppColors.greyHint(brightness)),
          const SizedBox(height: 12),
          Text(
            '还没有历史数据',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryText(brightness)),
          ),
          const SizedBox(height: 8),
          Text(
            '每次「刷新数据」都会顺手记一笔，不需要额外操作。\n'
            '同一天只保留一个点（以当天最后一次为准），所以一天里刷几次不会把曲线弄乱。',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12.5, color: AppColors.secondaryText(brightness)),
          ),
        ],
      ),
    );
  }

  static String _formatDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}/${two(d.month)}/${two(d.day)}';
  }
}
