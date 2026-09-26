import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../service/History/ChartHistoryCore.dart';
import '../service/History/ChartHistoryStore.dart';
import '../utils/AppTheme.dart';
import '../utils/CurrentDataSourceNotifier.dart';
import '../utils/ScoreInputValidator.dart';
import '../utils/UserProfileNotifier.dart';
import 'HistoryDateTimeDialog.dart';
import 'HistoryLineChart.dart';
import 'HistoryPointDelete.dart';

/// 曲目详情页里的「这张谱面的成绩历史」区块（达成率曲线 + DX 曲线）。
///
/// 设计取舍：
///   * **没有历史就完全不占空间**（[SizedBox.shrink]）——它挂在曲目详情页上，
///     而绝大多数谱面在刚开始记录时是没有历史的，不能凭空撑出一块空白；
///   * 只有一条记录时也绘制单点曲线，让用户能直接看到当前成绩；
///   * 有基线但一次变化都还没有时，也把基线作为单个数据点绘制；
///     这样首次采集后就能看到当前成绩，不必等下一次变化。
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
    this.maxAchievement = 101.0,
    this.cardStyle = false,
    this.emptyPadding = EdgeInsets.zero,
    this.textPadding = const EdgeInsets.only(top: 8),
    this.chartPadding = const EdgeInsets.only(top: 12),
  });

  final int songId;
  final int levelIndex;

  /// 该难度谱面的 DX 分理论满分（拿不到就退化成画绝对值）。
  final int? maxDxScore;

  /// 这张谱面的**达成率上限**：普通曲 101%；宴会场一个曲目里多张子谱相加，
  /// 上限 = 101 × 子谱数（2 个子谱即 202%）。
  ///
  /// 由调用方（曲目详情页）算好传进来：这里拿不到谱面物量 / ds 结构。
  /// 默认按普通曲处理 —— 缺数据时宁可放宽一点，也不能把用户挡在录入外面。
  /// 手动录入弹窗用它做合法值校验（口径见 [maxAchievementFor]）。
  final double maxAchievement;

  /// 是否给整块套一层「卡片」外观（`surface` 底色 + 圆角）。
  ///
  /// 曲目详情页把成绩趋势摆成独立板块时用 `true`，让它在视觉上和其他卡片同一档。
  final bool cardStyle;

  /// 没有任何历史（直接不渲染）时的内边距：**必须是 0**，否则会留白。
  final EdgeInsets emptyPadding;

  /// 保留给无变化基线等文字状态的内边距。
  final EdgeInsets textPadding;

  /// 画出曲线时的内边距（最完整的一种）。
  final EdgeInsets chartPadding;

  @override
  State<ChartHistorySection> createState() => _ChartHistorySectionState();
}

enum _HistoryMetric { achievement, dxScore }

class _ManualChartInput {
  const _ManualChartInput({
    required this.achievement,
    required this.dxScore,
    required this.tMs,
  });

  final double achievement;
  final int dxScore;
  final int tMs;
}

class _ChartHistorySectionState extends State<ChartHistorySection> {
  /// 变化列表默认只摆这么多条（这块挂在曲目详情页上，不能把页面撑长）。
  static const int _changeListPreview = 5;

  int _loadGeneration = 0;
  bool _loading = true;
  List<ChartHistoryEvent> _events = const [];
  ChartBaseline? _baseline;
  _HistoryMetric _metric = _HistoryMetric.achievement;

  /// 变化列表是否展开成全部（默认收起）。
  ///
  /// 为什么要能展开：**删除必须对每一个记录点都可用**，而收起状态只显示最近
  /// [_changeListPreview] 条 —— 手动补录了七八个点却删不掉最早那个，说不过去。
  bool _expandedChangeList = false;

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
      _expandedChangeList = false;
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

