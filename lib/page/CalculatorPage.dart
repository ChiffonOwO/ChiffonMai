import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';

// ============================================================================
// 共享：达成率-评级-倍率对照表（与 SongInfoPage 行 100-119 /
// SingleRatingCalculatorPage 行 29-52 完全一致）
// ============================================================================
const List<Map<String, dynamic>> _maimaiRatingMultiplier = [
  {"completion": 100.5, "rating": "SSS+", "multiplier": 0.224},
  {"completion": 100.4999, "rating": "SSS", "multiplier": 0.222},
  {"completion": 100.0, "rating": "SSS", "multiplier": 0.216},
  {"completion": 99.9999, "rating": "SS+", "multiplier": 0.214},
  {"completion": 99.5, "rating": "SS+", "multiplier": 0.211},
  {"completion": 99.0, "rating": "SS", "multiplier": 0.208},
  {"completion": 98.9999, "rating": "S+", "multiplier": 0.206},
  {"completion": 98.0, "rating": "S+", "multiplier": 0.203},
  {"completion": 97.0, "rating": "S", "multiplier": 0.2},
  {"completion": 96.9999, "rating": "AAA", "multiplier": 0.176},
  {"completion": 94.0, "rating": "AAA", "multiplier": 0.168},
  {"completion": 90.0, "rating": "AA", "multiplier": 0.152},
  {"completion": 80.0, "rating": "A", "multiplier": 0.136},
  {"completion": 79.9999, "rating": "BBB", "multiplier": 0.128},
  {"completion": 75.0, "rating": "BBB", "multiplier": 0.120},
  {"completion": 70.0, "rating": "BB", "multiplier": 0.112},
  {"completion": 60.0, "rating": "B", "multiplier": 0.096},
  {"completion": 50.0, "rating": "C", "multiplier": 0.08},
  {"completion": 40.0, "rating": "D", "multiplier": 0.064},
  {"completion": 30.0, "rating": "D", "multiplier": 0.048},
  {"completion": 20.0, "rating": "D", "multiplier": 0.032},
  {"completion": 10.0, "rating": "D", "multiplier": 0.016},
];

// ============================================================================
// 共享权重常量（与 SongInfoPage 行 158-162 / AchievementRateCalculatorPage
// 行 63-67 完全一致）
// ============================================================================
const int _tapWeight = 1;
const int _holdWeight = 2;
const int _slideWeight = 3;
const int _touchWeight = 1;
const int _breakWeight = 5;

// 5 种 note 类型标签（顺序：[TAP, HOLD, SLIDE, TOUCH, BREAK]）
const List<String> _noteLabels = ['TAP', 'HOLD', 'SLIDE', 'TOUCH', 'BREAK'];

// 5 种 note 类型对应权重
const List<int> _noteWeights = [_tapWeight, _holdWeight, _slideWeight, _touchWeight, _breakWeight];

// 4 种判定标签（PERFECT / GREAT / GOOD / MISS）—— 表头文字现在在 _buildTableHeaderRow 内联定义，
// 留空注释以备将来扩展（如想用 const 替代字面量）。
// const List<String> _judgmentLabels = ['PERFECT', 'GREAT', 'GOOD', 'MISS'];

// 5 列判定对应的填色（与 AchievementFullReverseCalculatorPage._buildNormalNoteTable 一致）
// 顺序：[CP, PF, GR, GD, MS]（普通音符 5 档判定）
const List<Color> _judgmentFillColors = [
  Color(0xFFFFE082), // CP: Colors.yellow[200]!
  Color(0xFFFFCA28), // PF: Colors.yellow[400]!
  Color(0xFFEF9A9A), // GR: Colors.pink[200]!
  Color(0xFFA5D6A7), // GD: Colors.green[200]!
  Color(0xFFE0E0E0), // MS: Colors.grey[200]!
];

// 行标签底色（与 AchievementFullReverseCalculator 一致：浅蓝 100）
Color _noteRowFillColor(Brightness brightness) =>
    brightness == Brightness.dark ? Colors.blueGrey.shade800 : Colors.lightBlue.shade100;

// 表头角落底色（与得分失分详细表格表头第一格一致：深色 grey.shade800 / 浅色 0xFFEFEFEF）
Color _headerCornerFillColor(Brightness brightness) =>
    brightness == Brightness.dark ? Colors.grey.shade800 : const Color(0xFFEFEFEF);

// ============================================================================
// 共享算法：定数 + 达成率 → 单曲 Rating（与 SongInfoPage 行 1587-1611 一致）
// ============================================================================
int _calculateSingleRating(double difficulty, double completion) {
  // 达成率 >100.5 按 100.5 算
  final double effectiveCompletion = completion > 100.5 ? 100.5 : completion;

  Map<String, dynamic>? selectedRating;
  for (final item in _maimaiRatingMultiplier) {
    if (effectiveCompletion >= (item['completion'] as num).toDouble()) {
      selectedRating = item;
      break;
    }
  }
  selectedRating ??= const {"rating": "D", "multiplier": 0.016};

  final double multiplier = (selectedRating['multiplier'] as num).toDouble();
  return (difficulty * multiplier * completion).floor();
}

// ============================================================================
// 共享算法：基础部分 + 额外部分 → 总达成率
// 输入：
//   - noteCounts: 5 种 note 的 [CP, PF, GR, GD, MS] 计数 (List<List<int>>, 5×5)
//   - breakSubs:  BREAK 8 种细分 (P/100/50/80/60/50g/Go/Miss) 计数
// 输出：{ totalScore, baseScore, extraScore, totalWeight }
// ============================================================================
class _AchievementBreakdown {
  final double baseScore;
  final double extraScore;
  final double totalScore;
  final int totalWeight;

  const _AchievementBreakdown({
    required this.baseScore,
    required this.extraScore,
    required this.totalScore,
    required this.totalWeight,
  });
}

// 基础+额外评价 → 总达成率的共享算法：当前无调用点（页面内走 1872 行起的
// 内联实现，_AchievementRateCalculatorPage 也自带一份），保留备查。
// ignore: unused_element
_AchievementBreakdown _calculateAchievementBreakdown({
  required List<List<int>> noteCounts, // 5 行 × 5 列 [CP, PF, GR, GD, MS]
  required List<int> breakSubs, // 8 列: [P, 100, 50, 80, 60, 50g, Go, Miss]
}) {
  // 每种 note 的总数
  int tapNum = 0, holdNum = 0, slideNum = 0, touchNum = 0, breakNum = 0;
  for (int j = 0; j < 5; j++) {
    tapNum += noteCounts[0][j];
    holdNum += noteCounts[1][j];
    slideNum += noteCounts[2][j];
    touchNum += noteCounts[3][j];
    breakNum += noteCounts[4][j];
  }
  // breakSubs 8 列累加也应等于 breakNum（前端校验），不强制相等

  final int totalTapWeight = tapNum * _tapWeight;
  final int totalHoldWeight = holdNum * _holdWeight;
  final int totalSlideWeight = slideNum * _slideWeight;
  final int totalTouchWeight = touchNum * _touchWeight;
  final int totalBreakWeight = breakNum * _breakWeight;
  final int totalWeight = totalTapWeight +
      totalHoldWeight +
      totalSlideWeight +
      totalTouchWeight +
      totalBreakWeight;

  if (totalWeight == 0 || breakNum == 0) {
    return const _AchievementBreakdown(
      baseScore: 0,
      extraScore: 0,
      totalScore: 0,
      totalWeight: 0,
    );
  }

  // 基础评价部分（满分 100）
  double baseTapWeight =
      _tapWeight * (noteCounts[0][0] + noteCounts[0][1] + noteCounts[0][2] * 0.80 + noteCounts[0][3] * 0.50);
  double baseHoldWeight =
      _holdWeight * (noteCounts[1][0] + noteCounts[1][1] + noteCounts[1][2] * 0.80 + noteCounts[1][3] * 0.50);
  double baseSlideWeight =
      _slideWeight * (noteCounts[2][0] + noteCounts[2][1] + noteCounts[2][2] * 0.80 + noteCounts[2][3] * 0.50);
  double baseTouchWeight =
      _touchWeight * (noteCounts[3][0] + noteCounts[3][1] + noteCounts[3][2] * 0.80 + noteCounts[3][3] * 0.50);
  // BREAK 基础评价：100% = 1.0，50% = 1.0（与 AchievementRateCalculatorPage 行 93-95 一致）
  // 这里用 breakSubs[0]=P, [1]=100, [2]=50, [3]=80, [4]=60, [5]=50g, [6]=Go, [7]=Miss
  double baseBreakWeight = _breakWeight *
      (breakSubs[0] +
          (breakSubs[1] + breakSubs[2]) +
          breakSubs[3] * 0.80 +
          breakSubs[4] * 0.60 +
          breakSubs[5] * 0.50 +
          breakSubs[6] * 0.40);
  double baseWeight = baseTapWeight +
      baseHoldWeight +
      baseSlideWeight +
      baseTouchWeight +
      baseBreakWeight;

  final double baseScore = double.parse(
      ((baseWeight / totalWeight) * 100).toStringAsFixed(4));

  // 额外评价部分（满分 1）
  double extraBreakWeight = breakSubs[0] +
      breakSubs[1] * 0.50 +
      breakSubs[2] * 0.75 +
      (breakSubs[3] + breakSubs[4] + breakSubs[5]) * 0.40 +
      breakSubs[6] * 0.30;
  final double extraScore =
      double.parse((extraBreakWeight / breakNum).toStringAsFixed(4));

  final double totalScore =
      double.parse((baseScore + extraScore).toStringAsFixed(4));

  return _AchievementBreakdown(
    baseScore: baseScore,
    extraScore: extraScore,
    totalScore: totalScore,
    totalWeight: totalWeight,
  );
}

