import 'package:flutter/material.dart';

import '../utils/AppTheme.dart';
import '../utils/CurrentDataSourceNotifier.dart';

/// 数据源标签（水鱼 / 落雪 / AWMC NET）的**唯一**取色取名处。
///
/// 为什么要有这个文件：排行榜那几页原本各自抄了一份
/// `dataSource == 'shuiyu' ? '水鱼' : '落雪'`（含配色），一共 6 份。
/// 这种写法加第三个数据源时**必然漏改**，而且 AWMC NET 会被错标成「落雪」。
/// 现在统一走 [RefreshDataSource.shortDisplayNameOfKey] + 这里的配色表。
///
/// 用的是**短名**（`AWMC` 而不是 `AWMC NET`）：这个标签是紧挨在用户名前面的，
/// 太长的名字会把昵称挤掉。
class DataSourceStyle {
  /// 界面上显示的名字。
  final String label;

  /// 文字颜色（也是描边/强调色）。
  final Color foreground;

  /// 填充底色（已带透明度）。
  final Color background;

  const DataSourceStyle({
    required this.label,
    required this.foreground,
    required this.background,
  });

  /// 认不出数据源时的兜底样式（灰）。
  static DataSourceStyle unknown(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return DataSourceStyle(
      label: '未知',
      foreground: AppColors.greyHint(brightness),
      background: (isDark ? Colors.grey : Colors.grey[300])!
          .withValues(alpha: isDark ? 0.25 : 0.5),
    );
  }
}

/// 开发者的排行榜 playerId 白名单（`'<source>:<id>'` 口径）。
///
/// 名单里的人除了数据源标签（水鱼 / 落雪 / AWMC）之外，还会在**后面**多挂一个
/// 「开发者喵」标签。加人只要往这里加一行，页面侧不用改任何逻辑。
const Set<String> kDeveloperPlayerIds = {
  'awmc:488581724',
  'luoxue:946923365021984',
  'shuiyu:488581724',
};

/// [playerId] 是不是开发者。
///
/// **精确匹配**整串 `'<source>:<id>'`，不做后缀匹配：否则 `awmc:488581724` 会把
/// 别的源里恰好同号的玩家（例如落雪的 488581724）也一起标成开发者。
bool isDeveloperPlayer(String? playerId) =>
    playerId != null && kDeveloperPlayerIds.contains(playerId);

/// 「开发者喵」标签的文字。
const String developerTagLabel = '开发者喵';

/// 「开发者喵」标签的配色。
///
/// 刻意不复用任何 [RefreshDataSource] 的配色：它标的是**身份**（开发组成员）而不是
/// 数据源，跟在水鱼 / 落雪 / AWMC 后面一起出现时必须一眼能分开，所以单独用粉色。
DataSourceStyle developerStyle(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  return DataSourceStyle(
    label: developerTagLabel,
    foreground: isDark ? Colors.pink[200]! : Colors.pink[700]!,
    background:
        isDark ? Colors.pink.withValues(alpha: 0.25) : Colors.pink[100]!,
  );
}

/// 按数据源 key（`'shuiyu'` / `'luoxue'` / `'awmc'`）取标签样式。
///
/// [key] 允许为 null / 空 / 未知，一律走灰色兜底，绝不默认成「水鱼」。
DataSourceStyle dataSourceStyleOf(String? key, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final label = RefreshDataSource.shortDisplayNameOfKey(key);
  if (label.isEmpty) return DataSourceStyle.unknown(brightness);

  final RefreshDataSource source;
  switch (key) {
    case 'shuiyu':
      source = RefreshDataSource.shuiyu;
    case 'luoxue':
      source = RefreshDataSource.luoxue;
    case 'awmc':
      source = RefreshDataSource.awmc;
    default:
      return DataSourceStyle.unknown(brightness);
  }

  switch (source) {
    case RefreshDataSource.shuiyu:
      // 水鱼：主题蓝（沿用原配色）
      final blue = AppColors.linkBlue(brightness);
      return DataSourceStyle(
        label: label,
        foreground: blue,
        background: blue.withValues(alpha: 0.15),
      );
    case RefreshDataSource.luoxue:
      // 落雪：紫（沿用原配色）
      return DataSourceStyle(
        label: label,
        foreground: isDark ? Colors.purple[200]! : Colors.purple[700]!,
        background: isDark
            ? Colors.purple.withValues(alpha: 0.25)
            : Colors.purple[100]!,
      );
    case RefreshDataSource.awmc:
      // AWMC NET：青绿，与另外两个源明显区分
      return DataSourceStyle(
        label: label,
        foreground: isDark ? Colors.teal[200]! : Colors.teal[700]!,
        background: isDark
            ? Colors.teal.withValues(alpha: 0.25)
            : Colors.teal[100]!,
      );
  }
}

/// 排行榜里的数据源小标签（圆角小胶囊）。
class DataSourceTag extends StatelessWidget {
  /// 默认文字大小（排行榜列表里的尺寸）。
  static const double defaultFontSize = 10;

  /// 胶囊的上下内边距。`build` 与 [heightFor] 共用一份，
  /// 否则「量出来的高」和「画出来的高」早晚会对不上。
  static const double verticalPadding = 2;

  /// 数据源 key：`'shuiyu'` / `'luoxue'` / `'awmc'`。
  final String? dataSource;

  /// 直接指定样式，覆盖 [dataSource] 推出的那份。
  ///
  /// 给「不是数据源、但用同一个胶囊外观」的标签用（目前就是 [developerStyle]
  /// 的「开发者喵」），省得为了一颗胶囊再抄一遍 `Container + Text`。
  final DataSourceStyle? styleOverride;

  /// 文字大小，默认 [defaultFontSize]（排行榜列表里的尺寸）。
  final double fontSize;

  const DataSourceTag({
    super.key,
    required this.dataSource,
    this.styleOverride,
    this.fontSize = defaultFontSize,
  });

  /// 与 [build] 里那个 `Text` **完全一致**的有效样式。
  ///
  /// 必须自己合并环境 `DefaultTextStyle`（`Text` 内部就是这么合并的）：标签只写了
  /// `fontSize`，**行高是从 Material 的 `bodyMedium` 继承来的** —— 换主题或调字体后
  /// 行高会变，只拿字面量算就会算错。
  static TextStyle textStyleFor(BuildContext context, double fontSize) =>
      DefaultTextStyle.of(context).style.merge(
        TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
      );

  /// 标签渲染出来的**总高**（一行文字 + 上下内边距）。
  ///
  /// [text] 要传**真正会显示的那串字**（水鱼 / 落雪 / AWMC / 未知）：字体缺字时
  /// 中文与拉丁字母走的回退字体不同，度量不一定一样。
  static double heightFor(
    BuildContext context,
    String text, {
    double fontSize = defaultFontSize,
  }) {
    final defaultStyle = DefaultTextStyle.of(context);
    final painter = TextPainter(
      text: TextSpan(text: text, style: textStyleFor(context, fontSize)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      // 与 `Text` 的兜底一致（顺带说明：`Text` 并**不**继承 DefaultTextStyle 的
      // strutStyle，所以这里也不传）。
      textHeightBehavior: defaultStyle.textHeightBehavior ??
          DefaultTextHeightBehavior.maybeOf(context),
      maxLines: 1,
    )..layout();
    final textHeight = painter.height;
    painter.dispose();
    return textHeight + verticalPadding * 2;
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final style =
        styleOverride ?? dataSourceStyleOf(dataSource, brightness);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 6, vertical: verticalPadding),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        style.label,
        style: textStyleFor(context, fontSize).copyWith(color: style.foreground),
      ),
    );
  }
}
