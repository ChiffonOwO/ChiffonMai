import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpClient;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' show IOClient;
import 'package:my_first_flutter_app/api/ApiUrls.dart';

/// 带超时和连接池复用的 HTTP 客户端，所有 API 调用统一使用此类。
///
/// 使用共享的 [IOClient] 实例来复用 TCP 连接（keep-alive），
/// 避免每次请求都重新建立 TLS 握手，在高并发场景下（如获取 1000+ maidata.txt）
/// 可将网络耗时从数分钟降低到数十秒。
class ApiClient {
  static const _defaultTimeout = Duration(seconds: 15);

  /// 共享的 HTTP 客户端，复用 TCP 连接
  static http.Client? _sharedClient;

  static http.Client get _client {
    if (_sharedClient != null) return _sharedClient!;
    // 使用较大的连接池，支持高并发批量请求
    final ioClient = HttpClient()
      ..maxConnectionsPerHost = 100
      ..idleTimeout = const Duration(seconds: 30);
    _sharedClient = IOClient(ioClient);
    return _sharedClient!;
  }

  /// 在应用退出或需要释放资源时调用
  static void dispose() {
    _sharedClient?.close();
    _sharedClient = null;
  }

  /// 合并默认请求头。
  /// 对自家后端（chiffonmai.cloud）附加网关/OAuth 代理鉴权头 `x-prober-key`。
  static Map<String, String> _mergeHeaders(Uri url, Map<String, String>? headers) {
    final merged = <String, String>{
      'Accept-Encoding': 'gzip',
    };
    if (url.host == 'chiffonmai.cloud') {
      merged['x-prober-key'] = ApiUrls.ProberApiKey;
    }
    if (headers != null) {
      merged.addAll(headers);
    }
    return merged;
  }

  static Future<http.Response> get(Uri url, {
    Map<String, String>? headers,
    Duration timeout = _defaultTimeout,
  }) {
    return _client.get(url, headers: _mergeHeaders(url, headers)).timeout(timeout);
  }

  static Future<http.Response> post(Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    Duration timeout = _defaultTimeout,
  }) {
    return _client.post(url, headers: _mergeHeaders(url, headers), body: body, encoding: encoding).timeout(timeout);
  }

  static Future<http.Response> put(Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    Duration timeout = _defaultTimeout,
  }) {
    return _client.put(url, headers: _mergeHeaders(url, headers), body: body, encoding: encoding).timeout(timeout);
  }

  static Future<http.Response> delete(Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    Duration timeout = _defaultTimeout,
  }) {
    return _client.delete(url, headers: _mergeHeaders(url, headers), body: body, encoding: encoding).timeout(timeout);
  }
}
