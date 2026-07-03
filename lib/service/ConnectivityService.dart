import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 网络连接监听服务（单例）
/// 包装 internet_connection_checker，提供连接状态监听和缓存年龄查询
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final InternetConnectionChecker _checker = InternetConnectionChecker();

  /// 当前是否在线
  final ValueNotifier<bool> isOnline = ValueNotifier(true);

  /// 连接状态变化流
  StreamSubscription<InternetConnectionStatus>? _subscription;

  /// 缓存时间戳键映射：功能名称 → 对应的 CacheTimestampConstant 键
  /// 用于查询缓存年龄
  static const Map<String, String> _cacheTimestampKeys = {
    'musicData': 'maidata_full_cache_timestamp',
    'diffData': 'diff_music_data_last_update',
    'userData': 'user_play_data_timestamp',
    'knowledgeData': 'knowledge_timestamp',
    'tagsData': 'mai_tags_cache_timestamp',
  };

  /// 需要网络连接的功能名称集合
  static const Set<String> onlineRequiredFeatures = {
    '刷新数据',
    '同步成绩',
    '登录水鱼',
    '登出账号',
    '服务器状态',
    '检查更新',
    '好友战绩对比',
    '排行榜(仅供参考)',
    '特殊排行榜',
  };

  /// 启动连接监听
  void start() {
    _subscription?.cancel();
    _subscription = _checker.onStatusChange.listen((status) {
      final online = status == InternetConnectionStatus.connected;
      if (isOnline.value != online) {
        debugPrint('🌐 网络状态变化: ${online ? "在线" : "离线"}');
        isOnline.value = online;
      }
    });
    // 初始检查
    _checkConnection();
  }

  /// 检查当前连接状态
  Future<void> _checkConnection() async {
    try {
      final hasConnection = await _checker.hasConnection;
      if (isOnline.value != hasConnection) {
        isOnline.value = hasConnection;
      }
    } catch (e) {
      debugPrint('检查连接状态出错: $e');
    }
  }

  /// 检查当前是否在线
  Future<bool> hasConnection() async {
    try {
      return await _checker.hasConnection;
    } catch (e) {
      debugPrint('检查连接状态出错: $e');
      return false;
    }
  }

  /// 获取指定数据的缓存年龄（距离上次更新的天数）
  /// 返回 null 表示无缓存或无法计算
  Future<int?> getCacheAgeDays(String cacheType) async {
    final timestampKey = _cacheTimestampKeys[cacheType];
    if (timestampKey == null) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(timestampKey);
      if (timestamp == null || timestamp == 0) return null;
      final ageMs = DateTime.now().millisecondsSinceEpoch - timestamp;
      return (ageMs / (1000 * 60 * 60 * 24)).round();
    } catch (e) {
      debugPrint('获取缓存年龄出错: $e');
      return null;
    }
  }

  /// 检查指定功能是否需要网络
  static bool isOnlineRequired(String featureTitle) {
    return onlineRequiredFeatures.contains(featureTitle);
  }

  /// 停止监听
  void dispose() {
    _subscription?.cancel();
  }
}
