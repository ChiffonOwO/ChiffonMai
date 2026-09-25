import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_flutter_app/page/HubComponents.dart';
import 'package:my_first_flutter_app/service/SyncStatsService.dart';
import 'package:my_first_flutter_app/utils/SyncRouteNotifier.dart';
import 'package:my_first_flutter_app/widgets/SyncStatsFooter.dart';

/// 「同步成绩到 AWMC NET」按钮 ↔ 它下面那行统计的间距回归。
///
/// 起因（真机反馈）：统计行离按钮有点远。原因是两行 `ListTile` 的最小高度是 72px，
/// 内容撑不满时**底部本来就空着约 23px**，一行小字挂在 tile 底边就会显得很远。
/// 现在 AWMC NET 那个 tile 会用 [HubActionTile.footerLift] 上提
/// （见 [SyncStatsFooter.footerLift]）。
///
/// 这里钉住三件事：
///   1. 副标题 → 统计行的距离确实收紧了（且不能贴死）；
///   2. 上提**不能**改变 footer 下方的留白（否则下面的 tile 会被挤压）；
///   3. 没传 footerLift 的 tile（水鱼 / 落雪的线路切换器）间距保持原样。
void main() {
  const stats = SyncStats(
    count: 42,
    successCount: 40,
    avgMs: 36000,
    minMs: 30000,
    maxMs: 45000,
    lastMs: 33000,
    lastOk: true,
    lastAtMs: 1,
  );

  setUp(() {
    SyncRouteNotifier.instance.debugResetForTest();
    SyncRouteNotifier.debugDisableStatsPolling = true;
    SyncRouteNotifier.instance.debugSetStats({
      SyncStatsService.slotOf(SyncLine.direct, SyncPlatform.awmc): stats,
    });
  });

  tearDown(() => SyncRouteNotifier.instance.debugResetForTest());

  /// 渲染一个 tile（+footer），返回「副标题底 → footer 第一行文字顶」的距离，
  /// 以及 footer 文字底部到整块底部的距离。
  Future<(double, double)> layout(
    WidgetTester tester, {
    required double footerLift,
    double scale = 1.0,
  }) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: ListView(
          children: [
            HubActionTile(
              title: '同步成绩到 AWMC NET',
              subtitle: '用机台二维码导入成绩到 AWMC NET',
              icon: Icons.cloud_upload_outlined,
              onTap: () {},
              footerLift: footerLift,
              footer: const SyncStatsFooter(
                slot: (SyncLine.direct, SyncPlatform.awmc),
              ),
            ),
          ],
        ),
      ),
    ));
    // ⚠️ 不能用 pumpAndSettle：字体调大后副标题会溢出，MarqueeText 的 ticker
    // 一跑起来就永远「settle」不了（那正是它该有的行为）。这里只量布局。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    // ⚠️ `.first`：字体调大后副标题会溢出，MarqueeText 会摆两份同样的文本
    final subtitle =
        tester.getRect(find.text('用机台二维码导入成绩到 AWMC NET').first);
    final statsText = tester.getRect(find.textContaining('近100次'));
    final column = tester.getRect(find.byType(Column).last);
    return (statsText.top - subtitle.bottom, column.bottom - statsText.bottom);
  }

  testWidgets('上提后：统计行离按钮更近，但没贴死', (tester) async {
    final (gap, _) = await layout(tester, footerLift: SyncStatsFooter.footerLift);

    // 原来是 25.8px（实测）——太远；上提 10 后约 15.8px
    expect(gap, lessThan(18), reason: '统计行离按钮还是太远（实测 ${gap}px）');
    expect(gap, greaterThan(8), reason: '贴太死会和副标题糊在一起（实测 ${gap}px）');
  });

  testWidgets('上提不改变 footer 下方的留白', (tester) async {
    final (_, belowWithLift) =
        await layout(tester, footerLift: SyncStatsFooter.footerLift);
    await tester.pumpWidget(const SizedBox.shrink());
    final (_, belowPlain) = await layout(tester, footerLift: 0);

    expect((belowWithLift - belowPlain).abs(), lessThan(0.5),
        reason: '上提只该把自己的底部内边距吃掉，不能让下面的 tile 被挤走');
  });

  testWidgets('大字体下也不会和副标题叠在一起', (tester) async {
    final (gap, _) = await layout(
      tester,
      footerLift: SyncStatsFooter.footerLift,
      scale: 1.5,
    );
    expect(gap, greaterThan(0),
        reason: '系统字体调大后统计行不能压到副标题上（实测 ${gap}px）');
  });

  testWidgets('没传 footerLift 的 tile 保持原样（水鱼 / 落雪的切换器）',
      (tester) async {
    final (gap, _) = await layout(tester, footerLift: 0);
    expect(gap, greaterThan(20), reason: '默认值 = 不动这些入口的间距');
  });
}
