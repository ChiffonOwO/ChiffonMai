import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../AccountStore.dart';

import '../../utils/CurrentDataSourceNotifier.dart';
import 'ChartHistoryCore.dart';

/// 成绩历史（Rating / 单谱达成率 / DX）持久化。
///
/// 按平台 + 账号 ID 分文件。刷新事务验证身份后传入固定身份，查询好友不采集。
/// 同一文件的写盘串行执行，以临时文件 + rename 保留完整 JSON。
/// 旧的按源历史在升级时绑定给原账号，并保留原文件备份。
class ChartHistoryStore {
  ChartHistoryStore._();

  static final ChartHistoryStore instance = ChartHistoryStore._();

  /// 落盘目录名（在应用支持目录下）。
  static const String dirName = 'history';

  /// 存储格式版本：字段结构变了就丢弃旧文件（历史是"能丢但不想丢"的数据，
  /// 与其带着半截结构跑，不如从新版本重新攒）。
  static const int schemaVersion = 1;

  /// 单文件最大谱面条数（防御性上限：真出现异常数据别把内存撑爆）。
  static const int maxCharts = 20000;

  /// 仅供测试：覆盖落盘目录，避免碰真实目录。
  @visibleForTesting
  static String? debugDirectoryOverride;

  /// 仅供测试：读盘时是否跳过缓存（用来验证"真的写进文件了"）。
  @visibleForTesting
  static bool debugBypassCache = false;

  /// 仅供测试：替换 Rating 曲线的读取实现。
  ///
  /// 为什么需要：widget 测试跑在 fake async 里，**真实文件 I/O 的 await 永远不会完成**
  /// （页面会一直停在加载态、甚至把测试挂死）。UI 测试用注入的数据，
  /// 真实文件读写由 `test/chart_history_test.dart` 覆盖。
  @visibleForTesting
  static Future<List<RatingPoint>> Function()? debugRatingSeriesLoader;

  /// 仅供测试：替换概览的读取实现（同上）。
  @visibleForTesting
  static Future<ChartHistorySummary> Function()? debugSummaryLoader;

  /// 仅供测试：替换单谱历史的读取实现（同上）。
  @visibleForTesting
  static Future<List<ChartHistoryEvent>> Function(int songId, int levelIndex)?
      debugChartEventsLoader;

  /// 仅供测试：替换单谱基线的读取实现（同上）。
  @visibleForTesting
  static Future<ChartBaseline?> Function(int songId, int levelIndex)?
      debugChartBaselineLoader;

  /// 仅供测试：替换 Rating 记录点的删除实现（同 [debugRatingSeriesLoader]，
  /// widget 测试里真实文件 I/O 的 await 永远不会完成）。
  @visibleForTesting
  static Future<bool> Function(int tMs)? debugRatingPointDeleter;

  /// 仅供测试：替换单谱记录点的删除实现（同上）。
  @visibleForTesting
  static Future<bool> Function(int songId, int levelIndex, int tMs)?
      debugChartPointDeleter;

  final Map<String, _HistoryDoc> _cache = {};
  final Map<String, Future<_HistoryDoc>> _loading = {};
  final Map<String, Future<void>> _writes = {};

  /// 采集抑制深度（好友对比期间 > 0）。
  static final Object _suppressionKey = Object();

  bool get isRecordingSuppressed => Zone.current[_suppressionKey] == true;

  /// 在 [body] 执行期间**不采集任何历史**（好友对比那种借用缓存的操作专用）。
  Future<T> runWithoutRecording<T>(Future<T> Function() body) async {
    return runZoned(body, zoneValues: {_suppressionKey: true});
  }

  /// 当前数据源（水鱼 / 落雪）——历史的隔离键。
  static String currentSourceKey() =>
      CurrentDataSourceNotifier.instance.value.key;

