import 'package:flutter/material.dart';
import '../entity/FeatureModels.dart';
import '../utils/CommonWidgetUtil.dart';
import '../utils/AppTheme.dart';
import '../utils/AppConstants.dart';
import '../widgets/FeatureButton.dart';
import '../widgets/QuickSearchBar.dart';

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

  List<ButtonItem> _buildItems(bool isLoggedIn) {
    // 根据当前登录状态动态替换"系统"分类中的登录/登出按钮
    List<ButtonItem> items = widget.category.items.map((item) {
      if (item.title == '登录水鱼' && isLoggedIn) {
        return ButtonItem(icon: Icons.logout, title: '登出账号', subtitle: '清除水鱼登录状态');
      }
      if (item.title == '登出账号' && !isLoggedIn) {
        return ButtonItem(icon: Icons.login, title: '登录水鱼', subtitle: '获取ImportToken以便同步成绩');
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
    final safeBottom = MediaQuery.of(context).padding.bottom; // 系统底部导航栏高度
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
          return FeatureButton(
            item: items[index],
            onTap: () => widget.onFeatureTap(items[index]),
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
              // 自定义顶部栏
              Container(
                padding: EdgeInsets.fromLTRB(16, 48, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: textPrimaryColor),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          widget.category.name,
                          style: TextStyle(
                            color: textPrimaryColor,
                            fontSize: screenWidth * 0.055,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48), // 平衡返回按钮的宽度
                  ],
                ),
              ),

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
                      QuickSearchBar(
                        onChanged: (query) {
                          setState(() => _searchQuery = query.toLowerCase());
                        },
                      ),
                      // 功能按钮网格 — 监听登录状态实时切换按钮
                      Expanded(
                        child: widget.loginStateNotifier != null
                            ? ValueListenableBuilder<bool>(
                                valueListenable: widget.loginStateNotifier!,
                                builder: (context, isLoggedIn, _) {
                                  return buildGrid(_buildItems(isLoggedIn));
                                },
                              )
                            : buildGrid(_buildItems(false)),
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
