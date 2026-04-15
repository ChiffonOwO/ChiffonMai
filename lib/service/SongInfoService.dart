import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_first_flutter_app/manager/MaimaiMusicDataManager.dart';
import 'package:my_first_flutter_app/manager/UserPlayDataManager.dart';
import 'package:my_first_flutter_app/manager/DiffMusicDataManager.dart';
import 'package:my_first_flutter_app/manager/CollectionsManager.dart';
import 'package:my_first_flutter_app/entity/Collection.dart';
import 'package:url_launcher/url_launcher.dart';

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
            result['songData'] = {
              'id': song.id,
              'title': song.title,
              'type': song.type,
              'ds': song.ds,
              'level': song.level,
              'cids': song.cids,
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
                'is_new': song.basicInfo.isNew
              }
            };
          }
        }
      } else {
        // 如果 API 数据不存在，尝试从资产文件加载 JSON 数据作为 fallback
        final songData = await rootBundle.loadString('assets/maimai_music_data.json');
        final List<dynamic> songList = json.decode(songData);
        int songIndex = songList.indexWhere((song) => song['id'] == songId);
        if (songIndex != -1) {
          result['songData'] = songList[songIndex];
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

      // 如果缓存中没有用户数据，尝试从资产文件加载 JSON 数据作为 fallback
      if (result['userData'] == null) {
        final userData = await rootBundle.loadString('assets/userPlayData.json');
        final Map<String, dynamic> userMap = json.decode(userData);
        result['userData'] = userMap;
      }

      // 加载标签数据
      final tagData = await rootBundle.loadString('assets/maiTags.json');
      final Map<String, dynamic> tagMap = json.decode(tagData);
      result['tagData'] = tagMap['tags'];
      result['tagSongsData'] = tagMap['tagSongs'];
    } catch (e) {
      print('加载数据失败: $e');
    }

    return result;
  }

  // 获取用户最佳成绩
  Map<String, dynamic>? getUserBestRecord(Map<String, dynamic>? userData, String songId, int currentDiffIndex) {
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
  Map<String, List<dynamic>> getTagsByGroup(List<dynamic>? tagData, List<dynamic>? tagSongsData, Map<String, dynamic>? songData, int currentDiffIndex) {
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
        final tag = tagData.firstWhere((t) => t['id'] == tagId, orElse: () => null);

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
  int calculateMaxDxScore(Map<String, dynamic>? songData, int songId, int levelIndex) {
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
  double calculateScoreRate(Map<String, dynamic>? songData, int songId, int levelIndex, int score) {
    int maxScore = calculateMaxDxScore(songData, songId, levelIndex);
    return maxScore > 0 ? score / maxScore : 0.0;
  }

  // 计算星星等级
  String calculateStars(Map<String, dynamic>? songData, int songId, int levelIndex, int score) {
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
  String calculateStarsBonus(Map<String, dynamic>? songData, int songId, int levelIndex, int score) {
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
    final url = Uri.parse('bilibili://search?keyword=${Uri.encodeComponent(searchQuery)}');

    // 尝试打开B站应用
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      // 如果无法打开B站应用，尝试在浏览器中打开
      final webUrl = Uri.parse('https://search.bilibili.com/all?keyword=${Uri.encodeComponent(searchQuery)}');
      if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl);
      }
    }
  }

  // 查看相关收藏品
  Future<List<Map<String, dynamic>>> fetchRelatedCollections(String songTitle, String songType) async {
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
      print('获取相关收藏品时出错: $e');
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
  bool isRelatedToSong(Collection collection, String songTitle, String songType) {
    // 检查 required 集合中是否有任何一个元素的 songs 集合中包含与当前歌曲标题和类型匹配的条目
    if (collection.required != null) {
      for (var requiredItem in collection.required!) {
        if (requiredItem.songs != null) {
          for (var song in requiredItem.songs!) {
            // 映射收藏品类型：standard -> SD
            String mappedCollectionType = song.type.toLowerCase() == 'standard' ? 'SD' : song.type;
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
        return 'ReMAS';
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
}