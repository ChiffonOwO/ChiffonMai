import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:my_first_flutter_app/api/ApiUrls.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_first_flutter_app/entity/UserBest50Entity.dart';
import 'package:my_first_flutter_app/entity/RecordItem.dart';

class UserBest50Manager {
  // API端点
  static const String _apiUrl = ApiUrls.UserBest50Api;
  
  // 单例实例
  static final UserBest50Manager _instance = UserBest50Manager._internal();
  factory UserBest50Manager() => _instance;
  UserBest50Manager._internal();
  
  // 获取用户Best50数据
  Future<UserBest50Entity> getUserBest50(String qq) async {
    try {
      // 构建请求体
      final requestBody = {
        'qq': qq,
        'b50': '1'
      };
      
      // 发送POST请求
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );
      
      // 检查响应状态
      if (response.statusCode == 200) {
        // 解析响应数据
        final jsonData = json.decode(response.body);
        
        // 缓存数据
        await _cacheBest50Data(qq, jsonData);
        
        return _parseBest50Data(jsonData);
      } else {
        throw Exception('Failed to load best50 data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching best50 data: $e');
      throw e;
    }
  }
  
  // 缓存Best50数据
  Future<void> _cacheBest50Data(String qq, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // 缓存数据，使用qq作为key的一部分
      await prefs.setString('best50_data_$qq', json.encode(data));
      // 缓存最后使用的qq号
      await prefs.setString('last_used_qq', qq);
    } catch (e) {
      print('Error caching best50 data: $e');
    }
  }
  
  // 获取缓存的Best50数据
  Future<Map<String, dynamic>?> getCachedBest50Data() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // 获取最后使用的qq号
      final lastQQ = prefs.getString('last_used_qq');
      if (lastQQ != null) {
        // 获取对应的缓存数据
        final cachedData = prefs.getString('best50_data_$lastQQ');
        if (cachedData != null) {
          return json.decode(cachedData);
        }
      }
      return null;
    } catch (e) {
      print('Error getting cached best50 data: $e');
      return null;
    }
  }
  
  // 解析Best50数据
  UserBest50Entity _parseBest50Data(Map<String, dynamic> jsonData) {
    // 解析dx和sd数据
    final dxRecords = _parseRecordItems(jsonData['charts']['dx'] ?? []);
    final sdRecords = _parseRecordItems(jsonData['charts']['sd'] ?? []);
    
    // 创建Charts对象
    final charts = Charts(
      dx: dxRecords,
      sd: sdRecords,
    );
    
    // 创建UserBest50Entity对象
    return UserBest50Entity(
      additionalRating: jsonData['additional_rating'] ?? 0,
      charts: charts,
    );
  }
  
  // 解析RecordItem列表
  List<RecordItem> _parseRecordItems(List<dynamic> records) {
    return records.map((record) => RecordItem.fromJson(record)).toList();
  }
}