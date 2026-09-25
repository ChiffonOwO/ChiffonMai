import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constant/CacheKeyConstant.dart';

/// 数据源：水鱼（Diving-Fish）、落雪（LuoXue）、AWMC NET。
///
/// 原先定义在 RefreshDataDialog.dart 里；双账号系统需要在 service 层引用它，
/// 所以抽到这里，RefreshDataDialog 内 export 出去，保持既有 import 不变。
enum RefreshDataSource {
  shuiyu,
  luoxue,
  awmc;

  /// 持久化用的键（写入 `last_data_source`）。
  String get key => name;

  static RefreshDataSource fromKey(String? key) {
    switch (key) {
      case 'luoxue':
        return RefreshDataSource.luoxue;
      case 'awmc':
        return RefreshDataSource.awmc;
      default:
        return RefreshDataSource.shuiyu;
    }
  }

  /// 界面上显示的名字。
  String get displayName {
    switch (this) {
      case RefreshDataSource.luoxue:
        return '落雪';
      case RefreshDataSource.awmc:
        return 'AWMC NET';
      case RefreshDataSource.shuiyu:
        return '水鱼';
    }
  }

  /// 紧凑场景用的短名（榜单里用户名前的小标签、排行榜 Tab 等）。
  ///
  /// 与 [displayName] 分开的原因：`AWMC NET` 放在 4 个平分一行的 Tab 里
  /// （每格约 80dp）会顶到边界、甚至折行；而「账号面板 / 数据源摘要 / 导出图」
  /// 这类宽裕的地方仍然希望显示完整名字。水鱼 / 落雪的短名与全名相同。
  String get shortDisplayName {
    switch (this) {
      case RefreshDataSource.luoxue:
        return '落雪';
      case RefreshDataSource.awmc:
        return 'AWMC';
      case RefreshDataSource.shuiyu:
        return '水鱼';
    }
  }

  /// 把持久化的 key 翻成界面名字；未知 / 空 key 返回空串。
  ///
  /// 与 [fromKey] 的区别：`fromKey` 对未知 key 会**兜底成水鱼**（切账号需要个确定值），
  /// 而导出图里的数据源标签宁可留空，也不能把未知来源错标成「水鱼」。
  static String displayNameOfKey(String? key) => _labelOfKey(key, short: false);

  /// [shortDisplayName] 的 key 版本，同样对未知 / 空 key 返回空串。
  static String shortDisplayNameOfKey(String? key) =>
      _labelOfKey(key, short: true);

  static String _labelOfKey(String? key, {required bool short}) {
    if (key == null || key.isEmpty) return '';
    for (final source in values) {
      if (source.key == key) {
        return short ? source.shortDisplayName : source.displayName;
      }
    }
    return '';
  }

  /// 该源的账号 id 是不是 **QQ 号**。
  ///
  /// 水鱼（绑定 QQ）与 AWMC NET（按 QQ 查分）都是；落雪是 friendCode。
  /// 用来决定界面上显示「QQ xxx」还是「ID xxx」——不要再写
  /// `source == RefreshDataSource.shuiyu ? 'QQ' : 'ID'`，那会把 AWMC NET 显示成 ID。
  bool get idIsQQ => this != RefreshDataSource.luoxue;

  /// 该源的「当前账号 id 标记」prefs 键。
  ///
  /// 每个源单独记一个 `'<source>:<id>'`。存在的意义是：共用的 `cachedQQ`
  /// 在异常路径下会把另一个源的 QQ/ID 串过来，所以
  /// `AccountStore._resolveActiveId` 优先读这个按源区分的标记。
  String get userIdCacheKey {
    switch (this) {
      case RefreshDataSource.shuiyu:
        return CacheKeyConstant.shuiyuUserId;
      case RefreshDataSource.luoxue:
        return CacheKeyConstant.luoxueUserId;
      case RefreshDataSource.awmc:
        return CacheKeyConstant.awmcUserId;
    }
  }

  /// 把 `'shuiyu:488581724'` 这样的标记拆出纯 id；不合法时返回 null。
  static String? parseUserIdMarker(String? marker) {
    if (marker == null) return null;
    final index = marker.indexOf(':');
    if (index < 0) return null;
    final value = marker.substring(index + 1);
    return value.isEmpty ? null : value;
  }
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(CacheKeyConstant.lastDataSource, source.key);
    value = source;
  }
}
