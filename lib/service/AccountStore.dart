import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constant/CacheKeyConstant.dart';
import '../utils/CurrentDataSourceNotifier.dart';

/// 单个数据源（账号）的元信息，用于切换面板展示。
class AccountMeta {
  final String source; // 'shuiyu' / 'luoxue'
  final String id; // 水鱼 QQ / 落雪 friendCode
  final String nickname;
  final int rating; // 段位（additional_rating），落雪没有则 0
  final int best50TotalRA;
  final int best35TotalRA;
  final int best15TotalRA;
  final bool hasData; // 是否缓存过成绩
  final int updatedAt; // ms

  const AccountMeta({
    required this.source,
    this.id = '',
    this.nickname = '',
    this.rating = 0,
    this.best50TotalRA = 0,
    this.best35TotalRA = 0,
    this.best15TotalRA = 0,
    this.hasData = false,
    this.updatedAt = 0,
  });

  AccountMeta copyWith({
    String? id,
    String? nickname,
    int? rating,
    int? best50TotalRA,
    int? best35TotalRA,
    int? best15TotalRA,
    bool? hasData,
    int? updatedAt,
  }) {
    return AccountMeta(
      source: source,
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      rating: rating ?? this.rating,
      best50TotalRA: best50TotalRA ?? this.best50TotalRA,
      best35TotalRA: best35TotalRA ?? this.best35TotalRA,
      best15TotalRA: best15TotalRA ?? this.best15TotalRA,
      hasData: hasData ?? this.hasData,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'source': source,
        'id': id,
        'nickname': nickname,
        'rating': rating,
        'best50TotalRA': best50TotalRA,
        'best35TotalRA': best35TotalRA,
        'best15TotalRA': best15TotalRA,
        'hasData': hasData,
        'updatedAt': updatedAt,
      };

  factory AccountMeta.fromJson(Map<String, dynamic> json) {
    return AccountMeta(
      source: json['source']?.toString() ?? '',
      id: json['id']?.toString() ?? '',
      nickname: json['nickname']?.toString() ?? '',
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      best50TotalRA: (json['best50TotalRA'] as num?)?.toInt() ?? 0,
      best35TotalRA: (json['best35TotalRA'] as num?)?.toInt() ?? 0,
      best15TotalRA: (json['best15TotalRA'] as num?)?.toInt() ?? 0,
      hasData: json['hasData'] == true,
      updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 双账号系统的存储层。
///
/// 设计：现有那一套「单槽」prefs 键（`user_play_data` / `userNickname` /
/// `last_used_qq` ...）继续作为**当前账号活动槽**，读取端完全不用改；
/// 每个数据源另存一份**存档**，切换时把活动槽与存档互相写入。
///
/// 键分两组：
///   * play：成绩 / Best50 / 推荐结果 / 排行榜参与 —— 可重新拉取，不进备份
///   * identity：昵称 / QQ / userId / 评论身份 / 评分摘要 —— 用户数据，进备份
class AccountStore {
  AccountStore._();

  /// play 组：活动槽里属于「成绩」的键（不含动态的 `best50_data_{id}`）。
  static const List<String> playKeys = [
    CacheKeyConstant.userPlayData,
    CacheKeyConstant.recommendationResults,
    CacheKeyConstant.participateRankings,
    CacheKeyConstant.showNickname,
    'last_used_qq',
  ];

  /// identity 组：活动槽里属于「身份」的键。
  static const List<String> identityKeys = [
    CacheKeyConstant.userNickname,
    CacheKeyConstant.cachedQQ,
    CacheKeyConstant.shuiyuUserId,
    CacheKeyConstant.luoxueUserId,
    CacheKeyConstant.selectedPlateIdCache,
    'best50TotalRA',
    'best35TotalRA',
    'best15TotalRA',
    CacheKeyConstant.commentDataSource,
    CacheKeyConstant.commentOriginalId,
    CacheKeyConstant.commentNickname,
  ];

  static String _identityArchiveKey(String source) =>
      '${CacheKeyConstant.accountArchiveIdentityPrefix}$source';
  static String _playArchiveKey(String source) =>
      '${CacheKeyConstant.accountArchivePlayPrefix}$source';

  /// 当前活动槽里按 QQ/ID 分键的 Best50 缓存键（键名形如 `best50_data_{id}`，没有则 null）。
  static Future<String?> _best50KeyOfActiveSlot(SharedPreferences prefs) async {
    final lastQQ = prefs.getString('last_used_qq');
    if (lastQQ == null || lastQQ.isEmpty) return null;
    return 'best50_data_$lastQQ';
  }

  // ───────────────────────── 元信息 ─────────────────────────

  static Future<Map<String, AccountMeta>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(CacheKeyConstant.accountStore);
    final result = <String, AccountMeta>{};
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = json.decode(raw);
        if (decoded is Map) {
          decoded.forEach((k, v) {
            if (v is Map<String, dynamic>) {
              result[k.toString()] = AccountMeta.fromJson(v);
            } else if (v is Map) {
              result[k.toString()] =
                  AccountMeta.fromJson(Map<String, dynamic>.from(v));
            }
          });
        }
      } catch (e) {
        debugPrint('读取账号元信息失败: $e');
      }
    }
    return result;
  }

  static Future<void> upsert(AccountMeta meta) async {
    final all = await loadAll();
    all[meta.source] = meta;
    await _persistAll(all);
  }

  static Future<void> remove(String source) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await loadAll();
    all.remove(source);
    await _persistAll(all);
    await prefs.remove(_identityArchiveKey(source));
    await prefs.remove(_playArchiveKey(source));
  }

