import 'package:flutter/material.dart';

class ColorUtil {
  /**
   * 获取星星等级颜色
   * @param stars 星星等级字符串
   * @return 星星等级颜色
   */
  static Color getStarsColor(String stars) {
    switch (stars) {
      case '✦6':
      case '✦5.5':
      case '✦5':
        return Colors.yellow;
      case '✦4':
      case '✦3':
        return Colors.orange;
      case '✦2':
      case '✦1':
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
      Color(0xFFFFCC00), // level_index 1 - 深黄色，让DX能够分辨可见
      Colors.red, // level_index 2
      Colors.purple.shade400, // level_index 3
      Colors.purple.shade200, // level_index 4
    ];
    return colors[levelIndex.clamp(0, 4)];
  }

  /**
   * 获取封面边框颜色
   * @param levelIndex 等级索引
   * @return 封面边框颜色
   */
  static Color getCoverBorderColor(int levelIndex) {
    return getCardColor(levelIndex);
  }

  // ──────────────────── Rating 图片徽章 ────────────────────

  /// 图片原始尺寸
  static const _imgW = 664.0;
  static const _imgH = 128.0;

  /// 根据 Rating 映射到图片编号 01-12
  static int _getRatingImageIndex(int rating) {
    if (rating >= 16000) return 12;
    if (rating >= 15000) return 11;
    if (rating >= 14500) return 10;
    if (rating >= 14000) return 9;
    if (rating >= 13000) return 8;
    if (rating >= 12000) return 7;
    if (rating >= 10000) return 6;
    if (rating >= 7000) return 5;
    if (rating >= 4000) return 4;
    if (rating >= 2000) return 3;
    if (rating >= 1000) return 2;
    return 1;
  }

  /// 根据 Rating 映射右侧星星编号（14000 以上每 250 分一档，4 张循环）
  static int? _getStarImageIndex(int rating) {
    if (rating >= 16750) return 4;
    if (rating >= 16500) return 3;
    if (rating >= 16250) return 2;
    if (rating >= 16000) return 1;
    if (rating >= 15750) return 4;
    if (rating >= 15500) return 3;
    if (rating >= 15250) return 2;
    if (rating >= 15000) return 1;
    if (rating >= 14750) return 2;
    if (rating >= 14500) return 1;
    if (rating >= 14250) return 2;
    if (rating >= 14000) return 1;
    return null;
  }

  /// 构建 Rating 徽章组件
  ///
  /// 使用 assets/ratingbg/UI_CMN_DXRating_XX.png 作为背景，
  /// 将数字按位拆分填入黑框的 5 个分割区域内。
  static Widget buildRatingBadge(
    int rating, {
    double height = 28,
  }) {
    final index = _getRatingImageIndex(rating);
    final path =
        'assets/ratingbg/UI_CMN_DXRating_${index.toString().padLeft(2, '0')}.png';
    final aspectRatio = _imgW / _imgH;
    final width = height * aspectRatio;

    // 数字按位拆分，右对齐（最多取低5位）
    String ratingStr = rating.toString();
    if (ratingStr.length > 5) {
      ratingStr = ratingStr.substring(ratingStr.length - 5);
    }
    final digits = ratingStr.padLeft(5, ' ').split('');

    // 黑框在原始图片中的像素坐标
    const boxL = 308.0;
    const boxR = 576.0;
    const boxT = 21.0;
    const boxB = 106.0;
    const boxW = boxR - boxL; // 268

    // 5 等分，每个数字一格
    final digitWidgets = <Widget>[];
    for (int i = 0; i < 5; i++) {
      final cellL = boxL + boxW * i / 5;
      final cellR = boxL + boxW * (i + 1) / 5;

      digitWidgets.add(
        Positioned(
          left: width * cellL / _imgW,
          top: height * boxT / _imgH,
          right: width * (1 - cellR / _imgW),
          bottom: height * (1 - boxB / _imgH),
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: Text(
                digits[i],
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final badge = SizedBox(
      height: height,
      width: width,
      child: Stack(
        children: [
          Positioned.fill(child: Image.asset(path, fit: BoxFit.fill)),
          ...digitWidgets,
        ],
      ),
    );

    // 右侧星星（14000 以上才有）
    final starIndex = _getStarImageIndex(rating);
    if (starIndex != null) {
      final starPath =
          'assets/ratingbg/UI_CMN_DXRating_Star_${starIndex.toString().padLeft(2, '0')}.png';
      const starAspectRatio = 72.0 / 120.0;
      final starWidth = height * starAspectRatio;
      final gap = height * 0.55; // 图右侧透明 + 星左侧透明
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          badge,
          SizedBox(
            width: 0,
            height: height,
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              maxWidth: starWidth,
              child: Transform.translate(
                offset: Offset(-gap, 0),
                child: SizedBox(
                  height: height,
                  width: starWidth,
                  child: Image.asset(starPath, fit: BoxFit.fill),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return badge;
  }
}
