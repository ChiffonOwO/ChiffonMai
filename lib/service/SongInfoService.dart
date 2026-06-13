import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mysql1/mysql1.dart';
import '../api/ApiUrls.dart';
import '../api/DeveloperToken.dart';
import '../constant/CacheKeyConstant.dart';
import '../constant/CacheTimestampConstant.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_first_flutter_app/manager/DivingFish/MaimaiMusicDataManager.dart';
import 'package:my_first_flutter_app/manager/DivingFish/UserPlayDataManager.dart';
import 'package:my_first_flutter_app/manager/DivingFish/DiffMusicDataManager.dart';
import 'package:my_first_flutter_app/manager/LuoXue/CollectionsManager.dart';
import 'package:my_first_flutter_app/manager/MaiTagsManager.dart';
import 'package:my_first_flutter_app/entity/LuoXue/Collection.dart';
import 'package:url_launcher/url_launcher.dart';

// 评论数据模型
class CommentItem {
  final int id;
  final String songId;
  final int? levelIndex;
  final String userId;
  final String dataSource;
  final String originalId;
  final String? nickname;
  final String content;
  final String? createdAt;

  CommentItem({
    required this.id,
    required this.songId,
    this.levelIndex,
    required this.userId,
    required this.dataSource,
    required this.originalId,
    this.nickname,
    required this.content,
    this.createdAt,
  });

  factory CommentItem.fromJson(Map<String, dynamic> json) {
    return CommentItem(
      id: json['id'] ?? 0,
      songId: json['songId'] ?? json['song_id'] ?? '',
      levelIndex: json['levelIndex'] ?? json['level_index'],
      userId: json['userId'] ?? json['user_id'] ?? '',
      dataSource: json['dataSource'] ?? json['data_source'] ?? '',
      originalId: json['originalId'] ?? json['original_id'] ?? '',
      nickname: json['nickname'],
      content: json['content'] ?? '',
      createdAt: json['createdAt'] ?? json['created_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'songId': songId,
      'levelIndex': levelIndex,
      'userId': userId,
      'dataSource': dataSource,
      'originalId': originalId,
      'nickname': nickname,
      'content': content,
      'createdAt': createdAt,
    };
  }
}

// 评论身份信息模型
class CommentIdentity {
  final String dataSource;
  final String originalId;
  final String? nickname;

  CommentIdentity({
    required this.dataSource,
    required this.originalId,
    this.nickname,
  });
}

class SongInfoService {
  // 单例实例
  static final SongInfoService _instance = SongInfoService._internal();

  // 工厂构造函数
  factory SongInfoService() {
    return _instance;
  }

  // 私有构造函数
  SongInfoService._internal();

  // 舞萌DX 完成度-评级-乘数对照表
  final List<Map<String, dynamic>> maimaiRatingMultiplier = [
    {"completion": 100.5, "rating": "SSS+", "multiplier": 0.224},
    {"completion": 100.4999, "rating": "SSS", "multiplier": 0.222},
    {"completion": 100.0, "rating": "SSS", "multiplier": 0.216},
    {"completion": 99.9999, "rating": "SS+", "multiplier": 0.214},
    {"completion": 99.5, "rating": "SS+", "multiplier": 0.211},
    {"completion": 99.0, "rating": "SS", "multiplier": 0.208},
    {"completion": 98.9999, "rating": "S+", "multiplier": 0.206},
    {"completion": 98.0, "rating": "S+", "multiplier": 0.203},
    {"completion": 97.0, "rating": "S", "multiplier": 0.2},
    {"completion": 96.9999, "rating": "AAA", "multiplier": 0.176},
    {"completion": 94.0, "rating": "AAA", "multiplier": 0.168},
    {"completion": 90.0, "rating": "AA", "multiplier": 0.152},
    {"completion": 80.0, "rating": "A", "multiplier": 0.136},
    {"completion": 79.9999, "rating": "BBB", "multiplier": 0.128},
    {"completion": 75.0, "rating": "BBB", "multiplier": 0.120},
    {"completion": 70.0, "rating": "BB", "multiplier": 0.112},
    {"completion": 60.0, "rating": "B", "multiplier": 0.096},
    {"completion": 50.0, "rating": "C", "multiplier": 0.08},
  ];

