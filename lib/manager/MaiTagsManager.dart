import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:my_first_flutter_app/entity/MaiTagsEntity.dart';

class MaiTagsManager {
  // 单例模式
  static final MaiTagsManager _instance = MaiTagsManager._internal();
  factory MaiTagsManager() => _instance;
  MaiTagsManager._internal();

  // API 配置
  static const String TAGS_API_URL = "https://derrakuma.dxrating.net/functions/v1/combined-tags";
  static const Map<String, String> TAGS_API_HEADERS = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxidHBubWRmZnVpbWlra3Nydm5zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MDYwMzMxNzAsImV4cCI6MjAyMTYwOTE3MH0.rrzOisCZGz2gkp-yh61-_HDY7YqL3lTc4XsOPzuAVDU",
    "authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxidHBubWRmZnVpbWlra3Nydm5zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MDYwMzMxNzAsImV4cCI6MjAyMTYwOTE3MH0.rrzOisCZGz2gkp-yh61-_HDY7YqL3lTc4XsOPzuAVDU",
    "origin": "https://dxrating.net",
    "referer": "https://dxrating.net/",
    "x-client-info": "supabase-js-web/2.49.1",
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36 Edg/131.0.0.0",
    "Accept": "*/*",
    "Accept-Encoding": "gzip, deflate, br",
    "Accept-Language": "zh-CN,zh;q=0.9,en-GB;q=0.8,en-US;q=0.7,en;q=0.6"
  };

  // 缓存变量
  MaiTagsEntity? _cachedMaiTagsEntity;
  Map<String, List<int>>? _cachedSongIdToTagIdsMap;
  Map<int, String>? _cachedGroupIdToNameMap;
  Map<int, (String, int)>? _cachedTagIdToInfoMap;
  bool _tagsLoaded = false;

  /**
   * 初始化标签数据
   */
  Future<void> initializeTags() async {
    try {
      // 发送 API 请求
      final response = await http.post(
        Uri.parse(TAGS_API_URL),
        headers: TAGS_API_HEADERS,
        body: [],
      );

      if (response.statusCode == 200) {
        final mainTagString = response.body;
        // 解析为最外层Map
        Map<String, dynamic> mainTagJson = json.decode(mainTagString);
        // 解析最外层的实体：MaiTagEntity
        _cachedMaiTagsEntity = MaiTagsEntity.fromJson(mainTagJson);
        // 清除其他缓存，确保下次使用新数据
        _cachedSongIdToTagIdsMap = null;
        _cachedGroupIdToNameMap = null;
        _cachedTagIdToInfoMap = null;
        _tagsLoaded = true;
        print('标签数据初始化成功');
      } else {
        print('标签数据初始化失败，状态码: ${response.statusCode}');
      }
    } catch (e) {
      print('标签数据初始化网络错误: $e');
    }
  }

  /**
   * 获取标签数据
   */
  Future<MaiTagsEntity?> getTags() async {
    if (!_tagsLoaded) {
      await initializeTags();
    }
    return _cachedMaiTagsEntity;
  }

  /**
   * 构建 谱面标识 = 谱面ID + 谱面类型 + 谱面难度 到 标签ID列表 的映射
   */
  Future<Map<String, List<int>>> getSongIdToTagIdsMap() async {
    if (_cachedSongIdToTagIdsMap == null) {
      final maiTagsEntity = await getTags();
      if (maiTagsEntity != null) {
        _cachedSongIdToTagIdsMap = buildSongIdToTagIdsMap(maiTagsEntity);
      } else {
        _cachedSongIdToTagIdsMap = {};
      }
    }
    return _cachedSongIdToTagIdsMap!;
  }

  /**
   * 构建分组ID到分组名称的映射
   */
  Future<Map<int, String>> getGroupIdToNameMap() async {
    if (_cachedGroupIdToNameMap == null) {
      final maiTagsEntity = await getTags();
      if (maiTagsEntity != null) {
        _cachedGroupIdToNameMap = {};
        List<TagGroupItem> tagGroups = maiTagsEntity.tagGroups;
        if (tagGroups.isNotEmpty) {
          for (var group in tagGroups) {
            _cachedGroupIdToNameMap![group.id] = group.localizedName.zhHans;
          }
        }
      } else {
        _cachedGroupIdToNameMap = {};
      }
    }
    return _cachedGroupIdToNameMap!;
  }

  /**
   * 构建标签ID → (标签名称, 分组ID) 的映射
   */
  Future<Map<int, (String, int)>> getTagIdToInfoMap() async {
    if (_cachedTagIdToInfoMap == null) {
      final maiTagsEntity = await getTags();
      if (maiTagsEntity != null) {
        _cachedTagIdToInfoMap = {};
        List<TagItem> tags = maiTagsEntity.tags;
        if (tags.isNotEmpty) {
          for (var tag in tags) {
            _cachedTagIdToInfoMap![tag.id] = (tag.localizedName.zhHans, tag.groupId);
          }
        }
      } else {
        _cachedTagIdToInfoMap = {};
      }
    }
    return _cachedTagIdToInfoMap!;
  }

  /**
   * 检查是否有缓存数据
   */
  bool hasCachedData() {
    return _tagsLoaded && _cachedMaiTagsEntity != null;
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