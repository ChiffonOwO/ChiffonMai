import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../api/ApiUrls.dart';
import '../../entity/DivingFish/Song.dart';
import '../../service/GuessChartGame/MultiplayerCloudBaseService.dart';
import '../../utils/MaidataDecodeUtil.dart';
import '../../constant/CacheKeyConstant.dart';
import '../../constant/CacheTimestampConstant.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../MaidataManager.dart';
import '../../service/ConnectivityService.dart';

class MaimaiMusicDataManager {
  static final MaimaiMusicDataManager _instance = MaimaiMusicDataManager._internal();
  factory MaimaiMusicDataManager() => _instance;
  MaimaiMusicDataManager._internal();

  static const String _apiUrl = ApiUrls.MusicDataApi;
  static const String _unionApiUrl = ApiUrls.UnionMusicDataApi;

  final MultiplayerCloudBaseService _cloudService = MultiplayerCloudBaseService();

  // 使用 compute 进行后台 JSON 解析
  Future<List<Song>> _parseSongsInBackground(String responseBody) async {
    return compute(_parseSongs, responseBody);
  }

  static List<Song> _parseSongs(String responseBody) {
    final List<dynamic> jsonList = json.decode(responseBody);
    return jsonList.map((json) => Song.fromJson(json)).toList();
  }

  // 使用 compute 进行后台 JSON 编码
  Future<String> _encodeSongsInBackground(List<Song> songs) async {
    return compute(_encodeSongs, songs);
  }

  static String _encodeSongs(List<Song> songs) {
    return json.encode(songs.map((song) => song.toJson()).toList());
  }

