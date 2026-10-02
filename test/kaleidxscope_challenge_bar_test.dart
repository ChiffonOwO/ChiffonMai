// 「KALEIDXSCOPE 门详细页的难度时间条」的回归测试。
//
// 起因（真机反馈）：最终相详情的「挑战条件」里，9 段放宽表被 24dp 高的胶囊按
// **阶段数**等宽切开，每格只有约 30dp；`Re:MASTER` / `MASTER` / `EXPERT` 的全名
// 在格子里换行（并被 `ClipRRect` 切掉），非常难看。
//
// 现在的口径：
//   1. 每个阶段的难度名**一行显示、不换行、不省略**（`RenderParagraph.didExceedMaxLines`
//      为 false）；
//   2. 9 段在 360dp 屏上折成多行（每行放得下几段就放几段），每行高度仍是 24dp；
//   3. 窄屏/大系统字号下允许整格等比缩小，但**不能换行**；
//   4. 阶段数少的时候仍然是单行一条（与改动前观感一致，只有最终相这种长表才折行）。
//
// 这里用真实页面 + 打桩接口，并先断言正文渲染出来了：页面停在加载/错误态时
// 「找不到难度文字」会假通过。
import 'dart:convert';

import 'package:flutter/material.dart';
// RenderParagraph 来自 rendering，material.dart 不导出它（缺这行 analyze 会报
// non_type_as_type_argument —— 与本次备案改造无关的既有报错，顺手补上）。
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_first_flutter_app/page/KaleidXScope/KaleidXScopeGatePage.dart';
import 'package:my_first_flutter_app/utils/ApiClient.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';

/// 最终相的 9 段放宽表（与 `assets/kaleidscope/stage2.json` 同构，只留难度）。
const List<String> kFinalDifficulties = [
  'Re:MASTER',
  'Re:MASTER',
  'Re:MASTER',
  'Re:MASTER',
  'MASTER',
  'MASTER',
  'MASTER',
  'EXPERT',
  'BASIC',
];

/// 常规门（棱镜塔：6 段）——用来钉住「放得下时仍是单行」。
const List<String> kPrismDifficulties = [
  'MASTER',
  'MASTER',
  'MASTER',
  'MASTER',
  'EXPERT',
  'BASIC',
];

List<Map<String, dynamic>> _phases(List<String> difficulties) => [
      for (var i = 0; i < difficulties.length; i++)
        {
          'startDate': '2026-10-${(i + 1).toString().padLeft(2, '0')}',
          'endDate': '2026-10-${(i + 2).toString().padLeft(2, '0')}',
          'difficulty': difficulties[i],
          'lifeTarget': i + 1,
        },
    ];

