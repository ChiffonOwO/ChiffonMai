// ignore_for_file: slash_for_doc_comments

import 'dart:convert';
import 'dart:math';

import 'package:my_first_flutter_app/entity/Song.dart';
import 'package:my_first_flutter_app/entity/RecommendationResult.dart';
import 'package:my_first_flutter_app/entity/RecordItem.dart';
import 'package:my_first_flutter_app/entity/UserPlayDataEntity.dart';
import 'package:my_first_flutter_app/manager/MaimaiMusicDataManager.dart';
import 'package:my_first_flutter_app/manager/UserPlayDataManager.dart';
import 'package:my_first_flutter_app/manager/MaiTagsManager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecommendByTagsService {
  static const int MAX_LIMIT = 70; // 最大推荐数
  static const int RA_RANGE_LIMIT = 20; // Rating极差上限
  static const String USER_PLAY_DATA_FILE_PATH =
      'assets/userPlayData.json'; // 玩家游玩记录文件路径
  static const String MAIN_TAG_FILE_PATH =
      'assets/maiTags.json'; // 标签文件路径（作为 fallback）
  static const String MAIMAI_MUSIC_DATA_FILE_PATH =
      'assets/maimai_music_data.json'; // 谱面数据文件路径

  /**
   * 初始化标签数据，在 app 启动时调用，或在刷新数据时调用
   */
  static Future<void> initializeTags() async {
    await MaiTagsManager().initializeTags();
  }

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
  // 仅保留谱面向量缓存，其他缓存由对应的Manager管理
  static Map<String, Map<String, Map<String, double>>>?
      _cachedChartVectors; // 缓存谱面向量

  // Group names constants
  static const String GROUP_CONFIG = 'config';
  static const String GROUP_DIFFICULTY = 'difficulty';
  static const String GROUP_EVALUATION = 'evaluation';
  static const String RECOMMENDATION_CACHE_KEY = 'recommendation_results'; // 推荐结果缓存键
}

/**
 * 获取玩家游玩记录中的Records数组
 * @return Records数组（包含玩家游玩的所有谱面记录）
 */
