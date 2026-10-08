// 「排行榜列表的头像高度 = 玩家名那一行 + 数据源标签那一行」的回归测试。
//
// 需求原文：头像高度应当等于「第一行的玩家名 + 第二行的数据源 label」所占的高度。
// 实现是**量出来**的（`TextPainter` + `DefaultTextStyle` + `MediaQuery.textScalerOf`），
// 所以这里也只用**几何**验证，不读源码字符串：
//
//   头像高 == 玩家名那一行的高度 + 行距(3) + 数据源标签的高度
//   且头像上/下边缘分别贴住第一行的顶、第二行的底
//
// 覆盖的页面：
//   * Best50 枢纽里除「特殊排行榜」外的那 4 个（Rating / 拟合总 Rating /
//     平均达成率 / 平均 DX 达成率）；
//   * 单曲排行榜 / DX 分数排行榜（同一个 `SongRankingPage`，两种 `RankingType`）。
//
// 后面两组还管单曲 / DX 分数榜的**横向**空间：数值区以前写死 `SizedBox(width: 130)`
// （底部固定条 150），内容右对齐、靠不满的那一截左边全是空白，昵称却因此提前打成
// 省略号 —— 现在改成按内容收缩，省下的宽度归昵称。
//
// 这类断言能挡住三种错法：写死一个偏小的 dp（老代码固定 32）、
// 只算一行文字、量的时候漏掉 `DefaultTextStyle` 的行高或 `textScaler`。
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_first_flutter_app/constant/CacheKeyConstant.dart';
import 'package:my_first_flutter_app/page/RankingList/AvgScoreRankingListPage.dart';
import 'package:my_first_flutter_app/page/RankingList/FittedRatingRankingListPage.dart';
import 'package:my_first_flutter_app/page/RankingList/RatingRankListPage.dart';
import 'package:my_first_flutter_app/page/RankingList/SongRankingPage.dart';
import 'package:my_first_flutter_app/service/RankingList/AvgRankingListService.dart';
import 'package:my_first_flutter_app/service/RankingList/FittedRatingRankingListService.dart';
import 'package:my_first_flutter_app/service/RankingList/RatingRankListService.dart';
import 'package:my_first_flutter_app/service/RankingList/SongRankingService.dart';
import 'package:my_first_flutter_app/utils/ApiClient.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:my_first_flutter_app/widgets/CommunityAvatar.dart';
import 'package:my_first_flutter_app/widgets/DataSourceTag.dart';

/// 状态栏高度（dp）——真实页面里 ListView 上方那块由 `PageTopBar` 占掉。
const double kProbeStatusBar = 24;

const int kCount = 6;

/// 单曲榜列表行 / 底部固定条的数值区**老宽度**（写死的 `SizedBox(width: …)`）。
const double kOldValueColumnWidth = 130;
const double kOldCurrentUserValueColumnWidth = 150;

/// `CommunityPlayerIdentity` 里头像与文字列之间的间距（改宽度断言时要跟着改）。
const double kIdentityAvatarGap = 8;

/// 两个「刚好卡在老布局放不下、新布局放得下」之间的昵称（见各自的用例前提）。
const String kLongRowName = '超长昵称测试名字'; // 8 字
const String kLongCurrentUserName = '超长昵称测试名二号'; // 9 字

String _userIdAt(int index) => 'shuiyu:${index + 1}';

/// 单曲排行榜接口里的一条成绩（`RankingEntry.fromJson` 的口径）。
///
/// [updateTime] 默认取「现在」：同步时间会显示成「刚刚」（2 个字），
/// 不会把数值区顶到上限宽度，宽度类断言才量得准。
Map<String, dynamic> _entryJson(
  int rank, {
  String? name,
  String? fc = 'ap',
  double? rate,
  int? dxScore,
  int? updateTime,
}) =>
    {
      'rank': rank,
      'playerId': _userIdAt(rank - 1),
      'playerName': name ?? '玩家$rank',
      'achievementRate': rate ?? (101.5 - rank * 0.01),
      'dxScore': dxScore ?? (3200 - rank),
      'fc': fc,
      'dataSource': 'shuiyu',
      'updateTime': updateTime ?? DateTime.now().millisecondsSinceEpoch,
      'avatarId': 73,
    };

