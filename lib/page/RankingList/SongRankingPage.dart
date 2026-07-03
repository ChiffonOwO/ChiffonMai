import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_first_flutter_app/constant/CacheKeyConstant.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:my_first_flutter_app/service/RankingList/SongRankingService.dart';
import 'package:my_first_flutter_app/utils/CoverUtil.dart';
import 'package:my_first_flutter_app/utils/StringUtil.dart';
import 'package:my_first_flutter_app/service/SongInfoService.dart';

class SongRankingPage extends StatefulWidget {
  final String songId;
  final int difficultyIndex;
  final RankingType rankingType;
  final String songTitle;
  final String difficultyLabel;
  final String songType;
  final String artist;
  final String genre;
  final String from;
  final double difficultyDs;

  const SongRankingPage({
    super.key,
    required this.songId,
    required this.difficultyIndex,
    required this.rankingType,
    required this.songTitle,
    required this.difficultyLabel,
    required this.songType,
    required this.artist,
    required this.genre,
    required this.from,
    required this.difficultyDs,
  });

  @override
  State<SongRankingPage> createState() => _SongRankingPageState();
}

class _SongRankingPageState extends State<SongRankingPage> {
  final SongRankingService _service = SongRankingService();
  bool _isLoading = true;
  List<RankingEntry> _rankingList = [];
  RankingEntry? _currentUserEntry;
  String? _errorMessage;
  int? _maxDxScore;
  Map<String, dynamic>? _songData;
  String _currentPlayerId = '';
  bool _showInvalidScoreWarning = false;
  bool _dontShowAgain = false;

