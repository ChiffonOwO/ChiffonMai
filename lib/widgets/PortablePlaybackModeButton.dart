/*
 * 播放模式切换按钮 —— **随身听曲库页底部那条**与**悬浮球的迷你卡片**共用同一个。
 *
 * 两个入口都挂在 [PortablePlayerController] 单例上，所以「播放模式 + 循环次数」
 * 天然同步：在迷你卡片里切成单曲循环，进曲库页看到的就是单曲循环。
 *
 * 为什么选择框不用 `PopupMenuButton`：
 *
 * 1. 它的弹层会压在按钮上（需求要求不能盖住按钮），位置由
 *    `PopupMenuPosition.over/under` 定死，做不出「底边贴着按钮顶边」；
 * 2. 它的出场动画恒为 300ms（`_kMenuDuration`），点起来发闷；
 * 3. 它的遮罩是一整块 `ModalBarrier`（`HitTestBehavior.opaque`），会把按钮一起
 *    吃掉 —— 「选择框开着时再点按钮继续切模式」就点不到按钮了。
 *
 * 所以这里自己算锚点、自己定 110ms 的淡入，并用一个自带「按钮洞」的路由。
 */
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../service/Portable/PortablePlayerController.dart';

/// 播放模式按钮。
///
/// 点一下：**先切一次模式**，再把选择框拉起来；选择框已经开着时只切模式、
/// **不关选择框** —— 框里那一列会自己平滑地把勾选移过去。
class PortablePlaybackModeButton extends StatefulWidget {
  const PortablePlaybackModeButton({
    super.key,
    this.iconButtonKey,
    this.iconSize = 24,
    this.density,
  });

  /// 给 [IconButton] 自己的 key：测试里定位用，也避免两个入口同时挂在树上时撞 key。
  final Key? iconButtonKey;

  final double iconSize;

  /// 迷你卡片里塞得比较紧，传 `VisualDensity.compact` 收一收。
  final VisualDensity? density;

  @override
  State<PortablePlaybackModeButton> createState() =>
      _PortablePlaybackModeButtonState();
}

