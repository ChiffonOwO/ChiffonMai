// 曲目详情页里「成绩历史」区块的测试（M3）。
//
// 关键口径：
//   * 没有历史**完全不占空间**（曲目页很挤，不能凭空撑一块空白）；
//   * 有基线但一次变化都没有 → 一行「已记录 …」，让用户知道功能是活的
//     （成绩取最高值，"采集过但没变化"是最常见的初始状态）；
//   * 只有一条 → 一行「首次记录」；
//   * 两条以上 → 曲线 + 可切达成率/DX + 变化列表；
//   * DX 分按"占理论满分的比例"画（不同谱面满分不同，绝对值不可比）；
//   * 出现下降要提示"疑似换源"（游戏里成绩取最高，下降必是数据差异）。
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_first_flutter_app/service/History/ChartHistoryCore.dart';
import 'package:my_first_flutter_app/service/History/ChartHistoryStore.dart';
import 'package:my_first_flutter_app/widgets/ChartHistorySection.dart';

ChartHistoryEvent ev(DateTime t, double ach, int dx) => ChartHistoryEvent(
      tMs: t.millisecondsSinceEpoch,
      achievement: ach,
      dxScore: dx,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ChartHistoryStore.instance.debugClearCache();
  });

  tearDown(() => ChartHistoryStore.instance.debugClearCache());

  // 注意：两个 loader 都要注入。真实文件 I/O 在 widget 测试的 fake async 里
  // 永远不会完成（会把测试挂死），所以这里**不允许**走到 store 的落盘分支。
  void seed(List<ChartHistoryEvent> events, {ChartBaseline? baseline}) {
    ChartHistoryStore.debugChartEventsLoader =
        (songId, levelIndex) async => events;
    ChartHistoryStore.debugChartBaselineLoader =
        (songId, levelIndex) async => baseline;
  }

  Future<void> pump(WidgetTester tester, {int? maxDxScore}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ChartHistorySection(
            songId: 11312,
            levelIndex: 3,
            maxDxScore: maxDxScore,
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('没有历史：完全占零空间', (tester) async {
    seed(const []);
    await pump(tester);

    expect(find.byType(LineChart), findsNothing);
    expect(find.textContaining('成绩历史'), findsNothing);
    expect(tester.getSize(find.byType(ChartHistorySection)).height, 0,
        reason: '曲目页很挤，没有历史时不该撑出空白');
  });

  testWidgets('采集过但还没变化：一行「已记录」，不画图也不占一块空白', (tester) async {
    seed(
      const [],
      baseline: ChartBaseline(
        achievement: 100.5678,
        dxScore: 3000,
        tMs: DateTime(2026, 9, 18).millisecondsSinceEpoch,
      ),
    );
    await pump(tester);

    expect(find.byType(LineChart), findsNothing);
    expect(find.textContaining('已记录 100.5678%'), findsOneWidget);
    expect(find.textContaining('DX 3000'), findsOneWidget);
    expect(find.textContaining('2026/09/18'), findsOneWidget);
    expect(find.textContaining('有变化后'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('基线没有时间戳（旧数据）：不显示 1970 年', (tester) async {
    seed(
      const [],
      baseline:
          const ChartBaseline(achievement: 99.5, dxScore: 0, tMs: 0),
    );
    await pump(tester);

    expect(find.textContaining('已记录 99.5000%'), findsOneWidget);
    expect(find.textContaining('1970'), findsNothing);
    expect(find.textContaining('DX'), findsNothing, reason: 'DX 为 0 时不该显示');
  });

  testWidgets('只有一条：一行「首次记录」，不画图', (tester) async {
    seed([ev(DateTime(2026, 9, 1), 99.8765, 2800)]);
    await pump(tester);

    expect(find.textContaining('首次记录'), findsOneWidget);
    expect(find.textContaining('99.8765%'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('两条以上：曲线 + 达成率/DX 切换 + 变化列表', (tester) async {
    seed([
      ev(DateTime(2026, 9, 1), 99.5000, 2800),
      ev(DateTime(2026, 9, 10), 100.1234, 2950),
      ev(DateTime(2026, 9, 18), 100.5678, 3000),
    ]);
    await pump(tester, maxDxScore: 3375);

    expect(find.textContaining('成绩历史（3 次变化）'), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
    expect(find.text('达成率'), findsOneWidget);
    expect(find.text('DX 分（占满分 %）'), findsOneWidget,
        reason: '能拿到满分就必须按比例画，而不是画绝对值');

    // 变化列表：最近一次 + 相对上一次的增量
    expect(find.text('100.5678%'), findsWidgets);
    expect(find.text('+0.4444'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 切到 DX：曲线仍然画得出来（值变成百分比）
    await tester.tap(find.text('DX 分（占满分 %）'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(LineChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('拿不到满分时退化：DX 标签不带"占满分"，也不报错', (tester) async {
    seed([
      ev(DateTime(2026, 9, 1), 99.5, 2800),
      ev(DateTime(2026, 9, 10), 100.1, 2950),
    ]);
    await pump(tester); // maxDxScore 不给

    expect(find.text('DX 分'), findsOneWidget);
    await tester.tap(find.text('DX 分'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(LineChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('曲线出现下降：提示疑似换源/换账号', (tester) async {
    seed([
      ev(DateTime(2026, 9, 1), 100.5678, 3000),
      ev(DateTime(2026, 9, 10), 99.1000, 2800),
    ]);
    await pump(tester);

    expect(find.textContaining('疑似'), findsNothing); // 文案里是"多半是"，不写"疑似"
    expect(find.textContaining('曲线出现下降'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('全程只有达成率、没有 DX 分时，不显示 DX 切换', (tester) async {
    seed([
      ev(DateTime(2026, 9, 1), 99.5, 0),
      ev(DateTime(2026, 9, 10), 100.1, 0),
    ]);
    await pump(tester);

    expect(find.byType(LineChart), findsOneWidget);
    expect(find.text('达成率'), findsNothing, reason: '只有一种指标就没必要给切换');
    expect(find.text('DX 分'), findsNothing);
  });
}
