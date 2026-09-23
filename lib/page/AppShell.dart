import 'package:flutter/material.dart';
import '../utils/AppDesignTokens.dart';
import '../widgets/ThemeAwareBackground.dart';
import 'HomePage.dart';
import 'Best50HubPage.dart';
import 'LibraryHubPage.dart';
import 'GuessHubPage.dart';
import 'ToolsHubPage.dart';
import 'SystemHubPage.dart';
import 'Portable/PortablePlayerPage.dart';

class AppShell extends StatefulWidget {
  final VoidCallback? onFirstFrameRendered;

  const AppShell({super.key, this.onFirstFrameRendered});

  /// 打开随身听曲库页（悬浮球的「播放列表」按钮用）。
  ///
  /// 只做一件事：push 曲库页。**没有**用来控制悬浮球显隐 ——
  /// 球本体挂在 `main.dart` 的 `MaterialApp.builder` 上（在所有路由之上；
  /// 放 AppShell 的 body 里会被 push 出来的功能页整个盖住，表现就是
  /// 「进了功能页只听到声音、看不到球」），显隐由 `PortablePlayerScope`
  /// 加上球自己判断。
  static Future<void> openPortablePlayerPage(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const PortablePlayerPage()),
    );
  }

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  late final List<Widget> _pages;
  final GlobalKey<HomePageState> _homePageKey = GlobalKey<HomePageState>();
  bool _firstFrameNotified = false;

  // ===== 6 个主分类标签（首页 + FeatureRegistry 的 5 大功能分类） =====
  static const List<_NavTab> _tabs = [
    _NavTab(
      label: '首页',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    _NavTab(
      label: '曲库与数据',
      icon: Icons.library_music_outlined,
      activeIcon: Icons.library_music_rounded,
    ),
    _NavTab(
      label: 'Best50',
      icon: Icons.emoji_events_outlined,
      activeIcon: Icons.emoji_events_rounded,
    ),
    _NavTab(
      label: '猜歌游戏',
      icon: Icons.casino_outlined,
      activeIcon: Icons.casino_rounded,
    ),
    _NavTab(
      label: '实用工具',
      icon: Icons.handyman_outlined,
      activeIcon: Icons.handyman_rounded,
    ),
    _NavTab(
      label: '系统',
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
    ),
  ];

  // ===== 底部导航尺寸 =====
  // 药丸 indicator 与图标槽共用 pillH/iconTop，图标天生在药丸内垂直居中，
  // 不再依赖 Column 在整栏里的居中位置（那样药丸和图标会有几像素错位）。
  static const double barH = 70; // 导航栏总高
  static const double pillW = 48; // 药丸宽
  static const double pillH = 28; // 药丸高（也是图标槽高）
  static const double iconTop = 11; // 药丸/图标槽的顶部偏移
  static const double labelGap = 3; // 图标与文字间距

  @override
  void initState() {
    super.initState();
    _pages = [
      HomePage(
        key: _homePageKey,
        onEntertainmentTap: () => setState(() => _index = 3),
      ),
      const LibraryHubPage(),
      const Best50HubPage(),
      const GuessHubPage(),
      const ToolsHubPage(),
      SystemHubPage(
        onAccountManageTap: () =>
            _homePageKey.currentState?.showAccountManageDialog(),
      ),
    ];
    // 仅在首帧渲染完成后触发一次回调，避免每次 build 都重新调度
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _firstFrameNotified) return;
      _firstFrameNotified = true;
      widget.onFirstFrameRendered?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      // 随身听悬浮球**不在这里** —— 它挂在 main.dart 的 MaterialApp.builder 上，
      // 这样才盖得住 push 出来的各个功能页（详见那边的注释）。
      body: ThemeAwareBackground(
        showDecorativeImage: _index == 0,
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: AppDesignTokens.maxContentWidth),
            child: IndexedStack(index: _index, children: _pages),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.92),
          border: Border(
            top: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.6),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
            child: SizedBox(
              height: barH,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double tabW = constraints.maxWidth / _tabs.length;
                  return Stack(
                    children: [
                      // 滑动的药丸 indicator（核心改动：AnimatedPositioned）
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 360),
                        curve: Curves.easeOutCubic,
                        left: _index * tabW + (tabW - pillW) / 2,
                        top: iconTop,
                        width: pillW,
                        height: pillH,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(pillH / 2),
                          ),
                        ),
                      ),
                      // Tab row：icon + label，点击切换 _index
                      Row(
                        children: [
                          for (int i = 0; i < _tabs.length; i++)
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => setState(() => _index = i),
                                child: Padding(
                                  // 图标槽与药丸同高同顶，保证图标在药丸内垂直居中
                                  padding: const EdgeInsets.only(top: iconTop),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        height: pillH,
                                        child: Center(
                                          child: Icon(
                                            i == _index
                                                ? _tabs[i].activeIcon
                                                : _tabs[i].icon,
                                            size: 24,
                                            color: i == _index
                                                ? scheme.primary
                                                : scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: labelGap),
                                      Text(
                                        _tabs[i].label,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: i == _index
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          letterSpacing: 0.4,
                                          color: i == _index
                                              ? scheme.primary
                                              : scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
        ),
      ),
    );
  }
}

class _NavTab {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _NavTab({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}
