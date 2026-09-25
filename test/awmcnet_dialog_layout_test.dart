import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_flutter_app/constant/CacheKeyConstant.dart';
import 'package:my_first_flutter_app/page/AwmcNet/SyncToAwmcNetPage.dart';
import 'package:my_first_flutter_app/service/SyncStatsService.dart';
import 'package:my_first_flutter_app/utils/SyncRouteNotifier.dart';
import 'package:my_first_flutter_app/widgets/SyncRouteSwitcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 「同步成绩到 AWMC NET」对话框的布局 / 交互回归。
///
/// 两件事：
///   1. **布局**：标题是 `Row(图标 + Text)`，而 `AlertDialog` 的标题区宽度很窄
///      （360dp 屏上只剩约 232dp）。`Text` 没有 `Expanded` 包着就撑不下，
///      直接 RenderFlex 溢出 —— 实测在真机上「溢出 45 像素」。
///      落雪的同类对话框标题只有 6 个汉字所以没事，这条名字长得多才暴露出来。
///   2. **交互**：等待进度显示在**按钮上**（与另外两个同步入口一致），
///      所以对话框里不该有任何「已等待 N 秒」之类的等待 UI，提交后立刻关闭。
void main() {
  setUp(() {
    // 统计页脚会订阅 SyncRouteNotifier，订阅一建立就开始轮询 Redis（挂 Timer）。
    // 布局测试不该被迫管那个 Timer，所以关掉轮询、直接把统计注进去。
    SyncRouteNotifier.instance.debugResetForTest();
    SyncRouteNotifier.debugDisableStatsPolling = true;
  });

  tearDown(() => SyncRouteNotifier.instance.debugResetForTest());

  /// 打开对话框并返回。把屏幕设成窄机（360dp）以复现真机约束。
  Future<void> openDialog(WidgetTester tester, {double width = 360}) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(Size(width, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showAwmcNetSyncInputDialog(ctx),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('360dp 窄屏：对话框不出现任何溢出', (tester) async {
    await openDialog(tester);

    // 溢出在测试里是以异常形式冒出来的（"A RenderFlex overflowed by N pixels"），
    // 所以这一行就是这条回归的核心断言。
    expect(tester.takeException(), isNull,
        reason: '对话框内不该有 RenderFlex 溢出（标题区曾溢出 45px）');
  });

  testWidgets('标题文字仍在（不靠删字来消溢出）', (tester) async {
    await openDialog(tester);
    expect(find.text('同步成绩到 AWMC NET'), findsOneWidget);
  });

  testWidgets('更窄的 320dp 屏也不溢出', (tester) async {
    await openDialog(tester, width: 320);
    expect(tester.takeException(), isNull, reason: '320dp 小屏同样不能溢出');
  });

  testWidgets('大字体（textScale 1.5）下也不溢出', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(textScaler: const TextScaler.linear(1.5)),
        child: child!,
      ),
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showAwmcNetSyncInputDialog(ctx),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: '用户把系统字体调大后标题区同样不能溢出');
  });

  testWidgets('Token 引导：指向设置页 + 说清在最底部点「生成/轮换Token」', (tester) async {
    await openDialog(tester);

    // 链接必须带尾斜杠的 /settings/ —— 这是真的能生成 Token 的那个页面
    expect(find.textContaining('https://net.wmc.pub/settings/'), findsOneWidget);
    // 「滑到底部」和按钮名都得写出来：按钮在页面最下面，不写用户在上面找不到
    expect(find.textContaining('滑到页面最底部'), findsOneWidget);
    expect(find.textContaining('生成/轮换Token'), findsOneWidget);
    expect(find.textContaining('粘贴到此处'), findsOneWidget);
  });

  testWidgets('近 100 次统计：有数据时显示，且没有线路切换器', (tester) async {
    SyncRouteNotifier.instance.debugSetStats({
      SyncStatsService.slotOf(SyncLine.direct, SyncPlatform.awmc): const SyncStats(
        count: 42,
        successCount: 40,
        avgMs: 36000,
        minMs: 30000,
        maxMs: 45000,
        lastMs: 33000,
        lastOk: true,
        lastAtMs: 1,
      ),
    });
    await openDialog(tester);

    expect(find.textContaining('近100次 / 42样本'), findsOneWidget);
    expect(find.textContaining('平均36.0s'), findsOneWidget);
    expect(find.textContaining('成功95%'), findsOneWidget);
    // 二维码直传没有线路可选 —— 这里**不该**出现线路切换器
    expect(find.byType(SyncRouteSwitcher), findsNothing,
        reason: '给 AWMC NET 画线路切换器没有意义（routeOf 也会抛异常）');
    expect(tester.takeException(), isNull);
  });

  testWidgets('还没拉到统计时显示「统计不可用」而不是空白', (tester) async {
    await openDialog(tester);
    // 没注数据 + 单测不连 Redis → notifier 里那份是 null
    expect(find.textContaining('近100次'), findsNothing);
    expect(find.textContaining('统计不可用'), findsOneWidget);
  });

  // 需求：等待进度显示在**按钮上**，对话框只负责收输入。
  // 这里钉住两件事：对话框里没有「已等待 N 秒」这类等待 UI，且提交后立刻关闭。
  testWidgets('对话框里没有等待进度（进度改到按钮上）', (tester) async {
    await openDialog(tester);

    expect(find.textContaining('已等待'), findsNothing,
        reason: '等待进度不该再出现在对话框里');
    expect(find.textContaining('秒后自动关闭'), findsNothing);
    expect(find.textContaining('机台正在拉取'), findsNothing);
    // 覆盖式写入的警告要在**操作前**说清楚（原来在结果页才说）
    expect(find.textContaining('覆盖 AWMC NET 上已存在的对应成绩'), findsOneWidget);
  });

  testWidgets('点「开始同步」只交出输入并立刻关闭对话框', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    AwmcNetSyncInput? captured;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                captured = await showAwmcNetSyncInputDialog(ctx);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 第 1 个是二维码框，第 2 个是 Token 框
    await tester.enterText(find.byType(TextField).at(0), 'SGWCMAID0123456789');
    await tester.enterText(
        find.byType(TextField).at(1), 'yBtsz-lDrWUW2NB1EEv25Zy3MF0_SaJR');
    await tester.tap(find.text('开始同步'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing,
        reason: '提交后对话框必须立刻关掉，30 多秒的等待交给按钮上的进度');
    expect(captured, isNotNull);
    expect(captured!.qr, 'SGWCMAID0123456789');
    expect(captured!.importToken, 'yBtsz-lDrWUW2NB1EEv25Zy3MF0_SaJR');
    // 顺手落盘：下次不用再填
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(CacheKeyConstant.awmcNetImportToken),
        'yBtsz-lDrWUW2NB1EEv25Zy3MF0_SaJR');
  });
}
