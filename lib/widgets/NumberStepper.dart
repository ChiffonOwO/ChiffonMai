import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 受控数字步进器，数量与是否允许操作仍由页面决定。
class NumberStepper extends StatelessWidget {
  final int value;
  final int minimum;
  final int? maximum;
  final ValueChanged<int>? onChanged;
  final String suffix;
  final TextEditingController? controller;
  final ValueChanged<String>? onTextChanged;
  final String? errorText;
  const NumberStepper(
      {super.key,
      required this.value,
      required this.onChanged,
      this.minimum = 1,
      this.maximum,
      this.suffix = '',
      this.controller,
      this.onTextChanged,
      this.errorText});
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
          constraints: const BoxConstraints(minWidth: 64, maxWidth: 100),
          child: controller == null
              ? Text('$value$suffix',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium)
              : TextField(
                  controller: controller,
                  enabled: onChanged != null,
                  onChanged: onTextChanged,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    suffixText: suffix,
                    errorText: errorText,
                    errorMaxLines: 3,
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    border: const OutlineInputBorder(),
                  ),
                ),
        ),
        IconButton(
            tooltip: '增加数量',
            onPressed:
                onChanged == null || (maximum != null && value >= maximum!)
                    ? null
                    : () => onChanged!(value + 1),
            icon: const Icon(Icons.add)),
      ]);
}
