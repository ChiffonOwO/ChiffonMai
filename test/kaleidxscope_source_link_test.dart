// 「KALEIDXSCOPE 门详细页只保留顶部那一条数据来源链接」的回归测试。
//
// 需求：所有门详细页的数据来源链接**只留顶部**（标题栏下面 / `PageTopBar.bottom` 里的
// [KaleidXScopeSourceNotice]），底部那条来源文字按钮删除。
//
// ⚠️ 这里用真实页面 + 打桩的接口，并且**先断言攻略正文确实渲染出来了**：
// 底部那条链接原本长在正文最下面（`gate.specialSongs` 非空才渲染），页面要是停在
// 加载/错误态，「找不到底部链接」就是假通过。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_first_flutter_app/page/KaleidXScope/KaleidXScopeGatePage.dart';
import 'package:my_first_flutter_app/utils/ApiClient.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:my_first_flutter_app/widgets/KaleidXScopeSourceNotice.dart';

/// 门详细页（6 个颜色门 + 新增的颜色门页）。
const List<String> kGateDetailPages = [
  'KaleidXScopeInfoPageBLUE.dart',
  'KaleidXScopeInfoPageWHITE.dart',
  'KaleidXScopeInfoPagePURPLE.dart',
  'KaleidXScopeInfoPageBLACK.dart',
  'KaleidXScopeInfoPageYELLOW.dart',
  'KaleidXScopeInfoPageRED.dart',
  'KaleidXScopeGatePage.dart',
];

/// 一份「有特殊曲」的最小门数据：老代码正是在 `specialSongs` 非空时
/// 才在正文最下面渲染那个底部来源按钮。
Map<String, dynamic> _prismGateJson() => {
      'id': 1,
      'color': 'prism',
      'name': 'PRISM',
      'displayName': 'PRISM 门',
      'doorName': 'PRISM',
      'prerequisite': '完成前置条件',
      'keyRequirement': '钥匙',
      'track1Desc': '第一首曲目',
      'songs': <String, List<int>>{},
      'challenges': <dynamic>[],
      'specialSongs': [
        {'songId': 11739, 'role': 'reward'},
      ],
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiClient.debugClient = MockClient((request) async {
      // 必须带 charset=utf-8：`http.Response(String)` 默认按 latin1 编码，
      // 门数据里的中文（门名 / 钥匙说明）会直接抛 "Contains invalid characters"。
      const jsonHeaders = {'content-type': 'application/json; charset=utf-8'};
      if (request.url.path.endsWith('/gates/prism')) {
        return http.Response(
            jsonEncode({'success': true, 'data': _prismGateJson()}), 200,
            headers: jsonHeaders);
      }
      return http.Response(jsonEncode({'success': false}), 404,
          headers: jsonHeaders);
    });
  });

  tearDown(() {
    ApiClient.debugClient = null;
  });

  testWidgets('门详细页整页只剩顶部一条数据来源链接', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme(),
      home: const KaleidXScopeGatePage(color: 'prism', title: 'PRISM'),
    ));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // 测试环境的默认字体比真机思源黑体宽，正文里个别一行会横向溢出 ——
    // 既有现象、与本次改动无关，只放过溢出这一种异常。
    for (Object? ex = tester.takeException();
        ex != null;
        ex = tester.takeException()) {
      final text = ex.toString();
      if (!text.contains('overflowed by')) {
        throw ex;
      }
      debugPrint('[已忽略的既有溢出] ${text.split('\n').first}');
    }

    // 1) 先证明攻略正文真的渲染了（底部那个按钮原本就在这段内容的最下面）
    expect(find.text('解锁方法'), findsOneWidget,
        reason: '门数据加载完必须渲染出攻略正文，否则下面的断言会假通过');

    // 2) 数据来源链接：整页只有顶部那一条，且位于正文上方
    final notice = find.byType(KaleidXScopeSourceNotice);
    expect(notice, findsOneWidget);
    expect(
        find.descendant(of: notice, matching: find.byIcon(Icons.open_in_new)),
        findsOneWidget,
        reason: '顶部来源条自带一个「打开外部链接」图标');
    expect(tester.getRect(notice).bottom,
        lessThan(tester.getRect(find.text('解锁方法')).top),
        reason: '唯一的数据来源链接必须在正文上方（顶部）');

    // 3) 底部那个文字按钮（含它自己的 open_in_new 图标）已经删除
    expect(find.textContaining('查看攻略来源'), findsNothing);
    expect(find.byIcon(Icons.open_in_new), findsOneWidget,
        reason: '整页只应剩下顶部来源条里的那个图标');
  });

  test('7 个门详细页都挂着顶部来源条，且没有任何页面自己开外部链接', () {
    for (final name in kGateDetailPages) {
      final src = File('lib/page/KaleidXScope/$name').readAsStringSync();
      expect(src.contains('KaleidXScopeSourceNotice'), isTrue,
          reason: '$name 顶部那条数据来源链接不能少');
      expect(src.contains('查看攻略来源'), isFalse,
          reason: '$name 又出现了底部那条来源文字链');
      expect(src.contains('launchUrl'), isFalse,
          reason: '$name 又自己打开了外部链接；来源链接只走 KaleidXScopeSourceNotice');
    }
  });

  test('来源 URL 全仓库只有 KaleidXScopeSourceNotice 一处', () {
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('KaleidXScopeSourceNotice.dart')) continue;
      expect(
          entity.readAsStringSync().contains('kaleidxscope.awmc.team'), isFalse,
          reason: '${entity.path} 又手写了来源 URL；'
              '来源链接只应有 KaleidXScopeSourceNotice.sourceUri 一处');
    }
  });
}
