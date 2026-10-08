import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../api/ApiUrls.dart';
import '../../utils/ApiClient.dart';

enum SpecialRankingType {
  breakCount, // 绝赞总数排行榜（谱面）
}

class SpecialRankingEntry {
  final int rank;
  final String songId;
  final String songTitle;
  final String songType; // ST/DX/UTAGE
  final int difficultyIndex;
  final String difficultyLabel;
  final double ds;
  final int breakCount;
  final int updateTime;

  SpecialRankingEntry({
    required this.rank,
    required this.songId,
    required this.songTitle,
    required this.songType,
    required this.difficultyIndex,
    required this.difficultyLabel,
    required this.ds,
    required this.breakCount,
    required this.updateTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'rank': rank,
      'songId': songId,
      'songTitle': songTitle,
      'songType': songType,
      'difficultyIndex': difficultyIndex,
      'difficultyLabel': difficultyLabel,
      'ds': ds,
      'breakCount': breakCount,
      'updateTime': updateTime,
    };
  }
}

/// 手机只调用 HTTP API；MySQL 持久化和 Redis 缓存均由服务端管理。
/// 手机只调用 HTTP API；MySQL 持久化和 Redis 缓存均由服务端管理。
class SpecialRankingListService {
  static final _instance = SpecialRankingListService._();
  factory SpecialRankingListService() => _instance;
  SpecialRankingListService._();
  bool lastReadWasCached = false;
  /// 手动刷新时让下一次请求绕过服务端 Redis 的短期 HTTP 响应缓存。
  bool forceRefreshNextRead = false;

  Future<List<SpecialRankingEntry>> _get(
    String type, {
    int limit = 100,
    bool reverse = false,
    Function(int)? onProgress,
  }) async {
    final cacheKey = 'special_http_v1_${type}_${reverse}_$limit';
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> payload;
    onProgress?.call(0);
    final forceRefresh = forceRefreshNextRead;
    forceRefreshNextRead = false;
    try {
      final query = <String, String>{
        'type': type,
        'reverse': '$reverse',
        'limit': '$limit',
        if (forceRefresh) 'refresh': 'true',
      };
      final uri =
          Uri.parse(ApiUrls.SpecialRankingsUrl).replace(queryParameters: query);
      final response =
          await ApiClient.get(uri, timeout: const Duration(seconds: 45));
      if (response.statusCode != 200) {
        throw Exception('排行榜服务暂不可用（${response.statusCode}）');
      }
      payload =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (payload['success'] != true || payload['data'] is! List) {
        throw const FormatException('排行榜响应格式无效');
      }
      lastReadWasCached = payload['stale'] == true;
      await prefs.setString(cacheKey, jsonEncode(payload));
    } catch (_) {
      final cached = prefs.getString(cacheKey);
      if (cached == null) rethrow;
      payload = jsonDecode(cached) as Map<String, dynamic>;
      lastReadWasCached = true;
    }
    final entries = (payload['data'] as List).map((raw) {
      final item = Map<String, dynamic>.from(raw as Map);
      return SpecialRankingEntry(
          rank: (item['rank'] as num).toInt(),
          songId: item['songId'].toString(),
          songTitle: item['songTitle'] as String,
          songType: item['songType'] as String,
          difficultyIndex: (item['difficultyIndex'] as num).toInt(),
          difficultyLabel: item['difficultyLabel'] as String,
          ds: (item['ds'] as num).toDouble(),
          breakCount: (item['breakCount'] as num).toInt(),
          updateTime: (item['updateTime'] as num).toInt());
    }).toList();
    onProgress?.call(100);
    return entries;
  }

