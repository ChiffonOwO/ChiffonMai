import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../service/RankingList/RatingRankListService.dart';
import '../../utils/AppTheme.dart';
import '../../utils/ColorUtil.dart';
import '../../widgets/PageTopBar.dart';
import '../../widgets/DataSourceTag.dart';
import '../../utils/CurrentDataSourceNotifier.dart';

class RatingRankListPage extends StatefulWidget {
  const RatingRankListPage({super.key});

  @override
  State<RatingRankListPage> createState() => _RatingRankListPageState();
}

class _RatingRankListPageState extends State<RatingRankListPage> {
  List<RankItem> _rankList = [];
  bool _isLoading = true;
  String _errorMessage = '';

  // 当前选择的排行榜类型
  int _selectedTab = 0; // 0: 总排行榜, 之后依次是 _tabSources 里的数据源

  /// Tab 1..N 依次对应的数据源。
  ///
  /// 抽成列表是为了**加源时不用改逻辑**：`_tabNames` 与它一一对应，
  /// `_loadRankings` 按下标取源，不再写死 1→水鱼 / 2→落雪 的 switch。
  static const List<RefreshDataSource> _tabSources = [
    RefreshDataSource.shuiyu,
    RefreshDataSource.luoxue,
    RefreshDataSource.awmc,
  ];

  /// Tab 标题。第 0 个是跨源总榜，其余按 [_tabSources] 的**短名**生成。
  ///
  /// 不写字面量列表：否则「Tab 上写 AWMC、标签里写 AWMC NET」这种两处名字
  /// 不一致的坑早晚会出现，加源时也要记得回来补一个字符串。
  late final List<String> _tabNames = [
    '总排行榜',
    for (final source in _tabSources) source.shortDisplayName,
  ];

  // 当前用户信息
  String? _currentUserId;
  String? _currentDataSource;
  RankItem? _currentUserRankItem;

  // 防抖相关变量
  bool _isButtonDisabled = false;

