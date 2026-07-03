import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../manager/DivingFish/MaimaiMusicDataManager.dart';
import '../manager/DivingFish/UserPlayDataManager.dart';
import '../entity/DivingFish/Song.dart';

/// 当日谱面推荐服务
/// 每天推荐 4 首用户未玩过的歌曲，使用日期+QQ 作为随机种子
class DailyRecommendService {
  static final DailyRecommendService _instance =
      DailyRecommendService._internal();
  factory DailyRecommendService() => _instance;
  DailyRecommendService._internal();

  static const String _cacheKey = 'daily_recommend_cache';
  static const String _cacheDateKey = 'daily_recommend_date';

  /// 获取今日推荐曲目
  /// [forceRefresh] 为 true 时绕过缓存重新生成
  Future<List<Song>> getDailyRecommendations({bool forceRefresh = false}) async {
    final todayStr = _getTodayDateString();

    // 非强制刷新时检查缓存
    if (!forceRefresh) {
      final cached = await _getCachedRecommendations(todayStr);
      if (cached != null && cached.isNotEmpty) {
        debugPrint('DailyRecommend: 使用缓存 ($todayStr)');
        return cached;
      }
    }

    debugPrint('DailyRecommend: 重新生成推荐 ($todayStr)');

    // 获取全曲库
    final musicManager = MaimaiMusicDataManager();
    final allSongs = await musicManager.getCachedSongs() ?? [];
    if (allSongs.isEmpty) {
      debugPrint('DailyRecommend: 曲库为空');
      return [];
    }

    // 获取用户已玩记录
    Set<String> playedKeys = {};
    try {
      final userPlayDataManager = UserPlayDataManager();
      final userData = await userPlayDataManager.getCachedUserPlayData();
      if (userData != null && userData['records'] != null) {
        final records = userData['records'] as List<dynamic>;
        for (final record in records) {
          final songId = record['song_id']?.toString() ?? '';
          final levelIndex = record['level_index']?.toString() ?? '';
          if (songId.isNotEmpty) {
            playedKeys.add('${songId}_$levelIndex');
          }
        }
      }
    } catch (e) {
      debugPrint('DailyRecommend: 获取用户数据失败，使用空记录: $e');
    }

    // 获取用户 QQ 用于个性化种子
    final qq = await _getUserQQ();

    // 过滤：排除 maidata 导入曲目，选择未玩过的歌
    List<Song> candidateSongs = allSongs.where((song) {
      // 排除 maidata 导入曲目（cids 全为 0）
      if (_isMaidataSong(song)) return false;
      return true;
    }).toList();

    // 为每首歌找一个未玩过的最高难度
    final List<_SongWithLevel> candidatesWithLevel = [];
    for (final song in candidateSongs) {
      final bestLevel = _pickBestLevel(song, playedKeys);
      if (bestLevel >= 0) {
        candidatesWithLevel.add(_SongWithLevel(song: song, levelIndex: bestLevel));
      }
    }

    // 如果候选不够，从所有歌中随机选（不限制已玩）
    List<_SongWithLevel> finalCandidates = candidatesWithLevel;
    if (finalCandidates.length < 4) {
      debugPrint('DailyRecommend: 候选不足 (${finalCandidates.length})，从全曲库补充');
      final remainingSongs = candidateSongs
          .where((s) => !finalCandidates.any((c) => c.song.id == s.id))
          .toList();
      for (final song in remainingSongs) {
        final bestLevel = _pickAnyBestLevel(song);
        if (bestLevel >= 0) {
          finalCandidates.add(_SongWithLevel(song: song, levelIndex: bestLevel));
        }
        if (finalCandidates.length >= 10) break;
      }
    }

    if (finalCandidates.isEmpty) {
      debugPrint('DailyRecommend: 无可用歌曲');
      return [];
    }

    // 用日期+QQ 作为种子，随机选择 4 首
    final seed = todayStr.hashCode ^ qq.hashCode;
    final random = Random(seed);
    final result = <Song>[];
    final used = <String>{};

    final pickCount = finalCandidates.length < 4 ? finalCandidates.length : 4;
    int attempts = 0;
    while (result.length < pickCount && attempts < 100 && used.length < finalCandidates.length) {
      final index = random.nextInt(finalCandidates.length);
      final candidate = finalCandidates[index];
      if (!used.contains(candidate.song.id)) {
        used.add(candidate.song.id);
        result.add(candidate.song);
      }
      attempts++;
    }

    // 缓存结果
    await _cacheRecommendations(todayStr, result);

    return result;
  }

  /// 为歌曲挑选一个未玩过的最高难度，返回 levelIndex
  int _pickBestLevel(Song song, Set<String> playedKeys) {
    final dsList = song.ds;
    // 从高难度往低难度找
    for (int i = dsList.length - 1; i >= 0; i--) {
      final key = '${song.id}_$i';
      if (!playedKeys.contains(key)) {
        return i;
      }
    }
    return -1; // 全玩过了
  }

  /// 挑选歌曲的最高可用难度
  int _pickAnyBestLevel(Song song) {
    final dsList = song.ds;
    if (dsList.isEmpty) return -1;
    // 优先 MASTER 或 RE:MASTER
    for (int i = dsList.length - 1; i >= 0; i--) {
      if (dsList[i] > 0) return i;
    }
    return dsList.length - 1;
  }

  /// 是否为 maidata 导入曲目
  bool _isMaidataSong(Song song) {
    try {
      final cids = song.cids;
      if (cids == null || cids.isEmpty) return false;
      return cids.every((cid) => cid == 0);
    } catch (_) {
      return false;
    }
  }

  /// 获取今日日期字符串
  String _getTodayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// 从缓存获取推荐
  Future<List<Song>?> _getCachedRecommendations(String dateStr) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedDate = prefs.getString(_cacheDateKey);
      if (cachedDate != dateStr) return null;

      final jsonStr = prefs.getString(_cacheKey);
      if (jsonStr == null || jsonStr.isEmpty) return null;

      final List<dynamic> jsonList = json.decode(jsonStr) as List<dynamic>;
      return jsonList
          .map((e) => Song.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('DailyRecommend: 读取缓存失败: $e');
      return null;
    }
  }

  /// 缓存推荐结果
  Future<void> _cacheRecommendations(String dateStr, List<Song> songs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = songs.map((s) => s.toJson()).toList();
      await prefs.setString(_cacheKey, json.encode(jsonList));
      await prefs.setString(_cacheDateKey, dateStr);
    } catch (e) {
      debugPrint('DailyRecommend: 缓存失败: $e');
    }
  }

  /// 获取用户 QQ
  Future<String> _getUserQQ() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('cachedQQ') ?? '';
    } catch (_) {
      return '';
    }
  }
}

/// 内部辅助类：歌曲和推荐难度
class _SongWithLevel {
  final Song song;
  final int levelIndex;

  _SongWithLevel({required this.song, required this.levelIndex});
}
