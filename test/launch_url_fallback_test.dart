import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_flutter_app/constant/AppLinks.dart';
import 'package:my_first_flutter_app/widgets/RefreshDataDialog.dart'
    show launchUrlFallback;

/// 外链打不开时的兜底：**复制到剪贴板 + 明确提示**。
///
/// 需求来源（系统 hub 新增的两个按钮）：官网跳不动要把链接复制给用户，
/// 加群页跳不动要复制**群号**（`qm.qq.com` 的链接粘到浏览器里只是个空壳
/// 中转页，复制链接等于没帮上忙），两种情况都要在界面上说清楚。
void main() {
  late List<String> copied;

  setUp(() {
    copied = <String>[];
    // 拦下剪贴板通道：既能看到到底复制了什么，也避免碰真实平台通道
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => launchUrlFallback(
              AppLinks.qqGroupJoinUrl,
              context,
              copyText: AppLinks.qqGroupNumber,
              message: '没能跳转到 QQ，群号 ${AppLinks.qqGroupNumber} 已复制到剪贴板',
            ),
            child: const Text('fallback'),
          ),
        ),
      ),
    ));
  }

  testWidgets('默认：复制链接本身 + 通用提示', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => launchUrlFallback(AppLinks.officialSite, context),
            child: const Text('fallback'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('fallback'));
    await tester.pump();

    expect(copied, [AppLinks.officialSite]);
    expect(find.textContaining('已复制到剪贴板'), findsOneWidget);
  });

  testWidgets('可以换成复制群号，并给出对应提示', (tester) async {
    await pumpHost(tester);

    await tester.tap(find.text('fallback'));
    await tester.pump();

    expect(copied, [AppLinks.qqGroupNumber],
        reason: '加群链接在浏览器里没用，必须复制群号');
    expect(find.byType(SnackBar), findsOneWidget,
        reason: '必须看得见提示，不能只是静默复制');
    expect(find.textContaining('群号 291826702 已复制到剪贴板'), findsOneWidget);
    // 提示带一个关闭按钮（文案由调用方给，这里验证框架那层还在）
    expect(find.text('知道了'), findsOneWidget);
  });
}