  /// source + 账号身份组成历史命名空间；相同 QQ 在不同平台也互不相干。
  static Future<String> storageKey({String? sourceKey, String? accountId}) =>
      AccountStore.accountKey(sourceKey: sourceKey, accountId: accountId);

  /// 升级时只把旧的按源文件绑定给升级前已知的账号；换人后绝不再认领。
  /// 保留原文件作为备份，不猜测历史中每个点的真实身份。
  Future<bool> migrateLegacy(String source, String id) async {
    if (id.isEmpty) return true;
    try {
      final original = await _fileFor(source);
      final targetKey = await storageKey(sourceKey: source, accountId: id);
      final target = await _fileFor(targetKey);
      if (await original.exists() && !await target.exists()) {
        await original.copy(target.path);
        _cache.remove(targetKey);
      }
      return true;
    } catch (e) {
      debugPrint('[History] 旧历史保留，迁移未完成: $e');
      return false;
    }
  }

  // ==================== 写入 ====================

  /// 用自己的**成绩记录**采集一次（记录形状与水鱼/落雪缓存一致）。
  ///
  /// [reason] 只进日志，便于排查"这条历史是哪次刷新记的"。
  Future<void> recordChartSnapshot(
    Map<String, dynamic> userData, {
    String? sourceKey,
    String? accountId,
    int? nowMs,
    String reason = '',
  }) async {
    if (isRecordingSuppressed) return;
    try {
      final records = userData['records'];
      final snapshots = snapshotsFromRecords(records);
      if (snapshots.isEmpty) {
        debugPrint('[History] 这次没有解析出任何成绩，跳过采集（$reason）');
        return;
      }

      final source =
          await storageKey(sourceKey: sourceKey, accountId: accountId);
      final doc = await _load(source);
      final diff = diffChartSnapshots(
        previousCurrent: doc.current.isEmpty ? null : doc.current,
        incoming: snapshots,
        nowMs: nowMs ?? DateTime.now().millisecondsSinceEpoch,
      );

      doc.current = diff.current;
      diff.events.forEach((key, list) {
        doc.events[key] =
            mergeAndPruneEvents(doc.events[key] ?? const [], list);
      });
      doc.updatedAtMs = nowMs ?? DateTime.now().millisecondsSinceEpoch;
      doc.recordCount = snapshots.length;

      await _persist(source, doc);
      debugPrint('[History] $source 采集完成：${snapshots.length} 条成绩 / '
          '${diff.baseline ? '建立基线' : '${diff.changedCount} 条变化'}（$reason）');
    } catch (e) {
      debugPrint('[History] 采集失败（忽略，不影响刷新）: $e');
    }
  }

  /// 记一个 Rating 点（数值直接取界面用的那份，保证口径一致）。
  Future<void> recordRating({
    required int rating,
    int best35 = 0,
    int best15 = 0,
    int recordCount = 0,
    String? sourceKey,
    String? accountId,
    int? nowMs,
  }) async {
    if (isRecordingSuppressed) return;
    if (rating <= 0) return; // 没登录 / 没数据时不记，免得曲线上出现 0 的坑
    try {
      final source =
          await storageKey(sourceKey: sourceKey, accountId: accountId);
      final doc = await _load(source);
      final t = historySecond(nowMs ?? DateTime.now().millisecondsSinceEpoch);
      final result = appendRatingPoint(
        doc.rating,
        RatingPoint(
          tMs: t,
          rating: rating,
          best35: best35,
          best15: best15,
          recordCount: recordCount > 0 ? recordCount : doc.recordCount,
        ),
      );
      if (!result.changed) {
        // Rating 没变 → 不记新点，但"最近一次检查时间"仍然要更新，
        // 否则界面上会看不出数据其实是新的。
        doc.updatedAtMs = t;
        await _persist(source, doc);
        debugPrint('[History] $source Rating=$rating 与上一个点相同，不记新点'
            '（${doc.rating.length} 个点）');
        return;
      }
      doc.rating = result.series;
      doc.updatedAtMs = t;
      await _persist(source, doc);
      debugPrint(
          '[History] $source 记录 Rating=$rating（${doc.rating.length} 个点）');
    } catch (e) {
      debugPrint('[History] 记录 Rating 失败（忽略）: $e');
    }
  }