class _PortablePlaybackModeButtonState
    extends State<PortablePlaybackModeButton> {
  final PortablePlayerController _player = PortablePlayerController();

  /// 按钮锚点：选择框要贴着它的顶边弹出（不能盖住按钮）。
  final GlobalKey _anchorKey = GlobalKey();

  /// 选择框是否正开着；开着时按钮那一下只切模式、不重复推路由。
  bool _menuOpen = false;

  @override
  void initState() {
    super.initState();
    // 模式可能在别处被改（另一个入口、通知栏…），图标要跟着走
    _player.addListener(_safeSetState);
  }

  @override
  void dispose() {
    _player.removeListener(_safeSetState);
    super.dispose();
  }

  void _safeSetState() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return KeyedSubtree(
      key: _anchorKey,
      child: IconButton(
        key: widget.iconButtonKey,
        visualDensity: widget.density,
        tooltip: '播放模式：${_player.playbackModeLabel}（点一下切换并展开）',
        icon: Icon(
          _playbackModeIcon(_player.playbackMode),
          size: widget.iconSize,
          color: scheme.primary,
        ),
        onPressed: _onTap,
      ),
    );
  }

  Future<void> _onTap() async {
    _cyclePlaybackMode();
    if (_menuOpen) return;
    await _showMenu();
  }

  /// 顺序 → 随机 → 单曲 → 顺序（就是 [PortablePlaybackMode] 的声明顺序）。
  ///
  /// 切到单曲循环时会沿用上次配置的次数（见 `setPlaybackMode` 的注释）。
  void _cyclePlaybackMode() {
    final modes = PortablePlaybackMode.values;
    final next = modes[(modes.indexOf(_player.playbackMode) + 1) % modes.length];
    unawaited(_player.setPlaybackMode(next));
  }

  IconData _playbackModeIcon(PortablePlaybackMode mode) {
    switch (mode) {
      case PortablePlaybackMode.sequential:
        return Icons.format_list_numbered;
      case PortablePlaybackMode.shuffle:
        return Icons.shuffle;
      case PortablePlaybackMode.single:
        return Icons.repeat_one;
    }
  }

  /// 在按钮**上方**弹出播放类型选择框。
  Future<void> _showMenu() async {
    final anchorBox = _anchorKey.currentContext?.findRenderObject();
    final overlayBox = Navigator.of(context, rootNavigator: true)
        .overlay
        ?.context
        .findRenderObject();
    if (anchorBox is! RenderBox ||
        !anchorBox.hasSize ||
        overlayBox is! RenderBox) {
      return;
    }
    // 按钮在屏幕里的位置（用 Overlay 的坐标系，和弹层的 Positioned 一致）
    final anchor = anchorBox.localToGlobal(Offset.zero, ancestor: overlayBox) &
        anchorBox.size;
    final screen = overlayBox.size;
    const gap = 8.0;
    const screenPadding = 12.0;
    final menuWidth = math.min(236.0, screen.width - screenPadding * 2);
    // 右边缘对齐按钮，同时兜住左边越界（窄屏 / 按钮贴着右边缘时）
    final maxLeft =
        math.max(screenPadding, screen.width - menuWidth - screenPadding);
    final left =
        math.min(math.max(screenPadding, anchor.right - menuWidth), maxLeft);
    // 「底边贴着按钮顶边」：不盖住按钮
    final bottom = math.max(screenPadding, screen.height - anchor.top + gap);

    _menuOpen = true;
    _PlaybackModeMenuResult? result;
    try {
      result = await Navigator.of(context, rootNavigator: true)
          .push<_PlaybackModeMenuResult>(_PlaybackModeMenuRoute(
        // 遮罩给按钮留洞用，钳进屏幕里免得 Positioned 拿到负的宽高
        holeInOverlay: Rect.fromLTRB(
          anchor.left.clamp(0.0, screen.width).toDouble(),
          anchor.top.clamp(0.0, screen.height).toDouble(),
          anchor.right.clamp(0.0, screen.width).toDouble(),
          anchor.bottom.clamp(0.0, screen.height).toDouble(),
        ),
        left: left,
        bottom: bottom,
        width: menuWidth,
        player: _player,
      ));
    } finally {
      // 选择框一收，按钮就恢复成「亮起来 + 顺手弹框」的行为
      _menuOpen = false;
    }
    // 抽屉页在选择框之外单独开：它自己就是模态的，别把 _menuOpen 也拖着
    if (result == _PlaybackModeMenuResult.loopCount && mounted) {
      await _showLoopCountSheet();
    }
  }

  /// 「循环次数」抽屉页：不设置次数 / 设置次数（+/- 步进器，最低 2 次）。
  Future<void> _showLoopCountSheet() async {
    final choice = await showModalBottomSheet<_LoopCountChoice>(
      context: context,
      showDragHandle: true,
      builder: (_) => _LoopCountSheet(initialCount: _player.singleLoopCount),
    );
    if (choice == null || !mounted) return;
    await _player.setSingleLoopCount(choice.count);
  }
}

/// 选择框里点了什么。
///
/// 前三个模式自己就把结果处理掉了（[Navigator.pop] 不带值），只有「循环次数」
/// 需要弹完选择框之后再去开抽屉页，所以用这个标记回传。
enum _PlaybackModeMenuResult { loopCount }

/// 播放类型选择框的路由。
///
/// 自己写路由的唯一理由：**遮罩要给切换按钮留一个洞**。
/// `showGeneralDialog` / `PopupMenuButton` 用的都是整块 `ModalBarrier`，
/// 会把整个页面一起吃掉 —— 于是「选择框开着时再点切换按钮继续切模式」根本
/// 点不到按钮。这里把遮罩换成按钮四周的四块矩形，中间留出按钮原来的位置：
///
///   * 点按钮 → 直接落到真正的 `IconButton`（有涟漪、走 `onPressed`），
///     模式接着往下切、选择框保持打开；
///   * 点旁边 → 收起选择框；
///   * 点框里的条目、或「循环次数」 → 切模式/开抽屉页并收起（见 [buildPage]）。
class _PlaybackModeMenuRoute extends PopupRoute<_PlaybackModeMenuResult> {
  _PlaybackModeMenuRoute({
    required this.holeInOverlay,
    required this.left,
    required this.bottom,
    required this.width,
    required this.player,
  });

  /// 切换按钮在根 Overlay 坐标系里的矩形（已经钳进屏幕）—— 遮罩在这儿挖洞。
  final Rect holeInOverlay;

