import 'dart:convert';
import 'dart:convert' show utf8;
import 'package:my_first_flutter_app/api/ApiUrls.dart';
import 'package:my_first_flutter_app/entity/SongAliasModel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class SongAliasManager {
  // 单例模式，全局唯一实例
  static final SongAliasManager instance = SongAliasManager._internal();
  SongAliasManager._internal();

  // 本地缓存的key
  static const _keyAliases = 'song_aliases';
  static const _keyLastUpdate = 'alias_last_update';

  // 内存中缓存的别名数据：key=歌曲ID(String)，value=别名列表
  Map<String, List<String>> _aliases = {};

  // 对外暴露的别名数据（只读）
  Map<String, List<String>> get aliases => _aliases;

  /// 初始化方法：APP启动时调用
  Future<void> init() async {
    // 先从本地加载缓存
    await _loadFromLocal();

    // 检查是否超过24小时未更新，超过则自动刷新
    final prefs = await SharedPreferences.getInstance();
    final lastUpdateTime = prefs.getInt(_keyLastUpdate) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    const twentyFourHours = 24 * 60 * 60 * 1000; // 24小时毫秒数

    if (now - lastUpdateTime > twentyFourHours) {
      await fetchFromApi(); // 自动刷新
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
        print('本地别名缓存解析失败：$e');
      }
    }
  }

  /// 调用第三方API获取最新别名（已适配指定API）
  Future<void> fetchFromApi() async {
    try {
      // 指定API地址
      final url = ApiUrls.SongAliasApi;
      final response = await http.get(Uri.parse(url));

      // 接口返回成功
      if (response.statusCode == 200) {
        // 确保使用正确的编码解析响应
        final responseBody = utf8.decode(response.bodyBytes);
        final Map<String, dynamic> jsonData = jsonDecode(responseBody);
        final aliasResponse = SongAliasResponse.fromJson(jsonData);

        // 只处理接口成功（code=0）的情况
        if (aliasResponse.code == 0) {
          Map<String, List<String>> newAliases = {};
          for (var song in aliasResponse.content) {
            // 歌曲ID转String作为key，适配SharedPreferences
            // 确保songId格式与maimai_music_data.json一致（字符串格式）
            String songIdKey = song.songId.toString();
            
            // 确保别名列表中的每个元素都是字符串
            List<String> aliases = song.alias.map((alias) {
              return alias;
                        }).toList();
            
            newAliases[songIdKey] = aliases;
          }

          // 更新内存数据
          _aliases = newAliases;
          print('成功加载${aliasResponse.content.length}首歌曲的别名');

          // 保存到本地缓存
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_keyAliases, jsonEncode(_aliases));
          await prefs.setInt(_keyLastUpdate, DateTime.now().millisecondsSinceEpoch);

          print('别名数据更新成功，共加载${_aliases.length}首歌曲的别名');
        } else {
          print('接口返回失败，code=${aliasResponse.code}');
        }
      } else {
        print('API请求失败，状态码=${response.statusCode}');
      }
    } catch (e) {
      // 捕获所有异常，避免崩溃，继续使用旧缓存
      print('获取别名API异常：$e');
    }
  }

  /// 手动刷新别名（供按钮点击调用）
  Future<void> refresh() async {
    await fetchFromApi();
  }

  /// 根据用户输入的别名查找对应的歌曲ID（忽略大小写）
  String? findSongIdByAlias(String input) {
    if (input.isEmpty) return null;
    final lowerInput = input.toLowerCase();

    for (final entry in _aliases.entries) {
      final songId = entry.key;
      final aliasList = entry.value;

      // 遍历别名列表，忽略大小写匹配
      if (aliasList.any((alias) => alias.toLowerCase() == lowerInput)) {
        return songId;
      }
    }
    return null; // 未找到对应歌曲ID
  }
}