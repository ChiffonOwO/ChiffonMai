import 'package:flutter/material.dart';

/// 宽度够就静态显示、超长才横向滚动的文本：**滚动一轮 → 停一下 → 再滚**。
///
/// 用它可以，但**别在这个组件外面再套 `marquee` 包**（原因见下）。
///
/// ── 为什么不直接用 `marquee` 包 ──
/// 用它的地方，文案基本都**每秒都在变**（`已等待 12 秒` → `已等待 13 秒`），
/// 而 marquee 包每一轮滚动的距离是拿**开滚那一刻**量到的文本宽度算出来的：
/// 宽度一变，内容就在视口下整体平移，于是「轮末停顿」的落点会漂到
/// ±`blankSpace` 之间 —— 实测真的会停在**第一个字前面空出 18~40px** 的位置上
/// （数字少一位时看不出来，多一位就露馅）。
///
/// 这里的位移是 `相位 × 周期`，而周期**每次都按当前文本宽度重算**，于是：
///   * 停顿时的位移恒等于整数个周期 → 左边缘永远正好落在第一个字上；
///   * 文本中途变宽/变窄只会让当帧平移几像素，不会把停顿位置顶歪；
///   * 两个副本由我们自己摆放（`period - shift`），所以**即使量宽度量歪了**，
///     停顿位置也仍然对齐 —— 量的误差只会体现在两轮之间的空隙大小上。
///
/// 回归测试：`test/marquee_text_test.dart`（"停顿处第一个字必须贴着左边缘"）。
class MarqueeText extends StatefulWidget {
  /// 要显示的文本。
  final String text;

  /// 文本样式（宽度与是否换行都按它算）。
  final TextStyle style;

  /// 两轮之间的空隙（跟着文本一起滚）。
  final double gap;

  /// 滚动一轮的时长。速度 = `(文本宽度 + 空隙) / 时长`，
  /// 所以文本越长滚得越快；**不要**用 marquee 包那种固定速度 —— 那样时长会
  /// 随文本长度变化，而文本每秒都在变，周期就永远不稳定。
  final Duration scrollDuration;

  /// 每轮结束后的停顿（停在**对齐**的位置上，不是停在空隙里）。
  final Duration pauseDuration;

  const MarqueeText({
    super.key,
    required this.text,
    required this.style,
    this.gap = 40,
    this.scrollDuration = const Duration(milliseconds: 7500),
    this.pauseDuration = const Duration(milliseconds: 1500),
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// 本帧是否真的需要滚动（帧后回调据此决定要不要起 ticker）。
  bool _wantScroll = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.scrollDuration + widget.pauseDuration,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 滚动占整个周期的比例，剩下的就是轮末停顿。
  double get _scrollFraction {
    final total = widget.scrollDuration + widget.pauseDuration;
    if (total.inMicroseconds <= 0) return 1;
    return widget.scrollDuration.inMicroseconds / total.inMicroseconds;
  }

  /// 按需启停 ticker。
  ///
  /// 静态文本（没溢出）时**必须停掉**：一个一直 repeat 的 `AnimationController`
  /// 会持续请求新帧，整页都别想进入空闲，白耗电。
  void _syncTicker({required bool overflows}) {
    _wantScroll = overflows;
    if (!overflows) {
      if (_controller.isAnimating) _controller.stop();
      return;
    }
    if (_controller.isAnimating) return;
    // build 期间不要直接 repeat（可能触发监听者在这棵树还在建的时候标脏）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_wantScroll || _controller.isAnimating) return;
      _controller.repeat();
    });
  }

  @override
  Widget build(BuildContext context) {
    // ⚠️ 量宽度必须用**真正渲染时的样式**，也就是 `Text` 自己那套合并逻辑：
    // 环境 `DefaultTextStyle`（ListTile 副标题就是 Material 的 bodyMedium，
    // 带 `letterSpacing: 0.25`）+ 调用方给的 style。
    // 只拿 widget.style 去量会**少算**每个字的字距（15 个字就是 3.5px），
    // 于是周期量短了、停顿落在第一个字前面空出那几个像素 —— 正是这次要修的观感。
    final style = DefaultTextStyle.of(context).style.merge(widget.style);

    return LayoutBuilder(
      builder: (context, constraints) {
        // textScaler 也必须带上：用户把系统字体调大时，实际渲染宽度是放大过的。
        // 不带的话「是否溢出」会按缩小后的宽度判断 —— 明明放不下却走静态分支，
        // 用户看到的就是被省略号截断的半句话。
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        final textWidth = painter.size.width;

        if (textWidth <= constraints.maxWidth) {
          _syncTicker(overflows: false);
          return Text(
            widget.text,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }

        _syncTicker(overflows: true);
        final period = textWidth + widget.gap;
        final scrollFraction = _scrollFraction;

        return ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              // 同一个 Text 摆两份（widget 是不可变配置，同实例放两处没问题）
              final copy = child!;
              // 相位 0→1 = 滚完一整个周期；之后（到本周期结束）停在相位 1。
              // 相位 1 时位移正好 = 周期 → 第二个副本贴在左边缘 = 第一个字对齐。
              final raw = _controller.value / scrollFraction;
              final phase = raw <= 0 ? 0.0 : (raw >= 1 ? 1.0 : raw);
              final shift = phase * period;
              return Transform.translate(
                offset: Offset(-shift, 0),
                // ⚠️ 必须 OverflowBox 放开宽度：Row 的两份文本加起来比视口宽得多，
                // 不放开就会被压缩/省略号截断，跑马灯就没内容可滚。
                // 它自己的尺寸仍是外层给的（220 × 16.2），照旧被 ClipRect 裁掉溢出。
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  maxWidth: double.infinity,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      copy,
                      // 两轮之间的空隙：由 SizedBox 给，所以**不依赖量出来的宽度**，
                      // 量歪了也只是空隙大小变化，不会让停顿位置偏掉。
                      SizedBox(width: widget.gap),
                      copy,
                    ],
                  ),
                ),
              );
            },
            child: Text(
              widget.text,
              style: style,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
            ),
          ),
        );
      },
    );
  }
}
