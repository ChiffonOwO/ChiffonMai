import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_first_flutter_app/constant/CacheKeyConstant.dart';
import 'package:my_first_flutter_app/service/CommunityAvatarStore.dart';
import 'package:my_first_flutter_app/utils/ApiClient.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final store = CommunityAvatarStore.instance;
  Future<void> flush() async {
    for (var i = 0; i < 30; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  setUp(() {
    ApiClient.debugClient = MockClient((_) async => http.Response('{}', 503));
    SharedPreferences.setMockInitialValues({
      CacheKeyConstant.lastDataSource: 'shuiyu',
      CacheKeyConstant.shuiyuUserId: 'shuiyu:12345',
      CacheKeyConstant.probeDivingFishToken: 'test-session',
    });
  });

  test('AWMC 用活动玩家 QQ 同步头像，不使用或串用其他来源的凭据', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(CacheKeyConstant.lastDataSource, 'awmc');
    await prefs.setString(CacheKeyConstant.awmcUserId, 'awmc:12345');
    final writes = <Map<String, dynamic>>[];
    ApiClient.debugClient = MockClient((req) async {
      expect(req.url.scheme, 'https');
      expect(req.headers['X-Profile-Source'], 'awmc');
      expect(req.headers['X-Profile-QQ'], '12345');
      expect(req.headers.containsKey('Authorization'), false);
      if (req.method == 'PUT') {
        writes.add(jsonDecode(req.body) as Map<String, dynamic>);
      }
      return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'playerId': 'awmc:12345',
              'avatarId': 1,
              'profileRevision': '2',
            }
          }),
          200);
    });
    await store.activate();
    await flush();
    await store.select(73);
    await flush();
    expect(writes.single['playerId'], 'awmc:12345');
    expect(writes.single['avatarId'], 73);
    expect(store.value.pending, false);
    expect(store.value.avatarId, 73);
  });

  test('水鱼已登录但未刷新成绩时，按绑定 QQ 上传头像', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(CacheKeyConstant.shuiyuUserId);
    await prefs.setString(CacheKeyConstant.probeDivingFishBindQQ, '12345');
    final puts = <Map<String, dynamic>>[];
    ApiClient.debugClient = MockClient((req) async {
      expect(req.headers['X-Profile-Source'], 'shuiyu');
      expect(req.headers['Authorization'], 'Bearer test-session');
      if (req.method == 'PUT') {
        puts.add(jsonDecode(req.body) as Map<String, dynamic>);
      } else {
        expect(req.url.queryParameters['playerId'], 'shuiyu:12345');
      }
      return http.Response(jsonEncode({
        'success': true,
        'data': {'playerId': 'shuiyu:12345', 'avatarId': 1, 'profileRevision': '2'},
      }), 200);
    });
    await store.activate();
    await flush();
    expect(store.value.playerId, 'shuiyu:12345');
    await store.select(73);
    await flush();
    expect(puts.single['playerId'], 'shuiyu:12345');
    expect(puts.single['avatarId'], 73);
    expect(store.value.pending, false);
    expect(store.value.message, '社区头像已同步');
  });

  test('未登录时的本机选择在登录后自动归属绑定 QQ 并上传', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(CacheKeyConstant.shuiyuUserId);
    await prefs.remove(CacheKeyConstant.probeDivingFishToken);
    await prefs.setString(CacheKeyConstant.cachedQQ, '99999');
    await store.activate();
    await flush();
    expect(store.value.playerId, isNull);
    expect(store.value.message, contains('登录水鱼后自动同步'));
    await store.select(73);
    await flush();
    final puts = <Map<String, dynamic>>[];
    ApiClient.debugClient = MockClient((req) async {
      if (req.method == 'PUT') {
        puts.add(jsonDecode(req.body) as Map<String, dynamic>);
      }
      return http.Response(jsonEncode({
        'success': true,
        'data': {'playerId': 'shuiyu:67890', 'avatarId': 1, 'profileRevision': '2'},
      }), 200);
    });
    await prefs.setString(CacheKeyConstant.probeDivingFishToken, 'new-session');
    await prefs.setString(CacheKeyConstant.probeDivingFishBindQQ, '67890');
    await store.activate();
    await flush();
    expect(store.value.playerId, 'shuiyu:67890');
    expect(puts.single['playerId'], 'shuiyu:67890');
    expect(puts.single['avatarId'], 73);
    expect(store.value.avatarId, 73);
    expect(store.value.pending, false);
  });

  test('绑定 QQ 不替代已有玩家标记，也不借给落雪或 AWMC', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(CacheKeyConstant.probeDivingFishBindQQ, '67890');
    await prefs.setString(CacheKeyConstant.cachedQQ, '99999');
    ApiClient.debugClient = MockClient((req) async {
      expect(req.url.queryParameters['playerId'], 'shuiyu:12345');
      return http.Response('{}', 403);
    });
    await store.activate();
    await flush();
    expect(store.value.playerId, 'shuiyu:12345');
    var requests = 0;
    ApiClient.debugClient = MockClient((req) async {
      requests++;
      return http.Response('{}', 503);
    });
    for (final source in ['luoxue', 'awmc']) {
      await prefs.setString(CacheKeyConstant.lastDataSource, source);
      await store.activate();
      await flush();
      expect(store.value.playerId, isNull);
    }
    expect(requests, 0);
    await prefs.setString(CacheKeyConstant.lastDataSource, 'shuiyu');
    await prefs.remove(CacheKeyConstant.shuiyuUserId);
    await prefs.remove(CacheKeyConstant.probeDivingFishToken);
    await store.activate();
    await flush();
    expect(store.value.playerId, isNull);
    expect(requests, 0);
  });
  tearDown(() async {
    await flush();
    ApiClient.debugClient = null;
  });

  test('状态级别随同步结果变化，供 Hub 页按语义着色', () async {
    ApiClient.debugClient = MockClient((req) async => http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'playerId': 'shuiyu:12345',
            'avatarId': 1,
            'profileRevision': '2',
          }
        }),
        200));
    await store.activate();
    await flush();
    expect(store.value.message, '社区头像已同步');
    expect(store.value.level, AvatarSyncLevel.synced);
    await store.select(73);
    await flush();
    expect(store.value.level, AvatarSyncLevel.synced);
    // 凭据失效：文案仍为「待同步」，但级别必须是异常（红色），不是黄色。
    ApiClient.debugClient = MockClient((_) async => http.Response('{}', 403));
    await store.select(74);
    await flush();
    expect(store.value.pending, true);
    expect(store.value.level, AvatarSyncLevel.error);
    expect(store.value.message, contains('待同步'));
  });

  test('迁移全局旧头像只归当前玩家；切账号和换同源玩家不串头像', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(CacheKeyConstant.probeDivingFishToken);
    await prefs.setInt('selectedAvatarId', 73);
    await store.activate();
    await flush();
    expect(store.value.avatarId, 73);
    expect(store.value.pending, true);
    await prefs.setString(CacheKeyConstant.lastDataSource, 'awmc');
    await prefs.setString(CacheKeyConstant.awmcUserId, 'awmc:12345');
    await store.activate();
    await flush();
    expect(store.value.avatarId, 1);
    await store.select(99);
    await flush();
    await prefs.setString(CacheKeyConstant.lastDataSource, 'shuiyu');
    await store.activate();
    await flush();
    expect(store.value.avatarId, 73);
    await prefs.setString(CacheKeyConstant.shuiyuUserId, 'shuiyu:67890');
    await store.activate();
    await flush();
    expect(store.value.avatarId, 1);
  });

  test('离线选择持久保留，恢复后重试按 HTTPS 写入且使评论缓存过期', () async {
    var fail = true;
    final puts = <Map<String, dynamic>>[];
    ApiClient.debugClient = MockClient((req) async {
      expect(req.url.scheme, 'https');
      if (fail) return http.Response('{}', 503);
      if (req.method == 'PUT') {
        puts.add(jsonDecode(req.body) as Map<String, dynamic>);
      }
      return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'playerId': 'shuiyu:12345',
              'avatarId': 1,
              'profileRevision': '2',
            }
          }),
          200);
    });
    await store.activate();
    await flush();
    await store.select(73);
    await flush();
    expect(store.value.avatarId, 73);
    expect(store.value.pending, true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        '${CacheKeyConstant.songCommentsCacheTimestampPrefix}test', 123);
    fail = false;
    await store.retry();
    await flush();
    expect(puts.single['avatarId'], 73);
    expect(store.value.pending, false);
    expect(
        prefs.containsKey(
            '${CacheKeyConstant.songCommentsCacheTimestampPrefix}test'),
        false);
  });

  test('连续选择期间旧响应不能清掉新选择或写到切换后的账号', () async {
    final firstPut = Completer<void>();
    final started = Completer<void>();
    final puts = <Map<String, dynamic>>[];
    ApiClient.debugClient = MockClient((req) async {
      if (req.method == 'PUT') {
        puts.add(jsonDecode(req.body) as Map<String, dynamic>);
        if (puts.length == 1) {
          started.complete();
          await firstPut.future;
        }
      }
      return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'playerId': 'shuiyu:12345',
              'avatarId': 1,
              'profileRevision': '3',
            }
          }),
          200);
    });
    await store.activate();
    await flush();
    await store.select(73);
    await started.future;
    await store.select(99);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(CacheKeyConstant.lastDataSource, 'awmc');
    await prefs.setString(CacheKeyConstant.awmcUserId, 'awmc:12345');
    await store.activate();
    firstPut.complete();
    await flush();
    expect(puts.map((e) => e['avatarId']).toList(), [73, 99]);
    expect(puts.every((e) => e['playerId'] == 'shuiyu:12345'), true);
    expect(store.value.playerId, 'awmc:12345');
    expect(store.value.avatarId, 1);
    final stored =
        jsonDecode(prefs.getString('community_avatar_v1_shuiyu:12345')!) as Map;
    expect(stored['avatarId'], 99);
    expect(stored['pending'], false);
  });

  test('409 冲突重取版本但保留用户选择；凭据与活动账号不符时保持待同步', () async {
    var mismatch = false;
    final revisions = <String>[];
    ApiClient.debugClient = MockClient((req) async {
      if (mismatch) return http.Response('{}', 403);
      if (req.method == 'PUT') {
        final body = jsonDecode(req.body) as Map;
        revisions.add(body['expectedProfileRevision'] as String);
        if (revisions.length == 1) {
          return http.Response(
              jsonEncode({
                'success': false,
                'data': {'playerId': 'shuiyu:12345', 'profileRevision': '4'},
              }),
              409);
        }
      }
      return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'playerId': 'shuiyu:12345',
              'avatarId': 1,
              'profileRevision': '2',
            }
          }),
          200);
    });
    await store.activate();
    await flush();
    await store.select(73);
    await flush();
    expect(revisions, ['2', '4']);
    expect(store.value.avatarId, 73);
    expect(store.value.pending, false);
    mismatch = true;
    await store.select(99);
    await flush();
    expect(store.value.pending, true);
    expect(store.value.avatarId, 99);
  });
}
