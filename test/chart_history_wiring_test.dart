import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_first_flutter_app/constant/CacheKeyConstant.dart';
import 'package:my_first_flutter_app/manager/DivingFish/UserPlayDataManager.dart';
import 'package:my_first_flutter_app/manager/AWMC/AwmcNetUserPlayDataManager.dart';
import 'package:my_first_flutter_app/service/FriendCompareService.dart';
import 'package:my_first_flutter_app/service/History/ChartHistoryStore.dart';
import 'package:my_first_flutter_app/utils/ApiClient.dart';
import 'package:my_first_flutter_app/utils/CurrentDataSourceNotifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory history;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      CacheKeyConstant.lastDataSource: 'luoxue',
      CacheKeyConstant.cachedQQ: 'luoxue-friend-code',
      CacheKeyConstant.probeDivingFishBindQQ: '12345',
      CacheKeyConstant.userPlayData: '{"records":[],"nickname":"原账号"}',
    });
    prefs = await SharedPreferences.getInstance();
    CurrentDataSourceNotifier.instance.value = RefreshDataSource.luoxue;
    history = Directory.systemTemp.createTempSync('history_wiring_');
    ChartHistoryStore.debugDirectoryOverride = history.path;
    ChartHistoryStore.instance.debugClearCache();
  });

  tearDown(() {
    ApiClient.debugClient?.close();
    ApiClient.debugClient = null;
    ChartHistoryStore.instance.debugClearCache();
    ChartHistoryStore.debugDirectoryOverride = null;
    history.deleteSync(recursive: true);
  });

  Map<String, dynamic> response(String id) => {
        'nickname': id,
        'rating': 15000,
        'records': [
          {
            'song_id': 8,
            'level_index': 3,
            'achievements': 100.5,
            'dxScore': 200,
            'title': 'test',
            'ds': 13.0,
            'ra': 290,
          }
        ],
      };

  test('好友对比使用水鱼绑定 QQ，两个查询都不覆盖当前落雪缓存或采集历史', () async {
    final requested = <String>[];
    ApiClient.debugClient = MockClient((request) async {
      final qq = request.url.queryParameters['qq']!;
      requested.add(qq);
      return http.Response(jsonEncode(response(qq)), 200);
    });
    final before = prefs.getString(CacheKeyConstant.userPlayData);
    final result = await FriendCompareService().compareWithFriend('67890');
    expect(requested, ['12345', '67890']);
    expect(result.friendNickname, '67890');
    expect(prefs.getString(CacheKeyConstant.userPlayData), before);
    expect(history.listSync(), isEmpty);
  });

  test('AWMC 查询晚返回时也不会写入已切换的活动槽', () async {
    ApiClient.debugClient = MockClient((request) async {
      await CurrentDataSourceNotifier.instance.set(RefreshDataSource.shuiyu);
      return http.Response(jsonEncode(response('12345')), 200);
    });
    final before = prefs.getString(CacheKeyConstant.userPlayData);
    final data = await AwmcNetUserPlayDataManager().fetchUserPlayData('12345');
    expect(data['rating'], 15000);
    expect(prefs.getString(CacheKeyConstant.userPlayData), before);
    expect(history.listSync(), isEmpty);
  });

  test('事务外不能把查询结果提交给别的账号', () async {
    await expectLater(
        UserPlayDataManager().storeFetchedData(response('12345'),
            source: RefreshDataSource.shuiyu, accountId: '12345'),
        throwsStateError);
    expect(prefs.getString(CacheKeyConstant.userPlayData), contains('原账号'));
  });

  test('水鱼查询失败保留当前账号数据', () async {
    ApiClient.debugClient =
        MockClient((_) async => http.Response('failure', 500));
    expect(await UserPlayDataManager().fetchUserPlayData('12345'), isNull);
    expect(prefs.getString(CacheKeyConstant.userPlayData), contains('原账号'));
    expect(history.listSync(), isEmpty);
  });
}
