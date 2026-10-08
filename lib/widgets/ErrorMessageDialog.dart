import 'package:flutter/material.dart';

/// 统一的错误信息弹窗。
///
/// 错误详情使用和文件导出结果相同的「主题信息区域 + 可选择文本」样式，
/// 方便长错误、网关返回内容和复制排查信息，不再让错误短暂消失在 Toast 中。
Future<void> showErrorMessageDialog(
  BuildContext context, {
  required String message,
  String title = '操作失败',
}) {
  final text = message.trim().isEmpty ? '未知错误' : message.trim();
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.error_outline_rounded,
              color: Theme.of(ctx).colorScheme.error),
          const SizedBox(width: 8),
          Expanded(child: Text(title)),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 360),
        child: SingleChildScrollView(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: Theme.of(ctx).colorScheme.outlineVariant),
            ),
            child: SelectableText(
              text,
              style: TextStyle(
                color: Theme.of(ctx).colorScheme.onSurface,
                fontSize: 13,
                height: 1.45,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('知道了'),
        ),
      ],
    ),
  );
}
