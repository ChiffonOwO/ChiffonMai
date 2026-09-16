import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constant/CacheKeyConstant.dart';
import '../utils/CurrentDataSourceNotifier.dart';
import '../utils/LoginStateNotifier.dart';
import '../utils/UserProfileNotifier.dart';
import 'AccountStore.dart';

enum SwitchOutcome {
  /// 切换成功
  switched,

  /// 目标账号没有缓存数据，需要先刷新
  noCache,

  /// 目标就是当前账号
  sameSource,

  /// 正在切换中
  busy,
}

/// 双账号切换的核心逻辑。
///
/// 现有单槽 prefs 键是「当前账号活动槽」，每个数据源另有一份存档；
/// 切换 = 活动槽写回当前源存档 → 目标源存档写进活动槽 → 更新指针与各 Notifier。
/// 读取端（约 50 处 `getCachedUserPlayData()`）完全不需要改动。
class AccountSwitchService {
  AccountSwitchService._();

  static bool _busy = false;

  /// 把当前活动槽的账号数据切到 [target]。使用缓存，不联网。
  static Future<SwitchOutcome> switchTo(RefreshDataSource target) async {
    if (_busy) return SwitchOutcome.busy;
    _busy = true;
    try {
      final current = CurrentDataSourceNotifier.instance.value;
      if (current == target) return SwitchOutcome.sameSource;

      // 1) 先把当前账号的数据存回它自己的存档
      await AccountStore.writeActiveSlotToArchive(current.key);

      // 2) 目标没有缓存 → 什么都不动，交给调用方引导刷新
      if (!await AccountStore.hasCache(target.key)) {
        return SwitchOutcome.noCache;
      }

      // 3) 崩溃恢复标记：清槽前先记下目标源，中途被杀也能恢复
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(CacheKeyConstant.accountRotationPending, target.key);

      // 4) 活动槽换入目标源存档
      await AccountStore.clearActiveSlot();
      await AccountStore.loadArchiveIntoActiveSlot(target.key);
      await CurrentDataSourceNotifier.instance.set(target);

      // 5) 刷新内存里的共享状态（首页 / 各页面自动重建）
      await UserProfileNotifier.load();
      await LoginStateNotifier.load();

      await prefs.remove(CacheKeyConstant.accountRotationPending);
      return SwitchOutcome.switched;
    } catch (e) {
      debugPrint('切换账号失败: $e');
      return SwitchOutcome.busy;
    } finally {
      _busy = false;
    }
  }

  /// 刷新前调用：保证活动槽属于即将刷新的 [source]。
  ///
  /// 必须做这一步，否则「当前是落雪、用户去刷水鱼」会把落雪的活动槽直接覆盖。
  /// 目标没有缓存时也继续——刷新流程随后会把数据填进去。
  static Future<void> prepareForRefresh(RefreshDataSource source) async {
    await ensureMigrated();
    if (CurrentDataSourceNotifier.instance.value == source) return;
    await switchTo(source);
  }

  /// 刷新成功后调用：把新的活动槽存进该源存档并更新元信息。
  static Future<void> onRefreshCompleted(RefreshDataSource source) async {
    await AccountStore.writeActiveSlotToArchive(source.key);
    final meta = await AccountStore.buildMetaFromActiveSlot(source);
    await AccountStore.upsert(meta);
    await CurrentDataSourceNotifier.instance.set(source);
    await UserProfileNotifier.load();
  }

  /// 清除某个账号的**缓存数据**（成绩 / Best50 / 玩家信息 / 推荐结果等），
  /// **不动登录 token**——下次刷新不用重新登录。
  ///
  /// 若清除的正是当前账号：回落到另一个账号（有缓存时），否则清空当前资料。
  static Future<void> clearAccountData(RefreshDataSource source) async {
    await AccountStore.remove(source.key);
    if (CurrentDataSourceNotifier.instance.value != source) {
      await UserProfileNotifier.load();
      return;
    }
    final other = source == RefreshDataSource.shuiyu
        ? RefreshDataSource.luoxue
        : RefreshDataSource.shuiyu;
    await AccountStore.clearActiveSlot();
    if (await AccountStore.hasCache(other.key)) {
      await AccountStore.loadArchiveIntoActiveSlot(other.key);
      await CurrentDataSourceNotifier.instance.set(other);
    } else {
      await CurrentDataSourceNotifier.instance.set(RefreshDataSource.shuiyu);
    }
    await UserProfileNotifier.load();
    await LoginStateNotifier.load();
  }

  /// 某个账号登出后调用。数据清理与 [clearAccountData] 相同；
  /// 该源的 token / 评分缓存由调用方负责清除。
  static Future<void> onAccountLoggedOut(RefreshDataSource source) =>
      clearAccountData(source);

  /// 启动时调用：若上次切换中途被杀，重新把标记的目标源存档写回活动槽。
  static Future<void> recoverIfInterrupted() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getString(CacheKeyConstant.accountRotationPending);
    if (pending == null || pending.isEmpty) return;
    try {
      await AccountStore.loadArchiveIntoActiveSlot(pending);
      await CurrentDataSourceNotifier.instance
          .set(RefreshDataSource.fromKey(pending));
      await UserProfileNotifier.load();
    } catch (e) {
      debugPrint('恢复账号切换失败: $e');
    } finally {
      await prefs.remove(CacheKeyConstant.accountRotationPending);
    }
  }

  /// 首次运行时把旧的「单套缓存」迁进账号系统（按 last_data_source 归到对应源）。
  static Future<void> ensureMigrated() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(CacheKeyConstant.accountStore)) {
      await recoverIfInterrupted();
      return;
    }
    final source = RefreshDataSource.fromKey(
      prefs.getString(CacheKeyConstant.lastDataSource),
    );
    final hasPlay = prefs.getString(CacheKeyConstant.userPlayData) != null;
    if (hasPlay) {
      await AccountStore.writeActiveSlotToArchive(source.key);
    }
    final meta = await AccountStore.buildMetaFromActiveSlot(source);
    await AccountStore.upsert(meta.copyWith(hasData: hasPlay));

    // 另一源写一份空占位，切换面板才能同时列出两个账号
    final other = source == RefreshDataSource.shuiyu
        ? RefreshDataSource.luoxue
        : RefreshDataSource.shuiyu;
    final all = await AccountStore.loadAll();
    if (!all.containsKey(other.key)) {
      await AccountStore.upsert(AccountMeta(source: other.key));
    }

    await recoverIfInterrupted();
  }
}
