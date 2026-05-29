import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../api/ApiUrls.dart';
import '../../constant/CacheKeyConstant.dart';
import '../../constant/CacheTimestampConstant.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RatingRankListService {
  // 缓存有效期：从常量文件读取（分钟转秒）
  static int get _cacheExpirySeconds => CacheTimestampConstant.rankingsCacheMinutes * 60;
  // 获取总排行榜
  static Future<List<RankItem>> getTotalRankings({int? limit}) async {
    // 先检查缓存
    final cachedData = await _getCachedRankings(
      CacheKeyConstant.totalRankingsCache,
      CacheKeyConstant.totalRankingsCacheTimestamp,
    );
    if (cachedData != null) {
      return cachedData;
    }

    try {
      String url = '${ApiUrls.RankingsBaseUrl}/total';
      if (limit != null) {
        url += '?limit=$limit';
      }
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          final items = _parseRankItems(result['data']);
          // 保存到缓存
          await _cacheRankings(
            items,
            CacheKeyConstant.totalRankingsCache,
            CacheKeyConstant.totalRankingsCacheTimestamp,
          );
          return items;
        }
      }
    } catch (e) {
      print('获取总排行榜失败: $e');
    }
    return [];
  }

  // 获取水鱼数据源排行榜
  static Future<List<RankItem>> getShuiyuRankings({int? limit}) async {
    // 先检查缓存
    final cachedData = await _getCachedRankings(
      CacheKeyConstant.shuiyuRankingsCache,
      CacheKeyConstant.shuiyuRankingsCacheTimestamp,
    );
    if (cachedData != null) {
      return cachedData;
    }

    try {
      String url = '${ApiUrls.RankingsBaseUrl}/shuiyu';
      if (limit != null) {
        url += '?limit=$limit';
      }
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          final items = _parseRankItems(result['data']);
          // 保存到缓存
          await _cacheRankings(
            items,
            CacheKeyConstant.shuiyuRankingsCache,
            CacheKeyConstant.shuiyuRankingsCacheTimestamp,
          );
          return items;
        }
      }
    } catch (e) {
      print('获取水鱼排行榜失败: $e');
    }
    return [];
  }

  // 获取落雪数据源排行榜
  static Future<List<RankItem>> getLuoxueRankings({int? limit}) async {
    // 先检查缓存
    final cachedData = await _getCachedRankings(
      CacheKeyConstant.luoxueRankingsCache,
      CacheKeyConstant.luoxueRankingsCacheTimestamp,
    );
    if (cachedData != null) {
      return cachedData;
    }

    try {
      String url = '${ApiUrls.RankingsBaseUrl}/luoxue';
      if (limit != null) {
        url += '?limit=$limit';
      }
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          final items = _parseRankItems(result['data']);
          // 保存到缓存
          await _cacheRankings(
            items,
            CacheKeyConstant.luoxueRankingsCache,
            CacheKeyConstant.luoxueRankingsCacheTimestamp,
          );
          return items;
        }
      }
    } catch (e) {
      print('获取落雪排行榜失败: $e');
    }
    return [];
  }

  // 获取指定用户排名
  static Future<int?> getUserRank(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiUrls.RankingsBaseUrl}/user/$userId'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          return result['rank'];
        }
      }
    } catch (e) {
      print('获取用户排名失败: $e');
    }
    return null;
  }

  // 获取指定用户详情
  static Future<RankItem?> getUserDetail(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiUrls.RankingsBaseUrl}/user/detail/$userId'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          return RankItem.fromJson(result['data']);
        }
      }
    } catch (e) {
      print('获取用户详情失败: $e');
    }
    return null;
  }

  // 解析排行榜数据
  static List<RankItem> _parseRankItems(List<dynamic> data) {
    return data.map((item) => RankItem.fromJson(item)).toList();
  }

  // 计算并列排名
  static List<RankItem> calculateRankedPositions(List<RankItem> items) {
    if (items.isEmpty) return items;
    
    // 按总Rating降序排序（确保排序正确）
    List<RankItem> sortedItems = List.from(items)
      ..sort((a, b) => b.totalRating.compareTo(a.totalRating));
    
    // 计算并列排名
    for (int i = 0; i < sortedItems.length; i++) {
      if (i == 0) {
        sortedItems[i].rank = 1;
      } else {
        // 如果当前用户的Rating和上一个相同，则排名相同
        if (sortedItems[i].totalRating == sortedItems[i - 1].totalRating) {
          sortedItems[i].rank = sortedItems[i - 1].rank;
        } else {
          // 否则排名为当前位置+1（因为索引从0开始）
          sortedItems[i].rank = i + 1;
        }
      }
    }
    
    return sortedItems;
  }

  // 从缓存获取排行榜数据
  static Future<List<RankItem>?> _getCachedRankings(String cacheKey, String timestampKey) async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(timestampKey);
    
    // 检查缓存是否存在且未过期
    if (timestamp != null) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (now - timestamp < _cacheExpirySeconds) {
        final cachedJson = prefs.getString(cacheKey);
        if (cachedJson != null) {
          try {
            final List<dynamic> data = json.decode(cachedJson);
            return data.map((item) => RankItem.fromJson(item)).toList();
          } catch (e) {
            print('解析缓存的排行榜数据失败: $e');
          }
        }
      }
    }
    return null;
  }

  // 保存排行榜数据到缓存
  static Future<void> _cacheRankings(List<RankItem> items, String cacheKey, String timestampKey) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final jsonString = json.encode(items.map((item) => item.toJson()).toList());
      await prefs.setString(cacheKey, jsonString);
      await prefs.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch ~/ 1000);
    } catch (e) {
      print('保存排行榜缓存失败: $e');
    }
  }

  // 清除排行榜缓存（用于强制刷新）
  static Future<void> clearRankingsCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(CacheKeyConstant.totalRankingsCache);
    await prefs.remove(CacheKeyConstant.totalRankingsCacheTimestamp);
    await prefs.remove(CacheKeyConstant.shuiyuRankingsCache);
    await prefs.remove(CacheKeyConstant.shuiyuRankingsCacheTimestamp);
    await prefs.remove(CacheKeyConstant.luoxueRankingsCache);
    await prefs.remove(CacheKeyConstant.luoxueRankingsCacheTimestamp);
  }
}

