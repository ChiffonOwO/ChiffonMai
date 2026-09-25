import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../service/History/ChartHistoryCore.dart';
import '../service/History/ChartHistoryStore.dart';
import '../utils/AppTheme.dart';
import '../utils/CurrentDataSourceNotifier.dart';
import '../utils/UserProfileNotifier.dart';
import 'HistoryLineChart.dart';

/// 曲目详情页里的「这张谱面的成绩历史」区块（达成率曲线 + DX 曲线）。
///
/// 设计取舍：
///   * **没有历史就完全不占空间**（[SizedBox.shrink]）——它挂在曲目详情页上，
///     而绝大多数谱面在刚开始记录时是没有历史的，不能凭空撑出一块空白；
///   * 只有一条记录时给一行「首次记录 …」，比"什么都不显示"更有意义，
///     也让用户知道这个功能是活的；
///   * **有基线但一次变化都还没有**时给一行「已记录 …，有变化后显示曲线」：
///     成绩取最高值，所以"采集了但没变化"是最常见的初始状态——如果这时什么都不显示，
///     用户会觉得功能不存在（我自己就找不到这张图）。
///   * 两条曲线**切换显示**而不是叠在一张图上：达成率是 4 位小数的百分比、
///     DX 分是整数，量纲差太远，双 Y 轴在手机上读不出来；
///   * DX 分**按占理论满分的比例画**（满分 = 物量 × 3，由调用方传入）：
///     不同谱面的 DX 满分不同，直接画绝对值不可比。
///
/// 三种渲染形态各有一套内边距参数（[emptyPadding] / [textPadding] /
/// [chartPadding]），默认值就是「纯文本贴边、曲线自带间距」的老行为；
/// 曲目详情页把它做成独立卡片（[cardStyle]）时会传入一套卡片用的内边距 ——
/// **不能只给一个统一的 padding**：空形态必须保持 0 高度，否则会在页面上留白。
class ChartHistorySection extends StatefulWidget {
  const ChartHistorySection({
    super.key,
    required this.songId,
    required this.levelIndex,
    this.maxDxScore,
    this.cardStyle = false,
    this.emptyPadding = EdgeInsets.zero,
    this.textPadding = const EdgeInsets.only(top: 8),
    this.chartPadding = const EdgeInsets.only(top: 12),
  });

  final int songId;
  final int levelIndex;

  /// 该难度谱面的 DX 分理论满分（拿不到就退化成画绝对值）。
  final int? maxDxScore;

  /// 是否给整块套一层「卡片」外观（`surface` 底色 + 圆角）。
  ///
  /// 曲目详情页把成绩趋势摆成独立板块时用 `true`，让它在视觉上和其他卡片同一档。
  final bool cardStyle;

  /// 没有任何历史（直接不渲染）时的内边距：**必须是 0**，否则会留白。
  final EdgeInsets emptyPadding;

  /// 只有一行文字（首次记录 / 已记录待变化）时的内边距。
  final EdgeInsets textPadding;

  /// 画出曲线时的内边距（最完整的一种）。
  final EdgeInsets chartPadding;

  @override
  State<ChartHistorySection> createState() => _ChartHistorySectionState();
}

enum _HistoryMetric { achievement, dxScore }

class _ChartHistorySectionState extends State<ChartHistorySection> {
  int _loadGeneration = 0;
  bool _loading = true;
  List<ChartHistoryEvent> _events = const [];
  ChartBaseline? _baseline;
  _HistoryMetric _metric = _HistoryMetric.achievement;

  @override
  void initState() {
    super.initState();
    CurrentDataSourceNotifier.instance.addListener(_onSourceChanged);
    UserProfileNotifier.instance.addListener(_onSourceChanged);
    _load();
  }

  @override
  void dispose() {
    CurrentDataSourceNotifier.instance.removeListener(_onSourceChanged);
    UserProfileNotifier.instance.removeListener(_onSourceChanged);
    super.dispose();
  }

  void _onSourceChanged() {
    if (mounted) _load();
  }

