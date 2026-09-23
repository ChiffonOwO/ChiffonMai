import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 打字机文本：把 [text] 按 [characters]（字素簇）一个一个"打"出来。
///
/// 为什么必须有这个组件而不是每页各写一个 `Timer`：
///   * **必须按字素簇切**（`text.characters`），不能按 `String` 下标切 ——
///     按 code unit 切会把 emoji / 组合字（如 👨‍👩‍👧、带变音符号的拉丁字母）
///     切成半个，渲染出"豆腐块"或闪烁的替换符；
///   * **点一下立即全显**：摘要短的时候观感很好，但只要有一条答案偏长，
///     等它一个字一个字打完就是煎熬 —— 所以"可跳过"是刚需，不是可选项；
///   * **动画期间关闭无障碍朗读**：半截的句子被读屏软件逐字念出来毫无意义，
///     所以动画期间用 `ExcludeSemantics` 屏蔽，打完再暴露完整语义；
///   * **尊重系统"减弱动态效果"**：`MediaQuery.disableAnimations` 为真时直接全显；
///   * **页面不可见就暂停**：`TickerMode` 关闭（比如被别的路由盖住）时停掉定时器，
///     否则会在后台白烧电。
class TypewriterText extends StatefulWidget {
  const TypewriterText({
    super.key,
    required this.text,
    required this.onCompleted,
    this.onProgress,
    this.interval,
    this.minInterval = const Duration(milliseconds: 12),
    this.maxInterval = const Duration(milliseconds: 45),
    this.charsPerTick = 1,
    this.cursor = true,
    this.style,
    this.textAlign = TextAlign.start,
  });

  /// 要"打"出来的完整文本。
  final String text;

  /// 打完（或被跳过）时回调。**恰好一次**。
  final VoidCallback onCompleted;

  /// 每打出一个字素回调一次（用于让外层列表跟着滚到底）。
  final VoidCallback? onProgress;

  /// 每个字素的固定间隔；为 null 时按文本长度在
  /// [minInterval]~[maxInterval] 之间自适应（见下）。
  final Duration? interval;

  /// 短答案用的间隔上限（慢一点，观感好）。
  final Duration maxInterval;

  /// 长答案用的间隔下限（快一点，别让人等）。
  final Duration minInterval;

  /// 每个 tick 打几个字素。
  final int charsPerTick;

  /// 是否在打字过程中显示光标。
  final bool cursor;

  /// 测试用：拿到「按当前文本长度算出来的每字素间隔」。
  ///
  /// 直接量"打完一个字素花了几毫秒"不可靠 —— `Timer.periodic` 对非整数时长
  /// 会取整到毫秒网格，测出来两边都是 20ms，看不出自适应（踩过）。
  @visibleForTesting
  static Duration intervalFor({
    required String text,
    Duration? interval,
    Duration minInterval = const Duration(milliseconds: 12),
    Duration maxInterval = const Duration(milliseconds: 45),
  }) =>
      _computeInterval(
        length: text.characters.length,
        interval: interval,
        minInterval: minInterval,
        maxInterval: maxInterval,
      );

  static Duration _computeInterval({
    required int length,
    required Duration? interval,
    required Duration minInterval,
    required Duration maxInterval,
  }) {
    if (interval != null) return interval;
    if (length <= 40) return maxInterval;
    if (length >= 200) return minInterval;
    final t = (length - 40) / 160; // 0..1
    final ms = maxInterval.inMilliseconds -
        t * (maxInterval.inMilliseconds - minInterval.inMilliseconds);
    return Duration(milliseconds: ms.round());
  }

  final TextStyle? style;
  final TextAlign textAlign;

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  /// 按**字素簇**切分的结果，整个组件的下标都以它为准。
  late List<String> _graphemes;
  late String _prefix; // 前 n 个字素的累计字符串
  int _shown = 0;
  Timer? _timer;
  bool _completed = false;

