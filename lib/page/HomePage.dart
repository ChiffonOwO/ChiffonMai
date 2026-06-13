import 'package:flutter/material.dart';
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
import '../manager/DivingFish/UserPlayDataManager.dart';
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
import 'VersionViewPage.dart';
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
class AppConstants {
  // 布局尺寸常量
  static const double targetHeight = 380.0;
  static const double blockSpacing = 160.0;
  static const double textLeft = 185.0;
  static const double textTop = 180.0;
  static const double buttonHeight = 70.0;
  static const double gridHorizontalPadding = 15.0; // 减小GridView左右边距
  static const double buttonPaddingVertical = 6.0;
  static const double buttonPaddingHorizontal = 4.0;

  // 网格布局常量
  static const int crossAxisCount = 2;
  static const double crossAxisSpacing = 8.0; // 减小按钮横向间距
  static const double mainAxisSpacing = 4.0; // 减小按钮纵向间距
  static const double childAspectRatio = 1.2;

  // 圆角常量
  static const double borderRadiusSmall = 8.0;
  static const double borderRadiusLarge = 12.0;

  // 边框常量
  static const double borderWidth = 1.5;

  // 阴影常量
  static const BoxShadow defaultShadow = BoxShadow(
    color: Colors.black12,
    blurRadius: 5.0,
    offset: Offset(2.0, 2.0),
  );

  // 颜色常量
  static const Color buttonBackgroundColor = Color.fromARGB(210, 227, 232, 125);
  static const Color buttonBorderColor = Color.fromARGB(199, 192, 133, 100);
  static const Color textPrimaryColor = Color.fromARGB(255, 84, 97, 97);
  static const Color textSecondaryColor = Color.fromARGB(255, 109, 125, 125);
}