  Future<void> _addManualPoint() async {
    // 输入框的 controller 由弹窗自己持有（见 [_ManualChartPointDialog]），
    // 这里**不要**去碰它们 —— 在 pop 那一刻就 dispose 会把弹窗的退场动画炸掉。
    final input = await showDialog<_ManualChartInput>(
      context: context,
      builder: (_) => _ManualChartPointDialog(
        maxAchievement: widget.maxAchievement,
        maxDxScore: widget.maxDxScore ?? 0,
      ),
    );
    if (!mounted || input == null) return;
    try {
      final sourceKey = await ChartHistoryStore.storageKey();
      await ChartHistoryStore.instance.recordManualChartPoint(
        songId: widget.songId,
        levelIndex: widget.levelIndex,
        achievement: input.achievement,
        dxScore: input.dxScore,
        tMs: input.tMs,
        sourceKey: sourceKey,
      );
      if (mounted) await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存历史失败：$e')),
        );
      }
    }
  }

  /// 删掉某一个记录点（自动采集 / 手动补录 / 基线都按同一秒匹配）。
  ///
  /// 先弹确认框：删一个点和"清空整条曲线"是两件事，误点一下少一个点太亏。
  Future<void> _deleteEvent(ChartHistoryEvent event) async {
    final confirmed = await confirmDeleteHistoryPoint(
      context,
      pointLabel: '${_formatDate(event.tMs)}\n'
          '达成率 ${event.achievement.toStringAsFixed(4)}%'
          '${event.dxScore > 0 ? ' · DX ${event.dxScore}' : ''}',
    );
    if (!mounted || !confirmed) return;
    try {
      final sourceKey = await ChartHistoryStore.storageKey();
      await ChartHistoryStore.instance.deleteChartPoint(
        songId: widget.songId,
        levelIndex: widget.levelIndex,
        tMs: event.tMs,
        sourceKey: sourceKey,
      );
      if (mounted) await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除记录点失败：$e')),
        );
      }
    }
  }

  List<ChartHistoryEvent> get _displayEvents {
    if (_events.isNotEmpty) return _events;
    final base = _baseline;
    if (base == null) return const [];
    return [
      ChartHistoryEvent(
        tMs: base.tMs,
        achievement: base.achievement,
        dxScore: base.dxScore,
      ),
    ];
  }

  bool get _hasDisplayedDx => _displayEvents.any((e) => e.dxScore > 0);
  int? get _maxDx {
    final max = widget.maxDxScore;
    return (max != null && max > 0) ? max : null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    final brightness = Theme.of(context).brightness;
    final events = _displayEvents;
    if (events.isEmpty) {
      return _wrap(
        widget.textPadding,
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addManualPoint,
            icon: const Icon(Icons.add_chart_outlined),
            label: const Text('添加成绩历史'),
          ),
        ),
      );
    }
    final eventCountLabel =
        events.length == 1 ? '1 个记录点' : '${events.length} 次变化';

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
                '成绩历史（$eventCountLabel）',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryText(brightness),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: '添加成绩历史',
                icon: const Icon(Icons.add_chart_outlined, size: 18),
                onPressed: _addManualPoint,
              ),
            ],
          ),
          if (_events.length > 1 && hasRegression(_events)) ...[
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
          if (_hasDisplayedDx)
            Row(
              children: [
                _metricChip('达成率', _HistoryMetric.achievement),
                const SizedBox(width: 8),
                _metricChip(
                  _maxDx != null ? 'DX分数（占满分%）' : 'DX分数',
                  _HistoryMetric.dxScore,
                ),
              ],
            ),
          const SizedBox(height: 8),
          _buildChart(brightness, events),
          const SizedBox(height: 8),
          _buildChangeList(brightness, events),
        ],
      ),
    );
  }

  /// 统一套「卡片外观 + 内边距」。
  ///
  /// 只有需要渲染时才包 `surface` 底：`_displayEvents.isEmpty`
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

  Widget _buildChart(Brightness brightness, List<ChartHistoryEvent> events) {
    final maxDx = _maxDx;
    final isAch = _metric == _HistoryMetric.achievement;

    final values = [
      for (final e in events)
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
    // 只有一个点时**必须**退回"日"：三个刻度都落在同一个点上，
    // 秒级文案（`2026/09/18 14:30:05` 这种 19 字符）会互相压字并顶出画布。
    final showTimeLabels = showSecondPrecisionAxis(
      events.first.tMs,
      events.last.tMs,
      events.length,
    );

    return HistoryLineChart(
      height: 170,
      spots: [
        for (var i = 0; i < events.length; i++) FlSpot(i.toDouble(), values[i]),
      ],
      minY: axis.min,
      maxY: axis.max,
      leftInterval: axis.interval,
      highlightIndex: bestIdx,
      interval: (events.length / 4).clamp(1, 9999),
      bottomLabel: (x) {
        final idx = x.round().clamp(0, events.length - 1);
        return showTimeLabels
            ? _formatDate(events[idx].tMs)
            : _formatShortDate(events[idx].tMs);
      },
      tooltipLabel: (index) {
        final e = events[index.clamp(0, events.length - 1)];
        final dxText = maxDx != null
            ? '${e.dxScore} / $maxDx（${(e.dxScore / maxDx * 100).toStringAsFixed(1)}%）'
            : '${e.dxScore}';
        return '${e.tMs > 0 ? _formatDate(e.tMs) : '日期未知'}\n'
            '达成率 ${e.achievement.toStringAsFixed(4)}%\n'
            'DX $dxText';
      },
    );
  }

  Widget _buildChangeList(
      Brightness brightness, List<ChartHistoryEvent> events) {
    // 列表倒序：最近的一次在最上面
    final all = events.reversed.toList(growable: false);
    final canExpand = all.length > _changeListPreview;
    final visible = (_expandedChangeList || !canExpand)
        ? all
        : all.sublist(0, _changeListPreview);
    final isAchievement = _metric == _HistoryMetric.achievement;
    final maxDx = _maxDx;

    final valueStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppColors.primaryText(brightness),
    );
    final subStyle = TextStyle(
      fontSize: 11.5,
      color: AppColors.secondaryText(brightness),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < visible.length; i++)
          Builder(builder: (context) {
            final e = visible[i];
            // 与更早的一次比较：`visible` 是 `all` 的前缀，所以下标可以直接用；
            // 增量一律按**完整列表**算，收起状态里最后一条才不会平白丢掉增量
            final prev = i + 1 < all.length ? all[i + 1] : null;
            final delta = prev == null
                ? null
                : isAchievement
                    ? e.achievement - prev.achievement
                    : e.dxScore - prev.dxScore;
            final showDelta = delta != null &&
                (isAchievement ? delta.abs() >= 0.0001 : delta != 0);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  // 日期定宽到实测需要的宽度（`2026/09/18 10:00:00` 真实字体
                  // 11.5px 下 112.1px）：以前写死 78px，日期在真机上会折成两行，
                  // 比别的行高出一截。外面套 FittedBox，放大系统字体时等比缩小。
                  SizedBox(
                    width: 114,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        e.tMs > 0 ? _formatDate(e.tMs) : '日期未知',
                        maxLines: 1,
                        style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.secondaryText(brightness)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // 数值 + 增量整体缩放：这一行里还有删除按钮，
                  // 不能让窄屏/大字体把它挤成溢出条纹
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isAchievement)
                            Text(
                              '${e.achievement.toStringAsFixed(4)}%',
                              style: valueStyle,
                            )
                          else ...[
                            Text('${e.dxScore}', style: valueStyle),
                            if (maxDx != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                '${(e.dxScore / maxDx * 100).toStringAsFixed(2)}%',
                                style: subStyle,
                              ),
                            ],
                          ],
                          if (showDelta) ...[
                            const SizedBox(width: 6),
                            Text(
                              isAchievement
                                  ? '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(4)}%'
                                  : '${delta >= 0 ? '+' : ''}${delta.toInt()}',
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
                    ),
                  ),
                  HistoryPointDeleteButton(onPressed: () => _deleteEvent(e)),
                ],
              ),
            );
          }),
        // 删点必须对每一个记录点都可用：收起时只能删到最近 5 条，
        // 手动补录了七八个点却删不掉最早那个是说不过去的
        if (canExpand)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () =>
                  setState(() => _expandedChangeList = !_expandedChangeList),
              child: Text(
                _expandedChangeList ? '收起' : '展开全部（${all.length} 条）',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }

  static String _formatDate(int ms) {
    if (ms <= 0) return '日期未知';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}/${two(d.month)}/${two(d.day)} '
        '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }

  static String _formatShortDate(int ms) {
    if (ms <= 0) return '--/--';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.month}/${d.day}';
  }
}

