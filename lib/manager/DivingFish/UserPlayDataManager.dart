import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:my_first_flutter_app/api/ApiUrls.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constant/CacheKeyConstant.dart';
import 'package:my_first_flutter_app/utils/ApiClient.dart';
import '../../service/History/ChartHistoryStore.dart';
import 'ProberException.dart';
import '../../utils/CurrentDataSourceNotifier.dart';
import '../../service/AccountSwitchService.dart';

class UserPlayDataManager {
  // 单例模式
  static final UserPlayDataManager _instance = UserPlayDataManager._internal();
  factory UserPlayDataManager() => _instance;
  UserPlayDataManager._internal();

  // 缓存时间戳键
  static const String _lastUpdateKey = 'user_play_data_last_update';

  // API 地址
  static const String _apiUrl = ApiUrls.UserPlayDataApi;

  // 从 API 获取用户游玩数据（经后端 OAuth 代理，后端自动换票并代理水鱼 /player/records）
  Future<Map<String, dynamic>?> fetchUserPlayData(
    String qq,
  ) async {
    try {
      // 构建 API URL
      final url = Uri.parse('$_apiUrl?qq=$qq');

      // 发送 GET 请求（ApiClient 会自动附加 x-prober-key 头）
      final response = await ApiClient.get(url);

      if (response.statusCode == 200) {
        // 水鱼 /player/records 的返回结构不固定：可能是直接数组，也可能是
        // 代理包装的 { records, additional_rating } 或 { success, data: ... }。
        // 统一归一化为 { records: [...], additional_rating }，避免下游读到空 records。
        final dynamic decoded = json.decode(response.body);
        final data = _normalizeRecords(decoded);
        if (data == null) {
          if (decoded is Map<String, dynamic>) {
            debugPrint(
                '水鱼成绩接口返回未知结构: ${decoded['message'] ?? decoded['error'] ?? decoded['code'] ?? decoded}');
          } else {
            debugPrint('水鱼成绩接口返回未知结构: ${decoded.runtimeType}');
          }
          return null;
        }

        debugPrint('成功从 API 获取用户游玩数据');
        return data;
      } else {
        _throwOnProberError(response);
        debugPrint('API 请求失败，状态码: ${response.statusCode}');
        return null;
      }
    } on ProberException {
      rethrow;
    } catch (e) {
      debugPrint('获取用户游玩数据时出错: $e');
      return null;
    }
  }

  // 归一化水鱼 /player/records 返回结构，统一为 { records: [...], additional_rating }。
  // 支持的直接形态：
  //   List                          -> { records: list }
  //   { records: [...] }            -> 原样返回
  //   { additional_rating, records }-> 原样返回
  // 后端 chiffonmai.cloud 代理包装形态：
  //   { success, data: [...] }                     -> 解包 data 为 records
  //   { success, data: { records: [...], ... } }   -> 解包 data.records
  Map<String, dynamic>? _normalizeRecords(dynamic decoded) {
    if (decoded is List) {
      return {'records': decoded, 'additional_rating': 0};
    }
    if (decoded is Map<String, dynamic>) {
      // 已是 { records } 形态
      final records = decoded['records'];
      if (records is List) {
        final normalized = Map<String, dynamic>.from(decoded);
        normalized['records'] = records;
        return normalized;
      }
      // 代理包装 { success, data: ... }
      final data = decoded['data'];
      if (data is List) {
        return {
          'records': data,
          'additional_rating': decoded['additional_rating'] ?? 0,
        };
      }
      if (data is Map<String, dynamic>) {
        final innerRecords = data['records'];
        if (innerRecords is List) {
          final normalized = Map<String, dynamic>.from(data);
          if (decoded['additional_rating'] != null) {
            normalized['additional_rating'] = decoded['additional_rating'];
          }
          return normalized;
        }
      }
    }
    return null;
  }

  // 将后端 OAuth 代理的错误码转为可区分的异常
  void _throwOnProberError(http.Response response) {
    Map<String, dynamic> body = {};
    try {
      body = json.decode(response.body) as Map<String, dynamic>;
    } catch (_) {}

    final code = (body['code'] ?? '').toString();
    switch (response.statusCode) {
      case 401:
        if (code == 'CONSENT_REQUIRED') throw ProberException.consentRequired();
        throw ProberException.unauthorized();
      case 403:
        throw ProberException.forbidden();
      case 429:
        throw ProberException.quotaExceeded();
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
      debugPrint('从缓存获取用户游玩数据时出错: $e');
      return null;
    }
  }

  /// 查询本身只返回数据；只有持有刷新事务的调用方才能提交自己的成绩。
  Future<void> storeFetchedData(
    Map<String, dynamic> data, {
    required RefreshDataSource source,
    required String accountId,
  }) async {
    AccountSwitchService.requireRefresh(source);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(CacheKeyConstant.userPlayData, json.encode(data));
    final updateKey = source == RefreshDataSource.awmc
        ? 'awmc_net_user_play_data_last_update'
        : _lastUpdateKey;
    await prefs.setInt(updateKey, DateTime.now().millisecondsSinceEpoch);
    await prefs.remove(CacheKeyConstant.recommendationResults);
    final historyFuture = ChartHistoryStore.instance.recordChartSnapshot(data,
        sourceKey: source.key, accountId: accountId, reason: 'refresh');
    unawaited(historyFuture);
  }

  // 获取最后更新时间
  Future<int?> getLastUpdateTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_lastUpdateKey);
    } catch (e) {
      debugPrint('获取最后更新时间时出错: $e');
      return null;
    }
  }
}
