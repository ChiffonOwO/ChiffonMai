import 'dart:io';

import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/utils/ThemeManager.dart';

/// 主题感知的背景组件：根据用户设置显示背景图和装饰图。
///
/// 性能说明：
/// 旧实现用 ColorFiltered + BlendMode.darken，该组合会强制每帧创建
/// 离屏缓冲区（saveLayer），在暗色模式下两张全屏背景图各自触发一次，
/// 部分设备上明显掉帧。
/// 新实现用 Stack + Positioned.fill + ColoredBox 做半透明覆层 —
/// Flutter 对纯色矩形的 alpha 合成走 fast path，不需要 saveLayer。
class ThemeAwareBackground extends StatelessWidget {
  final Widget? child;
  final bool showDecorativeImage;

  const ThemeAwareBackground({
    super.key,
    this.child,
    this.showDecorativeImage = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPureBlack = isDark && ThemeManager().pureBlackEnabled;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 底层：背景图 + 主题覆层
        _BgImage(isDark: isDark, isPureBlack: isPureBlack),
        // 上层：chiffon 装饰图（纯黑模式下不显示）
        if (showDecorativeImage) _ChiffonImage(isPureBlack: isPureBlack),
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
        // 上层：chiffon 装饰图（纯黑模式下不显示）
        _ChiffonImage(isPureBlack: isPureBlack),
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
      listenable: Listenable.merge([
        ThemeManager().lightOverlayNotifier,
        ThemeManager().chiffonOpacityNotifier,
      ]),
      builder: (context, _) {
        final opacity = ThemeManager().lightOverlayOpacity;
        final overlayAlpha = (opacity * 255).round().clamp(0, 255);
        final lightOverlay = Color.fromARGB(overlayAlpha, 255, 255, 255);

        final ImageProvider<Object> backgroundImage =
            ThemeManager().customBackgroundPath == null
                ? const AssetImage('assets/background.png') as ImageProvider<Object>
                : FileImage(File(ThemeManager().customBackgroundPath!))
                    as ImageProvider<Object>;

        return Stack(
          fit: StackFit.expand,
          children: [
            Image(
              image: backgroundImage,
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

/// 上层 chiffon 装饰图。
///
/// ⚠️ 深色模式下**不再**往装饰图上铺那层 `(8,8,20)` 的矩形覆层：
/// 装饰图 `chiffon2.png` 是 1179×2556 的整屏图，`BoxFit.contain` 居中铺开后
/// 几乎占满整个主体区域，那层 `Positioned.fill(ColoredBox)` 就画成了一整块纯黑：
///   * 它跟装饰图自己的透明度**无关** —— 装饰图设为 0（默认隐藏）时照样画，
///     于是「什么都没开」也能看到一块漆黑，背景图越亮（「背景透明度」调得越低）
///     越刺眼；纯黑模式反而看不到，因为那条分支早就 return 了；
///   * 覆层比装饰图还大一点点（图片按比例缩放、又整体上移 30），
///     所以在主体区域留下一条明显的纯黑边界。
/// 装饰图的浓淡本来就由它自己的滑杆（`chiffonOpacity`）控制，不需要额外的覆层。
class _ChiffonImage extends StatelessWidget {
  final bool isPureBlack;
  const _ChiffonImage({required this.isPureBlack});

  @override
  Widget build(BuildContext context) {
    // 纯黑模式：不显示装饰图
    if (isPureBlack) {
      return const SizedBox.shrink();
    }

    return ListenableBuilder(
      listenable: ThemeManager().chiffonOpacityNotifier,
      builder: (context, _) {
        final opacity = ThemeManager().chiffonOpacity;
        // 隐藏时直接不占位：既省掉一张全屏图的布局/解码，也不会留下任何覆层
        if (opacity <= 0) return const SizedBox.shrink();
        return Center(
          child: Transform.translate(
            offset: const Offset(0, -30),
            child: Image.asset(
              'assets/chiffon2.png',
              fit: BoxFit.contain,
              gaplessPlayback: true,
              opacity: AlwaysStoppedAnimation(opacity),
            ),
          ),
        );
      },
    );
  }
}
