// 「国服更新对照」页的渲染测试。
//
// 口径本身由 `test/union_update_compare_test.dart` 钉住，这里只验三件事：
//   * 没有曲库缓存时给的是**可操作的引导**（去刷新数据），而不是空白页；
//   * 有三段（候选 / 未收录旧曲 / 宴会场）且能切换，计数与列表对得上；
//   * 口径说明弹窗能开能关（这条判据不是官方数据，必须能查到说明）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_flutter_app/entity/DivingFish/Song.dart';
import 'package:my_first_flutter_app/page/UnionUpdateComparePage.dart';
import 'package:my_first_flutter_app/utils/StringUtil.dart';

Song song(
  String id, {
  required String title,
  String version = 'maimai でらっくす CiRCLE PLUS',
  String releaseDate = '20260220',
  bool isExtra = false,
}) =>
    Song(
      id: id,
      title: title,
      type: 'DX',
      ds: const [13.0],
      level: const ['13'],
      cids: const [1],
      charts: const [],
      basicInfo: BasicInfo(
        title: title,
        artist: 'artist',
        genre: 'ゲーム&バラエティ',
        bpm: 180,
        releaseDate: releaseDate,
        from: version,
        isNew: false,
      ),
      isExtra: isExtra,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pump(WidgetTester tester, List<Song>? songs) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: UnionUpdateComparePage(songsLoader: () async => songs),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  List<Song> sample() => [
        song('11000', title: '国服旧曲'),
        song('11878', title: 'Pixel Galaxy'),
        // 国服超前上线：国服已有、id 却最新 → 不能当前沿
        song('11919', title: '超前上线曲A', version: 'maimai でらくす PRiSM'),
        song('11944', title: '超前上线曲', version: 'maimai でらくす PRiSM'),
        // union 独有：比前沿大 → 待上线
        song('11879', title: '待上线A', isExtra: true),
        song('11947', title: '待上线B', isExtra: true),
        song('11948', title: '待上线C', isExtra: true),
        // union 独有但 id 更小 → 国服未收录的旧曲
        song('10000', title: '旧独占曲', isExtra: true),
        // union 独有的宴会场（6 位 id）
        song('100123', title: '宴会曲', isExtra: true),
      ];

  testWidgets('曲库没缓存：给出去刷新的引导而不是空白页', (tester) async {
    await pump(tester, null);

    expect(find.text('曲库还没有缓存'), findsOneWidget);
    expect(find.textContaining('刷新数据'), findsOneWidget);
    expect(find.text('国服（水鱼）更新前沿'), findsNothing);
  });

  testWidgets('前沿卡片与三段计数都来自同一份曲库', (tester) async {
    await pump(tester, sample());

    expect(find.textContaining('#11878'), findsOneWidget);
    expect(find.textContaining('Pixel Galaxy'), findsOneWidget);
    expect(find.textContaining('日服首发 2026-02-20'), findsOneWidget);

    // 计数：union 全量 9 / 国服已上 4 / 待上线 3 / 未收录 1
    // ⚠️ 不能直接 find.text('3')：歌曲行前面的序号也是 "2"/"3"，
    // 所以断言成「值必须和标签同处一个格子」。
    void expectCountCell(String label, String value) {
      final cell = find
          .ancestor(of: find.text(label), matching: find.byType(Column))
          .first;
      expect(
        find.descendant(of: cell, matching: find.text(value)),
        findsOneWidget,
        reason: '「$label」这一格应该显示 $value',
      );
    }

    expectCountCell('union 全量', '9');
    expectCountCell('国服已上', '4');
    expectCountCell('待上线', '3');
    expectCountCell('未收录', '1');
    expect(find.text('下次更新候选 3'), findsOneWidget);
    expect(find.text('国服未收录旧曲 1'), findsOneWidget);
    expect(find.text('宴会场 1'), findsOneWidget);
    expect(find.text('国服超前上线 2'), findsOneWidget);

    // 默认停在候选段，按 id 升序
    expect(find.text('待上线A'), findsOneWidget);
    expect(find.text('待上线B'), findsOneWidget);
    expect(find.text('旧独占曲'), findsNothing);
    expect(find.text('宴会曲'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('超前上线的曲目被排除在前沿之外，并在卡片上写明', (tester) async {
    await pump(tester, sample());

    // 前沿那行是 11878；超前上线曲只能在"被排除"的说明里出现
    expect(find.text('#11878  Pixel Galaxy'), findsOneWidget,
        reason: '前沿必须落在超前上线曲下面那首');
    expect(find.textContaining('已排除 2 首国服超前上线曲目'), findsOneWidget);
    expect(find.textContaining('#11944'), findsWidgets,
        reason: '卡片上要列出被排除的 id，用户才知道前沿为什么在这儿');

    await tester.tap(find.text('国服超前上线 2'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('超前上线曲'), findsOneWidget);
    expect(find.textContaining('国服先于日服'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('切到「国服未收录旧曲」与「宴会场」能看到各自那几首', (tester) async {
    await pump(tester, sample());

    await tester.tap(find.text('国服未收录旧曲 1'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('旧独占曲'), findsOneWidget);
    expect(find.text('待上线A'), findsNothing);
    expect(find.textContaining('区域限定'), findsOneWidget,
        reason: '这段的成因不确定，要如实说明');

    await tester.tap(find.text('宴会场 1'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('宴会曲'), findsOneWidget);
    expect(find.text('旧独占曲'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('「国服常规曲」段第一行就是被标注的前沿', (tester) async {
    await pump(tester, sample());

    await tester.tap(find.text('国服常规曲 2'));
    await tester.pump(const Duration(milliseconds: 50));

    // 降序：Pixel Galaxy(11878) 在前，国服旧曲(11000) 在后
    expect(find.text('Pixel Galaxy'), findsWidgets);
    expect(find.text('国服旧曲'), findsOneWidget);
    expect(find.byIcon(Icons.flag_rounded), findsWidgets,
        reason: '前沿那一行要有旗标标注');
    expect(tester.takeException(), isNull);
  });

  testWidgets('union 独有曲的版本显示与曲目详情页同口径', (tester) async {
    // 踩过的坑：union 独有曲的 from 是**日服写法**（`maimai でらっくす PRiSM PLUS`），
    // 用 `StringUtil.formatVersion`（不带 extra 标记）会一路查不到、落到官方世代
    // 年号那一档，于是同一个 id 在对照页显示「DX 2026彩」、详情页显示「PRiSM+ 彩」。
    const unionFrom = 'maimai でらっくす PRiSM PLUS';
    await pump(tester, [
      song('11878', title: 'Pixel Galaxy'),
      song('11879', title: '待上线曲', isExtra: true, version: unionFrom),
    ]);

    // 详情页用的就是这个函数（SongInfoPage：formatVersion2WithFlag(from, isExtra)）
    final expected = StringUtil.formatVersion2WithFlag(unionFrom, true);
    expect(expected, isNot(contains('DX 20')),
        reason: '年号名（DX 2026彩）是 extra=false 专属，不该出现在 union 独有曲上');

    expect(find.text('#11879 · $expected · 日服 2026-02-20'), findsOneWidget,
        reason: '对照页的版本串必须和详情页完全一致');
    expect(tester.takeException(), isNull);
  });

  testWidgets('11815~11821 直接显示在候选段里，不带任何额外标记', (tester) async {
    await pump(tester, [
      song('11878', title: 'Pixel Galaxy'),
      // 在名单里、id 比前沿小 → 仍要出现在候选段
      song('11815', title: 'IMBRUED:FLUX', isExtra: true),
      // 不在名单里、id 更小 → 留在"未收录旧曲"
      song('11000', title: '真区域限定', isExtra: true),
    ]);

    // 默认就是候选段：正常一行，没有任何额外标签
    expect(find.text('IMBRUED:FLUX'), findsOneWidget);
    expect(find.text('已确认'), findsNothing);
    expect(find.textContaining('人工确认'), findsNothing);
    expect(find.text('真区域限定'), findsNothing);

    // 未收录那段不受影响
    await tester.tap(find.text('国服未收录旧曲 1'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('真区域限定'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('口径说明弹窗能开能关', (tester) async {
    await pump(tester, sample());

    await tester.tap(find.byTooltip('口径说明'));
    await tester.pumpAndSettle();
    expect(find.text('这个页面的口径'), findsOneWidget);
    // 页面正文里也有同一句，断言必须限定在弹窗内
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('不是国服上线时间'),
      ),
      findsOneWidget,
      reason: '"首次上线是日服时间"是本页存在的理由，必须写在说明里',
    );

    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();
    expect(find.text('这个页面的口径'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
