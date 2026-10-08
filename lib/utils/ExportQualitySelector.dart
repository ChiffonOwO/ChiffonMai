import '../widgets/AnimatedChoiceBar.dart';
import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/utils/ImageEncodeUtil.dart';

/// 导出质量选择结果
class ExportQualityResult {
  /// JPEG 质量值 (0-100)，null 表示 PNG 无损
  final int? jpegQuality;

  /// 显示标签
  final String label;

  /// Best50 导出时是否采用雷霆模式（单列 50 行或单行 50 列）。
  final bool thunderMode;
  final bool thunderVertical;

  const ExportQualityResult({
    required this.jpegQuality,
    required this.label,
    this.thunderMode = false,
    this.thunderVertical = true,
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
    String? exportingLabel,
    bool enableThunderMode = false,
    bool initialThunderMode = false,
    bool initialThunderVertical = true,
  }) async {
    int? selectedIndex = 0; // 默认选中 PNG
    var thunderMode = initialThunderMode;
    var thunderVertical = initialThunderVertical;

    final result = await showModalBottomSheet<_ExportSelection>(
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
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Text(
                      '选择导出质量',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (exportingLabel != null &&
                      exportingLabel.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                      child: Text(
                        '当前正在导出：$exportingLabel',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 14,
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

                      return AnimatedContainer(
                          duration: const Duration(milliseconds: 240),
                          decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8)),
                          child: ListTile(
                            selected: isSelected,
                            selectedTileColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            leading: FadeContent(
                                child: Icon(
                              key: ValueKey(isSelected),
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                            )),
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
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
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
                          ));
                    },
                  ),
                  if (enableThunderMode) ...[
                    const Divider(),
                    SwitchListTile(
                      value: thunderMode,
                      onChanged: (value) => setState(() => thunderMode = value),
                      title: const Text('雷霆模式'),
                      subtitle: const Text('将歌曲卡片改为单列 50 行或单行 50 列，适合超长图片'),
                    ),
                    if (thunderMode)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment<bool>(
                                value: true, label: Text('单列 50 行')),
                            ButtonSegment<bool>(
                                value: false, label: Text('单行 50 列')),
                          ],
                          selected: {thunderVertical},
                          onSelectionChanged: (values) =>
                              setState(() => thunderVertical = values.first),
                        ),
                      ),
                  ],
                  const Divider(),
                  // 底部按钮
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx, null),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
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
                            onPressed: () => Navigator.pop(
                              ctx,
                              _ExportSelection(
                                selectedIndex: selectedIndex!,
                                thunderMode: thunderMode,
                                thunderVertical: thunderVertical,
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
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

    if (result == null) {
      return null; // 用户取消
    }

    final preset = ExportQualityResult.presets[result.selectedIndex];
    return ExportQualityResult(
      jpegQuality: preset.jpegQuality,
      label: preset.label,
      thunderMode: result.thunderMode,
      thunderVertical: result.thunderVertical,
    );
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

class _ExportSelection {
  final int selectedIndex;
  final bool thunderMode;
  final bool thunderVertical;

  const _ExportSelection({
    required this.selectedIndex,
    required this.thunderMode,
    required this.thunderVertical,
  });
}
