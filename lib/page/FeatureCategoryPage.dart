import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../entity/FeatureModels.dart';
import '../constant/CacheKeyConstant.dart';
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
  Set<String> _favoriteTitles = {};
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(CacheKeyConstant.favoriteFeatures) ?? [];
    if (mounted) {
      setState(() => _favoriteTitles = raw.toSet());
    }
  }

  void _toggleFavorite(String title) {
    setState(() {
      if (_favoriteTitles.contains(title)) {
        _favoriteTitles.remove(title);
      } else {
        _favoriteTitles.add(title);
      }
    });
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), _saveFavorites);
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        CacheKeyConstant.favoriteFeatures, _favoriteTitles.toList());
  }

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
          return FeatureButton(
            item: item,
            onTap: () => widget.onFeatureTap(item),
            isFavorited: _favoriteTitles.contains(item.title),
            onToggleFavorite: () => _toggleFavorite(item.title),
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
                padding: const EdgeInsets.fromLTRB(16, 48, 16, 8),
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
                    const SizedBox(width: 48),
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
