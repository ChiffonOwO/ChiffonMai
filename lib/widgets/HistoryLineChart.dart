import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../utils/AppTheme.dart';

/// 历史曲线的通用画法（Rating 历史页与谱面成绩历史共用）。
///
/// 抽出来的原因：两处的差异只有"数据、标签、是否标最高点"，
/// 而坐标轴/网格/tooltip/圆点这些排版细节**必须一致**（否则同一个 App 里
/// 两张曲线图观感不同，看起来像两个功能）。
class HistoryLineChart extends StatelessWidget {
  const HistoryLineChart({
    super.key,
    required this.spots,
    required this.bottomLabel,
    required this.tooltipLabel,
    this.highlightIndex,
    this.height = 200,
    this.minY,
    this.maxY,
    this.interval,
    this.leftInterval,
  });

  /// 曲线上的点（x 的含义由调用方决定，这里只负责画）。
  final List<FlSpot> spots;

  /// 横轴刻度文案。
  final String Function(double x) bottomLabel;

  /// 触摸某个点时的提示文案（按索引）。
  final String Function(int index) tooltipLabel;

  /// 要特别标出来的点（通常是最高点）。
  final int? highlightIndex;

  final double height;
  final double? minY;
  final double? maxY;

  /// 横轴刻度间隔；null 交给 fl_chart 自己算。
  final double? interval;

  /// 纵轴刻度间隔（配合 [minY]/[maxY] 用整数档，见 niceAxisRange）；null 交给 fl_chart。
  final double? leftInterval;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final scheme = Theme.of(context).colorScheme;
    final highlight = highlightIndex;
    final hasSpots = spots.isNotEmpty;
    final isSingleSpot = spots.length == 1;
    final firstX = hasSpots ? spots.first.x : 0.0;
    final lastX = hasSpots ? spots.last.x : 1.0;
    final chartMinX = isSingleSpot ? firstX - 0.5 : firstX;
    final chartMaxX =
        isSingleSpot ? firstX + 0.5 : (lastX <= firstX ? firstX + 1.0 : lastX);

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: chartMinX,
          maxX: chartMaxX,
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: scheme.outlineVariant.withValues(alpha: 0.4),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 46,
                interval: leftInterval,
                getTitlesWidget: (value, meta) => Text(
                  _trimNumber(value),
                  style: TextStyle(
                      fontSize: 10, color: AppColors.secondaryText(brightness)),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: interval,
                getTitlesWidget: (value, meta) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    bottomLabel(value),
                    style: TextStyle(
                        fontSize: 10,
                        color: AppColors.secondaryText(brightness)),
                  ),
                ),
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => scheme.surfaceContainerHighest,
              getTooltipItems: (touched) => touched.map((spot) {
                var idx = 0;
                var bestDistance = double.infinity;
                for (var i = 0; i < spots.length; i++) {
                  final distance = (spots[i].x - spot.x).abs();
                  if (distance < bestDistance) {
                    bestDistance = distance;
                    idx = i;
                  }
                }
                return LineTooltipItem(
                  tooltipLabel(idx),
                  TextStyle(
                      fontSize: 11.5, color: AppColors.primaryText(brightness)),
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              barWidth: 2.4,
              color: scheme.primary,
              dotData: FlDotData(
                show: true,
                checkToShowDot: (spot, _) =>
                    highlight == null ||
                    spots.length <= 40 ||
                    spot.x == spots[highlight].x,
                getDotPainter: (spot, percent, bar, index) {
                  final isHighlight =
                      highlight != null && spot.x == spots[highlight].x;
                  return FlDotCirclePainter(
                    radius: isHighlight ? 4 : 2.4,
                    color: isHighlight
                        ? AppColors.warningOrange(brightness)
                        : scheme.primary,
                    strokeWidth: isHighlight ? 1.5 : 0,
                    strokeColor: scheme.surface,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: scheme.primary.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 纵轴刻度：整数就不显示小数点（1250 而不是 1250.0）。
  static String _trimNumber(double v) {
    if ((v - v.roundToDouble()).abs() < 0.001) return v.round().toString();
    return v.toStringAsFixed(v.abs() < 10 ? 2 : 1);
  }
}
