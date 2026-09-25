// 成绩历史（M1 采集层）的测试。
//
// 这一层的风险不在"能不能跑"，而在**口径**：
//   * 阈值：三个数据源对同一条成绩的四位小数会差 0.0001，不放容差就会记出假事件；
//   * 基线：第一次采集不能凭空产生几千条"历史"；
//   * 并列/缺失：数据源某次少返回一条谱面，不能把它从基线里删掉（否则下次会当成新成绩）；
//   * 不是自己的数据不能记：好友对比会借用同一条 fetchUserPlayData。
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_flutter_app/service/History/ChartHistoryCore.dart';
import 'package:my_first_flutter_app/service/History/ChartHistoryStore.dart';

Map<String, dynamic> dfRecord(int songId, int levelIndex, double ach, int dx) =>
    {
      'song_id': songId,
      'level_index': levelIndex,
      'achievements': ach,
      'dxScore': dx,
      'ra': 300,
    };

void main() {
  group('从成绩记录解析快照', () {
    test('水鱼形状（achievements / dxScore）', () {
      final snaps = snapshotsFromRecords([
        dfRecord(11312, 3, 100.5678, 3000),
        dfRecord(8, 3, 99.5, 2900),
      ]);
      expect(snaps.length, 2);
      final first = snaps.firstWhere((s) => s.songId == 11312);
      expect(first.levelIndex, 3);
      expect(first.achievement, closeTo(100.5678, 0.00001));
      expect(first.dxScore, 3000);
      expect(first.key, '11312/3');
    });

    test('落雪形状（dx_score）与字符串数字都认', () {
      final snaps = snapshotsFromRecords([
        {
          'song_id': '11312',
          'level_index': '3',
          'achievements': '100.1234',
          'dx_score': '2810',
        },
      ]);
      expect(snaps.length, 1);
      expect(snaps.single.achievement, closeTo(100.1234, 0.00001));
      expect(snaps.single.dxScore, 2810);
    });

    test('达成率为 0 / 缺失的行不是"打过了"，直接丢掉', () {
      final snaps = snapshotsFromRecords([
        dfRecord(1, 3, 0, 0),
        {'song_id': 2, 'level_index': 3},
        dfRecord(3, 3, 98.0, 100),
        'garbage',
        null,
      ]);
      expect(snaps.map((s) => s.songId), [3]);
    });

    test('同一谱面重复出现时取达成率更高的那条（与游戏口径一致）', () {
      final snaps = snapshotsFromRecords([
        dfRecord(11312, 3, 99.0, 2000),
        dfRecord(11312, 3, 100.5, 3000),
      ]);
      expect(snaps.length, 1);
      expect(snaps.single.achievement, closeTo(100.5, 0.00001));
    });
  });

  group('快照 diff（历史的正确性核心）', () {
    List<ChartSnapshot> snaps(List<List<num>> rows) => [
          for (final r in rows)
            ChartSnapshot(
              songId: r[0].toInt(),
              levelIndex: r[1].toInt(),
              achievement: r[2].toDouble(),
              dxScore: r[3].toInt(),
            ),
        ];

    test('首次采集只建基线，不产生事件', () {
      final diff = diffChartSnapshots(
        previousCurrent: null,
        incoming: snaps([
          [11312, 3, 100.5, 3000],
          [8, 3, 99.0, 2800],
        ]),
        nowMs: 1000,
      );
      expect(diff.baseline, isTrue);
      expect(diff.events, isEmpty, reason: '第一次不能凭空造出历史');
      expect(diff.current.length, 2);
      expect(diff.current['11312/3'], [100.5, 3000, 1000]);
    });

    test('完全没变化时不产生事件，且保留旧时间戳', () {
      final first = diffChartSnapshots(
        previousCurrent: null,
        incoming: snaps([
          [11312, 3, 100.5, 3000]
        ]),
        nowMs: 1000,
      );
      final second = diffChartSnapshots(
        previousCurrent: first.current,
        incoming: snaps([
          [11312, 3, 100.5, 3000]
        ]),
        nowMs: 2000,
      );
      expect(second.events, isEmpty);
      expect(second.current['11312/3'], [100.5, 3000, 1000],
          reason: '时间戳是"最后一次变化"，不是"最后一次采集"');
    });

    test('达成率变化 ≥ 容差 → 记一条事件', () {
      final prev = {
        '11312/3': <num>[100.5, 3000, 1000]
      };
      final diff = diffChartSnapshots(
        previousCurrent: prev,
        incoming: snaps([
          [11312, 3, 100.5678, 3000]
        ]),
        nowMs: 2000,
      );
      expect(diff.events['11312/3'], [
        [2000, 100.5678, 3000]
      ]);
      expect(diff.current['11312/3'], [100.5678, 3000, 2000]);
    });

    test('达成率抖动小于容差（数据源四舍五入差异）不算变化', () {
      final prev = {
        '11312/3': <num>[100.5678, 3000, 1000]
      };
      final diff = diffChartSnapshots(
        previousCurrent: prev,
        incoming: snaps([
          [11312, 3, 100.56775, 3000]
        ]),
        nowMs: 2000,
      );
      expect(diff.events, isEmpty, reason: '0.00005 的差是数据源口径差，不是真打了');
    });

    test('只有 DX 分变化也算变化', () {
      final prev = {
        '11312/3': <num>[100.5, 3000, 1000]
      };
      final diff = diffChartSnapshots(
        previousCurrent: prev,
        incoming: snaps([
          [11312, 3, 100.5, 3001]
        ]),
        nowMs: 2000,
      );
      expect(diff.events['11312/3'], [
        [2000, 100.5, 3001]
      ]);
    });

    test('基线里没有的谱面 = 新成绩，要记一条', () {
      final prev = {
        '11312/3': <num>[100.5, 3000, 1000]
      };
      final diff = diffChartSnapshots(
        previousCurrent: prev,
        incoming: snaps([
          [11312, 3, 100.5, 3000],
          [999, 4, 98.0, 1500],
        ]),
        nowMs: 2000,
      );
      expect(diff.baseline, isFalse);
      expect(diff.events.keys, ['999/4']);
    });

    test('数据源这次少返回一条时，基线里那条不能被删掉', () {
      final prev = {
        '11312/3': <num>[100.5, 3000, 1000],
        '8/3': <num>[99.0, 2800, 1000],
      };
      final diff = diffChartSnapshots(
        previousCurrent: prev,
        incoming: snaps([
          [11312, 3, 100.5, 3000]
        ]),
        nowMs: 2000,
      );
      expect(diff.current.containsKey('8/3'), isTrue,
          reason: '删了下次再出现就会被当成新成绩');
      expect(diff.current['8/3'], [99.0, 2800, 1000]);
      expect(diff.events, isEmpty);
    });
  });

  group('事件降采样与曲线辅助', () {
    test('没超上限就原样保留', () {
      final events = [
        for (var i = 0; i < 10; i++) <num>[1000 + i, 99 + i * 0.1, 100 + i],
      ];
      final pruned = mergeAndPruneEvents(const [], events, max: 50);
      expect(pruned.length, 10);
    });

    test('超上限：保留最近 N 条 + 更早的每 7 天一条', () {
      const day = 24 * 3600 * 1000;
      // 200 天，每天一条
      final events = [
        for (var i = 0; i < 200; i++) <num>[i * day, 99.0 + i * 0.001, 100 + i],
      ];
      final pruned =
          mergeAndPruneEvents(const [], events, max: 50, keepRecent: 20);
      expect(pruned.length, lessThanOrEqualTo(50));
      expect(pruned.length, greaterThan(20));
      // 最近 20 条必须一条不少
      final tail = pruned.sublist(pruned.length - 20);
      expect(tail.map((e) => e[0]), events.sublist(180).map((e) => e[0]));
      // 时间升序
      for (var i = 1; i < pruned.length; i++) {
        expect(pruned[i][0], greaterThan(pruned[i - 1][0]));
      }
    });

    test('Rating 曲线：同一天只留一个点（用当天最后一次）', () {
      final day1 = DateTime(2026, 9, 1, 10).millisecondsSinceEpoch;
      final day1Later = DateTime(2026, 9, 1, 22).millisecondsSinceEpoch;
      final day2 = DateTime(2026, 9, 2, 9).millisecondsSinceEpoch;

      var series = <RatingPoint>[];
      series = appendRatingPoint(series, RatingPoint(tMs: day1, rating: 16000))
          .series;
      series =
          appendRatingPoint(series, RatingPoint(tMs: day1Later, rating: 16100))
              .series;
      expect(series.length, 1);
      expect(series.single.rating, 16100, reason: '当天以最后一次为准');

      series = appendRatingPoint(series, RatingPoint(tMs: day2, rating: 16200))
          .series;
      expect(series.length, 2);
      expect(series.last.rating, 16200);
    });

    test('Rating 没变就不记新点（跨天也不记）', () {
      final day1 = DateTime(2026, 9, 1, 10).millisecondsSinceEpoch;
      final day2 = DateTime(2026, 9, 2, 9).millisecondsSinceEpoch;
      final day3 = DateTime(2026, 9, 3, 20).millisecondsSinceEpoch;

      var r = appendRatingPoint(
          <RatingPoint>[], RatingPoint(tMs: day1, rating: 15610));
      expect(r.changed, isTrue, reason: '第一个点必须记');
      expect(r.series.length, 1);

      // 第二天只是游玩记录变了，Rating 还是 15610 → 不该多一个点
      r = appendRatingPoint(
          r.series, RatingPoint(tMs: day2, rating: 15610, recordCount: 999));
      expect(r.changed, isFalse, reason: 'Rating 没变 → changed 必须是 false');
      expect(r.series.length, 1, reason: 'Rating 没变就不该记新点');
      expect(r.series.single.rating, 15610);
      expect(r.series.single.tMs, day1, reason: '原来的点不该被挪走');

      // 连着好几天都没变，也只有一个点
      for (var d = 3; d <= 10; d++) {
        r = appendRatingPoint(
          r.series,
          RatingPoint(
            tMs: DateTime(2026, 9, d, 12).millisecondsSinceEpoch,
            rating: 15610,
          ),
        );
      }
      expect(r.series.length, 1, reason: '连续多天不变仍然只有一个点');

      // 真的变了才新增
      r = appendRatingPoint(r.series, RatingPoint(tMs: day3, rating: 15700));
      expect(r.changed, isTrue);
      expect(r.series.length, 2);
      expect(r.series.last.rating, 15700);
    });

    test('同一天内 Rating 没变：替换当天那个点，不新增', () {
      final morning = DateTime(2026, 9, 1, 9).millisecondsSinceEpoch;
      final evening = DateTime(2026, 9, 1, 21).millisecondsSinceEpoch;

      var r = appendRatingPoint(<RatingPoint>[],
          RatingPoint(tMs: morning, rating: 15610, recordCount: 100));
      r = appendRatingPoint(
          r.series, RatingPoint(tMs: evening, rating: 15610, recordCount: 120));

      expect(r.series.length, 1, reason: '同一天只能有一个点');
      expect(r.series.single.tMs, evening, reason: '以当天最后一次为准');
      expect(r.series.single.recordCount, 120, reason: '明细要更新成最新的');
    });

    test('Rating 下降也会记（换号/换源）', () {
      var r = appendRatingPoint(
          <RatingPoint>[],
          RatingPoint(
              tMs: DateTime(2026, 9, 1).millisecondsSinceEpoch, rating: 16000));
      r = appendRatingPoint(
          r.series,
          RatingPoint(
              tMs: DateTime(2026, 9, 2).millisecondsSinceEpoch, rating: 15500));
      expect(r.changed, isTrue, reason: '下降也是"变动"，必须记');
      expect(r.series.length, 2);
      expect(r.series.last.rating, 15500);
    });

    test('Rating 曲线上限 365 天', () {
      var series = <RatingPoint>[];
      for (var i = 0; i < 400; i++) {
        series = appendRatingPoint(
          series,
          RatingPoint(
              tMs: DateTime(2026, 1, 1)
                  .add(Duration(days: i))
                  .millisecondsSinceEpoch,
              rating: 16000 + i),
        ).series;
      }
      expect(series.length, 365);
      expect(series.last.rating, 16000 + 399);
    });

    test('下降检测：成绩取最高值，出现下降 = 多半是换源/换号', () {
      final ok = sortedEvents([
        [1000, 99.0, 100],
        [2000, 99.5, 120],
        [3000, 100.1, 150],
      ]);
      expect(hasRegression(ok), isFalse);

      final regressed = sortedEvents([
        [1000, 100.5, 150],
        [2000, 99.0, 120],
      ]);
      expect(hasRegression(regressed), isTrue);
    });

    test('Y 轴范围：给出该谱面自己的 min/max', () {
      final events = sortedEvents([
        [1000, 99.0, 100],
        [2000, 100.7, 300],
        [3000, 99.8, 200],
      ]);
      final range = eventRange(events);
      expect(range.minAch, closeTo(99.0, 1e-9));
      expect(range.maxAch, closeTo(100.7, 1e-9));
      expect(range.minDx, 100);
      expect(range.maxDx, 300);
    });

    test('坐标轴对齐到整数档：不出现 16956 / 98.7 这种读数', () {
      // Rating：16000~16800 → 每格 200，范围正好落在整数档上（16800 本身就是 200 的倍数）
      final rating = niceAxisRange(16000, 16800);
      expect(rating.min, 16000);
      expect(rating.max, 16800);
      expect(rating.interval, 200);

      // 达成率：99.1234~100.7589 → 每格 0.5，范围 99~101
      final ach = niceAxisRange(99.1234, 100.7589);
      expect(ach.min, 99.0);
      expect(ach.max, 101.0);
      expect(ach.interval, 0.5);

      // DX 占比：83.26~93.48 → 每格 5，范围 80~95
      final dx = niceAxisRange(83.26, 93.48);
      expect(dx.min, 80);
      expect(dx.max, 95);
      expect(dx.interval, 5);
    });

    test('坐标轴退化情况：一个值 / 非法值都不炸', () {
      final single = niceAxisRange(16353, 16353);
      expect(single.max, greaterThan(single.min));
      expect(single.interval, greaterThan(0));

      final bad = niceAxisRange(double.nan, double.infinity);
      expect(bad.max, greaterThan(bad.min));
    });
  });

  group('落盘（真写文件，用临时目录）', () {
    late Directory tmp;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      tmp = Directory.systemTemp.createTempSync('chart_history_test');
      ChartHistoryStore.debugDirectoryOverride = tmp.path;
      ChartHistoryStore.instance.debugClearCache();
    });

    tearDown(() {
      ChartHistoryStore.debugDirectoryOverride = null;
      ChartHistoryStore.instance.debugClearCache();
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    Map<String, dynamic> userData(List<Map<String, dynamic>> records) =>
        {'records': records, 'additional_rating': 0};

    test('首次采集建基线：文件写下来了、没有事件', () async {
      final store = ChartHistoryStore.instance;
      await store.recordChartSnapshot(
        userData([dfRecord(11312, 3, 100.5, 3000)]),
        sourceKey: 'shuiyu',
        nowMs: 1000,
        reason: 'test',
      );

      final file = File('${tmp.path}${Platform.pathSeparator}shuiyu.json');
      expect(file.existsSync(), isTrue, reason: '必须真的落盘');

      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(json['version'], ChartHistoryStore.schemaVersion);
      expect((json['current'] as Map).containsKey('11312/3'), isTrue);
      expect((json['events'] as Map).isEmpty, isTrue);

      final summary = await store.summary(sourceKey: 'shuiyu');
      expect(summary.chartCount, 1);
      expect(summary.eventCount, 0);
      expect(summary.firstRecordedText, contains('起记录'));
      expect(await store.chartEvents(11312, 3, sourceKey: 'shuiyu'), isEmpty);

      // 事件为空，但基线必须读得到——曲目详情页靠它区分
      // 「没采集过」和「采集过但没变化」
      final baseline = await store.chartBaseline(11312, 3, sourceKey: 'shuiyu');
      expect(baseline, isNotNull);
      expect(baseline!.achievement, closeTo(100.5, 0.0001));
      expect(baseline.dxScore, 3000);
      expect(baseline.tMs, 1000);
      expect(await store.chartBaseline(1, 0, sourceKey: 'shuiyu'), isNull,
          reason: '没采集过的谱面必须是 null，页面才会完全不占空间');
    });

    test('成绩变好 → 记一条事件，并把曲线读回来', () async {
      final store = ChartHistoryStore.instance;
      await store.recordChartSnapshot(
        userData([dfRecord(11312, 3, 100.5, 3000)]),
        sourceKey: 'shuiyu',
        nowMs: 1000,
      );
      await store.recordChartSnapshot(
        userData([dfRecord(11312, 3, 100.5678, 3000)]),
        sourceKey: 'shuiyu',
        nowMs: 2000,
      );

      final events = await store.chartEvents(11312, 3, sourceKey: 'shuiyu');
      expect(events.length, 1);
      expect(events.single.tMs, 2000);
      expect(events.single.achievement, closeTo(100.5678, 0.00001));

      final summary = await store.summary(sourceKey: 'shuiyu');
      expect(summary.eventCount, 1);
      expect(summary.chartCount, 1, reason: '基线不会因为一次变化就变两条');
    });

    test('重新读盘（模拟重启）数据仍在：文件才是唯一真相', () async {
      final store = ChartHistoryStore.instance;
      await store.recordChartSnapshot(
        userData([dfRecord(11312, 3, 100.5, 3000)]),
        sourceKey: 'shuiyu',
        nowMs: 1000,
      );
      ChartHistoryStore.instance.debugClearCache(); // 相当于杀掉进程重开

      final summary = await store.summary(sourceKey: 'shuiyu');
      expect(summary.chartCount, 1);
      expect(summary.updatedAtMs, 1000);
    });

    test('水鱼与落雪各存各的（历史绝不能串号）', () async {
      final store = ChartHistoryStore.instance;
      await store.recordChartSnapshot(
        userData([dfRecord(11312, 3, 100.5, 3000)]),
        sourceKey: 'shuiyu',
        nowMs: 1000,
      );
      await store.recordChartSnapshot(
        userData([dfRecord(8, 3, 99.0, 2000)]),
        sourceKey: 'luoxue',
        nowMs: 1000,
      );

      expect((await store.summary(sourceKey: 'shuiyu')).chartCount, 1);
      expect((await store.summary(sourceKey: 'luoxue')).chartCount, 1);
      expect(await store.chartEvents(8, 3, sourceKey: 'shuiyu'), isEmpty);
      expect(
          File('${tmp.path}${Platform.pathSeparator}luoxue.json').existsSync(),
          isTrue);
    });

    test('好友对比期间不采集任何历史', () async {
      final store = ChartHistoryStore.instance;
      await store.runWithoutRecording(() async {
        await store.recordChartSnapshot(
          userData([dfRecord(999, 4, 101.0, 3000)]),
          sourceKey: 'shuiyu',
          nowMs: 1000,
          reason: '好友的数据',
        );
      });
      expect((await store.summary(sourceKey: 'shuiyu')).chartCount, 0);
      expect(store.isRecordingSuppressed, isFalse, reason: '作用域结束后要复位');
    });

    test('Rating：同一天替换、跨天追加，并且 0 不记', () async {
      final store = ChartHistoryStore.instance;
      final day1 = DateTime(2026, 9, 1, 10).millisecondsSinceEpoch;
      await store.recordRating(
        rating: 16000,
        best35: 11000,
        best15: 5000,
        sourceKey: 'shuiyu',
        nowMs: day1,
      );
      await store.recordRating(
        rating: 0,
        sourceKey: 'shuiyu',
        nowMs: day1 + 3600000,
      );
      await store.recordRating(
        rating: 16100,
        best35: 11100,
        best15: 5000,
        sourceKey: 'shuiyu',
        nowMs: day1 + 7200000,
      );
      await store.recordRating(
        rating: 16200,
        sourceKey: 'shuiyu',
        nowMs: DateTime(2026, 9, 2, 9).millisecondsSinceEpoch,
      );

      final series = await store.ratingSeries(sourceKey: 'shuiyu');
      expect(series.length, 2);
      expect(series.first.rating, 16100, reason: '当天以最后一次为准，且 0 不记');
      expect(series.last.rating, 16200);
    });

    test('文件损坏：另存 .broken 并重新开始，而不是丢掉整个 App 的历史', () async {
      final file = File('${tmp.path}${Platform.pathSeparator}shuiyu.json');
      file.writeAsStringSync('{"version":1,"current":{"a":'); // 半截 JSON

      final summary =
          await ChartHistoryStore.instance.summary(sourceKey: 'shuiyu');
      expect(summary.chartCount, 0);
      expect(File('${file.path}.broken').existsSync(), isTrue,
          reason: '坏文件要留证据，方便排查');
    });

    test('清空历史：文件与内存都清掉', () async {
      final store = ChartHistoryStore.instance;
      await store.recordChartSnapshot(
        userData([dfRecord(11312, 3, 100.5, 3000)]),
        sourceKey: 'shuiyu',
        nowMs: 1000,
      );
      expect(await store.hasAnyHistory(sourceKey: 'shuiyu'), isTrue);

      await store.clear(sourceKey: 'shuiyu');
      expect(
        File('${tmp.path}${Platform.pathSeparator}shuiyu.json').existsSync(),
        isFalse,
      );
      expect(await store.hasAnyHistory(sourceKey: 'shuiyu'), isFalse);
    });
  });
}
