import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../api/ApiUrls.dart';
import '../entity/Song.dart';
import '../service/GuessChartGame/MultiplayerCloudBaseService.dart';
import '../utils/MaidataDecodeUtil.dart';
import '../constant/CacheKeyConstant.dart';
import '../constant/CacheTimestampConstant.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'MaidataManager.dart';

class MaimaiMusicDataManager {
  // 单例模式
  static final MaimaiMusicDataManager _instance = MaimaiMusicDataManager._internal();
  factory MaimaiMusicDataManager() => _instance;
  MaimaiMusicDataManager._internal();

  // API 地址
  static const String _apiUrl = ApiUrls.MusicDataApi;
  
  // 多人游戏云服务
  final MultiplayerCloudBaseService _cloudService = MultiplayerCloudBaseService();

  // 从 API 获取音乐数据并更新缓存
  Future<bool> fetchAndUpdateMusicData({List<String>? maidataTexts}) async {
    try {
      // 发送 GET 请求
      final response = await http.get(Uri.parse(_apiUrl));
      
      if (response.statusCode == 200) {
        // 解析 JSON 数据
        final List<dynamic> jsonList = json.decode(response.body);
        
        // 转换为 Song 对象列表
        final List<Song> songs = jsonList.map((json) => Song.fromJson(json)).toList();
        
        // 如果提供了 maidata 列表，解析并追加缺失的歌曲
        if (maidataTexts != null && maidataTexts.isNotEmpty) {
          debugPrint('开始解析 maidata 并追加缺失歌曲...');
          
          // 获取缓存的追加歌曲ID列表
          List<String>? cachedAddedSongIds = await _getCachedAddedSongIds();
          bool useCachedList = cachedAddedSongIds != null && await _isAddedSongsCacheValid();
          
          if (useCachedList) {
            debugPrint('使用缓存的追加歌曲列表（共 ${cachedAddedSongIds.length} 首）');
          }
          
          int addedCount = 0;
          List<String> newlyAddedSongIds = [];
          
          for (String text in maidataTexts) {
            try {
              MaidataData maidata = MaidataDecodeUtil.decode(text);
              
              if (maidata.title.isEmpty) {
                continue;
              }
              
              String songId = maidata.shortId.toString();
              
              // 如果使用缓存列表，只处理缓存中的歌曲
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
                //debugPrint('  追加歌曲: ${newSong.title}');
              }
            } catch (e) {
              debugPrint('  解析 maidata 失败: $e');
            }
          }
          
          // 如果是初次拉取（没有缓存），保存新追加的歌曲列表
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
        
        // 写入本地缓存
        final prefs = await SharedPreferences.getInstance();
        final songsJson = json.encode(songs.map((song) => song.toJson()).toList());
        await prefs.setString(CacheKeyConstant.cachedSongs, songsJson);
        
        debugPrint('成功从 API 获取并更新音乐数据，共 ${songs.length} 首歌曲');
        return true;
      } else {
        debugPrint('API 请求失败，状态码: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('获取音乐数据时出错: $e');
      return false;
    }
  }
  
  // 刷新数据（包含智能maidata获取）
  Future<bool> refreshDataWithSmartMaidata() async {
    final maidataManager = MaidataManager();
    
    // 检查是否有有效的追加歌曲缓存
    if (await hasValidAddedSongsCache()) {
      // 使用缓存的追加歌曲列表，只获取这些歌曲的maidata
      List<String>? addedSongIds = await getAddedSongIds();
      if (addedSongIds != null && addedSongIds.isNotEmpty) {
        debugPrint('使用智能刷新：只获取 ${addedSongIds.length} 首追加歌曲的maidata');
        List<String> maidataTexts = await maidataManager.fetchMaidataForSongIds(addedSongIds);
        return await fetchAndUpdateMusicData(maidataTexts: maidataTexts);
      }
    }
    
    // 初次拉取或缓存失效，获取全量maidata
    debugPrint('执行全量maidata获取...');
    await maidataManager.fetchAndCacheFullMaidata();
    List<String> maidataTexts = maidataManager.getAllMaidataTexts();
    return await fetchAndUpdateMusicData(maidataTexts: maidataTexts);
  }

  // 检查是否有缓存数据
  Future<bool> hasCachedData() async {
    // 检查本地缓存
    final prefs = await SharedPreferences.getInstance();
    final songsJson = prefs.getString(CacheKeyConstant.cachedSongs);
    return songsJson != null && songsJson.isNotEmpty;
  }

  // 获取缓存的歌曲数据
  Future<List<Song>?> getCachedSongs() async {
    // 从本地缓存读取
    try {
      final prefs = await SharedPreferences.getInstance();
      final songsJson = prefs.getString(CacheKeyConstant.cachedSongs);
      
      if (songsJson != null && songsJson.isNotEmpty) {
        final List<dynamic> jsonList = json.decode(songsJson);
        final List<Song> songs = jsonList.map((json) => Song.fromJson(json)).toList();
        return songs;
      }
    } catch (e) {
      debugPrint('读取本地缓存时出错: $e');
    }
    
    return null;
  }

  // 根据歌曲ID获取缓存的歌曲数据
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

  // 强制更新音乐数据
  Future<bool> forceUpdateMusicData() async {
    return await fetchAndUpdateMusicData();
  }

  // 将本地缓存的歌曲数据上传到服务器
  Future<bool> uploadCachedSongsToServer() async {
    try {
      // 获取本地缓存的歌曲数据
      final songs = await getCachedSongs();
      if (songs == null || songs.isEmpty) {
        debugPrint('没有缓存的歌曲数据可上传');
        return false;
      }
      
      // 转换为 Map 列表
      List<Map<String, dynamic>> songMaps = songs.map((song) => song.toJson()).toList();
      
      // 上传到服务器
      await _cloudService.uploadSongs(songMaps);
      debugPrint('成功将 ${songs.length} 首歌曲上传到服务器');
      return true;
    } catch (e) {
      debugPrint('上传歌曲数据到服务器时出错: $e');
      return false;
    }
  }

  // 获取服务器上的歌曲数量
  Future<void> getServerSongCount() async {
    try {
      await _cloudService.getSongCount();
    } catch (e) {
      debugPrint('获取服务器歌曲数量时出错: $e');
    }
  }

  // 将 MaidataData 转换为 Song 对象
  Song? _maidataToSong(MaidataData maidata) {
    if (maidata.title.isEmpty) {
      return null;
    }
    
    return MaidataDecodeUtil.toSong(maidata);
  }

  // 解析 maidata 文本并追加到缓存（仅添加缓存中不存在的歌曲）
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
      
      final prefs = await SharedPreferences.getInstance();
      final songsJson = json.encode(existingSongs.map((song) => song.toJson()).toList());
      await prefs.setString(CacheKeyConstant.cachedSongs, songsJson);
      
      debugPrint('成功追加歌曲 "${newSong.title}" 到缓存');
      return 1;
    } catch (e) {
      debugPrint('解析并追加 Maidata 时出错: $e');
      return 0;
    }
  }

