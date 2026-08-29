import 'package:flutter/material.dart';
import '../utils/CoverUtil.dart';

/// Best50 系列卡片通用 widget。
/// 采用两段式布局：上方 70% 卡色背景（曲绘 + 歌名 + 达成率 + 定数→RA | 分数/满分），
/// 下方 30% 白底（谱面 ID + 类型 chip + 评级 + FC + FS + 星数）。
///
/// 字号基于 `refCardWidth = 335` 的「导出图片单卡实际可见宽度」计算，
/// 通过 [scale] 适配不同使用场景：
///   * 导出图片时 `scale = 1.0`；
///   * 页面显示时 `scale = cardW / 335`，其中 `cardW` 为屏幕上单卡的实际宽度。
class B50GameCardWidget extends StatelessWidget {
  final Color cardColor;
  final String songName;
  final double achievementRate;
  final double difficulty;
  final bool dxMode;
  final bool isUtage;
  final int score;
  final int maxScore;
  final int rating;
  final String stars;
  final String fc;
  final String fs;
  final String rate;
  final int songId;
  final Color starsColor;
  final int maxIdLength;
  final double scale;

  const B50GameCardWidget({
    super.key,
    required this.cardColor,
    required this.songName,
    required this.achievementRate,
    required this.difficulty,
    required this.dxMode,
    required this.isUtage,
    required this.score,
    required this.maxScore,
    required this.rating,
    required this.stars,
    required this.fc,
    required this.fs,
    required this.rate,
    required this.songId,
    required this.starsColor,
    required this.maxIdLength,
    this.scale = 1.0,
  });

  // ---- 字号常量（基于 refCardWidth=335，与导出图片同源）----
  static const double _kSongName = 20.4;
  static const double _kDecimalMain = 34.0;
  static const double _kDecimalSmall = 25.5;
  static const double _kOther = 13.6;
  static const double _kGrade = 11.9;
  static const double _kType = 23.8;
  static const double _kCover = 100.0;
  static const double _kSpacing = 10.2;
  static const double _kSmallSpacing = 5.1;

