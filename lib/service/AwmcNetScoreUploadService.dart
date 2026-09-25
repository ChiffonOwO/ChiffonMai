import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../api/ApiUrls.dart';
import '../utils/ApiClient.dart';

/// AWMC NET 机台二维码导入的结果。
///
/// 接口是**一次同步调用**（实测约 36 秒），没有进度事件，所以这里只有最终统计。
class AwmcNetQrImportResult {
  /// 是否整体成功（HTTP 200）。
  final bool ok;

  /// 服务端把整套机台成绩拉下来后的总数。
  final int totalRecords;

  /// 本次**新增**的谱面数。
  final int imported;

  /// 本次**覆盖更新**的谱面数。
  final int updated;

  /// 本次跳过的谱面数（已有且没有更好）。
  final int skipped;

  /// 逐条失败的原因（多为「找不到歌曲」= AWMC NET 曲库还没收录）。
  /// **非空不代表整体失败** —— 实测 20 条失败时 HTTP 仍是 200。
  final List<String> errors;

  /// 失败时给用户看的中文文案（成功时为 null）。
  final String? errorMessage;

  /// 是不是「Token 无效」——调用方据此清掉本地存的 Token 并让用户重填。
  final bool tokenInvalid;

  final int elapsedMs;

  const AwmcNetQrImportResult({
    required this.ok,
    this.totalRecords = 0,
    this.imported = 0,
    this.updated = 0,
    this.skipped = 0,
    this.errors = const [],
    this.errorMessage,
    this.tokenInvalid = false,
    this.elapsedMs = 0,
  });

  factory AwmcNetQrImportResult.failure(
    String message, {
    bool tokenInvalid = false,
    int elapsedMs = 0,
  }) =>
      AwmcNetQrImportResult(
        ok: false,
        errorMessage: message,
        tokenInvalid: tokenInvalid,
        elapsedMs: elapsedMs,
      );

  /// 成功时给用户看的一行摘要。
  String get summary =>
      '新增 $imported 条 · 更新 $updated 条 · 跳过 $skipped 条（机台共 $totalRecords 条）';
}

/// AWMC NET.（https://net.wmc.pub）「同步成绩到 AWMC NET」。
///
/// ── 为什么是二维码而不是别的 ──
/// 这是 AWMC NET 提供的**唯一**一条我们走得通的写入路径：
///   * `POST /player/update_records` 等虽然也是水鱼兼容形状，但只认用户自己的
///     `Import-Token`，而 AWMC NET **没有用户名密码登录接口**（`/api/auth/login`
///     只有 GET，是 OAuth 跳转），App 没法像水鱼那样用密码换 Token；
///   * `POST /api/bot/sync` 虽然能直接用项目自带的密钥，但它接收的是**调用方给的
///     成绩数组** —— 而 App 本地活动槽里的成绩可能来自水鱼/落雪，推过去就是**串源**。
///
/// 二维码这条路让 **AWMC NET 自己拿二维码去机台拉成绩**，完全不经过我们的本地缓存，
/// 所以不存在串源问题。代价是需要用户去官网复制一次 Import-Token。
///
/// ── 两个实测要点 ──
///   1. **耗时约 36 秒且同步阻塞** —— 必须用 [timeout]（120s），
///      `ApiClient` 默认的 15s 会把成功判成超时；
///   2. **它是覆盖式的** —— 实测一次导入 `updated: 1106` / `skipped: 593`，
///      即以机台为准重写已有成绩，不是纯追加。UI 上要说清楚。
class AwmcNetScoreUploadService {
  AwmcNetScoreUploadService._();

  static final AwmcNetScoreUploadService instance =
      AwmcNetScoreUploadService._();

  /// 导入超时。实测 36 秒，留足余量（对方要登机台把整套成绩拉一遍）。
  static const Duration timeout = Duration(seconds: 120);

  /// 用机台登入二维码把成绩导入 AWMC NET。
  ///
  /// [importToken] 是用户在 net.wmc.pub **设置页最底部**「生成/轮换Token」生成、
  /// 自己保存的成绩导入 Token；[sgwcmaid] 是 `SGWCMAID` 开头的登入二维码字符串。
  ///
  /// 不抛异常：一切失败都收敛成 [AwmcNetQrImportResult.failure]，方便 UI 直接用。
  Future<AwmcNetQrImportResult> importByQr({
    required String importToken,
    required String sgwcmaid,
  }) async {
    final token = importToken.trim();
    final qr = sgwcmaid.trim();
    if (token.isEmpty) {
      return AwmcNetQrImportResult.failure('还没有设置 AWMC NET 成绩导入 Token');
    }
    if (qr.isEmpty) {
      return AwmcNetQrImportResult.failure('请先粘贴或扫描机台登入二维码');
    }

    final uri = Uri.parse(ApiUrls.AwmcNetScoreQrApi);
    // 出口固定校验：杜绝把 Token 发到别的域名
    if (uri.host != Uri.parse(ApiUrls.AwmcNetBaseUrl).host) {
      return AwmcNetQrImportResult.failure('拒绝请求非 AWMC NET 地址：${uri.host}');
    }

    final sw = Stopwatch()..start();
    final http.Response response;
    try {
      response = await ApiClient.postMultipart(
        uri,
        // 走 multipart 文本字段：接口另有一个 `file`（二维码图片）字段，
        // 但 App 现有扫码流程拿到的是字符串，用 sgwcmaid 这条更直接。
        fields: {'sgwcmaid': qr},
        headers: {'Import-Token': token},
        timeout: timeout,
      );
    } on TimeoutException {
      return AwmcNetQrImportResult.failure(
        '导入超时（已等待 ${timeout.inSeconds} 秒）。机台数据量大时会更久，请稍后重试',
        elapsedMs: sw.elapsedMilliseconds,
      );
    } catch (e) {
      return AwmcNetQrImportResult.failure(
        '连接 AWMC NET 失败：${_redact(e.toString())}',
        elapsedMs: sw.elapsedMilliseconds,
      );
    }
    final elapsed = sw.elapsedMilliseconds;
    return parseResponse(response, elapsed);
  }