  // 批量解析 maidata 文本列表并追加到缓存
  Future<int> batchParseAndAppendMaidata(List<String> maidataTexts) async {
    int count = 0;
    for (String text in maidataTexts) {
      count += await parseAndAppendMaidata(text);
    }
    debugPrint('批量追加完成，共新增 $count 首歌曲');
    return count;
  }

  // 获取缓存中不存在于指定 maidata 列表中的歌曲 ID
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
  
  // 获取缓存的追加歌曲ID列表
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
  
  // 保存追加歌曲ID列表到缓存
  Future<void> _saveAddedSongIds(List<String> songIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(CacheKeyConstant.maidataAddedSongs, json.encode(songIds));
      await prefs.setInt(CacheKeyConstant.maidataAddedSongsTimestamp, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('保存追加歌曲列表失败: $e');
    }
  }
  
  // 检查追加歌曲缓存是否有效
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
  
  // 清除追加歌曲缓存（用于强制刷新）
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
  
  // 获取追加歌曲缓存是否存在且有效
  Future<bool> hasValidAddedSongsCache() async {
    List<String>? cachedIds = await _getCachedAddedSongIds();
    if (cachedIds == null || cachedIds.isEmpty) {
      return false;
    }
    return _isAddedSongsCacheValid();
  }
  
  // 获取缓存的追加歌曲ID列表（对外接口）
  Future<List<String>?> getAddedSongIds() async {
    if (await hasValidAddedSongsCache()) {
      return _getCachedAddedSongIds();
    }
    return null;
  }
}