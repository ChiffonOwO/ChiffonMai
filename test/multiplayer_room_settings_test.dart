// 回归：多人建房页的「模式专属设置」滑条初值必须取自**已保存的单人猜歌设置**。
//
// 真实反馈：用户刚在单人「曲绘拼图」里把切块数调成 2500，进多人房间却还是
// 1000 块 / 1500ms，看起来就像「设置没同步到服务器」。实际原因是建房页的滑条
// 一直从硬编码默认值起步（房间参数与单人设置是两套，但初值不该无视用户设置）。
//
// 这里锁住：初值来自单人设置。房间参数真正上行到服务端的契约由
// test/multiplayer_payload_test.dart 对着真实报文校验。
//
// 注意：flutter_test 里同一个文件内多次 pumpWidget 建房页时，第二次起
// `_loadSongData` 的资产加载不会再返回（测试环境特性），页面会停在加载态、
// 渲染不出模式按钮。所以三档模式的断言放在**同一个**页面实例里顺序切换。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_first_flutter_app/entity/Multiplayer/GameType.dart';
import 'package:my_first_flutter_app/page/Multiplayer/RoomCreatePage.dart';
import 'package:my_first_flutter_app/service/GuessChartGame/GuessChartCommonSettingsService.dart';

/// 模式选择已从下拉框改成**平铺按钮**：点按钮上的文字即选中该模式。
Future<void> _switchMode(WidgetTester tester, String label) async {
  final option = find.text(label);
  expect(option, findsWidgets, reason: '建房页应把「$label」平铺成按钮');
  await tester.ensureVisible(option.first);
  await tester.pumpAndSettle();
  await tester.tap(option.first);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('建房页的模式专属滑条初值取自单人猜歌设置', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await GuessChartCommonSettingsService().saveSettings(
      selectedVersions: const [],
      masterMinDx: 1.0,
      masterMaxDx: 15.0,
      selectedGenres: const [],
      maxGuesses: 10,
      timeLimit: 0,
      flashDurationMs: 1200,
      tileCount: 2500,
      tileRevealIntervalMs: 800,
      peekDurationSeconds: 20,
      peekDifficulties: const ['3', '5'],
    );

    await tester.pumpWidget(const MaterialApp(home: RoomCreatePage()));
    // 等资产加载完、模式按钮出现（页面加载态没有按钮）
    final anyMode = find.text(GameType.info.name);
    for (var i = 0; i < 60 && !tester.any(anyMode); i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // 九个模式都平铺出来了（不再有下拉框）
    expect(find.byType(DropdownButton<GameType>), findsNothing,
        reason: '模式选择应平铺展开，不再是下拉框');
    for (final type in GameType.values) {
      expect(find.text(type.name), findsWidgets, reason: '缺模式按钮「${type.name}」');
    }

    // 曲绘拼图：切块数 / 揭示间隔
    await _switchMode(tester, '曲绘拼图');
    expect(find.text('2500 块'), findsOneWidget,
        reason: '切块数应沿用单人拼图设置，而不是硬编码的 1000');
    expect(find.text('800 ms'), findsOneWidget,
        reason: '揭示间隔应沿用单人拼图设置，而不是硬编码的 1500');

    // 曲绘快闪：快闪时长
    await _switchMode(tester, '曲绘快闪');
    expect(find.text('1200 ms'), findsOneWidget,
        reason: '快闪时长应沿用单人曲绘快闪设置');

    // 谱面片段：片段时长
    await _switchMode(tester, '谱面片段');
    expect(find.text('20 秒'), findsOneWidget,
        reason: '片段时长应沿用单人谱面片段设置');

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump(const Duration(seconds: 1));
  });
}
