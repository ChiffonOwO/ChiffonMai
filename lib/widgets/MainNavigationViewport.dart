import 'package:flutter/material.dart';

/// 保留所有主页面的状态，只对当前页和上一页进行淡入滑动过渡。
class MainNavigationViewport extends StatefulWidget {
  final List<Widget> pages;
  final int index;
  final bool transitionEnabled;

  const MainNavigationViewport({
    super.key,
    required this.pages,
    required this.index,
    required this.transitionEnabled,
  });

  @override
  State<MainNavigationViewport> createState() => _MainNavigationViewportState();
}

class _MainNavigationViewportState extends State<MainNavigationViewport>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    value: 1,
  );
  late int _fromIndex = widget.index;

  @override
  void didUpdateWidget(covariant MainNavigationViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index) {
      _fromIndex = oldWidget.index;
      if (widget.transitionEnabled) {
        _controller.forward(from: 0);
      } else {
        _controller.value = 1;
      }
    } else if (!widget.transitionEnabled) {
      _controller.stop();
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.index;
    final previous = _fromIndex;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = widget.transitionEnabled
            ? Curves.easeOutCubic.transform(_controller.value)
            : 1.0;
        final forward = current > previous;
        return Stack(
          fit: StackFit.expand,
          children: [
            for (var i = 0; i < widget.pages.length; i++)
              // 每个页面始终处于同一层级。切换包装组件的类型会销毁页面 State，
              // 导致账号、头像等重新加载，不能按可见性使用不同的组件结构。
              Offstage(
                offstage: i != current && (i != previous || progress == 1),
                child: IgnorePointer(
                  ignoring: i != current,
                  child: FractionalTranslation(
                    translation: i == current
                        ? Offset((forward ? 1 : -1) * (1 - progress) * .035, 0)
                        : Offset((forward ? -1 : 1) * progress * .035, 0),
                    child: Opacity(
                      opacity: i == current ? progress : 1 - progress,
                      child: TickerMode(
                        enabled: i == current,
                        child: widget.pages[i],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
