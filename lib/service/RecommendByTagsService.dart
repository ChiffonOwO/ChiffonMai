// ignore_for_file: slash_for_doc_comments

import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:my_first_flutter_app/entity/MaiTagsEntity.dart';
import 'package:my_first_flutter_app/entity/MaimaiMusicDataEntity.dart';
import 'package:my_first_flutter_app/entity/RecommendationResult.dart';
import 'package:my_first_flutter_app/entity/RecordItem.dart';
import 'package:my_first_flutter_app/entity/UserPlayDataEntity.dart';

class RecommendByTagsService {
  static const int MAX_LIMIT = 70; // 最大推荐数
  static const int RA_RANGE_LIMIT = 20; // Rating极差上限
  static const String USER_PLAY_DATA_FILE_PATH = 'assets/userPlayData.json';
  static const String MAIN_TAG_FILE_PATH = 'assets/mainTags.json';
  static const String MAIMAI_MUSIC_DATA_FILE_PATH =
      'assets/maimai_music_data.json';
  static const Map<String, String> TYPE_MAP = {
    "SD": "std",
    "DX": "dx",
  };
  static const Map<int, String> LEVEL_INDEX_MAP = {
    0: "basic",
    1: "advanced",
    2: "expert",
    3: "master",
    4: "remaster",
  };
}

/**
 * 获取玩家游玩记录中的Records数组
 * @return Records数组（包含玩家游玩的所有谱面记录）
 */
Future<List<RecordItem>> getUserPlayDataRecords() async {
  try {
    // 读取玩家游玩记录 JSON 文件
    String playDataPath = RecommendByTagsService.USER_PLAY_DATA_FILE_PATH;
    String playDataString = await rootBundle.loadString(playDataPath);

    // 解析为最外层Map
    Map<String, dynamic> playDataJson = json.decode(playDataString);

    // 解析最外层的实体：UserPlayDataEntity
    UserPlayDataEntity userPlayData = UserPlayDataEntity.fromJson(playDataJson);

    // 提取Records数组
    List<RecordItem> records = userPlayData.records;

    return records;
  } catch (e) {
    print('json解析失败: $e');
    return [];
  }
}

/**
 * 筛选单曲Rating前MAX_LIMIT(70)个且Rating极差≤20的谱面数据
 * @param records 玩家游玩记录中的Records数组
 * @return 筛选后的 Record 列表（包含至多70个Rating最高的谱面，且Rating极差≤20）
 */
List<RecordItem> filterRecordsByRating(List<RecordItem> records) {
  // 对Records数组按Rating降序排序
  records.sort((a, b) => b.ra.compareTo(a.ra));

  // 找出最高的单曲Rating，并算出Rating极差的下限
  int maxRa = records[0].ra;
  int minRa = maxRa - RecommendByTagsService.RA_RANGE_LIMIT;

  // 筛选Rating前MAX_LIMIT(70)个且Rating极差≤20的谱面 -> filterRecords
  List<RecordItem> filteredRecords = [];
  for (var record in records) {
    if (record.ra >= minRa && record.ra <= maxRa) {
      filteredRecords.add(record);
    }
    if (filteredRecords.length >= RecommendByTagsService.MAX_LIMIT) {
      break;
    }
  }
  return filteredRecords;
}

/**
 * 按分组统计筛选后谱面中各标签的出现次数
 * @param filteredRecords 筛选后的 Record 列表（包含至多70个Rating最高的谱面，且Rating极差≤20）
 * @return 按分组统计的标签出现次数Map（键：分组名称，值：该分组下各标签的出现次数Map）
 */
