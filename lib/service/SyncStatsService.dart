import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:redis/redis.dart';

import '../api/DeveloperToken.dart';

/// 同步成绩走的**通道**（前两个就是 `SyncRouteStore` 里可选的两条线路）。
enum SyncLine {
  /// 线路1：maimai Score Hub（scorehub 探针）。
  scoreHub(key: 'scorehub', label: '线路1 · maimai Score Hub'),

  /// 线路2：AWMC 网关。
  awmc(key: 'awmc', label: '线路2 · AWMC 网关'),

  /// **不是线路**：机台二维码直传（目前只有 AWMC NET 用）。
  ///
  /// 它不经过任何网关、也不依赖 [SyncRouteStore] 的线路选择，所以统计里
  /// **自成一个槽位**，不要去和上面两个线路混着算平均（二维码导入要 30 多秒，
  /// 混进去会把线路1/线路2 的平均耗时整体拉高，看起来像网关变慢了）。
  direct(key: 'direct', label: '二维码直传');

  const SyncLine({required this.key, required this.label});

  final String key;
  final String label;
}

/// 同步目标平台。
enum SyncPlatform {
  divingFish(key: 'fish', label: '水鱼'),
  luoXue(key: 'lx', label: '落雪'),

  /// AWMC NET 查分器（目前只有二维码直传这一条路）。
  awmc(key: 'awmc', label: 'AWMC NET');

  const SyncPlatform({required this.key, required this.label});

  final String key;
  final String label;
}

/// 统计的**槽位**：`<线路>:<平台>`，见 [SyncStatsService.slotOf]。
typedef SyncSlot = (SyncLine, SyncPlatform);

/// 近 N 次同步的聚合结果。
class SyncStats {
  /// 样本数（0 表示还没有任何记录）。
  final int count;

  /// 其中成功的次数。
  final int successCount;

  /// 平均耗时（毫秒）。
  final double avgMs;

  final int minMs;
  final int maxMs;

  /// 最近一次：耗时 / 是否成功 / 时间戳（毫秒）。
  final int lastMs;
  final bool lastOk;
  final int lastAtMs;

  const SyncStats({
    required this.count,
    required this.successCount,
    required this.avgMs,
    required this.minMs,
    required this.maxMs,
    required this.lastMs,
    required this.lastOk,
    required this.lastAtMs,
  });

  static const SyncStats empty = SyncStats(
    count: 0,
    successCount: 0,
    avgMs: 0,
    minMs: 0,
    maxMs: 0,
    lastMs: 0,
    lastOk: false,
    lastAtMs: 0,
  );

  bool get hasData => count > 0;

  /// 成功率（0.0 ~ 1.0）。
  double get successRate => count == 0 ? 0 : successCount / count;

  /// 失败次数。
  int get failCount => count - successCount;

  String get successRateText =>
      count == 0 ? '—' : '${(successRate * 100).round()}%';

  String get avgText => formatDuration(avgMs.round());

  String get rangeText => count == 0
      ? '—'
      : '${formatDuration(minMs)} ~ ${formatDuration(maxMs)}';

  String get lastText => count == 0
      ? '—'
      : '${formatDuration(lastMs)}${lastOk ? '' : '（失败）'}';

  /// 毫秒 → 便于阅读的文本。
  static String formatDuration(int ms) {
    if (ms <= 0) return '—';
    if (ms < 1000) return '${ms}ms';
    if (ms < 60000) return '${(ms / 1000).toStringAsFixed(1)}s';
    final m = ms ~/ 60000;
    final s = ((ms % 60000) / 1000).round();
    return '${m}m${s}s';
  }

  /// 把 Redis 里的原始条目（JSON 字符串列表）聚合成统计结果。
  ///
  /// 条目格式：`{"t":<毫秒时间戳>,"d":<耗时毫秒>,"ok":1|0}`。
  /// 坏数据（半截 JSON、字段缺失）直接跳过，不让它污染平均值。
  factory SyncStats.fromRawEntries(Iterable<String> rawEntries) {
    var count = 0;
    var successCount = 0;
    var sum = 0;
    var minMs = 0;
    var maxMs = 0;
    var lastMs = 0;
    var lastOk = false;
    var lastAtMs = 0;

    for (final raw in rawEntries) {
      try {
        final decoded = json.decode(raw);
        if (decoded is! Map) continue;
        final d = (decoded['d'] as num?)?.toInt();
        if (d == null || d < 0) continue;
        final okRaw = decoded['ok'];
        final ok = okRaw == 1 || okRaw == true || okRaw == '1';
        final t = (decoded['t'] as num?)?.toInt() ?? 0;

        count++;
        sum += d;
        if (ok) successCount++;
        if (count == 1 || d < minMs) minMs = d;
        if (count == 1 || d > maxMs) maxMs = d;
        if (t >= lastAtMs) {
          lastAtMs = t;
          lastMs = d;
          lastOk = ok;
        }
      } catch (_) {
        // 跳过坏条目
      }
    }

    if (count == 0) return SyncStats.empty;
    return SyncStats(
      count: count,
      successCount: successCount,
      avgMs: sum / count,
      minMs: minMs,
      maxMs: maxMs,
      lastMs: lastMs,
      lastOk: lastOk,
      lastAtMs: lastAtMs,
    );
  }
}

