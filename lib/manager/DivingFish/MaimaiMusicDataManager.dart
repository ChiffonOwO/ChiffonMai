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
import 'package:my_first_flutter_app/utils/ApiClient.dart';

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

      // ── 1. 并行获取水鱼 API 和 union API 的歌曲数据 ──
      List<Song> songs = [];

      // 同时发起两个请求
      final dfFuture = ApiClient.get(Uri.parse(_apiUrl));
      final unionFuture = ApiClient.get(Uri.parse(_unionApiUrl));

      // 解析水鱼数据
      List<Song>? dfSongs;
      try {
        final dfResponse = await dfFuture;
        if (dfResponse.statusCode == 200) {
          dfSongs = await _parseSongsInBackground(dfResponse.body);
          debugPrint('水鱼 API 返回 ${dfSongs!.length} 首歌曲');
        } else {
          debugPrint('水鱼 API 请求失败，状态码: ${dfResponse.statusCode}');
        }
      } catch (e) {
        debugPrint('水鱼 API 请求异常: $e');
      }

      // 解析 union 数据
      List<Song>? unionSongs;
      try {
        final unionResponse = await unionFuture;
        if (unionResponse.statusCode == 200) {
          unionSongs = await _parseSongsInBackground(unionResponse.body);
          debugPrint('Union API 返回 ${unionSongs!.length} 首歌曲');
        } else {
          debugPrint('Union API 请求失败，状态码: ${unionResponse.statusCode}');
        }
      } catch (e) {
        debugPrint('Union API 请求异常: $e');
      }

      // ── 2. 合并数据 ──
      if (dfSongs != null) {
        songs = dfSongs;
      } else if (unionSongs != null) {
        songs = unionSongs;
      } else {
        return false; // 两个 API 都失败了
      }

      if (unionSongs != null && dfSongs != null) {
        // 水鱼为主，union 补充
        final existingIds = songs.map((s) => s.id).toSet();

        final unionSongMap = <String, Song>{};
        for (final s in unionSongs) {
          unionSongMap[s.id] = s;
        }

        // 从 union 补充 release_date
        for (int i = 0; i < songs.length; i++) {
          final unionSong = unionSongMap[songs[i].id];
          if (unionSong != null &&
              unionSong.basicInfo.releaseDate.isNotEmpty &&
              songs[i].basicInfo.releaseDate.isEmpty) {
            final old = songs[i];
            songs[i] = Song(
              id: old.id, title: old.title, type: old.type,
              ds: old.ds, level: old.level, cids: old.cids,
              charts: old.charts,
              basicInfo: BasicInfo(
                title: old.basicInfo.title,
                artist: old.basicInfo.artist,
                genre: old.basicInfo.genre,
                bpm: old.basicInfo.bpm,
                releaseDate: unionSong.basicInfo.releaseDate,
                from: old.basicInfo.from,
                isNew: old.basicInfo.isNew,
              ),
              isExtra: old.isExtra,
            );
          }
        }

        for (final unionSong in unionSongs) {
          if (!existingIds.contains(unionSong.id)) {
            final isMaidataSong = unionSong.cids.isNotEmpty && unionSong.cids.every((cid) => cid == 0);
            songs.add(Song(
              id: unionSong.id,
              title: unionSong.title,
              type: unionSong.type,
              ds: unionSong.ds,
              level: unionSong.level,
              cids: unionSong.cids,
              charts: unionSong.charts,
              basicInfo: unionSong.basicInfo,
              isExtra: isMaidataSong ? false : true,
            ));
          }
        }
        final unionExtraCount = songs.length - existingIds.length;
        debugPrint('合并后共 ${songs.length} 首歌曲 (新增 $unionExtraCount 首 union 独有歌曲，已标记为 extra)');
      }

      // ── 3. 收集 union extra 歌曲 ID 列表 ──
      final List<String> unionExtraIds = songs
          .where((s) => s.isExtra)
          .map((s) => s.id)
          .toList();
      if (unionExtraIds.isNotEmpty) {
        debugPrint('共 ${unionExtraIds.length} 首 union 独有歌曲标记为 extra');
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

        final existingIdSet = songs.map((s) => s.id).toSet();

        // 第一遍：快速提取 shortId，只收集需要完整解码的文本
        final List<String> textsNeedingDecode = [];
        final List<String> correspondingIds = [];
        for (final text in maidataTexts) {
          final quickId = MaidataDecodeUtil.quickExtractShortId(text);
          if (quickId == null) continue;

          if (useCachedList && !cachedAddedSongIds.contains(quickId)) continue;
          if (existingIdSet.contains(quickId)) continue;

          textsNeedingDecode.add(text);
          correspondingIds.add(quickId);
        }

        debugPrint('${maidataTexts.length} 首 maidata 中，${textsNeedingDecode.length} 首需要完整解码');

        int addedCount = 0;
        final List<String> newlyAddedSongIds = [];

        if (textsNeedingDecode.isNotEmpty) {
          // 第二遍：使用 compute() 在后台 isolate 中批量解码
          const decodeBatchSize = 200;
          for (int i = 0; i < textsNeedingDecode.length; i += decodeBatchSize) {
            final end = (i + decodeBatchSize > textsNeedingDecode.length)
                ? textsNeedingDecode.length
                : i + decodeBatchSize;
            final batch = textsNeedingDecode.sublist(i, end);

            // 在后台 isolate 中解析
            final List<Map<String, dynamic>> decodedMaps =
                await compute(MaidataDecodeUtil.batchDecodeForIsolate, batch);

            for (final map in decodedMaps) {
              final maidata = MaidataDecodeUtil.fromIsolateMap(map);
              final songId = maidata.shortId.toString();

              if (existingIdSet.contains(songId)) continue;

              final newSong = _maidataToSong(maidata);
              if (newSong == null) continue;

              songs.add(newSong);
              existingIdSet.add(songId);
              addedCount++;
              newlyAddedSongIds.add(songId);
            }

            debugPrint('  maidata 解码进度: ${end}/${textsNeedingDecode.length}');
          }
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

    // ── 检查全量缓存 TTL ──
    final cacheValid = await maidataManager.isFullCacheValid();

    if (cacheValid) {
      debugPrint('maidata 缓存仍在 TTL 有效期内，计算增量...');

      // 获取 union API 全量歌曲 ID 列表（轻量 API 调用）
      List<String> unionSongIds = [];
      try {
        final unionResponse = await ApiClient.get(Uri.parse(_unionApiUrl));
        if (unionResponse.statusCode == 200) {
          final unionSongs = await _parseSongsInBackground(unionResponse.body);
          unionSongIds = unionSongs.map((s) => s.id).toList();
        }
      } catch (e) {
        debugPrint('获取 union 歌曲列表失败，跳过 maidata 刷新: $e');
        return await fetchAndUpdateMusicData();
      }

      // 计算缓存中缺失的歌曲 ID
      final missingIds = unionSongIds
          .where((id) => !maidataManager.hasCachedMaidata(id))
          .toList();

      if (missingIds.isEmpty) {
        debugPrint('maidata 缓存完整（${maidataManager.cachedCount} 首），跳过刷新');
        return await fetchAndUpdateMusicData();
      }

      debugPrint('缓存缺失 ${missingIds.length} 首，增量获取 maidata...');
      final maidataTexts = await maidataManager.fetchMaidataForSongIds(missingIds);
      // 同时更新 addedSongIds 缓存
      await _saveAddedSongIds(missingIds);
      return await fetchAndUpdateMusicData(maidataTexts: maidataTexts);
    }

    // ── 缓存过期：全量刷新 ──
    debugPrint('maidata 缓存已过期，执行全量刷新...');
    await maidataManager.fetchAndCacheFullMaidata();
    final maidataTexts = maidataManager.getAllMaidataTexts();
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