/// 「添加谱面成绩历史」弹窗本体。
///
/// ⚠️ 两个 controller 必须由**弹窗自己的 [State]** 持有并释放，不要在调用方
/// `await showDialog(...)` 之后再 dispose：`showDialog` 的 future 是
/// `Route.popped`，pop 那一刻就完成，而弹窗还要走完**退场动画**才从 overlay
/// 移除 —— 退场期间（真机上键盘收起会让弹窗重建）`TextField` 会再读一次
/// controller，于是必现「A TextEditingController was used after being
/// disposed」，紧接着框架卸载到一半就崩成一串断言
/// （`'_dependents.isEmpty': is not true` /
/// 「Tried to build dirty widget in the wrong build scope」），表现就是**红屏**。
/// 回归测试：`test/chart_history_section_test.dart` 的「取消关闭」两例。
///
/// 合法值校验（口径与自定义 Best50 一致，见 [checkNumberInput]）：
///   * 达成率：> 0、≤ 谱面上限（普通曲 101% / 宴会场 202%）、≤ [achievementHardMax]；
///   * DX 分数：≥ 0、≤ 谱面满分（物量 × 3）、≤ [dxScoreHardMax]；
///   * 上限拿不到时（[maxDxScore] 为 0）只做硬上限校验，不挡用户录入。
class _ManualChartPointDialog extends StatefulWidget {
  const _ManualChartPointDialog({
    required this.maxAchievement,
    required this.maxDxScore,
  });

