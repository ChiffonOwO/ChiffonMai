import 'package:flutter/material.dart';

/// 全局左边缘右滑返回检测器。
///
/// 仅当屏幕左边缘 ~30px 内起手向右滑动超过阈值时触发返回，
/// 不干扰页面内 ScrollView / PageView 等横向手势。
///
/// 用法：在 MaterialApp.builder 中包裹 child，并传入 navigatorKey。
class SwipeBackDetector extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  const SwipeBackDetector({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  @override
  State<SwipeBackDetector> createState() => _SwipeBackDetectorState();
}

class _SwipeBackDetectorState extends State<SwipeBackDetector> {
  // ── 可调参数 ──
  static const double _edgeWidth = 30.0;
  static const double _popThreshold = 80.0;
  static const double _velocityThreshold = 400.0;

  double _dragOffset = 0.0;
  bool _isDragging = false;

  NavigatorState? get _navigator => widget.navigatorKey.currentState;

  void _onHorizontalDragStart(DragStartDetails details) {
    if (_navigator == null || !_navigator!.canPop()) return;
    if (details.localPosition.dx > _edgeWidth) return;
    _isDragging = true;
    _dragOffset = 0.0;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    _dragOffset = (_dragOffset + details.delta.dx).clamp(0.0, 400.0);
    setState(() {});
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;
    final shouldPop = _dragOffset > _popThreshold ||
        details.primaryVelocity != null &&
            details.primaryVelocity! > _velocityThreshold;
    if (shouldPop) {
      _dragOffset = MediaQuery.of(context).size.width;
      setState(() {});
      Future.delayed(const Duration(milliseconds: 80), () {
        if (!mounted) return;
        _reset();
        _navigator?.maybePop();
      });
    } else {
      _reset();
    }
  }

  void _reset() {
    if (!mounted) return;
    setState(() {
      _dragOffset = 0.0;
      _isDragging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final canPop = _navigator?.canPop() ?? false;

    // 首页不可返回时不渲染拖拽叠加层
    if (!canPop && !_isDragging) {
      return widget.child;
    }

    return GestureDetector(
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: Stack(
        children: [
          if (_isDragging || _dragOffset > 0)
            Positioned.fill(
              child: Container(
                color: Theme.of(context)
                    .colorScheme
                    .surface
                    .withValues(alpha: 0.2),
              ),
            ),
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: widget.child,
          ),
          if (canPop && !_isDragging)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 2,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.08),
              ),
            ),
        ],
      ),
    );
  }
}
