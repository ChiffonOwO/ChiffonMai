import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 导出或下载完成后的结果弹窗。
///
/// 路径区域使用当前主题的 surfaceContainerHighest，避免深色模式下出现白底；
/// [fallbackPath] 用于提示公开目录不可写时的备用路径。
Future<void> showExportSuccessDialog(
  BuildContext context, {
  required String filePath,
  required String fileName,
  String title = '导出成功',
  String successPrefix = '已导出',
  String? fallbackPath,
  String? warning,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _ExportSuccessDialog(
      filePath: filePath,
      fileName: fileName,
      title: title,
      successPrefix: successPrefix,
      fallbackPath: fallbackPath,
      warning: warning,
    ),
  );
}

class _ExportSuccessDialog extends StatefulWidget {
  final String filePath;
  final String fileName;
  final String title;
  final String successPrefix;
  final String? fallbackPath;
  final String? warning;

  const _ExportSuccessDialog({
    required this.filePath,
    required this.fileName,
    required this.title,
    required this.successPrefix,
    this.fallbackPath,
    this.warning,
  });

  @override
  State<_ExportSuccessDialog> createState() => _ExportSuccessDialogState();
}

class _ExportSuccessDialogState extends State<_ExportSuccessDialog> {
  bool _copied = false;

  Future<void> _copyPath() async {
    await Clipboard.setData(ClipboardData(text: widget.filePath));
    if (!mounted) return;
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('路径已复制到剪贴板')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasWarning = widget.fallbackPath != null || widget.warning != null;
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade600, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Text(widget.title)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.successPrefix} ${widget.fileName}',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            '文件已保存到：',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.maxFinite,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: SelectableText(
              widget.filePath,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                height: 1.4,
                color: scheme.onSurface,
              ),
            ),
          ),
          if (hasWarning) ...[
            const SizedBox(height: 10),
            Container(
              width: double.maxFinite,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.fallbackPath != null)
                    Text(
                      '公开目录不可写，文件已保存到备用路径：${widget.fallbackPath}',
                      style: TextStyle(fontSize: 12, height: 1.4, color: scheme.onSurface),
                    ),
                  if (widget.fallbackPath != null && widget.warning != null)
                    const SizedBox(height: 4),
                  if (widget.warning != null)
                    Text(widget.warning!, style: TextStyle(fontSize: 12, height: 1.4, color: scheme.onSurface)),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: _copyPath,
          icon: Icon(
            _copied ? Icons.check : Icons.copy,
            size: 16,
            color: _copied ? Colors.green.shade600 : null,
          ),
          label: Text(_copied ? '已复制' : '复制路径'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
