import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_first_flutter_app/api/ApiUrls.dart';
import 'package:my_first_flutter_app/utils/ApiClient.dart';
import 'package:my_first_flutter_app/utils/TranslationUtil.dart';

void main() {
  tearDown(() {
    ApiClient.debugClient?.close();
    ApiClient.debugClient = null;
  });

  test('客户端仅向自家接口提交内容与语言，并缓存成功译文', () async {
    var calls = 0;
    ApiClient.debugClient = MockClient((request) async {
      calls++;
      expect(request.method, 'POST');
      expect(request.url.toString(), ApiUrls.TranslationUrl);
      expect(jsonDecode(request.body),
          {'q': 'proxy-test', 'from': 'en', 'to': 'zh'});
      return http.Response.bytes(
          utf8.encode(jsonEncode({'translation': '代理测试'})), 200,
          headers: {'Content-Type': 'application/json; charset=utf-8'});
    });
    expect(await TranslateService.enToZh('proxy-test'), '代理测试');
    expect(await TranslateService.enToZh('proxy-test'), '代理测试');
    expect(calls, 1);
  });

  test('服务端未配置或失败时返回 null，失败后允许重试', () async {
    ApiClient.debugClient = MockClient((_) async => http.Response('{}', 503));
    expect(await TranslateService.translate('retry-test'), isNull);
    ApiClient.debugClient = MockClient((_) async =>
        http.Response(jsonEncode({'translation': 'retry success'}), 200));
    expect(await TranslateService.translate('retry-test'), 'retry success');
  });
}