// ============================================================================
// CalculatorPage（顶层入口）
// ============================================================================
class CalculatorPage extends StatelessWidget {
  final String songId;
  final String songTitle;
  final String songType;
  final int difficultyIndex;
  final String difficultyLabel;
  final double ds;
  final double? fitDiff;
  final List<int> noteCounts; // [TAP, HOLD, SLIDE, TOUCH, BREAK]
  final double? userAchievement;
  final int? userRating; // 用户"玩家最佳成绩"中的 Rating 值（可选）

  const CalculatorPage({
    super.key,
    required this.songId,
    required this.songTitle,
    required this.songType,
    required this.difficultyIndex,
    required this.difficultyLabel,
    required this.ds,
    required this.fitDiff,
    required this.noteCounts,
    required this.userAchievement,
    this.userRating,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final brightness = Theme.of(context).brightness;
    final colorScheme = Theme.of(context).colorScheme;
    final primaryText = AppColors.primaryText(brightness);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // 防止键盘弹起时挤压背景导致卡顿
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            // 与同类计算器页面一致：通用背景 + Chiffon 背景
            CommonWidgetUtil.buildCommonBgWidget(),
            CommonWidgetUtil.buildCommonChiffonBgWidget(context),
            // 页面主体
            Column(
              children: [
                // 顶部状态栏安全区 + 自定义标题栏
                SafeArea(
                  bottom: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '计算工具',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.055,
                                  fontWeight: FontWeight.bold,
                                  color: primaryText,
                                ),
                              ),
                              Text(
                                '当前为 [$songType] $songTitle [$difficultyLabel] 的数据',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.03,
                                  color: AppColors.secondaryText(brightness),
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // TabBar
                Container(
                  color: colorScheme.surface,
                  child: TabBar(
                    labelColor: AppColors.linkBlue(brightness),
                    unselectedLabelColor: AppColors.secondaryText(brightness),
                    indicatorColor: AppColors.linkBlue(brightness),
                    tabs: const [
                      Tab(text: '分数线/绝赞分布计算'),
                      Tab(text: 'RATING线计算'),
                    ],
                  ),
                ),
                // Tab 内容
                Expanded(
                  child: TabBarView(
                    children: [
                      _ScoreLineTab(
                        noteCounts: noteCounts,
                        userAchievement: userAchievement,
                        fitDiff: fitDiff,
                      ),
                      _RatingLineTab(
                        ds: ds,
                        fitDiff: fitDiff,
                        userAchievement: userAchievement,
                        userRating: userRating,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Tab 2：RATING线计算
// ============================================================================
class _RatingLineTab extends StatefulWidget {
  final double ds;
  final double? fitDiff;
  final double? userAchievement;
  final int? userRating; // 用户"玩家最佳成绩"中的 Rating 值（mode 2 默认填入）

  const _RatingLineTab({
    required this.ds,
    required this.fitDiff,
    required this.userAchievement,
    this.userRating,
  });

  @override
  State<_RatingLineTab> createState() => _RatingLineTabState();
}

class _RatingLineTabState extends State<_RatingLineTab> {
  int _mode = 0; // 0=按定数 1=按达成率 2=按Rating
  late final TextEditingController _inputController;
  // mode 2 专用：误差范围（Rating 允许落到 targetR ~ targetR+error 之间所有解）
  late final TextEditingController _errorCtrl;
  // 结果表格：达成率排序方向（true=倒序↓，false=正序↑）
  bool _sortDescending = true;

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController(
      text: _formatDs(widget.ds),
    );
    _errorCtrl = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    _inputController.dispose();
    _errorCtrl.dispose();
    super.dispose();
  }

  // 切换计算模式：同步重置输入框默认值
  void _selectMode(int mode) {
    setState(() {
      _mode = mode;
      switch (mode) {
        case 0:
          _inputController.text = _formatDs(widget.ds);
          break;
        case 1:
          _inputController.text =
              widget.userAchievement?.toStringAsFixed(4) ?? '100.0000';
          break;
        default:
          // mode 2：按 Rating 计算，默认填入用户"玩家最佳成绩"的 Rating 值
          _inputController.text = widget.userRating?.toString() ?? '';
      }
    });
  }

  // 定数显示格式：固定 1 位小数，整数也补 .0
  //   13.5  → "13.5"
  //   13.0  → "13.0"
  //   13.55 → "13.6"（toStringAsFixed 自动四舍五入）
  String _formatDs(double ds) => ds.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final brightness = Theme.of(context).brightness;
    final primaryText = AppColors.primaryText(brightness);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 模式选择（用 ChoiceChip + Wrap，避免 RadioListTile 在窄列里竖排一个字一行）
        _buildCard(
          screenWidth: screenWidth,
          brightness: brightness,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('计算模式', screenWidth, brightness),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('按定数计算'),
                    selected: _mode == 0,
                    onSelected: (_) => _selectMode(0),
                  ),
                  ChoiceChip(
                    label: const Text('按达成率计算'),
                    selected: _mode == 1,
                    onSelected: (_) => _selectMode(1),
                  ),
                  ChoiceChip(
                    label: const Text('按Rating计算'),
                    selected: _mode == 2,
                    onSelected: (_) => _selectMode(2),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 输入框
        _buildCard(
          screenWidth: screenWidth,
          brightness: brightness,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle(_inputLabel(), screenWidth, brightness),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      ],
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: _inputHint(),
                        isDense: true,
                      ),
                      style: TextStyle(
                          color: primaryText, fontSize: screenWidth * 0.04),
                    ),
                  ),
                  // mode 2：误差输入
                  if (_mode == 2) ...[
                    const SizedBox(width: 8),
                    const Text('误差 +'),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: screenWidth * 0.22,
                      child: TextField(
                        controller: _errorCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: '如 5',
                          isDense: true,
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: primaryText, fontSize: screenWidth * 0.04),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 结果表格
        _buildCard(
          screenWidth: screenWidth,
          brightness: brightness,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('计算结果', screenWidth, brightness),
              const SizedBox(height: 8),
              _buildResultTable(screenWidth),
            ],
          ),
        ),
      ],
    );
  }

  String _inputLabel() {
    switch (_mode) {
      case 0:
        return '定数';
      case 1:
        return '达成率';
      default:
        return '目标Rating';
    }
  }

  String _inputHint() {
    switch (_mode) {
      case 0:
        return '如 14.3';
      case 1:
        return '如 100.5667';
      default:
        return '如 321';
    }
  }

  Widget _buildResultTable(double screenWidth) {
    final input = double.tryParse(_inputController.text) ?? 0.0;
    final brightness = Theme.of(context).brightness;
    final borderColor = AppColors.tableBorder(brightness);

    final List<List<String>> rows = [];
    if (_mode == 0) {
      // 按定数：固定 ds，遍历倍率表 + 相邻区间内迭代找所有可达 rating 边界
      final ds = input;
      // 在 (lo, hi) 开区间内二分找最小 c 使 _calculateSingleRating(ds, c) >= targetRating
      double binarySearchMinCompletion(double lo, double hi, int targetRating) {
        double mid = lo;
        int iters = 0;
        while (hi - lo > 0.0001 && iters < 100) {
          mid = (lo + hi) / 2;
          int currentRating = _calculateSingleRating(ds, mid);
          if (currentRating < targetRating) {
            lo = mid;
          } else {
            hi = mid;
          }
          iters++;
        }
        return mid;
      }

      for (int i = 0; i < _maimaiRatingMultiplier.length; i++) {
        final c = (_maimaiRatingMultiplier[i]['completion'] as num).toDouble();
        final rating = _calculateSingleRating(ds, c);
        rows.add([
          _formatDs(ds),
          '${c.toStringAsFixed(4)}%',
          rating.toString(),
        ]);

        // 与下一项之间找所有可达 rating 边界
        if (i + 1 < _maimaiRatingMultiplier.length) {
          final nextC =
              (_maimaiRatingMultiplier[i + 1]['completion'] as num).toDouble();
          final nextMult =
              (_maimaiRatingMultiplier[i + 1]['multiplier'] as num).toDouble();
          // 在 (nextC, c) 开区间内，倍率是 entry[i+1] 的（c' < c 时 lookup 命中 entry[i+1]）
          // rating 范围 = [floor(ds*nextMult*nextC), floor(ds*nextMult*c)]
          final lowerRating = (ds * nextMult * nextC).floor();
          final upperRating = (ds * nextMult * c).floor();

          if (upperRating > lowerRating) {
            double lowerBound = nextC;
            // target 范围 (lowerRating, upperRating]：upperRating 对应区间内可达到的
            // 最大 rating（在 c 处刚好取到），由 base row c 处的条目体现（但 base row
            // 用的不是 nextMult，所以仍然可能在表里有遗漏），故循环包含 upperRating
            for (int target = lowerRating + 1; target <= upperRating; target++) {
              final midC = binarySearchMinCompletion(lowerBound, c, target);
              if (_calculateSingleRating(ds, midC) < target) break;
              rows.add([
                _formatDs(ds),
                '${midC.toStringAsFixed(4)}%',
                target.toString(),
              ]);
              lowerBound = midC;
            }
          }
        }
      }
    } else if (_mode == 1) {
      // 按达成率：固定 c，遍历 ds(1.0→15.0 step 0.1) → (ds, Rating)
      final c = input;
      final List<double> dsList = [];
      for (int i = 10; i <= 150; i++) {
        dsList.add(i / 10.0);
      }
      dsList.sort((a, b) => b.compareTo(a)); // 降序
      for (final ds in dsList) {
        final rating = _calculateSingleRating(ds, c);
        rows.add([
          _formatDs(ds),
          '${c.toStringAsFixed(4)}%',
          rating.toString(),
        ]);
      }
    } else {
      // 按Rating：固定 R，遍历 ds × 倍率表 → 所有 (ds, completion) 满足 rating ∈ [R, R+误差]
      final targetR = input.toInt();
      final int errorTolerance = int.tryParse(_errorCtrl.text) ?? 0;
      final List<double> dsList = [];
      for (int i = 10; i <= 150; i++) {
        dsList.add(i / 10.0);
      }
      dsList.sort((a, b) => b.compareTo(a));
      for (final ds in dsList) {
        for (final m in _maimaiRatingMultiplier) {
          final c = (m['completion'] as num).toDouble();
          final rating = _calculateSingleRating(ds, c);
          if (rating >= targetR && rating <= targetR + errorTolerance) {
            rows.add([
              _formatDs(ds),
              '${c.toStringAsFixed(4)}%',
              rating.toString(),
            ]);
          }
        }
      }
    }

    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('没有符合条件的结果',
            style: TextStyle(color: AppColors.secondaryText(brightness))),
      );
    }

    // 按达成率排序（row[1] 形如 "100.5000%"）
    // 达成率相等时用 ds 作兜底，避免 mode 1（固定 c）下顺序被随机打乱
    double parsePercent(String s) =>
        double.tryParse(s.replaceAll('%', '').trim()) ?? 0.0;
    double parseDs(String s) => double.tryParse(s.trim()) ?? 0.0;
    rows.sort((a, b) {
      final cmp = parsePercent(a[1]).compareTo(parsePercent(b[1]));
      if (cmp != 0) return _sortDescending ? -cmp : cmp;
      final dsCmp = parseDs(a[0]).compareTo(parseDs(b[0]));
      return _sortDescending ? -dsCmp : dsCmp;
    });

    final arrow = _sortDescending ? ' ↓' : ' ↑';
    return Table(
      border: TableBorder(
        horizontalInside: BorderSide(color: borderColor, width: 1),
        verticalInside: BorderSide(color: borderColor, width: 1),
        top: BorderSide(color: AppColors.tableBorder(brightness), width: 1.5),
        bottom: BorderSide(color: AppColors.tableBorder(brightness), width: 1.5),
        left: BorderSide(color: AppColors.tableBorder(brightness), width: 1.5),
        right: BorderSide(color: AppColors.tableBorder(brightness), width: 1.5),
      ),
      columnWidths: const {
        0: FlexColumnWidth(1.4),
        1: FlexColumnWidth(2.0),
        2: FlexColumnWidth(1.4),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(
            color: brightness == Brightness.dark
                ? Colors.grey.shade800
                : const Color(0xFFEFEFEF),
          ),
          children: [
            _cell('定数', screenWidth, brightness, bold: true),
            // 达成率表头：可点击切换正/倒序
            InkWell(
              onTap: () =>
                  setState(() => _sortDescending = !_sortDescending),
              child: _cell('达成率$arrow', screenWidth, brightness, bold: true),
            ),
            _cell('Rating', screenWidth, brightness, bold: true),
          ],
        ),
        for (int i = 0; i < rows.length; i++)
          TableRow(
            decoration: BoxDecoration(
              color: i.isEven
              ? (brightness == Brightness.dark ? Colors.grey.shade900 : Colors.white)
              : (brightness == Brightness.dark ? Colors.grey.shade800 : const Color(0xFFF7F7F7)),
            ),
            children: [
              _cell(rows[i][0], screenWidth, brightness),
              _cell(rows[i][1], screenWidth, brightness),
              _cell(rows[i][2], screenWidth, brightness),
            ],
          ),
      ],
    );
  }

  Widget _cell(String text, double screenWidth, Brightness brightness, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: screenWidth * 0.03,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: AppColors.primaryText(brightness),
        ),
      ),
    );
  }
}

