import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:my_first_flutter_app/page/RankingList/AvgScoreRankingListPage.dart';
import 'package:my_first_flutter_app/page/RankingList/FittedRatingRankingListPage.dart';
import 'package:my_first_flutter_app/page/RankingList/RatingRankListPage.dart';
import 'package:my_first_flutter_app/page/RankingList/SpecialRankingListPage.dart';
import 'package:my_first_flutter_app/service/RankingList/AvgRankingListService.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/ApiUrls.dart';
import '../constant/CacheKeyConstant.dart';
import '../constant/LoadingTipsConstant.dart';
import '../service/HomeService.dart';
import '../manager/LZYCheckUpdateManager.dart';
import '../utils/ThemeManager.dart';
import '../utils/AppTheme.dart';
import '../utils/AppConstants.dart';
import 'DifficultyDistributionPage.dart';
import 'SettingsPage.dart';
import '../manager/DivingFish/MaimaiMusicDataManager.dart';
import '../manager/MaidataManager.dart';
import '../manager/SongAliasManager.dart';
import '../entity/FeatureModels.dart';
import 'HubComponents.dart';
import 'FeatureCategoryPage.dart';
import '../utils/FeatureRegistry.dart';
import 'AchievementFullReverseCalculatorPage.dart';
import 'AchievementRateCalculatorPage.dart';
import '../widgets/SyncScoreDialogs.dart';
import 'VersionViewPage.dart' hide AppConstants;
import 'Best50/Best50Page.dart';
import 'Best50/DiffBest50Page.dart';
import 'Best50/PersonalizedBest50Page.dart';
import 'Best50/PersonalizedDiffBest50Page.dart';
import 'History/RatingHistoryPage.dart';
import 'GlobalArcadeMapPage.dart';
import 'Collection/CollectionSearchPage.dart';
import 'GuessChartGame/GuessChartByAliaPage.dart';
import 'GuessChartGame/GuessChartByBlurredCoverPage.dart';
import 'GuessChartGame/GuessChartByCoverPage.dart';
import 'GuessChartGame/GuessChartByInfoPage.dart';
import 'GuessChartGame/GuessChartBySongExcerptPage.dart';
import 'GuessChartGame/GuessSongByOpenLettersPage.dart';
import 'KaleidXScope/KaleidXScopeSelectPage.dart';
import 'FavoriteFolderPage.dart';
import 'MaimaiServerStatusPage.dart';
import 'Multiplayer/MultiplayerLobbyPage.dart';
import 'PaiziProgressPage.dart';
import 'PersonalizedChartPlayConfigure.dart';
import 'Portable/PortablePlayerPage.dart';
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
import 'SupportDeveloperPage.dart';
import 'FriendLinksPage.dart';
import 'CoverRecognitionPage.dart';
import 'ScoreOcrPage.dart';
import 'DataBackupPage.dart';
import 'Awmc/AwmcConsolePage.dart';
import 'Awmc/AwmcSyncFlow.dart';
import 'DailyRecommendPage.dart';
import '../widgets/RefreshDataDialog.dart'
    show
        showRefreshDataDialog,
        executeRefreshData,
        executeAdvancedRefreshData,
        CurrentDataSourceNotifier,
        RefreshDataSource,
        refreshBest50DataWithProgress,
        launchUrlFallback;
// PLAYER OVERVIEW 卡片上半部分 → 「刷新数据（高级）」对话框
import '../widgets/AdvancedRefreshDataDialog.dart'
    show showAdvancedRefreshDataDialog;
import 'FriendComparePage.dart';
import 'RecentCommentsPage.dart';
import 'RecentRatingsPage.dart';
import 'LuoXue/UpdateLuoXueScorePage.dart';
import '../manager/DivingFishProbeManager.dart';
import '../manager/DivingFish/DivingFishOAuthManager.dart';
import 'package:my_first_flutter_app/utils/FavoriteFeaturesNotifier.dart';
import 'package:my_first_flutter_app/utils/FeatureFlags.dart';
import 'package:my_first_flutter_app/utils/LoginStateNotifier.dart';
import 'package:my_first_flutter_app/utils/UserProfileNotifier.dart';
import '../service/AccountSwitchService.dart';
import '../widgets/AccountSwitchSheet.dart';
import 'package:my_first_flutter_app/utils/ApiClient.dart';
import '../widgets/QrQuickFillButtons.dart';
import '../service/SyncRouteStore.dart';
import '../service/SyncStatsService.dart';
import '../utils/SyncRouteNotifier.dart';
import '../utils/UpdateNotifier.dart';
import '../widgets/SyncRouteFooter.dart';

// ds值与歌曲对应关系数据类已随 _calculateRatingLimits 一起抽离到
// lib/widgets/RefreshDataDialog.dart，不再需要此处的定义。

// 首页初始化时间间隔常量
class _InitInterval {
  static const Duration initializationCooldown = Duration(days: 7);
}

// 应用常量类：集中管理所有硬编码的配置值

// ButtonItem / ButtonCategory 已移至 ../entity/FeatureModels.dart

/// 首页组件：有状态组件，包含所有页面元素和业务数据
class HomePage extends StatefulWidget {
  final VoidCallback? onFirstFrameRendered;
  final VoidCallback? onEntertainmentTap;

  const HomePage(
      {super.key, this.onFirstFrameRendered, this.onEntertainmentTap});

  @override
  State<HomePage> createState() => HomePageState();
}

/// 首页状态类：处理页面状态、存储数据、实现布局构建
class HomePageState extends State<HomePage> {
  void showAccountManageDialog() {
    if (!mounted) return;
    _showAccountManageDialog(context);
  }

  // 收藏的功能（实际数据来自 FavoriteFeaturesNotifier，字段保留便于本地访问）
  Set<String> _favoriteTitles = <String>{};

  // 后台初始化状态
  bool _isBackgroundInitializing = false;
  bool _isInitializationCompleted = false;
  String _initializationProgress = '';

  // 用户数据（昵称 / Rating）：实际数据来自 UserProfileNotifier，字段保留便于本地访问
  String _userNickname = "";
  // 0 表示尚未从水鱼/落雪拉取真实数据；UI 层用 _displayBest* 回落为 "-"
  int _best50TotalRA = 0;
  int _best35TotalRA = 0;
  int _best15TotalRA = 0;

  // 缓存的QQ号（实际数据来自 UserProfileNotifier，字段保留便于本地访问）
  String _cachedQQ = "";

