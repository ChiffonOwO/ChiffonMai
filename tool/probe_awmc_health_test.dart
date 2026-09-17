// 探针：AWMC 网关自检（**0 Token**，只打 `/v1/health`）。
//
// 用途：同步失败时，先分清三种情况 ——
//   1) 假令牌拿不到 401  → 网关/CDN 本身不可达（不是你的令牌问题）；
//   2) 假令牌 401、真令牌却超时/502 → 网关对**有效令牌**的请求不响应
//      （实测出现过：带有效令牌的请求直接不回包，源站却是活的）；
//   3) 真令牌也返回 200 → 网关正常，问题在同步的具体接口或第三方凭据。
//
// 运行：flutter test tool/probe_awmc_health_test.dart
//
// 探针本来就在 test 之外，`@visibleForTesting` / mock 本就是测试用法
// ignore_for_file: avoid_print, invalid_use_of_visible_for_testing_member
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_first_flutter_app/service/AWMC/AwmcApiService.dart';
import 'package:my_first_flutter_app/service/AWMC/AwmcStore.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> probe(WidgetTester tester, String label, String token) async {
    await tester.runAsync(() async {
      // flutter_test 默认把 HttpClient 换成桩（一律 400），置空才走真网络
      final saved = HttpOverrides.current;
      HttpOverrides.global = null;
      try {
        final r = await AwmcApiService.health(
          token: token,
          timeout: const Duration(seconds: 20),
        );
        print('[AWMC 自检] $label → ok=${r.ok} http=${r.httpStatus} '
            '耗时=${r.elapsedMs}ms 文案=${r.displayMessage}');
      } finally {
        HttpOverrides.global = saved;
      }
    });
  }

  testWidgets('假令牌：判断网关是否可达（期望 401）', (tester) async {
    await probe(tester, '假令牌', 'gw_invalid_probe_token_zzz');
  });

  testWidgets('本机令牌：判断网关是否对有效令牌正常回包', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AwmcCredentials.ensureLoaded();
    final token = AwmcCredentials.token;
    print('[AWMC 自检] 使用令牌来源=${AwmcCredentials.tokenSource} '
        '${AwmcCredentials.maskedToken}');
    if (token.isEmpty) {
      print('[AWMC 自检] 没有可用令牌，跳过');
      return;
    }
    await probe(tester, '本机令牌', token);
  });
}
