// 「定位到我的排名」滑过头的回归测试。
//
// 根因（实测确认）：三个排行榜页定位时都用的是**估算行高** ——
// `animateTo(index * 72)`（拟合榜写的是 84）。而真实行高 = 上下 padding 24 + 内容高，
// 内容高由字体度量决定：
//
//   * 测试环境实测（360×800 逻辑尺寸）：Rating 榜 65、拟合榜 67、平均榜 64；
//   * 估高比真值大 7~17dp，而误差**按行号累加**：第 40 名就偏出 280dp
//     （拟合榜 680dp）——表现就是点定位后画面滑过头，自己的那一行跑到屏幕上方，
//     看到的全是比自己低的名次。
//
// 修法：`ListView.prototypeItem` 把每一行都排成「原型行」（内容最全的那一行）的高度，
// `RankingRowExtent` 量出这个高度，于是 `index × 行高` 就是第 index 行的精确偏移。
//
// ⚠️ 这里用**真实页面 + 打桩的 service**、量几何，不靠读源码字符串 ——
// 这个 bug 只有量落点才看得出来（与 `ranking_list_top_gap_test.dart` 同一套路）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_first_flutter_app/page/RankingList/AvgScoreRankingListPage.dart';
import 'package:my_first_flutter_app/page/RankingList/FittedRatingRankingListPage.dart';
import 'package:my_first_flutter_app/page/RankingList/RatingRankListPage.dart';
import 'package:my_first_flutter_app/service/RankingList/AvgRankingListService.dart';
import 'package:my_first_flutter_app/service/RankingList/FittedRatingRankingListService.dart';
import 'package:my_first_flutter_app/service/RankingList/RatingRankListService.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:my_first_flutter_app/utils/RankingRowExtent.dart';
import 'package:my_first_flutter_app/widgets/CommunityAvatar.dart';

/// 榜单长度：要足够长，让「估算行高 × 行号」的误差累积到肉眼可见（几百 dp）。
const int kCount = 60;

/// 当前玩家在第几行（0 基）。第 40 名：老代码在那里已经偏出 280dp 以上。
const int kMyIndex = 40;

const String kMyName = '玩家${kMyIndex + 1}';

/// 状态栏高度（dp）：列表首行上方那 24dp 就是从这来的。
const double kProbeStatusBar = 24;

