import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../api/ApiUrls.dart';
import '../../constant/CacheKeyConstant.dart';
import '../../entity/Union/UnionSong.dart';
import 'package:my_first_flutter_app/utils/ApiClient.dart';

class UnionManager {
  static final UnionManager _instance = UnionManager._internal();
  factory UnionManager() => _instance;
  UnionManager._internal();

  Map<String, SongInfo>? _lookupById;

  /// 获取缓存的 union 元数据（按歌曲 ID 查找）
  Future<Map<String, SongInfo>> getLookup() async {
    if (_lookupById != null) return _lookupById!;
    await _loadFromCache();
    if (_lookupById != null) return _lookupById!;
    return {};
  }

  /// 按歌曲 ID 查找单条记录
  Future<SongInfo?> lookupById(String songId) async {
    final lookup = await getLookup();
    return lookup[songId];
  }

  Future<bool> isCacheValid({Duration maxAge = const Duration(days: 1)}) async {
    if (_lookupById != null && _lookupById!.isNotEmpty) return true;
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(CacheKeyConstant.unionCacheTimestamp);
    final cached = prefs.getString(CacheKeyConstant.unionCache);
    if (timestamp == null || cached == null || cached.isEmpty) return false;
    return DateTime.now().millisecondsSinceEpoch - timestamp <=
        maxAge.inMilliseconds;
  }

  /// 从 API 获取并缓存
  Future<bool> fetchAndCache({bool forceNetwork = false}) async {
    if (!forceNetwork && await isCacheValid()) {
      debugPrint('[UnionManager] union 缓存有效，跳过网络刷新');
      return true;
    }

    try {
      debugPrint('[UnionManager] 从 union API 获取歌曲元数据...');
      final response = await ApiClient.get(Uri.parse(ApiUrls.UnionApi));
      if (response.statusCode != 200) {
        debugPrint('[UnionManager] API 请求失败，状态码: ${response.statusCode}');
        return false;
      }

      // 在后台 isolate 中解析
      final list = await compute((String body) {
        return SongInfo.parseResponse(body);
      }, response.body);

      debugPrint('[UnionManager] 成功获取 ${list.length} 条 union 数据');

      await _saveToCache(list);

      return true;
    } catch (e) {
      debugPrint('[UnionManager] 获取 union 数据异常: $e');
      return false;
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(CacheKeyConstant.unionCache);
      if (cached != null && cached.isNotEmpty) {
        final list = await compute((String jsonStr) {
          final List<dynamic> jsonList = json.decode(jsonStr);
          return jsonList
              .map((e) => SongInfo.fromJson(e as Map<String, dynamic>))
              .toList();
        }, cached);
        _lookupById = {for (final s in list) s.id.toString(): s};
        debugPrint('[UnionManager] 从缓存加载 ${list.length} 条 union 数据');
      }
    } catch (e) {
      debugPrint('[UnionManager] 加载缓存失败: $e');
    }
  }

  Future<void> _saveToCache(List<SongInfo> list) async {
    try {
      final encoded = await compute((List<SongInfo> data) {
        return json.encode(data.map((s) => s.toJson()).toList());
      }, list);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(CacheKeyConstant.unionCache, encoded);
      await prefs.setInt(
        CacheKeyConstant.unionCacheTimestamp,
        DateTime.now().millisecondsSinceEpoch,
      );
      debugPrint('[UnionManager] 缓存已保存');
    } catch (e) {
      debugPrint('[UnionManager] 保存缓存时异常: $e');
    }
  }
}