  /// 手动点单独保存，不受自动采集的去重、降采样影响。
  /// 保存失败向上抛出，让录入对话框保留内容并提示重试。
  Future<void> recordManualRating({
    required int rating,
    required int tMs,
    int best35 = 0,
    int best15 = 0,
    String? sourceKey,
    String? accountId,
  }) async {
    if (rating <= 0 || historySecond(tMs) <= 0 || best35 < 0 || best15 < 0) {
      throw ArgumentError('Rating 或时间无效');
    }
    final source = await storageKey(sourceKey: sourceKey, accountId: accountId);
    final doc = await _load(source);
    doc.manualRating = mergeRatingPoints([
      ...doc.manualRating,
      RatingPoint(
          tMs: historySecond(tMs),
          rating: rating,
          best35: best35,
          best15: best15),
    ]);
    doc.updatedAtMs = DateTime.now().millisecondsSinceEpoch;
    await _persist(source, doc);
  }

  /// 手动谱面记录不修改自动采集基线；补录旧成绩不会影响下一次刷新比较。
  Future<void> recordManualChartPoint({
    required int songId,
    required int levelIndex,
    required double achievement,
    required int dxScore,
    required int tMs,
    String? sourceKey,
    String? accountId,
  }) async {
    if (songId <= 0 ||
        levelIndex < 0 ||
        !achievement.isFinite ||
        achievement < 0 ||
        achievement > 202 ||
        dxScore < 0 ||
        historySecond(tMs) <= 0) {
      throw ArgumentError('谱面成绩或时间无效');
    }
    final source = await storageKey(sourceKey: sourceKey, accountId: accountId);
    final doc = await _load(source);
    final key = chartKeyOf(songId, levelIndex);
    final bySecond = <int, List<num>>{
      for (final e in doc.manualEvents[key] ?? <List<num>>[])
        historySecond(e[0].toInt()): e,
      historySecond(tMs): [historySecond(tMs), achievement, dxScore],
    };
    doc.manualEvents[key] = bySecond.values.toList()
      ..sort((a, b) => a[0].compareTo(b[0]));
    doc.updatedAtMs = DateTime.now().millisecondsSinceEpoch;
    await _persist(source, doc);
  }

  // ==================== 删除 ====================

  /// 删除一个 Rating 记录点（按整秒匹配，自动采集与手动补录都删）。
  ///
  /// 返回是否真的删掉了东西：同一秒在文件里找不到时返回 false，
  /// 让 UI 能区分「删成功了」和「这条早就没了」。
  Future<bool> deleteRatingPoint({
    required int tMs,
    String? sourceKey,
    String? accountId,
  }) async {
    final second = historySecond(tMs);
    final deleter = debugRatingPointDeleter;
    if (deleter != null) return deleter(second);
    final source = await storageKey(sourceKey: sourceKey, accountId: accountId);
    final doc = await _load(source);
    final before = doc.rating.length + doc.manualRating.length;
    doc.rating = [
      for (final p in doc.rating)
        if (historySecond(p.tMs) != second) p,
    ];
    doc.manualRating = [
      for (final p in doc.manualRating)
        if (historySecond(p.tMs) != second) p,
    ];
    if (doc.rating.length + doc.manualRating.length == before) return false;
    doc.updatedAtMs = DateTime.now().millisecondsSinceEpoch;
    await _persist(source, doc);
    debugPrint('[History] $source 删除 Rating 记录点 ${second ~/ 1000}'
        '（剩 ${doc.rating.length + doc.manualRating.length} 个点）');
    return true;
  }