/// 把单曲排行榜的两个接口打桩：榜单列表 + 当前玩家那一条。
void _installSongRankingMock({
  required List<Map<String, dynamic>> entries,
  Map<String, dynamic>? currentUser,
}) {
  ApiClient.debugClient = MockClient((request) async {
    // 必须带 charset=utf-8：`http.Response(String)` 默认按 latin1 编码，
    // 昵称里的中文会直接抛 "Contains invalid characters"。
    const jsonHeaders = {'content-type': 'application/json; charset=utf-8'};
    final path = request.url.path;
    if (path.contains('/api/song-rankings/')) {
      if (path.contains('/user/')) {
        return http.Response(
            jsonEncode({
              'success': true,
              'found': currentUser != null,
              if (currentUser != null) 'data': currentUser,
            }),
            200,
            headers: jsonHeaders);
      }
      return http.Response(
          jsonEncode({'success': true, 'data': entries}), 200,
          headers: jsonHeaders);
    }
    return http.Response(jsonEncode({'success': false}), 404,
        headers: jsonHeaders);
  });
}

/// 单曲排行榜相关用例的 prefs：当前玩家（第 2 名）+ 跳过免责声明弹窗。
void _setSongRankingPrefs() {
  SharedPreferences.setMockInitialValues({
    CacheKeyConstant.lastDataSource: 'shuiyu',
    CacheKeyConstant.shuiyuUserId: _userIdAt(1),
    // 别弹免责声明对话框，否则列表被对话框挡住、测不到行几何
    CacheKeyConstant.songRankingDisclaimerShown: true,
  });
}

