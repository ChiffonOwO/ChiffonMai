import 'dart:async';
// Rating 历史页（M2）的渲染测试。
//
// 三种状态都要能看：没数据（要讲清楚"从今天开始记"）、只有一个点（也绘制曲线）、
// 多个点（曲线 + 档位统计 + 记录点列表）。
//
// ⚠️ 数据用 `ChartHistoryStore.debugRatingSeriesLoader` 注入，**不碰真实文件**：
// widget 测试跑在 fake async 里，真实文件 I/O 的 await 不会完成（页面会一直转圈，
// 甚至把整个测试挂死）。真实文件读写由 `test/chart_history_test.dart` 覆盖。
import 'package:fl_chart/fl_chart.dart';
import 'package:my_first_flutter_app/utils/CurrentDataSourceNotifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_first_flutter_app/page/History/RatingHistoryPage.dart';
import 'package:my_first_flutter_app/service/History/ChartHistoryCore.dart';
import 'package:my_first_flutter_app/service/History/ChartHistoryStore.dart';
import 'package:my_first_flutter_app/service/SongInfoService.dart';
import 'package:my_first_flutter_app/utils/ScoreInputValidator.dart';

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
    CurrentDataSourceNotifier.instance.value = RefreshDataSource.shuiyu;
    ChartHistoryStore.instance.debugClearCache();
    SongInfoService.debugTheoreticalRatingOverride = null;
  });

  tearDown(() {
    ChartHistoryStore.instance.debugClearCache();
    SongInfoService.debugTheoreticalRatingOverride = null;
  });

  void seed(List<RatingPoint> series,
      {int chartCount = 0, int eventCount = 0}) {
    ChartHistoryStore.debugRatingSeriesLoader = () async => series;
    ChartHistoryStore.debugSummaryLoader = () async => ChartHistorySummary(
          sourceKey: 'shuiyu',
          chartCount: chartCount,
          eventCount: eventCount,
          ratingPointCount: series.length,
          firstRecordedAtMs: series.isEmpty ? 0 : series.first.tMs,
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

  testWidgets('只有一个记录点：也绘制单点曲线', (tester) async {
    seed([point(DateTime(2026, 9, 1, 10), 16353)]);
    await pump(tester);

    expect(find.byType(LineChart), findsOneWidget);
    // 统计行仍然要有值（用户至少能看到当前 Rating）
    expect(find.text('16353'), findsWidgets);
  });

  // ==========================================================================
  // 横轴刻度：只有一个记录点时必须只显示到「日」
  //
  // fl_chart 对**任何** min/max 都会画出起点/中点/终点三个刻度（实测单点时
  // minX=-0.5、maxX=0.5、interval=1 → -0.5 / 0 / 0.5，三个都落在同一个点上）。
  // 秒级文案 `9/1 10:00:00` 有 16 个字符，三个挤在同一处必然互相压字并顶出画布。
  // ==========================================================================

  /// 只找曲线内部的文字（页面别处也有日期，比如下面的记录点列表）。
  Finder chartText(String text) => find.descendant(
        of: find.byType(LineChart),
        matching: find.text(text),
      );

  Finder chartTextContaining(String text) => find.descendant(
        of: find.byType(LineChart),
        matching: find.textContaining(text),
      );

  testWidgets('只有一个记录点：横轴三个刻度都只显示到「日」', (tester) async {
    seed([point(DateTime(2026, 9, 1, 10), 16353)]);
    await pump(tester);

    expect(chartText('9/1'), findsWidgets);
    expect(chartTextContaining(':'), findsNothing,
        reason: '单点时秒级刻度会顶出画布，只留到日');
    expect(chartText('8/31'), findsNothing,
        reason: '单点曲线横轴被撑成前后各半天，左端不该标出"没有数据的前一天"');
    expect(tester.takeException(), isNull);
  });

  testWidgets('两个点且跨度小于两天：横轴仍然精确到秒', (tester) async {
    seed([
      point(DateTime(2026, 9, 1, 10), 16000),
      point(DateTime(2026, 9, 1, 22), 16100),
    ]);
    await pump(tester);

    expect(chartText('9/1 10:00:00'), findsWidgets,
        reason: '同一天内的两次变化要能看出是几点几分');
    expect(tester.takeException(), isNull);
  });

  testWidgets('记录点可以单独删除：取消不动数据，确认后按那一秒删掉', (tester) async {
    // 注意：不能借 seed()（它捕获的是它自己的参数），这里要捕获下面这个变量，
    // 删掉之后重新读取才会反映出来
    var series = [
      point(DateTime(2026, 9, 1, 10), 16000),
      point(DateTime(2026, 9, 2, 10), 16100),
      point(DateTime(2026, 9, 3, 10), 16353),
    ];
    ChartHistoryStore.debugRatingSeriesLoader = () async => series;
    ChartHistoryStore.debugSummaryLoader = () async => ChartHistorySummary(
          sourceKey: 'shuiyu',
          chartCount: 1,
          eventCount: 0,
          ratingPointCount: series.length,
          firstRecordedAtMs: series.first.tMs,
          updatedAtMs: series.last.tMs,
        );
    final deleted = <int>[];
    ChartHistoryStore.debugRatingPointDeleter = (tMs) async {
      deleted.add(tMs);
      series = series.where((p) => p.tMs != tMs).toList();
      return true;
    };

    await pump(tester);
    expect(find.text('2026/09/03 10:00:00'), findsOneWidget);

    // 列表是倒序，第一行就是最新的点
    final firstDelete = find.byTooltip('删除这个记录点').first;
    await tester.ensureVisible(firstDelete);
    await tester.pump();
    await tester.tap(firstDelete);
    await tester.pumpAndSettle();
    expect(find.text('删除这个记录点？'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(deleted, isEmpty, reason: '取消就该什么都不做');
    expect(find.text('2026/09/03 10:00:00'), findsOneWidget);

    await tester.tap(find.byTooltip('删除这个记录点').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(deleted, [DateTime(2026, 9, 3, 10).millisecondsSinceEpoch],
        reason: '删的必须是被点中的那一行的时间');
    expect(find.text('2026/09/03 10:00:00'), findsNothing);
    expect(find.text('2026/09/02 10:00:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('记录点那一行：B35 / B15 必须完整显示，不能被省略号截断', (tester) async {
    // 360dp 窄屏：以前日期列写死 150px、Rating 列写死 56px，
    // 留给 B35/B15 的只有 106px（实测这段文字要 117.9px），于是永远显示成
    // 「B35 11500 / B15 …」。
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0; // → 360 × 800 dp
    addTearDown(tester.view.reset);
    seed([point(DateTime(2026, 9, 3, 10), 16353, 16956, 5023)]);
    await pump(tester);

    final text = find.text('B35 16956 / B15 5023');
    expect(text, findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(text);
    expect(paragraph.didExceedMaxLines, isFalse,
        reason: '被 ellipsis 截断时这里会是 true');
    expect(tester.takeException(), isNull);
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
    expect(find.text('2026/09/03 10:00:00'), findsOneWidget);
    expect(find.text('2026/09/01 10:00:00'), findsOneWidget);
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

  testWidgets('近 30 天里只剩一个点时，会自动带上范围外最后一个点，曲线才有起点', (tester) async {
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
  testWidgets('账号切换会重载历史，先前账号迟到的读取不能覆盖新页面', (tester) async {
    final first = Completer<List<RatingPoint>>();
    var calls = 0;
    ChartHistoryStore.debugRatingSeriesLoader = () {
      calls++;
      if (calls == 1) return first.future;
      return Future.value([point(DateTime.now(), 12000)]);
    };
    ChartHistoryStore.debugSummaryLoader = () async =>
        const ChartHistorySummary(
            sourceKey: 'awmc',
            chartCount: 1,
            eventCount: 0,
            ratingPointCount: 1,
            firstRecordedAtMs: 0,
            updatedAtMs: 0);
    await pump(tester);
    CurrentDataSourceNotifier.instance.value = RefreshDataSource.awmc;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('12000'), findsWidgets);
    first.complete([point(DateTime.now(), 17000)]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('17000'), findsNothing);
    expect(find.textContaining('当前数据源：AWMC NET'), findsOneWidget);
  });
  testWidgets('换账号读取失败时不显示旧账号曲线', (tester) async {
    seed([point(DateTime.now(), 17000)]);
    await pump(tester);
    expect(find.text('17000'), findsWidgets);
    ChartHistoryStore.debugRatingSeriesLoader =
        () async => throw StateError('read failed');
    CurrentDataSourceNotifier.instance.value = RefreshDataSource.luoxue;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('17000'), findsNothing);
    expect(find.text('还没有历史数据'), findsOneWidget);
  });

  // ==========================================================================
  // 「添加 Rating 历史」弹窗的关闭路径
  //
  // 这里曾经**必崩红屏**：controller 在 `showDialog` 的 future 完成那一刻就被
  // dispose，而那个 future 是 `Route.popped` —— pop 的瞬间就完成，弹窗此时还在
  // **退场动画**里（真机上键盘收起会让它重建）。退场期间 `TextField` 再读一次
  // 已释放的 controller → 「A TextEditingController was used after being
  // disposed」；异常发生在卸载途中，元素树被撕成半死状态，于是紧接着刷出
  //   '_dependents.isEmpty': is not true
  //   Tried to build dirty widget in the wrong build scope
  // 修法：controller 交给弹窗自己的 State 释放（见 `_ManualRatingDialog`）。
  // ==========================================================================

  /// pop 的瞬间 + 退场动画期间（模拟真机键盘收起触发的重建）都不能有异常。
  Future<void> expectCleanDialogExit(WidgetTester tester) async {
    await tester.pump();
    expect(tester.takeException(), isNull,
        reason: 'pop 的瞬间不该读已释放的 controller');

    tester.view.viewInsets = const FakeViewPadding(bottom: 0);
    addTearDown(tester.view.reset);
    await tester.pump(const Duration(milliseconds: 40));
    expect(tester.takeException(), isNull,
        reason: '退场动画期间弹窗重建，同样不该读已释放的 controller');

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> openManualDialog(WidgetTester tester) async {
    await tester.tap(find.byTooltip('添加历史记录'));
    await tester.pumpAndSettle();
    expect(find.text('添加 Rating 历史'), findsOneWidget);
  }

  // ==========================================================================
  // 手动录入的合法值校验
  //
  // Rating / Best35 / Best15 都不得超过**当前理论值**（全谱面 SSS+ 时的
  // B35 / B15 / 总和）。只卡总和是不够的：用户完全可以把 B35 填成 99999
  // 而总和看着"还行"。
  //
  // 理论值靠 `SongInfoService.debugTheoreticalRatingOverride` 注入：
  // widget 测试里没有歌曲缓存，真实计算只会得到 0。
  // ==========================================================================

  Finder fieldWithLabel(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(TextField));

  bool saveEnabled(WidgetTester tester) =>
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '保存'))
          .onPressed !=
      null;

  testWidgets('手动录入：Rating / B35 / B15 分别不得超过当前理论值', (tester) async {
    seed([point(DateTime(2026, 9, 3, 10), 16353)]);
    SongInfoService.debugTheoreticalRatingOverride =
        (best35: 12000, best15: 5000, total: 17000);
    await pump(tester);
    await openManualDialog(tester);

    // 空值不给保存
    expect(saveEnabled(tester), isFalse);
    expect(find.text('上限 17000（当前理论 Rating）'), findsOneWidget);

    await tester.enterText(fieldWithLabel('Rating'), '17001');
    await tester.pump();
    expect(find.text('不得超过 17000（当前理论 Rating）'), findsOneWidget);
    expect(saveEnabled(tester), isFalse);

    // 正好等于理论值是合法的（理论上限就是"打得出来的最好成绩"）
    await tester.enterText(fieldWithLabel('Rating'), '17000');
    await tester.pump();
    expect(saveEnabled(tester), isTrue, reason: 'B35/B15 留空时 Rating 合法就能存');

    // B35 单独超了：哪怕总和没超也不合法
    await tester.enterText(fieldWithLabel('Best35（可选）'), '12001');
    await tester.pump();
    expect(find.text('不得超过 12000（当前理论 B35）'), findsOneWidget);
    expect(saveEnabled(tester), isFalse);

    await tester.enterText(fieldWithLabel('Best35（可选）'), '11900');
    await tester.pump();
    expect(saveEnabled(tester), isTrue);

    // B15 同理
    await tester.enterText(fieldWithLabel('Best15（可选）'), '5001');
    await tester.pump();
    expect(find.text('不得超过 5000（当前理论 B15）'), findsOneWidget);
    expect(saveEnabled(tester), isFalse);

    await tester.enterText(fieldWithLabel('Best15（可选）'), '4800');
    await tester.pump();
    expect(saveEnabled(tester), isTrue);

    // 非数字 / 手滑
    await tester.enterText(fieldWithLabel('Rating'), '-1');
    await tester.pump();
    expect(find.text('不能为负数'), findsOneWidget);
    expect(saveEnabled(tester), isFalse);

    await tester.enterText(fieldWithLabel('Rating'), '1635O');
    await tester.pump();
    expect(find.text('请输入数字'), findsOneWidget);
    expect(saveEnabled(tester), isFalse);

    // 小数按四舍五入存（校验是按 double 过的，别让它静默变成"点了没反应"）
    await tester.enterText(fieldWithLabel('Rating'), '16353.6');
    await tester.pump();
    expect(saveEnabled(tester), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('手动录入：拿不到理论值时退化成硬上限，不挡用户补录', (tester) async {
    seed([point(DateTime(2026, 9, 3, 10), 16353)]);
    // 不注入理论值 → 没有歌曲缓存，理论值三档全 0
    await pump(tester);
    await openManualDialog(tester);

    expect(find.text('上限 $ratingHardMax（理论值未取到）'), findsNWidgets(3),
        reason: '三个框都要如实说明在按硬上限兜底');

    await tester.enterText(fieldWithLabel('Rating'), '17500');
    await tester.pump();
    expect(saveEnabled(tester), isTrue,
        reason: '理论值不知道时不能凭空拦人（离线录历史是常见场景）');

    await tester.enterText(fieldWithLabel('Rating'), '${ratingHardMax}0');
    await tester.pump();
    expect(find.text('不得超过 $ratingHardMax'), findsOneWidget);
    expect(saveEnabled(tester), isFalse);
  });

  testWidgets('取消关闭「添加 Rating 历史」：退场全程不报错', (tester) async {
    seed([point(DateTime(2026, 9, 3, 10), 16353)]);
    await pump(tester);
    await openManualDialog(tester);

    await tester.tap(find.text('取消'));
    await expectCleanDialogExit(tester);

    expect(find.text('添加 Rating 历史'), findsNothing, reason: '弹窗要真的关掉');
    expect(find.text('16353'), findsWidgets, reason: '取消不该动到页面数据');
  });

  testWidgets('弹窗里套的「选择时间」弹窗：取消与确定都不报错，秒数要真的带回外层',
      (tester) async {
    seed([point(DateTime(2026, 9, 3, 10), 16353)]);
    await pump(tester);
    await openManualDialog(tester);

    // 打开嵌套的「选择时间」——它同样是「controller 先建后放」的重灾区
    await tester.tap(find.byIcon(Icons.event_outlined));
    await tester.pumpAndSettle();
    expect(find.text('选择时间'), findsOneWidget);

    // 外层弹窗自己有 3 个输入框，秒数那个必须按弹窗限定来找
    await tester.enterText(
      find.descendant(
        of: find.widgetWithText(AlertDialog, '选择时间'),
        matching: find.byType(TextField),
      ),
      '07',
    );
    await tester.pump();
    await tester.tap(find.text('确定'));
    await expectCleanDialogExit(tester);

    // 内层返回值必须落到外层的日期按钮上（:07），而不是被丢掉
    expect(find.textContaining(':07'), findsOneWidget);
    expect(find.text('选择时间'), findsNothing);

    // 外层再取消，整条链路的退场都不能报错
    await tester.tap(find.text('取消'));
    await expectCleanDialogExit(tester);
    expect(find.text('添加 Rating 历史'), findsNothing);
  });
}
