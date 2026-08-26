import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_first_flutter_app/api/ApiUrls.dart';
import 'package:my_first_flutter_app/manager/DivingFish/MaimaiMusicDataManager.dart';
import 'package:my_first_flutter_app/utils/ApiClient.dart';
import '../../constant/CacheKeyConstant.dart';

enum RankingType {
  achievementRate,
  dxScore,
}

class RankingEntry {
  final int rank;
  final String playerId;
  final String playerName;
  final double achievementRate;
  final int dxScore;
  final String? fc;
  final String dataSource;
  final int updateTime;

  RankingEntry({
    required this.rank,
    required this.playerId,
    required this.playerName,
    required this.achievementRate,
    required this.dxScore,
    this.fc,
    required this.dataSource,
    required this.updateTime,
  });

  factory RankingEntry.fromJson(Map<String, dynamic> json) {
    return RankingEntry(
      rank: json['rank'] ?? 0,
      playerId: json['playerId'] ?? '',
      playerName: json['playerName'] ?? '',
      achievementRate: (json['achievementRate'] ?? 0).toDouble(),
      dxScore: (json['dxScore'] ?? 0).toInt(),
      fc: json['fc'],
      dataSource: json['dataSource'] ?? parseDataSource(json['playerId'] ?? ''),
      updateTime: json['updateTime'] ?? 0,
    );
  }
}

String parseDataSource(String playerId) {
  if (playerId.startsWith('shuiyu:')) {
    return 'shuiyu';
  } else if (playerId.startsWith('luoxue:')) {
    return 'luoxue';
  }
  return 'luoxue';
}

class SongRankingService {
  static final SongRankingService _instance = SongRankingService._internal();

  factory SongRankingService() {
    return _instance;
  }

  SongRankingService._internal();

