import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:my_first_flutter_app/api/ApiUrls.dart';
import 'package:my_first_flutter_app/utils/ApiClient.dart';

/// 水鱼账号 OAuth 绑定流程封装。
/// 后端（server.js /api/prober）持有 client_secret，App 只负责发起绑定与打开授权链接。
class DivingFishOAuthManager {
  static final DivingFishOAuthManager _instance = DivingFishOAuthManager._internal();
  factory DivingFishOAuthManager() => _instance;
  DivingFishOAuthManager._internal();

  /// 发起一次设备码绑定，返回授权链接（verification_uri_complete）。
  Future<String> startBinding(String qq) async {
    try {
      final response = await ApiClient.post(
        Uri.parse('${ApiUrls.ProberBaseUrl}/bind'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'qq': qq}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return (data['verificationUriComplete'] as String?) ?? '';
      }
      debugPrint('发起绑定失败，状态码: ${response.statusCode}');
      return '';
    } catch (e) {
      debugPrint('发起绑定异常: $e');
      return '';
    }
  }

  /// 打开绑定链接让用户完成授权。
  Future<bool> openBindingLink(String qq) async {
    final url = await startBinding(qq);
    if (url.isEmpty) return false;
    final uri = Uri.parse(url);
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// 查询该 QQ 是否已授权本应用（后端换票探测）。
  /// 返回 true=已授权，false=未授权，null=查询失败/未知。
  Future<bool?> checkAuthorization(String qq) async {
    try {
      final response = await ApiClient.get(
        Uri.parse('${ApiUrls.ProberBaseUrl}/authorization-status?qq=$qq'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data['authorized'] as bool?;
      }
      debugPrint('查询授权状态失败，状态码: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('查询授权状态异常: $e');
      return null;
    }
  }
}
