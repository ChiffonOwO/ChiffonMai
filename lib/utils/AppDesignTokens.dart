import 'package:flutter/material.dart';

class AppDesignTokens {
  AppDesignTokens._();

  static const pagePadding = EdgeInsets.fromLTRB(20, 18, 20, 28);
  static const sectionGap = 28.0;
  static const itemGap = 12.0;
  static const radiusMedium = 16.0;
  static const radiusLarge = 24.0;
  static const minTouchTarget = 48.0;
  static const maxContentWidth = 1120.0;
  static const fastMotion = Duration(milliseconds: 180);
}

class AppSurfaces {
  static Color panel(BuildContext context) => Theme.of(context).colorScheme.surfaceContainerLow;
  static Color elevated(BuildContext context) => Theme.of(context).colorScheme.surfaceContainer;
  static Color accent(BuildContext context) => Theme.of(context).colorScheme.primaryContainer;
}
