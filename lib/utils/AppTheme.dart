import 'package:flutter/material.dart';

/// 集中式主题定义：提供浅色和暗色 ThemeData，以及主题感知的颜色访问器
class AppTheme {
  // ========== ColorScheme 定义 ==========

  static const ColorScheme lightColorScheme = ColorScheme.light(
    primary: Color(0xFF546161),
    onPrimary: Colors.white,
    surface: Colors.white,
    onSurface: Color(0xFF546161),
    surfaceContainerHighest: Color.fromARGB(230, 255, 255, 255),
    outline: Color.fromARGB(199, 192, 133, 100),
    secondary: Color(0xFF6D7D7D),
    onSurfaceVariant: Color(0xFF6D7D7D),
    tertiary: Color.fromARGB(210, 227, 232, 125),
  );

  static const ColorScheme darkColorScheme = ColorScheme.dark(
    primary: Color(0xFFB0C4C4),
    onPrimary: Color(0xFF1E1E2E),
    surface: Color(0xFF1E1E2E),
    onSurface: Color(0xFFB0C4C4),
    surfaceContainerHighest: Color.fromARGB(230, 30, 30, 46),
    outline: Color.fromARGB(199, 150, 140, 120),
    secondary: Color(0xFF9EADAD),
    onSurfaceVariant: Color(0xFF9EADAD),
    tertiary: Color.fromARGB(210, 100, 100, 80),
  );

  // ========== ThemeData 构建 ==========

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: lightColorScheme,
      scaffoldBackgroundColor: Colors.transparent,
      cardTheme: CardThemeData(
        color: lightColorScheme.surface,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      appBarTheme: AppBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: lightColorScheme.primary),
        titleTextStyle: TextStyle(
          color: lightColorScheme.primary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lightColorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightColorScheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: lightColorScheme.primary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightColorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: lightColorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: lightColorScheme.primary, width: 2),
        ),
      ),
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: darkColorScheme,
      scaffoldBackgroundColor: const Color(0xFF121220),
      cardTheme: CardThemeData(
        color: darkColorScheme.surface,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      appBarTheme: AppBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: darkColorScheme.primary),
        titleTextStyle: TextStyle(
          color: darkColorScheme.primary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkColorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkColorScheme.primary,
          foregroundColor: const Color(0xFF1E1E2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: darkColorScheme.primary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkColorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: darkColorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: darkColorScheme.primary, width: 2),
        ),
      ),
    );
  }
}

/// 主题感知的颜色访问器 — 新代码使用这些方法替代硬编码颜色
class AppColors {
  /// 主文字色（标题、重要文本）
  static Color primaryText(Brightness brightness) =>
      brightness == Brightness.dark
          ? const Color(0xFFB0C4C4)
          : const Color(0xFF546161);

  /// 次要文字色（辅助文本）
  static Color secondaryText(Brightness brightness) =>
      brightness == Brightness.dark
          ? const Color(0xFF9EADAD)
          : const Color(0xFF6D7D7D);

  /// 卡片/容器背景色
  static Color cardBackground(Brightness brightness) =>
      brightness == Brightness.dark
          ? const Color.fromARGB(230, 30, 30, 46)
          : Colors.white;

  /// 半透明卡片背景（叠加在背景图上）
  static Color cardBackgroundTranslucent(Brightness brightness) =>
      brightness == Brightness.dark
          ? const Color.fromARGB(200, 30, 30, 46)
          : Colors.white.withValues(alpha: 0.9);

  /// Scaffold 纯色背景（暗色模式下替代透明背景）
  static Color scaffoldBackground(Brightness brightness) =>
      brightness == Brightness.dark
          ? const Color(0xFF121220)
          : Colors.transparent;

  /// 首页按钮背景色
  static Color buttonBackground(Brightness brightness) =>
      brightness == Brightness.dark
          ? const Color.fromARGB(210, 100, 100, 80)
          : const Color.fromARGB(210, 227, 232, 125);

  /// 首页按钮边框色
  static Color buttonBorder(Brightness brightness) =>
      brightness == Brightness.dark
          ? const Color.fromARGB(199, 150, 140, 120)
          : const Color.fromARGB(199, 192, 133, 100);

