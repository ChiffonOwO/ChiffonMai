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
      final typeStr =
          type == RankingType.achievementRate ? 'achievement_rate' : 'dx_score';
      final url = Uri.parse(
              '${ApiUrls.SongRankingsBaseUrl}/$songId/$difficultyIndex/$typeStr')
          .replace(queryParameters: {'limit': limit.toString()});

      final response = await ApiClient.get(url);
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true) {
          final List<dynamic> data = body['data'] ?? [];
          return data.map((e) => RankingEntry.fromJson(e)).toList();
        }
      }
      debugPrint(
          '[SongRankingService] HTTP ${response.statusCode}: ${response.body}');
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
      final typeStr =
          type == RankingType.achievementRate ? 'achievement_rate' : 'dx_score';
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

  Future<bool> _validateRecord(String songId, int difficultyIndex,
      double achievementRate, int dxScore) async {
    try {
      final songs = await MaimaiMusicDataManager().getCachedSongs();
      if (songs == null) return true;

      final songIndex = songs.indexWhere((s) => s.id == songId);
      if (songIndex == -1) return true;

      final song = songs[songIndex];

      double maxAchievementRate = 101.0;
      if (songId.length == 6 && song.charts.length == 2) {
        maxAchievementRate = 202.0;
      }

      if (achievementRate > maxAchievementRate || achievementRate < 0) {
        debugPrint(
            '[SongRankingService] Invalid achievement rate: $achievementRate for song $songId');
        return false;
      }

      if (difficultyIndex >= 0 && difficultyIndex < song.charts.length) {
        int maxDxScore = 0;

        if (songId.length == 6 && song.charts.length == 2) {
          for (final chart in song.charts) {
            var noteTotal = 0;
            for (final note in chart.notes) {
              noteTotal += note;
            }
            maxDxScore += noteTotal * 3;
          }
        } else {
          var noteTotal = 0;
          for (final note in song.charts[difficultyIndex].notes) {
            noteTotal += note;
          }
          maxDxScore = noteTotal * 3;
        }

        if (dxScore > maxDxScore || dxScore < 0) {
          debugPrint(
              '[SongRankingService] Invalid DX score: $dxScore for song $songId');
          return false;
        }
      }

      return true;
    } catch (e) {
      debugPrint('[SongRankingService] Error validating record: $e');
      return true;
    }
  }

  Future<bool> validateUserRecord(String songId, int difficultyIndex,
      double achievementRate, int dxScore) async {
    return await _validateRecord(
        songId, difficultyIndex, achievementRate, dxScore);
  }

  Future<bool> updateSongRankings(
    String playerId,
    String playerName,
    List<Map<String, dynamic>> records, {
    List<dynamic>? songs,
    void Function(int sentBatches, int totalBatches)? onBatchProgress,
  }) async {
    try {
      // 歌曲按 id 建索引，避免逐记录 indexWhere 全表扫描（O(记录数×歌曲数)），
      // 直接把校验从平方级降到线性。
      final resolvedSongs =
          songs ?? await MaimaiMusicDataManager().getCachedSongs();
      final songById = <String, dynamic>{};
      for (final song in resolvedSongs ?? const <dynamic>[]) {
        songById[song.id] = song;
      }

      final validRecords = <Map<String, dynamic>>[];
      for (final record in records) {
        try {
          final songId = record['song_id'].toString();
          final difficultyIndex =
              int.tryParse(record['level_index'].toString()) ?? 0;
          final achievementRate =
              (record['achievements'] as num?)?.toDouble() ?? 0.0;
          final dxScore = int.tryParse(record['dxScore'].toString()) ?? 0;
          if (_validateRecordSync(songById, songId, difficultyIndex,
              achievementRate, dxScore)) {
            validRecords.add(record);
          }
        } catch (e) {
          debugPrint('[SongRankingService] Failed to validate record: $e');
        }
      }

      // 每张谱面只取其最佳：成就率最高、DX 分最高（可能来自不同一局）。
      final clientBest = _groupClientBest(validRecords);

      // 拉取服务器已存的该玩家成绩，做增量：只发送「服务器没有的新谱面」和
      // 「比服务器更高分」的记录，避免整包重传。拉取失败时返回空表 —— 此时
      // 所有记录都被当作新记录，退化为全量上传（幂等、安全）。
      final serverScores = await fetchPlayerStoredScores(playerId);
      debugPrint(
          '[SongRankingService] Fetched ${serverScores.length} stored score(s) from server for player $playerId');

      final payloadRecords = <Map<String, dynamic>>[];
      for (final best in clientBest.values) {
        final key = '${best.songId}|${best.difficultyIndex}';
        final server = serverScores[key];
        // 该谱面的 DX 满分（note 总数 × 3，UTAGE 双谱面求和）。
        // 若服务器尚未存过 max_dx_score（旧数据），即使成绩未提升也要重传，
        // 以便把缺失的 max_dx_score 回填回去 —— 否则平均DX得分达成率恒为 0。
        final computedMaxDx =
            _maxDxScoreOf(songById, best.songId, best.difficultyIndex);
        if (server == null) {
          // 服务器没有该谱面：新增。
          payloadRecords.add({
            'songId': best.songId,
            'difficultyIndex': best.difficultyIndex,
            'achievementRate': best.achievementRate,
            'dxScore': best.dxScore,
            'fc': best.fc,
            'maxDxScore': computedMaxDx,
          });
          continue;
        }

        // 把「客户端最佳」与「服务器已存」合并成双方较高的水位线，
        // 任一项（达成率/DX/连击）提升都更新，且绝不回退。
        final bestAch = best.achievementRate > server.achievementRate
            ? best.achievementRate
            : server.achievementRate;
        final bestDx = best.dxScore > server.dxScore
            ? best.dxScore
            : server.dxScore;
        final bestFc = _gradePriorityOf(best.fc) > _gradePriorityOf(server.fc)
            ? best.fc
            : server.fc;

        final missingMaxDx = server.maxDxScore <= 0 && computedMaxDx > 0;
        final improved = bestAch > server.achievementRate ||
            bestDx > server.dxScore ||
            bestFc != server.fc ||
            missingMaxDx;
        if (!improved) continue;

        payloadRecords.add({
          'songId': best.songId,
          'difficultyIndex': best.difficultyIndex,
          'achievementRate': bestAch,
          'dxScore': bestDx,
          'fc': bestFc,
          'maxDxScore': computedMaxDx,
        });
      }

      if (payloadRecords.isEmpty) {
        debugPrint(
            '[SongRankingService] No new/increased records to update for player $playerId');
        onBatchProgress?.call(1, 1);
        return true;
      }

      // 单个 bulk-update 请求会受服务器请求体大小限制（HTTP 413），
      // 因此把记录拆成多个批次顺序上传，并逐批回调进度。
      const batchSize = 300;
      final totalBatches = (payloadRecords.length + batchSize - 1) ~/ batchSize;
      debugPrint(
          '[SongRankingService] Sending ${payloadRecords.length} records in $totalBatches batch(es) for $playerId');
      for (var i = 0; i < totalBatches; i++) {
        final start = i * batchSize;
        final end = (start + batchSize) < payloadRecords.length
            ? start + batchSize
            : payloadRecords.length;
        final batch = payloadRecords.sublist(start, end);
        final response = await ApiClient.postGzip(
          Uri.parse(ApiUrls.SongRankingsBulkUpdateUrl),
          body: {
            'playerId': playerId,
            'playerName': playerName,
            'records': batch,
          },
          // 服务端每个批次要写入约 300 条记录，15s 默认超时容易触发
          // TimeoutException，这里给足写入时间。
          timeout: const Duration(seconds: 60),
        );
        if (response.statusCode != 200) {
          debugPrint(
              '[SongRankingService] bulk update HTTP ${response.statusCode}: ${response.body}');
          return false;
        }
        final body = json.decode(response.body);
        if (body['success'] != true) {
          debugPrint(
              '[SongRankingService] bulk update failed: ${body['error'] ?? 'unknown'}');
          return false;
        }
        debugPrint(
            '[SongRankingService] bulk update batch ${i + 1}/$totalBatches done: updated=${body['updatedCount']}, skipped=${body['skippedCount']}');
        onBatchProgress?.call(i + 1, totalBatches);
      }
      debugPrint(
          '[SongRankingService] bulk update done: ${payloadRecords.length} records across $totalBatches batch(es) for $playerId');
      return true;
    } catch (e) {
      debugPrint('[SongRankingService] Error updating rankings: $e');
      return false;
    }
  }

  bool _validateRecordSync(
    Map<String, dynamic>? songById,
    String songId,
    int difficultyIndex,
    double achievementRate,
    int dxScore,
  ) {
    try {
      if (songById == null || songById.isEmpty) return true;

      final song = songById[songId];
      if (song == null) return true;
      double maxAchievementRate = 101.0;
      if (songId.length == 6 && song.charts.length == 2) {
        maxAchievementRate = 202.0;
      }
      if (achievementRate > maxAchievementRate || achievementRate < 0) {
        return false;
      }

      if (difficultyIndex >= 0 && difficultyIndex < song.charts.length) {
        int maxDxScore = 0;
        if (songId.length == 6 && song.charts.length == 2) {
          for (final chart in song.charts) {
            var noteTotal = 0;
            for (final note in chart.notes) {
              noteTotal += (note as num).toInt();
            }
            maxDxScore += noteTotal * 3;
          }
        } else {
          var noteTotal = 0;
          for (final note in song.charts[difficultyIndex].notes) {
            noteTotal += (note as num).toInt();
          }
          maxDxScore = noteTotal * 3;
        }
        if (dxScore > maxDxScore || dxScore < 0) return false;
      }
      return true;
    } catch (e) {
      debugPrint('[SongRankingService] Error validating record: $e');
      return true;
    }
  }

  // 计算某张谱面的 DX 满分（note 总数 × 3）。UTAGE 双谱面时为两张谱面之和。
  // 用于换算「DX 得分达成率 = dxScore / maxDxScore」，返回 0 表示无法计算。
  int _maxDxScoreOf(
    Map<String, dynamic>? songById,
    String songId,
    int difficultyIndex,
  ) {
    try {
      final song = songById?[songId];
      if (song == null) return 0;
      int maxDxScore = 0;
      if (songId.length == 6 && song.charts.length == 2) {
        for (final chart in song.charts) {
          var noteTotal = 0;
          for (final note in chart.notes) {
            noteTotal += (note as num).toInt();
          }
          maxDxScore += noteTotal * 3;
        }
      } else {
        if (difficultyIndex < 0 || difficultyIndex >= song.charts.length) {
          return 0;
        }
        var noteTotal = 0;
        for (final note in song.charts[difficultyIndex].notes) {
          noteTotal += (note as num).toInt();
        }
        maxDxScore = noteTotal * 3;
      }
      return maxDxScore;
    } catch (e) {
      debugPrint('[SongRankingService] Error computing max DX score: $e');
      return 0;
    }
  }

  // 拉取服务器已存的该玩家全部单曲成绩。返回按 (songId|difficultyIndex) 索引的
  // { achievementRate, dxScore, fc, maxDxScore }。兼容 { success, data } 包装与裸
  // data 数组，同时兼容 camelCase（songId/difficultyIndex/achievementRate/maxDxScore）
  // 与 snake_case（song_id/level_index/achievements/max_dx_score）字段。拉取失败返回空表，
  // 便于上层退化为全量上传。
  Future<Map<String,
          ({double achievementRate, int dxScore, String fc, int maxDxScore})>>
      fetchPlayerStoredScores(String playerId) async {
    final url = Uri.parse('${ApiUrls.SongRankingsPlayerUrl}/$playerId');
    try {
      final response = await ApiClient.get(url);
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        dynamic data = body;
        if (body is Map<String, dynamic>) {
          data = body['data'] ?? data;
        }
        final list = data is List ? data : <dynamic>[];
        final map = <String,
            ({
              double achievementRate,
              int dxScore,
              String fc,
              int maxDxScore,
            })>{};
        for (final item in list) {
          if (item is! Map<String, dynamic>) continue;
          final songId = (item['songId'] ?? item['song_id'] ?? '').toString();
          final difficultyIndex =
              int.tryParse((item['difficultyIndex'] ?? item['level_index'] ?? 0)
                      .toString()) ??
                  0;
          final achRaw = item['achievementRate'] ?? item['achievements'] ?? 0;
          final achievementRate =
              achRaw is num ? achRaw.toDouble() : 0.0;
          final dxScore = int.tryParse((item['dxScore'] ?? 0).toString()) ?? 0;
          final fc = (item['fc'] ?? '').toString();
          final maxDxScore =
              int.tryParse((item['maxDxScore'] ?? item['max_dx_score'] ?? 0)
                      .toString()) ??
                  0;
          if (songId.isNotEmpty) {
            map['$songId|$difficultyIndex'] = (
              achievementRate: achievementRate,
              dxScore: dxScore,
              fc: fc,
              maxDxScore: maxDxScore,
            );
          }
        }
        return map;
      }
      debugPrint(
          '[SongRankingService] fetch stored scores HTTP ${response.statusCode}: ${response.body}');
    } catch (e) {
      debugPrint('[SongRankingService] Error fetching stored scores: $e');
    }
    return {};
  }

  // 按 (song_id, level_index) 分组，每张谱面独立保留最优指标：
  // 成就率最高、DX 分最高、连击（fc）等级最高。
  Map<String,
      ({
        String songId,
        int difficultyIndex,
        double achievementRate,
        int dxScore,
        String fc,
      })> _groupClientBest(List<Map<String, dynamic>> records) {
    final map = <String,
        ({
          String songId,
          int difficultyIndex,
          double achievementRate,
          int dxScore,
          String fc,
        })>{};
    for (final record in records) {
      final songId = record['song_id'].toString();
      final difficultyIndex =
          int.tryParse(record['level_index'].toString()) ?? 0;
      final key = '$songId|$difficultyIndex';

      final achievementValue = record['achievements'];
      final achievementRate = achievementValue is num
          ? achievementValue.toDouble()
          : double.tryParse(achievementValue?.toString() ?? '') ?? 0.0;
      final dxScore = int.tryParse(record['dxScore'].toString()) ?? 0;
      final fc = record['fc']?.toString() ?? '';

      final cur = map[key];
      if (cur == null) {
        map[key] = (
          songId: songId,
          difficultyIndex: difficultyIndex,
          achievementRate: achievementRate,
          dxScore: dxScore,
          fc: fc,
        );
      } else {
        map[key] = (
          songId: songId,
          difficultyIndex: difficultyIndex,
          achievementRate: achievementRate > cur.achievementRate
              ? achievementRate
              : cur.achievementRate,
          dxScore: dxScore > cur.dxScore ? dxScore : cur.dxScore,
          fc: _gradePriorityOf(fc) > _gradePriorityOf(cur.fc) ? fc : cur.fc,
        );
      }
    }
    return map;
  }

  // 连击（fc）相对等级，沿用 App 内的既有层级：fc < fcp < ap < app。
  int _gradePriorityOf(String value) {
    switch (value.toLowerCase()) {
      case 'app':
        return 4;
      case 'ap':
        return 3;
      case 'fcp':
        return 2;
      case 'fc':
      case 'sync':
        return 1;
      default:
        return 0;
    }
  }

  Future<bool> deleteSongRankings(String playerId) async {
    try {
      final response = await ApiClient.delete(
        Uri.parse('${ApiUrls.SongRankingsBaseUrl}/player/$playerId'),
      );

      if (response.statusCode == 200) {
        debugPrint(
            '[SongRankingService] Deleted rankings for player $playerId');
        return true;
      }
      debugPrint(
          '[SongRankingService] Delete failed HTTP ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('[SongRankingService] Error deleting rankings: $e');
      return false;
    }
  }
}
