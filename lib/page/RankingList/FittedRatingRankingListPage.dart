import '../../widgets/AnimatedChoiceBar.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constant/CacheKeyConstant.dart';
import '../../service/RankingList/FittedRatingRankingListService.dart';
import '../../utils/AppTheme.dart';
import '../../widgets/PageTopBar.dart';
import '../../widgets/ThemeAwareBackground.dart';
import '../../widgets/CommunityAvatar.dart';
import '../../utils/CurrentDataSourceNotifier.dart';
import '../../utils/RankingRowExtent.dart';

class FittedRatingRankingListPage extends StatefulWidget {
  final FittedMode initialMode;

  const FittedRatingRankingListPage(
      {super.key, this.initialMode = FittedMode.a});

  @override
  State<FittedRatingRankingListPage> createState() =>
      _FittedRatingRankingListPageState();
}

class _FittedRatingRankingListPageState
    extends State<FittedRatingRankingListPage> {
  int _requestGeneration = 0;
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

  /// 行高实测器（定位按钮要精确落位）：列表用 `prototypeItem` 把每行都排成它的高度。
  final RankingRowExtent _rowExtent = RankingRowExtent();

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

  /// 取当前玩家的排行榜 id（`'<source>:<id>'`）。
  ///
  /// 优先当前活动数据源，拿不到再按 enum 顺序找任一有标记的源；全都没有才退化到
  /// `cachedQQ`（历史上只有水鱼写它）。原来的二元写法只认 水鱼 / 落雪。
  Future<void> _loadCurrentUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final current = CurrentDataSourceNotifier.instance.value;
    final ordered = <RefreshDataSource>[
      current,
      ...RefreshDataSource.values.where((s) => s != current),
    ];
    for (final source in ordered) {
      final marker = prefs.getString(source.userIdCacheKey);
      if (marker != null && marker.isNotEmpty) {
        _currentUserId = marker;
        return;
      }
    }
    final qq = prefs.getString(CacheKeyConstant.cachedQQ);
    _currentUserId = (qq != null && qq.isNotEmpty) ? 'shuiyu:$qq' : null;
  }

  // 禁用按钮并在1秒后恢复
  void _disableButtons() {
    setState(() {
      _isButtonDisabled = true;
    });
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
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
      // 精确落位：行高由 [RankingRowExtent] 实测，不再写 `index * 84` 那种估算
      // （真实行高只有 67，估高每行多 17dp，到第 40 名就滑过头 680dp）。
      _rowExtent.scrollRowToTop(_scrollController, userIndex);
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
    if (!mounted) return;
    final generation = ++_requestGeneration;
    final mode = _currentMode;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final items = await FittedRatingRankingListService.getRankings(
        mode: mode,
        refresh: refresh,
      );

      if (!mounted || generation != _requestGeneration) return;
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
          mode: mode,
          userId: _currentUserId!,
        );
      }

      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _rankList = top;
        _currentUserRankItem = userItem;
      });
    } catch (e) {
      if (mounted && generation == _requestGeneration) {
        setState(() {
          _errorMessage = '加载失败: $e';
        });
      }
    } finally {
      if (mounted && generation == _requestGeneration) {
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

  Widget _buildValueCell(FittedRankItem item,
      {required Brightness brightness}) {
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
        border: Border(
            bottom: BorderSide(color: AppColors.tableBorder(brightness))),
        color: isCurrentUser
            ? AppColors.linkBlue(brightness).withValues(alpha: 0.08)
            : null,
      ),
      child: Row(
        children: [
          // 排名
          SizedBox(
            width: 40,
            child: Center(
                child: _buildRankBadge(item.rank, brightness: brightness)),
          ),

          Expanded(
            child: CommunityPlayerIdentity(
              avatarId: item.avatarId,
              dataSource: item.dataSource,
              // 开发者白名单按 `<source>:<id>` 整串匹配，见 DataSourceTag
              playerId: item.playerId,
              name: item.playerName.isEmpty ? '未知玩家' : item.playerName,
              // 头像高度对齐「玩家名 + 数据源标签」两行文字的总高
              avatarMatchesTextHeight: true,
              nameStyle: TextStyle(
                fontSize: 14,
                fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.w500,
                color: isCurrentUser
                    ? AppColors.primaryText(brightness)
                    : AppColors.secondaryText(brightness),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 估值信息
          SizedBox(
            width: 130,
            child: _buildValueCell(item, brightness: brightness),
          ),
        ],
      ),
    );
  }

  /// 定位用的「原型行」：内容最全的一行（第 1 名那 28dp 奖杯 + 拟合值 + 差值小字）。
  /// 列表会先把它排一遍，再让每一行都用它的高度 —— 于是「第 index 行」的偏移
  /// 就是 `index × 行高`，见 [RankingRowExtent]。
  Widget _buildRowPrototype(Brightness brightness) => KeyedSubtree(
        key: _rowExtent.key,
        child: _buildRankItem(_prototypeRankItem, brightness: brightness),
      );

  FittedRankItem get _prototypeRankItem => FittedRankItem(
        rank: 1,
        playerId: '',
        playerName: '',
        dataSource: RefreshDataSource.shuiyu.key,
        mode: _currentMode.name,
        fittedRating: 17000,
        officialRating: 16800,
        diff: 200,
      );

  Widget _buildEmptyState(Brightness brightness) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_graph,
              size: 64, color: AppColors.greyHint(brightness)),
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

  Widget _buildModeSwitcher() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: AnimatedChoiceBar<FittedMode>(
            values: FittedMode.values,
            value: _currentMode,
            label: (mode) => '模式${mode.label}',
            onChanged: _onModeChanged),
      );

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: ColoredBox(color: Theme.of(context).colorScheme.surface),
          ),
          const ThemeAwareBackground(),
          Column(
            children: [
          // 顶部栏统一走公共组件（标题 = 思源黑体 20 / bold / primary / 居中）。
          // 以前是 `Scaffold.appBar: AppBar` + 裸 `Text`，标题会被 AppBar
          // 重新套上的 DefaultTextStyle 顶成系统 Roboto。
          PageTopBar(
            title: '拟合总Rating排行榜',
            actions: [
              IconButton(
                icon: _isLoading
                    ? CircularProgressIndicator(
                        color: AppColors.primaryText(brightness),
                        strokeWidth: 2)
                    : Icon(Icons.refresh,
                        color: AppColors.primaryText(brightness)),
                onPressed:
                    (_isLoading || _isButtonDisabled) ? null : _onRefresh,
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
          // 免责声明
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color:
                  AppColors.warningOrange(brightness).withValues(alpha: 0.08),
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
                        // 必须显式清零：`Scaffold` 在没有 `appBar:` 时不会消耗顶部安全区，
                        // `ListView` 会把 `MediaQuery.padding.top`（状态栏 24dp）当成
                        // 内边距垫在列表最上面，而状态栏已被 `PageTopBar` 占掉 ——
                        // 结果就是「第一名那行上方多出一块空白」（实测 24dp）。
                        padding: EdgeInsets.zero,
                        // 每行都排成原型行的高度：定位按钮才能用
                        // `index × 行高` 精确落位（行高不再靠 84 这种估算）
                        prototypeItem: _buildRowPrototype(brightness),
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

                  Expanded(
                    child: CommunityPlayerIdentity(
                      avatarId: _currentUserRankItem!.avatarId,
                      dataSource: _currentUserRankItem!.dataSource,
                      playerId: _currentUserRankItem!.playerId,
                      name: _currentUserRankItem!.playerName.isEmpty
                          ? '未知玩家'
                          : _currentUserRankItem!.playerName,
                      avatarMatchesTextHeight: true,
                      nameStyle: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryText(brightness),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

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
        ],
      ),
    );
  }
}
