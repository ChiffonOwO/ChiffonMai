import 'package:flutter/foundation.dart';
import 'package:redis/redis.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_first_flutter_app/api/DeveloperToken.dart';
import 'package:my_first_flutter_app/manager/DivingFish/MaimaiMusicDataManager.dart';

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

  // 使用 DeveloperToken 中的 Redis 配置
  static String get redisHost => DeveloperToken.RedisHost;
  static int get redisPort => DeveloperToken.RedisPort;
  static String get redisPassword => DeveloperToken.RedisPassword;

  Future<List<RankingEntry>> getSongRanking(
    String songId,
    int difficultyIndex,
    RankingType type, {
    int limit = 100,
  }) async {
    List<RankingEntry> result = [];
    
    try {
      final conn = await RedisConnection().connect(redisHost, redisPort);
      
      try {
        await conn.send_object(['AUTH', redisPassword]);
        
        String key = _buildRedisKey(songId, difficultyIndex, type);
        debugPrint('[SongRankingService] Fetching ranking from Redis: $key');
        
        List<dynamic> redisResult = await conn.send_object(
          ['ZREVRANGE', key, 0, limit - 1, 'WITHSCORES']
        );
        
        if (redisResult != null && redisResult.isNotEmpty) {
          // 先收集所有数据（包含更新时间）
          List<Map<String, dynamic>> rawData = [];
          
          for (int i = 0; i < redisResult.length; i += 2) {
            String playerId = redisResult[i] as String;
            
            dynamic scoreValue = redisResult[i + 1];
            double score = 0.0;
            if (scoreValue is num) {
              score = scoreValue.toDouble();
            } else if (scoreValue is String) {
              score = double.tryParse(scoreValue) ?? 0.0;
            }
            
            String? playerName = await _getPlayerNameFromRedis(conn, playerId);
            
            String? fc = null;
            if (type == RankingType.achievementRate) {
              String fcKey = 'song:fc:$songId:$difficultyIndex:$playerId';
              dynamic fcResult = await conn.send_object(['GET', fcKey]);
              if (fcResult is String) {
                fc = fcResult;
              }
            }
            
            // 获取更新时间（用于同分排序）
            String updateTimeKey = 'song:updateTime:$songId:$difficultyIndex:$playerId';
            dynamic updateTimeResult = await conn.send_object(['GET', updateTimeKey]);
            int updateTime = 0;
            if (updateTimeResult is int) {
              updateTime = updateTimeResult;
            } else if (updateTimeResult is String) {
              updateTime = int.tryParse(updateTimeResult) ?? 0;
            }
            
            rawData.add({
              'playerId': playerId,
              'playerName': playerName ?? playerId,
              'score': score,
              'fc': fc,
              'dataSource': parseDataSource(playerId),
              'updateTime': updateTime,
            });
          }
          
          // 按分数降序，同分按更新时间升序（早更新的排在前面）
          rawData.sort((a, b) {
            int scoreCompare = b['score'].compareTo(a['score']);
            if (scoreCompare != 0) {
              return scoreCompare;
            }
            // 同分情况下，更新时间早的排在前面
            return a['updateTime'].compareTo(b['updateTime']);
          });
          
          // 计算密集排名（并列排名）
          for (int i = 0; i < rawData.length; i++) {
            int rank = i + 1;
            // 如果当前分数和前一个相同，排名相同
            if (i > 0 && rawData[i]['score'] == rawData[i - 1]['score']) {
              // 找到第一个同分的位置
              int j = i - 1;
              while (j >= 0 && rawData[j]['score'] == rawData[i]['score']) {
                j--;
              }
              rank = j + 2; // j+1是0-based索引，+2变成1-based排名
            }
            
            result.add(RankingEntry(
              rank: rank,
              playerId: rawData[i]['playerId'],
              playerName: rawData[i]['playerName'],
              achievementRate: type == RankingType.achievementRate ? rawData[i]['score'] : 0,
              dxScore: type == RankingType.dxScore ? rawData[i]['score'].toInt() : 0,
              fc: rawData[i]['fc'],
              dataSource: rawData[i]['dataSource'],
              updateTime: rawData[i]['updateTime'],
            ));
          }
          
          debugPrint('[SongRankingService] Got ${result.length} entries from Redis');
        }
      } finally {
        try {
          await conn.send_object(['QUIT']);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[SongRankingService] Redis error: $e');
    }
    
    return result;
  }

  Future<RankingEntry?> getUserRanking(
    String songId,
    int difficultyIndex,
    RankingType type,
    String playerId,
  ) async {
    try {
      final conn = await RedisConnection().connect(redisHost, redisPort);
      
      try {
        await conn.send_object(['AUTH', redisPassword]);
        
        String key = _buildRedisKey(songId, difficultyIndex, type);
        
        // 使用 ZREVRANK 按分数降序获取排名（与排行榜显示一致）
        dynamic result = await conn.send_object(
          ['ZREVRANK', key, playerId]
        );
        
        if (result != null) {
          int rank = 0;
          if (result is int) {
            rank = result + 1;
          } else if (result is String) {
            rank = (int.tryParse(result) ?? 0) + 1;
          }
          
          dynamic scoreResult = await conn.send_object(
            ['ZSCORE', key, playerId]
          );
          
          double score = 0.0;
          if (scoreResult is num) {
            score = scoreResult.toDouble();
          } else if (scoreResult is String) {
            score = double.tryParse(scoreResult) ?? 0.0;
          }
          
          String? playerName = await _getPlayerNameFromRedis(conn, playerId);
          
          String? fc = null;
          if (type == RankingType.achievementRate) {
            String fcKey = 'song:fc:$songId:$difficultyIndex:$playerId';
            dynamic fcResult = await conn.send_object(['GET', fcKey]);
            if (fcResult is String) {
              fc = fcResult;
            }
          }
          
          // 获取更新时间
          String updateTimeKey = 'song:updateTime:$songId:$difficultyIndex:$playerId';
          dynamic updateTimeResult = await conn.send_object(['GET', updateTimeKey]);
          int updateTime = 0;
          if (updateTimeResult is int) {
            updateTime = updateTimeResult;
          } else if (updateTimeResult is String) {
            updateTime = int.tryParse(updateTimeResult) ?? 0;
          }
          
          return RankingEntry(
            rank: rank,
            playerId: playerId,
            playerName: playerName ?? playerId,
            achievementRate: type == RankingType.achievementRate ? score : 0,
            dxScore: type == RankingType.dxScore ? score.toInt() : 0,
            fc: fc,
            dataSource: parseDataSource(playerId),
            updateTime: updateTime,
          );
        }
      } finally {
        try {
          await conn.send_object(['QUIT']);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[SongRankingService] Redis error in getUserRanking: $e');
    }
    
    return null;
  }

  Future<String?> _getPlayerNameFromRedis(Command conn, String playerId) async {
    try {
      String key = 'player:name:$playerId';
      dynamic result = await conn.send_object(['GET', key]);
      if (result != null) {
        return result as String;
      }
    } catch (e) {
      debugPrint('[SongRankingService] Failed to get player name from Redis: $e');
    }
    return null;
  }

  String _buildRedisKey(String songId, int difficultyIndex, RankingType type) {
    String typeStr = type == RankingType.achievementRate ? 'rate' : 'score';
    return 'song:ranking:$songId:$difficultyIndex:$typeStr';
  }

  Future<String> getCurrentPlayerId() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 优先获取洛雪用户ID
    String? luoxueUserId = prefs.getString('luoxue_user_id');
    if (luoxueUserId != null && luoxueUserId.isNotEmpty) {
      return luoxueUserId;
    }
    
    // 获取水鱼用户ID
    String? shuiyuUserId = prefs.getString('shuiyu_user_id');
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
    List<Map<String, dynamic>> records,
  ) async {
    try {
      // 优化1：预加载所有歌曲数据，避免重复查询
      final songs = await MaimaiMusicDataManager().getCachedSongs();
      
      // 优化2：先过滤有效记录，减少后续处理量
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
      
      debugPrint('[SongRankingService] Processing ${validRecords.length} valid records');
      
      // 优化3：连接Redis，使用管道批量操作
      final conn = await RedisConnection().connect(redisHost, redisPort);
      
      try {
        await conn.send_object(['AUTH', redisPassword]);
        
        // 设置玩家名称
        await conn.send_object(['SET', 'player:name:$playerId', playerName]);
        
        // 优化4：批量获取所有当前分数（使用管道）
        // 构建所有需要查询的key和对应的记录索引
        List<Map<String, dynamic>> recordsWithKeys = [];
        List<Future<dynamic>> fetchFutures = [];
        
        for (var record in validRecords) {
          String songId = record['song_id'].toString();
          int difficultyIndex = int.tryParse(record['level_index'].toString()) ?? 0;
          
          String rateKey = _buildRedisKey(songId, difficultyIndex, RankingType.achievementRate);
          String scoreKey = _buildRedisKey(songId, difficultyIndex, RankingType.dxScore);
          String fcKey = 'song:fc:$songId:$difficultyIndex:$playerId';
          
          // 并行发送查询命令
          fetchFutures.add(conn.send_object(['ZSCORE', rateKey, playerId]));
          fetchFutures.add(conn.send_object(['ZSCORE', scoreKey, playerId]));
          fetchFutures.add(conn.send_object(['GET', fcKey]));
          
          recordsWithKeys.add({
            'record': record,
            'rateKey': rateKey,
            'scoreKey': scoreKey,
            'fcKey': fcKey,
            'updateTimeKey': 'song:updateTime:$songId:$difficultyIndex:$playerId',
          });
        }
        
        // 批量等待所有查询结果
        debugPrint('[SongRankingService] Fetching ${fetchFutures.length} current values from Redis');
        List<dynamic> fetchResults = await Future.wait(fetchFutures);
        
        // 优化5：处理查询结果，构建更新命令
        List<List<dynamic>> redisCommands = [];
        int updatedCount = 0;
        int skippedCount = 0;
        int resultIndex = 0;
        
        for (var item in recordsWithKeys) {
          Map<String, dynamic> record = item['record'];
          record['song_id'].toString();
          
          // 获取解析后的新分数
          dynamic achievementsValue = record['achievements'];
          double newAchievementRate = 0.0;
          if (achievementsValue is num) {
            newAchievementRate = achievementsValue.toDouble();
          } else if (achievementsValue is String) {
            newAchievementRate = double.tryParse(achievementsValue) ?? 0.0;
          }
          
          int newDxScore = int.tryParse(record['dxScore'].toString()) ?? 0;
          String newFc = record['fc']?.toString() ?? '';
          
          // 解析查询结果
          double currentAchievementRate = 0.0;
          dynamic rateResult = fetchResults[resultIndex++];
          if (rateResult is num) {
            currentAchievementRate = rateResult.toDouble();
          } else if (rateResult is String) {
            currentAchievementRate = double.tryParse(rateResult) ?? 0.0;
          }
          
          int currentDxScore = 0;
          dynamic scoreResult = fetchResults[resultIndex++];
          if (scoreResult is num) {
            currentDxScore = scoreResult.toInt();
          } else if (scoreResult is String) {
            currentDxScore = int.tryParse(scoreResult) ?? 0;
          }
          
          String currentFc = '';
          dynamic fcResult = fetchResults[resultIndex++];
          if (fcResult is String) {
            currentFc = fcResult;
          }
          
          // 判断是否需要更新
          bool needUpdate = false;
          if (currentAchievementRate == 0 && currentDxScore == 0) {
            needUpdate = true;
          } else {
            if (newAchievementRate > currentAchievementRate || newDxScore > currentDxScore) {
              needUpdate = true;
            } else if (newAchievementRate == currentAchievementRate && newDxScore == currentDxScore) {
              if (_isFcBetter(newFc, currentFc)) {
                needUpdate = true;
              }
            }
          }
          
          if (needUpdate) {
            redisCommands.add(['ZADD', item['rateKey'], newAchievementRate.toString(), playerId]);
            redisCommands.add(['ZADD', item['scoreKey'], newDxScore.toString(), playerId]);
            redisCommands.add(['SET', item['fcKey'], newFc]);
            redisCommands.add(['SET', item['updateTimeKey'], DateTime.now().millisecondsSinceEpoch.toString()]);
            updatedCount++;
          } else {
            skippedCount++;
          }
        }
        
        // 优化6：批量执行更新命令
        if (redisCommands.isNotEmpty) {
          debugPrint('[SongRankingService] Sending ${redisCommands.length} Redis update commands');
          List<Future<dynamic>> updateFutures = [];
          for (var command in redisCommands) {
            updateFutures.add(conn.send_object(command));
          }
          await Future.wait(updateFutures);
        }
        
        debugPrint('[SongRankingService] Updated $updatedCount records, skipped $skippedCount records for player $playerId');
      } finally {
        try {
          await conn.send_object(['QUIT']);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[SongRankingService] Redis error in updateSongRankings: $e');
    }
  }
  
  // 判断新FC是否比旧FC更好
  bool _isFcBetter(String newFc, String currentFc) {
    // FC优先级：AP+ > AP > FC > 无
    Map<String, int> fcPriority = {
      'app': 3,
      'AP+': 3,
      'ap': 2,
      'AP': 2,
      'fc': 1,
      'FC': 1,
    };
    
    int newPriority = fcPriority[newFc.toLowerCase()] ?? 0;
    int currentPriority = fcPriority[currentFc.toLowerCase()] ?? 0;
    
    return newPriority > currentPriority;
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
      final conn = await RedisConnection().connect(redisHost, redisPort);
      
      try {
        await conn.send_object(['AUTH', redisPassword]);
        
        await conn.send_object(['DEL', 'player:name:$playerId']);
        
        debugPrint('[SongRankingService] Deleted player name for $playerId');
      } finally {
        try {
          await conn.send_object(['QUIT']);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[SongRankingService] Redis error in deleteSongRankings: $e');
    }
  }
}