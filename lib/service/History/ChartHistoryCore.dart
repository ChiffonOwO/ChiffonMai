/// 成绩历史（Rating / 单谱达成率 / 单谱 DX 分）的**纯逻辑核心**。
///
/// 为什么单独一层：历史只能靠「每次刷新成绩时存一份当前值 → 和上次比 → 只记变化」
/// 攒出来（水鱼/落雪都只给最新成绩，没有历史接口）。这一层的每个函数都不碰 I/O，
/// 于是阈值、并列、降采样这些**最容易写歪**的口径可以被单测直接钉住。
///
/// 数据规模估算（这是"只记变化"而不是"每次存全量"的原因）：
///   * 全量快照：3000 条谱面 × 按秒存一年会产生大量重复；
///   * 只记变化：3000 条基线 + 每年约 5 次/谱面的变化 ≈ 450 KB/年。
library;

import 'dart:math' as math;

/// 谱面键：`'<songId>/<levelIndex>'`（与 App 其它地方的口径一致）。
String chartKeyOf(int songId, int levelIndex) => '$songId/$levelIndex';

/// 难度中文化的短名（历史列表里显示用）。
const List<String> chartDifficultyLabels = [
  'BASIC',
  'ADVANCED',
  'EXPERT',
  'MASTER',
  'Re:MASTER',
  'UTAGE',
];

String difficultyLabelOf(int levelIndex) =>
    (levelIndex >= 0 && levelIndex < chartDifficultyLabels.length)
        ? chartDifficultyLabels[levelIndex]
        : '难度$levelIndex';

/// 一次刷新里读到的**当前成绩**。
class ChartSnapshot {
  const ChartSnapshot({
    required this.songId,
    required this.levelIndex,
    required this.achievement,
    required this.dxScore,
  });

  final int songId;
  final int levelIndex;

  /// 达成率（四位小数，例如 100.5678）。
  final double achievement;

  /// DX 分数（拿不到时为 0）。
  final int dxScore;

  String get key => chartKeyOf(songId, levelIndex);

  @override
  String toString() => 'ChartSnapshot($key, ach=$achievement, dx=$dxScore)';
}

/// 一张谱面**当前记录到的成绩**（也就是最近一次采集到的值）。
///
/// 和 [ChartHistoryEvent] 的区别：事件是"变化"，基线是"现状"。
/// 刚装上这个功能、只采集过一次时，事件是空的（没有变化），但基线已经有了——
/// UI 靠它来区分「这张谱面还没被记录过」和「记录过、只是还没有变化」。
class ChartBaseline {
  const ChartBaseline({
    required this.achievement,
    required this.dxScore,
    required this.tMs,
  });

  final double achievement;
  final int dxScore;

  /// 基线是哪一次采集写下的（0 表示旧数据里没存时间）。
  final int tMs;
}

/// 一条谱面成绩的变化事件：`[时间戳ms, 达成率, DX分]`。
///
/// 用 List 而不是对象是为了落盘紧凑（几千条谱面各存若干条时，字段名很占地方）。
class ChartHistoryEvent {
  const ChartHistoryEvent({
    required this.tMs,
    required this.achievement,
    required this.dxScore,
  });

  final int tMs;
  final double achievement;
  final int dxScore;

  static ChartHistoryEvent? fromJson(dynamic raw) {
    if (raw is! List || raw.length < 3) return null;
    final t = (raw[0] as num?)?.toInt();
    final ach = (raw[1] as num?)?.toDouble();
    final dx = (raw[2] as num?)?.toInt();
    if (t == null || ach == null || dx == null) return null;
    return ChartHistoryEvent(tMs: t, achievement: ach, dxScore: dx);
  }

  List<num> toJson() => [tMs, achievement, dxScore];
}

