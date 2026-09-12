import 'dart:convert';
import 'dart:io';

import 'package:http_parser/http_parser.dart';

import '../api/ApiUrls.dart';
import '../entity/MaimaiHubOcrResult.dart';
import '../manager/DivingFishProbeManager.dart';
import '../utils/ApiClient.dart';

/// MaimaiHub 结算画面识别（走 MaimaiHub backend 代理）
///
/// 输入是**对着机台结算页面拍的照片**（不是手机截图），文案统一用「拍摄」。
///
/// ## 为什么要绕 backend
/// MaimaiHub 的 OCR 是仓库里的独立 FastAPI 服务 `ocr-api/`，只监听 `127.0.0.1:19100`，
/// 通过 autossh 隧道转发给 backend 容器（`host.docker.internal:19100`）。
/// **App 直连不到它**，只能调 backend 的代理接口：
///
/// ```text
/// POST {MaimaiHubBaseUrl}/me/ocr/recognize
/// Authorization: Bearer <MaimaiHub 用户 token>
/// Content-Type: multipart/form-data，字段名 images（可重复，1..20 张）
/// ```
///
/// ## 和自家后端 OCR 的区别
/// 自家 `POST /api/ocr/score` 返回**原始文本块**（百度/腾讯通用 OCR），字段要自己解析；
/// 这个是**面向舞萌成绩图的专用识别**，直接返回曲名候选/达成率/DX分/难度/FC/FS。
class MaimaiHubOcrService {
  MaimaiHubOcrService._();
  static final MaimaiHubOcrService instance = MaimaiHubOcrService._();

  /// 单张图最大 8 MiB（服务端硬限制，超了返回 413）
  static const int maxImageBytes = 8 * 1024 * 1024;

  /// 一批最多 20 张（服务端硬限制，超了返回 400）
  static const int maxImagesPerBatch = 20;

  /// 识别比较慢（真实模型跑 GPU），给足超时
  static const Duration _timeout = Duration(seconds: 90);

  /// 当前是否有可用的 MaimaiHub 登录态。
  ///
  /// 该接口必须带用户 token，未登录时直接返回 false，调用方应引导去登录
  /// （见首页/账号同步页的 MaimaiHub 扫码登录入口）。
  Future<bool> isAvailable() async =>
      await DivingFishProbeManager().ensureAuthToken() != null;

  /// 识别一张或多张结算画面图片。
  ///
  /// [imageFiles] 1..20 张，格式 JPEG/PNG/WebP，单张 ≤8 MiB。
  /// 未登录或 token 失效时抛 [MaimaiHubOcrException]，请先调 [isAvailable]。
  Future<MaimaiHubOcrBatch> recognize(List<File> imageFiles) async {
    if (imageFiles.isEmpty) {
      throw MaimaiHubOcrException('请先选择至少一张结算画面图片');
    }
    if (imageFiles.length > maxImagesPerBatch) {
      throw MaimaiHubOcrException(
          '一次最多识别 $maxImagesPerBatch 张，当前选了 ${imageFiles.length} 张');
    }

    for (final f in imageFiles) {
      if (!await f.exists()) {
        throw MaimaiHubOcrException('文件不存在：${f.path}');
      }
      final len = await f.length();
      if (len > maxImageBytes) {
        throw MaimaiHubOcrException(
            '${f.uri.pathSegments.last} 超过 8 MiB 上限（${(len / 1024 / 1024).toStringAsFixed(1)} MiB）');
      }
    }

    final token = await DivingFishProbeManager().ensureAuthToken();
    if (token == null || token.isEmpty) {
      throw MaimaiHubOcrException('未登录 MaimaiHub，无法使用该识别服务');
    }

    final uri = Uri.parse(ApiUrls.MaimaiHubOcrRecognizeUrl);
    try {
      final resp = await ApiClient.postMultipart(
        uri,
        // 字段名必须是 images，且多张图共用同一个字段名
        files: [
          for (final f in imageFiles)
            (
              field: 'images',
              filePath: f.path,
              contentType: _contentTypeFor(f.path),
            ),
        ],
        headers: {'Authorization': 'Bearer $token'},
        timeout: _timeout,
      );

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw MaimaiHubOcrException(_describeError(resp.statusCode, resp.body));
      }

      final Map<String, dynamic> body;
      try {
        body = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      } catch (e) {
        throw MaimaiHubOcrException('识别结果 JSON 解析失败: $e');
      }
      return MaimaiHubOcrBatch.fromJson(body);
    } on MaimaiHubOcrException {
      rethrow;
    } catch (e) {
      throw MaimaiHubOcrException('识别请求失败: $e');
    }
  }

  /// 按扩展名推断 mime（服务端只接受 JPEG/PNG/WebP，错类型返回 415）
  MediaType _contentTypeFor(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    return MediaType('image', 'jpeg');
  }

  /// 把 HTTP 状态码翻译成人话（对照 ocr-api 文档里的错误表）
  String _describeError(int status, String body) {
    final detail = _extractMessage(body);
    switch (status) {
      case 400:
        return '图片为空或数量超限${detail.isEmpty ? '' : '：$detail'}';
      case 401:
        return '登录状态已失效，请重新登录 MaimaiHub';
      case 413:
        return '有图片超过 8 MiB 上限';
      case 415:
        return '图片格式不支持（仅支持 JPEG / PNG / WebP）';
      case 502:
        return 'OCR 服务返回了无法解析的结果';
      case 503:
        return 'OCR 服务暂时不可用，请稍后再试';
      case 504:
        return 'OCR 识别超时，请稍后再试';
      default:
        return '识别失败（HTTP $status）${detail.isEmpty ? '' : '：$detail'}';
    }
  }

  /// 从后端错误体里取可读信息（NestJS 用 message，FastAPI 用 detail）
  String _extractMessage(String body) {
    if (body.isEmpty) return '';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final m = decoded['message'] ?? decoded['detail'];
        if (m is String) return m;
        if (m is List && m.isNotEmpty) return m.first.toString();
      }
    } catch (_) {
      // 非 JSON，截断原始文本
    }
    return body.length > 120 ? '${body.substring(0, 120)}…' : body;
  }
}

class MaimaiHubOcrException implements Exception {
  final String message;
  MaimaiHubOcrException(this.message);

  @override
  String toString() => 'MaimaiHubOcrException: $message';
}
