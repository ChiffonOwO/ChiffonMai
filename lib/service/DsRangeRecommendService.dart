import 'package:flutter/foundation.dart';
import 'package:my_first_flutter_app/entity/DivingFish/DiffSong.dart';
import 'package:my_first_flutter_app/manager/DivingFish/MaimaiMusicDataManager.dart';
import 'package:my_first_flutter_app/manager/DivingFish/DiffMusicDataManager.dart';
import 'package:my_first_flutter_app/manager/DivingFish/UserPlayDataManager.dart';
import 'package:my_first_flutter_app/entity/DivingFish/UserPlayDataEntity.dart';

class DsRangeRecommendItem {
  final String songId;
  final String songTitle;
  final String type;
  final int levelIndex;
  final int difficultyCount;
  final double ds;
  final double fitDiff;
  final double diffDifference;
  final double avg;
  final String level;
  final double? userAchievement;

  DsRangeRecommendItem({
    required this.songId,
    required this.songTitle,
    required this.type,
    required this.levelIndex,
    required this.difficultyCount,
    required this.ds,
    required this.fitDiff,
    required this.diffDifference,
    required this.avg,
    required this.level,
    this.userAchievement,
  });
}

class DsRangeRecommendService {
  static final DsRangeRecommendService _instance =
      DsRangeRecommendService._internal();
  factory DsRangeRecommendService() => _instance;
  DsRangeRecommendService._internal();

  static const List<String> LEVEL_LABELS = [
    'BASIC',
    'ADVANCED',
    'EXPERT',
    'MASTER',
    'Re:MASTER',
  ];

  Future<List<DsRangeRecommendItem>> getRecommendations(
      double minDs, double maxDs, String sortMode) async {
    final musicManager = MaimaiMusicDataManager();
    final allSongs = await musicManager.getCachedSongs() ?? [];
    if (allSongs.isEmpty) {
      return [];
    }

    final diffManager = DiffMusicDataManager();
    final diffSong = await diffManager.getCachedDiffData();
    final Map<String, List<DiffData>> charts = diffSong?.charts ?? {};

    final userPlayDataManager = UserPlayDataManager();
    final Map<String, num> userAchievementMap = {};
    try {
      final cachedUserData = await userPlayDataManager.getCachedUserPlayData();
      if (cachedUserData != null) {
        final userPlayData = UserPlayDataEntity.fromJson(cachedUserData);
        for (final record in userPlayData.records) {
          final key = '${record.songId}_${record.levelIndex}';
          userAchievementMap[key] = record.achievements;
        }
      }
    } catch (e) {
      debugPrint('加载用户游玩数据失败: $e');
    }

    final List<DsRangeRecommendItem> results = [];

    for (final song in allSongs) {
      if (song.id.length == 6) continue;

      final dsList = song.ds;
      if (dsList.isEmpty) continue;

      final diffDataList = charts[song.id];
      if (diffDataList == null || diffDataList.isEmpty) continue;

      for (int i = 0; i < dsList.length && i < diffDataList.length; i++) {
        final ds = dsList[i];
        if (ds < minDs || ds > maxDs) continue;

        final diffData = diffDataList[i];
        final fitDiff = diffData.fitDiff.toDouble();
        final avg = diffData.avg.toDouble();
        final diffDifference = fitDiff - ds;

        final levelLabel = i < LEVEL_LABELS.length ? LEVEL_LABELS[i] : '';
        final songIdInt = int.tryParse(song.id) ?? 0;
        final userAchievement = userAchievementMap['${songIdInt}_$i'];
        final userAchievementDouble = userAchievement?.toDouble();

        results.add(DsRangeRecommendItem(
          songId: song.id,
          songTitle: song.basicInfo.title,
          type: song.type,
          levelIndex: i,
          difficultyCount: dsList.length,
          ds: ds,
          fitDiff: fitDiff,
          diffDifference: diffDifference,
          avg: avg,
          level: levelLabel,
          userAchievement: userAchievementDouble,
        ));
      }
    }

    if (sortMode == 'avg') {
      results.sort((a, b) => b.avg.compareTo(a.avg));
    } else if (sortMode == 'diff') {
      results.sort((a, b) => a.diffDifference.compareTo(b.diffDifference));
    }

    return results;
  }
}