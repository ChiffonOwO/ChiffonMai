import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../api/ApiUrls.dart';
import '../entity/KnowledgeEntity.dart';
import '../constant/CacheKeyConstant.dart';
import '../constant/CacheTimestampConstant.dart';

class KnowledgeManager {
  static final KnowledgeManager _instance = KnowledgeManager._internal();
  factory KnowledgeManager() => _instance;
  KnowledgeManager._internal();

  // 获取知识数据
  Future<KnowledgeEntity?> getKnowledgeData() async {
    // 检查缓存
    final cachedData = await _getCachedData();
    if (cachedData != null) {
      return cachedData;
    }

    // 缓存过期，从网络获取
    try {
      final knowledgeData = await _fetchKnowledgeData();
      // 保存到缓存
      await _saveToCache(knowledgeData);
      return knowledgeData;
    } catch (e) {
      print('获取知识数据失败: $e');
      return null;
    }
  }

  // 从网络获取知识数据
  Future<KnowledgeEntity> _fetchKnowledgeData() async {
    final response = await http.get(Uri.parse(ApiUrls.knowledgeApi));
    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      return KnowledgeEntity.fromJson(jsonData);
    } else {
      throw Exception('Failed to load knowledge data');
    }
  }

  // 获取缓存数据
  Future<KnowledgeEntity?> _getCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString(CacheKeyConstant.knowledgeData);
    final timestamp = prefs.getInt(CacheKeyConstant.knowledgeTimestamp);

    // 检查缓存是否存在且未过期
    if (cachedData != null && timestamp != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - timestamp < CacheTimestampConstant.knowledgeCacheMillis) {
        try {
          final jsonData = json.decode(cachedData);
          return KnowledgeEntity.fromJson(jsonData);
        } catch (e) {
          print('解析缓存数据失败: $e');
          return null;
        }
      }
    }
    return null;
  }

  // 保存数据到缓存
  Future<void> _saveToCache(KnowledgeEntity knowledgeData) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = knowledgeData.knowledgeItems?.map((item) {
      return {
        'id': item.id,
        'title': item.title,
        'category': item.category,
        'content': item.content,
        'recommendSongs': item.recommendSongs?.map((song) {
          return {
            'id': song.id,
            'level_index': song.levelIndex,
          };
        }).toList(),
      };
    }).toList();

    await prefs.setString(CacheKeyConstant.knowledgeData, json.encode(jsonData));
    await prefs.setInt(CacheKeyConstant.knowledgeTimestamp, DateTime.now().millisecondsSinceEpoch);
  }

  // 清除缓存
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(CacheKeyConstant.knowledgeData);
    await prefs.remove(CacheKeyConstant.knowledgeTimestamp);
  }

  // 强制刷新数据
  Future<KnowledgeEntity?> refreshData() async {
    await clearCache();
    return await getKnowledgeData();
  }
}