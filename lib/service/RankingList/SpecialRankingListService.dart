import 'package:flutter/foundation.dart';
import 'package:redis/redis.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_first_flutter_app/api/DeveloperToken.dart';
import 'package:my_first_flutter_app/manager/DivingFish/MaimaiMusicDataManager.dart';
import 'package:my_first_flutter_app/manager/DivingFish/DiffMusicDataManager.dart';
import 'package:my_first_flutter_app/entity/DivingFish/Song.dart';
import 'package:my_first_flutter_app/entity/DivingFish/DiffSong.dart';
import 'package:my_first_flutter_app/manager/MaidataManager.dart';
import 'package:my_first_flutter_app/constant/CacheKeyConstant.dart';
import 'package:my_first_flutter_app/utils/MaidataDecodeUtil.dart';
import 'dart:convert';

enum SpecialRankingType {
  breakCount, // 绝赞总数排行榜（谱面）
}

class SpecialRankingEntry {
  final int rank;
  final String songId;
  final String songTitle;
  final String songType; // ST/DX/UTAGE
  final int difficultyIndex;
  final String difficultyLabel;
  final double ds;
  final int breakCount;
  final int updateTime;

  SpecialRankingEntry({
    required this.rank,
    required this.songId,
    required this.songTitle,
    required this.songType,
    required this.difficultyIndex,
    required this.difficultyLabel,
    required this.ds,
    required this.breakCount,
    required this.updateTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'rank': rank,
      'songId': songId,
      'songTitle': songTitle,
      'songType': songType,
      'difficultyIndex': difficultyIndex,
      'difficultyLabel': difficultyLabel,
      'ds': ds,
      'breakCount': breakCount,
      'updateTime': updateTime,
    };
  }
}

class SpecialRankingListService {
  static final SpecialRankingListService _instance = SpecialRankingListService._internal();
  
  factory SpecialRankingListService() {
    return _instance;
  }
  
  SpecialRankingListService._internal();

  static String get redisHost => DeveloperToken.RedisHost;
  static int get redisPort => DeveloperToken.RedisPort;
  static String get redisPassword => DeveloperToken.RedisPassword;
  
  // 远程缓存过期时间：7天
  static const int cacheExpireDays = 7;
  static const int cacheExpireSeconds = cacheExpireDays * 24 * 60 * 60;
  
  // 远程缓存key前缀
  static const String remoteCacheKey = 'special:break_count_ranking_remote';

  // 定数差值排行榜相关缓存key
  static const String diffCacheKey = 'special:difficulty_diff_ranking_remote';

  // MASTER/RE:MASTER定数差值排行榜相关缓存key
  static const String masterDiffCacheKey = 'special:master_diff_ranking_remote';

  // EXPERT定数差值排行榜相关缓存key
  static const String expertDiffCacheKey = 'special:expert_diff_ranking_remote';

  // 反向定数差值排行榜相关缓存key
  static const String reverseDiffCacheKey = 'special:reverse_diff_ranking_remote';

  // 反向MASTER/RE:MASTER定数差值排行榜相关缓存key
  static const String reverseMasterDiffCacheKey = 'special:reverse_master_diff_ranking_remote';

  // 反向EXPERT定数差值排行榜相关缓存key
  static const String reverseExpertDiffCacheKey = 'special:reverse_expert_diff_ranking_remote';

  // 样本总数排行榜相关缓存key
  static const String sampleCountCacheKey = 'special:sample_count_ranking_remote';

  // 物量排行榜相关缓存key
  static const String noteCountCacheKey = 'special:note_count_ranking_remote';

  // 平均达成排行榜相关缓存key
  static const String avgAchievementCacheKey = 'special:avg_achievement_ranking_remote';

  // MASTER/RE:MASTER平均达成排行榜相关缓存key
  static const String masterAvgAchievementCacheKey = 'special:master_avg_achievement_ranking_remote';

  // EXPERT平均达成排行榜相关缓存key
  static const String expertAvgAchievementCacheKey = 'special:expert_avg_achievement_ranking_remote';

