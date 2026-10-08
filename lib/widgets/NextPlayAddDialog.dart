import 'package:flutter/material.dart';

import '../service/NextPlayQueueStore.dart';
import '../utils/AppTheme.dart';

/// 下次想玩的难度选项。索引与歌曲详情页、随身听保持一致。
class NextPlayDifficultyOption {
  final int index;
  final String name;
  final String? constant;

  const NextPlayDifficultyOption({
    required this.index,
    required this.name,
    this.constant,
  });

  static const names = <String>[
    'BASIC',
    'ADVANCED',
    'EXPERT',
    'MASTER',
    'Re:MASTER',
    'UTAGE',
  ];

  static List<NextPlayDifficultyOption> standard({
    List<String?> constants = const [],
    int count = 5,
  }) {
    final length = count.clamp(0, names.length).toInt();
    return List.generate(
      length,
      (index) => NextPlayDifficultyOption(
        index: index,
        name: names[index],
        constant: index < constants.length ? constants[index] : null,
      ),
    );
  }
}

class _NextPlayAddResult {
  final List<int> difficultyIndices;
  final int count;
  final String note;

  const _NextPlayAddResult({
    required this.difficultyIndices,
    required this.count,
    required this.note,
  });
}

/// 从歌曲详情与随身听共用的「下次想玩」添加表单。
Future<bool> showNextPlayAddDialog(
  BuildContext context, {
  required String songId,
  required String title,
  required String artist,
  String? type,
  int? coverId,
  List<NextPlayDifficultyOption>? difficulties,
}) async {
  final options = difficulties ?? NextPlayDifficultyOption.standard();
  final result = await showDialog<_NextPlayAddResult>(
    context: context,
    builder: (_) => _NextPlayAddForm(title: title, difficulties: options),
  );
  if (result == null) return false;

  await NextPlayQueueStore.instance.add(
    songId: songId,
    title: title,
    artist: artist,
    type: type,
    coverId: coverId,
    difficultyIndices: result.difficultyIndices,
    note: result.note,
    count: result.count,
  );
  return true;
}

class _NextPlayAddForm extends StatefulWidget {
  final String title;
  final List<NextPlayDifficultyOption> difficulties;

  const _NextPlayAddForm({
    required this.title,
    required this.difficulties,
  });

  @override
  State<_NextPlayAddForm> createState() => _NextPlayAddFormState();
}

class _NextPlayAddFormState extends State<_NextPlayAddForm> {
  final Set<int> _selected = <int>{};
  final TextEditingController _noteController = TextEditingController();
  int _count = 1;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(
      _NextPlayAddResult(
        difficultyIndices: _selected.toList()..sort(),
        count: _count,
        note: _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return AlertDialog(
      title: const Text('加入下次想玩'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text('想玩的难度（可多选）'),
            const SizedBox(height: 6),
            ...widget.difficulties.map((option) {
              final selected = _selected.contains(option.index);
              final background = AppColors.difficultyBackgroundByIndex(
                option.index,
                brightness: brightness,
              );
              final foreground = AppColors.difficultyForegroundByIndex(
                option.index,
                brightness: brightness,
              );
              final suffix = option.constant == null || option.constant!.isEmpty
                  ? ''
                  : ' ${option.constant}';
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() {
                    if (selected) {
                      _selected.remove(option.index);
                    } else {
                      _selected.add(option.index);
                    }
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? foreground
                            : foreground.withOpacity(0.35),
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          size: 20,
                          color: foreground,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${option.name}$suffix',
                            style: TextStyle(
                              color: foreground,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 4),
            Row(
              children: [
                const Expanded(child: Text('添加次数')),
                IconButton(
                  tooltip: '减少次数',
                  onPressed:
                      _count <= 1 ? null : () => setState(() => _count--),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                SizedBox(
                  width: 36,
                  child: Center(
                    child: Text(
                      '$_count',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '增加次数',
                  onPressed:
                      _count >= 99 ? null : () => setState(() => _count++),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            TextField(
              controller: _noteController,
              maxLines: 2,
              maxLength: 100,
              decoration: const InputDecoration(
                labelText: '备注（可选）',
                hintText: '例如：和朋友一起玩',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('加入'),
        ),
      ],
    );
  }
}
