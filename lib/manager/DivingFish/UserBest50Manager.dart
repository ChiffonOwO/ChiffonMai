import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_first_flutter_app/entity/DivingFish/UserBest50Entity.dart';
import 'package:my_first_flutter_app/entity/DivingFish/RecordItem.dart';
import 'UserPlayDataManager.dart';
import 'MaimaiMusicDataManager.dart';

class UserBest50Manager {
  static final UserBest50Manager _instance = UserBest50Manager._internal();
  factory UserBest50Manager() => _instance;
  UserBest50Manager._internal();

  Future<UserBest50Entity> getUserBest50(
    String qq, {
    Map<String, dynamic>? playData,
  }) async {
    try {
      // OAuth 用户由 access token 决定，不能再调用按 QQ 查询的旧接口。
      final resolvedPlayData =
          playData ?? await UserPlayDataManager().fetchUserPlayData(qq);
      if (resolvedPlayData == null || resolvedPlayData['records'] is! List) {
        throw Exception('水鱼成绩接口未返回 records');
      }
      final songs = await MaimaiMusicDataManager().getCachedSongs();
      if (songs == null || songs.isEmpty) {
        throw Exception('缺少歌曲数据，无法区分当前版本歌曲');
      }
      final isNewById = <String, bool>{
        for (final song in songs) song.id: song.basicInfo.isNew,
      };
      final records = (resolvedPlayData['records'] as List)
          .whereType<Map<String, dynamic>>()
          .map(RecordItem.fromJson)
          .toList()
        ..sort((a, b) => b.ra.compareTo(a.ra));
      final oldRecords = records
          .where((r) => !(isNewById[r.songId.toString()] ?? false))
          .take(35)
          .toList();
      final newRecords = records
          .where((r) => isNewById[r.songId.toString()] ?? false)
          .take(15)
          .toList();
      final rating = [...oldRecords, ...newRecords]
          .fold<int>(0, (sum, record) => sum + record.ra);
      final jsonData = <String, dynamic>{
        'rating': rating,
        'additional_rating':
            (resolvedPlayData['additional_rating'] as num?)?.toInt() ?? 0,
        'charts': {
          'sd': oldRecords.map((r) => r.toJson()).toList(),
          'dx': newRecords.map((r) => r.toJson()).toList(),
        },
      };
      await _cacheBest50Data(qq, jsonData);
      return _parseBest50Data(jsonData);
    } catch (e) {
      debugPrint('Error fetching best50 data: $e');
      rethrow;
    }
  }

  Future<void> _cacheBest50Data(String qq, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('best50_data_$qq', json.encode(data));
      await prefs.setString('last_used_qq', qq);
    } catch (e) {
      debugPrint('Error caching best50 data: $e');
    }
  }

  Future<Map<String, dynamic>?> getCachedBest50Data() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastQQ = prefs.getString('last_used_qq');
      if (lastQQ == null) return null;
      final cachedData = prefs.getString('best50_data_$lastQQ');
      return cachedData == null
          ? null
          : json.decode(cachedData) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error getting cached best50 data: $e');
      return null;
    }
  }

  UserBest50Entity _parseBest50Data(Map<String, dynamic> jsonData) {
    final charts = jsonData['charts'] as Map<String, dynamic>? ?? {};
    return UserBest50Entity(
      additionalRating: (jsonData['additional_rating'] as num?)?.toInt() ?? 0,
      charts: Charts(
        dx: _parseRecordItems(charts['dx'] as List<dynamic>? ?? const []),
        sd: _parseRecordItems(charts['sd'] as List<dynamic>? ?? const []),
      ),
    );
  }

  List<RecordItem> _parseRecordItems(List<dynamic> records) => records
      .whereType<Map<String, dynamic>>()
      .map(RecordItem.fromJson)
      .toList();
}
