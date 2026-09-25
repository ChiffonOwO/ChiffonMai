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
  /// 数据源 key：`'shuiyu'` / `'luoxue'` / `'awmc'`。
  final String? dataSource;

  /// 文字大小，默认 10（排行榜列表里的尺寸）。
  final double fontSize;

  const DataSourceTag({
    super.key,
    required this.dataSource,
    this.fontSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final style = dataSourceStyleOf(dataSource, brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        style.label,
        style: TextStyle(
          fontSize: fontSize,
          color: style.foreground,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