  /// 删除某个谱面在某一秒的记录点。
  ///
  /// 三处都按同一秒匹配，删的就是用户在列表里看到的那一行：
  ///   * `events`：自动采集到的变化；
  ///   * `manualEvents`：手动补录；
  ///   * `current`：基线（"当前成绩"）。**它必须一起删** —— 只要它有同一秒的
  ///     时间戳，单谱曲线就会把它当成一个点再画出来（见 [_chartEvents]），
  ///     只删事件等于没删。
  ///
  /// 代价说清楚：基线删掉后，下一次刷新会把当前成绩重新记成一条新事件
  /// （对采集层来说这张谱面又变成"没采集过"）。自动采集的数据删不干净是必然的，
  /// UI 的确认弹窗要如实提示。
  Future<bool> deleteChartPoint({
    required int songId,
    required int levelIndex,
    required int tMs,
    String? sourceKey,
    String? accountId,
  }) async {
    final second = historySecond(tMs);
    final deleter = debugChartPointDeleter;
    if (deleter != null) return deleter(songId, levelIndex, second);
    final source = await storageKey(sourceKey: sourceKey, accountId: accountId);
    final doc = await _load(source);
    final key = chartKeyOf(songId, levelIndex);
    var removed = false;

    for (final map in [doc.events, doc.manualEvents]) {
      final list = map[key];
      if (list == null) continue;
      final kept = [
        for (final e in list)
          if (_eventSecond(e) != second) e,
      ];
      if (kept.length == list.length) continue;
      removed = true;
      if (kept.isEmpty) {
        map.remove(key);
      } else {
        map[key] = kept;
      }
    }

    final baseline = doc.current[key];
    if (baseline != null) {
      // 旧数据的基线没有时间戳（长度 2），按 0 对齐 —— 页面上它也显示成"日期未知"
      final baseSecond =
          baseline.length > 2 ? historySecond(baseline[2].toInt()) : 0;
      if (baseSecond == second) {
        doc.current.remove(key);
        removed = true;
      }
    }

    if (!removed) return false;
    doc.updatedAtMs = DateTime.now().millisecondsSinceEpoch;
    await _persist(source, doc);
    debugPrint('[History] $source 删除谱面记录点 $key @${second ~/ 1000}');
    return true;
  }

  /// 事件行的时间戳（长度不足的坏数据算 0）。
  static int _eventSecond(List<num> event) =>
      event.isEmpty ? 0 : historySecond(event[0].toInt());

  // ==================== 读取 ====================

  /// Rating 曲线（按时间升序）。
  Future<List<RatingPoint>> ratingSeries(
      {String? sourceKey, String? accountId}) async {
    final loader = debugRatingSeriesLoader;
    if (loader != null) return loader();
    final doc = await _load(
        await storageKey(sourceKey: sourceKey, accountId: accountId));
    return mergeRatingPoints([...doc.rating, ...doc.manualRating]);
  }

  /// 某个谱面的达成率 / DX 分历史（按时间升序）。
  Future<List<ChartHistoryEvent>> chartEvents(
    int songId,
    int levelIndex, {
    String? sourceKey,
    String? accountId,
  }) async {
    final loader = debugChartEventsLoader;
    if (loader != null) return loader(songId, levelIndex);
    final doc = await _load(
        await storageKey(sourceKey: sourceKey, accountId: accountId));
    return _chartEvents(doc, chartKeyOf(songId, levelIndex));
  }

  List<ChartHistoryEvent> _chartEvents(_HistoryDoc doc, String key) {
    final automatic = doc.events[key] ?? const <List<num>>[];
    final manual = doc.manualEvents[key] ?? const <List<num>>[];
    final baseline = doc.current[key];
    final bySecond = <int, List<num>>{
      if (manual.isNotEmpty &&
          baseline != null &&
          baseline.length > 2 &&
          baseline[2] > 0)
        historySecond(baseline[2].toInt()): [
          baseline[2],
          baseline[0],
          baseline[1]
        ],
      for (final e in [...automatic, ...manual]) historySecond(e[0].toInt()): e,
    };
    return sortedEvents(bySecond.values);
  }

