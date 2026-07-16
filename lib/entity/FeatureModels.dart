import 'package:flutter/material.dart';

/// 功能按钮数据模型
class ButtonItem {
  final IconData icon;
  final String title;
  final String subtitle;

  const ButtonItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

/// 按钮分类数据模型
class ButtonCategory {
  final String name;
  final List<ButtonItem> items;

  const ButtonCategory({
    required this.name,
    required this.items,
  });
}
