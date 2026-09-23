import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../api/ApiUrls.dart';
import '../../constant/CacheKeyConstant.dart';
import '../../constant/CacheTimestampConstant.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_first_flutter_app/utils/ApiClient.dart';

/// 平均值排行榜的衡量指标
enum AvgMetric {
  achievement, // 平均达成率
  dx, // 平均DX得分达成率
}

/// 单个玩家在平均值排行榜中的条目
class AvgRankItem {
  int rank;
  final String playerId;
  final String playerName;
  final String dataSource;
  final double avgAchievement;
  final double avgDxAchievement;
  final int achievementCount;
  final int dxCount;
  final int updateTime;

  AvgRankItem({
    this.rank = 0,
    required this.playerId,
    required this.playerName,
    required this.dataSource,
    required this.avgAchievement,
    required this.avgDxAchievement,
    required this.achievementCount,
    required this.dxCount,
    this.updateTime = 0,
  });

  factory AvgRankItem.fromJson(Map<String, dynamic> json) {
    final playerId = (json['playerId'] ?? json['player_id'] ?? '').toString();
    return AvgRankItem(
      rank: (json['rank'] ?? 0) as int,
      playerId: playerId,
      playerName: (json['playerName'] ?? json['player_name'] ?? '').toString(),
      dataSource: (json['dataSource'] ?? json['data_source'] ?? '')
          .toString()
          .isNotEmpty
          ? (json['dataSource'] ?? json['data_source'] ?? '').toString()
          : _parseDataSource(playerId),
      avgAchievement:
          (json['avgAchievement'] ?? json['avg_achievement'] ?? 0).toDouble(),
      avgDxAchievement:
          (json['avgDxAchievement'] ?? json['avg_dx_achievement'] ?? 0)
              .toDouble(),
      achievementCount:
          (json['achievementCount'] ?? json['achievement_count'] ?? 0).toInt(),
      dxCount: (json['dxCount'] ?? json['dx_count'] ?? 0).toInt(),
      updateTime: (json['updateTime'] ?? json['update_time'] ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rank': rank,
      'playerId': playerId,
      'playerName': playerName,
      'dataSource': dataSource,
      'avgAchievement': avgAchievement,
      'avgDxAchievement': avgDxAchievement,
      'achievementCount': achievementCount,
      'dxCount': dxCount,
      'updateTime': updateTime,
    };
  }
}

/// 根据 playerId 前缀推断数据源（与 SongRankingService.parseDataSource 一致）
String _parseDataSource(String playerId) {
  if (playerId.startsWith('shuiyu:')) return 'shuiyu';
  if (playerId.startsWith('luoxue:')) return 'luoxue';
  return 'luoxue';
}

class AvgRankingListService {
  // 缓存有效期：从常量文件读取（分钟转秒）
  static int get _cacheExpirySeconds =>
      CacheTimestampConstant.rankingsCacheMinutes * 60;

  /// 测试专用：把排行榜请求打桩掉（见 [getAverages] 里的用法）。真机永远是 null。
  @visibleForTesting
  static Future<List<AvgRankItem>> Function()? debugRankingsLoader;

  // 获取所有玩家的平均值数据（原始、未排序），可读缓存
  static Future<List<AvgRankItem>> getAverages({bool refresh = false}) async {
    if (!refresh) {
      final cachedData = await _getCachedRankings();
      if (cachedData != null && cachedData.isNotEmpty) {
        return cachedData;
      }
    }

    // 测试专用打桩：这几个排行榜接口都不读缓存（rankingsCacheMinutes = -1），
    // widget 测试里不打桩页面永远停在空状态，几何/间距问题就量不出来。
    // 真机（debug/release）永远是 null。
    final stub = debugRankingsLoader;
    if (stub != null) return stub();

    try {
      final url =
          Uri.parse('${ApiUrls.SongRankingsAveragesUrl}?refresh=$refresh');
      final response = await ApiClient.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          final items = (result['data'] as List<dynamic>)
              .map((e) => AvgRankItem.fromJson(e as Map<String, dynamic>))
              .toList();
          await _cacheRankings(items);
          return items;
        }
      }
      debugPrint('获取平均值排行榜失败: HTTP ${response.statusCode}: ${response.body}');
    } catch (e) {
      debugPrint('获取平均值排行榜失败: $e');
    }
    return [];
  }

  // 按指标排序并分配排名（并列名次，1,1,3,3,5 风格）
  static List<AvgRankItem> calculateRankedPositions(
    List<AvgRankItem> items,
    AvgMetric metric,
  ) {
    if (items.isEmpty) return items;

    double valueOf(AvgRankItem item) =>
        metric == AvgMetric.achievement ? item.avgAchievement : item.avgDxAchievement;

    final sortedItems = List<AvgRankItem>.from(items)
      ..sort((a, b) => valueOf(b).compareTo(valueOf(a)));

    for (int i = 0; i < sortedItems.length; i++) {
      if (i == 0) {
        sortedItems[i].rank = 1;
      } else {
        if (valueOf(sortedItems[i]) == valueOf(sortedItems[i - 1])) {
          sortedItems[i].rank = sortedItems[i - 1].rank;
        } else {
          sortedItems[i].rank = i + 1;
        }
      }
    }

    return sortedItems;
  }

  // 从缓存读取平均值排行数据
  static Future<List<AvgRankItem>?> _getCachedRankings() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(CacheKeyConstant.avgRankingsCacheTimestamp);

    if (timestamp != null) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (now - timestamp < _cacheExpirySeconds) {
        final cachedJson = prefs.getString(CacheKeyConstant.avgRankingsCache);
        if (cachedJson != null) {
          try {
            final List<dynamic> data = json.decode(cachedJson);
            return data
                .map((e) => AvgRankItem.fromJson(e as Map<String, dynamic>))
                .toList();
          } catch (e) {
            debugPrint('解析缓存的平均值排行数据失败: $e');
          }
        }
      }
    }
    return null;
  }

  // 保存平均值排行数据到缓存
  static Future<void> _cacheRankings(List<AvgRankItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final jsonString =
          json.encode(items.map((item) => item.toJson()).toList());
      await prefs.setString(CacheKeyConstant.avgRankingsCache, jsonString);
      await prefs.setInt(
        CacheKeyConstant.avgRankingsCacheTimestamp,
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
    } catch (e) {
      debugPrint('保存平均值排行缓存失败: $e');
    }
  }

  // 清除平均值排行缓存（用于强制刷新）
  static Future<void> clearRankingsCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(CacheKeyConstant.avgRankingsCache);
    await prefs.remove(CacheKeyConstant.avgRankingsCacheTimestamp);
  }
}