Future<Map<String, Map<String, int>>> countTagsByGroup(
    List<RecordItem> filteredRecords) async {
  // 读取主要标签 JSON 文件
  String mainTagPath = RecommendByTagsService.MAIN_TAG_FILE_PATH;
  String mainTagString = await rootBundle.loadString(mainTagPath);

  // 解析为最外层Map
  Map<String, dynamic> mainTagJson = json.decode(mainTagString);

  // 解析最外层的实体：MaiTagEntity
  MaiTagsEntity MaiTagEntity = MaiTagsEntity.fromJson(mainTagJson);

  // 第一步：构建分组ID到分组名称的映射，如 1 -> 配置
  Map<int, String> groupIdToNameMap = {};
  List<TagGroupItem> tagGroups = MaiTagEntity.tagGroups;
  if (tagGroups.isNotEmpty) {
    for (var group in tagGroups) {
      groupIdToNameMap[group.id] = group.localizedName.zhHans;
    }
  } else {
    print('MaiTagEntity.tagGroups 为空');
    return {};
  }

  // 第二步：构建标签ID → (标签名称, 分组ID) 的映射, 如 22 -> (高物量, 3)
  Map<int, (String, int)> tagIdToInfoMap = {};
  List<TagItem> tags = MaiTagEntity.tags;
  if (tags.isNotEmpty) {
    for (var tag in tags) {
      tagIdToInfoMap[tag.id] = (tag.localizedName.zhHans, tag.groupId);
    }
  } else {
    print('MaiTagEntity.tags 为空');
    return {};
  }

  // 第三步：构建 谱面标识 → 标签ID列表 的映射
  Map<String, List<int>> songIdToTagIdsMap = {};
  List<TagSongItem> tagSongs = MaiTagEntity.tagSongs;
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

  // 第四步：遍历筛选后的RA谱面，按分组统计标签出现次数
  // 分组名 → (标签名 → 出现次数)
  Map<String, Map<String, int>> groupTagCountMap = {};
  // 统计一次谱面的标签出现次数会增加其所属分组的对应标签的出现次数，所以设定一个Set防止多次统计
  Set<String> processedSongKeys = {};
  for (var record in filteredRecords) {
    // 构建谱面标识，注意type和难度需要相关映射，两个数据源的属性值不同
    String songKey = record.title +
        "#" +
        RecommendByTagsService.TYPE_MAP[record.type]! +
        "#" +
        RecommendByTagsService.LEVEL_INDEX_MAP[record.levelIndex]!;
    // 如果该谱面已被处理过，则跳过
    if (processedSongKeys.contains(songKey)) {
      continue;
    }
    processedSongKeys.add(songKey);

    //获取该谱面的所有标签ID
    List<int>? tagIds = songIdToTagIdsMap[songKey] ?? [];
    String tagName = "";
    int groupId = 0;
    for (var tagId in tagIds) {
      final tagInfo = tagIdToInfoMap[tagId];
      if (tagInfo != null) {
        // 解构提取 tagName 和 groupId
        (tagName, groupId) = tagInfo;
      }
      // 获取分组名称
      String groupName = groupIdToNameMap[groupId]!;

      // 如果目标分组不存在，则初始化分组的标签统计Map
      if (!groupTagCountMap.containsKey(groupName)) {
        groupTagCountMap[groupName] = {};
      }

      Map<String, int> tagCountMap = groupTagCountMap[groupName]!;
      // 如果标签不存在，则初始化
      if (!tagCountMap.containsKey(tagName)) {
        tagCountMap[tagName] = 0;
      }
      // 增加标签出现次数
      tagCountMap[tagName] = tagCountMap[tagName]! + 1;
    }
  }
  return groupTagCountMap;
}

/**
 * 计算玩家的能力向量(3个向量)
 * 频率 = 标签出现次数 / 该分组总标签数
 * @param filteredRecords 筛选后的谱面记录列表
 * @return 玩家的能力向量Map（键：分组名称，值：该分组下各标签的能力向量Map）
 */
Future<Map<String, Map<String, double>>> calculatePlayerAbilityVectors(
    List<RecordItem> filteredRecords) async {
  Map<String, Map<String, double>> playerAbilityVectors = {};
  Map<String, Map<String, int>> groupTagCountMap =
      await countTagsByGroup(filteredRecords);
  // 遍历每个分组，计算其下各标签的能力向量
  for (var groupName in groupTagCountMap.keys) {
    // 对于每个分组，计算其下各标签的能力向量
    Map<String, int> tagCountMap = groupTagCountMap[groupName]!;
    int totalTagCount = tagCountMap.values.fold(0, (sum, count) => sum + count);
    playerAbilityVectors[groupName] = {};
    for (var tagName in tagCountMap.keys) {
      int tagCount = tagCountMap[tagName]!;
      double frequency = tagCount / totalTagCount;
      playerAbilityVectors[groupName]![tagName] = frequency;
    }
  }
  return playerAbilityVectors;
}

/**
 * 获取玩家的过往版本中的BestN个谱面或当前版本中的BestN个谱面
 * @param allRecords 所有谱面记录列表
 * @param n 要获取的谱面数量
 * @param isNewOnly 是否仅获取当前版本的BestN个谱面
 * @return 玩家的BestN个谱面记录列表
 */
