import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:my_first_flutter_app/page/RankingList/RatingRankListPage.dart';
import 'package:my_first_flutter_app/page/RankingList/SpecialRankingListPage.dart';
import 'dart:convert';
import 'package:my_first_flutter_app/utils/StringUtil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/ApiUrls.dart';
import '../constant/CacheKeyConstant.dart';
import '../constant/LoadingTipsConstant.dart';
import '../service/HomeService.dart';
import '../service/PaiziProgressService.dart';
import '../service/PersonalizedScoreService.dart';
import '../service/RecommendByTagsService.dart';
import '../utils/CommonWidgetUtil.dart';
import '../manager/LZYCheckUpdateManager.dart';
import '../utils/ThemeManager.dart';
import '../utils/AppTheme.dart';
import '../utils/AppConstants.dart';
import '../service/ConnectivityService.dart';
import '../widgets/QuickSearchBar.dart';
import 'DifficultyDistributionPage.dart';import '../manager/DivingFish/UserPlayDataManager.dart';
import '../manager/DivingFish/MaimaiMusicDataManager.dart';
import '../manager/DivingFish/UnionUniManager.dart';
import '../manager/MaidataManager.dart';
import '../manager/DivingFish/DiffMusicDataManager.dart';
import '../manager/SongAliasManager.dart';
import '../manager/DivingFish/UserBest50Manager.dart';
import '../manager/LuoXue/LuoXueUserPlayDataManager.dart';
import '../entity/DivingFish/RecordItem.dart';
import '../service/RankingList/SongRankingService.dart';
import '../entity/DivingFish/Song.dart';
import '../entity/FeatureModels.dart';
import '../widgets/FeatureButton.dart';
import 'FeatureCategoryPage.dart';
import 'FavoriteFeaturesPage.dart';
import '../utils/FeatureRegistry.dart';
import 'AchievementFullReverseCalculatorPage.dart';
import 'AchievementRateCalculatorPage.dart';
import 'VersionViewPage.dart' hide AppConstants;
import 'Best50/Best50Page.dart';
import 'Best50/DiffBest50Page.dart';
import 'Best50/PersonalizedBest50Page.dart';
import 'Collection/CollectionSearchPage.dart';
import 'GuessChartGame/GuessChartByAliaPage.dart';
import 'GuessChartGame/GuessChartByBlurredCoverPage.dart';
import 'GuessChartGame/GuessChartByCoverPage.dart';
import 'GuessChartGame/GuessChartByInfoPage.dart';
import 'GuessChartGame/GuessChartBySongExcerptPage.dart';
import 'GuessChartGame/GuessSongByOpenLettersPage.dart';
import 'KaleidXScope/KaleidXScopeSelectPage.dart';
import 'KnowledgeSearchPage.dart';
import 'FavoriteFolderPage.dart';
import 'MaimaiServerStatusPage.dart';
import 'Multiplayer/MultiplayerLobbyPage.dart';
import 'PaiziProgressPage.dart';
import 'PersonalizedChartPlayConfigure.dart';
import 'PersonalizedScorePage.dart';
import 'RankTable/RankTablePage.dart';
import 'RandomChartPage.dart';
import 'RatingRecommendPage.dart';
import 'DsRangeRecommendPage.dart';
import 'RecommendByTagsPage.dart';
import 'SingleRatingCalculatorPage.dart';
import 'SongSearchPage.dart';
import 'UserScoreSearchPage.dart';
import 'AboutAppPage.dart';
import 'CoverRecognitionPage.dart';
import 'DataBackupPage.dart';
import 'DailyRecommendPage.dart';
import 'FriendComparePage.dart';
import 'RecentCommentsPage.dart';
import 'RecentRatingsPage.dart';
import 'LuoXue/UpdateLuoXueScorePage.dart';
import '../manager/LuoXue/CollectionsManager.dart';
import '../manager/DivingFishProbeManager.dart';
import '../entity/LuoXue/Collection.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:my_first_flutter_app/utils/ApiClient.dart';

// Rating上限数据类
class RatingLimits {
  final int best35Limit;
  final int best15Limit;
  final int best50Limit;

  RatingLimits({
    required this.best35Limit,
    required this.best15Limit,
    required this.best50Limit,
  });
}

// ds值与歌曲对应关系数据类
class DsSong {
  final double ds;
  final String songId;
  final String songTitle;
  final String level;

  DsSong({
    required this.ds,
    required this.songId,
    required this.songTitle,
    required this.level,
  });
}

// 首页初始化时间间隔常量
class _InitInterval {
  static const Duration initializationCooldown = Duration(days: 7);
}

// 应用常量类：集中管理所有硬编码的配置值

// ButtonItem / ButtonCategory 已移至 ../entity/FeatureModels.dart

/// 首页组件：有状态组件，包含所有页面元素和业务数据
class HomePage extends StatefulWidget {
  final VoidCallback? onFirstFrameRendered;

  const HomePage({super.key, this.onFirstFrameRendered});

  @override
  State<HomePage> createState() => _HomePageState();
}

/// 数据源枚举
enum DataSource {
  shuiyu,  // 水鱼
  luoxue,  // 落雪
}

/// 首页状态类：处理页面状态、存储数据、实现布局构建
class _HomePageState extends State<HomePage> {
  // 个人信息展示风格
  bool _useCardStyle = true; // true=卡片式，false=经典式

  // 功能搜索过滤
  String _featureSearchQuery = '';

  // 收藏的功能
  int _favoriteCount = 0;
  Set<String> _favoriteTitles = {};

  // 后台初始化状态
  bool _isBackgroundInitializing = false;
  bool _isInitializationCompleted = false;
  String _initializationProgress = '';
  
  // 用户数据
  String _userNickname = "U+5E78";
  int _best50TotalRA = 15049;
  int _best35TotalRA = 10670;
  int _best15TotalRA = 4379;
  
  // 缓存的QQ号
  String _cachedQQ = "";
  
  // 当前数据源
  DataSource _currentDataSource = DataSource.shuiyu;

  // 头像选择器
  int _selectedAvatarId = 1;
  List<Collection> _avatarIcons = [];

