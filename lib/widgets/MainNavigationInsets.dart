import 'package:flutter/widgets.dart';

/// 主壳悬浮导航需要的列表尾部留白。只增加滚动内容长度，不缩短页面视口。
class MainNavigationInsets extends InheritedWidget {
  const MainNavigationInsets({
    super.key,
    required this.bottom,
    required super.child,
  });

  final double bottom;

  static double bottomOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<MainNavigationInsets>()
          ?.bottom ??
      0;

  @override
  bool updateShouldNotify(MainNavigationInsets oldWidget) =>
      bottom != oldWidget.bottom;
}
