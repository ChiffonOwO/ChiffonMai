import 'package:flutter/material.dart';

/// 历史点共用的日期、时分和秒选择器。
Future<DateTime?> showHistoryDateTimeDialog(
  BuildContext context, {
  DateTime? initial,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (_) => _HistoryDateTimeDialog(initial: initial ?? DateTime.now()),
  );
}

/// 为什么 controller 由弹窗自己的 [State] 持有并释放，**不能**在调用方
/// `await showDialog(...)` 之后再 dispose：
///
/// `showDialog` 返回的 future 是 `Route.popped` —— pop 那一刻就完成，而弹窗
/// 此时还在**退场动画**里（真机上键盘收起会让弹窗重建，`TextField` 会再读一次
/// controller）。于是必现「A TextEditingController was used after being
/// disposed」；更糟的是这个异常发生在**卸载/重建**途中，元素树会被撕成半死
/// 状态，紧接着刷出成串断言——
/// `'_dependents.isEmpty': is not true` 与
/// 「Tried to build dirty widget in the wrong build scope」（用户看到的就是红屏）。
///
/// 交给 [State.dispose] 就**结构上**不可能提前：它只在弹窗元素真正卸载之后才跑。
/// 同类坑与另一种修法（等 `Route.completed`）见 `lib/widgets/SyncScoreDialogs.dart`。
class _HistoryDateTimeDialog extends StatefulWidget {
  const _HistoryDateTimeDialog({required this.initial});

  final DateTime initial;

  @override
  State<_HistoryDateTimeDialog> createState() => _HistoryDateTimeDialogState();
}

class _HistoryDateTimeDialogState extends State<_HistoryDateTimeDialog> {
  static String _two(int value) => value.toString().padLeft(2, '0');

  late DateTime _selected;
  late final TextEditingController _secondsController;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
    _secondsController = TextEditingController(text: _two(_selected.second));
  }

  @override
  void dispose() {
    _secondsController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: DateTime(1970),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selected = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _selected.hour,
        _selected.minute,
        _selected.second,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selected),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selected = DateTime(
        _selected.year,
        _selected.month,
        _selected.day,
        picked.hour,
        picked.minute,
        _selected.second,
      );
    });
  }

  void _onSecondsChanged(String value) {
    final seconds = int.tryParse(value);
    setState(() {
      if (seconds != null && seconds >= 0 && seconds <= 59) {
        _selected = DateTime(
          _selected.year,
          _selected.month,
          _selected.day,
          _selected.hour,
          _selected.minute,
          seconds,
        );
      }
    });
  }

  void _confirm() {
    final seconds = int.tryParse(_secondsController.text);
    if (seconds == null || seconds < 0 || seconds > 59) return;
    Navigator.of(context).pop(DateTime(
      _selected.year,
      _selected.month,
      _selected.day,
      _selected.hour,
      _selected.minute,
      seconds,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final dateText = '${_selected.year}-${_two(_selected.month)}-'
        '${_two(_selected.day)}';
    final timeText =
        '${_two(_selected.hour)}:${_two(_selected.minute)}';
    return AlertDialog(
      title: const Text('选择时间'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(dateText),
              onPressed: _pickDate,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.schedule_outlined),
              label: Text(
                  '$timeText:${_secondsController.text.padLeft(2, '0')}'),
              onPressed: _pickTime,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _secondsController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '秒（0-59）',
              border: OutlineInputBorder(),
            ),
            onChanged: _onSecondsChanged,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _confirm,
          child: const Text('确定'),
        ),
      ],
    );
  }
}