  @override
  void didUpdateWidget(ChartHistorySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 切难度时要重新取这一份历史
    if (oldWidget.songId != widget.songId ||
        oldWidget.levelIndex != widget.levelIndex) {
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    setState(() => _loading = true);
    try {
      final songId = widget.songId;
      final levelIndex = widget.levelIndex;
      final store = ChartHistoryStore.instance;
      final sourceKey = await ChartHistoryStore.storageKey();
      final events =
          await store.chartEvents(songId, levelIndex, sourceKey: sourceKey);
      // 没有事件时才需要基线（用来区分"没记录过"和"记录过但没变化"）
      final baseline = events.isEmpty
          ? await store.chartBaseline(songId, levelIndex, sourceKey: sourceKey)
          : null;
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _events = events;
        _baseline = baseline;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[ChartHistory] 读取谱面历史失败（忽略）: $e');
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _events = const [];
        _baseline = null;
        _loading = false;
      });
    }
  }

  bool get _hasDx => _events.any((e) => e.dxScore > 0);
  int? get _maxDx {
    final max = widget.maxDxScore;
    return (max != null && max > 0) ? max : null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    final brightness = Theme.of(context).brightness;
    if (_events.isEmpty) {
      final base = _baseline;
      // 没记录过这张谱面 → 完全不占空间
      if (base == null) return const SizedBox.shrink();
      // 记录过、但成绩还没变化过 → 给一行，让用户知道功能是活的、曲线在等数据
      final dxText = base.dxScore > 0 ? '，DX ${base.dxScore}' : '';
      final whenText = base.tMs > 0 ? '（${_formatDate(base.tMs)}）' : '';
      return _wrap(
        widget.textPadding,
        Text(
          '成绩历史：已记录 ${base.achievement.toStringAsFixed(4)}%$dxText$whenText，'
          '成绩有变化后这里会显示曲线',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.secondaryText(brightness),
          ),
        ),
      );
    }

    if (_events.length == 1) {
      final only = _events.single;
      return _wrap(
        widget.textPadding,
        Text(
          '成绩历史：首次记录 ${only.achievement.toStringAsFixed(4)}%'
          '（${_formatDate(only.tMs)}）',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.secondaryText(brightness),
          ),
        ),
      );
    }

    final regressed = hasRegression(_events);

    return _wrap(
      widget.chartPadding,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded,
                  size: 15, color: AppColors.secondaryText(brightness)),
              const SizedBox(width: 6),
              Text(
                '成绩历史（${_events.length} 次变化）',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryText(brightness),
                ),
              ),
            ],
          ),
          if (regressed) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 14, color: AppColors.warningOrange(brightness)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '曲线出现下降：游戏里成绩取最高，这多半是切换数据源/账号造成的记录差异',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.warningOrange(brightness)),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          if (_hasDx)
            Row(
              children: [
                _metricChip('达成率', _HistoryMetric.achievement),
                const SizedBox(width: 8),
                _metricChip(
                  _maxDx != null ? 'DX 分（占满分 %）' : 'DX 分',
                  _HistoryMetric.dxScore,
                ),
              ],
            ),
          const SizedBox(height: 8),
          _buildChart(brightness),
          const SizedBox(height: 8),
          _buildChangeList(brightness),
        ],
      ),
    );
  }

  /// 统一套「卡片外观 + 内边距」。
  ///
  /// 只有需要渲染时才包 `surface` 底：`_events.isEmpty && _baseline == null`
  /// 那一支走的是 `SizedBox.shrink()`，**不会经过这里**，所以空形态既没有
  /// 背景也不占高度 —— 这正是详情页把曲线摆成独立卡片时需要的。
  Widget _wrap(EdgeInsets padding, Widget child) {
    if (!widget.cardStyle) {
      return Padding(padding: padding, child: child);
    }
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  Widget _metricChip(String label, _HistoryMetric metric) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11.5)),
      selected: _metric == metric,
      onSelected: (_) => setState(() => _metric = metric),
    );
  }

  Widget _buildChart(Brightness brightness) {
    final maxDx = _maxDx;
    final isAch = _metric == _HistoryMetric.achievement;

    final values = [
      for (final e in _events)
        isAch
            ? e.achievement
            : (maxDx != null ? e.dxScore / maxDx * 100 : e.dxScore.toDouble()),
    ];
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    // 达成率往往只差零点几，从 0 画起等于一条直线；但上下界也不能直接用
    // padded min/max（轴上会出现 98.7 / 101.2），所以对齐到整数档。
    final axis = niceAxisRange(minV, maxV);
    final bestIdx = values.indexOf(maxV);

    return HistoryLineChart(
      height: 170,
      spots: [
        for (var i = 0; i < _events.length; i++)
          FlSpot(i.toDouble(), values[i]),
      ],
      minY: axis.min,
      maxY: axis.max,
      leftInterval: axis.interval,
      highlightIndex: bestIdx,
      interval: (_events.length / 4).clamp(1, 9999),
      bottomLabel: (x) {
        final idx = x.round().clamp(0, _events.length - 1);
        return _formatShortDate(_events[idx].tMs);
      },
      tooltipLabel: (index) {
        final e = _events[index.clamp(0, _events.length - 1)];
        final dxText = maxDx != null
            ? '${e.dxScore} / $maxDx（${(e.dxScore / maxDx * 100).toStringAsFixed(1)}%）'
            : '${e.dxScore}';
        return '${_formatDate(e.tMs)}\n'
            '达成率 ${e.achievement.toStringAsFixed(4)}%\n'
            'DX $dxText';
      },
    );
  }

  Widget _buildChangeList(Brightness brightness) {
    final recent = _events.reversed.take(5).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < recent.length; i++)
          Builder(builder: (context) {
            final e = recent[i];
            // 与更早的一次比较（列表是倒序，所以"更早"是后一个）
            final prev = i + 1 < recent.length ? recent[i + 1] : null;
            final delta =
                prev == null ? null : e.achievement - prev.achievement;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 78,
                    child: Text(
                      _formatDate(e.tMs),
                      style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.secondaryText(brightness)),
                    ),
                  ),
                  Text(
                    '${e.achievement.toStringAsFixed(4)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryText(brightness),
                    ),
                  ),
                  if (delta != null && delta.abs() >= 0.0001) ...[
                    const SizedBox(width: 6),
                    Text(
                      '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(4)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: delta > 0
                            ? AppColors.successGreen(brightness)
                            : AppColors.errorRed(brightness),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }

  static String _formatDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}/${two(d.month)}/${two(d.day)}';
  }

  static String _formatShortDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.month}/${d.day}';
  }
}