  static Future<void> _persistAll(Map<String, AccountMeta> all) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      CacheKeyConstant.accountStore,
      json.encode(all.map((k, v) => MapEntry(k, v.toJson()))),
    );
  }

  // ───────────────────────── 存档读写 ─────────────────────────

  static Future<bool> hasCache(String source) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_playArchiveKey(source));
    if (raw == null || raw.isEmpty) return false;
    try {
      final decoded = json.decode(raw);
      if (decoded is Map) {
        return decoded[CacheKeyConstant.userPlayData] != null;
      }
    } catch (_) {}
    return false;
  }

  /// 把当前活动槽写进 [source] 的存档。
  static Future<void> writeActiveSlotToArchive(String source) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final playMap = <String, dynamic>{};
      for (final k in playKeys) {
        final v = prefs.get(k);
        if (v != null) playMap[k] = v;
      }
      final best50Key = await _best50KeyOfActiveSlot(prefs);
      if (best50Key != null) {
        final v = prefs.get(best50Key);
        if (v != null) playMap[best50Key] = v;
      }
      // 活动槽里没有成绩数据时，不要用空存档覆盖已有存档（避免误删）。
      final slotHasPlay = playMap[CacheKeyConstant.userPlayData] != null;
      final archiveExists =
          prefs.getString(_playArchiveKey(source))?.isNotEmpty ?? false;
      if (slotHasPlay || !archiveExists) {
        await prefs.setString(_playArchiveKey(source), json.encode(playMap));
      }

      final identityMap = <String, dynamic>{};
      for (final k in identityKeys) {
        final v = prefs.get(k);
        if (v != null) identityMap[k] = v;
      }
      await prefs.setString(
        _identityArchiveKey(source),
        json.encode(identityMap),
      );
    } catch (e) {
      debugPrint('写账号存档失败($source): $e');
    }
  }

  /// 把 [source] 的存档写回活动槽（覆盖）。
  static Future<void> loadArchiveIntoActiveSlot(String source) async {
    final prefs = await SharedPreferences.getInstance();
    await _applyArchive(prefs, _identityArchiveKey(source));
    await _applyArchive(prefs, _playArchiveKey(source));
  }

  static Future<void> _applyArchive(
      SharedPreferences prefs, String archiveKey) async {
    final raw = prefs.getString(archiveKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map) return;
      final writes = <Future<bool>>[];
      decoded.forEach((k, v) {
        final key = k.toString();
        if (v is String) {
          writes.add(prefs.setString(key, v));
        } else if (v is int) {
          writes.add(prefs.setInt(key, v));
        } else if (v is bool) {
          writes.add(prefs.setBool(key, v));
        } else if (v is double) {
          writes.add(prefs.setDouble(key, v));
        }
      });
      await Future.wait(writes);
    } catch (e) {
      debugPrint('读账号存档失败($archiveKey): $e');
    }
  }

  /// 清空活动槽里属于账号的键；**不动** token / lastDataSource / 主题 / 曲库缓存。
  static Future<void> clearActiveSlot() async {
    final prefs = await SharedPreferences.getInstance();
    final best50Key = await _best50KeyOfActiveSlot(prefs);
    final keys = <String>[
      ...playKeys,
      ...identityKeys,
      if (best50Key != null) best50Key,
    ];
    await Future.wait([for (final k in keys) prefs.remove(k)]);
  }

  // ───────────────────────── 便捷读取（生成 meta）─────────────────────────

  /// 用当前活动槽里的值补全一个账号的元信息（刷新成功后调用）。
  static Future<AccountMeta> buildMetaFromActiveSlot(
    RefreshDataSource source, {
    String? id,
    String? nickname,
    int? rating,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final best50 = prefs.getInt('best50TotalRA') ?? 0;
    final best35 = prefs.getInt('best35TotalRA') ?? 0;
    final best15 = prefs.getInt('best15TotalRA') ?? 0;
    final resolvedId = id ?? _resolveActiveId(prefs, source);
    final resolvedNick = nickname ?? prefs.getString('userNickname') ?? '';
    return AccountMeta(
      source: source.key,
      id: resolvedId,
      nickname: resolvedNick,
      rating: rating ?? 0,
      best50TotalRA: best50,
      best35TotalRA: best35,
      best15TotalRA: best15,
      hasData: prefs.getString(CacheKeyConstant.userPlayData) != null,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// 取活动槽里当前源的账号 id。
  ///
  /// 优先用按源区分的标记键（`shuiyu_user_id` / `luoxue_user_id`，只会被对应源的
  /// 刷新写入），避免共用的 `cachedQQ` 在异常路径下把另一个源的 QQ/ID 串过来。
  static String _resolveActiveId(
      SharedPreferences prefs, RefreshDataSource source) {
    final markerKey = source == RefreshDataSource.shuiyu
        ? CacheKeyConstant.shuiyuUserId
        : CacheKeyConstant.luoxueUserId;
    final marker = prefs.getString(markerKey);
    if (marker != null && marker.contains(':')) {
      final value = marker.substring(marker.indexOf(':') + 1);
      if (value.isNotEmpty) return value;
    }
    // 兜底：只有拿不到按源标记时才用共用的 cachedQQ
    return prefs.getString(CacheKeyConstant.cachedQQ) ?? '';
  }
}
