import 'package:flutter/material.dart';
import '../service/RankTable/RankCompletionStore.dart';
import '../utils/AppTheme.dart';

/// 段位完成情况的文字标签，同时作为编辑入口。
class RankCompletionButton extends StatelessWidget {
  final String rank;
  final bool showAchievement;
  const RankCompletionButton({
    super.key,
    required this.rank,
    this.showAchievement = true,
  });

  static String label(RankCompletion status) => switch (status) {
        RankCompletion.unplayed => '未挑战',
        RankCompletion.failed => '不合格',
        RankCompletion.passed => '合格',
        RankCompletion.redPassed => '赤合格',
      };

  static Color color(BuildContext context, RankCompletion status) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    return switch (status) {
      RankCompletion.unplayed => scheme.surfaceContainerHighest,
      RankCompletion.failed => scheme.errorContainer,
      RankCompletion.passed => AppColors.successSurface(brightness),
      RankCompletion.redPassed =>
        Color.lerp(scheme.surface, AppColors.warningOrange(brightness), .22)!,
    };
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: RankCompletionStore.instance,
        builder: (_, __) {
          final store = RankCompletionStore.instance;
          final status = store.status(rank);
          final achievement = store.achievement(rank);
          final suffix = !showAchievement ||
                  status == RankCompletion.unplayed ||
                  achievement == null
              ? ''
              : ' · ${achievement.toStringAsFixed(4)}%';
          return InkWell(
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => _RankCompletionDialog(rank: rank),
            ),
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: color(context, status),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${label(status)}$suffix',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          );
        },
      );
}

class _RankCompletionDialog extends StatefulWidget {
  final String rank;
  const _RankCompletionDialog({required this.rank});

  @override
  State<_RankCompletionDialog> createState() => _RankCompletionDialogState();
}

class _RankCompletionDialogState extends State<_RankCompletionDialog> {
  late final TextEditingController _controller;
  late RankCompletion _status;

  @override
  void initState() {
    super.initState();
    final store = RankCompletionStore.instance;
    _status = store.status(widget.rank);
    _controller = TextEditingController(
        text: store.achievement(widget.rank)?.toStringAsFixed(4) ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final raw = _controller.text.trim();
    final value = raw.isEmpty ? null : double.tryParse(raw);
    final fraction = raw.contains('.') ? raw.split('.').last : '';
    if (fraction.length > 4 || (value != null && (value < 0 || value > 404))) {
      return;
    }
    // 先结束路由退出动画，持久化通知在弹窗销毁后进行。
    Navigator.pop(context);
    await RankCompletionStore.instance.setCompletion(widget.rank, _status,
        _status == RankCompletion.unplayed ? null : value);
  }

  @override
  Widget build(BuildContext context) {
    final canInput = _status != RankCompletion.unplayed;
    return AlertDialog(
      title: const Text('段位完成情况'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final option in RankCompletion.values)
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _status = option),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: option == _status
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Expanded(child: Text(RankCompletionButton.label(option))),
                if (option == _status) const Icon(Icons.check, size: 18),
              ]),
            ),
          ),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          enabled: canInput,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
              labelText: '总达成率（最高 404.0000%）', suffixText: '%'),
        ),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }
}
