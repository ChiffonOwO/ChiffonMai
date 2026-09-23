// 回归测试：B50 卡片达成率的「大整数 + 小小数」两段必须**画在同一个段落里**，
// 且真渲染出来的字形墨迹底边齐平（≤1 物理像素）。
//
// ## 背景（踩过的坑）
//
// 曾经用「两句 `Text` + `Row(crossAxisAlignment: baseline)`」拼这两段。布局上两段基线
// 是精确重合的，但两句 `Text` 是两个 `RenderParagraph`，**各自光栅化、各自吸附像素格**，
// 两个字形游程落到不同相位，墨迹底就会差 0~3 物理像素；差多少只看字号恰好落在哪一格：
// 真字体（Google Fonts 的 Noto Sans SC Bold，dpr 3.0）实测 `101.0000%`
//
//   * 主/次字号 18.09 / 13.56（即 `cardW=(W−0.01W)/2` 的 Best50 / 拟合 Best50）→ 0，"看起来齐"；
//   * 17.90 / 13.43（另外 4 个页面的口径）→ −2，"小数肉眼可见偏高"。
//
// 于是"同一套卡片模板，只有部分 Best50 页面是齐的"——根源就在这里，与页面无关。
//
// 修法：`B50GameCardWidget._buildAchievement` 改成一个 `Text.rich`（两段字号做成同一
// 段落的两个 span）。一个段落只有一个基线、只做一次排版，本测试就是对它的回归：
// 真字体 + 卡片真实尺寸 + 真渲染（toImage 后逐列扫墨迹），与真机同口径。
//
// ⚠️ 别把 `_buildAchievement` 改回两句 `Text`（本测试的"必须在同一段落"断言会先炸）。
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_flutter_app/widgets/B50GameCardWidget.dart';

import 'support/real_fonts.dart';

/// google_fonts 的族名（按字重分文件），真机上是 Noto Sans SC Bold。
const String _font = 'NotoSansSC_700';

/// 卡片**真实可见宽度**的两种历史口径：Best50 / 拟合 Best50 当时算成 0.01，
/// 其余 4 个页面算成 0.02。现在字号由卡片**自己**按实际宽度算（`autoScale`），
/// 这里就把这两种宽度当成待测格子宽度 —— 两者都必须齐。
const List<double> _cellFactors = [0.01, 0.02];

const List<double> _screenWidths = [360.0, 393.0, 411.0, 430.0];
const List<double> _dprs = [2.75, 3.0];

/// 亚像素相位：卡片在像素格里落在哪儿，也要扫到（历史 bug 就是这样翻来覆去的）。
const List<double> _phases = [0.0, 0.25, 0.5];

/// 屏幕口径的字号基准宽度（`autoScale` 用的就是它）。
///
/// **不是** `B50GameCardWidget.refCardWidth` = 335（导出基准）：屏幕口径比它
/// 大 8.8%（≈308），统一口径时留下的「估宽水分」就是从这里还回来的。
const double _screenRefCardWidth = B50GameCardWidget.screenRefCardWidth;

TextStyle _intStyle(double scale) => TextStyle(
      fontSize: 34.0 * scale,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    );

TextStyle _decStyle(double scale) => TextStyle(
      fontSize: 25.5 * scale,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    );

class _Ink {
  final int top, bottom;
  const _Ink(this.top, this.bottom);
}

/// 在 [x0, x1) × [y0, y1) 里扫白字墨迹的上下边界（卡片画在纯黑底上）。
_Ink? _scanInk(ui.Image img, ByteData data, int x0, int x1, int y0, int y1) {
  final bpr = data.lengthInBytes ~/ img.height;
  bool lit(int x, int y) {
    final o = y * bpr + x * 4;
    return data.getUint8(o) > 150 &&
        data.getUint8(o + 1) > 150 &&
        data.getUint8(o + 2) > 150 &&
        data.getUint8(o + 3) > 30;
  }

  int? top, bottom;
  for (int y = y0; y < y1 && y < img.height; y++) {
    for (int x = x0; x < x1 && x < img.width; x++) {
      if (lit(x, y)) {
        top ??= y;
        bottom = y;
        break;
      }
    }
  }
  return (top == null || bottom == null) ? null : _Ink(top, bottom);
}

