import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constant/CacheKeyConstant.dart';
import 'CurrentDataSourceNotifier.dart';
import '../service/AccountSwitchService.dart';

/// 未登录 / 未写入昵称时显示的占位文案：
/// `displayNickname` 工具方法使用，便于首页 / 我的页等保持一致。
const String kUnsetNicknameLabel = '请登录';

/// 用户个人信息快照：昵称 / Rating / QQ。
/// 值对象，变更时整体替换以触发 ValueListenableBuilder 重建。
class UserProfile {
  final String nickname;
  final int best50TotalRA;
  final int best35TotalRA;
  final int best15TotalRA;
  final String cachedQQ;

  const UserProfile({
    required this.nickname,
    required this.best50TotalRA,
    required this.best35TotalRA,
    required this.best15TotalRA,
    required this.cachedQQ,
  });

  /// 首次进入应用、尚未写入任何缓存时的默认值（昵称为空，显示时回落为"请登录"；Rating 为 0，显示为 "-"）。
  static const UserProfile defaults = UserProfile(
    nickname: '',
    best50TotalRA: 0,
    best35TotalRA: 0,
    best15TotalRA: 0,
    cachedQQ: '',
  );

  /// 已清空登录态后的"未登录"快照：昵称置空，Rating 归零。
  static const UserProfile loggedOut = UserProfile(
    nickname: '',
    best50TotalRA: 0,
    best35TotalRA: 0,
    best15TotalRA: 0,
    cachedQQ: '',
  );

  UserProfile copyWith({
    String? nickname,
    int? best50TotalRA,
    int? best35TotalRA,
    int? best15TotalRA,
    String? cachedQQ,
  }) {
    return UserProfile(
      nickname: nickname ?? this.nickname,
      best50TotalRA: best50TotalRA ?? this.best50TotalRA,
      best35TotalRA: best35TotalRA ?? this.best35TotalRA,
      best15TotalRA: best15TotalRA ?? this.best15TotalRA,
      cachedQQ: cachedQQ ?? this.cachedQQ,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is UserProfile &&
        other.nickname == nickname &&
        other.best50TotalRA == best50TotalRA &&
        other.best35TotalRA == best35TotalRA &&
        other.best15TotalRA == best15TotalRA &&
        other.cachedQQ == cachedQQ;
  }

  @override
  int get hashCode => Object.hash(
      nickname, best50TotalRA, best35TotalRA, best15TotalRA, cachedQQ);

  /// 渲染用的昵称：未设置时回落为 "请登录"，避免暴露空字符串或硬编码占位符。
  String get displayNickname =>
      nickname.isEmpty ? kUnsetNicknameLabel : nickname;

  /// 渲染用的 Rating：未设置（0）时回落为 "-"，避免暴露硬编码占位数字。
  String get displayBest50RA =>
      best50TotalRA == 0 ? '-' : best50TotalRA.toString();
  String get displayBest35RA =>
      best35TotalRA == 0 ? '-' : best35TotalRA.toString();
  String get displayBest15RA =>
      best15TotalRA == 0 ? '-' : best15TotalRA.toString();
}

/// 用户个人信息共享状态。
///
/// 任意页面（首页 / 我的 Hub / 同步对话框等）写入新值后，
/// 其它监听 [UserProfileNotifier.instance] 的页面会自动重建 UI，
/// 因此登出水鱼账号后首页"欢迎回来，xxx"和我的页头像区昵称会同步更新。
class UserProfileNotifier {
  static final ValueNotifier<UserProfile> instance =
      ValueNotifier<UserProfile>(UserProfile.defaults);

  /// 从 SharedPreferences 加载（应用启动时调用一次）。
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _publish(UserProfile(
      nickname:
          prefs.getString('userNickname') ?? UserProfile.defaults.nickname,
      best50TotalRA:
          prefs.getInt('best50TotalRA') ?? UserProfile.defaults.best50TotalRA,
      best35TotalRA:
          prefs.getInt('best35TotalRA') ?? UserProfile.defaults.best35TotalRA,
      best15TotalRA:
          prefs.getInt('best15TotalRA') ?? UserProfile.defaults.best15TotalRA,
      cachedQQ: prefs.getString('cachedQQ') ?? '',
    ));
  }

  /// 整体覆盖当前快照（例如同步成功 / 数据刷新）。
  static void replace(UserProfile profile) {
    _publish(profile);
  }

  /// 登出水鱼账号：清除 SharedPreferences 中的用户缓存，
  /// 并把内存快照切回 [UserProfile.loggedOut]。
  ///
  /// 监听此 notifier 的页面（首页、我的页等）会自动重建 UI。
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userNickname');
    await prefs.remove('best50TotalRA');
    await prefs.remove('best35TotalRA');
    await prefs.remove('best15TotalRA');
    await prefs.remove('cachedQQ');
    await prefs.remove('probe_diving_fish_bind_qq');
    _publish(UserProfile.loggedOut);
  }

  /// 在账号事务内登出水鱼；活动槽、回落和内存失效由协调器统一处理。
  /// 当前是落雪/AWMC 时仅删除水鱼自己的凭据和存档。
  static Future<void> clearShuiyuAccountCache() =>
      AccountSwitchService.onAccountLoggedOut(RefreshDataSource.shuiyu,
          clearCredentials: () async {
        final prefs = await SharedPreferences.getInstance();
        for (final key in [
          CacheKeyConstant.probeDivingFishToken,
          CacheKeyConstant.probeDivingFishImportToken,
          CacheKeyConstant.probeDivingFishBindQQ,
          CacheKeyConstant.shuiyuRankingsCache,
          CacheKeyConstant.shuiyuRankingsCacheTimestamp,
          CacheKeyConstant.totalRankingsCache,
          CacheKeyConstant.totalRankingsCacheTimestamp,
        ]) {
          await prefs.remove(key);
        }
      });

  static void _publish(UserProfile next) {
    if (instance.value != next) {
      instance.value = next;
    }
  }
}