String _userIdAt(int index) => 'shuiyu:${index + 1}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'last_data_source': 'shuiyu',
      'shuiyu_user_id': _userIdAt(kMyIndex),
    });
    RatingRankListService.debugRankingsLoader = () async => [
          for (var i = 0; i < kCount; i++)
            RankItem(
              rank: i + 1,
              userId: _userIdAt(i),
              dataSource: 'shuiyu',
              originalId: '${i + 1}',
              nickname: '玩家${i + 1}',
              avatarId: 73,
              totalRating: 17000 - i * 10,
              best35Rating: 12000 - i * 10,
              best15Rating: 5000 - i * 5,
            ),
        ];
    AvgRankingListService.debugRankingsLoader = () async => [
          for (var i = 0; i < kCount; i++)
            AvgRankItem(
              rank: i + 1,
              playerId: _userIdAt(i),
              playerName: '玩家${i + 1}',
              avatarId: 73,
              dataSource: 'shuiyu',
              avgAchievement: 101.5 - i * 0.01,
              avgDxAchievement: 99.5 - i * 0.01,
              achievementCount: 1100 - i,
              dxCount: 900 - i,
            ),
        ];
    FittedRatingRankingListService.debugRankingsLoader = () async => [
          for (var i = 0; i < kCount; i++)
            FittedRankItem(
              rank: i + 1,
              playerId: _userIdAt(i),
              playerName: '玩家${i + 1}',
              avatarId: 73,
              dataSource: 'shuiyu',
              mode: FittedMode.a.name,
              fittedRating: 17000 - i * 100,
              officialRating: 16800 - i * 100,
              diff: 200,
            ),
        ];
  });

  tearDown(() {
    RatingRankListService.debugRankingsLoader = null;
    AvgRankingListService.debugRankingsLoader = null;
    FittedRatingRankingListService.debugRankingsLoader = null;
  });

  /// 渲染页面并等到列表出来。
  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    tester.view.padding = const FakeViewPadding(top: kProbeStatusBar * 3);
    tester.view.viewPadding = const FakeViewPadding(top: kProbeStatusBar * 3);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme(),
      home: page,
    ));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // ⚠️ 测试环境的默认字体比真机思源黑体宽得多，每行右侧的 "B35: xxx  B15: xxx"
    // 会横向溢出（既有现象、与本次改动无关）。它会以异常形式挂在 tester 上
    // 让断言失败，所以显式清掉。
    Object? ex;
    while ((ex = tester.takeException()) != null) {
      debugPrint('[渲染异常-已忽略] ${ex.toString().split('\n').first}');
    }
  }

  /// 列表里某一行的最外层 Container（带下边框的那个）。
  Finder rowFinder(String name) => find.descendant(
        of: find.byType(ListView),
        matching: find.text(name),
      );

  Rect rowRect(WidgetTester tester, String name) => tester.getRect(
        find.ancestor(of: rowFinder(name), matching: find.byType(Container)).last,
      );

  /// 点右上角的定位按钮并等动画走完。
  Future<void> tapLocate(WidgetTester tester) async {
    final locate = find.byTooltip('跳转到我的排名');
    expect(locate, findsOneWidget, reason: '当前玩家在榜上时应显示定位按钮');
    await tester.tap(locate);
    await tester.pumpAndSettle();
    Object? ex;
    while ((ex = tester.takeException()) != null) {
      debugPrint('[渲染异常-已忽略] ${ex.toString().split('\n').first}');
    }
  }

  /// 把当前玩家的那一行滚进视野后，断言它**正好贴住列表顶部**（误差 < 0.5dp）。
  ///
  /// 老代码：第 40 行的落点是 40 × 72 = 2880（拟合榜 3360），而精确值是
  /// 40 × 真实行高 —— 目标行被顶到列表上方（相对列表顶 -280 / -680），这条断言必挂。
  Future<void> expectLocatedAtTop(WidgetTester tester) async {
    await tapLocate(tester);

    expect(rowFinder(kMyName), findsOneWidget,
        reason: '定位后当前玩家的行必须在列表里可见（而不是被滚过头顶）');
    final identity = find.ancestor(
      of: rowFinder(kMyName),
      matching: find.byType(CommunityPlayerIdentity),
    );
    final avatar = find.descendant(
      of: identity,
      matching: find.byType(CommunityAvatar),
    );
    expect(avatar, findsOneWidget, reason: '实际排行榜行必须显示玩家头像');
    expect(tester.widget<CommunityAvatar>(avatar).avatarId, 73,
        reason: '头像必须使用该行玩家的服务端选择');
    final listRect = tester.getRect(find.byType(ListView));
    final target = rowRect(tester, kMyName);
    expect(target.top - listRect.top, closeTo(0, 0.5),
        reason: '落点必须是 `index × 实测行高`，不能再用估算行高');
    expect(target.bottom, lessThanOrEqualTo(listRect.bottom + 0.5),
        reason: '整行都要在视野内');
  }

  testWidgets('Rating 排行榜：定位落在当前玩家行上（贴住列表顶部）', (tester) async {
    await pumpPage(tester, const RatingRankListPage());
    await expectLocatedAtTop(tester);
  });

  testWidgets('拟合总 Rating 排行榜：定位落在当前玩家行上', (tester) async {
    await pumpPage(tester, const FittedRatingRankingListPage());
    await expectLocatedAtTop(tester);
  });

  testWidgets('平均达成率排行榜：定位落在当前玩家行上', (tester) async {
    await pumpPage(
        tester,
        const AvgScoreRankingListPage(
            initialMetric: AvgMetric.achievement));
    await expectLocatedAtTop(tester);
  });

  testWidgets('平均 DX 达成率排行榜：定位落在当前玩家行上', (tester) async {
    await pumpPage(
        tester, const AvgScoreRankingListPage(initialMetric: AvgMetric.dx));
    await expectLocatedAtTop(tester);
  });

  testWidgets('行高不齐的榜单也要精确落位（有的行没有 B35/B15 两行小字）',
      (tester) async {
    // 前面 20 行没有 B35/B15：自然高度会比别的行矮，
    // 靠 `index × 估算行高` 一定错位；`prototypeItem` 把每行都排成同一高度才算得准。
    RatingRankListService.debugRankingsLoader = () async => [
          for (var i = 0; i < kCount; i++)
            RankItem(
              rank: i + 1,
              userId: _userIdAt(i),
              dataSource: 'shuiyu',
              originalId: '${i + 1}',
              nickname: '玩家${i + 1}',
              avatarId: 73,
              totalRating: i < 20 ? 0 : 17000 - i * 10,
              best35Rating: i < 20 ? 0 : 12000 - i * 10,
              best15Rating: i < 20 ? 0 : 5000 - i * 5,
            ),
        ];

    await pumpPage(tester, const RatingRankListPage());
    await expectLocatedAtTop(tester);
  });

  testWidgets('名次靠后时滚不到顶也要保证整行可见（夹到可滚范围）', (tester) async {
    // 当前玩家是最后一名：`index × 行高` 超过 maxScrollExtent，夹住后行贴在底部。
    SharedPreferences.setMockInitialValues({
      'last_data_source': 'shuiyu',
      'shuiyu_user_id': _userIdAt(kCount - 1),
    });
    await pumpPage(tester, const RatingRankListPage());
    await tapLocate(tester);

    final listRect = tester.getRect(find.byType(ListView));
    final target = rowRect(tester, '玩家$kCount');
    expect(target.top, greaterThanOrEqualTo(listRect.top - 0.5));
    expect(target.bottom, lessThanOrEqualTo(listRect.bottom + 0.5));
  });

  testWidgets('行高还没实测出来时宁可不动，也不拿估算值乱滚', (tester) async {
    final extent = RankingRowExtent();
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView.builder(
          controller: controller,
          itemCount: 100,
          itemBuilder: (_, i) => SizedBox(height: 50, child: Text('行$i')),
        ),
      ),
    ));

    expect(extent.rowHeight, isNull);
    await extent.scrollRowToTop(controller, 50);
    expect(controller.offset, 0, reason: '量不到行高就不该滚动');
  });
}