// ============================================================================
// Tab 1：分数线 / 绝赞分布计算
// ============================================================================
class _ScoreLineTab extends StatefulWidget {
  final List<int> noteCounts; // [TAP, HOLD, SLIDE, TOUCH, BREAK]
  final double? userAchievement;
  final double? fitDiff;

  const _ScoreLineTab({
    required this.noteCounts,
    required this.userAchievement,
    required this.fitDiff,
  });

  @override
  State<_ScoreLineTab> createState() => _ScoreLineTabState();
}

class _ScoreLineTabState extends State<_ScoreLineTab> {
  // 5 个 note 总数输入控制器（可编辑，默认值 = 当前曲谱物量）
  late final List<TextEditingController> _noteCountCtrls;
  // 目标达成率（上方"目标达成率"卡用）
  late final TextEditingController _targetCtrl;
  // 绝赞分布计算的目标达成率（独立于上方）
  late final TextEditingController _reverseTargetCtrl;

  // 5×5 绝赞分布输入：5 行 × 5 列（CP/PF/GR/GD/MS）
  // 第 5 行 BREAK 用 CP/P/GR/Go/M
  late final List<List<TextEditingController>> _excellentCtrls;

  // 分数模式：0=0+, 1=100-, 2=101-
  int _scoreMode = 0;

