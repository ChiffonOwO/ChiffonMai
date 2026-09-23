// 回归：B50 卡片的字号/曲绘必须跟着**卡片自己的可见宽度**走，且内容不出界。
//
// ## 背景（口径统一）
//
// 6 个 Best50 页面 + 单曲成绩搜索原来各自手算：
//
//     final cardW = (screenW - screenW * 0.01) / 2;   // 或 0.02
//     final scale = cardW / 335;
//
// 但 `screenW` 是**屏幕**宽，而卡片真实可见宽度还要扣掉容器 padding
// （`0.03 * screenW` 那种）、列表 margin、网格列间距。360 屏的 Best50 页：
// 真实格子 ≈ 163.4，估算 178.2 —— 字号整整偏大 9%。
//
// 现在统一成 `scale: B50GameCardWidget.autoScale`（默认值）：卡片根部的
// `LayoutBuilder` 直接取渲染宽度（网格给卡片的是**紧约束**，`maxWidth` 就是
// 卡片的可见宽度）→ `scale = 可见宽度 / screenRefCardWidth`（≈308；**不是**
// 导出基准 335：屏幕口径故意大 8.8%，把上面那 9% 的「估宽水分」还回来，
// 否则卡片内容会比统一前小一圈）。本测试锁定四件事：
//
//   1. autoScale 取值就是「卡片实际宽度 / screenRefCardWidth」（口径本身）；
//   2. 卡片铺满格子（尺寸 == 格子）；
//   3. 上半区（7:3 里的 7）装得下「曲绘 + 上下内边距」——注意：字号偏大时曲绘
//      不会 overflow，而是**被 Row 的约束夹住压扁**（静默变形），所以这条要按数算；
//   4. 任何后代 RenderBox 都没画到卡片外面（能抓到 RenderFlex overflow）。
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_flutter_app/widgets/B50GameCardWidget.dart';

import 'support/real_fonts.dart';

/// 真机字体（google_fonts 的族名，按字重分文件）。
const String _font = 'NotoSansSC_700';

/// 设计稿常量，与 widget 里的 `_kCover` / `_kSpacing` / `_kSmallSpacing` 同源。
/// 谁改了那几个常量，这条断言就会先炸。
const double _kCover = 100.0;
const double _kSpacing = 10.2;
const double _kSmallSpacing = 5.1;

/// 待测的"卡片可见宽度"：覆盖 320~480 屏、2 列网格里卡片真正拿到的宽度
/// （= `(屏宽 - 容器 padding - 边距 - 列间距) / 2`，360 屏 ≈ 163.4）。
const List<double> _cellWidths = [
  145.0,
  163.4,
  176.7,
  188.3,
  200.0,
  235.0,
  335.0,
];

const List<double> _dprs = [2.75, 3.0];

Widget _card() => const B50GameCardWidget(
      cardColor: Color(0xFF9966CC),
      songName: '测试曲目',
      achievementRate: 101.0,
      difficulty: 13.4,
      dxMode: true,
      isUtage: false,
      score: 2098,
      maxScore: 2277,
      rating: 301,
      stars: '✦5',
      fc: '',
      fs: '',
      rate: '',
      songId: 0,
      starsColor: Colors.yellow,
      maxIdLength: 5,
      // 默认值就是 autoScale，这里显式写出来表明"页面口径"。
      scale: B50GameCardWidget.autoScale,
    );

/// 取卡片里"达成率"那个段落（`Text.rich`）。
RenderParagraph? _achievementParagraph(RenderObject root) {
  RenderParagraph? found;
  void walk(RenderObject o) {
    if (o is RenderParagraph && o.text.toPlainText().startsWith('101')) {
      found = o;
    }
    o.visitChildren(walk);
  }

  walk(root);
  return found;
}

