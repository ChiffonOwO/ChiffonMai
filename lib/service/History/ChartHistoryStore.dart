import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../utils/CurrentDataSourceNotifier.dart';
import 'ChartHistoryCore.dart';

/// 成绩历史的落盘与读写（Rating 曲线 + 单谱达成率/DX 曲线）。
///
/// ## 这份数据与 App 里其它缓存的本质区别
/// 别的缓存（曲库、别名、AWMC 游玩次数…）**都能重新拉**，坏了就坏了；
/// **历史不能**：水鱼/落雪只给"当前成绩"，没有历史接口，所以一旦丢了就永远补不回来。
/// 由此定下三条：
///   1. **按数据源分文件**（水鱼 / 落雪 各一份，文件名 = [RefreshDataSource.key]）——
///      两个账号的历史绝不能混在一起；将来接进备份时也不会串号。
///   2. **原子写**：先写 `<file>.tmp` 再 rename，崩在写一半也不会毁掉已有历史。
///   3. **永不抛异常**：采集一律 `unawaited`，失败只打日志 —— 顺手的记录不能影响
///      刷新成绩这条主流程。
///
/// ## 采集点与"不要污染"
/// 目前两个入口：
///   * `UserPlayDataManager.fetchUserPlayData()` 拿到自己的成绩后 → [recordChartSnapshot]；
///   * `RefreshDataDialog._saveUserData()` 落盘 Rating 后 → [recordRating]。
/// ⚠️ **好友对比**（`FriendCompareService`）会借用同一个 fetchUserPlayData 拉好友的成绩，
/// 还会把好友数据临时写进活动缓存 —— 那一段必须用 [runWithoutRecording] 包住，
/// 否则好友的成绩会被记进你自己的历史。
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

  final Map<String, _HistoryDoc> _cache = {};
  final Map<String, Future<_HistoryDoc>> _loading = {};

  /// 采集抑制深度（好友对比期间 > 0）。
  int _suppressDepth = 0;

  bool get isRecordingSuppressed => _suppressDepth > 0;

  /// 在 [body] 执行期间**不采集任何历史**（好友对比那种借用缓存的操作专用）。
  Future<T> runWithoutRecording<T>(Future<T> Function() body) async {
    _suppressDepth++;
    try {
      return await body();
    } finally {
      _suppressDepth--;
    }
  }

  /// 当前数据源（水鱼 / 落雪）——历史的隔离键。
  static String currentSourceKey() =>
      CurrentDataSourceNotifier.instance.value.key;

  // ==================== 写入 ====================

  /// 用自己的**成绩记录**采集一次（记录形状与水鱼/落雪缓存一致）。
  ///
  /// [reason] 只进日志，便于排查"这条历史是哪次刷新记的"。
  Future<void> recordChartSnapshot(
    Map<String, dynamic> userData, {
    String? sourceKey,
    int? nowMs,
    String reason = '',
  }) async {
    if (_suppressDepth > 0) return;
    try {
      final records = userData['records'];
      final snapshots = snapshotsFromRecords(records);
      if (snapshots.isEmpty) {
        debugPrint('[History] 这次没有解析出任何成绩，跳过采集（$reason）');
        return;
      }

      final source = sourceKey ?? currentSourceKey();
      final doc = await _load(source);
      final diff = diffChartSnapshots(
        previousCurrent: doc.current.isEmpty ? null : doc.current,
        incoming: snapshots,
        nowMs: nowMs ?? DateTime.now().millisecondsSinceEpoch,
      );

      doc.current = diff.current;
      diff.events.forEach((key, list) {
        doc.events[key] = mergeAndPruneEvents(doc.events[key] ?? const [], list);
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
    int? nowMs,
  }) async {
    if (_suppressDepth > 0) return;
    if (rating <= 0) return; // 没登录 / 没数据时不记，免得曲线上出现 0 的坑
    try {
      final source = sourceKey ?? currentSourceKey();
      final doc = await _load(source);
      final t = nowMs ?? DateTime.now().millisecondsSinceEpoch;
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
      debugPrint('[History] $source 记录 Rating=$rating（${doc.rating.length} 个点）');
    } catch (e) {
      debugPrint('[History] 记录 Rating 失败（忽略）: $e');
    }
  }

  // ==================== 读取 ====================

  /// Rating 曲线（按时间升序）。
  Future<List<RatingPoint>> ratingSeries({String? sourceKey}) async {
    final loader = debugRatingSeriesLoader;
    if (loader != null) return loader();
    final doc = await _load(sourceKey ?? currentSourceKey());
    final list = List<RatingPoint>.from(doc.rating)
      ..sort((a, b) => a.tMs.compareTo(b.tMs));
    return list;
  }

  /// 某个谱面的达成率 / DX 分历史（按时间升序）。
  Future<List<ChartHistoryEvent>> chartEvents(
    int songId,
    int levelIndex, {
    String? sourceKey,
  }) async {
    final loader = debugChartEventsLoader;
    if (loader != null) return loader(songId, levelIndex);
    final doc = await _load(sourceKey ?? currentSourceKey());
    final raw = doc.events[chartKeyOf(songId, levelIndex)];
    if (raw == null) return const [];
    return sortedEvents(raw);
  }

  /// 某个谱面**当前记录到的成绩**（基线）。
  ///
  /// 返回 null = 这张谱面从来没被采集过；返回非 null 但没有事件
  /// = 采集过、只是成绩还没出现过变化。曲目详情页靠这个区分两种情况。
  Future<ChartBaseline?> chartBaseline(
    int songId,
    int levelIndex, {
    String? sourceKey,
  }) async {
    final loader = debugChartBaselineLoader;
    if (loader != null) return loader(songId, levelIndex);
    final doc = await _load(sourceKey ?? currentSourceKey());
    final raw = doc.current[chartKeyOf(songId, levelIndex)];
    if (raw == null || raw.isEmpty) return null;
    return ChartBaseline(
      achievement: raw[0].toDouble(),
      dxScore: raw.length > 1 ? raw[1].toInt() : 0,
      tMs: raw.length > 2 ? raw[2].toInt() : 0,
    );
  }

  /// 概览：记了多少谱面、多少条事件、从什么时候开始、最近一次采集时间。
  Future<ChartHistorySummary> summary({String? sourceKey}) async {
    final loader = debugSummaryLoader;
    if (loader != null) return loader();
    final doc = await _load(sourceKey ?? currentSourceKey());
    var eventCount = 0;
    int? firstEventMs;
    doc.events.forEach((_, list) {
      for (final raw in list) {
        final e = ChartHistoryEvent.fromJson(raw);
        if (e == null) continue;
        eventCount++;
        final prev = firstEventMs;
        if (prev == null || e.tMs < prev) firstEventMs = e.tMs;
      }
    });
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
      chartCount: doc.current.length,
      eventCount: eventCount,
      ratingPointCount: doc.rating.length,
      firstRecordedAtMs: firstEventMs ?? 0,
      updatedAtMs: doc.updatedAtMs,
    );
  }

  /// 某个数据源是否有任何历史（UI 据此决定显示曲线还是"从今天开始记录"）。
  Future<bool> hasAnyHistory({String? sourceKey}) async {
    final doc = await _load(sourceKey ?? currentSourceKey());
    return doc.current.isNotEmpty || doc.rating.isNotEmpty;
  }

  /// 清空某个数据源的历史（设置里的"清除历史记录"）。
  Future<void> clear({String? sourceKey}) async {
    final source = sourceKey ?? currentSourceKey();
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
    _suppressDepth = 0;
    debugRatingSeriesLoader = null;
    debugSummaryLoader = null;
    debugChartEventsLoader = null;
    debugChartBaselineLoader = null;
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

  Future<void> _persist(String source, _HistoryDoc doc) async {
    _cache[source] = doc;
    try {
      final file = await _fileFor(source);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(json.encode(doc.toJson()), flush: true);
      // rename 在同一文件系统内是原子的
      await tmp.rename(file.path);
    } catch (e) {
      debugPrint('[History] 历史写入失败（内存里仍有，下次再试）: $e');
    }
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

  /// 「从 X 年 X 月 X 日开始记录」——谱面级历史没有公开来源可回填，
  /// 只能从开启记录那天算起，UI 要如实说明。
  String get firstRecordedText {
    if (firstRecordedAtMs <= 0) return '尚未开始记录';
    final d = DateTime.fromMillisecondsSinceEpoch(firstRecordedAtMs);
    return '${d.year} 年 ${d.month} 月 ${d.day} 日起记录';
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

  Map<String, dynamic> toJson() => {
        'version': ChartHistoryStore.schemaVersion,
        'source': source,
        'updatedAt': updatedAtMs,
        'recordCount': recordCount,
        'current': current,
        'events': events,
        'rating': rating.map((p) => p.toJson()).toList(),
      };

  static _HistoryDoc fromJson(dynamic raw, String fallbackSource) {
    final doc = _HistoryDoc(source: fallbackSource);
    if (raw is! Map) return doc;
    if ((raw['version'] as num?)?.toInt() != ChartHistoryStore.schemaVersion) {
      debugPrint('[History] 版本不匹配，忽略旧历史文件');
      return doc;
    }
    doc.source = raw['source']?.toString() ?? fallbackSource;
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
      doc.rating = rating
          .map(RatingPoint.fromJson)
          .whereType<RatingPoint>()
          .toList();
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