  Future<List<SpecialRankingEntry>> getBreakCountRanking(
          {int limit = 100, bool ascending = false}) =>
      _get('breakCount', limit: limit, reverse: ascending);
  Future<List<SpecialRankingEntry>> getReverseBreakCountRanking(
          {int limit = 100}) =>
      _get('breakCount', limit: limit, reverse: true);
  Future<List<SpecialRankingEntry>> getDifficultyDiffRanking(
          {int limit = 100, Function(int)? onProgress}) =>
      _get('difficultyDiff',
          limit: limit, reverse: false, onProgress: onProgress);
  Future<List<SpecialRankingEntry>> getReverseDifficultyDiffRanking(
          {int limit = 100, Function(int)? onProgress}) =>
      _get('difficultyDiff',
          limit: limit, reverse: true, onProgress: onProgress);
  Future<List<SpecialRankingEntry>> getMasterDifficultyDiffRanking(
          {int limit = 100, Function(int)? onProgress}) =>
      _get('masterDiff', limit: limit, reverse: false, onProgress: onProgress);
  Future<List<SpecialRankingEntry>> getReverseMasterDifficultyDiffRanking(
          {int limit = 100, Function(int)? onProgress}) =>
      _get('masterDiff', limit: limit, reverse: true, onProgress: onProgress);
  Future<List<SpecialRankingEntry>> getExpertDifficultyDiffRanking(
          {int limit = 100, Function(int)? onProgress}) =>
      _get('expertDiff', limit: limit, reverse: false, onProgress: onProgress);
  Future<List<SpecialRankingEntry>> getReverseExpertDifficultyDiffRanking(
          {int limit = 100, Function(int)? onProgress}) =>
      _get('expertDiff', limit: limit, reverse: true, onProgress: onProgress);
  Future<List<SpecialRankingEntry>> getSampleCountRanking(
          {int limit = 100, Function(int)? onProgress}) =>
      _get('sampleCount', limit: limit, reverse: false, onProgress: onProgress);
  Future<List<SpecialRankingEntry>> getReverseSampleCountRanking(
          {int limit = 100, Function(int)? onProgress}) =>
      _get('sampleCount', limit: limit, reverse: true, onProgress: onProgress);
  Future<List<SpecialRankingEntry>> getNoteCountRanking(
          {int limit = 100, Function(int)? onProgress}) =>
      _get('noteCount', limit: limit, reverse: false, onProgress: onProgress);
  Future<List<SpecialRankingEntry>> getReverseNoteCountRanking(
          {int limit = 100, Function(int)? onProgress}) =>
      _get('noteCount', limit: limit, reverse: true, onProgress: onProgress);
  Future<List<SpecialRankingEntry>> getAvgAchievementRanking(
          {int limit = 100, Function(int)? onProgress}) =>
      _get('avgAchievement',
          limit: limit, reverse: false, onProgress: onProgress);
  Future<List<SpecialRankingEntry>> getReverseAvgAchievementRanking(
          {int limit = 100, Function(int)? onProgress}) =>
      _get('avgAchievement',
          limit: limit, reverse: true, onProgress: onProgress);
  Future<List<SpecialRankingEntry>> getMasterAvgAchievementRanking(
          {int limit = 100, Function(int)? onProgress}) =>
      _get('masterAvgAchievement',
          limit: limit, reverse: false, onProgress: onProgress);
  Future<List<SpecialRankingEntry>> getReverseMasterAvgAchievementRanking(
          {int limit = 100, Function(int)? onProgress}) =>
      _get('masterAvgAchievement',
          limit: limit, reverse: true, onProgress: onProgress);
  Future<List<SpecialRankingEntry>> getExpertAvgAchievementRanking(
          {int limit = 100, Function(int)? onProgress}) =>
      _get('expertAvgAchievement',
          limit: limit, reverse: false, onProgress: onProgress);
  Future<List<SpecialRankingEntry>> getReverseExpertAvgAchievementRanking(
          {int limit = 100, Function(int)? onProgress}) =>
      _get('expertAvgAchievement',
          limit: limit, reverse: true, onProgress: onProgress);
  Future<List<SpecialRankingEntry>> getBpmRanking(
          {int limit = 100, Function(int)? onProgress}) =>
      _get('bpmRanking', limit: limit, reverse: false, onProgress: onProgress);
  Future<List<SpecialRankingEntry>> getReverseBpmRanking(
          {int limit = 100, Function(int)? onProgress}) =>
      _get('bpmRanking', limit: limit, reverse: true, onProgress: onProgress);

  /// 保留旧调用签名，重新计算改为由后端按快照时效统一执行。
  Future<void> recalculateBreakCountRanking({Function(int)? onProgress}) async {
    await _get('breakCount', onProgress: onProgress);
  }

  Future<void> updateAllSongBreakCounts({Function(int)? onProgress}) =>
      recalculateBreakCountRanking(onProgress: onProgress);
}
