import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_first_flutter_app/widgets/QrQuickFillButtons.dart';
import 'package:my_first_flutter_app/widgets/SyncScoreDialogs.dart'
    show showDivingFishSyncInputDialog, showLuoXueSyncInputDialog;

/// 二维码「快速填入」三件套的回归测试。
///
/// 起因：「同步成绩到水鱼」有读取剪贴板 / 从相册识别 / 扫描二维码三个按钮，
/// 而「同步成绩到落雪」只做了「读取剪贴板」一个（手工检查才发现），
/// 两边体验不一致。这里把「两个对话框都必须有这三个按钮」钉成断言，
/// 免得以后再漏。
void main() {
  const threeButtons = ['读取剪贴板', '从相册识别', '扫描二维码'];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // fluttertoast 走平台通道，测试环境里没有实现
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('fluttertoast'),
      (call) async => null,
    );
  });

  Future<void> pumpAndOpen(
    WidgetTester tester,
    Future<void> Function(BuildContext context) open,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => open(context),
                child: const Text('打开对话框'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开对话框'));
    await tester.pumpAndSettle();
  }

  testWidgets('同步成绩到落雪：三个快速填入按钮都在', (tester) async {
    await pumpAndOpen(tester, (ctx) async {
      await showLuoXueSyncInputDialog(ctx);
    });

    expect(find.text('同步成绩到落雪'), findsOneWidget);
    for (final label in threeButtons) {
      expect(find.text(label), findsOneWidget, reason: '落雪对话框缺少「$label」');
    }
    // 二维码输入框与提交按钮仍在
    expect(find.text('开始同步'), findsOneWidget);
  });

  testWidgets('同步成绩到水鱼：三个快速填入按钮都在', (tester) async {
    await pumpAndOpen(tester, (ctx) async {
      await showDivingFishSyncInputDialog(ctx);
    });

    expect(find.text('同步成绩到水鱼'), findsOneWidget);
    for (final label in threeButtons) {
      expect(find.text(label), findsOneWidget, reason: '水鱼对话框缺少「$label」');
    }
  });

  testWidgets('公共组件 QrQuickFillButtons：读取剪贴板真的会写进控制器', (tester) async {
    // 剪贴板走 SystemChannels.platform，测试里给它一个假实现
    const qrText = 'SGWCMAID1234567890ABCDEFGHIJ';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return <String, dynamic>{'text': '  $qrText  '}; // 带空白，应被 trim
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var filled = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QrQuickFillButtons(
            controller: controller,
            onFilled: () => filled++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('读取剪贴板'));
    await tester.pumpAndSettle();

    expect(controller.text, qrText, reason: '应把剪贴板内容 trim 后填入');
    expect(filled, 1, reason: 'onFilled 回调应触发一次（用于清旧错误提示）');
  });

  testWidgets('QrQuickFillButtons：enabled=false 时三个按钮都禁用', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QrQuickFillButtons(controller: controller, enabled: false),
        ),
      ),
    );

    for (final label in threeButtons) {
      final button = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(button.onPressed, isNull, reason: '「$label」应当被禁用');
    }
  });
}
