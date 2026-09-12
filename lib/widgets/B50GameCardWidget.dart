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
  final bool isFitDiff;

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
    this.isFitDiff = false,
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

    // 定数（整数 + 小数部分）：常规定数保留 1 位小数（如 15.0、13.9），
    // 拟合定数（fit_diff）保留 2 位小数（如 13.57）以避免丢失精度。
    final int diffDecimalPlaces = isFitDiff ? 2 : 1;
    final String diffStr = difficulty.toStringAsFixed(diffDecimalPlaces);
    final List<String> diffParts = diffStr.split('.');
    final String diffMain = diffParts[0];
    final String diffDecimal = '.${diffParts[1]}';

    // 卡片下方 30% 区域固定使用白色背景 + 深色文字，
    // 避免深色 / 浅色模式影响屏幕显示与导出图片效果，保证导出一致性。
    const Color cardBottomBg = Colors.white;
    const Color cardBottomText = Colors.black;

    return Container(
      decoration: BoxDecoration(
        // 外层填色：上半 cardColor / 下半白色，70% 处硬切换。
        // 同时充当 border 缝隙（ClipRRect 因 border 内缩 2px 留出的几像素环）
        // 的兜底，让圆角四周都能被正确颜色覆盖。
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            cardColor,
            cardColor,
            cardBottomBg,
            cardBottomBg,
          ],
          stops: const [0.0, 0.7, 0.7, 1.0],
        ),
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
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8.0),
                    topRight: Radius.circular(8.0),
                  ),
                ),
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
                                  style: TextStyle(fontSize: coverSize * 0.24)),
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
            // ★ 下方 30%：固定白色背景 + 深色文字，导出图片与屏幕显示一致
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: cardBottomBg,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8.0),
                    bottomRight: Radius.circular(8.0),
                  ),
                ),
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
                            color: cardBottomText,
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
  static Widget buildTypeChip(bool isUtage, bool dxMode, double fontSize) {
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
  /// 0 / 5.5 / 6 等其他星数用 SizedBox 强制占位为同图片尺寸，保证与有星卡片右边界对齐。
  /// [fontSize] 同时决定图片高度（fontSize * heightMultiplier）与占位尺寸。
  /// dxstars/*.png 实测尺寸 60×36，宽高比 = 5/3。
  static Widget buildStarsWidget(
    String stars,
    Color starsColor,
    double fontSize, {
    double heightMultiplier = 1.8,
  }) {
    const double starsAspect = 5 / 3;
    final match = RegExp(r'✦(\d+(?:\.\d+)?)').firstMatch(stars);
    if (match != null) {
      final n = double.tryParse(match.group(1)!);
      if (n != null && n >= 1 && n <= 5 && n == n.truncateToDouble()) {
        return Image.asset(
          'assets/dxstars/${n.toInt()}.png',
          height: fontSize * heightMultiplier,
          fit: BoxFit.contain,
          errorBuilder: (ctx, err, st) => SizedBox(
            width: fontSize * heightMultiplier * starsAspect,
            height: fontSize * heightMultiplier,
            child: Center(
              child: Text(
                stars,
                style: TextStyle(
                  fontSize: fontSize,
                  color: starsColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      }
    }
    // ✦0 / ✦5.5 / ✦6 等情况：用占位 SizedBox 保持与有星卡片对齐；
    // Text 用 FittedBox + 大字号自动缩放到与图片星等高，加粗加深可读性。
    // 5.5 / 6 字号比图片星略小一点（1.5x vs 2.0x），避免视觉过重。
    // 5.5 / 6 走细描边（4 方向 Shadow 偏移 1.0）让数字更"立"起来。
    // ✦ 与数字拆成 Row 用 baseline 对齐，避免 ✦ 与数字上下错位。
    final bool needsStroke = stars == '✦6' || stars == '✦5.5';
    final String digits =
        stars.startsWith('✦') ? stars.substring(1) : stars;
    final TextStyle starStyle = TextStyle(
      fontSize: fontSize * 1.5,
      color: starsColor,
      fontWeight: FontWeight.w900,
      height: 1.0,
      shadows: needsStroke
          ? const [
              Shadow(color: Colors.black87, offset: Offset(-1.0, 0), blurRadius: 0),
              Shadow(color: Colors.black87, offset: Offset(1.0, 0), blurRadius: 0),
              Shadow(color: Colors.black87, offset: Offset(0, -1.0), blurRadius: 0),
              Shadow(color: Colors.black87, offset: Offset(0, 1.0), blurRadius: 0),
            ]
          : null,
    );
    return SizedBox(
      width: fontSize * heightMultiplier * starsAspect,
      height: fontSize * heightMultiplier,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              // ✦ 在很多字体里视觉重心偏低，整体上移 1.5 让它和数字看起来一样高
              Transform.translate(
                offset: const Offset(0, -1.5),
                child: Text('✦', style: starStyle),
              ),
              const SizedBox(width: 1.5),
              Text(digits, style: starStyle),
            ],
          ),
        ),
      ),
    );
  }
}