  // 加载所有数据
  Future<Map<String, dynamic>> loadData(String songId) async {
    Map<String, dynamic> result = {
      'songData': null,
      'diffData': null,
      'userData': null,
      'tagData': null,
      'tagSongsData': null,
    };

    try {
      // 加载歌曲基础数据
      if (await MaimaiMusicDataManager().hasCachedData()) {
        final songs = await MaimaiMusicDataManager().getCachedSongs();
        if (songs != null) {
          final songIndex = songs.indexWhere((s) => s.id == songId);
          if (songIndex != -1) {
            final song = songs[songIndex];
            // 计算 shortId（去掉前导零的歌曲ID）
            String shortId = song.id.replaceFirst(RegExp(r'^0+'), '');

            result['songData'] = {
              'id': song.id,
              'title': song.title,
              'type': song.type,
              'ds': song.ds,
              'level': song.level,
              'cids': song.cids,
              'shortId': shortId,
              'charts': song.charts
                  .map((chart) =>
                      {'notes': chart.notes, 'charter': chart.charter})
                  .toList(),
              'basic_info': {
                'title': song.basicInfo.title,
                'artist': song.basicInfo.artist,
                'genre': song.basicInfo.genre,
                'bpm': song.basicInfo.bpm,
                'release_date': song.basicInfo.releaseDate,
                'from': song.basicInfo.from,
                'is_new': song.basicInfo.isNew,
                'short_id': shortId
              }
            };
          }
        }
      }

      // 加载难度数据
      final diffManager = DiffMusicDataManager();
      final diffSong = await diffManager.getCachedDiffData();
      if (diffSong != null) {
        result['diffData'] = diffSong.charts[songId];
      }

      // 加载用户数据
      final userPlayDataManager = UserPlayDataManager();
      result['userData'] = await userPlayDataManager.getCachedUserPlayData();

      // 加载标签数据
      final maiTagsManager = MaiTagsManager();
      final tagsEntity = await maiTagsManager.getTags();
      if (tagsEntity != null) {
        result['tagData'] = tagsEntity.tags
            .map((tag) => {
                  'id': tag.id,
                  'name': tag.localizedName.zhHans,
                  'description': tag.localizedDescription.zhHans,
                  'group_id': tag.groupId
                })
            .toList();
        result['tagSongsData'] = tagsEntity.tagSongs
            .map((tagSong) => {
                  'song_id': tagSong.songId,
                  'sheet_type': tagSong.sheetType,
                  'sheet_difficulty': tagSong.sheetDifficulty,
                  'tag_id': tagSong.tagId
                })
            .toList();
      }
    } catch (e) {
      debugPrint('加载数据失败: $e');
    }

    return result;
  }

  // 获取用户最佳成绩
  Map<String, dynamic>? getUserBestRecord(
      Map<String, dynamic>? userData, String songId, int currentDiffIndex) {
    if (userData == null) return null;

    final records = userData['records'];
    if (records == null) return null;

    // 找到对应歌曲的记录
    final songRecord = records
        .where((record) =>
            record['song_id'].toString() == songId &&
            record['level_index'].toString() == currentDiffIndex.toString())
        .toList();

    return songRecord.isNotEmpty ? songRecord.first : null;
  }

  // 获取标签分组
  Map<String, List<dynamic>> getTagsByGroup(
      List<dynamic>? tagData,
      List<dynamic>? tagSongsData,
      Map<String, dynamic>? songData,
      int currentDiffIndex) {
    final Map<String, List<dynamic>> groupedTags = {
      '配置': [],
      '评价': [],
      '难度': []
    };

    if (tagData != null && tagSongsData != null && songData != null) {
      // 获取当前曲目的相关信息
      final String songTitle = songData['basic_info']['title'];
      final String songType = songData['type'];
      final String sheetType = songType == 'DX' ? 'dx' : 'std';

      // 映射难度索引到sheet_difficulty
      String sheetDifficulty = _getSheetDifficulty(currentDiffIndex);

      // 过滤出当前曲目的当前难度的标签ID
      final List<int> tagIds = tagSongsData
          .where((item) =>
              item['song_id'] == songTitle &&
              item['sheet_type'] == sheetType &&
              item['sheet_difficulty'] == sheetDifficulty)
          .map((item) => item['tag_id'] as int)
          .toList();

      // 根据标签ID获取标签详情
      for (int tagId in tagIds) {
        final tag =
            tagData.firstWhere((t) => t['id'] == tagId, orElse: () => null);

        if (tag != null) {
          int groupId = tag['group_id'] ?? 0;
          String groupName = _getGroupName(groupId);

          if (groupedTags.containsKey(groupName)) {
            groupedTags[groupName]!.add(tag);
          }
        }
      }
    }

    return groupedTags;
  }

  // 根据难度索引获取主题颜色
  Color getThemeColor(int diffIndex, Map<String, dynamic>? songData) {
    // 检查难度数量
    int difficultyCount = 0;
    if (songData != null && songData['level'] != null) {
      difficultyCount = songData['level'].length;
    }

    // 对于只有1或2个难度的歌曲，所有难度的背景全部采用粉色
    if (difficultyCount <= 2) {
      return Color(0xFFE9D8FF); // Master难度的颜色
    }

    switch (diffIndex) {
      case 0: // Basic
        return Color(0xFFE8F5E8); // 浅绿色
      case 1: // Advan
        return Color(0xFFFFF8E1); // 浅黄色
      case 2: // Expert
        return Color(0xFFFCE4EC); // 浅红色
      case 3: // Master
        return Color(0xFFE9D8FF); // 当前颜色不变
      case 4: // Re:MASTER
        return Color(0xFFF3E5F5); // 浅粉色
      default:
        return Color(0xFFE9D8FF);
    }
  }

