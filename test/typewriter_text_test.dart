// 打字机组件的回归测试。
//
// 这个组件的坑几乎都在"边界"上，所以测试也按边界组织：
//   * 必须按**字素簇**切 —— 按 code unit 切会把 emoji 切成半个；
//   * `onCompleted` 必须**恰好一次**（多调会把上层状态打乱）；
//   * 点一下必须立刻全显（长答案的唯一出路）；
//   * 系统开了"减弱动态效果"就直接全显；
//   * 页面不可见（TickerMode 关闭）时要**停**，别在后台烧电；
//   * 节奏要按长度自适应（短答案慢、长答案快）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_flutter_app/widgets/TypewriterText.dart';

const _interval = Duration(milliseconds: 20);

/// 渲染一个打字机，[banner] 用来注入 MediaQuery 之类。
Future<void> pumpTypewriter(
  WidgetTester tester, {
  required String text,
  required VoidCallback onCompleted,
  VoidCallback? onProgress,
  Duration? interval = _interval,
  MediaQueryData? mediaQuery,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) {
          final child = TypewriterText(
            text: text,
            interval: interval,
            onCompleted: onCompleted,
            onProgress: onProgress,
          );
          if (mediaQuery == null) return child;
          return MediaQuery(data: mediaQuery, child: child);
        },
      ),
    ),
  ));
  await tester.pump();
}

/// 当前打字机渲染出来的完整文本（含光标）。
///
/// ⚠️ 必须精确定位到打字机自己的那个 `Text`：`find.byType(Text).first` 会
/// 命中别处（比如按钮文案），它没有 `textSpan`，直接 `!` 会抛 "Null check
/// operator used on a null value"。
String renderedText(WidgetTester tester) {
  final spans = tester
      .widgetList<Text>(find.descendant(
        of: find.byType(TypewriterText),
        matching: find.byType(Text),
      ))
      .map((t) => t.textSpan)
      .whereType<TextSpan>()
      .toList();
  if (spans.isEmpty) return '';
  final span = spans.first;
  final buffer = StringBuffer(span.text ?? '');
  for (final c in span.children ?? const <InlineSpan>[]) {
    if (c is TextSpan) buffer.write(c.text ?? '');
  }
  return buffer.toString();
}

/// 去掉光标字符后的可见正文。
String visibleText(WidgetTester tester) =>
    renderedText(tester).replaceAll('▌', '');