/// 一次同步尝试的计时 + 上报。
///
/// 口径集中在这里（各处自己写 stopwatch 很容易写歪）：
///   * 用户主动取消、或「只是还没绑定 ImportToken」→ `finish(skip: true)`，
///     **不计样本**（算失败会拉低成功率、误导看统计的人）；
///   * 同一次尝试重复 `finish` → 只算一条（流程里多个分支都可能调）；
///   * 耗时 ≤ 0（压根没开始）→ 不计样本。
///
/// 落到哪个槽位由构造时的 line/platform 决定：水鱼/落雪走线路1、线路2，
/// **AWMC NET 的二维码直传用 `(SyncLine.direct, SyncPlatform.awmc)`**。
class SyncAttemptTracker {
  SyncAttemptTracker({required this.line, required this.platform});

  final SyncLine line;
  final SyncPlatform platform;

  final Stopwatch _stopwatch = Stopwatch();
  bool _recorded = false;

  bool get running => _stopwatch.isRunning;
  int get elapsedMs => _stopwatch.elapsedMilliseconds;

  /// 开始计时（重试会重新开始一次尝试）。
  void start() {
    _recorded = false;
    _stopwatch
      ..reset()
      ..start();
  }

  /// 结束并上报；返回**是否真的写了一条样本**（调用方据此决定要不要刷新统计）。
  bool finish({required bool ok, bool skip = false}) {
    _stopwatch.stop();
    if (skip || _recorded) return false;
    final ms = _stopwatch.elapsedMilliseconds;
    if (ms <= 0) return false;
    _recorded = true;
    unawaited(SyncStatsService.record(
      line: line,
      platform: platform,
      durationMs: ms,
      ok: ok,
    ));
    return true;
  }
}

/// 同步成绩的耗时 / 成功率统计（Redis）。
///
/// 每个「线路 × 平台」槽位一条 Redis LIST（共 [allSlots] 个），只保留**最近 100 次**：
///
/// ```
/// chiffonmai:sync_stats:<line>:<platform>     # LPUSH 新条目 + LTRIM 0 99
///   条目 = {"t":<毫秒时间戳>,"d":<耗时毫秒>,"ok":1|0}
/// ```
///
/// 刻意只存这三个字段：**不含二维码、令牌、QQ、账号 id** 等任何个人信息，
/// 因此这些键可以安全地共享统计（看到的是所有用户的整体情况）。
///
/// 所有操作都是「尽力而为」：Redis 连不上、超时、返回异常数据都不抛异常，
/// 也**绝不影响同步本身**（统计失败最多是少一条样本）。
class SyncStatsService {
  SyncStatsService._();

  /// 只保留最近多少次记录。
  static const int windowSize = 100;

  /// 键前缀。
  static const String keyPrefix = 'chiffonmai:sync_stats';

  /// 每次操作的整体超时（连不上就快速放弃，别拖住 UI）。
  static const Duration timeout = Duration(seconds: 6);

  /// 全部统计槽位 —— **显式列出，不要用 `SyncLine.values × SyncPlatform.values` 的叉乘**。
  ///
  /// 叉乘会得到 9 个组合，其中 5 个是没意义的（二维码直传没有线路、
  /// AWMC NET 也不走线路1/线路2），既白读 5 个空键，详情弹窗里还会多出
  /// 一堆永远「暂无记录」的行。
  static const List<SyncSlot> allSlots = [
    (SyncLine.scoreHub, SyncPlatform.divingFish),
    (SyncLine.scoreHub, SyncPlatform.luoXue),
    (SyncLine.awmc, SyncPlatform.divingFish),
    (SyncLine.awmc, SyncPlatform.luoXue),
    // 机台二维码直传 → AWMC NET（30 多秒一次，单列一项）
    (SyncLine.direct, SyncPlatform.awmc),
  ];

