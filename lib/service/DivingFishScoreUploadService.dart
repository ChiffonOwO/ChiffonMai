import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../api/ApiUrls.dart';
import '../utils/ApiClient.dart';

/// 把一条成绩同步到水鱼查分器。
///
/// 走批量端点 `/player/update_records`（请求体为 JSON List），
/// 而不是单曲端点 `/player/update_record` —— 后者内部对
/// `NewRecord.aio_get()` 的结果有 `assert r`，记录不存在时直接抛
/// AssertionError，只能改已有成绩、无法新增。批量端点同时处理
/// 新增与更新，并在响应里分别给出 `creates` / `updates` 计数。
///
/// 认证用 `Import-Token` 头：文档里该端点支持「登录验证 / Import-Token / Bearer」，
/// 而 Import-Token 是本 App 一直在缓存的东西（`getCachedDivingFishImportToken`），
/// 不需要额外的登录流程。
class DivingFishScoreUploadService {
  static final DivingFishScoreUploadService _instance =
      DivingFishScoreUploadService._internal();
  factory DivingFishScoreUploadService() => _instance;
  DivingFishScoreUploadService._internal();

  /// 上传一条成绩。
  ///
  /// [title] 与 [type] 用来让服务端反查歌曲（服务端按「标题 + 类型」匹配，
  /// 所以 type 必须是 `DX` 或 `SD`，写错会匹配不到歌）。
  /// [levelIndex] 必须是该歌曲**实际存在**的难度索引，越界会被服务端跳过
  /// —— 请求照样返回成功，但成绩没写进去，属于静默失败。
  ///
  /// 成功时返回服务端的统计信息。
  /// 失败时抛 [ScoreUploadException]，message 可直接展示给用户。
  Future<ScoreUploadResult> uploadRecord({
    required String importToken,
    required String title,
    required String type,
    required int levelIndex,
    required double achievement,
    String? fc,
    String? fs,
    int? dxScore,
  }) async {
    if (importToken.trim().isEmpty) {
      throw const ScoreUploadException('还没有水鱼 Import-Token，请先登录水鱼账号');
    }

    final normalizedType = type.toUpperCase() == 'DX' ? 'DX' : 'SD';
    final record = <String, dynamic>{
      'title': title,
      'type': normalizedType,
      'level_index': levelIndex,
      'achievements': achievement,
      // 空字符串会被服务端的 std_fc / std_fs 归一化成「无标记」，
      // 所以直接传空串比省略字段更明确。
      'fc': (fc ?? '').isEmpty ? '' : fc,
      'fs': (fs ?? '').isEmpty ? '' : fs,
      'dxScore': dxScore ?? 0,
    };

    final http.Response resp;
    try {
      resp = await ApiClient.post(
        Uri.parse(ApiUrls.DivingFishUpdateRecordsApi),
        headers: {
          'Import-Token': importToken,
          'Content-Type': 'application/json',
        },
        // 服务端读的是 JSON List
        body: jsonEncode([record]),
        timeout: const Duration(seconds: 20),
      );
    } catch (e) {
      throw ScoreUploadException('无法连接水鱼查分器：$e');
    }

    // 该端点的错误返回是 {status: 'error', message: '...'}，状态码可能非 200
    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is Map) body = Map<String, dynamic>.from(decoded);
    } catch (_) {
      // 非 JSON 响应，交给下面按状态码处理
    }

    if (resp.statusCode != 200) {
      final msg = body?['message']?.toString();
      if (resp.statusCode == 400) {
        throw ScoreUploadException(
            msg == null || msg.isEmpty ? '导入 Token 有误或请求格式不对' : msg);
      }
      if (resp.statusCode == 403) {
        throw ScoreUploadException(
            msg == null || msg.isEmpty ? '登录状态无效，请重新登录水鱼' : msg);
      }
      throw ScoreUploadException(
          '同步失败（HTTP ${resp.statusCode}）${msg == null ? '' : '：$msg'}');
    }

    // 成功路径：{message, updates, creates}
    final updates = (body?['updates'] as num?)?.toInt() ?? 0;
    final creates = (body?['creates'] as num?)?.toInt() ?? 0;
    debugPrint('DivingFishScoreUpload: updates=$updates creates=$creates');

    if (updates == 0 && creates == 0) {
      // 服务端对「歌曲匹配不到」和「level_index 越界」都是静默 continue，
      // 响应依然是成功。所以这里必须自己把它当失败报出来，否则用户会以为同步成功了。
      throw const ScoreUploadException(
          '水鱼没有接受这条成绩（歌曲没匹配上，或难度索引对该歌曲不存在），请检查曲名和难度');
    }

    return ScoreUploadResult(updates: updates, creates: creates);
  }
}

class ScoreUploadResult {
  final int updates;
  final int creates;

  const ScoreUploadResult({required this.updates, required this.creates});

  bool get isNew => creates > 0;
}

class ScoreUploadException implements Exception {
  final String message;
  const ScoreUploadException(this.message);
  @override
  String toString() => message;
}