/// `Text` 完整显示所需的宽度（与页面同口径：环境 `DefaultTextStyle` + `textScaler`）。
double _fullTextWidth(WidgetTester tester, Finder textFinder) {
  final element = tester.element(textFinder);
  final text = tester.widget<Text>(textFinder);
  final style =
      DefaultTextStyle.of(element).style.merge(text.style);
  final painter = TextPainter(
    text: TextSpan(text: text.data, style: style),
    textDirection: Directionality.of(element),
    textScaler: MediaQuery.textScalerOf(element),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

/// 某个玩家身份块里昵称**可用**的宽度（身份块宽 − 头像 − 间距）。
double _nameAvailableWidth(WidgetTester tester, Finder identity) {
  final identityRect = tester.getRect(identity);
  final avatarRect = tester.getRect(
      find.descendant(of: identity, matching: find.byType(CommunityAvatar)));
  return identityRect.width - avatarRect.width - kIdentityAvatarGap;
}

/// 数值区**内容**的宽度：数值与同步时间都右对齐，取两者较宽的那个。
double _valueContentWidth(WidgetTester tester, Finder value, Finder time) =>
    math.max(tester.getRect(value).width, tester.getRect(time).width);

/// 数值区**占位**的宽度：从身份块右边缘（含两者之间的间距）到数值右边缘。
///
/// 为什么要单独量「占位」而不是「内容」：老代码是 `SizedBox(width: 130)`，
/// 内容右对齐、靠不满也照样占掉 130dp —— 只量内容宽度看不出这段浪费。
/// 身份块是 `Expanded`（会吃掉剩余宽度），所以「它右边还剩多少」就是数值区占掉的宽度。
double _valueReservedWidth(
        WidgetTester tester, Finder identity, Finder valueText) =>
    tester.getRect(valueText).right -
    tester.getRect(identity).right -
    kIdentityAvatarGap;

SongRankingPage _songRankingPage(RankingType type) => SongRankingPage(
      songId: '1234',
      difficultyIndex: 3,
      rankingType: type,
      songTitle: '测试曲目',
      difficultyLabel: 'MASTER',
      songType: 'SD',
      artist: '测试歌手',
      genre: '测试分类',
      from: 'DX 2024',
      difficultyDs: 13.5,
    );

/// 断言某一个玩家身份块里：头像高 == 两行文字（玩家名 + 标签行）的总高。
///
/// 标签行可能有一颗胶囊（普通玩家），也可能有两颗（开发者：数据源 + 开发者喵），
/// 所以这里取所有标签的**并集高度**——两颗标签同处一个 `Row`，高度本来就相同，
/// 并集是为了让「多一颗标签」这件事本身不会把断言写法顶坏。
void expectAvatarMatchesTextRows(WidgetTester tester, Finder identity) {
  final widget = tester.widget<CommunityPlayerIdentity>(identity);
  final avatar =
      find.descendant(of: identity, matching: find.byType(CommunityAvatar));
  final tags = find.descendant(of: identity, matching: find.byType(DataSourceTag));
  final nameLine =
      find.descendant(of: identity, matching: find.text(widget.name));

  expect(avatar, findsOneWidget, reason: '每个玩家身份块都要有头像');
  expect(tags, findsWidgets, reason: '每个玩家身份块都要有数据源标签');
  expect(nameLine, findsOneWidget);

  final avatarRect = tester.getRect(avatar);
  final nameRect = tester.getRect(nameLine);
  final tagRects = [
    for (var i = 0; i < tags.evaluate().length; i++) tester.getRect(tags.at(i)),
  ];
  final tagTop = tagRects.map((r) => r.top).reduce(math.min);
  final tagBottom = tagRects.map((r) => r.bottom).reduce(math.max);
  final textBlockHeight = nameRect.height +
      CommunityPlayerIdentity.nameTagGap +
      (tagBottom - tagTop);

  expect(avatarRect.height, closeTo(textBlockHeight, 0.01),
      reason: '头像高（${avatarRect.height}）必须等于「玩家名那一行 + 行距 + '
          '标签行」（$textBlockHeight）');
  expect(avatarRect.width, closeTo(avatarRect.height, 0.01),
      reason: '头像必须是正方形');
  expect(avatarRect.top, closeTo(nameRect.top, 0.01),
      reason: '头像上边缘要贴住第一行（玩家名）的顶');
  expect(avatarRect.bottom, closeTo(tagBottom, 0.01),
      reason: '头像下边缘要贴住第二行（标签行）的底');
  expect(avatarRect.height, greaterThan(CommunityAvatar.defaultSize),
      reason: '两行文字本来就比固定的 ${CommunityAvatar.defaultSize}dp 高，'
          '头像必须跟着变大而不是还是 32');
}

/// 页面上**每一处**玩家身份（榜单里的行 + 底部固定条）都要满足上面的约束。
void expectAllIdentitiesAligned(WidgetTester tester) {
  final identities = find.byType(CommunityPlayerIdentity);
  final count = identities.evaluate().length;
  expect(count, greaterThan(1),
      reason: '至少要同时覆盖到榜单行与底部固定条');
  for (var i = 0; i < count; i++) {
    expectAvatarMatchesTextRows(tester, identities.at(i));
  }
}

/// 组件级测试用的最小行：40dp 名次 + 玩家身份 + 数值区，与真实榜单行同构。
Widget _harness({
  double textScale = 1.0,
  bool avatarMatchesTextHeight = false,
  String name = '玩家一号',
  String dataSource = 'awmc',
  String? playerId,
}) {
  return MaterialApp(
    theme: AppTheme.lightTheme(),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            child: Row(
              children: [
                const SizedBox(width: 40, child: Text('7')),
                Expanded(
                  child: CommunityPlayerIdentity(
                    avatarId: 1234,
                    name: name,
                    dataSource: dataSource,
                    playerId: playerId,
                    avatarMatchesTextHeight: avatarMatchesTextHeight,
                  ),
                ),
                const SizedBox(width: 8),
                const SizedBox(width: 120, child: Text('17000')),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      CacheKeyConstant.lastDataSource: 'shuiyu',
      // 当前玩家是第 2 名：这样底部固定条与榜单首行的名字不会混在一起
      CacheKeyConstant.shuiyuUserId: _userIdAt(1),
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

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    tester.view.padding = const FakeViewPadding(top: kProbeStatusBar * 3);
    tester.view.viewPadding = const FakeViewPadding(top: kProbeStatusBar * 3);
    addTearDown(tester.view.reset);

    // ⚠️ 这里不用 `tester.takeException()` 收拾异常：测试环境的默认字体是等宽方块字，
    // 比真机思源黑体宽得多，每行右侧的 "B35: xxx  B15: xxx"（固定 140dp 宽）会横向
    // 溢出好几条，**同一帧**里报出来的多条会被框架合并成一句
    // "Multiple exceptions (N) …"，就分不出哪条是既有溢出、哪条是本次改动引入的错。
    // 所以自己逐条记录 `FlutterError.onError`，只放过溢出，其它照样让测试挂。
    final errors = <Object>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.exception);
    try {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme(),
        home: page,
      ));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    } finally {
      FlutterError.onError = previousOnError;
    }

    final unexpected = errors
        .where((e) => !e.toString().contains('overflowed by'))
        .toList();
    expect(unexpected, isEmpty,
        reason: '除了这几个榜单既有的横向溢出，页面不该再报别的渲染异常');
  }

  group('4 个排行榜（Best50 枢纽里除特殊排行榜外）', () {
    testWidgets('Rating 排行榜：榜单行与底部固定条的头像都等于两行文字高',
        (tester) async {
      await pumpPage(tester, const RatingRankListPage());

      expectAllIdentitiesAligned(tester);
    });

    testWidgets('拟合总 Rating 排行榜：同上', (tester) async {
      await pumpPage(tester, const FittedRatingRankingListPage());

      expectAllIdentitiesAligned(tester);
    });

    testWidgets('平均达成率排行榜：同上', (tester) async {
      await pumpPage(
          tester,
          const AvgScoreRankingListPage(
              initialMetric: AvgMetric.achievement));

      expectAllIdentitiesAligned(tester);
    });

    testWidgets('平均 DX 达成率排行榜：同上', (tester) async {
      await pumpPage(
          tester, const AvgScoreRankingListPage(initialMetric: AvgMetric.dx));

      expectAllIdentitiesAligned(tester);
    });

    testWidgets('Rating 排行榜：白名单玩家的行端到端多出「开发者喵」', (tester) async {
      // 其余玩家用「玩家N」，开发者单独给一个能对上的名字：
      // 名字重复的话 find.text 会撞车（底部固定条与榜单行会同时命中）。
      RatingRankListService.debugRankingsLoader = () async => [
            RankItem(
              rank: 1,
              userId: 'shuiyu:488581724',
              dataSource: 'shuiyu',
              originalId: '488581724',
              nickname: '开发者玩家',
              avatarId: 73,
              totalRating: 17000,
              best35Rating: 12000,
              best15Rating: 5000,
            ),
            RankItem(
              rank: 2,
              userId: 'shuiyu:1',
              dataSource: 'shuiyu',
              originalId: '1',
              nickname: '普通玩家',
              avatarId: 73,
              totalRating: 16000,
              best35Rating: 11000,
              best15Rating: 5000,
            ),
          ];

      await pumpPage(tester, const RatingRankListPage());

      // 白名单里那一条：数据源标签 + 开发者喵
      final developerRow = find.ancestor(
        of: find.text('开发者玩家'),
        matching: find.byType(CommunityPlayerIdentity),
      );
      expect(
        find.descendant(
            of: developerRow, matching: find.text('开发者喵')),
        findsOneWidget,
        reason: 'playerId 要走 `RankItem.userId` 传进身份块，白名单命中后多一颗胶囊',
      );

      // 普通玩家不受影响，仍然只有数据源标签
      final normalRow = find.ancestor(
        of: find.text('普通玩家'),
        matching: find.byType(CommunityPlayerIdentity),
      );
      expect(
        find.descendant(of: normalRow, matching: find.byType(DataSourceTag)),
        findsOneWidget,
      );
    });
  });

  group('单曲排行榜 / DX 分数排行榜（SongRankingPage）', () {
    setUp(() {
      _setSongRankingPrefs();
      _installSongRankingMock(
        entries: [for (var i = 1; i <= kCount; i++) _entryJson(i)],
        // 当前玩家在榜上 → 底部固定条也要一起测
        currentUser: _entryJson(2),
      );
    });

    tearDown(() {
      ApiClient.debugClient = null;
    });

    testWidgets('单曲排行榜（达成率）：榜单行与底部固定条的头像都等于两行文字高',
        (tester) async {
      await pumpPage(tester, _songRankingPage(RankingType.achievementRate));

      expect(find.text('达成率排行榜'), findsOneWidget,
          reason: '先确认渲染的是达成率榜，不是空列表或错误态');
      expectAllIdentitiesAligned(tester);
    });

    testWidgets('DX 分数排行榜：同上', (tester) async {
      await pumpPage(tester, _songRankingPage(RankingType.dxScore));

      expect(find.text('DX分数排行榜'), findsOneWidget,
          reason: '先确认渲染的是 DX 分数榜，不是空列表或错误态');
      expectAllIdentitiesAligned(tester);
    });
  });

  group('单曲排行榜 / DX 分数排行榜的昵称可用宽度', () {
    setUp(_setSongRankingPrefs);

    tearDown(() {
      ApiClient.debugClient = null;
    });

    testWidgets('DX 分数排行榜：数值区按内容收缩，昵称拿到省下的宽度（不再提前省略）',
        (tester) async {
      _installSongRankingMock(
        entries: [
          _entryJson(1, name: kLongRowName, dxScore: 3199),
          for (var i = 2; i <= kCount; i++) _entryJson(i),
        ],
        // 底部固定条那一条是**单独**拉的（`/user/`），昵称故意跟榜单里的不一样：
        // 否则同一个名字在榜单行和固定条各出现一次，finder 会撞车
        currentUser: _entryJson(2, name: kLongCurrentUserName, dxScore: 3111),
      );

      await pumpPage(tester, _songRankingPage(RankingType.dxScore));

      // —— 榜单行：数值区老宽度 130dp ——
      final rowName = find.text(kLongRowName);
      final rowIdentity = find.ancestor(
          of: rowName, matching: find.byType(CommunityPlayerIdentity));
      expect(rowIdentity, findsOneWidget);
      // DX 分数只有 4 位数、同步时间又是「刚刚」，数值区很短：老布局那 130dp
      // 里有一大半是空白
      final rowGain = kOldValueColumnWidth -
          _valueReservedWidth(tester, rowIdentity, find.text('3199'));
      expect(rowGain, greaterThan(20),
          reason: '数值区必须真的把没用的空白让出来（让出 $rowGain dp）');

      final rowFullName = _fullTextWidth(tester, rowName);
      final rowOldAvailable = _nameAvailableWidth(tester, rowIdentity) - rowGain;
      expect(rowOldAvailable, lessThan(rowFullName),
          reason: '老布局（数值区固定 ${kOldValueColumnWidth}dp）下这个昵称会被省略号截断，'
              '这条用例才证明得了「空间被浪费」');
      expect(tester.getRect(rowName).width,
          greaterThanOrEqualTo(rowFullName - 0.5),
          reason: '新布局下这条昵称必须完整显示');

      // —— 底部固定条：数值区老宽度 150dp，同样处理 ——
      final barName = find.text(kLongCurrentUserName);
      final barIdentity = find.ancestor(
          of: barName, matching: find.byType(CommunityPlayerIdentity));
      expect(barIdentity, findsOneWidget);
      // 数值 / 同步时间都右对齐，`.last` 拿的就是底部固定条那一份
      final barGain = kOldCurrentUserValueColumnWidth -
          _valueReservedWidth(tester, barIdentity, find.text('3111'));
      final barFullName = _fullTextWidth(tester, barName);
      final barOldAvailable = _nameAvailableWidth(tester, barIdentity) - barGain;
      expect(barOldAvailable, lessThan(barFullName),
          reason: '底部固定条老布局（固定 ${kOldCurrentUserValueColumnWidth}dp）同样会截断它');
      expect(tester.getRect(barName).width,
          greaterThanOrEqualTo(barFullName - 0.5),
          reason: '底部固定条的昵称也要完整显示');
    });

    testWidgets('单曲达成率排行榜：数值区不再固定占 130dp，而是按内容收缩',
        (tester) async {
      _installSongRankingMock(
        entries: [
          // 达成率取 9.5%（`9.5000%`）而不是 100% 往上：数值本身窄，才量得出
          // 「收缩」这件事（老代码不管内容多窄都占满 130dp）
          _entryJson(1, rate: 9.5, fc: null),
          for (var i = 2; i <= kCount; i++) _entryJson(i),
        ],
        currentUser: null,
      );

      await pumpPage(tester, _songRankingPage(RankingType.achievementRate));

      final value = find.text('9.5000%');
      expect(value, findsOneWidget, reason: '先确认达成率榜渲染出了这一行');
      final time = find.text('刚刚').first;
      final contentWidth = _valueContentWidth(tester, value, time);
      // 数值和昵称在同一个 Row 里是**兄弟**（数值不在身份块内部），
      // 所以身份块要用这一行的昵称去找。
      final reservedWidth = _valueReservedWidth(
          tester,
          find.ancestor(
              of: find.text('玩家1'),
              matching: find.byType(CommunityPlayerIdentity)),
          value);

      expect(reservedWidth, closeTo(math.min(kOldValueColumnWidth, contentWidth), 0.5),
          reason: '数值区必须按内容宽度收缩（老代码固定占 ${kOldValueColumnWidth}dp，'
              '靠不满的空白全浪费了）');

      // 只是把左边的空白让给昵称，数值本身仍然贴右（和同步时间共用同一条右边线）
      final rowRect = tester.getRect(
          find.ancestor(of: value, matching: find.byType(Container)).last);
      expect(tester.getRect(value).right, closeTo(tester.getRect(time).right, 0.5),
          reason: '数值与同步时间必须仍然右对齐、共用同一条右边线');
      expect(tester.getRect(value).right, greaterThan(rowRect.center.dx),
          reason: '数值仍然贴右，只是左边那一截空白变成了昵称可用宽度');
    });
  });

  group('CommunityPlayerIdentity 组件级', () {
    testWidgets('默认仍然固定 32dp（歌单排行等页面观感不变）', (tester) async {
      await tester.pumpWidget(_harness());

      expect(tester.getSize(find.byType(CommunityAvatar)),
          const Size(CommunityAvatar.defaultSize,
              CommunityAvatar.defaultSize));
    });

    testWidgets('默认在系统字号放大后仍固定 32dp', (tester) async {
      await tester.pumpWidget(_harness(textScale: 1.5));

      expect(tester.getSize(find.byType(CommunityAvatar)),
          const Size(CommunityAvatar.defaultSize,
              CommunityAvatar.defaultSize));
    });

    for (final scale in [1.0, 1.3, 1.5]) {
      testWidgets('打开开关后 textScale $scale 仍然严丝合缝', (tester) async {
        await tester.pumpWidget(_harness(
          textScale: scale,
          avatarMatchesTextHeight: true,
        ));

        expectAvatarMatchesTextRows(
            tester, find.byType(CommunityPlayerIdentity));
      });
    }

    testWidgets('长昵称被省略号截断时高度依旧是一行（不会撑高头像）',
        (tester) async {
      await tester.pumpWidget(_harness(
        name: '这是一个特别特别长的玩家昵称用来挤爆一行',
        avatarMatchesTextHeight: true,
      ));

      expectAvatarMatchesTextRows(
          tester, find.byType(CommunityPlayerIdentity));
      expect(tester.takeException(), isNull);
    });

    testWidgets('标签长度/数据源不同（AWMC / 落雪 / 未知）也都对得上',
        (tester) async {
      for (final source in ['awmc', 'luoxue', 'shuiyu', 'unknown-source']) {
        await tester.pumpWidget(_harness(
          dataSource: source,
          avatarMatchesTextHeight: true,
        ));

        expectAvatarMatchesTextRows(
            tester, find.byType(CommunityPlayerIdentity));
      }
    });
  });

  group('开发者喵标签（排行榜行）', () {
    const developerId = 'shuiyu:488581724';

    for (final scale in [1.0, 1.3, 1.5]) {
      testWidgets('开发者多挂一个「开发者喵」，头像仍然等于两行文字高 @ textScale $scale',
          (tester) async {
        await tester.pumpWidget(_harness(
          textScale: scale,
          avatarMatchesTextHeight: true,
          dataSource: 'shuiyu',
          playerId: developerId,
        ));

        expect(find.text('开发者喵'), findsOneWidget,
            reason: '白名单里的 playerId 要在数据源标签后面多出一个「开发者喵」');
        expect(find.byType(DataSourceTag), findsNWidgets(2),
            reason: '数据源标签 + 开发者喵，一共两颗胶囊');
        expectAvatarMatchesTextRows(
            tester, find.byType(CommunityPlayerIdentity));
      });
    }

    testWidgets('普通玩家只有数据源标签，没有「开发者喵」', (tester) async {
      await tester.pumpWidget(_harness(
        playerId: 'shuiyu:1',
        dataSource: 'shuiyu',
        avatarMatchesTextHeight: true,
      ));

      expect(find.text('开发者喵'), findsNothing);
      expect(find.byType(DataSourceTag), findsOneWidget);
      expectAvatarMatchesTextRows(
          tester, find.byType(CommunityPlayerIdentity));
    });

    testWidgets('不传 playerId 时也不显示「开发者喵」', (tester) async {
      await tester.pumpWidget(_harness(avatarMatchesTextHeight: true));

      expect(find.text('开发者喵'), findsNothing);
    });

    testWidgets('两个标签在同一个 FittedBox 里，不会撑破身份块宽度', (tester) async {
      await tester.pumpWidget(_harness(
        playerId: developerId,
        dataSource: 'shuiyu',
        avatarMatchesTextHeight: true,
      ));

      expect(tester.takeException(), isNull);
      final identity = find.byType(CommunityPlayerIdentity);
      final tags = find.descendant(
          of: identity, matching: find.byType(DataSourceTag));
      // 「开发者喵」必须紧跟在数据源标签后面（横坐标递增）
      final first = tester.getRect(tags.at(0));
      final second = tester.getRect(tags.at(1));
      expect(second.left, greaterThanOrEqualTo(first.right - 0.01),
          reason: '开发者喵要排在数据源标签后面，不能重叠');
      expect(second.right, lessThanOrEqualTo(tester.getRect(identity).right + 0.01),
          reason: '两个标签都要待在身份块内（超宽时由 FittedBox 整体缩放）');
    });
  });

  group('DataSourceTag 高度测量', () {
    testWidgets('heightFor 量出的高度 == 真实渲染高度（含字号缩放）',
        (tester) async {
      for (final scale in [1.0, 1.3, 1.5]) {
        for (final source in ['shuiyu', 'luoxue', 'awmc', 'unknown-source']) {
          late BuildContext context;
          await tester.pumpWidget(MaterialApp(
            theme: AppTheme.lightTheme(),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: Builder(builder: (ctx) {
                  context = ctx;
                  return Center(child: DataSourceTag(dataSource: source));
                }),
              ),
            ),
          ));

          final label = dataSourceStyleOf(
                  source, Theme.of(context).brightness)
              .label;
          final measured =
              DataSourceTag.heightFor(context, label);
          final rendered =
              tester.getSize(find.byType(DataSourceTag)).height;

          expect(measured, closeTo(rendered, 0.01),
              reason: '$source @ textScale $scale：量的是 $measured、'
                  '画出来的是 $rendered');
        }
      }
    });
  });
}
