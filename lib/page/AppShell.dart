import 'dart:async';

import 'package:flutter/material.dart';
import '../utils/AppDesignTokens.dart';
import '../utils/NavigationPreferences.dart';
import '../widgets/LiquidGlassNavigationBar.dart';
import '../widgets/MainNavigationViewport.dart';
import '../widgets/MainNavigationInsets.dart';
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
  final GlobalKey<SystemHubPageState> _systemPageKey =
      GlobalKey<SystemHubPageState>();
  bool _firstFrameNotified = false;
  double _horizontalDragDistance = 0;
  Timer? _navSelectionDebounce;
  int? _pendingIndex;

  static const Duration _navDebounceDuration = Duration(milliseconds: 120);

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
  static const double barH = 66; // 导航栏总高
  static const double pillW = 48; // 药丸宽
  static const double pillH = 28; // 药丸高（也是图标槽高）
  static const double iconTop = 11; // 药丸/图标槽的顶部偏移
  static const double labelGap = 2; // 图标与文字间距
  static const double navigationBottomGap = 14;
  static const double contentBottomGap = 8;

  @override
  void initState() {
    super.initState();
    NavigationPreferences.instance.addListener(_onNavigationPreferencesChanged);
    unawaited(NavigationPreferences.instance.load());
    _pages = [
      HomePage(
        key: _homePageKey,
        onEntertainmentTap: () => _selectIndex(3),
        onSystemFeatureTap: (item) async {
          await _systemPageKey.currentState?.openFeature(item);
        },
      ),
      const LibraryHubPage(),
      const Best50HubPage(),
      const GuessHubPage(),
      const ToolsHubPage(),
      SystemHubPage(
        key: _systemPageKey,
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
  void dispose() {
    _navSelectionDebounce?.cancel();
    NavigationPreferences.instance
        .removeListener(_onNavigationPreferencesChanged);
    super.dispose();
  }

  void _onNavigationPreferencesChanged() {
    if (mounted) setState(() {});
  }

  void _selectIndex(int index) {
    // 离开当前 Hub 时清理输入框焦点，避免返回首页后输入法重新拉起。
    FocusManager.instance.primaryFocus?.unfocus();
    final next = index.clamp(0, _tabs.length - 1);
    if (next == _index && _pendingIndex == null) return;
    if (next == _index) {
      _pendingIndex = null;
      _navSelectionDebounce?.cancel();
      return;
    }

    _pendingIndex = next;
    _navSelectionDebounce?.cancel();
    _navSelectionDebounce = Timer(_navDebounceDuration, () {
      if (!mounted || _pendingIndex == null) return;
      final target = _pendingIndex!;
      _pendingIndex = null;
      if (target == _index) return;
      setState(() => _index = target);
    });
  }

  void _onHorizontalDragStart(DragStartDetails _) {
    _horizontalDragDistance = 0;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    _horizontalDragDistance += details.primaryDelta ?? details.delta.dx;
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (NavigationPreferences.instance.swipeEnabled &&
        _horizontalDragDistance.abs() >= 48) {
      _selectIndex(_index + (_horizontalDragDistance < 0 ? 1 : -1));
    }
    _horizontalDragDistance = 0;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // viewPadding 是窗口当前真实的系统底部 inset：系统导航栏隐藏时为 0，
    // 手势条/三键导航栏出现时则自动变成对应设备的实际高度。
    // 不使用 padding，避免 SafeArea 或键盘状态改变后把系统栏高度算错。
    final systemBottomInset = MediaQuery.viewPaddingOf(context).bottom;
    // Hub 列表的尾部留白由布局参数和系统 inset 共同计算，而不是写死某个
    // 设备的导航栏高度。这样有无系统栏时，最后一个功能按钮到悬浮栏的视觉距离相同。
    final navigationReserve =
        barH + systemBottomInset + navigationBottomGap + contentBottomGap;
    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      // 随身听悬浮球**不在这里** —— 它挂在 main.dart 的 MaterialApp.builder 上，
      // 这样才盖得住 push 出来的各个功能页（详见那边的注释）。
      body: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: NavigationPreferences.instance.swipeEnabled
                ? _onHorizontalDragStart
                : null,
            onHorizontalDragUpdate: NavigationPreferences.instance.swipeEnabled
                ? _onHorizontalDragUpdate
                : null,
            onHorizontalDragEnd: NavigationPreferences.instance.swipeEnabled
                ? _onHorizontalDragEnd
                : null,
            child: ThemeAwareBackground(
              showDecorativeImage: _index == 0,
              child: MainNavigationInsets(
                bottom: navigationReserve,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                        maxWidth: AppDesignTokens.maxContentWidth),
                    child: MainNavigationViewport(
                      pages: _pages,
                      index: _index,
                      transitionEnabled:
                          NavigationPreferences.instance.transitionEnabled,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 导航栏属于页面内容层：它只占自己的圆角浮层，不再挂在
          // Scaffold.bottomNavigationBar，也不会铺满设备底部。
          Positioned(
            left: 12,
            right: 12,
            bottom: systemBottomInset + navigationBottomGap,
            child: _buildFloatingNavigation(scheme),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingNavigation(ColorScheme scheme) {
    if (NavigationPreferences.instance.liquidGlassEnabled) {
      return LiquidGlassNavigationBar(
        height: barH,
        selectedIndex: _index,
        onSelected: _selectIndex,
        animationEnabled: NavigationPreferences.instance.transitionEnabled,
        destinations: [
          for (final tab in _tabs)
            LiquidGlassDestination(
              label: tab.label,
              icon: tab.icon,
              selectedIcon: tab.activeIcon,
            ),
        ],
      );
    }
    return Material(
      color: scheme.surfaceContainerHigh.withValues(alpha: 0.96),
      elevation: 8,
      shadowColor: scheme.shadow.withValues(alpha: 0.26),
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
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
                          onTap: () => _selectIndex(i),
                          child: Padding(
                            // 图标槽与药丸同高同顶，保证图标在药丸内垂直居中
                            padding: const EdgeInsets.only(top: iconTop),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  height: pillH,
                                  child: Center(
                                    child: AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 180),
                                      switchInCurve: Curves.easeOut,
                                      switchOutCurve: Curves.easeIn,
                                      transitionBuilder: (child, animation) =>
                                          FadeTransition(
                                        opacity: animation,
                                        child: child,
                                      ),
                                      child: Icon(
                                        i == _index
                                            ? _tabs[i].activeIcon
                                            : _tabs[i].icon,
                                        key: ValueKey(i == _index),
                                        size: 24,
                                        color: i == _index
                                            ? scheme.primary
                                            : scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: labelGap),
                                SizedBox(
                                  width: tabW,
                                  child: Text(
                                    _tabs[i].label,
                                    maxLines: 1,
                                    softWrap: false,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: i == _index
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      letterSpacing: 0,
                                      color: i == _index
                                          ? scheme.primary
                                          : scheme.onSurfaceVariant,
                                    ),
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