  /// 仅读取缓存，不触发重新计算。缓存不存在时返回空列表，页面可据此决定是否显示重新计算进度。
  Future<List<SpecialRankingEntry>> getBreakCountRanking({
    int limit = 100,
  }) async {
    List<SpecialRankingEntry> result = [];
    
    try {
      final conn = await RedisConnection().connect(redisHost, redisPort);
      
      try {
        await conn.send_object(['AUTH', redisPassword]);
        
        String key = 'special:song_break_count';
        debugPrint('[SpecialRankingListService] Fetching song break count ranking from Redis: $key');
        
        List<dynamic> redisResult = await conn.send_object(
          ['ZREVRANGE', key, 0, limit - 1, 'WITHSCORES']
        );
        
        // 检查本地缓存是否为空
        bool localCacheEmpty = redisResult == null || redisResult.isEmpty;
        
        if (localCacheEmpty) {
          debugPrint('[SpecialRankingListService] Local cache is empty, checking remote cache');

          // 检查远程缓存是否存在（由Redis自动根据TTL过期）
          dynamic remoteData = await conn.send_object(['GET', remoteCacheKey]);
          bool remoteCacheValid = remoteData is String && remoteData.isNotEmpty;

          if (remoteCacheValid) {
            // 远程缓存有效，加载远程缓存
            debugPrint('[SpecialRankingListService] Loading from remote cache');
            String rawRemoteData = remoteData;
            try {
              List<dynamic> remoteList = json.decode(rawRemoteData);
              for (int i = 0; i < remoteList.length; i++) {
                Map<String, dynamic> item = remoteList[i];
                result.add(SpecialRankingEntry(
                  rank: i + 1,
                  songId: item['songId'],
                  songTitle: item['songTitle'],
                  songType: item['songType'],
                  difficultyIndex: item['difficultyIndex'],
                  difficultyLabel: item['difficultyLabel'],
                  ds: item['ds'],
                  breakCount: item['breakCount'],
                  updateTime: item['updateTime'],
                ));
              }
              debugPrint('[SpecialRankingListService] Loaded ${result.length} entries from remote cache');
            } catch (e) {
              debugPrint('[SpecialRankingListService] Failed to parse remote cache: $e');
            }
          }
          
          // 缓存不存在也不触发重新计算，由调用方决定是否显示重新计算进度
          if (result.isEmpty) {
            debugPrint('[SpecialRankingListService] No cached data available, returning empty. Page should trigger background recalc.');
          }
        }
        
        if (!localCacheEmpty && redisResult != null && redisResult.isNotEmpty) {
          // 预构建歌曲映射表，O(1)查找
          final songManager = MaimaiMusicDataManager();
          List<Song>? songs = await songManager.getCachedSongs();
          Map<String, Song> songMap = {};
          if (songs != null) {
            for (Song song in songs) {
              songMap[song.id] = song;
            }
          }
          
          // 收集所有需要查询的key，准备批量获取更新时间
          List<String> updateTimeKeys = [];
          List<Map<String, dynamic>> parsedEntries = [];
          
          for (int i = 0; i < redisResult.length; i += 2) {
            String songKey = redisResult[i] as String;
            dynamic scoreValue = redisResult[i + 1];
            
            int breakCount = 0;
            if (scoreValue is num) {
              breakCount = scoreValue.toInt();
            } else if (scoreValue is String) {
              breakCount = int.tryParse(scoreValue) ?? 0;
            }
            
            List<String> parts = songKey.split(':');
            if (parts.length >= 2) {
              String songId = parts[0];
              int difficultyIndex = int.tryParse(parts[1]) ?? 0;
              
              // 从映射表获取歌曲信息，O(1)复杂度
              Song? song = songMap[songId];
              String songTitle = song?.title ?? '未知歌曲';
              String songType = song?.type ?? 'ST';
              String difficultyLabel = _getDifficultyLabel(songId, difficultyIndex);
              double ds = _getDifficultyDs(song, difficultyIndex);
              
              // 收集更新时间查询key
              updateTimeKeys.add('special:song_break_count:updateTime:$songKey');
              
              parsedEntries.add({
                'rank': i ~/ 2 + 1,
                'songId': songId,
                'songTitle': songTitle,
                'songType': songType,
                'difficultyIndex': difficultyIndex,
                'difficultyLabel': difficultyLabel,
                'ds': ds,
                'breakCount': breakCount,
                'songKey': songKey,
              });
            }
          }
          
          // 批量获取所有更新时间，一次Redis请求替代多次请求
          Map<String, int> updateTimeMap = {};
          if (updateTimeKeys.isNotEmpty) {
            List<dynamic> mgetResult = await conn.send_object(['MGET', ...updateTimeKeys]);
            for (int i = 0; i < updateTimeKeys.length; i++) {
              dynamic value = mgetResult[i];
              int updateTime = 0;
              if (value is String) {
                updateTime = int.tryParse(value) ?? 0;
              }
              updateTimeMap[updateTimeKeys[i]] = updateTime;
            }
          }
          
          // 构建结果列表
          for (Map<String, dynamic> entry in parsedEntries) {
            String updateTimeKey = 'special:song_break_count:updateTime:${entry['songKey']}';
            int updateTime = updateTimeMap[updateTimeKey] ?? 0;
            
            result.add(SpecialRankingEntry(
              rank: entry['rank'] as int,
              songId: entry['songId'] as String,
              songTitle: entry['songTitle'] as String,
              songType: entry['songType'] as String,
              difficultyIndex: entry['difficultyIndex'] as int,
              difficultyLabel: entry['difficultyLabel'] as String,
              ds: entry['ds'] as double,
              breakCount: entry['breakCount'] as int,
              updateTime: updateTime,
            ));
          }
        }
        
        debugPrint('[SpecialRankingListService] Fetched ${result.length} entries');
      } finally {
        try {
          await conn.send_object(['QUIT']);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[SpecialRankingListService] Redis error: $e');
    }
    
    return result;
  }

  // 获取定数差值排行榜（拟合定数 - 官方定数）
  Future<List<SpecialRankingEntry>> getDifficultyDiffRanking({
    int limit = 100,
    Function(int)? onProgress,
  }) async {
    List<SpecialRankingEntry> result = [];
    
    try {
      final conn = await RedisConnection().connect(redisHost, redisPort);
      
      try {
        await conn.send_object(['AUTH', redisPassword]);
        
        // 检查远程缓存是否存在（由Redis自动根据TTL过期）
        dynamic remoteData = await conn.send_object(['GET', diffCacheKey]);
        bool remoteCacheValid = remoteData is String && remoteData.isNotEmpty;

        if (remoteCacheValid) {
          debugPrint('[SpecialRankingListService] Loading difficulty diff ranking from remote cache');
          String rawRemoteData = remoteData;
          try {
            List<dynamic> remoteList = json.decode(rawRemoteData);
            for (int i = 0; i < remoteList.length && i < limit; i++) {
              Map<String, dynamic> item = remoteList[i];
              result.add(SpecialRankingEntry(
                rank: i + 1,
                songId: item['songId'],
                songTitle: item['songTitle'],
                songType: item['songType'],
                difficultyIndex: item['difficultyIndex'],
                difficultyLabel: item['difficultyLabel'],
                ds: item['ds'],
                breakCount: item['breakCount'], // 这里用breakCount存储差值
                updateTime: item['updateTime'],
              ));
            }
            debugPrint('[SpecialRankingListService] Loaded ${result.length} entries from remote cache');
            return result;
          } catch (e) {
            debugPrint('[SpecialRankingListService] Failed to parse remote cache: $e');
          }
        }
        
        // 缓存无效，重新计算
        debugPrint('[SpecialRankingListService] Remote cache empty or expired, recalculating difficulty diff ranking...');
        
        // 先一次性获取所有diff数据，避免重复查询
        final diffManager = DiffMusicDataManager();
        DiffSong? diffSong = await diffManager.getCachedDiffData();
        
        if (diffSong == null) {
          // 如果没有缓存，尝试从API获取
          debugPrint('[SpecialRankingListService] Fetching diff data from API...');
          await diffManager.fetchAndUpdateDiffData();
          diffSong = await diffManager.getCachedDiffData();
        }
        
        // 获取歌曲列表
        final songManager = MaimaiMusicDataManager();
        List<Song>? songs = await songManager.getCachedSongs();
        
        if (songs == null || songs.isEmpty) {
          debugPrint('[SpecialRankingListService] No songs found');
          return result;
        }
        
        // 如果没有diff数据，直接返回空结果
        if (diffSong == null) {
          debugPrint('[SpecialRankingListService] No diff data available');
          return result;
        }
        
        // 获取需要排除的maidata追加歌曲ID
        Set<String> excludedSongIds = await _getMaidataAddedSongIds();
        
        // 用于存储定数差值
        List<Map<String, dynamic>> diffList = [];
        
        int totalSongs = songs.length;
        int processedCount = 0;
        
        // 遍历歌曲，使用内存中的diff数据进行查询
        for (Song song in songs) {
          // 过滤掉maidata追加的歌曲
          if (excludedSongIds.contains(song.id)) {
            processedCount++;
            continue;
          }
          try {
            // 从内存中获取该歌曲的diff数据（O(1)查询）
            List<DiffData>? songDiffDataList = diffSong.charts[song.id];
            
            if (songDiffDataList == null || songDiffDataList.isEmpty) {
              processedCount++;
              continue;
            }
            
            // 遍历每个难度
            for (int i = 0; i < song.ds.length; i++) {
              double officialDs = song.ds[i];
              double ratedDs = 0.0;
              
              // 从diffData获取拟合定数
              if (i < songDiffDataList.length) {
                DiffData diffData = songDiffDataList[i];
                ratedDs = diffData.fitDiff.toDouble();
              }
              
              // 计算差值
              double diff = ratedDs - officialDs;
              
              // 只有有效数据才加入排行榜
              if (ratedDs > 0 && officialDs > 0) {
                diffList.add({
                  'songId': song.id,
                  'songTitle': song.title,
                  'songType': song.type,
                  'difficultyIndex': i,
                  'officialDs': officialDs,
                  'ratedDs': ratedDs,
                  'diff': diff,
                });
              }
            }
            
            processedCount++;
            if (onProgress != null) {
              onProgress((processedCount * 100) ~/ totalSongs);
            }
          } catch (e) {
            debugPrint('[SpecialRankingListService] Error processing song ${song.id}: $e');
            processedCount++;
          }
        }
        
        // 按差值降序排序
        diffList.sort((a, b) => (b['diff'] as double).compareTo(a['diff'] as double));
        
        // 取前limit个
        List<Map<String, dynamic>> topEntries = diffList.take(limit).toList();
        
        // 构建结果
        for (int i = 0; i < topEntries.length; i++) {
          Map<String, dynamic> entry = topEntries[i];
          String songId = entry['songId'];
          int difficultyIndex = entry['difficultyIndex'];
          
          result.add(SpecialRankingEntry(
            rank: i + 1,
            songId: songId,
            songTitle: entry['songTitle'],
            songType: entry['songType'],
            difficultyIndex: difficultyIndex,
            difficultyLabel: _getDifficultyLabel(songId, difficultyIndex),
            ds: entry['officialDs'],
            breakCount: (entry['diff'] * 100).toInt(), // 存储差值*100作为整数
            updateTime: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ));
        }
        
        // 缓存到远程
        if (result.isNotEmpty) {
          await conn.send_object(['SET', diffCacheKey, json.encode(result), 'EX', cacheExpireSeconds.toString()]);
          debugPrint('[SpecialRankingListService] Difficulty diff ranking cached to remote');
        }
        
        debugPrint('[SpecialRankingListService] Calculated ${result.length} difficulty diff entries');
        
      } finally {
        try {
          await conn.send_object(['QUIT']);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[SpecialRankingListService] Redis error in getDifficultyDiffRanking: $e');
    }
    
    return result;
  }

  // 获取MASTER/RE:MASTER定数差值排行榜（只统计levelIndex为3和4的谱面）
  Future<List<SpecialRankingEntry>> getMasterDifficultyDiffRanking({
    int limit = 100,
    Function(int)? onProgress,
  }) async {
    List<SpecialRankingEntry> result = [];
    
    try {
      final conn = await RedisConnection().connect(redisHost, redisPort);
      
      try {
        await conn.send_object(['AUTH', redisPassword]);
        
        // 检查远程缓存是否存在（由Redis自动根据TTL过期）
        dynamic remoteData = await conn.send_object(['GET', masterDiffCacheKey]);
        bool remoteCacheValid = remoteData is String && remoteData.isNotEmpty;

        if (remoteCacheValid) {
          debugPrint('[SpecialRankingListService] Loading master diff ranking from remote cache');
          String rawRemoteData = remoteData;
          try {
            List<dynamic> remoteList = json.decode(rawRemoteData);
            for (int i = 0; i < remoteList.length && i < limit; i++) {
              Map<String, dynamic> item = remoteList[i];
              result.add(SpecialRankingEntry(
                rank: i + 1,
                songId: item['songId'],
                songTitle: item['songTitle'],
                songType: item['songType'],
                difficultyIndex: item['difficultyIndex'],
                difficultyLabel: item['difficultyLabel'],
                ds: item['ds'],
                breakCount: item['breakCount'],
                updateTime: item['updateTime'],
              ));
            }
            debugPrint('[SpecialRankingListService] Loaded ${result.length} entries from remote cache');
            return result;
          } catch (e) {
            debugPrint('[SpecialRankingListService] Failed to parse remote cache: $e');
          }
        }
        
        // 缓存无效，重新计算
        debugPrint('[SpecialRankingListService] Remote cache empty or expired, recalculating master diff ranking...');
        
        // 先一次性获取所有diff数据，避免重复查询
        final diffManager = DiffMusicDataManager();
        DiffSong? diffSong = await diffManager.getCachedDiffData();
        
        if (diffSong == null) {
          debugPrint('[SpecialRankingListService] Fetching diff data from API...');
          await diffManager.fetchAndUpdateDiffData();
          diffSong = await diffManager.getCachedDiffData();
        }
        
        // 获取歌曲列表
        final songManager = MaimaiMusicDataManager();
        List<Song>? songs = await songManager.getCachedSongs();
        
        if (songs == null || songs.isEmpty) {
          debugPrint('[SpecialRankingListService] No songs found');
          return result;
        }
        
        if (diffSong == null) {
          debugPrint('[SpecialRankingListService] No diff data available');
          return result;
        }
        
        // 获取需要排除的maidata追加歌曲ID
        Set<String> excludedSongIds = await _getMaidataAddedSongIds();
        
        // 用于存储定数差值（只统计MASTER/RE:MASTER，即levelIndex为3和4）
        List<Map<String, dynamic>> diffList = [];
        
        int totalSongs = songs.length;
        int processedCount = 0;
        
        for (Song song in songs) {
          // 过滤掉maidata追加的歌曲
          if (excludedSongIds.contains(song.id)) {
            processedCount++;
            continue;
          }
          try {
            List<DiffData>? songDiffDataList = diffSong.charts[song.id];
            
            if (songDiffDataList == null || songDiffDataList.isEmpty) {
              processedCount++;
              continue;
            }
            
            // 只统计MASTER(3)和RE:MASTER(4)难度
            for (int i = 3; i <= 4 && i < song.ds.length; i++) {
              double officialDs = song.ds[i];
              double ratedDs = 0.0;
              
              if (i < songDiffDataList.length) {
                DiffData diffData = songDiffDataList[i];
                ratedDs = diffData.fitDiff.toDouble();
              }
              
              double diff = ratedDs - officialDs;
              
              if (ratedDs > 0 && officialDs > 0) {
                diffList.add({
                  'songId': song.id,
                  'songTitle': song.title,
                  'songType': song.type,
                  'difficultyIndex': i,
                  'officialDs': officialDs,
                  'ratedDs': ratedDs,
                  'diff': diff,
                });
              }
            }
            
            processedCount++;
            if (onProgress != null) {
              onProgress((processedCount * 100) ~/ totalSongs);
            }
          } catch (e) {
            debugPrint('[SpecialRankingListService] Error processing song ${song.id}: $e');
            processedCount++;
          }
        }
        
        // 按差值降序排序
        diffList.sort((a, b) => (b['diff'] as double).compareTo(a['diff'] as double));
        
        List<Map<String, dynamic>> topEntries = diffList.take(limit).toList();
        
        for (int i = 0; i < topEntries.length; i++) {
          Map<String, dynamic> entry = topEntries[i];
          String songId = entry['songId'];
          int difficultyIndex = entry['difficultyIndex'];
          
          result.add(SpecialRankingEntry(
            rank: i + 1,
            songId: songId,
            songTitle: entry['songTitle'],
            songType: entry['songType'],
            difficultyIndex: difficultyIndex,
            difficultyLabel: _getDifficultyLabel(songId, difficultyIndex),
            ds: entry['officialDs'],
            breakCount: (entry['diff'] * 100).toInt(),
            updateTime: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ));
        }
        
        // 缓存到远程
        if (result.isNotEmpty) {
          await conn.send_object(['SET', masterDiffCacheKey, json.encode(result), 'EX', cacheExpireSeconds.toString()]);
          debugPrint('[SpecialRankingListService] Master diff ranking cached to remote');
        }
        
        debugPrint('[SpecialRankingListService] Calculated ${result.length} master diff entries');
        
      } finally {
        try {
          await conn.send_object(['QUIT']);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[SpecialRankingListService] Redis error in getMasterDifficultyDiffRanking: $e');
    }
    
    return result;
  }

  // 获取EXPERT定数差值排行榜（只统计levelIndex为2的谱面）
  Future<List<SpecialRankingEntry>> getExpertDifficultyDiffRanking({
    int limit = 100,
    Function(int)? onProgress,
  }) async {
    List<SpecialRankingEntry> result = [];
    
    try {
      final conn = await RedisConnection().connect(redisHost, redisPort);
      
      try {
        await conn.send_object(['AUTH', redisPassword]);
        
        // 检查远程缓存是否存在（由Redis自动根据TTL过期）
        dynamic remoteData = await conn.send_object(['GET', expertDiffCacheKey]);
        bool remoteCacheValid = remoteData is String && remoteData.isNotEmpty;

        if (remoteCacheValid) {
          debugPrint('[SpecialRankingListService] Loading expert diff ranking from remote cache');
          String rawRemoteData = remoteData;
          try {
            List<dynamic> remoteList = json.decode(rawRemoteData);
            for (var item in remoteList) {
              result.add(SpecialRankingEntry(
                rank: item['rank'],
                songId: item['songId'],
                songTitle: item['songTitle'],
                songType: item['songType'],
                difficultyIndex: item['difficultyIndex'],
                difficultyLabel: item['difficultyLabel'],
                ds: item['ds'],
                breakCount: item['breakCount'],
                updateTime: item['updateTime'],
              ));
            }
          } catch (e) {
            debugPrint('[SpecialRankingListService] Failed to parse remote expert diff ranking: $e');
          }
        }
        
        if (result.isEmpty) {
          debugPrint('[SpecialRankingListService] Remote cache empty or expired, recalculating expert diff ranking...');
          
          // 先一次性获取所有diff数据，避免重复查询
          final diffManager = DiffMusicDataManager();
          DiffSong? diffSong = await diffManager.getCachedDiffData();
          
          if (diffSong == null) {
            debugPrint('[SpecialRankingListService] Fetching diff data from API...');
            await diffManager.fetchAndUpdateDiffData();
            diffSong = await diffManager.getCachedDiffData();
          }
          
          // 获取歌曲列表
          final songManager = MaimaiMusicDataManager();
          List<Song>? songs = await songManager.getCachedSongs();
          
          if (songs == null || songs.isEmpty) {
            debugPrint('[SpecialRankingListService] No songs found');
            return result;
          }
          
          if (diffSong == null) {
            debugPrint('[SpecialRankingListService] No diff data available');
            return result;
          }
          
          // 获取需要排除的maidata追加歌曲ID
          Set<String> excludedSongIds = await _getMaidataAddedSongIds();
          
          // 用于存储定数差值（只统计EXPERT，即levelIndex为2）
          List<Map<String, dynamic>> diffList = [];
          
          int totalSongs = songs.length;
          int processedCount = 0;
          
          for (Song song in songs) {
            // 过滤掉maidata追加的歌曲
            if (excludedSongIds.contains(song.id)) {
              processedCount++;
              continue;
            }
            try {
              List<DiffData>? songDiffDataList = diffSong.charts[song.id];
              
              if (songDiffDataList == null || songDiffDataList.isEmpty) {
                processedCount++;
                continue;
              }
              
              // 只统计EXPERT(2)难度
              int i = 2;
              if (i < song.ds.length) {
                double officialDs = song.ds[i];
                double ratedDs = 0.0;
                
                if (i < songDiffDataList.length) {
                  DiffData diffData = songDiffDataList[i];
                  ratedDs = diffData.fitDiff.toDouble();
                }
                
                double diff = ratedDs - officialDs;
                
                if (ratedDs > 0 && officialDs > 0) {
                  diffList.add({
                    'songId': song.id,
                    'songTitle': song.title,
                    'songType': song.type,
                    'difficultyIndex': i,
                    'officialDs': officialDs,
                    'ratedDs': ratedDs,
                    'diff': diff,
                  });
                }
              }
              
              processedCount++;
              if (onProgress != null) {
                onProgress((processedCount * 100) ~/ totalSongs);
              }
            } catch (e) {
              debugPrint('[SpecialRankingListService] Error processing song ${song.id}: $e');
              processedCount++;
            }
          }
          
          // 按差值降序排序
          diffList.sort((a, b) => (b['diff'] as double).compareTo(a['diff'] as double));
          
          List<Map<String, dynamic>> topEntries = diffList.take(limit).toList();
          
          for (int i = 0; i < topEntries.length; i++) {
            Map<String, dynamic> entry = topEntries[i];
            String songId = entry['songId'];
            int difficultyIndex = entry['difficultyIndex'];
            
            result.add(SpecialRankingEntry(
              rank: i + 1,
              songId: songId,
              songTitle: entry['songTitle'],
              songType: entry['songType'],
              difficultyIndex: difficultyIndex,
              difficultyLabel: _getDifficultyLabel(songId, difficultyIndex),
              ds: entry['officialDs'],
              breakCount: (entry['diff'] * 100).toInt(),
              updateTime: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ));
          }
          
          // 缓存到远程
          if (result.isNotEmpty) {
            await conn.send_object(['SET', expertDiffCacheKey, json.encode(result), 'EX', cacheExpireSeconds.toString()]);
            debugPrint('[SpecialRankingListService] Expert diff ranking cached to remote');
          }
          
          debugPrint('[SpecialRankingListService] Calculated ${result.length} expert diff entries');
        }
      } finally {
        try {
          await conn.send_object(['QUIT']);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[SpecialRankingListService] Redis error in getExpertDifficultyDiffRanking: $e');
    }
    
    return result;
  }

  // 获取反向定数差值排行榜（拟合定数-官方定数最小的前100位）
  Future<List<SpecialRankingEntry>> getReverseDifficultyDiffRanking({
    int limit = 100,
    Function(int)? onProgress,
  }) async {
    List<SpecialRankingEntry> result = [];
    
    try {
      final conn = await RedisConnection().connect(redisHost, redisPort);
      
      try {
        await conn.send_object(['AUTH', redisPassword]);
        
        // 检查远程缓存是否存在（由Redis自动根据TTL过期）
        dynamic remoteData = await conn.send_object(['GET', reverseDiffCacheKey]);
        bool remoteCacheValid = remoteData is String && remoteData.isNotEmpty;

        if (remoteCacheValid) {
          debugPrint('[SpecialRankingListService] Loading reverse diff ranking from remote cache');
          String rawRemoteData = remoteData;
          try {
            List<dynamic> remoteList = json.decode(rawRemoteData);
            for (var item in remoteList) {
              result.add(SpecialRankingEntry(
                rank: item['rank'],
                songId: item['songId'],
                songTitle: item['songTitle'],
                songType: item['songType'],
                difficultyIndex: item['difficultyIndex'],
                difficultyLabel: item['difficultyLabel'],
                ds: item['ds'],
                breakCount: item['breakCount'],
                updateTime: item['updateTime'],
              ));
            }
          } catch (e) {
            debugPrint('[SpecialRankingListService] Failed to parse remote reverse diff ranking: $e');
          }
        }
        
        if (result.isEmpty) {
          debugPrint('[SpecialRankingListService] Remote cache empty or expired, recalculating reverse diff ranking...');
          
          // 先一次性获取所有diff数据，避免重复查询
          final diffManager = DiffMusicDataManager();
          DiffSong? diffSong = await diffManager.getCachedDiffData();
          
          if (diffSong == null) {
            debugPrint('[SpecialRankingListService] Fetching diff data from API...');
            await diffManager.fetchAndUpdateDiffData();
            diffSong = await diffManager.getCachedDiffData();
          }
          
          // 获取歌曲列表
          final songManager = MaimaiMusicDataManager();
          List<Song>? songs = await songManager.getCachedSongs();
          
          if (songs == null || songs.isEmpty) {
            debugPrint('[SpecialRankingListService] No songs found');
            return result;
          }
          
          if (diffSong == null) {
            debugPrint('[SpecialRankingListService] No diff data available');
            return result;
          }
          
          // 获取需要排除的maidata追加歌曲ID
          Set<String> excludedSongIds = await _getMaidataAddedSongIds();
          
          // 用于存储定数差值
          List<Map<String, dynamic>> diffList = [];
          
          int totalSongs = songs.length;
          int processedCount = 0;
          
          for (Song song in songs) {
            if (excludedSongIds.contains(song.id)) {
              processedCount++;
              continue;
            }
            
            try {
              List<DiffData>? songDiffDataList = diffSong.charts[song.id];
              
              if (songDiffDataList == null || songDiffDataList.isEmpty) {
                processedCount++;
                continue;
              }
              
              // 遍历所有难度
              for (int i = 0; i < song.ds.length; i++) {
                double officialDs = song.ds[i];
                double ratedDs = 0.0;
                
                if (i < songDiffDataList.length) {
                  DiffData diffData = songDiffDataList[i];
                  ratedDs = diffData.fitDiff.toDouble();
                }
                
                double diff = ratedDs - officialDs;
                
                if (ratedDs > 0 && officialDs > 0) {
                  diffList.add({
                    'songId': song.id,
                    'songTitle': song.title,
                    'songType': song.type,
                    'difficultyIndex': i,
                    'officialDs': officialDs,
                    'ratedDs': ratedDs,
                    'diff': diff,
                  });
                }
              }
              
              processedCount++;
              if (onProgress != null) {
                onProgress((processedCount * 100) ~/ totalSongs);
              }
            } catch (e) {
              debugPrint('[SpecialRankingListService] Error processing song ${song.id}: $e');
              processedCount++;
            }
          }
          
          // 按差值升序排序（反向排序，取最小的）
          diffList.sort((a, b) => (a['diff'] as double).compareTo(b['diff'] as double));
          
          List<Map<String, dynamic>> topEntries = diffList.take(limit).toList();
          
          for (int i = 0; i < topEntries.length; i++) {
            Map<String, dynamic> entry = topEntries[i];
            String songId = entry['songId'];
            int difficultyIndex = entry['difficultyIndex'];
            
            result.add(SpecialRankingEntry(
              rank: i + 1,
              songId: songId,
              songTitle: entry['songTitle'],
              songType: entry['songType'],
              difficultyIndex: difficultyIndex,
              difficultyLabel: _getDifficultyLabel(songId, difficultyIndex),
              ds: entry['officialDs'],
              breakCount: (entry['diff'] * 100).toInt(),
              updateTime: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ));
          }
          
          // 缓存到远程
          if (result.isNotEmpty) {
            await conn.send_object(['SET', reverseDiffCacheKey, json.encode(result), 'EX', cacheExpireSeconds.toString()]);
            debugPrint('[SpecialRankingListService] Reverse diff ranking cached to remote');
          }
          
          debugPrint('[SpecialRankingListService] Calculated ${result.length} reverse diff entries');
        }
      } finally {
        try {
          await conn.send_object(['QUIT']);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[SpecialRankingListService] Redis error in getReverseDifficultyDiffRanking: $e');
    }
    
    return result;
  }

  // 获取反向MASTER/RE:MASTER定数差值排行榜
  Future<List<SpecialRankingEntry>> getReverseMasterDifficultyDiffRanking({
    int limit = 100,
    Function(int)? onProgress,
  }) async {
    List<SpecialRankingEntry> result = [];
    
    try {
      final conn = await RedisConnection().connect(redisHost, redisPort);
      
      try {
        await conn.send_object(['AUTH', redisPassword]);
        
        // 检查远程缓存是否存在（由Redis自动根据TTL过期）
        dynamic remoteData = await conn.send_object(['GET', reverseMasterDiffCacheKey]);
        bool remoteCacheValid = remoteData is String && remoteData.isNotEmpty;

        if (remoteCacheValid) {
          debugPrint('[SpecialRankingListService] Loading reverse master diff ranking from remote cache');
          String rawRemoteData = remoteData;
          try {
            List<dynamic> remoteList = json.decode(rawRemoteData);
            for (var item in remoteList) {
              result.add(SpecialRankingEntry(
                rank: item['rank'],
                songId: item['songId'],
                songTitle: item['songTitle'],
                songType: item['songType'],
                difficultyIndex: item['difficultyIndex'],
                difficultyLabel: item['difficultyLabel'],
                ds: item['ds'],
                breakCount: item['breakCount'],
                updateTime: item['updateTime'],
              ));
            }
          } catch (e) {
            debugPrint('[SpecialRankingListService] Failed to parse remote reverse master diff ranking: $e');
          }
        }
        
        if (result.isEmpty) {
          debugPrint('[SpecialRankingListService] Remote cache empty or expired, recalculating reverse master diff ranking...');
          
          // 先一次性获取所有diff数据，避免重复查询
          final diffManager = DiffMusicDataManager();
          DiffSong? diffSong = await diffManager.getCachedDiffData();
          
          if (diffSong == null) {
            debugPrint('[SpecialRankingListService] Fetching diff data from API...');
            await diffManager.fetchAndUpdateDiffData();
            diffSong = await diffManager.getCachedDiffData();
          }
          
          // 获取歌曲列表
          final songManager = MaimaiMusicDataManager();
          List<Song>? songs = await songManager.getCachedSongs();
          
          if (songs == null || songs.isEmpty) {
            debugPrint('[SpecialRankingListService] No songs found');
            return result;
          }
          
          if (diffSong == null) {
            debugPrint('[SpecialRankingListService] No diff data available');
            return result;
          }
          
          // 获取需要排除的maidata追加歌曲ID
          Set<String> excludedSongIds = await _getMaidataAddedSongIds();
          
          // 用于存储定数差值（只统计MASTER/RE:MASTER，即levelIndex为3和4）
          List<Map<String, dynamic>> diffList = [];
          
          int totalSongs = songs.length;
          int processedCount = 0;
          
          for (Song song in songs) {
            if (excludedSongIds.contains(song.id)) {
              processedCount++;
              continue;
            }
            
            try {
              List<DiffData>? songDiffDataList = diffSong.charts[song.id];
              
              if (songDiffDataList == null || songDiffDataList.isEmpty) {
                processedCount++;
                continue;
              }
              
              // 只统计MASTER(3)和RE:MASTER(4)难度
              for (int i = 3; i <= 4 && i < song.ds.length; i++) {
                double officialDs = song.ds[i];
                double ratedDs = 0.0;
                
                if (i < songDiffDataList.length) {
                  DiffData diffData = songDiffDataList[i];
                  ratedDs = diffData.fitDiff.toDouble();
                }
                
                double diff = ratedDs - officialDs;
                
                if (ratedDs > 0 && officialDs > 0) {
                  diffList.add({
                    'songId': song.id,
                    'songTitle': song.title,
                    'songType': song.type,
                    'difficultyIndex': i,
                    'officialDs': officialDs,
                    'ratedDs': ratedDs,
                    'diff': diff,
                  });
                }
              }
              
              processedCount++;
              if (onProgress != null) {
                onProgress((processedCount * 100) ~/ totalSongs);
              }
            } catch (e) {
              debugPrint('[SpecialRankingListService] Error processing song ${song.id}: $e');
              processedCount++;
            }
          }
          
          // 按差值升序排序（反向排序，取最小的）
          diffList.sort((a, b) => (a['diff'] as double).compareTo(b['diff'] as double));
          
          List<Map<String, dynamic>> topEntries = diffList.take(limit).toList();
          
          for (int i = 0; i < topEntries.length; i++) {
            Map<String, dynamic> entry = topEntries[i];
            String songId = entry['songId'];
            int difficultyIndex = entry['difficultyIndex'];
            
            result.add(SpecialRankingEntry(
              rank: i + 1,
              songId: songId,
              songTitle: entry['songTitle'],
              songType: entry['songType'],
              difficultyIndex: difficultyIndex,
              difficultyLabel: _getDifficultyLabel(songId, difficultyIndex),
              ds: entry['officialDs'],
              breakCount: (entry['diff'] * 100).toInt(),
              updateTime: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ));
          }
          
          // 缓存到远程
          if (result.isNotEmpty) {
            await conn.send_object(['SET', reverseMasterDiffCacheKey, json.encode(result), 'EX', cacheExpireSeconds.toString()]);
            debugPrint('[SpecialRankingListService] Reverse master diff ranking cached to remote');
          }
          
          debugPrint('[SpecialRankingListService] Calculated ${result.length} reverse master diff entries');
        }
      } finally {
        try {
          await conn.send_object(['QUIT']);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[SpecialRankingListService] Redis error in getReverseMasterDifficultyDiffRanking: $e');
    }
    
    return result;
  }

  // 获取反向EXPERT定数差值排行榜
  Future<List<SpecialRankingEntry>> getReverseExpertDifficultyDiffRanking({
    int limit = 100,
    Function(int)? onProgress,
  }) async {
    List<SpecialRankingEntry> result = [];
    
    try {
      final conn = await RedisConnection().connect(redisHost, redisPort);
      
      try {
        await conn.send_object(['AUTH', redisPassword]);
        
        // 检查远程缓存是否存在（由Redis自动根据TTL过期）
        dynamic remoteData = await conn.send_object(['GET', reverseExpertDiffCacheKey]);
        bool remoteCacheValid = remoteData is String && remoteData.isNotEmpty;

        if (remoteCacheValid) {
          debugPrint('[SpecialRankingListService] Loading reverse expert diff ranking from remote cache');
          String rawRemoteData = remoteData;
          try {
            List<dynamic> remoteList = json.decode(rawRemoteData);
            for (var item in remoteList) {
              result.add(SpecialRankingEntry(
                rank: item['rank'],
                songId: item['songId'],
                songTitle: item['songTitle'],
                songType: item['songType'],
                difficultyIndex: item['difficultyIndex'],
                difficultyLabel: item['difficultyLabel'],
                ds: item['ds'],
                breakCount: item['breakCount'],
                updateTime: item['updateTime'],
              ));
            }
          } catch (e) {
            debugPrint('[SpecialRankingListService] Failed to parse remote reverse expert diff ranking: $e');
          }
        }
        
        if (result.isEmpty) {
          debugPrint('[SpecialRankingListService] Remote cache empty or expired, recalculating reverse expert diff ranking...');
          
          // 先一次性获取所有diff数据，避免重复查询
          final diffManager = DiffMusicDataManager();
          DiffSong? diffSong = await diffManager.getCachedDiffData();
          
          if (diffSong == null) {
            debugPrint('[SpecialRankingListService] Fetching diff data from API...');
            await diffManager.fetchAndUpdateDiffData();
            diffSong = await diffManager.getCachedDiffData();
          }
          
          // 获取歌曲列表
          final songManager = MaimaiMusicDataManager();
          List<Song>? songs = await songManager.getCachedSongs();
          
          if (songs == null || songs.isEmpty) {
            debugPrint('[SpecialRankingListService] No songs found');
            return result;
          }
          
          if (diffSong == null) {
            debugPrint('[SpecialRankingListService] No diff data available');
            return result;
          }
          
          // 获取需要排除的maidata追加歌曲ID
          Set<String> excludedSongIds = await _getMaidataAddedSongIds();
          
          // 用于存储定数差值（只统计EXPERT，即levelIndex为2）
          List<Map<String, dynamic>> diffList = [];
          
          int totalSongs = songs.length;
          int processedCount = 0;
          
          for (Song song in songs) {
            if (excludedSongIds.contains(song.id)) {
              processedCount++;
              continue;
            }
            
            try {
              List<DiffData>? songDiffDataList = diffSong.charts[song.id];
              
              if (songDiffDataList == null || songDiffDataList.isEmpty) {
                processedCount++;
                continue;
              }
              
              // 只统计EXPERT(2)难度
              int i = 2;
              if (i < song.ds.length) {
                double officialDs = song.ds[i];
                double ratedDs = 0.0;
                
                if (i < songDiffDataList.length) {
                  DiffData diffData = songDiffDataList[i];
                  ratedDs = diffData.fitDiff.toDouble();
                }
                
                double diff = ratedDs - officialDs;
                
                if (ratedDs > 0 && officialDs > 0) {
                  diffList.add({
                    'songId': song.id,
                    'songTitle': song.title,
                    'songType': song.type,
                    'difficultyIndex': i,
                    'officialDs': officialDs,
                    'ratedDs': ratedDs,
                    'diff': diff,
                  });
                }
              }
              
              processedCount++;
              if (onProgress != null) {
                onProgress((processedCount * 100) ~/ totalSongs);
              }
            } catch (e) {
              debugPrint('[SpecialRankingListService] Error processing song ${song.id}: $e');
              processedCount++;
            }
          }
          
          // 按差值升序排序（反向排序，取最小的）
          diffList.sort((a, b) => (a['diff'] as double).compareTo(b['diff'] as double));
          
          List<Map<String, dynamic>> topEntries = diffList.take(limit).toList();
          
          for (int i = 0; i < topEntries.length; i++) {
            Map<String, dynamic> entry = topEntries[i];
            String songId = entry['songId'];
            int difficultyIndex = entry['difficultyIndex'];
            
            result.add(SpecialRankingEntry(
              rank: i + 1,
              songId: songId,
              songTitle: entry['songTitle'],
              songType: entry['songType'],
              difficultyIndex: difficultyIndex,
              difficultyLabel: _getDifficultyLabel(songId, difficultyIndex),
              ds: entry['officialDs'],
              breakCount: (entry['diff'] * 100).toInt(),
              updateTime: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ));
          }
          
          // 缓存到远程
          if (result.isNotEmpty) {
            await conn.send_object(['SET', reverseExpertDiffCacheKey, json.encode(result), 'EX', cacheExpireSeconds.toString()]);
            debugPrint('[SpecialRankingListService] Reverse expert diff ranking cached to remote');
          }
          
          debugPrint('[SpecialRankingListService] Calculated ${result.length} reverse expert diff entries');
        }
      } finally {
        try {
          await conn.send_object(['QUIT']);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[SpecialRankingListService] Redis error in getReverseExpertDifficultyDiffRanking: $e');
    }
    
    return result;
  }

  // 获取样本总数排行榜（dist数组元素和排名）
  Future<List<SpecialRankingEntry>> getSampleCountRanking({
    int limit = 100,
    Function(int)? onProgress,
  }) async {
    List<SpecialRankingEntry> result = [];
    
    try {
      final conn = await RedisConnection().connect(redisHost, redisPort);
      
      try {
        await conn.send_object(['AUTH', redisPassword]);
        
        // 检查远程缓存是否存在（由Redis自动根据TTL过期）
        dynamic remoteData = await conn.send_object(['GET', sampleCountCacheKey]);
        bool remoteCacheValid = remoteData is String && remoteData.isNotEmpty;

        if (remoteCacheValid) {
          debugPrint('[SpecialRankingListService] Loading sample count ranking from remote cache');
          String rawRemoteData = remoteData;
          try {
            List<dynamic> remoteList = json.decode(rawRemoteData);
            for (var item in remoteList) {
              result.add(SpecialRankingEntry(
                rank: item['rank'],
                songId: item['songId'],
                songTitle: item['songTitle'],
                songType: item['songType'],
                difficultyIndex: item['difficultyIndex'],
                difficultyLabel: item['difficultyLabel'],
                ds: item['ds'],
                breakCount: item['breakCount'],
                updateTime: item['updateTime'],
              ));
            }
          } catch (e) {
            debugPrint('[SpecialRankingListService] Failed to parse remote sample count ranking: $e');
          }
        }
        
        if (result.isEmpty) {
          debugPrint('[SpecialRankingListService] Remote cache empty or expired, recalculating sample count ranking...');
          
          // 先一次性获取所有diff数据，避免重复查询
          final diffManager = DiffMusicDataManager();
          DiffSong? diffSong = await diffManager.getCachedDiffData();
          
          if (diffSong == null) {
            debugPrint('[SpecialRankingListService] Fetching diff data from API...');
            await diffManager.fetchAndUpdateDiffData();
            diffSong = await diffManager.getCachedDiffData();
          }
          
          // 获取歌曲列表
          final songManager = MaimaiMusicDataManager();
          List<Song>? songs = await songManager.getCachedSongs();
          
          if (songs == null || songs.isEmpty) {
            debugPrint('[SpecialRankingListService] No songs found');
            return result;
          }
          
          if (diffSong == null) {
            debugPrint('[SpecialRankingListService] No diff data available');
            return result;
          }
          
          // 获取需要排除的maidata追加歌曲ID
          Set<String> excludedSongIds = await _getMaidataAddedSongIds();
          
          // 用于存储样本总数
          List<Map<String, dynamic>> sampleList = [];
          
          int totalSongs = songs.length;
          int processedCount = 0;
          
          for (Song song in songs) {
            if (excludedSongIds.contains(song.id)) {
              processedCount++;
              continue;
            }
            
            try {
              List<DiffData>? songDiffDataList = diffSong.charts[song.id];
              
              if (songDiffDataList == null || songDiffDataList.isEmpty) {
                processedCount++;
                continue;
              }
              
              // 遍历所有难度
              for (int i = 0; i < song.ds.length; i++) {
                if (i < songDiffDataList.length) {
                  DiffData diffData = songDiffDataList[i];
                  
                  // 计算dist数组所有元素的和
                  num sampleSum = diffData.dist.fold(0, (sum, element) => sum + element);
                  
                  if (sampleSum > 0) {
                    sampleList.add({
                      'songId': song.id,
                      'songTitle': song.title,
                      'songType': song.type,
                      'difficultyIndex': i,
                      'ds': song.ds[i],
                      'sampleSum': sampleSum,
                    });
                  }
                }
              }
              
              processedCount++;
              if (onProgress != null) {
                onProgress((processedCount * 100) ~/ totalSongs);
              }
            } catch (e) {
              debugPrint('[SpecialRankingListService] Error processing song ${song.id}: $e');
              processedCount++;
            }
          }
          
          // 按样本总数降序排序
          sampleList.sort((a, b) => (b['sampleSum'] as num).compareTo(a['sampleSum'] as num));
          
          List<Map<String, dynamic>> topEntries = sampleList.take(limit).toList();
          
          for (int i = 0; i < topEntries.length; i++) {
            Map<String, dynamic> entry = topEntries[i];
            String songId = entry['songId'];
            int difficultyIndex = entry['difficultyIndex'];
            
            result.add(SpecialRankingEntry(
              rank: i + 1,
              songId: songId,
              songTitle: entry['songTitle'],
              songType: entry['songType'],
              difficultyIndex: difficultyIndex,
              difficultyLabel: _getDifficultyLabel(songId, difficultyIndex),
              ds: entry['ds'],
              breakCount: (entry['sampleSum'] as num).toInt(),
              updateTime: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ));
          }
          
          // 缓存到远程
          if (result.isNotEmpty) {
            await conn.send_object(['SET', sampleCountCacheKey, json.encode(result), 'EX', cacheExpireSeconds.toString()]);
            debugPrint('[SpecialRankingListService] Sample count ranking cached to remote');
          }
          
          debugPrint('[SpecialRankingListService] Calculated ${result.length} sample count entries');
        }
      } finally {
        try {
          await conn.send_object(['QUIT']);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[SpecialRankingListService] Redis error in getSampleCountRanking: $e');
    }
    
    return result;
  }

  // 获取物量排行榜（五种note总数排名）
  Future<List<SpecialRankingEntry>> getNoteCountRanking({
    int limit = 100,
    Function(int)? onProgress,
  }) async {
    List<SpecialRankingEntry> result = [];
    
    try {
      final conn = await RedisConnection().connect(redisHost, redisPort);
      
      try {
        await conn.send_object(['AUTH', redisPassword]);
        
        // 检查远程缓存是否存在（由Redis自动根据TTL过期）
        dynamic remoteData = await conn.send_object(['GET', noteCountCacheKey]);
        bool remoteCacheValid = remoteData is String && remoteData.isNotEmpty;

        if (remoteCacheValid) {
          debugPrint('[SpecialRankingListService] Loading note count ranking from remote cache');
          String rawRemoteData = remoteData;
          try {
            List<dynamic> remoteList = json.decode(rawRemoteData);
            for (int i = 0; i < remoteList.length && i < limit; i++) {
              Map<String, dynamic> item = remoteList[i];
              result.add(SpecialRankingEntry(
                rank: i + 1,
                songId: item['songId'],
                songTitle: item['songTitle'],
                songType: item['songType'],
                difficultyIndex: item['difficultyIndex'],
                difficultyLabel: item['difficultyLabel'],
                ds: item['ds'],
                breakCount: item['breakCount'],
                updateTime: item['updateTime'],
              ));
            }
            debugPrint('[SpecialRankingListService] Loaded ${result.length} entries from remote cache');
            return result;
          } catch (e) {
            debugPrint('[SpecialRankingListService] Failed to parse remote cache: $e');
          }
        }
        
        // 缓存无效，重新计算
        debugPrint('[SpecialRankingListService] Remote cache empty or expired, recalculating note count ranking...');
        
        // 获取歌曲列表
        final songManager = MaimaiMusicDataManager();
        List<Song>? songs = await songManager.getCachedSongs();
        
        if (songs == null || songs.isEmpty) {
          debugPrint('[SpecialRankingListService] No songs found');
          return result;
        }
        
        // 获取需要排除的maidata追加歌曲ID
        Set<String> excludedSongIds = await _getMaidataAddedSongIds();
        
        // 用于存储物量数据
        List<Map<String, dynamic>> noteCountList = [];
        
        int totalSongs = songs.length;
        int processedCount = 0;
        
        for (Song song in songs) {
          // 过滤掉maidata追加的歌曲
          if (excludedSongIds.contains(song.id)) {
            processedCount++;
            continue;
          }
          try {
            // 遍历每个难度
            for (int i = 0; i < song.ds.length; i++) {
              // 获取该难度的notes数据
              int totalNotes = 0;
              
              // 尝试从song的charts字段获取notes数据
              if (i < song.charts.length) {
                List<int> notes = song.charts[i].notes;
                // notes数组格式: [tap, hold, slide, touch, break] 或 [tap, hold, slide, break]
                for (int j = 0; j < notes.length; j++) {
                  totalNotes += notes[j];
                }
              }
              
              if (totalNotes > 0) {
                noteCountList.add({
                  'songId': song.id,
                  'songTitle': song.title,
                  'songType': song.type,
                  'difficultyIndex': i,
                  'ds': song.ds[i],
                  'totalNotes': totalNotes,
                });
              }
            }
            
            processedCount++;
            if (onProgress != null) {
              onProgress((processedCount * 100) ~/ totalSongs);
            }
          } catch (e) {
            debugPrint('[SpecialRankingListService] Error processing song ${song.id}: $e');
            processedCount++;
          }
        }
        
        // 按物量降序排序
        noteCountList.sort((a, b) => (b['totalNotes'] as int).compareTo(a['totalNotes'] as int));
        
        List<Map<String, dynamic>> topEntries = noteCountList.take(limit).toList();
        
        for (int i = 0; i < topEntries.length; i++) {
          Map<String, dynamic> entry = topEntries[i];
          String songId = entry['songId'];
          int difficultyIndex = entry['difficultyIndex'];
          
          result.add(SpecialRankingEntry(
            rank: i + 1,
            songId: songId,
            songTitle: entry['songTitle'],
            songType: entry['songType'],
            difficultyIndex: difficultyIndex,
            difficultyLabel: _getDifficultyLabel(songId, difficultyIndex),
            ds: entry['ds'],
            breakCount: entry['totalNotes'],
            updateTime: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ));
        }
        
        // 缓存到远程
        if (result.isNotEmpty) {
          await conn.send_object(['SET', noteCountCacheKey, json.encode(result), 'EX', cacheExpireSeconds.toString()]);
          debugPrint('[SpecialRankingListService] Note count ranking cached to remote');
        }
        
        debugPrint('[SpecialRankingListService] Calculated ${result.length} note count entries');
        
      } finally {
        try {
          await conn.send_object(['QUIT']);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[SpecialRankingListService] Redis error in getNoteCountRanking: $e');
    }
    
    return result;
  }

  // 获取平均达成排行榜
  Future<List<SpecialRankingEntry>> getAvgAchievementRanking({
    int limit = 100,
    Function(int)? onProgress,
  }) async {
    List<SpecialRankingEntry> result = [];
    
    try {
      final conn = await RedisConnection().connect(redisHost, redisPort);
      
      try {
        await conn.send_object(['AUTH', redisPassword]);
        
        // 检查远程缓存是否存在（由Redis自动根据TTL过期）
        dynamic remoteData = await conn.send_object(['GET', avgAchievementCacheKey]);
        bool remoteCacheValid = remoteData is String && remoteData.isNotEmpty;

        if (remoteCacheValid) {
          debugPrint('[SpecialRankingListService] Loading avg achievement ranking from remote cache');
          String rawRemoteData = remoteData;
          try {
            List<dynamic> remoteList = json.decode(rawRemoteData);
            for (int i = 0; i < remoteList.length && i < limit; i++) {
              Map<String, dynamic> item = remoteList[i];
              result.add(SpecialRankingEntry(
                rank: i + 1,
                songId: item['songId'],
                songTitle: item['songTitle'],
                songType: item['songType'],
                difficultyIndex: item['difficultyIndex'],
                difficultyLabel: item['difficultyLabel'],
                ds: item['ds'],
                breakCount: item['breakCount'],
                updateTime: item['updateTime'],
              ));
            }
            debugPrint('[SpecialRankingListService] Loaded ${result.length} entries from remote cache');
            return result;
          } catch (e) {
            debugPrint('[SpecialRankingListService] Failed to parse remote cache: $e');
          }
        }
        
        // 缓存无效，重新计算
        debugPrint('[SpecialRankingListService] Remote cache empty or expired, recalculating avg achievement ranking...');
        
        // 先获取diff数据
        final diffManager = DiffMusicDataManager();
        DiffSong? diffSong = await diffManager.getCachedDiffData();
        
        if (diffSong == null) {
          debugPrint('[SpecialRankingListService] Fetching diff data from API...');
          await diffManager.fetchAndUpdateDiffData();
          diffSong = await diffManager.getCachedDiffData();
        }
        
        // 获取歌曲列表
        final songManager = MaimaiMusicDataManager();
        List<Song>? songs = await songManager.getCachedSongs();
        
        if (songs == null || songs.isEmpty) {
          debugPrint('[SpecialRankingListService] No songs found');
          return result;
        }
        
        if (diffSong == null) {
          debugPrint('[SpecialRankingListService] No diff data available');
          return result;
        }
        
        // 获取需要排除的maidata追加歌曲ID
        Set<String> excludedSongIds = await _getMaidataAddedSongIds();
        
        // 用于存储平均达成率数据
        List<Map<String, dynamic>> avgAchievementList = [];
        
        int totalSongs = songs.length;
        int processedCount = 0;
        
        // 遍历歌曲
        for (Song song in songs) {
          // 过滤掉maidata追加的歌曲
          if (excludedSongIds.contains(song.id)) {
            processedCount++;
            continue;
          }
          
          try {
            // 从内存中获取该歌曲的diff数据
            List<DiffData>? songDiffDataList = diffSong.charts[song.id];
            
            if (songDiffDataList == null || songDiffDataList.isEmpty) {
              processedCount++;
              if (onProgress != null) {
                onProgress((processedCount * 100) ~/ totalSongs);
              }
              continue;
            }
            
            // 遍历每个难度
            for (int i = 0; i < song.ds.length; i++) {
              // 对于有2个难度的6位数ID谱面，只让第一个难度上榜
              if (song.id.length == 6 && song.ds.length == 2 && i > 0) {
                continue;
              }
              
              // 使用索引匹配（与定数差值排行榜保持一致）
              double avgAchievement = 0.0;
              
              // 对于只有2个难度的歌曲，拟合难度的数据跟第一个难度保持相同
              int dataIndex = i;
              if (song.ds.length == 2 && songDiffDataList.length == 1) {
                dataIndex = 0; // 两个难度共享同一个diff数据
              }
              
              if (dataIndex < songDiffDataList.length) {
                DiffData diffData = songDiffDataList[dataIndex];
                avgAchievement = diffData.avg.toDouble();
              }
              
              if (avgAchievement > 0) {
                avgAchievementList.add({
                  'songId': song.id,
                  'songTitle': song.title,
                  'songType': song.type,
                  'difficultyIndex': i,
                  'ds': song.ds[i],
                  'avgAchievement': avgAchievement,
                });
              }
            }
            
            processedCount++;
            if (onProgress != null) {
              onProgress((processedCount * 100) ~/ totalSongs);
            }
          } catch (e) {
            debugPrint('[SpecialRankingListService] Error processing song ${song.id}: $e');
            processedCount++;
          }
        }
        
        // 按平均达成率降序排序
        avgAchievementList.sort((a, b) => (b['avgAchievement'] as double).compareTo(a['avgAchievement'] as double));
        
        List<Map<String, dynamic>> topEntries = avgAchievementList.take(limit).toList();
        
        for (int i = 0; i < topEntries.length; i++) {
          Map<String, dynamic> entry = topEntries[i];
          String songId = entry['songId'];
          int difficultyIndex = entry['difficultyIndex'];
          
          result.add(SpecialRankingEntry(
            rank: i + 1,
            songId: songId,
            songTitle: entry['songTitle'],
            songType: entry['songType'],
            difficultyIndex: difficultyIndex,
            difficultyLabel: _getDifficultyLabel(songId, difficultyIndex),
            ds: entry['ds'],
            breakCount: (entry['avgAchievement'] * 100).toInt(),
            updateTime: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ));
        }
        
        // 缓存到远程
        if (result.isNotEmpty) {
          await conn.send_object(['SET', avgAchievementCacheKey, json.encode(result), 'EX', cacheExpireSeconds.toString()]);
          debugPrint('[SpecialRankingListService] Avg achievement ranking cached to remote');
        }
        
        debugPrint('[SpecialRankingListService] Calculated ${result.length} avg achievement entries');
        
      } finally {
        try {
          await conn.send_object(['QUIT']);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[SpecialRankingListService] Redis error in getAvgAchievementRanking: $e');
    }
    
    return result;
  }

  // 获取MASTER/RE:MASTER平均达成排行榜
  Future<List<SpecialRankingEntry>> getMasterAvgAchievementRanking({
    int limit = 100,
    Function(int)? onProgress,
  }) async {
    List<SpecialRankingEntry> result = [];
    
    try {
      final conn = await RedisConnection().connect(redisHost, redisPort);
      
      try {
        await conn.send_object(['AUTH', redisPassword]);
        
        // 检查远程缓存是否存在（由Redis自动根据TTL过期）
        dynamic remoteData = await conn.send_object(['GET', masterAvgAchievementCacheKey]);
        bool remoteCacheValid = remoteData is String && remoteData.isNotEmpty;

        if (remoteCacheValid) {
          debugPrint('[SpecialRankingListService] Loading master avg achievement ranking from remote cache');
          String rawRemoteData = remoteData;
          try {
            List<dynamic> remoteList = json.decode(rawRemoteData);
            for (int i = 0; i < remoteList.length && i < limit; i++) {
              Map<String, dynamic> item = remoteList[i];
              result.add(SpecialRankingEntry(
                rank: i + 1,
                songId: item['songId'],
                songTitle: item['songTitle'],
                songType: item['songType'],
                difficultyIndex: item['difficultyIndex'],
                difficultyLabel: item['difficultyLabel'],
                ds: item['ds'],
                breakCount: item['breakCount'],
                updateTime: item['updateTime'],
              ));
            }
            debugPrint('[SpecialRankingListService] Loaded ${result.length} entries from remote cache');
            return result;
          } catch (e) {
            debugPrint('[SpecialRankingListService] Failed to parse remote cache: $e');
          }
        }
        
        // 缓存无效，重新计算
        debugPrint('[SpecialRankingListService] Remote cache empty or expired, recalculating master avg achievement ranking...');
        
        // 先获取diff数据
        final diffManager = DiffMusicDataManager();
        DiffSong? diffSong = await diffManager.getCachedDiffData();
        
        if (diffSong == null) {
          debugPrint('[SpecialRankingListService] Fetching diff data from API...');
          await diffManager.fetchAndUpdateDiffData();
          diffSong = await diffManager.getCachedDiffData();
        }
        
        // 获取歌曲列表
        final songManager = MaimaiMusicDataManager();
        List<Song>? songs = await songManager.getCachedSongs();
        
        if (songs == null || songs.isEmpty) {
          debugPrint('[SpecialRankingListService] No songs found');
          return result;
        }
        
        if (diffSong == null) {
          debugPrint('[SpecialRankingListService] No diff data available');
          return result;
        }
        
        // 获取需要排除的maidata追加歌曲ID
        Set<String> excludedSongIds = await _getMaidataAddedSongIds();
        
        // 用于存储平均达成率数据
        List<Map<String, dynamic>> avgAchievementList = [];
        
        int totalSongs = songs.length;
        int processedCount = 0;
        
        // 遍历歌曲
        for (Song song in songs) {
          // 过滤掉maidata追加的歌曲
          if (excludedSongIds.contains(song.id)) {
            processedCount++;
            continue;
          }
          
          try {
            // 从内存中获取该歌曲的diff数据
            List<DiffData>? songDiffDataList = diffSong.charts[song.id];
            
            if (songDiffDataList == null || songDiffDataList.isEmpty) {
              processedCount++;
              continue;
            }
            
            // 只统计MASTER/RE:MASTER难度（levelIndex为3和4）
            for (int i = 3; i <= 4 && i < song.ds.length; i++) {
              // 使用索引匹配
              double avgAchievement = 0.0;
              
              // 对于只有2个难度的歌曲，拟合难度的数据跟第一个难度保持相同
              int dataIndex = i;
              if (song.ds.length == 2 && songDiffDataList.length == 1) {
                dataIndex = 0;
              }
              
              if (dataIndex < songDiffDataList.length) {
                DiffData diffData = songDiffDataList[dataIndex];
                avgAchievement = diffData.avg.toDouble();
              }
              
              if (avgAchievement > 0) {
                avgAchievementList.add({
                  'songId': song.id,
                  'songTitle': song.title,
                  'songType': song.type,
                  'difficultyIndex': i,
                  'ds': song.ds[i],
                  'avgAchievement': avgAchievement,
                });
              }
            }
            
            processedCount++;
            if (onProgress != null) {
              onProgress((processedCount * 100) ~/ totalSongs);
            }
          } catch (e) {
            debugPrint('[SpecialRankingListService] Error processing song ${song.id}: $e');
            processedCount++;
          }
        }
        
        // 按平均达成率降序排序
        avgAchievementList.sort((a, b) => (b['avgAchievement'] as double).compareTo(a['avgAchievement'] as double));
        
        List<Map<String, dynamic>> topEntries = avgAchievementList.take(limit).toList();
        
        for (int i = 0; i < topEntries.length; i++) {
          Map<String, dynamic> entry = topEntries[i];
          String songId = entry['songId'];
          int difficultyIndex = entry['difficultyIndex'];
          
          result.add(SpecialRankingEntry(
            rank: i + 1,
            songId: songId,
            songTitle: entry['songTitle'],
            songType: entry['songType'],
            difficultyIndex: difficultyIndex,
            difficultyLabel: _getDifficultyLabel(songId, difficultyIndex),
            ds: entry['ds'],
            breakCount: (entry['avgAchievement'] * 100).toInt(),
            updateTime: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ));
        }
        
        // 缓存到远程
        if (result.isNotEmpty) {
          await conn.send_object(['SET', masterAvgAchievementCacheKey, json.encode(result), 'EX', cacheExpireSeconds.toString()]);
          debugPrint('[SpecialRankingListService] Master avg achievement ranking cached to remote');
        }
        
        debugPrint('[SpecialRankingListService] Calculated ${result.length} master avg achievement entries');
        
      } finally {
        try {
          await conn.send_object(['QUIT']);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[SpecialRankingListService] Redis error in getMasterAvgAchievementRanking: $e');
    }
    
    return result;
  }

  // 获取EXPERT平均达成排行榜（只统计levelIndex为2的谱面）
  Future<List<SpecialRankingEntry>> getExpertAvgAchievementRanking({
    int limit = 100,
    Function(int)? onProgress,
  }) async {
    List<SpecialRankingEntry> result = [];
    
    try {
      final conn = await RedisConnection().connect(redisHost, redisPort);
      
      try {
        await conn.send_object(['AUTH', redisPassword]);
        
        // 检查远程缓存是否存在（由Redis自动根据TTL过期）
        dynamic remoteData = await conn.send_object(['GET', expertAvgAchievementCacheKey]);
        bool remoteCacheValid = remoteData is String && remoteData.isNotEmpty;

        if (remoteCacheValid) {
          debugPrint('[SpecialRankingListService] Loading expert avg achievement ranking from remote cache');
          String rawRemoteData = remoteData;
          try {
            List<dynamic> remoteList = json.decode(rawRemoteData);
            for (int i = 0; i < remoteList.length && i < limit; i++) {
              Map<String, dynamic> item = remoteList[i];
              result.add(SpecialRankingEntry(
                rank: i + 1,
                songId: item['songId'],
                songTitle: item['songTitle'],
                songType: item['songType'],
                difficultyIndex: item['difficultyIndex'],
                difficultyLabel: item['difficultyLabel'],
                ds: item['ds'],
                breakCount: item['breakCount'],
                updateTime: item['updateTime'],
              ));
            }
            debugPrint('[SpecialRankingListService] Loaded ${result.length} entries from remote cache');
            return result;
          } catch (e) {
            debugPrint('[SpecialRankingListService] Failed to parse remote cache: $e');
          }
        }
        
        // 缓存无效，重新计算
        debugPrint('[SpecialRankingListService] Remote cache empty or expired, recalculating expert avg achievement ranking...');
        
        // 先获取diff数据
        final diffManager = DiffMusicDataManager();
        DiffSong? diffSong = await diffManager.getCachedDiffData();
        
        if (diffSong == null) {
          debugPrint('[SpecialRankingListService] Fetching diff data from API...');
          await diffManager.fetchAndUpdateDiffData();
          diffSong = await diffManager.getCachedDiffData();
        }
        
        // 获取歌曲列表
        final songManager = MaimaiMusicDataManager();
        List<Song>? songs = await songManager.getCachedSongs();
        
        if (songs == null || songs.isEmpty) {
          debugPrint('[SpecialRankingListService] No songs found');
          return result;
        }
        
        if (diffSong == null) {
          debugPrint('[SpecialRankingListService] No diff data available');
          return result;
        }
        
        // 获取需要排除的maidata追加歌曲ID
        Set<String> excludedSongIds = await _getMaidataAddedSongIds();
        
        // 用于存储平均达成率数据
        List<Map<String, dynamic>> avgAchievementList = [];
        
        int totalSongs = songs.length;
        int processedCount = 0;
        
        // 遍历歌曲
        for (Song song in songs) {
          // 过滤掉maidata追加的歌曲
          if (excludedSongIds.contains(song.id)) {
            processedCount++;
            continue;
          }
          
          try {
            // 从内存中获取该歌曲的diff数据
            List<DiffData>? songDiffDataList = diffSong.charts[song.id];
            
            if (songDiffDataList == null || songDiffDataList.isEmpty) {
              processedCount++;
              continue;
            }
            
            // 只统计EXPERT难度（levelIndex为2）
            int i = 2;
            if (i < song.ds.length) {
              // 使用索引匹配
              double avgAchievement = 0.0;
              
              // 对于只有2个难度的歌曲，拟合难度的数据跟第一个难度保持相同
              int dataIndex = i;
              if (song.ds.length == 2 && songDiffDataList.length == 1) {
                dataIndex = 0;
              }
              
              if (dataIndex < songDiffDataList.length) {
                DiffData diffData = songDiffDataList[dataIndex];
                avgAchievement = diffData.avg.toDouble();
              }
              
              if (avgAchievement > 0) {
                avgAchievementList.add({
                  'songId': song.id,
                  'songTitle': song.title,
                  'songType': song.type,
                  'difficultyIndex': i,
                  'ds': song.ds[i],
                  'avgAchievement': avgAchievement,
                });
              }
            }
            
            processedCount++;
            if (onProgress != null) {
              onProgress((processedCount * 100) ~/ totalSongs);
            }
          } catch (e) {
            debugPrint('[SpecialRankingListService] Error processing song ${song.id}: $e');
            processedCount++;
          }
        }
        
        // 按平均达成率降序排序
        avgAchievementList.sort((a, b) => (b['avgAchievement'] as double).compareTo(a['avgAchievement'] as double));
        
        List<Map<String, dynamic>> topEntries = avgAchievementList.take(limit).toList();
        
        for (int i = 0; i < topEntries.length; i++) {
          Map<String, dynamic> entry = topEntries[i];
          String songId = entry['songId'];
          int difficultyIndex = entry['difficultyIndex'];
          
          result.add(SpecialRankingEntry(
            rank: i + 1,
            songId: songId,
            songTitle: entry['songTitle'],
            songType: entry['songType'],
            difficultyIndex: difficultyIndex,
            difficultyLabel: _getDifficultyLabel(songId, difficultyIndex),
            ds: entry['ds'],
            breakCount: (entry['avgAchievement'] * 100).toInt(),
            updateTime: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ));
        }
        
        // 缓存到远程
        if (result.isNotEmpty) {
          await conn.send_object(['SET', expertAvgAchievementCacheKey, json.encode(result), 'EX', cacheExpireSeconds.toString()]);
          debugPrint('[SpecialRankingListService] Expert avg achievement ranking cached to remote');
        }
        
        debugPrint('[SpecialRankingListService] Calculated ${result.length} expert avg achievement entries');
        
      } finally {
        try {
          await conn.send_object(['QUIT']);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[SpecialRankingListService] Redis error in getExpertAvgAchievementRanking: $e');
    }
    
    return result;
  }

  // 获取从maidata追加的歌曲列表
  Future<Set<String>> _getMaidataAddedSongIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? cachedData = prefs.getString(CacheKeyConstant.maidataAddedSongs);
      if (cachedData != null) {
        List<String> ids = List<String>.from(json.decode(cachedData));
        debugPrint('[SpecialRankingListService] Found ${ids.length} maidata-added songs to exclude');
        return ids.toSet();
      }
    } catch (e) {
      debugPrint('[SpecialRankingListService] Error getting maidata added songs: $e');
    }
    return {};
  }

  // 更新谱面绝赞总数排行榜（需要先解析maidata）
  Future<void> updateAllSongBreakCounts({Function(int)? onProgress}) async {
    try {
      final conn = await RedisConnection().connect(redisHost, redisPort);
      
      try {
        await conn.send_object(['AUTH', redisPassword]);
        
        // 先清空旧数据
        await conn.send_object(['DEL', 'special:song_break_count']);
        
        // 获取所有歌曲
        final songManager = MaimaiMusicDataManager();
        List<Song>? songs = await songManager.getCachedSongs();
        
        if (songs == null || songs.isEmpty) {
          debugPrint('[SpecialRankingListService] No songs found');
          return;
        }
        
        // 获取从maidata追加的歌曲列表（需要排除）
        Set<String> excludedSongIds = await _getMaidataAddedSongIds();
        
        // 初始化maidata管理器
        await MaidataManager().initialize();
        
        // ==== 优化：先在内存中收集所有数据，再批量写入Redis，避免逐条网络往返 ====
        // 收集ZADD参数: [score1, member1, score2, member2, ...]
        final List<String> zaddMembers = [];
        // 收集SET命令
        final List<List<String>> setCommands = [];
        // 记录更新时间戳（所有条目使用同一时间戳）
        final String nowTimestamp = DateTime.now().millisecondsSinceEpoch.toString();
        
        int updatedCount = 0;
        int excludedCount = 0;
        int failedCount = 0;
        int totalSongs = songs.length;
        int processedCount = 0;
        
        for (Song song in songs) {
          // 排除从maidata追加的歌曲
          if (excludedSongIds.contains(song.id)) {
            excludedCount++;
            processedCount++;
            continue;
          }
          
          try {
            // 获取歌曲的maidata原始内容
            String? maidataContent = MaidataManager().getMaidata(song.id);
            
            // 查询失败的歌曲不计入排行榜
            if (maidataContent == null || maidataContent.isEmpty) {
              failedCount++;
              processedCount++;
              continue;
            }
            
            // 使用MaidataDecodeUtil解析maidata（与SongInfoPage一致）
            MaidataData maidata;
            try {
              maidata = MaidataDecodeUtil.decode(maidataContent);
            } catch (e) {
              failedCount++;
              processedCount++;
              continue;
            }
            
            // 遍历所有谱面
            for (ChartData chart in maidata.charts) {
              if (chart.stats != null) {
                // 使用解析后的breakNote数量（与SongInfoPage一致）
                int breakCount = chart.stats!.breakNote;
                
                if (breakCount > 0) {
                  // 计算实际难度索引（跳过EASY）
                  int displayIndex = _getDisplayDifficultyIndex(song.id, chart.difficultyIndex);
                  if (displayIndex >= 0 && displayIndex <= 4) {
                    String songKey = '${song.id}:$displayIndex';
                    // 收集到内存中，暂不写入Redis
                    zaddMembers.add(breakCount.toString());
                    zaddMembers.add(songKey);
                    setCommands.add(['SET', 'special:song_break_count:updateTime:$songKey', nowTimestamp]);
                    updatedCount++;
                  }
                }
              }
            }
          } catch (e) {
            failedCount++;
          }
          
          processedCount++;
          
          // 回调进度
          if (onProgress != null && totalSongs > 0) {
            int progress = (processedCount * 100) ~/ totalSongs;
            onProgress(progress);
          }
        }
        
        // ==== 批量写入Redis ====
        // 1. 一次ZADD写入所有成员（替代逐个ZADD，减少~2000次网络往返到1次）
        if (zaddMembers.isNotEmpty) {
          await conn.send_object(['ZADD', 'special:song_break_count', ...zaddMembers]);
        }
        
        // 2. 批量SET：禁用Nagle算法批量发送，再统一等待完成
        if (setCommands.isNotEmpty) {
          conn.pipe_start();
          final List<Future> setFutures = [];
          for (final cmd in setCommands) {
            setFutures.add(conn.send_object(cmd));
          }
          await Future.wait(setFutures);
          conn.pipe_end();
        }
        
        debugPrint('[SpecialRankingListService] Updated $updatedCount charts break counts (${zaddMembers.length ~/ 2} entries), excluded $excludedCount maidata-added songs, failed $failedCount songs');
      } finally {
        try {
          await conn.send_object(['QUIT']);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[SpecialRankingListService] Redis error in updateAllSongBreakCounts: $e');
    }
  }

  // 获取显示用的难度索引（跳过EASY）
  int _getDisplayDifficultyIndex(String songId, int maimaiIndex) {
    // maidata的difficultyIndex是2-6（对应BASIC, ADVANCED, EXPERT, MASTER, RE:MASTER）和7（EASY）
    // 显示用的是0-4（跳过EASY，对应BASIC, ADVANCED, EXPERT, MASTER, RE:MASTER）
    
    // UTAGE歌曲只有一个难度
    if (songId.length == 6) {
      return 0;
    }
    
    // 普通歌曲：跳过EASY(7)
    if (maimaiIndex == 7) {
      return -1; // EASY，不显示
    }
    
    // 转换为0-4的显示索引
    return maimaiIndex - 2;
  }

  String _getDifficultyLabel(String songId, int index) {
    // UTAGE歌曲显示UTAGE作为难度标签
    if (songId.length == 6) {
      return 'UTAGE';
    }
    
    switch (index) {
      case 0: return 'BASIC';
      case 1: return 'ADVANCED';
      case 2: return 'EXPERT';
      case 3: return 'MASTER';
      case 4: return 'RE:MASTER';
      default: return 'UNKNOWN';
    }
  }

  double _getDifficultyDs(Song? song, int index) {
    if (song == null || song.ds == null || song.ds.length <= index) {
      return 0.0;
    }
    return song.ds[index];
  }

  /// 触发绝赞数排行榜的重新计算（解析maidata），支持进度回调。
  /// 计算完成后数据自动写入Redis缓存，页面再次调用 [getBreakCountRanking] 即可获取最新结果。
  Future<void> recalculateBreakCountRanking({Function(int)? onProgress}) async {
    try {
      final conn = await RedisConnection().connect(redisHost, redisPort);
      try {
        await conn.send_object(['AUTH', redisPassword]);
        await _recalculateAndCacheRanking(conn, onProgress);
        debugPrint('[SpecialRankingListService] Break count ranking recalculated successfully');
      } finally {
        try {
          await conn.send_object(['QUIT']);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[SpecialRankingListService] Error in recalculateBreakCountRanking: $e');
    }
  }

  // 重新计算排名并上传到远程缓存
  Future<void> _recalculateAndCacheRanking(Command? conn, Function(int)? onProgress) async {
    if (conn == null) return;
    
    try {
      // 重新计算所有歌曲的绝赞数
      await updateAllSongBreakCounts(onProgress: onProgress);
      
      // 获取计算后的排名数据
      String key = 'special:song_break_count';
      List<dynamic> redisResult = await conn.send_object(
        ['ZREVRANGE', key, 0, -1, 'WITHSCORES']
      );
      
      if (redisResult != null && redisResult.isNotEmpty) {
        // 预构建歌曲映射表
        final songManager = MaimaiMusicDataManager();
        List<Song>? songs = await songManager.getCachedSongs();
        Map<String, Song> songMap = {};
        if (songs != null) {
          for (Song song in songs) {
            songMap[song.id] = song;
          }
        }
        
        // 收集更新时间
        List<String> updateTimeKeys = [];
        List<Map<String, dynamic>> entries = [];
        
        for (int i = 0; i < redisResult.length; i += 2) {
          String songKey = redisResult[i] as String;
          dynamic scoreValue = redisResult[i + 1];
          
          int breakCount = 0;
          if (scoreValue is num) {
            breakCount = scoreValue.toInt();
          } else if (scoreValue is String) {
            breakCount = int.tryParse(scoreValue) ?? 0;
          }
          
          List<String> parts = songKey.split(':');
          if (parts.length >= 2) {
            String songId = parts[0];
            int difficultyIndex = int.tryParse(parts[1]) ?? 0;
            
            Song? song = songMap[songId];
            String songTitle = song?.title ?? '未知歌曲';
            String songType = song?.type ?? 'ST';
            String difficultyLabel = _getDifficultyLabel(songId, difficultyIndex);
            double ds = _getDifficultyDs(song, difficultyIndex);
            
            updateTimeKeys.add('special:song_break_count:updateTime:$songKey');
            
            entries.add({
              'songId': songId,
              'songTitle': songTitle,
              'songType': songType,
              'difficultyIndex': difficultyIndex,
              'difficultyLabel': difficultyLabel,
              'ds': ds,
              'breakCount': breakCount,
              'updateTime': 0,
            });
          }
        }
        
        // 批量获取更新时间
        Map<String, int> updateTimeMap = {};
        if (updateTimeKeys.isNotEmpty) {
          List<dynamic> mgetResult = await conn.send_object(['MGET', ...updateTimeKeys]);
          for (int i = 0; i < updateTimeKeys.length; i++) {
            dynamic value = mgetResult[i];
            int updateTime = 0;
            if (value is String) {
              updateTime = int.tryParse(value) ?? 0;
            }
            updateTimeMap[updateTimeKeys[i]] = updateTime;
          }
        }
        
        // 设置更新时间
        for (Map<String, dynamic> entry in entries) {
          String songKey = '${entry['songId']}:${entry['difficultyIndex']}';
          String updateTimeKey = 'special:song_break_count:updateTime:$songKey';
          entry['updateTime'] = updateTimeMap[updateTimeKey] ?? 0;
        }
        
        // 上传到远程缓存
        String jsonData = json.encode(entries);
        await conn.send_object(['SET', remoteCacheKey, jsonData, 'EX', cacheExpireSeconds.toString()]);

        debugPrint('[SpecialRankingListService] Uploaded ranking to remote cache with ${entries.length} entries');
      }
    } catch (e) {
      debugPrint('[SpecialRankingListService] Error in _recalculateAndCacheRanking: $e');
    }
  }
}