  // 滚动控制器
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadCurrentUserInfo();
    await _loadRankings();
  }

  /// 推断当前玩家（数据源 + 排行榜 id）。
  ///
  /// 按源区分的标记键（`shuiyu_user_id` / `luoxue_user_id` / `awmc_user_id`）由各源的
  /// 刷新流程写入，比共用的 `cachedQQ` 权威。优先当前活动数据源，拿不到再按 enum
  /// 顺序兜底，全都没有才退化到 `cachedQQ`（历史上只有水鱼写它）。
  ///
  /// 原来的二元写法只认 水鱼 / 落雪，且 `lastDataSource == 'awmc'` 时会把数据源
  /// 标成水鱼、id 却取水鱼的 QQ —— 拿 AWMC 账号看排行榜会高亮错人。
  Future<void> _loadCurrentUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final current = CurrentDataSourceNotifier.instance.value;
    final ordered = <RefreshDataSource>[
      current,
      ...RefreshDataSource.values.where((s) => s != current),
    ];

    _currentDataSource = null;
    _currentUserId = null;
    for (final source in ordered) {
      final marker = prefs.getString(source.userIdCacheKey);
      if (marker != null && marker.isNotEmpty) {
        _currentDataSource = source.key;
        _currentUserId = marker;
        return;
      }
    }

    // 都没有按源标记，fallback 到 cachedQQ
    final qq = prefs.getString('cachedQQ');
    if (qq != null && qq.isNotEmpty) {
      _currentDataSource = RefreshDataSource.shuiyu.key;
      _currentUserId = 'shuiyu:$qq';
    }
  }

  // 禁用按钮并在1秒后恢复
  void _disableButtons() {
    setState(() {
      _isButtonDisabled = true;
    });
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _isButtonDisabled = false;
      });
    });
  }

  // 带防抖的刷新方法
  Future<void> _onRefresh() async {
    _disableButtons();
    // 清除缓存以便重新获取最新数据
    await RatingRankListService.clearRankingsCache();
    await _loadRankings();
  }

  // 滚动到当前用户位置
  void _scrollToCurrentUser() {
    if (_currentUserRankItem == null) {
      return;
    }

    // 查找当前用户在列表中的索引
    int userIndex = _rankList.indexWhere((item) => item.userId == _currentUserId);

    if (userIndex != -1) {
      // 滚动到当前用户位置，带有动画
      _scrollController.animateTo(
        userIndex * 72.0, // 假设每个列表项高度约为72
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _loadRankings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _currentUserRankItem = null;
    });

    try {
      List<RankItem> items;
      if (_selectedTab == 0) {
        // 第 0 个 Tab 是跨源总榜
        items = await RatingRankListService.getTotalRankings(limit: 100);
      } else {
        // 其余 Tab 按 _tabSources 取对应数据源的榜（水鱼 / 落雪 / AWMC NET）
        final index = _selectedTab - 1;
        items = index >= 0 && index < _tabSources.length
            ? await RatingRankListService.getSourceRankings(
                _tabSources[index],
                limit: 100,
              )
            : <RankItem>[];
      }

      // 计算并列排名
      items = RatingRankListService.calculateRankedPositions(items);

      // 查找当前用户的排名
      if (_currentUserId != null) {
        print('[DEBUG] 排行榜数据数量: ${items.length}');
        print('[DEBUG] 当前用户ID: $_currentUserId');

        // 打印前10个排行榜项的用户ID
        for (int i = 0; i < items.length && i < 10; i++) {
          print('[DEBUG] 排行榜项[$i]: userId=${items[i].userId}, nickname=${items[i].nickname}, totalRating=${items[i].totalRating}');
        }

        // 查找当前用户
        final foundUser = items.firstWhere(
          (item) => item.userId == _currentUserId,
          orElse: () => RankItem(
            userId: _currentUserId!,
            dataSource: _currentDataSource ?? '',
            originalId: '',
            totalRating: 0,
            best35Rating: 0,
            best15Rating: 0,
          ),
        );

        _currentUserRankItem = foundUser;

        // 检查是否找到匹配的用户
        if (foundUser.totalRating > 0) {
          print('[DEBUG] ✅ 找到当前用户: rank=${foundUser.rank}, nickname=${foundUser.nickname}, totalRating=${foundUser.totalRating}');
        } else {
          print('[DEBUG] ❌ 未找到当前用户，使用默认值');
        }
      }

      setState(() {
        _rankList = items;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '加载失败: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildRankItem(RankItem item, {bool isCurrentUser = false, required Brightness brightness}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.tableBorder(brightness))),
        color: isCurrentUser ? AppColors.linkBlue(brightness).withValues(alpha: 0.08) : null,
      ),
      child: Row(
        children: [
          // 排名
          SizedBox(
            width: 40,
            child: Center(
              child: _buildRankBadge(item.rank, brightness: brightness),
            ),
          ),

          // 数据源标识（配色/取名统一在 DataSourceTag）
          DataSourceTag(dataSource: item.dataSource),

          const SizedBox(width: 12),

          // 昵称
          Expanded(
            child: Text(
              item.nickname ?? '未知玩家',
              style: TextStyle(
                fontSize: 14,
                fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.w500,
                color: isCurrentUser ? AppColors.primaryText(brightness) : AppColors.secondaryText(brightness),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Rating 信息
          SizedBox(
            width: 140,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 总Rating
                ColorUtil.buildRatingBadge(
                  item.totalRating,
                  height: 24,
                ),
                // Best35 和 Best15
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (item.best35Rating > 0)
                      Text(
                        'B35: ${item.best35Rating}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.greyHint(brightness),
                        ),
                      ),
                    if (item.best35Rating > 0 && item.best15Rating > 0)
                      const SizedBox(width: 8),
                    if (item.best15Rating > 0)
                      Text(
                        'B15: ${item.best15Rating}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.greyHint(brightness),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankBadge(int rank, {required Brightness brightness}) {
    if (rank == 1) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.yellow, Colors.orange],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.emoji_events,
          size: 16,
          color: Colors.white,
        ),
      );
    } else if (rank == 2) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey, Colors.grey[400]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.emoji_events,
          size: 16,
          color: Colors.white,
        ),
      );
    } else if (rank == 3) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange[300]!, Colors.orange[600]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.emoji_events,
          size: 16,
          color: Colors.white,
        ),
      );
    } else {
      return Text(
        rank.toString(),
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.primaryText(brightness),
        ),
      );
    }
  }

  Widget _buildEmptyState(Brightness brightness) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart,
            size: 64,
            color: AppColors.greyHint(brightness),
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage.isNotEmpty ? _errorMessage : '暂无排行数据',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.greyHint(brightness),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: AppColors.cardBackground(brightness),
      body: Column(
        children: [
          // 顶部栏统一走公共组件：标题 = 思源黑体 20 / bold / primary / 居中，
          // 与 Best50 页、其余 50 多个页面同款。
          //
          // 这里原来直接用 `Scaffold.appBar: AppBar(title: Text(...))`：标题那层
          // `Text` 不带 fontFamily，会被 AppBar 自己的 `DefaultTextStyle`
          // （`appBarTheme.titleTextStyle`）接管，标题就退化成系统 Roboto，
          // 于是出现「同一个 App 里排行榜页的标题字体和别人不一样」。
          PageTopBar(
            title: 'Rating 排行榜',
            actions: [
              IconButton(
                icon: _isLoading
                    ? CircularProgressIndicator(
                        color: AppColors.primaryText(brightness), strokeWidth: 2)
                    : Icon(Icons.refresh,
                        color: AppColors.primaryText(brightness)),
                onPressed: (_isLoading || _isButtonDisabled) ? null : _onRefresh,
                tooltip: '刷新',
              ),
              // 快速定位到当前用户的按钮
              if (_currentUserRankItem != null)
                IconButton(
                  icon: Icon(Icons.location_searching,
                      color: AppColors.primaryText(brightness)),
                  onPressed: _scrollToCurrentUser,
                  tooltip: '跳转到我的排名',
                ),
            ],
          ),
          // 免责声明
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.warningOrange(brightness).withValues(alpha: 0.08),
              border: Border(bottom: BorderSide(color: AppColors.warningOrange(brightness).withValues(alpha: 0.3))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppColors.warningOrange(brightness),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '本排行榜数据仅供参考和娱乐使用，不代表任何官方立场或权威性排名。排名数据基于玩家自愿上传的游戏数据，可能存在误差或延迟。请理性看待排名结果，享受游戏乐趣。',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.warningOrange(brightness),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tab 切换
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.tableBorder(brightness))),
            ),
            child: Row(
              children: List.generate(_tabNames.length, (index) {
                return Expanded(
                  child: InkWell(
                    onTap: (_isLoading || _isButtonDisabled) ? null : () {
                      setState(() {
                        _selectedTab = index;
                      });
                      _onRefresh();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _selectedTab == index
                                ? AppColors.primaryText(brightness)
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _tabNames[index],
                          // 4 个 Tab 平分一行，每格只有 ~80dp：宁可省略号，
                          // 也不要让它折成两行把 Tab 栏撑高
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: _selectedTab == index
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: (_isLoading || _isButtonDisabled) && _selectedTab != index
                                ? AppColors.secondaryText(brightness)
                                : (_selectedTab == index
                                    ? AppColors.primaryText(brightness)
                                    : AppColors.secondaryText(brightness)),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          // 排行榜列表
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: AppColors.primaryText(brightness)))
                : _rankList.isEmpty
                    ? _buildEmptyState(brightness)
                    : ListView.builder(
                        controller: _scrollController,
                        // 必须显式清零：`Scaffold` 在没有 `appBar:` 时不会消耗顶部安全区，
                        // 于是 `ListView` 会把 `MediaQuery.padding.top`（状态栏 24dp）
                        // 当成内边距垫在**列表最上面** —— 而状态栏已经被 `PageTopBar`
                        // 占掉了，结果就是「第一名那一行上方多出一块空白」（实测 24dp）。
                        padding: EdgeInsets.zero,
                        itemCount: _rankList.length,
                        itemBuilder: (context, index) {
                          final item = _rankList[index];
                          final isCurrentUser = _currentUserId != null &&
                              item.userId == _currentUserId;
                          return _buildRankItem(item, isCurrentUser: isCurrentUser, brightness: brightness);
                        },
                      ),
          ),

          // 底部固定显示当前用户
          if (!_isLoading && _currentUserRankItem != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.primaryText(brightness))),
                color: AppColors.linkBlue(brightness).withValues(alpha: 0.08),
              ),
              child: Row(
                children: [
                  // 排名
                  SizedBox(
                    width: 40,
                    child: Center(
                      child: _buildRankBadge(_currentUserRankItem!.rank, brightness: brightness),
                    ),
                  ),

                  // 数据源标识（配色/取名统一在 DataSourceTag）
                  DataSourceTag(
                      dataSource: _currentUserRankItem!.dataSource),

                  const SizedBox(width: 12),

                  // 昵称
                  Expanded(
                    child: Text(
                      _currentUserRankItem!.nickname ?? '未知玩家',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryText(brightness),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Rating 信息
                  SizedBox(
                    width: 140,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ColorUtil.buildRatingBadge(
                          _currentUserRankItem!.totalRating,
                          height: 24,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (_currentUserRankItem!.best35Rating > 0)
                              Text(
                                'B35: ${_currentUserRankItem!.best35Rating}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.greyHint(brightness),
                                ),
                              ),
                            if (_currentUserRankItem!.best35Rating > 0 &&
                                _currentUserRankItem!.best15Rating > 0)
                              const SizedBox(width: 8),
                            if (_currentUserRankItem!.best15Rating > 0)
                              Text(
                                'B15: ${_currentUserRankItem!.best15Rating}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.greyHint(brightness),
                                ),
                              ),
                          ],
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
}