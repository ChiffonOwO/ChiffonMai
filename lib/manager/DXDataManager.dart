import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:my_first_flutter_app/api/ApiUrls.dart';
import 'package:my_first_flutter_app/entity/DXRating/DXDataEntity.dart';
import 'package:my_first_flutter_app/utils/ApiClient.dart';

/// 加载 dxrating 全量数据（仅从 API 拉取，带内存缓存）。
class DXDataManager {
  static final DXDataManager _instance = DXDataManager._internal();
  factory DXDataManager() => _instance;
  DXDataManager._internal();

  DXDataEntity? _cached;
  bool _loading = false;

  Future<DXDataEntity?> load() async {
    if (_cached != null) return _cached;
    if (_loading) return _cached;
    _loading = true;
    try {
      final json = await _fetchFromNetwork();
      if (json != null) {
        _cached = DXDataEntity.fromJson(json);
        debugPrint('DXData 从 API 加载成功，共 ${_cached?.songs.length ?? 0} 首歌曲');
      } else {
        debugPrint('DXData API 加载失败：返回 null');
      }
    } catch (e) {
      debugPrint('DXData 加载异常: $e');
    } finally {
      _loading = false;
    }
    return _cached;
  }

  /// 从 miruku.dxrating.net 拉取全量 dxdata。
  Future<Map<String, dynamic>?> _fetchFromNetwork() async {
    try {
      final response = await ApiClient.get(
        Uri.parse(ApiUrls.DXDataApi),
        headers: {'Content-Type': 'application/json'},
        // ⚠️ 别改回 30s：dxdata 有 4MB，实测从 miruku.dxrating.net 下载要
        // **200s+**（≈20KB/s，首字节 1s 后开始慢速传输），30s 必然超时 ——
        // 定数历史与「曲绘兜底索引更新」都会静默失败。
        timeout: const Duration(seconds: 300),
      );
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      }
      debugPrint('DXData 网络请求失败: HTTP ${response.statusCode}');
    } catch (e) {
      debugPrint('DXData 网络请求异常: $e');
    }
    return null;
  }
}