void main() {
  testWidgets('B50 卡片达成率：两段同段排版，字形墨迹底边齐平', (tester) async {
    await tester.runAsync(loadRealFonts);

    final failures = <String>[];
    var checked = 0;

    for (final dpr in _dprs) {
      for (final screenW in _screenWidths) {
        for (final factor in _cellFactors) {
          for (final phase in _phases) {
            tester.view.devicePixelRatio = dpr;
            tester.view.physicalSize = Size(screenW * dpr, 600 * dpr);
            addTearDown(tester.view.reset);

            // 卡片放进这个宽度的盒子里；`autoScale` 算出的就是
            // 「盒子宽 / screenRefCardWidth」。
            final cellW = (screenW - screenW * factor) / 2;
            final cardH = cellW / B50GameCardWidget.designAspectRatio;
            final scale = cellW / _screenRefCardWidth;

            final key = GlobalKey();
            await tester.pumpWidget(MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(fontFamily: _font),
              home: Scaffold(
                backgroundColor: Colors.black,
                body: RepaintBoundary(
                  key: key,
                  child: Padding(
                    // phase 用来挪动整卡在像素格里的亚像素相位
                    padding: EdgeInsets.only(left: 3.3, top: 12 + phase),
                    child: SizedBox(
                      width: cellW,
                      height: cardH,
                      child: B50GameCardWidget(
                        cardColor: Colors.black,
                        songName: '',
                        achievementRate: 101.0,
                        difficulty: 13.4,
                        dxMode: true,
                        isUtage: false,
                        score: 2098,
                        maxScore: 2277,
                        rating: 301,
                        stars: '',
                        fc: '',
                        fs: '',
                        rate: '',
                        songId: 0,
                        starsColor: Colors.black,
                        maxIdLength: 5,
            // 让卡片自己算：字号 = 卡片实际宽度 / 335
            scale: B50GameCardWidget.autoScale,
                      ),
                    ),
                  ),
                ),
              ),
            ));
            await tester.pumpAndSettle();

            final tag = 'W=$screenW dpr=$dpr factor=$factor phase=$phase';

            // ---- 结构：达成率必须是**一个段落**（两句 Text 的时代已过去）----
            final paras = <RenderParagraph>[];
            void walk(RenderObject o) {
              if (o is RenderParagraph) paras.add(o);
              o.visitChildren(walk);
            }

            walk(tester.renderObject(find.byType(B50GameCardWidget)));
            final matches = paras.where((p) {
              final t = p.text.toPlainText();
              return t.startsWith('101.') ||
                  t == '101' ||
                  t.startsWith('.0000%');
            }).toList();
            if (matches.length != 1) {
              failures.add('$tag: 达成率应该正好是 1 个段落，实为 ${matches.length} 个'
                  '（两句 Text 的写法会拆成 2 个）');
              continue;
            }
            final rp = matches.single;
            final leaves = <TextSpan>[];
            void collect(InlineSpan span) {
              if (span is TextSpan) {
                if (span.text != null) leaves.add(span);
                for (final c in span.children ?? const <InlineSpan>[]) {
                  collect(c);
                }
              }
            }

            collect(rp.text);
            if (leaves.length != 2) {
              failures.add('$tag: 达成率段落里应有 2 个 span，实为 ${leaves.length}');
              continue;
            }
            if (leaves[0].text != '101' || leaves[1].text != '.0000%') {
              failures.add('$tag: 两段文本不对（${leaves[0].text} / ${leaves[1].text}）');
              continue;
            }
            // 同时验证 autoScale 的口径：字号恰好是
            // 「盒子宽度 / screenRefCardWidth」× 34 / 25.5。
            final intSize = leaves[0].style!.fontSize!;
            final decSize = leaves[1].style!.fontSize!;
            // 字号须正好是 34 / 25.5 ×（卡片自己的宽度 / screenRefCardWidth）
            if ((intSize - _intStyle(scale).fontSize!).abs() > 1e-6 ||
                (decSize - _decStyle(scale).fontSize!).abs() > 1e-6) {
              failures.add('$tag: 两段字号不是 34/25.5 × scale'
                  '（实为 $intSize / $decSize）');
              continue;
            }

            // ---- 墨迹：两段字形底边之差 ≤ 1 物理像素 ----
            final intBoxes = rp.getBoxesForSelection(
                const TextSelection(baseOffset: 0, extentOffset: 3),
                boxHeightStyle: ui.BoxHeightStyle.tight);
            final decBoxes = rp.getBoxesForSelection(
                TextSelection(baseOffset: 3, extentOffset: 11),
                boxHeightStyle: ui.BoxHeightStyle.tight);
            if (intBoxes.length != 1 || decBoxes.length != 1) {
              failures.add('$tag: 取字形区间失败'
                  '（int=${intBoxes.length}, dec=${decBoxes.length}）');
              continue;
            }

            final cardRO =
                key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
            final cardOrigin = cardRO.localToGlobal(Offset.zero);

            Rect px(TextBox box) {
              final a = rp.localToGlobal(box.toRect().topLeft) - cardOrigin;
              final b = rp.localToGlobal(box.toRect().bottomRight) - cardOrigin;
              return Rect.fromLTRB(a.dx * dpr, a.dy * dpr, b.dx * dpr, b.dy * dpr);
            }

            final iR = px(intBoxes.single);
            final dR = px(decBoxes.single);
            final img = await tester.runAsync(
                () async => await cardRO.toImage(pixelRatio: dpr));
            final data =
                await tester.runAsync(() async => await img!.toByteData());

            int x0(Rect r) => r.left.round() + 1;
            int x1(Rect r) => r.right.round() - 1;
            final int y0 = (iR.top - 24).round();
            final y1 = (iR.bottom + 24).round();

            final intInk = _scanInk(img!, data!, x0(iR), x1(iR), y0, y1);
            final decInk = _scanInk(img, data, x0(dR), x1(dR), y0, y1);
            img.dispose();
            checked++;

            if (intInk == null || decInk == null) {
              failures.add('$tag: 没扫到墨迹（int=$intInk, dec=$decInk）');
              continue;
            }
            final gap = decInk.bottom - intInk.bottom;
            if (gap.abs() > 1) {
              failures.add('$tag: 两段墨迹底差 $gap 物理像素'
                  '（小数${gap > 0 ? "偏低" : "偏高"}，scale=${scale.toStringAsFixed(4)}）');
            }
          }
        }
      }
    }

    expect(failures, isEmpty,
        reason: '达成率两段的底边没对齐（共 ${failures.length} 例）：\n'
            '${failures.join("\n")}');
    expect(checked, 2 * 4 * 2 * 3, reason: '用例数不对，说明有分支提前 continue 了');
  });
}
