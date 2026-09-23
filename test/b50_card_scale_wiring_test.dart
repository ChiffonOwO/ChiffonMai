// 回归：卡片字号必须由 `B50GameCardWidget` 自己按**实际宽度**算 ——
// 页面里不许再手抄 `((screenW - screenW * 0.0x) / 2) / 335`。
//
// 为什么：`screenW` 是屏幕宽，卡片可见宽度还要扣掉容器 padding、列表 margin、
// 网格列间距 —— 实测差 ~9%，于是"同一套卡片模板，6 个页面字号各不相同"。
// 页面（Best50 系列 / 单曲成绩搜索）都要联网+登录才能 pump，所以这条断言只能
// 用"扫源码"的形式，但它锁的正是那条口径：
//
//   1. 7 个用卡片的页面：不许出现 `cardW` / `refCardWidth`，
//      且卡片必须显式写 `scale: B50GameCardWidget.autoScale`；
//   2. 4 个导出服务：必须显式 `scale: 1.0`（导出基准宽度
//      [B50GameCardWidget.refCardWidth] = 335 就是照它标定的）；
//   3. 屏幕口径 [B50GameCardWidget.screenRefCardWidth]（≈308，比导出基准大
//      8.8%）：**别退回 335** —— 退回就等于卡片内容整体小一圈（反馈：
//      "曲绘、评级连击同步图片和文本字号都变小了"）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_flutter_app/widgets/B50GameCardWidget.dart';

/// 页面上用到卡片的地方：文件 → 页面名。
const Map<String, String> _cardPages = {
  'lib/page/Best50/Best50Page.dart': 'Best50',
  'lib/page/Best50/DiffBest50Page.dart': '拟合 Best50',
  'lib/page/Best50/PersonalizedBest50Page.dart': '个性化 Best50',
  'lib/page/Best50/PersonalizedDiffBest50Page.dart': '个性化拟合 Best50',
  'lib/page/Best50/CustomBest50Page.dart': '自定义 Best50',
  'lib/page/Best50/IdealBest50Page.dart': '理想 Best50',
  'lib/page/UserScoreSearchPage.dart': '单曲成绩搜索',
};

/// 导出图片服务：离屏渲染，基准宽度 [B50GameCardWidget.refCardWidth]，必须显式 1.0。
const List<String> _exportServices = [
  'lib/service/Best50/Best50ConvertToImgService.dart',
  'lib/service/Best50/DiffBest50ConvertToImgService.dart',
  'lib/service/Best50/PersonalizedBest50ConvertToImgService.dart',
  'lib/service/Best50/PersonalizedDiffBest50ConvertToImgService.dart',
];

void main() {
  test('卡片页面统一走 autoScale，不再自己算卡宽', () {
    final failures = <String>[];
    var checked = 0;

    for (final entry in _cardPages.entries) {
      checked++;
      final src = File(entry.key).readAsStringSync();
      if (RegExp(r'\bcardW\b').hasMatch(src)) {
        failures.add('${entry.value}（${entry.key}）：又出现 cardW —— '
            '卡片宽度是"卡片自己的可见宽度"，页面不许估');
      }
      if (src.contains('refCardWidth')) {
        failures.add('${entry.value}：又出现 refCardWidth（手册基准宽度）');
      }
      if (!src.contains('B50GameCardWidget.autoScale')) {
        failures.add('${entry.value}：卡片没写 scale: B50GameCardWidget.autoScale');
      }
    }

    expect(failures, isEmpty, reason: failures.join('\n'));
    expect(checked, 7);
  });

  test('导出图片仍显式 scale: 1.0（别被 autoScale 带偏）', () {
    final failures = <String>[];
    var checked = 0;

    for (final f in _exportServices) {
      checked++;
      final src = File(f).readAsStringSync();
      if (!src.contains('scale: 1.0')) {
        failures.add('$f：导出卡片应显式 scale: 1.0');
      }
      if (src.contains('B50GameCardWidget.autoScale')) {
        failures.add('$f：导出是离屏渲染，宽度约束不是屏幕格子，别用 autoScale');
      }
    }

    expect(failures, isEmpty, reason: failures.join('\n'));
    expect(checked, 4);
  });

  test('resolveScale 的口径', () {
    expect(B50GameCardWidget.autoScale, lessThanOrEqualTo(0.0));
    // autoScale：按传入的盒子宽度换算（屏幕口径的基准宽度）
    expect(
        B50GameCardWidget.resolveScale(
            B50GameCardWidget.autoScale,
            B50GameCardWidget.screenRefCardWidth),
        1.0);
    expect(B50GameCardWidget.resolveScale(B50GameCardWidget.autoScale, 154.0),
        closeTo(0.5, 1e-12));
    expect(
        B50GameCardWidget.resolveScale(
            B50GameCardWidget.autoScale,
            2 * B50GameCardWidget.screenRefCardWidth),
        2.0);
    // 显式 scale 优先
    expect(B50GameCardWidget.resolveScale(1.0, 167.5), 1.0);
    // 拿不到有界宽度时退回 1.0（导出/离屏的兜底）
    expect(B50GameCardWidget.resolveScale(B50GameCardWidget.autoScale, 0.0),
        1.0);
    expect(B50GameCardWidget.resolveScale(
            B50GameCardWidget.autoScale, double.infinity),
        1.0);
  });

  test('屏幕口径：内容尺寸回到统一前（≈308），别退回导出基准 335', () {
    // 320~480 屏实测「真实格子 / 统一前的估算格子」= 1.082~1.097，取 1.088。
    expect(B50GameCardWidget.refCardWidth / B50GameCardWidget.screenRefCardWidth,
        inInclusiveRange(1.075, 1.10));
    // 360 屏的 Best50 格子宽 163.4：统一前的字号是 0.532 一档（178.2 / 335），
    // **不是** 0.4877（163.4 / 335 —— 卡片会小一圈）。
    expect(B50GameCardWidget.resolveScale(B50GameCardWidget.autoScale, 163.4),
        closeTo(0.5305, 0.004));
  });
}
