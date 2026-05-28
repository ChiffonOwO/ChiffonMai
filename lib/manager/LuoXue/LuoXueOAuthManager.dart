import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../api/ApiUrls.dart';
import '../../api/DeveloperToken.dart';
import '../../constant/CacheKeyConstant.dart';

/// 落雪OAuth鉴权管理器
/// 实现OAuth 2.0授权码流程（authorization_code + oob模式）
class LuoXueOAuthManager {
  static final LuoXueOAuthManager _instance = LuoXueOAuthManager._internal();
  
  factory LuoXueOAuthManager() => _instance;
  
  LuoXueOAuthManager._internal();
  
  // OAuth配置常量
  static const String _clientId = '56a76019-2e7b-4650-abeb-082b8d5dede6';
  static const String _redirectUri = 'urn:ietf:wg:oauth:2.0:oob';
  static const String _scope = 'read_user_profile write_player read_player';
  
  // 缓存键（使用常量类统一管理）
  static const String _accessTokenKey = CacheKeyConstant.luoxueAccessToken;
  static const String _refreshTokenKey = CacheKeyConstant.luoxueRefreshToken;
  static const String _expiresAtKey = CacheKeyConstant.luoxueExpiresAt;
  static const String _tokenTypeKey = CacheKeyConstant.luoxueTokenType;
  
  /// 获取授权URL
  /// 用户访问此URL进行授权，授权后会获得授权码（显示在页面上）
  String getAuthorizationUrl() {
    final params = {
      'response_type': 'code',
      'client_id': _clientId,
      'redirect_uri': Uri.encodeComponent(_redirectUri),
      'scope': _scope,
    };
    final queryString = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    return '${ApiUrls.LuoXueOAuthAuthorizeUrl}?$queryString';
  }
  
  /// 使用授权码获取令牌
  /// 授权码由用户在浏览器中完成授权后获得（显示在页面上）
  Future<OAuthTokenResponse?> exchangeCodeForToken(String code) async {
    try {
      debugPrint('=== 开始获取令牌 ===');
      debugPrint('授权码长度: ${code.length}');
      debugPrint('client_id: ${_clientId.substring(0, 10)}...');
      debugPrint('client_secret: ${DeveloperToken.LuoXueClientSecret.substring(0, 10)}...');
      debugPrint('redirect_uri: $_redirectUri');
      debugPrint('请求URL: ${ApiUrls.LuoXueOAuthTokenUrl}');
      
      final response = await http.post(
        Uri.parse(ApiUrls.LuoXueOAuthTokenUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'grant_type': 'authorization_code',
          'code': code,
          'client_id': _clientId,
          'client_secret': DeveloperToken.LuoXueClientSecret,
          'redirect_uri': _redirectUri,
        },
      );
      
      debugPrint('HTTP状态码: ${response.statusCode}');
      debugPrint('响应体: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('令牌响应原始数据: $data');
        
        final tokenData = data['data'] ?? data;
        
        final tokenResponse = OAuthTokenResponse.fromJson(tokenData);
        debugPrint('解析后的令牌: accessToken=${tokenResponse.accessToken.substring(0, tokenResponse.accessToken.length > 10 ? 10 : tokenResponse.accessToken.length)}..., expiresIn=${tokenResponse.expiresIn}');
        
        if (tokenResponse.accessToken.isEmpty) {
          debugPrint('❌ 获取令牌失败: accessToken 为空');
          return null;
        }
        if (tokenResponse.expiresIn <= 0) {
          debugPrint('❌ 获取令牌失败: expiresIn 无效 (${tokenResponse.expiresIn})');
          return null;
        }
        
        await _saveToken(tokenResponse);
        debugPrint('✅ 令牌获取成功，已保存到缓存');
        return tokenResponse;
      } else {
        String errorMsg = '未知错误';
        try {
          final errorData = json.decode(response.body);
          errorMsg = errorData['message'] as String? ?? errorMsg;
        } catch (_) {}
        
        debugPrint('❌ 获取令牌失败: HTTP ${response.statusCode} - $errorMsg');
        return null;
      }
    } catch (e) {
      debugPrint('❌ 获取令牌异常: $e');
      debugPrint('异常类型: ${e.runtimeType}');
      return null;
    }
  }
  
  /// 使用刷新令牌获取新令牌
  Future<OAuthTokenResponse?> refreshToken() async {
    final refreshToken = await _getRefreshToken();
    if (refreshToken == null) {
      return null;
    }
    
    try {
      final response = await http.post(
        Uri.parse(ApiUrls.LuoXueOAuthTokenUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
          'client_id': _clientId,
          'client_secret': DeveloperToken.LuoXueClientSecret,
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tokenData = data['data'] ?? data;
        final tokenResponse = OAuthTokenResponse.fromJson(tokenData);
        await _saveToken(tokenResponse);
        return tokenResponse;
      } else {
        debugPrint('刷新令牌失败: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('刷新令牌异常: $e');
      return null;
    }
  }
  
  /// 获取当前访问令牌
  Future<String?> getAccessToken() async {
    final token = await _getAccessToken();
    if (token == null) {
      return null;
    }
    
    final expiresAt = await _getExpiresAt();
    if (expiresAt != null && DateTime.now().millisecondsSinceEpoch + 60000 >= expiresAt) {
      final refreshed = await refreshToken();
      return refreshed?.accessToken;
    }
    
    return token;
  }
  
  /// 检查是否已登录
  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null;
  }
  
  /// 登出
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_expiresAtKey);
    await prefs.remove(_tokenTypeKey);
  }
  
  /// 获取带Bearer授权头的请求头
  Future<Map<String, String>> getAuthHeaders() async {
    final token = await getAccessToken();
    
    if (token != null) {
      final tokenType = await _getTokenType() ?? 'Bearer';
      return {
        'Authorization': '$tokenType $token',
        'Content-Type': 'application/json',
      };
    }
    
    return {'Content-Type': 'application/json'};
  }
  
  Future<void> _saveToken(OAuthTokenResponse token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, token.accessToken);
    if (token.refreshToken != null) {
      await prefs.setString(_refreshTokenKey, token.refreshToken!);
    }
    final expiresAt = DateTime.now().millisecondsSinceEpoch + (token.expiresIn * 1000);
    await prefs.setInt(_expiresAtKey, expiresAt);
    await prefs.setString(_tokenTypeKey, token.tokenType);
  }
  
  Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }
  
  Future<String?> _getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }
  
  Future<int?> _getExpiresAt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_expiresAtKey);
  }
  
  Future<String?> _getTokenType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenTypeKey);
  }
}

/// OAuth令牌响应
class OAuthTokenResponse {
  final String accessToken;
  final String tokenType;
  final int expiresIn;
  final String? refreshToken;
  final String? scope;
  
  OAuthTokenResponse({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    this.refreshToken,
    this.scope,
  });
  
  factory OAuthTokenResponse.fromJson(Map<String, dynamic> json) {
    return OAuthTokenResponse(
      accessToken: json['access_token'] as String? ?? '',
      tokenType: json['token_type'] as String? ?? 'Bearer',
      expiresIn: json['expires_in'] as int? ?? 0,
      refreshToken: json['refresh_token'] as String?,
      scope: json['scope'] as String?,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'token_type': tokenType,
      'expires_in': expiresIn,
      'refresh_token': refreshToken,
      'scope': scope,
    };
  }
  
  @override
  String toString() {
    return 'OAuthTokenResponse{accessToken: ${accessToken.substring(0, 10)}..., tokenType: $tokenType, expiresIn: $expiresIn}';
  }
}