import 'dart:ui';

import 'package:flutter/material.dart';

class KaleidXScopeSelectService {
  // 获取所有可用的KaleidX Scope图片
  List<String> getScopeImages() {
    return [
      'assets/kaleidxscope/blue.webp',
      'assets/kaleidxscope/white.webp',
      'assets/kaleidxscope/purple.webp',
      'assets/kaleidxscope/black.webp',
    ];
  }

  // 获取Scope的名称
  String getScopeName(String imagePath) {
    final fileName = imagePath.split('/').last;
    final name = fileName.split('.').first;
    return _capitalizeFirstLetter(name);
  }

  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  // 获取难度颜色
  static Color getDifficultyColor(String type) {
    switch (type.toUpperCase()) {
      case 'MASTER':
        return Color(0xFF9966CC); // 紫色
      case 'EXPERT':
        return Color(0xFFE91E63); // 红色
      case 'BASIC':
        return Color(0xFF4CAF50); // 绿色
      default:
        return Colors.grey;
    }
  }
}