import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
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
import '../widgets/OfflineBanner.dart';
import '../widgets/QuickSearchBar.dart';
import 'DifficultyDistributionPage.dart';import '../manager/DivingFish/UserPlayDataManager.dart';
import '../manager/DivingFish/MaimaiMusicDataManager.dart';
import '../manager/DivingFish/DiffMusicDataManager.dart';
import '../manager/SongAliasManager.dart';
import '../manager/DivingFish/UserBest50Manager.dart';
import '../manager/LuoXue/LuoXueUserPlayDataManager.dart';
import '../entity/DivingFish/RecordItem.dart';
import '../service/RankingList/SongRankingService.dart';
import '../entity/DivingFish/Song.dart';
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
import 'RecommendByTagsPage.dart';
import 'SingleRatingCalculatorPage.dart';
import 'SongSearchPage.dart';
import 'UserScoreSearchPage.dart';
import 'AboutAppPage.dart';
import 'CoverRecognitionPage.dart';
import 'DataBackupPage.dart';
import '../manager/LuoXue/CollectionsManager.dart';
import '../manager/DivingFishProbeManager.dart';
import '../entity/LuoXue/Collection.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
class ButtonItem {
  final IconData icon;
  final String title;
  final String subtitle;

  const ButtonItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

// 按钮分类数据模型
class ButtonCategory {
  final String name;
  final List<ButtonItem> items;

  const ButtonCategory({
    required this.name,
    required this.items,
  });
}

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
  // 后台初始化状态
  // 功能搜索过滤
  String _featureSearchQuery = '';

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
    _loadUserData();
    _loadCachedAvatarId();
    _fetchAvatarIcons();
    _autoCheckUpdate();
    _checkDivingFishLoginStatus();
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
  
  // 按钮分类数据源
  bool _isDivingFishLoggedIn = false;