void main() {
  testWidgets('逐字推进：先出第一个字，再按间隔增长', (tester) async {
    var done = 0;
    await pumpTypewriter(
      tester,
      text: '错位是什么',
      onCompleted: () => done++,
    );

    // 第一帧（post frame 后启动）还没打
    expect(visibleText(tester), '');

    await tester.pump(_interval);
    expect(visibleText(tester), '错');
    await tester.pump(_interval);
    expect(visibleText(tester), '错位');
    await tester.pump(_interval);
    expect(visibleText(tester), '错位是');

    // 还没打完
    expect(done, 0);

    // 走完剩余字符
    for (var i = 0; i < 10; i++) {
      await tester.pump(_interval);
    }
    expect(visibleText(tester), '错位是什么');
    expect(done, 1, reason: 'onCompleted 必须恰好一次');
  });

  testWidgets('onCompleted 恰好一次（多打几帧也不会重复回调）', (tester) async {
    var done = 0;
    await pumpTypewriter(tester, text: 'abc', onCompleted: () => done++);
    for (var i = 0; i < 20; i++) {
      await tester.pump(_interval);
    }
    expect(done, 1);
  });

  testWidgets('按字素簇切：emoji / 组合字不会被切成半个', (tester) async {
    // 👨‍👩‍👧 是一个 ZWJ 序列（多个 code point 组成一个字素簇）
    // é 用组合形式（e + U+0301）
    const text = '👨‍👩‍👧e\u0301X';
    var done = 0;
    await pumpTypewriter(tester, text: text, onCompleted: () => done++);

    final seen = <String>{};
    for (var i = 0; i < 20; i++) {
      await tester.pump(_interval);
      seen.add(visibleText(tester));
      if (done > 0) break;
    }

    // 每个中间态都必须是"若干完整字素簇"的前缀，不能出现半个 emoji
    for (final s in seen) {
      expect(
        text.startsWith(s),
        isTrue,
        reason: '出现了不是原文前缀的中间态「$s」—— 说明按 code unit 切了',
      );
    }
    expect(visibleText(tester), text);
    expect(done, 1);
  });

  testWidgets('点一下立即全显', (tester) async {
    var done = 0;
    await pumpTypewriter(
      tester,
      text: '这是一段挺长的答案，用户不一定愿意等它一个字一个字打完。',
      onCompleted: () => done++,
    );

    await tester.pump(_interval);
    expect(visibleText(tester).length, 1, reason: '先确认还只打了一个字');

    await tester.tap(find.byType(TypewriterText));
    await tester.pump();

    expect(visibleText(tester), '这是一段挺长的答案，用户不一定愿意等它一个字一个字打完。');
    expect(done, 1, reason: '跳过也要算"打完"，否则外层状态会一直卡在 typing');

    // 打过之后再点不该再回调
    await tester.tap(find.byType(TypewriterText));
    await tester.pump();
    expect(done, 1);
  });

  testWidgets('系统开启"减弱动态效果"时直接全显', (tester) async {
    var done = 0;
    await pumpTypewriter(
      tester,
      text: '无障碍模式下不要动画',
      onCompleted: () => done++,
      mediaQuery: const MediaQueryData(disableAnimations: true),
    );
    await tester.pump();

    expect(visibleText(tester), '无障碍模式下不要动画');
    expect(done, 1);
  });

  testWidgets('TickerMode 关闭时不打字，重新打开才继续', (tester) async {
    var done = 0;
    // ⚠️ 一开始就关着：否则 TickerMode 默认是开的，打字机第一帧就跑起来了，
    // 等你去关的时候已经打了几个字 —— 那样测不出"暂停"。
    var enabled = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setLocal) => Column(
            children: [
              TextButton(
                onPressed: () => setLocal(() => enabled = !enabled),
                child: const Text('toggle'),
              ),
              TickerMode(
                enabled: enabled,
                child: TypewriterText(
                  text: 'abcdef',
                  interval: _interval,
                  onCompleted: () => done++,
                ),
              ),
            ],
          ),
        ),
      ),
    ));
    await tester.pump();

    // 关着：一个字都不该打出来（页面不可见时不该白烧电）
    for (var i = 0; i < 8; i++) {
      await tester.pump(_interval);
    }
    expect(visibleText(tester), '',
        reason: 'TickerMode 关闭时不该打字');

    // 打开：开始打
    await tester.tap(find.text('toggle'));
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(_interval);
    }
    expect(visibleText(tester), 'abcdef');
    expect(done, 1);
  });

  test('节奏按长度自适应：短答案慢、长答案快（直接查实现，不靠计时）', () {
    // ⚠️ 不要用"打一个字素花了几毫秒"来测：`Timer.periodic` 对非整数时长会
    // 取整到毫秒网格，两边量出来都是 20ms，反而看不出自适应。
    final short = TypewriterText.intervalFor(text: '短答案');
    final mid = TypewriterText.intervalFor(text: '中' * 120);
    final long = TypewriterText.intervalFor(text: '长' * 260);

    expect(short, const Duration(milliseconds: 45));
    expect(long, const Duration(milliseconds: 12));
    expect(mid.inMilliseconds, lessThan(short.inMilliseconds));
    expect(mid.inMilliseconds, greaterThan(long.inMilliseconds));

    // 显式传 interval 时不受长度影响
    expect(
      TypewriterText.intervalFor(
          text: '长' * 260, interval: const Duration(milliseconds: 33)),
      const Duration(milliseconds: 33),
    );
  });

  testWidgets('onProgress 每打一个字素都回调', (tester) async {
    var progress = 0;
    await pumpTypewriter(
      tester,
      text: 'abcd',
      onCompleted: () {},
      onProgress: () => progress++,
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(_interval);
    }
    expect(progress, 4, reason: '4 个字素 → 4 次进度回调');
  });
}
