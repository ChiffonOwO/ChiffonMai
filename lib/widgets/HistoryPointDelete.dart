import 'package:flutter/material.dart';

import '../utils/AppTheme.dart';

/// 历史记录点的删除件：行尾按钮 + 确认弹窗。
///
/// 为什么抽出来：Rating 历史页与曲目详情页的成绩历史都要"删掉某一个记录点"，
/// 两处的按钮尺寸、提示语、确认文案必须一致 —— 一处叫"删除"另一处叫"移除"，
/// 用户会以为是两种不同的操作。
///
/// ⚠️ 删除**只删这一个时间点**，不会顺带清空整条曲线（清空在设置页，
/// 那是 `ChartHistoryStore.clear`）。

/// 记录点行尾的删除按钮。
///
/// 为什么不用 `IconButton`：Material 3 的 `IconButton` 默认带
/// `MaterialTapTargetSize.padded`，`ButtonStyleButton` 内部的 `_InputPadding`
/// 会把它**撑成 48×48**——一行记录正文才 20 出头的高度，一个 48 的按钮能把行距
/// 拉高一倍。这里用 `InkWell` 自己压到 26×26，与行高对齐（点按热区仍是整块）。
class HistoryPointDeleteButton extends StatelessWidget {
  const HistoryPointDeleteButton({
    super.key,
    required this.onPressed,
    this.tooltip = '删除这个记录点',
  });

  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 26,
          height: 26,
          child: Icon(
            Icons.delete_outline_rounded,
            size: 15,
            color: AppColors.greyHint(brightness),
          ),
        ),
      ),
    );
  }
}

/// 删除单个记录点前的确认框；返回 true = 用户确认删除。
///
/// [pointLabel] 要让用户认出删的是哪一条（时间 + 数值），别只写"确定删除吗"。
/// [note] 用来补充"删了会怎样"，默认文案已经说明自动采集的点可能重新出现。
Future<bool> confirmDeleteHistoryPoint(
  BuildContext context, {
  required String pointLabel,
  String? note,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('删除这个记录点？'),
      content: Text(
        '$pointLabel\n\n'
        '${note ?? '删除后无法恢复。如果它是自动采集到的当前成绩，下次刷新可能会重新记录。'}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
