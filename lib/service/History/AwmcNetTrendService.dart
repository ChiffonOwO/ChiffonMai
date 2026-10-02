/*
 * AWMC NET「玩家 Rating 趋势」API 客户端。
 *
 * 端点：`GET https://net.wmc.pub/api/player/{qqid}/trend?days={1..365}`（默认 30）。
 * **公开端点，无需鉴权** —— 实测 QQ = 488581724 返回 200 + 完整 JSON。
 *
 * 响应形如：
 * ```
 * {
 *   "qq": 488581724,
 *   "nickname": "...",
 *   "days": 30,
 *   "points": [
 *     { "date": "2026-09-24", "source": "qr", "rating": 15610,
 *       "delta": 0, "old_rating": 10974, "new_rating": 4636,
 *       "record_count": 1690, "imported": 9, "updated": 1106 }
 *   ],
 *   "summary": {
 *     "days_with_data": 1, "start_rating": 15610, "end_rating": 15610,
 *     "rating_delta": 0, "min_rating": 15610, "max_rating": 15610,
 *     "total_imported": 9, "total_updated": 1106
 *   }
 * }
 * ```
 *
 * ⚠️ **响应头坑**：服务端只回 `Content-Type: application/json`、**没有** charset，
 * 默认走 latin1 解码会得到乱码「ï¼£ï½ï½‰ï¼¦ï¼¦ï½ï½®」（C++ / 旧 FastAPI 实现的常见 bug）。
 * 这里**显式按 UTF-8 解码 bodyBytes**绕开。
 *
 * ⚠️ **`date` 是 `YYYY-MM-DD` 不带时区**：按**本地零点**处理，与 App 其他历史曲线
 * 同口径（见 `historySecond` / `appendRatingPoint` 的整秒对齐逻辑）。
 */
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../api/ApiUrls.dart';
import '../../utils/ApiClient.dart';

/// 每日一条趋势点。`tMs` 是按本地 0 点对齐后的整秒时间戳。
class AwmcNetTrendPoint {
  const AwmcNetTrendPoint({
    required this.tMs,
    required this.rating,
    required this.delta,
    required this.source,
    required this.oldRating,
    required this.newRating,
    required this.recordCount,
  });

  final int tMs;
  final int rating;
  final int delta;
  final String source;
  final int oldRating;
  final int newRating;
  final int recordCount;
}

/// 接口完整响应。`summary` 是服务端算好的窗口内总览，**不参与本地存盘**。
class AwmcNetTrendResult {
  const AwmcNetTrendResult({
    required this.qq,
    required this.nickname,
    required this.days,
    required this.points,
    required this.summary,
  });

  final int qq;
  final String nickname;
  final int days;
  final List<AwmcNetTrendPoint> points;
  final Map<String, dynamic> summary;
}

class AwmcNetTrendException implements Exception {
  AwmcNetTrendException(this.message);
  final String message;
  @override
  String toString() => 'AwmcNetTrendException: $message';
}

/// 公开拉一次玩家趋势。失败转成 [AwmcNetTrendException] 抛出，方便 UI 收口。
///
/// [qqid] 服务端要 5~12 位数字（与 `/dev/player/records` 同口径）。
/// [days] 默认 90 天；上限 365，超出会被服务端 422。
Future<AwmcNetTrendResult> fetchAwmcNetTrend({
  required String qqid,
  int days = 90,
  Duration timeout = const Duration(seconds: 15),
}) async {
  final id = qqid.trim();
  if (!RegExp(r'^\d{5,12}$').hasMatch(id)) {
    throw AwmcNetTrendException('QQ 号格式不对（应为 5–12 位数字）：$id');
  }

  final url = Uri.parse(
    ApiUrls.awmcPlayerTrendUrl(id, days: days),
  );
  // 出口固定校验：和 [AwmcNetUserPlayDataManager] 同样的「绝不把请求发到别的域名」保险。
  if (url.host != Uri.parse(ApiUrls.AwmcNetTrendBaseUrl).host) {
    throw AwmcNetTrendException('拒绝请求非 AWMC NET 地址：${url.host}');
  }

  final http.Response response;
  try {
    response = await ApiClient.get(url, timeout: timeout);
  } on Exception catch (e) {
    throw AwmcNetTrendException('AWMC NET 连接失败：$e');
  }

  if (response.statusCode == 404) {
    throw AwmcNetTrendException('AWMC NET 没有 QQ $id 的数据（请确认该 QQ 已在 net.wmc.pub 绑定并上传过成绩）');
  }
  if (response.statusCode == 422) {
    throw AwmcNetTrendException('AWMC NET 拒绝了请求：days 参数超出范围（1~365）');
  }
  if (response.statusCode != 200) {
    throw AwmcNetTrendException('AWMC NET 返回了 HTTP ${response.statusCode}');
  }

  final Map<String, dynamic> body;
  try {
    // ⚠️ 见文件头注释：服务端 Content-Type 不带 charset，必须显式 UTF-8 解码。
    body = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  } on Exception catch (e) {
    throw AwmcNetTrendException('AWMC NET 返回了无法解析的 JSON：$e');
  }

  final pointsRaw = body['points'];
  if (pointsRaw is! List) {
    throw AwmcNetTrendException('AWMC NET 返回结构里没有 points 数组');
  }
  final points = <AwmcNetTrendPoint>[];
  for (final item in pointsRaw) {
    if (item is! Map) continue;
    final date = item['date'];
    if (date is! String) continue;
    final tMs = _parseLocalDate(date);
    if (tMs == null) continue;
    final rating = _asInt(item['rating']);
    if (rating == null || rating <= 0) continue;
    points.add(AwmcNetTrendPoint(
      tMs: tMs,
      rating: rating,
      delta: _asInt(item['delta']) ?? 0,
      source: (item['source'] ?? '').toString(),
      oldRating: _asInt(item['old_rating']) ?? 0,
      newRating: _asInt(item['new_rating']) ?? 0,
      recordCount: _asInt(item['record_count']) ?? 0,
    ));
  }
  // 服务端不一定按日期升序排，安全起见排一下。
  points.sort((a, b) => a.tMs.compareTo(b.tMs));

  final summaryRaw = body['summary'];
  final summary = summaryRaw is Map<String, dynamic>
      ? Map<String, dynamic>.from(summaryRaw)
      : <String, dynamic>{};

  return AwmcNetTrendResult(
    qq: _asInt(body['qq']) ?? int.tryParse(id) ?? 0,
    nickname: (body['nickname'] ?? '').toString(),
    days: _asInt(body['days']) ?? days,
    points: points,
    summary: summary,
  );
}

int? _parseLocalDate(String date) {
  // "YYYY-MM-DD" → 本地 0 点。
  final m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(date);
  if (m == null) return null;
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  final dt = DateTime(y, mo, d); // local
  return dt.millisecondsSinceEpoch;
}

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString().trim());
}