  // 绝赞反推计算状态
  String? _reverseResultText;
  bool _calculatingReverse = false;

  @override
  void initState() {
    super.initState();
    _noteCountCtrls = List.generate(
      5,
      (i) => TextEditingController(text: widget.noteCounts[i].toString()),
    );

    _targetCtrl = TextEditingController(
      text: widget.userAchievement?.toStringAsFixed(4) ?? '101.0000',
    );
    _reverseTargetCtrl = TextEditingController(
      text: widget.userAchievement?.toStringAsFixed(4) ?? '101.0000',
    );

    // 5×5 绝赞分布输入：5 行 × 5 列（CP/PF/GR/GD/MS）
    // 第 5 行 BREAK 用 CP/P/GR/Go/M
    // 默认全部填为 CP（即第 0 列 = 各 note 总数，其余 4 列 = 0）
    _excellentCtrls = List.generate(
      5,
      (i) => [
        TextEditingController(text: widget.noteCounts[i].toString()), // CP
        TextEditingController(text: '0'),                              // PF
        TextEditingController(text: '0'),                              // GR
        TextEditingController(text: '0'),                              // GD
        TextEditingController(text: '0'),                              // MS
      ],
    );
  }

  @override
  void dispose() {
    for (final c in _noteCountCtrls) c.dispose();
    _targetCtrl.dispose();
    _reverseTargetCtrl.dispose();
    for (final row in _excellentCtrls) {
      for (final c in row) c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final brightness = Theme.of(context).brightness;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ---- note 总数输入 ----
        _buildCard(
          screenWidth: screenWidth,
          brightness: brightness,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('物量分布（可编辑）', screenWidth, brightness),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (int i = 0; i < 5; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          children: [
                            Text(_noteLabels[i],
                                style: TextStyle(
                                  fontSize: screenWidth * 0.03,
                                  color: AppColors.secondaryText(brightness),
                                )),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _noteCountCtrls[i],
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 8),
                              ),
                              style: TextStyle(fontSize: screenWidth * 0.035),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ---- 得分/失分详细 + 分数模式 ----
        _buildCard(
          screenWidth: screenWidth,
          brightness: brightness,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildSectionTitle('得分/失分详细', screenWidth, brightness),
                  ),
                  Text('分数模式',
                      style: TextStyle(
                        fontSize: screenWidth * 0.032,
                        color: AppColors.secondaryText(brightness),
                      )),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _scoreMode,
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('0+')),
                      DropdownMenuItem(value: 1, child: Text('100-')),
                      DropdownMenuItem(value: 2, child: Text('101-')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _scoreMode = v);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildAchievementDetailGrid(screenWidth, brightness),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ---- 目标达成率 + 容错实时显示 ----
        _buildCard(
          screenWidth: screenWidth,
          brightness: brightness,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              // 输入框行（含左侧"目标达成率"标签 + 居中输入 + 右侧状态）
              // 容错信息与 7 行 BREAK 等效
              _buildTargetInputRow(screenWidth, brightness),
              const SizedBox(height: 12),
              ..._buildBreakEquivalentLines(screenWidth, brightness),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ---- 绝赞分布（可展开） ----
        _buildExcellentPanel(screenWidth, brightness),
      ],
    );
  }

  // 计算单个格子的得分/失分（按 _scoreMode 区分）
  //   0  = 0+   ：单 note 在 0+ 模式下的得分（百分点）
  //   1  = 100- ：
  //               非 BREAK：与 101- 相同（cell_0+ − PERFECT_0+）
  //               BREAK PERFECT 列（baseCoeff=1.00）：+reward（= extraCoeff/breakN）
  //               BREAK 非 PERFECT：基础得分与 CP 的差距 + reward
  //                              = (baseCoeff−1)·w/totalW·100 + extraCoeff/breakN
  //   2  = 101- ：单 note 在 0+ 下的得分 − 参考 cell 的得分
  //                 非 BREAK 参考 PERFECT (base=1.00, extra=0)
  //                 BREAK 参考 CRITICAL PERFECT (base=1.00, extra=1.00)
  //   行物量为 0 时该行所有格子强制显示 '-'（不论哪种模式）
  String _cellText({
    required int noteIndex,
    required double baseCoefficient,
    double extraCoefficient = 0,
    required int totalWeight,
  }) {
    // 行物量为 0 → 强制 '-'
    if ((int.tryParse(_noteCountCtrls[noteIndex].text) ?? 0) == 0) {
      return '-';
    }

    if (totalWeight <= 0) return '0.0000%';

    final int breakNum = int.tryParse(_noteCountCtrls[4].text) ?? 0;
    final bool isBreak = noteIndex == 4;
    final int weight = _noteWeights[noteIndex];

    // 当前 cell 在 0+ 下的值（百分点）
    final double currentBase =
        baseCoefficient * weight / totalWeight * 100;
    final double currentExtra =
        (isBreak && breakNum > 0) ? extraCoefficient / breakNum : 0.0;
    final double currentValue = currentBase + currentExtra;

    if (_scoreMode == 2) {
      // 101- 模式：当前 cell 减参考 cell
      // 非 BREAK 参考 PERFECT (1.00, 0)；BREAK 参考 CP (1.00, 1.00)
      final double refBaseCoeff = 1.00;
      final double refExtraCoeff = isBreak ? 1.00 : 0.0;
      final double refBase = refBaseCoeff * weight / totalWeight * 100;
      final double refExtra =
          (isBreak && breakNum > 0) ? refExtraCoeff / breakNum : 0.0;
      final double refValue = refBase + refExtra;
      return '${(currentValue - refValue).toStringAsFixed(4)}%';
    }

    if (_scoreMode == 1) {
      // 100- 模式
      //   非 BREAK：与 101- 相同（cell_0+ − PERFECT_0+）
      //   BREAK PERFECT 列（baseCoeff=1.00）：+reward（= extraCoeff/breakN）
      //   BREAK 非 PERFECT：基础得分与 CP 的差距 + 奖励得分
      final double reward =
          (isBreak && breakNum > 0) ? extraCoefficient / breakNum : 0.0;

      if (isBreak && baseCoefficient == 1.00) {
        // BREAK PERFECT 列：+reward
        return '+${reward.toStringAsFixed(4)}%';
      }

      if (isBreak) {
        // BREAK 非 PERFECT：(base − CP_base) + reward
        final double baseDiff =
            (baseCoefficient - 1.00) * weight / totalWeight * 100;
        return '${(baseDiff + reward).toStringAsFixed(4)}%';
      }

      // 非 BREAK：与 101- 相同（cell_0+ − PERFECT_0+）
      final double refBase = 1.00 * weight / totalWeight * 100;
      return '${(currentBase - refBase).toStringAsFixed(4)}%';
    }

    // _scoreMode == 0：0+ 模式
    return '${currentValue.toStringAsFixed(4)}%';
  }

