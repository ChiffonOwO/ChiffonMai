import 'dart:convert' show utf8, jsonDecode, jsonEncode;
import 'package:flutter/foundation.dart';
import 'package:my_first_flutter_app/api/ApiUrls.dart';
import 'package:my_first_flutter_app/entity/SongAliasModel.dart';
import 'package:my_first_flutter_app/entity/DXRatingSongAliasModel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class SongAliasManager {
  // 单例模式，全局唯一实例
  static final SongAliasManager instance = SongAliasManager._internal();
  SongAliasManager._internal();

  // 本地缓存的key
  static const _keyAliases = 'song_aliases';
  static const _keyLastUpdate = 'alias_last_update';

  // 内存中缓存的别名数据：key=歌曲名(String)，value=别名列表
  Map<String, List<String>> _aliases = {};

  // 对外暴露的别名数据（只读）
  Map<String, List<String>> get aliases => _aliases;

  /// 初始化方法：APP启动时调用
  Future<void> init() async {
    // 先从本地加载缓存
    await _loadFromLocal();
    debugPrint('SongAliasManager初始化完成，当前缓存${_aliases.length}首歌曲的别名');

    // 检查是否超过24小时未更新，超过则自动刷新
    final prefs = await SharedPreferences.getInstance();
    final lastUpdateTime = prefs.getInt(_keyLastUpdate) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    const twentyFourHours = 24 * 60 * 60 * 1000; // 24小时毫秒数

    if (now - lastUpdateTime > twentyFourHours) {
      debugPrint('别名缓存已过期，开始自动刷新...');
      await fetchFromApi(); // 自动刷新
    } else {
      debugPrint('别名缓存未过期，上次更新时间: ${DateTime.fromMillisecondsSinceEpoch(lastUpdateTime)}');
    }
  }

  /// 从本地缓存加载别名数据
  Future<void> _loadFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyAliases);

    if (jsonString != null) {
      try {
        final Map<String, dynamic> map = jsonDecode(jsonString);
        _aliases = map.map((key, value) {
          return MapEntry(key, List<String>.from(value));
        });
      } catch (e) {
        // 缓存解析失败则清空，避免脏数据
        _aliases = {};
        debugPrint('本地别名缓存解析失败：$e');
      }
    }
  }

  /// 调用第三方API获取最新别名（同时获取两个API的数据并合并）
  Future<void> fetchFromApi() async {
    try {
      // 同时调用两个API
      final futures = await Future.wait([
        _fetchFromSongAliasApi(),
        _fetchFromDXRatingSongAliasApi(),
      ]);

      // 合并两个API的数据
      Map<String, List<String>> combinedAliases = {};

      // 处理第一个API的数据
      if (futures[0] != null) {
        debugPrint('SongAliasApi返回${futures[0]!.length}首歌曲的别名');
        combinedAliases.addAll(futures[0]!);
      } else {
        debugPrint('SongAliasApi返回null');
      }

      // 处理第二个API的数据，合并到已有数据中
      if (futures[1] != null) {
        debugPrint('DXRatingSongAliasApi返回${futures[1]!.length}首歌曲的别名');
        int addedCount = 0;
        int mergedCount = 0;
        futures[1]!.forEach((songName, aliases) {
          if (combinedAliases.containsKey(songName)) {
            // 合并别名列表，去重
            final existingAliases = combinedAliases[songName]!;
            for (var alias in aliases) {
              if (!existingAliases.contains(alias)) {
                existingAliases.add(alias);
                mergedCount++;
              }
            }
          } else {
            combinedAliases[songName] = aliases;
            addedCount++;
          }
        });
        debugPrint('DXRatingSongAliasApi新增$addedCount首歌曲，合并$mergedCount个别名到已有歌曲');
      } else {
        debugPrint('DXRatingSongAliasApi返回null');
      }

      // 只有在成功获取到新数据时才更新缓存，否则保留原有数据
      if (combinedAliases.isNotEmpty) {
        // 更新内存数据
        _aliases = combinedAliases;

        // 保存到本地缓存
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyAliases, jsonEncode(_aliases));
        await prefs.setInt(_keyLastUpdate, DateTime.now().millisecondsSinceEpoch);

        debugPrint('别名数据更新成功，共加载${_aliases.length}首歌曲的别名');
      } else {
        // 如果没有获取到任何新数据，保留原有缓存
        debugPrint('未获取到新的别名数据，保留原有缓存');
      }
    } catch (e) {
      // 捕获所有异常，避免崩溃，继续使用旧缓存
      debugPrint('获取别名API异常：$e');
    }
  }

  /// 从 SongAliasApi 获取别名数据
  Future<Map<String, List<String>>?> _fetchFromSongAliasApi() async {
    try {
      final url = ApiUrls.SongAliasApi;
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final Map<String, dynamic> jsonData = jsonDecode(responseBody);
        final aliasResponse = SongAliasResponse.fromJson(jsonData);

        if (aliasResponse.code == 0) {
          Map<String, List<String>> newAliases = {};
          for (var song in aliasResponse.content) {
            String songName = song.name;
            
            List<String> aliases = song.alias.map((alias) => alias).toList();
            
            newAliases[songName] = aliases;
          }
          debugPrint('成功从SongAliasApi加载${aliasResponse.content.length}首歌曲的别名');
          return newAliases;
        } else {
          debugPrint('SongAliasApi接口返回失败，code=${aliasResponse.code}');
        }
      } else {
        debugPrint('SongAliasApi请求失败，状态码=${response.statusCode}');
      }
    } catch (e) {
      debugPrint('获取SongAliasApi异常：$e');
    }
    return null;
  }

  /// 从 DXRatingSongAliasApi 获取别名数据
  Future<Map<String, List<String>>?> _fetchFromDXRatingSongAliasApi() async {
    try {
      final url = ApiUrls.DXRatingSongAliasApi;
      debugPrint('开始请求DXRatingSongAliasApi: $url');
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        debugPrint('DXRatingSongAliasApi返回数据长度: ${responseBody.length}');
        
        // 打印前500个字符用于调试
        if (responseBody.length > 0) {
          debugPrint('DXRatingSongAliasApi返回数据预览: ${responseBody.substring(0, responseBody.length > 500 ? 500 : responseBody.length)}...');
        }
        
        final dynamic jsonData = jsonDecode(responseBody);
        
        // 检查数据格式
        if (jsonData is List) {
          debugPrint('DXRatingSongAliasApi返回的是列表，长度: ${jsonData.length}');
          final aliasModel = DXRatingSongAliasModel.fromJson(jsonData);

          Map<String, List<String>> newAliases = {};
          for (var song in aliasModel.data) {
            // songId 实际上是歌曲名，name 才是别名
            String songName = song.songId;
            String alias = song.name;
            
            // 调试：打印前几个数据
            if (newAliases.length < 3) {
              debugPrint('DXRatingSongAliasApi解析数据: songName="$songName", alias="$alias"');
            }
            
            // 将同一首歌的多个别名收集到一起
            if (newAliases.containsKey(songName)) {
              // 如果歌曲已存在，添加别名（去重）
              if (!newAliases[songName]!.contains(alias)) {
                newAliases[songName]!.add(alias);
              }
            } else {
              // 如果歌曲不存在，创建新列表
              newAliases[songName] = [alias];
            }
          }
          debugPrint('成功从DXRatingSongAliasApi加载${newAliases.length}首歌曲的别名');
          return newAliases;
        } else {
          debugPrint('DXRatingSongAliasApi返回的数据不是列表格式，类型: ${jsonData.runtimeType}');
          return null;
        }
      } else {
        debugPrint('DXRatingSongAliasApi请求失败，状态码=${response.statusCode}');
      }
    } catch (e) {
      debugPrint('获取DXRatingSongAliasApi异常：$e');
    }
    return null;
  }

  /// 手动刷新别名（供按钮点击调用）
  Future<void> refresh() async {
    await fetchFromApi();
  }

  /// 根据用户输入的别名查找对应的歌曲名（忽略大小写）
  String? findSongNameByAlias(String input) {
    if (input.isEmpty) return null;
    final lowerInput = input.toLowerCase();

    for (final entry in _aliases.entries) {
      final songName = entry.key;
      final aliasList = entry.value;

      // 遍历别名列表，忽略大小写匹配
      if (aliasList.any((alias) => alias.toLowerCase() == lowerInput)) {
        return songName;
      }
    }
    return null; // 未找到对应歌曲名
  }

  /// 根据用户输入的歌曲名查找对应的别名列表
  List<String>? findAliasesBySongName(String songName) {
    return _aliases[songName];
  }
}