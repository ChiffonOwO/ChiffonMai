import 'package:flutter/material.dart';
import '../utils/CoverUtil.dart';

/// Best50 系列卡片通用 widget。
/// 采用两段式布局：上方 70% 卡色背景（曲绘 + 歌名 + 达成率 + 定数→RA | 分数/满分），
/// 下方 30% 白底（谱面 ID + 类型 chip + 评级 + FC + FS + 星数）。
///
/// 字号常量的标定基准是「导出图片单卡实际可见宽度」[refCardWidth] = 335，
/// 通过 [scale] 适配不同使用场景：
///   * 导出图片时 `scale = 1.0`（335 就是照它标定的）；
///   * 页面显示时**默认 [autoScale]**：字号按卡片**渲染时的实际宽度**换算，
///     基准是 [screenRefCardWidth] —— 屏幕口径**故意**比导出基准大约 8.8%
///     （统一口径前页面拿屏幕宽度估格子宽，比真实格子大 ~9%，见常量注释）。
class B50GameCardWidget extends StatelessWidget {
  /// 字号换算的基准卡宽（与导出图片同源）。
  ///
  /// 这个数**不能改**：所有字号常量（[_kSongName] 等）都是照着它标定的。
  static const double refCardWidth = 335.0;

  /// **屏幕口径**的字号换算基准宽度：`335 / 1.088 ≈ 308`。
  ///
  /// 比导出基准 [refCardWidth] 小 8.8% —— 分母越小，字号 / 曲绘 / 角标越大，
  /// 这是**故意**的：卡片若按「真实格子宽 / 335」换算，会比用户熟悉的版本
  /// 整体小一圈（反馈："卡片里的曲绘、评级连击同步图片和文本字号都变小了"）。
  ///
  /// 那 8.8% 正是「统一口径」**之前估宽的水分**：页面按 `screenW` 估格子宽
  /// （`(screenW - screenW * 0.0x) / 2`），没扣容器 padding / 网格间距 ——
  /// 360 屏估 178.2、真实格子 163.4（1.09 倍）。换成真实宽度后卡片内容
  /// 整体小了 ~9%，这里在**屏幕口径**上把这一截还回来。
  ///
  /// 旧尺寸**装得下**（上半区 7:3 + 现有内边距实测还有 ~4% 余量）：
  /// `test/b50_card_scale_test.dart` 按格子宽 145~335 × dpr 2.75/3.0 逐个核对
  /// 「上半区装得下 + 后代不出卡片」；320~480 屏的「真实格子 / 旧估算」实测
  /// 落在 1.082~1.097，取中值 1.088。
  ///
  /// ⚠️ **导出图片（`scale: 1.0` 的离屏渲染）不走这里**，仍按 [refCardWidth]
  /// 标定；反过来说，页面口径下也别再把 [refCardWidth] 当分母。
  static const double screenRefCardWidth = 308.0;

  /// [scale] 的哨兵值：**按卡片渲染时真实拿到的宽度自适应**。
  ///
  /// 页面显示一律用这个（默认值）。网格格子给卡片的是**紧约束**，卡片根部的
  /// `LayoutBuilder` 拿到的 `maxWidth` 就是它最终的可见宽度，因此
  /// `scale = maxWidth / [screenRefCardWidth]` 永远和实际渲染一致。
  ///
  /// ⚠️ 页面里**别再手算** `((screenW - screenW * 0.0x) / 2) / 335`：容器
  /// padding / 边距 / 网格间距都没算进去，和真实格子对不上。
  ///
  /// 导出图片时显式传 `1.0`（基准宽度 [refCardWidth] 就是照它标定的）。
  static const double autoScale = 0.0;

  /// 把 [scale] 换算成真正生效的缩放值。
  ///
  /// * `scale > 0`：[scale] 本身（导出图片传 1.0）；
  /// * `scale <= 0`（[autoScale]）：`[boxWidth] / [screenRefCardWidth]`，
  ///   其中 [boxWidth] 是卡片渲染时**真实拿到的宽度**。
  ///
  /// ⚠️ [boxWidth] 只能是**渲染时**拿到的宽度（`LayoutBuilder` 的 `maxWidth`）：
  /// 拿屏幕宽度 / 网格外层宽度「估」出来的值都会偏大（统一口径前偏大 ~9%）。
  static double resolveScale(double scale, double boxWidth) {
    if (scale > 0) return scale;
    return (boxWidth.isFinite && boxWidth > 0)
        ? boxWidth / screenRefCardWidth
        : 1.0;
  }

