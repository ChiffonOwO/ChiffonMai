import 'package:flutter/material.dart';

import 'ThemeAwareBackground.dart';
import 'PageTopBar.dart';

/// 直接铺在主题背景上的页面壳。
///
/// 页面级内容不再被一块大面积 surface 面板包住；需要分组时由页面内部使用
/// Card、Container 或 PageSection 等局部组件完成。底色先于异步背景图绘制，
/// 避免首帧出现黑色闪烁。
class BackgroundPageScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final bool showBack;
  final PageTopBarTitleAlign titleAlign;
  final bool resizeToAvoidBottomInset;
  final bool showDecorativeImage;
  final EdgeInsetsGeometry contentPadding;

  /// 仅供收藏夹批量操作等特殊工具栏替换标准标题栏。
  final Widget? headerOverride;

  /// 来源说明等随标题栏显示的附加区域。
  final PreferredSizeWidget? bottom;
  final bool animateTitle;
  final bool centerTitleInAvailableSpace;

  const BackgroundPageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions = const <Widget>[],
    this.onBack,
    this.showBack = true,
    this.titleAlign = PageTopBarTitleAlign.center,
    this.resizeToAvoidBottomInset = false,
    this.showDecorativeImage = true,
    this.contentPadding = EdgeInsets.zero,
    this.headerOverride,
    this.bottom,
    this.animateTitle = false,
    this.centerTitleInAvailableSpace = false,
  });

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: ColoredBox(color: surface)),
          ThemeAwareBackground(showDecorativeImage: showDecorativeImage),
          Column(
            children: [
              headerOverride ??
                  PageTopBar(
                    title: title,
                    actions: actions,
                    onBack: onBack,
                    showBack: showBack,
                    titleAlign: titleAlign,
                    barBackground: Colors.transparent,
                    bottom: bottom,
                    animateTitle: animateTitle,
                    centerTitleInAvailableSpace: centerTitleInAvailableSpace,
                  ),
              Expanded(
                child: Padding(
                  padding: contentPadding,
                  child: child,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
