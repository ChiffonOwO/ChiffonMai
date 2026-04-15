import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:my_first_flutter_app/api/ApiUrls.dart';
import 'package:my_first_flutter_app/entity/MaimaiServerStatusEntity.dart';
import 'package:my_first_flutter_app/entity/MaimaiServerStatusTitleEntity.dart';

// 服务器状态服务
class MaimaiServerStatusService {
  // 缓存相关
  static MaimaiServerStatusEntity? _cachedStatus;
  static DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(minutes: 5);
  
  // 服务器标题缓存
  static MaimaiServerStatusTitleEntity? _cachedTitleStatus;
  static DateTime? _lastTitleFetchTime;
  static const Duration _titleCacheDuration = Duration(days: 3);

  // 从API获取服务器状态数据
  static Future<MaimaiServerStatusEntity?> getServerStatus() async {
    try {
      // 检查缓存是否有效
      if (_cachedStatus != null && _lastFetchTime != null) {
        final timeSinceLastFetch = DateTime.now().difference(_lastFetchTime!);
        if (timeSinceLastFetch < _cacheDuration) {
          return _cachedStatus;
        }
      }

      // 从API获取数据
      final response = await http.get(Uri.parse(ApiUrls.ServerStatusApi));
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final status = MaimaiServerStatusEntity.fromJson(json);
        
        // 更新缓存
        _cachedStatus = status;
        _lastFetchTime = DateTime.now();
        
        return status;
      } else {
        print('获取服务器状态失败: ${response.statusCode}');
        // 如果API失败，返回缓存数据（如果有）
        return _cachedStatus;
      }
    } catch (e) {
      print('获取服务器状态异常: $e');
      // 如果网络异常，返回缓存数据（如果有）
      return _cachedStatus;
    }
  }

  // 获取服务器状态标题数据
  static Future<MaimaiServerStatusTitleEntity?> getServerStatusTitle() async {
    try {
      // 检查缓存是否有效
      if (_cachedTitleStatus != null && _lastTitleFetchTime != null) {
        final timeSinceLastFetch = DateTime.now().difference(_lastTitleFetchTime!);
        if (timeSinceLastFetch < _titleCacheDuration) {
          return _cachedTitleStatus;
        }
      }

      // 从API获取数据
      final response = await http.get(Uri.parse(ApiUrls.ServerStatusTitleApi));
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final titleStatus = MaimaiServerStatusTitleEntity.fromJson(json);
        
        // 更新缓存
        _cachedTitleStatus = titleStatus;
        _lastTitleFetchTime = DateTime.now();
        
        return titleStatus;
      } else {
        print('获取服务器状态标题失败: ${response.statusCode}');
        // 如果API失败，返回缓存数据（如果有）
        return _cachedTitleStatus;
      }
    } catch (e) {
      print('获取服务器状态标题异常: $e');
      // 如果网络异常，返回缓存数据（如果有）
      return _cachedTitleStatus;
    }
  }

  // 获取服务器ID到名称的映射
  static Future<Map<String, String>> getServerIdToNameMap() async {
    try {
      final titleStatus = await getServerStatusTitle();
      if (titleStatus == null) {
        return {};
      }
      return titleStatus.getServerIdToNameMap();
    } catch (e) {
      print('获取服务器ID到名称映射失败: $e');
      return {};
    }
  }

  // 获取服务器名称
  static Future<String> getServerName(String serverId) async {
    try {
      final map = await getServerIdToNameMap();
      return map[serverId] ?? '服务器 $serverId';
    } catch (e) {
      print('获取服务器名称失败: $e');
      return '服务器 $serverId';
    }
  }

  // 检查指定服务器是否在线
  static Future<bool> isServerOnline(String serverId) async {
    try {
      final status = await getServerStatus();
      if (status == null) {
        return false;
      }
      
      final latestHeartbeat = status.heartbeatList.getLatestHeartbeat(serverId);
      return latestHeartbeat?.status == 1;
    } catch (e) {
      print('检查服务器状态异常: $e');
      return false;
    }
  }

  // 获取所有服务器ID
  static Future<List<String>> getServerIds() async {
    try {
      final status = await getServerStatus();
      if (status == null) {
        return [];
      }
      return status.heartbeatList.getServerIds();
    } catch (e) {
      print('获取服务器ID列表失败: $e');
      return [];
    }
  }

  // 清除缓存
  static void clearCache() {
    _cachedStatus = null;
    _lastFetchTime = null;
    _cachedTitleStatus = null;
    _lastTitleFetchTime = null;
  }
}