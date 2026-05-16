import 'dart:convert';
import 'dart:convert' show utf8;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:my_first_flutter_app/api/ApiUrls.dart';
import 'package:my_first_flutter_app/entity/Collection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constant/CacheKeyConstant.dart';

class CollectionsManager {
  // 单例模式
  static final CollectionsManager _instance = CollectionsManager._internal();
  factory CollectionsManager() => _instance;
  CollectionsManager._internal();

  // 缓存时间戳键
  static const String _trophiesLastUpdateKey = 'trophies_collections_last_update';
  static const String _iconsLastUpdateKey = 'icons_collections_last_update';
  static const String _platesLastUpdateKey = 'plates_collections_last_update';
  static const String _framesLastUpdateKey = 'frames_collections_last_update';
  
  // API地址
  static const String _trophiesApi = ApiUrls.TrophiesCollectionApi;
  static const String _iconsApi = ApiUrls.IconsCollectionApi;
  static const String _platesApi = ApiUrls.PlatesCollectionApi;
  static const String _framesApi = ApiUrls.FramesCollectionApi;

  // 获取奖杯收藏品数据
  Future<CollectionData?> fetchTrophiesCollections() async {
    return await _fetchCollectionsWithRequired(_trophiesApi, CacheKeyConstant.trophiesCollectionsCacheData, _trophiesLastUpdateKey);
  }

  // 获取图标收藏品数据
  Future<CollectionData?> fetchIconsCollections() async {
    return await _fetchCollectionsWithRequired(_iconsApi, CacheKeyConstant.iconsCollectionsCacheData, _iconsLastUpdateKey);
  }

  // 获取铭牌收藏品数据
  Future<CollectionData?> fetchPlatesCollections() async {
    return await _fetchCollectionsWithRequired(_platesApi, CacheKeyConstant.platesCollectionsCacheData, _platesLastUpdateKey);
  }

  // 获取框架收藏品数据
  Future<CollectionData?> fetchFramesCollections() async {
    return await _fetchCollectionsWithRequired(_framesApi, CacheKeyConstant.framesCollectionsCacheData, _framesLastUpdateKey);
  }

  // 通用获取收藏品数据方法（带required参数）
  Future<CollectionData?> _fetchCollectionsWithRequired(String apiUrl, String cacheKey, String lastUpdateKey) async {
    // 检查缓存是否过期（1天）
    final bool isCacheExpired = await _isCacheExpired(lastUpdateKey);
    
    // 如果缓存未过期，直接返回缓存数据
    if (!isCacheExpired && await hasCachedData(cacheKey)) {
      return await _getCachedCollections(cacheKey);
    }
    
    try {
      // 执行两次查询：required=false 和 required=true
      final CollectionData? dataFalse = await _fetchCollections(apiUrl, false);
      final CollectionData? dataTrue = await _fetchCollections(apiUrl, true);
      
      // 合并结果
      final CollectionData mergedData = _mergeCollectionData(dataFalse, dataTrue);
      
      // 保存到缓存
      await _saveToCache(mergedData, cacheKey, lastUpdateKey);
      
      // 输出收藏品数量
      final int trophiesCount = mergedData.trophies?.length ?? 0;
      final int iconsCount = mergedData.icons?.length ?? 0;
      final int platesCount = mergedData.plates?.length ?? 0;
      final int framesCount = mergedData.frames?.length ?? 0;
      
      debugPrint('成功从 API 获取收藏品数据: 称号 $trophiesCount 个, 头像 $iconsCount 个, 姓名框 $platesCount 个, 背景 $framesCount 个');
      return mergedData;
    } catch (e) {
      debugPrint('获取收藏品数据时出错: $e');
      // 尝试从缓存获取
      return await _getCachedCollections(cacheKey);
    }
  }

