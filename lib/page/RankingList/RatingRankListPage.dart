import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../service/RankingList/RatingRankListService.dart';
import '../../constant/CacheKeyConstant.dart';
import '../../utils/AppTheme.dart';

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
  int _selectedTab = 0; // 0: 总排行榜, 1: 水鱼, 2: 落雪

  final List<String> _tabNames = ['总排行榜', '水鱼', '落雪'];

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

  // 获取当前用户信息
  Future<void> _loadCurrentUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDataSource = prefs.getString(CacheKeyConstant.lastDataSource);
    final qq = prefs.getString('cachedQQ');
    final luoxueUserId = prefs.getString('luoxue_user_id');

    // 根据缓存推断当前数据源：优先使用有有效用户ID的数据源
    // 如果水鱼有QQ且落雪没有用户ID，使用水鱼
    // 如果落雪有用户ID且水鱼没有QQ，使用落雪
    // 否则使用缓存的上次数据源
    if (qq != null && qq.isNotEmpty && (luoxueUserId == null || luoxueUserId.isEmpty)) {
      _currentDataSource = 'shuiyu';
      _currentUserId = 'shuiyu:$qq';
    } else if (luoxueUserId != null && luoxueUserId.isNotEmpty && (qq == null || qq.isEmpty)) {
      _currentDataSource = 'luoxue';
      _currentUserId = luoxueUserId;
    } else {
      // 两者都有或都没有，使用缓存的上次数据源
      _currentDataSource = lastDataSource;
      if (_currentDataSource == 'shuiyu' && qq != null && qq.isNotEmpty) {
        _currentUserId = 'shuiyu:$qq';
      } else if (_currentDataSource == 'luoxue') {
        _currentUserId = luoxueUserId;
      }
    }

    // 调试日志
    print('[DEBUG] 缓存的上次数据源: $lastDataSource');
    print('[DEBUG] 推断的当前数据源: $_currentDataSource');
    print('[DEBUG] 水鱼QQ: $qq');
    print('[DEBUG] 落雪用户ID: $luoxueUserId');
    print('[DEBUG] 当前用户ID: $_currentUserId');
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
      switch (_selectedTab) {
        case 0:
          items = await RatingRankListService.getTotalRankings(limit: 100);
          break;
        case 1:
          items = await RatingRankListService.getShuiyuRankings(limit: 100);
          break;
        case 2:
          items = await RatingRankListService.getLuoxueRankings(limit: 100);
          break;
        default:
          items = [];
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

          // 数据源标识
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: item.dataSource == 'shuiyu'
                  ? AppColors.linkBlue(brightness).withValues(alpha: 0.15)
                  : (brightness == Brightness.dark ? Colors.purple.withValues(alpha: 0.25) : Colors.purple[100]),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              item.dataSource == 'shuiyu' ? '水鱼' : '落雪',
              style: TextStyle(
                fontSize: 10,
                color: item.dataSource == 'shuiyu'
                    ? AppColors.linkBlue(brightness)
                    : (brightness == Brightness.dark ? Colors.purple[200] : Colors.purple[700]),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

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
            width: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 总Rating
                Text(
                  item.totalRating.toString(),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryText(brightness),
                  ),
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
      backgroundColor: AppColors.scaffoldBackground(brightness),
      appBar: AppBar(
        title: const Text('Rating 排行榜'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: _isLoading
                ? CircularProgressIndicator(color: AppColors.primaryText(brightness), strokeWidth: 2)
                : Icon(Icons.refresh, color: AppColors.primaryText(brightness)),
            onPressed: (_isLoading || _isButtonDisabled) ? null : _onRefresh,
            tooltip: '刷新',
          ),
          // 快速定位到当前用户的按钮
          if (_currentUserRankItem != null)
            IconButton(
              icon: Icon(Icons.location_searching, color: AppColors.primaryText(brightness)),
              onPressed: _scrollToCurrentUser,
              tooltip: '跳转到我的排名',
            ),
        ],
      ),
      body: Column(
        children: [
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
                ? const Center(child: CircularProgressIndicator())
                : _rankList.isEmpty
                    ? _buildEmptyState(brightness)
                    : ListView.builder(
                        controller: _scrollController,
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

                  // 数据源标识
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _currentUserRankItem!.dataSource == 'shuiyu'
                          ? AppColors.linkBlue(brightness).withValues(alpha: 0.15)
                          : (brightness == Brightness.dark ? Colors.purple.withValues(alpha: 0.25) : Colors.purple[100]),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _currentUserRankItem!.dataSource == 'shuiyu' ? '水鱼' : '落雪',
                      style: TextStyle(
                        fontSize: 10,
                        color: _currentUserRankItem!.dataSource == 'shuiyu'
                            ? AppColors.linkBlue(brightness)
                            : (brightness == Brightness.dark ? Colors.purple[200] : Colors.purple[700]),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

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
                    width: 120,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _currentUserRankItem!.totalRating.toString(),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryText(brightness),
                          ),
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