  Future<bool> fetchAndUpdateMusicData({List<String>? maidataTexts}) async {
    try {
      // 离线检查
      final isOnline = await ConnectivityService().hasConnection();
      if (!isOnline) {
        debugPrint('离线模式：跳过获取音乐数据，使用缓存');
        return false;
      }

      // ── 1. 从 union API（更全）获取歌曲数据 ──
      List<Song> songs = [];
      Set<String> unionSongIds = {};  // union API 中的歌曲ID集合
      Set<String> oldSongIds = {};    // 旧水鱼 API 中的歌曲ID集合

      try {
        debugPrint('从 union API 获取全量歌曲数据...');
        final unionResponse = await http.get(Uri.parse(_unionApiUrl));
        if (unionResponse.statusCode == 200) {
          songs = await _parseSongsInBackground(unionResponse.body);
          unionSongIds = songs.map((s) => s.id).toSet();
          debugPrint('Union API 返回 ${songs.length} 首歌曲');
        } else {
          debugPrint('Union API 请求失败，状态码: ${unionResponse.statusCode}，回退到水鱼API');
        }
      } catch (e) {
        debugPrint('Union API 请求异常: $e，回退到水鱼API');
      }

      // ── 2. 从旧水鱼 API 获取歌曲数据（兜底+比对） ──
      try {
        final oldResponse = await http.get(Uri.parse(_apiUrl));
        if (oldResponse.statusCode == 200) {
          final oldSongs = await _parseSongsInBackground(oldResponse.body);
          oldSongIds = oldSongs.map((s) => s.id).toSet();
          debugPrint('水鱼 API 返回 ${oldSongs.length} 首歌曲');

          // 如果 union API 没有数据，使用水鱼数据作为基础
          if (songs.isEmpty) {
            songs = oldSongs;
            unionSongIds = oldSongIds.toSet();
          } else {
            // ── 合并：union为主，水鱼补充union中没有的歌曲 ──
            final existingIds = songs.map((s) => s.id).toSet();
            for (final oldSong in oldSongs) {
              if (!existingIds.contains(oldSong.id)) {
                songs.add(oldSong);
              }
            }
            debugPrint('合并后共 ${songs.length} 首歌曲 (新增 ${songs.length - existingIds.length} 首来自水鱼)');
          }
        } else {
          debugPrint('水鱼 API 请求失败，状态码: ${oldResponse.statusCode}');
          if (songs.isEmpty) return false;
        }
      } catch (e) {
        debugPrint('水鱼 API 请求异常: $e');
        if (songs.isEmpty) return false;
      }

      // ── 3. 标记 union API 独有的歌曲（不在旧API中）为 isExtra ──
      // 水鱼 API 中没有的 union 歌曲 = 可能是非官方/补充歌曲，不参与推荐
      final List<String> unionExtraIds = [];
      if (oldSongIds.isNotEmpty) {
        for (int i = 0; i < songs.length; i++) {
          final song = songs[i];
          if (unionSongIds.contains(song.id) && !oldSongIds.contains(song.id)) {
            // 该歌曲仅在 union API 中存在，标记为 extra
            // 但不标记 maidata 追加的歌曲（cids全为0的那些）
            final isMaidataSong = song.cids.isNotEmpty && song.cids.every((cid) => cid == 0);
            if (!isMaidataSong) {
              songs[i] = Song(
                id: song.id,
                title: song.title,
                type: song.type,
                ds: song.ds,
                level: song.level,
                cids: song.cids,
                charts: song.charts,
                basicInfo: song.basicInfo,
                isExtra: true,
              );
              unionExtraIds.add(song.id);
            }
          }
        }
        debugPrint('标记了 ${unionExtraIds.length} 首 union 独有歌曲为 extra（不参与推荐）');
      }

      // ── 4. 保存 union extra 歌曲 ID 列表 ──
      if (unionExtraIds.isNotEmpty) {
        await _saveUnionExtraSongIds(unionExtraIds);
      } else {
        await _clearUnionExtraSongIds();
      }

      // ── 5. 处理 maidata 追加 ──
      if (maidataTexts != null && maidataTexts.isNotEmpty) {
        debugPrint('开始解析 maidata 并追加缺失歌曲...');

        List<String>? cachedAddedSongIds = await _getCachedAddedSongIds();
        bool useCachedList = cachedAddedSongIds != null && await _isAddedSongsCacheValid();

        if (useCachedList) {
          debugPrint('使用缓存的追加歌曲列表（共 ${cachedAddedSongIds.length} 首）');
        }

        int addedCount = 0;
        List<String> newlyAddedSongIds = [];

        // 分批处理 maidata，每批50首
        const batchSize = 50;
        for (int i = 0; i < maidataTexts.length; i += batchSize) {
          int end = i + batchSize;
          if (end > maidataTexts.length) {
            end = maidataTexts.length;
          }
          List<String> batch = maidataTexts.sublist(i, end);

          for (String text in batch) {
            try {
              MaidataData maidata = MaidataDecodeUtil.decode(text);

              if (maidata.title.isEmpty) {
                continue;
              }

              String songId = maidata.shortId.toString();

              if (useCachedList && !cachedAddedSongIds.contains(songId)) {
                continue;
              }

              bool exists = songs.any((song) => song.id == songId);

              if (!exists) {
                Song? newSong = _maidataToSong(maidata);
                if (newSong == null) {
                  continue;
                }
                songs.add(newSong);
                addedCount++;
                newlyAddedSongIds.add(songId);
              }
            } catch (e) {
              debugPrint('  解析 maidata 失败: $e');
            }
          }

          await Future.delayed(Duration(milliseconds: 10));
        }

        if (!useCachedList && newlyAddedSongIds.isNotEmpty) {
          await _saveAddedSongIds(newlyAddedSongIds);
          debugPrint('已保存追加歌曲列表到缓存（有效期 ${CacheTimestampConstant.maidataAddedSongsCacheDays} 天）');
        }

        if (addedCount > 0) {
          debugPrint('成功从 maidata 追加 $addedCount 首歌曲');
        } else {
          debugPrint('maidata 中没有缺失的歌曲');
        }
      }

      // ── 6. 编码并写入本地缓存 ──
      final songsJson = await _encodeSongsInBackground(songs);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(CacheKeyConstant.cachedSongs, songsJson);

      debugPrint('成功更新音乐数据缓存，共 ${songs.length} 首歌曲');
      return true;
    } catch (e) {
      debugPrint('获取音乐数据时出错: $e');
      return false;
    }
  }
  
