import 'package:flutter/material.dart';
import 'AppTheme.dart';

/// 共享常量：集中管理跨页面使用的布局常量
class AppConstants {
  // 圆角常量
  static const double borderRadiusSmall = 8.0;
  static const double borderRadiusLarge = 12.0;

  // 边框常量
  static const double borderWidth = 1.5;

  // 网格布局常量
  static const int crossAxisCount = 2;

  // 阴影常量（委托给 AppColors）
  static BoxShadow defaultShadow(Brightness b) => AppColors.defaultShadow(b);
}
