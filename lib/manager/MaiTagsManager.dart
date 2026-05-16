import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:my_first_flutter_app/api/ApiUrls.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_first_flutter_app/entity/MaiTagsEntity.dart';
import '../constant/CacheKeyConstant.dart';

class MaiTagsManager {
  // 单例模式
  static final MaiTagsManager _instance = MaiTagsManager._internal();
  factory MaiTagsManager() => _instance;
  MaiTagsManager._internal();

  // API 配置
  static const String TAGS_API_URL = ApiUrls.TagDataApi;
  // static const Map<String, String> TAGS_API_HEADERS = {
  //   "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxidHBubWRmZnVpbWlra3Nydm5zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MDYwMzMxNzAsImV4cCI6MjAyMTYwOTE3MH0.rrzOisCZGz2gkp-yh61-_HDY7YqL3lTc4XsOPzuAVDU",
  //   "authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxidHBubWRmZnVpbWlra3Nydm5zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MDYwMzMxNzAsImV4cCI6MjAyMTYwOTE3MH0.rrzOisCZGz2gkp-yh61-_HDY7YqL3lTc4XsOPzuAVDU",
  //   "origin": "https://dxrating.net",
  //   "referer": "https://dxrating.net/",
  //   "x-client-info": "supabase-js-web/2.49.1",
  //   "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36 Edg/131.0.0.0",
  //   "Accept": "*/*",
  //   "Accept-Encoding": "gzip, deflate, br",
  //   "Accept-Language": "zh-CN,zh;q=0.9,en-GB;q=0.8,en-US;q=0.7,en;q=0.6"
  // };

  /**
   * 初始化标签数据
   */
  Future<void> initializeTags() async {
    try {
      // 尝试从本地缓存加载
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(CacheKeyConstant.maiTagsCache);
      
      // 移除定时策略，缓存永不过期
      bool isCacheValid = cachedData != null;
      
      if (!isCacheValid) {
        // 从网络加载
        final response = await http.get(
          Uri.parse(TAGS_API_URL),
          // headers: TAGS_API_HEADERS,
        );

        if (response.statusCode == 200) {
          // 强制使用UTF-8编码解码响应内容，避免乱码
          final mainTagString = utf8.decode(response.bodyBytes);
          
          // 更新本地缓存
          await prefs.setString(CacheKeyConstant.maiTagsCache, mainTagString);
          await prefs.setInt(CacheKeyConstant.maiTagsCacheTimestamp, DateTime.now().millisecondsSinceEpoch);
          
          debugPrint('从网络加载标签数据并更新缓存');
        } else {
          debugPrint('标签数据初始化失败，状态码: ${response.statusCode}');
        }
      } else {
        debugPrint('本地缓存有效，无需更新');
      }
    } catch (e) {
      debugPrint('标签数据初始化错误: $e');
    }
  }

  /**
   * 获取标签数据
   */
  Future<MaiTagsEntity?> getTags() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(CacheKeyConstant.maiTagsCache);
      
      if (cachedData != null) {
        Map<String, dynamic> mainTagJson = json.decode(cachedData);
        return MaiTagsEntity.fromJson(mainTagJson);
      }
      
      // 如果没有缓存，尝试初始化
      await initializeTags();
      
      // 再次尝试获取
      final updatedData = prefs.getString(CacheKeyConstant.maiTagsCache);
      if (updatedData != null) {
        Map<String, dynamic> mainTagJson = json.decode(updatedData);
        return MaiTagsEntity.fromJson(mainTagJson);
      }
      
