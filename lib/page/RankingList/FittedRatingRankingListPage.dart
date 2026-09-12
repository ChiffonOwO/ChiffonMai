import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constant/CacheKeyConstant.dart';
import '../../service/RankingList/FittedRatingRankingListService.dart';
import '../../utils/AppDesignTokens.dart';
import '../../utils/AppTheme.dart';

class FittedRatingRankingListPage extends StatefulWidget {
  final FittedMode initialMode;

  const FittedRatingRankingListPage({super.key, this.initialMode = FittedMode.a});

  @override
  State<FittedRatingRankingListPage> createState() =>
      _FittedRatingRankingListPageState();
}

class _FittedRatingRankingListPageState extends State<FittedRatingRankingListPage> {
  // 排行榜（按当前指标排序后取前100）
  List<FittedRankItem> _rankList = [];
  bool _isLoading = true;
  String _errorMessage = '';

  // 当前选择的模式
  late FittedMode _currentMode;

  // 当前用户信息
  String? _currentUserId;
  FittedRankItem? _currentUserRankItem;

  // 防抖相关变量
  bool _isButtonDisabled = false;

  // 滚动控制器
  final ScrollController _scrollController = ScrollController();

  // 近似每行高度（用于跳转到当前用户）
  static const double _rowExtent = 84.0;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _loadCurrentUserInfo();
    await _loadRankings();
  }

  // 获取当前用户信息
  Future<void> _loadCurrentUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDataSource = prefs.getString(CacheKeyConstant.lastDataSource);
    final qq = prefs.getString(CacheKeyConstant.cachedQQ);
    final shuiyuUserId = prefs.getString(CacheKeyConstant.shuiyuUserId);
    final luoxueUserId = prefs.getString(CacheKeyConstant.luoxueUserId);

    final hasShuiyuId = shuiyuUserId != null && shuiyuUserId.isNotEmpty;
    final hasLuoxueId = luoxueUserId != null && luoxueUserId.isNotEmpty;
    final hasQQ = qq != null && qq.isNotEmpty;

    // 优先使用正式存储的用户ID，其次 fallback 到 cachedQQ
    if (hasShuiyuId && !hasLuoxueId) {
      _currentUserId = shuiyuUserId;
    } else if (hasLuoxueId && !hasShuiyuId) {
      _currentUserId = luoxueUserId;
    } else if (hasShuiyuId && hasLuoxueId) {
      _currentUserId =
          lastDataSource == 'luoxue' ? luoxueUserId : shuiyuUserId;
    } else if (hasQQ) {
      _currentUserId = 'shuiyu:$qq';
    } else {
      _currentUserId = null;
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
    await FittedRatingRankingListService.clearRankingsCache();
    await _loadRankings(refresh: true);
  }

  // 滚动到当前用户位置
  void _scrollToCurrentUser() {
    if (_currentUserRankItem == null) {
      return;
    }
    final userIndex =
        _rankList.indexWhere((item) => item.playerId == _currentUserId);
    if (userIndex != -1) {
      _scrollController.animateTo(
        userIndex * _rowExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  // 切换模式并刷新
  void _onModeChanged(FittedMode mode) {
    if (mode == _currentMode) return;
    setState(() {
      _currentMode = mode;
      _isLoading = true;
      _errorMessage = '';
    });
    _loadRankings();
  }

  Future<void> _loadRankings({bool refresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final items = await FittedRatingRankingListService.getRankings(
        mode: _currentMode,
        refresh: refresh,
      );

      if (!mounted) return;
      final ranked =
          FittedRatingRankingListService.calculateRankedPositions(items);
      final top = ranked.take(100).toList();

      FittedRankItem? userItem;
      if (_currentUserId != null) {
        for (final item in top) {
          if (item.playerId == _currentUserId) {
            userItem = item;
            break;
          }
        }
        userItem ??= await FittedRatingRankingListService.getCurrentUserRank(
          mode: _currentMode,
          userId: _currentUserId!,
        );
      }

      if (!mounted) return;
      setState(() {
        _rankList = top;
        _currentUserRankItem = userItem;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '加载失败: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _modeName(FittedMode mode) => switch (mode) {
        FittedMode.a => '模式A：不分类，按拟合 Rating 取前50',
        FittedMode.b => '模式B：按官方 Best35/Best15 替换拟合定数重算',
        FittedMode.c => '模式C：非新曲取前35，新曲取前15',
      };

  Widget _buildDataSourceTag(String dataSource, {required Brightness brightness}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: dataSource == 'shuiyu'
            ? AppColors.linkBlue(brightness).withValues(alpha: 0.15)
            : (brightness == Brightness.dark
                ? Colors.purple.withValues(alpha: 0.25)
                : Colors.purple[100]),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        dataSource == 'shuiyu' ? '水鱼' : '落雪',
        style: TextStyle(
          fontSize: 10,
          color: dataSource == 'shuiyu'
              ? AppColors.linkBlue(brightness)
              : (brightness == Brightness.dark
                  ? Colors.purple[200]
                  : Colors.purple[700]),
          fontWeight: FontWeight.bold,
        ),
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
        child: const Icon(Icons.emoji_events, size: 16, color: Colors.white),
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
        child: const Icon(Icons.emoji_events, size: 16, color: Colors.white),
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
        child: const Icon(Icons.emoji_events, size: 16, color: Colors.white),
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

  Widget _buildValueCell(FittedRankItem item, {required Brightness brightness}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${item.fittedRating}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryText(brightness),
          ),
        ),
        Text(
          '与Best50差值 ${item.diff >= 0 ? '+' : ''}${item.diff}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: item.diff >= 0
                ? AppColors.successGreen(brightness)
                : AppColors.errorRed(brightness),
          ),
        ),
      ],
    );
  }

  Widget _buildRankItem(
    FittedRankItem item, {
    bool isCurrentUser = false,
    required Brightness brightness,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.tableBorder(brightness))),
        color: isCurrentUser
            ? AppColors.linkBlue(brightness).withValues(alpha: 0.08)
            : null,
      ),
      child: Row(
        children: [
          // 排名
          SizedBox(
            width: 40,
            child: Center(child: _buildRankBadge(item.rank, brightness: brightness)),
          ),

          // 数据源标识
          _buildDataSourceTag(item.dataSource, brightness: brightness),

          const SizedBox(width: 12),

          // 昵称
          Expanded(
            child: Text(
              item.playerName.isEmpty ? '未知玩家' : item.playerName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.w500,
                color: isCurrentUser
                    ? AppColors.primaryText(brightness)
                    : AppColors.secondaryText(brightness),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // 估值信息
          SizedBox(
            width: 130,
            child: _buildValueCell(item, brightness: brightness),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Brightness brightness) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_graph, size: 64, color: AppColors.greyHint(brightness)),
          const SizedBox(height: 16),
          Text(
            _errorMessage.isNotEmpty ? _errorMessage : '暂无排行数据',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.greyHint(brightness),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildModeSwitcher() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusLarge),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: FittedMode.values.map((m) {
            final selected = m == _currentMode;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: GestureDetector(
                  onTap: () => _onModeChanged(m),
                  child: AnimatedContainer(
                    duration: AppDesignTokens.fastMotion,
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: selected
                          ? scheme.primaryContainer
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: scheme.primary.withValues(alpha: 0.22),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '模式${m.label}',
                          style: TextStyle(
                            fontSize: 14,
                            letterSpacing: 0.2,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected
                                ? scheme.onPrimaryContainer
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                        if (selected) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: scheme.onPrimaryContainer,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: AppColors.cardBackground(brightness),
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('拟合总Rating排行榜'),
        ),
        centerTitle: true,
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
          if (_currentUserRankItem != null)
            IconButton(
              icon: Icon(Icons.location_searching,
                  color: AppColors.primaryText(brightness)),
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
              border: Border(
                  bottom: BorderSide(
                      color: AppColors.warningOrange(brightness)
                          .withValues(alpha: 0.3))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: AppColors.warningOrange(brightness)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '拟合总Rating排行榜基于玩家自愿上传的全量成绩与最新拟合定数（chart_stats）计算，仅供娱乐参考，不代表任何官方立场。',
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

          // 模式切换
          _buildModeSwitcher(),

          // 当前模式说明
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _modeName(_currentMode),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.greyHint(brightness),
                ),
              ),
            ),
          ),

          // 排行榜列表
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primaryText(brightness)))
                : _rankList.isEmpty
                    ? _buildEmptyState(brightness)
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: _rankList.length,
                        itemBuilder: (context, index) {
                          final item = _rankList[index];
                          final isCurrentUser = _currentUserId != null &&
                              item.playerId == _currentUserId;
                          return _buildRankItem(
                            item,
                            isCurrentUser: isCurrentUser,
                            brightness: brightness,
                          );
                        },
                      ),
          ),

          // 底部固定显示当前用户
          if (!_isLoading && _currentUserRankItem != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(color: AppColors.primaryText(brightness))),
                color: AppColors.linkBlue(brightness).withValues(alpha: 0.08),
              ),
              child: Row(
                children: [
                  // 排名
                  SizedBox(
                    width: 40,
                    child: Center(
                      child: _buildRankBadge(_currentUserRankItem!.rank,
                          brightness: brightness),
                    ),
                  ),

                  // 数据源标识
                  _buildDataSourceTag(_currentUserRankItem!.dataSource,
                      brightness: brightness),

                  const SizedBox(width: 12),

                  // 昵称
                  Expanded(
                    child: Text(
                      _currentUserRankItem!.playerName.isEmpty
                          ? '未知玩家'
                          : _currentUserRankItem!.playerName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryText(brightness),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // 估值信息
                  SizedBox(
                    width: 130,
                    child: _buildValueCell(_currentUserRankItem!,
                        brightness: brightness),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
