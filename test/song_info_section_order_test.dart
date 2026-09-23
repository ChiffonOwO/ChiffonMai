// 「成绩趋势」板块的位置回归测试。
//
// 要求：成绩趋势（`ChartHistorySection`，达成率 / DX 分曲线）必须
//   * **不嵌在**「玩家最佳成绩」卡片内部；
//   * 作为**独立板块排在它的下方**。
//
// 以前它是「玩家最佳成绩」Container 里的一段，看起来像成绩卡的一部分，
// 但它其实是"这张谱面的历史"，粒度是谱面而不是这一次成绩。
//
// SongInfoPage 会联网、读缓存、拉一堆数据，widget 测试里跑不动；
// 所以这里用**结构断言**钉住：把 build 方法里两个锚点之间的源码抽出来看包含关系。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_first_flutter_app/service/History/ChartHistoryCore.dart';
import 'package:my_first_flutter_app/service/History/ChartHistoryStore.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:my_first_flutter_app/widgets/ChartHistorySection.dart';

String _src() => File('lib/page/SongInfoPage.dart').readAsStringSync();

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

  /// 注入 loader：真实文件 I/O 在 widget 测试的 fake async 里永远不会完成。
  void seed(List<ChartHistoryEvent> events) {
    ChartHistoryStore.debugChartEventsLoader =
        (songId, levelIndex) async => events;
    ChartHistoryStore.debugChartBaselineLoader =
        (songId, levelIndex) async => null;
  }

  test('成绩趋势不再是「玩家最佳成绩」卡片内的子节点', () {
    final src = _src();
    final cardStart = src.indexOf("'玩家最佳成绩'");
    expect(cardStart, greaterThan(0));

    // 卡片标题之后、按钮行之前，不该再出现 ChartHistorySection 的构造
    final gridStart = src.indexOf('// 按钮行（跳转到B站', cardStart);
    expect(gridStart, greaterThan(cardStart), reason: '找不到按钮行锚点');
    final insideCard = src.substring(cardStart, gridStart);
    expect(insideCard.contains('ChartHistorySection('), isFalse,
        reason: '成绩趋势还在「玩家最佳成绩」卡片里面');
  });

  test('成绩趋势卡片排在「玩家最佳成绩」下方', () {
    final src = _src();
    final cardTitle = src.indexOf("'玩家最佳成绩'");
    expect(cardTitle, greaterThan(0));
    // ⚠️ 要找的是**调用点**（build 里的 `_buildChartHistoryCard(),`），
    // 不是方法定义 `Widget _buildChartHistoryCard() {` —— 定义在类的前部，
    // 位置天然早于 build，用它比较会得到"排在前面"的错误结论。
    final callIdx = src.indexOf('_buildChartHistoryCard(),');
    final defIdx = src.indexOf('Widget _buildChartHistoryCard()');
    expect(defIdx, greaterThan(0), reason: '方法定义不见了');
    expect(callIdx, greaterThan(0), reason: '方法没有被调用');
    expect(callIdx, greaterThan(cardTitle),
        reason: '独立板块必须出现在「玩家最佳成绩」之后');
  });

  test('独立板块复用 ChartHistorySection，并给足卡片内边距', () {
    final src = _src();
    final idx = src.indexOf('Widget _buildChartHistoryCard()');
    expect(idx, greaterThan(0));
    final body = src.substring(idx, idx + 1300);
    expect(body.contains('ChartHistorySection('), isTrue);
    expect(body.contains('cardStyle: true'), isTrue,
        reason: '独立板块要有自己的卡片外观');
    expect(body.contains('emptyPadding: EdgeInsets.zero'), isTrue,
        reason: '没有历史时必须整块 0 高，不能凭空撑出一块空白');
    expect(body.contains('songId: songId'), isTrue);
    expect(body.contains('levelIndex: _currentDiffIndex'), isTrue);
    expect(body.contains('textPadding'), isTrue);
    expect(body.contains('chartPadding'), isTrue);
  });

  test('两张卡片之间有显式间隔（用户反馈原来贴在一起）', () {
    final src = _src();
    final call = src.indexOf('_buildChartHistoryCard(),');
    expect(call, greaterThan(0));
    // 调用点**前面**必须紧挨着一个 SizedBox —— 卡片之间原本没有任何间距 widget
    // （旧代码里那个 12dp 在「玩家最佳成绩」卡片内部、垫在标题行下面）。
    final before = src.substring(call - 120, call);
    expect(before.contains('SizedBox(height:'), isTrue,
        reason: '「成绩趋势」和上方成绩卡之间必须有显式间隔');
    // 而且这个间隔在函数体内不该被复制一份，避免双重留白
    // （先去掉行注释：函数注释里就写了 `SizedBox(height: 10)` 作说明）
    final idx = src.indexOf('Widget _buildChartHistoryCard()');
    final body = src
        .substring(idx, idx + 1300)
        .split('\n')
        .map((l) {
          final c = l.indexOf('//');
          return c < 0 ? l : l.substring(0, c);
        })
        .join('\n');
    expect(body.contains('SizedBox(height'), isFalse,
        reason: '曲线为空时整块高度 0，函数体外层不许垫固定高度');
  });

  test('「玩家最佳成绩」四行的行间距一致（各一个 8dp）', () {
    final src = _src();
    final cardStart = src.indexOf("'玩家最佳成绩'");
    final end = src.indexOf('// 成绩趋势：**独立于', cardStart);
    expect(cardStart, greaterThan(0));
    expect(end, greaterThan(cardStart), reason: '找不到卡片结束锚点');
    final card = src.substring(cardStart, end);

    // 按出现顺序定位四个值行（用值那一行的锚点，别用标签 —— 标签在
    // `Text('DX分数达成率: ')` 里和下面的值分开成两个 span）
    final rows = <String, int>{
      'Rating': card.indexOf("'Rating: "),
      '游玩次数': card.indexOf('游玩次数: '),
      'DX分数': card.indexOf("'DX分数: "),
      'DX分数达成率': card.indexOf("'DX分数达成率: "),
    };
    for (final e in rows.entries) {
      expect(e.value, greaterThan(0), reason: '找不到「${e.key}」这一行');
    }
    final ordered = rows.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    expect(ordered.map((e) => e.key).toList(),
        ['Rating', '游玩次数', 'DX分数', 'DX分数达成率'],
        reason: '四行的顺序变了，这个测试的假设要跟着改');

    // 每一行**正上方**都必须有一个 8dp 间隔。
    // 原来「DX分数」那一行前面什么都没有，所以它和上一行贴得特别近。
    for (final e in ordered) {
      final head = card.substring(0, e.value);
      final lastGap = head.lastIndexOf('SizedBox(height: 8)');
      final lastOther = head.lastIndexOf("'玩家最佳成绩'");
      expect(lastGap, greaterThan(0), reason: '「${e.key}」上方没有 8dp 间隔');
    }

    // 更严格：每行之上、到上一行之间，恰好只有一个 8dp 间隔
    // （多一个就是双重留白，0 个就是贴在一起）
    //
    // ⚠️ `card` 是子串，`rows` 里的偏移是**相对 card** 的；
    //    别再混进 `cardStart`（那是相对全文的），否则 substring 会越界。
    final orderedPoints = <String, int>{
      for (final e in ordered) e.key: e.value,
    };
    final keys = ['Rating', '游玩次数', 'DX分数', 'DX分数达成率'];
    for (var i = 1; i < keys.length; i++) {
      final seg = card.substring(orderedPoints[keys[i - 1]]!, orderedPoints[keys[i]]!);
      final gaps = RegExp(r'SizedBox\(height: 8\)').allMatches(seg).length;
      expect(gaps, 1,
          reason: '「${keys[i]}」上方到「${keys[i - 1]}」之间'
              '应当恰好 1 个 8dp 间隔，实得 $gaps 个');
    }
  });

  group('ChartHistorySection 的三种形态与内边距', () {
    Future<void> pump(
      WidgetTester tester, {
      required bool cardStyle,
      EdgeInsets emptyPadding = EdgeInsets.zero,
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ChartHistorySection(
              songId: 1,
              levelIndex: 0,
              cardStyle: cardStyle,
              emptyPadding: emptyPadding,
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('cardStyle=true 且无历史时：依然是 0 高、无卡片底色',
        (tester) async {
      await pump(tester, cardStyle: true);
      expect(tester.getSize(find.byType(ChartHistorySection)).height, 0,
          reason: '卡片外壳不能把空形态撑出高度');
      // 该形态连 DecoratedBox 都不会建（直接 SizedBox.shrink）
      expect(
        find.descendant(
          of: find.byType(ChartHistorySection),
          matching: find.byType(DecoratedBox),
        ),
        findsNothing,
      );
    });

    testWidgets('cardStyle 是纯外观参数：不改变空形态的高度口径', (tester) async {
      await pump(tester, cardStyle: false);
      expect(tester.getSize(find.byType(ChartHistorySection)).height, 0);
    });

    testWidgets('有曲线时：卡片内边距真的生效（曲线不贴边）', (tester) async {
      seed([
        ev(DateTime(2026, 9, 1), 99.5, 2800),
        ev(DateTime(2026, 9, 10), 100.1, 2950),
        ev(DateTime(2026, 9, 18), 100.5, 3000),
      ]);
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ChartHistorySection(
              songId: 11312,
              levelIndex: 3,
              maxDxScore: 3375,
              cardStyle: true,
              emptyPadding: EdgeInsets.zero,
              textPadding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              chartPadding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final section = tester.getRect(find.byType(ChartHistorySection));
      final title = tester.getRect(find.textContaining('成绩历史（3 次变化）'));
      // 卡片内部：标题离卡片顶留出 chartPadding.top
      expect(title.top - section.top, greaterThanOrEqualTo(4),
          reason: '曲线不该贴着卡片上边缘');
      expect(title.left - section.left, greaterThanOrEqualTo(16));
    });
  });
}
