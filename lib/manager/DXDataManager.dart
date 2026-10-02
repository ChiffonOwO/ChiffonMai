import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:my_first_flutter_app/api/ApiUrls.dart';
import 'package:my_first_flutter_app/entity/DXRating/DXDataEntity.dart';
import 'package:my_first_flutter_app/utils/ApiClient.dart';
import 'package:path_provider/path_provider.dart';

/// 一次目录请求的结果。
///
/// **304 与失败必须分开**：304 的意思是"本地就是最新的、这次没下正文"，
/// 失败的意思是"这次没成功、下次还得试"。混在一起要么把 304 当失败反复重试，
/// 要么把失败当成最新、从此再也不更新。
typedef DxCatalogResponse = ({
  int status,
  Map<String, dynamic>? body,
  String? etag,
});

/// 加载 dxrating 全量数据（定数历史、曲绘兜底索引都用它）。
///
/// 三条路，按代价从低到高：
///   1. **内存**：同一会话内直接用；
///   2. **磁盘**：冷启动读本地副本；
///   3. **网络**：只在没有本地副本、或目录真的变了时才走。
///
/// ⚠️ 磁盘这一层是 2026-09 补的：之前只有内存缓存（`_cached`），所以**每次冷启动
/// 打开曲目详情页都会重新拉一遍 4MB 的 dxdata**（用户反馈"进页面老是重新加载
/// 定数历史"）——4MB / 实测 200s+，慢网下既慢又容易失败。
///
/// 「目录变没变」用官方文档支持的 **HEAD + ETag** 判断（`/spec.json` 里
/// `HEAD /dxdata` 的说明就是"metadata，不加载正文"）：HEAD 只有几百字节，
/// 带上 `If-None-Match` 的 GET 在目录没变时回 **304**（零正文）。
/// 于是最常见的路径是"一个 HEAD 就结束"，而不是"每 7 天盲下 4MB"。
class DXDataManager {
  static final DXDataManager _instance = DXDataManager._internal();
  factory DXDataManager() => _instance;
  DXDataManager._internal();

  /// 本地副本的格式版本（改了结构就 +1，旧文件自动忽略）。
  static const int cacheVersion = 1;

  /// 冷启动后自动探测目录是否变化的间隔。
  ///
  /// 探测本身很便宜（HEAD 几百字节），但没必要每进一次页面都探一次；
  /// 目录大约一周才变一次，6 小时已经足够及时。
  static const Duration probeTtl = Duration(hours: 6);

  /// 正文（就是接口原样返回的 JSON）与元信息分开存：
  /// 套一层 JSON 会让 4MB 再编码一遍（翻倍且丢字段），分开存最省事。
  static const String _bodyFileName = 'dxdata_catalog_v$cacheVersion.json';
  static const String _metaFileName = 'dxdata_catalog_v${cacheVersion}_meta.json';

  DXDataEntity? _cached;
  String? _etag;
  DateTime? _checkedAt;

  /// 单飞：并发调用只跑一次加载 / 探测。
  Future<DXDataEntity?>? _inflight;
  Future<void>? _checking;

  /// 内存里现有的目录（可能来自磁盘副本）。没加载过时为 null。
  DXDataEntity? get data => _cached;

  /// 本地副本对应的目录 ETag（诊断用）。
  String? get etag => _etag;

  /// 本地副本的落盘时间（诊断用）。
  @visibleForTesting
  DateTime? get checkedAt => _checkedAt;

  // ===========================================================================
  // 加载
  // ===========================================================================

  /// 取目录：内存 → 磁盘 → 网络。重复调用安全（单飞）。
  Future<DXDataEntity?> load() =>
      _inflight ??= _load().whenComplete(() => _inflight = null);