  /// 槽位名：`<line>:<platform>`（就是 Redis 键去掉前缀的部分）。
  static String slotOf(SyncLine line, SyncPlatform platform) =>
      '${line.key}:${platform.key}';

  /// 键名：`chiffonmai:sync_stats:<line>:<platform>`。
  static String keyFor(SyncLine line, SyncPlatform platform) =>
      '$keyPrefix:${slotOf(line, platform)}';

  /// 仅供测试：置 true 后 [record] 直接返回。
  ///
  /// 单测**绝不能**往这个项目的线上 Redis 写假样本（测试里的耗时只有几毫秒，
  /// 会污染所有人看到的平均耗时与成功率）。`test/sync_stats_test.dart` 里已置位。
  @visibleForTesting
  static bool debugDisableWrites = false;

  /// 记录一次同步（耗时 + 成败）。调用方可以直接 `unawaited(...)`。
  static Future<void> record({
    required SyncLine line,
    required SyncPlatform platform,
    required int durationMs,
    required bool ok,
  }) async {
    if (debugDisableWrites) return;
    final key = keyFor(line, platform);
    final entry = json.encode({
      't': DateTime.now().millisecondsSinceEpoch,
      'd': durationMs < 0 ? 0 : durationMs,
      'ok': ok ? 1 : 0,
    });
    await _withConnection((conn) async {
      await conn.send_object(['LPUSH', key, entry]);
      await conn.send_object(['LTRIM', key, 0, windowSize - 1]);
      // 30 天没同步就让键自然过期，避免长期堆积
      await conn.send_object(['EXPIRE', key, 30 * 24 * 3600]);
      debugPrint('[SyncStats] 已记录 ${line.key}/${platform.key} '
          '${durationMs}ms ok=$ok');
    });
  }

  /// 读取某条线路 + 平台的统计；不可用（Redis 连不上 / 无数据）时返回 null。
  static Future<SyncStats?> load({
    required SyncLine line,
    required SyncPlatform platform,
  }) async {
    final all = await loadMany([(line, platform)]);
    return all['${line.key}:${platform.key}'];
  }

  /// 一次连接批量读取多个组合（详情弹窗要 4 组，避免开 4 条连接）。
  static Future<Map<String, SyncStats?>> loadMany(
    List<(SyncLine, SyncPlatform)> queries,
  ) async {
    final result = <String, SyncStats?>{};
    if (queries.isEmpty) return result;

    await _withConnection((conn) async {
      for (final (line, platform) in queries) {
        final id = '${line.key}:${platform.key}';
        final raw = await conn
            .send_object(['LRANGE', keyFor(line, platform), 0, windowSize - 1]);
        final entries = <String>[];
        if (raw is List) {
          for (final item in raw) {
            if (item is String) entries.add(item);
          }
        }
        result[id] = SyncStats.fromRawEntries(entries);
      }
    });

    // 一个组合都没读到 = Redis 不可用：返回 null 让 UI 显示「统计不可用」，
    // 而不是冒充「暂无记录」（这两件事对用户的意义完全不同）。
    if (result.isEmpty) {
      for (final (line, platform) in queries) {
        result['${line.key}:${platform.key}'] = null;
      }
    }
    return result;
  }

  /// 清空统计（调试 / 排查用；正常流程不会调用）。
  static Future<void> clearAll() async {
    await _withConnection((conn) async {
      for (final (line, platform) in allSlots) {
        await conn.send_object(['DEL', keyFor(line, platform)]);
      }
    });
  }

  /// 建连接 → AUTH →（必要时 SELECT）→ 执行 → 退出；任何异常都被吞掉。
  static Future<void> _withConnection(
    Future<void> Function(dynamic conn) body,
  ) async {
    try {
      final conn =
          await RedisConnection().connect(DeveloperToken.RedisHost, DeveloperToken.RedisPort)
              .timeout(timeout);
      try {
        await conn.send_object(['AUTH', DeveloperToken.RedisPassword]).timeout(timeout);
        if (DeveloperToken.RedisDatabase != 0) {
          await conn.send_object(['SELECT', DeveloperToken.RedisDatabase])
              .timeout(timeout);
        }
        await body(conn).timeout(timeout);
      } finally {
        try {
          await conn.send_object(['QUIT']);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[SyncStats] Redis 不可用，已忽略统计: $e');
    }
  }
}
