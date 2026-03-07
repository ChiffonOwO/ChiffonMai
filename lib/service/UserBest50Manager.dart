import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:my_first_flutter_app/entity/UserBest50Entity.dart';
import 'package:my_first_flutter_app/entity/RecordItem.dart';

class UserBest50Manager {
  // API端点
  static const String _apiUrl = 'https://www.diving-fish.com/api/maimaidxprober/query/player';
  
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
        print(response.body);
        return _parseBest50Data(jsonData);
      } else {
        throw Exception('Failed to load best50 data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching best50 data: $e');
      throw e;
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