  final double maxAchievement;
  final int maxDxScore;

  @override
  State<_ManualChartPointDialog> createState() =>
      _ManualChartPointDialogState();
}

class _ManualChartPointDialogState extends State<_ManualChartPointDialog> {
  final TextEditingController _achievementController = TextEditingController();
  final TextEditingController _dxController = TextEditingController(text: '0');
  DateTime _selectedAt = DateTime.now();

  String? _achievementError;
  String? _dxError;

  @override
  void dispose() {
    _achievementController.dispose();
    _dxController.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _achievementController.text.trim().isNotEmpty &&
      _achievementError == null &&
      _dxError == null;

  /// 逐格校验，错误挂到对应的输入框上。
  ///
  /// ⚠️ **保存时也要再跑一次**：真实输入在 controller 里，只信 `onChanged`
  /// 存下来的值会出现"框里写着 100.55、存进去的是 100.5"。
  void _revalidate() {
    setState(() {
      _achievementError = checkNumberInput(
        _achievementController.text,
        hardMax: achievementHardMax,
        limit: widget.maxAchievement,
        limitLabel: '谱面上限',
      ).error;
      _dxError = checkNumberInput(
        _dxController.text,
        hardMax: dxScoreHardMax,
        limit: widget.maxDxScore > 0 ? widget.maxDxScore : null,
        limitLabel: '谱面上限',
        allowZero: true,
      ).error;
    });
  }

  Future<void> _pickDateTime() async {
    final picked = await showHistoryDateTimeDialog(
      context,
      initial: _selectedAt,
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedAt = picked);
  }

  void _save() {
    _revalidate();
    if (!_canSave) return;
    final achievement =
        double.tryParse(_achievementController.text.trim());
    // 先按 double 解再取整（与自定义 Best50 的 DX 输入同一处理）：
    // 校验是按 double 过的，这里再 `int.tryParse` 会把 "3000.5" 解析成 null，
    // 于是 DX 被静默存成 0。
    final dxScore = double.tryParse(_dxController.text.trim())?.round() ?? 0;
    if (achievement == null || achievement <= 0 || dxScore < 0) return;
    Navigator.of(context).pop(_ManualChartInput(
      achievement: achievement,
      dxScore: dxScore,
      tMs: _selectedAt.millisecondsSinceEpoch,
    ));
  }

  static String _formatDateTime(DateTime value) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${value.year}/${two(value.month)}/${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加谱面成绩历史'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _achievementController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => _revalidate(),
              decoration: InputDecoration(
                labelText: '达成率（%）',
                border: const OutlineInputBorder(),
                helperText: limitHelperText(
                  widget.maxAchievement,
                  widget.maxAchievement > 101.0 ? '宴会场子谱相加' : '普通谱面上限',
                ),
                helperStyle: const TextStyle(fontSize: 11),
                errorText: _achievementError,
                errorStyle: const TextStyle(fontSize: 11),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _dxController,
              keyboardType: TextInputType.number,
              onChanged: (_) => _revalidate(),
              decoration: InputDecoration(
                labelText: 'DX 分数（可选）',
                border: const OutlineInputBorder(),
                helperText: widget.maxDxScore > 0
                    ? limitHelperText(widget.maxDxScore, '谱面满分')
                    : null,
                helperStyle: const TextStyle(fontSize: 11),
                errorText: _dxError,
                errorStyle: const TextStyle(fontSize: 11),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.event_outlined),
                label: Text(_formatDateTime(_selectedAt)),
                onPressed: _pickDateTime,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          // 空值 / 非法值都不给点：弹窗里没有别的提示位，最省事的是按钮直接灰掉
          onPressed: _canSave ? _save : null,
          child: const Text('保存'),
        ),
      ],
    );
  }
}