  /// 是否已经进入过第一帧。`initState` 里不能读 `MediaQuery` / `TickerMode`，
  /// 所以启动动作推迟到 build 之后再执行。
  bool _firstBuildDone = false;

  @override
  void initState() {
    super.initState();
    _graphemes = widget.text.characters.toList(growable: false);
    _prefix = '';
  }

  @override
  void didUpdateWidget(TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _reset();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // 节奏
  // ---------------------------------------------------------------------------

  /// 每字素的间隔：按长度自适应（实现见 [TypewriterText.intervalFor]）。
  ///
  /// 单条知识有 1800+ 字，固定 30ms 要打将近一分钟；但短答案用 12ms 又太快、
  /// 没有"在打字"的观感。所以按长度线性插值：短答案慢、长答案快。
  Duration get _perGrapheme => TypewriterText.intervalFor(
        text: widget.text,
        interval: widget.interval,
        minInterval: widget.minInterval,
        maxInterval: widget.maxInterval,
      );

  /// 是否应该"瞬间全显"（系统开了"减弱动态效果"）。
  ///
  /// ⚠️ 只能在 build / 回调里读，不能在 `initState` 里读（那时还没有依赖）。
  bool get _instant => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  // ---------------------------------------------------------------------------
  // 状态机
  // ---------------------------------------------------------------------------

  void _reset() {
    _timer?.cancel();
    _timer = null;
    _graphemes = widget.text.characters.toList(growable: false);
    _prefix = '';
    _shown = 0;
    _completed = false;
    if (_firstBuildDone) _schedule();
  }

  /// 把启动/收尾推到下一帧，避免在 build 期间 `setState`。
  void _schedule() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _completed) return;
      if (_graphemes.isEmpty) {
        _finish();
        return;
      }
      if (_instant) {
        _skipToEnd();
        return;
      }
      _start();
    });
  }

  void _start() {
    if (_timer != null || _completed) return;
    // ⚠️ 用 valuesOf 而不是已废弃的 `TickerMode.of`（本项目 Flutter 3.41）
    if (!TickerMode.valuesOf(context).enabled) {
      // 页面不可见：不启动。TickerMode 重新打开时 build 会重新 _schedule。
      return;
    }
    _timer = Timer.periodic(_perGrapheme, (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    final step = math.max(1, widget.charsPerTick);
    final next = math.min(_shown + step, _graphemes.length);
    setState(() {
      _shown = next;
      _prefix = _graphemes.take(next).join();
    });
    widget.onProgress?.call();
    if (next >= _graphemes.length) _finish();
  }

  void _finish() {
    _timer?.cancel();
    _timer = null;
    if (_completed) return;
    _completed = true;
    widget.onCompleted();
  }

  /// 立即全显并结束（用户点击 / 无障碍要求 / 文本为空）。
  void _skipToEnd() {
    _timer?.cancel();
    _timer = null;
    if (_shown != _graphemes.length) {
      setState(() {
        _shown = _graphemes.length;
        _prefix = widget.text;
      });
    }
    _finish();
  }

  @override
  Widget build(BuildContext context) {
    if (!_firstBuildDone) {
      _firstBuildDone = true;
      _schedule();
    } else if (!_completed && _timer == null) {
      // TickerMode 由关变开会重建；这里补一次启动。
      // （_schedule 内部会自己判断要不要真启动，重复调用是安全的。）
      _schedule();
    }

    final typing = !_completed;
    final content = Text.rich(
      TextSpan(
        text: _prefix,
        children: typing && widget.cursor
            ? [
                TextSpan(
                  text: '▌',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ]
            : null,
      ),
      style: widget.style,
      textAlign: widget.textAlign,
    );

    return GestureDetector(
      // 点一下立即全显：长答案的救命按钮
      onTap: typing ? _skipToEnd : null,
      behavior: HitTestBehavior.opaque,
      child: typing
          // 动画期间屏蔽语义，避免读屏软件逐字念半截句子
          ? ExcludeSemantics(child: content)
          : Semantics(label: widget.text, child: content),
    );
  }
}
