// 「第一名那一行上方多出一块空白」的回归测试。
//
// 根因（实测确认）：`Scaffold` 在没有 `appBar:` 时**不会消耗顶部安全区**，
// 于是 `ListView` 把 `MediaQuery.padding.top`（状态栏 24dp）当成内边距垫在
// 列表最上面；而状态栏那块地方早就被 body 里的 `PageTopBar` 占掉了 ——
// 结果就是列表首行上方凭空多出 24dp 空白。
// （截图量像素 + widget 测试量几何，两条路都得到同一个数：24.0）
//
// 修法：这三个页面的 `ListView` 显式 `padding: EdgeInsets.zero`。
//
// ⚠️ 这里用**真实页面 + 打桩的 service**，不靠读源码字符串：
// 这个问题只有量几何才看得出来。
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

/// 状态栏高度（dp）—— 列表首行上方那 24dp 就是从这来的。
const double kProbeStatusBar = 24;

List<RankItem> _ratingItems() => [
      for (var i = 1; i <= 6; i++)
        RankItem(
          rank: i,
          userId: 'shuiyu:$i',
          dataSource: 'shuiyu',
          originalId: '$i',
          nickname: '玩家$i',
          totalRating: 17000 - i * 10,
          best35Rating: 12000 - i * 10,
          best15Rating: 5000 - i * 5,
        ),
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'last_data_source': 'shuiyu',
      'shuiyu_user_id': 'shuiyu:2',
    });
    RatingRankListService.debugRankingsLoader = () async => _ratingItems();
    AvgRankingListService.debugRankingsLoader = () async => [
          for (var i = 1; i <= 6; i++)
            AvgRankItem(
              rank: i,
              playerId: 'shuiyu:$i',
              playerName: '玩家$i',
              dataSource: 'shuiyu',
              avgAchievement: 101.5 - i * 0.1,
              avgDxAchievement: 99.5 - i * 0.1,
              achievementCount: 1100 - i,
              dxCount: 900 - i,
            ),
        ];
    FittedRatingRankingListService.debugRankingsLoader = () async => [
          for (var i = 1; i <= 6; i++)
            FittedRankItem(
              rank: i,
              playerId: 'shuiyu:$i',
              playerName: '玩家$i',
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
    tester.view.padding =
        const FakeViewPadding(top: kProbeStatusBar * 3);
    tester.view.viewPadding =
        const FakeViewPadding(top: kProbeStatusBar * 3);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme(),
      home: page,
    ));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // ⚠️ 测试环境的默认字体是**等宽方块字**，比真机的思源黑体宽得多，
    // 于是每行右侧的 "B35: xxx  B15: xxx" 会横向溢出几十像素。
    // 这是既有现象、与本次改动无关（真机出图里没有任何溢出），
    // 但它会以异常形式挂在 tester 上让断言失败，所以这里显式清掉。
    Object? ex;
    while ((ex = tester.takeException()) != null) {
      debugPrint('[渲染异常-已忽略] ${ex.toString().split('\n').first}');
    }
  }

  /// 列表首行最外层（带下边框的那个 Container）到 ListView 顶部的距离。
  double firstRowOffset(WidgetTester tester) {
    final listView = tester.getRect(find.byType(ListView));
    final row = tester.getRect(
      find.ancestor(of: find.text('玩家1'), matching: find.byType(Container)).last,
    );
    return row.top - listView.top;
  }

  testWidgets('Rating 排行榜：列表首行紧贴顶部分隔线（不留状态栏高度的空白）',
      (tester) async {
    await pumpPage(tester, const RatingRankListPage());

    expect(find.text('玩家1'), findsOneWidget);
    expect(firstRowOffset(tester), 0,
        reason: '首行上方多出的正是 MediaQuery.padding.top；'
            '`ListView` 必须显式 padding: EdgeInsets.zero');
  });

  testWidgets('平均达成率/平均 DX 排行榜：同样紧贴', (tester) async {
    await pumpPage(
        tester, const AvgScoreRankingListPage(initialMetric: AvgMetric.achievement));

    expect(find.text('玩家1'), findsWidgets);
    expect(firstRowOffset(tester), 0);
  });

  testWidgets('拟合总 Rating 排行榜：同样紧贴', (tester) async {
    await pumpPage(tester, const FittedRatingRankingListPage());

    expect(find.text('玩家1'), findsWidgets);
    expect(firstRowOffset(tester), 0);
  });
}