  Future<bool> refreshDataWithSmartMaidata() async {
    final maidataManager = MaidataManager();
    
    if (await hasValidAddedSongsCache()) {
      List<String>? addedSongIds = await getAddedSongIds();
      if (addedSongIds != null && addedSongIds.isNotEmpty) {
        debugPrint('使用智能刷新：只获取 ${addedSongIds.length} 首追加歌曲的maidata');
        List<String> maidataTexts = await maidataManager.fetchMaidataForSongIds(addedSongIds);
        return await fetchAndUpdateMusicData(maidataTexts: maidataTexts);
      }
    }
    
    debugPrint('执行全量maidata获取...');
    await maidataManager.fetchAndCacheFullMaidata();
    List<String> maidataTexts = maidataManager.getAllMaidataTexts();
    return await fetchAndUpdateMusicData(maidataTexts: maidataTexts);
  }

  Future<bool> hasCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    final songsJson = prefs.getString(CacheKeyConstant.cachedSongs);
    return songsJson != null && songsJson.isNotEmpty;
  }

  Future<List<Song>?> getCachedSongs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final songsJson = prefs.getString(CacheKeyConstant.cachedSongs);
      
      if (songsJson != null && songsJson.isNotEmpty) {
        // 使用 compute 在后台解析
        return await compute((String jsonStr) {
          final List<dynamic> jsonList = json.decode(jsonStr);
          return jsonList.map((item) => Song.fromJson(item)).toList();
        }, songsJson);
      }
    } catch (e) {
      debugPrint('读取本地缓存时出错: $e');
    }
    
    return null;
  }

  Future<Song?> getCachedSongById(String songId) async {
    try {
      final songs = await getCachedSongs();
      if (songs != null) {
        return songs.firstWhere((song) => song.id == songId);
      }
    } catch (e) {
      debugPrint('根据ID获取缓存歌曲数据时出错: $e');
    }
    
    return null;
  }

  Future<bool> forceUpdateMusicData() async {
    return await fetchAndUpdateMusicData();
  }

  Future<bool> uploadCachedSongsToServer() async {
    try {
      final songs = await getCachedSongs();
      if (songs == null || songs.isEmpty) {
        debugPrint('没有缓存的歌曲数据可上传');
        return false;
      }
      
      List<Map<String, dynamic>> songMaps = songs.map((song) => song.toJson()).toList();
      
      await _cloudService.uploadSongs(songMaps);
      debugPrint('成功将 ${songs.length} 首歌曲上传到服务器');
      return true;
    } catch (e) {
      debugPrint('上传歌曲数据到服务器时出错: $e');
      return false;
    }
  }

  Future<void> getServerSongCount() async {
    try {
      await _cloudService.getSongCount();
    } catch (e) {
      debugPrint('获取服务器歌曲数量时出错: $e');
    }
  }

  Song? _maidataToSong(MaidataData maidata) {
    if (maidata.title.isEmpty) {
      return null;
    }
    
    return MaidataDecodeUtil.toSong(maidata);
  }

  Future<int> parseAndAppendMaidata(String maidataText) async {
    try {
      MaidataData maidata = MaidataDecodeUtil.decode(maidataText);
      
      if (maidata.title.isEmpty) {
        debugPrint('Maidata 解析失败：标题为空');
        return 0;
      }

      Song? newSong = _maidataToSong(maidata);
      if (newSong == null) {
        debugPrint('Maidata 转换为 Song 失败');
        return 0;
      }

      List<Song> existingSongs = await getCachedSongs() ?? [];
      
      bool exists = existingSongs.any((song) => 
        song.id == newSong.id || 
        song.title == newSong.title && song.basicInfo.artist == newSong.basicInfo.artist
      );

      if (exists) {
        debugPrint('歌曲 "${newSong.title}" 已存在于缓存中，跳过');
        return 0;
      }

      existingSongs.add(newSong);
      
      final songsJson = await _encodeSongsInBackground(existingSongs);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(CacheKeyConstant.cachedSongs, songsJson);
      
      debugPrint('成功追加歌曲 "${newSong.title}" 到缓存');
      return 1;
    } catch (e) {
      debugPrint('解析并追加 Maidata 时出错: $e');
      return 0;
    }
  }

  Future<int> batchParseAndAppendMaidata(List<String> maidataTexts) async {
    int count = 0;
    for (String text in maidataTexts) {
      count += await parseAndAppendMaidata(text);
    }
    debugPrint('批量追加完成，共新增 $count 首歌曲');
    return count;
  }

  Future<List<String>> getMissingSongIdsFromMaidata(List<String> maidataTexts) async {
    List<String> missingIds = [];
    List<Song> existingSongs = await getCachedSongs() ?? [];
    
    for (String text in maidataTexts) {
      try {
        MaidataData maidata = MaidataDecodeUtil.decode(text);
        String songId = maidata.shortId.toString();
        if (songId.isEmpty || songId == '0') {
          songId = maidata.title.hashCode.toString();
        }
        
        bool exists = existingSongs.any((song) => 
          song.id == songId || 
          song.title == maidata.title && song.basicInfo.artist == maidata.artist
        );
        
        if (!exists && maidata.title.isNotEmpty) {
          missingIds.add(songId);
        }
      } catch (e) {
        debugPrint('解析 Maidata 时出错: $e');
      }
    }
    
    return missingIds;
  }
  
  Future<List<String>?> _getCachedAddedSongIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? cachedData = prefs.getString(CacheKeyConstant.maidataAddedSongs);
      if (cachedData != null) {
        return List<String>.from(json.decode(cachedData));
      }
    } catch (e) {
      debugPrint('获取缓存的追加歌曲列表失败: $e');
    }
    return null;
  }
  
  Future<void> _saveAddedSongIds(List<String> songIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(CacheKeyConstant.maidataAddedSongs, json.encode(songIds));
      await prefs.setInt(CacheKeyConstant.maidataAddedSongsTimestamp, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('保存追加歌曲列表失败: $e');
    }
  }
  
  Future<bool> _isAddedSongsCacheValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int? timestamp = prefs.getInt(CacheKeyConstant.maidataAddedSongsTimestamp);
      if (timestamp != null) {
        int now = DateTime.now().millisecondsSinceEpoch;
        return now - timestamp < CacheTimestampConstant.maidataAddedSongsCacheMillis;
      }
    } catch (e) {
      debugPrint('检查追加歌曲缓存有效性失败: $e');
    }
    return false;
  }
  
  Future<void> clearAddedSongsCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(CacheKeyConstant.maidataAddedSongs);
      await prefs.remove(CacheKeyConstant.maidataAddedSongsTimestamp);
      debugPrint('追加歌曲缓存已清除');
    } catch (e) {
      debugPrint('清除追加歌曲缓存失败: $e');
    }
  }
  
  Future<bool> hasValidAddedSongsCache() async {
    List<String>? cachedIds = await _getCachedAddedSongIds();
    if (cachedIds == null || cachedIds.isEmpty) {
      return false;
    }
    return _isAddedSongsCacheValid();
  }
  
  Future<List<String>?> getAddedSongIds() async {
    if (await hasValidAddedSongsCache()) {
      return _getCachedAddedSongIds();
    }
    return null;
  }

  // ── Union API 独有歌曲（不参与推荐系统） ──

  /// 保存 union API 独有的歌曲 ID 列表
  Future<void> _saveUnionExtraSongIds(List<String> songIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(CacheKeyConstant.unionExtraSongIds, json.encode(songIds));
    } catch (e) {
      debugPrint('保存 union extra 歌曲ID失败: $e');
    }
  }

  /// 清除 union API 独有歌曲 ID 列表
  Future<void> _clearUnionExtraSongIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(CacheKeyConstant.unionExtraSongIds);
    } catch (e) {
      debugPrint('清除 union extra 歌曲ID失败: $e');
    }
  }

  /// 获取 union API 独有的歌曲 ID 列表（来自新API但不在旧水鱼API中）
  Future<List<String>> getUnionExtraSongIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(CacheKeyConstant.unionExtraSongIds);
      if (cachedData != null) {
        return List<String>.from(json.decode(cachedData));
      }
    } catch (e) {
      debugPrint('获取 union extra 歌曲ID失败: $e');
    }
    return [];
  }

  /// 检查歌曲是否应被排除在推荐/计算之外
  /// 排除条件：1) cids全为0 (maidata追加) 2) isExtra (union独有) 3) 6位数ID (宴会场)
  static bool isSongExcludedFromRecommendations(Song song) {
    // 6位数ID的歌曲（宴会场）
    if (song.id.length == 6) return true;
    // maidata 追加的歌曲（cids全为0）
    if (song.cids.isNotEmpty && song.cids.every((cid) => cid == 0)) return true;
    // union API 独有的额外歌曲
    if (song.isExtra) return true;
    return false;
  }
}