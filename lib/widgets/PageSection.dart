import 'package:flutter/material.dart';

/// 页面内的语义分组。
///
/// 默认保持透明，让内容直接参与背景构图；当表单、表格或说明需要更强的
/// 对比度时，可通过 [surface] 使用主题提供的局部 surface，而不是重新包住整页。
class PageSection extends StatelessWidget {
  final Widget child;
  final String? title;
  final String? subtitle;
  final bool surface;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const PageSection({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.surface = false,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );

    return Padding(
      padding: margin,
      child: surface
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow.withValues(alpha: 0.86),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: content,
            )
          : content,
    );
  }
}
