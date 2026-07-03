import 'package:flutter/material.dart';

/// 主题感知的背景组件：浅色模式使用原版 PNG 背景图，暗色模式使用变暗滤镜处理
class ThemeAwareBackground extends StatelessWidget {
  final Widget? child;

  const ThemeAwareBackground({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 底层：背景图（暗色模式下加变暗滤镜）
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            isDark
                ? const Color.fromARGB(150, 20, 20, 35)
                : Colors.transparent,
            BlendMode.darken,
          ),
          child: Image.asset(
            'assets/background.png',
            fit: BoxFit.cover,
          ),
        ),
        // 上层：chiffon 装饰图（暗色模式下加变暗 + 降低透明度）
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            isDark
                ? const Color.fromARGB(120, 10, 10, 25)
                : Colors.transparent,
            BlendMode.darken,
          ),
          child: Opacity(
            opacity: isDark ? 0.4 : 1.0,
            child: Center(
              child: Image.asset(
                'assets/chiffon2.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        // 子组件
        if (child != null)
          Positioned.fill(child: child!),
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
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 底层：背景图
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            isDark
                ? const Color.fromARGB(150, 20, 20, 35)
                : Colors.transparent,
            BlendMode.darken,
          ),
          child: Image.asset(
            'assets/background.png',
            fit: BoxFit.cover,
          ),
        ),
        // 上层：chiffon 装饰图
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            isDark
                ? const Color.fromARGB(120, 10, 10, 25)
                : Colors.transparent,
            BlendMode.darken,
          ),
          child: Opacity(
            opacity: isDark ? 0.4 : 1.0,
            child: Center(
              child: Image.asset(
                'assets/chiffon2.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        // 用户自定义内容
        ...children,
      ],
    );
  }
}
