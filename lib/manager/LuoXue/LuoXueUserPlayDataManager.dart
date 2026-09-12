import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './LuoXueOAuthManager.dart';
import '../../api/ApiUrls.dart';
import '../../entity/LuoXue/LuoXuePlayer.dart';
import '../../entity/LuoXue/LuoXueScore.dart';
import '../../entity/DivingFish/RecordItem.dart';
import '../../entity/DivingFish/Song.dart';
import '../../utils/LuoXueToDivingFishUtil.dart';
import '../../manager/DivingFish/MaimaiMusicDataManager.dart';
import '../../constant/CacheKeyConstant.dart';
import 'package:my_first_flutter_app/utils/ApiClient.dart';

/// 落雪用户游玩数据管理器
/// 使用OAuth鉴权访问落雪API
///
/// API基础URL: https://maimai.lxns.net/api/v0/
/// 授权范围: read_user_profile write_player read_player
class LuoXueUserPlayDataManager {
  static final LuoXueUserPlayDataManager _instance =
      LuoXueUserPlayDataManager._internal();

  factory LuoXueUserPlayDataManager() => _instance;

  LuoXueUserPlayDataManager._internal();

  final LuoXueOAuthManager _oauthManager = LuoXueOAuthManager();

  /// 获取玩家信息
  /// GET /api/v0/user/maimai/player
  Future<LuoXuePlayer?> getPlayerInfo() async {
    try {
      final headers = await _oauthManager.getAuthHeaders();
      final response = await ApiClient.get(
        Uri.parse(ApiUrls.LuoXuePlayerApi),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseBody = response.body;
        final preview = responseBody.length > 500
            ? responseBody.substring(0, 500) + '...'
            : responseBody;
        debugPrint('✅ 玩家信息API响应（前500字符）: $preview');

        final data = json.decode(responseBody);
        final playerData = data['data'] ?? data;
        return LuoXuePlayer.fromJson(playerData);
      } else {
        print('获取玩家信息失败: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('获取玩家信息异常: $e');
      return null;
    }
  }

  /// 获取玩家所有成绩（原始 LuoXueScore 列表）
  /// GET /api/v0/user/maimai/player/scores
  Future<List<LuoXueScore>?> getPlayerRecords() async {
    try {
      final headers = await _oauthManager.getAuthHeaders();
      final response = await ApiClient.get(
        Uri.parse(ApiUrls.LuoXuePlayerScoresApi),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseBody = response.body;
        final preview = responseBody.length > 500
            ? responseBody.substring(0, 500) + '...'
            : responseBody;
        debugPrint('✅ 玩家成绩API响应（前500字符）: $preview');

        final data = json.decode(responseBody);
        final scoresData = data['data'] ?? data;

        if (scoresData is List) {
          return scoresData.map((item) => LuoXueScore.fromJson(item)).toList();
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

  /// 获取玩家成绩并转换为 RecordItem 列表
  /// 同时更新所有用到 RecordItem 的缓存
  Future<List<RecordItem>?> getPlayerRecordsAsRecordItems({
    LuoXuePlayer? playerInfo,
    List<Song>? songs,
  }) async {
    try {
      final luoxueScores = await getPlayerRecords();
      if (luoxueScores == null || luoxueScores.isEmpty) {
        debugPrint('未获取到玩家成绩');
        return null;
      }

      final resolvedSongs =
          songs ?? await MaimaiMusicDataManager().getCachedSongs();
      final songByTitleAndType = <String, Song>{};
      for (final song in resolvedSongs ?? const <Song>[]) {
        songByTitleAndType['${song.basicInfo.title}|${song.type}'] = song;
      }

      final recordItems = <RecordItem>[];
      for (final score in luoxueScores) {
        final type = _getTypeLabel(score.type);
        recordItems.add(
          LuoXueToDivingFishUtil.toRecordItem(
            score,
            song: songByTitleAndType['${score.songName}|$type'],
          ),
        );
      }

      await _updateRecordItemCache(
        recordItems,
        nickname: playerInfo?.name ?? '',
      );
      return recordItems;
    } catch (e) {
      print('获取并转换玩家成绩异常: $e');
      return null;
    }
  }

  String _getTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'standard':
        return 'SD';
      case 'dx':
        return 'DX';
      case 'utage':
        return 'UTAGE';
      default:
        return type;
    }
  }

  /// 更新 RecordItem 相关缓存
  Future<void> _updateRecordItemCache(List<RecordItem> recordItems,
      {String nickname = ''}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 构建缓存数据结构（与水鱼数据源格式保持一致）
      Map<String, dynamic> cacheData = {
        'additional_rating': 0,
        'nickname': nickname,
        'plate': '',
        'rating': 0,
        'records': recordItems.map((item) => item.toJson()).toList(),
      };

      // 保存到 userPlayData 缓存
      await prefs.setString(
          CacheKeyConstant.userPlayData, json.encode(cacheData));
      debugPrint('✅ 已更新 RecordItem 缓存（共 ${recordItems.length} 条）');

      // 清除旧的 Best50 缓存，强制重新计算（重要！）
      final lastQQ = prefs.getString('last_used_qq');
      if (lastQQ != null) {
        await prefs.remove('best50_data_$lastQQ');
        debugPrint('✅ 已清除旧的 Best50 缓存');
      }
      await prefs.remove('last_used_qq');

      // 清除可能影响的其他缓存
      await prefs.remove(CacheKeyConstant.recommendationResults);
      debugPrint('✅ 已清除推荐结果缓存');
    } catch (e) {
      print('更新 RecordItem 缓存时出错: $e');
    }
  }

  /// 获取授权URL
  String getAuthorizationUrl() {
    return _oauthManager.getAuthorizationUrl();
  }

  /// 使用授权码获取令牌
  Future<bool> exchangeCodeForToken(String code) async {
    final result = await _oauthManager.exchangeCodeForToken(code);
    return result != null;
  }

  /// 检查是否已登录
  Future<bool> isLoggedIn() async {
    return _oauthManager.isLoggedIn();
  }

  /// 登出（清除本地令牌缓存和用户数据缓存）
  Future<void> logout() async {
    await _oauthManager.logout();

    // 清除用户数据缓存
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(CacheKeyConstant.userPlayData);
    await prefs.remove(CacheKeyConstant.lastDataSource);
    debugPrint('✅ 已清除用户数据缓存');
  }

  /// 获取当前访问令牌
  Future<String?> getAccessToken() async {
    return _oauthManager.getAccessToken();
  }
}
