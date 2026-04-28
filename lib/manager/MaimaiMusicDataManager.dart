import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api/ApiUrls.dart';
import '../entity/Song.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MaimaiMusicDataManager {
  // 单例模式
  static final MaimaiMusicDataManager _instance = MaimaiMusicDataManager._internal();
  factory MaimaiMusicDataManager() => _instance;
  MaimaiMusicDataManager._internal();

  // API 地址
  static const String _apiUrl = ApiUrls.MusicDataApi;

  // 从 API 获取音乐数据并更新缓存
  Future<bool> fetchAndUpdateMusicData() async {
    try {
      // 发送 GET 请求
      final response = await http.get(Uri.parse(_apiUrl));
      
      if (response.statusCode == 200) {
        // 解析 JSON 数据
        final List<dynamic> jsonList = json.decode(response.body);
        
        // 转换为 Song 对象列表
        final List<Song> songs = jsonList.map((json) => Song.fromJson(json)).toList();
        
        // 写入本地缓存
        final prefs = await SharedPreferences.getInstance();
        final songsJson = json.encode(songs.map((song) => song.toJson()).toList());
        await prefs.setString('cached_songs', songsJson);
        
        print('成功从 API 获取并更新音乐数据，共 ${songs.length} 首歌曲');
        return true;
      } else {
        print('API 请求失败，状态码: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('获取音乐数据时出错: $e');
      return false;
    }
  }

  // 检查是否有缓存数据
  Future<bool> hasCachedData() async {
    // 检查本地缓存
    final prefs = await SharedPreferences.getInstance();
    final songsJson = prefs.getString('cached_songs');
    return songsJson != null && songsJson.isNotEmpty;
  }

  // 获取缓存的歌曲数据
  Future<List<Song>?> getCachedSongs() async {
    // 从本地缓存读取
    try {
      final prefs = await SharedPreferences.getInstance();
      final songsJson = prefs.getString('cached_songs');
      
      if (songsJson != null && songsJson.isNotEmpty) {
        final List<dynamic> jsonList = json.decode(songsJson);
        final List<Song> songs = jsonList.map((json) => Song.fromJson(json)).toList();
        return songs;
      }
    } catch (e) {
      print('读取本地缓存时出错: $e');
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
      print('根据ID获取缓存歌曲数据时出错: $e');
    }
    
    return null;
  }

  // 强制更新音乐数据
  Future<bool> forceUpdateMusicData() async {
    return await fetchAndUpdateMusicData();
  }
}