  Future<DXDataEntity?> _load() async {
    if (_cached != null) return _cached;

    // 1) 磁盘副本：冷启动不再每次都下 4MB
    final local = await _readLocalCatalog();
    if (local != null) {
      _cached = local.entity;
      _etag = local.etag;
      _checkedAt = local.savedAt;
      debugPrint('[DXData] 磁盘副本命中：${_cached!.songs.length} 首'
          '（保存于 ${local.savedAt.toIso8601String()}，不再下载）');
      // 2) 顺手在后台探一次"目录变了没有"：只有真变了才下正文
      unawaited(checkForUpdate());
      return _cached;
    }

    // 3) 没有本地副本 → 只能下载
    await checkForUpdate(force: true);
    return _cached;
  }

  // ===========================================================================
  // 新鲜度探测
  // ===========================================================================

  /// 探测目录是否变化，必要时下载并落盘。
  ///
  /// 返回**本地数据是否被换掉**。[force] 只是跳过 [probeTtl] 节流，
  /// **不会**在目录没变时硬下 4MB —— 那没有任何意义。
  Future<bool> checkForUpdate({bool force = false}) {
    if (_checking != null) return _checking!.then((_) => false);
    final future = _checkForUpdate(force: force);
    _checking = future.whenComplete(() => _checking = null);
    return future;
  }

  Future<bool> _checkForUpdate({required bool force}) async {
    if (!force && _checkedAt != null) {
      if (DateTime.now().difference(_checkedAt!) < probeTtl) return false;
    }

    // 便宜的一步：只要响应头，不加载正文
    final remoteEtag = await _headEtag();
    if (remoteEtag != null && _etag != null && remoteEtag == _etag) {
      _checkedAt = DateTime.now();
      debugPrint('[DXData] 目录未变化（ETag 一致），跳过 4MB 下载');
      return false;
    }

    // 变了（或拿不到 ETag）才请求正文；带上本地 ETag，没变会回 304
    final res = await _fetchCatalog(ifNoneMatch: _etag);
    if (res.status == 304) {
      _checkedAt = DateTime.now();
      debugPrint('[DXData] 目录未变化（304），跳过 4MB 下载');
      return false;
    }
    final body = res.body;
    if (res.status != 200 || body == null) {
      debugPrint('[DXData] 目录下载失败：HTTP ${res.status}');
      return false;
    }

    try {
      _cached = DXDataEntity.fromJson(body);
    } catch (e) {
      debugPrint('[DXData] 目录解析失败: $e');
      return false;
    }
    _etag = res.etag ?? remoteEtag;
    _checkedAt = DateTime.now();
    await _writeLocalCatalog(body, _etag);
    debugPrint('[DXData] 目录已更新：${_cached!.songs.length} 首'
        '（etag=${_etag ?? '无'}）');
    return true;
  }

  /// `HEAD /dxdata`：拿 ETag，不下载正文。失败返回 null（那就退回直接请求正文）。
  Future<String?> _headEtag() async {
    final hook = debugHeadEtag;
    if (hook != null) return hook();
    try {
      final r = await ApiClient.head(
        Uri.parse(ApiUrls.DXDataApi),
        timeout: const Duration(seconds: 30),
      );
      if (r.statusCode == 200) return _normalizeEtag(r.headers['etag']);
      debugPrint('[DXData] HEAD 失败：HTTP ${r.statusCode}');
    } catch (e) {
      // 探测失败不算错：退回普通 GET（拿不到 ETag 就是多下一次而已）
      debugPrint('[DXData] HEAD 异常（忽略）: $e');
    }
    return null;
  }

  /// `GET /dxdata`（可带 `If-None-Match`）。
  ///
  /// ⚠️ 超时 300s 别改小：dn 数据 4MB，实测从 miruku.dxrating.net 下载要 **200s+**
  /// （≈20KB/s，首字节 1s 后开始慢速传输），30s 必然超时 —— 定数历史与
  /// 「曲绘兜底索引更新」都会静默失败。
  Future<DxCatalogResponse> _fetchCatalog({String? ifNoneMatch}) async {
    final hook = debugFetchCatalog;
    if (hook != null) return hook(ifNoneMatch);
    try {
      final response = await ApiClient.get(
        Uri.parse(ApiUrls.DXDataApi),
        headers: {
          'Content-Type': 'application/json',
          if (ifNoneMatch != null) 'If-None-Match': ifNoneMatch,
        },
        timeout: const Duration(seconds: 300),
      );
      if (response.statusCode == 304) {
        return (status: 304, body: null, etag: ifNoneMatch);
      }
      if (response.statusCode == 200) {
        return (
          status: 200,
          body: jsonDecode(utf8.decode(response.bodyBytes))
              as Map<String, dynamic>,
          etag: _normalizeEtag(response.headers['etag']),
        );
      }
      return (status: response.statusCode, body: null, etag: null);
    } catch (e) {
      debugPrint('[DXData] 网络请求异常: $e');
      return (status: 0, body: null, etag: null);
    }
  }