      return null;
    } catch (e) {
      debugPrint('获取标签数据错误: $e');
      return null;
    }
  }

  /**
   * 构建 谱面标识 = 谱面ID + 谱面类型 + 谱面难度 到 标签ID列表 的映射
   */
  Future<Map<String, List<int>>> getSongIdToTagIdsMap() async {
    final maiTagsEntity = await getTags();
    if (maiTagsEntity != null) {
      return buildSongIdToTagIdsMap(maiTagsEntity);
    } else {
      return {};
    }
  }

  /**
   * 构建分组ID到分组名称的映射
   */
  Future<Map<int, String>> getGroupIdToNameMap() async {
    final maiTagsEntity = await getTags();
    if (maiTagsEntity != null) {
      Map<int, String> groupIdToNameMap = {};
      List<TagGroupItem> tagGroups = maiTagsEntity.tagGroups;
      if (tagGroups.isNotEmpty) {
        for (var group in tagGroups) {
          groupIdToNameMap[group.id] = group.localizedName.zhHans;
        }
      }
      return groupIdToNameMap;
    } else {
      return {};
    }
  }

  /**
   * 构建 标签ID → 标签名称 的映射
   */
  Future<Map<int, String>> getTagIdToNameMap() async {
    final maiTagsEntity = await getTags();
    if (maiTagsEntity != null) {
      Map<int, String> tagIdToNameMap = {};
      List<TagItem> tags = maiTagsEntity.tags;
      if (tags.isNotEmpty) {
        for (var tag in tags) {
          tagIdToNameMap[tag.id] = tag.localizedName.zhHans;
        }
      }
      return tagIdToNameMap;
    } else {
      return {};
    }
  }

  /**
   * 构建标签ID → (标签名称, 分组ID) 的映射
   */
  Future<Map<int, (String, int)>> getTagIdToInfoMap() async {
    final maiTagsEntity = await getTags();
    if (maiTagsEntity != null) {
      Map<int, (String, int)> tagIdToInfoMap = {};
      List<TagItem> tags = maiTagsEntity.tags;
      if (tags.isNotEmpty) {
        for (var tag in tags) {
          tagIdToInfoMap[tag.id] = (tag.localizedName.zhHans, tag.groupId);
        }
      }
      return tagIdToInfoMap;
    } else {
      return {};
    }
  }

  /**
   * 检查是否有缓存数据
   */
  Future<bool> hasCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString(CacheKeyConstant.maiTagsCache);
    return cachedData != null && cachedData.isNotEmpty;
  }
  
  /**
   * 手动刷新缓存
   */
  Future<void> refreshCache() async {
    try {
      // 从网络加载
      final response = await http.get(
        Uri.parse(TAGS_API_URL),
        // headers: TAGS_API_HEADERS,
      );

      if (response.statusCode == 200) {
        // 强制使用UTF-8编码解码响应内容，避免乱码
        final mainTagString = utf8.decode(response.bodyBytes);
        
        // 更新本地缓存
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(CacheKeyConstant.maiTagsCache, mainTagString);
        await prefs.setInt(CacheKeyConstant.maiTagsCacheTimestamp, DateTime.now().millisecondsSinceEpoch);
        
        debugPrint('手动刷新标签数据缓存成功');
      } else {
        debugPrint('手动刷新标签数据缓存失败，状态码: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('手动刷新标签数据缓存错误: $e');
    }
  }

  /**
   * 构建 谱面标识 = 谱面ID + 谱面类型 + 谱面难度 到 标签ID列表 的映射
   */
  Map<String, List<int>> buildSongIdToTagIdsMap(MaiTagsEntity maiTagsEntity) {
    Map<String, List<int>> songIdToTagIdsMap = {};
    List<TagSongItem> tagSongs = maiTagsEntity.tagSongs;
    for (var tagSong in tagSongs) {
      String songId = tagSong.songId;
      String sheetType = tagSong.sheetType;
      String sheetDifficulty = tagSong.sheetDifficulty;

      // 构建 谱面标识 = 谱面ID + 谱面类型 + 谱面难度
      String songKey = songId + "#" + sheetType + "#" + sheetDifficulty;
      if (!songIdToTagIdsMap.containsKey(songKey)) {
        songIdToTagIdsMap[songKey] = [];
      }
      // 向 谱面标识 对应的标签ID列表 中添加标签ID
      songIdToTagIdsMap[songKey]?.add(tagSong.tagId);
    }
    return songIdToTagIdsMap;
  }
}