import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/utils/ThemeManager.dart';

/// 暗色遮罩颜色常量
abstract class _DarkOverlay {
  /// 暗色模式 chiffon 透明度
  static const double chiffonOpacity = 0.28;
}

/// 浅色模式颜色常量
abstract class _LightOverlay {
  /// 浅色模式 chiffon 透明度
  static const double chiffonOpacity = 0.40;
}

/// 主题感知的背景组件：浅色模式使用白色覆层将 PNG 背景图洗淡为柔和纹理，
/// 暗色模式使用半透明深色遮罩，纯黑模式不显示背景图。
///
/// 性能说明：
/// 旧实现用 ColorFiltered + BlendMode.darken，该组合会强制每帧创建
/// 离屏缓冲区（saveLayer），在暗色模式下两张全屏背景图各自触发一次，
/// 部分设备上明显掉帧。
/// 新实现用 Stack + Positioned.fill + ColoredBox 做半透明覆层 —
/// Flutter 对纯色矩形的 alpha 合成走 fast path，不需要 saveLayer。
class ThemeAwareBackground extends StatelessWidget {
  final Widget? child;

  const ThemeAwareBackground({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPureBlack = isDark && ThemeManager().pureBlackEnabled;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 底层：背景图 + 主题覆层
        _BgImage(isDark: isDark, isPureBlack: isPureBlack),
        // 上层：chiffon 装饰图 + 主题覆层
        _ChiffonImage(isDark: isDark, isPureBlack: isPureBlack),
        // 子组件
        if (child != null) Positioned.fill(child: child!),
      ],
    );
  }
}

/// 简化版：只返回背景 Stack，用于需要自定义叠加内容的页面
class ThemeAwareBgStack extends StatelessWidget {
  final List<Widget> children;

  const ThemeAwareBgStack({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPureBlack = isDark && ThemeManager().pureBlackEnabled;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 底层：背景图 + 主题覆层
        _BgImage(isDark: isDark, isPureBlack: isPureBlack),
        // 上层：chiffon 装饰图 + 主题覆层
        _ChiffonImage(isDark: isDark, isPureBlack: isPureBlack),
        // 用户自定义内容
        ...children,
      ],
    );
  }
}

// ============ 内部组件 ============

/// 底层背景图 + 主题半透明遮罩
class _BgImage extends StatelessWidget {
  final bool isDark;
  final bool isPureBlack;
  const _BgImage({required this.isDark, required this.isPureBlack});

  @override
  Widget build(BuildContext context) {
    // 纯黑模式：不渲染背景图，直接返回纯黑
    if (isPureBlack) {
      return Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: ColoredBox(color: Colors.black),
          ),
        ],
      );
    }

    return ListenableBuilder(
      listenable: ThemeManager().lightOverlayNotifier,
      builder: (context, _) {
        final opacity = ThemeManager().lightOverlayOpacity;
        final overlayAlpha = (opacity * 255).round().clamp(0, 255);
        final lightOverlay = Color.fromARGB(overlayAlpha, 255, 255, 255);

        return Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/background.png',
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
            if (isDark)
              Positioned.fill(
                child: ColoredBox(
                  color: Color.fromARGB(overlayAlpha, 15, 15, 28),
                ),
              )
            else
              Positioned.fill(
                child: ColoredBox(color: lightOverlay),
              ),
          ],
        );
      },
    );
  }
}

/// 上层 chiffon 装饰图 + 主题半透明遮罩
class _ChiffonImage extends StatelessWidget {
  final bool isDark;
  final bool isPureBlack;
  const _ChiffonImage({required this.isDark, required this.isPureBlack});

  @override
  Widget build(BuildContext context) {
    // 纯黑模式：不显示装饰图
    if (isPureBlack) {
      return const SizedBox.shrink();
    }

    return ListenableBuilder(
      listenable: ThemeManager().lightOverlayNotifier,
      builder: (context, _) {
        final opacity = ThemeManager().lightOverlayOpacity;
        final overlayAlpha = (opacity * 255).round().clamp(0, 255);
        return Center(
          child: Transform.translate(
            offset: const Offset(0, -30),
            child: Transform.scale(
              scale: 1,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    'assets/chiffon2.png',
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    opacity: AlwaysStoppedAnimation(
                      isDark ? _DarkOverlay.chiffonOpacity : _LightOverlay.chiffonOpacity,
                    ),
                  ),
                  if (isDark)
                    Positioned.fill(
                      child: ColoredBox(
                        color: Color.fromARGB(overlayAlpha, 8, 8, 20),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
