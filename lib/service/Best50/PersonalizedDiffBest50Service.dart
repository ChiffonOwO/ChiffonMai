import 'package:flutter/foundation.dart';

import '../../manager/DivingFish/UserPlayDataManager.dart';
import '../../manager/DivingFish/DiffMusicDataManager.dart';
import '../../manager/DivingFish/MaimaiMusicDataManager.dart';
import '../../manager/MaiTagsManager.dart';

class PersonalizedDiffBest50Service {
  // 单例模式
  static final PersonalizedDiffBest50Service _instance = PersonalizedDiffBest50Service._internal();
  factory PersonalizedDiffBest50Service() => _instance;
  PersonalizedDiffBest50Service._internal();

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
    {"completion": 40.0, "rating": "D", "multiplier": 0.064},
    {"completion": 30.0, "rating": "D", "multiplier": 0.048},
    {"completion": 20.0, "rating": "D", "multiplier": 0.032},
    {"completion": 10.0, "rating": "D", "multiplier": 0.016},
  ];

  // 加载歌曲拟合难度数据
  Future<Map<String, dynamic>> loadSongDiffData() async {
    try {
      final diffMusicDataManager = DiffMusicDataManager();
      if (await diffMusicDataManager.hasCachedData()) {
        final diffSong = await diffMusicDataManager.getCachedDiffData();
        if (diffSong != null) {
          Map<String, dynamic> diffData = {'charts': <String, dynamic>{}};
          diffSong.charts.forEach((songId, diffDataList) {
            List<Map<String, dynamic>> songCharts = [];
            for (var diffDataItem in diffDataList) {
              songCharts.add({
                'fit_diff': diffDataItem.fitDiff.toDouble()
              });
            }
            (diffData['charts'] as Map<String, dynamic>)[songId] = songCharts;
          });
          return diffData;
        }
      }
      return {};
    } catch (e) {
      debugPrint('加载歌曲难度数据失败: $e');
      return {};
    }
  }

  // 计算单曲Rating
  int calculateSingleRating(double difficulty, double completion) {
    // 特别处理：如果达成率大于100.5，则按100.5计算
    double adjustedCompletion = completion > 100.5 ? 100.5 : completion;
    double calculationCompletion = completion > 100.5 ? 100.5 : completion;

    // 查找对应的评级和乘数
    Map<String, dynamic>? selectedRating;

    for (var item in maimaiRatingMultiplier) {
      if (adjustedCompletion >= item['completion']) {
        selectedRating = item;
        break;
      }
    }

    selectedRating ??= {"rating": "D", "multiplier": 0.016};

    double multiplier = selectedRating['multiplier'];

    // 计算单曲Rating
    double singleRating = difficulty * multiplier * calculationCompletion;
    return singleRating.floor();
  }

  // 获取标签对应的个性化拟合Best50数据
  Future<Map<String, dynamic>?> getTagDiffBest50Data(int tagId) async {
    try {
      // 加载拟合难度数据
      final songDiffData = await loadSongDiffData();
      final chartsRaw = songDiffData['charts'];
      final chartsData = chartsRaw is Map<String, dynamic>
          ? chartsRaw
          : chartsRaw is Map
              ? Map<String, dynamic>.from(chartsRaw)
              : <String, dynamic>{};

      // 获取用户游玩记录
      final userPlayData = await UserPlayDataManager().getCachedUserPlayData();
      if (userPlayData == null) return null;

      final records = userPlayData['records'];
      if (!(records is List)) return null;

      // 获取所有歌曲数据（用于构建谱面标识映射）
      final allSongs = await MaimaiMusicDataManager().getCachedSongs();
      if (allSongs == null) return null;

      // 构建歌曲ID到歌曲信息的映射
      final songMap = { for (var song in allSongs) song.id: song };

      // 获取标签-歌曲映射
      final songIdToTagIdsMap = await MaiTagsManager().getSongIdToTagIdsMap();

      // 难度索引 → 难度字符串映射
      const diffNames = ['basic', 'advanced', 'expert', 'master', 'remaster'];

      // 存储计算结果
      List<Map<String, dynamic>> diffBest50 = [];

      // 遍历用户游玩记录
      for (var record in records) {
        if (record is! Map<String, dynamic>) continue;

        final songId = record['song_id']?.toString() ?? '';
        final levelIndex = (record['level_index'] ?? 0) as int;
        final achievements = double.tryParse(record['achievements'].toString()) ?? 0.0;
        final song = songMap[songId];

        if (song == null) continue;

        // 检查该谱面是否有指定标签
        final String sheetType;
        if (song.basicInfo.genre == '宴会场') {
          sheetType = 'utage';
        } else {
          sheetType = song.type == 'DX' ? 'dx' : 'std';
        }
        final sheetDifficulty = diffNames[levelIndex.clamp(0, 4)];
        final songKey = '${song.title}#$sheetType#$sheetDifficulty';
        final tagIds = songIdToTagIdsMap[songKey] ?? [];
        if (!tagIds.contains(tagId)) continue;

        // 查找对应的拟合定数
        double fitDiff = 0.0;
        bool useOfficialDiff = false;
        if (chartsData.containsKey(songId)) {
          final songCharts = chartsData[songId] as List<dynamic>;
          if (levelIndex < songCharts.length) {
            fitDiff = (songCharts[levelIndex] as Map<String, dynamic>)['fit_diff'] ?? 0.0;
          }
        }

        // 如果拟合定数为0，使用官方定数
        if (fitDiff == 0.0) {
          fitDiff = double.tryParse((record['ds'] ?? '0').toString()) ?? 0.0;
          useOfficialDiff = true;
        }

        // 计算DiffRating
        int diffRating = calculateSingleRating(fitDiff, achievements);

        // 获取ds值
        double dsValue = 0.0;
        if (levelIndex >= 0 && levelIndex < song.ds.length) {
          dsValue = song.ds[levelIndex];
        }

        diffBest50.add({
          'song_id': int.tryParse(songId) ?? 0,
          'level_index': levelIndex,
          'title': song.title,
          'type': song.type,
          'ds': dsValue,
          'achievements': achievements,
          'dxScore': record['dxScore'] ?? 0,
          'fc': record['fc'] ?? '',
          'fs': record['fs'] ?? '',
          'rate': record['rate'] ?? '',
          'ra': record['ra'] ?? 0,
          'diffRating': diffRating,
          'fit_diff': fitDiff,
          'use_official_diff': useOfficialDiff,
        });
      }

      // 按DiffRating降序排序
      diffBest50.sort((a, b) => b['diffRating'].compareTo(a['diffRating']));

      // 取前50条
      if (diffBest50.length > 50) {
        diffBest50 = diffBest50.sublist(0, 50);
      }

      // 计算DiffRating总和
      int diffRatingSum = diffBest50.fold(0, (sum, item) => sum + (item['diffRating'] as int));

      return {
        'diffRatingSum': diffRatingSum,
        'diffBest50': diffBest50,
        'total': diffBest50.length,
        'tag_id': tagId,
      };
    } catch (e) {
      debugPrint('获取标签拟合Best50数据失败: $e');
      return null;
    }
  }
}