  // 主表格组装：表头 + 4 普通行 + BREAK 行
  Widget _buildAchievementDetailGrid(double screenWidth, Brightness brightness) {
    final noteCounts = _noteCountCtrls
        .map((c) => int.tryParse(c.text) ?? 0)
        .toList(growable: false);
    final int totalWeight = noteCounts
        .asMap()
        .entries
        .fold<int>(0, (sum, e) => sum + e.value * _noteWeights[e.key]);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.tableBorder(brightness), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTableHeaderRow(screenWidth, brightness),
          for (int i = 0; i < 4; i++)
            _buildNormalNoteRow(
              noteLabel: _noteLabels[i],
              noteIndex: i,
              totalWeight: totalWeight,
              screenWidth: screenWidth,
              brightness: brightness,
            ),
          _buildBreakRow(totalWeight, screenWidth, brightness),
        ],
      ),
    );
  }

  // 表格表头：空 + PERFECT + GREAT + GOOD + MISS
  Widget _buildTableHeaderRow(double screenWidth, Brightness brightness) {
    final labels = ['', 'PERFECT', 'GREAT', 'GOOD', 'MISS'];
    final darkBg = brightness == Brightness.dark
        ? Colors.grey.shade800
        : const Color(0xFFEFEFEF);
    // 4 个判定列着色（与下方绝赞分布表一致）
    final headerColors = <Color?>[
      darkBg,
      _judgmentFillColors[1], // PERFECT → yellow400
      _judgmentFillColors[2], // GREAT   → pink200
      _judgmentFillColors[3], // GOOD    → green200
      _judgmentFillColors[4], // MISS    → grey200
    ];
    final border = AppColors.tableBorder(brightness);
    return Row(
      children: [
        for (int i = 0; i < labels.length; i++)
          Expanded(
            flex: i == 0 ? 6 : 5, // 行标签列宽 6，其余 5 列等分
            child: _buildCell(
              text: labels[i],
              isHeader: true,
              backgroundColor: headerColors[i],
              darkText: i > 0, // 染色列强制深色文字
              rowHeight: _rowHeight(screenWidth),
              screenWidth: screenWidth,
              brightness: brightness,
              // 仅最左 cell 画 outer left；中间 cell 不画 left border，
              // 否则会与左侧 cell 的 borderRight 叠加，形成加粗竖线
              borderLeft: i == 0
                  ? BorderSide(color: border, width: 1.5) // 表格最左边外框
                  : BorderSide.none,
              borderTop: BorderSide(color: border, width: 1.5), // 表格最上边外框
              borderBottom: BorderSide(color: border, width: 1), // 表头与数据分隔（内格线）
              borderRight: BorderSide(
                color: border,
                width: i == labels.length - 1 ? 1.5 : 1, // 最右列为外框 1.5，其余内格线 1
              ),
            ),
          ),
      ],
    );
  }

  // 普通 4 行：note 标签 + 4 个判定列
  Widget _buildNormalNoteRow({
    required String noteLabel,
    required int noteIndex,
    required int totalWeight,
    required double screenWidth,
    required Brightness brightness,
  }) {
    // 普通音符 4 个判定列的 baseScore 系数：PERFECT 1.0 / GREAT 0.8 / GOOD 0.5 / MISS 0
    final List<double> coefficients = [1.00, 0.80, 0.50, 0.00];
    // 4 个判定列的填色（与下方绝赞分布表一致）
    const List<Color> rowJudgmentColors = [
      Color(0xFFFFCA28), // PERFECT → yellow400
      Color(0xFFEF9A9A), // GREAT   → pink200
      Color(0xFFA5D6A7), // GOOD    → green200
      Color(0xFFE0E0E0), // MISS    → grey200
    ];
    final rowH = _rowHeight(screenWidth);
    final border = AppColors.tableBorder(brightness);
    return Row(
      children: [
        // 行标签列（6）
        Expanded(
          flex: 6,
          child: _buildCell(
            text: noteLabel,
            isHeader: true,
            backgroundColor: _noteRowFillColor(brightness),
            rowHeight: rowH,
            screenWidth: screenWidth,
            brightness: brightness,
            borderLeft: BorderSide(color: border, width: 1.5), // 表格最左边外框
            borderRight: BorderSide(color: border, width: 1), // 内格线
            borderBottom: BorderSide(color: border, width: 1), // 内格线
          ),
        ),
        // 4 个判定列（各 5）
        for (int j = 0; j < 4; j++)
          Expanded(
            flex: 5,
            child: _buildCell(
              text: _cellText(
                noteIndex: noteIndex,
                baseCoefficient: coefficients[j],
                totalWeight: totalWeight,
              ),
              isHeader: false,
              backgroundColor: rowJudgmentColors[j],
              darkText: true,
              rowHeight: rowH,
              screenWidth: screenWidth,
              brightness: brightness,
              borderRight: BorderSide(
                color: border,
                width: j == 3 ? 1.5 : 1, // 表格最右边外框
              ),
              borderBottom: BorderSide(color: border, width: 1), // 内格线
            ),
          ),
      ],
    );
  }

  // BREAK 行：3 行高
  // - 标签列（Br）：合并为 1 cell（占 3 行高），居中
  // - PERFECT 列：3 子格（CRITICAL PERFECT / 50落 / 100落），全部系数 1.00
  // - GREAT 列：3 子格（80% GREAT / 60% GREAT / 50% GREAT），分别系数 0.80/0.60/0.50
  // - GOOD 列：合并为 1 cell（占 3 行高），显示 Go 系数 0.40
  // - MISS 列：合并为 1 cell（占 3 行高），显示 Miss 系数 0.00
  // 列间竖线（width: 1）：在 PERFECT↔GREAT、GREAT↔GOOD 之间用独立 Container 分割，
  // 宽度与下方普通行的 borderRight(1) 内格线对齐
  Widget _buildBreakRow(int totalWeight, double screenWidth, Brightness brightness) {
    final rowH = _rowHeight(screenWidth);
    final breakRowH = rowH * 3;
    final border = AppColors.tableBorder(brightness);

    // 列间竖向分隔线（3 行高）
    Widget verticalDivider() => Container(
          width: 1,
          height: breakRowH,
          color: border,
        );

    // 子格渲染辅助（带底分割线）
    Widget subCell(
      String text, {
      required bool isLast,
      Color? color,
    }) {
      return Container(
        height: rowH,
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.01),
        decoration: BoxDecoration(
          color: color,
          border: Border(
            bottom: BorderSide(color: border, width: isLast ? 1.5 : 1),
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: screenWidth * 0.028,
            color: color != null
                ? Colors.black87
                : AppColors.primaryText(brightness),
          ),
        ),
      );
    }

    // 合并格（占满 3 行高），居中显示
    Widget mergedCell(String text, {Color? color}) {
      return Container(
        height: breakRowH,
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.01),
        decoration: BoxDecoration(
          color: color,
          border: Border(
            right: BorderSide(color: border, width: 1),
            bottom: BorderSide(color: border, width: 1.5), // 表格最下边外框
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: screenWidth * 0.028,
            color: color != null
                ? Colors.black87
                : AppColors.primaryText(brightness),
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标签列：合并单格，居中
        Expanded(
          flex: 6,
          child: Container(
            height: breakRowH,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _noteRowFillColor(brightness),
              border: Border(
                left: BorderSide(color: border, width: 1.5), // 表格最左边外框
                right: BorderSide(color: border, width: 1), // 内格线
                bottom: BorderSide(color: border, width: 1.5), // 表格最下边外框
              ),
            ),
            child: Text(
              'BREAK',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: screenWidth * 0.03,
                color: AppColors.primaryText(brightness),
              ),
            ),
          ),
        ),
        // PERFECT 列：3 子格（CRITICAL PERFECT / 50落 / 100落）
        // base 系数 1.00；extra 系数 1.00/0.75/0.50（与 extraBreakWeight 公式一致）
        Expanded(
          flex: 5,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              subCell(
                _cellText(noteIndex: 4, baseCoefficient: 1.00, extraCoefficient: 1.00, totalWeight: totalWeight),
                isLast: false,
                color: _judgmentFillColors[0], // CP     → yellow200
              ),
              subCell(
                _cellText(noteIndex: 4, baseCoefficient: 1.00, extraCoefficient: 0.75, totalWeight: totalWeight),
                isLast: false,
                color: _judgmentFillColors[1], // 50落   → yellow400
              ),
              subCell(
                _cellText(noteIndex: 4, baseCoefficient: 1.00, extraCoefficient: 0.50, totalWeight: totalWeight),
                isLast: true,
                color: _judgmentFillColors[1], // 100落  → yellow400
              ),
            ],
          ),
        ),
        // 列间竖线 1：PERFECT ↔ GREAT
        verticalDivider(),
        // GREAT 列：3 子格（80%/60%/50% GREAT）
        // base 系数 0.80/0.60/0.50；extra 系数都是 0.40
        Expanded(
          flex: 5,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              subCell(
                _cellText(noteIndex: 4, baseCoefficient: 0.80, extraCoefficient: 0.40, totalWeight: totalWeight),
                isLast: false,
                color: _judgmentFillColors[2], // 80% GREAT → pink200
              ),
              subCell(
                _cellText(noteIndex: 4, baseCoefficient: 0.60, extraCoefficient: 0.40, totalWeight: totalWeight),
                isLast: false,
                color: _judgmentFillColors[2], // 60% GREAT → pink200
              ),
              subCell(
                _cellText(noteIndex: 4, baseCoefficient: 0.50, extraCoefficient: 0.40, totalWeight: totalWeight),
                isLast: true,
                color: _judgmentFillColors[2], // 50% GREAT → pink200
              ),
            ],
          ),
        ),
        // 列间竖线 2：GREAT ↔ GOOD
        verticalDivider(),
        // GOOD 列：合并单格，显示 Go（base 0.40 / extra 0.30）
        Expanded(
          flex: 5,
          child: mergedCell(
            _cellText(noteIndex: 4, baseCoefficient: 0.40, extraCoefficient: 0.30, totalWeight: totalWeight),
            color: _judgmentFillColors[3], // GOOD → green200
          ),
        ),
        // MISS 列：合并单格，显示 Miss（base 0 / extra 0）
        Expanded(
          flex: 5,
          child: Container(
            height: breakRowH,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _judgmentFillColors[4], // MISS → grey200
              border: Border(
                right: BorderSide(color: border, width: 1.5), // 表格最右边外框
                bottom: BorderSide(color: border, width: 1.5), // 表格最下边外框
              ),
            ),
            child: Text(
              _cellText(noteIndex: 4, baseCoefficient: 0.00, extraCoefficient: 0.00, totalWeight: totalWeight),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: screenWidth * 0.028,
                color: Colors.black87,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 单格高度（约屏幕高度的 4%）
  double _rowHeight(double screenWidth) =>
      MediaQuery.of(context).size.height * 0.04;

  // 通用单格渲染（用于表头 / 普通行）
  Widget _buildCell({
    required String text,
    required bool isHeader,
    required Color? backgroundColor,
    required double rowHeight,
    required double screenWidth,
    required Brightness brightness,
    bool darkText = false,
    BorderSide borderLeft = BorderSide.none,
    BorderSide borderRight = BorderSide.none,
    BorderSide borderTop = BorderSide.none,
    BorderSide borderBottom = BorderSide.none,
  }) {
    return Container(
      height: rowHeight,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(left: borderLeft, right: borderRight, top: borderTop, bottom: borderBottom),
      ),
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.01),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: screenWidth * 0.028,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          color: darkText ? Colors.black87 : AppColors.primaryText(brightness),
        ),
      ),
    );
  }

  // 目标达成率输入行：左 "目标达成率" 标签 + 中居中输入框 + 右状态标签
  Widget _buildTargetInputRow(double screenWidth, Brightness brightness) {
    final target = double.tryParse(_targetCtrl.text) ?? 0.0;
    final noteCounts = _noteCountCtrls
        .map((c) => int.tryParse(c.text) ?? 0)
        .toList(growable: false);
    final totalWeight = noteCounts
        .asMap()
        .entries
        .fold<int>(0, (sum, e) => sum + e.value * _noteWeights[e.key]);
    final singleTapGreatLoss = totalWeight > 0
        ? (0.20 * 100.00 * _tapWeight / totalWeight)
        : 0.0;
    final tapGreatEquivalentForTarget =
        singleTapGreatLoss > 0 ? ((101.0 - target) / singleTapGreatLoss) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 左侧：目标达成率 标签
            SizedBox(
              width: screenWidth * 0.25,
              child: Text(
                '目标达成率',
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: screenWidth * 0.035,
                  fontWeight: FontWeight.bold,
                  color: AppColors.linkBlue(brightness),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 中间：输入框居中
            Expanded(
              child: Center(
                child: SizedBox(
                  width: screenWidth * 0.3,
                  child: TextField(
                    controller: _targetCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: TextStyle(fontSize: screenWidth * 0.035),
                    onChanged: (v) {
                      final parsed = double.tryParse(v);
                      if (parsed != null && parsed > 101.0) {
                        _targetCtrl.text = '101';
                        _targetCtrl.selection = TextSelection.collapsed(
                          offset: _targetCtrl.text.length,
                        );
                      }
                      setState(() {});
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 右侧：状态徽章
            SizedBox(
              width: screenWidth * 0.2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _buildTargetStatusBadge(screenWidth, brightness),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 容错信息单独成行居中
        Center(
          child: Text(
            '达成 ${target.toStringAsFixed(4)}% 容错为 ${tapGreatEquivalentForTarget.toStringAsFixed(3)} 个 TAP GREAT',
            style: TextStyle(
              fontSize: screenWidth * 0.028,
              color: AppColors.secondaryText(brightness),
            ),
          ),
        ),
      ],
    );
  }

  // 目标达成率状态标签：值 == widget.userAchievement → "用户数据"（绿），
  // 否则 → "自定义"（橙）
  Widget _buildTargetStatusBadge(double screenWidth, Brightness brightness) {
    final currentValue = double.tryParse(_targetCtrl.text) ?? 0.0;
    final isUserData =
        widget.userAchievement != null && currentValue == widget.userAchievement;
    final bgColor = isUserData ? Colors.green.shade100 : Colors.orange.shade100;
    final fgColor = isUserData ? Colors.green.shade800 : Colors.orange.shade800;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isUserData ? '用户数据' : '自定义',
        style: TextStyle(
          fontSize: screenWidth * 0.026,
          color: fgColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // 7 行 BREAK 等效（除 CRITICAL PERFECT 外），每行居中显示
  // 通用公式：(1-base)*25 + (1-extra)*totalW/(20*breakN)
  List<Widget> _buildBreakEquivalentLines(double screenWidth, Brightness brightness) {
    final noteCounts = _noteCountCtrls
        .map((c) => int.tryParse(c.text) ?? 0)
        .toList(growable: false);
    final totalWeight = noteCounts
        .asMap()
        .entries
        .fold<int>(0, (sum, e) => sum + e.value * _noteWeights[e.key]);
    final breakNum = noteCounts[4];

    const List<Map<String, dynamic>> breakSubs = [
      {'label': '50落',       'base': 1.00, 'extra': 0.75},
      {'label': '100落',      'base': 1.00, 'extra': 0.50},
      {'label': '80% GREAT',  'base': 0.80, 'extra': 0.40},
      {'label': '60% GREAT',  'base': 0.60, 'extra': 0.40},
      {'label': '50% GREAT',  'base': 0.50, 'extra': 0.40},
      {'label': 'GOOD',       'base': 0.40, 'extra': 0.30},
      {'label': 'MISS',       'base': 0.00, 'extra': 0.00},
    ];

    final widgets = <Widget>[];
    for (final sub in breakSubs) {
      final base = (sub['base'] as num).toDouble();
      final extra = (sub['extra'] as num).toDouble();
      final equivalent = (totalWeight > 0 && breakNum > 0)
          ? (1.0 - base) * 25.0 + (1.0 - extra) * totalWeight / (20.0 * breakNum)
          : 0.0;
      widgets.add(
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              'BREAK ${sub['label']}相当于 ${equivalent.toStringAsFixed(3)} 个 TAP GREAT',
              style: TextStyle(
                fontSize: screenWidth * 0.028,
                color: AppColors.secondaryText(brightness),
              ),
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  // 构建 5×6 填色表格（note 类型 × 5 种判定 CP/PF/GR/GD/MS），Table 实现
  Widget _buildExcellentTable(double screenWidth, Brightness brightness) {
    final cellFontSize = screenWidth * 0.03;
    // labelCell 背景为 theme-aware 颜色（_noteRowFillColor），用主题感知文字色
    Widget labelCell(String text) => _buildTableCell(text,
        color: _noteRowFillColor(brightness), fontSize: cellFontSize);
    // headerCell 背景为固定 pastel 色（_judgmentFillColors），强制黑字
    Widget headerCell(String text, int colorIdx, {double? fontSize}) =>
        _buildTableCell(text,
            color: _judgmentFillColors[colorIdx],
            fontSize: fontSize ?? cellFontSize,
            darkText: true);
    Widget inputCell(int i, int j) => _buildNumberInputCell(
          value: int.tryParse(_excellentCtrls[i][j].text) ?? 0,
          controller: _excellentCtrls[i][j],
          color: _judgmentFillColors[j],
        );

    return Table(
      border: TableBorder(
        // 内格线 1px
        horizontalInside: BorderSide(color: AppColors.tableBorder(brightness), width: 1),
        verticalInside: BorderSide(color: AppColors.tableBorder(brightness), width: 1),
        // 外围 1.5px
        top: BorderSide(color: AppColors.tableBorder(brightness), width: 1.5),
        bottom: BorderSide(color: AppColors.tableBorder(brightness), width: 1.5),
        left: BorderSide(color: AppColors.tableBorder(brightness), width: 1.5),
        right: BorderSide(color: AppColors.tableBorder(brightness), width: 1.5),
      ),
      children: [
        // 表头（CRITICAL PERFECT 字号调小，与源页 _buildNormalNoteTable 保持一致）
        TableRow(
          children: [
            _buildTableCell('', color: _headerCornerFillColor(brightness), fontSize: cellFontSize),
            headerCell('CRITICAL\nPERFECT', 0, fontSize: cellFontSize * 0.7),
            headerCell('PERFECT', 1),
            headerCell('GREAT', 2),
            headerCell('GOOD', 3),
            headerCell('MISS', 4),
          ],
        ),
        // TAP 行
        TableRow(
          children: [
            labelCell('TAP'),
            inputCell(0, 0), // CP
            inputCell(0, 1), // PF
            inputCell(0, 2), // GR
            inputCell(0, 3), // GD
            inputCell(0, 4), // MS
          ],
        ),
        // HOLD 行
        TableRow(
          children: [
            labelCell('HOLD'),
            inputCell(1, 0), // CP
            inputCell(1, 1), // PF
            inputCell(1, 2), // GR
            inputCell(1, 3), // GD
            inputCell(1, 4), // MS
          ],
        ),
        // SLIDE 行
        TableRow(
          children: [
            labelCell('SLIDE'),
            inputCell(2, 0), // CP
            inputCell(2, 1), // PF
            inputCell(2, 2), // GR
            inputCell(2, 3), // GD
            inputCell(2, 4), // MS
          ],
        ),
        // TOUCH 行
        TableRow(
          children: [
            labelCell('TOUCH'),
            inputCell(3, 0), // CP
            inputCell(3, 1), // PF
            inputCell(3, 2), // GR
            inputCell(3, 3), // GD
            inputCell(3, 4), // MS
          ],
        ),
        // BREAK 行
        TableRow(
          children: [
            labelCell('BREAK'),
            inputCell(4, 0), // CP
            inputCell(4, 1), // PF
            inputCell(4, 2), // GR
            inputCell(4, 3), // GD
            inputCell(4, 4), // MS
          ],
        ),
      ],
    );
  }

  // 构建表格单元格：显式高度（screenHeight × 0.04）让背景填色撑满格子
  // 不要用 SizedBox.expand，会让 Table.intrinsicRowHeight 测到 0 导致整行消失
  // [darkText] true 时强制 Colors.black87（用于浅色 pastel 判定色背景，黑色可读）；
  //             false 时使用主题感知颜色（用于深浅模式自动适配的 cell 背景）。
  Widget _buildTableCell(String text, {Color? color, double fontSize = 12.0, bool darkText = false}) {
    final screenHeight = MediaQuery.of(context).size.height;
    final brightness = Theme.of(context).brightness;
    final Color? textColor = darkText
        ? Colors.black87
        : AppColors.primaryText(brightness);
    return Container(
      height: screenHeight * 0.04,
      decoration: BoxDecoration(color: color),
      padding: EdgeInsets.symmetric(vertical: screenHeight * 0.005),
      alignment: Alignment.center,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: fontSize,
          color: textColor,
        ),
      ),
    );
  }

  // 构建数字输入单元格：显式高度让背景填色撑满
  Widget _buildNumberInputCell({
    required int value,
    required TextEditingController controller,
    required Color color,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: screenHeight * 0.04,
      decoration: BoxDecoration(color: color),
      alignment: Alignment.center,
      padding: EdgeInsets.zero,
      margin: EdgeInsets.zero,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          filled: false,
          border: InputBorder.none,
          hintText: value == 0 ? '' : value.toString(),
          contentPadding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.01,
              vertical: screenHeight * 0.005),
          isDense: true,
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: screenWidth * 0.025,
          color: isDark ? Colors.black87 : null,
        ),
      ),
    );
  }

  Widget _buildExcellentPanel(double screenWidth, Brightness brightness) {
    return _buildCard(
      screenWidth: screenWidth,
      brightness: brightness,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题
          _buildSectionTitle('绝赞分布计算', screenWidth, brightness),
          const SizedBox(height: 8),
          // 5×6 填色表格（note 类型 × 5 种判定），复用 AchievementFullReverseCalculator 的填色配色
          _buildExcellentTable(screenWidth, brightness),
          const SizedBox(height: 12),
          // 目标达成率输入（独立的 _reverseTargetCtrl）
          _buildReverseTargetInputRow(screenWidth, brightness),
          const SizedBox(height: 8),
          // 计算按钮（移植 AchievementFullReverseCalculatorPage 的"计算绝赞详情"）
          _buildReverseCalculateButton(screenWidth, brightness),
          const SizedBox(height: 12),
          // 结果显示
          if (_reverseResultText != null)
            _buildReverseResult(screenWidth, brightness),
        ],
      ),
    );
  }

  // 反推目标达成率输入行（与 AchievementFullReverseCalculatorPage._buildAchievementRateInput 一致）
  Widget _buildReverseTargetInputRow(double screenWidth, Brightness brightness) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('达成率: '),
        SizedBox(
          width: screenWidth * 0.3,
          child: TextField(
            controller: _reverseTargetCtrl,
            decoration: InputDecoration(
              filled: false,
              border: const OutlineInputBorder(),
              hintText: '四位小数',
              contentPadding:
                  EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,4}')),
            ],
            textAlign: TextAlign.center,
            onChanged: (_) => setState(() {}),
          ),
        ),
        SizedBox(width: screenWidth * 0.01),
        const Text('%'),
      ],
    );
  }

  // 反推"计算绝赞详情"按钮（带 loading 状态）
  Widget _buildReverseCalculateButton(double screenWidth, Brightness brightness) {
    return Center(
      child: ElevatedButton(
        onPressed: _calculatingReverse ? null : _calculateFullReverse,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.linkBlue(brightness),
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
              vertical: screenWidth * 0.025,
              horizontal: screenWidth * 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: _calculatingReverse
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: screenWidth * 0.04,
                    height: screenWidth * 0.04,
                    child: const CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  ),
                  SizedBox(width: screenWidth * 0.025),
                  const Text('计算中...'),
                ],
              )
            : Text('计算绝赞详情',
                style: TextStyle(fontSize: screenWidth * 0.035)),
      ),
    );
  }

  // 反推结果显示（与 AchievementFullReverseCalculatorPage 一致：✅/❌ + 50落/100落/80/60/50 + 基础/额外/总达成率/误差）
  Widget _buildReverseResult(double screenWidth, Brightness brightness) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(screenWidth * 0.03),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.linkBlue(brightness)),
      ),
      child: Text(
        _reverseResultText!,
        style: TextStyle(fontSize: screenWidth * 0.03, height: 1.5),
      ),
    );
  }

  // 绝赞反推核心逻辑（移植 AchievementFullReverseCalculatorPage._calculateFullReverse）
  // 输入：5×5 表格（_excellentCtrls）、_reverseTargetCtrl 文本
  // 思路：固定其他 note 总数，遍历 breakP 在 50落/100落 之间的分配，
  //       遍历 breakG 在 80%/60%/50% 之间的分配，找最接近目标达成率的解。
  void _calculateFullReverse() async {
    if (_reverseTargetCtrl.text.isEmpty) {
      _showReverseError('请输入目标达成率');
      return;
    }

    double targetRate;
    try {
      targetRate = double.parse(_reverseTargetCtrl.text);
      if (targetRate < 0 || targetRate > 101) {
        _showReverseError('达成率请输入0~101之间的数值');
        return;
      }
    } catch (e) {
      _showReverseError('达成率格式错误，请输入有效的数字（如100.5000）');
      return;
    }

    setState(() {
      _calculatingReverse = true;
      _reverseResultText = null;
    });

    await Future.delayed(const Duration(milliseconds: 100), () {
      // 读取 5×5 输入
      int tapCp   = int.tryParse(_excellentCtrls[0][0].text) ?? 0;
      int tapP    = int.tryParse(_excellentCtrls[0][1].text) ?? 0;
      int tapG    = int.tryParse(_excellentCtrls[0][2].text) ?? 0;
      int tapGo   = int.tryParse(_excellentCtrls[0][3].text) ?? 0;
      int tapM    = int.tryParse(_excellentCtrls[0][4].text) ?? 0;
      int holdCp  = int.tryParse(_excellentCtrls[1][0].text) ?? 0;
      int holdP   = int.tryParse(_excellentCtrls[1][1].text) ?? 0;
      int holdG   = int.tryParse(_excellentCtrls[1][2].text) ?? 0;
      int holdGo  = int.tryParse(_excellentCtrls[1][3].text) ?? 0;
      int holdM   = int.tryParse(_excellentCtrls[1][4].text) ?? 0;
      int slideCp = int.tryParse(_excellentCtrls[2][0].text) ?? 0;
      int slideP  = int.tryParse(_excellentCtrls[2][1].text) ?? 0;
      int slideG  = int.tryParse(_excellentCtrls[2][2].text) ?? 0;
      int slideGo = int.tryParse(_excellentCtrls[2][3].text) ?? 0;
      int slideM  = int.tryParse(_excellentCtrls[2][4].text) ?? 0;
      int touchCp = int.tryParse(_excellentCtrls[3][0].text) ?? 0;
      int touchP  = int.tryParse(_excellentCtrls[3][1].text) ?? 0;
      int touchG  = int.tryParse(_excellentCtrls[3][2].text) ?? 0;
      int touchGo = int.tryParse(_excellentCtrls[3][3].text) ?? 0;
      int touchM  = int.tryParse(_excellentCtrls[3][4].text) ?? 0;
      int breakCp = int.tryParse(_excellentCtrls[4][0].text) ?? 0;
      int breakP  = int.tryParse(_excellentCtrls[4][1].text) ?? 0;
      int breakG  = int.tryParse(_excellentCtrls[4][2].text) ?? 0;
      int breakGo = int.tryParse(_excellentCtrls[4][3].text) ?? 0;
      int breakM  = int.tryParse(_excellentCtrls[4][4].text) ?? 0;

      // 各类型总数
      int tapNum   = tapCp + tapP + tapG + tapGo + tapM;
      int holdNum  = holdCp + holdP + holdG + holdGo + holdM;
      int slideNum = slideCp + slideP + slideG + slideGo + slideM;
      int touchNum = touchCp + touchP + touchG + touchGo + touchM;
      int breakNum = breakCp + breakP + breakG + breakGo + breakM;

      // 总权重
      int totalTapWeight   = tapNum * _tapWeight;
      int totalHoldWeight  = holdNum * _holdWeight;
      int totalSlideWeight = slideNum * _slideWeight;
      int totalTouchWeight = touchNum * _touchWeight;
      int totalBreakWeight = breakNum * _breakWeight;
      int totalWeight = totalTapWeight +
          totalHoldWeight +
          totalSlideWeight +
          totalTouchWeight +
          totalBreakWeight;

      // 非 break 部分基础得分
      double baseTap   = _tapWeight   * (tapCp   + tapP   + tapG   * 0.8 + tapGo   * 0.5);
      double baseHold  = _holdWeight  * (holdCp  + holdP  + holdG  * 0.8 + holdGo  * 0.5);
      double baseSlide = _slideWeight * (slideCp + slideP + slideG * 0.8 + slideGo * 0.5);
      double baseTouch = _touchWeight * (touchCp + touchP + touchG * 0.8 + touchGo * 0.5);
      double baseNonBreak = baseTap + baseHold + baseSlide + baseTouch;

      // 反推迭代
      bool found = false;
      const double errorThreshold = 0.0001;
      String result = '';
      int bestP75 = 0, bestP50 = 0, bestG80 = 0, bestG60 = 0, bestG50 = 0;
      double bestBaseScore = 0, bestExtraScore = 0, bestTotalScore = 0;
      double minError = double.infinity;

      for (int breakP75 = 0; breakP75 <= breakP; breakP75++) {
        int breakP50 = breakP - breakP75;
        for (int breakG80 = 0; breakG80 <= breakG; breakG80++) {
          for (int breakG60 = 0; breakG60 <= breakG - breakG80; breakG60++) {
            int breakG50 = breakG - breakG80 - breakG60;

            // base: breakP 不论 50落/100落 都按 1.0 算
            double baseBreak = _breakWeight *
                (breakCp +
                    breakP +
                    breakG80 * 0.8 +
                    breakG60 * 0.6 +
                    breakG50 * 0.5 +
                    breakGo * 0.4);
            double baseTotal = baseNonBreak + baseBreak;
            double baseScore = (baseTotal / totalWeight) * 100;
            baseScore = double.parse(baseScore.toStringAsFixed(4));

            // extra: breakP 50落=0.75, 100落=0.50; breakG 80/60/50 都 0.40
            double extraBreak = breakCp +
                breakP75 * 0.75 +
                breakP50 * 0.50 +
                (breakG80 + breakG60 + breakG50) * 0.40 +
                breakGo * 0.30;
            double extraScore = breakNum == 0 ? 0 : (extraBreak / breakNum);
            extraScore = double.parse(extraScore.toStringAsFixed(4));

            double totalScore = baseScore + extraScore;
            totalScore = double.parse(totalScore.toStringAsFixed(4));
            double error = (totalScore - targetRate).abs();

            if (error < minError) {
              minError = error;
              bestP75 = breakP75;
              bestP50 = breakP50;
              bestG80 = breakG80;
              bestG60 = breakG60;
              bestG50 = breakG50;
              bestBaseScore = baseScore;
              bestExtraScore = extraScore;
              bestTotalScore = totalScore;
            }

            if (error <= errorThreshold) {
              result = """✅ 找到可行解（误差≤0.0001%）：
目标达成率：${targetRate.toStringAsFixed(4)}%
50落 = $breakP75
100落 = $breakP50
80% GREAT = $breakG80
60% GREAT = $breakG60
50% GREAT = $breakG50
基础达成率：$baseScore%
额外达成率：$extraScore%
总达成率：$totalScore%
误差：$error%""";
              found = true;
              break;
            }
          }
          if (found) break;
        }
        if (found) break;
      }

      if (!found) {
        result = """❌ 未找到符合误差阈值的解，以下是最接近的结果：
目标达成率：${targetRate.toStringAsFixed(4)}%
50落 = $bestP75
100落 = $bestP50
80% GREAT = $bestG80
60% GREAT = $bestG60
50% GREAT = $bestG50
基础达成率：${bestBaseScore}%
额外达成率：${bestExtraScore}%
总达成率：${bestTotalScore}%
最小误差：${minError}%""";
      }

      setState(() {
        _calculatingReverse = false;
        _reverseResultText = result;
      });
    });
  }

  void _showReverseError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('输入错误'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// UI 通用组件（主题感知）
// ============================================================================
Widget _buildCard({
  required double screenWidth,
  required Brightness brightness,
  required Widget child,
}) {
  return Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: AppColors.cardBackgroundTranslucent(brightness),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.tableBorder(brightness), width: 2),
      boxShadow: [AppColors.defaultShadow(brightness)],
    ),
    padding: const EdgeInsets.all(12),
    child: child,
  );
}

Widget _buildSectionTitle(String text, double screenWidth, Brightness brightness) {
  return Text(
    text,
    style: TextStyle(
      fontSize: screenWidth * 0.035,
      fontWeight: FontWeight.bold,
      color: AppColors.linkBlue(brightness),
    ),
  );
}