  // 执行单次API查询
  Future<CollectionData?> _fetchCollections(String apiUrl, bool required) async {
    try {
      // 构建带参数的URL
      final Uri uri = Uri.parse(apiUrl).replace(
        queryParameters: {'required': required.toString()}
      );
      
      // 发送 GET 请求
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        // 打印响应头，查看 Content-Type
        debugPrint('API 响应头: ${response.headers}');
        
        // 尝试使用 UTF-8 编码解析响应
        String responseBody;
        try {
          responseBody = utf8.decode(response.bodyBytes);
        } catch (e) {
          // 如果 UTF-8 解析失败，尝试使用 Latin1 编码
          debugPrint('UTF-8 解析失败，尝试使用 Latin1 编码: $e');
          responseBody = response.body;
        }
        
        // 打印响应体的前 200 个字符，检查是否有乱码
        debugPrint('API 响应体前 200 个字符: ${responseBody.substring(0, responseBody.length > 200 ? 200 : responseBody.length)}');
        
        // 解析 JSON 数据
        final dynamic jsonData = json.decode(responseBody);
        
        // 转换为 CollectionData 对象
        final CollectionData collectionData = CollectionData.fromJson(jsonData);
        
        // 打印解析后的数据，检查是否有乱码
        if (collectionData.trophies != null && collectionData.trophies!.isNotEmpty) {
          debugPrint('解析后的数据 - 第一个奖杯名称: ${collectionData.trophies![0].name}');
        }
        if (collectionData.icons != null && collectionData.icons!.isNotEmpty) {
          debugPrint('解析后的数据 - 第一个图标名称: ${collectionData.icons![0].name}');
        }
        if (collectionData.plates != null && collectionData.plates!.isNotEmpty) {
          debugPrint('解析后的数据 - 第一个姓名框名称: ${collectionData.plates![0].name}');
        }
        if (collectionData.frames != null && collectionData.frames!.isNotEmpty) {
          debugPrint('解析后的数据 - 第一个背景名称: ${collectionData.frames![0].name}');
        }
        
        return collectionData;
      } else {
        debugPrint('API 请求失败，状态码: ${response.statusCode}, required=$required');
        return null;
      }
    } catch (e) {
      debugPrint('获取收藏品数据时出错 (required=$required): $e');
      return null;
    }
  }

  // 合并两个CollectionData对象
  CollectionData _mergeCollectionData(CollectionData? data1, CollectionData? data2) {
    // 合并奖杯并去重
    final List<Collection> mergedTrophies = _mergeAndDeduplicate(data1?.trophies, data2?.trophies);
    
    // 合并图标并去重
    final List<Collection> mergedIcons = _mergeAndDeduplicate(data1?.icons, data2?.icons);
    
    // 合并铭牌并去重
    final List<Collection> mergedPlates = _mergeAndDeduplicate(data1?.plates, data2?.plates);
    
    // 合并框架并去重
    final List<Collection> mergedFrames = _mergeAndDeduplicate(data1?.frames, data2?.frames);
    
    return CollectionData(
      trophies: mergedTrophies,
      icons: mergedIcons,
      plates: mergedPlates,
      frames: mergedFrames,
    );
  }
  
  // 合并并去重收藏品列表，优先保留带 required 信息的对象
  List<Collection> _mergeAndDeduplicate(List<Collection>? list1, List<Collection>? list2) {
    final Map<int, Collection> collectionMap = {};
    
    // 先处理第一个列表（通常是不带 required 信息的）
    if (list1 != null) {
      for (final collection in list1) {
        collectionMap[collection.id] = collection;
      }
    }
    
    // 再处理第二个列表（通常是带 required 信息的），覆盖相同 ID 的对象
    if (list2 != null) {
      for (final collection in list2) {
        collectionMap[collection.id] = collection;
      }
    }
    
    return collectionMap.values.toList();
  }

  // 检查缓存是否过期（1天）
  Future<bool> _isCacheExpired(String lastUpdateKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdateTime = prefs.getInt(lastUpdateKey);
      
      if (lastUpdateTime == null) {
        return true; // 没有缓存时间，视为过期
      }
      
      final now = DateTime.now().millisecondsSinceEpoch;
      const oneDay = 24 * 60 * 60 * 1000; // 1天的毫秒数
      
      return now - lastUpdateTime > oneDay;
    } catch (e) {
      debugPrint('检查缓存过期时出错: $e');
      return true; // 出错时视为过期
    }
  }

  // 从缓存获取收藏品数据
  Future<CollectionData?> _getCachedCollections(String cacheKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(cacheKey);
      
      if (jsonString != null) {
        try {
          final dynamic jsonData = json.decode(jsonString);
          
          // 处理不同格式的缓存数据
          if (jsonData is Map<String, dynamic>) {
            // 新格式：直接是CollectionData的Map
            final CollectionData collections = CollectionData.fromJson(jsonData);
            // 输出收藏品数量
            final int trophiesCount = collections.trophies?.length ?? 0;
            final int iconsCount = collections.icons?.length ?? 0;
            final int platesCount = collections.plates?.length ?? 0;
            final int framesCount = collections.frames?.length ?? 0;
            debugPrint('从缓存获取收藏品数据 (Map格式): 称号 $trophiesCount 个, 头像 $iconsCount 个, 姓名框 $platesCount 个, 背景 $framesCount 个');
            return collections;
          } else if (jsonData is List) {
            // 旧格式：是Collection的List
            // 转换为新格式
            final List<Collection> collectionList = jsonData.map((item) => Collection.fromJson(item)).toList();
            // 根据缓存键确定类型
            String collectionType = '';
            if (cacheKey == CacheKeyConstant.trophiesCollectionsCacheData) {
              collectionType = 'trophies';
            } else if (cacheKey == CacheKeyConstant.iconsCollectionsCacheData) {
              collectionType = 'icons';
            } else if (cacheKey == CacheKeyConstant.platesCollectionsCacheData) {
              collectionType = 'plates';
            } else if (cacheKey == CacheKeyConstant.framesCollectionsCacheData) {
              collectionType = 'frames';
            }
            
            // 创建新格式的CollectionData
            CollectionData collections;
            switch (collectionType) {
              case 'trophies':
                collections = CollectionData(trophies: collectionList);
                break;
              case 'icons':
                collections = CollectionData(trophies: [], icons: collectionList);
                break;
              case 'plates':
                collections = CollectionData(trophies: [], plates: collectionList);
                break;
              case 'frames':
                collections = CollectionData(trophies: [], frames: collectionList);
                break;
              default:
                collections = CollectionData(trophies: []);
            }
            
            debugPrint('从缓存获取收藏品数据 (List格式，已转换)');
            return collections;
          } else {
            debugPrint('缓存数据格式不正确');
            return null;
          }
        } catch (jsonError) {
          debugPrint('解析缓存数据时出错: $jsonError');
          // 清除损坏的缓存数据
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove(cacheKey);
            debugPrint('已清除损坏的缓存数据');
          } catch (clearError) {
            debugPrint('清除损坏缓存时出错: $clearError');
          }
          return null;
        }
      }
      return null;
    } catch (e) {
      debugPrint('从缓存获取收藏品数据时出错: $e');
      // 尝试清除旧的缓存数据
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(cacheKey);
        debugPrint('已清除旧的缓存数据');
      } catch (clearError) {
        debugPrint('清除旧缓存时出错: $clearError');
      }
      return null;
    }
  }

  // 保存数据到缓存
  Future<void> _saveToCache(CollectionData collections, String cacheKey, String lastUpdateKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(collections.toJson());
      await prefs.setString(cacheKey, jsonString);
      await prefs.setInt(lastUpdateKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('保存收藏品数据到缓存时出错: $e');
    }
  }

  // 检查是否有缓存数据
  Future<bool> hasCachedData(String cacheKey) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(cacheKey);
    return jsonString != null && jsonString.isNotEmpty;
  }

  // 获取最后更新时间
  Future<int?> getLastUpdateTime(String lastUpdateKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(lastUpdateKey);
    } catch (e) {
      debugPrint('获取最后更新时间时出错: $e');
      return null;
    }
  }

  // 清除缓存
  Future<void> clearCache(String cacheKey, String lastUpdateKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(cacheKey);
      await prefs.remove(lastUpdateKey);
    } catch (e) {
      debugPrint('清除收藏品数据缓存时出错: $e');
    }
  }

  // 清除所有缓存
  Future<void> clearAllCache() async {
    await clearCache(CacheKeyConstant.trophiesCollectionsCacheData, _trophiesLastUpdateKey);
    await clearCache(CacheKeyConstant.iconsCollectionsCacheData, _iconsLastUpdateKey);
    await clearCache(CacheKeyConstant.platesCollectionsCacheData, _platesLastUpdateKey);
    await clearCache(CacheKeyConstant.framesCollectionsCacheData, _framesLastUpdateKey);
  }

  // 手动刷新所有数据
  Future<void> refreshAllCollections() async {
    await fetchTrophiesCollections();
    await fetchIconsCollections();
    await fetchPlatesCollections();
    await fetchFramesCollections();
  }
}