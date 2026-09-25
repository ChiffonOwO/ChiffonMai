import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:my_first_flutter_app/constant/CacheKeyConstant.dart';
import 'package:my_first_flutter_app/utils/ColorUtil.dart';
import 'CurrentDataSourceNotifier.dart';

/// 导出图片共享个人信息组件
class ExportUserInfoWidget {
  /// 构建个人信息区域 Widget（异步加载数据）
  ///
  /// [exportTime] 图片导出时间，不传则使用当前时间
  /// [selectedPlateId] 用户选中的姓名框 ID；null 时从 SharedPreferences 读取
  static Widget buildUserInfoSection(
    BuildContext context, {
    DateTime? exportTime,
    int? selectedPlateId,
  }) {
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
        // 姓名框优先级：调用方 override > prefs > null（隐藏）
        final int? plateId = selectedPlateId ?? data['plateId'] as int?;

        return ClipRRect(
          borderRadius: BorderRadius.circular(14.0),
          child: SizedBox(
            // 姓名框尺寸：2.5× = 1150×230（宽度 2.5x，高度保持 230）
            // 内尺寸按 5/6 比例从 3x 缩放得到（1380→1150 = 5/6）
            width: 1150,
            height: 230,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 姓名框图片作为唯一背景：用 BoxFit.contain + Alignment.center 让图片完整显示，
                // 不会被 cover 裁剪（原图 4:1，1150×230 是 5:1，cover 会裁掉两侧）
                if (plateId != null)
                  CachedNetworkImage(
                    imageUrl:
                        'https://assets2.lxns.net/maimai/plate/$plateId.png',
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    placeholder: (ctx, url) => Container(
                      color: const Color(0xFFE0E0E0),
                    ),
                    errorWidget: (ctx, url, err) => Container(
                      color: const Color(0xFFE0E0E0),
                      child: const Icon(Icons.image_not_supported,
                          color: Colors.grey),
                    ),
                  ),

                // 个人信息直接放到姓名框图片的内侧（左对齐 + 紧贴边缘）
                // 无任何半透白色背景遮罩，让姓名框图片完全可见
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      // 头像放大：132×160（保持方形），边框宽 5，圆角 16
                      // 头像占位 icon 96，姓名框内高度 230 - padding 28 = 202 可用，
                      // 160 留 21px 上下间距，视觉更突出
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: const Color(0xFF4DA8FF), width: 5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: avatarUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: avatarUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => const Icon(
                                      Icons.person,
                                      size: 96,
                                      color: Colors.grey),
                                )
                              : const Icon(Icons.person,
                                  size: 96,
                                  color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 27),
                      // 用户信息：Rating 徽章 + 昵称 + Best35/Best15
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Rating 徽章置顶（原顺序是昵称在上），高度 46（2.5x 比例）
                            ColorUtil.buildRatingBadge(
                              totalRating,
                              height: 46,
                            ),
                            const SizedBox(height: 5),
                            // 用 IntrinsicWidth + crossAxisAlignment.stretch
                            // 强制让昵称 chip 和 Best chip 的背景宽度严格一致：
                            //   1. IntrinsicWidth 给 Column 一个 tight 宽度约束
                            //      = max(昵称 intrinsic width, Best intrinsic width)
                            //   2. Column 用 stretch 让所有子元素填满该宽度
                            //   3. 容器无 explicit width 时填满约束 → 两个 chip 严格等宽
                            // 这样不论昵称几个字符，背景宽度都跟 Best 完全对齐。
                            IntrinsicWidth(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  // 昵称（去掉「昵称:」前缀）— 字号 36，白色背景小标签
                                  // 字符间插空格：例如「1234」→「1 2 3 4」，便于在姓名框上视觉展开
                                  _buildWhiteChip(
                                    _addCharSpaces(nickname.isNotEmpty
                                        ? nickname
                                        : '未知玩家'),
                                    fontSize: 36,
                                    blurRadius: 7,
                                  ),
                                  const SizedBox(height: 5),
                                  // Best35 + Best15 — 字号 27，白色背景小标签
                                  _buildWhiteChip(
                                    'Best35: $best35Rating  |  Best15: $best15Rating',
                                    fontSize: 27,
                                    blurRadius: 7,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 小白色背景标签 — 用于昵称 / Best35+Best15。
  /// 让文字在姓名框图片上仍清晰可读，同时不破坏整体设计风格。
  /// 自动内边距 + 圆角，长文本撑满父宽度（Expanded 上下文内）。
  /// 边框宽度跟字体大小成比例，避免大字号下边框太细。
  /// [blurRadius] 文字阴影模糊半径，3x 姓名框统一用 8。
  static Widget _buildWhiteChip(
    String text, {
    required double fontSize,
    double blurRadius = 7,
  }) {
    final borderWidth = (fontSize / 18).clamp(1.5, 4.0);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: fontSize * 0.45, vertical: fontSize * 0.18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(fontSize * 0.35),
        border: Border.all(color: const Color(0xFF4DA8FF), width: borderWidth),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: fontSize,
          color: Colors.black,
          fontWeight: FontWeight.w700,
          shadows: [
            Shadow(
              color: Colors.black87,
              blurRadius: blurRadius,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }

  /// 在字符串每个字符之间插入一个空格。
  /// 例如：`"1234"` → `"1 2 3 4"`，`"小明"` → `"小 明"`。
  /// 使用 runes 处理 Unicode（emoji / 组合字符安全）。
  static String _addCharSpaces(String text) {
    if (text.isEmpty) return text;
    final chars = text.runes.map((r) => String.fromCharCode(r)).toList();
    return chars.join(' ');
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
      final totalRating =
          prefs.getInt('best50TotalRA') ?? (best35Rating + best15Rating);
      final plateId = prefs.getInt(CacheKeyConstant.selectedPlateIdCache);

      // 读取数据源
      final dataSource = RefreshDataSource.displayNameOfKey(
          prefs.getString(CacheKeyConstant.lastDataSource));

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
        'plateId': plateId,
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
        'plateId': null,
      };
    }
  }
}