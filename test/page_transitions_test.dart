// Android 页面转场必须**显式**钉在非预测性返回的 builder 上。
//
// 背景（真机反馈）：用返回手势返回上一级时 App 有概率卡死 —— 页面从四个角向内缩，
// 缩完返回上一级，有时正常、有时整个 App 点不动。
//
// 那个"向内缩"就是 Flutter 的预测性返回转场
// （`PredictiveBackSharedElementPageTransition`：缩到 0.90 + 32px 圆角 + 右下位移）。
// 本 Flutter 版本把 Android 的默认转场换成了 `PredictiveBackPageTransitionsBuilder`
// （`page_transitions_theme.dart` 的 `_defaultBuilders`），而本项目**没有**覆写
// `pageTransitionsTheme`，于是每一条路由都装上了 `_PredictiveBackGestureDetector`：
//   * 手势一开始框架就替系统认领（`handleStartBackGesture` 返回 true），页面由框架
//     按手指进度缩放；
//   * 框架必须等到平台发 commit / cancel 才退出该状态，而它与路由 pop 是异步竞态；
//   * 竞态输了就停在缩了一半的位置、事件被 Navigator 的 AbsorbPointer 吞掉。
// 按键返回时 `backEvent.isButtonEvent == true`，框架不认领 —— 所以只有手势会中招。
//
// 修法有两半，**缺一个都还会认领手势**：
//   1. 这里断言的：`AppTheme` 把 Android 转场钉成 `FadeForwardsPageTransitionsBuilder`
//      （它正是框架在"没有手势"时的回落分支，所以普通 push / 按钮返回观感不变）；
//   2. `AndroidManifest.xml` 的 `android:enableOnBackInvokedCallback="false"`。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_flutter_app/utils/AppTheme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('三套主题的 Android 页面转场都不是预测性返回', () {
    final themes = <String, ThemeData>{
      '浅色': AppTheme.lightTheme(),
      '深色': AppTheme.darkTheme(),
      '纯黑': AppTheme.pureBlackTheme(),
    };

    themes.forEach((name, theme) {
      final builder = theme.pageTransitionsTheme.builders[TargetPlatform.android];

      expect(
        builder,
        isNot(isA<PredictiveBackPageTransitionsBuilder>()),
        reason: '$name主题：预测性返回转场会在返回手势时由框架认领手势、'
            '按手指进度自行缩放，事件竞态下会把页面停在缩了一半的状态'
            '（真机反馈：返回手势后 App 卡死）',
      );
      expect(
        builder,
        isA<FadeForwardsPageTransitionsBuilder>(),
        reason: '$name主题：要和框架"没有手势"时的回落分支一致，'
            '这样普通 push / 返回按钮的观感完全不变',
      );
    });
  });

  test('其他平台的转场保持框架默认（只动 Android）', () {
    final builders = AppTheme.lightTheme().pageTransitionsTheme.builders;
    final defaults = const PageTransitionsTheme().builders;

    for (final platform in TargetPlatform.values) {
      if (platform == TargetPlatform.android) continue;
      expect(
        builders[platform],
        same(defaults[platform]),
        reason: '$platform 的转场不该被这次修改动到',
      );
    }
  });
}
