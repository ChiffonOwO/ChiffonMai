import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_first_flutter_app/constant/CacheKeyConstant.dart';
import 'package:my_first_flutter_app/service/CommunityNicknameSyncService.dart';
import 'package:my_first_flutter_app/utils/ApiClient.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({
      CacheKeyConstant.probeDivingFishToken: 'test-session',
    });
  });
  tearDown(() => ApiClient.debugClient = null);
  Future<bool> sync(String name, {String player = 'shuiyu:12345'}) =>
      CommunityNicknameSyncService.syncFreshNickname(
          playerId: player, nickname: name);
  http.Response response(String player, String name, String revision,
          {int status = 200}) =>
      http.Response(
          jsonEncode({
            'success': status == 200,
            if (status == 409) 'code': 'PROFILE_CONFLICT',
            'data': {
              'playerId': player,
              'nickname': name,
              'profileRevision': revision,
            },
          }),
          status,
          headers: {'content-type': 'application/json; charset=utf-8'});

  test('same player syncs a renamed nickname without rating or privacy fields',
      () async {
    final puts = <Map<String, dynamic>>[];
    ApiClient.debugClient = MockClient((req) async {
      expect(req.url.scheme, 'https');
      expect(req.url.path, '/api/me/nickname');
      expect(req.headers['Authorization'], 'Bearer test-session');
      if (req.method == 'GET') return response('shuiyu:12345', '旧昵称', '8');
      puts.add(jsonDecode(req.body) as Map<String, dynamic>);
      return response('shuiyu:12345', '新昵称', '9');
    });
    expect(await sync('新昵称'), true);
    expect(puts.single, {
      'playerId': 'shuiyu:12345',
      'nickname': '新昵称',
      'expectedProfileRevision': '8',
    });
  });

  test('concurrent avatar revision conflict retries with the latest revision',
      () async {
    final revisions = <String>[];
    ApiClient.debugClient = MockClient((req) async {
      if (req.method == 'GET') return response('shuiyu:12345', '旧昵称', '8');
      revisions.add(jsonDecode(req.body)['expectedProfileRevision'] as String);
      return revisions.length == 1
          ? response('shuiyu:12345', '旧昵称', '9', status: 409)
          : response('shuiyu:12345', '新昵称', '10');
    });
    expect(await sync('新昵称'), true);
    expect(revisions, ['8', '9']);
  });

  test('rapid renames remain ordered and captured accounts never change target',
      () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final puts = <Map<String, dynamic>>[];
    ApiClient.debugClient = MockClient((req) async {
      final player = req.method == 'GET'
          ? req.url.queryParameters['playerId']!
          : jsonDecode(req.body)['playerId'] as String;
      if (req.method == 'GET' && !started.isCompleted) {
        started.complete();
        await release.future;
      }
      if (player.startsWith('awmc:')) {
        expect(req.headers['X-Profile-QQ'], '67890');
        expect(req.headers.containsKey('Authorization'), false);
      }
      if (req.method == 'GET') return response(player, '旧昵称', '1');
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      puts.add(body);
      return response(player, body['nickname'] as String, '2');
    });
    final first = sync('第一次改名');
    await started.future;
    final second = sync('第二次改名');
    final third = sync('另一个账号', player: 'awmc:67890');
    release.complete();
    expect(await Future.wait([first, second, third]), [true, true, true]);
    expect(puts.map((body) => body['nickname']), ['第一次改名', '第二次改名', '另一个账号']);
    expect(puts.map((body) => body['playerId']),
        ['shuiyu:12345', 'shuiyu:12345', 'awmc:67890']);
  });

  test('unchanged names and anonymous placeholders do not issue PUT', () async {
    var requests = 0;
    ApiClient.debugClient = MockClient((req) async {
      requests++;
      expect(req.method, 'GET');
      return response('shuiyu:12345', '新昵称', '8');
    });
    expect(await sync(' 新昵称 '), true);
    expect(await sync('匿名用户'), false);
    expect(await sync(''), false);
    expect(requests, 1);
  });

  test('auth failures and mismatched player responses fail without a write',
      () async {
    ApiClient.debugClient = MockClient((_) async => http.Response('{}', 401));
    expect(await sync('新昵称'), false);
    ApiClient.debugClient = MockClient((req) async {
      expect(req.method, 'GET');
      return response('shuiyu:99999', '旧昵称', '8');
    });
    expect(await sync('新昵称'), false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(CacheKeyConstant.probeDivingFishToken);
    expect(await sync('新昵称'), false);
  });
}