// 按钮项数据模型
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
  
  // 初始化方法，用于从本地存储加载数据
  @override
  void initState() {
    super.initState();
    _loadUserData();
    _autoCheckUpdate();
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
    setState(() {
      _cachedQQ = qq;
    });
  }
  
  // 按钮数据源：使用类型安全的ButtonItem模型
  final List<ButtonItem> buttonItems = const [
    ButtonItem(icon: Icons.music_note, title: '乐曲查询', subtitle: '查询舞萌曲库的乐曲'),
    ButtonItem(icon: Icons.score, title: '成绩查询', subtitle: '查看游玩数据'),
    ButtonItem(icon: Icons.wysiwyg_rounded, title: '牌子进度', subtitle: '真代没有真将哦'),
    ButtonItem(icon: Icons.grading_rounded, title: '个性化成绩查询', subtitle: '目前支持等级/谱师的牌子查询'),
    ButtonItem(icon: Icons.collections_bookmark, title: '收藏品查询', subtitle: '查看收藏品详细信息'),
    ButtonItem(icon: Icons.bookmark_add, title: '舞萌百科', subtitle: '到底什么是错位?'),
    ButtonItem(icon: Icons.leaderboard, title: 'Best50查询', subtitle: '我去,龙币!'),
    ButtonItem(icon: Icons.analytics, title: '拟合Best50查询', subtitle: '我w55怎么拟合才w52?!'),
    ButtonItem(icon: Icons.person_search_outlined, title: '个性化Best50查询', subtitle: '我超，名刀50!'),
    ButtonItem(icon: Icons.arrow_circle_up, title: '段位表', subtitle: '我去，炫彩真段位!'),
    ButtonItem(icon: Icons.door_back_door, title: 'KALEIDXSCOPE', subtitle: '白xx!(bushi)'),
    ButtonItem(icon: Icons.label, title: '基于标签推荐', subtitle: '基于你游玩的谱面标签推荐曲目'),
    ButtonItem(icon: Icons.shuffle, title: '随机乐曲', subtitle: '随机选曲1-4首'),
    ButtonItem(icon: Icons.calculate, title: '单曲Rating计算', subtitle: '我鸟加这个有分吃吗？'),
    ButtonItem(icon: Icons.percent, title: '达成率计算', subtitle: '根据判定详情算出达成率'),
    ButtonItem(icon: Icons.compare_arrows, title: '版本对照', subtitle: '舞神要打哪些代的歌？'),
    ButtonItem(icon: Icons.replay, title: '达成率反推', subtitle: '根据判定详情推出绝赞详情'),
    ButtonItem(icon: Icons.gamepad, title: '无提示猜歌', subtitle: '舞萌笑传之猜猜呗1'),
    ButtonItem(icon: Icons.gamepad, title: '根据部分曲绘猜歌', subtitle: '舞萌笑传之猜猜呗2'),
    ButtonItem(icon: Icons.gamepad, title: '根据模糊曲绘猜歌', subtitle: '舞萌笑传之猜猜呗3'),
    ButtonItem(icon: Icons.gamepad, title: '根据歌曲片段猜歌', subtitle: '舞萌笑传之猜猜呗4'),
    ButtonItem(icon: Icons.gamepad, title: '根据别名猜歌', subtitle: '舞萌笑传之猜猜呗5'),
    ButtonItem(icon: Icons.gamepad, title: '舞萌开字母', subtitle: '舞萌笑传之猜猜呗6'),
    ButtonItem(icon: Icons.gamepad, title: '多人猜歌游戏', subtitle: '什么叫你随便答了一个就对了?!'),
    ButtonItem(icon: Icons.leaderboard, title: '排行榜(仅供参考)', subtitle: '总Rating排行榜'),
    ButtonItem(icon: Icons.leaderboard_outlined, title: '特殊排行榜', subtitle: '各种有意思的排行榜'),
    ButtonItem(icon: Icons.file_upload_sharp, title: '刷新数据', subtitle: '刷新你的舞萌数据'),
    ButtonItem(icon: Icons.network_check, title: '服务器状态', subtitle: '查看舞萌服务器状态'),
    ButtonItem(icon: Icons.update, title: '检查更新', subtitle: '检查应用是否有新版本'),
    ButtonItem(icon: Icons.poll_outlined, title: '问卷调查', subtitle: '助力ChiffonMai更上一层楼!'),
    ButtonItem(icon: Icons.favorite, title: '收藏夹', subtitle: '管理你收藏的谱面'),
    ButtonItem(icon: Icons.play_arrow, title: '自定义谱面播放', subtitle: '播放你自己本地的谱面')
  ];

  @override
  Widget build(BuildContext context) {
    // 获取屏幕尺寸
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

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

          // 层级3：第二张虚化装饰图 - 居中显示，与层级2重叠，增强视觉效果
          Center(
            child: Transform.translate(
              offset: Offset(0, -screenHeight * 0.03),
              child: Transform.scale(
                scale: 1,
                child: Image.asset(
                  'assets/userinfobg.png',
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
                      color: AppConstants.textPrimaryColor,
                      fontSize: screenWidth * 0.06, // 根据屏幕宽度调整字号
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.01), // 添加间距
                  Text(
                    "基本信息",
                    style: TextStyle(
                      color: AppConstants.textPrimaryColor,
                      fontSize: screenWidth * 0.045,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          // 层级4：个人信息静态文本
            Positioned(
              left: screenWidth * 0.5,
              top: screenHeight * 0.21,
              child: _buildUserInfo(context),
            ),

          
          // 功能中心标题
          Positioned(
            left: screenWidth * 0.04,
            right: screenWidth * 0.04,
            bottom: screenHeight * 0.62, // 在GridView上方定位
            child: Center(
              child: Text(
                "功能中心",
                style: TextStyle(
                  color: AppConstants.textPrimaryColor,
                  fontSize: screenWidth * 0.045,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // 层级5：核心功能区 - 直接使用Positioned定位GridView
          Positioned(
            left: screenWidth * 0.02,
            right: screenWidth * 0.02,
            bottom: screenHeight * 0.06, // 距离底部减小，为版权信息留出空间
            height: screenHeight * 0.55, // 根据屏幕高度调整
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                boxShadow: const [AppConstants.defaultShadow],
              ),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.03, vertical: screenHeight * 0.015),
                child: GridView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: AppConstants.crossAxisCount,
                    crossAxisSpacing: screenWidth * 0.02,
                    mainAxisSpacing: screenHeight * 0.01,
                    childAspectRatio: screenWidth > 600 ? 1.3 : 1.2,
                  ),
                  itemCount: buttonItems.length,
                  itemBuilder: (context, index) {
                    final item = buttonItems[index];
                    return _buildCustomButton(item, context);
                  },
                ),
              ),
            ),
          ),
          
          // 层级6：底部版权信息
          Positioned(
            bottom: screenHeight * 0.015,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "ChiffonMai by ChiFFoN 2026",
                style: TextStyle(
                  color: AppConstants.textPrimaryColor,
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
                    color: _isInitializationCompleted ? Colors.green.withValues(alpha: 0.85) : Colors.black.withValues(alpha: 0.7),
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
                            color: Colors.white,
                          ),
                        ),
                      SizedBox(width: screenWidth * 0.02),
                      Text(
                        _initializationProgress,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
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
              color: AppConstants.textPrimaryColor,
              fontSize: screenWidth * 0.05,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              height: 1.2,
            ),
          ),
          Text(
            "刷新数据",
            style: TextStyle(
              color: AppConstants.textPrimaryColor,
              fontSize: screenWidth * 0.05,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              height: 1.2,
            ),
          ),
          Text(
            "刷新成绩",
            style: TextStyle(
              color: AppConstants.textPrimaryColor,
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
              color: AppConstants.textPrimaryColor,
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
              color: AppConstants.textSecondaryColor,
              fontSize: screenWidth * 0.045,
              fontWeight: FontWeight.normal,
            ),
          ),
          Text(
            "$_best50TotalRA",
            style: TextStyle(
              color: AppConstants.textSecondaryColor,
              fontSize: screenWidth * 0.07,
              fontWeight: FontWeight.w600,
              height: 0.8,
            ),
          ),
          Text(
            "$_best35TotalRA+$_best15TotalRA",
            style: TextStyle(
              color: AppConstants.textSecondaryColor,
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
      barrierDismissible: true,
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
                            style: TextStyle(fontSize: 12, color: Colors.grey),
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
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: progress / 100,
                            minHeight: 8,
                          ),
                          SizedBox(height: 8),
                          Text(
                            progressText,
                            style: TextStyle(fontSize: 14),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '$progress%',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 16),
                          // 随机加载提示
                          Text(
                            currentLoadingTip,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
      await Future.delayed(Duration(milliseconds: 100));
      
      // 清除推荐结果缓存
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(CacheKeyConstant.recommendationResults);
        debugPrint('推荐结果缓存已清除');
      } catch (e) {
        debugPrint('清除推荐结果缓存失败: $e');
      }
      
      onProgress(10, '正在换取访问令牌...');
      await Future.delayed(Duration(milliseconds: 100));
      
      // 使用授权码换取令牌
      final success = await LuoXueUserPlayDataManager().exchangeCodeForToken(authCode);
      
      if (success) {
        onProgress(15, '授权成功，正在保存数据源...');
        await Future.delayed(Duration(milliseconds: 100));
        
        // 授权成功，保存数据源为落雪
        await _saveLastDataSource('luoxue');
        
        onProgress(20, '正在刷新歌曲数据...');
        await Future.delayed(Duration(milliseconds: 100));
        
        // 使用智能刷新：初次拉取获取全量maidata，后续只获取追加歌曲的maidata
        await MaimaiMusicDataManager().refreshDataWithSmartMaidata();
        
        onProgress(35, '正在刷新难度数据...');
        await Future.delayed(Duration(milliseconds: 100));
        
        // 从API获取并更新难度数据
        await DiffMusicDataManager().fetchAndUpdateDiffData();
        
        onProgress(50, '正在刷新标签数据...');
        await Future.delayed(Duration(milliseconds: 100));
        
        // 刷新标签数据
        await RecommendByTagsService.initializeTags();
        
        onProgress(60, '正在刷新别名数据...');
        await Future.delayed(Duration(milliseconds: 100));
        
        // 刷新别名数据
        await SongAliasManager.instance.refresh();
        
        onProgress(65, '正在获取玩家信息...');
        await Future.delayed(Duration(milliseconds: 100));
        
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
        await Future.delayed(Duration(milliseconds: 100));
        
        // 获取玩家成绩并转换为 RecordItem（自动更新缓存）
        final playerRecords = await LuoXueUserPlayDataManager().getPlayerRecordsAsRecordItems();
        debugPrint('玩家成绩数量: ${playerRecords?.length ?? 0}');
        
        onProgress(85, '正在计算 Best50 数据...');
        await Future.delayed(Duration(milliseconds: 100));
        
        // 从落雪数据计算并更新首页的 Best50 数据
        if (playerRecords != null && playerRecords.isNotEmpty) {
          await _calculateBest50FromLuoXueRecords(playerRecords);
        }
        
        onProgress(95, '正在保存数据...');
        await Future.delayed(Duration(milliseconds: 100));
        
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
      await Future.delayed(Duration(milliseconds: 100));
      
      // 清除推荐结果缓存
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(CacheKeyConstant.recommendationResults);
        debugPrint('推荐结果缓存已清除');
      } catch (e) {
        debugPrint('清除推荐结果缓存失败: $e');
      }
      
      onProgress(10, '正在刷新歌曲数据...');
      await Future.delayed(Duration(milliseconds: 100));
      
      // 使用智能刷新：初次拉取获取全量maidata，后续只获取追加歌曲的maidata
      await MaimaiMusicDataManager().refreshDataWithSmartMaidata();
      
      onProgress(30, '正在刷新难度数据...');
      await Future.delayed(Duration(milliseconds: 100));
      
      // 从API获取并更新难度数据
      await DiffMusicDataManager().fetchAndUpdateDiffData();
      
      onProgress(45, '正在刷新标签数据...');
      await Future.delayed(Duration(milliseconds: 100));
      
      // 刷新标签数据
      await RecommendByTagsService.initializeTags();
      
      onProgress(55, '正在刷新别名数据...');
      await Future.delayed(Duration(milliseconds: 100));
      
      // 刷新别名数据
      await SongAliasManager.instance.refresh();
      
      onProgress(65, '正在获取用户数据...');
      await Future.delayed(Duration(milliseconds: 100));
      
      // 从API获取并更新用户游玩数据
      final userPlayDataManager = UserPlayDataManager();
      final userPlayData = await userPlayDataManager.fetchUserPlayData(qq);
      
      onProgress(75, '正在获取Best50数据...');
      await Future.delayed(Duration(milliseconds: 100));
      
      final best50Manager = UserBest50Manager();
      final best50Data = await best50Manager.getUserBest50(qq);
      debugPrint(best50Data.toString());
      
      // 更新用户昵称
      if (userPlayData != null && userPlayData.containsKey('nickname')) {
        setState(() {
          _userNickname = userPlayData['nickname'];
        });
      }
      
      onProgress(85, '正在计算Rating...');
      await Future.delayed(Duration(milliseconds: 100));
      
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
      setState(() {
        _best50TotalRA = totalRA;
        _best35TotalRA = best35RA;
        _best15TotalRA = best15RA;
      });
      
      onProgress(95, '正在保存数据...');
      await Future.delayed(Duration(milliseconds: 100));
      
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
  
  // 构建自定义功能按钮
  Widget _buildCustomButton(ButtonItem item, BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return SizedBox(
      height: screenHeight * 0.12,
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: Colors.transparent, // 按钮整体背景设为透明
          side: const BorderSide(
            color: AppConstants.buttonBorderColor,
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
          if (item.title == '问卷调查') {
            final uri = Uri.parse('https://wj.qq.com/s2/26540572/7828/');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
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
          if (item.title == '收藏夹'){
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FavoriteFolderPage()),
            );
          }
        },
        child: Column(
          children: [
            // 上半部分：原背景色，居中图标
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppConstants.buttonBackgroundColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppConstants.borderRadiusLarge),
                    topRight: Radius.circular(AppConstants.borderRadiusLarge),
                  ),
                ),
                child: Center(
                  child: Container(
                    width: screenWidth * 0.09, // 圆形背景的宽度
                    height: screenWidth * 0.09, // 圆形背景的高度
                    decoration: const BoxDecoration(
                      color: Colors.white, // 白色背景
                      shape: BoxShape.circle, // 圆形形状
                    ),
                    child: Center(
                      child: Icon(
                        item.icon,
                        color: AppConstants.textPrimaryColor,
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
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
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
                          color: AppConstants.textPrimaryColor,
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
                          color: AppConstants.textPrimaryColor.withValues(alpha: 0.8),
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