  // 初始化方法，用于从本地存储加载数据
  @override
  void initState() {
    super.initState();
    _loadProfileCardStyle();
    _loadUserData();
    _loadCachedAvatarId();
    _fetchAvatarIcons();
    _autoCheckUpdate();
    _checkDivingFishLoginStatus();
    _loadFavoriteCount();
    // 无论冷却状态如何，都先加载别名缓存到内存
    // 防止冷却期间别名丢失（详见：冷却逻辑在_initializeDataInBackground内）
    SongAliasManager.instance.init();
    _initializeDataInBackground();

    // 在第一帧渲染完成后触发字体加载
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onFirstFrameRendered?.call();
    });
  }
  
  // 自动检查更新
  Future<void> _autoCheckUpdate() async {
    debugPrint("首页加载时自动检查更新");
    final updateManager = LZYCheckUpdateManager();
    try {
      // 检查是否应该显示更新提示
      if (await updateManager.shouldShowUpdateDialog()) {
        var updateInfo = await updateManager.checkUpdate();
        if (updateInfo['hasUpdate'] && mounted) {
          updateManager.showUpdateDialog(context);
        }
      }
    } catch (e) {
      debugPrint("自动检查更新失败：$e");
    }
  }
  
  // 加载个人信息展示风格偏好
  Future<void> _loadProfileCardStyle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _useCardStyle = prefs.getBool(CacheKeyConstant.profileCardStyle) ?? true;
        });
      }
    } catch (e) {
      debugPrint('加载个人信息展示风格失败: $e');
    }
  }

  // 切换并保存个人信息展示风格
  Future<void> _toggleProfileCardStyle() async {
    final newStyle = !_useCardStyle;
    setState(() => _useCardStyle = newStyle);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(CacheKeyConstant.profileCardStyle, newStyle);
    } catch (e) {
      debugPrint('保存个人信息展示风格失败: $e');
    }
  }

  // 从本地存储加载用户数据
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userNickname = prefs.getString('userNickname') ?? "U+5E78";
      _best50TotalRA = prefs.getInt('best50TotalRA') ?? 15049;
      _best35TotalRA = prefs.getInt('best35TotalRA') ?? 10670;
      _best15TotalRA = prefs.getInt('best15TotalRA') ?? 4379;
      _cachedQQ = prefs.getString('cachedQQ') ?? "";
    });
  }
  
  // 更新初始化进度
  void _updateProgress(String message) {
    if (mounted) {
      setState(() => _initializationProgress = message);
    }
  }
  
  // 后台初始化数据 - 使用 HomeService
  Future<void> _initializeDataInBackground() async {
    // 检查上次初始化的时间，如果在冷却时间内则跳过自动初始化
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastInitMillis = prefs.getInt(CacheKeyConstant.lastInitializationTimestamp);
      if (lastInitMillis != null) {
        final lastInit = DateTime.fromMillisecondsSinceEpoch(lastInitMillis);
        final diff = DateTime.now().difference(lastInit);
        if (diff < _InitInterval.initializationCooldown) {
          debugPrint('距上次初始化仅 ${diff.inHours} 小时，跳过自动初始化（冷却时间：${_InitInterval.initializationCooldown.inHours} 小时）');
          return;
        }
      }
    } catch (e) {
      debugPrint('检查上次初始化时间失败: $e，继续执行初始化');
    }

    if (mounted) {
      setState(() {
        _isBackgroundInitializing = true;
        _initializationProgress = '正在初始化应用数据，请稍候...';
      });
    }
    
    final result = await HomeService().initializeDataInBackground(
      onProgress: _updateProgress,
    );
    
    if (mounted) {
      setState(() {
        _isBackgroundInitializing = false;
        if (result.success) {
          _isInitializationCompleted = true;
          _initializationProgress = '数据初始化完成！总耗时 ${result.durationStr}';
          
          // 保存本次成功初始化的时间戳
          try {
            SharedPreferences.getInstance().then((prefs) {
              prefs.setInt(
                CacheKeyConstant.lastInitializationTimestamp,
                DateTime.now().millisecondsSinceEpoch,
              );
            });
          } catch (e) {
            debugPrint('保存初始化时间戳失败: $e');
          }
          
          // 4秒后隐藏完成提示
          Future.delayed(const Duration(seconds: 4), () {
            if (mounted) {
              setState(() {
                _isInitializationCompleted = false;
                _initializationProgress = '';
              });
            }
          });
        } else {
          _initializationProgress = '初始化失败: ${result.errorMessage}\n建议检查网络连接后重启应用';
        }
      });
    }
  }
  
  // 保存用户数据到本地存储
  Future<void> _saveUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userNickname', _userNickname);
    await prefs.setInt('best50TotalRA', _best50TotalRA);
    await prefs.setInt('best35TotalRA', _best35TotalRA);
    await prefs.setInt('best15TotalRA', _best15TotalRA);
  }
  
  // 保存QQ号到本地存储
  Future<void> _saveQQ(String qq) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cachedQQ', qq);
    if (mounted) {
      setState(() {
        _cachedQQ = qq;
      });
    }
  }
  
  // 使用 ValueNotifier 以便 FeatureCategoryPage 等子页面也能响应登录状态变化
  final ValueNotifier<bool> _loginStateNotifier = ValueNotifier<bool>(false);
  bool get _isDivingFishLoggedIn => _loginStateNotifier.value;

  @override
  void dispose() {
    _loginStateNotifier.dispose();
    super.dispose();
  }

  Future<void> _checkDivingFishLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final jwt = prefs.getString(CacheKeyConstant.probeDivingFishToken) ?? '';
    if (mounted) {
      _loginStateNotifier.value = jwt.isNotEmpty;
      setState(() {});
    }
  }

  Future<void> _loadFavoriteCount() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(CacheKeyConstant.favoriteFeatures) ?? [];
    if (mounted) {
      setState(() {
        _favoriteTitles = raw.toSet();
        _favoriteCount = raw.length;
      });
    }
  }

  Future<void> _toggleFavorite(String title) async {
    setState(() {
      if (_favoriteTitles.contains(title)) {
        _favoriteTitles.remove(title);
      } else {
        _favoriteTitles.add(title);
      }
      _favoriteCount = _favoriteTitles.length;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        CacheKeyConstant.favoriteFeatures, _favoriteTitles.toList());
  }

  Future<void> _logoutDivingFish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(CacheKeyConstant.probeDivingFishToken);
    await prefs.remove(CacheKeyConstant.probeDivingFishImportToken);
    await prefs.remove(CacheKeyConstant.probeDivingFishBindQQ);
    // 清除缓存的用户标识符，防止排行榜等页面使用旧账号数据
    await prefs.remove('cachedQQ');
    await prefs.remove(CacheKeyConstant.shuiyuUserId);
    await prefs.remove(CacheKeyConstant.luoxueUserId);
    await prefs.remove(CacheKeyConstant.lastDataSource);
    if (mounted) {
      _loginStateNotifier.value = false;
      setState(() {
        _cachedQQ = '';
      });
    }
    Fluttertoast.showToast(msg: '已登出水鱼账号');
  }

  List<ButtonCategory> get _buttonCategories =>
      FeatureRegistry.allCategories(_isDivingFishLoggedIn);

  @override
  Widget build(BuildContext context) {
    // 获取屏幕尺寸
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final safeBottom = MediaQuery.of(context).padding.bottom; // 系统底部导航栏高度
    final brightness = Theme.of(context).brightness;

    // 页面根布局：Scaffold + Stack 实现多层级叠加布局
    // Stack子组件按书写顺序从上到下叠加，越靠后层级越高
    return Scaffold(
      backgroundColor: Colors.transparent, // 透明背景，显示底层图片
      resizeToAvoidBottomInset: false, // 防止输入法弹出时重新布局导致卡顿
      body: Stack(
        children: [
          // 层级1：基础背景图 - 使用通用背景Widget
          CommonWidgetUtil.buildCommonBgWidget(),

          // 层级2：第一张虚化装饰图 - 使用通用装饰背景Widget
          CommonWidgetUtil.buildCommonChiffonBgWidget(context),

          // ChiffonMai 标题
          if (_useCardStyle)
            Positioned(
              top: screenHeight * 0.08,
              left: 0,
              right: 0,
              child: Text(
                "ChiffonMai",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: screenWidth * 0.07,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          // 层级3：个人信息区域
          if (_useCardStyle)
            Positioned(
              top: screenHeight * 0.14,
              left: screenWidth * 0.03,
              right: screenWidth * 0.03,
              child: _buildProfileCard(context),
            )
          else
            ..._buildClassicProfile(context),


          // 层级5：核心功能区 - 分分类的可滚动按钮区域
          Positioned(
            left: screenWidth * 0.02,
            right: screenWidth * 0.02,
            top: _useCardStyle ? screenHeight * 0.335 : screenHeight * 0.34,
            bottom: 10 + safeBottom,
            child: Builder(
              builder: (context) {
                final brightness = Theme.of(context).brightness;
                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                boxShadow: [AppConstants.defaultShadow(brightness)],
              ),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.03, vertical: screenHeight * 0.015),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 功能搜索栏
                    QuickSearchBar(
                      onChanged: (query) {
                        setState(() => _featureSearchQuery = query.toLowerCase());
                      },
                    ),
                    // 功能中心标题
                    Center(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: screenHeight * 0.01),
                        child: Text(
                          "功能中心",
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: screenWidth * 0.045,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // 分类按钮区域（支持搜索过滤）
                    if (_featureSearchQuery.isEmpty) ...[
                      // 搜索为空：收藏的功能卡片（置顶）
                      _buildCategoryCard(
                        const ButtonCategory(name: '收藏的功能', icon: Icons.star, items: []),
                        context,
                        overrideCount: _favoriteCount,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (ctx) => FavoriteFeaturesPage(
                                allCategories: _buttonCategories,
                                onFeatureTap: _handleFeatureTap,
                              ),
                            ),
                          ).then((_) => _loadFavoriteCount());
                        },
                      ),
                      // 大类导航卡片
                      ..._buttonCategories.map((category) => _buildCategoryCard(category, context)),
                    ],
                    if (_featureSearchQuery.isNotEmpty)
                      // 搜索有内容：显示匹配的功能按钮（保持原有分类分组行为）
                      ..._buttonCategories.where((category) {
                        return category.items.any((item) =>
                          item.title.toLowerCase().contains(_featureSearchQuery) ||
                          item.subtitle.toLowerCase().contains(_featureSearchQuery));
                      }).map((category) {
                        final filteredItems = category.items.where((item) =>
                          item.title.toLowerCase().contains(_featureSearchQuery) ||
                          item.subtitle.toLowerCase().contains(_featureSearchQuery)).toList();
                        return _buildCategorySection(
                          ButtonCategory(name: category.name, items: filteredItems),
                          context,
                        );
                      }),
                  ],
                ),
              ),
              ); // Container end
            }, // Builder callback
          ), // Builder end
          ),


          // 后台初始化状态提示
          if (_isBackgroundInitializing || _isInitializationCompleted)
            Positioned(
              bottom: screenHeight * 0.06 + safeBottom,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  constraints: BoxConstraints(maxWidth: screenWidth * 0.8),
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05, vertical: screenHeight * 0.015),
                  decoration: BoxDecoration(
                    color: _isInitializationCompleted
                        ? AppColors.successGreen(brightness).withValues(alpha: 0.85)
                        : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (!_isInitializationCompleted)
                        SizedBox(
                          width: screenWidth * 0.04,
                          height: screenWidth * 0.04,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      if (!_isInitializationCompleted)
                        SizedBox(width: screenWidth * 0.02),
                      Flexible(
                        child: Text(
                          _initializationProgress,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: screenWidth * 0.03,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          ],
      ),
    );
  }

  // 从本地存储加载缓存的头像ID
  Future<void> _loadCachedAvatarId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedId = prefs.getInt('selectedAvatarId');
      if (cachedId != null && mounted) {
        setState(() => _selectedAvatarId = cachedId);
      }
    } catch (e) {
      debugPrint('加载缓存头像ID失败: $e');
    }
  }

  // 保存头像ID到本地存储
  Future<void> _saveAvatarId(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('selectedAvatarId', id);
    } catch (e) {
      debugPrint('保存头像ID失败: $e');
    }
  }

  // 获取头像列表
  Future<void> _fetchAvatarIcons() async {
    try {
      final collectionData = await CollectionsManager().fetchIconsCollections();
      if (collectionData?.icons != null && mounted) {
        setState(() => _avatarIcons = collectionData!.icons!);
      }
    } catch (e) {
      debugPrint('获取头像列表失败: $e');
    }
  }

  // 构建经典式个人信息区域（userinfobg2 风格）
  List<Widget> _buildClassicProfile(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return [
      // userinfobg2 装饰图
      Center(
        child: Transform.translate(
          offset: const Offset(0, -30),
          child: Image.asset(
            'assets/userinfobg2.png',
            fit: BoxFit.cover,
            opacity: const AlwaysStoppedAnimation(1),
          ),
        ),
      ),
      // 标题
      Positioned(
        top: screenHeight * 0.08,
        left: 0,
        right: 0,
        child: Column(
          children: [
            Text("ChiffonMai",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: screenWidth * 0.06,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: screenHeight * 0.01),
            Text("基本信息",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: screenWidth * 0.045,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      // 主题切换 + 风格切换
      Positioned(
        top: screenHeight * 0.07,
        right: screenWidth * 0.02,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _toggleProfileCardStyle,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(Icons.swap_horiz, size: 20,
                    color: Theme.of(context).colorScheme.onSurface),
              ),
            ),
            const SizedBox(width: 6),
            _buildThemeToggleButton(context),
          ],
        ),
      ),
      // 头像
      Positioned(
        left: screenWidth * 0.1,
        top: screenHeight * 0.19,
        child: _buildClassicAvatar(context),
      ),
      // 用户信息
      Positioned(
        left: screenWidth * 0.5,
        top: screenHeight * 0.21,
        child: _buildClassicUserInfo(context),
      ),
    ];
  }

  // 经典式头像
  Widget _buildClassicAvatar(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final avatarSize = screenWidth * 0.3;
    final brightness = Theme.of(context).brightness;

    return GestureDetector(
      onTap: _showAvatarPicker,
      child: Container(
        width: avatarSize,
        height: avatarSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
          border: Border.all(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              width: 1.5),
          boxShadow: [AppConstants.defaultShadow(brightness)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: 'https://assets2.lxns.net/maimai/icon/$_selectedAvatarId.png',
            placeholder: (ctx, url) =>
                Icon(Icons.person, size: 30, color: AppColors.greyHint(brightness)),
            errorWidget: (ctx, url, err) =>
                Icon(Icons.person, size: 30, color: AppColors.greyHint(brightness)),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  // 经典式用户信息
  Widget _buildClassicUserInfo(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final hasNoCachedData = _userNickname == "U+5E78";

    return GestureDetector(
      onTap: () => _showRefreshDataDialog(context),
      child: hasNoCachedData
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("请点击", style: TextStyle(color: const Color(0xFF546161), fontSize: screenWidth * 0.05, fontWeight: FontWeight.w700, letterSpacing: 1, height: 1.2)),
                Text("刷新数据", style: TextStyle(color: const Color(0xFF546161), fontSize: screenWidth * 0.05, fontWeight: FontWeight.w700, letterSpacing: 1, height: 1.2)),
                Text("刷新成绩", style: TextStyle(color: const Color(0xFF546161), fontSize: screenWidth * 0.05, fontWeight: FontWeight.w700, letterSpacing: 1, height: 1.2)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_userNickname,
                  style: TextStyle(color: const Color(0xFF546161), fontSize: screenWidth * 0.07, fontWeight: FontWeight.w700, letterSpacing: 1, height: 0.6),
                  overflow: TextOverflow.ellipsis, maxLines: 1),
                SizedBox(height: screenHeight * 0.005),
                Text("Rating", style: TextStyle(color: const Color(0xFF546161), fontSize: screenWidth * 0.045)),
                Text("$_best50TotalRA", style: TextStyle(color: const Color(0xFF546161), fontSize: screenWidth * 0.07, fontWeight: FontWeight.w600, height: 0.8)),
                Text("$_best35TotalRA+$_best15TotalRA", style: TextStyle(color: const Color(0xFF6D7D7D), fontSize: screenWidth * 0.04, fontWeight: FontWeight.w300)),
              ],
            ),
    );
  }

  // 构建个人信息卡片（头像 + 昵称 + Rating + 主题切换）
  Widget _buildProfileCard(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final brightness = Theme.of(context).brightness;
    final avatarSize = screenWidth * 0.20;
    final hasNoCachedData = _userNickname == "U+5E78";

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.04,
        vertical: screenHeight * 0.018,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
        boxShadow: [AppConstants.defaultShadow(brightness)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 第一行：标题 + 主题切换按钮
          Row(
            children: [
              Text(
                "基础信息",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: screenWidth * 0.055,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              // 风格切换按钮
              GestureDetector(
                onTap: _toggleProfileCardStyle,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(Icons.swap_horiz, size: 20,
                      color: Theme.of(context).colorScheme.onSurface),
                ),
              ),
              const SizedBox(width: 6),
              _buildThemeToggleButton(context),
            ],
          ),
          SizedBox(height: screenHeight * 0.015),
          // 第二行：头像 + 用户信息
          GestureDetector(
            onTap: () => _showRefreshDataDialog(context),
            child: Row(
              children: [
                // 头像
                GestureDetector(
                  onTap: _showAvatarPicker,
                  child: Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(
                        imageUrl: 'https://assets2.lxns.net/maimai/icon/$_selectedAvatarId.png',
                        placeholder: (ctx, url) => Icon(Icons.person, size: avatarSize * 0.4,
                            color: AppColors.greyHint(brightness)),
                        errorWidget: (ctx, url, err) => Icon(Icons.person, size: avatarSize * 0.4,
                            color: AppColors.greyHint(brightness)),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: screenWidth * 0.04),
                // 用户信息
                Expanded(
                  child: hasNoCachedData
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("请点击刷新数据",
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: screenWidth * 0.042,
                                fontWeight: FontWeight.w600,
                              )),
                            SizedBox(height: 4),
                            Text("获取你的舞萌成绩",
                              style: TextStyle(
                                color: AppColors.greyHint(brightness),
                                fontSize: screenWidth * 0.032,
                              )),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_userNickname,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: screenWidth * 0.06,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            SizedBox(height: 2),
                            Text("Rating $_best50TotalRA",
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                                fontSize: screenWidth * 0.04,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text("$_best35TotalRA + $_best15TotalRA",
                              style: TextStyle(
                                color: AppColors.greyHint(brightness),
                                fontSize: screenWidth * 0.032,
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
    );
  }

  // 显示头像选择对话框
  void _showAvatarPicker() {
    if (_avatarIcons.isEmpty) {
      Fluttertoast.showToast(msg: '头像数据尚未加载，请先刷新数据');
      return;
    }

    final screenSize = MediaQuery.of(context).size;
    final crossAxisCount = 4;
    final selectedId = _selectedAvatarId;
    final TextEditingController searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final brightness = Theme.of(ctx).brightness;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            // 根据关键词过滤头像列表
            final keyword = searchController.text.trim().toLowerCase();
            final filteredIcons = keyword.isEmpty
                ? List<Collection>.from(_avatarIcons)
                : _avatarIcons.where((icon) {
                    final matchName = icon.name.toLowerCase().contains(keyword);
                    final matchDesc = icon.description?.toLowerCase().contains(keyword) ?? false;
                    return matchName || matchDesc;
                  }).toList();
            // 将当前选中的头像移到最前面（只移动第一个匹配项）
            final selectedIndex = filteredIcons.indexWhere((icon) => icon.id == selectedId);
            if (selectedIndex > 0) {
              final selected = filteredIcons.removeAt(selectedIndex);
              filteredIcons.insert(0, selected);
            }

            return Container(
              height: screenSize.height * 0.65,
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  // 标题栏
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        const Text('选择头像', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            searchController.dispose();
                            Navigator.of(ctx).pop();
                          },
                        ),
                      ],
                    ),
                  ),
                  // 搜索栏
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: TextField(
                      controller: searchController,
                      onChanged: (_) => setSheetState(() {}),
                      decoration: InputDecoration(
                        hintText: '输入头像名称或描述搜索...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  searchController.clear();
                                  setSheetState(() {});
                                },
                              )
                            : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppColors.tableBorder(brightness)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppColors.tableBorder(brightness)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface),
                        ),
                      ),
                    ),
                  ),
                  // 搜索结果数量
                  if (keyword.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '找到 ${filteredIcons.length} 个头像',
                          style: TextStyle(fontSize: 13, color: AppColors.greyHint(brightness, shade: 600)),
                        ),
                      ),
                    ),
                  const Divider(height: 1),
                  // 头像网格
                  Expanded(
                    child: filteredIcons.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_off, size: 48, color: AppColors.greyHint(brightness, shade: 400)),
                                const SizedBox(height: 8),
                                Text('未找到匹配的头像', style: TextStyle(color: AppColors.greyHint(brightness, shade: 500))),
                              ],
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(12),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 1,
                            ),
                            itemCount: filteredIcons.length,
                            itemBuilder: (ctx, index) {
                              final iconItem = filteredIcons[index];
                              final isSelected = iconItem.id == selectedId;
                              return GestureDetector(
                                onTap: () {
                                  _saveAvatarId(iconItem.id);
                                  setState(() => _selectedAvatarId = iconItem.id);
                                  searchController.dispose();
                                  Navigator.of(ctx).pop();
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isSelected ? AppColors.warningOrange(brightness) : AppColors.tableBorder(brightness),
                                      width: isSelected ? 3 : 1,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: CachedNetworkImage(
                                      imageUrl: 'https://assets2.lxns.net/maimai/icon/${iconItem.id}.png',
                                      placeholder: (ctx, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                      errorWidget: (ctx, url, err) => const Icon(Icons.error, size: 20),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 保存上次更新使用的数据源
  Future<void> _saveLastDataSource(String dataSource) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(CacheKeyConstant.lastDataSource, dataSource);
    } catch (e) {
      debugPrint('保存上次数据源失败: $e');
    }
  }

  // 显示刷新数据对话框
  Future<void> _showRefreshDataDialog(BuildContext context) async {
    final brightness = Theme.of(context).brightness;
    
    // 水鱼：读取登录状态和绑定的QQ号
    final prefsForBind = await SharedPreferences.getInstance();
    final jwt = prefsForBind.getString(CacheKeyConstant.probeDivingFishToken) ?? '';
    final bindQQ = prefsForBind.getString(CacheKeyConstant.probeDivingFishBindQQ) ?? '';
    final bool isDivingFishLoggedIn = jwt.isNotEmpty && bindQQ.isNotEmpty;
    
    final TextEditingController qqController = TextEditingController(text: bindQQ.isNotEmpty ? bindQQ : _cachedQQ);
    final TextEditingController authCodeController = TextEditingController();
    bool isRefreshing = false;
    int progress = 0;
    String progressText = '';
    String currentLoadingTip = LoadingTipsConstant.getRandomLoadingTip();
    bool isFirstBuild = true;
    
    // 排行榜相关选项
    bool participateRankings = false;
    bool showNickname = false;
    
    // 从缓存读取排行榜设置
    Future<void> loadRankingSettings() async {
      final prefs = await SharedPreferences.getInstance();
      participateRankings = prefs.getBool(CacheKeyConstant.participateRankings) ?? false;
      showNickname = prefs.getBool(CacheKeyConstant.showNickname) ?? false;
      // 使用StatefulBuilder的setState更新UI
      setState(() {});
    }
    
    // 保存排行榜设置到缓存
    Future<void> saveRankingSettings() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(CacheKeyConstant.participateRankings, participateRankings);
      await prefs.setBool(CacheKeyConstant.showNickname, showNickname);
    }
    
    // 初始化时加载设置
    loadRankingSettings();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // 只在第一次构建时初始化
            if (isFirstBuild) {
              isFirstBuild = false;
              // 启动定时切换
              LoadingTipsConstant.startAutoSwitch(3);
              // 监听加载提示切换
              LoadingTipsConstant.tipStream.listen((tip) {
                if (isRefreshing) {
                  // 使用StatefulBuilder的context来检查mounted状态
                  try {
                    setState(() {
                      currentLoadingTip = tip;
                    });
                  } catch (_) {
                    // 忽略已销毁状态的错误
                  }
                }
              });
            }
            
            return PopScope(
              canPop: !isRefreshing,
              child: AlertDialog(
              title: Text('刷新数据'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 数据源切换
                    if (!isRefreshing)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('当前数据源：'),
                          SizedBox(width: 8),
                          ToggleButtons(
                            constraints: BoxConstraints(minHeight: 28, minWidth: 50),
                            isSelected: [
                              _currentDataSource == DataSource.shuiyu,
                              _currentDataSource == DataSource.luoxue,
                            ],
                            onPressed: (index) {
                              setState(() {
                                _currentDataSource = index == 0 ? DataSource.shuiyu : DataSource.luoxue;
                                authCodeController.clear();
                              });
                            },
                            children: [
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                child: Text('水鱼'),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                child: Text('落雪'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    if (!isRefreshing) SizedBox(height: 12),
                    
                    // 水鱼数据源：QQ号输入（需登录后自动填充）
                    if (!isRefreshing && _currentDataSource == DataSource.shuiyu)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: qqController,
                            keyboardType: TextInputType.number,
                            enabled: false,
                            decoration: InputDecoration(
                              labelText: isDivingFishLoggedIn ? '已绑定QQ号' : '请先登录水鱼账号',
                              hintText: isDivingFishLoggedIn ? bindQQ : '登录后自动填充',
                              suffixIcon: isDivingFishLoggedIn
                                  ? Icon(Icons.check_circle, color: Colors.green)
                                  : Icon(Icons.warning_amber, color: Colors.orange),
                            ),
                          ),
                          if (!isDivingFishLoggedIn)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '请先在「水鱼数据同步」中登录水鱼账号，再进行数据刷新',
                                style: TextStyle(fontSize: 12, color: AppColors.warningOrange(brightness)),
                              ),
                            ),
                        ],
                      ),
                    
                    // 落雪数据源：授权相关
                    if (!isRefreshing && _currentDataSource == DataSource.luoxue)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ElevatedButton(
                            onPressed: () async {
                              final url = LuoXueUserPlayDataManager().getAuthorizationUrl();
                              if (await canLaunchUrl(Uri.parse(url))) {
                                await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                              }
                            },
                            child: Text('点击授权'),
                          ),
                          const SizedBox(height: 8),
                          // 降级方案：复制授权链接手动打开浏览器
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.warningOrange(brightness).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.warningOrange(brightness).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.info_outline, size: 16,
                                        color: AppColors.warningOrange(brightness)),
                                    const SizedBox(width: 6),
                                    Text(
                                      '点击授权没反应？',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.warningOrange(brightness),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '请复制链接后在浏览器中手动打开完成授权：',
                                  style: TextStyle(fontSize: 12, color: AppColors.greyHint(brightness)),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.copy, size: 16),
                                  label: const Text('复制授权链接', style: TextStyle(fontSize: 13)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  onPressed: () {
                                    final url = LuoXueUserPlayDataManager().getAuthorizationUrl();
                                    Clipboard.setData(ClipboardData(text: url));
                                    Fluttertoast.showToast(msg: '授权链接已复制，请在浏览器中粘贴打开');
                                  },
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '授权后复制页面上显示的授权码，粘贴到下方输入框',
                            style: TextStyle(fontSize: 12, color: AppColors.greyHint(brightness)),
                          ),
                          SizedBox(height: 8),
                          TextField(
                            controller: authCodeController,
                            decoration: InputDecoration(
                              labelText: '请输入授权码',
                              hintText: '粘贴授权码',
                            ),
                          ),
                        ],
                      ),
                    
                    // 参与排行榜选项
                    if (!isRefreshing)
                      Column(
                        children: [
                          SizedBox(height: 16),
                          CheckboxListTile(
                            title: Text('参与排行榜'),
                            value: participateRankings,
                            onChanged: (value) {
                              setState(() {
                                participateRankings = value ?? false;
                                if (!participateRankings) {
                                  showNickname = false;
                                }
                              });
                              saveRankingSettings();
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                          // 展示昵称选项（只有勾选参与排行榜时才显示）
                          if (participateRankings)
                            CheckboxListTile(
                              title: Text('展示昵称（不勾选则显示为匿名用户）'),
                              value: showNickname,
                              onChanged: (value) {
                                setState(() {
                                  showNickname = value ?? false;
                                });
                                saveRankingSettings();
                              },
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                        ],
                      ),
                    
                    // 刷新进度显示
                    if (isRefreshing)
                      Column(
                        children: [
                          SizedBox(height: 16),
                          CircularProgressIndicator(color: AppColors.linkBlue(brightness)),
                          SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: progress / 100,
                            minHeight: 8,
                            color: AppColors.linkBlue(brightness),
                          ),
                          SizedBox(height: 8),
                          Text(
                            progressText,
                            style: TextStyle(fontSize: 14),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '$progress%',
                            style: TextStyle(fontSize: 12, color: AppColors.greyHint(brightness)),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 16),
                          // 随机加载提示
                          Text(
                            currentLoadingTip,
                            style: TextStyle(fontSize: 12, color: AppColors.greyHint(brightness, shade: 600)),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              actions: [
                if (!isRefreshing)
                  TextButton(
                    onPressed: () {
                      LoadingTipsConstant.stopAutoSwitch();
                      Navigator.of(context).pop();
                    },
                    child: Text('取消'),
                  ),
                if (!isRefreshing)
                  TextButton(
                    onPressed: () async {
                      // 水鱼数据源：检查是否已登录
                      if (_currentDataSource == DataSource.shuiyu && !isDivingFishLoggedIn) {
                        Fluttertoast.showToast(msg: '请先登录水鱼账号后再刷新数据');
                        return;
                      }
                      
                      final isOnline = await ConnectivityService().hasConnection();
                      if (!isOnline) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('当前无网络连接，无法刷新数据。请联网后重试。'), duration: Duration(seconds: 3)),
                          );
                        }
                        return;
                      }
                      setState(() {
                        isRefreshing = true;
                        progress = 0;
                        progressText = '开始刷新数据...';
                      });
                      
                      try {
                        if (_currentDataSource == DataSource.shuiyu) {
                          // 水鱼数据源
                          if (qqController.text.isNotEmpty) {
                            await _saveQQ(qqController.text);
                            await _refreshBest50DataWithProgress(
                              qqController.text, 
                              (p, t) {
                                setState(() {
                                  progress = p;
                                  progressText = t;
                                });
                              },
                              participateRankings,
                              showNickname,
                            );
                          }
                        } else {
                          // 落雪数据源
                          if (authCodeController.text.isNotEmpty) {
                            await _handleLuoXueAuthWithProgress(
                              authCodeController.text, 
                              (p, t) {
                                setState(() {
                                  progress = p;
                                  progressText = t;
                                });
                              },
                              participateRankings,
                              showNickname,
                            );
                          }
                        }
                        
                        // 刷新成功，停止定时器并关闭对话框
                        LoadingTipsConstant.stopAutoSwitch();
                        if (mounted) {
                          Navigator.of(context).pop();
                          Fluttertoast.showToast(msg: '数据刷新成功!');
                        }
                      } catch (e) {
                        // 刷新失败，停止定时器并关闭对话框
                        LoadingTipsConstant.stopAutoSwitch();
                        if (mounted) {
                          Navigator.of(context).pop();
                          Fluttertoast.showToast(msg: '刷新数据失败：$e');
                        }
                      }
                    },
                    child: Text('确认'),
                  ),
              ],
            ));
          },
        );
      },
    );
  }
  
  // 处理落雪授权（带进度回调）
  Future<void> _handleLuoXueAuthWithProgress(
    String authCode,
    Function(int, String) onProgress,
    [bool participateRankings = false,
    bool showNickname = false]
  ) async {
    try {
      onProgress(5, '正在清除缓存...');

      // 清除推荐结果缓存
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(CacheKeyConstant.recommendationResults);
        debugPrint('推荐结果缓存已清除');
      } catch (e) {
        debugPrint('清除推荐结果缓存失败: $e');
      }

      onProgress(10, '正在换取访问令牌...');

      // 使用授权码换取令牌（必须串行，需要authCode）
      final success = await LuoXueUserPlayDataManager().exchangeCodeForToken(authCode);

      if (success) {
        onProgress(15, '授权成功，正在并行刷新数据...');

        // 第二阶段：令牌获取成功后，并行执行所有独立的数据刷新请求
        int completedCount = 0;
        const totalParallelTasks = 6; // alias 改为后台执行，不计入并行任务数
        void updateParallelProgress(String message) {
          completedCount++;
          final progress = 15 + ((completedCount / totalParallelTasks) * 60).round();
          onProgress(progress, message);
        }

        final saveDataSourceFuture = _saveLastDataSource('luoxue');
        final musicFuture = MaimaiMusicDataManager().refreshDataWithSmartMaidata();
        final diffFuture = DiffMusicDataManager().fetchAndUpdateDiffData();
        final tagsFuture = RecommendByTagsService.initializeTags();
        final playerInfoFuture = LuoXueUserPlayDataManager().getPlayerInfo();
        final playerRecordsFuture = LuoXueUserPlayDataManager().getPlayerRecordsAsRecordItems();

        saveDataSourceFuture.then((_) => updateParallelProgress('数据源已保存'));
        musicFuture.then((_) => updateParallelProgress('歌曲数据已刷新'));
        diffFuture.then((_) => updateParallelProgress('难度数据已刷新'));
        tagsFuture.then((_) => updateParallelProgress('标签数据已刷新'));
        playerInfoFuture.then((_) => updateParallelProgress('玩家信息已获取'));
        playerRecordsFuture.then((_) => updateParallelProgress('玩家成绩已获取'));

        // 别名在后台刷新，不阻塞主流程
        SongAliasManager.instance.refresh().then((_) {
          debugPrint('别名数据已刷新（后台）');
        });

        await Future.wait([
          saveDataSourceFuture, musicFuture, diffFuture, tagsFuture,
          playerInfoFuture, playerRecordsFuture,
          UnionUniManager().fetchAndCache(),
        ]);

        // 处理玩家信息结果
        final playerInfo = await playerInfoFuture;
        if (playerInfo != null) {
          setState(() {
            // 将全角字符转换为半角字符
            final halfWidthName = StringUtil.toHalfWidth(playerInfo.name);
            _userNickname = halfWidthName.isNotEmpty ? halfWidthName : '未知玩家';
          });
          await _saveUserData();

          // 保存落雪用户ID（格式：luoxue:friendCode）
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('luoxue_user_id', 'luoxue:${playerInfo.friendCode}');
        }

        // 处理玩家成绩结果
        final playerRecords = await playerRecordsFuture;
        debugPrint('玩家成绩数量: ${playerRecords?.length ?? 0}');

        onProgress(85, '正在计算 Best50 数据...');

        // 从落雪数据计算并更新首页的 Best50 数据
        var luoxueRecords = playerRecords != null && playerRecords.isNotEmpty
            ? await _calculateBest50FromLuoXueRecords(playerRecords)
            : null;

        onProgress(95, '正在保存数据...');

        // 更新排行榜数据
        String? rankingError;
        if (playerInfo != null) {
          final userId = 'luoxue:${playerInfo.friendCode}';

          if (participateRankings) {
            final displayNickname = showNickname ? _userNickname : '匿名用户';
            rankingError = await _updateRankings(
              dataSource: 'luoxue',
              originalId: playerInfo.friendCode.toString(),
              nickname: displayNickname,
              totalRating: _best50TotalRA,
              best35Rating: _best35TotalRA,
              best15Rating: _best15TotalRA,
              best35Records: luoxueRecords?.best35,
              best15Records: luoxueRecords?.best15,
            );
            
            // 同步歌曲记录到Redis排行榜
            if (playerRecords != null && playerRecords.isNotEmpty) {
              final recordsMap = playerRecords.map((record) => record.toJson()).toList();
              await SongRankingService().updateSongRankings(
                userId,
                displayNickname,
                recordsMap,
              );
            }
          } else {
            // 如果不参与排行榜且有记录，删除记录
            await _deleteRankings(userId);
            await SongRankingService().deleteSongRankings(userId);
          }
        }
        
        // 清除有状态服务的记录缓存，确保下次打开时使用最新数据
        PersonalizedScoreService().clearRecordsCache();
        PaiziProgressService().clearRecordsCache();
        
        onProgress(100, '完成');
        
        // 如果有排行榜数据异常，显示警告
        if (rankingError != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('警告'),
                content: Text(rankingError!),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('确定'),
                  ),
                ],
              ),
            );
          });
        }
      } else {
        throw Exception('授权失败，请检查授权码是否正确');
      }
    } catch (e) {
      throw e;
    }
  }
  
  // 更新排行榜数据，返回异常信息（如果数据异常）
  Future<String?> _updateRankings({
    required String dataSource,
    required String originalId,
    required String nickname,
    required int totalRating,
    required int best35Rating,
    required int best15Rating,
    List<RecordItem>? best35Records,
    List<RecordItem>? best15Records,
  }) async {
    try {
      // 计算合法值上限
      final ratingLimits = await _calculateRatingLimits();

      // 验证数据合法性，收集异常信息
      List<String> errors = [];
      if (totalRating > ratingLimits.best50Limit) {
        errors.add('Best50 数据异常');
      }
      if (best35Rating > ratingLimits.best35Limit) {
        errors.add('Best35 数据异常');
      }
      if (best15Rating > ratingLimits.best15Limit) {
        errors.add('Best15 数据异常');
      }

      // 如果有异常，返回错误信息，不更新排行榜
      if (errors.isNotEmpty) {
        final errorMsg = errors.join('、');
        debugPrint('警告: $errorMsg，跳过排行榜更新');
        debugPrint('  用户数据: Best50=$totalRating, Best35=$best35Rating, Best15=$best15Rating');
        debugPrint('  理论上限: Best50=${ratingLimits.best50Limit}, Best35=${ratingLimits.best35Limit}, Best15=${ratingLimits.best15Limit}');

        // 打印用户 Best35 记录
        if (best35Records != null && best35Records.isNotEmpty) {
          final sorted = List<RecordItem>.from(best35Records)..sort((a, b) => b.ra.compareTo(a.ra));
          debugPrint('  --- 用户 Best35 记录 (按RA降序) ---');
          for (int i = 0; i < sorted.length; i++) {
            final r = sorted[i];
            debugPrint('  ${i + 1}. RA=${r.ra} 定数=${r.ds} songId=${r.songId} title=${r.title} level=${r.level}');
          }
        }

        // 打印用户 Best15 记录
        if (best15Records != null && best15Records.isNotEmpty) {
          final sorted = List<RecordItem>.from(best15Records)..sort((a, b) => b.ra.compareTo(a.ra));
          debugPrint('  --- 用户 Best15 记录 (按RA降序) ---');
          for (int i = 0; i < sorted.length; i++) {
            final r = sorted[i];
            debugPrint('  ${i + 1}. RA=${r.ra} 定数=${r.ds} songId=${r.songId} title=${r.title} level=${r.level}');
          }
        }

        return '$errorMsg，可能存在非法数据，请检查';
      }
      
      final response = await ApiClient.post(
        Uri.parse(ApiUrls.RankingsUpdateUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'dataSource': dataSource,
          'originalId': originalId,
          'nickname': nickname,
          'totalRating': totalRating,
          'best35Rating': best35Rating,
          'best15Rating': best15Rating,
        }),
      );
      
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          debugPrint('排行榜数据更新成功: ${result['message']}');
        } else {
          debugPrint('排行榜数据更新失败: ${result['error']}');
        }
      } else {
        debugPrint('排行榜数据更新失败，状态码: ${response.statusCode}');
      }
      return null;
    } catch (e) {
      debugPrint('更新排行榜数据时发生异常: $e');
      return null;
    }
  }
  
  // 删除排行榜记录
  Future<void> _deleteRankings(String userId) async {
    try {
      final response = await ApiClient.delete(
        Uri.parse('${ApiUrls.RankingsBaseUrl}/user/$userId'),
      );
      
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          debugPrint('排行榜记录删除成功: ${result['message']}');
        } else {
          debugPrint('排行榜记录删除失败: ${result['error']}');
        }
      } else {
        debugPrint('排行榜记录删除失败，状态码: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('删除排行榜记录时发生异常: $e');
    }
  }
  
  // 计算Rating合法值上限
  Future<RatingLimits> _calculateRatingLimits() async {
    final musicManager = MaimaiMusicDataManager();
    final songs = await musicManager.getCachedSongs();
    
    if (songs == null || songs.isEmpty) {
      debugPrint('警告: 歌曲缓存为空，使用默认Rating上限');
      return RatingLimits(best35Limit: 12000, best15Limit: 5000, best50Limit: 17000);
    }
    
    // 获取从maidata追加的歌曲ID列表
    final addedSongIds = await musicManager.getAddedSongIds() ?? [];
    
    // 过滤掉ID为6位数的歌曲和从maidata追加的歌曲
    final filteredSongs = songs.where((song) {
      // 过滤掉从maidata追加的歌曲
      if (addedSongIds.contains(song.id)) {
        return false;
      }
      // 过滤掉union API独有的歌曲
      if (song.isExtra) {
        return false;
      }
      // 过滤掉ID为6位数的歌曲
      final id = song.id;
      if (id.length == 6 && RegExp(r'^\d+$').hasMatch(id)) {
        final numId = int.parse(id);
        return numId < 100000 || numId > 999999;
      }
      return true;
    }).toList();
    
    // 根据is_new分类
    final best35Candidates = filteredSongs
        .where((song) => song.basicInfo.isNew == false)
        .toList();
    final best15Candidates = filteredSongs
        .where((song) => song.basicInfo.isNew == true)
        .toList();
    
    // 提取所有ds值及对应的歌曲信息并排序
    List<DsSong> best35DsSongs = [];
    for (var song in best35Candidates) {
      for (int i = 0; i < song.ds.length; i++) {
        final ds = song.ds[i];
        if (ds != null) {
          final level = i < song.level.length ? song.level[i] : '';
          best35DsSongs.add(DsSong(
            ds: ds,
            songId: song.id,
            songTitle: song.title,
            level: level,
          ));
        }
      }
    }
    best35DsSongs.sort((a, b) => b.ds.compareTo(a.ds));
    
    List<DsSong> best15DsSongs = [];
    for (var song in best15Candidates) {
      for (int i = 0; i < song.ds.length; i++) {
        final ds = song.ds[i];
        if (ds != null) {
          final level = i < song.level.length ? song.level[i] : '';
          best15DsSongs.add(DsSong(
            ds: ds,
            songId: song.id,
            songTitle: song.title,
            level: level,
          ));
        }
      }
    }
    best15DsSongs.sort((a, b) => b.ds.compareTo(a.ds));
    
    // 取前35和前15个最高值计算
    final top35DsSongs = best35DsSongs.take(35).toList();
    final top15DsSongs = best15DsSongs.take(15).toList();
    
    // 计算公式: ds * 0.224 * 100.5 并向下取整
    int calculateRating(List<DsSong> dsSongs) {
      return dsSongs.fold(0, (sum, dsSong) => sum + (dsSong.ds * 0.224 * 100.5).floor());
    }
    
    final best35Limit = calculateRating(top35DsSongs);
    final best15Limit = calculateRating(top15DsSongs);
    final best50Limit = best35Limit + best15Limit;
    
    // 输出到控制台
    debugPrint('=== Rating 合法值上限计算结果 ===');
    debugPrint('Best35 歌曲数量: ${best35Candidates.length}');
    debugPrint('Best15 歌曲数量: ${best15Candidates.length}');
    
    // 输出Best35最高35个ds值及对应歌曲
    debugPrint('--- Best35 最高35个ds值及对应歌曲 ---');
    for (int i = 0; i < top35DsSongs.length; i++) {
      final dsSong = top35DsSongs[i];
      final ra = (dsSong.ds * 0.224 * 100.5).floor();
      debugPrint('${i + 1}. ds=${dsSong.ds}, ra=$ra, level=${dsSong.level}, title=${dsSong.songTitle}, id=${dsSong.songId}');
    }
    
    // 输出Best15最高15个ds值及对应歌曲
    debugPrint('--- Best15 最高15个ds值及对应歌曲 ---');
    for (int i = 0; i < top15DsSongs.length; i++) {
      final dsSong = top15DsSongs[i];
      final ra = (dsSong.ds * 0.224 * 100.5).floor();
      debugPrint('${i + 1}. ds=${dsSong.ds}, ra=$ra, level=${dsSong.level}, title=${dsSong.songTitle}, id=${dsSong.songId}');
    }
    
    debugPrint('=== Rating 上限值 ===');
    debugPrint('Best35 总Rating上限: $best35Limit');
    debugPrint('Best15 总Rating上限: $best15Limit');
    debugPrint('Best50 总Rating上限: $best50Limit');
    debugPrint('==================================');
    
    return RatingLimits(
      best35Limit: best35Limit,
      best15Limit: best15Limit,
      best50Limit: best50Limit,
    );
  }
  
  // 刷新Best50数据（带进度回调）
  Future<void> _refreshBest50DataWithProgress(
    String qq, 
    Function(int, String) onProgress,
    [bool participateRankings = false,
    bool showNickname = false]
  ) async {
    try {
      onProgress(5, '正在清除缓存...');

      // 清除推荐结果缓存
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(CacheKeyConstant.recommendationResults);
        debugPrint('推荐结果缓存已清除');
      } catch (e) {
        debugPrint('清除推荐结果缓存失败: $e');
      }

      // 保存当前数据源
      await _saveLastDataSource('shuiyu');

      // 第二阶段：并行执行所有独立的数据刷新请求
      onProgress(10, '正在并行刷新数据...');

      int completedCount = 0;
      const totalParallelTasks = 5; // alias 改为后台执行，不计入并行任务数
      void updateParallelProgress(String message) {
        completedCount++;
        final progress = 10 + ((completedCount / totalParallelTasks) * 65).round();
        onProgress(progress, message);
      }

      final musicFuture = MaimaiMusicDataManager().refreshDataWithSmartMaidata();
      final diffFuture = DiffMusicDataManager().fetchAndUpdateDiffData();
      final tagsFuture = RecommendByTagsService.initializeTags();
      final userPlayDataFuture = UserPlayDataManager().fetchUserPlayData(qq);
      final best50Future = UserBest50Manager().getUserBest50(qq);

      musicFuture.then((_) => updateParallelProgress('歌曲数据已刷新'));
      diffFuture.then((_) => updateParallelProgress('难度数据已刷新'));
      tagsFuture.then((_) => updateParallelProgress('标签数据已刷新'));
      userPlayDataFuture.then((_) => updateParallelProgress('用户数据已获取'));
      best50Future.then((_) => updateParallelProgress('Best50数据已获取'));

      // 别名在后台刷新，不阻塞主流程
      SongAliasManager.instance.refresh().then((_) {
        debugPrint('别名数据已刷新（后台）');
      });

      await Future.wait([
        musicFuture, diffFuture, tagsFuture,
        userPlayDataFuture, best50Future,
        UnionUniManager().fetchAndCache(),
      ]);

      final userPlayData = await userPlayDataFuture;
      final best50Data = await best50Future;
      debugPrint(best50Data.toString());
      
      // 更新用户昵称
      if (userPlayData != null && userPlayData.containsKey('nickname')) {
        if (mounted) {
          setState(() {
            _userNickname = userPlayData['nickname'];
          });
        }
      }
      
      onProgress(85, '正在计算Rating...');

      // 计算Best50、Best35、Best15总RA
      int totalRA = 0;
      int best35RA = 0;
      int best15RA = 0;
      
      // 计算Best35总RA (sd charts)
      for (var record in best50Data.charts.sd) {
        best35RA += record.ra;
      }
      
      // 计算Best15总RA (dx charts)
      for (var record in best50Data.charts.dx) {
        best15RA += record.ra;
      }
      
      // 计算Best50总RA (sd + dx)
      totalRA = best35RA + best15RA;
      
      // 更新状态
      if (mounted) {
        setState(() {
          _best50TotalRA = totalRA;
          _best35TotalRA = best35RA;
          _best15TotalRA = best15RA;
        });
      }
      
      onProgress(95, '正在保存数据...');

      // 保存数据到本地存储
      await _saveUserData();
      
      // 清除有状态服务的记录缓存，确保下次打开时使用最新数据
      PersonalizedScoreService().clearRecordsCache();
      PaiziProgressService().clearRecordsCache();
      
      // 更新排行榜数据
      String? rankingError;
      final userId = 'shuiyu:$qq';

      // 保存水鱼用户ID到本地存储
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('shuiyu_user_id', userId);

      if (participateRankings) {
        final displayNickname = showNickname ? _userNickname : '匿名用户';
        rankingError = await _updateRankings(
          dataSource: 'shuiyu',
          originalId: qq,
          nickname: displayNickname,
          totalRating: _best50TotalRA,
          best35Rating: _best35TotalRA,
          best15Rating: _best15TotalRA,
          best35Records: best50Data.charts.sd,
          best15Records: best50Data.charts.dx,
        );

        // 同步歌曲记录到Redis排行榜
        if (userPlayData != null && userPlayData['records'] is List) {
          final records = userPlayData['records'] as List;
          if (records.isNotEmpty) {
            await SongRankingService().updateSongRankings(
              userId,
              displayNickname,
              records.cast<Map<String, dynamic>>(),
            );
          }
        }
      } else {
        // 如果不参与排行榜且有记录，删除记录
        await _deleteRankings(userId);
        await SongRankingService().deleteSongRankings(userId);
      }
      
      // 清除有状态服务的记录缓存，确保下次打开时使用最新数据
      PersonalizedScoreService().clearRecordsCache();
      PaiziProgressService().clearRecordsCache();
      
      onProgress(100, '完成');
      
      // 如果有排行榜数据异常，显示警告
      if (rankingError != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('警告'),
              content: Text(rankingError!),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('确定'),
                ),
              ],
            ),
          );
        });
      }
    } catch (e) {
      throw e;
    }
  }

  // 同步成功后自动刷新首页数据（成绩 + Best50 + 排行榜）
  // 调用前需确保 _cachedQQ / bind_qq 已保存
  Future<void> _autoRefreshAfterSync({
    Future<void> Function(double progress, String text)? onProgress,
  }) async {
    final qq = _cachedQQ.isNotEmpty ? _cachedQQ : null;

    if (qq == null || qq.isEmpty) {
      debugPrint('[HomePage] _autoRefreshAfterSync: QQ 为空，跳过刷新');
      return;
    }

    debugPrint('[HomePage] _autoRefreshAfterSync: 使用 QQ=$qq 自动刷新');

    await _refreshBest50DataWithProgress(
      qq,
      (p, t) async {
        debugPrint('[HomePage] 后台刷新 $p%: $t');
        await onProgress?.call(0.70 + (p / 100) * 0.30, t);
      },
      await _getParticipateRankings(),
      await _getShowNickname(),
    );
    debugPrint('[HomePage] _autoRefreshAfterSync: 完成');
  }

  Future<bool> _getParticipateRankings() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(CacheKeyConstant.participateRankings) ?? false;
  }

  Future<bool> _getShowNickname() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(CacheKeyConstant.showNickname) ?? false;
  }

  // 显示同步成绩对话框，返回 friendCode 表示同步成功
  Future<String?> _showSyncScoreDialog(BuildContext context) async {
    final brightness = Theme.of(context).brightness;
    final TextEditingController qrController = TextEditingController();
    final TextEditingController dfUserController = TextEditingController();
    final TextEditingController dfPassController = TextEditingController();
    bool isSyncing = false;
    bool needDivingFishToken = false;
    bool isBinding = false;
    String statusText = '';
    String? bindingError;
    double? progress;
    SyncStage? currentStage;

    // 排行榜选项（与刷新数据对话框公用 prefs 缓存）
    bool participateRankings = false;
    bool showNickname = false;

    // 从缓存读取排行榜设置
    Future<void> loadRankingSettings() async {
      final prefs = await SharedPreferences.getInstance();
      participateRankings = prefs.getBool(CacheKeyConstant.participateRankings) ?? false;
      showNickname = prefs.getBool(CacheKeyConstant.showNickname) ?? false;
    }

    Future<void> saveRankingSettings() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(CacheKeyConstant.participateRankings, participateRankings);
      await prefs.setBool(CacheKeyConstant.showNickname, showNickname);
    }

    loadRankingSettings();

    final String? result = await showDialog<String?>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        Timer? _autoCloseTimer;
        int _countdown = 3;
        String _currentTip = LoadingTipsConstant.getRandomLoadingTip();
        StreamSubscription<String>? _tipSub;
        return StatefulBuilder(
          builder: (context, setState) {
            // 完成态：点击空白可关闭 + 3 秒倒计时自动关闭
            final isDone = currentStage == SyncStage.completed ||
                currentStage == SyncStage.failed ||
                currentStage == SyncStage.cancelled;

            if (isDone && _autoCloseTimer == null) {
              void tick() {
                _countdown--;
                if (_countdown > 0) {
                  setState(() {}); // 刷新按钮文字
                  _autoCloseTimer = Timer(const Duration(seconds: 1), tick);
                } else {
                  if (Navigator.of(dialogContext).canPop()) {
                    Navigator.of(dialogContext).pop();
                  }
                }
              }
              _autoCloseTimer = Timer(const Duration(seconds: 1), tick);
            }

            return PopScope(
              canPop: !isSyncing && !isBinding,
              child: AlertDialog(
              title: Row(
                children: [
                  Icon(
                    needDivingFishToken ? Icons.link : Icons.qr_code_scanner,
                    color: Theme.of(context).colorScheme.onSurface,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(needDivingFishToken ? '绑定水鱼账号' : '同步成绩到水鱼'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ===== 阶段 1：输入 QR 码 =====
                    if (!isSyncing && !needDivingFishToken) ...[
                      Text(
                        '在舞萌|中二公众号请求并打开二维码，扫描后将字符串粘贴到下方：',
                        style: TextStyle(fontSize: 13, color: AppColors.greyHint(brightness)),
                      ),
                      const SizedBox(height: 12),
                      // 多方式导入按钮
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildClipboardButton(setState, qrController),
                          _buildGalleryQrButton(setState, qrController),
                          _buildCameraScanButton(setState, qrController, dialogContext),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: qrController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: '舞萌DX | 中二节奏 登入二维码(SGWCMAID...)',
                          hintStyle: TextStyle(fontSize: 13, color: AppColors.greyHint(brightness, shade: 400)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        title: const Text('参与排行榜', style: TextStyle(fontSize: 14)),
                        value: participateRankings,
                        onChanged: (value) {
                          setState(() {
                            participateRankings = value ?? false;
                            if (!participateRankings) showNickname = false;
                          });
                          saveRankingSettings();
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (participateRankings)
                        CheckboxListTile(
                          title: const Text('展示昵称（不勾选则显示为匿名用户）',
                              style: TextStyle(fontSize: 13)),
                          value: showNickname,
                          onChanged: (value) {
                            setState(() => showNickname = value ?? false);
                            saveRankingSettings();
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                    ],

                    // ===== 阶段 2：绑定水鱼账号 =====
                    if (needDivingFishToken) ...[
                      Text(
                        '成绩已抓取成功！但要推送到水鱼，需要先绑定你的水鱼账号：',
                        style: TextStyle(fontSize: 13, color: AppColors.greyHint(brightness)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: dfUserController,
                        decoration: InputDecoration(
                          labelText: '水鱼用户名',
                          hintText: '输入 Diving-Fish 用户名',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: dfPassController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: '水鱼密码',
                          hintText: '输入 Diving-Fish 密码',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10,
                          ),
                        ),
                      ),
                      if (bindingError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          bindingError!,
                          style: TextStyle(fontSize: 12, color: AppColors.errorRed(brightness)),
                        ),
                      ],
                    ],

                    // ===== 同步进度 =====
                    if (isSyncing && !needDivingFishToken) ...[
                      // 同步中：随机 Tips + 警告
                      if (currentStage != SyncStage.completed &&
                          currentStage != SyncStage.failed &&
                          currentStage != SyncStage.cancelled) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.warningOrange(brightness).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.warningOrange(brightness).withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, size: 16, color: AppColors.warningOrange(brightness)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '同步进行中，请耐心等待，不要进行其他操作',
                                  style: TextStyle(fontSize: 12, color: AppColors.warningOrange(brightness)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            ),
                          ),
                        ),
                      ],

                      // 完成/失败/取消：阶段图标
                      if (currentStage == SyncStage.completed ||
                          currentStage == SyncStage.failed ||
                          currentStage == SyncStage.cancelled) ...[
                        const SizedBox(height: 8),
                        Center(child: _buildStageIcon(currentStage, brightness)),
                        const SizedBox(height: 8),
                      ],
                      Center(
                        child: Text(
                          statusText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: currentStage == SyncStage.failed ||
                                    currentStage == SyncStage.cancelled
                                ? AppColors.errorRed(brightness)
                                : currentStage == SyncStage.completed
                                    ? AppColors.successGreen(brightness)
                                    : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (currentStage != SyncStage.completed &&
                          currentStage != SyncStage.failed &&
                          currentStage != SyncStage.cancelled) ...[
                        const SizedBox(height: 10),
                        if (progress != null)
                          LinearProgressIndicator(value: progress, color: AppColors.linkBlue(brightness))
                        else
                          LinearProgressIndicator(color: AppColors.linkBlue(brightness)),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            _currentTip,
                            style: TextStyle(fontSize: 12, color: AppColors.greyHint(brightness, shade: 600)),
                          ),
                        ),
                      ],
                      if (currentStage == SyncStage.completed) ...[
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            '成绩已同步！可前往水鱼查看',
                            style: TextStyle(fontSize: 12, color: AppColors.greyHint(brightness, shade: 600)),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              actions: [
                // ---- 初始/失败/完成：关闭按钮 ----
                if (!isSyncing && !needDivingFishToken)
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('关闭'),
                  ),
                if (isSyncing &&
                    (currentStage == SyncStage.completed ||
                        currentStage == SyncStage.failed ||
                        currentStage == SyncStage.cancelled))
                  TextButton(
                    onPressed: () {
                      _autoCloseTimer?.cancel();
                      final fc = currentStage == SyncStage.completed
                          ? DivingFishProbeManager().currentFriendCode
                          : null;
                      Navigator.of(dialogContext).pop(fc);
                    },
                    child: Text(
                      _countdown > 0 ? '确定 ($_countdown)' : '确定',
                    ),
                  ),

                // ---- 绑定水鱼账号页面：关闭 & 绑定 ----
                if (needDivingFishToken) ...[
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('跳过'),
                  ),
                  ElevatedButton.icon(
                    icon: isBinding
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.link, size: 18),
                    label: Text(isBinding ? '绑定中...' : '绑定并同步'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.linkBlue(brightness),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: isBinding
                        ? null
                        : () async {
                            final username = dfUserController.text.trim();
                            final password = dfPassController.text.trim();
                            if (username.isEmpty || password.isEmpty) {
                              setState(() {
                                bindingError = '请输入水鱼用户名和密码';
                              });
                              return;
                            }

                            setState(() {
                              isBinding = true;
                              bindingError = null;
                            });

                            final ok = await DivingFishProbeManager()
                                .bindDivingFishAccount(username, password);

                            if (!ok) {
                              setState(() {
                                isBinding = false;
                                bindingError = '绑定失败，请检查用户名密码是否正确';
                              });
                              return;
                            }

                            // 绑定成功 → 同步缓存水鱼 JWT（用于后续 fetchBindQQ）
                            _log('Hub 绑定成功，同步直登水鱼以缓存 JWT...');
                            await DivingFishProbeManager()
                                .loginDivingFishDirect(username, password);

                            // 重试导出
                            _log('重试导出到水鱼...');
                            final exportData =
                                await DivingFishProbeManager().exportToDivingFish();

                            if (exportData != null &&
                                (exportData.tryGet<int>('status') ?? 0) == 200) {
                              final count = exportData.tryGet<int>('exported') ?? 0;

                              // 自动刷新本地数据
                              setState(() {
                                statusText = '同步成功！正在刷新本地数据...';
                              });
                              String? qq = _cachedQQ.isNotEmpty ? _cachedQQ : null;
                              if (qq == null) {
                                qq = await DivingFishProbeManager().fetchBindQQ();
                              }
                              if (qq != null && qq.isNotEmpty) {
                                await _saveQQ(qq);
                                await _saveLastDataSource('shuiyu');
                              }
                              await _autoRefreshAfterSync(
                                onProgress: (p, t) async {
                                  setState(() {
                                    progress = p;
                                    statusText = t;
                                  });
                                  await Future.delayed(const Duration(milliseconds: 80));
                                },
                              );

                              Fluttertoast.showToast(
                                  msg: '全部完成！$count 条成绩已同步，本地数据已刷新');
                              final fc = DivingFishProbeManager().currentFriendCode;
                              Navigator.of(dialogContext).pop(fc);
                            } else {
                              setState(() {
                                isBinding = false;
                                bindingError = '导出失败，请稍后重试';
                              });
                            }
                          },
                  ),
                ],

                // ---- 初始：开始同步按钮 ----
                if (!isSyncing && !needDivingFishToken)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text('开始同步'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.linkBlue(brightness),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final qrCode = qrController.text.trim();
                      if (qrCode.isEmpty) {
                        Fluttertoast.showToast(msg: '请先粘贴舞萌|中二登入二维码字符串');
                        return;
                      }

                      setState(() {
                        isSyncing = true;
                        statusText = '准备同步...';
                        currentStage = SyncStage.authenticating;
                      });

                      LoadingTipsConstant.startAutoSwitch(3);
                      _tipSub?.cancel();
                      _tipSub = LoadingTipsConstant.tipStream.listen((tip) {
                        setState(() => _currentTip = tip);
                      });

                      // 验证二维码格式：必须为 SGWCMAID 开头
                      if (!qrCode.startsWith('SGWCMAID')) {
                        setState(() {
                          currentStage = SyncStage.failed;
                          statusText = '无效的二维码，请使用舞萌|中二公众号生成的登入二维码';
                          isSyncing = false;
                        });
                        LoadingTipsConstant.stopAutoSwitch();
                        _tipSub?.cancel();
                        return;
                      }

                      final result = await DivingFishProbeManager().syncByCabinetQr(
                        qrCode,
                        onProgress: (p) {
                          setState(() {
                            currentStage = p.stage;
                            statusText = p.message;
                            progress = _stageProgress(p);
                          });
                        },
                      );

                      LoadingTipsConstant.stopAutoSwitch();
                      _tipSub?.cancel();

                      if (result.isSuccess) {
                        // ===== 同步成功 → 先展示过渡态 =====
                        setState(() {
                          currentStage = SyncStage.exporting;
                          statusText = '同步成功！正在刷新本地数据...';
                          progress = 0.70;
                        });
                        // 让 UI 先渲染出 70% 和过渡文字
                        await Future.delayed(const Duration(milliseconds: 300));

                        // 确保 QQ 已保存
                        String? qq = _cachedQQ.isNotEmpty ? _cachedQQ : null;
                        if (qq == null) {
                          qq = await DivingFishProbeManager().fetchBindQQ();
                        }
                        final hasQQ = qq != null && qq.isNotEmpty;
                        if (hasQQ) {
                          await _saveQQ(qq);
                          await _saveLastDataSource('shuiyu');
                        }

                        if (hasQQ) {
                          await _autoRefreshAfterSync(
                            onProgress: (p, t) async {
                              setState(() {
                                progress = p;
                                statusText = t;
                              });
                              await Future.delayed(const Duration(milliseconds: 80));
                            },
                          );
                        } else {
                          // 没有 QQ，假装走一段进度让用户看到
                          for (int i = 0; i < 4; i++) {
                            setState(() => progress = 0.70 + (i + 1) * 0.05);
                            await Future.delayed(const Duration(milliseconds: 200));
                          }
                        }

                        setState(() {
                          currentStage = SyncStage.completed;
                          progress = 1.0;
                          if (hasQQ) {
                            statusText = '全部完成！${result.exportedCount} 条成绩已同步，本地数据已刷新';
                          } else {
                            statusText = '同步完成！${result.exportedCount} 条成绩已推送到水鱼\n（需先登录水鱼才能自动刷新本地数据）';
                          }
                        });
                      } else if (result.errorMessage == '用户取消同步') {
                        setState(() {
                          currentStage = SyncStage.cancelled;
                          statusText = '同步已取消';
                        });
                      } else {
                        final msg = result.errorMessage ?? '';
                        if (msg.contains('divingFishImportToken') ||
                            msg.contains('missing')) {
                          needDivingFishToken = true;
                          isSyncing = false;
                          _log('检测到缺少水鱼 importToken，切换到绑定界面');
                        } else {
                          setState(() {
                            currentStage = SyncStage.failed;
                            statusText = msg;
                          });
                        }
                      }
                    },
                  ),
              ],
          ),); // PopScope closing
          },
        );
      },
    );
    return result;
  }

  // 将同步阶段映射为 0~1 的进度值（总范围 0~0.70，刷新占 0.70~1.0）
  double _stageProgress(SyncProgress p) {
    switch (p.stage) {
      case SyncStage.authenticating:
        return 0.02;
      case SyncStage.requesting:
        return 0.10;
      case SyncStage.sendingFriendRequest:
        return 0.18;
      case SyncStage.waitingAcceptance:
        return 0.25;
      case SyncStage.scraping:
        // 抓取阶段：25%~65%，由实际 diffs 进度填充
        return 0.25 + (p.progress ?? 0) * 0.40;
      case SyncStage.exporting:
        return 0.68;
      default:
        return 0.0;
    }
  }

  // 调试日志（HomePage 内用，避免和 DivingFishProbeManager 混淆）
  void _log(String msg) {
    debugPrint('[HomePage-Sync] $msg');
  }

  // 显示水鱼登录对话框
  void _showDivingFishLoginDialog(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final TextEditingController userController = TextEditingController();
    final TextEditingController passController = TextEditingController();
    bool isLoggingIn = false;
    bool loginSuccess = false;
    String? importedToken;
    String statusText = '';
    String? errorMsg;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    loginSuccess ? Icons.check_circle : Icons.login,
                    color: loginSuccess ? AppColors.successGreen(brightness) : Theme.of(context).colorScheme.onSurface,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(loginSuccess ? '登录成功' : '登录水鱼'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!loginSuccess) ...[
                      Text(
                        '输入你的 Diving-Fish 水鱼账号密码以获取 ImportToken：',
                        style: TextStyle(fontSize: 13, color: AppColors.greyHint(brightness)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: userController,
                        decoration: InputDecoration(
                          labelText: '用户名',
                          hintText: 'Diving-Fish 用户名',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: passController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: '密码',
                          hintText: 'Diving-Fish 密码',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10,
                          ),
                        ),
                      ),
                      if (errorMsg != null) ...[
                        const SizedBox(height: 8),
                        Text(errorMsg!, style: TextStyle(fontSize: 12, color: AppColors.errorRed(brightness))),
                      ],
                    ] else ...[
                      Icon(Icons.check_circle, color: AppColors.successGreen(brightness), size: 48),
                      const SizedBox(height: 12),
                      Text(
                        statusText.isNotEmpty ? statusText : '登录成功',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ImportToken 已获取并缓存',
                        style: TextStyle(fontSize: 13, color: AppColors.greyHint(brightness)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Token: ${importedToken ?? "***"}',
                        style: TextStyle(fontSize: 11, color: AppColors.greyHint(brightness, shade: 600)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '现在可以使用"同步成绩"功能一键同步到水鱼了',
                        style: TextStyle(fontSize: 12, color: AppColors.greyHint(brightness)),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(loginSuccess ? '完成' : '取消'),
                ),
                if (!loginSuccess)
                  ElevatedButton.icon(
                    icon: isLoggingIn
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.login, size: 18),
                    label: Text(isLoggingIn ? '登录中...' : '登录'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.linkBlue(brightness),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: isLoggingIn
                        ? null
                        : () async {
                            final username = userController.text.trim();
                            final password = passController.text.trim();
                            if (username.isEmpty || password.isEmpty) {
                              setState(() => errorMsg = '请输入用户名和密码');
                              return;
                            }
                            setState(() {
                              isLoggingIn = true;
                              errorMsg = null;
                            });

                            final result = await DivingFishProbeManager()
                                .loginDivingFishDirect(username, password);

                            if (result != null && result.tryGet<String>('importToken') != null) {
                              final token = result.tryGet<String>('importToken') ?? '';
                              final nickname = result.tryGet<String>('nickname') ?? '';
                              final plate = result.tryGet<String>('plate') ?? '';
                              setState(() {
                                isLoggingIn = false;
                                loginSuccess = true;
                                importedToken = token.isNotEmpty
                                    ? '${token.substring(0, token.length > 12 ? 12 : token.length)}...'
                                    : '***';
                                statusText = '欢迎，$nickname${plate.isNotEmpty ? " ($plate)" : ""}';
                              });
                              // 登录成功后立即更新缓存的QQ号，确保排行榜等页面使用新账号标识
                              final bindQQ = result.tryGet<String>('bind_qq') ?? '';
                              if (bindQQ.isNotEmpty) {
                                await _saveQQ(bindQQ);
                              }
                              _checkDivingFishLoginStatus();
                            } else {
                              setState(() {
                                isLoggingIn = false;
                                errorMsg = '登录失败：用户名或密码错误';
                              });
                            }
                          },
                  ),
              ],
            );
          },
        );
      },
    );
  }

  // 右上角主题快捷切换按钮
  Widget _buildThemeToggleButton(BuildContext context) {
    final currentMode = ThemeManager().themeMode;
    final isDark = currentMode == ThemeMode.dark;
    return GestureDetector(
      onTap: () {
        if (isDark) {
          ThemeManager().setThemeMode(ThemeMode.light);
        } else {
          ThemeManager().setThemeMode(ThemeMode.dark);
        }
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withOpacity(0.7),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          isDark ? Icons.dark_mode : Icons.light_mode,
          size: 20,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  // 显示主题切换对话框
  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final currentMode = ThemeManager().themeMode;
          final isDarkSelected = currentMode == ThemeMode.dark;
          final pureBlackEnabled = ThemeManager().pureBlackEnabled;
          final overlayOpacity = ThemeManager().lightOverlayOpacity;
          final brightness = Theme.of(context).brightness;
          return AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: Text('主题设置', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 背景强度（浅色/深色模式共用）
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('背景强度',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14)),
                          Text('${(overlayOpacity * 100).round()}%',
                            style: TextStyle(color: AppColors.linkBlue(brightness), fontSize: 13)),
                        ],
                      ),
                      Slider(
                        value: overlayOpacity,
                        min: 0.0,
                        max: 1.0,
                        divisions: 20,
                        label: '${(overlayOpacity * 100).round()}%',
                        onChanged: (value) {
                          ThemeManager().setLightOverlayOpacity(value);
                          setDialogState(() {});
                        },
                      ),
                      Text(
                        isDarkSelected ? '数值越高背景越暗，0% 为原始背景图' : '数值越高背景越淡，0% 为原始背景图',
                        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                // 浅色模式
                _buildThemeOption(Icons.light_mode, '浅色模式', '始终使用浅色主题', ThemeMode.light, currentMode, setDialogState),
                const Divider(),
                // 深色模式
                _buildThemeOption(Icons.dark_mode, '深色模式', '始终使用深色主题', ThemeMode.dark, currentMode, setDialogState),
                // 纯黑模式开关 — 仅深色模式可用
                if (isDarkSelected) ...[
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('纯黑背景',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14)),
                    subtitle: Text('使用真正的纯黑背景（#000000），隐藏背景图',
                      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    value: pureBlackEnabled,
                    onChanged: (value) {
                      ThemeManager().setPureBlackEnabled(value);
                      setDialogState(() {});
                    },
                  ),
                ],
                const Divider(),
                // 跟随系统
                _buildThemeOption(Icons.settings_suggest, '跟随系统', '根据系统设置自动切换', ThemeMode.system, currentMode, setDialogState),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('完成', style: TextStyle(color: AppColors.linkBlue(brightness))),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildThemeOption(IconData icon, String title, String subtitle, ThemeMode mode,
      ThemeMode currentMode, StateSetter setDialogState) {
    final brightness = Theme.of(context).brightness;
    final isSelected = currentMode == mode;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: isSelected ? AppColors.linkBlue(brightness) : Theme.of(context).colorScheme.onSurface),
      title: Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      trailing: isSelected ? Icon(Icons.check, color: AppColors.linkBlue(brightness), size: 20) : null,
      selected: isSelected,
      onTap: () {
        ThemeManager().setThemeMode(mode);
        setDialogState(() {});
      },
    );
  }

  // 显示账号管理对话框
  void _showAccountManageDialog(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return FutureBuilder<Map<String, dynamic>?>(
          future: _fetchAccountProfile(),
          builder: (ctx, snapshot) {
            final isLoading = snapshot.connectionState != ConnectionState.done;
            final errorMsg = snapshot.hasError ? '${snapshot.error}' : null;
            final profile = snapshot.data;

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.manage_accounts, size: 22),
                  SizedBox(width: 8),
                  Text('账号管理'),
                ],
              ),
              content: SingleChildScrollView(
                child: isLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : errorMsg != null
                        ? Text(errorMsg,
                            style: TextStyle(color: AppColors.errorRed(brightness)))
                        : profile != null
                            ? Column(mainAxisSize: MainAxisSize.min, children: [
                                _buildAccountInfo(profile, dialogContext),
                                _buildLxnsTokenSection(brightness),
                              ])
                            : const Text('暂无数据'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('关闭'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 本地检查落雪 importToken 是否已缓存
  Future<bool> _checkLxnsTokenLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final local = prefs.getString(CacheKeyConstant.probeLxnsImportToken);
    return local != null && local.isNotEmpty;
  }

  /// 管理落雪 API 密钥（Hub 侧）
  Widget _buildLxnsTokenSection(Brightness brightness) {
    final tokenCtrl = TextEditingController();
    bool? hasToken;
    bool saving = false;
    bool checking = true;

    return StatefulBuilder(
      builder: (ctx, setState) {
        // 初次检查：优先本地缓存，其次 Hub 查询
        if (checking) {
          _checkLxnsTokenLocal().then((localHas) {
            if (localHas) {
              if (checking) setState(() { hasToken = true; checking = false; });
            } else {
              DivingFishProbeManager().hasLxnsImportToken().then((has) {
                if (checking) setState(() { hasToken = has; checking = false; });
              });
            }
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 24),
            Row(
              children: [
                Icon(
                  hasToken == true ? Icons.check_circle : Icons.vpn_key,
                  size: 18,
                  color: hasToken == true
                      ? AppColors.successGreen(brightness)
                      : AppColors.greyHint(brightness),
                ),
                const SizedBox(width: 8),
                Text(
                  '落雪 API 密钥',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(ctx).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (checking)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else ...[
              if (hasToken == true)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('已设置',
                    style: TextStyle(color: AppColors.successGreen(brightness), fontSize: 13)),
                )
              else ...[
                Text('未设置',
                  style: TextStyle(color: AppColors.warningOrange(brightness), fontSize: 13)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final uri = Uri.parse('https://maimai.lxns.net/user/profile?tab=thirdparty');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: '访问 ', style: TextStyle(fontSize: 12)),
                        TextSpan(
                          text: 'https://maimai.lxns.net/user/profile?tab=thirdparty',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                            color: AppColors.linkBlue(brightness), decoration: TextDecoration.underline),
                        ),
                        const TextSpan(text: '，滑到最底部获取密钥。',
                          style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: tokenCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: '在此粘贴落雪个人 API 密钥...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: saving ? null : () async {
                      final t = tokenCtrl.text.trim();
                      if (t.isEmpty) {
                        Fluttertoast.showToast(msg: '请先输入 API 密钥');
                        return;
                      }
                      setState(() => saving = true);
                      // 先本地缓存（无需 Hub 登录）
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString(CacheKeyConstant.probeLxnsImportToken, t);
                      // 尝试同步绑定到 Hub
                      final ok = await DivingFishProbeManager().setLxnsImportToken(t);
                      setState(() => saving = false);
                      hasToken = true;
                      tokenCtrl.clear();
                      setState(() {});
                      Fluttertoast.showToast(msg: ok
                          ? '落雪 API 密钥已保存'
                          : '已本地保存，同步时将自动绑定到云端');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.linkBlue(brightness),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    child: saving
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('保存', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
              if (hasToken == true) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    // 清除本地缓存
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove(CacheKeyConstant.probeLxnsImportToken);
                    // 尝试清除 Hub 侧绑定
                    await DivingFishProbeManager().setLxnsImportToken(null);
                    hasToken = false;
                    Fluttertoast.showToast(msg: '落雪 API 密钥已清除');
                    setState(() {});
                  },
                  child: Text('清除密钥',
                    style: TextStyle(color: AppColors.errorRed(brightness), fontSize: 12)),
                ),
              ],
            ],
          ],
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _fetchAccountProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final jwt = prefs.getString(CacheKeyConstant.probeDivingFishToken);
    if (jwt == null || jwt.isEmpty) {
      throw Exception('未登录水鱼，请先在首页点击「登录水鱼」');
    }
    final response = await ApiClient.get(
      Uri.parse(ApiUrls.DivingFishProfileApi),
      headers: {
        'Content-Type': 'application/json',
        'Cookie': 'jwt_token=$jwt',
      },
    );
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('获取账号信息失败 (${response.statusCode})');
  }

  Widget _buildAccountInfo(Map<String, dynamic> p, BuildContext dialogContext) {
    final brightness = Theme.of(dialogContext).brightness;
    final importToken = p.tryGet<String>('import_token') ?? '无';
    final bindQQ = p.tryGet<String>('bind_qq') ?? '未绑定';
    final nickname = p.tryGet<String>('nickname') ?? '无';
    final channelUid = p.tryGet<String>('qq_channel_uid') ?? '未绑定';
    final username = p.tryGet<String>('username') ?? '无';
    final plate = p.tryGet<String>('plate') ?? '无';
    final additionalRating = p.tryGet<int>('additional_rating') ?? 0;

    String displayToken = importToken.length > 20
        ? '${importToken.substring(0, 16)}...'
        : importToken;

    // 需要跨 setState 保持状态，声明在 StatefulBuilder 外部
    bool isRefreshing = false;

    return StatefulBuilder(
      builder: (ctx, setState) {
        final rows = <Widget>[
          _infoRow('用户名', username, brightness),
          _infoRow('昵称', nickname, brightness),
          _infoRow('牌子', plate.isNotEmpty ? plate : '无', brightness),
          _infoRow('Rating段位', _ratingName(additionalRating), brightness),
          _infoRow('绑定QQ', bindQQ, brightness),
          _infoRow('频道ID', channelUid, brightness),
          // ImportToken 行带操作按钮
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 90,
                  child: Text('ImportToken',
                      style: TextStyle(color: AppColors.greyHint(brightness), fontSize: 13)),
                ),
                Expanded(
                  child: Text(displayToken,
                      style: const TextStyle(fontSize: 13)),
                ),
                if (isRefreshing)
                  const SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else ...[
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    tooltip: '刷新 ImportToken',
                    onPressed: () async {
                      setState(() => isRefreshing = true);
                      final newToken = await _refreshImportToken();
                      if (newToken != null) {
                        displayToken = newToken.length > 20
                            ? '${newToken.substring(0, 16)}...'
                            : newToken;
                        Fluttertoast.showToast(msg: 'ImportToken 已刷新');
                      } else {
                        Fluttertoast.showToast(msg: '刷新失败');
                      }
                      setState(() => isRefreshing = false);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    tooltip: '复制 ImportToken',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: importToken));
                      Fluttertoast.showToast(msg: 'ImportToken 已复制到剪贴板');
                    },
                  ),
                ],
              ],
            ),
          ),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: rows,
        );
      },
    );
  }

  Widget _infoRow(String label, String value, Brightness brightness) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: TextStyle(color: AppColors.greyHint(brightness), fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Future<String?> _refreshImportToken() async {
    final prefs = await SharedPreferences.getInstance();
    final jwt = prefs.getString(CacheKeyConstant.probeDivingFishToken);
    if (jwt == null || jwt.isEmpty) return null;

    try {
      final response = await ApiClient.put(
        Uri.parse(ApiUrls.DivingFishImportTokenApi),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'jwt_token=$jwt',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final newToken = data.tryGet<String>('token') ?? '';
        if (newToken.isNotEmpty) {
          await prefs.setString(CacheKeyConstant.probeDivingFishImportToken, newToken);
          return newToken;
        }
      }
    } catch (e) {
      debugPrint('_refreshImportToken error: $e');
    }
    return null;
  }

  String _ratingName(int rating) {
    const names = [
      '初学者', '一段', '二段', '三段', '四段', '五段',
      '六段', '七段', '八段', '九段', '十段',
      '真初段', '真二段', '真三段', '真四段', '真五段',
      '真六段', '真七段', '真八段', '真九段', '真十段',
      '真皆传', '里皆传',
    ];
    if (rating < 0 || rating >= names.length) return '$rating';
    return '${names[rating]} ($rating)';
  }

  // 构建同步状态图标
  Widget _buildStageIcon(SyncStage? stage, Brightness brightness) {
    if (stage == null) return const SizedBox.shrink();
    switch (stage) {
      case SyncStage.completed:
        return Icon(Icons.check_circle, color: AppColors.successGreen(brightness), size: 36);
      case SyncStage.failed:
        return Icon(Icons.error, color: AppColors.errorRed(brightness), size: 36);
      case SyncStage.cancelled:
        return Icon(Icons.cancel, color: AppColors.greyHint(brightness), size: 36);
      case SyncStage.waitingAcceptance:
        return Icon(Icons.hourglass_bottom, color: AppColors.warningOrange(brightness), size: 36);
      default:
        return const SizedBox.shrink();
    }
  }

  // 功能按钮点击分发（提取为独立方法，作为回调传给 FeatureCategoryPage）
  Future<void> _handleFeatureTap(ButtonItem item) async {
    debugPrint("点击了：${item.title}");
    // 版本对照按钮点击事件
    if (item.title == '版本对照') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => VersionView()),
      );
    }
    if (item.title == '达成率计算') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AchievementRateCalculator()),
      );
    }
    if (item.title == '达成率反推') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AchievementFullReverseCalculator()),
      );
    }
    if (item.title == 'Best50查询') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => B50Page()),
      );
    }
    if (item.title == '单曲Rating计算') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => SingleRatingCalculator()),
      );
    }
    if (item.title == '基于标签推荐') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => RecommendByTags()),
      );
    }
    if (item.title == '基于目标Rating推荐') {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RatingRecommendPage()),
    );
  }
  if (item.title == '基于定数区间推荐') {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DsRangeRecommendPage()),
    );
  }
    if (item.title == '乐曲查询') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => SongSearchPage()),
      );
    }
    if (item.title == '刷新数据') {
      final isOnline = await ConnectivityService().hasConnection();
      if (!mounted) return;
      if (!isOnline) {
        Fluttertoast.showToast(msg: '当前无网络连接，请联网后重试');
        return;
      }
      _showRefreshDataDialog(context);
    }
    if (item.title == '刷新maidata') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('确认刷新'),
          content: const Text('将清除所有maidata缓存并从服务器重新拉取全部maidata数据，耗时可能较长。\n\n确定要刷新吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('确认刷新'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        // 显示加载对话框
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => const AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在刷新maidata...'),
                ],
              ),
            ),
          );
        }
        try {
          // 清除所有maidata缓存
          await MaidataManager().clearCache();
          await MaimaiMusicDataManager().clearAddedSongsCache();
          final prefs = await SharedPreferences.getInstance();
          final keys = prefs.getKeys();
          for (final key in keys) {
            if (key.startsWith(CacheKeyConstant.maidataCachePrefix)) {
              await prefs.remove(key);
            }
          }
          // 重新拉取全量maidata
          await MaimaiMusicDataManager().refreshDataWithSmartMaidata();
          // 关闭加载对话框
          if (mounted) Navigator.of(context).pop();
          if (mounted) {
            Fluttertoast.showToast(msg: 'Maidata刷新成功');
          }
        } catch (e) {
          debugPrint('[HomePage] 刷新maidata失败: $e');
          if (mounted) Navigator.of(context).pop();
          if (mounted) {
            Fluttertoast.showToast(msg: '刷新失败: $e');
          }
        }
      }
    }
    if (item.title == '成绩查询') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => UserScoreSearchPage()),
      );
    }
    if (item.title == '拟合Best50查询'){
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => DiffBest50Page()),
      );
    }
    if (item.title == '随机乐曲'){
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => RandomChartPage()),
      );
    }
    if (item.title == '无提示猜歌'){
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => GuessChartByInfoPage()),
      );
    }
    if (item.title == '根据部分曲绘猜歌'){
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => GuessChartByCoverPage()),
      );
    }
    if (item.title == '收藏品查询'){
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => CollectionSearchPage()),
      );
    }
    if (item.title == '根据模糊曲绘猜歌'){
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => GuessChartByBlurredCoverPage()),
      );
    }
    if (item.title == '根据歌曲片段猜歌'){
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => GuessChartBySongExcerptPage()),
      );
    }
    if (item.title == '根据别名猜歌'){
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => GuessChartByAliaPage()),
      );
    }
    if (item.title == '舞萌开字母'){
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => GuessSongByOpenLettersPage()),
      );
    }
    if (item.title == '多人猜歌游戏'){
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => MultiplayerLobbyPage()),
      );
    }
    if (item.title == '服务器状态'){
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => MaimaiServerStatusPage()),
      );
    }
    if (item.title == '个性化Best50查询'){
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PersonalizedBest50Page()),
      );
    }
    if (item.title == '舞萌百科'){
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => KnowledgeSearchPage()),
      );
    }
    if (item.title == 'KALEIDXSCOPE'){
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => KaleidXScopeSelectPage()),
      );
    }
    if (item.title == '曲绘识别'){
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CoverRecognitionPage()),
      );
    }
    if (item.title == '牌子进度'){
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PaiziProgressPage()),
      );
    }
    if (item.title == '个性化成绩查询'){
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PersonalizedScorePage()),
      );
    }
    if (item.title == '自定义谱面播放'){
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PersonalizedChartPlayConfigure()),
      );
    }
    if (item.title == '关于本APP') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AboutAppPage()),
      );
    }
    if (item.title == '问卷调查') {
      final uri = Uri.parse('https://wj.qq.com/s2/26540572/7828/');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
    if (item.title == '同步成绩到水鱼') {
      // 检测是否已登录水鱼
      final prefs = await SharedPreferences.getInstance();
      final hasJwt = (prefs.getString(CacheKeyConstant.probeDivingFishToken) ?? '').isNotEmpty;
      if (!hasJwt) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('提示'),
              content: const Text('请先在「登录水鱼」中登录你的水鱼账号，再使用同步功能。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _showDivingFishLoginDialog(context);
                  },
                  child: const Text('去登录'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // 检测缓存 QQ 与当前水鱼 bind_qq 是否一致
      final cachedQQ = _cachedQQ.isNotEmpty ? _cachedQQ : null;
      if (cachedQQ != null) {
        final bindQQ = await DivingFishProbeManager().fetchBindQQ();
        if (bindQQ != null && bindQQ.isNotEmpty && bindQQ != cachedQQ) {
          if (context.mounted) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('账号不匹配'),
                content: Text(
                  '当前登录的水鱼账号绑定的 QQ（$bindQQ）与本机缓存的 QQ（$cachedQQ）不一致。\n\n'
                  '请先登出当前水鱼账号，登录正确的账号后再同步。',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('确定'),
                  ),
                ],
              ),
            );
          }
          return;
        }
      }

      await _showSyncScoreDialog(context);
    }
    if (item.title == '账号管理') {
      _showAccountManageDialog(context);
    }
    if (item.title == '登录水鱼') {
      _showDivingFishLoginDialog(context);
    }
    if (item.title == '登出账号') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('确认登出'),
          content: const Text('登出后将清除缓存的登录信息和 ImportToken，确定要登出吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed(Theme.of(context).brightness)),
              child: const Text('登出', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (ok == true) {
        await _logoutDivingFish();
      }
    }
    if (item.title == '段位表'){
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => RankListPage()),
      );
    }
    if (item.title == '排行榜(仅供参考)'){
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => RatingRankListPage()),
      );
    }
    if (item.title == '特殊排行榜'){
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => SpecialRankingListPage()),
      );
    }
    if (item.title == '检查更新'){
      // 显示加载对话框
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('检查更新'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在检查更新...'),
              ],
            ),
          );
        },
      );

      // 检查更新
      final updateManager = LZYCheckUpdateManager();
      updateManager.showUpdateDialog(context, force: true).then((_) {
        Navigator.of(context).pop(); // 关闭加载对话框
      }).catchError((error) {
        Navigator.of(context).pop(); // 关闭加载对话框
        // 显示错误提示
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('检查更新失败'),
                content: Text('请检查网络连接后重试'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Clipboard.setData(const ClipboardData(text: LZYCheckUpdateManager.defaultDownloadUrl));
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('下载链接已复制到剪贴板'), duration: Duration(seconds: 2)),
                      );
                    },
                    child: Text('复制下载链接'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text('确定'),
                  ),
                ],
              );
            },
          );
        }
      });
    }
    if (item.title == '定数分布'){
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DifficultyDistributionPage()),
      );
    }
    if (item.title == '浅色/深色模式'){
      _showThemeDialog();
    }
    if (item.title == '收藏夹'){
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const FavoriteFolderPage()),
      );
    }
    if (item.title == '同步成绩到落雪'){
      UpdateLuoXueScorePage.show(context);
    }
    if (item.title == '每日推荐'){
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DailyRecommendPage()),
      );
    }
    if (item.title == '好友对比'){
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const FriendComparePage()),
      );
    }
    if (item.title == '全国音游地图'){
      final uri = Uri.parse('https://map.bemanicn.com/');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
    if (item.title == '最近评论'){
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const RecentCommentsPage()),
      );
    }
    if (item.title == '最近评分'){
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const RecentRatingsPage()),
      );
    }
    if (item.title == '数据备份'){
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DataBackupPage()),
      );
    }
  }

  // 构建分类区域（分类标题 + 分隔条 + 按钮网格）
  Widget _buildCategorySection(ButtonCategory category, BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 分隔条
        const Divider(height: 1, thickness: 1),
        SizedBox(height: screenHeight * 0.008),
        // 分类标题（居中 + 底色突出）
        Center(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.04,
              vertical: screenHeight * 0.004,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
            ),
            child: Text(
              category.name,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: screenWidth * 0.035,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        SizedBox(height: screenHeight * 0.006),
        // 按钮网格
        GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: AppConstants.crossAxisCount,
            crossAxisSpacing: screenWidth * 0.02,
            mainAxisSpacing: screenHeight * 0.01,
            childAspectRatio: screenWidth > 600 ? 1.3 : 1.2,
          ),
          itemCount: category.items.length,
          itemBuilder: (context, index) {
            final item = category.items[index];
            return FeatureButton(
              item: item,
              onTap: () => _handleFeatureTap(item),
              isFavorited: _favoriteTitles.contains(item.title),
              onToggleFavorite: () => _toggleFavorite(item.title),
            );
          },
        ),
        SizedBox(height: screenHeight * 0.006),
      ],
    );
  }

  // 构建大类导航卡片按钮
  Widget _buildCategoryCard(ButtonCategory category, BuildContext context, {
    int? overrideCount,
    VoidCallback? onTap,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final brightness = Theme.of(context).brightness;

    return Padding(
      padding: EdgeInsets.only(bottom: screenHeight * 0.012),
      child: SizedBox(
        height: screenHeight * 0.09,
        child: TextButton(
          style: TextButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
            side: BorderSide(
              color: AppColors.buttonBorder(brightness),
              width: AppConstants.borderWidth,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.04,
              vertical: screenHeight * 0.01,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
            ),
            elevation: 0,
          ),
          onPressed: onTap ?? () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => FeatureCategoryPage(
                  category: category,
                  onFeatureTap: _handleFeatureTap,
                  loginStateNotifier: _loginStateNotifier,
                ),
              ),
            ).then((_) {
              _checkDivingFishLoginStatus();
              _loadFavoriteCount();
            });
          },
          child: Row(
            children: [
              // 左侧：分类图标（圆形背景）
              Container(
                width: screenWidth * 0.11,
                height: screenWidth * 0.11,
                decoration: BoxDecoration(
                  color: AppColors.buttonBackground(brightness),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  category.icon ?? (category.items.isNotEmpty ? category.items.first.icon : Icons.folder),
                  color: Theme.of(context).colorScheme.onSurface,
                  size: screenWidth * 0.06,
                ),
              ),
              SizedBox(width: screenWidth * 0.04),
              // 中间：分类名称 + 功能数量
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: screenWidth * 0.042,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '${overrideCount ?? category.items.length} 个功能',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: screenWidth * 0.03,
                      ),
                    ),
                  ],
                ),
              ),
              // 右侧：箭头
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                size: screenWidth * 0.06,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 从落雪玩家记录计算并更新首页的 Best50 数据
  Future<({List<RecordItem> best35, List<RecordItem> best15})?> _calculateBest50FromLuoXueRecords(List<RecordItem> playerRecords) async {
    try {
      // 使用缓存的歌曲数据
      final musicDataManager = MaimaiMusicDataManager();
      final cachedSongs = await musicDataManager.getCachedSongs();
      
      if (cachedSongs == null || cachedSongs.isEmpty) {
        debugPrint('❌ 无法获取缓存的歌曲数据');
        return null;
      }

      // 根据歌曲的 is_new 字段分组
      List<RecordItem> oldSongs = []; // is_new = false
      List<RecordItem> newSongs = [];  // is_new = true

      for (var record in playerRecords) {
        bool isNew = _isSongNewFromCache(record.songId, cachedSongs);
        if (isNew) {
          newSongs.add(record);
        } else {
          oldSongs.add(record);
        }
      }

      // 按 ra 降序排序并取前 N 个
      oldSongs.sort((a, b) => b.ra.compareTo(a.ra));
      newSongs.sort((a, b) => b.ra.compareTo(a.ra));

      // Best35: is_new=false 的前35首
      List<RecordItem> best35 = oldSongs.take(35).toList();
      // Best15: is_new=true 的前15首
      List<RecordItem> best15 = newSongs.take(15).toList();

      // 计算总 Rating
      int best35RA = best35.fold(0, (sum, item) => sum + item.ra);
      int best15RA = best15.fold(0, (sum, item) => sum + item.ra);
      int totalRA = best35RA + best15RA;

      // 更新首页状态
      if (mounted) {
        setState(() {
          _best50TotalRA = totalRA;
          _best35TotalRA = best35RA;
          _best15TotalRA = best15RA;
        });
        await _saveUserData(); // 保存到缓存
      }

      debugPrint('✅ 从落雪数据计算Best50完成: Best35=${best35RA}, Best15=${best15RA}, 总Rating=$totalRA');
      return (best35: best35, best15: best15);
    } catch (e) {
      debugPrint('Error calculating Best50 from LuoXue records: $e');
      return null;
    }
  }

  /// 根据歌曲ID从缓存判断是否为新曲（is_new=true）
  bool _isSongNewFromCache(int songId, List<Song> cachedSongs) {
    try {
      Song song = cachedSongs.firstWhere(
        (song) => song.id == songId.toString(),
      );
      
      return song.basicInfo.isNew;
    } catch (e) {
      // 歌曲未找到时返回 false
      debugPrint('Song $songId not found in cached songs');
    }
    
    return false;
  }

  // ===== 水鱼导入辅助方法 =====

  /// 读取剪贴板按钮
  Widget _buildClipboardButton(StateSetter setState, TextEditingController qrCtrl) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.paste, size: 16),
      label: const Text('读取剪贴板', style: TextStyle(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      onPressed: () async {
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        final text = data?.text ?? '';
        if (text.trim().startsWith('SGWCMAID')) {
          setState(() {
            qrCtrl.text = text.trim();
          });
          Fluttertoast.showToast(msg: '已识别到有效二维码字符串，已自动填入');
        } else if (text.isNotEmpty) {
          // 未检测到有效前缀，提示用户
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('提示'),
              content: const Text('剪贴板内容不是有效的登入二维码，仍要填入吗？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('填入'),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            setState(() {
              qrCtrl.text = text.trim();
            });
          }
        } else {
          Fluttertoast.showToast(msg: '剪贴板为空');
        }
      },
    );
  }

  /// 从相册识别二维码按钮
  Widget _buildGalleryQrButton(StateSetter setState, TextEditingController qrCtrl) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.photo_library, size: 16),
      label: const Text('从相册识别', style: TextStyle(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      onPressed: () async {
        try {
          final picker = ImagePicker();
          final pickedFile = await picker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 100,
          );
          if (pickedFile == null) return;

          // 使用 mobile_scanner 解析图片中的二维码
          final controller = MobileScannerController();
          try {
            final barcodes = await controller.analyzeImage(pickedFile.path);

            if (barcodes != null && barcodes.barcodes.isNotEmpty) {
              final qrText = barcodes.barcodes.first.rawValue ?? '';
              if (qrText.isNotEmpty) {
                setState(() {
                  qrCtrl.text = qrText;
                });
                Fluttertoast.showToast(msg: '已识别到二维码，已自动填入');
              } else {
                Fluttertoast.showToast(msg: '未能从图片中识别到二维码内容');
              }
            } else {
              Fluttertoast.showToast(msg: '未在图片中检测到二维码');
            }
          } finally {
            controller.dispose();
          }
        } catch (e) {
          debugPrint('从相册识别二维码失败: $e');
          Fluttertoast.showToast(msg: '识别失败: $e');
        }
      },
    );
  }

  /// 摄像头扫码按钮
  Widget _buildCameraScanButton(StateSetter setState, TextEditingController qrCtrl, BuildContext dialogContext) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.qr_code_scanner, size: 16),
      label: const Text('扫描二维码', style: TextStyle(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      onPressed: () async {
        try {
          final result = await Navigator.of(dialogContext).push<String>(
            MaterialPageRoute(
              builder: (_) => _QrScannerPage(),
            ),
          );
          if (result != null && result.isNotEmpty) {
            setState(() {
              qrCtrl.text = result;
            });
            Fluttertoast.showToast(msg: '已扫描到二维码，已自动填入');
          }
        } catch (e) {
          debugPrint('摄像头扫码失败: $e');
          Fluttertoast.showToast(msg: '扫码失败: $e');
        }
      },
    );
  }
}

/// 摄像头扫二维码页面
class _QrScannerPage extends StatefulWidget {
  const _QrScannerPage();

  @override
  State<_QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<_QrScannerPage> {
  bool _hasPopped = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('扫描二维码'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: MobileScanner(
        onDetect: (BarcodeCapture capture) {
          if (_hasPopped) return;
          final barcode = capture.barcodes.firstOrNull;
          if (barcode != null && barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
            _hasPopped = true;
            Navigator.pop(context, barcode.rawValue);
          }
        },
        errorBuilder: (context, error) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('摄像头错误: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('返回'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}