  // 根据难度索引获取次要主题颜色
  Color getSecondaryThemeColor(int diffIndex, Map<String, dynamic>? songData) {
    // 检查难度数量
    int difficultyCount = 0;
    if (songData != null && songData['level'] != null) {
      difficultyCount = songData['level'].length;
    }

    // 对于只有1或2个难度的歌曲，所有难度的背景全部采用粉色
    if (difficultyCount <= 2) {
      return Color(0xFFD4BFFF); // Master难度的颜色
    }

    switch (diffIndex) {
      case 0: // Basic
        return Color(0xFFC8E6C9); // 浅绿色
      case 1: // Advan
        return Color(0xFFFFE0B2); // 浅黄色
      case 2: // Expert
        return Color(0xFFF8BBD0); // 浅红色
      case 3: // Master
        return Color(0xFFD4BFFF); // 当前颜色不变
      case 4: // Re:MASTER
        return Color(0xFFE1BEE7); // 浅粉色
      default:
        return Color(0xFFD4BFFF);
    }
  }

  // 根据难度索引获取强调颜色
  Color getAccentColor(int diffIndex, Map<String, dynamic>? songData) {
    // 检查难度数量
    int difficultyCount = 0;
    if (songData != null && songData['level'] != null) {
      difficultyCount = songData['level'].length;
    }

    // 对于只有1或2个难度的歌曲，所有难度的背景全部采用粉色
    if (difficultyCount <= 2) {
      return Color(0xFF9966CC); // Master难度的颜色
    }

    switch (diffIndex) {
      case 0: // Basic
        return Color(0xFF4CAF50); // 绿色
      case 1: // Advan
        return Color(0xFFFF9800); // 橙色
      case 2: // Expert
        return Color(0xFFE91E63); // 红色
      case 3: // Master
        return Color(0xFF9966CC); // 当前颜色不变
      case 4: // Re:MASTER
        return Color(0xFF9C27B0); // 紫色
      default:
        return Color(0xFF9966CC);
    }
  }

  // 计算单曲Rating
  int calculateSingleRating(double difficulty, double completion) {
    // 特别处理：如果达成率大于100.5，则按100.5计算
    double adjustedCompletion = completion > 100.5 ? 100.5 : completion;
    double calculationCompletion = completion > 100.5 ? 100.5 : completion;

    // 查找对应的评级和乘数
    Map<String, dynamic>? selectedRating;

    // 遍历表格查找正确的区间
    for (var item in maimaiRatingMultiplier) {
      if (adjustedCompletion >= item['completion']) {
        selectedRating = item;
        break;
      }
    }

    // 如果没有找到（不应该发生），使用默认值
    selectedRating ??= {"rating": "D", "multiplier": 0.016};

    double multiplier = selectedRating['multiplier'];

    // 计算单曲Rating
    double singleRating = difficulty * multiplier * calculationCompletion;
    return singleRating.floor(); // 取整数部分（向下取整）
  }

  // 计算maxScore
  int calculateMaxScore(Map<String, dynamic>? songData, int levelIndex) {
    if (songData == null) return 0;

    // 查找对应的charts
    List<dynamic> charts = songData['charts'];
    if (levelIndex < 0 || levelIndex >= charts.length) return 0;

    dynamic chart = charts[levelIndex];
    if (chart['notes'] == null) return 0;

    // 计算maxScore
    List<dynamic> notes = chart['notes'];
    int notesSum = notes.fold(0, (sum, note) => sum + (note as int));
    return notesSum * 3;
  }

  // 计算最大DX分
  // 当ds数组长度为2时，返回两个难度谱面DX分之和
  // 否则返回当前难度的最大分数
  int calculateMaxDxScore(
      Map<String, dynamic>? songData, int songId, int levelIndex) {
    if (songData == null) return 0;

    // 检查ds数组长度
    List<dynamic> ds = songData['ds'];
    if (ds.length == 2) {
      // 计算两个难度谱面的最大分数之和
      int maxScore1 = calculateMaxScore(songData, 0);
      int maxScore2 = calculateMaxScore(songData, 1);
      return maxScore1 + maxScore2;
    } else {
      // 返回当前难度的最大分数
      return calculateMaxScore(songData, levelIndex);
    }
  }

  // 计算scoreRate
  double calculateScoreRate(
      Map<String, dynamic>? songData, int songId, int levelIndex, int score) {
    int maxScore = calculateMaxDxScore(songData, songId, levelIndex);
    return maxScore > 0 ? score / maxScore : 0.0;
  }

  // 计算星星等级
  String calculateStars(
      Map<String, dynamic>? songData, int songId, int levelIndex, int score) {
    double scoreRate = calculateScoreRate(songData, songId, levelIndex, score);

    // 确定星星等级
    if (scoreRate >= 0.97) {
      return '\u2726 5';
    } else if (scoreRate >= 0.95) {
      return '\u2726 4';
    } else if (scoreRate >= 0.93) {
      return '\u2726 3';
    } else if (scoreRate >= 0.90) {
      return '\u2726 2';
    } else if (scoreRate >= 0.85) {
      return '\u2726 1';
    } else {
      return '\u2726 0';
    }
  }

