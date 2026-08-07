import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../entity/FeatureModels.dart';
import '../constant/CacheKeyConstant.dart';
import '../utils/CommonWidgetUtil.dart';
import '../utils/AppTheme.dart';
import '../utils/AppConstants.dart';
import '../widgets/FeatureButton.dart';
import '../widgets/QuickSearchBar.dart';

/// 收藏的功能页面：只展示已收藏的功能项
class FavoriteFeaturesPage extends StatefulWidget {
  final List<ButtonCategory> allCategories;
  final Future<void> Function(ButtonItem) onFeatureTap;

  const FavoriteFeaturesPage({
    super.key,
    required this.allCategories,
    required this.onFeatureTap,
  });

  @override
  State<FavoriteFeaturesPage> createState() => _FavoriteFeaturesPageState();
}

class _FavoriteFeaturesPageState extends State<FavoriteFeaturesPage> {
  Set<String> _favoriteTitles = {};
  String _searchQuery = '';

  /// 扁平化所有功能项
  List<ButtonItem> get _allItems =>
      widget.allCategories.expand((c) => c.items).toList();

  /// 已收藏的功能项（按原始分类顺序）
  List<ButtonItem> get _favoritedItems =>
      _allItems.where((item) => _favoriteTitles.contains(item.title)).toList();

  /// 过滤后的已收藏项
  List<ButtonItem> get _filteredItems {
    if (_searchQuery.isEmpty) return _favoritedItems;
    return _favoritedItems
        .where((item) =>
            item.title.toLowerCase().contains(_searchQuery) ||
            item.subtitle.toLowerCase().contains(_searchQuery))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(CacheKeyConstant.favoriteFeatures) ?? [];
    if (mounted) {
      setState(() => _favoriteTitles = raw.toSet());
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final Color textPrimaryColor = Theme.of(context).colorScheme.onSurface;

    final items = _filteredItems;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          CommonWidgetUtil.buildCommonBgWidget(),
          CommonWidgetUtil.buildCommonChiffonBgWidget(context),

          Column(
            children: [
              // 顶部栏
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
                          '收藏的功能',
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
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                    boxShadow: [AppColors.defaultShadow(brightness)],
                  ),
                  child: Column(
                    children: [
                      // 搜索栏
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

                      // 提示文字
                      if (_favoritedItems.isEmpty)
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.star_border, size: 48,
                                    color: AppColors.greyHint(brightness)),
                                const SizedBox(height: 12),
                                Text(
                                  '还没有收藏任何功能',
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.04,
                                    color: AppColors.greyHint(brightness),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '在功能分类页面中点击星标即可收藏',
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.032,
                                    color: AppColors.greyHint(brightness),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // 已收藏功能网格
                      if (items.isNotEmpty)
                        Expanded(
                          child: items.isEmpty
                              ? Center(
                                  child: Text(
                                    '未找到匹配的功能',
                                    style: TextStyle(
                                      color: AppColors.greyHint(brightness),
                                      fontSize: screenWidth * 0.04,
                                    ),
                                  ),
                                )
                              : GridView.builder(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: screenWidth * 0.03,
                                    vertical: screenHeight * 0.015,
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
                                    );
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
