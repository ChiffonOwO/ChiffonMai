// 「发现新版本」按钮的显示逻辑单测。
//
// 这条逻辑链上最容易错的两点：
//   1. `hasUpdate` 的判定必须严格看 true，云端返回的 networkError 分支不能当成有更新；
//   2. 按钮标题变了、但**收藏列表里存的名字没变**（仍然是「检查更新」），
//      所以匹配收藏项必须用 idleTitle 而不是当前显示标题 —— 否则星标会失效。
import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_flutter_app/utils/UpdateNotifier.dart';

Map<String, dynamic> _result({
  required bool hasUpdate,
  String latestVersion = '9.9.9',
  Object? latestBuild = 99,
  bool networkError = false,
}) =>
    <String, dynamic>{
      'hasUpdate': hasUpdate,
      if (!networkError) 'latestVersion': latestVersion,
      if (!networkError) 'latestBuild': latestBuild,
      if (networkError) 'networkError': true,
      'updateLog': '一些更新内容',
    };

void main() {
  group('UpdateAvailability.fromCheckResult', () {
    test('hasUpdate=true 时解析出版本信息', () {
      final info = _result(hasUpdate: true, latestVersion: '2.2.0', latestBuild: 42);
      final parsed = UpdateAvailability.fromCheckResult(info);
      expect(parsed, isNotNull);
      expect(parsed!.latestVersion, '2.2.0');
      expect(parsed.latestBuild, 42);
    });

    test('hasUpdate=false 时返回 null（按钮保持「检查更新」）', () {
      expect(UpdateAvailability.fromCheckResult(_result(hasUpdate: false)),
          isNull);
    });

    test('网络失败不能当成有更新', () {
      final info = _result(hasUpdate: false, networkError: true);
      expect(UpdateAvailability.fromCheckResult(info), isNull);
    });

    test('latestBuild 是字符串时也能解析', () {
      final parsed = UpdateAvailability.fromCheckResult(
          _result(hasUpdate: true, latestBuild: '2038'));
      expect(parsed!.latestBuild, 2038);
    });

    test('hasUpdate 是「真值字符串」不算有更新（必须严格 true）', () {
      expect(
        UpdateAvailability.fromCheckResult(<String, dynamic>{'hasUpdate': 'true'}),
        isNull,
      );
    });
  });

  group('按钮文案', () {
    final update = UpdateAvailability.fromCheckResult(
        _result(hasUpdate: true, latestVersion: '2.2.0'))!;

    test('无更新 → 原样', () {
      expect(UpdateNotifier.titleFor(null), UpdateNotifier.idleTitle);
      expect(UpdateNotifier.subtitleFor(null, '原副标题'), '原副标题');
    });

    test('有更新 → 「发现新版本」+ 带版本号的副标题', () {
      expect(UpdateNotifier.titleFor(update), '发现新版本');
      expect(UpdateNotifier.subtitleFor(update, '原副标题'), contains('v2.2.0'));
    });

    test('版本号缺失时不显示空的 v', () {
      final noVersion = UpdateAvailability.fromCheckResult(
          _result(hasUpdate: true, latestVersion: ''));
      final subtitle = UpdateNotifier.subtitleFor(noVersion!, 'x');
      expect(subtitle, isNot(contains('v 已')));
      expect(subtitle, contains('新版本'));
    });
  });

  group('收藏项匹配', () {
    test('按钮已显示「发现新版本」，收藏项名字仍是「检查更新」', () {
      // 收藏列表里存的是 FeatureRegistry 的静态标题，不受按钮形态影响
      expect(UpdateNotifier.isUpdateEntry(UpdateNotifier.idleTitle), isTrue);
      expect(UpdateNotifier.isUpdateEntry('发现新版本'), isFalse);
      expect(UpdateNotifier.isUpdateEntry('随身听'), isFalse);
      expect(UpdateNotifier.isUpdateEntry(null), isFalse);
    });
  });

  group('setResult', () {
    setUp(UpdateNotifier.debugReset);
    tearDown(UpdateNotifier.debugReset);

    test('写入有更新后 available 非空，且 checked 置位', () {
      expect(UpdateNotifier.checked, isFalse);
      UpdateNotifier.setResult(_result(hasUpdate: true));
      expect(UpdateNotifier.checked, isTrue);
      expect(UpdateNotifier.available.value, isNotNull);
    });

    test('写入无更新时清空（例如用户刚更新完又点了一次）', () {
      UpdateNotifier.setResult(_result(hasUpdate: true));
      expect(UpdateNotifier.available.value, isNotNull);
      UpdateNotifier.setResult(_result(hasUpdate: false));
      expect(UpdateNotifier.available.value, isNull);
    });

    test('传 null（检查抛异常）时清空且标记已查过', () {
      UpdateNotifier.setResult(null);
      expect(UpdateNotifier.available.value, isNull);
      expect(UpdateNotifier.checked, isTrue);
    });
  });
}