  Future<List<RankingEntry>> getSongRanking(
    String songId,
    int difficultyIndex,
    RankingType type, {
    int limit = 100,
  }) async {
    try {
      final typeStr = type == RankingType.achievementRate ? 'achievement_rate' : 'dx_score';
      final url = Uri.parse('${ApiUrls.SongRankingsBaseUrl}/$songId/$difficultyIndex/$typeStr')
          .replace(queryParameters: {'limit': limit.toString()});

      final response = await ApiClient.get(url);
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true) {
          final List<dynamic> data = body['data'] ?? [];
          return data.map((e) => RankingEntry.fromJson(e)).toList();
        }
      }
      debugPrint('[SongRankingService] HTTP ${response.statusCode}: ${response.body}');
    } catch (e) {
      debugPrint('[SongRankingService] Error fetching ranking: $e');
    }

    return [];
  }

  Future<RankingEntry?> getUserRanking(
    String songId,
    int difficultyIndex,
    RankingType type,
    String playerId,
  ) async {
    try {
      final typeStr = type == RankingType.achievementRate ? 'achievement_rate' : 'dx_score';
      final url = Uri.parse(
        '${ApiUrls.SongRankingsBaseUrl}/$songId/$difficultyIndex/$typeStr/user/$playerId',
      );

      final response = await ApiClient.get(url);
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true && body['found'] == true) {
          return RankingEntry.fromJson(body['data']);
        }
      }
    } catch (e) {
      debugPrint('[SongRankingService] Error fetching user ranking: $e');
    }

    return null;
  }

  Future<String> getCurrentPlayerId() async {
    final prefs = await SharedPreferences.getInstance();

    // 优先获取洛雪用户ID
    String? luoxueUserId = prefs.getString(CacheKeyConstant.luoxueUserId);
    if (luoxueUserId != null && luoxueUserId.isNotEmpty) {
      return luoxueUserId;
    }

    // 获取水鱼用户ID
    String? shuiyuUserId = prefs.getString(CacheKeyConstant.shuiyuUserId);
    if (shuiyuUserId != null && shuiyuUserId.isNotEmpty) {
      return shuiyuUserId;
    }

    // 默认返回空字符串
    return '';
  }

  Future<bool> _validateRecord(String songId, int difficultyIndex, double achievementRate, int dxScore) async {
    try {
      final songs = await MaimaiMusicDataManager().getCachedSongs();
      if (songs == null) return true;

      final songIndex = songs.indexWhere((s) => s.id == songId);
      if (songIndex == -1) return true;

      final song = songs[songIndex];

      // 校验规则1：达成率满分判断
      double maxAchievementRate = 101.0;
      // 判断是否为6位ID且只有2个难度的歌曲
      if (songId.length == 6 && song.charts.length == 2) {
        maxAchievementRate = 202.0;
      }

      if (achievementRate > maxAchievementRate || achievementRate < 0) {
        debugPrint('[SongRankingService] Invalid achievement rate: $achievementRate for song $songId');
        return false;
      }

      // 校验规则2：DX分数不得超过满分
      if (difficultyIndex >= 0 && difficultyIndex < song.charts.length) {
        int maxDxScore = 0;

        // 对于6位ID且只有2个难度的歌曲，将两个难度的满分DX分相加作为满分
        if (songId.length == 6 && song.charts.length == 2) {
          for (int i = 0; i < song.charts.length; i++) {
            List<int> notesList = song.charts[i].notes;
            int totalNotes = notesList.reduce((a, b) => a + b);
            maxDxScore += totalNotes * 3;
          }
        } else {
          List<int> notesList = song.charts[difficultyIndex].notes;
          int totalNotes = notesList.reduce((a, b) => a + b);
          maxDxScore = totalNotes * 3;
        }

        if (dxScore > maxDxScore || dxScore < 0) {
          debugPrint('[SongRankingService] Invalid DX score: $dxScore (max: $maxDxScore) for song $songId');
          return false;
        }
      }

      return true;
    } catch (e) {
      debugPrint('[SongRankingService] Error validating record: $e');
      return true;
    }
  }

  Future<bool> validateUserRecord(String songId, int difficultyIndex, double achievementRate, int dxScore) async {
    return await _validateRecord(songId, difficultyIndex, achievementRate, dxScore);
  }

  Future<void> updateSongRankings(
    String playerId,
    String playerName,
    List<Map<String, dynamic>> records, {
    void Function(int sentBatches, int totalBatches)? onBatchProgress,
  }) async {
    try {
      // 预加载所有歌曲数据用于校验
      final songs = await MaimaiMusicDataManager().getCachedSongs();

      // 过滤有效记录
      List<Map<String, dynamic>> validRecords = [];
      for (var record in records) {
        try {
          String songId = record['song_id'].toString();
          int difficultyIndex = int.tryParse(record['level_index'].toString()) ?? 0;

          dynamic achievementsValue = record['achievements'];
          double achievementRate = 0.0;
          if (achievementsValue is num) {
            achievementRate = achievementsValue.toDouble();
          } else if (achievementsValue is String) {
            achievementRate = double.tryParse(achievementsValue) ?? 0.0;
          }

          int dxScore = int.tryParse(record['dxScore'].toString()) ?? 0;

          if (_validateRecordSync(songs, songId, difficultyIndex, achievementRate, dxScore)) {
            validRecords.add(record);
          }
        } catch (e) {
          debugPrint('[SongRankingService] Failed to validate record: $e');
        }
      }

      if (validRecords.isEmpty) {
        debugPrint('[SongRankingService] No valid records to update for player $playerId');
        return;
      }

      // 构建请求 payload
      List<Map<String, dynamic>> payloadRecords = [];
      for (var record in validRecords) {
        String songId = record['song_id'].toString();
        int difficultyIndex = int.tryParse(record['level_index'].toString()) ?? 0;

        dynamic achievementsValue = record['achievements'];
        double achievementRate = 0.0;
        if (achievementsValue is num) {
          achievementRate = achievementsValue.toDouble();
        } else if (achievementsValue is String) {
          achievementRate = double.tryParse(achievementsValue) ?? 0.0;
        }

        int dxScore = int.tryParse(record['dxScore'].toString()) ?? 0;
        String fc = record['fc']?.toString() ?? '';

        payloadRecords.add({
          'songId': songId,
          'difficultyIndex': difficultyIndex,
          'achievementRate': achievementRate,
          'dxScore': dxScore,
          'fc': fc,
        });
      }

      debugPrint('[SongRankingService] Sending ${payloadRecords.length} records to server for player $playerId');

      // 单包超 100KB 会被 express 默认 body-parser 拦截（413 PayloadTooLarge），
      // 这里按记录数分批上传，每批 500 条 ≈ 60-75KB，留足余量。
      const int batchSize = 500;
      final totalBatches = (payloadRecords.length / batchSize).ceil();
      int totalUpdated = 0;
      int totalSkipped = 0;
      int failedBatches = 0;

      debugPrint(
          '[SongRankingService] Splitting into $totalBatches batches (≤$batchSize records each)');

      for (int i = 0; i < payloadRecords.length; i += batchSize) {
        final end = (i + batchSize > payloadRecords.length)
            ? payloadRecords.length
            : i + batchSize;
        final batch = payloadRecords.sublist(i, end);
        final batchIndex = (i ~/ batchSize) + 1;

        debugPrint(
            '[SongRankingService] → batch $batchIndex/$totalBatches (${batch.length} records)');

        onBatchProgress?.call(batchIndex, totalBatches);

        try {
          final response = await ApiClient.post(
            Uri.parse('${ApiUrls.SongRankingsBaseUrl}/update'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'playerId': playerId,
              'playerName': playerName,
              'records': batch,
            }),
          );

          if (response.statusCode == 200) {
            final body = json.decode(response.body);
            if (body['success'] == true) {
              totalUpdated += (body['updatedCount'] as int?) ?? 0;
              totalSkipped += (body['skippedCount'] as int?) ?? 0;
              debugPrint(
                  '[SongRankingService] ✓ batch $batchIndex: updated=${body['updatedCount']}, skipped=${body['skippedCount']}');
            } else {
              failedBatches++;
              debugPrint(
                  '[SongRankingService] ✗ batch $batchIndex rejected: ${body['error'] ?? 'unknown'}');
            }
          } else {
            failedBatches++;
            debugPrint(
                '[SongRankingService] ✗ batch $batchIndex HTTP ${response.statusCode}: ${response.body}');
          }
        } catch (e) {
          failedBatches++;
          debugPrint('[SongRankingService] ✗ batch $batchIndex error: $e');
        }
      }

      debugPrint(
          '[SongRankingService] All batches done for $playerId: $totalUpdated updated, $totalSkipped skipped, $failedBatches failed');
    } catch (e) {
      debugPrint('[SongRankingService] Error updating rankings: $e');
    }
  }

  // 同步版本的校验方法，使用预加载的数据
  bool _validateRecordSync(
    List<dynamic>? songs,
    String songId,
    int difficultyIndex,
    double achievementRate,
    int dxScore,
  ) {
    try {
      if (songs == null || songs.isEmpty) return true;

      // 查找歌曲
      final songIndex = songs.indexWhere((s) => s.id == songId);
      if (songIndex == -1) return true;

      final song = songs[songIndex];

      // 校验规则1：达成率满分判断
      double maxAchievementRate = 101.0;
      if (songId.length == 6 && song.charts.length == 2) {
        maxAchievementRate = 202.0;
      }

      if (achievementRate > maxAchievementRate || achievementRate < 0) {
        debugPrint('[SongRankingService] Invalid achievement rate: $achievementRate for song $songId');
        return false;
      }

      // 校验规则2：DX分数不得超过满分
      if (difficultyIndex >= 0 && difficultyIndex < song.charts.length) {
        int maxDxScore = 0;

        if (songId.length == 6 && song.charts.length == 2) {
          for (int i = 0; i < song.charts.length; i++) {
            List<int> notesList = song.charts[i].notes;
            int totalNotes = notesList.reduce((a, b) => a + b);
            maxDxScore += totalNotes * 3;
          }
        } else {
          List<int> notesList = song.charts[difficultyIndex].notes;
          int totalNotes = notesList.reduce((a, b) => a + b);
          maxDxScore = totalNotes * 3;
        }

        if (dxScore > maxDxScore || dxScore < 0) {
          debugPrint('[SongRankingService] Invalid DX score: $dxScore (max: $maxDxScore) for song $songId');
          return false;
        }
      }

      return true;
    } catch (e) {
      debugPrint('[SongRankingService] Error validating record: $e');
      return true;
    }
  }

  Future<void> deleteSongRankings(String playerId) async {
    try {
      final response = await ApiClient.delete(
        Uri.parse('${ApiUrls.SongRankingsBaseUrl}/player/$playerId'),
      );

      if (response.statusCode == 200) {
        debugPrint('[SongRankingService] Deleted rankings for player $playerId');
      }
    } catch (e) {
      debugPrint('[SongRankingService] Error deleting rankings: $e');
    }
  }
}