import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:my_first_flutter_app/api/ApiUrls.dart';

/// B站播放量 Redis 缓存服务
///
/// 负责将 B站播放量数据保存到远程 Redis 服务器，
/// 以及从 Redis 加载缓存的播放量数据。
/// 同时支持用户自定义上传 BV 号。
class BiliRedisService {
  static final BiliRedisService _instance = BiliRedisService._internal();
  factory BiliRedisService() => _instance;
  BiliRedisService._internal();

  static const _kTag = '[BiliRedis]';

  void _log(String msg) {
    debugPrint('$_kTag $msg');
  }

  // ============================================================
  // 保存播放量到 Redis
  // ============================================================

  /// 将 B站播放量保存到远程 Redis 服务器
  ///
  /// [songId] 歌曲ID
  /// [songTitle] 歌曲标题
  /// [diffIndex] 难度索引 (0=Basic, 1=Advanced, 2=Expert, 3=Master, 4=Re:Master)
  /// [playCount] 播放量
  /// [bvid] 可选的 BV 号（如果已知）
  ///
  /// 返回 true 表示保存成功，false 表示失败
  Future<bool> savePlayCount({
    required String songId,
    required String songTitle,
    required int diffIndex,
    required int playCount,
    String? bvid,
  }) async {
    try {
      _log('保存播放量: songId=$songId, diffIndex=$diffIndex, playCount=$playCount, bvid=$bvid');

      final response = await http
          .post(
            Uri.parse(ApiUrls.BiliRedisSaveUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'song_id': songId,
              'song_title': songTitle,
              'diff_index': diffIndex,
              'play_count': playCount,
              if (bvid != null) 'bvid': bvid,
              'source': 'auto_fetch',
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _log('播放量保存成功');
        return true;
      }
      _log('保存播放量失败: HTTP ${response.statusCode}');
      return false;
    } catch (e) {
      _log('保存播放量异常: $e');
      return false;
    }
  }

  // ============================================================
  // 从 Redis 获取缓存的播放量
  // ============================================================

  /// 从远程 Redis 获取缓存的播放量
  ///
  /// 返回 Map 包含 playCount, bvid, updatedAt 等信息，无缓存返回 null
  Future<Map<String, dynamic>?> getCachedPlayCount({
    required String songId,
    required int diffIndex,
  }) async {
    try {
      _log('获取缓存播放量: songId=$songId, diffIndex=$diffIndex');

      final response = await http
          .get(
            Uri.parse(
              '${ApiUrls.BiliRedisGetUrl}?song_id=$songId&diff_index=$diffIndex',
            ),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['found'] == true) {
          _log('缓存命中: playCount=${data['play_count']}, bvid=${data['bvid']}');
          return data;
        }
      }
      _log('缓存未命中: HTTP ${response.statusCode}');
      return null;
    } catch (e) {
      _log('获取缓存播放量异常: $e');
      return null;
    }
  }

  // ============================================================
  // 用户自定义上传 BV 号
  // ============================================================

  /// 用户上传自定义 BV 号
  ///
  /// [songId] 歌曲ID
  /// [songTitle] 歌曲标题（用于服务端记录）
  /// [diffIndex] 难度索引
  /// [bvid] 用户提供的 BV 号
  /// [playCount] 从 B站获取到的播放量（可选）
  ///
  /// 返回 true 表示上传成功
  Future<bool> uploadUserBv({
    required String songId,
    required String songTitle,
    required int diffIndex,
    required String bvid,
    int? playCount,
  }) async {
    try {
      _log('上传用户 BV: songId=$songId, diffIndex=$diffIndex, bvid=$bvid, playCount=$playCount');

      final response = await http
          .post(
            Uri.parse(ApiUrls.BiliRedisUploadBvUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'song_id': songId,
              'song_title': songTitle,
              'diff_index': diffIndex,
              'bvid': bvid,
              if (playCount != null) 'play_count': playCount,
              'source': 'user_upload',
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _log('用户 BV 上传成功');
        return true;
      }
      _log('用户 BV 上传失败: HTTP ${response.statusCode}');
      return false;
    } catch (e) {
      _log('用户 BV 上传异常: $e');
      return false;
    }
  }

  // ============================================================
  // 参考时长 Redis 缓存
  // ============================================================

  /// 从远程 Redis 获取缓存的参考时长（秒）
  ///
  /// 返回秒数，无缓存返回 null
  Future<int?> getCachedReferenceDuration({
    required String songId,
  }) async {
    try {
      _log('获取参考时长缓存: songId=$songId');

      final response = await http
          .get(
            Uri.parse('${ApiUrls.RefDurationGetUrl}?song_id=$songId'),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['found'] == true && data['duration_seconds'] != null) {
          final duration = data['duration_seconds'] as int;
          _log('参考时长缓存命中: ${duration}s');
          return duration;
        }
      }
      _log('参考时长缓存未命中');
      return null;
    } catch (e) {
      _log('获取参考时长缓存异常: $e');
      return null;
    }
  }

  /// 保存参考时长到远程 Redis（30天过期）
  Future<bool> saveReferenceDuration({
    required String songId,
    required String songTitle,
    required int durationSeconds,
  }) async {
    try {
      _log('保存参考时长: songId=$songId, duration=${durationSeconds}s');

      final response = await http
          .post(
            Uri.parse(ApiUrls.RefDurationSaveUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'song_id': songId,
              'song_title': songTitle,
              'duration_seconds': durationSeconds,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _log('参考时长保存成功');
        return true;
      }
      _log('参考时长保存失败: HTTP ${response.statusCode}');
      return false;
    } catch (e) {
      _log('参考时长保存异常: $e');
      return false;
    }
  }
}
