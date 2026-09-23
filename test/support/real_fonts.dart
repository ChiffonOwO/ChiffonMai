// 测试共享：把**真实字体**装进测试环境。
//
// ## 为什么需要
//
// 测试环境默认的字体每个字形都占满 1em（数字也是），而真机思源黑体的数字只有
// ~0.5em、汉字也更窄。这个差异会让"宽度敏感"的组件在测试里**假阳性溢出**：
//
//   * `B50GameCardWidget` 底部那行「#id + 定数→RA + 星星」在默认字体下宽近一倍，
//     于是各种 `childAspectRatio` 都会报 overflow —— 我为此绕了很久，
//     最后发现**真实字体下同尺寸零溢出**（见 `tool/probe_recommend_grid_test.dart`）。
//
// 所以：**凡是断言"宽度/排版"的 widget 测试，都应该先调 [loadRealFonts]。**
//
// ## 用法
//
// ```dart
// testWidgets('...', (tester) async {
//   await tester.runAsync(loadRealFonts);   // 必须在 runAsync 里（要读文件）
//   ...
// });
// ```
//
// 字体文件取 Windows 自带的中文字体（本机跑测试用），图标字体取 Flutter 缓存里的
// `MaterialIcons`。找不到就静默跳过 —— 别人换机器跑测试时不会因为缺字体直接挂。
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_flutter_app/utils/AppTheme.dart';

/// 把真实字体注册进测试环境，并让 `AppTheme.font` 走本地族名（不联网）。
///
/// **必须在 `tester.runAsync` 里调用**（内部要读文件）。
Future<void> loadRealFonts() async {
  // 让 AppTheme.font 返回本地族名而不是 google_fonts 的网络族
  AppTheme.debugLocalFontFamily = true;

  Future<void> load(String family, List<String> candidates) async {
    for (final path in candidates) {
      final f = File(path);
      if (!f.existsSync()) continue;
      try {
        final bytes = await f.readAsBytes();
        final loader = FontLoader(family);
        loader.addFont(Future.value(ByteData.view(bytes.buffer)));
        await loader.load();
        return;
      } catch (_) {
        // 换下一个候选
      }
    }
  }

  // google_fonts 的族名是**按字重分文件**的，用到的都要注册。
  //
  // 选字顺序（越靠前越像真机）：
  //   1. `test/.fonts/NotoSansSC-Bold.ttf` = Google Fonts 的 Noto Sans SC Bold（**真机用的就是它**）。
  //      有它，测试的墨迹几何才和真机一模一样（字体有没有 hinting 差别很大）。
  //   2. `NotoSansSC-VF.ttf` = Windows 自带的同族可变字体（默认 400 字重）。
  //   3. 微软雅黑 / 黑体 —— 只是"有字"的兜底，几何不保证。
  const deviceBold = r'test\.fonts\NotoSansSC-Bold.ttf';
  const variableFallback = r'C:\Windows\Fonts\NotoSansSC-VF.ttf';
  const cjkFallback = [r'C:\Windows\Fonts\msyh.ttc', r'C:\Windows\Fonts\simhei.ttf'];

  for (final family in [
    'Roboto',
    'NotoSansSC_regular',
    'NotoSansSC_500',
    'NotoSansSC_600',
  ]) {
    await load(family, [variableFallback, ...cjkFallback]);
  }
  // w700（卡片上的达成率、标题栏用的就是这份）
  await load('NotoSansSC_700', [deviceBold, variableFallback, ...cjkFallback]);

  await load('MaterialIcons', const [
    r'D:\flutter\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf',
  ]);
}