Future<List<RecordItem>> getUserPlayDataRecords() async {
  try {
    // 直接从 UserPlayDataManager 获取数据
    final userPlayDataManager = UserPlayDataManager();
    final cachedUserData = await userPlayDataManager.getCachedUserPlayData();

    if (cachedUserData != null) {
      // 解析最外层的实体：UserPlayDataEntity
      UserPlayDataEntity userPlayData =
          UserPlayDataEntity.fromJson(cachedUserData);
      // 提取Records数组
      List<RecordItem> records = userPlayData.records;
      return records;
    } else {
      // 如果缓存中没有数据，返回空列表
      print('UserPlayDataManager 中没有缓存数据');
      return [];
    }
  } catch (e) {
    print('获取玩家游玩记录失败: $e');
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
  // 获取标签管理器实例
  final maiTagsManager = MaiTagsManager();

  // 构建分组ID到分组名称的映射，使用英文常量
  Map<int, String> groupIdToNameMap = {
    1: RecommendByTagsService.GROUP_CONFIG,
    2: RecommendByTagsService.GROUP_DIFFICULTY,
    3: RecommendByTagsService.GROUP_EVALUATION,
  };

  // 第二步：构建标签ID → (标签名称, 分组ID) 的映射, 如 22 -> (高物量, 3)
  Map<int, (String, int)> tagIdToInfoMap =
      await maiTagsManager.getTagIdToInfoMap();
  if (tagIdToInfoMap.isEmpty) {
    print('标签ID到信息的映射为空');
    return {};
  }

  // 第三步：构建 谱面标识 → 标签ID列表 的映射
  Map<String, List<int>> songIdToTagIdsMap =
      await maiTagsManager.getSongIdToTagIdsMap();

  // 第四步：遍历筛选后的RA谱面，按分组统计标签出现次数
  // 分组名 → (标签名 → 出现次数)
  Map<String, Map<String, int>> groupTagCountMap = {};
  // 统计一次谱面的标签出现次数会增加其所属分组的对应标签的出现次数，所以设定一个Set防止多次统计
  Set<String> processedSongKeys = {};
  for (var record in filteredRecords) {
    // 构建谱面标识，注意type和难度需要相关映射，两个数据源的属性值不同
    String sheetType = '';
    if (RecommendByTagsService.TYPE_MAP.containsKey(record.type)) {
      sheetType = RecommendByTagsService.TYPE_MAP[record.type]!;
    } else {
      // 尝试反向映射
      sheetType = RecommendByTagsService.TYPE_MAP.entries
          .firstWhere((entry) => entry.value == record.type.toLowerCase(),
              orElse: () => MapEntry('', ''))
          .value;
    }
    String songKey = record.title +
        "#" +
        sheetType +
        "#" +
        RecommendByTagsService.LEVEL_INDEX_MAP[record.levelIndex]!;
    // 如果该谱面已被处理过，则跳过
    if (processedSongKeys.contains(songKey)) {
      continue;
    }
    processedSongKeys.add(songKey);

    //获取该谱面的所有标签ID
    List<int>? tagIds = songIdToTagIdsMap[songKey] ?? [];
    for (var tagId in tagIds) {
      final tagInfo = tagIdToInfoMap[tagId];
      if (tagInfo != null) {
        // 解构提取 tagName 和 groupId
        String tagName = tagInfo.$1;
        int groupId = tagInfo.$2;

        // 获取分组名称
        String? groupName = groupIdToNameMap[groupId];
        if (groupName != null) {
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
  // 先求出玩家筛选后的数据中的各标签出现次数(按分组统计)
  Map<String, Map<String, int>> groupTagCountMap =
      await countTagsByGroup(filteredRecords);
  // 打印分组统计标签出现次数
  print('按分组统计标签出现次数:');
  groupTagCountMap.forEach((groupName, tagCounts) {
    print('  $groupName:');
    tagCounts.forEach((tagName, count) {
      print('    $tagName: $count');
    });
  });
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
  // 打印玩家能力向量
  print('玩家能力向量:');
  playerAbilityVectors.forEach((groupName, tagWeights) {
    print('  $groupName:');
    tagWeights.forEach((tagName, weight) {
      print('    $tagName: ${weight.toStringAsFixed(4)}');
    });
  });
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
  // 直接使用 MaimaiMusicDataManager 中的数据构建 songId 到 isNew 的映射
  final maimaiMusicDataManager = MaimaiMusicDataManager();
  Map<String, bool> songIdToIsNewMap = {};

  if (await maimaiMusicDataManager.hasCachedData()) {
    final songs = await maimaiMusicDataManager.getCachedSongs();
    if (songs != null) {
      // 构建 songId 到 isNew 的映射
      songIdToIsNewMap = {
        for (var song in songs) song.id: song.basicInfo.isNew,
      };
    }
  } else {
    print('MaimaiMusicDataManager 中没有缓存数据');
    return [];
  }

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
  // 构建谱面唯一标识
  String songTitle = recordItem.title;
  // 处理类型映射，确保统一使用 std/dx 格式
  String sheetType = '';
  if (RecommendByTagsService.TYPE_MAP.containsKey(recordItem.type)) {
    sheetType = RecommendByTagsService.TYPE_MAP[recordItem.type]!;
  } else if (recordItem.type.toLowerCase() == 'std' ||
      recordItem.type.toLowerCase() == 'dx') {
    sheetType = recordItem.type.toLowerCase();
  }
  String sheetDifficulty =
      RecommendByTagsService.LEVEL_INDEX_MAP[recordItem.levelIndex] ?? '';
  String songKey = songTitle + "#" + sheetType + "#" + sheetDifficulty;

  // 检查缓存
  if (RecommendByTagsService._cachedChartVectors != null &&
      RecommendByTagsService._cachedChartVectors!.containsKey(songKey)) {
    return RecommendByTagsService._cachedChartVectors![songKey]!;
  }

  // 获取标签管理器实例
  final maiTagsManager = MaiTagsManager();

  // 构建 谱面标识 = 谱面ID + 谱面类型 + 谱面难度 到 标签ID列表 的映射
  Map<String, List<int>> songIdToTagIdsMap =
      await maiTagsManager.getSongIdToTagIdsMap();

  // 构建 标签ID 到 标签名称 的映射
  Map<int, String> tagIdToNameMap = {};
  final maiTagsEntity = await maiTagsManager.getTags();
  if (maiTagsEntity != null) {
    for (var tag in maiTagsEntity.tags) {
      tagIdToNameMap[tag.id] = tag.localizedName.zhHans;
    }
  }

  // 构建 标签ID 到 标签分组ID 的映射
  Map<int, int> tagIdToGroupIdMap = {};
  if (maiTagsEntity != null) {
    for (var tag in maiTagsEntity.tags) {
      tagIdToGroupIdMap[tag.id] = tag.groupId;
    }
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
  if (groupTotalTags[1]! > 0) {
    for (String tagName in groupTagCounts[1]!.keys) {
      int count = groupTagCounts[1]![tagName] ?? 0;
      double weight = count / groupTotalTags[1]!;
      configVector[tagName] = weight;
    }
  }
  chartVectors[RecommendByTagsService.GROUP_CONFIG] = configVector;

  // 难度向量(groupId == 2)
  Map<String, double> difficultyVector = {};
  if (groupTotalTags[2]! > 0) {
    for (String tagName in groupTagCounts[2]!.keys) {
      int count = groupTagCounts[2]![tagName] ?? 0;
      double weight = count / groupTotalTags[2]!;
      difficultyVector[tagName] = weight;
    }
  }
  chartVectors[RecommendByTagsService.GROUP_DIFFICULTY] = difficultyVector;

  // 评价向量(groupId == 3)
  Map<String, double> modeVector = {};
  if (groupTotalTags[3]! > 0) {
    for (String tagName in groupTagCounts[3]!.keys) {
      int count = groupTagCounts[3]![tagName] ?? 0;
      double weight = count / groupTotalTags[3]!;
      modeVector[tagName] = weight;
    }
  }
  chartVectors[RecommendByTagsService.GROUP_EVALUATION] = modeVector;

  // 缓存结果
  if (RecommendByTagsService._cachedChartVectors == null) {
    RecommendByTagsService._cachedChartVectors = {};
  }
  RecommendByTagsService._cachedChartVectors![songKey] = chartVectors;

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
  // 计算每个向量的相似度，添加空值检查
  double configSimilarity = 0.0;
  if (playerAbilityVectors.containsKey(RecommendByTagsService.GROUP_CONFIG)) {
    configSimilarity = calculateVectorSimilarity(
        playerAbilityVectors[RecommendByTagsService.GROUP_CONFIG]!,
        chartVectors[RecommendByTagsService.GROUP_CONFIG] ?? {});
  }

  double difficultySimilarity = 0.0;
  if (playerAbilityVectors.containsKey(RecommendByTagsService.GROUP_DIFFICULTY)) {
    difficultySimilarity = calculateVectorSimilarity(
        playerAbilityVectors[RecommendByTagsService.GROUP_DIFFICULTY]!,
        chartVectors[RecommendByTagsService.GROUP_DIFFICULTY] ?? {});
  }

  double evaluationSimilarity = 0.0;
  if (playerAbilityVectors.containsKey(RecommendByTagsService.GROUP_EVALUATION)) {
    evaluationSimilarity = calculateVectorSimilarity(
        playerAbilityVectors[RecommendByTagsService.GROUP_EVALUATION]!,
        chartVectors[RecommendByTagsService.GROUP_EVALUATION] ?? {});
  }

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
 *  @param allRecords 所有谱面记录列表
 *  @param playerAbilityVectors 玩家的能力向量Map（键：分组名称，值：该分组下各标签的能力向量Map）
 *  @param minDs 目标定数下限
 *  @param maxDs 目标定数上限
 *  @param minRating 目标Rating下限
 *  @param maxRating 目标Rating上限
 *  @param best35minRating 玩家的Best35谱面记录列表中最小Rating
 *  @param best35maxRating 玩家的Best35谱面记录列表中最大Rating
 *  @param isNewOnly 是否仅推荐当前版本的谱面
 *  @return 推荐结果列表
 */
Future<List<RecommendationResult>> calculateRecommendations(
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
  List<Song>? songs;
  // 直接使用 MaimaiMusicDataManager 中的数据
  final maimaiMusicDataManager = MaimaiMusicDataManager();
  if (await maimaiMusicDataManager.hasCachedData()) {
    songs = await maimaiMusicDataManager.getCachedSongs();
  } else {
    print('MaimaiMusicDataManager 中没有缓存数据');
    return [];
  }

  // 预构建玩家记录的映射，提高查找效率
  Map<String, RecordItem> playerRecordMap = {};
  for (var record in allRecords) {
    String key = '${record.songId}_${record.levelIndex}';
    playerRecordMap[key] = record;
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
  for (var song in songs!) {
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
        String recordKey = '${int.parse(song.id)}_$i';
        RecordItem? existingRecord = playerRecordMap[recordKey];
        if (existingRecord != null && existingRecord.achievements > 100.5) {
          continue;
        }

        // 检查玩家是否在此谱面上有记录
        double currentAchievement = double.parse(existingRecord?.achievements.toString() ?? '0.0');
        // 计算能落入rating区间的最低达成率（用于后续计算）
        double minAchievements = 0.0;
        if (isNewOnly == false)
          minAchievements = calculateMinAchievements(ds, best35minRating, currentAchievement);
        if (isNewOnly == true)
          minAchievements = calculateMinAchievements(ds, minRating, currentAchievement);

        // 提前过滤，避免不必要的计算 - 只过滤掉无法达到目标Rating的歌曲
        if (minAchievements > 100.5) {
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
          RecordItem? playerRecord = playerRecordMap[recordKey] ?? recordItem;
          // 确保目标达成率始终大于玩家目前达成率
          double targetAchievement = minAchievements;
          if (playerRecord.achievements >= minAchievements) {
            // 如果当前达成率大于等于最低达成率，则目标达成率为当前达成率加上一个小的增量
            targetAchievement = playerRecord.achievements + 0.001;
          }
          recommendations.add(RecommendationResult(
            songTitle: song.basicInfo.title,
            level: song.level[i],
            ds: ds,
            similarity: similarity,
            nowAchievement: double.parse(playerRecord.achievements.toString()),
            minAchievement: targetAchievement,
            ableRiseTotalRating: ableRiseTotalRating,
            riseTotalRating: ableRiseTotalRating
                ? "+" + riseToatalRating.toString()
                : '无Rating提升,推荐练习',
            songId: song.id,
            levelIndex: i,
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
 * @param targetRa 目标Rating
 * @param currentAchievement 当前达成率
 * @return 能落入rating区间的最低达成率，且始终大于当前达成率
 */
double calculateMinAchievements(double ds, int targetRa, double currentAchievement) {
  // 生成所有可能的分数点
  List<double> achievementPoints = generateAchievementPoints(ds, currentAchievement);
  
  // 从分数点中找到能达到目标Rating的最低达成率
  double minAchievement = 100.5; // 默认值
  
  for (double achievement in achievementPoints) {
    int ra = calculateSingleRating(ds, achievement);
    if (ra >= targetRa) {
      minAchievement = achievement;
      break; // 找到第一个能达到目标Rating的分数点
    }
  }
  
  return minAchievement;
}

/**
 * 生成推荐结果所需的分数点
 * @param ds 谱面定数
 * @param currentAchievement 当前达成率
 * @return 分数点列表，包含100-100.5%之间的最多2个值，以及100.5%
 */
List<double> generateAchievementPoints(double ds, double currentAchievement) {
  List<double> points = [];
  
  // 计算100%对应的Rating
  int raAt100 = calculateSingleRating(ds, 100.0);
  
  // 计算100-100.5%之间的点
  int additionalPoints = 0;
  double currentPoint = currentAchievement + 0.001; // 确保大于当前达成率
  
  // 确保起点不低于100.0
  if (currentPoint < 100.0) {
    currentPoint = 100.0;
  }
  
  // 尝试找到第一个点（Rating比100%高1）
  while (currentPoint < 100.5 && additionalPoints < 2) {
    currentPoint += 0.001;
    int currentRa = calculateSingleRating(ds, currentPoint);
    if (currentRa == raAt100 + 1) {
      points.add(currentPoint);
      additionalPoints++;
    } else if (currentRa > raAt100 + 1) {
      break;
    }
  }
  
  // 尝试找到第二个点（Rating比100%高2）
  if (additionalPoints < 2) {
    while (currentPoint < 100.5) {
      currentPoint += 0.001;
      int currentRa = calculateSingleRating(ds, currentPoint);
      if (currentRa == raAt100 + 2) {
        points.add(currentPoint);
        additionalPoints++;
        break;
      } else if (currentRa > raAt100 + 2) {
        break;
      }
    }
  }
  
  // 100.5% 达成率
  double hundredPointFive = 100.5;
  if (hundredPointFive > currentAchievement) {
    points.add(hundredPointFive);
  }
  
  return points;
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
    // 初始化标签数据
    await MaiTagsManager().initializeTags();
    print('标签数据初始化完成');

    // 使用已经筛选的单曲Rating最高的70个谱面
    List<RecordItem> userPlayDataRecords = await getUserPlayDataRecords();
    print('获取到 ${userPlayDataRecords.length} 条玩家游玩记录');

    List<RecordItem> filteredRecords = 
        filterRecordsByRating(userPlayDataRecords);
    print('筛选后得到 ${filteredRecords.length} 条记录');

    // 根据Best70标签的出现频率计算玩家的能力向量(3个向量)
    Map<String, Map<String, double>> playerAbilityVectors = 
        await calculatePlayerAbilityVectors(filteredRecords);
    print('计算得到玩家能力向量: ${playerAbilityVectors.keys.toList()}');

    // 获取玩家的过往版本中的Best55和当前版本中的Best15
    List<RecordItem> best55 = 
        await getBestNRecords(userPlayDataRecords, 55, false);
    print('获取到 ${best55.length} 条Best55记录');

    List<RecordItem> best15 = 
        await getBestNRecords(userPlayDataRecords, 15, true);
    print('获取到 ${best15.length} 条Best15记录');

    // 计算过往版本中的Best35用于判断Best55推荐结果是否能够增长总Rating
    List<RecordItem> best35 = 
        await getBestNRecords(userPlayDataRecords, 35, false);
    print('获取到 ${best35.length} 条Best35记录');

    // 获取Rating范围
    int best55minRating = 0;
    int best55maxRating = 0;
    (best55minRating, best55maxRating) = getRaRange(best55);
    print('Best55 Rating范围: $best55minRating - $best55maxRating');

    int best15minRating = 0;
    int best15maxRating = 0;
    (best15minRating, best15maxRating) = getRaRange(best15);
    print('Best15 Rating范围: $best15minRating - $best15maxRating');

    int best35minRating = 0;
    int best35maxRating = 0;
    (best35minRating, best35maxRating) = getRaRange(best35);
    print('Best35 Rating范围: $best35minRating - $best35maxRating');

    // 获取定数范围
    double best55minDs = 0.0;
    double best55maxDs = 0.0;
    (best55minDs, best55maxDs) = 
        getDifficultyRange(best55minRating, best55maxRating);
    print('Best55 定数范围: $best55minDs - $best55maxDs');

    double best15minDs = 0.0;
    double best15maxDs = 0.0;
    (best15minDs, best15maxDs) = 
        getDifficultyRange(best15minRating, best15maxRating);
    print('Best15 定数范围: $best15minDs - $best15maxDs');

    // 并行计算推荐结果，提高性能
    final Future<List<RecommendationResult>> best55Future = 
        calculateRecommendations(
            userPlayDataRecords,
            playerAbilityVectors,
            best55minDs,
            best55maxDs,
            best55minRating,
            best55maxRating,
            best35minRating,
            best35maxRating,
            false);

    final Future<List<RecommendationResult>> best15Future = 
        calculateRecommendations(
            userPlayDataRecords,
            playerAbilityVectors,
            best15minDs,
            best15maxDs,
            best15minRating,
            best15maxRating,
            best35minRating,
            best35maxRating,
            true);

    // 等待两个计算完成
    final best55Recommendations = await best55Future;
    print('计算得到 ${best55Recommendations.length} 条Best55推荐结果');
    best55Recommendations.sort((a, b) => b.similarity.compareTo(a.similarity));

    final best15Recommendations = await best15Future;
    print('计算得到 ${best15Recommendations.length} 条Best15推荐结果');
    best15Recommendations.sort((a, b) => b.similarity.compareTo(a.similarity));

    // 保存推荐结果到缓存
    try {
      final prefs = await SharedPreferences.getInstance();
      final resultMap = {
        'Best55': best55Recommendations.map((r) => r.toJson()).toList(),
        'Best15': best15Recommendations.map((r) => r.toJson()).toList(),
      };
      final resultJson = json.encode(resultMap);
      await prefs.setString(RecommendByTagsService.RECOMMENDATION_CACHE_KEY, resultJson);
      print('推荐结果已保存到缓存');
    } catch (e) {
      print('保存推荐结果到缓存失败: $e');
    }

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