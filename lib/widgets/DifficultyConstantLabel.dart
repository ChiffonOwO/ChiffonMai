import 'package:flutter/material.dart';
import '../utils/ColorUtil.dart';
import '../utils/AppTheme.dart';

/// 只显示定数，用难度索引色填充底色；供选曲卡片等场景复用。
class DifficultyConstantLabel extends StatelessWidget {
  final double constant;
  final int difficultyIndex;
  final bool utage;
  const DifficultyConstantLabel(
      {super.key,
      required this.constant,
      required this.difficultyIndex,
      this.utage = false});
  @override
  Widget build(BuildContext context) {
    final background = utage
        ? AppColors.utageAccent(brightness: Theme.of(context).brightness)
        : ColorUtil.getCardColor(difficultyIndex);
    final foreground =
        ThemeData.estimateBrightnessForColor(background) == Brightness.dark
            ? Colors.white
            : Colors.black87;
    return Semantics(
        label: '${utage ? '宴会' : [
            'BASIC',
            'ADVANCED',
            'EXPERT',
            'MASTER',
            'Re:MASTER'
          ][difficultyIndex.clamp(0, 4)]} 定数 ${constant.toStringAsFixed(1)}',
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: background, borderRadius: BorderRadius.circular(6)),
            child: Text(constant.toStringAsFixed(1),
                style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                    fontSize: 12))));
  }
}
