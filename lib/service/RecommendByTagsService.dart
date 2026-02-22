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
  static const String USER_PLAY_DATA_FILE_PATH =
      'assets/userPlayData.json'; // 玩家游玩记录文件路径
  static const String MAIN_TAG_FILE_PATH = 'assets/maiTags.json'; // 标签文件路径
  static const String MAIMAI_MUSIC_DATA_FILE_PATH =
      'assets/maimai_music_data.json'; // 谱面数据文件路径
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
  static const List<double> RATING_WEIGHT = [
    0.224,
    0.222,
    0.216,
    0.214,
    0.211,
    0.208,
    0.206,
    0.203,
    0.2,
    0.176,
    0.168,
    0.152,
    0.136,
    0.128,
    0.12,
    0.112,
    0.096,
    0.08,
    0.064,
    0.048,
    0.032,
    0.016,
  ];

  // 缓存变量
  static String? _maiTagFileContent;
  static String? _maimaiMusicDataFileContent;
  static String? _userPlayDataFileContent;
  static MaiTagsEntity? _cachedMaiTagsEntity;
  static List<Song>? _cachedMaimaiMusicData;
  static UserPlayDataEntity? _cachedUserPlayDataEntity;
  static Map<String, List<int>>? _cachedSongIdToTagIdsMap;
  static Map<int, String>? _cachedGroupIdToNameMap;
  static Map<int, (String, int)>? _cachedTagIdToInfoMap;
  static Map<String, bool>? _cachedSongIdToIsNewMap;
}

/**
 * 构建 谱面标识 = 谱面ID + 谱面类型 + 谱面难度 到 标签ID列表 的映射
 * @param maiTagEntity 标签实体类
 * @return 谱面标识 = 谱面ID + 谱面类型 + 谱面难度 到 标签ID列表 的映射
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

/**
 * 获取玩家游玩记录中的Records数组
 * @return Records数组（包含玩家游玩的所有谱面记录）
 */