  Future<void> _checkDivingFishLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final jwt = prefs.getString(CacheKeyConstant.probeDivingFishToken) ?? '';
    if (mounted) {
      setState(() => _isDivingFishLoggedIn = jwt.isNotEmpty);
    }
  }

  Future<void> _logoutDivingFish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(CacheKeyConstant.probeDivingFishToken);
    await prefs.remove(CacheKeyConstant.probeDivingFishImportToken);
    await prefs.remove(CacheKeyConstant.probeDivingFishBindQQ);
    if (mounted) {
      setState(() => _isDivingFishLoggedIn = false);
    }
    Fluttertoast.showToast(msg: '已登出水鱼账号');
  }

  List<ButtonCategory> get _buttonCategories => [
    ButtonCategory(name: '曲库与数据', items: [
      ButtonItem(icon: Icons.music_note, title: '乐曲查询', subtitle: '查询舞萌曲库的乐曲'),
      ButtonItem(icon: Icons.score, title: '成绩查询', subtitle: '查看游玩数据'),
      ButtonItem(icon: Icons.wysiwyg_rounded, title: '牌子进度', subtitle: '真代没有真将哦'),
      ButtonItem(icon: Icons.grading_rounded, title: '个性化成绩查询', subtitle: '目前支持等级/谱师的牌子查询'),
      ButtonItem(icon: Icons.collections_bookmark, title: '收藏品查询', subtitle: '查看收藏品详细信息'),
      ButtonItem(icon: Icons.bookmark_add, title: '舞萌百科', subtitle: '到底什么是错位?'),
    ]),
    ButtonCategory(name: 'Best50与排行榜', items: [
      ButtonItem(icon: Icons.leaderboard, title: 'Best50查询', subtitle: '我去,龙币!'),
      ButtonItem(icon: Icons.analytics, title: '拟合Best50查询', subtitle: '我w55怎么拟合才w52?!'),
      ButtonItem(icon: Icons.person_search_outlined, title: '个性化Best50查询', subtitle: '我超，名刀50!'),
      ButtonItem(icon: Icons.leaderboard, title: '排行榜(仅供参考)', subtitle: '总Rating排行榜'),
      ButtonItem(icon: Icons.leaderboard_outlined, title: '特殊排行榜', subtitle: '各种有意思的排行榜'),
    ]),
    ButtonCategory(name: '猜歌游戏', items: [
      ButtonItem(icon: Icons.gamepad, title: '无提示猜歌', subtitle: '舞萌笑传之猜猜呗1'),
      ButtonItem(icon: Icons.gamepad, title: '根据部分曲绘猜歌', subtitle: '舞萌笑传之猜猜呗2'),
      ButtonItem(icon: Icons.gamepad, title: '根据模糊曲绘猜歌', subtitle: '舞萌笑传之猜猜呗3'),
      ButtonItem(icon: Icons.gamepad, title: '根据歌曲片段猜歌', subtitle: '舞萌笑传之猜猜呗4'),
      ButtonItem(icon: Icons.gamepad, title: '根据别名猜歌', subtitle: '舞萌笑传之猜猜呗5'),
      ButtonItem(icon: Icons.gamepad, title: '舞萌开字母', subtitle: '舞萌笑传之猜猜呗6'),
      ButtonItem(icon: Icons.gamepad, title: '多人猜歌游戏', subtitle: '什么叫你随便答了一个就对了?!'),
    ]),
    ButtonCategory(name: '实用工具', items: [
      ButtonItem(icon: Icons.arrow_circle_up, title: '段位表', subtitle: '我去，炫彩真段位!'),
      ButtonItem(icon: Icons.label, title: '基于标签推荐', subtitle: '基于你游玩的谱面标签推荐曲目'),
      ButtonItem(icon: Icons.shuffle, title: '随机乐曲', subtitle: '随机选曲1-4首'),
      ButtonItem(icon: Icons.calculate, title: '单曲Rating计算', subtitle: '我鸟加这个有分吃吗？'),
      ButtonItem(icon: Icons.percent, title: '达成率计算', subtitle: '根据判定详情算出达成率'),
      ButtonItem(icon: Icons.compare_arrows, title: '版本对照', subtitle: '舞神要打哪些代的歌？'),
      ButtonItem(icon: Icons.replay, title: '达成率反推', subtitle: '根据判定详情推出绝赞详情'),
      ButtonItem(icon: Icons.door_back_door, title: 'KALEIDXSCOPE', subtitle: '白xx!(bushi)'),
      ButtonItem(icon: Icons.image_search, title: '曲绘识别', subtitle: '拍照识别曲绘对应的歌曲'),
      ButtonItem(icon: Icons.bar_chart, title: '定数分布', subtitle: '查看谱面定数分布柱状图'),
      ButtonItem(icon: Icons.favorite, title: '收藏夹', subtitle: '管理你收藏的谱面'),
      ButtonItem(icon: Icons.play_arrow, title: '自定义谱面播放', subtitle: '播放你自己本地的谱面'),
      ButtonItem(icon: Icons.qr_code_scanner, title: '同步成绩', subtitle: '将成绩同步到水鱼查分器'),
    ]),
    ButtonCategory(name: '系统', items: [
      ButtonItem(icon: Icons.file_upload_sharp, title: '刷新数据', subtitle: '刷新你的舞萌数据'),
      if (_isDivingFishLoggedIn)
        ButtonItem(icon: Icons.logout, title: '登出账号', subtitle: '清除水鱼登录状态')
      else
        ButtonItem(icon: Icons.login, title: '登录水鱼', subtitle: '获取ImportToken以便同步成绩'),
      ButtonItem(icon: Icons.network_check, title: '服务器状态', subtitle: '查看舞萌服务器状态'),
      ButtonItem(icon: Icons.update, title: '检查更新', subtitle: '检查应用是否有新版本'),
      ButtonItem(icon: Icons.info_outline, title: '关于本APP', subtitle: '了解ChiffonMai的方方面面'),
      ButtonItem(icon: Icons.poll_outlined, title: '问卷调查', subtitle: '助力ChiffonMai更上一层楼!'),
      ButtonItem(icon: Icons.manage_accounts, title: '账号管理', subtitle: '查看已绑定的水鱼账号信息'),
      ButtonItem(icon: Icons.backup, title: '数据备份', subtitle: '导出/导入本地数据'),
      ButtonItem(icon: Icons.dark_mode, title: '深色模式', subtitle: '切换深色/浅色主题'),
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    // 获取屏幕尺寸
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
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

          // 离线横幅
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: OfflineBanner(
              onRefresh: () => _showRefreshDataDialog(context),
            ),
          ),

          // 层级3：第二张虚化装饰图 - 居中显示，与层级2重叠，增强视觉效果
          Center(
            child: Transform.translate(
              offset: Offset(0, -screenHeight * 0.03),
              child: Transform.scale(
                scale: 1,
                child: Image.asset(
                  'assets/userinfobg2.png',
                  fit: BoxFit.cover,
                  opacity: const AlwaysStoppedAnimation(1),
                ),
              ),
            ),
          ),

          // 层级3.5：页面标题
            Positioned(
              top: screenHeight * 0.08,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Text(
                    "ChiffonMai",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: screenWidth * 0.06, // 根据屏幕宽度调整字号
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.01), // 添加间距
                  Text(
                    "基本信息",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: screenWidth * 0.045,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          // 层级4：左侧头像选择器
            Positioned(
              left: screenWidth * 0.1,
              top: screenHeight * 0.19,
              child: _buildAvatarSelector(context),
            ),

          // 层级5：个人信息静态文本
            Positioned(
              left: screenWidth * 0.5,
              top: screenHeight * 0.21,
              child: _buildUserInfo(context),
            ),

          
          // 层级5：核心功能区 - 分分类的可滚动按钮区域
          Positioned(
            left: screenWidth * 0.02,
            right: screenWidth * 0.02,
            top: screenHeight * 0.36,
            bottom: screenHeight * 0.03,
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
                    ..._buttonCategories.where((category) {
                      if (_featureSearchQuery.isEmpty) return true;
                      return category.items.any((item) =>
                        item.title.toLowerCase().contains(_featureSearchQuery) ||
                        item.subtitle.toLowerCase().contains(_featureSearchQuery));
                    }).map((category) {
                      if (_featureSearchQuery.isEmpty) {
                        return _buildCategorySection(category, context);
                      }
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

          // 层级6：底部版权信息
          Positioned(
            bottom: screenHeight * 0.01,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "ChiffonMai by ChiFFoN 2026",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: screenWidth * 0.03,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
          ),
          
          // 后台初始化状态提示
          if (_isBackgroundInitializing || _isInitializationCompleted)
            Positioned(
              bottom: screenHeight * 0.06,
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
                      SizedBox(width: screenWidth * 0.02),
                      Text(
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

  // 构建头像选择器
  Widget _buildAvatarSelector(BuildContext context) {
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
          color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
          border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [AppConstants.defaultShadow(brightness)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: 'https://assets2.lxns.net/maimai/icon/$_selectedAvatarId.png',
            placeholder: (ctx, url) => Icon(Icons.person, size: 30, color: AppColors.greyHint(brightness)),
            errorWidget: (ctx, url, err) => Icon(Icons.person, size: 30, color: AppColors.greyHint(brightness)),
            fit: BoxFit.cover,
          ),
        ),
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

  // 构建用户信息文本
  Widget _buildUserInfo(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // 检查是否有缓存数据（通过检查用户昵称为默认值判断）
    bool hasNoCachedData = _userNickname == "U+5E78";
    
    Widget userInfoContent;
    
    if (hasNoCachedData) {
      // 没有缓存数据时显示提示信息
      userInfoContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "请点击",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: screenWidth * 0.05,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              height: 1.2,
            ),
          ),
          Text(
            "刷新数据",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: screenWidth * 0.05,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              height: 1.2,
            ),
          ),
          Text(
            "刷新成绩",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: screenWidth * 0.05,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              height: 1.2,
            ),
          ),
        ],
      );
    } else {
      // 有缓存数据时显示正常信息
      userInfoContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _userNickname,
            style: TextStyle(
              color: const Color(0xFF546161),
              fontSize: screenWidth * 0.07,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              height: 0.6,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          SizedBox(height: screenHeight * 0.005), // 在玩家名和Rating中间添加SizedBox
          Text(
            "Rating",
            style: TextStyle(
              color: const Color(0xFF546161),
              fontSize: screenWidth * 0.045,
              fontWeight: FontWeight.normal,
            ),
          ),
          Text(
            "$_best50TotalRA",
            style: TextStyle(
              color: const Color(0xFF546161),
              fontSize: screenWidth * 0.07,
              fontWeight: FontWeight.w600,
              height: 0.8,
            ),
          ),
          Text(
            "$_best35TotalRA+$_best15TotalRA",
            style: TextStyle(
              color: const Color(0xFF546161),
              fontSize: screenWidth * 0.04,
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      );
    }
    
    // 包装成可点击的Widget
    return GestureDetector(
      onTap: () {
        // 点击个人信息区域时显示刷新数据对话框
        _showRefreshDataDialog(context);
      },
      child: userInfoContent,
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
  void _showRefreshDataDialog(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final TextEditingController qqController = TextEditingController(text: _cachedQQ);
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
      barrierDismissible: !isRefreshing,
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
            
            return AlertDialog(
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
                    
                    // 水鱼数据源：QQ号输入
                    if (!isRefreshing && _currentDataSource == DataSource.shuiyu)
                      TextField(
                        controller: qqController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: '请输入QQ号',
                          hintText: '例如:1919810',
                        ),
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
            );
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
      await Future.delayed(const Duration(milliseconds: 250));
      
      // 清除推荐结果缓存
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(CacheKeyConstant.recommendationResults);
        debugPrint('推荐结果缓存已清除');
      } catch (e) {
        debugPrint('清除推荐结果缓存失败: $e');
      }
      
      onProgress(10, '正在换取访问令牌...');
      await Future.delayed(const Duration(milliseconds: 250));
      
      // 使用授权码换取令牌
      final success = await LuoXueUserPlayDataManager().exchangeCodeForToken(authCode);
      
      if (success) {
        onProgress(15, '授权成功，正在保存数据源...');
        await Future.delayed(const Duration(milliseconds: 250));
        
        // 授权成功，保存数据源为落雪
        await _saveLastDataSource('luoxue');
        
        onProgress(20, '正在刷新歌曲数据...');
        await Future.delayed(const Duration(milliseconds: 250));
        
        // 使用智能刷新：初次拉取获取全量maidata，后续只获取追加歌曲的maidata
        await MaimaiMusicDataManager().refreshDataWithSmartMaidata();
        
        onProgress(35, '正在刷新难度数据...');
        await Future.delayed(const Duration(milliseconds: 250));
        
        // 从API获取并更新难度数据
        await DiffMusicDataManager().fetchAndUpdateDiffData();
        
        onProgress(50, '正在刷新标签数据...');
        await Future.delayed(const Duration(milliseconds: 250));
        
        // 刷新标签数据
        await RecommendByTagsService.initializeTags();
        
        onProgress(60, '正在刷新别名数据...');
        await Future.delayed(const Duration(milliseconds: 250));
        
        // 刷新别名数据
        await SongAliasManager.instance.refresh();
        
        onProgress(65, '正在获取玩家信息...');
        await Future.delayed(const Duration(milliseconds: 250));
        
        // 授权成功，获取玩家信息
        final playerInfo = await LuoXueUserPlayDataManager().getPlayerInfo();
        
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
        
        onProgress(75, '正在获取玩家成绩...');
        await Future.delayed(const Duration(milliseconds: 250));
        
        // 获取玩家成绩并转换为 RecordItem（自动更新缓存）
        final playerRecords = await LuoXueUserPlayDataManager().getPlayerRecordsAsRecordItems();
        debugPrint('玩家成绩数量: ${playerRecords?.length ?? 0}');
        
        onProgress(85, '正在计算 Best50 数据...');
        await Future.delayed(const Duration(milliseconds: 250));
        
        // 从落雪数据计算并更新首页的 Best50 数据
        if (playerRecords != null && playerRecords.isNotEmpty) {
          await _calculateBest50FromLuoXueRecords(playerRecords);
        }
        
        onProgress(95, '正在保存数据...');
        await Future.delayed(const Duration(milliseconds: 250));
        
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
        return '$errorMsg，可能存在非法数据，请检查';
      }
      
      final response = await http.post(
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
      final response = await http.delete(
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
      await Future.delayed(const Duration(milliseconds: 250));
      
      // 清除推荐结果缓存
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(CacheKeyConstant.recommendationResults);
        debugPrint('推荐结果缓存已清除');
      } catch (e) {
        debugPrint('清除推荐结果缓存失败: $e');
      }
      
      onProgress(10, '正在刷新歌曲数据...');
      await Future.delayed(const Duration(milliseconds: 250));
      
      // 使用智能刷新：初次拉取获取全量maidata，后续只获取追加歌曲的maidata
      await MaimaiMusicDataManager().refreshDataWithSmartMaidata();
      
      onProgress(30, '正在刷新难度数据...');
      await Future.delayed(const Duration(milliseconds: 250));
      
      // 从API获取并更新难度数据
      await DiffMusicDataManager().fetchAndUpdateDiffData();
      
      onProgress(45, '正在刷新标签数据...');
      await Future.delayed(const Duration(milliseconds: 250));
      
      // 刷新标签数据
      await RecommendByTagsService.initializeTags();
      
      onProgress(55, '正在刷新别名数据...');
      await Future.delayed(const Duration(milliseconds: 250));
      
      // 刷新别名数据
      await SongAliasManager.instance.refresh();
      
      onProgress(65, '正在获取用户数据...');
      await Future.delayed(const Duration(milliseconds: 250));
      
      // 从API获取并更新用户游玩数据
      final userPlayDataManager = UserPlayDataManager();
      final userPlayData = await userPlayDataManager.fetchUserPlayData(qq);
      
      onProgress(75, '正在获取Best50数据...');
      await Future.delayed(const Duration(milliseconds: 250));
      
      final best50Manager = UserBest50Manager();
      final best50Data = await best50Manager.getUserBest50(qq);
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
      await Future.delayed(const Duration(milliseconds: 250));
      
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
      await Future.delayed(const Duration(milliseconds: 250));
      
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
      barrierDismissible: !isSyncing,
      builder: (BuildContext dialogContext) {
        Timer? _autoCloseTimer;
        int _countdown = 3;
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

            return AlertDialog(
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
                      TextField(
                        controller: qrController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'SGWCMAID...',
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
                      if (currentStage != SyncStage.completed &&
                          currentStage != SyncStage.failed &&
                          currentStage != SyncStage.cancelled)
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
                      const SizedBox(height: 8),
                      Center(child: _buildStageIcon(currentStage, brightness)),
                      const SizedBox(height: 8),
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
                    icon: const Icon(Icons.sync, size: 18),
                    label: const Text('开始同步'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.linkBlue(brightness),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final qrCode = qrController.text.trim();
                      if (qrCode.isEmpty) {
                        Fluttertoast.showToast(msg: '请先粘贴机台上的QR码字符串');
                        return;
                      }

                      setState(() {
                        isSyncing = true;
                        statusText = '准备同步...';
                        currentStage = SyncStage.authenticating;
                      });

                      final result = await DivingFishProbeManager().syncByQrCode(
                        qrCode,
                        onProgress: (p) {
                          setState(() {
                            currentStage = p.stage;
                            statusText = p.message;
                            progress = _stageProgress(p);
                          });
                        },
                      );

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
          );
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

  // 显示主题切换对话框
  void _showThemeDialog() {
    final currentMode = ThemeManager().themeMode;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('选择主题模式', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeOption(ctx, Icons.light_mode, '浅色模式', '始终使用浅色主题', ThemeMode.light, currentMode),
            const Divider(),
            _buildThemeOption(ctx, Icons.dark_mode, '深色模式', '始终使用深色主题', ThemeMode.dark, currentMode),
            const Divider(),
            _buildThemeOption(ctx, Icons.settings_suggest, '跟随系统', '根据系统设置自动切换', ThemeMode.system, currentMode),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('取消', style: TextStyle(color: Theme.of(context).colorScheme.onSurface))),
        ],
      ),
    );
  }

  Widget _buildThemeOption(BuildContext ctx, IconData icon, String title, String subtitle, ThemeMode mode, ThemeMode currentMode) {
    final brightness = Theme.of(context).brightness;
    final isSelected = currentMode == mode;
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppColors.linkBlue(brightness) : Theme.of(context).colorScheme.onSurface),
      title: Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      trailing: isSelected ? Icon(Icons.check, color: AppColors.linkBlue(brightness)) : null,
      selected: isSelected,
      onTap: () { ThemeManager().setThemeMode(mode); Navigator.of(ctx).pop(); },
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
                            ? _buildAccountInfo(profile, dialogContext)
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

  Future<Map<String, dynamic>?> _fetchAccountProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final jwt = prefs.getString(CacheKeyConstant.probeDivingFishToken);
    if (jwt == null || jwt.isEmpty) {
      throw Exception('未登录水鱼，请先在首页点击「登录水鱼」');
    }
    final response = await http.get(
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
      final response = await http.put(
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
        return Icon(Icons.sync, color: AppColors.linkBlue(brightness), size: 36);
    }
  }

  // 构建自定义功能按钮
  Widget _buildCustomButton(ButtonItem item, BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final brightness = Theme.of(context).brightness;

    return SizedBox(
      height: screenHeight * 0.12,
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: Colors.transparent, // 按钮整体背景设为透明
          side: BorderSide(
            color: AppColors.buttonBorder(brightness),
            width: AppConstants.borderWidth,
          ),
          padding: EdgeInsets.zero, // 移除默认内边距
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
          ),
          elevation: 0,
        ),
        onPressed: () async {
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
          if (item.title == '乐曲查询') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SongSearchPage()),
            );
          }
          if (item.title == '刷新数据') {
            _showRefreshDataDialog(context);
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
          if (item.title == '同步成绩') {
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
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed(brightness)),
                    child: const Text('登出', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
            if (ok == true) {
              _logoutDivingFish();
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
          if (item.title == '深色模式'){
            _showThemeDialog();
          }
          if (item.title == '收藏夹'){
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FavoriteFolderPage()),
            );
          }
          if (item.title == '数据备份'){
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DataBackupPage()),
            );
          }
        },
        child: Column(
          children: [
            // 上半部分：原背景色，居中图标
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.buttonBackground(brightness),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppConstants.borderRadiusLarge),
                    topRight: Radius.circular(AppConstants.borderRadiusLarge),
                  ),
                ),
                child: Center(
                  child: Container(
                    width: screenWidth * 0.09, // 圆形背景的宽度
                    height: screenWidth * 0.09, // 圆形背景的高度
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface, // 主题感知背景
                      shape: BoxShape.circle, // 圆形形状
                    ),
                    child: Center(
                      child: Icon(
                        item.icon,
                        color: Theme.of(context).colorScheme.onSurface,
                        size: screenWidth * 0.05, // 图标尺寸
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // 下半部分：白色背景，居中标题和副标题
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(AppConstants.borderRadiusLarge),
                    bottomRight: Radius.circular(AppConstants.borderRadiusLarge),
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: screenWidth * 0.035,
                          fontWeight: FontWeight.bold,
                          fontStyle: FontStyle.normal,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: screenHeight * 0.005),
                      Text(
                        item.subtitle,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                          fontSize: screenWidth * 0.025,
                          fontWeight: FontWeight.w300,
                        ),
                        textAlign: TextAlign.center,
                        softWrap: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
            return _buildCustomButton(category.items[index], context);
          },
        ),
        SizedBox(height: screenHeight * 0.006),
      ],
    );
  }

  /// 从落雪玩家记录计算并更新首页的 Best50 数据
  Future<void> _calculateBest50FromLuoXueRecords(List<RecordItem> playerRecords) async {
    try {
      // 使用缓存的歌曲数据
      final musicDataManager = MaimaiMusicDataManager();
      final cachedSongs = await musicDataManager.getCachedSongs();
      
      if (cachedSongs == null || cachedSongs.isEmpty) {
        debugPrint('❌ 无法获取缓存的歌曲数据');
        return;
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
    } catch (e) {
      debugPrint('Error calculating Best50 from LuoXue records: $e');
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
}