/// Rating 曲线上的一个点。
///
/// 记点规则见 [appendRatingPoint]：
///   * **Rating 没变不记新点**（所以同值不会连着出现多条）；
///   * 同一秒再刷新就替换那个点；
///   * Rating 没变化时仍不新增自动采集点，但手动录入可保留同值的指定时间点；
///   * 自动采集最多保留 10000 个点；手动记录单独保存。
class RatingPoint {
  const RatingPoint({
    required this.tMs,
    required this.rating,
    this.best35 = 0,
    this.best15 = 0,
    this.recordCount = 0,
  });

  final int tMs;
  final int rating;
  final int best35;
  final int best15;

  /// 当时的成绩条数（能顺带看出"最近有没有在打"）。
  final int recordCount;

  DateTime get day => DateTime.fromMillisecondsSinceEpoch(tMs);

  static RatingPoint? fromJson(dynamic raw) {
    if (raw is! List || raw.length < 2) return null;
    final t = (raw[0] as num?)?.toInt();
    final rating = (raw[1] as num?)?.toInt();
    if (t == null || rating == null) return null;
    return RatingPoint(
      tMs: t,
      rating: rating,
      best35: (raw.length > 2 ? raw[2] as num? : null)?.toInt() ?? 0,
      best15: (raw.length > 3 ? raw[3] as num? : null)?.toInt() ?? 0,
      recordCount: (raw.length > 4 ? raw[4] as num? : null)?.toInt() ?? 0,
    );
  }

  List<num> toJson() => [tMs, rating, best35, best15, recordCount];
}

/// `diffChartSnapshots` 的结果。
class ChartHistoryDiff {
  const ChartHistoryDiff({
    required this.current,
    required this.events,
    required this.baseline,
  });

  /// 新的「最后已知值」：`key → [达成率, DX分, 时间戳]`。
  final Map<String, List<num>> current;

  /// **本次**发生变化的谱面事件：`key → [[t, ach, dx], ...]`（通常很小）。
  final Map<String, List<List<num>>> events;

  /// 是否是首次建立基线（此时**不产生任何事件**：没有可比的上一次）。
  final bool baseline;

  int get changedCount => events.length;
}

/// 从成绩记录里解析快照。
///
/// 容错原则（两个数据源的字段名并不完全一致，缓存前虽已归一化，但历史是
/// 长期数据，宁可多认几种写法也不要因为一次改字段就断档）：
///   * songId：`song_id` / `songId` / `id`
///   * levelIndex：`level_index` / `levelIndex` / `difficulty`
///   * 达成率：`achievements` / `achievement` / `achieve`
///   * DX 分：`dxScore` / `dx_score` / `deluxscoreMax` / `deluxeScoreMax`
///
/// 达成率 ≤ [minAchievement] 的行直接丢掉：那不是"打过了"，而是空占位。
List<ChartSnapshot> snapshotsFromRecords(
  dynamic records, {
  double minAchievement = 0.0001,
}) {
  if (records is! List) return const [];
  final byKey = <String, ChartSnapshot>{};

  for (final raw in records) {
    if (raw is! Map) continue;
    final songId = _pickInt(raw, const ['song_id', 'songId', 'id', 'musicId']);
    final levelIndex =
        _pickInt(raw, const ['level_index', 'levelIndex', 'difficulty']);
    final achievement = _pickDouble(
      raw,
      const ['achievements', 'achievement', 'achieve', 'achievementRate'],
    );
    final dxScore = _pickInt(
      raw,
      const ['dxScore', 'dx_score', 'deluxscoreMax', 'deluxeScoreMax'],
    );

    if (songId == null || songId <= 0 || levelIndex == null) continue;
    if (achievement == null || achievement <= minAchievement) continue;

    final snap = ChartSnapshot(
      songId: songId,
      levelIndex: levelIndex,
      achievement: achievement,
      dxScore: dxScore ?? 0,
    );
    // 同一谱面出现多条（理论上不该有）时留达成率更高的那条，与游戏口径一致
    final prev = byKey[snap.key];
    if (prev == null || snap.achievement > prev.achievement) {
      byKey[snap.key] = snap;
    }
  }
  return byKey.values.toList();
}