  /// 某个谱面**当前记录到的成绩**（基线）。
  ///
  /// 返回 null = 这张谱面从来没被采集过；返回非 null 但没有事件
  /// = 采集过、只是成绩还没出现过变化。曲目详情页靠这个区分两种情况。
  Future<ChartBaseline?> chartBaseline(
    int songId,
    int levelIndex, {
    String? sourceKey,
    String? accountId,
  }) async {
    final loader = debugChartBaselineLoader;
    if (loader != null) return loader(songId, levelIndex);
    final doc = await _load(
        await storageKey(sourceKey: sourceKey, accountId: accountId));
    final raw = doc.current[chartKeyOf(songId, levelIndex)];
    if (raw == null || raw.isEmpty) return null;
    return ChartBaseline(
      achievement: raw[0].toDouble(),
      dxScore: raw.length > 1 ? raw[1].toInt() : 0,
      tMs: raw.length > 2 ? raw[2].toInt() : 0,
    );
  }

  /// 概览：记了多少谱面、多少条事件、从什么时候开始、最近一次采集时间。
  Future<ChartHistorySummary> summary(
      {String? sourceKey, String? accountId}) async {
    final loader = debugSummaryLoader;
    if (loader != null) return loader();
    final doc = await _load(
        await storageKey(sourceKey: sourceKey, accountId: accountId));
    var eventCount = 0;
    int? firstEventMs;
    final chartKeys = {
      ...doc.current.keys,
      ...doc.events.keys,
      ...doc.manualEvents.keys
    };
    for (final key in chartKeys) {
      for (final e in _chartEvents(doc, key)) {
        eventCount++;
        if (e.tMs > 0 && (firstEventMs == null || e.tMs < firstEventMs)) {
          firstEventMs = e.tMs;
        }
      }
    }
    final ratings = mergeRatingPoints([...doc.rating, ...doc.manualRating]);
    for (final point in ratings) {
      if (point.tMs > 0 && (firstEventMs == null || point.tMs < firstEventMs)) {
        firstEventMs = point.tMs;
      }
    }
    // 基线本身也是"从这天开始记录"的证据
    if (doc.current.isNotEmpty) {
      int? baselineMs;
      doc.current.forEach((_, v) {
        final t = (v.length > 2 ? v[2] : 0).toInt();
        if (t <= 0) return;
        final prev = baselineMs;
        if (prev == null || t < prev) baselineMs = t;
      });
      final base = baselineMs;
      if (base != null) {
        final prev = firstEventMs;
        if (prev == null || base < prev) firstEventMs = base;
      }
    }
    return ChartHistorySummary(
      sourceKey: doc.source,
      chartCount: chartKeys.length,
      eventCount: eventCount,
      ratingPointCount: ratings.length,
      firstRecordedAtMs: firstEventMs ?? 0,
      updatedAtMs: doc.updatedAtMs,
    );
  }

  /// 某个数据源是否有任何历史（UI 据此决定显示曲线还是"从今天开始记录"）。
  Future<bool> hasAnyHistory({String? sourceKey, String? accountId}) async {
    final doc = await _load(
        await storageKey(sourceKey: sourceKey, accountId: accountId));
    return doc.current.isNotEmpty ||
        doc.events.isNotEmpty ||
        doc.rating.isNotEmpty ||
        doc.manualRating.isNotEmpty ||
        doc.manualEvents.isNotEmpty;
  }