  @override
  void initState() {
    super.initState();
    _loadSongData();
    // 延迟显示免责声明对话框（等待 context 初始化完成）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDisclaimer();
    });
  }

  // 检查是否需要显示免责声明
  Future<void> _checkDisclaimer() async {
    final prefs = await SharedPreferences.getInstance();
    bool hasShown = prefs.getBool(CacheKeyConstant.songRankingDisclaimerShown) ?? false;
    if (!hasShown) {
      _showDisclaimerDialogFunc();
    }
  }

  // 显示免责声明对话框
  void _showDisclaimerDialogFunc({bool showCheckbox = true}) {
    bool localDontShowAgain = _dontShowAgain;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final dialogBrightness = Theme.of(context).brightness;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 24,
                    color: AppColors.warningOrange(dialogBrightness),
                  ),
                  SizedBox(width: 8),
                  Text(
                    '免责声明',
                    style: TextStyle(
                      color: AppColors.warningOrange(dialogBrightness),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '本排行榜数据仅供参考和娱乐使用，不代表任何官方立场或权威性排名。排名数据基于玩家自愿上传的游戏数据，可能存在误差或延迟。请理性看待排名结果，享受游戏乐趣。',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.greyHint(dialogBrightness),
                        height: 1.6,
                      ),
                    ),
                    if (showCheckbox) ...[
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Checkbox(
                            value: localDontShowAgain,
                            onChanged: (value) {
                              setDialogState(() {
                                localDontShowAgain = value ?? false;
                              });
                              _dontShowAgain = value ?? false;
                            },
                          ),
                          Text('不再提示'),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _closeDisclaimer(dontShowAgain: showCheckbox ? localDontShowAgain : false);
                  },
                  child: Text('知道了'),
                ),
              ],
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            );
          },
        );
      },
    );
  }

  // 显示免责声明对话框（从按钮点击调用）
  void _showDisclaimer() {
    _dontShowAgain = false;
    _showDisclaimerDialogFunc(showCheckbox: false);
  }

  // 关闭免责声明对话框
  void _closeDisclaimer({bool dontShowAgain = false}) async {
    Navigator.of(context).pop();
    if (dontShowAgain) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(CacheKeyConstant.songRankingDisclaimerShown, true);
    }
  }

  Future<void> _loadSongData() async {
    try {
      final result = await SongInfoService().loadData(widget.songId);
      _songData = result['songData'];
      _calculateMaxDxScore();
    } catch (e) {
      debugPrint('[SongRankingPage] Error loading song data: $e');
      _maxDxScore = 0;
    }
    await _loadRankingData();
  }

  void _calculateMaxDxScore() {
    if (_songData == null) {
      _maxDxScore = 0;
      return;
    }

    int levelIndex = widget.difficultyIndex;
    List<dynamic> ds = _songData!['ds'];
    
    if (ds.length == 2) {
      _maxDxScore = _calculateMaxScore(0) + _calculateMaxScore(1);
    } else {
      _maxDxScore = _calculateMaxScore(levelIndex);
    }
  }

  int _calculateMaxScore(int levelIndex) {
    if (_songData == null) return 0;
    
    List<dynamic> charts = _songData!['charts'];
    if (levelIndex < 0 || levelIndex >= charts.length) return 0;
    
    dynamic chart = charts[levelIndex];
    if (chart['notes'] == null) return 0;
    
    List<dynamic> notes = chart['notes'];
    int notesSum = notes.fold(0, (sum, note) => sum + (note as int));
    return notesSum * 3;
  }

  String _calculateStarsBonus(int score) {
    if (_maxDxScore == null || _maxDxScore == 0) return '';
    
    double scoreRate = score / _maxDxScore!;
    dynamic starLevel = 0;
    double minRate = 0.0;

    if (scoreRate >= 0.99) {
      starLevel = 6;
      minRate = 0.99;
    } else if (scoreRate >= 0.98) {
      starLevel = 5.5;
      minRate = 0.98;
    } else if (scoreRate >= 0.97) {
      starLevel = 5;
      minRate = 0.97;
    } else if (scoreRate >= 0.95) {
      starLevel = 4;
      minRate = 0.95;
    } else if (scoreRate >= 0.93) {
      starLevel = 3;
      minRate = 0.93;
    } else if (scoreRate >= 0.90) {
      starLevel = 2;
      minRate = 0.90;
    } else if (scoreRate >= 0.85) {
      starLevel = 1;
      minRate = 0.85;
    } else {
      starLevel = 0;
      minRate = 0.85;
    }

    int minScore = (_maxDxScore! * minRate).ceil();
    int difference = score - minScore;
    String symbol = difference >= 0 ? '+' : '';

    dynamic displayStarLevel = starLevel == 0 ? 1 : starLevel;

    return '\u2726 $displayStarLevel $symbol$difference';
  }

  Color _getStarsColor(int score) {
    if (_maxDxScore == null || _maxDxScore == 0) return Colors.grey;
    
    double scoreRate = score / _maxDxScore!;
    
    if (scoreRate >= 0.97) {
      return Colors.yellow;
    } else if (scoreRate >= 0.93) {
      return Colors.orange;
    } else if (scoreRate >= 0.85) {
      return Colors.green.shade300;
    } else {
      return Colors.grey;
    }
  }

  bool _isHighStarLevel(int score) {
    if (_maxDxScore == null || _maxDxScore == 0) return false;
    double scoreRate = score / _maxDxScore!;
    return scoreRate >= 0.97; // 5星、5.5星、6星
  }

  Color _getDifficultyColor(int difficultyIndex) {
    // UTAGE类型歌曲（6位ID）显示粉色
    if (widget.songId.length == 6) {
      return Color(0xFFFF1493); // 粉色（深粉）
    }
    
    switch (difficultyIndex) {
      case 0: // BASIC
        return Color(0xFF4CAF50); // 绿色
      case 1: // ADVANCED
        return Color(0xFFFF9800); // 橙色
      case 2: // EXPERT
        return Color(0xFFE91E63); // 红色
      case 3: // MASTER
        return Color(0xFF9966CC); // 紫色
      case 4: // Re:MASTER
        return Color(0xFF9C27B0); // 深紫色
      default:
        return Color(0xFF9966CC);
    }
  }

  Color _getDifficultyBackgroundColor(int difficultyIndex) {
    // UTAGE类型歌曲（6位ID）显示粉色背景
    if (widget.songId.length == 6) {
      return Color(0xFFFFB6C1); // 浅粉色
    }
    
    switch (difficultyIndex) {
      case 0: // BASIC
        return Color(0xFFE8F5E9); // 浅绿色
      case 1: // ADVANCED
        return Color(0xFFFFF3E0); // 浅橙色
      case 2: // EXPERT
        return Color(0xFFFCE4EC); // 浅红色
      case 3: // MASTER
        return Color(0xFFE9D8FF); // 浅紫色
      case 4: // Re:MASTER
        return Color(0xFFF3E5F5); // 浅粉色
      default:
        return Color(0xFFE9D8FF);
    }
  }

  void _showDifficultySelector() {
    if (_songData == null) return;

    List<dynamic> levels = _songData!['level'];
    List<dynamic> dsList = _songData!['ds'];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('选择难度'),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: levels.length,
              itemBuilder: (context, index) {
                // UTAGE歌曲全部显示为UTAGE，否则按下标显示标准标签
                final bool isUtage = widget.songId.length == 6;
                String levelLabel = isUtage ? 'UTAGE' : _getDifficultyLabelByIndex(index);
                double ds = dsList[index] is num ? (dsList[index] as num).toDouble() : 0.0;
                
                return InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    // 导航到选中难度的排行榜页面
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SongRankingPage(
                          songId: widget.songId,
                          difficultyIndex: index,
                          difficultyLabel: levelLabel,
                          difficultyDs: ds,
                          rankingType: widget.rankingType,
                          songTitle: widget.songTitle,
                          songType: widget.songType,
                          artist: widget.artist,
                          genre: widget.genre,
                          from: widget.from,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: index == widget.difficultyIndex
                          ? _getDifficultyBackgroundColor(index)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getDifficultyBackgroundColor(index),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            levelLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _getDifficultyColor(index),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          '${ds.toStringAsFixed(1)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _getDifficultyColor(index),
                          ),
                        ),
                        if (index == widget.difficultyIndex)
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Icon(
                                Icons.check,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  String _getDifficultyLabelByIndex(int index) {
    switch (index) {
      case 0:
        return 'BASIC';
      case 1:
        return 'ADVANCED';
      case 2:
        return 'EXPERT';
      case 3:
        return 'MASTER';
      case 4:
        return 'RE:MASTER';
      default:
        return 'BASIC';
    }
  }

  String _formatDifficultyLabel(String label) {
    String lowerLabel = label.toLowerCase();
    if (lowerLabel.contains('basic')) {
      return 'BASIC';
    } else if (lowerLabel.contains('advanced')) {
      return 'ADVANCED';
    } else if (lowerLabel.contains('expert')) {
      return 'EXPERT';
    } else if (lowerLabel.contains('master') && !lowerLabel.contains('re:')) {
      return 'MASTER';
    } else if (lowerLabel.contains('re:master')) {
      return 'RE:MASTER';
    } else if (lowerLabel.contains('utage')) {
      return 'UTAGE';
    }
    return label.toUpperCase();
  }

  // 格式化更新时间
  String _formatUpdateTime(int updateTime) {
    if (updateTime == 0) {
      return '';
    }
    DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(updateTime);
    DateTime now = DateTime.now();
    Duration difference = now.difference(dateTime);
    
    // 超过7天显示绝对时间，否则显示相对时间
    if (difference.inDays >= 7) {
      return '${dateTime.year}-${_padZero(dateTime.month)}-${_padZero(dateTime.day)} ${_padZero(dateTime.hour)}:${_padZero(dateTime.minute)}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }
  
  // 数字补零
  String _padZero(int number) {
    return number.toString().padLeft(2, '0');
  }

  Future<void> _loadRankingData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _showInvalidScoreWarning = false;
    });

    try {
      List<RankingEntry> rankingList = await _service.getSongRanking(
        widget.songId,
        widget.difficultyIndex,
        widget.rankingType,
        limit: 100,
      );

      String currentPlayerId = await _service.getCurrentPlayerId();
      setState(() {
        _currentPlayerId = currentPlayerId;
      });
      RankingEntry? userEntry = await _service.getUserRanking(
        widget.songId,
        widget.difficultyIndex,
        widget.rankingType,
        currentPlayerId,
      );

      // 校验当前用户数据是否合法
      if (userEntry != null) {
        bool isValid = await _service.validateUserRecord(
          widget.songId,
          widget.difficultyIndex,
          userEntry.achievementRate,
          userEntry.dxScore,
        );
        if (!isValid) {
          setState(() {
            _showInvalidScoreWarning = true;
          });
        }
      }

      setState(() {
        _rankingList = rankingList;
        _currentUserEntry = userEntry;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[SongRankingPage] Error loading ranking data: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = '加载排行榜数据失败';
      });
    }
  }

  Widget _buildRankingItem(RankingEntry entry, bool isCurrentUser, Brightness brightness) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.tableBorder(brightness))),
        color: isCurrentUser ? AppColors.linkBlue(brightness).withValues(alpha: 0.08) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Center(
              child: _buildRankBadge(entry.rank, brightness),
            ),
          ),

          SizedBox(width: 12),

          Expanded(
            child: Row(
              children: [
                // 数据源标识
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  margin: EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: entry.dataSource == 'shuiyu'
                        ? AppColors.linkBlue(brightness).withValues(alpha: 0.12)
                        : (brightness == Brightness.dark
                            ? Colors.purple.withValues(alpha: 0.2)
                            : const Color(0xFFE1BEE7)),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    entry.dataSource == 'shuiyu' ? '水鱼' : '落雪',
                    style: TextStyle(
                      fontSize: 10,
                      color: entry.dataSource == 'shuiyu'
                          ? AppColors.linkBlue(brightness)
                          : (brightness == Brightness.dark
                              ? const Color(0xFFCE93D8)
                              : const Color(0xFF7B1FA2)),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    entry.playerName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.w500,
                      color: isCurrentUser ? AppColors.linkBlue(brightness) : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(
            width: 130,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // DX分数排行榜显示星星等级
                    if (widget.rankingType == RankingType.dxScore)
                      Container(
                        padding: _isHighStarLevel(entry.dxScore)
                            ? EdgeInsets.symmetric(horizontal: 6, vertical: 2)
                            : EdgeInsets.zero,
                        decoration: _isHighStarLevel(entry.dxScore)
                            ? BoxDecoration(
                                color: _getStarsColor(entry.dxScore),
                                borderRadius: BorderRadius.circular(4),
                              )
                            : null,
                        child: Text(
                          _calculateStarsBonus(entry.dxScore),
                          style: TextStyle(
                            fontSize: 12,
                            color: _isHighStarLevel(entry.dxScore)
                                ? Colors.black
                                : _getStarsColor(entry.dxScore),
                            fontWeight: _isHighStarLevel(entry.dxScore) ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    if (widget.rankingType == RankingType.dxScore)
                      SizedBox(width: 8),
                    // AP/AP+ 标签
                    if (widget.rankingType == RankingType.achievementRate &&
                        (entry.fc?.toLowerCase() == 'ap' || entry.fc?.toLowerCase() == 'app'))
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          entry.fc?.toLowerCase() == 'app' ? 'AP+' : entry.fc?.toUpperCase() ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    Text(
                      widget.rankingType == RankingType.achievementRate
                          ? '${entry.achievementRate.toStringAsFixed(4)}%'
                          : entry.dxScore.toString(),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                // 同步时间
                Text(
                  _formatUpdateTime(entry.updateTime),
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.greyHint(brightness),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankBadge(int rank, Brightness brightness) {
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
            colors: [Color(0xFFCD7F32), Color(0xFFB87333)],
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
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.greyHint(brightness),
        ),
      );
    }
  }

  

  Widget _buildTypeBadge(String type) {
    final brightness = Theme.of(context).brightness;
    bool isUtage = widget.songId.length == 6;

    if (isUtage) {
      return Text(
        'UTAGE',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.red,
        ),
      );
    } else if (type == 'DX') {
      return Text(
        'DX',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.warningOrange(brightness),
        ),
      );
    } else {
      return Text(
        'ST',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.linkBlue(brightness),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final screenWidth = MediaQuery.of(context).size.width;
    final title = widget.rankingType == RankingType.achievementRate
        ? '达成率排行榜'
        : 'DX分数排行榜';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          CommonWidgetUtil.buildCommonBgWidget(),
          CommonWidgetUtil.buildCommonChiffonBgWidget(context),
          
          Column(
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(16, 48, 16, 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: screenWidth * 0.06,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // 免责声明按钮
                    IconButton(
                      icon: Icon(Icons.info_outline, color: Theme.of(context).colorScheme.onSurface),
                      onPressed: _showDisclaimer,
                    ),
                  ],
                ),
              ),
              
              // 歌曲信息区域 - 固定宽高，左侧曲绘，右侧信息
              Container(
                margin: EdgeInsets.fromLTRB(8, 0, 8, 8),
                height: 120,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    AppColors.defaultShadow(brightness),
                  ],
                ),
                child: Row(
                    children: [
                      // 左侧曲绘
                      Container(
                        width: 100,
                        height: 100,
                        margin: EdgeInsets.all(10),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CoverUtil.buildCoverWidgetWithContext(context, widget.songId, 100),
                        ),
                      ),
                      
                      // 右侧信息
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(0, 12, 12, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // 第一行：谱面类型 + 歌名
                              Row(
                                children: [
                                  _buildTypeBadge(widget.songType),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      widget.songTitle,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              
                              // 第二行：版本
                              Text(
                                StringUtil.formatVersion2(widget.from),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.greyHint(brightness),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              
                              // 第三行：难度和定数（可点击切换难度）
                              Align(
                                alignment: Alignment.centerLeft,
                                child: InkWell(
                                  onTap: _showDifficultySelector,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _getDifficultyBackgroundColor(widget.difficultyIndex),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: _getDifficultyColor(widget.difficultyIndex),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _formatDifficultyLabel(widget.difficultyLabel),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: _getDifficultyColor(widget.difficultyIndex),
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          '${widget.difficultyDs.toStringAsFixed(1)}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: _getDifficultyColor(widget.difficultyIndex),
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                        Icon(
                                          Icons.arrow_drop_down,
                                          size: 16,
                                          color: _getDifficultyColor(widget.difficultyIndex),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: Container(
                  margin: EdgeInsets.fromLTRB(8, 8, 8, 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      AppColors.defaultShadow(brightness),
                    ],
                  ),
                  child: _isLoading 
                      ? Center(child: CircularProgressIndicator())
                      : _errorMessage != null
                          ? Center(child: Text(_errorMessage!))
                          : _rankingList.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.emoji_events_outlined,
                                        size: 64,
                                        color: AppColors.greyHint(brightness),
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        '榜上无人哦，快来抢沙发！',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: AppColors.greyHint(brightness),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Column(
                              children: [
                                Expanded(
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    itemCount: _rankingList.length,
                                    itemBuilder: (context, index) {
                                      RankingEntry entry = _rankingList[index];
                                      bool isCurrentUser = entry.playerId == _currentPlayerId;
                                      return _buildRankingItem(entry, isCurrentUser, brightness);
                                    },
                                  ),
                                ),
                                if (_currentUserEntry != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      border: Border(top: BorderSide(color: Theme.of(context).primaryColor)),
                                      color: AppColors.linkBlue(brightness).withValues(alpha: 0.08),
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 40,
                                          child: Center(
                                            child: _buildRankBadge(_currentUserEntry!.rank, brightness),
                                          ),
                                        ),

                                        SizedBox(width: 12),

                                        Expanded(
                                          child: Row(
                                            children: [
                                              // 数据源标识
                                              Container(
                                                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                margin: EdgeInsets.only(right: 6),
                                                decoration: BoxDecoration(
                                                  color: _currentUserEntry!.dataSource == 'shuiyu'
                                                      ? AppColors.linkBlue(brightness).withValues(alpha: 0.12)
                                                      : (brightness == Brightness.dark
                                                          ? Colors.purple.withValues(alpha: 0.2)
                                                          : const Color(0xFFE1BEE7)),
                                                  borderRadius: BorderRadius.circular(3),
                                                ),
                                                child: Text(
                                                  _currentUserEntry!.dataSource == 'shuiyu' ? '水鱼' : '落雪',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: _currentUserEntry!.dataSource == 'shuiyu'
                                                        ? AppColors.linkBlue(brightness)
                                                        : (brightness == Brightness.dark
                                                            ? const Color(0xFFCE93D8)
                                                            : const Color(0xFF7B1FA2)),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  _currentUserEntry!.playerName,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.linkBlue(brightness),
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        SizedBox(
                                          width: 150,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              // 如果成绩异常，显示警告信息
                                              if (_showInvalidScoreWarning)
                                                Container(
                                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.warningOrange(brightness).withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    '您的此谱面游玩数据存在异常，请检查!',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: AppColors.warningOrange(brightness),
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                    textAlign: TextAlign.right,
                                                  ),
                                                )
                                              else
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.end,
                                                  children: [
                                                    // DX分数排行榜显示星星等级
                                                    if (widget.rankingType == RankingType.dxScore)
                                                      Container(
                                                        padding: _isHighStarLevel(_currentUserEntry!.dxScore)
                                                            ? EdgeInsets.symmetric(horizontal: 6, vertical: 2)
                                                            : EdgeInsets.zero,
                                                        decoration: _isHighStarLevel(_currentUserEntry!.dxScore)
                                                            ? BoxDecoration(
                                                                color: _getStarsColor(_currentUserEntry!.dxScore),
                                                                borderRadius: BorderRadius.circular(4),
                                                              )
                                                            : null,
                                                        child: Text(
                                                          _calculateStarsBonus(_currentUserEntry!.dxScore),
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: _isHighStarLevel(_currentUserEntry!.dxScore)
                                                                ? Colors.black
                                                                : _getStarsColor(_currentUserEntry!.dxScore),
                                                            fontWeight: _isHighStarLevel(_currentUserEntry!.dxScore) ? FontWeight.bold : FontWeight.normal,
                                                          ),
                                                        ),
                                                      ),
                                                    if (widget.rankingType == RankingType.dxScore)
                                                      SizedBox(width: 8),
                                                    if (widget.rankingType == RankingType.achievementRate &&
                                                        (_currentUserEntry!.fc?.toLowerCase() == 'ap' || _currentUserEntry!.fc?.toLowerCase() == 'app'))
                                                      Container(
                                                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        margin: EdgeInsets.only(right: 8),
                                                        decoration: BoxDecoration(
                                                          color: Colors.orange,
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          _currentUserEntry!.fc?.toLowerCase() == 'app' ? 'AP+' : _currentUserEntry!.fc?.toUpperCase() ?? '',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.bold,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ),
                                                    Text(
                                                      widget.rankingType == RankingType.achievementRate
                                                          ? '${_currentUserEntry!.achievementRate.toStringAsFixed(4)}%'
                                                          : _currentUserEntry!.dxScore.toString(),
                                                      textAlign: TextAlign.right,
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                        color: Theme.of(context).colorScheme.onSurface,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              // 同步时间（非异常时显示）
                                              if (!_showInvalidScoreWarning)
                                                Text(
                                                  _formatUpdateTime(_currentUserEntry!.updateTime),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: AppColors.greyHint(brightness),
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
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}