import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:my_first_flutter_app/api/ApiUrls.dart';
import 'package:my_first_flutter_app/entity/nearcade/NearCadeShop.dart';
import 'package:my_first_flutter_app/utils/ApiClient.dart';

class NearCadeService {
  static final NearCadeService _instance = NearCadeService._internal();
  factory NearCadeService() => _instance;
  NearCadeService._internal();

  /// 获取店铺列表
  /// [page] 页码
  /// [limit] 每页数量（最多100）
  /// [q] 搜索关键词
  /// [regionId] 地区ID
  /// [includeTimeInfo] 是否包含时间信息
  Future<NearCadeShop?> getShops({
    int page = 1,
    int limit = 100,
    String? q,
    String? regionId,
    bool includeTimeInfo = true,
  }) async {
    try {
      final uri = Uri.parse(ApiUrls.NearCadeShopsApi).replace(queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
        if (q != null && q.isNotEmpty) 'q': q,
        if (regionId != null && regionId.isNotEmpty) 'regionId': regionId,
        'includeTimeInfo': includeTimeInfo.toString(),
      });

      final response = await ApiClient.get(uri, headers: {
        'Accept-Language': 'zh-CN,zh;q=0.9',
      });

      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return NearCadeShop.fromJson(json);
      }
      return null;
    } catch (e) {
      debugPrint('获取NearCade店铺数据失败: $e');
      return null;
    }
  }

  /// 获取所有店铺（循环拉取直到没有更多页）
  Future<List<Shop>> getAllShops({
    String? q,
    String? regionId,
  }) async {
    final allShops = <Shop>[];
    int page = 1;

    while (true) {
      final result = await getShops(
        page: page,
        limit: 100,
        q: q,
        regionId: regionId,
      );

      if (result == null || result.shops.isEmpty) break;

      allShops.addAll(result.shops);

      if (!result.hasNextPage) break;
      page++;
    }

    return allShops;
  }
}
