import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../manager/DivingFish/UserPlayDataManager.dart';
import '../entity/FriendComparisonResult.dart';

/// 好友战绩对比服务
/// 拉取当前用户和好友的游玩数据，进行谱面对比
class FriendCompareService {
  static final FriendCompareService _instance = FriendCompareService._internal();
  factory FriendCompareService() => _instance;
  FriendCompareService._internal();

  /// 与好友进行战绩对比
  /// [friendQQ] 好友的 QQ 号
  /// 返回 ComparisonResult
  Future<ComparisonResult> compareWithFriend(String friendQQ) async {
    // 保存本地缓存数据，防止被好友数据覆盖
    final userPlayDataManager = UserPlayDataManager();
    final myQQ = await getCachedQQ();
    if (myQQ.isEmpty) {
      throw Exception('当前用户未绑定 QQ，请先在首页刷新数据');
    }

    // 先备份本地缓存
    final cachedBackup = await userPlayDataManager.getCachedUserPlayData();

    // 1. 拉取自己的最新数据
    Map<String, dynamic>? myData;
    try {
      myData = await userPlayDataManager.fetchUserPlayData(myQQ);
    } catch (e) {
      debugPrint('获取自己数据失败: $e');
      throw Exception('获取自己数据失败，请检查网络连接');
    }
    if (myData == null || myData['records'] == null) {
      throw Exception('当前用户无游玩数据，请先在首页刷新数据');
    }

    final myRecords = myData['records'] as List<dynamic>;
    final myRating = (myData['rating'] as num?)?.toInt() ?? 0;

    // 2. 获取好友的游玩数据（会覆盖缓存，下面会恢复）
    Map<String, dynamic>? friendData;
    try {
      friendData = await userPlayDataManager.fetchUserPlayData(friendQQ);
    } catch (e) {
      debugPrint('获取好友数据失败: $e');
      // 恢复本地缓存
      if (cachedBackup != null) {
        await userPlayDataManager.restoreCache(cachedBackup);
      }
      throw Exception('获取好友数据失败，请检查 QQ 号是否正确（好友需要在水鱼查分器注册）');
    }

    if (friendData == null || friendData['records'] == null) {
      if (cachedBackup != null) {
        await userPlayDataManager.restoreCache(cachedBackup);
      }
      throw Exception('未找到该好友的游玩数据，请检查 QQ 号是否正确');
    }

    final friendRecords = friendData['records'] as List<dynamic>;
    final friendNickname = friendData['nickname'] ?? friendQQ;
    final friendRating = (friendData['rating'] as num?)?.toInt() ?? 0;

    // 3. 恢复本地缓存（好友数据已获取，立即恢复自己的数据到缓存）
    if (cachedBackup != null) {
      userPlayDataManager.restoreCache(cachedBackup);
    }

    // 3. 构建查找 Map：key = "songId_levelIndex"
    final myMap = <String, Map<String, dynamic>>{};
    for (final record in myRecords) {
      final songId = record['song_id']?.toString() ?? '';
      final levelIndex = record['level_index']?.toString() ?? '';
      if (songId.isNotEmpty) {
        myMap['${songId}_$levelIndex'] = record as Map<String, dynamic>;
      }
    }

    final friendMap = <String, Map<String, dynamic>>{};
    for (final record in friendRecords) {
      final songId = record['song_id']?.toString() ?? '';
      final levelIndex = record['level_index']?.toString() ?? '';
      if (songId.isNotEmpty) {
        friendMap['${songId}_$levelIndex'] = record as Map<String, dynamic>;
      }
    }

    // 4. 取交集
    final commonKeys = myMap.keys.toSet().intersection(friendMap.keys.toSet());

    // 5. 构建对比项列表
    final commonCharts = <ChartComparisonItem>[];
    int myWinCount = 0, friendWinCount = 0, tieCount = 0;

    for (final key in commonKeys) {
      final myRecord = myMap[key]!;
      final friendRecord = friendMap[key]!;

      final myAchievements = _toDouble(myRecord['achievements']);
      final friendAchievements = _toDouble(friendRecord['achievements']);

      final item = ChartComparisonItem(
        songId: int.tryParse(myRecord['song_id']?.toString() ?? '0') ?? 0,
        songTitle: myRecord['title']?.toString() ?? '',
        levelIndex: _toInt(myRecord['level_index']),
        levelLabel: myRecord['level_label']?.toString() ?? '',
        ds: _toDouble(myRecord['ds']),
        type: myRecord['type']?.toString() ?? '',
        myAchievements: myAchievements,
        friendAchievements: friendAchievements,
        myRa: _toInt(myRecord['ra']),
        friendRa: _toInt(friendRecord['ra']),
        myRate: myRecord['rate']?.toString() ?? '',
        friendRate: friendRecord['rate']?.toString() ?? '',
        myFc: myRecord['fc']?.toString() ?? '',
        friendFc: friendRecord['fc']?.toString() ?? '',
        myFs: myRecord['fs']?.toString() ?? '',
        friendFs: friendRecord['fs']?.toString() ?? '',
        myDxScore: _toInt(myRecord['dxScore']),
        friendDxScore: _toInt(friendRecord['dxScore']),
      );

      commonCharts.add(item);

      if (item.isMyWin) {
        myWinCount++;
      } else if (item.isFriendWin) {
        friendWinCount++;
      } else {
        tieCount++;
      }
    }

    // 按定数降序排列
    commonCharts.sort((a, b) => b.ds.compareTo(a.ds));

    return ComparisonResult(
      commonCharts: commonCharts,
      myTotalCharts: myRecords.length,
      friendTotalCharts: friendRecords.length,
      commonCount: commonKeys.length,
      myWinCount: myWinCount,
      friendWinCount: friendWinCount,
      tieCount: tieCount,
      friendNickname: friendNickname,
      friendRating: friendRating,
      myRating: myRating,
    );
  }