  // 计算星星等级的最低DX分和超出部分
  String calculateStarsBonus(
      Map<String, dynamic>? songData, int songId, int levelIndex, int score) {
    int maxScore = calculateMaxDxScore(songData, songId, levelIndex);
    double scoreRate = score / maxScore;
    int starLevel = 0;
    double minRate = 0.0;

    // 确定当前星星等级和对应的最低达成率
    if (scoreRate >= 0.97) {
      starLevel = 5;
      minRate = 0.97;
    } else if (scoreRate >= 0.95) {
      starLevel = 4;
      minRate = 0.95;
    } else if (scoreRate >= 0.93) {
      starLevel = 3;
      minRate = 0.93;
    } else if (scoreRate >= 0.90) {
      starLevel = 2;
      minRate = 0.90;
    } else if (scoreRate >= 0.85) {
      starLevel = 1;
      minRate = 0.85;
    } else {
      starLevel = 0;
      minRate = 0.85; // 0星时计算与1星的差距
    }

    // 计算最低DX分（向上取整）
    int minScore = (maxScore * minRate).ceil();
    // 计算超出部分或差距
    int difference = score - minScore;
    String symbol = difference >= 0 ? '+' : '';

    // 0星时显示1星的差距
    int displayStarLevel = starLevel == 0 ? 1 : starLevel;

    return '\u2726 $displayStarLevel $symbol$difference';
  }

  // 获取星星颜色
  Color getStarsColor(String stars) {
    switch (stars) {
      case '\u2726 5':
        return Colors.yellow;
      case '\u2726 4':
      case '\u2726 3':
        return Colors.orange;
      case '\u2726 2':
      case '\u2726 1':
        return Colors.green.shade300;
      case '\u2726 0':
        return Colors.grey;
      default:
        return Colors.white;
    }
  }

