import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import './LuoXueOAuthManager.dart';
import '../../api/ApiUrls.dart';
import '../../entity/LuoXue/LuoXuePlayer.dart';
import '../../entity/LuoXue/LuoXueScore.dart';

/// 落雪用户游玩数据管理器
/// 使用OAuth鉴权访问落雪API
/// 
/// API基础URL: https://maimai.lxns.net/api/v0/
/// 授权范围: read_user_profile write_player read_player
class LuoXueUserPlayDataManager {
  static final LuoXueUserPlayDataManager _instance = LuoXueUserPlayDataManager._internal();
  
  factory LuoXueUserPlayDataManager() => _instance;
  
  LuoXueUserPlayDataManager._internal();
  
  final LuoXueOAuthManager _oauthManager = LuoXueOAuthManager();
  
  /// 获取玩家信息
  /// GET /api/v0/user/maimai/player
  Future<LuoXuePlayer?> getPlayerInfo() async {
    try {
      final headers = await _oauthManager.getAuthHeaders();
      final response = await http.get(
        Uri.parse(ApiUrls.LuoXuePlayerApi),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return LuoXuePlayer.fromJson(data);
      } else {
        print('获取玩家信息失败: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('获取玩家信息异常: $e');
      return null;
    }
  }
  
  /// 获取玩家所有成绩
  /// GET /api/v0/user/maimai/player/scores
  Future<List<LuoXueScore>?> getPlayerRecords() async {
    try {
      final headers = await _oauthManager.getAuthHeaders();
      final response = await http.get(
        Uri.parse(ApiUrls.LuoXuePlayerScoresApi),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return data.map((item) => LuoXueScore.fromJson(item)).toList();
        }
        return null;
      } else {
        print('获取玩家成绩失败: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('获取玩家成绩异常: $e');
      return null;
    }
  }
  
  /// 获取授权URL
  /// 用户访问此URL进行授权，授权后会获得授权码（显示在页面上）
  String getAuthorizationUrl() {
    return _oauthManager.getAuthorizationUrl();
  }
  
  /// 使用授权码获取令牌
  /// 授权码由用户在浏览器中完成授权后获得（显示在页面上）
  Future<bool> exchangeCodeForToken(String code) async {
    final result = await _oauthManager.exchangeCodeForToken(code);
    return result != null;
  }
  
  /// 检查是否已登录（是否有有效的访问令牌）
  Future<bool> isLoggedIn() async {
    return _oauthManager.isLoggedIn();
  }
  
  /// 登出（清除本地令牌缓存）
  Future<void> logout() async {
    await _oauthManager.logout();
  }
  
  /// 获取当前访问令牌
  Future<String?> getAccessToken() async {
    return _oauthManager.getAccessToken();
  }
}