import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../entity/DivingFish/UserPlayDataEntity.dart';
import '../manager/DivingFish/MaimaiMusicDataManager.dart';
import '../manager/DivingFish/UserPlayDataManager.dart';
import '../service/DifficultyDistributionService.dart';
import '../utils/CommonWidgetUtil.dart';
import '../utils/AppTheme.dart';
import 'SongInfoPage.dart';

/// 谱面定数分布柱状图页面
class DifficultyDistributionPage extends StatefulWidget {
  const DifficultyDistributionPage({super.key});

  @override
  State<DifficultyDistributionPage> createState() =>
      _DifficultyDistributionPageState();
}

class _DifficultyDistributionPageState
    extends State<DifficultyDistributionPage> {
  int _selectedLevelIndex = -1;
  List<DistributionBucket> _buckets = [];
  bool _isLoading = true;

  static const _levelNames = ['BASIC', 'ADV', 'EXPERT', 'MASTER', 'Re:MAS'];
  static const _levelColors = [
    Colors.green,
    Colors.orange,
    Colors.red,
    Colors.purple,
    Colors.deepPurple,
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final songs = await MaimaiMusicDataManager().getCachedSongs();
      if (songs == null || songs.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }
      UserPlayDataEntity? userData;
      try {
        final raw = await UserPlayDataManager().getCachedUserPlayData();
        if (raw != null) userData = UserPlayDataEntity.fromJson(raw);
      } catch (_) {}
      final buckets = DifficultyDistributionService.calculateDistribution(
        levelIndex: _selectedLevelIndex,
        allSongs: songs,
        userPlayData: userData,
      );
      if (mounted) {
        setState(() {
          _buckets = buckets;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('加载定数分布数据失败: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onLevelChanged(int index) {
    setState(() => _selectedLevelIndex = index);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          CommonWidgetUtil.buildCommonBgWidget(),
          CommonWidgetUtil.buildCommonChiffonBgWidget(context),
          Column(
            children: [
              // 标题栏
              Container(
                padding: const EdgeInsets.fromLTRB(16, 48, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: textColor),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Center(
                        child: Text('定数分布',
                            style: TextStyle(
                                color: textColor,
                                fontSize: 22,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              // 难度分段控件
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildLevelChip('全部', -1, Colors.grey),
                      for (int i = 0; i < _levelNames.length; i++)
                        _buildLevelChip(_levelNames[i], i, _levelColors[i]),
                    ],
                  ),
                ),
              ),
              // 图表区域
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [AppColors.defaultShadow(brightness)],
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _buckets.isEmpty
                          ? Center(
                              child: Text('暂无数据',
                                  style: TextStyle(color: textColor)))
                          : _buildChart(brightness),
                ),
              ),
              // 图例
              if (!_isLoading && _buckets.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _legendItem(Colors.green, '已游玩'),
                      const SizedBox(width: 20),
                      _legendItem(AppColors.greyHint(brightness), '未游玩'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildLevelChip(String label, int index, Color color) {
    final isSelected = _selectedLevelIndex == index;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : color)),
        selected: isSelected,
        selectedColor: color,
        backgroundColor: color.withValues(alpha: 0.12),
        onSelected: (_) => _onLevelChanged(index),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
    );
  }

  Widget _buildChart(Brightness brightness) {
    final barWidth = 28.0;
    final count = _buckets.length;
    // 图表宽度根据柱子数量动态计算，最少填满屏幕
    final chartWidth = (count * (barWidth + 20) + 60).clamp(
      MediaQuery.of(context).size.width - 50, 1200.0);

    final maxY = _buckets
        .map((b) => b.totalCount.toDouble())
        .reduce((a, b) => a > b ? a : b);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: chartWidth,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.center,
            maxY: maxY * 1.12,
            minY: 0,
            barGroups: _buckets.asMap().entries.map((entry) {
              final idx = entry.key;
              final bucket = entry.value;
              return BarChartGroupData(
                x: idx,
                barRods: [
                  // 未游玩（灰色底）
                  BarChartRodData(
                    toY: bucket.unplayedCount.toDouble(),
                    color: AppColors.greyHint(brightness),
                    width: barWidth,
                    borderRadius: bucket.playedCount > 0
                        ? BorderRadius.zero
                        : const BorderRadius.vertical(
                            top: Radius.circular(5)),
                  ),
                  // 已游玩（彩色顶）
                  if (bucket.playedCount > 0)
                    BarChartRodData(
                      toY: bucket.totalCount.toDouble(),
                      color: _getBarColor(),
                      width: barWidth,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(5)),
                    ),
                ],
              );
            }).toList(),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= _buckets.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${_buckets[i].dsMin.toInt()}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  interval: (maxY / 5).ceilToDouble().clamp(1, double.infinity),
                  getTitlesWidget: (value, meta) => Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ),
              ),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              show: true,
              horizontalInterval: (maxY / 6).ceilToDouble().clamp(1, double.infinity),
              getDrawingHorizontalLine: (value) => FlLine(
                color: AppColors.tableBorder(brightness).withValues(alpha: 0.4),
                strokeWidth: 0.5,
              ),
            ),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  if (groupIndex >= _buckets.length) return null;
                  final bucket = _buckets[groupIndex];
                  return BarTooltipItem(
                    '定数 ${bucket.dsMin.toInt()}~${(bucket.dsMax - 1).toInt()}\n共 ${bucket.totalCount} 首\n已玩 ${bucket.playedCount} 首',
                    const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                },
              ),
              touchCallback: (event, response) {
                if (response?.spot != null && event is FlTapUpEvent) {
                  final idx = response!.spot!.touchedBarGroupIndex;
                  if (idx >= 0 && idx < _buckets.length) {
                    _showBucketDetail(_buckets[idx]);
                  }
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Color _getBarColor() {
    if (_selectedLevelIndex >= 0 &&
        _selectedLevelIndex < _levelColors.length) {
      return _levelColors[_selectedLevelIndex];
    }
    return Colors.blue;
  }

  void _showBucketDetail(DistributionBucket bucket) {
    final suffix = _selectedLevelIndex >= 0
        ? ' (${_levelNames[_selectedLevelIndex.clamp(0, 4)]})'
        : '';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (ctx, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.tableBorder(Theme.of(ctx).brightness),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '定数 ${bucket.dsMin.toInt()}~${(bucket.dsMax - 1).toInt()} $suffix (共 ${bucket.totalCount} 首)',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: bucket.songs.length,
                    itemBuilder: (_, i) {
                      final song = bucket.songs[i];
                      final isPlayed = bucket.playedSongs.any(
                          (s) => s.id == song.id);
                      final dsIdx = _selectedLevelIndex >= 0 &&
                              _selectedLevelIndex < song.ds.length
                          ? _selectedLevelIndex
                          : (song.ds.isNotEmpty ? 0 : -1);
                      return ListTile(
                        leading: Icon(
                          isPlayed
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: isPlayed ? Colors.green : Colors.grey,
                          size: 18,
                        ),
                        title: Text(song.basicInfo.title,
                            style: const TextStyle(fontSize: 14),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${song.basicInfo.artist} | ${song.type}',
                            style: const TextStyle(fontSize: 11)),
                        trailing: Text(
                          dsIdx >= 0
                              ? song.ds[dsIdx].toStringAsFixed(1)
                              : '',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => SongInfoPage(
                              songId: song.id,
                              initialLevelIndex:
                                  _selectedLevelIndex >= 0 ? _selectedLevelIndex : 3,
                              isDefaultLevelIndex: _selectedLevelIndex < 0,
                            ),
                          ));
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
