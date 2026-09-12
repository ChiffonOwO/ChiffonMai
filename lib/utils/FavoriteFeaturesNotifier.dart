import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constant/CacheKeyConstant.dart';

/// 收藏列表的不可变快照。
///
/// 用一个独立类包装 [Set] 是为了：默认 [Object.==] 走身份比较，
/// 每次 [FavoriteFeaturesNotifier] 发布新值时都会创建新对象，
/// [ValueNotifier] 的 `value` setter 一定判定为"不同"并触发 [notifyListeners]，
/// 避免 Set 在某种边界情况下被认为"相等"导致监听者收不到通知。
@immutable
class FavoritesPayload {
  final Set<String> titles;
  const FavoritesPayload(this.titles);
}

/// 收藏的功能：跨页面共享的实时状态。
///
/// 所有页面（首页、成绩/曲库/娱乐/我的四个 Hub 页、分类页、收藏管理页）
/// 都通过 [FavoriteFeaturesNotifier.instance] 监听同一个 ValueNotifier，
/// 因此在任意一处点星标切换收藏，其他页面会立刻重建 UI。
class FavoriteFeaturesNotifier {
  static final ValueNotifier<FavoritesPayload> _state =
      ValueNotifier<FavoritesPayload>(const FavoritesPayload(<String>{}));

  /// 监听器：任意页面调用 [toggle] / [load] / [replaceAll] 都会触发。
  static ValueListenable<FavoritesPayload> get instance => _state;

  /// 当前收藏标题集合（直接读取实时值，不会触发通知）。
  static Set<String> get titles => _state.value.titles;

  /// 功能改名时的历史标题映射：旧标题 → 新标题。
  ///
  /// 收藏是以**功能标题字符串**为 key 存在 SharedPreferences 里的（见 [toggle]），
  /// 所以功能一改名，用户原来的收藏就会变成一条谁也匹配不上的脏数据、
  /// 表现为「星标莫名其妙没了」。加载时顺手替换掉。
  static const Map<String, String> _renamedTitles = {
    '成绩截图 OCR': '结算画面识别',
  };

  /// 从 SharedPreferences 加载收藏列表（应用启动时调用一次）。
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(CacheKeyConstant.favoriteFeatures) ?? <String>[];
    final titles = raw.toSet();

    final migrated = <String>{};
    var changed = false;
    for (final title in titles) {
      final renamed = _renamedTitles[title];
      if (renamed != null) {
        migrated.add(renamed);
        changed = true;
      } else {
        migrated.add(title);
      }
    }

    _publish(migrated);
    // 只有真的改过才回写，避免每次启动都多写一次磁盘
    if (changed) {
      await prefs.setStringList(
          CacheKeyConstant.favoriteFeatures, migrated.toList());
    }
  }

  /// 切换收藏状态：新增或移除 [title]，并持久化到 SharedPreferences。
  /// 返回切换后是否已收藏。
  static Future<bool> toggle(String title) async {
    final current = _state.value.titles;
    final next = Set<String>.from(current);
    final added = !next.contains(title);
    if (added) {
      next.add(title);
    } else {
      next.remove(title);
    }
    _publish(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(CacheKeyConstant.favoriteFeatures, next.toList());
    return added;
  }

  /// 强制覆盖当前内存与持久化的收藏列表（一般用于清除）。
  static Future<void> replaceAll(Set<String> newTitles) async {
    _publish(Set<String>.from(newTitles));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        CacheKeyConstant.favoriteFeatures, newTitles.toList());
  }

  static void _publish(Set<String> next) {
    // 新 FavoritesPayload 实例 → 身份不同 → ValueNotifier 必定通知。
    _state.value = FavoritesPayload(Set<String>.unmodifiable(next));
  }
}