/// 与上一次的「最后已知值」比较，算出新的基线 + 本次变化事件。
///
/// [previousCurrent] 为 null / 空 = 首次采集：只建立基线，**不产生事件**
/// （否则第一次就会凭空多出几千条"历史"）。
///
/// 变化判定用 [achievementEpsilon] 容差：水鱼 / 落雪 / AWMC 三个来源对同一条
/// 成绩的四位小数偶尔会差 0.0001，不放容差就会被记成"你又打了一遍"。
ChartHistoryDiff diffChartSnapshots({
  required Map<String, List<num>>? previousCurrent,
  required List<ChartSnapshot> incoming,
  required int nowMs,
  double achievementEpsilon = 0.0001,
}) {
  nowMs = historySecond(nowMs);
  final baseline = previousCurrent == null || previousCurrent.isEmpty;
  final nextCurrent = <String, List<num>>{};
  final events = <String, List<List<num>>>{};

  // 先把旧值搬进来：数据源某次没返回某条谱面时，不能把它从基线里删掉
  // （删了下次再出现就会被当成"新成绩"，凭空多一条事件）。
  if (!baseline) {
    previousCurrent.forEach((key, value) {
      nextCurrent[key] = List<num>.from(value);
    });
  }

  for (final snap in incoming) {
    final prev = baseline ? null : previousCurrent[snap.key];
    if (prev == null) {
      nextCurrent[snap.key] = [snap.achievement, snap.dxScore, nowMs];
      if (!baseline) {
        // 基线里没有 = 新打出来的成绩，值得记一条
        (events[snap.key] ??= []).add([nowMs, snap.achievement, snap.dxScore]);
      }
      continue;
    }

    final prevAch = (prev.isNotEmpty ? prev[0] : 0).toDouble();
    final prevDx = (prev.length > 1 ? prev[1] : 0).toInt();
    final achChanged = (snap.achievement - prevAch).abs() >= achievementEpsilon;
    final dxChanged = snap.dxScore != prevDx;

    if (achChanged || dxChanged) {
      nextCurrent[snap.key] = [snap.achievement, snap.dxScore, nowMs];
      (events[snap.key] ??= []).add([nowMs, snap.achievement, snap.dxScore]);
    }
    // 没变：保留旧值（含旧时间戳），这样"最后变化时间"才是真的
  }

  return ChartHistoryDiff(
    current: nextCurrent,
    events: events,
    baseline: baseline,
  );
}

/// 把新事件并进已有事件列表，并做降采样。
///
/// [max]：单谱最多留多少条；超出后保留**最近 [keepRecent] 条**，
/// 更早的按每 [olderEveryDays] 天留一条（保留趋势，不保留噪音）。
List<List<num>> mergeAndPruneEvents(
  List<List<num>> existing,
  List<List<num>> incoming, {
  int max = 50,
  int keepRecent = 20,
  int olderEveryDays = 7,
}) {
  final bySecond = <int, List<num>>{
    for (final event in [...existing, ...incoming])
      historySecond(_timeOf(event)): [
        historySecond(_timeOf(event)),
        ...event.skip(1)
      ],
  };
  final all = bySecond.values.toList()
    ..sort((a, b) => _timeOf(a).compareTo(_timeOf(b)));
  if (all.length <= max) return all;

  final kept = <List<num>>[];
  final recentStart = all.length - keepRecent;
  int? lastOlderKeptMs;
  for (var i = all.length - 1; i >= 0; i--) {
    if (i >= recentStart) {
      kept.add(all[i]);
      continue;
    }
    final t = _timeOf(all[i]);
    final gap = olderEveryDays * 24 * 3600 * 1000;
    if (lastOlderKeptMs == null || lastOlderKeptMs - t >= gap) {
      kept.add(all[i]);
      lastOlderKeptMs = t;
    }
  }
  return kept.reversed.toList();
}

