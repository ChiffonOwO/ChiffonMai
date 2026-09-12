import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constant/CacheKeyConstant.dart';

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
  int get hashCode =>
      Object.hash(nickname, best50TotalRA, best35TotalRA, best15TotalRA, cachedQQ);

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
      nickname: prefs.getString('userNickname') ?? UserProfile.defaults.nickname,
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

  /// 完整登出水鱼账号：清除所有水鱼账号相关的成绩 / 缓存。
  ///
  /// 与 [clear] 不同：本方法还会清掉水鱼缓存的 player/records、Best50 缓存、
  /// 排行榜缓存与参与设置、推荐结果、评论身份，并把 `lastDataSource` 重置为
  /// `shuiyu`（同时清掉 SharedPreferences 中的条目）。
  ///
  /// 不清的（账号通用静态数据）：歌曲 / 难度 / 标签 / 收藏品 / maidata 缓存 /
  /// 主题设置 / 收藏功能 / KaleidXScope 标记 / 猜歌设置 / 落雪缓存（落雪先不动）。
  static Future<void> clearShuiyuAccountCache() async {
    final prefs = await SharedPreferences.getInstance();
    // 先读上一个 QQ，用于定位按 QQ 分键的 Best50 缓存。
    final lastQQ = prefs.getString('last_used_qq');
    // 把所有需清除的键一次性并行移除，避免逐个 await 造成长时间无反馈。
    final keys = <String>[
      // 1) 登录 token / 账号关联
      CacheKeyConstant.probeDivingFishToken,
      CacheKeyConstant.probeDivingFishImportToken,
      CacheKeyConstant.probeDivingFishBindQQ,
      CacheKeyConstant.shuiyuUserId,
      // 2) 个人成绩缓存（水鱼 player/records 拉回来的原始记录）
      CacheKeyConstant.userPlayData,
      // 3) Best50 缓存（按 QQ 分键，清掉 last_used_qq 与上一个 QQ 的缓存）
      'last_used_qq',
      if (lastQQ != null && lastQQ.isNotEmpty) 'best50_data_$lastQQ',
      // 4) 推荐结果（依赖个人成绩，账号换人后失效）
      CacheKeyConstant.recommendationResults,
      // 5) 排行榜参与设置（按账号绑定）
      CacheKeyConstant.participateRankings,
      CacheKeyConstant.showNickname,
      // 6) 排行榜缓存（水鱼 + 总榜）
      CacheKeyConstant.shuiyuRankingsCache,
      CacheKeyConstant.shuiyuRankingsCacheTimestamp,
      CacheKeyConstant.totalRankingsCache,
      CacheKeyConstant.totalRankingsCacheTimestamp,
      // 7) 评论身份（按账号生成）
      CacheKeyConstant.commentDataSource,
      CacheKeyConstant.commentOriginalId,
      CacheKeyConstant.commentNickname,
      // 8) 上次数据源：清掉 prefs 条目，首页"数据源"摘要回退到默认"水鱼"
      CacheKeyConstant.lastDataSource,
      // 9) 最后清掉内存中的 UserProfile（同时清掉 prefs 里的昵称 / Rating / QQ）
      'userNickname',
      'best50TotalRA',
      'best35TotalRA',
      'best15TotalRA',
      'cachedQQ',
      'probe_diving_fish_bind_qq',
    ];
    await Future.wait([for (final key in keys) prefs.remove(key)]);
    _publish(UserProfile.loggedOut);
  }

  static void _publish(UserProfile next) {
    if (instance.value != next) {
      instance.value = next;
    }
  }
}