  @override
  Widget build(BuildContext context) {
    final double songNameFontSize = _kSongName * scale;
    final double decimalMainFontSize = _kDecimalMain * scale;
    final double decimalSmallFontSize = _kDecimalSmall * scale;
    final double otherFontSize = _kOther * scale;
    final double gradeFontSize = _kGrade * scale;
    final double typeFontSize = _kType * scale;
    final double coverSize = _kCover * scale;
    final double spacing = _kSpacing * scale;
    final double smallSpacing = _kSmallSpacing * scale;

    // 定数（整数 + 小数部分）：统一保留 2 位小数，
    // 拟合定数（fit_diff）可能给出 13.5678 之类的多位小数，这里截断到 2 位。
    final String diffStr = difficulty.toStringAsFixed(2);
    final List<String> diffParts = diffStr.split('.');
    final String diffMain = diffParts[0];
    final String diffDecimal = '.${diffParts[1]}';

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        border: Border.all(color: Colors.black, width: 2.0),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // ★ 上方 70%（卡色）：曲绘顶对齐 + 三行信息
            Expanded(
              flex: 7,
              child: Container(
                color: cardColor,
                padding: EdgeInsets.fromLTRB(
                    spacing, spacing, spacing, smallSpacing * 0.5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 左侧：曲绘（顶部对齐）
                    Container(
                      width: coverSize,
                      height: coverSize,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.black, width: 1.0),
                      ),
                      child: songId != 0
                          ? CoverUtil.buildCoverWidgetWithContext(
                              context, songId.toString(), coverSize)
                          : Center(
                              child: Text('曲绘',
                                  style:
                                      TextStyle(fontSize: coverSize * 0.24)),
                            ),
                    ),
                    SizedBox(width: spacing),
                    // 右侧：歌名 / 达成率 / 定数→RA | 分数/满分
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            songName,
                            style: TextStyle(
                              fontSize: songNameFontSize,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          SizedBox(height: 1.5 * scale),
                          SizedBox(
                            width: double.infinity,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    achievementRate
                                        .toStringAsFixed(4)
                                        .split('.')[0],
                                    style: TextStyle(
                                      fontSize: decimalMainFontSize,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    '.${achievementRate.toStringAsFixed(4).split('.')[1]}%',
                                    style: TextStyle(
                                      fontSize: decimalSmallFontSize,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 4 * scale),
                          SizedBox(
                            width: double.infinity,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '$diffMain$diffDecimal → $rating  $score / $maxScore',
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.visible,
                                style: TextStyle(
                                  fontSize: otherFontSize,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ★ 下方 30%（白底）：ID + 类型 chip + 评级 + FC + FS + 星数
            Expanded(
              flex: 3,
              child: Container(
                color: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: smallSpacing),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    // 谱面 ID（Stack + 不可见占位保证等宽对齐）
                    Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Opacity(
                          opacity: 0.0,
                          child: Text(
                            '#${'0' * maxIdLength}',
                            style: TextStyle(
                              fontSize: otherFontSize * 1.5,
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              height: 1.0,
                            ),
                          ),
                        ),
                        Text(
                          songId != 0 ? '#${songId.toString()}' : '',
                          style: TextStyle(
                            fontSize: otherFontSize * 1.5,
                            color: Colors.black54,
                            fontWeight: FontWeight.bold,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: smallSpacing),
                    // 类型 chip（Stack + 不可见 'UT' 占位保证等宽对齐）
                    Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Opacity(
                          opacity: 0.0,
                          child: Text(
                            'UT',
                            style: TextStyle(
                              fontSize: typeFontSize,
                              color: Colors.transparent,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                            ),
                          ),
                        ),
                        buildTypeChip(isUtage, dxMode, typeFontSize),
                      ],
                    ),
                    const Spacer(),
                    // 评级图
                    if (rate.isNotEmpty)
                      Transform.translate(
                        offset: Offset(2 * scale, -1 * scale),
                        child: Padding(
                          padding: EdgeInsets.only(top: 3 * scale),
                          child: SizedBox(
                            width: gradeFontSize * 2.0 * 110 / 44,
                            height: gradeFontSize * 2.0,
                            child: Image.asset(
                              'assets/gamrank/$rate.png',
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                              errorBuilder: (context, error, stackTrace) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ),
                    SizedBox(width: 0.5 * scale),
                    // FC 图
                    Image.asset(
                      'assets/grade/${fc.isNotEmpty ? fc : 'empty'}.png',
                      height: gradeFontSize * 3.0,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox.shrink(),
                    ),
                    SizedBox(width: 0.5 * scale),
                    // FS 图
                    Image.asset(
                      'assets/grade/${fs.isNotEmpty ? fs : 'empty'}.png',
                      height: gradeFontSize * 3.0,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox.shrink(),
                    ),
                    SizedBox(width: 0.5 * scale),
                    // 星数
                    buildStarsWidget(stars, starsColor, otherFontSize,
                        heightMultiplier: 2.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 类型标签（带颜色文字，无背景）
  static Widget buildTypeChip(
      bool isUtage, bool dxMode, double fontSize) {
    Color textColor;
    String text;
    if (isUtage) {
      textColor = const Color(0xFFE60012); // 红色
      text = 'UT';
    } else if (dxMode) {
      textColor = const Color(0xFFC95A12); // 加深后的橙色
      text = 'DX';
    } else {
      textColor = const Color(0xFF1F4FA5); // 蓝色
      text = 'ST';
    }
    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        color: textColor,
        fontWeight: FontWeight.w900,
        height: 1.0,
      ),
    );
  }

  /// 星数渲染：整数 1-5 用 assets/dxstars/N.png 图片，
  /// 5.5 / 6 等其他星数保持原文字。
  /// [fontSize] 同时决定图片高度（fontSize * heightMultiplier）与文字字号，确保视觉一致。
  static Widget buildStarsWidget(
    String stars,
    Color starsColor,
    double fontSize, {
    double heightMultiplier = 1.8,
  }) {
    final match = RegExp(r'✦(\d+(?:\.\d+)?)').firstMatch(stars);
    if (match != null) {
      final n = double.tryParse(match.group(1)!);
      if (n != null && n >= 1 && n <= 5 && n == n.truncateToDouble()) {
        return Image.asset(
          'assets/dxstars/${n.toInt()}.png',
          height: fontSize * heightMultiplier,
          fit: BoxFit.contain,
          errorBuilder: (ctx, err, st) => Text(
            stars,
            style: TextStyle(
              fontSize: fontSize,
              color: starsColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }
    }
    return Text(
      stars,
      style: TextStyle(
        fontSize: fontSize,
        color: starsColor,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}