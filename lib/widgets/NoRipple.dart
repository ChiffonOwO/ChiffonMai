import 'package:flutter/material.dart';

/// 给类型、模式、时间范围等切换控件关闭波纹，保留它自己的选中动画。
class NoRipple extends StatelessWidget {
  final Widget child;

  const NoRipple({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Theme(
        data: Theme.of(context).copyWith(
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
        ),
        child: child,
      );
}
