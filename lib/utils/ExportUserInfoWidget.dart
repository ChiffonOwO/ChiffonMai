import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:my_first_flutter_app/constant/CacheKeyConstant.dart';
import 'package:my_first_flutter_app/utils/ColorUtil.dart';

/// 导出图片共享个人信息组件
class ExportUserInfoWidget {
  /// 构建个人信息区域 Widget（异步加载数据）
  ///
  /// [exportTime] 图片导出时间，不传则使用当前时间
  static Widget buildUserInfoSection(BuildContext context, {DateTime? exportTime}) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadUserInfo(exportTime ?? DateTime.now()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black, width: 2.0),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final data = snapshot.data ?? {};
        final avatarUrl = data['avatarUrl'] as String? ?? '';
        final nickname = data['nickname'] as String? ?? '';
        final best35Rating = data['best35Rating'] as int? ?? 0;
        final best15Rating = data['best15Rating'] as int? ?? 0;
        final totalRating = data['totalRating'] as int? ?? 0;
        final dataSource = data['dataSource'] as String? ?? '';
        final exportTimeStr = data['exportTime'] as String? ?? '';

        return Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black, width: 2.0),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Row(
            children: [
              // 头像（正方形）
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: avatarUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: avatarUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const Icon(Icons.person, size: 56, color: Colors.grey),
                        )
                      : const Icon(Icons.person, size: 56, color: Colors.grey),
                ),
              ),
              const SizedBox(width: 16),
              // 左侧：用户数据
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '昵称: ${nickname.isNotEmpty ? nickname : '未知玩家'}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ColorUtil.buildRatingBadge(
                      totalRating,
                      height: 32,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Best35: $best35Rating  |  Best15: $best15Rating',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              // 右侧：元信息
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // 数据源
                    Text(
                      '数据源: ${dataSource.isNotEmpty ? dataSource : '未知'}',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // 导出时间
                    Text(
                      '导出时间: $exportTimeStr',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Generated by
                    const Text(
                      'Generated by ChiffonMai',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 从 SharedPreferences 加载用户信息
  static Future<Map<String, dynamic>> _loadUserInfo(DateTime exportTime) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final avatarId = prefs.getInt('selectedAvatarId') ?? 1;
      final avatarUrl = 'https://assets2.lxns.net/maimai/icon/$avatarId.png';
      final nickname = prefs.getString('userNickname') ?? '';
      final best35Rating = prefs.getInt('best35TotalRA') ?? 0;
      final best15Rating = prefs.getInt('best15TotalRA') ?? 0;
      final totalRating = prefs.getInt('best50TotalRA') ?? (best35Rating + best15Rating);

      // 读取数据源
      final lastDataSource = prefs.getString(CacheKeyConstant.lastDataSource) ?? '';
      final dataSource = lastDataSource == 'luoxue' ? '落雪' : (lastDataSource == 'shuiyu' ? '水鱼' : '');

      // 格式化导出时间
      final exportTimeStr =
          '${exportTime.year}-${exportTime.month.toString().padLeft(2, '0')}-${exportTime.day.toString().padLeft(2, '0')} '
          '${exportTime.hour.toString().padLeft(2, '0')}:${exportTime.minute.toString().padLeft(2, '0')}:${exportTime.second.toString().padLeft(2, '0')}';

      return {
        'avatarUrl': avatarUrl,
        'nickname': nickname,
        'best35Rating': best35Rating,
        'best15Rating': best15Rating,
        'totalRating': totalRating,
        'dataSource': dataSource,
        'exportTime': exportTimeStr,
      };
    } catch (e) {
      debugPrint('加载用户信息失败: $e');
      return {
        'avatarUrl': '',
        'nickname': '',
        'best35Rating': 0,
        'best15Rating': 0,
        'totalRating': 0,
        'dataSource': '',
        'exportTime': '',
      };
    }
  }
}