  /// 获取当前用户的 QQ
  Future<String> getCachedQQ() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('cachedQQ') ?? '';
    } catch (_) {
      return '';
    }
  }

  // --- 历史记录 ---

  static const String _historyKey = 'friend_compare_history';

  /// 保存对比记录
  Future<void> saveHistory(String friendQQ, ComparisonResult result) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_historyKey);
      final List<dynamic> history = jsonStr != null ? json.decode(jsonStr) : [];

      // 移除同一好友的旧记录
      history.removeWhere((e) => e['friendQQ'] == friendQQ);

      // 插入新记录到最前面
      history.insert(0, {
        'friendQQ': friendQQ,
        'friendNickname': result.friendNickname,
        'date': DateTime.now().toIso8601String().substring(0, 10),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'myRating': result.myRating,
        'friendRating': result.friendRating,
        'commonCount': result.commonCount,
        'myWinCount': result.myWinCount,
        'friendWinCount': result.friendWinCount,
        'tieCount': result.tieCount,
      });

      // 最多保留 20 条
      if (history.length > 20) {
        history.removeRange(20, history.length);
      }

      await prefs.setString(_historyKey, json.encode(history));
    } catch (e) {
      debugPrint('FriendCompare: 保存历史失败: $e');
    }
  }

  /// 加载历史记录
  Future<List<Map<String, dynamic>>> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_historyKey);
      if (jsonStr == null || jsonStr.isEmpty) return [];
      final List<dynamic> list = json.decode(jsonStr);
      return list.map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      return [];
    }
  }

  /// 删除历史记录
  Future<void> deleteHistory(String friendQQ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_historyKey);
      if (jsonStr == null) return;
      final List<dynamic> history = json.decode(jsonStr);
      history.removeWhere((e) => e['friendQQ'] == friendQQ);
      await prefs.setString(_historyKey, json.encode(history));
    } catch (e) {
      debugPrint('FriendCompare: 删除历史失败: $e');
    }
  }

  /// 清空全部历史
  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}