Future<List<RecordItem>> getBestNRecords(
    List<RecordItem> allRecords, int n, bool isNewOnly) async {
  // 1. 读取并解析 JSON 文件
  final String maimaiMusicDataString = await rootBundle
      .loadString(RecommendByTagsService.MAIMAI_MUSIC_DATA_FILE_PATH);
  final List<dynamic> rawSongList = json.decode(maimaiMusicDataString);
  final List<Song> maimaiMusicData = rawSongList
      .map((json) => Song.fromJson(json as Map<String, dynamic>))
      .toList();

  // 2. 构建 songId 到 isNew 的映射（原逻辑不变，可简化为一行）
  final Map<String, bool> songIdToIsNewMap = {
    for (var song in maimaiMusicData) song.id: song.basicInfo.isNew,
  };

  // 3. 优化后的筛选+排序+取前 N 逻辑
  final List<RecordItem> bestRecords = allRecords
      // 筛选条件：显式处理空值，逻辑更清晰
      .where((record) {
    // 兜底：如果 songId 不在映射中，默认按 "非目标版本" 处理（返回 false）
    final bool? isNew = songIdToIsNewMap[record.songId];
    return isNew ?? false == isNewOnly;
  })
      // 按 Rating 降序排序
      .toList() // where 返回 Iterable，需先转 List 才能排序
    ..sort((a, b) => b.ra.compareTo(a.ra))
    // 取前 N 个并转 List
    ..take(n).toList();

  return bestRecords;
}

/**
 * 获取玩家的Rating范围
 * @param records 玩家的谱面记录列表
 * @return (minRating, maxRating) 玩家的Rating范围
 */
(int, int) getRaRange(List<RecordItem> records) {
  if (records.isEmpty) {
    return (0, 0);
  }
  int minRating = records.first.ra;
  int maxRating = records.first.ra;
  for (var record in records) {
    minRating = min(minRating, record.ra);
    maxRating = max(maxRating, record.ra);
  }
  return (minRating, maxRating);
}

/**
 * 计算推荐结果
 * @param allRecords 所有谱面记录列表
 * @param playerAbilityVectors 玩家的能力向量Map（键：分组名称，值：该分组下各标签的能力向量Map）
 * @param best55minRating 玩家的Best55谱面记录列表中最小Rating
 * @param best55maxRating 玩家的Best55谱面记录列表中最大Rating
 * @param isNewOnly 是否仅推荐当前版本的谱面
 * @return 推荐结果列表
 */
List<RecommendationResult> calculateRecommendations(
    List<RecordItem> allRecords,
    Map<String, Map<String, double>> playerAbilityVectors,
    int minRating,
    int maxRating,
    bool isNewOnly) {
      return [];
    }

/**
 * 推荐算法实现 
 * 设计思想：根据单曲Rating最高的70个谱面，计算玩家的能力向量(3个向量)，
 * 并根据玩家的能力向量，推荐玩家能够推分的谱面
 * Best55 部分兼顾推分和基础
 * Best15 部分专注于推分
 */
Future<void> recommendSongs() async {
  // 使用已经筛选的单曲Rating最高的70个谱面
  List<RecordItem> userPlayDataRecords = await getUserPlayDataRecords();
  List<RecordItem> filteredRecords = filterRecordsByRating(userPlayDataRecords);

  // 根据Best70标签的出现频率计算玩家的能力向量(3个向量)
  Map<String, Map<String, double>> playerAbilityVectors =
      await calculatePlayerAbilityVectors(filteredRecords);

  // 获取玩家的过往版本中的Best55和当前版本中的Best15
  List<RecordItem> best55 = await getBestNRecords(filteredRecords, 55, false);
  List<RecordItem> best15 = await getBestNRecords(filteredRecords, 15, true);

  // 计算过往版本中的Best35用于判断Best55推荐结果是否能够增长总Rating
  List<RecordItem> best35 = await getBestNRecords(filteredRecords, 35, false);

  // 获取Rating范围
  int best55minRating = 0;
  int best55maxRating = 0;
  (best55minRating, best55maxRating) = getRaRange(best55);
  int best15minRating = 0;
  int best15maxRating = 0;
  (best15minRating, best15maxRating) = getRaRange(best15);
  int best35minRating = 0;
  int best35maxRating = 0;
  (best35minRating, best35maxRating) = getRaRange(best35);

  //计算推荐结果
  List<RecommendationResult> best55Recommendations = calculateRecommendations(
      userPlayDataRecords,
      playerAbilityVectors,
      best55minRating,
      best55maxRating,
      false);
}
