import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:my_first_flutter_app/service/RankingList/SpecialRankingListService.dart';
import 'package:my_first_flutter_app/utils/CoverUtil.dart';
import '../SongInfoPage.dart';

class SpecialRankingListPage extends StatefulWidget {
  const SpecialRankingListPage({super.key});

  @override
  State<SpecialRankingListPage> createState() => _SpecialRankingListPageState();
}

enum RankingType {
  breakCount, // 绝赞数排行榜
  difficultyDiff, // 定数差值排行榜
  masterDiff, // MASTER/RE:MASTER定数差值排行榜
  expertDiff, // EXPERT定数差值排行榜
  reverseDiff, // 反向定数差值排行榜
  reverseMasterDiff, // 反向MASTER/RE:MASTER定数差值排行榜
  reverseExpertDiff, // 反向EXPERT定数差值排行榜
  sampleCount, // 样本总数排行榜
  noteCount, // 物量排行榜
  avgAchievement, // 平均达成排行榜
  masterAvgAchievement, // MASTER/RE:MASTER平均达成排行榜
  expertAvgAchievement, // EXPERT平均达成排行榜
}

class _SpecialRankingListPageState extends State<SpecialRankingListPage> {
  final SpecialRankingListService _service = SpecialRankingListService();
  bool _isLoading = true;
  bool _isRecalculating = false;
  int _progress = 0;
  RankingType _currentRankingType = RankingType.breakCount;
  List<SpecialRankingEntry> _rankingList = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRanking();
  }

  Future<void> _loadRanking() async {
    // Phase 1: 快速读取缓存，无论是否为空都立即展示页面
    setState(() {
      _isLoading = true;
      _isRecalculating = false;
      _progress = 0;
      _errorMessage = null;
    });

    try {
      List<SpecialRankingEntry> ranking = await _fetchCachedRanking();

      setState(() {
        _rankingList = ranking;
        _isLoading = false;
      });

      // Phase 2: 如果缓存为空，后台触发重新计算，不阻塞页面交互
      if (ranking.isEmpty) {
        setState(() {
          _isRecalculating = true;
          _progress = 0;
        });

        try {
          await _recalculateRankingWithProgress();

          // 重新计算完成后，重新读取缓存并更新列表
          List<SpecialRankingEntry> newRanking = await _fetchCachedRanking();
          if (mounted) {
            setState(() {
              _rankingList = newRanking;
              _isRecalculating = false;
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _errorMessage = '重新计算排行榜失败: $e';
              _isRecalculating = false;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '获取排行榜失败: $e';
          _isLoading = false;
          _isRecalculating = false;
        });
      }
    }
  }

  /// 仅从缓存读取排行榜，不触发重新计算
  Future<List<SpecialRankingEntry>> _fetchCachedRanking() async {
    switch (_currentRankingType) {
      case RankingType.breakCount:
        return _service.getBreakCountRanking(limit: 100);
      case RankingType.difficultyDiff:
        return _service.getDifficultyDiffRanking(limit: 100);
      case RankingType.masterDiff:
        return _service.getMasterDifficultyDiffRanking(limit: 100);
      case RankingType.expertDiff:
        return _service.getExpertDifficultyDiffRanking(limit: 100);
      case RankingType.reverseDiff:
        return _service.getReverseDifficultyDiffRanking(limit: 100);
      case RankingType.reverseMasterDiff:
        return _service.getReverseMasterDifficultyDiffRanking(limit: 100);
      case RankingType.reverseExpertDiff:
        return _service.getReverseExpertDifficultyDiffRanking(limit: 100);
      case RankingType.sampleCount:
        return _service.getSampleCountRanking(limit: 100);
      case RankingType.noteCount:
        return _service.getNoteCountRanking(limit: 100);
      case RankingType.avgAchievement:
        return _service.getAvgAchievementRanking(limit: 100);
      case RankingType.masterAvgAchievement:
        return _service.getMasterAvgAchievementRanking(limit: 100);
      case RankingType.expertAvgAchievement:
        return _service.getExpertAvgAchievementRanking(limit: 100);
    }
  }

  /// 后台触发重新计算（目前仅绝赞数排行榜支持独立重新计算）
  Future<void> _recalculateRankingWithProgress() async {
    // 目前仅 breakCount 有独立的重新计算方法，其他类型由缓存读取方法内部处理
    switch (_currentRankingType) {
      case RankingType.breakCount:
        await _service.recalculateBreakCountRanking(
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                _progress = progress;
              });
            }
          },
        );
        break;
      // 其他排行榜类型暂时保持原有行为（缓存为空时由 service 内部计算）
      default:
        break;
    }
  }

  String _getRankingTypeName(RankingType type) {
    switch (type) {
      case RankingType.breakCount:
        return '绝赞数排行榜';
      case RankingType.difficultyDiff:
        return '定数差值排行榜';
      case RankingType.masterDiff:
        return 'MASTER/RE:MASTER定数差值排行榜';
      case RankingType.expertDiff:
        return 'EXPERT定数差值排行榜';
      case RankingType.reverseDiff:
        return '反向定数差值排行榜';
      case RankingType.reverseMasterDiff:
        return '反向MASTER/RE:MASTER定数差值排行榜';
      case RankingType.reverseExpertDiff:
        return '反向EXPERT定数差值排行榜';
      case RankingType.sampleCount:
        return '样本总数排行榜';
      case RankingType.noteCount:
        return '物量排行榜';
      case RankingType.avgAchievement:
        return '平均达成率排行榜';
      case RankingType.masterAvgAchievement:
        return 'MASTER/RE:MASTER平均达成率排行榜';
      case RankingType.expertAvgAchievement:
        return 'EXPERT平均达成率排行榜';
    }
  }

  MaterialColor _getRankingValueColor() {
    switch (_currentRankingType) {
      case RankingType.breakCount:
        return Colors.blue;
      case RankingType.difficultyDiff:
      case RankingType.masterDiff:
      case RankingType.expertDiff:
      case RankingType.reverseDiff:
      case RankingType.reverseMasterDiff:
      case RankingType.reverseExpertDiff:
        return Colors.orange;
      case RankingType.sampleCount:
        return Colors.teal;
      case RankingType.noteCount:
        return Colors.green;
      case RankingType.avgAchievement:
      case RankingType.masterAvgAchievement:
      case RankingType.expertAvgAchievement:
        return Colors.purple;
    }
  }

  String _formatRankingValue(int value) {
    switch (_currentRankingType) {
      case RankingType.breakCount:
        return value.toString();
      case RankingType.difficultyDiff:
      case RankingType.masterDiff:
      case RankingType.expertDiff:
      case RankingType.reverseDiff:
      case RankingType.reverseMasterDiff:
      case RankingType.reverseExpertDiff:
        return (value / 100).toStringAsFixed(2);
      case RankingType.sampleCount:
        return value.toString();
      case RankingType.noteCount:
        return value.toString();
      case RankingType.avgAchievement:
      case RankingType.masterAvgAchievement:
      case RankingType.expertAvgAchievement:
        return (value / 100).toStringAsFixed(2);
    }
  }

  String _getRankingValueLabel() {
    switch (_currentRankingType) {
      case RankingType.breakCount:
        return '绝赞数';
      case RankingType.difficultyDiff:
      case RankingType.masterDiff:
      case RankingType.expertDiff:
      case RankingType.reverseDiff:
      case RankingType.reverseMasterDiff:
      case RankingType.reverseExpertDiff:
        return '定数差值';
      case RankingType.sampleCount:
        return '样本总数';
      case RankingType.noteCount:
        return '物量';
      case RankingType.avgAchievement:
      case RankingType.masterAvgAchievement:
      case RankingType.expertAvgAchievement:
        return '平均达成率';
    }
  }

  void _showRankingTypeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('选择排行榜类型'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  title: const Text('绝赞数排行榜',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('按谱面绝赞数量排名'),
                  trailing: _currentRankingType == RankingType.breakCount
                      ? const Icon(Icons.check, color: Colors.blue)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _currentRankingType = RankingType.breakCount;
                    });
                    _loadRanking();
                  },
                ),
                ListTile(
                  title: const Text('定数差值排行榜',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('拟合定数与官方定数差值排名'),
                  trailing: _currentRankingType == RankingType.difficultyDiff
                      ? const Icon(Icons.check, color: Colors.blue)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _currentRankingType = RankingType.difficultyDiff;
                    });
                    _loadRanking();
                  },
                ),
                ListTile(
                  title: const Text('MASTER/RE:MASTER定数差值排行榜',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('只统计MASTER/RE:MASTER难度'),
                  trailing: _currentRankingType == RankingType.masterDiff
                      ? const Icon(Icons.check, color: Colors.blue)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _currentRankingType = RankingType.masterDiff;
                    });
                    _loadRanking();
                  },
                ),
                ListTile(
                  title: const Text('EXPERT定数差值排行榜',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('只统计EXPERT难度'),
                  trailing: _currentRankingType == RankingType.expertDiff
                      ? const Icon(Icons.check, color: Colors.blue)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _currentRankingType = RankingType.expertDiff;
                    });
                    _loadRanking();
                  },
                ),
                ListTile(
                  title: const Text('反向定数差值排行榜',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('拟合定数-官方定数最小的前100位'),
                  trailing: _currentRankingType == RankingType.reverseDiff
                      ? const Icon(Icons.check, color: Colors.blue)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _currentRankingType = RankingType.reverseDiff;
                    });
                    _loadRanking();
                  },
                ),
                ListTile(
                  title: const Text('反向MASTER/RE:MASTER定数差值排行榜',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('只统计MASTER/RE:MASTER难度'),
                  trailing: _currentRankingType == RankingType.reverseMasterDiff
                      ? const Icon(Icons.check, color: Colors.blue)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _currentRankingType = RankingType.reverseMasterDiff;
                    });
                    _loadRanking();
                  },
                ),
                ListTile(
                  title: const Text('反向EXPERT定数差值排行榜',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('只统计EXPERT难度'),
                  trailing: _currentRankingType == RankingType.reverseExpertDiff
                      ? const Icon(Icons.check, color: Colors.blue)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _currentRankingType = RankingType.reverseExpertDiff;
                    });
                    _loadRanking();
                  },
                ),
                ListTile(
                  title: const Text('样本总数排行榜',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('玩家样本总量排名'),
                  trailing: _currentRankingType == RankingType.sampleCount
                      ? const Icon(Icons.check, color: Colors.blue)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _currentRankingType = RankingType.sampleCount;
                    });
                    _loadRanking();
                  },
                ),
                ListTile(
                  title: const Text('物量排行榜',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('五种note总数排名'),
                  trailing: _currentRankingType == RankingType.noteCount
                      ? const Icon(Icons.check, color: Colors.blue)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _currentRankingType = RankingType.noteCount;
                    });
                    _loadRanking();
                  },
                ),
                ListTile(
                  title: const Text('平均达成率排行榜',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('按平均达成率排名'),
                  trailing: _currentRankingType == RankingType.avgAchievement
                      ? const Icon(Icons.check, color: Colors.blue)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _currentRankingType = RankingType.avgAchievement;
                    });
                    _loadRanking();
                  },
                ),
                ListTile(
                  title: const Text('MASTER/RE:MASTER平均达成率排行榜',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('只统计MASTER/RE:MASTER难度'),
                  trailing:
                      _currentRankingType == RankingType.masterAvgAchievement
                          ? const Icon(Icons.check, color: Colors.blue)
                          : null,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _currentRankingType = RankingType.masterAvgAchievement;
                    });
                    _loadRanking();
                  },
                ),
                ListTile(
                  title: const Text('EXPERT平均达成率排行榜',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('只统计EXPERT难度'),
                  trailing:
                      _currentRankingType == RankingType.expertAvgAchievement
                          ? const Icon(Icons.check, color: Colors.blue)
                          : null,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _currentRankingType = RankingType.expertAvgAchievement;
                    });
                    _loadRanking();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRankBadge(int rank) {
    Color badgeColor;
    String badgeText;

    switch (rank) {
      case 1:
        badgeColor = Colors.yellow.shade600;
        badgeText = '1';
        break;
      case 2:
        badgeColor = Colors.grey.shade400;
        badgeText = '2';
        break;
      case 3:
        badgeColor = Colors.orange.shade400;
        badgeText = '3';
        break;
      default:
        return Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          child: Text(
            rank.toString(),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        );
    }

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text(
        badgeText,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildTypeTag(String type, String songId) {
    bool isUtage = songId.length == 6;

    if (isUtage) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'UT',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
      );
    } else if (type == 'DX') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'DX',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.orange,
          ),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.blue.shade100,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'ST',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
      );
    }
  }

  Widget _buildDifficultyTag(
      String difficultyLabel, int difficultyIndex, String songId) {
    Color bgColor;
    Color textColor;

    // UTAGE歌曲使用红色样式
    if (songId.length == 6) {
      bgColor = Colors.red.shade100;
      textColor = Colors.red;
    } else {
      switch (difficultyIndex) {
        case 0: // BASIC
          bgColor = Colors.green.shade100;
          textColor = Colors.green.shade700;
          break;
        case 1: // ADVANCED
          bgColor = Colors.orange.shade100;
          textColor = Colors.orange.shade700;
          break;
        case 2: // EXPERT
          bgColor = Colors.red.shade100;
          textColor = Colors.red;
          break;
        case 3: // MASTER
          bgColor = Colors.purple.shade100;
          textColor = Colors.purple.shade700;
          break;
        case 4: // RE:MASTER
          bgColor = Colors.purple.shade100;
          textColor = Colors.purple.shade300;
          break;
        default:
          bgColor = Colors.grey.shade100;
          textColor = Colors.grey.shade700;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        difficultyLabel,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textPrimaryColor = const Color.fromARGB(255, 84, 97, 97);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          CommonWidgetUtil.buildCommonBgWidget(),
          CommonWidgetUtil.buildCommonChiffonBgWidget(context),
          Column(
            children: [
              // 头部
              Container(
                padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: textPrimaryColor),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '特殊排行榜',
                          style: TextStyle(
                            color: textPrimaryColor,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _loadRanking,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        foregroundColor: textPrimaryColor,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.refresh, size: 16),
                          SizedBox(width: 4),
                          Text('刷新'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 排行榜类型选择按钮
              Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: ElevatedButton(
                  onPressed: _showRankingTypeDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[100],
                    foregroundColor: textPrimaryColor,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _getRankingTypeName(_currentRankingType),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_drop_down, size: 20),
                    ],
                  ),
                ),
              ),

              // 排行榜列表
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 5.0,
                        offset: Offset(2.0, 2.0),
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              const Text('正在加载...'),
                            ],
                          ),
                        )
                      : Stack(
                          children: [
                            // 主内容区
                            _errorMessage != null
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.error_outline,
                                              size: 48, color: Colors.red),
                                          const SizedBox(height: 16),
                                          Text(
                                            _errorMessage!,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                fontSize: 16,
                                                color: Colors.red),
                                          ),
                                          const SizedBox(height: 16),
                                          ElevatedButton(
                                            onPressed: _loadRanking,
                                            child: const Text('重试'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : _rankingList.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              _isRecalculating
                                                  ? Icons.cloud_download
                                                  : Icons.music_note,
                                              size: 48,
                                              color: _isRecalculating
                                                  ? Colors.purple
                                                  : Colors.grey,
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              _isRecalculating
                                                  ? '正在重新计算排行数据...'
                                                  : '暂无排行数据',
                                              style:
                                                  const TextStyle(fontSize: 16),
                                            ),
                                            if (_isRecalculating) ...[
                                              const Text(
                                                '解析maidata中，请耐心等待',
                                                style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey),
                                              ),
                                              const SizedBox(height: 20),
                                              SizedBox(
                                                width: 200,
                                                child: LinearProgressIndicator(
                                                  value: _progress / 100,
                                                  backgroundColor:
                                                      Colors.grey[200],
                                                  valueColor:
                                                      const AlwaysStoppedAnimation<
                                                          Color>(Colors.purple),
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                '$_progress%',
                                                style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey),
                                              ),
                                            ] else ...[
                                              const SizedBox(height: 8),
                                              const Text(
                                                '获取数据后点击右上角刷新按钮生成',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey),
                                              ),
                                            ],
                                          ],
                                        ),
                                      )
                                    : ListView.builder(
                                        padding: EdgeInsets.only(
                                            top: _isRecalculating ? 56 : 0),
                                        itemCount: _rankingList.length,
                                        itemBuilder: (context, index) {
                                          SpecialRankingEntry entry =
                                              _rankingList[index];
                                          return InkWell(
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        SongInfoPage(
                                                      songId: entry.songId,
                                                      initialLevelIndex:
                                                          entry.difficultyIndex,
                                                      isDefaultLevelIndex:
                                                          false,
                                                    ),
                                                  ),
                                                );
                                              },
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 12,
                                                ),
                                                decoration: BoxDecoration(
                                                  border: index <
                                                          _rankingList.length -
                                                              1
                                                      ? const Border(
                                                          bottom: BorderSide(
                                                            color: Colors.grey,
                                                            width: 0.5,
                                                          ),
                                                        )
                                                      : null,
                                                ),
                                                child: Row(
                                                  children: [
                                                    // 排名
                                                    _buildRankBadge(entry.rank),
                                                    const SizedBox(width: 12),

                                                    // 封面
                                                    ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      child: CoverUtil
                                                          .buildCoverWidgetWithContext(
                                                        context,
                                                        entry.songId,
                                                        56,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),

                                                    // 歌曲信息
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              _buildTypeTag(
                                                                  entry
                                                                      .songType,
                                                                  entry.songId),
                                                              const SizedBox(
                                                                  width: 6),
                                                              Expanded(
                                                                child: Text(
                                                                  entry
                                                                      .songTitle,
                                                                  style:
                                                                      const TextStyle(
                                                                    fontSize:
                                                                        14,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color: Colors
                                                                        .black,
                                                                  ),
                                                                  maxLines: 1,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(
                                                              height: 4),
                                                          Row(
                                                            children: [
                                                              _buildDifficultyTag(
                                                                  entry
                                                                      .difficultyLabel,
                                                                  entry
                                                                      .difficultyIndex,
                                                                  entry.songId),
                                                              const SizedBox(
                                                                  width: 8),
                                                              Text(
                                                                '${entry.ds}',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 12,
                                                                  color: Colors
                                                                          .grey[
                                                                      700],
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),

                                                    // 排行榜数值
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 12,
                                                        vertical: 6,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            _getRankingValueColor()
                                                                .shade50,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                      ),
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .center,
                                                        children: [
                                                          Text(
                                                            _formatRankingValue(
                                                                entry
                                                                    .breakCount),
                                                            style: TextStyle(
                                                              fontSize: 18,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color:
                                                                  _getRankingValueColor(),
                                                            ),
                                                          ),
                                                          Text(
                                                            _getRankingValueLabel(),
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              color:
                                                                  _getRankingValueColor()
                                                                      .shade400,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ));
                                        },
                                      ),

                            // 重新计算进度横幅：显示在列表顶部，不遮挡列表内容
                            if (_isRecalculating)
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.shade50,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(12),
                                      topRight: Radius.circular(12),
                                    ),
                                    border: Border(
                                      bottom: BorderSide(
                                          color: Colors.purple.shade200,
                                          width: 1),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.purple.shade400),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          '正在重新计算... $_progress%',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.purple.shade700),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 100,
                                        child: LinearProgressIndicator(
                                          value: _progress / 100,
                                          backgroundColor:
                                              Colors.purple.shade100,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.purple.shade400),
                                        ),
                                      ),
                                    ],
                                  ),
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
