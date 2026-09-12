import 'package:flutter/material.dart';

/// 应用启动加载页：纯白背景 + 应用图标 + 应用名称 + 加载动画。
/// 设计目标：克制、聚焦，把视觉权重留给 Logo。
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLogo(context),
              const SizedBox(height: 28),
              _buildBrand(scheme),
              const SizedBox(height: 32),
              _buildLoading(scheme),
            ],
          ),
        ),
      ),
    );
  }

  // Logo：app 自身图标，按 Android 自适应图标的「72/108 安全区」裁剪显示，
  // 跟 AboutAppPage 的 _AndroidLauncherIcon 同款，还原启动器观感。
  Widget _buildLogo(BuildContext context) {
    final size = 108.0;
    const double safeZoneRatio = 72 / 108;
    final cacheWidth =
        (size / safeZoneRatio * MediaQuery.of(context).devicePixelRatio).round();

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.24),
        child: Transform.scale(
          scale: 1 / safeZoneRatio,
          child: Image.asset(
            'assets/icon.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
            cacheWidth: cacheWidth,
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }

  Widget _buildBrand(ColorScheme scheme) {
    return Text(
      'ChiffonMai',
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.6,
        color: scheme.onSurface,
      ),
    );
  }

  // 加载动画：Material CircularProgressIndicator
  Widget _buildLoading(ColorScheme scheme) {
    return SizedBox(
      width: 28,
      height: 28,
      child: CircularProgressIndicator(
        strokeWidth: 2.4,
        valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
      ),
    );
  }
}