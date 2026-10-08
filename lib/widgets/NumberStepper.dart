import 'package:flutter/material.dart';

/// 受控数字步进器，数量与是否允许操作仍由页面决定。
class NumberStepper extends StatelessWidget {
  final int value;
  final int minimum;
  final int? maximum;
  final ValueChanged<int>? onChanged;
  final String suffix;
  const NumberStepper(
      {super.key,
      required this.value,
      required this.onChanged,
      this.minimum = 1,
      this.maximum,
      this.suffix = ''});
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
            tooltip: '减少数量',
            onPressed: onChanged == null || value <= minimum
                ? null
                : () => onChanged!(value - 1),
            icon: const Icon(Icons.remove)),
        ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 56),
            child: Text('$value$suffix',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium)),
        IconButton(
            tooltip: '增加数量',
            onPressed:
                onChanged == null || (maximum != null && value >= maximum!)
                    ? null
                    : () => onChanged!(value + 1),
            icon: const Icon(Icons.add)),
      ]);
}