/// [appendRatingPoint] 的结果：新序列 + 这次到底有没有动过曲线。
///
/// 调用方靠 [changed] 区分"真的记了一笔"和"Rating 没变所以跳过"，
/// 日志和界面提示都别把后者说成前者。
class RatingAppendResult {
  const RatingAppendResult(this.series, {required this.changed});

  final List<RatingPoint> series;

  /// false = Rating 与上一个点相同，序列原样返回。
  final bool changed;
}

/// 保留毫秒文件格式，新记录对齐到整秒。
int historySecond(int ms) => ms ~/ 1000 * 1000;

/// 自动采集：同秒更新，不同秒保留变化；数值没变时不新增点。
/// 自动记录最多保留 [maxPoints] 个点，手动记录不参与裁剪。
RatingAppendResult appendRatingPoint(
  List<RatingPoint> series,
  RatingPoint point, {
  int maxPoints = 10000,
}) {
  final normalized = RatingPoint(
    tMs: historySecond(point.tMs),
    rating: point.rating,
    best35: point.best35,
    best15: point.best15,
    recordCount: point.recordCount,
  );
  final next = mergeRatingPoints(series);

  if (next.isEmpty) {
    next.add(normalized);
  } else {
    final sameTimestamp =
        next.lastIndexWhere((p) => historySecond(p.tMs) == normalized.tMs);
    if (sameTimestamp >= 0) {
      next[sameTimestamp] = normalized;
    } else if (next.last.rating == normalized.rating) {
      return RatingAppendResult(series, changed: false);
    } else {
      next.add(normalized);
    }
  }

  next.sort((a, b) => a.tMs.compareTo(b.tMs));
  if (next.length > maxPoints) {
    next.removeRange(0, next.length - maxPoints);
  }
  return RatingAppendResult(next, changed: true);
}

/// 按秒合并 Rating 点，同一秒保留最后一个。
List<RatingPoint> mergeRatingPoints(Iterable<RatingPoint> points) {
  final bySecond = <int, RatingPoint>{
    for (final point in points)
      historySecond(point.tMs): RatingPoint(
        tMs: historySecond(point.tMs),
        rating: point.rating,
        best35: point.best35,
        best15: point.best15,
        recordCount: point.recordCount,
      ),
  };
  return bySecond.values.toList()..sort((a, b) => a.tMs.compareTo(b.tMs));
}

/// 「好看」的坐标轴范围与刻度间隔。
///
/// 为什么需要：直接拿 padded min/max 当上下界，轴上会出现 98.7 / 101.2 / 16956
/// 这种读不出来的刻度。这里把范围对齐到 1/2/2.5/5/10 × 10^n 的"整数档"，
/// 于是刻度变成 99 / 100 / 101、16000 / 16500 / 17000。
///
/// 返回的 [interval] 交给 fl_chart 当刻度间隔，保证每一格都是整档数值。
({double min, double max, double interval}) niceAxisRange(
  double dataMin,
  double dataMax, {
  int targetTicks = 4,
}) {
  if (!dataMin.isFinite || !dataMax.isFinite) {
    return (min: 0, max: 1, interval: 1);
  }
  var lo = math.min(dataMin, dataMax);
  var hi = math.max(dataMin, dataMax);
  if (hi - lo < 1e-9) {
    // 只有一个值：给一点高度，否则画不出东西
    final bump = lo.abs() < 1 ? 0.1 : (lo.abs() * 0.01).clamp(0.1, 100.0);
    lo -= bump;
    hi += bump;
  }

  final rough = (hi - lo) / math.max(1, targetTicks);
  final magnitude =
      math.pow(10, (math.log(rough) / math.ln10).floor()).toDouble();
  var step = magnitude;
  for (final m in const [1.0, 2.0, 2.5, 5.0, 10.0]) {
    if (m * magnitude >= rough) {
      step = m * magnitude;
      break;
    }
  }

  final niceLo = (lo / step).floorToDouble() * step;
  var niceHi = (hi / step).ceilToDouble() * step;
  if (niceHi <= niceLo) niceHi = niceLo + step;
  return (min: niceLo, max: niceHi, interval: step);
}

