import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/CommonWidgetUtil.dart';
import '../widgets/PageTopBar.dart';

String attendanceRegionLabel(int index) => index.isEven ? '出勤' : '不出勤';

int normalizeAttendanceCount(int count) {
  final bounded = count.clamp(2, 100);
  return bounded.isOdd ? bounded + 1 : bounded;
}

class AttendanceWheelPage extends StatefulWidget {
  const AttendanceWheelPage({super.key});
  @override
  State<AttendanceWheelPage> createState() => _AttendanceWheelPageState();
}

class _AttendanceWheelPageState extends State<AttendanceWheelPage>
    with SingleTickerProviderStateMixin {
  static const _countKey = 'attendance_wheel_region_count';
  final _random = math.Random.secure();
  late final AnimationController _controller;
  Animation<double> _rotation = const AlwaysStoppedAnimation(0);
  SharedPreferences? _prefs;
  int _count = 20;
  int? _result;
  int? _target;
  double _angle = 0;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed && mounted) {
              setState(() {
                _angle = _rotation.value;
                _result = _target;
              });
            }
          });
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _count = normalizeAttendanceCount(prefs.getInt(_countKey) ?? 20);
    });
    if (_count != prefs.getInt(_countKey))
      await prefs.setInt(_countKey, _count);
  }

  void _setCount(int value) {
    if (_controller.isAnimating || _prefs == null) return;
    setState(() {
      _count = normalizeAttendanceCount(value);
      _result = null;
      _angle = 0;
      _rotation = const AlwaysStoppedAnimation(0);
    });
    _prefs!.setInt(_countKey, _count);
  }

  void _spin() {
    if (_controller.isAnimating || _prefs == null) return;
    final winner = _random.nextInt(_count);
    final fullTurn = math.pi * 2;
    final targetAngle =
        (fullTurn - (winner + .5) * fullTurn / _count) % fullTurn;
    final end = _angle +
        5 * fullTurn +
        (targetAngle - _angle % fullTurn + fullTurn) % fullTurn;
    setState(() {
      _result = null;
      _target = winner + 1;
      _rotation = Tween<double>(begin: _angle, end: end).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      _controller.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spinning = _controller.isAnimating;
    return Scaffold(
      resizeToAvoidBottomInset: false,
        backgroundColor: Colors.transparent,
        body: Stack(fit: StackFit.expand, children: [
          ColoredBox(color: scheme.surface),
          CommonWidgetUtil.buildCommonBgWidget(),
          CommonWidgetUtil.buildCommonChiffonBgWidget(context),
          Column(children: [
            const PageTopBar(title: '出勤转盘'),
            Expanded(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(children: [
                      Text('出勤和不出勤交替排布，让转盘决定今天要不要出勤吧。',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                      const SizedBox(height: 20),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('区域数量'),
                            const SizedBox(width: 12),
                            IconButton(
                                tooltip: '减少区域',
                                onPressed:
                                    spinning || _prefs == null || _count <= 2
                                        ? null
                                        : () => _setCount(_count - 2),
                                icon: const Icon(Icons.remove)),
                            SizedBox(
                                width: 48,
                                child: Text('$_count',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge)),
                            IconButton(
                                tooltip: '增加区域',
                                onPressed:
                                    spinning || _prefs == null || _count >= 100
                                        ? null
                                        : () => _setCount(_count + 2),
                                icon: const Icon(Icons.add)),
                          ]),
                      const Text('默认 20，最多 100 区；每次增减 2 区，保持交替'),
                      const SizedBox(height: 20),
                      ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: AspectRatio(
                              aspectRatio: 1,
                              child: Stack(
                                  alignment: Alignment.topCenter,
                                  children: [
                                    Positioned.fill(
                                        child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: AnimatedBuilder(
                                                animation: _controller,
                                                builder: (_, __) =>
                                                    Transform.rotate(
                                                        angle: _rotation.value,
                                                        child: CustomPaint(
                                                            painter:
                                                                _WheelPainter(
                                                                    _count,
                                                                    scheme)))))),
                                    Icon(Icons.arrow_drop_down,
                                        size: 48, color: scheme.primary),
                                  ]))),
                      const SizedBox(height: 20),
                      Semantics(
                          liveRegion: true,
                          child: Text(
                              _result == null
                                  ? (spinning ? '转盘正在旋转…' : '准备好就开始吧')
                                  : '本次：${attendanceRegionLabel(_result! - 1)}',
                              style: Theme.of(context).textTheme.titleLarge)),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                          onPressed: spinning || _prefs == null ? null : _spin,
                          icon: const Icon(Icons.casino_outlined),
                          label: const Text('转一转')),
                    ])))
          ])
        ]));
  }
}

class _WheelPainter extends CustomPainter {
  final int count;
  final ColorScheme scheme;
  _WheelPainter(this.count, this.scheme);
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweep = math.pi * 2 / count;
    for (var i = 0; i < count; i++) {
      final start = -math.pi / 2 + i * sweep;
      canvas.drawArc(
          rect,
          start,
          sweep,
          true,
          Paint()
            ..color =
                i.isEven ? scheme.primaryContainer : scheme.secondaryContainer);
      canvas.drawLine(
          center,
          center + Offset(math.cos(start), math.sin(start)) * radius,
          Paint()
            ..color = scheme.outlineVariant
            ..strokeWidth = 1);
      final angle = start + sweep / 2;
      final labelRadius = radius * (count > 50 ? .88 : .83);
      final fontSize = (sweep * labelRadius * .8).clamp(5.0, 12.0);
      final painter = TextPainter(
          text: TextSpan(
              text: attendanceRegionLabel(i),
              style: TextStyle(
                  color: i.isEven
                      ? scheme.onPrimaryContainer
                      : scheme.onSecondaryContainer,
                  fontSize: fontSize,
                  height: 1,
                  fontWeight: FontWeight.bold)),
          textDirection: TextDirection.ltr)
        ..layout();
      // 区域较多时沿半径排数字，避免相邻编号横向重叠。
      canvas.save();
      final labelCenter =
          center + Offset(math.cos(angle), math.sin(angle)) * labelRadius;
      canvas.translate(labelCenter.dx, labelCenter.dy);
      canvas.rotate(angle);
      painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
      canvas.restore();
    }
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = scheme.outlineVariant
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    canvas.drawCircle(center, radius * .09, Paint()..color = scheme.primary);
  }

  @override
  bool shouldRepaint(_WheelPainter oldDelegate) =>
      count != oldDelegate.count || scheme != oldDelegate.scheme;
}
