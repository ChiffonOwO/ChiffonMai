import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_first_flutter_app/entity/DiffSong.dart';

class DiffMusicDataManager {
  // 单例模式
  static final DiffMusicDataManager _instance = DiffMusicDataManager._internal();
  factory DiffMusicDataManager() => _instance;
  DiffMusicDataManager._internal();

  // API 地址
  static const String _apiUrl = 'https://www.diving-fish.com/api/maimaidxprober/chart_stats';
  
  // 缓存键
  static const String _cacheKey = 'diff_music_data';
  static const String _lastUpdateKey = 'diff_music_data_last_update';
  static const int _cacheExpiryDays = 7;

  // 从 API 获取音乐难度数据并更新缓存
  Future<bool> fetchAndUpdateDiffData() async {
    try {
      // 发送 GET 请求
      final response = await http.get(Uri.parse(_apiUrl));
      
      if (response.statusCode == 200) {
        // 解析 JSON 数据
        final Map<String, dynamic> jsonData = json.decode(response.body);
        
        // 转换为 DiffSong 对象
        final DiffSong diffSong = DiffSong.fromJson(jsonData);
        
        // 写入本地缓存
        final prefs = await SharedPreferences.getInstance();
        final diffJson = json.encode(diffSong.toJson());
        await prefs.setString(_cacheKey, diffJson);
        await prefs.setInt(_lastUpdateKey, DateTime.now().millisecondsSinceEpoch);
        
        print('成功从 API 获取并更新音乐难度数据');
        return true;
      } else {
        print('API 请求失败，状态码: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('获取音乐难度数据时出错: $e');
      return false;
    }
  }

  // 检查是否有缓存数据
  Future<bool> hasCachedData() async {
    // 检查本地缓存
    final prefs = await SharedPreferences.getInstance();
    final diffJson = prefs.getString(_cacheKey);
    return diffJson != null && diffJson.isNotEmpty;
  }

  // 获取缓存的难度数据
  Future<DiffSong?> getCachedDiffData() async {
    // 从本地缓存读取
    try {
      final prefs = await SharedPreferences.getInstance();
      final diffJson = prefs.getString(_cacheKey);
      
      if (diffJson != null && diffJson.isNotEmpty) {
        final Map<String, dynamic> jsonData = json.decode(diffJson);
        final DiffSong diffSong = DiffSong.fromJson(jsonData);
        return diffSong;
      }
    } catch (e) {
      print('读取本地缓存时出错: $e');
    }
    
    // 如果没有缓存，尝试从 API 获取
    await fetchAndUpdateDiffData();
    
    // 再次尝试读取
    try {
      final prefs = await SharedPreferences.getInstance();
      final diffJson = prefs.getString(_cacheKey);
      
      if (diffJson != null && diffJson.isNotEmpty) {
        final Map<String, dynamic> jsonData = json.decode(diffJson);
        final DiffSong diffSong = DiffSong.fromJson(jsonData);
        return diffSong;
      }
    } catch (e) {
      print('读取更新后的缓存时出错: $e');
    }
    
    return null;
  }

  // 手动刷新缓存
  Future<void> refreshCache() async {
    await fetchAndUpdateDiffData();
  }

  // 获取最后更新时间
  Future<int?> getLastUpdateTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_lastUpdateKey);
    } catch (e) {
      print('获取最后更新时间时出错: $e');
      return null;
    }
  }

  // 清除缓存
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_lastUpdateKey);
    } catch (e) {
      print('清除缓存时出错: $e');
    }
  }
}