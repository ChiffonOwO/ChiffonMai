import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/service/FriendCompareService.dart';
import 'package:my_first_flutter_app/entity/FriendComparisonResult.dart';
import 'package:my_first_flutter_app/utils/CoverUtil.dart';
import 'package:my_first_flutter_app/utils/ColorUtil.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:my_first_flutter_app/utils/StringUtil.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:my_first_flutter_app/utils/AppConstants.dart';
import 'SongInfoPage.dart';

class FriendComparePage extends StatefulWidget {
  const FriendComparePage({super.key});

  @override
  State<FriendComparePage> createState() => _FriendComparePageState();
}

class _FriendComparePageState extends State<FriendComparePage> {
  final FriendCompareService _service = FriendCompareService();
  final TextEditingController _qqController = TextEditingController();

  bool _isLoading = false;
  ComparisonResult? _result;
  String? _errorMessage;
  // ignore: unused_field
  String? _currentFriendQQ;

  // 筛选和分页
  int? _filterLevelIndex; // null=全部, 0-4=指定难度
  String? _filterResult; // null=全部, 'win'=我赢, 'tie'=平局, 'lose'=好友赢
  static const int _pageSize = 20;
  int _displayCount = _pageSize;

  // 历史记录
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadCachedQQ();
    _loadHistory();
  }

  Future<void> _loadCachedQQ() async {
    final qq = await _service.getCachedQQ();
    _qqController.text = qq;
  }

  Future<void> _loadHistory() async {
    final history = await _service.loadHistory();
    if (mounted) setState(() => _history = history);
  }

  @override
  void dispose() {
    _qqController.dispose();
    super.dispose();
  }

  Future<void> _startCompare() async {
    final friendQQ = _qqController.text.trim();
    if (friendQQ.isEmpty) {
      setState(() => _errorMessage = '请输入好友的 QQ 号');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final result = await _service.compareWithFriend(friendQQ);
      if (mounted) {
        setState(() {
          _result = result;
          _currentFriendQQ = friendQQ;
          _isLoading = false;
          _displayCount = _pageSize;
          _filterLevelIndex = null;
          _filterResult = null;
        });
        // 保存到历史记录
        _service.saveHistory(friendQQ, result);
        _loadHistory();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textPrimaryColor = Theme.of(context).colorScheme.onSurface;
    final cardBgColor = Theme.of(context).colorScheme.surface;
    final cardShadow = AppColors.defaultShadow(brightness);
    // ignore: unused_local_variable
    final borderColor = AppColors.tableBorder(brightness);

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          CommonWidgetUtil.buildCommonBgWidget(),
          CommonWidgetUtil.buildCommonChiffonBgWidget(context),
          Column(
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(16, 48, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: textPrimaryColor),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '好友战绩对比',
                          style: TextStyle(
                            color: textPrimaryColor,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 48),
                  ],
                ),
              ),

              Expanded(
                child: Container(
                  margin: EdgeInsets.fromLTRB(8, 0, 8, 16),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [cardShadow],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _qqController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: '输入好友的 QQ 号',
                                  prefixIcon: Icon(Icons.person_search),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                onSubmitted: (_) => _startCompare(),
                              ),
                            ),
                            SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _isLoading ? null : _startCompare,
                              icon: _isLoading
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Icon(Icons.compare_arrows),
                              label: Text('开始对比'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],
                        ),

                        if (_errorMessage != null) ...[
                          SizedBox(height: 16),
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.errorRed(brightness).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.errorRed(brightness).withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline,
                                    color: AppColors.errorRed(brightness), size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: AppColors.errorRed(brightness),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        if (_isLoading) ...[
                          SizedBox(height: 40),
                          Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text(
                                '正在拉取好友数据并对比...',
                                style: TextStyle(
                                  color: textPrimaryColor,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],

                        // 对比结果
                        if (_result != null) ...[
                          SizedBox(height: 16),
                          _buildSummaryCard(textPrimaryColor, Theme.of(context).colorScheme.primary, brightness),
                          SizedBox(height: 12),
                          // 难度筛选
                          _buildLevelFilter(brightness),
                          SizedBox(height: 12),
                          _buildComparisonList(),
                        ],

                        // 空状态 / 历史记录
                        if (_result == null &&
                            !_isLoading &&
                            _errorMessage == null) ...[
                          if (_history.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(top: 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.history, size: 18, color: AppColors.greyHint(brightness)),
                                      SizedBox(width: 6),
                                      Text('历史对比记录',
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                                          color: textPrimaryColor)),
                                      Spacer(),
                                      GestureDetector(
                                        onTap: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: Text('清空历史'),
                                              content: Text('确定要清空全部历史记录吗？'),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('取消')),
                                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('清空', style: TextStyle(color: AppColors.errorRed(brightness)))),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            await _service.clearHistory();
                                            _loadHistory();
                                          }
                                        },
                                        child: Text('清空', style: TextStyle(fontSize: 12, color: AppColors.errorRed(brightness))),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  ..._history.map((h) => _buildHistoryItem(h)),
                                ],
                              ),
                            ),
                          if (_history.isEmpty)
                            Padding(
                              padding: EdgeInsets.only(top: 40),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.people_outline, size: 80, color: AppColors.greyHint(brightness)),
                                    SizedBox(height: 16),
                                    Text('输入好友 QQ 号开始对比\n（好友需在水鱼查分器有数据）',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: AppColors.greyHint(brightness), fontSize: 15)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建摘要卡片
  Widget _buildSummaryCard(Color textColor, Color primaryColor, Brightness brightness) {
    final result = _result!;
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withValues(alpha: 0.75)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // 好友昵称
          Text(
            '${result.friendNickname} 的战绩对比',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12),
          // 统计行
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatBadge('我的谱面', '${result.myTotalCharts}'),
              _buildStatBadge('好友谱面', '${result.friendTotalCharts}'),
              _buildStatBadge('共同谱面', '${result.commonCount}'),
            ],
          ),
          SizedBox(height: 12),
          // 胜负统计
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildWinBadge('我赢', result.myWinCount, AppColors.successGreen(brightness)),
              _buildWinBadge('平局', result.tieCount, AppColors.warningOrange(brightness)),
              _buildWinBadge('好友赢', result.friendWinCount, AppColors.errorRed(brightness)),
            ],
          ),
          SizedBox(height: 12),
          // Rating 对比
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Rating: ${result.myRating}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withAlpha(200),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.compare_arrows,
                    color: Colors.white.withAlpha(180), size: 20),
              ),
              Text(
                '${result.friendRating}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withAlpha(200),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withAlpha(180),
          ),
        ),
      ],
    );
  }

  Widget _buildWinBadge(String label, int count, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(60),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(120), width: 1),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withAlpha(200),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> h) {
    final brightness = Theme.of(context).brightness;
    final qq = h['friendQQ'] ?? '';
    final nick = h['friendNickname'] ?? qq;
    final date = h['date'] ?? '';
    final common = h['commonCount'] ?? 0;
    final win = h['myWinCount'] ?? 0;
    final tie = h['tieCount'] ?? 0;
    final lose = h['friendWinCount'] ?? 0;

    return GestureDetector(
      onTap: () {
        _qqController.text = qq;
        _startCompare();
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.tableBorder(brightness)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nick, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface)),
                  SizedBox(height: 2),
                  Text('$date  |  共同$common 首',
                    style: TextStyle(fontSize: 12, color: AppColors.greyHint(brightness))),
                ],
              ),
            ),
            Row(mainAxisSize: MainAxisSize.min, children: [
              _buildMiniBadge('$win', AppColors.successGreen(brightness)),
              SizedBox(width: 4),
              _buildMiniBadge('$tie', AppColors.warningOrange(brightness)),
              SizedBox(width: 4),
              _buildMiniBadge('$lose', AppColors.errorRed(brightness)),
            ]),
            SizedBox(width: 8),
            GestureDetector(
              onTap: () async {
                await _service.deleteHistory(qq);
                _loadHistory();
              },
              child: Icon(Icons.close, size: 16, color: AppColors.greyHint(brightness)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniBadge(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }

  /// 难度 + 胜负筛选栏
  Widget _buildLevelFilter(Brightness brightness) {
    const diffNames = ['BASIC', 'ADVANCED', 'EXPERT', 'MASTER', 'RE:MAS'];
    final diffColors = [
      Colors.green, Color(0xFFFFCC00), Colors.red,
      Colors.purple.shade400, Colors.purple.shade200,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 难度筛选
        Wrap(spacing: 6, runSpacing: 8, children: [
          _buildDiffChip('全部', null, AppColors.greyHint(brightness),
              selectedBg: Theme.of(context).colorScheme.surfaceContainerHighest),
          ...List.generate(5, (i) =>
              _buildDiffChip(diffNames[i], i, diffColors[i])),
        ]),
        SizedBox(height: 8),
        // 胜负筛选
        Wrap(spacing: 6, children: [
          _buildResultChip('全部', null, AppColors.greyHint(brightness),
              selectedBg: Theme.of(context).colorScheme.surfaceContainerHighest),
          _buildResultChip('我赢', 'win', Colors.green),
          _buildResultChip('平局', 'tie', Colors.orange),
          _buildResultChip('好友赢', 'lose', Colors.red),
        ]),
      ],
    );
  }

  Widget _buildDiffChip(String label, int? levelIndex, Color color, {Color? selectedBg}) {
    final isSelected = _filterLevelIndex == levelIndex;
    return GestureDetector(
      onTap: () => setState(() {
        _filterLevelIndex = levelIndex;
        _displayCount = _pageSize;
      }),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? (selectedBg ?? color) : Colors.transparent,
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : color)),
      ),
    );
  }

  Widget _buildResultChip(String label, String? resultKey, Color color, {Color? selectedBg}) {
    final isSelected = _filterResult == resultKey;
    return GestureDetector(
      onTap: () => setState(() {
        _filterResult = resultKey;
        _displayCount = _pageSize;
      }),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? (selectedBg ?? color) : Colors.transparent,
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : color)),
      ),
    );
  }

  /// 构建对比列表（使用 ListView.builder 实现懒加载，避免卡顿，支持筛选和分页）
  Widget _buildComparisonList() {
    final brightness = Theme.of(context).brightness;
    final result = _result!;
    const diffNames = ['BASIC', 'ADVANCED', 'EXPERT', 'MASTER', 'RE:MAS'];

    var filtered = result.commonCharts;
    if (_filterLevelIndex != null) {
      filtered = filtered.where((c) => c.levelIndex == _filterLevelIndex).toList();
    }
    if (_filterResult != null) {
      filtered = filtered.where((c) {
        switch (_filterResult) {
          case 'win': return c.isMyWin;
          case 'tie': return c.isTie;
          case 'lose': return c.isFriendWin;
          default: return true;
        }
      }).toList();
    }

    final totalFiltered = filtered.length;
    final maxDisplay = _displayCount > totalFiltered ? totalFiltered : _displayCount;
    final hasMore = maxDisplay < totalFiltered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '谱面对比详情 (按定数降序, 显示 $maxDisplay / $totalFiltered)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 2),
        if (totalFiltered == 0)
          Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                '没有符合条件的谱面',
                style: TextStyle(color: AppColors.greyHint(brightness)),
              ),
            ),
          )
        else ...[
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: maxDisplay,
            itemBuilder: (context, index) =>
                _buildComparisonItem(filtered[index], diffNames),
          ),
          if (hasMore)
            Padding(
              padding: EdgeInsets.only(top: 12),
              child: Center(
                child: TextButton.icon(
                  onPressed: () => setState(() => _displayCount += _pageSize),
                  icon: Icon(Icons.expand_more, size: 18),
                  label: Text('加载更多 ($maxDisplay / $totalFiltered)',
                    style: TextStyle(fontSize: 13)),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildComparisonItem(ChartComparisonItem item, List<String> diffNames) {
    final brightness = Theme.of(context).brightness;
    final isUtage = item.songId.toString().length == 6;
    final diffName = isUtage ? 'UTAGE' : diffNames[item.levelIndex.clamp(0, 4)];
    final accentColor = isUtage ? AppColors.utageAccent : ColorUtil.getCardColor(item.levelIndex);

    Color myColor;
    Color friendColor;
    if (item.isTie) {
      myColor = AppColors.warningOrange(brightness);
      friendColor = AppColors.warningOrange(brightness);
    } else if (item.isMyWin) {
      myColor = AppColors.successGreen(brightness);
      friendColor = AppColors.errorRed(brightness);
    } else {
      myColor = AppColors.errorRed(brightness);
      friendColor = AppColors.successGreen(brightness);
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SongInfoPage(
              songId: item.songId.toString(),
              initialLevelIndex: item.levelIndex,
              isDefaultLevelIndex: false,
            ),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.tableBorder(brightness)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CoverUtil.buildCoverWidgetWithContextRRect(
                  context, item.songId.toString(), 44,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(item.songTitle,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    SizedBox(height: 1),
                    Text('$diffName  ${item.ds.toStringAsFixed(1)}',
                      style: TextStyle(fontSize: 10, color: accentColor, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              SizedBox(width: 4),
              SizedBox(
                width: 72,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  FittedBox(fit: BoxFit.scaleDown,
                    child: Text('${item.myAchievements.toStringAsFixed(4)}%',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: myColor))),
                  if (item.myRate.isNotEmpty)
                    Text(StringUtil.formatRate(item.myRate), style: TextStyle(fontSize: 10,
                      color: myColor.withAlpha(200), fontWeight: FontWeight.w600)),
                ]),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  item.isTie ? Icons.drag_handle : item.isMyWin ? Icons.arrow_forward : Icons.arrow_back,
                  size: 16, color: item.isTie ? AppColors.warningOrange(brightness) : AppColors.greyHint(brightness)),
              ),
              SizedBox(
                width: 72,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  FittedBox(fit: BoxFit.scaleDown,
                    child: Text('${item.friendAchievements.toStringAsFixed(4)}%',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: friendColor))),
                  if (item.friendRate.isNotEmpty)
                    Text(StringUtil.formatRate(item.friendRate), style: TextStyle(fontSize: 10,
                      color: friendColor.withAlpha(200), fontWeight: FontWeight.w600)),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}