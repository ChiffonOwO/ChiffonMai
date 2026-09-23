// 设置页「自定义主题色」取色器的回归测试。
//
// 修的是什么：原来用的是 `flutter_colorpicker` 的 `ColorPicker`，它的取色区宽度
// **写死 `colorPickerWidth: 300`**（见 colorpicker-1.1.0/lib/src/colorpicker.dart:283），
// 而手机 AlertDialog 给 content 的宽度只有 280 - 2*24 ≈ 232dp —— 取色区横向溢出，
// 大部分区域摸不到，表现就是「取色器用不了，只能点预设色」。
//
// 现在换成自绘的自适应取色器，这里钉住三件事：
//   1. 在窄屏（360dp 宽的手机）上**没有溢出异常**；
//   2. 点取色区真的会改到颜色（预览色块 / hex 文本跟着变）；
//   3. 色相滑条与"输入十六进制"都能用。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_flutter_app/page/SettingsPage.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';

void main() {
  /// 渲染设置页（等宽 360dp 的常见手机）。
  Future<void> pumpSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme(),
      home: const SettingsPage(),
    ));
    await tester.pumpAndSettle();
  }

  /// 打开取色弹窗。
  Future<void> openPicker(WidgetTester tester) async {
    await tester.tap(find.text('自定义颜色'));
    await tester.pumpAndSettle();
    expect(find.text('自定义主题色'), findsOneWidget);
  }

  testWidgets('设置页把后缀展示成固定的 .cmf', (tester) async {
    await pumpSettings(tester);
    // 说明区要能滚到底（ListView 里）
    await tester.dragUntilVisible(
      find.text('收藏夹导出后缀'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(find.text('收藏夹导出后缀'), findsOneWidget);
    expect(find.text('.cmf'), findsOneWidget);
    // 输入框已移除 → 不该再有"保存"按钮
    expect(find.widgetWithText(FilledButton, '保存'), findsNothing);
  });

  testWidgets('窄屏打开取色器不溢出（以前 ColorPicker 写死 300 宽会溢出）',
      (tester) async {
    await pumpSettings(tester);
    await openPicker(tester);

    expect(tester.takeException(), isNull,
        reason: '取色弹窗在 360dp 宽的手机上不该有 RenderFlex overflow');
    // 取色区必须真的落在弹窗里（宽高都为正）
    final area = tester.getSize(find.byKey(const ValueKey('color-picker-area')));
    expect(area.width, greaterThan(150));
    expect(area.height, greaterThan(100));
    expect(area.width, lessThanOrEqualTo(360));
  });

  testWidgets('点取色区左上角（白）→ 右下角（黑），预览与 hex 跟着变', (tester) async {
    await pumpSettings(tester);
    await openPicker(tester);

    final area = find.byKey(const ValueKey('color-picker-area'));
    final rect = tester.getRect(area);

    // 断言用的是"解析出来的 Color"而不是 hex 字符串：
    // 点在角落时 saturation/value 会带上 (2px / 边长) 的取样偏差，
    // 取到 #FAFCFC 而不是 #FFFFFF 属于正常，拿字符串比会假失败。
    Color previewColor() {
      final container = tester.widget<Container>(
        find.byKey(const ValueKey('color-picker-preview')),
      );
      return (container.decoration! as BoxDecoration).color!;
    }

    // 左上角 = 白（饱和度 0、明度 1）
    await tester.tapAt(rect.topLeft + const Offset(2, 2));
    await tester.pumpAndSettle();
    final white = previewColor();
    expect(white.r, greaterThan(0.95), reason: '左上角应该是白色');
    expect(white.g, greaterThan(0.95));
    expect(white.b, greaterThan(0.95));

    // 右下角 = 黑（明度 0）
    await tester.tapAt(rect.bottomRight - const Offset(2, 2));
    await tester.pumpAndSettle();
    final black = previewColor();
    expect(black.r, lessThan(0.05), reason: '右下角应该是黑色');
    expect(black.g, lessThan(0.05));
    expect(black.b, lessThan(0.05));
  });

  testWidgets('拖动取色区会实时改色（不是点了没反应）', (tester) async {
    await pumpSettings(tester);
    await openPicker(tester);

    final rect = tester.getRect(find.byKey(const ValueKey('color-picker-area')));
    // 先在右上角点一下（纯色相、饱和度/明度都拉满）
    await tester.tapAt(rect.topRight - const Offset(2, -2));
    await tester.pumpAndSettle();
    final afterTap = _previewColor(tester);

    await tester.dragFrom(
      rect.centerRight - const Offset(4, 0),
      Offset(-rect.width / 2, 0),
    );
    await tester.pumpAndSettle();
    final afterDrag = _previewColor(tester);

    expect(afterDrag, isNot(afterTap), reason: '拖动后颜色必须变化');
  });

  testWidgets('色相滑条可用', (tester) async {
    await pumpSettings(tester);
    await openPicker(tester);

    // 先把明度/饱和度点满，让颜色只由色相决定
    final area = tester.getRect(find.byKey(const ValueKey('color-picker-area')));
    await tester.tapAt(area.topRight - const Offset(2, -2));
    await tester.pumpAndSettle();

    final before = _previewColor(tester);
    final sliderRect =
        tester.getRect(find.byKey(const ValueKey('color-hue-slider')));

    // ⚠️ 不要点滑条中点：中点是青色，而默认主题色 #546161 的色相也接近青，
    // 点了颜色不变会假失败。取 1/8 处（橙红一带）才是明确的另一个色相。
    await tester.tapAt(
        Offset(sliderRect.left + sliderRect.width / 8, sliderRect.center.dy));
    await tester.pumpAndSettle();
    final after = _previewColor(tester);
    expect(after, isNot(before), reason: '点色相滑条应该换色相');
    expect(after.r, greaterThan(after.b),
        reason: '1/8 处应该是暖色（红>蓝），说明色相真的跟着走了');
  });

  testWidgets('输入十六进制：合法值生效，非法值给错误提示而不是静默失败',
      (tester) async {
    await pumpSettings(tester);
    await openPicker(tester);

    await tester.tap(find.text('输入十六进制'));
    await tester.pumpAndSettle();
    expect(find.text('输入十六进制颜色'), findsOneWidget);

    // ⚠️ 取色弹窗的「确定」还在下面那一层，必须限定在十六进制弹窗内部找，
    // 否则 find.widgetWithText(TextButton, '确定') 会同时命中两个而报歧义。
    final hexDialog = find.ancestor(
      of: find.text('输入十六进制颜色'),
      matching: find.byType(AlertDialog),
    );
    final confirm = find.descendant(
      of: hexDialog,
      matching: find.widgetWithText(TextButton, '确定'),
    );

    // 非法值：应该就地报错，不关弹窗
    await tester.enterText(find.byType(TextField), '#12');
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(find.textContaining('格式应为'), findsOneWidget,
        reason: '以前是"点确定没反应"，用户不知道哪里错了');
    expect(find.text('输入十六进制颜色'), findsOneWidget);

    // 合法值：关闭并回填到取色器预览
    await tester.enterText(find.byType(TextField), '#123456');
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(find.text('输入十六进制颜色'), findsNothing, reason: '合法值应该关掉弹窗');
    expect(_previewColor(tester), const Color(0xFF123456),
        reason: '输入的颜色要回填到预览，而不是被丢掉');
  });
}

/// 取色器弹窗里的预览色块颜色。
Color _previewColor(WidgetTester tester) {
  final container = tester.widget<Container>(
    find.byKey(const ValueKey('color-picker-preview')),
  );
  return (container.decoration! as BoxDecoration).color!;
}
