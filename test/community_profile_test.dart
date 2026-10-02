import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:my_first_flutter_app/service/RankingList/AvgRankingListService.dart';
import 'package:my_first_flutter_app/service/RankingList/FittedRatingRankingListService.dart';
import 'package:my_first_flutter_app/service/RankingList/RatingRankListService.dart';
import 'package:my_first_flutter_app/service/RankingList/SongRankingService.dart';
import 'package:my_first_flutter_app/service/SongInfoService.dart';
import 'package:my_first_flutter_app/utils/CommunityProfileUtil.dart';
import 'package:my_first_flutter_app/widgets/CommunityAvatar.dart';

void main() {
  test('服务端匿名 author 优先于旧头像字段，包括空或损坏的 author', () {
    for (final author in [
      {'avatarId': 1},
      {'avatarId': null},
      <String, dynamic>{},
      null,
      'invalid',
    ]) {
      expect(
          CommunityProfileUtil.avatarIdFromJson({
            'avatarId': 1234,
            'author': author,
          }),
          1);
    }
    expect(
        CommunityProfileUtil.avatarIdFromJson({
          'avatarId': 1,
          'author': {'avatarId': '1234'},
        }),
        1234);
  });

  test('旧响应和非法头像 ID 平稳回退', () {
    expect(CommunityProfileUtil.avatarIdFromJson({}), 1);
    expect(CommunityProfileUtil.avatarIdFromJson({'avatarId': 1234}), 1234);
    for (final value in [
      0,
      -1,
      1.5,
      double.nan,
      double.infinity,
      'bad',
      4294967296,
      <String, int>{}
    ]) {
      expect(CommunityProfileUtil.normalizeAvatarId(value), 1);
    }
  });

  test('全部社区模型读取 author，JSON 缓存往返保留头像和原数据', () {
    final response = <String, dynamic>{
      'userId': 'shuiyu:test',
      'playerId': 'shuiyu:test',
      'originalId': 'test',
      'dataSource': 'shuiyu',
      'nickname': '测试玩家',
      'playerName': '测试玩家',
      'rank': 7,
      'totalRating': 15000,
      'best35Rating': 10500,
      'best15Rating': 4500,
      'avgAchievement': 100.1,
      'fittedRating': 15123,
      'achievementRate': 100.5,
      'content': '评论内容',
      'author': {'avatarId': 1234},
    };
    final cached = <Map<String, dynamic>>[
      RankItem.fromJson(response).toJson(),
      AvgRankItem.fromJson(response).toJson(),
      FittedRankItem.fromJson(response).toJson(),
      CommentItem.fromJson(response).toJson(),
    ]
        .map((value) => jsonDecode(jsonEncode(value)) as Map<String, dynamic>)
        .toList();
    expect(RankItem.fromJson(cached[0]).avatarId, 1234);
    expect(RankItem.fromJson(cached[0]).totalRating, 15000);
    expect(AvgRankItem.fromJson(cached[1]).avatarId, 1234);
    expect(AvgRankItem.fromJson(cached[1]).avgAchievement, 100.1);
    expect(FittedRankItem.fromJson(cached[2]).avatarId, 1234);
    expect(FittedRankItem.fromJson(cached[2]).fittedRating, 15123);
    expect(CommentItem.fromJson(cached[3]).avatarId, 1234);
    expect(CommentItem.fromJson(cached[3]).content, '评论内容');
    expect(RankingEntry.fromJson(response).avatarId, 1234);
    expect(RankingEntry.fromJson(response).achievementRate, 100.5);
    expect(CommentItem.fromJson({}).displayName, '匿名用户');
    expect(CommentItem.fromJson({'nickname': '   '}).displayName, '匿名用户');
  });

  testWidgets('窄屏、大字体下头像固定大小，长昵称不挤出成绩区域', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: 288,
              child: Row(
                children: [
                  const SizedBox(width: 40, child: Text('7')),
                  const Expanded(
                    child: CommunityPlayerIdentity(
                      avatarId: 1234,
                      name: '这是很长很长的玩家昵称',
                      dataSource: 'awmc',
                    ),
                  ),
                  const SizedBox(width: 8),
                  const SizedBox(width: 150, child: Text('100.5000%')),
                ],
              ),
            ),
          ),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(CommunityAvatar)), const Size(32, 32));
    final image =
        tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
    expect(image.imageUrl, 'https://assets2.lxns.net/maimai/icon/1234.png');
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
