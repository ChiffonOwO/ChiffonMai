// 曲目详情页里「成绩历史」区块的测试（M3）。
//
// 关键口径：
//   * 没有历史**完全不占空间**（曲目页很挤，不能凭空撑一块空白）；
//   * 有基线但一次变化都没有 → 也绘制基线单点；
//   * 只有一条 → 也绘制单点曲线；
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

  Future<void> pump(WidgetTester tester,
      {int? maxDxScore, double maxAchievement = 101.0}) async {
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
            maxAchievement: maxAchievement,
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
    expect(find.text('添加成绩历史'), findsOneWidget);
    expect(
        tester.getSize(find.byType(ChartHistorySection)).height, greaterThan(0),
        reason: '没有历史时仍需提供手动录入入口');
  });

  testWidgets('采集过但还没变化：绘制基线单点', (tester) async {
    seed(
      const [],
      baseline: ChartBaseline(
        achievement: 100.5678,
        dxScore: 3000,
        tMs: DateTime(2026, 9, 18).millisecondsSinceEpoch,
      ),
    );
    await pump(tester);

    expect(find.byType(LineChart), findsOneWidget);
    expect(find.textContaining('100.5678%'), findsOneWidget);
    expect(find.textContaining('2026/09/18'), findsWidgets);
    await tester.tap(find.text('DX分数'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('3000'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('基线没有时间戳（旧数据）：不显示 1970 年', (tester) async {
    seed(
      const [],
      baseline: const ChartBaseline(achievement: 99.5, dxScore: 0, tMs: 0),
    );
    await pump(tester);

    expect(find.byType(LineChart), findsOneWidget);
    expect(find.textContaining('99.5000%'), findsOneWidget);
    expect(find.textContaining('1970'), findsNothing);
    expect(find.textContaining('DX'), findsNothing, reason: 'DX 为 0 时不该显示');
  });

  testWidgets('只有一条：也绘制单点曲线', (tester) async {
    seed([ev(DateTime(2026, 9, 1), 99.8765, 2800)]);
    await pump(tester);

    expect(find.textContaining('99.8765%'), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
  });

  // ==========================================================================
  // 横轴刻度：只有一个记录点时必须只显示到「日」
  //
  // fl_chart 对**任何** min/max 都会画出起点/中点/终点三个刻度（实测单点时
  // minX=-0.5、maxX=0.5、interval=1 → -0.5 / 0 / 0.5，三个都落在同一个点上）。
  // 秒级文案 `2026/09/01 14:30:05` 有 19 个字符，三个挤在同一处必然互相压字、
  // 还会顶出画布。
  // ==========================================================================

  /// 只找曲线内部的文字（下方变化列表里的日期是另一个 Text，别混进来）。
  Finder chartText(String text) =>
      find.descendant(of: find.byType(LineChart), matching: find.text(text));

  Finder chartTextContaining(String text) => find.descendant(
      of: find.byType(LineChart), matching: find.textContaining(text));

  testWidgets('只有一个记录点：横轴三个刻度都只显示到「日」', (tester) async {
    seed([ev(DateTime(2026, 9, 1, 14, 30, 5), 99.8765, 2800)]);
    await pump(tester);

    expect(chartText('9/1'), findsWidgets);
    expect(chartTextContaining(':'), findsNothing,
        reason: '单点时秒级刻度会顶出画布，只留到日');
    expect(tester.takeException(), isNull);
  });

  testWidgets('两个点且跨度小于两天：横轴仍然精确到秒', (tester) async {
    seed([
      ev(DateTime(2026, 9, 1, 10), 99.5, 2800),
      ev(DateTime(2026, 9, 1, 22), 100.1, 2950),
    ]);
    await pump(tester);

    expect(chartText('2026/09/01 10:00:00'), findsWidgets,
        reason: '同一天内的两次变化要能看出是几点几分');
    expect(tester.takeException(), isNull);
  });

  testWidgets('记录点可以单独删除：取消不动数据，确认后按那一秒删掉', (tester) async {
    // 不能借 seed()：它捕获的是它自己的参数，这里要捕获下面这个变量，
    // 删掉之后重新读取才会反映出来
    var events = [
      ev(DateTime(2026, 9, 1), 99.5, 2800),
      ev(DateTime(2026, 9, 10), 100.1234, 2950),
    ];
    ChartHistoryStore.debugChartEventsLoader =
        (songId, levelIndex) async => events;
    ChartHistoryStore.debugChartBaselineLoader =
        (songId, levelIndex) async => null;
    final deleted = <String>[];
    ChartHistoryStore.debugChartPointDeleter = (songId, levelIndex, tMs) async {
      deleted.add('$songId/$levelIndex@$tMs');
      events = events.where((e) => e.tMs != tMs).toList();
      return true;
    };

    await pump(tester, maxDxScore: 3375);
    expect(find.textContaining('成绩历史（2 次变化）'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('删除这个记录点').first);
    await tester.pump();
    await tester.tap(find.byTooltip('删除这个记录点').first);
    await tester.pumpAndSettle();
    expect(find.text('删除这个记录点？'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(deleted, isEmpty, reason: '取消就该什么都不做');
    expect(find.textContaining('成绩历史（2 次变化）'), findsOneWidget);

    await tester.tap(find.byTooltip('删除这个记录点').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(deleted,
        ['11312/3@${DateTime(2026, 9, 10).millisecondsSinceEpoch}'],
        reason: '删的必须是被点中的那一行的时间（列表倒序，第一行是最新的）');
    expect(find.textContaining('成绩历史（1 个记录点）'), findsOneWidget);
    expect(find.text('100.1234%'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('只有基线单点时也能删掉它', (tester) async {
    seed(
      const [],
      baseline: ChartBaseline(
        achievement: 100.5678,
        dxScore: 3000,
        tMs: DateTime(2026, 9, 18, 12).millisecondsSinceEpoch,
      ),
    );
    final deleted = <String>[];
    ChartHistoryStore.debugChartPointDeleter = (songId, levelIndex, tMs) async {
      deleted.add('$songId/$levelIndex@$tMs');
      // 基线删掉后这张谱面就"没采集过"了
      ChartHistoryStore.debugChartBaselineLoader =
          (a, b) async => null;
      return true;
    };

    await pump(tester);
    expect(find.byType(LineChart), findsOneWidget);

    await tester.tap(find.byTooltip('删除这个记录点'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(deleted,
        ['11312/3@${DateTime(2026, 9, 18, 12).millisecondsSinceEpoch}']);
    expect(find.byType(LineChart), findsNothing, reason: '删完就回到"没有历史"的形态');
    expect(find.text('添加成绩历史'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('变化超过 5 条：默认只摆 5 条，展开后每个点都能删', (tester) async {
    seed([
      for (var i = 1; i <= 7; i++)
        ev(DateTime(2026, 9, i), 99.0 + i * 0.1, 2800 + i),
    ]);
    await pump(tester);

    expect(find.byTooltip('删除这个记录点'), findsNWidgets(5));
    expect(find.text('展开全部（7 条）'), findsOneWidget,
        reason: '收起时删不到更早的点，必须给展开入口');

    await tester.ensureVisible(find.text('展开全部（7 条）'));
    await tester.pump();
    await tester.tap(find.text('展开全部（7 条）'));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byTooltip('删除这个记录点'), findsNWidgets(7));
    expect(find.text('收起'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
    expect(find.text('DX分数（占满分%）'), findsOneWidget,
        reason: '能拿到满分就必须按比例画，而不是画绝对值');

    // 变化列表：最近一次 + 相对上一次的增量
    expect(find.text('100.5678%'), findsWidgets);
    expect(find.text('+0.4444%'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 切到 DX：曲线仍然画得出来（值变成百分比）
    await tester.tap(find.text('DX分数（占满分%）'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(LineChart), findsOneWidget);
    expect(find.text('3000'), findsOneWidget);
    expect(find.text('88.89%'), findsOneWidget);
    expect(find.text('+50'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('拿不到满分时退化：DX 标签不带"占满分"，也不报错', (tester) async {
    seed([
      ev(DateTime(2026, 9, 1), 99.5, 2800),
      ev(DateTime(2026, 9, 10), 100.1, 2950),
    ]);
    await pump(tester); // maxDxScore 不给

    expect(find.text('DX分数'), findsOneWidget);
    await tester.tap(find.text('DX分数'));
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
    expect(find.text('DX分数'), findsNothing);
  });

  // ==========================================================================
  // 「添加谱面成绩历史」弹窗的关闭路径
  //
  // 这里曾经**必崩红屏**：controller 在 `showDialog` 的 future 完成那一刻就被
  // dispose，而那个 future 是 `Route.popped` —— pop 的瞬间就完成，弹窗此时还在
  // **退场动画**里（真机上键盘收起会让它重建）。退场期间 `TextField` 再读一次
  // 已释放的 controller → 「A TextEditingController was used after being
  // disposed」；异常发生在卸载途中，元素树被撕成半死状态，于是紧接着刷出
  //   '_dependents.isEmpty': is not true
  //   Tried to build dirty widget in the wrong build scope
  // 修法：controller 交给弹窗自己的 State 释放（见 `_ManualChartPointDialog`）。
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

  testWidgets('没有历史时：从「添加成绩历史」进弹窗，取消关掉全程不报错', (tester) async {
    seed(const []);
    await pump(tester);

    await tester.tap(find.text('添加成绩历史'));
    await tester.pumpAndSettle();
    expect(find.text('添加谱面成绩历史'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await expectCleanDialogExit(tester);
    expect(find.text('添加谱面成绩历史'), findsNothing);
  });

  // ==========================================================================
  // 手动录入的合法值校验（口径与「自定义 Best50」一致，见 ScoreInputValidator）
  //
  // 历史是长期数据，写进去一个 99999 的达成率，曲线会被一个点拉成一条竖线，
  // 而且它跟自动采集的点混在一起、事后分不出哪个是手滑。
  // ==========================================================================

  Finder fieldWithLabel(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(TextField));

  bool saveEnabled(WidgetTester tester) =>
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '保存'))
          .onPressed !=
      null;

  Future<void> openAddDialog(WidgetTester tester) async {
    await tester.tap(find.text('添加成绩历史'));
    await tester.pumpAndSettle();
    expect(find.text('添加谱面成绩历史'), findsOneWidget);
  }

  testWidgets('手动录入：达成率和 DX 都要卡在谱面上限内，非法就不给保存', (tester) async {
    seed(const []);
    await pump(tester, maxDxScore: 3375);
    await openAddDialog(tester);

    // 达成率还没填 → 不给保存（空值也不能进历史）
    expect(saveEnabled(tester), isFalse);

    // 超过普通谱面上限 101%（旧版本客户端能打出的 101.5 之类）
    await tester.enterText(fieldWithLabel('达成率（%）'), '101.5');
    await tester.pump();
    expect(find.text('不得超过 101（谱面上限）'), findsOneWidget);
    expect(saveEnabled(tester), isFalse);

    // 手滑多打一位：离谱到超过硬上限时先报硬上限
    await tester.enterText(fieldWithLabel('达成率（%）'), '1005');
    await tester.pump();
    expect(find.text('不得超过 999.9999'), findsOneWidget);
    expect(saveEnabled(tester), isFalse);

    await tester.enterText(fieldWithLabel('达成率（%）'), 'abc');
    await tester.pump();
    expect(find.text('请输入数字'), findsOneWidget);
    expect(saveEnabled(tester), isFalse);

    await tester.enterText(fieldWithLabel('达成率（%）'), '100.5');
    await tester.pump();
    expect(saveEnabled(tester), isTrue,
        reason: 'DX 默认 0（可选）时，达成率合法就能存');

    // DX 超过谱面满分（物量 × 3）
    await tester.enterText(fieldWithLabel('DX 分数（可选）'), '3376');
    await tester.pump();
    expect(find.text('不得超过 3375（谱面上限）'), findsOneWidget);
    expect(saveEnabled(tester), isFalse);

    await tester.enterText(fieldWithLabel('DX 分数（可选）'), '3375');
    await tester.pump();
    expect(saveEnabled(tester), isTrue, reason: '正好满分是合法的');

    // 小数按四舍五入存（校验按 double 过，别让它静默变成"点了没反应"）
    await tester.enterText(fieldWithLabel('DX 分数（可选）'), '3000.6');
    await tester.pump();
    expect(saveEnabled(tester), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('手动录入：宴会场达成率上限是 101 × 子谱数', (tester) async {
    seed(const []);
    await pump(tester, maxDxScore: 2000, maxAchievement: 202);
    await openAddDialog(tester);

    // 150% 在普通曲非法，在宴会场（两个子谱相加）合法
    await tester.enterText(fieldWithLabel('达成率（%）'), '150');
    await tester.pump();
    expect(saveEnabled(tester), isTrue);
    expect(find.text('上限 202（宴会场子谱相加）'), findsOneWidget);

    await tester.enterText(fieldWithLabel('达成率（%）'), '202.5');
    await tester.pump();
    expect(find.text('不得超过 202（谱面上限）'), findsOneWidget);
    expect(saveEnabled(tester), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('手动录入：上限拿不到时（没有物量数据）只做硬上限校验', (tester) async {
    seed(const []);
    await pump(tester); // maxDxScore 不给
    await openAddDialog(tester);

    await tester.enterText(fieldWithLabel('达成率（%）'), '100.5');
    await tester.pump();
    expect(saveEnabled(tester), isTrue);

    await tester.enterText(fieldWithLabel('DX 分数（可选）'), '9000');
    await tester.pump();
    expect(saveEnabled(tester), isTrue, reason: '不知道满分就不能乱挡');

    await tester.enterText(fieldWithLabel('DX 分数（可选）'), '10000');
    await tester.pump();
    expect(find.text('不得超过 9999'), findsOneWidget,
        reason: '硬上限始终生效');
    expect(saveEnabled(tester), isFalse);
  });

  testWidgets('已有历史时：从右上角图标进弹窗，取消关掉全程不报错', (tester) async {
    seed([
      ev(DateTime(2026, 9, 1), 99.5, 2800),
      ev(DateTime(2026, 9, 10), 100.1, 2950),
    ]);
    await pump(tester, maxDxScore: 3375);

    await tester.tap(find.byTooltip('添加成绩历史'));
    await tester.pumpAndSettle();
    expect(find.text('添加谱面成绩历史'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await expectCleanDialogExit(tester);
    expect(find.text('添加谱面成绩历史'), findsNothing);
    expect(find.byType(LineChart), findsOneWidget, reason: '取消不该动到曲线');
  });

  testWidgets('弹窗里套的「选择时间」弹窗：确定后秒数要带回外层的日期按钮',
      (tester) async {
    seed(const []);
    await pump(tester);

    await tester.tap(find.text('添加成绩历史'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.event_outlined));
    await tester.pumpAndSettle();
    expect(find.text('选择时间'), findsOneWidget);

    // 外层弹窗自己有 2 个输入框，秒数那个必须按弹窗限定来找
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

    expect(find.textContaining(':07'), findsOneWidget);
    expect(find.text('选择时间'), findsNothing);

    await tester.tap(find.text('取消'));
    await expectCleanDialogExit(tester);
    expect(find.text('添加谱面成绩历史'), findsNothing);
  });
}
