import 'dart:convert' show utf8, jsonDecode, jsonEncode;
import 'package:flutter/foundation.dart';
import 'package:my_first_flutter_app/api/ApiUrls.dart';
import 'package:my_first_flutter_app/entity/SongAliasModel.dart';
import 'package:my_first_flutter_app/entity/DXRating/DXRatingSongAliasModel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_first_flutter_app/utils/ApiClient.dart';

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

    // 检查是否超过7天未更新，超过则后台自动刷新（不阻塞初始化流程）
    final prefs = await SharedPreferences.getInstance();
    final lastUpdateTime = prefs.getInt(_keyLastUpdate) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    const sevenDays = 7 * 24 * 60 * 60 * 1000;

    if (now - lastUpdateTime > sevenDays) {
      debugPrint('别名缓存已过期（超过7天），开始后台自动刷新...');
      // 不阻塞 init 完成，别名在后台异步更新
      fetchFromApi().then((_) {
        debugPrint('别名后台刷新完成');
      });
    } else {
      debugPrint(
          '别名缓存未过期，上次更新时间: ${DateTime.fromMillisecondsSinceEpoch(lastUpdateTime)}');
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

  /// 调用第三方API获取最新别名（同时获取三个API的数据并合并）
  Future<bool> fetchFromApi() async {
    try {
      // 同时调用三个API
      final futures = await Future.wait([
        _fetchFromSongAliasApi(),
        _fetchFromDXRatingSongAliasApi(),
        _fetchFromMaimaiHubAliases(),
      ]);

      // 合并三个API的数据：第一个作为基底，其余依次并入
      Map<String, List<String>> combinedAliases = {};

      // 处理第一个API的数据
      if (futures[0] != null) {
        debugPrint('SongAliasApi返回${futures[0]!.length}首歌曲的别名');
        combinedAliases.addAll(futures[0]!);
      } else {
        debugPrint('SongAliasApi返回null');
      }

      // 处理后两个API的数据，合并到已有数据中
      _mergeAliasSource(combinedAliases, futures[1], 'DXRatingSongAliasApi');
      _mergeAliasSource(combinedAliases, futures[2], 'MaimaiHubMusicAliases');

      // 只有在成功获取到新数据时才更新缓存，否则保留原有数据
      if (combinedAliases.isNotEmpty) {
        // 更新内存数据
        _aliases = combinedAliases;

        // 保存到本地缓存
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyAliases, jsonEncode(_aliases));
        await prefs.setInt(
            _keyLastUpdate, DateTime.now().millisecondsSinceEpoch);

        debugPrint('别名数据更新成功，共加载${_aliases.length}首歌曲的别名');
        return true;
      } else {
        // 如果没有获取到任何新数据，保留原有缓存
        debugPrint('未获取到新的别名数据，保留原有缓存');
        return false;
      }
    } catch (e) {
      // 捕获所有异常，避免崩溃，继续使用旧缓存
      debugPrint('获取别名API异常：$e');
      return false;
    }
  }

  /// 把一路别名数据并入 [combined]：同名歌曲合并别名列表并去重，新歌则新建条目。
  ///
  /// [source] 为 null 表示该路本次没取到数据，只记日志、不影响其它来源。
  void _mergeAliasSource(
    Map<String, List<String>> combined,
    Map<String, List<String>>? source,
    String label,
  ) {
    if (source == null) {
      debugPrint('$label返回null');
      return;
    }
    int addedCount = 0;
    int mergedCount = 0;
    source.forEach((songName, aliases) {
      final existing = combined[songName];
      if (existing != null) {
        // 合并别名列表，去重
        for (final alias in aliases) {
          if (!existing.contains(alias)) {
            existing.add(alias);
            mergedCount++;
          }
        }
      } else {
        combined[songName] = List<String>.from(aliases);
        addedCount++;
      }
    });
    debugPrint('$label新增$addedCount首歌曲，合并$mergedCount个别名到已有歌曲');
  }

  /// 从 SongAliasApi 获取别名数据
  Future<Map<String, List<String>>?> _fetchFromSongAliasApi() async {
    try {
      final url = ApiUrls.SongAliasApi;
      final response = await ApiClient.get(Uri.parse(url));

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
      final response = await ApiClient.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        debugPrint('DXRatingSongAliasApi返回数据长度: ${responseBody.length}');

        // 打印前500个字符用于调试
        if (responseBody.length > 0) {
          debugPrint(
              'DXRatingSongAliasApi返回数据预览: ${responseBody.substring(0, responseBody.length > 500 ? 500 : responseBody.length)}...');
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
              debugPrint(
                  'DXRatingSongAliasApi解析数据: songName="$songName", alias="$alias"');
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
          debugPrint(
              'DXRatingSongAliasApi返回的数据不是列表格式，类型: ${jsonData.runtimeType}');
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

  /// 从 MaimaiHub 的曲目别名接口获取别名数据
  ///
  /// 该接口按 `musicId` 返回别名，而本管理器与所有调用方都按**歌曲名**索引
  /// （调用方一律写 `aliases[song.title]`），所以要先拉一次 `/catalog/music`
  /// 建出 musicId → 曲名 的映射，再据此把别名挂到曲名上。
  ///
  /// 任何一步失败都返回 null，由 `_mergeAliasSource` 记日志后跳过，
  /// 不影响另外两路别名来源。
  Future<Map<String, List<String>>?> _fetchFromMaimaiHubAliases() async {
    try {
      // 1) 曲目目录：musicId -> title
      final catalogResp =
          await ApiClient.get(Uri.parse(ApiUrls.MaimaiHubMusicCatalogUrl));
      if (catalogResp.statusCode != 200) {
        debugPrint('MaimaiHub曲目表请求失败，状态码=${catalogResp.statusCode}');
        return null;
      }
      final dynamic catalogJson =
          jsonDecode(utf8.decode(catalogResp.bodyBytes));
      if (catalogJson is! List) {
        debugPrint('MaimaiHub曲目表格式异常，类型: ${catalogJson.runtimeType}');
        return null;
      }

      final Map<String, String> idToTitle = {};
      for (final item in catalogJson) {
        if (item is! Map) continue;
        final id = item['id'];
        final title = item['title'];
        if (id == null || title is! String || title.trim().isEmpty) continue;
        // 规范里 id 是 string | number，统一转字符串再当 key
        idToTitle[id.toString().trim()] = title.trim();
      }
      if (idToTitle.isEmpty) {
        debugPrint('MaimaiHub曲目表为空，跳过该来源');
        return null;
      }

      // 2) 别名：{ revision, aliases: [{ musicId, aliases: [...] }] }
      final aliasResp =
          await ApiClient.get(Uri.parse(ApiUrls.MaimaiHubMusicAliasesUrl));
      if (aliasResp.statusCode != 200) {
        debugPrint('MaimaiHub别名请求失败，状态码=${aliasResp.statusCode}');
        return null;
      }
      final dynamic aliasJson = jsonDecode(utf8.decode(aliasResp.bodyBytes));
      if (aliasJson is! Map<String, dynamic>) {
        debugPrint('MaimaiHub别名格式异常，类型: ${aliasJson.runtimeType}');
        return null;
      }
      final rawList = aliasJson['aliases'];
      if (rawList is! List) {
        debugPrint('MaimaiHub别名缺少 aliases 字段');
        return null;
      }

      final Map<String, List<String>> newAliases = {};
      int skippedNoTitle = 0;
      for (final entry in rawList) {
        if (entry is! Map) continue;
        final musicId = entry['musicId']?.toString().trim();
        final title = musicId == null ? null : idToTitle[musicId];
        if (title == null) {
          // musicId 在曲目表里找不到标题：没法挂到曲名上，只能跳过
          skippedNoTitle++;
          continue;
        }
        final rawAliases = entry['aliases'];
        if (rawAliases is! List) continue;

        final list = newAliases.putIfAbsent(title, () => <String>[]);
        for (final a in rawAliases) {
          if (a is! String) continue;
          final alias = a.trim();
          if (alias.isEmpty || list.contains(alias)) continue;
          list.add(alias);
        }
      }
      // 丢掉只有空别名列表的条目，避免污染合并结果
      newAliases.removeWhere((_, v) => v.isEmpty);

      debugPrint('成功从MaimaiHub别名接口加载${newAliases.length}首歌曲的别名'
          '（revision=${aliasJson['revision']}，'
          '${skippedNoTitle}条 musicId 在曲目表里找不到标题）');
      return newAliases;
    } catch (e) {
      debugPrint('获取MaimaiHub别名异常：$e');
    }
    return null;
  }

  /// 手动刷新别名（供按钮点击调用）
  Future<bool> refresh({bool forceNetwork = false}) async {
    if (!forceNetwork && await _isCacheValid()) {
      debugPrint('别名缓存有效，跳过网络刷新');
      return true;
    }
    return fetchFromApi();
  }

  Future<bool> _isCacheValid(
      {Duration maxAge = const Duration(days: 7)}) async {
    if (_aliases.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    final lastUpdateTime = prefs.getInt(_keyLastUpdate);
    if (lastUpdateTime == null) return false;
    return DateTime.now().millisecondsSinceEpoch - lastUpdateTime <=
        maxAge.inMilliseconds;
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
