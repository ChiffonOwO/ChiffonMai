import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../api/ApiUrls.dart';
import '../../constant/CacheKeyConstant.dart';
import '../../entity/Union/UnionSong.dart';
import 'package:my_first_flutter_app/utils/ApiClient.dart';

class UnionUniManager {
  static final UnionUniManager _instance = UnionUniManager._internal();
  factory UnionUniManager() => _instance;
  UnionUniManager._internal();

  List<SongInfo>? _cachedList;
  Map<String, SongInfo>? _lookupById;

  /// 获取缓存的 union uni 数据（按歌曲 ID 查找）
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

  /// 从 API 获取并缓存
  Future<bool> fetchAndCache() async {
    try {
      debugPrint('[UnionUniManager] 从 union uni API 获取歌曲元数据...');
      final response = await ApiClient.get(Uri.parse(ApiUrls.UnionUniApi));
      if (response.statusCode != 200) {
        debugPrint('[UnionUniManager] API 请求失败，状态码: ${response.statusCode}');
        return false;
      }

      // 在后台 isolate 中解析
      final list = await compute((String body) {
        return SongInfo.parseResponse(body);
      }, response.body);

      _cachedList = list;
      _lookupById = {for (final s in list) s.id.toString(): s};
      debugPrint('[UnionUniManager] 成功获取 ${list.length} 条 union uni 数据');

      // 非阻塞保存缓存
      _saveToCache(list);

      return true;
    } catch (e) {
      debugPrint('[UnionUniManager] 获取 union uni 数据异常: $e');
      return false;
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(CacheKeyConstant.unionUniCache);
      if (cached != null && cached.isNotEmpty) {
        final list = await compute((String jsonStr) {
          final List<dynamic> jsonList = json.decode(jsonStr);
          return jsonList
              .map((e) => SongInfo.fromJson(e as Map<String, dynamic>))
              .toList();
        }, cached);
        _cachedList = list;
        _lookupById = {for (final s in list) s.id.toString(): s};
        debugPrint('[UnionUniManager] 从缓存加载 ${list.length} 条 union uni 数据');
      }
    } catch (e) {
      debugPrint('[UnionUniManager] 加载缓存失败: $e');
    }
  }

  void _saveToCache(List<SongInfo> list) {
    compute((List<SongInfo> data) {
      return json.encode(data.map((s) => s.toJson()).toList());
    }, list).then((encoded) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(CacheKeyConstant.unionUniCache, encoded);
        debugPrint('[UnionUniManager] 缓存已保存');
      } catch (e) {
        debugPrint('[UnionUniManager] 保存缓存失败: $e');
      }
    });
  }
}
