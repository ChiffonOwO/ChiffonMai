import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../api/ApiUrls.dart';
import '../../constant/CacheKeyConstant.dart';
import '../../constant/CacheTimestampConstant.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_first_flutter_app/utils/ApiClient.dart';
import 'SongRankingService.dart' show parseDataSource;

/// 拟合总Rating排行榜的模式（对应服务端 fitted-ranking 的 mode 参数）
enum FittedMode {
  a('A'),
  b('B'),
  c('C');

  final String label;

  const FittedMode(this.label);
}

/// 单个玩家在拟合总Rating排行榜中的条目
class FittedRankItem {
  int rank;
  final String playerId;
  final String playerName;
  final String dataSource;
  final String mode;
  final int fittedRating;
  final int officialRating;
  final int diff;
  final int updateTime;

  FittedRankItem({
    this.rank = 0,
    required this.playerId,
    required this.playerName,
    required this.dataSource,
    required this.mode,
    required this.fittedRating,
    required this.officialRating,
    required this.diff,
    this.updateTime = 0,
  });

  factory FittedRankItem.fromJson(Map<String, dynamic> json) {
    final playerId = (json['playerId'] ?? json['player_id'] ?? '').toString();
    final dataSource = (json['dataSource'] ?? json['data_source'] ?? '')
        .toString()
        .isNotEmpty
        ? (json['dataSource'] ?? json['data_source'] ?? '').toString()
        : _parseDataSource(playerId);
    return FittedRankItem(
      rank: _toInt(json['rank'] ?? 0),
      playerId: playerId,
      playerName: (json['playerName'] ?? json['player_name'] ?? '').toString(),
      dataSource: dataSource,
      mode: (json['mode'] ?? '').toString(),
      fittedRating: _toInt(json['fittedRating'] ?? json['fitted_rating'] ?? 0),
      officialRating:
          _toInt(json['officialRating'] ?? json['official_rating'] ?? 0),
      diff: _toInt(json['diff'] ?? 0),
      updateTime: _toInt(json['updateTime'] ?? json['update_time'] ?? 0),
    );
  }

  /// 数值安全转换：int 直接用；num 取整；字符串（如 ISO 时间）尝试解析，失败归 0
  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'rank': rank,
      'playerId': playerId,
      'playerName': playerName,
      'dataSource': dataSource,
      'mode': mode,
      'fittedRating': fittedRating,
      'officialRating': officialRating,
      'diff': diff,
      'updateTime': updateTime,
    };
  }
}

/// 根据 playerId 前缀推断数据源。
///
/// 复用 [SongRankingService] 里那份唯一的实现（原因见 AvgRankingListService 的同名注释）。
String _parseDataSource(String playerId) => parseDataSource(playerId);

class FittedRatingRankingListService {
  // 缓存有效期：从常量文件读取（分钟转秒）
  static int get _cacheExpirySeconds =>
      CacheTimestampConstant.rankingsCacheMinutes * 60;

  /// 测试专用：把排行榜请求打桩掉（见 [getRankings] 里的用法）。真机永远是 null。
  @visibleForTesting
  static Future<List<FittedRankItem>> Function()? debugRankingsLoader;

  // 按模式拼接缓存 key
  static String _cacheKey(String mode) =>
      '${CacheKeyConstant.fittedRankingsCachePrefix}$mode';
  static String _timestampKey(String mode) =>
      '${CacheKeyConstant.fittedRankingsCacheTimestampPrefix}$mode';