  // 初始化方法，用于从本地存储加载数据
  @override
  void initState() {
    super.initState();
    // 监听用户档案共享状态（昵称 / Rating / QQ 跨页面同步）
    UserProfileNotifier.instance.addListener(_onUserProfileChanged);
    _onUserProfileChanged();
    // 加载当前数据源（首页摘要"数据源"显示用），并确保旧数据已迁进双账号系统
    CurrentDataSourceNotifier.load().then((_) {
      AccountSwitchService.ensureMigrated();
    });
    _loadUserData();
    _autoCheckUpdate();
    _checkDivingFishLoginStatus();
    // 注意：收藏列表的实时同步不再走 addListener，
    // 而是直接在 build 顶层用 ValueListenableBuilder<FavoritesPayload>
    // 包整个 Scaffold，确保 IndexedStack 内任意子页面点星标时首页都能立即重建。
    _loadFavoriteCount();
    // 无论冷却状态如何，都先加载别名缓存到内存
    // 防止冷却期间别名丢失（详见：冷却逻辑在_initializeDataInBackground内）
    SongAliasManager.instance.init();
    _initializeDataInBackground();
    // 同步入口的线路 + 统计（与「系统」hub 页共享同一份状态；重复调用幂等）
    SyncRouteNotifier.instance.addListener(_onSyncRouteChanged);
    SyncRouteNotifier.instance.ensureLoaded();

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
      _userNickname = prefs.getString('userNickname') ?? '';
      // 0 表示尚未拉到真实数据，UI 显示为 "-"
      _best50TotalRA = prefs.getInt('best50TotalRA') ?? 0;
      _best35TotalRA = prefs.getInt('best35TotalRA') ?? 0;
      _best15TotalRA = prefs.getInt('best15TotalRA') ?? 0;
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
    // 曲库缓存是否可用：用于「冷却期内但缓存缺失」的抢占式兜底。
    //
    // 背景（真实故障）：冷却期只看 `lastInitializationTimestamp`，一旦上次
    // 初始化**失败/被跳过**（离线、接口 502、恢复备份后 prefs 被清空……）
    // 而这个时间戳照样被写下，就会连续 7 天跳过自动初始化。结果是
    // `cachedSongs` 长期为空，所有单人猜歌页抽不到曲 → 永久转圈。
    // 所以缓存缺失时必须无视冷却期，立刻补一次拉取。
    final hasSongCache = await MaimaiMusicDataManager().hasValidMusicCache(
      maxAge: const Duration(days: 30),
    );

    if (hasSongCache) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final lastInitMillis =
            prefs.getInt(CacheKeyConstant.lastInitializationTimestamp);
        if (lastInitMillis != null) {
          final lastInit = DateTime.fromMillisecondsSinceEpoch(lastInitMillis);
          final diff = DateTime.now().difference(lastInit);
          if (diff < _InitInterval.initializationCooldown) {
            debugPrint(
                '距上次初始化仅 ${diff.inHours} 小时，跳过自动初始化（冷却时间：${_InitInterval.initializationCooldown.inHours} 小时）');
            return;
          }
        }
      } catch (e) {
        debugPrint('检查上次初始化时间失败: $e，继续执行初始化');
      }
    } else {
      debugPrint('曲库缓存缺失，无视 7 天冷却期，立即执行数据初始化');
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
        } else {
          _initializationProgress =
              '初始化失败: ${result.errorMessage}\n建议检查网络连接后重启应用';
        }
      });

      // 冷却时间戳只在「曲库真的拿到了」时才写。
      //
      // 原先无论成功与否都写，于是「首次启动时没网」会让 App 认下这次初始化，
      // 接下来 7 天都不再自动补拉，`cachedSongs` 一直是空的 ——
      // 这正是「所有单人猜歌卡加载页」的成因之一。
      final libraryReady = await MaimaiMusicDataManager().hasValidMusicCache(
        maxAge: const Duration(days: 30),
      );
      if (result.success && libraryReady) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt(
            CacheKeyConstant.lastInitializationTimestamp,
            DateTime.now().millisecondsSinceEpoch,
          );
        } catch (e) {
          debugPrint('保存初始化时间戳失败: $e');
        }
      } else if (result.success) {
        debugPrint('曲库仍为空，不记录初始化时间戳（下次进首页会重试）');
      }

      if (!mounted) return;
      // 4秒后隐藏完成提示
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() {
            _isInitializationCompleted = false;
            _initializationProgress = '';
          });
        }
      });
    }
  }

  // 保存QQ号到本地存储
  Future<void> _saveQQ(String qq) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cachedQQ', qq);
    await prefs.setString(CacheKeyConstant.probeDivingFishBindQQ, qq);
    if (mounted) {
      setState(() {
        _cachedQQ = qq;
      });
    }
    // 同步共享 notifier，让我的页头像区也能即时更新 QQ 字段
    UserProfileNotifier.replace(UserProfile(
      nickname: _userNickname,
      best50TotalRA: _best50TotalRA,
      best35TotalRA: _best35TotalRA,
      best15TotalRA: _best15TotalRA,
      cachedQQ: qq,
    ));
  }

  // 使用 ValueNotifier 以便 FeatureCategoryPage 等子页面也能响应登录状态变化
  final ValueNotifier<bool> _loginStateNotifier = ValueNotifier<bool>(false);
  bool get _isDivingFishLoggedIn => _loginStateNotifier.value;

  @override
  void dispose() {
    UserProfileNotifier.instance.removeListener(_onUserProfileChanged);
    SyncRouteNotifier.instance.removeListener(_onSyncRouteChanged);
    _loginStateNotifier.dispose();
    super.dispose();
  }

  /// 线路 / 统计变化时重建首页（收藏区那一行要立刻反映）。
  void _onSyncRouteChanged() {
    if (mounted) setState(() {});
  }

  /// 渲染用的 Rating：值为 0 时回落为 "-"，避免暴露 15049/10670/4379 这类硬编码占位。
  String _displayBest50RA() => _best50TotalRA == 0 ? '-' : '$_best50TotalRA';
  String _displayBest35RA() => _best35TotalRA == 0 ? '-' : '$_best35TotalRA';
  String _displayBest15RA() => _best15TotalRA == 0 ? '-' : '$_best15TotalRA';

  /// 共享用户档案变更回调：把 notifier 中的值同步到本地字段，
  /// 触发 setState 后首页"欢迎回来，xxx" / 仪表盘 Rating 等区域立刻更新。
  void _onUserProfileChanged() {
    if (!mounted) return;
    final p = UserProfileNotifier.instance.value;
    setState(() {
      _userNickname = p.nickname;
      _best50TotalRA = p.best50TotalRA;
      _best35TotalRA = p.best35TotalRA;
      _best15TotalRA = p.best15TotalRA;
      _cachedQQ = p.cachedQQ;
    });
  }

  Future<void> _checkDivingFishLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final jwt = prefs.getString(CacheKeyConstant.probeDivingFishToken) ?? '';
    // 只更新 ValueNotifier；登录态变化本身就是触发重建的信号，不需要再 setState
    final loggedIn = jwt.isNotEmpty;
    _loginStateNotifier.value = loggedIn;
    // 同步共享 LoginStateNotifier，让"我的"页等监听者也能感知登录态变化
    LoginStateNotifier.setLoggedIn(loggedIn);
  }

  Future<void> _loadFavoriteCount() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(CacheKeyConstant.favoriteFeatures) ?? [];
    if (mounted) {
      setState(() {
        _favoriteTitles = raw.toSet();
      });
    }
  }

  Future<void> _toggleFavorite(String title) async {
    // 通过共享 notifier 切换；顶层 ValueListenableBuilder 会随之重建首页 UI。
    await FavoriteFeaturesNotifier.toggle(title);
  }

  Future<void> _logoutDivingFish() async {
    // 集中清理：清掉水鱼账号相关的所有成绩 / 缓存（保留歌曲 / 收藏品等静态数据）
    if (!mounted) return;
    // 立即给出视觉反馈：清缓存是逐键移除，可能耗时较久，先弹一个加载框
    // 避免出现"点了半天没反应"的空白等待。
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在登出水鱼账号…'),
          ],
        ),
      ),
    );
    try {
      await UserProfileNotifier.clearShuiyuAccountCache();
      // 双账号：清掉水鱼账号的存档；若当前正是水鱼则回落到落雪（有缓存时）。
      await AccountSwitchService.onAccountLoggedOut(
          RefreshDataSource.shuiyu);
    } catch (e) {
      debugPrint('登出水鱼账号失败：$e');
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    LoginStateNotifier.setLoggedIn(false);
    _loginStateNotifier.value = false;
    Fluttertoast.showToast(msg: '已登出水鱼账号');
  }

  List<ButtonCategory> get _buttonCategories =>
      FeatureRegistry.allCategories(_isDivingFishLoggedIn);

  /// 不参与首页搜索和收藏的分类名集合
  static const Set<String> _excludedFromSearch = <String>{};

  /// 参与首页搜索和收藏的分类（已过滤掉 _excludedFromSearch 中的项）
  List<ButtonCategory> get _searchableCategories => _buttonCategories
      .where((c) => !_excludedFromSearch.contains(c.name))
      .toList();

  @override
  Widget build(BuildContext context) {
    // 顶层直接监听共享收藏列表：
    //   IndexedStack 子页面点星标 / 收藏管理页删除收藏 / 其他 Hub 页切换收藏时，
    //   整页 Scaffold 必定重建，"收藏的功能"区域即时刷新。
    //   不依赖 addListener 隐式 setState（IndexedStack 中非可见子页在某些情况下
    //   不会触发自身的 markNeedsBuild 链路）。
    return ValueListenableBuilder<FavoritesPayload>(
      valueListenable: FavoriteFeaturesNotifier.instance,
      builder: (context, payload, _) {
        // 直接用 notifier 的最新 titles 渲染；本地 _favoriteTitles 字段仍保留，
        // 仅给 _loadFavoriteCount 初始化时使用
        return _buildScaffold(context, payload.titles);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, Set<String> favoriteTitles) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ChiffonMai',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: scheme.primary,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _userNickname.isEmpty
                            ? '请登录水鱼账号'
                            : '欢迎回来，$_userNickname',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '切换主题',
                  onPressed: _showThemeDialog,
                  icon: const Icon(Icons.brightness_6_outlined),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _buildDashboardSummary(context, brightness),
            const SizedBox(height: 28),
            _buildHomeSectionTitle(context, '快捷入口', '现在就去做点什么'),
            const SizedBox(height: 12),
            _buildQuickActions(context),
            const SizedBox(height: 28),
            // 顶层 ValueListenableBuilder 已保证整页重建，直接用 notifier 传入的 titles 渲染。
            _buildFavoriteFeaturesSection(context, favoriteTitles),
            if (_isBackgroundInitializing || _isInitializationCompleted) ...[
              const SizedBox(height: 16),
              _buildInitializationStatus(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardSummary(BuildContext context, Brightness brightness) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary,
            Color.alphaBlend(
                scheme.secondary.withValues(alpha: .38), scheme.primary)
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 上半部分（PLAYER OVERVIEW 标题 + TOTAL RATING）点击 → 「刷新数据（高级）」
        Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: _openAdvancedRefreshData,
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                      child: Text('PLAYER OVERVIEW',
                          style: TextStyle(
                              color: scheme.onPrimary.withValues(alpha: .72),
                              letterSpacing: 1.5,
                              fontSize: 11,
                              fontWeight: FontWeight.w800))),
                  Icon(Icons.music_note,
                      color: scheme.onPrimary.withValues(alpha: .3), size: 28),
                ]),
                const SizedBox(height: 8),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(_displayBest50RA(),
                      style: TextStyle(
                          color: scheme.onPrimary,
                          fontSize: 36,
                          height: 1,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(width: 10),
                  Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text('TOTAL RATING',
                          style: TextStyle(
                              color: scheme.onPrimary.withValues(alpha: .76),
                              fontSize: 12,
                              fontWeight: FontWeight.w700))),
                ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        ValueListenableBuilder<RefreshDataSource>(
          valueListenable: CurrentDataSourceNotifier.instance,
          builder: (context, source, _) => Row(children: [
            _summaryMetric(context, 'Best35', _displayBest35RA()),
            _summaryMetric(context, 'Best15', _displayBest15RA()),
            // 点「数据源」即可切换水鱼 / 落雪账号（使用缓存，不联网）
            _summaryMetric(
              context,
              '数据源',
              source.displayName,
              onTap: _showAccountSwitchSheet,
              trailingIcon: Icons.swap_horiz_rounded,
            ),
          ]),
        ),
      ]),
    );
  }

  // 顶部头像 / 姓名框入口已迁移到 MeHubPage；选择结果仍存于 SharedPreferences，
  // 供 Best50 / 拟合等图片导出时由 ExportUserInfoWidget 读取。

  Widget _summaryMetric(BuildContext context, String label, String value,
      {VoidCallback? onTap, IconData? trailingIcon}) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    final content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: onPrimary.withValues(alpha: .68), fontSize: 12)),
          const SizedBox(height: 3),
          Row(children: [
            Flexible(
              child: Text(value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: onPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: 2),
              Icon(trailingIcon,
                  size: 14, color: onPrimary.withValues(alpha: .8)),
            ],
          ]),
        ]);
    return Expanded(
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: content,
            ),
    );
  }

  Widget _buildHomeSectionTitle(
      BuildContext context, String title, String subtitle) {
    final scheme = Theme.of(context).colorScheme;
    return Row(children: [
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(subtitle,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant)),
      ])),
    ]);
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(children: [
      Expanded(
          child:
              _homeAction(context, Icons.score_outlined, '查成绩', '游玩记录', '查成绩')),
      const SizedBox(width: 12),
      Expanded(
          child: _homeAction(context, Icons.leaderboard_outlined, 'Best50',
              '评分构成', 'Best50')),
      const SizedBox(width: 12),
      Expanded(child: _homeAction(context, Icons.search, '查歌曲', '曲库搜索', '查歌曲')),
      const SizedBox(width: 12),
      Expanded(
          child: _homeAction(
              context, Icons.today_outlined, '每日推荐', '今日选曲', '每日推荐')),
    ]);
  }

  Widget _buildAllFeaturesList(BuildContext context) {
    final categories = _searchableCategories;
    return Column(
      children: [
        for (final category in categories)
          _buildCategoryCard(category, context),
      ],
    );
  }

  Widget _homeAction(BuildContext context, IconData icon, String title,
      String subtitle, String featureTitle) {
    return HubQuickAction(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: () => _tapFeatureTitle(featureTitle),
    );
  }

  void _tapFeatureTitle(String title) {
    switch (title) {
      case '查成绩':
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => UserScoreSearchPage()));
        return;
      case 'Best50':
        Navigator.push(context, MaterialPageRoute(builder: (_) => B50Page()));
        return;
      case '查歌曲':
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => SongSearchPage()));
        return;
      case '每日推荐':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const DailyRecommendPage()));
        return;
      case '我的收藏夹':
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => FavoriteFolderPage()));
        return;
    }
    final item = _buttonCategories
        .expand((category) => category.items)
        .where((item) => item.title == title)
        .firstOrNull;
    if (item != null) _handleFeatureTap(item);
  }

  Widget _buildInitializationStatus(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final completed = _isInitializationCompleted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          color: completed
              ? scheme.secondaryContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        if (!completed)
          const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
        else
          Icon(Icons.check_circle_outline, color: scheme.onSecondaryContainer),
        const SizedBox(width: 10),
        Expanded(
            child: Text(_initializationProgress,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: completed
                        ? scheme.onSecondaryContainer
                        : scheme.onSurfaceVariant,
                    fontSize: 12))),
      ]),
    );
  }

  // 收藏品选择 tab 按钮已迁移到独立的 CollectionPickerSheet StatefulWidget
  //（避免 showModalBottomSheet.builder 多次调用时局部变量 activeTab 被重置的 bug）

  // 保存上次更新使用的数据源
  Future<void> _saveLastDataSource(String dataSource) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(CacheKeyConstant.lastDataSource, dataSource);
    } catch (e) {
      debugPrint('保存上次数据源失败: $e');
    }
  }

  SyncCallbacks get _syncCallbacks => SyncCallbacks(
        cachedQQ: _cachedQQ,
        onSaveQQ: _saveQQ,
        onSaveLastDataSource: _saveLastDataSource,
        onRefreshAfterSync: ({
          required String qq,
          required void Function(double progress, String text) onProgress,
          required bool participateRankings,
          required bool showNickname,
        }) async {
          await refreshBest50DataWithProgress(
            qq,
            (p, t) {
              debugPrint('[HomePage] 后台刷新 $p%: $t');
              onProgress(0.70 + (p / 100) * 0.30, t);
            },
            participateRankings: participateRankings,
            showNickname: showNickname,
          );
        },
        onLoginStateChanged: () async {
          await _loadUserData();
          await _checkDivingFishLoginStatus();
        },
      );

  /// 线路2：通过 AWMC 网关同步（与「系统」hub 页共用 [AwmcSyncFlow]）。
  ///
  /// 首页没有按钮进度条，用顶部提示代替；两条线路的行为与 hub 页完全一致。
  Future<void> _syncToDivingFishViaAwmc() async {
    if (!mounted) return;
    final outcome = await AwmcSyncFlow.run(
      context,
      target: AwmcSyncTarget.divingFish,
    );
    if (!mounted || outcome.cancelled) return;
    Fluttertoast.showToast(
      msg: outcome.ok
          ? AwmcSyncFlow.successToast(AwmcSyncTarget.divingFish, outcome)
          : (outcome.message ?? '同步失败'),
    );
    SyncRouteNotifier.instance.refreshStatsSoon();
  }

  /// 线路2：通过 AWMC 网关同步到落雪（同上）。
  Future<void> _syncToLuoXueViaAwmc() async {
    if (!mounted) return;
    final outcome = await AwmcSyncFlow.run(
      context,
      target: AwmcSyncTarget.luoXue,
    );
    if (!mounted || outcome.cancelled) return;
    Fluttertoast.showToast(
      msg: outcome.ok
          ? AwmcSyncFlow.successToast(AwmcSyncTarget.luoXue, outcome)
          : (outcome.message ?? '同步失败'),
    );
    SyncRouteNotifier.instance.refreshStatsSoon();
  }

  Future<void> _syncToDivingFish() async {
    final prefs = await SharedPreferences.getInstance();
    final hasJwt =
        (prefs.getString(CacheKeyConstant.probeDivingFishToken) ?? '')
            .isNotEmpty;

    if (!hasJwt) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('提示'),
          content: const Text('请先登录你的水鱼账号，再使用同步功能。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('去登录'),
            ),
          ],
        ),
      );
      if (ok == true && mounted) {
        await SyncScoreDialogs.showDivingFishLoginDialog(
            context, _syncCallbacks);
        final prefs2 = await SharedPreferences.getInstance();
        final hasJwt2 =
            (prefs2.getString(CacheKeyConstant.probeDivingFishToken) ?? '')
                .isNotEmpty;
        if (hasJwt2 && mounted) {
          await SyncScoreDialogs.showDivingFishSyncDialog(
              context, _syncCallbacks);
        }
      }
      return;
    }

    final bindQQ =
        prefs.getString(CacheKeyConstant.probeDivingFishBindQQ) ?? '';
    final cachedQQ = _cachedQQ.isNotEmpty ? _cachedQQ : null;
    if (bindQQ.isNotEmpty && cachedQQ != null && bindQQ != cachedQQ) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('账号不匹配'),
          content: Text(
            '当前登录水鱼账号绑定的 QQ（$bindQQ）与本机缓存的 QQ（$cachedQQ）不一致。\n\n请先登出当前水鱼账号，登录正确的账号后再同步。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('确定'),
            ),
          ],
        ),
      );
      return;
    }

    if (!mounted) return;
    await SyncScoreDialogs.showDivingFishSyncDialog(context, _syncCallbacks);
  }

  // 显示刷新数据对话框（旧版实现已抽离到 lib/widgets/RefreshDataDialog.dart，
  // 这里仅保留给其它可能的本地调用入口；首页/系统 Tab 现统一调用 showRefreshDataDialog）
  Future<void> _autoRefreshAfterSync({
    Future<void> Function(double progress, String text)? onProgress,
  }) async {
    final qq = _cachedQQ.isNotEmpty ? _cachedQQ : null;

    if (qq == null || qq.isEmpty) {
      debugPrint('[HomePage] _autoRefreshAfterSync: QQ 为空，跳过刷新');
      return;
    }

    debugPrint('[HomePage] _autoRefreshAfterSync: 使用 QQ=$qq 自动刷新');

    await refreshBest50DataWithProgress(
      qq,
      (p, t) async {
        debugPrint('[HomePage] 后台刷新 $p%: $t');
        await onProgress?.call(0.70 + (p / 100) * 0.30, t);
      },
      participateRankings: await _getParticipateRankings(),
      showNickname: await _getShowNickname(),
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
      participateRankings =
          prefs.getBool(CacheKeyConstant.participateRankings) ?? false;
      showNickname = prefs.getBool(CacheKeyConstant.showNickname) ?? false;
    }

    Future<void> saveRankingSettings() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
          CacheKeyConstant.participateRankings, participateRankings);
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
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.greyHint(brightness)),
                        ),
                        const SizedBox(height: 12),
                        // 多方式导入按钮（剪贴板 / 相册 / 扫码，公共组件）
                        QrQuickFillButtons(controller: qrController),
                        const SizedBox(height: 12),
                        TextField(
                          controller: qrController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: '舞萌DX | 中二节奏 登入二维码(SGWCMAID...)',
                            hintStyle: TextStyle(
                                fontSize: 13,
                                color:
                                    AppColors.greyHint(brightness, shade: 400)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          title: const Text('参与排行榜',
                              style: TextStyle(fontSize: 14)),
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
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.greyHint(brightness)),
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
                              horizontal: 12,
                              vertical: 10,
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
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        ),
                        if (bindingError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            bindingError!,
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.errorRed(brightness)),
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.warningOrange(brightness)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppColors.warningOrange(brightness)
                                      .withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline,
                                    size: 16,
                                    color: AppColors.warningOrange(brightness)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '同步进行中，请耐心等待，不要进行其他操作',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.warningOrange(
                                            brightness)),
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
                                child:
                                    CircularProgressIndicator(strokeWidth: 2.5),
                              ),
                            ),
                          ),
                        ],

                        // 完成/失败/取消：阶段图标
                        if (currentStage == SyncStage.completed ||
                            currentStage == SyncStage.failed ||
                            currentStage == SyncStage.cancelled) ...[
                          const SizedBox(height: 8),
                          Center(
                              child: _buildStageIcon(currentStage, brightness)),
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
                            LinearProgressIndicator(
                                value: progress,
                                color: AppColors.linkBlue(brightness))
                          else
                            LinearProgressIndicator(
                                color: AppColors.linkBlue(brightness)),
                          const SizedBox(height: 12),
                          Center(
                            child: Text(
                              _currentTip,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.greyHint(brightness,
                                      shade: 600)),
                            ),
                          ),
                        ],
                        if (currentStage == SyncStage.completed) ...[
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              '成绩已同步！可前往水鱼查看',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.greyHint(brightness,
                                      shade: 600)),
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
                              final exportData = await DivingFishProbeManager()
                                  .exportToDivingFish();

                              if (exportData != null &&
                                  (exportData.tryGet<int>('status') ?? 0) ==
                                      200) {
                                final count =
                                    exportData.tryGet<int>('exported') ?? 0;

                                // 自动刷新本地数据
                                setState(() {
                                  statusText = '同步成功！正在刷新本地数据...';
                                });
                                String? qq =
                                    _cachedQQ.isNotEmpty ? _cachedQQ : null;
                                if (qq == null) {
                                  qq = await DivingFishProbeManager()
                                      .fetchBindQQ();
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
                                    await Future.delayed(
                                        const Duration(milliseconds: 80));
                                  },
                                );

                                Fluttertoast.showToast(
                                    msg: '全部完成！$count 条成绩已同步，本地数据已刷新');
                                final fc =
                                    DivingFishProbeManager().currentFriendCode;
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

                        final result =
                            await DivingFishProbeManager().syncByCabinetQr(
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
                          await Future.delayed(
                              const Duration(milliseconds: 300));

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
                                await Future.delayed(
                                    const Duration(milliseconds: 80));
                              },
                            );
                          } else {
                            // 没有 QQ，假装走一段进度让用户看到
                            for (int i = 0; i < 4; i++) {
                              setState(() => progress = 0.70 + (i + 1) * 0.05);
                              await Future.delayed(
                                  const Duration(milliseconds: 200));
                            }
                          }

                          setState(() {
                            currentStage = SyncStage.completed;
                            progress = 1.0;
                            if (hasQQ) {
                              statusText =
                                  '全部完成！${result.exportedCount} 条成绩已同步，本地数据已刷新';
                            } else {
                              statusText =
                                  '同步完成！${result.exportedCount} 条成绩已推送到水鱼\n（需先登录水鱼才能自动刷新本地数据）';
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
              ),
            ); // PopScope closing
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
                    color: loginSuccess
                        ? AppColors.successGreen(brightness)
                        : Theme.of(context).colorScheme.onSurface,
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
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.greyHint(brightness)),
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
                            horizontal: 12,
                            vertical: 10,
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
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                      if (errorMsg != null) ...[
                        const SizedBox(height: 8),
                        Text(errorMsg!,
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.errorRed(brightness))),
                      ],
                    ] else ...[
                      Icon(Icons.check_circle,
                          color: AppColors.successGreen(brightness), size: 48),
                      const SizedBox(height: 12),
                      Text(
                        statusText.isNotEmpty ? statusText : '登录成功',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ImportToken 已获取并缓存',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.greyHint(brightness)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Token: ${importedToken ?? "***"}',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.greyHint(brightness, shade: 600)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '现在可以使用"同步成绩"功能一键同步到水鱼了',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.greyHint(brightness)),
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
                              strokeWidth: 2,
                              color: Colors.white,
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

                            if (result != null &&
                                result.tryGet<String>('importToken') != null) {
                              final token =
                                  result.tryGet<String>('importToken') ?? '';
                              final nickname =
                                  result.tryGet<String>('nickname') ?? '';
                              final plate =
                                  result.tryGet<String>('plate') ?? '';
                              setState(() {
                                isLoggingIn = false;
                                loginSuccess = true;
                                importedToken = token.isNotEmpty
                                    ? '${token.substring(0, token.length > 12 ? 12 : token.length)}...'
                                    : '***';
                                statusText =
                                    '欢迎，$nickname${plate.isNotEmpty ? " ($plate)" : ""}';
                              });
                              // 登录成功后立即更新缓存的QQ号，确保排行榜等页面使用新账号标识
                              final bindQQ =
                                  result.tryGet<String>('bind_qq') ?? '';
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
            title: Text('主题设置',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.onSurface)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 背景透明度（浅色/深色模式共用）
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('背景透明度',
                              style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  fontSize: 14)),
                          Text('${(overlayOpacity * 100).round()}%',
                              style: TextStyle(
                                  color: AppColors.linkBlue(brightness),
                                  fontSize: 13)),
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
                        isDarkSelected
                            ? '数值越高背景越暗，0% 为原始背景图'
                            : '数值越高背景越淡，0% 为原始背景图',
                        style: TextStyle(
                            fontSize: 11,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                // 浅色模式
                _buildThemeOption(Icons.light_mode, '浅色模式', '始终使用浅色主题',
                    ThemeMode.light, currentMode, setDialogState),
                const Divider(),
                // 深色模式
                _buildThemeOption(Icons.dark_mode, '深色模式', '始终使用深色主题',
                    ThemeMode.dark, currentMode, setDialogState),
                // 纯黑模式开关 — 仅深色模式可用
                if (isDarkSelected) ...[
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('纯黑背景',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 14)),
                    subtitle: Text('使用真正的纯黑背景（#000000），隐藏背景图',
                        style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                    value: pureBlackEnabled,
                    onChanged: (value) {
                      ThemeManager().setPureBlackEnabled(value);
                      setDialogState(() {});
                    },
                  ),
                ],
                const Divider(),
                // 跟随系统
                _buildThemeOption(Icons.settings_suggest, '跟随系统', '根据系统设置自动切换',
                    ThemeMode.system, currentMode, setDialogState),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  );
                },
                child: Text('更多设置',
                    style: TextStyle(color: AppColors.linkBlue(brightness))),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('完成',
                    style: TextStyle(color: AppColors.linkBlue(brightness))),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildThemeOption(IconData icon, String title, String subtitle,
      ThemeMode mode, ThemeMode currentMode, StateSetter setDialogState) {
    final brightness = Theme.of(context).brightness;
    final isSelected = currentMode == mode;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon,
          color: isSelected
              ? AppColors.linkBlue(brightness)
              : Theme.of(context).colorScheme.onSurface),
      title: Text(title,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface, fontSize: 14)),
      subtitle: Text(subtitle,
          style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
      trailing: isSelected
          ? Icon(Icons.check, color: AppColors.linkBlue(brightness), size: 20)
          : null,
      selected: isSelected,
      onTap: () {
        ThemeManager().setThemeMode(mode);
        setDialogState(() {});
      },
    );
  }

  // 显示账号管理对话框
  /// 打开「切换账号」底部面板；目标无缓存时引导去刷新对应数据源。
  Future<void> _showAccountSwitchSheet() async {
    await showAccountSwitchSheet(
      context,
      onNeedRefresh: (source) => _openRefreshData(initialSource: source),
    );
  }

  /// 跑一遍「刷新数据」流程（首页用常驻 SnackBar 显示进度）。
  Future<void> _openRefreshData({RefreshDataSource? initialSource}) async {
    final request = await showRefreshDataDialog(
      context,
      initialSource: initialSource,
    );
    if (request == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    // SnackBar 同一时刻只保留一条，所以每次进度更新前先清空旧的，
    // 否则高频 onProgress 会把 SnackBar 排成长队。
    void showProgress(String text) {
      messenger.clearSnackBars();
      messenger.showSnackBar(SnackBar(
        content: Text(text),
        duration: const Duration(minutes: 10),
      ));
    }

    showProgress('正在刷新数据...');
    var failed = false;
    try {
      await executeRefreshData(request, onProgress: (p, t) {
        if (!mounted) return;
        showProgress('$t ($p%)');
      });
    } catch (e) {
      failed = true;
      if (mounted) Fluttertoast.showToast(msg: '刷新数据失败：$e');
    } finally {
      messenger.clearSnackBars();
    }
    if (!failed && mounted) Fluttertoast.showToast(msg: '数据刷新成功!');
  }

  /// 高级模式刷新数据：和「系统」Tab 的入口同源，只是这里把入口挂在
  /// PLAYER OVERVIEW 卡片的上半部分（标题 + 总分）上。
  ///
  /// 高级对话框返回的 [RefreshDataRequest.forceSourceIds] 非空，
  /// 交给 executeAdvancedRefreshData 按缓存源强制刷新；进度沿用首页常驻
  /// SnackBar 的写法（同一时刻只留一条，避免高频进度排成长队）。
  bool _isAdvancedRefreshing = false;

  Future<void> _openAdvancedRefreshData() async {
    if (_isAdvancedRefreshing) return;
    final request = await showAdvancedRefreshDataDialog(context);
    if (request == null || !mounted) return;

    setState(() => _isAdvancedRefreshing = true);
    final messenger = ScaffoldMessenger.of(context);
    void showProgress(String text) {
      messenger.clearSnackBars();
      messenger.showSnackBar(SnackBar(
        content: Text(text),
        duration: const Duration(minutes: 10),
      ));
    }

    showProgress('正在刷新数据（高级）...');
    var failed = false;
    try {
      await executeAdvancedRefreshData(request, onProgress: (p, t) {
        if (!mounted) return;
        showProgress('$t ($p%)');
      });
    } catch (e) {
      failed = true;
      if (mounted) Fluttertoast.showToast(msg: '刷新数据失败：$e');
    } finally {
      messenger.clearSnackBars();
      if (mounted) setState(() => _isAdvancedRefreshing = false);
    }
    if (!failed && mounted) Fluttertoast.showToast(msg: '数据刷新成功!');
  }

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
                            style: TextStyle(
                                color: AppColors.errorRed(brightness)))
                        : Column(mainAxisSize: MainAxisSize.min, children: [
                            // 已登录水鱼：显示账号信息 + 水鱼授权状态
                            if (profile != null) ...[
                              _buildAccountInfo(profile, dialogContext),
                              _buildDivingFishAuthSection(
                                  dialogContext, brightness, profile),
                            ] else
                              // 未登录水鱼：友好提示用户去登录水鱼（落雪 token 仍可操作）
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  '未登录水鱼账号，仅显示落雪相关设置',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.greyHint(brightness),
                                  ),
                                ),
                              ),
                            // 始终显示：落雪 API 密钥管理（不依赖水鱼登录）
                            _buildLxnsTokenSection(brightness),
                          ]),
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

  /// 水鱼 OAuth 授权指引（读取成绩需在浏览器授权本应用，并显示授权状态）
  Widget _buildDivingFishAuthSection(
    BuildContext dialogContext,
    Brightness brightness,
    Map<String, dynamic> profile,
  ) {
    final bindQQ = profile.tryGet<String>('bind_qq') ?? '';
    final qq = bindQQ.isNotEmpty ? bindQQ : _cachedQQ;
    final authFuture = qq.isNotEmpty
        ? DivingFishOAuthManager().checkAuthorization(qq)
        : Future<bool?>.value(null);

    return FutureBuilder<bool?>(
      future: authFuture,
      builder: (ctx, snapshot) {
        final checking = snapshot.connectionState != ConnectionState.done;
        final authorized = snapshot.data;

        final statusColor = authorized == true
            ? AppColors.successGreen(brightness)
            : (authorized == false
                ? AppColors.warningOrange(brightness)
                : AppColors.greyHint(brightness));
        final statusIcon = authorized == true
            ? Icons.check_circle
            : (authorized == false ? Icons.warning_amber : Icons.verified_user);

        Widget status;
        if (checking) {
          status = const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        } else if (qq.isEmpty) {
          status = Text('未找到 QQ 号，请先刷新数据或登录水鱼',
              style: TextStyle(
                  color: AppColors.warningOrange(brightness), fontSize: 13));
        } else if (authorized == true) {
          status = Text('已授权',
              style: TextStyle(
                  color: AppColors.successGreen(brightness), fontSize: 13));
        } else if (authorized == false) {
          status = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('未授权',
                  style: TextStyle(
                      color: AppColors.warningOrange(brightness),
                      fontSize: 13)),
              const SizedBox(height: 6),
              Text('读取你的水鱼成绩需要先在浏览器里授权本应用。点下方按钮打开授权链接，登录水鱼并同意即可。',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.greyHint(brightness))),
            ],
          );
        } else {
          status = Text('状态未知',
              style: TextStyle(
                  color: AppColors.greyHint(brightness), fontSize: 13));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 24),
            Row(
              children: [
                Icon(statusIcon, size: 18, color: statusColor),
                const SizedBox(width: 8),
                Text(
                  '水鱼授权',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(dialogContext).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            status,
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                if (qq.isEmpty) {
                  Fluttertoast.showToast(msg: '未找到 QQ 号，请先刷新数据或登录水鱼');
                  return;
                }
                final ok = await DivingFishOAuthManager().openBindingLink(qq);
                if (!dialogContext.mounted) return;
                Fluttertoast.showToast(
                    msg: ok ? '已打开授权链接，请在浏览器中完成授权后返回查看' : '发起授权失败，请稍后重试');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.linkBlue(brightness),
                foregroundColor: Colors.white,
              ),
              child: Text(
                authorized == true ? '重新授权' : '打开授权链接',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        );
      },
    );
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
              if (checking)
                setState(() {
                  hasToken = true;
                  checking = false;
                });
            } else {
              DivingFishProbeManager().hasLxnsImportToken().then((has) {
                if (checking)
                  setState(() {
                    hasToken = has;
                    checking = false;
                  });
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
                child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else ...[
              if (hasToken == true)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('已设置',
                      style: TextStyle(
                          color: AppColors.successGreen(brightness),
                          fontSize: 13)),
                )
              else ...[
                Text('未设置',
                    style: TextStyle(
                        color: AppColors.warningOrange(brightness),
                        fontSize: 13)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final uri = Uri.parse(
                        'https://maimai.lxns.net/user/profile?tab=thirdparty');
                    try {
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      } else {
                        launchUrlFallback(uri.toString(), context);
                      }
                    } catch (e) {
                      debugPrint('打开落雪第三方绑定链接失败: $e');
                      launchUrlFallback(uri.toString(), context);
                    }
                  },
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                            text: '访问 ', style: TextStyle(fontSize: 12)),
                        TextSpan(
                          text:
                              'https://maimai.lxns.net/user/profile?tab=thirdparty',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.linkBlue(brightness),
                              decoration: TextDecoration.underline),
                        ),
                        const TextSpan(
                            text: '，滑到最底部获取密钥。',
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
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            final t = tokenCtrl.text.trim();
                            if (t.isEmpty) {
                              Fluttertoast.showToast(msg: '请先输入 API 密钥');
                              return;
                            }
                            setState(() => saving = true);
                            // 先本地缓存（无需 Hub 登录）
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString(
                                CacheKeyConstant.probeLxnsImportToken, t);
                            // 尝试同步绑定到 Hub
                            final ok = await DivingFishProbeManager()
                                .setLxnsImportToken(t);
                            setState(() => saving = false);
                            hasToken = true;
                            tokenCtrl.clear();
                            setState(() {});
                            Fluttertoast.showToast(
                                msg: ok ? '落雪 API 密钥已保存' : '已本地保存，同步时将自动绑定到云端');
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.linkBlue(brightness),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    child: saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
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
                      style: TextStyle(
                          color: AppColors.errorRed(brightness), fontSize: 12)),
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
      // 未登录水鱼：返回 null，由弹窗决定渲染降级 UI；
      // 落雪 token 区块始终会渲染，不受影响。
      return null;
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
                      style: TextStyle(
                          color: AppColors.greyHint(brightness), fontSize: 13)),
                ),
                Expanded(
                  child:
                      Text(displayToken, style: const TextStyle(fontSize: 13)),
                ),
                if (isRefreshing)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else ...[
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
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
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
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
                style: TextStyle(
                    color: AppColors.greyHint(brightness), fontSize: 13)),
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
          await prefs.setString(
              CacheKeyConstant.probeDivingFishImportToken, newToken);
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
      '初学者',
      '一段',
      '二段',
      '三段',
      '四段',
      '五段',
      '六段',
      '七段',
      '八段',
      '九段',
      '十段',
      '真初段',
      '真二段',
      '真三段',
      '真四段',
      '真五段',
      '真六段',
      '真七段',
      '真八段',
      '真九段',
      '真十段',
      '真皆传',
      '里皆传',
    ];
    if (rating < 0 || rating >= names.length) return '$rating';
    return '${names[rating]} ($rating)';
  }

  // 构建同步状态图标
  Widget _buildStageIcon(SyncStage? stage, Brightness brightness) {
    if (stage == null) return const SizedBox.shrink();
    switch (stage) {
      case SyncStage.completed:
        return Icon(Icons.check_circle,
            color: AppColors.successGreen(brightness), size: 36);
      case SyncStage.failed:
        return Icon(Icons.error,
            color: AppColors.errorRed(brightness), size: 36);
      case SyncStage.cancelled:
        return Icon(Icons.cancel,
            color: AppColors.greyHint(brightness), size: 36);
      case SyncStage.waitingAcceptance:
        return Icon(Icons.hourglass_bottom,
            color: AppColors.warningOrange(brightness), size: 36);
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
        MaterialPageRoute(
            builder: (context) => AchievementFullReverseCalculator()),
      );
    }
    if (item.title == 'Best50') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => B50Page()),
      );
    }
    if (item.title == '单曲 Rating 计算') {
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
    if (item.title == '基于目标 Rating 推荐') {
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
      await _openRefreshData();
    }
    if (item.title == '刷新 maidata') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('确认刷新'),
          content: const Text(
              '将清除所有maidata缓存并从服务器重新拉取全部maidata数据，耗时可能较长。\n\n确定要刷新吗？'),
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
          await MaimaiMusicDataManager().refreshDataWithSmartMaidata(
            forceMaidataRefresh: true,
          );
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
    if (item.title == '拟合 Best50') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => DiffBest50Page()),
      );
    }
    if (item.title == '随机乐曲') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => RandomChartPage()),
      );
    }
    if (item.title == '无提示猜歌') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => GuessChartByInfoPage()),
      );
    }
    if (item.title == '根据部分曲绘猜歌') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => GuessChartByCoverPage()),
      );
    }
    if (item.title == '收藏品查询') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => CollectionSearchPage()),
      );
    }
    if (item.title == '根据模糊曲绘猜歌') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => GuessChartByBlurredCoverPage()),
      );
    }
    if (item.title == '根据歌曲片段猜歌') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => GuessChartBySongExcerptPage()),
      );
    }
    if (item.title == '根据别名猜歌') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => GuessChartByAliaPage()),
      );
    }
    if (item.title == '舞萌开字母') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => GuessSongByOpenLettersPage()),
      );
    }
    if (item.title == '多人猜歌游戏') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => MultiplayerLobbyPage()),
      );
    }
    if (item.title == '服务器状态') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => MaimaiServerStatusPage()),
      );
    }
    if (item.title == '个性化 Best50') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PersonalizedBest50Page()),
      );
    }
    if (item.title == 'Rating 历史') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const RatingHistoryPage()),
      );
    }
    if (item.title == '个性化拟合 Best50') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PersonalizedDiffBest50Page()),
      );
    }
    if (item.title == 'KALEIDXSCOPE') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => KaleidXScopeSelectPage()),
      );
    }
    if (item.title == '曲绘识别') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CoverRecognitionPage()),
      );
    }
    if (item.title == '结算画面识别') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ScoreOcrPage()),
      );
    }
    if (item.title == '牌子进度') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PaiziProgressPage()),
      );
    }
    if (item.title == '个性化成绩查询') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PersonalizedScorePage()),
      );
    }
    if (item.title == '随身听') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PortablePlayerPage()),
      );
    }
    if (item.title == '自定义谱面播放') {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => PersonalizedChartPlayConfigure()),
      );
    }
    if (item.title == '关于 APP') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AboutAppPage()),
      );
    }
    if (item.title == '支持开发者') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SupportDeveloperPage()),
      );
    }
    if (item.title == '问卷调查') {
      final uri = Uri.parse('https://wj.qq.com/s2/26540572/7828/');
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          launchUrlFallback(uri.toString(), context);
        }
      } catch (e) {
        debugPrint('打开问卷调查链接失败: $e');
        launchUrlFallback(uri.toString(), context);
      }
    }
    if (item.title == '同步成绩到水鱼') {
      // 与「系统」hub 页同一套线路记忆：线路2 走 AWMC 网关，线路1 走原有流程
      if (SyncRouteNotifier.instance.routeOf(SyncPlatform.divingFish) ==
          SyncRouteStore.routeAwmc) {
        await _syncToDivingFishViaAwmc();
      } else {
        await _syncToDivingFish();
      }
    }
    if (item.title == '账号管理') {
      _showAccountManageDialog(context);
    }
    if (item.title == '登录水鱼') {
      await SyncScoreDialogs.showDivingFishLoginDialog(context, _syncCallbacks);
    }
    if (item.title == '登出水鱼账号') {
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
              style: ElevatedButton.styleFrom(
                  backgroundColor:
                      AppColors.errorRed(Theme.of(context).brightness)),
              child: const Text('登出', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (ok == true) {
        await _logoutDivingFish();
      }
    }
    if (item.title == '段位表') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => RankListPage()),
      );
    }
    if (item.title == 'Rating 排行榜') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => RatingRankListPage()),
      );
    }
    if (item.title == '拟合总Rating排行榜') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const FittedRatingRankingListPage(),
        ),
      );
    }
    if (item.title == '特殊排行榜') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => SpecialRankingListPage()),
      );
    }
    if (item.title == '平均达成率排行榜') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              const AvgScoreRankingListPage(initialMetric: AvgMetric.achievement),
        ),
      );
    }
    if (item.title == '平均DX分数达成率排行榜') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              const AvgScoreRankingListPage(initialMetric: AvgMetric.dx),
        ),
      );
    }
    if (item.title == '检查更新') {
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
                      Clipboard.setData(const ClipboardData(
                          text: LZYCheckUpdateManager.defaultDownloadUrl));
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('下载链接已复制到剪贴板'),
                            duration: Duration(seconds: 2)),
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
    if (item.title == '定数分布') {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => const DifficultyDistributionPage()),
      );
    }
    if (item.title == '主题与背景') {
      _showThemeDialog();
    }
    if (item.title == '收藏夹') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const FavoriteFolderPage()),
      );
    }
    if (item.title == '同步成绩到落雪') {
      if (SyncRouteNotifier.instance.routeOf(SyncPlatform.luoXue) ==
          SyncRouteStore.routeAwmc) {
        await _syncToLuoXueViaAwmc();
      } else {
        UpdateLuoXueScorePage.show(context);
      }
    }
    if (item.title == '每日推荐') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DailyRecommendPage()),
      );
    }
    if (item.title == '好友对比') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const FriendComparePage()),
      );
    }
    if (item.title == '全国音游地图') {
      final uri = Uri.parse('https://map.bemanicn.com/');
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          launchUrlFallback(uri.toString(), context);
        }
      } catch (e) {
        debugPrint('打开全国音游地图失败: $e');
        launchUrlFallback(uri.toString(), context);
      }
    }
    if (item.title == '全球音游街机地图') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => GlobalArcadeMapPage()),
      );
    }
    if (item.title == '最近评论') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const RecentCommentsPage()),
      );
    }
    if (item.title == '最近评分') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const RecentRatingsPage()),
      );
    }
    if (item.title == '数据备份') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DataBackupPage()),
      );
    }
    // 「AWMC 网关」入口默认隐藏（FeatureFlags.awmcGateway），这里跟着开关走：
    // 入口不显示时根本点不到，留着分支是为了开关一开就立刻可用。
    if (item.title == 'AWMC 网关' && FeatureFlags.awmcGateway) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AwmcConsolePage()),
      );
    }
    if (item.title == '查看友情链接') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const FriendLinksPage()),
      );
    }
  }

  // 构建收藏的功能区域（首页直接显示已收藏功能的入口按钮）
  // [titles] 来自 FavoriteFeaturesNotifier 的实时值，
  // 这样其他页面切换星标后，本区域无需依赖本地缓存即可立即刷新。
  Widget _buildFavoriteFeaturesSection(
      BuildContext context, Set<String> titles) {
    final items = _searchableCategories
        .expand((c) => c.items)
        .where((item) => titles.contains(item.title))
        .toList();

    return HubSection(
      title: '收藏的功能',
      icon: Icons.star,
      subtitle: '常用功能快速直达',
      children: [
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Center(
              child: Text(
                '点击分类中的 ⭐ 星标即可收藏功能，收藏后直接显示在此处',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          for (final item in items)
            // 「检查更新」在收藏区也要跟着变成「发现新版本」+ 绿色圆环箭头，
            // 否则同一个功能在两处长得不一样。形态统一由 UpdateNotifier 给。
            ValueListenableBuilder<UpdateAvailability?>(
              valueListenable: UpdateNotifier.available,
              builder: (context, update, _) {
                final isUpdate = UpdateNotifier.isUpdateEntry(item.title);
                final effective =
                    isUpdate && update != null ? update : null;
                return HubActionTile(
                  title: UpdateNotifier.titleFor(effective),
                  subtitle: UpdateNotifier.subtitleFor(
                      effective, item.subtitle),
                  icon: isUpdate ? Icons.arrow_upward_rounded : item.icon,
                  titleColor:
                      effective == null ? null : UpdateAvailableIcon.green,
                  leading: effective == null
                      ? null
                      : const UpdateAvailableIcon(),
                  isFavorited: true,
                  onToggleFavorite: () => _toggleFavorite(item.title),
                  onTap: () => _handleFeatureTap(item),
                  // 两个同步入口在收藏区也带上线路切换 + 近 100 次统计，
                  // 与「系统」hub 页共享同一份状态（SyncRouteNotifier）
                  footer: _syncFooterFor(item.title),
                );
              },
            ),
      ],
    );
  }

  /// 收藏区里「同步成绩」入口的附加区；其它功能返回 null（不占位置）。
  Widget? _syncFooterFor(String title) {
    if (title == '同步成绩到水鱼') {
      return const SyncRouteFooter(platform: SyncPlatform.divingFish);
    }
    if (title == '同步成绩到落雪') {
      return const SyncRouteFooter(platform: SyncPlatform.luoXue);
    }
    return null;
  }

  // 构建大类导航卡片按钮
  Widget _buildCategoryCard(
    ButtonCategory category,
    BuildContext context, {
    int? overrideCount,
    VoidCallback? onTap,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: screenHeight * 0.012),
      child: SizedBox(
        height: screenHeight * 0.09,
        child: TextButton(
          style: TextButton.styleFrom(
            backgroundColor: scheme.surface.withValues(alpha: 0.85),
            side: BorderSide(
              color: scheme.outlineVariant,
              width: AppConstants.borderWidth,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.04,
              vertical: screenHeight * 0.01,
            ),
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(AppConstants.borderRadiusLarge),
            ),
            elevation: 0,
          ),
          onPressed: onTap ??
              () {
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
              // 左侧：分类图标（主题色圆形背景）
              Container(
                width: screenWidth * 0.11,
                height: screenWidth * 0.11,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  category.icon ??
                      (category.items.isNotEmpty
                          ? category.items.first.icon
                          : Icons.folder),
                  color: scheme.primary,
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
                        color: scheme.onSurface,
                        fontSize: screenWidth * 0.042,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '${overrideCount ?? category.items.length} 个功能',
                      style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                        fontSize: screenWidth * 0.03,
                      ),
                    ),
                  ],
                ),
              ),
              // 右侧：箭头
              Icon(
                Icons.chevron_right,
                color: scheme.onSurface.withValues(alpha: 0.5),
                size: screenWidth * 0.06,
              ),
            ],
          ),
        ),
      ),
    );
  }

}
