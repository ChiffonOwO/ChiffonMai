import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_flutter_app/page/HubComponents.dart';
import 'package:my_first_flutter_app/widgets/MarqueeText.dart';

/// 滚动副标题的回归测试。
///
/// 起因（真机反馈）：「同步成绩到 AWMC NET」按钮的副标题滚动一轮**停下来**时，
/// 第一个字前面空出约两个字的空间。
///
/// 根因：原来用的是 `marquee` 包，它每轮滚动的距离是拿**开滚那一刻**量到的文本
/// 宽度算的，而这类文案每秒都在变（`已等待 12 秒` → `已等待 13 秒`）。宽度一变，
/// 内容就在视口下整体平移，于是停顿落点漂到 ±blankSpace 之间。下面这条测试就是
/// 复现它的：跑到每一个「停顿」处，量第一个可见字符离视口左边缘多远，
/// **正数即代表第一个字前面有空隙**（原来是 0~+40px 乱漂，现在是恒等于 0）。
void main() {
  /// 关键指标：视口左边缘到「第一个可见字符」的距离。
  ///
  /// 负数 = 文字从左边被裁掉一点（正常滚动/对齐）；正数 = 前面有空隙（bug）。
  double gapOf(WidgetTester tester, String text) {
    final viewport = find.byType(MarqueeText);
    if (viewport.evaluate().isEmpty) return -999;
    final left = tester.getTopLeft(viewport).dx;
    final width = tester.getSize(viewport).width;

    var best = double.infinity;
    for (final element in find.text(text).evaluate()) {
      final box = element.renderObject! as RenderBox;
      final x = box.localToGlobal(Offset.zero).dx;
      // 只算真的在视口里露出来的那一份（另一份在左边/右边完全看不见）
      if (x + box.size.width > left + 0.5 && x < left + width) {
        if (x < best) best = x;
      }
    }
    return best == double.infinity ? -888 : best - left;
  }

  Widget wrap(Widget child, {double scale = 1.0, double width = 220}) =>
      MaterialApp(
        builder: (ctx, c) => MediaQuery(
          data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.linear(scale)),
          child: c!,
        ),
        home:
            Scaffold(body: Center(child: SizedBox(width: width, child: child))),
      );

  /// 采一段时间，把「连续 >=1.2 秒几乎不动」的区段当成轮末停顿。
  Future<List<(int, double)>> pauses(
    WidgetTester tester, {
    required String Function(int second) label,
    required Widget Function(String) build,
    required double scale,
    int untilMs = 30000,
  }) async {
    var second = 0;
    await tester.pumpWidget(wrap(build(label(second)), scale: scale));

    final samples = <(int, double)>[];
    for (var ms = 0; ms < untilMs; ms += 100) {
      final next = ms ~/ 1000;
      if (next != second) {
        second = next;
        // 真实流程里文案每秒都会变（数字多一位 → 文本变宽）
        await tester.pumpWidget(wrap(build(label(second)), scale: scale));
      }
      await tester.pump(const Duration(milliseconds: 100));
      samples.add((ms, gapOf(tester, label(second))));
    }

    final found = <(int, double)>[];
    for (var i = 0; i < samples.length; i++) {
      final start = samples[i];
      var j = i;
      while (j + 1 < samples.length &&
          (samples[j + 1].$2 - start.$2).abs() < 0.6) {
        j++;
      }
      if (samples[j].$1 - start.$1 >= 1200) {
        found.add(start);
        i = j;
      }
    }
    return found;
  }

  testWidgets('短文本：静态显示，不滚动也不溢出', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(wrap(
      const MarqueeText(
        text: '用机台二维码导入成绩到 AWMC NET',
        style: TextStyle(fontSize: 12),
      ),
      width: 400,
    ));
    await tester.pump(const Duration(seconds: 3));

    // 静态分支：只有一份文本，而且贴着左边缘
    expect(find.text('用机台二维码导入成绩到 AWMC NET'), findsOneWidget);
    expect(gapOf(tester, '用机台二维码导入成绩到 AWMC NET'),
        lessThanOrEqualTo(0.5));
    expect(tester.takeException(), isNull);
  });

  group('超长文本：每个轮末停顿处，第一个字都必须贴着左边缘', () {
    for (final scale in <double>[1.0, 1.3, 1.5]) {
      testWidgets('textScale $scale', (tester) async {
        await tester.binding.setSurfaceSize(const Size(400, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        String label(int s) => '正在导入成绩…已等待 $s 秒';
        final stops = await pauses(
          tester,
          label: label,
          build: (text) =>
              MarqueeText(text: text, style: const TextStyle(fontSize: 12)),
          scale: scale,
        );

        expect(stops, isNotEmpty, reason: '跑满 30 秒应该至少停过一次');
        for (final (at, gap) in stops) {
          expect(gap, lessThanOrEqualTo(0.5),
              reason: '第 ${at}ms 处的停顿，第一个字前面空了 ${gap.toStringAsFixed(1)}px'
                  '（正数 = 有空隙，就是这次要修的那个 bug）');
        }
      });
    }
  });

  testWidgets('HubActionTile 的 loadingText 也走同一套（按钮上的进度)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String label(int s) => '正在导入成绩…已等待 $s 秒';
    final stops = await pauses(
      tester,
      label: label,
      build: (text) => HubActionTile(
        title: '同步成绩到 AWMC NET',
        subtitle: '用机台二维码导入成绩到 AWMC NET',
        icon: Icons.cloud_upload_outlined,
        onTap: () {},
        loading: true,
        loadingText: text,
      ),
      scale: 1.0,
      untilMs: 22000,
    );

    expect(stops, isNotEmpty);
    for (final (at, gap) in stops) {
      expect(gap, lessThanOrEqualTo(0.5),
          reason: '第 ${at}ms 处的停顿不能有前置空隙（实测 ${gap.toStringAsFixed(1)}px）');
    }
  });
}
