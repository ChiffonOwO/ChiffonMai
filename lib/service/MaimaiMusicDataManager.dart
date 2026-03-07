import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:my_first_flutter_app/service/SongSearchService.dart';

class MaimaiMusicDataManager {
  // 单例模式
  static final MaimaiMusicDataManager _instance = MaimaiMusicDataManager._internal();
  factory MaimaiMusicDataManager() => _instance;
  MaimaiMusicDataManager._internal();

  // API 地址
  static const String _apiUrl = 'https://www.diving-fish.com/api/maimaidxprober/music_data';

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
        
        // 更新缓存
        SongSearchService.cachedSongs = songs;
        
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
  bool hasCachedData() {
    return SongSearchService.cachedSongs != null && SongSearchService.cachedSongs!.isNotEmpty;
  }

  // 获取缓存的歌曲数据
  List<Song>? getCachedSongs() {
    return SongSearchService.cachedSongs;
  }
}