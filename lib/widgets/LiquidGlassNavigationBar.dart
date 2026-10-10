import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class LiquidGlassDestination {
  const LiquidGlassDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// 局部背景模糊、玻璃反光与切换时伸缩的选中胶囊。
/// 动画只在切换时运行，静止时不请求新帧；不改变主壳的底部留白。
class LiquidGlassNavigationBar extends StatefulWidget {
  const LiquidGlassNavigationBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    this.height = 66,
    this.animationEnabled = true,
  })  : assert(destinations.length > 1),
        assert(selectedIndex >= 0 && selectedIndex < destinations.length);

  final List<LiquidGlassDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final double height;
  final bool animationEnabled;

  @override
  State<LiquidGlassNavigationBar> createState() =>
      _LiquidGlassNavigationBarState();
}

class _LiquidGlassNavigationBarState extends State<LiquidGlassNavigationBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: 1,
  );
  late double _from = widget.selectedIndex.toDouble();
  late double _to = _from;

  bool get _animate =>
      widget.animationEnabled && !MediaQuery.disableAnimationsOf(context);

  double get _position => ui.lerpDouble(
      _from, _to, Curves.easeOutCubic.transform(_controller.value))!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_animate) _controller.value = 1;
  }

  @override
  void didUpdateWidget(covariant LiquidGlassNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      // 连续点击时从当前可见的位置继续移动，不跳回上一次的起点。
      _from = _position;
      _to = widget.selectedIndex.toDouble();
      if (_animate) {
        _controller.forward(from: 0);
      } else {
        _controller.value = 1;
      }
    } else if (!_animate) {
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(28);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: dark ? 0.28 : 0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        // 模糊范围严格限制在导航栏内，图标与文字在滤镜之后绘制。
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.surface.withValues(alpha: dark ? 0.78 : 0.76),
                  scheme.surfaceContainerHigh
                      .withValues(alpha: dark ? 0.60 : 0.48),
                  scheme.surface.withValues(alpha: dark ? 0.70 : 0.64),
                ],
              ),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: SizedBox(
              height: widget.height,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const inset = 5.0;
                  final tabWidth = (constraints.maxWidth - inset * 2) /
                      widget.destinations.length;
                  // 高亮比单个 tab 略宽，避免「曲库与数据」两端的字形外沿
                  // 贴到甚至越过胶囊边界；两侧仍保留清晰的分隔。
                  final lensWidth = tabWidth + 2;
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _GlassReflectionPainter(
                              color: dark ? scheme.onSurface : scheme.surface,
                              dark: dark,
                            ),
                          ),
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) {
                          final stretch = math
                                  .sin(_controller.value * math.pi) *
                              math.min(
                                  (_to - _from).abs() * tabWidth * 0.18, 16.0);
                          return Positioned(
                            left:
                                (inset + _position * tabWidth - 1 - stretch / 2)
                                    .clamp(
                                        inset,
                                        constraints.maxWidth -
                                            inset -
                                            lensWidth -
                                            stretch),
                            top: 5,
                            width: lensWidth + stretch,
                            height: widget.height - 10,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(23),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    scheme.primary
                                        .withValues(alpha: dark ? 0.28 : 0.18),
                                    scheme.primary
                                        .withValues(alpha: dark ? 0.12 : 0.07),
                                    scheme.primary
                                        .withValues(alpha: dark ? 0.22 : 0.14),
                                  ],
                                ),
                                border:
                                    Border.all(color: scheme.outlineVariant),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        scheme.primary.withValues(alpha: 0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: CustomPaint(
                                painter: _GlassReflectionPainter(
                                  color:
                                      dark ? scheme.onSurface : scheme.surface,
                                  dark: dark,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      Positioned.fill(
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: inset),
                          child: Material(
                            type: MaterialType.transparency,
                            child: Row(
                              children: [
                                for (var i = 0;
                                    i < widget.destinations.length;
                                    i++)
                                  Expanded(child: _buildDestination(i, scheme)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDestination(int index, ColorScheme scheme) {
    final destination = widget.destinations[index];
    final selected = index == widget.selectedIndex;
    final color = selected ? scheme.primary : scheme.onSurface;
    return Semantics(
      selected: selected,
      child: TextButton(
        onPressed: () {
          if (!selected) widget.onSelected(index);
        },
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: color,
          overlayColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
        ).copyWith(
          // 键盘焦点有明确描边；点击和按下仍不使用波纹或高亮遮罩。
          side: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.focused)
                  ? BorderSide(color: scheme.primary, width: 1.5)
                  : BorderSide.none),
        ),
        child: SizedBox.expand(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: _animate
                    ? const Duration(milliseconds: 180)
                    : Duration.zero,
                child: Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  key: ValueKey(selected),
                  size: 24,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    destination.label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 0,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 玻璃上沿与下沿的弧形反光。它不参与命中测试，也不持续播放动画。
class _GlassReflectionPainter extends CustomPainter {
  const _GlassReflectionPainter({required this.color, required this.dark});

  final Color color;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shape = RRect.fromRectAndRadius(
      rect.deflate(1.5),
      Radius.circular(math.min(26, size.height / 2)),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          color.withValues(alpha: dark ? 0.24 : 0.90),
          color.withValues(alpha: 0),
          color.withValues(alpha: dark ? 0.04 : 0.02),
          color.withValues(alpha: dark ? 0.16 : 0.55),
        ],
        stops: const [0, 0.38, 0.62, 1],
      ).createShader(rect);
    canvas.drawRRect(shape, paint);
  }

  @override
  bool shouldRepaint(covariant _GlassReflectionPainter oldDelegate) =>
      color != oldDelegate.color || dark != oldDelegate.dark;
}
