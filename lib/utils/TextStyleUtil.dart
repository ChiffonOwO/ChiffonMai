import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TextStyleUtil {
  // ========== 字重常量定义 ==========
  
  // 极细体 (100)
  static const FontWeight thin = FontWeight.w100;
  
  // 超细体 (200)
  static const FontWeight extraLight = FontWeight.w200;
  
  // 细体 (300)
  static const FontWeight light = FontWeight.w300;
  
  // 常规体 (400) - 默认
  static const FontWeight regular = FontWeight.w400;
  
  // 中等体 (500)
  static const FontWeight medium = FontWeight.w500;
  
  // 半粗体 (600)
  static const FontWeight semiBold = FontWeight.w600;
  
  // 粗体 (700)
  static const FontWeight bold = FontWeight.w700;
  
  // 特粗体 (800)
  static const FontWeight extraBold = FontWeight.w800;
  
  // 极粗体 (900)
  static const FontWeight black = FontWeight.w900;

  // ========== 默认样式 ==========

  // 默认文本样式 - 常规字重（与思源黑体一致）
  static TextStyle get defaultStyle => GoogleFonts.notoSansSc(
        fontWeight: regular,
      );

  // ========== 标题样式 ==========

  // 标题样式 - 大（粗体）
  static TextStyle get headlineLarge => GoogleFonts.notoSansSc(
        fontSize: 32,
        fontWeight: bold,
      );

  // 标题样式 - 中（粗体）
  static TextStyle get headlineMedium => GoogleFonts.notoSansSc(
        fontSize: 24,
        fontWeight: bold,
      );

  // 标题样式 - 小（粗体）
  static TextStyle get headlineSmall => GoogleFonts.notoSansSc(
        fontSize: 20,
        fontWeight: bold,
      );

  // ========== 正文样式 ==========

  // 正文样式 - 大（常规）
  static TextStyle get bodyLarge => GoogleFonts.notoSansSc(
        fontSize: 18,
        fontWeight: regular,
      );

  // 正文样式 - 中（默认，常规）
  static TextStyle get bodyMedium => GoogleFonts.notoSansSc(
        fontSize: 16,
        fontWeight: regular,
      );

  // 正文样式 - 小（常规）
  static TextStyle get bodySmall => GoogleFonts.notoSansSc(
        fontSize: 14,
        fontWeight: regular,
      );

  // ========== 提示文字样式 ==========

  // 提示文字样式（常规）
  static TextStyle get hintStyle => GoogleFonts.notoSansSc(
        fontSize: 14,
        fontWeight: regular,
        color: Colors.grey,
      );

  // ========== 按钮文字样式 ==========

  // 按钮文字样式（半粗体）
  static TextStyle get buttonStyle => GoogleFonts.notoSansSc(
        fontSize: 16,
        fontWeight: semiBold,
      );

  // ========== 按字重分类的样式 ==========

  // 极细体样式
  static TextStyle get thinStyle => GoogleFonts.notoSansSc(
        fontWeight: thin,
      );

  // 超细体样式
  static TextStyle get extraLightStyle => GoogleFonts.notoSansSc(
        fontWeight: extraLight,
      );

  // 细体样式
  static TextStyle get lightStyle => GoogleFonts.notoSansSc(
        fontWeight: light,
      );

  // 常规体样式
  static TextStyle get regularStyle => GoogleFonts.notoSansSc(
        fontWeight: regular,
      );

  // 中等体样式
  static TextStyle get mediumStyle => GoogleFonts.notoSansSc(
        fontWeight: medium,
      );

  // 半粗体样式
  static TextStyle get semiBoldStyle => GoogleFonts.notoSansSc(
        fontWeight: semiBold,
      );

  // 粗体样式
  static TextStyle get boldStyle => GoogleFonts.notoSansSc(
        fontWeight: bold,
      );

  // 特粗体样式
  static TextStyle get extraBoldStyle => GoogleFonts.notoSansSc(
        fontWeight: extraBold,
      );

  // 极粗体样式
  static TextStyle get blackStyle => GoogleFonts.notoSansSc(
        fontWeight: black,
      );

  // ========== 自定义样式生成器 ==========

  // 自定义样式生成器（默认常规字重）
  static TextStyle custom({
    double? fontSize,
    FontWeight? fontWeight = regular,
    Color? color,
    double? letterSpacing,
    FontStyle? fontStyle,
    double? height,
    TextDecoration? decoration,
  }) =>
      GoogleFonts.notoSansSc(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        fontStyle: fontStyle,
        height: height,
        decoration: decoration,
      );

  // ========== 便捷工厂方法 ==========

  // 创建带字体的 TextStyle（最常用）
  static TextStyle style({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    FontStyle? fontStyle,
    double? height,
    TextDecoration? decoration,
    TextDecorationStyle? decorationStyle,
    Color? decorationColor,
  }) {
    return GoogleFonts.notoSansSc(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      fontStyle: fontStyle,
      height: height,
      decoration: decoration,
      decorationStyle: decorationStyle,
      decorationColor: decorationColor,
    );
  }

  // ========== 按字体大小分类的便捷方法 ==========

  // 仅设置字体大小
  static TextStyle font(double fontSize) {
    return GoogleFonts.notoSansSc(fontSize: fontSize);
  }

  // 字体大小 + 颜色
  static TextStyle fontColor(double fontSize, Color color) {
    return GoogleFonts.notoSansSc(fontSize: fontSize, color: color);
  }

  // 字体大小 + 字重
  static TextStyle fontWithWeight(double fontSize, FontWeight fontWeight) {
    return GoogleFonts.notoSansSc(fontSize: fontSize, fontWeight: fontWeight);
  }

  // 字体大小 + 字重 + 颜色
  static TextStyle fontWColor(double fontSize, FontWeight fontWeight, Color color) {
    return GoogleFonts.notoSansSc(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  // ========== 按字号分类的样式（常规字重）==========

  // 小号文字 (12px)
  static TextStyle get small => GoogleFonts.notoSansSc(fontSize: 12);

  // 小号文字 + 颜色
  static TextStyle smallColor(Color color) {
    return GoogleFonts.notoSansSc(fontSize: 12, color: color);
  }

  // 中号文字 (14px)
  static TextStyle get textMedium => GoogleFonts.notoSansSc(fontSize: 14);

  // 中号文字 + 颜色
  static TextStyle textMediumColor(Color color) {
    return GoogleFonts.notoSansSc(fontSize: 14, color: color);
  }

  // 大号文字 (16px)
  static TextStyle get large => GoogleFonts.notoSansSc(fontSize: 16);

  // 大号文字 + 颜色
  static TextStyle largeColor(Color color) {
    return GoogleFonts.notoSansSc(fontSize: 16, color: color);
  }

  // 超大号文字 (18px)
  static TextStyle get extraLarge => GoogleFonts.notoSansSc(fontSize: 18);

  // 超大号文字 + 颜色
  static TextStyle extraLargeColor(Color color) {
    return GoogleFonts.notoSansSc(fontSize: 18, color: color);
  }

  // ========== 按字号分类的样式（带字重）==========

  // 小号细体 (12px, w300)
  static TextStyle get smallLight => GoogleFonts.notoSansSc(fontSize: 12, fontWeight: light);

  // 小号常规 (12px, w400)
  static TextStyle get smallRegular => GoogleFonts.notoSansSc(fontSize: 12, fontWeight: regular);

  // 小号中等 (12px, w500)
  static TextStyle get smallMedium => GoogleFonts.notoSansSc(fontSize: 12, fontWeight: medium);

  // 小号半粗 (12px, w600)
  static TextStyle get smallSemiBold => GoogleFonts.notoSansSc(fontSize: 12, fontWeight: semiBold);

  // 小号粗体 (12px, w700)
  static TextStyle get smallBold => GoogleFonts.notoSansSc(fontSize: 12, fontWeight: bold);

  // 中号细体 (14px, w300)
  static TextStyle get mediumLight => GoogleFonts.notoSansSc(fontSize: 14, fontWeight: light);

  // 中号常规 (14px, w400)
  static TextStyle get mediumRegular => GoogleFonts.notoSansSc(fontSize: 14, fontWeight: regular);

  // 中号中等 (14px, w500)
  static TextStyle get mediumMedium => GoogleFonts.notoSansSc(fontSize: 14, fontWeight: medium);

  // 中号半粗 (14px, w600)
  static TextStyle get mediumSemiBold => GoogleFonts.notoSansSc(fontSize: 14, fontWeight: semiBold);

  // 中号粗体 (14px, w700)
  static TextStyle get mediumBold => GoogleFonts.notoSansSc(fontSize: 14, fontWeight: bold);

  // 大号细体 (16px, w300)
  static TextStyle get largeLight => GoogleFonts.notoSansSc(fontSize: 16, fontWeight: light);

  // 大号常规 (16px, w400)
  static TextStyle get largeRegular => GoogleFonts.notoSansSc(fontSize: 16, fontWeight: regular);

  // 大号中等 (16px, w500)
  static TextStyle get largeMedium => GoogleFonts.notoSansSc(fontSize: 16, fontWeight: medium);

  // 大号半粗 (16px, w600)
  static TextStyle get largeSemiBold => GoogleFonts.notoSansSc(fontSize: 16, fontWeight: semiBold);

  // 大号粗体 (16px, w700)
  static TextStyle get largeBold => GoogleFonts.notoSansSc(fontSize: 16, fontWeight: bold);

  // 超大号细体 (18px, w300)
  static TextStyle get extraLargeLight => GoogleFonts.notoSansSc(fontSize: 18, fontWeight: light);

  // 超大号常规 (18px, w400)
  static TextStyle get extraLargeRegular => GoogleFonts.notoSansSc(fontSize: 18, fontWeight: regular);

  // 超大号中等 (18px, w500)
  static TextStyle get extraLargeMedium => GoogleFonts.notoSansSc(fontSize: 18, fontWeight: medium);

  // 超大号半粗 (18px, w600)
  static TextStyle get extraLargeSemiBold => GoogleFonts.notoSansSc(fontSize: 18, fontWeight: semiBold);

  // 超大号粗体 (18px, w700)
  static TextStyle get extraLargeBold => GoogleFonts.notoSansSc(fontSize: 18, fontWeight: bold);

  // ========== 预设颜色样式 ==========

  // 灰色提示文字 (12px)
  static TextStyle get greyHint =>
      GoogleFonts.notoSansSc(fontSize: 12, color: Colors.grey);

  // 灰色提示文字 (14px)
  static TextStyle get greyHint14 =>
      GoogleFonts.notoSansSc(fontSize: 14, color: Colors.grey);

  // 白色文字 (12px)
  static TextStyle get whiteSmall =>
      GoogleFonts.notoSansSc(fontSize: 12, color: Colors.white);

  // 白色文字 (14px)
  static TextStyle get whiteMedium =>
      GoogleFonts.notoSansSc(fontSize: 14, color: Colors.white);

  // 白色文字 (16px)
  static TextStyle get whiteLarge =>
      GoogleFonts.notoSansSc(fontSize: 16, color: Colors.white);

  // 黑色粗体文字
  static TextStyle get blackBold =>
      GoogleFonts.notoSansSc(fontSize: 16, fontWeight: bold, color: Colors.black);

  // ========== 数字样式 ==========

  // 数字样式 - 用于显示分数、评级等
  static TextStyle numberStyle({
    double? fontSize,
    FontWeight fontWeight = bold,
    Color color = Colors.black,
  }) {
    return GoogleFonts.notoSansSc(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: -0.5,
    );
  }

  // ========== TextSpan 相关方法 ==========

  // 创建带字体的 TextSpan
  static TextSpan textSpan({
    String? text,
    TextStyle? style,
    List<InlineSpan>? children,
    GestureRecognizer? recognizer,
  }) {
    TextStyle effectiveStyle = style ?? const TextStyle();
    return TextSpan(
      text: text,
      style: GoogleFonts.notoSansSc(
        fontSize: effectiveStyle.fontSize,
        fontWeight: effectiveStyle.fontWeight,
        color: effectiveStyle.color,
        letterSpacing: effectiveStyle.letterSpacing,
        fontStyle: effectiveStyle.fontStyle,
        height: effectiveStyle.height,
        decoration: effectiveStyle.decoration,
        decorationStyle: effectiveStyle.decorationStyle,
        decorationColor: effectiveStyle.decorationColor,
      ),
      children: children,
      recognizer: recognizer,
    );
  }

  // 创建带字体的 TextSpan（简化版，仅设置文字和样式）
  static TextSpan span(String text, TextStyle style) {
    return TextSpan(
      text: text,
      style: GoogleFonts.notoSansSc(
        fontSize: style.fontSize,
        fontWeight: style.fontWeight,
        color: style.color,
        letterSpacing: style.letterSpacing,
        fontStyle: style.fontStyle,
        height: style.height,
        decoration: style.decoration,
      ),
    );
  }

  // 创建带字体和字重的 TextSpan
  static TextSpan spanWithWeight(String text, double fontSize, FontWeight fontWeight, [Color? color]) {
    return TextSpan(
      text: text,
      style: GoogleFonts.notoSansSc(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      ),
    );
  }
}