Future<List<RecordItem>> getUserPlayDataRecords() async {
  try {
    // 检查缓存
    if (RecommendByTagsService._cachedUserPlayDataEntity != null) {
      return RecommendByTagsService._cachedUserPlayDataEntity!.records;
    }

    // 读取玩家游玩记录 JSON 文件
    String playDataPath = RecommendByTagsService.USER_PLAY_DATA_FILE_PATH;
    String playDataString;

    // 检查文件内容缓存
    if (RecommendByTagsService._userPlayDataFileContent == null) {
      playDataString = await rootBundle.loadString(playDataPath);
      RecommendByTagsService._userPlayDataFileContent = playDataString;
    } else {
      playDataString = RecommendByTagsService._userPlayDataFileContent!;
    }

    // 解析为最外层Map
    Map<String, dynamic> playDataJson = json.decode(playDataString);

    // 解析最外层的实体：UserPlayDataEntity
    UserPlayDataEntity userPlayData = UserPlayDataEntity.fromJson(playDataJson);
    // 缓存结果
    RecommendByTagsService._cachedUserPlayDataEntity = userPlayData;

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
  // 检查缓存
  if (RecommendByTagsService._cachedMaiTagsEntity == null) {
    // 读取主要标签 JSON 文件
    String mainTagPath = RecommendByTagsService.MAIN_TAG_FILE_PATH;
    String mainTagString;

    // 检查文件内容缓存
    if (RecommendByTagsService._maiTagFileContent == null) {
      mainTagString = await rootBundle.loadString(mainTagPath);
      RecommendByTagsService._maiTagFileContent = mainTagString;
    } else {
      mainTagString = RecommendByTagsService._maiTagFileContent!;
    }

    // 解析为最外层Map
    Map<String, dynamic> mainTagJson = json.decode(mainTagString);

    // 解析最外层的实体：MaiTagEntity
    RecommendByTagsService._cachedMaiTagsEntity =
        MaiTagsEntity.fromJson(mainTagJson);
  }

  MaiTagsEntity MaiTagEntity = RecommendByTagsService._cachedMaiTagsEntity!;

  // 第一步：构建分组ID到分组名称的映射，如 1 -> 配置
  Map<int, String> groupIdToNameMap;
  if (RecommendByTagsService._cachedGroupIdToNameMap == null) {
    groupIdToNameMap = {};
    List<TagGroupItem> tagGroups = MaiTagEntity.tagGroups;
    if (tagGroups.isNotEmpty) {
      for (var group in tagGroups) {
        groupIdToNameMap[group.id] = group.localizedName.zhHans;
      }
    } else {
      print('MaiTagEntity.tagGroups 为空');
      return {};
    }
    RecommendByTagsService._cachedGroupIdToNameMap = groupIdToNameMap;
  } else {
    groupIdToNameMap = RecommendByTagsService._cachedGroupIdToNameMap!;
  }

  // 第二步：构建标签ID → (标签名称, 分组ID) 的映射, 如 22 -> (高物量, 3)
  Map<int, (String, int)> tagIdToInfoMap;
  if (RecommendByTagsService._cachedTagIdToInfoMap == null) {
    tagIdToInfoMap = {};
    List<TagItem> tags = MaiTagEntity.tags;
    if (tags.isNotEmpty) {
      for (var tag in tags) {
        tagIdToInfoMap[tag.id] = (tag.localizedName.zhHans, tag.groupId);
      }
    } else {
      print('MaiTagEntity.tags 为空');
      return {};
    }
    RecommendByTagsService._cachedTagIdToInfoMap = tagIdToInfoMap;
  } else {
    tagIdToInfoMap = RecommendByTagsService._cachedTagIdToInfoMap!;
  }

  // 第三步：构建 谱面标识 → 标签ID列表 的映射
  Map<String, List<int>> songIdToTagIdsMap;
  if (RecommendByTagsService._cachedSongIdToTagIdsMap == null) {
    songIdToTagIdsMap = buildSongIdToTagIdsMap(MaiTagEntity);
    RecommendByTagsService._cachedSongIdToTagIdsMap = songIdToTagIdsMap;
  } else {
    songIdToTagIdsMap = RecommendByTagsService._cachedSongIdToTagIdsMap!;
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
  // 先求出玩家筛选后的数据中的变迁出现次数(按分组统计)
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
  // 检查缓存
  if (RecommendByTagsService._cachedSongIdToIsNewMap == null) {
    // 1. 读取并解析 JSON 文件
    String maimaiMusicDataString;
    if (RecommendByTagsService._maimaiMusicDataFileContent == null) {
      maimaiMusicDataString = await rootBundle
          .loadString(RecommendByTagsService.MAIMAI_MUSIC_DATA_FILE_PATH);
      RecommendByTagsService._maimaiMusicDataFileContent =
          maimaiMusicDataString;
    } else {
      maimaiMusicDataString =
          RecommendByTagsService._maimaiMusicDataFileContent!;
    }

    final List<dynamic> rawSongList = json.decode(maimaiMusicDataString);
    final List<Song> maimaiMusicData = rawSongList
        .map((json) => Song.fromJson(json as Map<String, dynamic>))
        .toList();

    // 2. 构建 songId 到 isNew 的映射
    RecommendByTagsService._cachedSongIdToIsNewMap = {
      for (var song in maimaiMusicData) song.id: song.basicInfo.isNew,
    };
  }

  Map<String, bool> songIdToIsNewMap =
      RecommendByTagsService._cachedSongIdToIsNewMap!;

  // 3. 优化后的筛选+排序+取前 N 逻辑
  final List<RecordItem> bestRecords = allRecords
      // 筛选条件：显式处理空值，逻辑更清晰
      .where((record) {
    // 兜底：如果 songId 不在映射中，默认按 "非目标版本" 处理（返回 false）
    final bool? isNew = songIdToIsNewMap[record.songId.toString()];
    return (isNew ?? false) == isNewOnly;
  })
      // 按 Rating 降序排序
      .toList() // where 返回 Iterable，需先转 List 才能排序
    ..sort((a, b) => b.ra.compareTo(a.ra));

  // 取前 N 个
  return bestRecords.take(n).toList();
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
 * 获取定数范围
 * @param minRating 最小Rating
 * @param maxRating 最大Rating
 * @return (minDs, maxDs) 定数范围
 */
(double, double) getDifficultyRange(int minRating, int maxRating) {
  double minDs = (minRating / (100.5 * 0.224) * 10).round() / 10;
  double maxDs = (maxRating / (100.0 * 0.216) * 10).round() / 10;
  return (minDs, maxDs);
}

/**
 * 计算单曲Rating
 * @param ds 谱面难度
 * @param achievement 玩家达成率 只考虑100.0 - 101.0的范围
 * @return 单曲Rating
 */
int calculateSingleRating(double ds, double achievement) {
  // 达成率大于等于100.5 SSS+
  if (achievement >= 100.5) {
    return (ds * 100.5 * RecommendByTagsService.RATING_WEIGHT[0]).truncate();
  }
  // 100.4999 SSS
  if (achievement == 100.4999) {
    return (ds * 100.4999 * RecommendByTagsService.RATING_WEIGHT[1]).truncate();
  }
  // 100.0 - 100.4998 SSS
  if (achievement >= 100.0 && achievement < 100.4999) {
    return (ds * achievement * RecommendByTagsService.RATING_WEIGHT[2])
        .truncate();
  }
  return 0;
}

/**
 * 计算单个谱面的向量
 */
Future<Map<String, Map<String, double>>> calculateChartVectors(
    RecordItem recordItem) async {
  // 检查缓存
  if (RecommendByTagsService._cachedMaiTagsEntity == null) {
    // 读取标签 JSON 文件
    String mainTagPath = RecommendByTagsService.MAIN_TAG_FILE_PATH;
    String mainTagString;

    if (RecommendByTagsService._maiTagFileContent == null) {
      mainTagString = await rootBundle.loadString(mainTagPath);
      RecommendByTagsService._maiTagFileContent = mainTagString;
    } else {
      mainTagString = RecommendByTagsService._maiTagFileContent!;
    }

    // 解析为最外层Map
    Map<String, dynamic> mainTagJson = json.decode(mainTagString);

    // 解析最外层的实体：MaiTagEntity
    RecommendByTagsService._cachedMaiTagsEntity =
        MaiTagsEntity.fromJson(mainTagJson);
  }

  MaiTagsEntity MaiTagEntity = RecommendByTagsService._cachedMaiTagsEntity!;

  // 构建 谱面标识 = 谱面ID + 谱面类型 + 谱面难度 到 标签ID列表 的映射
  Map<String, List<int>> songIdToTagIdsMap;
  if (RecommendByTagsService._cachedSongIdToTagIdsMap == null) {
    songIdToTagIdsMap = buildSongIdToTagIdsMap(MaiTagEntity);
    RecommendByTagsService._cachedSongIdToTagIdsMap = songIdToTagIdsMap;
  } else {
    songIdToTagIdsMap = RecommendByTagsService._cachedSongIdToTagIdsMap!;
  }

  // 构建 标签ID 到 标签名称 的映射
  Map<int, String> tagIdToNameMap = {};
  for (var tag in MaiTagEntity.tags) {
    tagIdToNameMap[tag.id] = tag.localizedName.zhHans;
  }

  // 构建 标签ID 到 标签分组ID 的映射
  Map<int, int> tagIdToGroupIdMap = {};
  for (var tag in MaiTagEntity.tags) {
    tagIdToGroupIdMap[tag.id] = tag.groupId;
  }

  // 按照groupId统计标签出现次数 （键：groupId，值：(标签名 → 出现次数)）
  Map<int, Map<String, int>> groupTagCounts = {};
  // groupId 的总标签数
  Map<int, int> groupTotalTags = {};
  // 初始化3个group
  groupTagCounts[1] = {};
  groupTagCounts[2] = {};
  groupTagCounts[3] = {};
  groupTotalTags[1] = 0;
  groupTotalTags[2] = 0;
  groupTotalTags[3] = 0;

  // 获取当前谱面的标签
  String songTitle = recordItem.title;
  String sheetType = RecommendByTagsService.TYPE_MAP[recordItem.type] ?? '';
  String sheetDifficulty =
      RecommendByTagsService.LEVEL_INDEX_MAP[recordItem.levelIndex] ?? '';
  String songKey = songTitle + "#" + sheetType + "#" + sheetDifficulty;
  List<int> tagIds = songIdToTagIdsMap[songKey] ?? [];
  // 统计每个标签分组的出现次数
  for (int tagId in tagIds) {
    int groupId = tagIdToGroupIdMap[tagId] ?? 0;
    if (groupId == 0) {
      continue;
    }
    String tagName = tagIdToNameMap[tagId] ?? '';
    if (tagName.isEmpty) {
      continue;
    }
    groupTagCounts[groupId]![tagName] =
        (groupTagCounts[groupId]![tagName] ?? 0) + 1;
    groupTotalTags[groupId] = (groupTotalTags[groupId] ?? 0) + 1;
  }

  // 计算三个向量
  Map<String, Map<String, double>> chartVectors = {};
  // 配置向量(groupId == 1)
  Map<String, double> configVector = {};
  for (String tagName in groupTagCounts[1]!.keys) {
    int count = groupTagCounts[1]![tagName] ?? 0;
    double weight = count / groupTotalTags[1]!;
    configVector[tagName] = weight;
  }
  chartVectors['config'] = configVector;

  // 难度向量(groupId == 2)
  Map<String, double> difficultyVector = {};
  for (String tagName in groupTagCounts[2]!.keys) {
    int count = groupTagCounts[2]![tagName] ?? 0;
    double weight = count / groupTotalTags[2]!;
    difficultyVector[tagName] = weight;
  }
  chartVectors['difficulty'] = difficultyVector;

  // 评价向量(groupId == 3)
  Map<String, double> modeVector = {};
  for (String tagName in groupTagCounts[3]!.keys) {
    int count = groupTagCounts[3]![tagName] ?? 0;
    double weight = count / groupTotalTags[3]!;
    modeVector[tagName] = weight;
  }
  chartVectors['evaluation'] = modeVector;

  return chartVectors;
}

/**
 * 计算向量相似度
 */
double calculateVectorSimilarity(
    Map<String, double> playerVector, Map<String, double> chartVector) {
  if (playerVector.isEmpty || chartVector.isEmpty) {
    return 0.0;
  }
  // 计算点积
  double dotProduct = 0.0;
  for (String key in playerVector.keys) {
    if (chartVector.containsKey(key)) {
      dotProduct += playerVector[key]! * chartVector[key]!;
    }
  }
  // 计算两个向量的长度
  double playerVectorLength = 0.0;
  for (double value in playerVector.values) {
    playerVectorLength += value * value;
  }
  playerVectorLength = sqrt(playerVectorLength);
  double chartVectorLength = 0.0;
  for (double value in chartVector.values) {
    chartVectorLength += value * value;
  }
  chartVectorLength = sqrt(chartVectorLength);

  if (playerVectorLength == 0.0 || chartVectorLength == 0.0) {
    return 0.0;
  }
  // 计算相似度
  return dotProduct / (playerVectorLength * chartVectorLength);
}

/**
 * 计算玩家的能力向量和谱面的向量的综合相似度
 * @param playerAbilityVectors 玩家的能力向量Map（键：分组名称，值：该分组下各标签的能力向量Map）
 * @param chartVectors 谱面记录的向量Map（键：分组名称，值：该分组下各标签的谱面记录向量Map）
 * @return 综合相似度
 */
double calculateSimilarity(
    Map<String, Map<String, double>> playerAbilityVectors,
    Map<String, Map<String, double>> chartVectors) {
  // 计算每个向量的相似度
  double configSimilarity = calculateVectorSimilarity(
      playerAbilityVectors['配置']!, chartVectors['config']!);
  double difficultySimilarity = calculateVectorSimilarity(
      playerAbilityVectors['难度']!, chartVectors['difficulty']!);
  double evaluationSimilarity = calculateVectorSimilarity(
      playerAbilityVectors['评价']!, chartVectors['evaluation']!);

  // 设定权重
  double weightConfig = 0.5;
  double weightDifficulty = 0.3;
  double weightEvaluation = 0.2;
  // 计算综合相似度
  double similarity = configSimilarity * weightConfig +
      difficultySimilarity * weightDifficulty +
      evaluationSimilarity * weightEvaluation;
  return similarity;
}

/**
 * 计算推荐结果
 * 基于玩家的能力向量和谱面记录，计算推荐结果
 * @param maimaiMusicData 所有歌曲列表
 * @param allRecords 所有谱面记录列表
 * @param playerAbilityVectors 玩家的能力向量Map（键：分组名称，值：该分组下各标签的能力向量Map）
 * @param best55minRating 玩家的Best55谱面记录列表中最小Rating
 * @param best55maxRating 玩家的Best55谱面记录列表中最大Rating
 * @param isNewOnly 是否仅推荐当前版本的谱面
 * @return 推荐结果列表
 */
Future<List<RecommendationResult>> calculateRecommendations(
    List<Song> maimaiMusicData,
    List<RecordItem> allRecords,
    Map<String, Map<String, double>> playerAbilityVectors,
    double minDs,
    double maxDs,
    int minRating,
    int maxRating,
    int best35minRating,
    int best35maxRating,
    bool isNewOnly) async {
  List<RecommendationResult> recommendations = [];
  // 初始化所有歌曲列表
  List<Song> songs;
  if (RecommendByTagsService._cachedMaimaiMusicData == null) {
    String maimaiMusicDataString;
    if (RecommendByTagsService._maimaiMusicDataFileContent == null) {
      maimaiMusicDataString = await rootBundle
          .loadString(RecommendByTagsService.MAIMAI_MUSIC_DATA_FILE_PATH);
      RecommendByTagsService._maimaiMusicDataFileContent =
          maimaiMusicDataString;
    } else {
      maimaiMusicDataString =
          RecommendByTagsService._maimaiMusicDataFileContent!;
    }
    final List<dynamic> rawSongList = json.decode(maimaiMusicDataString);
    songs = rawSongList
        .map((json) => Song.fromJson(json as Map<String, dynamic>))
        .toList();
    RecommendByTagsService._cachedMaimaiMusicData = songs;
  } else {
    songs = RecommendByTagsService._cachedMaimaiMusicData!;
  }
  /**
   * 核心是从maimaiMusicData中进行筛选
   * 匹配条件： 
   * 1. 歌曲必须是目标版本的谱面（根据isNewOnly判断）
   * 2. 歌曲的定数必须在目标定数范围内（minDs <= ds <= maxDs）
   * 3. 标签匹配度 >= 0.500
   * 剔除条件：
   * 1. 达成率已达到100.5%以上的谱面
   */
  for (var song in songs) {
    // 1. 歌曲必须是目标版本的谱面（根据isNewOnly判断）
    if (song.basicInfo.isNew != isNewOnly) {
      continue;
    }
    // 2. 歌曲的定数必须在目标定数范围内（minDs <= ds <= maxDs）
    // 在maimaiMusicData中，ds为数组，需要遍历每个定数
    for (int i = 0; i < song.ds.length; i++) {
      double ds = song.ds[i];
      if (ds >= minDs && ds <= maxDs) {
        // 检查玩家是否在此谱面上获得了大于100.5%的达成率
        bool hasHighAchievement = allRecords.any((record) =>
            record.songId == int.parse(song.id) &&
            record.levelIndex == i &&
            record.achievements > 100.5);
        if (hasHighAchievement) {
          continue;
        }

        // 计算能落入rating区间的最低达成率
        double minAchievements = 0.0;
        if (isNewOnly == false)
          minAchievements = calculateMinAchievements(ds, best35minRating);
        if (isNewOnly == true)
          minAchievements = calculateMinAchievements(ds, minRating);

        // 提前过滤，避免不必要的计算
        if (minAchievements < 100.0) {
          continue;
        }

        bool ableRiseTotalRating = false;
        int riseToatalRating = 0;

        // 计算单个谱面的向量
        // 将song转换为RecordItem
        RecordItem recordItem = RecordItem(
          achievements: 0.0,
          ds: ds,
          dxScore: 0,
          fc: '',
          fs: '',
          level: '',
          levelIndex: i,
          levelLabel: '',
          ra: 0,
          rate: '',
          songId: int.parse(song.id),
          title: song.basicInfo.title,
          type: song.type,
        );

        Map<String, Map<String, double>> songVectors =
            await calculateChartVectors(recordItem);
        // 计算综合相似度
        double similarity =
            calculateSimilarity(playerAbilityVectors, songVectors);

        // 将综合相似度 >= 0.5 的谱面加入推荐结果列表
        if (similarity >= 0.5) {
          // 计算此推荐结果能否带来Rating的提升
          int minAchievementsRating =
              calculateSingleRating(ds, minAchievements);
          // 对于Best35的提升情况
          if (isNewOnly == false && minAchievementsRating > best35minRating) {
            // 计算此推荐结果能提升的Rating
            ableRiseTotalRating = true;
            riseToatalRating = minAchievementsRating - best35minRating;
          }
          // 对于Best15的提升情况
          if (isNewOnly == true) {
            // 计算此推荐结果能提升的Rating
            ableRiseTotalRating = true;
            riseToatalRating = minAchievementsRating - minRating;
          }

          // 根据转换的对象中的已知条件找出玩家这个谱面的达成率
          RecordItem? playerRecord = allRecords.firstWhere(
            (record) =>
                record.songId == recordItem.songId &&
                record.levelIndex == recordItem.levelIndex,
            orElse: () => recordItem,
          );
          recommendations.add(RecommendationResult(
            songTitle: song.basicInfo.title,
            level: song.level[i],
            ds: ds,
            similarity: similarity,
            nowAchievement: playerRecord.achievements,
            minAchievement: minAchievements,
            ableRiseTotalRating: ableRiseTotalRating,
            riseTotalRating: ableRiseTotalRating
                ? "+" + riseToatalRating.toString()
                : '无Rating提升,推荐练习',
          ));
        }
      }
    }
  }

  // // 构建 songId 到 isNew 的映射
  // Map<String, bool> songIdToIsNewMap = {
  //   for (var song in maimaiMusicData) song.id: song.basicInfo.isNew,
  // };
  // for (var record in allRecords) {
  //   // 检查是否为目标版本的谱面
  //   if (songIdToIsNewMap[record.songId] != isNewOnly) {
  //     continue;
  //   }
  //   // 过滤掉达成率已经超过100.5%的谱面
  //   if (record.achievements >= 100.5) {
  //     continue;
  //   }

  //   // 构建songKey,避免重复推荐
  //   String songTitle = record.title;
  //   String songType = record.type;
  //   String level = record.level;
  //   String songKey = songTitle + '#' + songType + '#' + level;
  //   // 检查是否已经推荐过该谱面
  //   if (recommendedSongKeys.contains(songKey)) {
  //     continue;
  //   }
  //   // 添加到推荐结果列表
  //   recommendedSongKeys.add(songKey);
  //   // 检查定数是否在范围内
  //   if (record.ds >= minDs && record.ds <= maxDs) {}
  // }
  return recommendations;
}

/**
 * 计算能落入rating区间的最低达成率
 * @param ds 谱面定数
 * @param targetRating 目标Rating
 * @return 能落入rating区间的最低达成率
 */
double calculateMinAchievements(double ds, int targetRa) {
  // 避免除以零
  if (ds <= 0 || RecommendByTagsService.RATING_WEIGHT[2] <= 0) {
    return 100.5;
  }

  // 计算能落入rating区间的最低达成率
  double achievement =
      targetRa / (ds * RecommendByTagsService.RATING_WEIGHT[2]);
  // 注意到回代验证有.9999的存在，所以需要二次验证
  double roundedRa =
      achievement * (ds * RecommendByTagsService.RATING_WEIGHT[2]);
  if (roundedRa.truncate() < targetRa) {
    achievement = 100.5;
  }

  return min(achievement, 100.5);
}

/**
 * 推荐算法实现 
 * 设计思想：根据单曲Rating最高的70个谱面，计算玩家的能力向量(3个向量)，
 * 并根据玩家的能力向量，推荐玩家能够推分的谱面
 * Best55 部分兼顾推分和基础
 * Best15 部分专注于推分
 */
Future<Map<String, List<RecommendationResult>>> recommendSongs() async {
  // 定义兜底返回值，确保异常时也能返回规范格式
  final defaultResult = {
    'Best55': <RecommendationResult>[],
    'Best15': <RecommendationResult>[]
  };

  try {
    // 使用已经筛选的单曲Rating最高的70个谱面
    List<RecordItem> userPlayDataRecords = await getUserPlayDataRecords();
    List<RecordItem> filteredRecords =
        filterRecordsByRating(userPlayDataRecords);

    // 根据Best70标签的出现频率计算玩家的能力向量(3个向量)
    Map<String, Map<String, double>> playerAbilityVectors =
        await calculatePlayerAbilityVectors(filteredRecords);

    // 获取玩家的过往版本中的Best55和当前版本中的Best15
    List<RecordItem> best55 =
        await getBestNRecords(userPlayDataRecords, 55, false);
    List<RecordItem> best15 =
        await getBestNRecords(userPlayDataRecords, 15, true);

    // 计算过往版本中的Best35用于判断Best55推荐结果是否能够增长总Rating
    List<RecordItem> best35 =
        await getBestNRecords(userPlayDataRecords, 35, false);
    for (var record in best35) {
      print(record.toString());
    }

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

    // 获取定数范围
    double best55minDs = 0.0;
    double best55maxDs = 0.0;
    (best55minDs, best55maxDs) =
        getDifficultyRange(best55minRating, best55maxRating);
    double best15minDs = 0.0;
    double best15maxDs = 0.0;
    (best15minDs, best15maxDs) =
        getDifficultyRange(best15minRating, best15maxRating);

    // 计算b55推荐结果
    List<RecommendationResult> best55Recommendations =
        await calculateRecommendations([],
            userPlayDataRecords,
            playerAbilityVectors,
            best55minDs,
            best55maxDs,
            best55minRating,
            best55maxRating,
            best35minRating,
            best35maxRating,
            false);
    best55Recommendations.sort((a, b) => b.similarity.compareTo(a.similarity));

    // 计算b15推荐结果
    List<RecommendationResult> best15Recommendations =
        await calculateRecommendations([],
            userPlayDataRecords,
            playerAbilityVectors,
            best15minDs,
            best15maxDs,
            best15minRating,
            best15maxRating,
            best35minRating,
            best35maxRating,
            true);
    best15Recommendations.sort((a, b) => b.similarity.compareTo(a.similarity));

    // 返回推荐结果
    return {
      'Best55': best55Recommendations,
      'Best15': best15Recommendations,
    };
  } catch (e, stackTrace) {
    // 全局异常捕获，打印详细错误信息便于排查
    print('推荐算法执行异常: $e');
    print('异常堆栈信息: $stackTrace');
    // 异常时返回空的推荐结果，避免崩溃
    return defaultResult;
  }
}