  final double left;
  final double bottom;
  final double width;

  /// 选择框要跟着它重建，否则按钮切模式时框里的勾选不会动。
  ///
  /// 名字不能叫 `controller`：`TransitionRoute` 上已经有一个
  /// `AnimationController? controller`，同名字段会把那个 getter 覆盖掉。
  final PortablePlayerController player;

  /// 出厂 300ms 太闷，110ms 就够了。
  @override
  Duration get transitionDuration => const Duration(milliseconds: 110);

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => '关闭播放模式选择';

  @override
  Widget buildModalBarrier() {
    Widget catcher() => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => navigator?.maybePop(),
          child: const SizedBox.expand(),
        );
    return BlockSemantics(
      child: ExcludeSemantics(
        child: Stack(
          children: [
            // 上
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              height: holeInOverlay.top,
              child: catcher(),
            ),
            // 左
            Positioned(
              left: 0,
              top: holeInOverlay.top,
              width: holeInOverlay.left,
              height: holeInOverlay.height,
              child: catcher(),
            ),
            // 右
            Positioned(
              left: holeInOverlay.right,
              top: holeInOverlay.top,
              right: 0,
              height: holeInOverlay.height,
              child: catcher(),
            ),
            // 下
            Positioned(
              left: 0,
              top: holeInOverlay.bottom,
              right: 0,
              bottom: 0,
              child: catcher(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) => _PlaybackModeMenu(
        left: left,
        bottom: bottom,
        width: width,
        mode: player.playbackMode,
        loopCount: player.singleLoopCount,
        onSelectMode: (mode) {
          navigator?.pop();
          unawaited(player.setPlaybackMode(mode));
        },
        onTapLoopCount: () => navigator?.pop(_PlaybackModeMenuResult.loopCount),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      key: const Key('playbackModeMenuFade'),
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    );
  }
}

/// 播放类型选择框：贴在切换按钮**上方**，四行 = 顺序 / 随机 / 单曲 / 循环次数。
///
/// 位置由调用方算好（相对根 Overlay 的 left / bottom / width），这里只负责画。
/// 高亮与勾选都是隐式动画：按钮连续切模式时，能看出勾选平滑地移过去，而不是硬切。
class _PlaybackModeMenu extends StatelessWidget {
  const _PlaybackModeMenu({
    required this.left,
    required this.bottom,
    required this.width,
    required this.mode,
    required this.loopCount,
    required this.onSelectMode,
    required this.onTapLoopCount,
  });

  /// 框内切换模式的过渡时长。
  ///
  /// 和路由的出场动画（110ms）是两回事：那个是「框本身淡入淡出」，
  /// 这个是「勾选/高亮滑过去」，稍慢一点才看得出是滑过去的。
  static const Duration _switchDuration = Duration(milliseconds: 160);

  final double left;
  final double bottom;
  final double width;
  final PortablePlaybackMode mode;
  final int? loopCount;
  final ValueChanged<PortablePlaybackMode> onSelectMode;
  final VoidCallback onTapLoopCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Positioned(
          left: left,
          bottom: bottom,
          width: width,
          // 卡片自己的空白处（分隔线、圆角）也要吃掉点击，
          // 别穿透到底下那层「点旁边收起」的遮罩上
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: Material(
              key: const Key('playbackModeMenu'),
              elevation: 6,
              color: scheme.surface,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _modeItem(context, PortablePlaybackMode.sequential,
                      Icons.format_list_numbered, '顺序播放'),
                  _modeItem(context, PortablePlaybackMode.shuffle,
                      Icons.shuffle, '随机播放'),
                  _modeItem(context, PortablePlaybackMode.single,
                      Icons.repeat_one, '单曲循环'),
                  Divider(
                    height: 1,
                    color: scheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                  _loopCountItem(context),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _modeItem(
    BuildContext context,
    PortablePlaybackMode value,
    IconData icon,
    String label,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final selected = mode == value;
    return InkWell(
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      onTap: () => onSelectMode(value),
      child: AnimatedContainer(
        duration: _switchDuration,
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        // 选中行的底色淡入淡出 —— 看起来就是「高亮滑到了这一行」
        color: selected
            ? scheme.primary.withValues(alpha: 0.10)
            : Colors.transparent,
        child: Row(
          children: [
            TweenAnimationBuilder<Color?>(
              duration: _switchDuration,
              curve: Curves.easeOut,
              tween: ColorTween(
                end: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              builder: (context, color, child) =>
                  Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AnimatedDefaultTextStyle(
                duration: _switchDuration,
                curve: Curves.easeOut,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? scheme.primary : scheme.onSurface,
                ),
                child: Text(label),
              ),
            ),
            // 勾选：淡入 + 轻微放大。没选中时保留占位（透明度 0），行宽才不会抖
            AnimatedOpacity(
              key: Key('playbackModeCheck_${value.name}'),
              duration: _switchDuration,
              curve: Curves.easeOut,
              opacity: selected ? 1 : 0,
              child: AnimatedScale(
                duration: _switchDuration,
                curve: Curves.easeOutBack,
                scale: selected ? 1 : 0.7,
                child: Icon(Icons.check, size: 18, color: scheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 第四项不是模式，而是「单曲循环的次数」设置：点开抽屉页去配。
  Widget _loopCountItem(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTapLoopCount,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.repeat, size: 20, color: scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '循环次数',
                style: TextStyle(fontSize: 14, color: scheme.onSurface),
              ),
            ),
            Text(
              loopCount == null ? '不设置' : '$loopCount 次',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(width: 2),
            Icon(Icons.chevron_right,
                size: 18, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// 抽屉页的结果：`count` 为 `null` 表示「不设置次数」（一直循环）。
class _LoopCountChoice {
  const _LoopCountChoice(this.count);

  final int? count;
}

/// 「循环次数」抽屉页：两个选项 + 一个 +/- 步进器。
///
/// 需求：**不要输入框**，用 +/- 步进；最低 2 次（1 次就是单曲循环本身）；
/// 选中「不设置次数」时步进器不可用。
class _LoopCountSheet extends StatefulWidget {
  const _LoopCountSheet({required this.initialCount});

  /// 当前已配置的次数；`null` = 还没设置过。
  final int? initialCount;

  @override
  State<_LoopCountSheet> createState() => _LoopCountSheetState();
}

class _LoopCountSheetState extends State<_LoopCountSheet> {
  /// 最低 2 次：设成 1 次与「单曲循环」没有区别，没有意义。
  static const int _minCount = 2;

  /// 上限只是防手滑点出一串没意义的数字（真正跑到 99 次的人也不在乎精确值）。
  static const int _maxCount = 99;

  late bool _setCount;
  late int _count;

  @override
  void initState() {
    super.initState();
    // 没设置过时默认停在「不设置次数」，步进器停在最低值备选。
    _setCount = widget.initialCount != null;
    _count = (widget.initialCount ?? _minCount).clamp(_minCount, _maxCount);
  }

  void _step(int delta) {
    final next = (_count + delta).clamp(_minCount, _maxCount);
    if (next != _count) setState(() => _count = next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      // 系统字体放大时内容会比抽屉页的默认高度高，允许滚动，别把内容挤 overflow
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('循环次数', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              RadioGroup<int>(
                groupValue: _setCount ? 1 : 0,
                onChanged: (value) => setState(() => _setCount = value == 1),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const RadioListTile<int>(
                      value: 0,
                      contentPadding: EdgeInsets.zero,
                      title: Text('不设置次数'),
                      subtitle: Text('一直循环当前曲目'),
                    ),
                    RadioListTile<int>(
                      value: 1,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('设置次数'),
                      subtitle: _buildStepper(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(
                        _LoopCountChoice(_setCount ? _count : null),
                      ),
                      child: const Text('确定'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepper() {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: _setCount ? 1 : 0.4,
      child: IgnorePointer(
        key: const Key('loopCountStepper'),
        ignoring: !_setCount,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: const Key('loopCountMinus'),
              tooltip: '减少次数',
              visualDensity: VisualDensity.compact,
              onPressed: _count > _minCount ? () => _step(-1) : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            SizedBox(
              width: 60,
              child: Text(
                '$_count 次',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            IconButton(
              key: const Key('loopCountPlus'),
              tooltip: '增加次数',
              visualDensity: VisualDensity.compact,
              onPressed: _count < _maxCount ? () => _step(1) : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ),
    );
  }
}