  /// 清空某个数据源的历史（设置里的"清除历史记录"）。
  Future<void> clear({String? sourceKey, String? accountId}) async {
    final source = await storageKey(sourceKey: sourceKey, accountId: accountId);
    _cache.remove(source);
    _loading.remove(source);
    try {
      final file = await _fileFor(source);
      if (await file.exists()) await file.delete();
      debugPrint('[History] 已清空 $source 的历史');
    } catch (e) {
      debugPrint('[History] 清空历史失败: $e');
    }
  }

  /// 仅供测试：清掉内存缓存（不动文件）。
  @visibleForTesting
  void debugClearCache() {
    _cache.clear();
    _loading.clear();
    debugRatingSeriesLoader = null;
    debugSummaryLoader = null;
    debugChartEventsLoader = null;
    debugChartBaselineLoader = null;
    debugRatingPointDeleter = null;
    debugChartPointDeleter = null;
    debugBypassCache = false;
  }

  // ==================== 文件读写 ====================

  Future<_HistoryDoc> _load(String source) {
    if (debugBypassCache) {
      _cache.remove(source);
      _loading.remove(source);
    }
    final cached = _cache[source];
    if (cached != null) return Future.value(cached);
    final inFlight = _loading[source];
    if (inFlight != null) return inFlight;

    final future = _readFromDisk(source);
    _loading[source] = future;
    return future.whenComplete(() => _loading.remove(source));
  }

  Future<_HistoryDoc> _readFromDisk(String source) async {
    try {
      final file = await _fileFor(source);
      if (!await file.exists()) {
        final empty = _HistoryDoc(source: source);
        _cache[source] = empty;
        return empty;
      }
      final text = await file.readAsString();
      final doc = _HistoryDoc.fromJson(json.decode(text), source);
      _cache[source] = doc;
      return doc;
    } catch (e) {
      // 文件坏了（半截 JSON / 手改坏）：不删，另存一个 .broken 备份，重新开始记
      debugPrint('[History] 历史文件读取失败，将重新开始记录: $e');
      try {
        final file = await _fileFor(source);
        if (await file.exists()) {
          await file.rename('${file.path}.broken');
        }
      } catch (_) {}
      final empty = _HistoryDoc(source: source);
      _cache[source] = empty;
      return empty;
    }
  }

  Future<void> _persist(String source, _HistoryDoc doc) {
    _cache[source] = doc;
    final payload = json.encode(doc.toJson());
    final previous = _writes[source] ?? Future<void>.value();
    final next = previous.catchError((Object _) {}).then((_) async {
      try {
        final file = await _fileFor(source);
        final tmp = File('${file.path}.tmp');
        await tmp.writeAsString(payload, flush: true);
        await tmp.rename(file.path);
      } catch (e) {
        if (identical(_cache[source], doc)) _cache.remove(source);
        rethrow;
      }
    });
    _writes[source] = next;
    return next.whenComplete(() {
      if (identical(_writes[source], next)) _writes.remove(source);
    });
  }

  Future<File> _fileFor(String source) async {
    final dir = await _directory();
    return File('${dir.path}${Platform.pathSeparator}$source.json');
  }

  Future<Directory> _directory() async {
    final override = debugDirectoryOverride;
    final dir = override != null
        ? Directory(override)
        : Directory(
            '${(await getApplicationSupportDirectory()).path}'
            '${Platform.pathSeparator}$dirName',
          );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}

/// 历史概览。
class ChartHistorySummary {
  const ChartHistorySummary({
    required this.sourceKey,
    required this.chartCount,
    required this.eventCount,
    required this.ratingPointCount,
    required this.firstRecordedAtMs,
    required this.updatedAtMs,
  });

  final String sourceKey;
  final int chartCount;
  final int eventCount;
  final int ratingPointCount;
  final int firstRecordedAtMs;
  final int updatedAtMs;

  bool get isEmpty => chartCount == 0 && ratingPointCount == 0;

