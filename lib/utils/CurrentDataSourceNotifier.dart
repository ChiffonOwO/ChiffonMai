import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constant/CacheKeyConstant.dart';

/// 数据源：水鱼（Diving-Fish）/ 落雪（LuoXue）。
///
/// 原先定义在 RefreshDataDialog.dart 里；双账号系统需要在 service 层引用它，
/// 所以抽到这里，RefreshDataDialog 再 export 出去，保持既有 import 不变。
enum RefreshDataSource {
  shuiyu,
  luoxue;

  /// 持久化用的键（写入 `last_data_source`）。
  String get key => name;

  static RefreshDataSource fromKey(String? key) =>
      key == 'luoxue' ? RefreshDataSource.luoxue : RefreshDataSource.shuiyu;

  /// 界面上显示的名字。
  String get displayName =>
      this == RefreshDataSource.luoxue ? '落雪' : '水鱼';
}

/// 当前数据源（首页摘要显示使用），由刷新对话框 / 账号切换更新。
class CurrentDataSourceNotifier extends ValueNotifier<RefreshDataSource> {
  CurrentDataSourceNotifier._(super.source);
  static final CurrentDataSourceNotifier instance =
      CurrentDataSourceNotifier._(RefreshDataSource.shuiyu);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    instance.value = RefreshDataSource.fromKey(
      prefs.getString(CacheKeyConstant.lastDataSource),
    );
  }

  Future<void> set(RefreshDataSource source) async {
    value = source;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(CacheKeyConstant.lastDataSource, source.key);
  }
}