  // 跳转到B站
  Future<void> jumpToBilibili(String songTitle, int currentDiffIndex) async {
    final diffLabel = getDiffLabel(currentDiffIndex, null);
    final searchQuery = '$songTitle $diffLabel';

    // B站搜索链接
    final url = Uri.parse(
        'bilibili://search?keyword=${Uri.encodeComponent(searchQuery)}');

    // 尝试打开B站应用
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      // 如果无法打开B站应用，尝试在浏览器中打开
      final webUrl = Uri.parse(
          'https://search.bilibili.com/all?keyword=${Uri.encodeComponent(searchQuery)}');
      if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl);
      }
    }
  }

  // 查看相关收藏品
  Future<List<Map<String, dynamic>>> fetchRelatedCollections(
      String songTitle, String songType) async {
    try {
      // 获取所有收藏品数据
      final collectionsManager = CollectionsManager();
      final trophiesData = await collectionsManager.fetchTrophiesCollections();
      final iconsData = await collectionsManager.fetchIconsCollections();
      final platesData = await collectionsManager.fetchPlatesCollections();
      final framesData = await collectionsManager.fetchFramesCollections();

      // 查找与歌曲相关的收藏品
      return findRelatedCollections(
        songTitle,
        songType,
        trophiesData,
        iconsData,
        platesData,
        framesData,
      );
    } catch (e) {
      debugPrint('获取相关收藏品时出错: $e');
      return [];
    }
  }

  // 查找与歌曲相关的收藏品
  List<Map<String, dynamic>> findRelatedCollections(
    String songTitle,
    String songType,
    CollectionData? trophiesData,
    CollectionData? iconsData,
    CollectionData? platesData,
    CollectionData? framesData,
  ) {
    final List<Map<String, dynamic>> relatedCollections = [];

    // 检查奖杯
    if (trophiesData?.trophies != null) {
      for (var trophy in trophiesData!.trophies!) {
        if (isRelatedToSong(trophy, songTitle, songType)) {
          relatedCollections.add({
            'type': 'trophies',
            'name': trophy.name,
            'description': trophy.description,
            'collection': trophy,
          });
        }
      }
    }

    // 检查图标
    if (iconsData?.icons != null) {
      for (var icon in iconsData!.icons!) {
        if (isRelatedToSong(icon, songTitle, songType)) {
          relatedCollections.add({
            'type': 'icons',
            'name': icon.name,
            'description': icon.description,
            'collection': icon,
          });
        }
      }
    }

    // 检查铭牌
    if (platesData?.plates != null) {
      for (var plate in platesData!.plates!) {
        if (isRelatedToSong(plate, songTitle, songType)) {
          relatedCollections.add({
            'type': 'plates',
            'name': plate.name,
            'description': plate.description,
            'collection': plate,
          });
        }
      }
    }

    // 检查框架
    if (framesData?.frames != null) {
      for (var frame in framesData!.frames!) {
        if (isRelatedToSong(frame, songTitle, songType)) {
          relatedCollections.add({
            'type': 'frames',
            'name': frame.name,
            'description': frame.description,
            'collection': frame,
          });
        }
      }
    }

    return relatedCollections;
  }

  // 判断收藏品是否与歌曲相关
  bool isRelatedToSong(
      Collection collection, String songTitle, String songType) {
    // 检查 required 集合中是否有任何一个元素的 songs 集合中包含与当前歌曲标题和类型匹配的条目
    if (collection.required != null) {
      for (var requiredItem in collection.required!) {
        if (requiredItem.songs != null) {
          for (var song in requiredItem.songs!) {
            // 映射收藏品类型：standard -> SD
            String mappedCollectionType =
                song.type.toLowerCase() == 'standard' ? 'SD' : song.type;
            if (song.title.toLowerCase() == songTitle.toLowerCase() &&
                mappedCollectionType.toLowerCase() == songType.toLowerCase()) {
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  // 获取难度标签
  String getDiffLabel(int index, Map<String, dynamic>? songData) {
    // 检查难度数量
    int difficultyCount = 0;
    if (songData != null && songData['level'] != null) {
      difficultyCount = songData['level'].length;
    }

    // 如果难度数量≤2个，显示"U\u00b7TA\u00b7GE​"
    if (difficultyCount <= 2) {
      return 'U\u00b7TA\u00b7GE​';
    }

    // 否则返回原来的标签
    switch (index) {
      case 0:
        return 'Basic';
      case 1:
        return 'Advan';
      case 2:
        return 'Expert';
      case 3:
        return 'Master';
      case 4:
        return 'Re:MAS';
      default:
        return '';
    }
  }

  // 获取收藏品类型名称
  String getCollectionTypeName(String type) {
    switch (type) {
      case 'trophies':
        return '称号';
      case 'icons':
        return '头像';
      case 'plates':
        return '姓名框';
      case 'frames':
        return '背景';
      default:
        return '未知类型';
    }
  }

  // 获取收藏品类型颜色
  Color getCollectionTypeColor(String type) {
    switch (type) {
      case 'trophies':
        return Colors.orange;
      case 'icons':
        return Colors.blue;
      case 'plates':
        return Colors.green;
      case 'frames':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  // 获取标签颜色
  Color getTagColor(String group) {
    switch (group) {
      case '配置':
        return Color(0xFFE8F4F8);
      case '评价':
        return Color(0xFFFFF3E0);
      case '难度':
        return Color(0xFFFCE4EC);
      default:
        return Color(0xFFF0E6FF);
    }
  }

  // 获取标签边框颜色
  Color getTagBorderColor(String group) {
    switch (group) {
      case '配置':
        return Color(0xFFD1E7DD);
      case '评价':
        return Color(0xFFFFE0B2);
      case '难度':
        return Color(0xFFF8BBD0);
      default:
        return Color(0xFFE0D0FF);
    }
  }

  // 获取标签文本颜色
  Color getTagTextColor(String group) {
    switch (group) {
      case '配置':
        return Color(0xFF388E3C);
      case '评价':
        return Color(0xFFF57C00);
      case '难度':
        return Color(0xFFD81B60);
      default:
        return Color(0xFF664499);
    }
  }

  // 辅助方法：获取sheet_difficulty
  String _getSheetDifficulty(int diffIndex) {
    switch (diffIndex) {
      case 0:
        return 'basic';
      case 1:
        return 'advanced';
      case 2:
        return 'expert';
      case 3:
        return 'master';
      case 4:
        return 'remaster';
      default:
        return 'master';
    }
  }

  // 辅助方法：获取分组名称
  String _getGroupName(int groupId) {
    switch (groupId) {
      case 1:
        return '配置';
      case 2:
        return '难度';
      case 3:
        return '评价';
      default:
        return '配置';
    }
  }

  // ============== 歌曲评论相关方法 ==============

  // 生成唯一用户ID（与服务器端保持一致: dataSource:originalId）
  static String generateUserId(String dataSource, String originalId) {
    return '$dataSource:$originalId';
  }

  // 获取评论者身份信息（与SongRankingService.getCurrentPlayerId()对齐）
  static Future<CommentIdentity?> getCommentIdentity() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. 优先尝试从已保存的评论身份键读取（兼容旧版手动输入）
    final savedDataSource = prefs.getString(CacheKeyConstant.commentDataSource);
    final savedOriginalId = prefs.getString(CacheKeyConstant.commentOriginalId);
    if (savedDataSource != null && savedOriginalId != null) {
      final savedNickname = prefs.getString(CacheKeyConstant.commentNickname);
      return CommentIdentity(
        dataSource: savedDataSource,
        originalId: savedOriginalId,
        nickname: savedNickname,
      );
    }

    // 2. 自动从HomePage缓存的用户数据构建（与SongRankingService.getCurrentPlayerId()一致）
    // 优先落雪，其次水鱼
    String? luoxueUserId = prefs.getString(CacheKeyConstant.luoxueUserId);
    if (luoxueUserId != null && luoxueUserId.isNotEmpty) {
      final parts = luoxueUserId.split(':');
      if (parts.length >= 2) {
        return CommentIdentity(
          dataSource: 'luoxue',
          originalId: parts.sublist(1).join(':'), // 兼容ID中包含冒号的情况
          nickname: prefs.getString(CacheKeyConstant.userNickname),
        );
      }
    }

    String? shuiyuUserId = prefs.getString(CacheKeyConstant.shuiyuUserId);
    if (shuiyuUserId != null && shuiyuUserId.isNotEmpty) {
      final parts = shuiyuUserId.split(':');
      if (parts.length >= 2) {
        return CommentIdentity(
          dataSource: 'shuiyu',
          originalId: parts.sublist(1).join(':'),
          nickname: prefs.getString(CacheKeyConstant.userNickname),
        );
      }
    }

    return null;
  }

  // 保存评论者身份信息到本地prefs
  static Future<void> saveCommentIdentity(
      String dataSource, String originalId, String? nickname) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(CacheKeyConstant.commentDataSource, dataSource);
    await prefs.setString(CacheKeyConstant.commentOriginalId, originalId);
    if (nickname != null) {
      await prefs.setString(CacheKeyConstant.commentNickname, nickname);
    }
  }

  // 清除评论者身份信息
  static Future<void> clearCommentIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(CacheKeyConstant.commentDataSource);
    await prefs.remove(CacheKeyConstant.commentOriginalId);
    await prefs.remove(CacheKeyConstant.commentNickname);
  }

  // 获取指定歌曲的评论列表（带缓存）
  static Future<List<CommentItem>> getCommentsForSong(String songId,
      {int? levelIndex,
      int? limit,
      bool forceRefresh = false,
      bool serverRefresh = false}) async {
    // 先检查缓存
    if (!forceRefresh) {
      final cachedData =
          await _getCachedComments(songId, levelIndex: levelIndex);
      if (cachedData != null) {
        debugPrint(
            'SongInfoService: 使用缓存的评论数据，songId=$songId，levelIndex=$levelIndex，数量=${cachedData.length}');
        return cachedData;
      }
    }

    try {
      String url = '${ApiUrls.CommentsBySongUrl}/$songId';
      final queryParams = <String>[];
      if (levelIndex != null) {
        queryParams.add('levelIndex=$levelIndex');
      }
      if (limit != null) {
        queryParams.add('limit=$limit');
      }
      if (serverRefresh) {
        queryParams.add('refresh=true');
      }
      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
      }
      debugPrint('SongInfoService: 从服务器获取评论，url=$url');

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          final List<dynamic> dataList = result['data'] ?? [];
          final items =
              dataList.map((item) => CommentItem.fromJson(item)).toList();

          // 保存到缓存
          await _cacheComments(songId, items, levelIndex: levelIndex);
          debugPrint('SongInfoService: 获取评论成功，数量=${items.length}');
          return items;
        }
      }

      debugPrint('SongInfoService: 获取评论失败，statusCode=${response.statusCode}');
    } catch (e) {
      debugPrint('SongInfoService: 获取歌曲评论异常: $e');
    }

    // 失败时尝试返回缓存数据
    final cachedData = await _getCachedComments(songId, levelIndex: levelIndex);
    if (cachedData != null) {
      return cachedData;
    }
    return [];
  }

  // 创建新评论
  static Future<Map<String, dynamic>> createComment({
    required String songId,
    int? levelIndex,
    required String dataSource,
    required String originalId,
    String? nickname,
    required String content,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiUrls.CommentsCreateUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'songId': songId,
          'levelIndex': levelIndex,
          'dataSource': dataSource,
          'originalId': originalId,
          'nickname': nickname,
          'content': content,
        }),
      );

      debugPrint('SongInfoService: 创建评论，statusCode=${response.statusCode}');

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          // 保存身份信息到本地
          await saveCommentIdentity(dataSource, originalId, nickname);

          // 清除该歌曲该难度的评论缓存
          await _clearCommentsCache(songId, levelIndex: levelIndex);

          debugPrint('SongInfoService: 评论创建成功');
          return {
            'success': true,
            'message': result['message'] ?? '评论创建成功',
            'comment': result['comment'] != null
                ? CommentItem.fromJson(result['comment'])
                : null,
          };
        }
        return {
          'success': false,
          'message': result['error'] ?? '评论创建失败',
        };
      }
      final errorResult = json.decode(response.body);
      return {
        'success': false,
        'message': errorResult['error'] ?? '评论创建失败 (${response.statusCode})',
      };
    } catch (e) {
      debugPrint('SongInfoService: 创建评论异常: $e');
      return {
        'success': false,
        'message': '网络连接异常: $e',
      };
    }
  }

  // 删除评论
  static Future<Map<String, dynamic>> deleteComment({
    required int commentId,
    required String songId,
    int? levelIndex,
    required String dataSource,
    required String originalId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiUrls.CommentsBaseUrl}/$commentId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'dataSource': dataSource,
          'originalId': originalId,
        }),
      );

      debugPrint(
          'SongInfoService: 删除评论，commentId=$commentId，statusCode=${response.statusCode}');

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          // 清除该歌曲该难度的评论缓存
          await _clearCommentsCache(songId, levelIndex: levelIndex);
          return {
            'success': true,
            'message': result['message'] ?? '评论删除成功',
          };
        }
        return {
          'success': false,
          'message': result['error'] ?? '评论删除失败',
        };
      }
      final errorResult = json.decode(response.body);
      return {
        'success': false,
        'message': errorResult['error'] ?? '评论删除失败 (${response.statusCode})',
      };
    } catch (e) {
      debugPrint('SongInfoService: 删除评论异常: $e');
      return {
        'success': false,
        'message': '网络连接异常: $e',
      };
    }
  }

  // ============== 评论缓存相关私有方法 ==============

  // 从缓存获取评论数据
  static Future<List<CommentItem>?> _getCachedComments(String songId,
      {int? levelIndex}) async {
    final prefs = await SharedPreferences.getInstance();
    final suffix = levelIndex != null ? '${songId}_$levelIndex' : songId;
    final cacheKey = '${CacheKeyConstant.songCommentsCachePrefix}$suffix';
    final timestampKey =
        '${CacheKeyConstant.songCommentsCacheTimestampPrefix}$suffix';
    final timestamp = prefs.getInt(timestampKey);

    if (timestamp != null) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (now - timestamp < CacheTimestampConstant.songCommentsCacheSeconds) {
        final cachedJson = prefs.getString(cacheKey);
        if (cachedJson != null) {
          try {
            final List<dynamic> data = json.decode(cachedJson);
            return data.map((item) => CommentItem.fromJson(item)).toList();
          } catch (e) {
            debugPrint('SongInfoService: 解析缓存评论数据失败: $e');
          }
        }
      }
    }
    return null;
  }

  // 保存评论数据到缓存
  static Future<void> _cacheComments(String songId, List<CommentItem> items,
      {int? levelIndex}) async {
    final prefs = await SharedPreferences.getInstance();
    final suffix = levelIndex != null ? '${songId}_$levelIndex' : songId;
    final cacheKey = '${CacheKeyConstant.songCommentsCachePrefix}$suffix';
    final timestampKey =
        '${CacheKeyConstant.songCommentsCacheTimestampPrefix}$suffix';
    try {
      final jsonString =
          json.encode(items.map((item) => item.toJson()).toList());
      await prefs.setString(cacheKey, jsonString);
      await prefs.setInt(
          timestampKey, DateTime.now().millisecondsSinceEpoch ~/ 1000);
    } catch (e) {
      debugPrint('SongInfoService: 保存评论缓存失败: $e');
    }
  }

  // 清除指定歌曲的评论缓存
  static Future<void> _clearCommentsCache(String songId,
      {int? levelIndex}) async {
    final prefs = await SharedPreferences.getInstance();
    final suffix = levelIndex != null ? '${songId}_$levelIndex' : songId;
    final cacheKey = '${CacheKeyConstant.songCommentsCachePrefix}$suffix';
    final timestampKey =
        '${CacheKeyConstant.songCommentsCacheTimestampPrefix}$suffix';
    await prefs.remove(cacheKey);
    await prefs.remove(timestampKey);
  }

  // 清除所有歌曲评论缓存
  static Future<void> clearAllCommentsCache() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    for (String key in allKeys) {
      if (key.startsWith(CacheKeyConstant.songCommentsCachePrefix) ||
          key.startsWith(CacheKeyConstant.songCommentsCacheTimestampPrefix)) {
        await prefs.remove(key);
      }
    }
    debugPrint('SongInfoService: 所有歌曲评论缓存已清除');
  }

  // ============== 谱面评分功能 ==============

  // 获取用户当前总Rating（从缓存的Best50数据或游玩数据计算）
  static Future<int> getUserTotalRating() async {
    try {
      final userPlayDataManager = UserPlayDataManager();
      final userPlayData = await userPlayDataManager.getCachedUserPlayData();

      if (userPlayData == null || userPlayData['records'] == null) return 0;

      final records = userPlayData['records'] as List;
      if (records.isEmpty) return 0;

      final songs = await MaimaiMusicDataManager().getCachedSongs();
      if (songs == null) return 0;

      List<Map<String, dynamic>> allRatings = [];

      for (var record in records) {
        String songIdStr = record['song_id'].toString();
        int ra = record['ra'] is int
            ? record['ra']
            : int.tryParse(record['ra'].toString()) ?? 0;

        bool isNew = false;
        try {
          final song = songs.firstWhere((s) => s.id == songIdStr);
          isNew = song.basicInfo.isNew;
        } catch (_) {}

        allRatings.add({
          'ra': ra,
          'is_new': isNew,
        });
      }

      List<Map<String, dynamic>> oldSongs =
          allRatings.where((s) => s['is_new'] == false).toList();
      List<Map<String, dynamic>> newSongs =
          allRatings.where((s) => s['is_new'] == true).toList();

      oldSongs.sort((a, b) => (b['ra'] as int).compareTo(a['ra'] as int));
      newSongs.sort((a, b) => (b['ra'] as int).compareTo(a['ra'] as int));

      int best35 =
          oldSongs.take(35).fold(0, (sum, item) => sum + (item['ra'] as int));
      int best15 =
          newSongs.take(15).fold(0, (sum, item) => sum + (item['ra'] as int));

      return best35 + best15;
    } catch (e) {
      debugPrint('获取用户总Rating失败: $e');
      return 0;
    }
  }

  // 计算理论Rating（所有谱面SSS+时的Best50 Rating）
  static Future<int> getTheoreticalRating() async {
    try {
      final songs = await MaimaiMusicDataManager().getCachedSongs();
      if (songs == null) return 0;

      List<Map<String, dynamic>> allSongs = [];

      for (var song in songs) {
        int songId = int.parse(song.id);
        bool isNew = song.basicInfo.isNew;
        List<dynamic> cids = song.cids;

        bool isMaidataSong = cids.isNotEmpty && cids.every((cid) => cid == 0);
        if (songId >= 100000 || isMaidataSong) continue;

        for (int levelIndex = 0;
            levelIndex < song.charts.length;
            levelIndex++) {
          double ds = song.ds.length > levelIndex
              ? double.parse(song.ds[levelIndex].toString())
              : 0.0;
          int ra = (ds * 0.224 * 100.5).floor();

          allSongs.add({
            'ra': ra,
            'is_new': isNew,
          });
        }
      }

      List<Map<String, dynamic>> oldSongs =
          allSongs.where((s) => s['is_new'] == false).toList();
      List<Map<String, dynamic>> newSongs =
          allSongs.where((s) => s['is_new'] == true).toList();

      oldSongs.sort((a, b) => (b['ra'] as int).compareTo(a['ra'] as int));
      newSongs.sort((a, b) => (b['ra'] as int).compareTo(a['ra'] as int));

      int best35 =
          oldSongs.take(35).fold(0, (sum, item) => sum + (item['ra'] as int));
      int best15 =
          newSongs.take(15).fold(0, (sum, item) => sum + (item['ra'] as int));

      return best35 + best15;
    } catch (e) {
      debugPrint('计算理论Rating失败: $e');
      return 0;
    }
  }

  // 获取谱面评分信息（含加权平均分、用户自己的评分）
  static Future<Map<String, dynamic>> getChartRating({
    required String songId,
    required int levelIndex,
  }) async {
    try {
      final identity = await getCommentIdentity();
      final url = Uri.parse('${ApiUrls.RatingsByChartUrl}/$songId')
          .replace(queryParameters: {
        'levelIndex': levelIndex.toString(),
        if (identity != null)
          'userId': '${identity.dataSource}:${identity.originalId}',
      });
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'success': false, 'error': '获取评分信息失败'};
    } catch (e) {
      debugPrint('获取谱面评分失败: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // 直接从 MySQL 查询用户的谱面评分行（只取 score 和 createdAt）
  static Future<Map<String, dynamic>?> getUserChartRatingFromMySQL({
    required String songId,
    required int levelIndex,
  }) async {
    final identity = await getCommentIdentity();
    if (identity == null) {
      return null;
    }

    final String userId = '${identity.dataSource}:${identity.originalId}';

    MySqlConnection? conn;
    try {
      final settings = ConnectionSettings(
        host: DeveloperToken.MySQLHost,
        port: DeveloperToken.MySQLPort,
        db: DeveloperToken.MySQLDatabase,
        user: DeveloperToken.MySQLUsername,
        password: DeveloperToken.MySQLPassword,
        timeout: const Duration(seconds: 10),
      );

      conn = await MySqlConnection.connect(settings);

      final results = await conn.query(
        'SELECT score, created_at FROM chart_ratings WHERE user_id = ? AND song_id = ? AND level_index = ?',
        [userId, songId, levelIndex],
      );

      if (results.isNotEmpty) {
        final row = results.first;
        return {
          'score': row[0] is num
              ? (row[0] as num).toDouble()
              : (row[0] != null ? double.tryParse(row[0].toString()) : null),
          'createdAt': row[1]?.toString(),
        };
      }

      return null;
    } catch (e) {
      debugPrint('从MySQL获取用户评分失败: $e');
      return null;
    } finally {
      if (conn != null) {
        try {
          await conn.close();
        } catch (_) {}
      }
    }
  }

  // 提交谱面评分（创建或覆盖）
  static Future<Map<String, dynamic>> submitChartRating({
    required String songId,
    required int levelIndex,
    required double score,
    required double achievementRate,
    required int totalRating,
    required int theoreticalRating,
  }) async {
    try {
      final identity = await getCommentIdentity();
      if (identity == null) {
        return {'success': false, 'message': '请先在首页刷新数据以获取用户身份'};
      }

      final url = Uri.parse(ApiUrls.RatingsCreateUrl);
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'songId': songId,
          'levelIndex': levelIndex,
          'dataSource': identity.dataSource,
          'originalId': identity.originalId,
          'score': score,
          'achievementRate': achievementRate,
          'totalRating': totalRating,
          'theoreticalRating': theoreticalRating,
        }),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'success': false, 'message': '提交评分失败'};
    } catch (e) {
      debugPrint('提交谱面评分失败: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // 删除谱面评分
  static Future<Map<String, dynamic>> deleteChartRating({
    required String songId,
    required int levelIndex,
  }) async {
    try {
      final identity = await getCommentIdentity();
      if (identity == null) {
        return {'success': false, 'message': '请先在首页刷新数据以获取用户身份'};
      }

      final url = Uri.parse('${ApiUrls.RatingsDeleteUrl}/$songId/$levelIndex')
          .replace(queryParameters: {
        'userId': '${identity.dataSource}:${identity.originalId}',
      });
      final response = await http.delete(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'dataSource': identity.dataSource,
          'originalId': identity.originalId,
        }),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'success': false, 'message': '删除评分失败'};
    } catch (e) {
      debugPrint('删除谱面评分失败: $e');
      return {'success': false, 'message': e.toString()};
    }
  }
}