  /// 卡片的设计宽高比（由"上下 7:3 定高"决定）。
  ///
  /// 页面摆放时**高度要按这个比例跟着宽度走**：卡片内部是定高分区 + 按宽度
  /// 缩放的字号，高度给错了会挤到溢出。
  static const double designAspectRatio = 1.75;

  /// 单卡宽度：`可用宽` 里放 [columns] 张、扣掉 [columnGap] 间隙。
  static double cardWidthFor(
    double availableWidth, {
    int columns = 2,
    double columnGap = 0,
  }) {
    final cols = columns < 1 ? 1 : columns;
    final w = (availableWidth - columnGap) / cols;
    return w <= 0 ? 1 : w;
  }

  /// 字号缩放比例：`单卡宽 / [screenRefCardWidth]`（屏幕口径）。
  ///
  /// 用于**拿不到卡片渲染宽度**的场景（比如按网格外层的宽度估算）。网格
  /// `itemBuilder` 里有紧约束，优先用 [autoScale]（卡片自己量）。
  /// 两种情况都别自己抄 `格子宽 / 335` 或 `格子宽 / 308` —— 抄错不报错，
  /// 只会让字号悄悄不对。
  static double scaleForWidth(
    double availableWidth, {
    int columns = 2,
    double columnGap = 0,
  }) =>
      cardWidthFor(availableWidth, columns: columns, columnGap: columnGap) /
      screenRefCardWidth;

  /// 这个宽度下卡片应该有多高（网格的 `mainAxisExtent` 直接用）。
  static double heightForWidth(
    double availableWidth, {
    int columns = 2,
    double columnGap = 0,
    double aspectRatio = designAspectRatio,
  }) =>
      cardWidthFor(availableWidth, columns: columns, columnGap: columnGap) /
      aspectRatio;

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

  /// 字号缩放。`> 0`：按给定值（导出图片传 `1.0`）；[autoScale]（默认）：
  /// 按卡片**渲染时的实际宽度**自适应。
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
    this.scale = autoScale,
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