  /// 「从 X 年 X 月 X 日 HH:mm:ss 开始记录」——谱面级历史没有公开来源可回填，
  /// 只能从开启记录那天算起，UI 要如实说明。
  String get firstRecordedText {
    if (firstRecordedAtMs <= 0) return '尚未开始记录';
    final d = DateTime.fromMillisecondsSinceEpoch(firstRecordedAtMs);
    String two(int value) => value.toString().padLeft(2, '0');
    return '${d.year} 年 ${d.month} 月 ${d.day} 日 '
        '${two(d.hour)}:${two(d.minute)}:${two(d.second)} 起记录';
  }
}

/// 落盘结构（一个数据源一个文件）。
class _HistoryDoc {
  _HistoryDoc({required this.source});

  String source;
  int updatedAtMs = 0;

  /// 最近一次采集到的成绩条数（Rating 点的 recordCount 用）。
  int recordCount = 0;

  /// `key → [达成率, DX分, 时间戳]`
  Map<String, List<num>> current = {};

  /// `key → [[t, ach, dx], ...]`
  Map<String, List<List<num>>> events = {};

  List<RatingPoint> rating = [];
  // 新字段兼容旧文件，不升级 schema、不丢弃已有记录。
  List<RatingPoint> manualRating = [];
  Map<String, List<List<num>>> manualEvents = {};

  Map<String, dynamic> toJson() => {
        'version': ChartHistoryStore.schemaVersion,
        'source': source,
        'updatedAt': updatedAtMs,
        'recordCount': recordCount,
        'current': current,
        'events': events,
        'rating': rating.map((p) => p.toJson()).toList(),
        'manualRating': manualRating.map((p) => p.toJson()).toList(),
        'manualEvents': manualEvents,
      };

  static _HistoryDoc fromJson(dynamic raw, String fallbackSource) {
    final doc = _HistoryDoc(source: fallbackSource);
    if (raw is! Map) return doc;
    if ((raw['version'] as num?)?.toInt() != ChartHistoryStore.schemaVersion) {
      debugPrint('[History] 版本不匹配，忽略旧历史文件');
      return doc;
    }
    doc.source = fallbackSource;
    doc.updatedAtMs = (raw['updatedAt'] as num?)?.toInt() ?? 0;
    doc.recordCount = (raw['recordCount'] as num?)?.toInt() ?? 0;

    final current = raw['current'];
    if (current is Map) {
      current.forEach((k, v) {
        if (v is List && v.length >= 2) {
          doc.current[k.toString()] = v.cast<num>();
        }
      });
    }

    final events = raw['events'];
    if (events is Map) {
      events.forEach((k, v) {
        if (v is! List) return;
        final list = <List<num>>[];
        for (final item in v) {
          if (item is List && item.length >= 3) {
            list.add(item.cast<num>());
          }
        }
        if (list.isNotEmpty) doc.events[k.toString()] = list;
      });
    }

    final rating = raw['rating'];
    if (rating is List) {
      doc.rating =
          rating.map(RatingPoint.fromJson).whereType<RatingPoint>().toList();
    }

    final manualRating = raw['manualRating'];
    if (manualRating is List) {
      doc.manualRating = manualRating
          .map(RatingPoint.fromJson)
          .whereType<RatingPoint>()
          .toList();
    }
    final manualEvents = raw['manualEvents'];
    if (manualEvents is Map) {
      manualEvents.forEach((key, value) {
        if (value is List) {
          doc.manualEvents[key.toString()] =
              sortedEvents(value).map((event) => event.toJson()).toList();
        }
      });
    }

    // 防御：异常数据别把内存撑爆
    if (doc.current.length > ChartHistoryStore.maxCharts) {
      final keep = doc.current.entries.toList()
        ..sort((a, b) => _tOf(b.value).compareTo(_tOf(a.value)));
      doc.current = Map.fromEntries(keep.take(ChartHistoryStore.maxCharts));
    }
    return doc;
  }

  static int _tOf(List<num> v) => v.length > 2 ? v[2].toInt() : 0;
}