class RankItem {
  int rank;
  final String userId;
  final String dataSource;
  final String originalId;
  final String? nickname;
  final int totalRating;
  final int best35Rating;
  final int best15Rating;
  final String? updatedAt;

  RankItem({
    this.rank = 0,
    required this.userId,
    required this.dataSource,
    required this.originalId,
    this.nickname,
    required this.totalRating,
    required this.best35Rating,
    required this.best15Rating,
    this.updatedAt,
  });

  factory RankItem.fromJson(Map<String, dynamic> json) {
    return RankItem(
      rank: json['rank'] ?? 0,
      userId: json['userId'] ?? json['user_id'] ?? '',
      dataSource: json['dataSource'] ?? json['data_source'] ?? '',
      originalId: json['originalId'] ?? json['original_id'] ?? '',
      nickname: json['nickname'],
      totalRating: json['totalRating'] ?? json['total_rating'] ?? 0,
      best35Rating: json['best35Rating'] ?? json['best35_rating'] ?? 0,
      best15Rating: json['best15Rating'] ?? json['best15_rating'] ?? 0,
      updatedAt: json['updatedAt'] ?? json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rank': rank,
      'userId': userId,
      'dataSource': dataSource,
      'originalId': originalId,
      'nickname': nickname,
      'totalRating': totalRating,
      'best35Rating': best35Rating,
      'best15Rating': best15Rating,
      'updatedAt': updatedAt,
    };
  }
}