  /// 在卡片上**叠**一枚角标（PC50 的 `PC 1234` 就是它）。
  ///
  /// 刻意做成叠层、而不是往卡里塞一个格子：卡片上下两块是 7:3 定高，
  /// 加内容会把里面挤到溢出（调试期就是黄黑条）。位置用本组件的设计稿常量 ——
  /// 内边距 [10.2] + 曲绘 [100] 高的正下方，那块区域是空的，
  /// 不压歌名 / 达成率 / `定数 → RA  DX分`，也碰不到下方白色信息条。
  static Widget withBadgeOverlay({
    required Widget card,
    required String text,
    double scale = autoScale,
  }) {
    // 角标位置必须和卡片用**同一个** scale：给卡片一个值、给角标另一个值，
    // PC50 角标就会跟曲绘对不上（历史 bug）。
    return LayoutBuilder(
      builder: (context, constraints) {
        final double resolved = resolveScale(scale, constraints.maxWidth);
        return Stack(
          children: [
            card,
            Positioned(
              left: _kSpacing * resolved,
              top: (_kSpacing + _kCover + 2.8) * resolved,
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: 6 * resolved, vertical: 2 * resolved),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(6 * resolved),
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 12 * resolved,
                    height: 1.1,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 达成率的「整数段 + 小数段」。
  ///
  /// 两段字号不同（`_kDecimalMain` / `_kDecimalSmall`），**必须画在同一个段落里**
  /// （一个 `Text.rich` + 两个 span）——不要让它们各自成为一句 `Text`。
  ///
  /// ⚠️ **"两句 `Text` + `Row(crossAxisAlignment: baseline)`"就是"有的页面看起来齐、
  /// 有的页面小数偏高"的根源**（6 个 Best50 卡片里恰好只有 2 个是对的）：
  ///
  /// * `Row` 的 baseline 对齐只保证**布局**上基线重合（亚像素级精确）；可两句
  ///   `Text` 是两个 `RenderParagraph`，**各自光栅化、各自吸附像素格**，两段字形
  ///   游程落到不同相位，墨迹底相差 0~3 物理像素。
  /// * 差多少取决于字号落在哪一格：真字体（Google Fonts 的 Noto Sans SC Bold，
  ///   dpr 3.0，按字形墨迹底扫描）实测 `101.0000%`：
  ///
  ///   | 主 / 次字号（dp） | 两段墨迹底之差 |
  ///   |---|---|
  ///   | 18.09 / 13.56 | 0（"齐平"） |
  ///   | 17.90 / 13.43 | −2（小数肉眼可见偏高） |
  ///
  ///   前者正是 `cardW=(W−0.01W)/2` 的 Best50 / 拟合 Best50，后者是另外 4 个页面。
  ///
  /// 换成单个段落（`Text.rich`）后只有一个基线、两段在同一次排版里定位：同一字体
  /// 实测 W=360~430、dpr 2.75 / 3.0、两种卡宽系数、多种亚像素相位下之差**恒为 0**。
  ///
  /// ⚠️ **不要再给小数段叠 `Transform.translate` 做"补偿"**（历史实现就是
  /// 这么写的，那正是"小数严重偏下"的根源）：
  ///
  /// * `RenderTransform` 会把 translate 记进自己的 baseline（`child.getDistanceToBaseline() + offset.dy`），
  ///   但 `RenderFlex` 的 baseline 对齐**实测并不会因此反补偿**——真字体
  ///   （`NotoSansSC_700`，dpr 3.0，按字形墨迹底扫描）测得：`dy` 每变 1 逻辑像素，
  ///   墨迹就跟着平移 1 逻辑像素（1:1，不是 2:1）。
  /// * 于是那笔"补偿"变成了**纯额外的下推量**，得多少就压下去多少
  ///   （scale 1.0 时 +7 物理像素，scale 0.53 时 +3）。
  static Widget _buildAchievement({
    required double achievementRate,
    required double mainFontSize,
    required double subFontSize,
  }) {
    final text = achievementRate.toStringAsFixed(4);
    final parts = text.split('.');
    final intPart = parts[0];
    final decPart = parts.length > 1 ? '.${parts[1]}%' : '%';

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: intPart,
            style: TextStyle(
              fontSize: mainFontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          TextSpan(
            text: decPart,
            style: TextStyle(
              fontSize: subFontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (scale > 0) return _buildCard(context, scale);
    // 默认（[autoScale]）：字号按卡片**渲染时的实际宽度**换算。
    // 网格格子给卡片的是紧约束，`maxWidth` 就是卡片的可见宽度；
    // 页面自己拿屏幕宽度估的值差好几个百分点，会挤出去或留白。
    return LayoutBuilder(
      builder: (context, constraints) =>
          _buildCard(context, resolveScale(scale, constraints.maxWidth)),
    );
  }

  /// [scale] 是**已经解析过**的缩放值（见 [resolveScale]）。
  Widget _buildCard(BuildContext context, double scale) {
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
                              child: _buildAchievement(
                                achievementRate: achievementRate,
                                mainFontSize: decimalMainFontSize,
                                subFontSize: decimalSmallFontSize,
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
    // 5.5 / 6 走细描边（8 方向 Shadow 偏移 1.0）让数字更"立"起来。
    // 只描上下左右 4 个方向时，字形的斜角会露出缝隙，补上 4 个对角方向才是完整一圈。
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
              Shadow(color: Colors.black87, offset: Offset(-1.0, -1.0), blurRadius: 0),
              Shadow(color: Colors.black87, offset: Offset(1.0, -1.0), blurRadius: 0),
              Shadow(color: Colors.black87, offset: Offset(-1.0, 1.0), blurRadius: 0),
              Shadow(color: Colors.black87, offset: Offset(1.0, 1.0), blurRadius: 0),
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
