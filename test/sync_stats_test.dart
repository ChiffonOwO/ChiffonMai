import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_flutter_app/service/SyncStatsService.dart';

/// 同步统计（Redis）的纯逻辑测试：条目聚合、耗时格式化、键名、上报口径。
///
/// 这里不打桩 Redis，但**禁止写入**（`debugDisableWrites`）：测试里的耗时只有
/// 几毫秒，写进线上会把所有人看到的平均耗时 / 成功率带偏。
/// 覆盖的是最容易被写错、也最影响显示的两部分：
/// 从 LRANGE 回来的一串 JSON 算出平均耗时与成功率、以及「哪些情况算一条样本」。
void main() {
  // 单测里的耗时就几毫秒，**绝不能**写进线上 Redis（会污染所有人看到的统计）。
  setUp(() => SyncStatsService.debugDisableWrites = true);
  tearDown(() => SyncStatsService.debugDisableWrites = false);

  String entry({required int t, required int d, required bool ok}) =>
      json.encode({'t': t, 'd': d, 'ok': ok ? 1 : 0});

  group('条目聚合', () {
    test('平均耗时 / 成功率 / 最近一次', () {
      final stats = SyncStats.fromRawEntries([
        entry(t: 3000, d: 12000, ok: true),
        entry(t: 2000, d: 8000, ok: false),
        entry(t: 1000, d: 10000, ok: true),
      ]);

      expect(stats.count, 3);
      expect(stats.successCount, 2);
      expect(stats.failCount, 1);
      expect(stats.avgMs, 10000);
      expect(stats.avgText, '10.0s');
      expect(stats.successRateText, '67%');
      expect(stats.minMs, 8000);
      expect(stats.maxMs, 12000);
      expect(stats.rangeText, '8.0s ~ 12.0s');
      // 最近一次 = 时间戳最大的那条
      expect(stats.lastMs, 12000);
      expect(stats.lastOk, isTrue);
      expect(stats.lastText, '12.0s');
    });

    test('最近一次失败会标注出来', () {
      final stats = SyncStats.fromRawEntries([
        entry(t: 5000, d: 3000, ok: false),
        entry(t: 1000, d: 1000, ok: true),
      ]);
      expect(stats.lastOk, isFalse);
      expect(stats.lastText, '3.0s（失败）');
    });

    test('空列表 → 没有数据（不是「不可用」）', () {
      final stats = SyncStats.fromRawEntries(const []);
      expect(stats.count, 0);
      expect(stats.hasData, isFalse);
      expect(stats.successRateText, '—');
      expect(stats.avgText, '—');
      expect(stats.lastText, '—');
      expect(stats.rangeText, '—');
    });

    test('坏数据被跳过，不污染平均值', () {
      final stats = SyncStats.fromRawEntries([
        entry(t: 1000, d: 1000, ok: true),
        '{ 半截 JSON', // 坏
        json.encode({'t': 2000}), // 缺 d
        json.encode({'t': 3000, 'd': -5, 'ok': 1}), // 负耗时
        'null',
        entry(t: 4000, d: 3000, ok: true),
      ]);
      expect(stats.count, 2);
      expect(stats.avgMs, 2000);
      expect(stats.successRateText, '100%');
    });

    test('ok 字段兼容 1/true/"1"', () {
      final stats = SyncStats.fromRawEntries([
        json.encode({'t': 1, 'd': 100, 'ok': 1}),
        json.encode({'t': 2, 'd': 100, 'ok': true}),
        json.encode({'t': 3, 'd': 100, 'ok': '1'}),
        json.encode({'t': 4, 'd': 100, 'ok': 0}),
      ]);
      expect(stats.count, 4);
      expect(stats.successCount, 3);
      expect(stats.successRateText, '75%');
    });

    test('整批 100 条样本的口径', () {
      final raw = <String>[];
      for (var i = 0; i < 100; i++) {
        raw.add(entry(t: i, d: 1000 + i * 10, ok: i % 4 != 0)); // 25 次失败
      }
      final stats = SyncStats.fromRawEntries(raw);
      expect(stats.count, 100);
      expect(stats.successCount, 75);
      expect(stats.successRateText, '75%');
      expect(stats.avgMs, 1495); // 1000..1990 的均值
    });
  });

  group('一次同步尝试的计时 / 上报口径', () {
    /// 计时器只在「真的跑了 >0ms」时才写样本，测试里要保证这一点。
    Future<void> spin() =>
        Future<void>.delayed(const Duration(milliseconds: 2));

    test('成功 / 失败各写一条样本', () async {
      final ok = SyncAttemptTracker(
        line: SyncLine.scoreHub,
        platform: SyncPlatform.divingFish,
      );
      ok.start();
      await spin();
      expect(ok.finish(ok: true), isTrue);

      final failed = SyncAttemptTracker(
        line: SyncLine.scoreHub,
        platform: SyncPlatform.luoXue,
      );
      failed.start();
      await spin();
      expect(failed.finish(ok: false), isTrue);
    });

    test('用户取消 / 缺 ImportToken 不算样本', () async {
      final tracker = SyncAttemptTracker(
        line: SyncLine.scoreHub,
        platform: SyncPlatform.divingFish,
      );
      tracker.start();
      await spin();
      expect(tracker.finish(ok: false, skip: true), isFalse,
          reason: '取消算失败会拉低成功率、误导看统计的人');
    });

    test('同一次尝试重复 finish 只算一条', () async {
      final tracker = SyncAttemptTracker(
        line: SyncLine.awmc,
        platform: SyncPlatform.luoXue,
      );
      tracker.start();
      await spin();
      expect(tracker.finish(ok: true), isTrue);
      expect(tracker.finish(ok: true), isFalse, reason: '流程里多个分支都调也只算一次');
    });

    test('重试 = 新的一次尝试，会再算一条', () async {
      final tracker = SyncAttemptTracker(
        line: SyncLine.awmc,
        platform: SyncPlatform.divingFish,
      );
      tracker.start();
      await spin();
      expect(tracker.finish(ok: false), isTrue);

      tracker.start(); // 用户再点一次
      await spin();
      expect(tracker.finish(ok: true), isTrue);
    });

    test('没开始就 finish（耗时 0）不写样本', () {
      final tracker = SyncAttemptTracker(
        line: SyncLine.scoreHub,
        platform: SyncPlatform.divingFish,
      );
      expect(tracker.finish(ok: true), isFalse);
      expect(tracker.running, isFalse);
    });
  });

  group('耗时格式化', () {
    test('毫秒 / 秒 / 分钟', () {
      expect(SyncStats.formatDuration(0), '—');
      expect(SyncStats.formatDuration(850), '850ms');
      expect(SyncStats.formatDuration(12345), '12.3s');
      expect(SyncStats.formatDuration(59999), '60.0s');
      expect(SyncStats.formatDuration(75000), '1m15s');
    });
  });

  group('键名与窗口', () {
    test('一条线路 + 一个平台一个键', () {
      expect(
        SyncStatsService.keyFor(SyncLine.scoreHub, SyncPlatform.divingFish),
        'chiffonmai:sync_stats:scorehub:fish',
      );
      expect(
        SyncStatsService.keyFor(SyncLine.awmc, SyncPlatform.luoXue),
        'chiffonmai:sync_stats:awmc:lx',
      );
    });

    test('窗口是最近 100 次，槽位互不相同', () {
      expect(SyncStatsService.windowSize, 100);
      final keys = <String>{
        for (final (line, platform) in SyncStatsService.allSlots)
          SyncStatsService.keyFor(line, platform),
      };
      expect(keys.length, SyncStatsService.allSlots.length,
          reason: '槽位重名 = 两个入口的样本混进同一条平均');
    });

    test('槽位是显式列表，不是线路 × 平台的叉乘', () {
      // 叉乘 = 3 线路 × 3 平台 = 9 个，其中 5 个没意义：
      // AWMC NET 只有机台二维码直传，不该挂在线路1/线路2 下面
      // （它一次要 30 多秒，混进网关那条会把平均耗时整体拉高）。
      expect(SyncStatsService.allSlots.length, 5);
      expect(
        SyncStatsService.allSlots
            .where((slot) => slot.$2 == SyncPlatform.awmc)
            .toList(),
        [(SyncLine.direct, SyncPlatform.awmc)],
        reason: 'AWMC NET 只有直传一个槽位',
      );
      expect(
        SyncStatsService.allSlots
            .where((slot) => slot.$1 == SyncLine.direct)
            .toList(),
        [(SyncLine.direct, SyncPlatform.awmc)],
        reason: '「直传」不是线路，不该挂水鱼/落雪',
      );
    });

    test('AWMC NET 二维码直传自成一个键', () {
      expect(
        SyncStatsService.keyFor(SyncLine.direct, SyncPlatform.awmc),
        'chiffonmai:sync_stats:direct:awmc',
      );
      expect(
        SyncStatsService.slotOf(SyncLine.direct, SyncPlatform.awmc),
        'direct:awmc',
      );
    });

    test('线路与平台的显示名', () {
      expect(SyncLine.scoreHub.label, contains('maimai Score Hub'));
      expect(SyncLine.awmc.label, contains('AWMC'));
      expect(SyncLine.direct.label, '二维码直传');
      expect(SyncPlatform.divingFish.label, '水鱼');
      expect(SyncPlatform.luoXue.label, '落雪');
      expect(SyncPlatform.awmc.label, 'AWMC NET');
    });
  });
}