  // 获取指定模式的排行榜数据（原始、未排序）
  static Future<List<FittedRankItem>> getRankings({
    required FittedMode mode,
    bool refresh = false,
    String? userId,
  }) async {
    if (!refresh) {
      final cachedData = await _getCachedRankings(mode);
      if (cachedData != null && cachedData.isNotEmpty) {
        return cachedData;
      }
    }

    // 测试专用打桩：这几个排行榜接口都不读缓存（rankingsCacheMinutes = -1），
    // widget 测试里不打桩页面永远停在空状态，几何/间距问题就量不出来。
    // 真机（debug/release）永远是 null。
    final stub = debugRankingsLoader;
    if (stub != null) return stub();

    try {
      var url = Uri.parse(
          '${ApiUrls.SongRankingsFittedUrl}?mode=${mode.name}&refresh=$refresh');
      if (userId != null && userId.isNotEmpty) {
        url = Uri.parse(
            '${ApiUrls.SongRankingsFittedUrl}?mode=${mode.name}&refresh=$refresh&userId=$userId');
      }
      final response = await ApiClient.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          final items = (result['data'] as List<dynamic>)
              .map((e) => FittedRankItem.fromJson(e as Map<String, dynamic>))
              .toList();
          await _cacheRankings(mode, items);
          return items;
        }
      }
      debugPrint(
          '获取拟合总Rating排行榜失败: HTTP ${response.statusCode}: ${response.body}');
    } catch (e) {
      debugPrint('获取拟合总Rating排行榜失败: $e');
    }
    return [];
  }

  // 获取当前用户在完整榜单中的条目（可能不在前100，由服务端返回）
  static Future<FittedRankItem?> getCurrentUserRank({
    required FittedMode mode,
    required String userId,
  }) async {
    try {
      final url = Uri.parse(
          '${ApiUrls.SongRankingsFittedUrl}?mode=${mode.name}&refresh=false&userId=$userId');
      final response = await ApiClient.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true && result['currentUser'] != null) {
          return FittedRankItem.fromJson(
              result['currentUser'] as Map<String, dynamic>);
        }
      }
    } catch (e) {
      debugPrint('获取当前用户拟合排行失败: $e');
    }
    return null;
  }

  // 按 fittedRating 排序并分配排名（并列名次，1,1,3,3,5 风格）
  static List<FittedRankItem> calculateRankedPositions(
    List<FittedRankItem> items,
  ) {
    if (items.isEmpty) return items;

    final sortedItems = List<FittedRankItem>.from(items)
      ..sort((a, b) => b.fittedRating.compareTo(a.fittedRating));

    for (int i = 0; i < sortedItems.length; i++) {
      if (i == 0) {
        sortedItems[i].rank = 1;
      } else {
        if (sortedItems[i].fittedRating == sortedItems[i - 1].fittedRating) {
          sortedItems[i].rank = sortedItems[i - 1].rank;
        } else {
          sortedItems[i].rank = i + 1;
        }
      }
    }

    return sortedItems;
  }

  // 从缓存读取排行榜数据
  static Future<List<FittedRankItem>?> _getCachedRankings(FittedMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_timestampKey(mode.name));

    if (timestamp != null) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (now - timestamp < _cacheExpirySeconds) {
        final cachedJson = prefs.getString(_cacheKey(mode.name));
        if (cachedJson != null) {
          try {
            final List<dynamic> data = json.decode(cachedJson);
            return data
                .map((e) => FittedRankItem.fromJson(e as Map<String, dynamic>))
                .toList();
          } catch (e) {
            debugPrint('解析缓存的拟合总Rating排行数据失败: $e');
          }
        }
      }
    }
    return null;
  }

  // 保存排行榜数据到缓存
  static Future<void> _cacheRankings(
      FittedMode mode, List<FittedRankItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final jsonString =
          json.encode(items.map((item) => item.toJson()).toList());
      await prefs.setString(_cacheKey(mode.name), jsonString);
      await prefs.setInt(
        _timestampKey(mode.name),
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
    } catch (e) {
      debugPrint('保存拟合总Rating排行缓存失败: $e');
    }
  }

  // 清除拟合计分排行缓存（用于强制刷新）
  static Future<void> clearRankingsCache() async {
    final prefs = await SharedPreferences.getInstance();
    for (final mode in FittedMode.values) {
      await prefs.remove(_cacheKey(mode.name));
      await prefs.remove(_timestampKey(mode.name));
    }
  }
}
