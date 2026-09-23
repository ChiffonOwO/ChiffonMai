// Rating 历史页（M2）的渲染测试。
//
// 三种状态都要能看：没数据（要讲清楚"从今天开始记"）、只有一个点（画不出曲线，
// 要给出下一步动作）、多个点（曲线 + 档位统计 + 记录点列表）。
//
// ⚠️ 数据用 `ChartHistoryStore.debugRatingSeriesLoader` 注入，**不碰真实文件**：
// widget 测试跑在 fake async 里，真实文件 I/O 的 await 不会完成（页面会一直转圈，
// 甚至把整个测试挂死）。真实文件读写由 `test/chart_history_test.dart` 覆盖。
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_first_flutter_app/page/History/RatingHistoryPage.dart';
import 'package:my_first_flutter_app/service/History/ChartHistoryCore.dart';
import 'package:my_first_flutter_app/service/History/ChartHistoryStore.dart';

RatingPoint point(DateTime t, int rating, [int b35 = 11500, int b15 = 4853]) =>
    RatingPoint(
      tMs: t.millisecondsSinceEpoch,
      rating: rating,
      best35: b35,
      best15: b15,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ChartHistoryStore.instance.debugClearCache();
  });

  tearDown(() {
    ChartHistoryStore.instance.debugClearCache();
  });

  void seed(List<RatingPoint> series, {int chartCount = 0, int eventCount = 0}) {
    ChartHistoryStore.debugRatingSeriesLoader = () async => series;
    ChartHistoryStore.debugSummaryLoader = () async => ChartHistorySummary(
          sourceKey: 'shuiyu',
          chartCount: chartCount,
          eventCount: eventCount,
          ratingPointCount: series.length,
          firstRecordedAtMs:
              series.isEmpty ? 0 : series.first.tMs,
          updatedAtMs: series.isEmpty ? 0 : series.last.tMs,
        );
  }

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: RatingHistoryPage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('没有历史：说明会怎么开始记录，而不是空白页', (tester) async {
    seed(const []);
    await pump(tester);

    expect(find.text('还没有历史数据'), findsOneWidget);
    expect(find.textContaining('每次「刷新数据」都会顺手记一笔'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
    expect(find.textContaining('当前数据源：'), findsOneWidget);
    expect(find.textContaining('已记录 0 张谱面'), findsNothing,
        reason: '没采集到时不必显示"已记录 0 张"这种废话');
    expect(find.textContaining('历史只能从现在开始攒'), findsOneWidget,
        reason: '要如实说明：水鱼/落雪都没有历史接口，回填不了');
  });

  testWidgets('只有一个记录点：画不出曲线，但给出下一步动作', (tester) async {
    seed([point(DateTime(2026, 9, 1, 10), 16353)]);
    await pump(tester);

    expect(find.textContaining('目前只有 1 个记录点'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
    // 统计行仍然要有值（用户至少能看到当前 Rating）
    expect(find.text('16353'), findsWidgets);
  });

  testWidgets('多个记录点：画出曲线 + 档位统计 + 记录点列表', (tester) async {
    seed([
      point(DateTime(2026, 9, 1, 10), 16000, 11200, 4800),
      point(DateTime(2026, 9, 2, 10), 16150, 11300, 4850),
      point(DateTime(2026, 9, 3, 10), 16353, 11500, 4853),
    ], chartCount: 1189, eventCount: 42);
    await pump(tester);

    expect(find.byType(LineChart), findsOneWidget);
    expect(find.text('当前'), findsOneWidget);
    expect(find.text('最高'), findsOneWidget);
    expect(find.text('16353'), findsWidgets);
    // 默认「近 90 天」里三个点都在 → 区间变化 = 16353 - 16000
    expect(find.text('+353'), findsOneWidget);
    expect(find.text('记录点'), findsOneWidget);
    expect(find.text('2026/09/03'), findsOneWidget);
    expect(find.text('2026/09/01'), findsOneWidget);
    expect(find.text('近 30 天'), findsOneWidget);
    expect(find.text('全部'), findsOneWidget);
    // 采集规模要如实展示：单谱曲线挂在这些"变化"上
    expect(find.textContaining('已记录 1189 张谱面的成绩基线'), findsOneWidget);
    expect(find.textContaining('42 次成绩变化'), findsOneWidget);
    expect(find.textContaining('曲目详情页'), findsOneWidget,
        reason: '要告诉用户单谱曲线在哪看');
    expect(tester.takeException(), isNull);
  });

  testWidgets('切换时间范围不会崩（近30天 / 全部）', (tester) async {
    final now = DateTime.now();
    seed([
      for (final offset in [60, 40, 3, 1])
        point(now.subtract(Duration(days: offset)), 16000 + offset),
    ]);
    await pump(tester);
    expect(find.byType(LineChart), findsOneWidget);

    await tester.tap(find.text('全部'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(LineChart), findsOneWidget);

    await tester.tap(find.text('近 30 天'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(LineChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('近 30 天里只剩一个点时，会自动带上范围外最后一个点，曲线才有起点',
      (tester) async {
    final now = DateTime.now();
    seed([
      point(now.subtract(const Duration(days: 60)), 16000),
      point(now.subtract(const Duration(days: 2)), 16200),
    ]);
    await pump(tester);

    // 切到「近 30 天」：范围里只剩 2 天前那一个点，
    // 于是自动把 60 天前那个也带上，否则画不出任何趋势
    await tester.tap(find.text('近 30 天'));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(LineChart), findsOneWidget);
    expect(find.text('+200'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
