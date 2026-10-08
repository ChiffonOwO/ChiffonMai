import 'package:flutter/material.dart';
import '../utils/AppTheme.dart';

/// ST/DX 沿用歌曲详情页的蓝/橙色样式，宴会完整写为 UTAGE。
class SongTypeLabel extends StatelessWidget {
  final String type;
  final String songId;
  const SongTypeLabel({super.key, required this.type, required this.songId});
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final utage = songId.length == 6 || type == 'UTAGE';
    return Text(
        utage
            ? 'UTAGE'
            : type == 'DX'
                ? 'DX'
                : 'ST',
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: utage
                ? AppColors.utageAccent(brightness: brightness)
                : type == 'DX'
                    ? AppColors.warningOrange(brightness)
                    : AppColors.linkBlue(brightness)));
  }
}
