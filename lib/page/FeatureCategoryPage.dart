import 'package:flutter/material.dart';
import '../entity/FeatureModels.dart';
import '../utils/CommonWidgetUtil.dart';
import '../utils/AppTheme.dart';
import '../utils/AppConstants.dart';
import '../utils/FavoriteFeaturesNotifier.dart';
import '../utils/UpdateNotifier.dart';
import '../widgets/FeatureButton.dart';
import '../widgets/PageTopBar.dart';
import '../widgets/QuickSearchBar.dart';
// UpdateAvailableIcon 是「发现新版本」的绿色圆环箭头，定义在 Hub 组件库里
import 'HubComponents.dart' show UpdateAvailableIcon;

/// 大类子功能页面：显示某个分类下的所有功能按钮
class FeatureCategoryPage extends StatefulWidget {
  final ButtonCategory category;
  final Future<void> Function(ButtonItem) onFeatureTap;
  /// 登录状态通知器，用于在登录/登出后实时更新按钮（如"登录水鱼"↔"登出账号"）
  final ValueNotifier<bool>? loginStateNotifier;

  const FeatureCategoryPage({
    super.key,
    required this.category,
    required this.onFeatureTap,
    this.loginStateNotifier,
  });

  @override
  State<FeatureCategoryPage> createState() => _FeatureCategoryPageState();
}

class _FeatureCategoryPageState extends State<FeatureCategoryPage> {
  String _searchQuery = '';

  @override
  void dispose() {
    super.dispose();
  }

  bool _isFavorited(String title) =>
      FavoriteFeaturesNotifier.titles.contains(title);

  Future<void> _toggleFavorite(String title) =>
      FavoriteFeaturesNotifier.toggle(title);

  List<ButtonItem> _buildItems(bool isLoggedIn) {
    // 根据当前登录状态动态替换"系统"分类中的登录/登出按钮
    List<ButtonItem> items = widget.category.items.map((item) {
      if (item.title == '登录水鱼' && isLoggedIn) {
        return const ButtonItem(icon: Icons.logout, title: '登出账号', subtitle: '清除水鱼登录状态');
      }
      if (item.title == '登出账号' && !isLoggedIn) {
        return const ButtonItem(icon: Icons.login, title: '登录水鱼', subtitle: '获取ImportToken以便同步成绩');
      }
      return item;
    }).toList();

    if (_searchQuery.isNotEmpty) {
      items = items.where((item) =>
        item.title.toLowerCase().contains(_searchQuery) ||
        item.subtitle.toLowerCase().contains(_searchQuery)
      ).toList();
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final Color textPrimaryColor = Theme.of(context).colorScheme.onSurface;
    final Color cardBgColor = Theme.of(context).colorScheme.surface.withValues(alpha: 0.9);
    final BoxShadow defaultShadow = AppColors.defaultShadow(brightness);

    // 构建按钮网格
    Widget buildGrid(List<ButtonItem> items) {
      if (items.isEmpty) {
        return Center(
          child: Text(
            '未找到匹配的功能',
            style: TextStyle(
              color: AppColors.greyHint(brightness),
              fontSize: screenWidth * 0.04,
            ),
          ),
        );
      }
      return GridView.builder(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.03,
          vertical: screenHeight * 0.01,
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: AppConstants.crossAxisCount,
          crossAxisSpacing: screenWidth * 0.02,
          mainAxisSpacing: screenHeight * 0.01,
          childAspectRatio: screenWidth > 600 ? 1.3 : 1.2,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return ValueListenableBuilder<UpdateAvailability?>(
            valueListenable: UpdateNotifier.available,
            builder: (context, update, _) {
              // 「检查更新」在检测到新版本时变成「发现新版本」+ 绿色向上箭头，
              // 与「系统」Hub 页 / 首页收藏区保持一致（形态统一由 UpdateNotifier 给）
              final isUpdate = UpdateNotifier.isUpdateEntry(item.title);
              final effective = isUpdate && update != null ? update : null;
              return FeatureButton(
                item: item,
                onTap: () => widget.onFeatureTap(item),
                isFavorited: _isFavorited(item.title),
                onToggleFavorite: () => _toggleFavorite(item.title),
                titleOverride: isUpdate
                    ? UpdateNotifier.titleFor(effective)
                    : null,
                titleColor:
                    effective == null ? null : UpdateAvailableIcon.green,
                iconOverride: effective == null
                    ? null
                    : Icon(
                        Icons.arrow_upward_rounded,
                        color: UpdateAvailableIcon.green,
                        size: MediaQuery.of(context).size.width * 0.05,
                      ),
              );
            },
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          CommonWidgetUtil.buildCommonBgWidget(),
          CommonWidgetUtil.buildCommonChiffonBgWidget(context),

          Column(
            children: [
              // 顶部栏统一走公共组件（标题是变量，直接传进去即可）
              PageTopBar(title: widget.category.name),

              // 内容区
              Expanded(
                child: Container(
                  margin: EdgeInsets.fromLTRB(4, 0, 4, 10 + safeBottom),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                    boxShadow: [defaultShadow],
                  ),
                  child: Column(
                    children: [
                      // 分类内搜索栏
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          screenWidth * 0.03,
                          screenHeight * 0.015,
                          screenWidth * 0.03,
                          0,
                        ),
                        child: QuickSearchBar(
                          onChanged: (query) {
                            setState(() => _searchQuery = query.toLowerCase());
                          },
                        ),
                      ),
                      // 功能按钮网格 — 监听登录状态实时切换按钮
                      Expanded(
                        child: ValueListenableBuilder<FavoritesPayload>(
                          valueListenable: FavoriteFeaturesNotifier.instance,
                          builder: (context, payload, _) {
                            return widget.loginStateNotifier != null
                                ? ValueListenableBuilder<bool>(
                                    valueListenable: widget.loginStateNotifier!,
                                    builder: (context, isLoggedIn, _) {
                                      return buildGrid(_buildItems(isLoggedIn));
                                    },
                                  )
                                : buildGrid(_buildItems(false));
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
