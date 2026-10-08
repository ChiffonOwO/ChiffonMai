import 'package:flutter/material.dart';

/// 可复用的无内容提示，文案可由页面按场景覆盖。
class EmptyState extends StatelessWidget {
  final String message;
  final Widget? action;
  const EmptyState({super.key, this.message = '啥都木有', this.action});
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(r'¯\_(ツ)_/¯',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ])));
}