Map<String, dynamic> _gateJson(String color, List<String> difficulties) => {
      'id': 1,
      'color': color,
      'name': 'GATE',
      'displayName': '测试门',
      'doorName': 'GATE',
      'prerequisite': '前置条件',
      'keyRequirement': '钥匙',
      'songs': <String, List<int>>{},
      'challenges': [
        {
          'name': '${color}挑战条件（来源推算）',
          'phases': _phases(difficulties),
        },
      ],
      'specialSongs': <dynamic>[],
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String mockedColor;
  late List<String> mockedDifficulties;

  setUp(() {
    mockedColor = 'final';
    mockedDifficulties = kFinalDifficulties;
    SharedPreferences.setMockInitialValues({});
    ApiClient.debugClient = MockClient((request) async {
      // 必须带 charset=utf-8：`http.Response(String)` 默认按 latin1 编码。
      const jsonHeaders = {'content-type': 'application/json; charset=utf-8'};
      if (request.url.path.contains('/gates/')) {
        return http.Response(
            jsonEncode({
              'success': true,
              'data': _gateJson(mockedColor, mockedDifficulties),
            }),
            200,
            headers: jsonHeaders);
      }
      return http.Response(jsonEncode({'success': false}), 404,
          headers: jsonHeaders);
    });
  });

  tearDown(() {
    ApiClient.debugClient = null;
  });

  Future<void> pumpGate(
    WidgetTester tester, {
    double width = 375,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = Size(width * 3, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    // 测试环境的默认字体是等宽方块字，正文里个别一行会横向溢出 —— 既有现象，
    // 只放过「overflowed by」，其它异常照旧让测试挂。
    final errors = <Object>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.exception);
    try {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme(),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: KaleidXScopeGatePage(color: mockedColor, title: '测试门'),
        ),
      ));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    } finally {
      FlutterError.onError = previousOnError;
    }

    final unexpected =
        errors.where((e) => !e.toString().contains('overflowed by')).toList();
    expect(unexpected, isEmpty, reason: '除了既有横向溢出，不该再报别的渲染异常');
  }

  /// 每一个难度标签都必须**单行显示**（`didExceedMaxLines` 只反映 maxLines 的截断，
  /// 所以这里找的是 `RenderParagraph`：换行与否看它自己的尺寸与 lineCount）。
  void expectNoLabelWrapped(WidgetTester tester, List<String> difficulties) {
    for (final label in difficulties.toSet()) {
      final finder = find.text(label);
      expect(finder, findsWidgets, reason: '$label 没渲染出来，断言会假通过');
      final count = finder.evaluate().length;
      for (var i = 0; i < count; i++) {
        final paragraph = tester.renderObject<RenderParagraph>(finder.at(i));
        expect(paragraph.didExceedMaxLines, isFalse,
            reason: '「$label」被省略号截断了');
        // 一行的高度 ≈ 单倍行高；换行后会接近两倍。
        final lines = paragraph.size.height / paragraph.text.style!.fontSize!;
        expect(lines, lessThan(1.8),
            reason: '「$label」在自己的格子里换行/被撑高了（height=${paragraph.size.height}）');
      }
    }
  }

  testWidgets('最终相 9 段：难度名一行一个，不换行不省略，且折成多行', (tester) async {
    await pumpGate(tester);

    expect(find.text('final挑战条件（来源推算）'), findsOneWidget,
        reason: '先证明挑战条件正文真的渲染出来了');

    expectNoLabelWrapped(tester, mockedDifficulties);

    // 折行的证据：同一行的相邻格子垂直位置相同，且至少存在两种不同的 top。
    final reMaster = find.text('Re:MASTER');
    final basics = find.text('BASIC');
    final tops = <double>{
      for (var i = 0; i < reMaster.evaluate().length; i++)
        tester.getRect(reMaster.at(i)).top,
      tester.getRect(basics).top,
    };
    expect(tops.length, greaterThan(1),
        reason: '9 段在 375dp 屏上必须折成多行，不该还挤在一条线上');

    // 每格高度仍是那条 24dp 的胶囊高度
    for (var i = 0; i < reMaster.evaluate().length; i++) {
      expect(tester.getRect(reMaster.at(i)).height, lessThan(24.0),
          reason: '标签必须装得进 24dp 的胶囊');
    }
  });

  testWidgets('最终相 9 段 @ textScale 1.5：仍然不换行（允许整格缩小）', (tester) async {
    await pumpGate(tester, textScale: 1.5);

    expect(find.text('final挑战条件（来源推算）'), findsOneWidget);
    expectNoLabelWrapped(tester, mockedDifficulties);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320dp 极窄屏：仍然不换行', (tester) async {
    await pumpGate(tester, width: 320);

    expect(find.text('final挑战条件（来源推算）'), findsOneWidget);
    expectNoLabelWrapped(tester, mockedDifficulties);
  });

  testWidgets('阶段数少的门（棱镜塔 6 段）：宽屏下仍然是单行一条', (tester) async {
    mockedColor = 'prism';
    mockedDifficulties = kPrismDifficulties;
    // 测试环境用的是等宽方块字体，比真机思源黑体宽得多；给足宽度才能验证
    // 「放得下就不折行」这条规则本身，而不是被测试字体宽度带偏。
    await pumpGate(tester, width: 900);

    expect(find.text('prism挑战条件（来源推算）'), findsOneWidget);
    expectNoLabelWrapped(tester, mockedDifficulties);

    final tops = <double>{
      for (final label in {'MASTER', 'EXPERT', 'BASIC'})
        tester.getRect(find.text(label).first).top,
    };
    expect(tops.length, 1, reason: '放得下时必须是单行，观感与改动前一致');
  });
}
