import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:my_first_flutter_app/entity/DXRating/DXDataEntity.dart';

/// 加载 dxrating 静态数据（assets/dxrating_dxdata.json），带内存缓存。
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
      final jsonStr = await rootBundle.loadString(
        'assets/dxrating_dxdata.json',
      );
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      _cached = DXDataEntity.fromJson(json);
      debugPrint('DXData 加载成功，共 ${_cached?.songs.length ?? 0} 首歌曲');
    } catch (e) {
      debugPrint('DXData 加载失败: $e');
    } finally {
      _loading = false;
    }
    return _cached;
  }
}