  /// 默认阴影
  static BoxShadow defaultShadow(Brightness brightness) =>
      brightness == Brightness.dark
          ? BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, 3),
            )
          : BoxShadow(
              color: Colors.black12,
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, 3),
            );

  /// 灰色文本/图标（根据主题调整深度）
  static Color greyHint(Brightness brightness, {int shade = 500}) =>
      brightness == Brightness.dark
          ? Colors.grey.shade500
          : Colors.grey.shade400;

  /// 表格/列表边框色
  static Color tableBorder(Brightness brightness) =>
      brightness == Brightness.dark
          ? Colors.grey.shade700
          : Colors.grey.shade300;

  /// 语义红色（错误、危险）
  static Color errorRed(Brightness brightness) =>
      brightness == Brightness.dark
          ? const Color(0xFFEF5350)
          : Colors.red;

  /// 语义绿色（成功）
  static Color successGreen(Brightness brightness) =>
      brightness == Brightness.dark
          ? const Color(0xFF66BB6A)
          : Colors.green;

  /// 语义蓝色（链接、信息）
  static Color linkBlue(Brightness brightness) =>
      brightness == Brightness.dark
          ? const Color(0xFF64B5F6)
          : Colors.blue;

  /// 语义橙色（警告）
  static Color warningOrange(Brightness brightness) =>
      brightness == Brightness.dark
          ? const Color(0xFFFFB74D)
          : Colors.orange;

  // ========== 语义颜色（不随主题变化 — 代表游戏内固定概念） ==========

  /// 难度等级前景色（文字/边框）
  static Color difficultyForeground(String level) {
    switch (level.toUpperCase()) {
      case 'BASIC':
        return const Color(0xFF4CAF50);
      case 'ADVANCED':
        return const Color(0xFFFF9800);
      case 'EXPERT':
        return const Color(0xFFE91E63);
      case 'MASTER':
        return const Color(0xFF9966CC);
      case 'RE:MASTER':
      case 'REMASTER':
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFF546161);
    }
  }

  /// 难度等级背景色（浅色用于标签/徽章背景）
  static Color difficultyBackground(String level) {
    switch (level.toUpperCase()) {
      case 'BASIC':
        return const Color(0xFFE8F5E8);
      case 'ADVANCED':
        return const Color(0xFFFFF8E1);
      case 'EXPERT':
        return const Color(0xFFFCE4EC);
      case 'MASTER':
        return const Color(0xFFE9D8FF);
      case 'RE:MASTER':
      case 'REMASTER':
        return const Color(0xFFF3E5F5);
      default:
        return const Color(0xFFF0F0F0);
    }
  }

  /// 难度等级二级背景色（稍深，用于交替行等）
  static Color difficultySecondaryBackground(String level) {
    switch (level.toUpperCase()) {
      case 'BASIC':
        return const Color(0xFFC8E6C9);
      case 'ADVANCED':
        return const Color(0xFFFFE0B2);
      case 'EXPERT':
        return const Color(0xFFF8BBD0);
      case 'MASTER':
        return const Color(0xFFD4BFFF);
      case 'RE:MASTER':
      case 'REMASTER':
        return const Color(0xFFE1BEE7);
      default:
        return const Color(0xFFE0E0E0);
    }
  }

  /// utage（6位ID歌曲）主题色
  static const Color utageAccent = Color(0xFFFF69B4);
  static const Color utageCard = Color(0xFFFFB3D1);
  static const Color utageBackground = Color(0xFFFFE6F0);
  static const Color utageDeep = Color(0xFFFF1493);
  static const Color utageTag = Color(0xFFFF6B8B);

  /// 成就徽章前景色
  static Color achievementForeground(String type) {
    switch (type.toUpperCase()) {
      case 'AP':
      case 'AP+':
        return const Color(0xFFF57C00);
      case 'FC':
      case 'FC+':
        return const Color(0xFF2E7D32);
      case 'FS':
      case 'FS+':
        return const Color(0xFF1565C0);
      case 'FDX':
      case 'FDX+':
        return const Color(0xFFF57C00);
      case 'SYNC':
        return const Color(0xFFFF5722);
      default:
        return const Color(0xFF666666);
    }
  }

  /// 成就徽章背景色
  static Color achievementBackground(String type) {
    switch (type.toUpperCase()) {
      case 'AP':
      case 'AP+':
        return const Color(0xFFFFF3E0);
      case 'FC':
      case 'FC+':
        return const Color(0xFFD4F4DD);
      case 'FS':
      case 'FS+':
        return const Color(0xFFE0F4FF);
      case 'FDX':
      case 'FDX+':
        return const Color(0xFFFFF3E0);
      case 'SYNC':
        return const Color(0xFFFFE0B2);
      default:
        return const Color(0xFFF0F0F0);
    }
  }

  /// 评级颜色
  static Color ratingColor(String grade) {
    switch (grade.toUpperCase().replaceAll('+', '').trim()) {
      case 'SSS':
        return Colors.yellow;
      case 'SS':
        return const Color(0xFFFFAA00);
      case 'S':
        return const Color(0xFFFF9900);
      case 'AAA':
      case 'AA':
      case 'A':
        return const Color(0xFFFF4444);
      case 'BBB':
      case 'BB':
      case 'B':
        return const Color(0xFF44AAFF);
      case 'C':
      case 'D':
        return const Color(0xFFFF4444);
      default:
        return Colors.grey;
    }
  }

  /// 奖牌颜色
  static Color medalColor(String medal) {
    switch (medal.toLowerCase()) {
      case 'bronze':
      case '铜':
        return const Color(0xFFCD7F32);
      case 'silver':
      case '银':
        return const Color(0xFFC0C0C0);
      case 'gold':
      case '金':
        return const Color(0xFFFFD700);
      case 'prism':
      case 'rainbow':
      case '彩虹':
        return const Color(0xFF9400D3);
      default:
        return const Color(0xFFCD7F32);
    }
  }

  /// 难度索引 → 前景色（通过 index 0-4）
  static Color difficultyForegroundByIndex(int index, {Brightness brightness = Brightness.light}) {
    if (brightness == Brightness.dark) {
      const colors = [
        Color(0xFF81C784),
        Color(0xFFFFB74D),
        Color(0xFFF06292),
        Color(0xFFBA68C8),
        Color(0xFFCE93D8),
      ];
      return colors[index.clamp(0, 4)];
    }
    const colors = [
      Color(0xFF4CAF50),
      Color(0xFFFF9800),
      Color(0xFFE91E63),
      Color(0xFF9966CC),
      Color(0xFF9C27B0),
    ];
    return colors[index.clamp(0, 4)];
  }

  /// 难度索引 → 背景色（通过 index 0-4）
  static Color difficultyBackgroundByIndex(int index, {Brightness brightness = Brightness.light}) {
    if (brightness == Brightness.dark) {
      const colors = [
        Color(0xFF1B3D1B),
        Color(0xFF3D2E00),
        Color(0xFF4A2020),
        Color(0xFF2A1A3D),
        Color(0xFF3D1A3D),
      ];
      return colors[index.clamp(0, 4)];
    }
    const colors = [
      Color(0xFFE8F5E8),
      Color(0xFFFFF8E1),
      Color(0xFFFCE4EC),
      Color(0xFFE9D8FF),
      Color(0xFFF3E5F5),
    ];
    return colors[index.clamp(0, 4)];
  }

  /// 难度索引 → 二级背景色（通过 index 0-4）
  static Color difficultySecondaryBgByIndex(int index, {Brightness brightness = Brightness.light}) {
    if (brightness == Brightness.dark) {
      const colors = [
        Color(0xFF2E5C2E),
        Color(0xFF5C4A00),
        Color(0xFF6B3030),
        Color(0xFF3D2A5C),
        Color(0xFF5C2A5C),
      ];
      return colors[index.clamp(0, 4)];
    }
    const colors = [
      Color(0xFFC8E6C9),
      Color(0xFFFFE0B2),
      Color(0xFFF8BBD0),
      Color(0xFFD4BFFF),
      Color(0xFFE1BEE7),
    ];
    return colors[index.clamp(0, 4)];
  }

  // ========== 标签分组颜色 ==========

  /// 标签分组颜色
  static Color tagGroupBackground(String group) {
    switch (group) {
      case '配置':
        return const Color(0xFFE8F4F8);
      case '评价':
        return const Color(0xFFFFF3E0);
      case '难度':
        return const Color(0xFFFCE4EC);
      default:
        return const Color(0xFFF0E6FF);
    }
  }

  static Color tagGroupBorder(String group) {
    switch (group) {
      case '配置':
        return const Color(0xFFD1E7DD);
      case '评价':
        return const Color(0xFFFFE0B2);
      case '难度':
        return const Color(0xFFF8BBD0);
      default:
        return const Color(0xFFE0D0FF);
    }
  }

  static Color tagGroupText(String group) {
    switch (group) {
      case '配置':
        return const Color(0xFF388E3C);
      case '评价':
        return const Color(0xFFF57C00);
      case '难度':
        return const Color(0xFFD81B60);
      default:
        return const Color(0xFF664499);
    }
  }
}