List<TextSpan> _leafSpans(InlineSpan span) {
  final out = <TextSpan>[];
  void collect(InlineSpan s) {
    if (s is TextSpan) {
      if (s.text != null) out.add(s);
      for (final c in s.children ?? const <InlineSpan>[]) {
        collect(c);
      }
    }
  }

  collect(span);
  return out;
}

void main() {
  testWidgets('字号跟实际宽度走，且内容不出界', (tester) async {
    await tester.runAsync(loadRealFonts);

    final failures = <String>[];
    var checked = 0;

    for (final dpr in _dprs) {
      for (final cellW in _cellWidths) {
        tester.view.devicePixelRatio = dpr;
        tester.view.physicalSize = Size(cellW * 3 * dpr, 900 * dpr);
        addTearDown(tester.view.reset);

        final cellH = cellW / B50GameCardWidget.designAspectRatio;
        final expectedScale = cellW / B50GameCardWidget.screenRefCardWidth;

        await tester.pumpWidget(MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: _font),
          home: Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: SizedBox(width: cellW, height: cellH, child: _card()),
            ),
          ),
        ));
        await tester.pumpAndSettle();

        final tag = 'cellW=$cellW dpr=$dpr';
        final exception = tester.takeException();
        if (exception != null) {
          failures.add('$tag: 渲染就报错 → $exception');
          continue;
        }

        final cardFinder = find.byType(B50GameCardWidget);
        final size = tester.getSize(cardFinder);
        if ((size.width - cellW).abs() > 0.01 ||
            (size.height - cellH).abs() > 0.01) {
          failures.add('$tag: 卡片没铺满格子（$size）');
          continue;
        }

        checked++;

        // ---- 1. autoScale == 实际宽度 / screenRefCardWidth（从达成率段落字号反推）----
        final cardRO = tester.renderObject(cardFinder) as RenderBox;
        final rp = _achievementParagraph(cardRO);
        if (rp == null) {
          failures.add('$tag: 没找到达成率段落');
          continue;
        }
        final leaves = _leafSpans(rp.text);
        if (leaves.length != 2 || leaves.first.style?.fontSize == null) {
          failures.add('$tag: 达成率段落的 span 不对（${leaves.length} 个）');
          continue;
        }
        final intFont = leaves.first.style!.fontSize!;
        final wantFont = 34.0 * expectedScale;
        if ((intFont - wantFont).abs() > 0.01) {
          failures.add('$tag: 字号 $intFont ≠ 卡片宽度 / screenRefCardWidth × 34'
              ' = $wantFont');
        }

        // ---- 2. 上半区装得下曲绘 + 上下内边距（外框 2px 双边先扣掉）----
        final topRegion = 0.7 * (cellH - 4.0);
        final needs =
            (_kCover + _kSpacing + _kSmallSpacing * 0.5) * expectedScale;
        if (needs > topRegion + 0.5) {
          failures.add('$tag: 上半区装不下（需要 ${needs.toStringAsFixed(1)}，'
              '可用 ${topRegion.toStringAsFixed(1)}）');
        }

        // ---- 3. 后代一律不许画到卡片外（overflow / 越界都会露出来）----
        final cardRect = Offset.zero & cardRO.size;
        final limit = cardRect.inflate(0.5);
        void checkBounds(RenderObject o) {
          o.visitChildren((child) {
            if (child is RenderBox && child.hasSize) {
              final r = MatrixUtils.transformRect(
                  child.getTransformTo(cardRO), child.paintBounds);
              if (!limit.contains(r.topLeft) || !limit.contains(r.bottomRight)) {
                failures.add('$tag: ${child.runtimeType} 画到卡片外'
                    '（$r ⊄ $cardRect）');
              }
            }
            checkBounds(child);
          });
        }

        checkBounds(cardRO);
      }
    }

    expect(failures, isEmpty,
        reason: '卡片口径/出界问题（共 ${failures.length} 例）：\n'
            '${failures.join("\n")}');
    expect(checked, 2 * 7, reason: '用例数不对，说明有分支提前 continue 了');
  });
}
