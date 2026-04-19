import 'dart:ui';

import 'package:flutter/material.dart';

class ColorUtil {
  /**
   * 获取星星等级颜色
   * @param stars 星星等级字符串
   * @return 星星等级颜色
   */
  static Color getStarsColor(String stars) {
    switch (stars) {
      case '\u27266':
      case '\u27265.5':
      case '\u27265':
        return Colors.yellow;
      case '\u27264':
      case '\u27263':
        return Colors.orange;
      case '\u27262':
      case '\u27261':
        return Colors.green.shade300;
      default:
        return Colors.white;
    }
  }

  /**
   * 获取卡片颜色 用于Best50页面
   * @param levelIndex 等级索引
   * @return 卡片颜色
   */
  static Color getCardColor(int levelIndex) {
    List<Color> colors = [
      Colors.green, // level_index 0
      Colors.yellow, // level_index 1
      Colors.red, // level_index 2
      Colors.purple.shade400, // level_index 3
      Colors.purple.shade200, // level_index 4
    ];
    return colors[levelIndex.clamp(0, 4)];
  }


}