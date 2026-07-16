import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/utils/ImageEncodeUtil.dart';

/// 导出质量选择结果
class ExportQualityResult {
  /// JPEG 质量值 (0-100)，null 表示 PNG 无损
  final int? jpegQuality;
  /// 显示标签
  final String label;

  const ExportQualityResult({
    required this.jpegQuality,
    required this.label,
  });

  /// 预设选项列表
  static const List<ExportQualityResult> presets = [
    ExportQualityResult(jpegQuality: null, label: 'PNG 无损（原始画质）'),
    ExportQualityResult(jpegQuality: 95, label: 'JPEG 高质量'),
    ExportQualityResult(jpegQuality: 85, label: 'JPEG 标准'),
    ExportQualityResult(jpegQuality: 70, label: 'JPEG 压缩'),
  ];

  /// 获取文件扩展名
  String get extension => jpegQuality != null ? 'jpg' : 'png';

  /// 获取格式名称
  String get formatName => jpegQuality != null ? 'JPEG (Q$jpegQuality)' : 'PNG';
}

/// 导出质量选择底部弹窗
///
/// 用法：
/// ```dart
/// final quality = await ExportQualitySelector.show(
///   context,
///   estimatedPngSize: ImageEncodeUtil.estimatePngSize(songCount: 50),
/// );
/// if (quality != null) {
///   // 使用 quality.jpegQuality 导出
/// }
/// ```
class ExportQualitySelector {
  /// 显示质量选择底部弹窗
  /// [context] BuildContext
  /// [estimatedPngSize] 预估的 PNG 文件大小（字节）
  /// 返回用户选择的质量，null 表示取消
  static Future<ExportQualityResult?> show(
    BuildContext context, {
    required int estimatedPngSize,
  }) async {
    int? selectedIndex = 0; // 默认选中 PNG

    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 拖拽手柄
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // 标题
                  const Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Text(
                      '选择导出质量',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(),
                  // 选项列表
                  ...List.generate(
                    ExportQualityResult.presets.length,
                    (i) {
                      final preset = ExportQualityResult.presets[i];
                      final estimatedSize = _getEstimatedSize(
                          estimatedPngSize, preset.jpegQuality);
                      final isSelected = selectedIndex == i;

                      return ListTile(
                        selected: isSelected,
                        selectedTileColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        leading: Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey[500],
                        ),
                        title: Text(
                          preset.label,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          '预计大小: $estimatedSize',
                          style: TextStyle(
                            fontSize: 14,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey[600],
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle,
                                color:
                                    Theme.of(context).colorScheme.primary,
                              )
                            : null,
                        onTap: () => setState(() => selectedIndex = i),
                      );
                    },
                  ),
                  const Divider(),
                  // 底部按钮
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx, -1),
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text(
                              '取消',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: FilledButton(
                            onPressed: () =>
                                Navigator.pop(ctx, selectedIndex),
                            style: FilledButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text(
                              '确认导出',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result == null || result < 0) {
      return null; // 用户取消
    }

    return ExportQualityResult.presets[result];
  }

  /// 获取预估文件大小的显示文本
  static String _getEstimatedSize(int pngSize, int? jpegQuality) {
    if (jpegQuality == null) {
      return ImageEncodeUtil.formatFileSize(pngSize);
    }
    final estimatedJpegSize =
        ImageEncodeUtil.estimateJpegSize(pngSize, jpegQuality);
    return ImageEncodeUtil.formatFileSize(estimatedJpegSize);
  }
}