/// 横轴刻度是否该精确到「时:分:秒」。
///
/// **只有一个记录点时必须为 false**：此时横轴根本没有跨度可言，而 fl_chart 对
/// 任何 min/max 都会画出「起点 / 中点 / 终点」三个刻度（实测 minX=-0.5、
/// maxX=0.5、interval=1 时给出 -0.5 / 0 / 0.5，三个都落在同一个点上）。
/// 秒级文案 `9/18 14:30:05` 有 20 个字符，三个挤在同一处必然互相压字、还会顶出
/// 画布 —— 只有一个点时横轴显示到「日」就够了。
///
/// 跨度超过 [windowMs]（默认 2 天）时秒也没有意义：一格往往是好几天。
///
/// 两个页面（Rating 历史页、曲目详情页的成绩历史）必须同口径，所以规则放在这里。
bool showSecondPrecisionAxis(
  int firstMs,
  int lastMs,
  int pointCount, {
  int windowMs = 2 * 24 * 3600 * 1000,
}) =>
    pointCount > 1 && (lastMs - firstMs) < windowMs;

/// 单谱事件 → 曲线用的点（按时间升序，去掉坏数据）。
List<ChartHistoryEvent> sortedEvents(Iterable<dynamic> raw) {
  final list = <ChartHistoryEvent>[];
  for (final item in raw) {
    final e = ChartHistoryEvent.fromJson(item);
    if (e != null) {
      list.add(ChartHistoryEvent(
        tMs: historySecond(e.tMs),
        achievement: e.achievement,
        dxScore: e.dxScore,
      ));
    }
  }
  list.sort((a, b) => a.tMs.compareTo(b.tMs));
  return list;
}

/// 单谱曲线是否出现"下降"。
///
/// 游戏里成绩取最高值，所以达成率与 DX 分**理论上单调不减**；
/// 真出现下降，几乎一定是数据源/账号变了造成的假事件，
/// UI 可以据此提示「疑似换源」，而不是让用户以为自己的成绩退了。
bool hasRegression(List<ChartHistoryEvent> events, {double epsilon = 0.0001}) {
  for (var i = 1; i < events.length; i++) {
    if (events[i].achievement < events[i - 1].achievement - epsilon) {
      return true;
    }
  }
  return false;
}

/// 事件列表里最大/最小的达成率与 DX 分（画图时决定 Y 轴范围用）。
({double minAch, double maxAch, int minDx, int maxDx}) eventRange(
  List<ChartHistoryEvent> events,
) {
  if (events.isEmpty) {
    return (minAch: 0, maxAch: 0, minDx: 0, maxDx: 0);
  }
  var minAch = events.first.achievement;
  var maxAch = events.first.achievement;
  var minDx = events.first.dxScore;
  var maxDx = events.first.dxScore;
  for (final e in events) {
    minAch = math.min(minAch, e.achievement);
    maxAch = math.max(maxAch, e.achievement);
    minDx = math.min(minDx, e.dxScore);
    maxDx = math.max(maxDx, e.dxScore);
  }
  return (minAch: minAch, maxAch: maxAch, minDx: minDx, maxDx: maxDx);
}

// ==================== 内部工具 ====================

int _timeOf(List<num> raw) => raw.isEmpty ? 0 : raw[0].toInt();

int? _pickInt(Map raw, List<String> keys) {
  for (final k in keys) {
    final v = raw[k];
    if (v == null) continue;
    if (v is int) return v;
    if (v is num) return v.toInt();
    final parsed = int.tryParse(v.toString().trim());
    if (parsed != null) return parsed;
  }
  return null;
}

double? _pickDouble(Map raw, List<String> keys) {
  for (final k in keys) {
    final v = raw[k];
    if (v == null) continue;
    if (v is num) return v.toDouble();
    final parsed = double.tryParse(v.toString().trim());
    if (parsed != null) return parsed;
  }
  return null;
}