  /// ETag 归一化：去掉 `W/` 弱校验前缀与首尾空白，只留引号内的值。
  ///
  /// 服务器给的是强校验（正文 SHA-256），但中间可能有 CDN 改写；
  /// 归一化后比较，避免因为 `W/` 前缀或多余空格误判成"变了"而白下 4MB。
  static String? _normalizeEtag(String? raw) {
    if (raw == null) return null;
    var s = raw.trim();
    if (s.startsWith('W/')) s = s.substring(2).trim();
    if (s.isEmpty) return null;
    return s;
  }

  // ===========================================================================
  // 本地副本（磁盘）
  // ===========================================================================

  /// 仅供测试：替换本地目录（默认 `getApplicationDocumentsDirectory()`）。
  @visibleForTesting
  static Directory? debugCacheDirOverride;

  /// 仅供测试：替换 `HEAD /dxdata`（返回 ETag；null 表示探测不可用）。
  @visibleForTesting
  static Future<String?> Function()? debugHeadEtag;

  /// 仅供测试：替换 `GET /dxdata`。
  @visibleForTesting
  static Future<DxCatalogResponse> Function(String? ifNoneMatch)?
      debugFetchCatalog;

  /// 仅供测试：清空内存状态（不动磁盘副本）。
  @visibleForTesting
  void debugResetForTest() {
    _cached = null;
    _etag = null;
    _checkedAt = null;
    _inflight = null;
    _checking = null;
  }

  static Future<File> _bodyFile() async {
    final dir =
        debugCacheDirOverride ?? await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_bodyFileName');
  }

  static Future<File> _metaFile() async {
    final dir =
        debugCacheDirOverride ?? await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_metaFileName');
  }

  Future<({DXDataEntity entity, String? etag, DateTime savedAt})?>
      _readLocalCatalog() async {
    try {
      final body = await _bodyFile();
      if (!await body.exists()) return null;
      final text = await body.readAsString();
      final json = jsonDecode(text);
      if (json is! Map<String, dynamic>) return null;

      String? etag;
      var savedAt = DateTime.fromMillisecondsSinceEpoch(0);
      try {
        final meta = await _metaFile();
        if (await meta.exists()) {
          final decoded = jsonDecode(await meta.readAsString());
          if (decoded is Map) {
            etag = _normalizeEtag(decoded['etag'] as String?);
            final ms = decoded['savedAt'];
            if (ms is num) {
              savedAt = DateTime.fromMillisecondsSinceEpoch(ms.toInt());
            }
          }
        }
      } catch (e) {
        debugPrint('[DXData] 读取副本元信息失败（忽略）: $e');
      }

      return (
        entity: DXDataEntity.fromJson(json),
        etag: etag,
        savedAt: savedAt,
      );
    } catch (e) {
      debugPrint('[DXData] 读取磁盘副本失败（忽略）: $e');
      return null;
    }
  }

  Future<void> _writeLocalCatalog(
      Map<String, dynamic> body, String? etag) async {
    try {
      await (await _bodyFile()).writeAsString(jsonEncode(body));
      await (await _metaFile()).writeAsString(jsonEncode({
        'v': cacheVersion,
        'etag': etag,
        'savedAt': DateTime.now().millisecondsSinceEpoch,
        'count': _cached?.songs.length ?? 0,
      }));
    } catch (e) {
      debugPrint('[DXData] 写入磁盘副本失败（忽略）: $e');
    }
  }
}
