import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:my_first_flutter_app/api/ApiUrls.dart';
import 'package:my_first_flutter_app/api/DeveloperToken.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constant/CacheKeyConstant.dart';

class UserPlayDataManager {
  // 单例模式
  static final UserPlayDataManager _instance = UserPlayDataManager._internal();
  factory UserPlayDataManager() => _instance;
  UserPlayDataManager._internal();

  // 缓存时间戳键
  static const String _lastUpdateKey = 'user_play_data_last_update';

  // API 地址
  static const String _apiUrl = ApiUrls.UserPlayDataApi;

  // 从 API 获取用户游玩数据
  Future<Map<String, dynamic>?> fetchUserPlayData(String qq) async {
    try {
      // 构建 API URL
      final url = Uri.parse('$_apiUrl?qq=$qq');
      
      // 设置请求头
      final headers = {
        'Developer-Token': DeveloperToken.DivingFishDeveloperToken,
      };
      
      // 发送 GET 请求
      final response = await http.get(url, headers: headers);
      
      if (response.statusCode == 200) {
        // 解析 JSON 数据
        final Map<String, dynamic> data = json.decode(response.body);
        
        // 保存到缓存
        await _saveToCache(data);
        
        print('成功从 API 获取用户游玩数据');
        return data;
      } else {
        print('API 请求失败，状态码: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('获取用户游玩数据时出错: $e');
      return null;
    }
  }

  // 从缓存获取用户游玩数据
  Future<Map<String, dynamic>?> getCachedUserPlayData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(CacheKeyConstant.userPlayData);
      
      if (jsonString != null) {
        return json.decode(jsonString);
      }
      return null;
    } catch (e) {
      print('从缓存获取用户游玩数据时出错: $e');
      return null;
    }
  }

  // 保存数据到缓存
  Future<void> _saveToCache(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(CacheKeyConstant.userPlayData, json.encode(data));
      await prefs.setInt(_lastUpdateKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('保存用户游玩数据到缓存时出错: $e');
    }
  }

  // 清除缓存
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(CacheKeyConstant.userPlayData);
      await prefs.remove(_lastUpdateKey);
    } catch (e) {
      print('清除用户游玩数据缓存时出错: $e');
    }
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
}