  /// 把一次响应翻成结果。**抽成纯函数是为了能用真实响应体做单测**
  /// （下面的文案全部对着实测到的服务端原文写）。
  @visibleForTesting
  static AwmcNetQrImportResult parseResponse(
      http.Response response, int elapsedMs) {
    if (response.statusCode != 200) {
      return _failureForStatus(response, elapsedMs);
    }

    // 成功：解析统计。**响应体里不含 Token / 二维码**，可以安全 debugPrint。
    try {
      final decoded = json.decode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) {
        return AwmcNetQrImportResult.failure(
          'AWMC NET 返回了无法识别的数据',
          elapsedMs: elapsedMs,
        );
      }
      // 注意：`errors` 非空**不代表整体失败** —— 实测 20 条「找不到歌曲」时
      // HTTP 仍是 200，成绩也真的导进去了。
      final result = AwmcNetQrImportResult(
        ok: true,
        totalRecords: _asInt(decoded['total_records']),
        imported: _asInt(decoded['imported']),
        updated: _asInt(decoded['updated']),
        skipped: _asInt(decoded['skipped']),
        errors: (decoded['errors'] is List)
            ? (decoded['errors'] as List).map((e) => '$e').toList()
            : const [],
        elapsedMs: elapsedMs,
      );
      debugPrint('[AWMC NET] QR 导入成功：${result.summary} '
          '(${(elapsedMs / 1000).toStringAsFixed(1)}s, '
          '${result.errors.length} 条逐条失败)');
      return result;
    } catch (e) {
      return AwmcNetQrImportResult.failure(
        '解析 AWMC NET 返回失败：$e',
        elapsedMs: elapsedMs,
      );
    }
  }

  /// 把非 200 的响应翻成给用户看的中文。
  ///
  /// 文案对着**实测**到的服务端原文写：
  ///   * 401 `程序上传需要提供 Import-Token` —— 没带 Token
  ///   * 401 `Import-Token 无效` —— Token 不对
  ///   * 400 `需要提供 sgwcmaid 或二维码图片` —— 二维码字段是空的
  static AwmcNetQrImportResult _failureForStatus(
      http.Response response, int elapsed) {
    var detail = '';
    try {
      final decoded = json.decode(utf8.decode(response.bodyBytes));
      if (decoded is Map) {
        detail = (decoded['message'] ?? decoded['detail'] ?? '').toString();
      }
    } catch (_) {
      // 非 JSON（网关错误页等）：正文没参考价值
    }
    final clipped = detail.length > 200 ? '${detail.substring(0, 200)}…' : detail;

    if (response.statusCode == 401) {
      final invalid = !detail.contains('需要提供');
      return AwmcNetQrImportResult.failure(
        invalid
            ? 'AWMC NET 导入 Token 无效，请到 net.wmc.pub 设置页最底部重新生成'
            : '缺少 AWMC NET 导入 Token',
        tokenInvalid: invalid,
        elapsedMs: elapsed,
      );
    }
    if (response.statusCode == 400) {
      return AwmcNetQrImportResult.failure(
        detail.contains('sgwcmaid') || detail.contains('二维码')
            ? '机台二维码无效或已过期，请重新在公众号/机台获取后重试'
            : 'AWMC NET 拒绝了请求：${clipped.isEmpty ? '参数不合法' : clipped}',
        elapsedMs: elapsed,
      );
    }
    if (response.statusCode == 429) {
      return AwmcNetQrImportResult.failure(
        'AWMC NET 请求过于频繁，请稍后再试',
        elapsedMs: elapsed,
      );
    }
    if (response.statusCode >= 500) {
      return AwmcNetQrImportResult.failure(
        'AWMC NET 服务端异常（HTTP ${response.statusCode}），请稍后重试',
        elapsedMs: elapsed,
      );
    }
    return AwmcNetQrImportResult.failure(
      'AWMC NET 返回 HTTP ${response.statusCode}'
      '${clipped.isEmpty ? '' : '：$clipped'}',
      elapsedMs: elapsed,
    );
  }

  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  /// 异常文本里的长串一律打码：它们很可能就是 Token 本身。
  static String _redact(String input) => input.replaceAllMapped(
      RegExp(r'[A-Za-z0-9_\-]{24,}'), (m) => '****');
}
