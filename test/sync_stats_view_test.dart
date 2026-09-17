import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_flutter_app/service/SyncStatsService.dart';
import 'package:my_first_flutter_app/widgets/SyncStatsView.dart';

/// 统计摘要行的排版测试。
///
/// 起因：早先用「·」分隔 + 「近 100 次 · 87 条样本 · 平均 12.3s · 成功率 96%」
/// 在窄屏上顶出了边界，所以改成 `/` 分隔并压缩文字。
/// 这里在窄视口（320dp）下钉住「格式」与「不溢出」两件事。
void main() {
  const stats = SyncStats(
    count: 87,
    successCount: 84,
    avgMs: 12345,
    minMs: 8000,
    maxMs: 30000,
    lastMs: 11000,
    lastOk: true,
    lastAtMs: 1700000000000,
  );

  const longStats = SyncStats(
    count: 100,
    successCount: 100,
    avgMs: 75000,
    minMs: 60000,
    maxMs: 120000,
    lastMs: 90000,
    lastOk: true,
    lastAtMs: 1700000000000,
  );

  /// 用 320dp 窄屏渲染并取回那一行的文字。
  ///
  /// ⚠️ 必须用 `tester.view` 设尺寸：`tester.binding.setSurfaceSize()` 在本版本里
  /// **不会反映到 MediaQuery 的 size**，那样「320dp 窄屏不溢出」这条断言会静默失效
  /// （实际还是按 800dp 渲染）。
  Future<String> render(WidgetTester tester, SyncStats? s,
      {bool loading = false}) async {
    tester.view.physicalSize = const Size(960, 1920); // 320dp × dpr 3
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => SyncStatsView.summaryLine(
            context,
            stats: s,
            loading: loading,
            onTap: () {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    // 确认窄屏真的生效了（否则后面几条断言都是假的）
    final width = tester.getSize(find.byType(MaterialApp)).width;
    expect(width, lessThanOrEqualTo(321), reason: '视口宽度应为 320dp 左右，实际 $width');
    return tester.widget<Text>(find.byType(Text)).data!;
  }

  testWidgets('有数据：用 / 分隔，320dp 窄屏不溢出', (tester) async {
    final text = await render(tester, stats);

    // 84 / 87 = 96.55% → 四舍五入 97%
    expect(text, '近100次 / 87样本 / 平均12.3s / 成功97%');
    expect(text, isNot(contains('·')), reason: '分隔符改为 /');
    expect(tester.takeException(), isNull);
  });

  testWidgets('无数据 / 不可用 / 加载中三种文案', (tester) async {
    expect(await render(tester, SyncStats.empty), '近100次 / 暂无记录');
    await tester.pumpWidget(const SizedBox.shrink()); // 换一棵树
    expect(await render(tester, null), '统计不可用');
    await tester.pumpWidget(const SizedBox.shrink());
    expect(await render(tester, null, loading: true), '统计加载中…');
  });

  testWidgets('最长文案（1m15s / 100%）也不撑爆', (tester) async {
    final text = await render(tester, longStats);
    expect(text, '近100次 / 100样本 / 平均1m15s / 成功100%');
    expect(tester.takeException(), isNull);
  });
}
