import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:marquee/marquee.dart';
import 'package:my_first_flutter_app/manager/SongAliasManager.dart';
import 'package:my_first_flutter_app/manager/MaimaiMusicDataManager.dart';
import 'package:my_first_flutter_app/manager/UserPlayDataManager.dart';
import 'package:my_first_flutter_app/manager/DiffMusicDataManager.dart';
import 'package:my_first_flutter_app/entity/DiffSong.dart';
import 'package:my_first_flutter_app/utils/CoverUtil.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:url_launcher/url_launcher.dart';

class SongInfoPage extends StatefulWidget {
  final String songId;
  final int initialLevelIndex;

  const SongInfoPage(
      {super.key, required this.songId, this.initialLevelIndex = 0});

  @override
  State<SongInfoPage> createState() => _SongInfoPageState();
}

class _SongInfoPageState extends State<SongInfoPage> {
  // 数据加载状态
  bool _isLoading = true;
  Map<String, dynamic>? _songData;
  List<dynamic>? _diffData; // 保持为dynamic类型，兼容Map和DiffData
  Map<String, dynamic>? _userData;
  List<dynamic>? _tagData;
  List<dynamic>? _tagSongsData;
  
  // 舞萌DX 完成度-评级-乘数对照表
  final List<Map<String, dynamic>> maimaiRatingMultiplier = [
    {"completion": 100.5, "rating": "SSS+", "multiplier": 0.224},
    {"completion": 100.4999, "rating": "SSS", "multiplier": 0.222},
    {"completion": 100.0, "rating": "SSS", "multiplier": 0.216},
    {"completion": 99.9999, "rating": "SS+", "multiplier": 0.214},
    {"completion": 99.5, "rating": "SS+", "multiplier": 0.211},
    {"completion": 99.0, "rating": "SS", "multiplier": 0.208},
    {"completion": 98.9999, "rating": "S+", "multiplier": 0.206},
    {"completion": 98.0, "rating": "S+", "multiplier": 0.203},
    {"completion": 97.0, "rating": "S", "multiplier": 0.2},
    {"completion": 96.9999, "rating": "AAA", "multiplier": 0.176},
    {"completion": 94.0, "rating": "AAA", "multiplier": 0.168},
    {"completion": 90.0, "rating": "AA", "multiplier": 0.152},
    {"completion": 80.0, "rating": "A", "multiplier": 0.136},
    {"completion": 79.9999, "rating": "BBB", "multiplier": 0.128},
    {"completion": 75.0, "rating": "BBB", "multiplier": 0.120},
    {"completion": 70.0, "rating": "BB", "multiplier": 0.112},
    {"completion": 60.0, "rating": "B", "multiplier": 0.096},
    {"completion": 50.0, "rating": "C", "multiplier": 0.08},
  ];

  // 当前选中的难度索引
  late int _currentDiffIndex; // 初始值将在initState中设置
  
  // 表格展开状态
  bool _starScoreTableExpanded = false; // 星星等级表格默认收起
  bool _achievementScoreTableExpanded = false; // 达成率表格默认收起
  bool _tagsTableExpanded = false; // 谱面标签默认收起
  bool _toleranceCalculationExpanded = false; // 容错计算默认收起
  bool _ratingDistributionExpanded = false; // 评级分布默认收起
  bool _comboDistributionExpanded = false; // 连击分布默认收起
  
  // 容错计算相关
  String _selectedNoteType = 'TAP'; // 当前选中的音符类型
  final List<String> _noteTypes = ['TAP', 'HOLD', 'SLIDE', 'TOUCH', 'BREAK']; // 五种音符类型
  // 各音符权重（参考AchievementRateCalculatorPage）
  static const int _tapWeight = 1;
  static const int _holdWeight = 2;
  static const int _slideWeight = 3;
  static const int _touchWeight = 1;
  static const int _breakWeight = 5;

  @override
  void initState() {
    super.initState();
    _currentDiffIndex = widget.initialLevelIndex;
    _loadData();
  }

  // 加载所有数据
  Future<void> _loadData() async {
    try {
      // 加载歌曲基础数据
      if (await MaimaiMusicDataManager().hasCachedData()) {
        final songs = await MaimaiMusicDataManager().getCachedSongs();
        if (songs != null) {
          // 更优的解决方案
          final songIndex = songs.indexWhere((s) => s.id == widget.songId);
          if (songIndex != -1) {
            final song = songs[songIndex];
            _songData = {
              'id': song.id,
              'title': song.title,
              'type': song.type,
              'ds': song.ds,
              'level': song.level,
              'cids': song.cids,
              'charts': song.charts
                  .map((chart) =>
                      {'notes': chart.notes, 'charter': chart.charter})
                  .toList(),
              'basic_info': {
                'title': song.basicInfo.title,
                'artist': song.basicInfo.artist,
                'genre': song.basicInfo.genre,
                'bpm': song.basicInfo.bpm,
                'release_date': song.basicInfo.releaseDate,
                'from': song.basicInfo.from,
                'is_new': song.basicInfo.isNew
              }
            };
          }
        }
      } else {
        // 如果 API 数据不存在，尝试从资产文件加载 JSON 数据作为 fallback
        final songData =
            await rootBundle.loadString('assets/maimai_music_data.json');
        final List<dynamic> songList = json.decode(songData);
        int songIndex =
            songList.indexWhere((song) => song['id'] == widget.songId);
        if (songIndex != -1) {
          _songData = songList[songIndex];
        }
      }

      // 加载难度数据
      final diffManager = DiffMusicDataManager();
      final diffSong = await diffManager.getCachedDiffData();
      if (diffSong != null) {
        _diffData = diffSong.charts[widget.songId];
      }

      // 加载用户数据
      final userPlayDataManager = UserPlayDataManager();
      _userData = await userPlayDataManager.getCachedUserPlayData();

      // 如果缓存中没有用户数据，尝试从资产文件加载 JSON 数据作为 fallback
      if (_userData == null) {
        final userData =
            await rootBundle.loadString('assets/userPlayData.json');
        final Map<String, dynamic> userMap = json.decode(userData);
        _userData = userMap;
      }

      // 加载标签数据
      final tagData = await rootBundle.loadString('assets/maiTags.json');
      final Map<String, dynamic> tagMap = json.decode(tagData);
      _tagData = tagMap['tags'];
      _tagSongsData = tagMap['tagSongs'];
    } catch (e) {
      print('加载数据失败: $e');
    } finally {
      // 调整_currentDiffIndex，确保不超过实际难度数量
      if (_songData != null) {
        final levels = _songData!['level'];
        if (levels != null && levels is List) {
          // 对于难度数量大于等于4个的歌曲，默认选择第4个难度
          if (levels.length >= 4 && widget.initialLevelIndex == 0) {
            _currentDiffIndex = 3; // 第4个难度（索引为3）
          } else if (_currentDiffIndex >= levels.length) {
            _currentDiffIndex = levels.length - 1;
          }
          // 确保索引不为负数
          if (_currentDiffIndex < 0) {
            _currentDiffIndex = 0;
          }

          // 对于只有2个难度的歌曲，拟合难度的数据跟第一个难度保持相同
          if (levels.length == 2 &&
              _diffData != null &&
              _diffData!.isNotEmpty) {
            _diffData = [_diffData![0], _diffData![0]];
          }
        } else {
          // 如果没有难度数据，设置为0
          _currentDiffIndex = 0;
        }
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  // 获取用户最佳成绩
  Map<String, dynamic>? _getUserBestRecord() {
    if (_userData == null || _songData == null) return null;

    final records = _userData!['records'];
    if (records == null) return null;

    // 找到对应歌曲的记录
    final songRecord = records
        .where((record) =>
            record['song_id'].toString() == widget.songId &&
            record['level_index'].toString() == _currentDiffIndex.toString())
        .toList();

    return songRecord.isNotEmpty ? songRecord.first : null;
  }

  // 获取标签分组
  Map<String, List<dynamic>> _getTagsByGroup() {
    final Map<String, List<dynamic>> groupedTags = {
      '配置': [],
      '评价': [],
      '难度': []
    };

    if (_tagData != null && _tagSongsData != null && _songData != null) {
      // 获取当前曲目的相关信息
      final String songTitle = _songData!['basic_info']['title'];
      final String songType = _songData!['type'];
      final String sheetType = songType == 'DX' ? 'dx' : 'std';

      // 映射难度索引到sheet_difficulty
      String sheetDifficulty;
      switch (_currentDiffIndex) {
        case 0:
          sheetDifficulty = 'basic';
          break;
        case 1:
          sheetDifficulty = 'advanced';
          break;
        case 2:
          sheetDifficulty = 'expert';
          break;
        case 3:
          sheetDifficulty = 'master';
          break;
        case 4:
          sheetDifficulty = 'remaster';
          break;
        default:
          sheetDifficulty = 'master';
      }

      // 过滤出当前曲目的当前难度的标签ID
      final List<int> tagIds = _tagSongsData!
          .where((item) =>
              item['song_id'] == songTitle &&
              item['sheet_type'] == sheetType &&
              item['sheet_difficulty'] == sheetDifficulty)
          .map((item) => item['tag_id'] as int)
          .toList();

      // 根据标签ID获取标签详情
      for (int tagId in tagIds) {
        final tag =
            _tagData!.firstWhere((t) => t['id'] == tagId, orElse: () => null);

        if (tag != null) {
          int groupId = tag['group_id'] ?? 0;
          String groupName;

          switch (groupId) {
            case 1:
              groupName = '配置';
              break;
            case 2:
              groupName = '难度';
              break;
            case 3:
              groupName = '评价';
              break;
            default:
              groupName = '配置';
          }

          if (groupedTags.containsKey(groupName)) {
            groupedTags[groupName]!.add(tag);
          }
        }
      }
    }

    return groupedTags;
  }

  // 根据难度索引获取主题颜色
  Color _getThemeColor(int diffIndex) {
    // 检查难度数量
    int difficultyCount = 0;
    if (_songData != null && _songData!['level'] != null) {
      difficultyCount = _songData!['level'].length;
    }

    // 对于只有1或2个难度的歌曲，所有难度的背景全部采用粉色
    if (difficultyCount <= 2) {
      return Color(0xFFE9D8FF); // Master难度的颜色
    }

    switch (diffIndex) {
      case 0: // Basic
        return Color(0xFFE8F5E8); // 浅绿色
      case 1: // Advan
        return Color(0xFFFFF8E1); // 浅黄色
      case 2: // Expert
        return Color(0xFFFCE4EC); // 浅红色
      case 3: // Master
        return Color(0xFFE9D8FF); // 当前颜色不变
      case 4: // Re:MASTER
        return Color(0xFFF3E5F5); // 浅粉色
      default:
        return Color(0xFFE9D8FF);
    }
  }

  // 根据难度索引获取次要主题颜色
  Color _getSecondaryThemeColor(int diffIndex) {
    // 检查难度数量
    int difficultyCount = 0;
    if (_songData != null && _songData!['level'] != null) {
      difficultyCount = _songData!['level'].length;
    }

    // 对于只有1或2个难度的歌曲，所有难度的背景全部采用粉色
    if (difficultyCount <= 2) {
      return Color(0xFFD4BFFF); // Master难度的颜色
    }

    switch (diffIndex) {
      case 0: // Basic
        return Color(0xFFC8E6C9); // 浅绿色
      case 1: // Advan
        return Color(0xFFFFE0B2); // 浅黄色
      case 2: // Expert
        return Color(0xFFF8BBD0); // 浅红色
      case 3: // Master
        return Color(0xFFD4BFFF); // 当前颜色不变
      case 4: // Re:MASTER
        return Color(0xFFE1BEE7); // 浅粉色
      default:
        return Color(0xFFD4BFFF);
    }
  }

  // 根据难度索引获取强调颜色
  Color _getAccentColor(int diffIndex) {
    // 检查难度数量
    int difficultyCount = 0;
    if (_songData != null && _songData!['level'] != null) {
      difficultyCount = _songData!['level'].length;
    }

    // 对于只有1或2个难度的歌曲，所有难度的背景全部采用粉色
    if (difficultyCount <= 2) {
      return Color(0xFF9966CC); // Master难度的颜色
    }

    switch (diffIndex) {
      case 0: // Basic
        return Color(0xFF4CAF50); // 绿色
      case 1: // Advan
        return Color(0xFFFF9800); // 橙色
      case 2: // Expert
        return Color(0xFFE91E63); // 红色
      case 3: // Master
        return Color(0xFF9966CC); // 当前颜色不变
      case 4: // Re:MASTER
        return Color(0xFF9C27B0); // 紫色
      default:
        return Color(0xFF9966CC);
    }
  }
  
  // 计算单曲Rating
  int _calculateSingleRating(double difficulty, double completion) {
    // 特别处理：如果达成率大于100.5，则按100.5计算
    double adjustedCompletion = completion > 100.5 ? 100.5 : completion;
    double calculationCompletion = completion > 100.5 ? 100.5 : completion;

    // 查找对应的评级和乘数
    Map<String, dynamic>? selectedRating;
    
    // 遍历表格查找正确的区间
    for (var item in maimaiRatingMultiplier) {
      if (adjustedCompletion >= item['completion']) {
        selectedRating = item;
        break;
      }
    }
    
    // 如果没有找到（不应该发生），使用默认值
    selectedRating ??= {"rating": "D", "multiplier": 0.016};

    double multiplier = selectedRating['multiplier'];

    // 计算单曲Rating
    double singleRating = difficulty * multiplier * calculationCompletion;
    return singleRating.floor(); // 取整数部分（向下取整）
  }
  
  // 构建星星等级最低DX分对照表
  Widget _buildStarScoreTable() {
    if (_songData == null) return Container();
    
    int maxScore = _calculateMaxDxScore(int.parse(widget.songId), _currentDiffIndex);
    
    // 星星等级对应的最低达成率（降序排列）
    List<Map<String, dynamic>> starLevels = [
      {"star": 6, "rate": 0.99, "color": Colors.yellow},
      {"star": 5.5, "rate": 0.98, "color": Colors.yellow},
      {"star": 5, "rate": 0.97, "color": Colors.yellow},
      {"star": 4, "rate": 0.95, "color": Colors.orange},
      {"star": 3, "rate": 0.93, "color": Colors.orange},
      {"star": 2, "rate": 0.90, "color": Colors.green.shade300},
      {"star": 1, "rate": 0.85, "color": Colors.green.shade300},
    ];
    
    // 计算每个星星等级的最低DX分
    List<Map<String, dynamic>> starScoreData = [];
    for (var item in starLevels) {
      num star = item['star'];
      double rate = item['rate'];
      Color color = item['color'];
      int minScore = (maxScore * rate).ceil();
      starScoreData.add({"star": star, "rate": rate, "minScore": minScore, "color": color});
    }
    
    // 计算提升值
    for (int i = starScoreData.length - 1; i > 0; i--) {
      int currentScore = starScoreData[i]['minScore'];
      int nextScore = starScoreData[i - 1]['minScore'];
      starScoreData[i]['delta'] = nextScore - currentScore;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题和展开收起按钮
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '星数-最低DX分对照表',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _getAccentColor(_currentDiffIndex),
              ),
            ),
            IconButton(
              icon: Icon(
                _starScoreTableExpanded ? Icons.expand_less : Icons.expand_more,
                color: _getAccentColor(_currentDiffIndex),
              ),
              onPressed: () {
                setState(() {
                  _starScoreTableExpanded = !_starScoreTableExpanded;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        
        // 表格内容（根据展开状态显示）
        if (_starScoreTableExpanded) ...[
          // 表头
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('星数', style: TextStyle(fontSize: 16, color: Colors.grey)),
                const Text('最低DX分', style: TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
          ),
          
          // 表格内容
            Column(
              children: starScoreData.asMap().entries.map((entry) {
                var item = entry.value;
                num star = item['star'];
                double rate = item['rate'];
                int minScore = item['minScore'];
                int? delta = item['delta'];
                Color color = item['color'];
                
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            '\u2726 ${star.toString()}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: color,
                              shadows: [
                                Shadow(
                                  color: color.withOpacity(0.5),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${(rate * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(fontSize: 16, color: Colors.black),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (delta != null) 
                            Text(
                              '↑$delta',
                              style: const TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          Text(
                            minScore.toString(),
                            style: const TextStyle(fontSize: 16, color: Colors.black),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ],
    );
  }

  // 构建达成率-得分对照表
  Widget _buildAchievementScoreTable() {
    if (_songData == null) return Container();
    
    double difficulty = double.tryParse(_songData!['ds'][_currentDiffIndex].toString()) ?? 0.0;
    
    // 计算每个达成率对应的得分
    List<Map<String, dynamic>> scoreData = [];
    for (var item in maimaiRatingMultiplier) {
      double completion = item['completion'];
      String rating = item['rating'];
      int score = _calculateSingleRating(difficulty, completion);
      scoreData.add({"completion": completion, "rating": rating, "score": score});
    }
    
    // 对于定数大于等于12.0的谱面，添加额外的达成率点（比基准达成率高1分）
    if (difficulty >= 12.0) {
      // 定义需要添加额外点的基准达成率
      List<double> baseCompletions = [97.0, 98.0, 99.0, 99.5, 100.0];
      
      for (double baseCompletion in baseCompletions) {
        // 找到基准达成率对应的得分
        var baseItem = scoreData.firstWhere(
          (item) => item['completion'] == baseCompletion,
        );
        
        int baseScore = baseItem['score'];
        int targetScore = baseScore + 1;
        
        // 二分查找找到需要的达成率
        double lowerBound = baseCompletion;
        double upperBound = baseCompletion;
        
        // 确定上界
        switch (baseCompletion) {
          case 97.0:
            upperBound = 98.0;
            break;
          case 98.0:
            upperBound = 98.9999;
            break;
          case 99.0:
            upperBound = 99.5;
            break;
          case 99.5:
            upperBound = 99.9999;
            break;
          case 100.0:
            upperBound = 100.4999;
            break;
        }
        
        // 二分查找
        double mid = lowerBound;
        int iterations = 0;
        while (upperBound - lowerBound > 0.0001 && iterations < 100) {
          mid = (lowerBound + upperBound) / 2;
          int currentScore = _calculateSingleRating(difficulty, mid);
          
          if (currentScore < targetScore) {
            lowerBound = mid;
          } else {
            upperBound = mid;
          }
          iterations++;
        }
        
        // 添加新的达成率点
        if (_calculateSingleRating(difficulty, mid) >= targetScore) {
          // 查找对应的评级
          String rating = "";
          for (var item in maimaiRatingMultiplier) {
            if (mid >= item['completion']) {
              rating = item['rating'];
              break;
            }
          }
          
          scoreData.add({"completion": mid, "rating": rating, "score": targetScore});
        }
            }
      
      // 按达成率降序排序
      scoreData.sort((a, b) => b['completion'].compareTo(a['completion']));
    }
    
    // 计算得分提升值
    for (int i = scoreData.length - 1; i > 0; i--) {
      int currentScore = scoreData[i]['score'];
      int nextScore = scoreData[i - 1]['score'];
      scoreData[i]['delta'] = nextScore - currentScore;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题和展开收起按钮
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '达成率-得分对照表',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _getAccentColor(_currentDiffIndex),
              ),
            ),
            IconButton(
              icon: Icon(
                _achievementScoreTableExpanded ? Icons.expand_less : Icons.expand_more,
                color: _getAccentColor(_currentDiffIndex),
              ),
              onPressed: () {
                setState(() {
                  _achievementScoreTableExpanded = !_achievementScoreTableExpanded;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        
        // 表格内容（根据展开状态显示）
        if (_achievementScoreTableExpanded) ...[
          // 表头
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('达成率', style: TextStyle(fontSize: 16, color: Colors.grey)),
                const Text('得分', style: TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
          ),
          
          // 表格内容
            Column(
              children: scoreData.asMap().entries.map((entry) {
                var item = entry.value;
                String rating = item['rating'];
                double completion = item['completion'];
                int score = item['score'];
                int? delta = item['delta'];
                
                // 获取评级颜色
                Color ratingColor = Colors.black;
                switch (rating) {
                  case 'SSS+':
                  case 'SSS':
                    ratingColor = Colors.yellow;
                    break;
                  case 'SS+':
                  case 'SS':
                    ratingColor = Color(0xFFFFAA00);
                    break;
                  case 'S+':
                  case 'S':
                    ratingColor = Color(0xFFFF9900);
                    break;
                  case 'AAA':
                  case 'AA':
                  case 'A':
                    ratingColor = Color(0xFFFF4444);
                    break;
                  case 'BBB':
                  case 'BB':
                  case 'B':
                    ratingColor = Color(0xFF44AAFF);
                    break;
                  case 'C':
                    ratingColor = Color(0xFF88CCAA);
                    break;
                }
                
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            rating,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: ratingColor,
                              shadows: [
                                Shadow(
                                  color: ratingColor.withOpacity(0.5),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${completion.toStringAsFixed(4)}%',
                            style: const TextStyle(fontSize: 16, color: Colors.black),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (delta != null) 
                            Text(
                              '↑$delta',
                              style: const TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          Text(
                            score.toString(),
                            style: const TextStyle(fontSize: 16, color: Colors.black),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _songData == null) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final basicInfo = _songData!['basic_info'];
    final charts = _songData!['charts'];
    final levels = _songData!['level'];
    final currentChart = charts[_currentDiffIndex];
    final currentDiffData =
        _diffData != null && _diffData!.length > _currentDiffIndex
            ? _diffData![_currentDiffIndex]
            : null;
    final userRecord = _getUserBestRecord();
    final groupedTags = _getTagsByGroup();

    // 获取当前难度的主题颜色
    final themeColor = _getThemeColor(_currentDiffIndex);
    final secondaryThemeColor = _getSecondaryThemeColor(_currentDiffIndex);
    final accentColor = _getAccentColor(_currentDiffIndex);

    // 自定义常量
    final Color textPrimaryColor = Color.fromARGB(255, 84, 97, 97);
    final double borderRadiusSmall = 8.0;
    final BoxShadow defaultShadow = BoxShadow(
      color: Colors.black12,
      blurRadius: 5.0,
      offset: Offset(2.0, 2.0),
    );

    // 曲绘将使用CoverPathUtil工具类加载

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 背景
          CommonWidgetUtil.buildCommonBgWidget(),
          CommonWidgetUtil.buildCommonChiffonBgWidget(context),

          // 页面内容
          Column(
            children: [
              // 标题栏
              Container(
                padding: EdgeInsets.fromLTRB(16, 48, 16, 8),
                child: Row(
                  children: [
                    // 返回按钮
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: textPrimaryColor),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    // 标题
                    Expanded(
                      child: Center(
                        child: Text(
                          '歌曲详情',
                          style: TextStyle(
                            color: textPrimaryColor,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // 占位，保持标题居中
                    SizedBox(width: 48),
                  ],
                ),
              ),

              // 主内容区域
              Expanded(
                child: Container(
                  margin: EdgeInsets.fromLTRB(8, 0, 8, 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(borderRadiusSmall),
                    boxShadow: [defaultShadow],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    // 卡片区域
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            themeColor,
                            secondaryThemeColor,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 歌曲信息头部
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 封面（可点击放大）
                              GestureDetector(
                                onTap: () {
                                  // 显示放大的封面
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return Dialog(
                                        child: Container(
                                          padding: EdgeInsets.all(16),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                basicInfo['title'],
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                  color: accentColor,
                                                ),
                                              ),
                                              SizedBox(height: 16),
                                              Container(
                                                width: 300,
                                                height: 300,
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: CoverUtil.buildCoverWidgetWithContext(context, widget.songId.toString(), 300),
                                                ),
                                              ),
                                              SizedBox(height: 16),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                children: [
                                                  ElevatedButton(
                                                    onPressed: () {
                                                      // 保存到本地相册
                                                      // 这里需要实现保存图片的逻辑
                                                      Navigator.of(context).pop();
                                                    },
                                                    child: Text('保存到相册'),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: accentColor,
                                                      foregroundColor: Colors.white,
                                                    ),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () {
                                                      Navigator.of(context).pop();
                                                    },
                                                    child: Text('关闭'),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.grey,
                                                      foregroundColor: Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                                child: Container(
                                  width: MediaQuery.of(context).size.width * 0.3,
                                  height: MediaQuery.of(context).size.width * 0.3,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: CoverUtil.buildCoverWidgetWithContext(context, widget.songId.toString(), 120),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 16),

                              // 歌曲信息
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // 根据标题长度决定是否使用滚动
                                    GestureDetector(
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return AlertDialog(
                                              title: Text('歌曲标题'),
                                              content: Text(basicInfo['title']),
                                              actions: [
                                                TextButton(
                                                  onPressed: () {
                                                    Clipboard.setData(ClipboardData(text: basicInfo['title']));
                                                    Navigator.of(context).pop();
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text('已复制到剪贴板')),
                                                    );
                                                  },
                                                  child: Text('复制'),
                                                ),
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.of(context).pop();
                                                  },
                                                  child: Text('关闭'),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          final style = TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: accentColor,
                                          );
                                          
                                          // 计算文本宽度
                                          final TextPainter textPainter = TextPainter(
                                            text: TextSpan(text: basicInfo['title'], style: style),
                                            maxLines: 1,
                                            textDirection: TextDirection.ltr,
                                          )..layout(minWidth: 0, maxWidth: double.infinity);
                                          
                                          final textWidth = textPainter.width;
                                          final safeWidth = constraints.maxWidth * 0.9; // 留10%的安全空间
                                          
                                          // 如果文本宽度小于安全宽度，不需要滚动
                                          if (textWidth <= safeWidth) {
                                            return Text(
                                              basicInfo['title'],
                                              style: style,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            );
                                          } else {
                                            // 否则使用Marquee组件
                                            return SizedBox(
                                              height: 40,
                                              child: Marquee(
                                                text: basicInfo['title'],
                                                style: style,
                                                scrollAxis: Axis.horizontal,
                                                blankSpace: 20.0,
                                                velocity: 30.0,
                                                pauseAfterRound: Duration(seconds: 3),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ),

                                    const SizedBox(height: 12),
                                    // 显示歌曲别名
                                    _buildAliasSection(basicInfo['title']),

                                    const SizedBox(height: 8),
                                    
                                    // 显示类型和序号
                                    Row(
                                      children: [
                                        Text(
                                          widget.songId.length == 6 ? 'UTAGE' : '${_songData!['type'] == 'SD' ? 'ST' : _songData!['type']}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: widget.songId.length == 6 ? Color(0xFFFF6B8B) : (_songData!['type'] == 'SD' ? Colors.blue : Colors.orange),
                                          ),
                                        ),
                                        Text(
                                          '  #${widget.songId}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // 难度标签页
                          Row(
                            children: List.generate(
                              levels.length,
                              (index) => Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _currentDiffIndex = index;
                                    });
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 2),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 4),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      color: _currentDiffIndex == index
                                          ? accentColor
                                          : themeColor,
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _getDiffLabel(index),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.025,
                                            fontWeight: FontWeight.bold,
                                            color: _currentDiffIndex == index
                                                ? Colors.white
                                                : accentColor,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Lv.${levels[index]}',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.03,
                                            fontWeight: FontWeight.bold,
                                            color: _currentDiffIndex == index
                                                ? Colors.white
                                                : accentColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          // 统计信息行
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStatItem('类别', basicInfo['genre']),
                              _buildStatItem(
                                  'BPM', basicInfo['bpm'].toString()),
                              _buildStatItem(
                                  '版本', _formatVersion(basicInfo['from'])),
                              _buildStatItem(
                                  '曲师', basicInfo['artist'].split('/').last),
                            ],
                          ),

                          const SizedBox(height: 20),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStatItem(
                                  '官方定数',
                                  _songData!['ds'][_currentDiffIndex]
                                      .toStringAsFixed(1)),
                              _buildStatItem(
                                  '拟合难度',
                                  currentDiffData != null
                                      ? (currentDiffData is DiffData
                                              ? currentDiffData.fitDiff
                                              : currentDiffData['fit_diff'])
                                          .toStringAsFixed(2)
                                      : '-'),
                              _buildStatItem('谱面谱师', currentChart['charter']),
                              _buildStatItem(
                                  '平均达成',
                                  currentDiffData != null
                                      ? '${(currentDiffData is DiffData ? currentDiffData.avg : currentDiffData['avg']).toStringAsFixed(2)}%'
                                      : '-'),
                            ],
                          ),

                          const SizedBox(height: 20),


                          // 音符分布网格
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                  child: _buildNoteItem('TAP',
                                      currentChart['notes'][0].toString())),
                              SizedBox(width: 4),
                              Expanded(
                                  child: _buildNoteItem('HOLD',
                                      currentChart['notes'][1].toString())),
                              SizedBox(width: 4),
                              Expanded(
                                  child: _buildNoteItem('SLIDE',
                                      currentChart['notes'][2].toString())),
                              SizedBox(width: 4),
                              Expanded(
                                  child: _buildNoteItem(
                                      'BREAK',
                                      currentChart['notes'].length > 4
                                          ? currentChart['notes'][4].toString()
                                          : currentChart['notes'][3]
                                              .toString())),
                              SizedBox(width: 4),
                              Expanded(
                                  child: _buildNoteItem(
                                      'TOUCH',
                                      (currentChart['notes'].length > 4
                                              ? currentChart['notes'][3]
                                              : 0)
                                          .toString())),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // 玩家最佳成绩
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                // 标题
                                Row(
                                  children: [
                                    Text(
                                      '玩家最佳成绩',
                                      style: TextStyle(
                                        fontSize: MediaQuery.of(context)
                                                .size
                                                .width *
                                            0.035,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                
                                // 内容（始终展开）
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            userRecord != null
                                                ? '${userRecord['achievements'].toStringAsFixed(4)}%'
                                                : '无记录',
                                            style: TextStyle(
                                              fontSize: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.08,
                                              fontWeight: FontWeight.bold,
                                              foreground: Paint()
                                                ..shader = LinearGradient(
                                                  colors: [
                                                    Colors.red,
                                                    Colors.yellow,
                                                  ],
                                                  begin: Alignment.centerLeft,
                                                  end: Alignment.centerRight,
                                                ).createShader(Rect.fromLTWH(
                                                    0,
                                                    0,
                                                    MediaQuery.of(context)
                                                            .size
                                                            .width *
                                                        0.5,
                                                    50)),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            userRecord != null
                                                ? 'Rating: ${userRecord['ra']}'
                                                : '',
                                            style: TextStyle(
                                              fontSize: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.04,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          if (userRecord != null) ...[
                                            RichText(
                                              text: TextSpan(
                                                children: [
                                                  TextSpan(
                                                    text:
                                                        'DX分数: ${userRecord['dxScore']} / ${_calculateMaxDxScore(int.parse(widget.songId), _currentDiffIndex)}  ',
                                                    style: TextStyle(
                                                      fontSize:
                                                          MediaQuery.of(context)
                                                                  .size
                                                                  .width *
                                                              0.042,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            RichText(
                                              text: TextSpan(
                                                children: [
                                                  TextSpan(
                                                    text: 'DX分数达成率: ',
                                                    style: TextStyle(
                                                      fontSize: MediaQuery.of(context).size.width * 0.042,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: '${(userRecord['dxScore'] / _calculateMaxDxScore(int.parse(widget.songId), _currentDiffIndex) * 100).toStringAsFixed(2)}%  ',
                                                    style: TextStyle(
                                                      fontSize: MediaQuery.of(context).size.width * 0.042,
                                                      color: _getStarsColor(
                                                          _calculateStars(
                                                              int.parse(widget.songId),
                                                              _currentDiffIndex,
                                                              userRecord['dxScore'])),
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: _calculateStarsBonus(int.parse(widget.songId), _currentDiffIndex, userRecord['dxScore']),
                                              style: TextStyle(
                                                fontSize: MediaQuery.of(context).size.width * 0.042,
                                                color: _getStarsColor(
                                                    _calculateStars(
                                                        int.parse(widget.songId),
                                                        _currentDiffIndex,
                                                        userRecord['dxScore'])),
                                              ),
                                            ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            
                                            const SizedBox(height: 8),
                                          ],
                                          Row(
                                            children: [
                                              Text('连击,同步：'),
                                              if (userRecord != null) ...[
                                                userRecord['fc'].isNotEmpty 
                                                    ? _buildBadge(userRecord['fc'])
                                                    : _buildPlaceholder(),
                                                userRecord['fs'].isNotEmpty 
                                                    ? _buildBadge(userRecord['fs'])
                                                    : _buildPlaceholder(),
                                              ] else ...[
                                                _buildPlaceholder(),
                                                _buildPlaceholder(),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // 跳转到B站按钮（放在玩家最佳成绩下方）
                          Container(
                            margin: const EdgeInsets.only(top: 12),
                            child: ElevatedButton(
                              onPressed: _jumpToBilibili,
                              child: const Text('跳转到B站'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.pink,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // 评级分布
                          _buildRatingDistribution(currentDiffData),

                          const SizedBox(height: 20),

                          // 连击分布
                          _buildComboDistribution(currentDiffData),

                          const SizedBox(height: 20),

                          // 谱面标签
                          Container(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 标题和展开收起按钮
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '谱面标签(仅供参考)',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: accentColor,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        _tagsTableExpanded ? Icons.expand_less : Icons.expand_more,
                                        color: accentColor,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _tagsTableExpanded = !_tagsTableExpanded;
                                        });
                                      },
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 10),

                                // 标签分组（根据展开状态显示）
                                if (_tagsTableExpanded) ...[
                                  for (var group in groupedTags.entries)
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          group.key,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: accentColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        if (group.value.isNotEmpty)
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: group.value
                                                .map(
                                                  (tag) => Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 12,
                                                      vertical: 6,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              20),
                                                      color:
                                                          _getTagColor(group.key),
                                                      border: Border.all(
                                                        color: _getTagBorderColor(
                                                            group.key),
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      tag['localized_name']
                                                          ['zh-Hans'],
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: _getTagTextColor(
                                                            group.key),
                                                      ),
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                          )
                                        else
                                          Text(
                                            '当前分类暂无标签',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        const SizedBox(height: 12),
                                      ],
                                    ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),
                          
                          // 容错计算
                          _buildToleranceCalculation(),
                          
                          const SizedBox(height: 20),
                          
                          // 星星等级最低DX分对照表
                          _buildStarScoreTable(),
                          
                          const SizedBox(height: 20),
                          
                          // 达成率-得分对照表
                          _buildAchievementScoreTable(),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
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

  // 构建容错计算区域
  Widget _buildToleranceCalculation() {
    if (_songData == null) return Container();
    
    final currentChart = _songData!['charts'][_currentDiffIndex];
    final notes = currentChart['notes'];
    
    // 计算总音符权重
    int totalTap = notes.length > 0 ? notes[0] : 0;
    int totalHold = notes.length > 1 ? notes[1] : 0;
    int totalSlide = notes.length > 2 ? notes[2] : 0;
    int totalTouch = notes.length == 5 ? notes[3] : 0;
    int totalBreak = notes.length == 5 ? notes[4] : notes[3];
    
    int totalWeight = totalTap * _tapWeight +
                      totalHold * _holdWeight +
                      totalSlide * _slideWeight +
                      totalTouch * _touchWeight +
                      totalBreak * _breakWeight;
    
    // 获取当前选中音符的信息
    int noteCount = 0;
    int noteWeight = 0;
    switch (_selectedNoteType) {
      case 'TAP':
        noteCount = totalTap;
        noteWeight = _tapWeight;
        break;
      case 'HOLD':
        noteCount = totalHold;
        noteWeight = _holdWeight;
        break;
      case 'SLIDE':
        noteCount = totalSlide;
        noteWeight = _slideWeight;
        break;
      case 'TOUCH':
        noteCount = totalTouch;
        noteWeight = _touchWeight;
        break;
      case 'BREAK':
        noteCount = totalBreak;
        noteWeight = _breakWeight;
        break;
    }
    
    double weightRatio = totalWeight > 0 ? (noteCount * noteWeight) / totalWeight : 0;
    
    // 计算判定损失（参考AchievementRateCalculatorPage）
    double greatLoss = totalWeight > 0 ? (0.20 * 100.00 * noteWeight / totalWeight) : 0;
    double goodLoss = totalWeight > 0 ? (0.50 * 100.00 * noteWeight / totalWeight) : 0;
    double missLoss = totalWeight > 0 ? (1.00 * 100.00 * noteWeight / totalWeight) : 0;
    
    // BREAK音符特殊判定损失
   // 50落：基础部分权重相同，额外部分损失0.25 (1.0 - 0.75)
    double break50Loss = noteCount > 0 ? 0.25 / noteCount : 0; // 50落 -> 损失25%
    // 100落：基础部分权重相同，额外部分损失0.50 (1.0 - 0.50)
    double break100Loss = noteCount > 0 ? 0.5 / noteCount : 0; // 100落 -> 损失50%
    double break80Loss = totalWeight > 0 ? (0.20 * 100.00 * noteWeight / totalWeight) : 0; // 80% -> 损失20%
    double break60Loss = totalWeight > 0 ? (0.40 * 100.00 * noteWeight / totalWeight) : 0; // 60% -> 损失40%
    double break50gLoss = totalWeight > 0 ? (0.50 * 100.00 * noteWeight / totalWeight) : 0; // 50% -> 损失50%
    double breakGoLoss = totalWeight > 0 ? (0.60 * 100.00 * noteWeight / totalWeight) : 0; // 40% -> 损失60%
    
    // 计算容错数量
    int tolerance05Great = greatLoss > 0 ? (0.5 / greatLoss).floor() : 0;
    int tolerance05Good = goodLoss > 0 ? (0.5 / goodLoss).floor() : 0;
    int tolerance05Miss = missLoss > 0 ? (0.5 / missLoss).floor() : 0;
    int tolerance10Great = greatLoss > 0 ? (1.0 / greatLoss).floor() : 0;
    int tolerance10Good = goodLoss > 0 ? (1.0 / goodLoss).floor() : 0;
    int tolerance10Miss = missLoss > 0 ? (1.0 / missLoss).floor() : 0;
    
    // BREAK音符容错数量
    int tolerance05Break80 = break80Loss > 0 ? (0.5 / break80Loss).floor() : 0;
    int tolerance05Break60 = break60Loss > 0 ? (0.5 / break60Loss).floor() : 0;
    int tolerance05Break50g = break50gLoss > 0 ? (0.5 / break50gLoss).floor() : 0;
    int tolerance05BreakGo = breakGoLoss > 0 ? (0.5 / breakGoLoss).floor() : 0;
    int tolerance10Break80 = break80Loss > 0 ? (1.0 / break80Loss).floor() : 0;
    int tolerance10Break60 = break60Loss > 0 ? (1.0 / break60Loss).floor() : 0;
    int tolerance10Break50g = break50gLoss > 0 ? (1.0 / break50gLoss).floor() : 0;
    int tolerance10BreakGo = breakGoLoss > 0 ? (1.0 / breakGoLoss).floor() : 0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题和展开收起按钮
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '容错计算',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _getAccentColor(_currentDiffIndex),
              ),
            ),
            IconButton(
              icon: Icon(
                _toleranceCalculationExpanded ? Icons.expand_less : Icons.expand_more,
                color: _getAccentColor(_currentDiffIndex),
              ),
              onPressed: () {
                setState(() {
                  _toleranceCalculationExpanded = !_toleranceCalculationExpanded;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        
        // 表格内容（根据展开状态显示）
        if (_toleranceCalculationExpanded) ...[
          // 音符类型选择器
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _noteTypes
                .where((noteType) => !(noteType == 'TOUCH' && totalTouch == 0))
                .map((noteType) => ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedNoteType = noteType;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedNoteType == noteType 
                    ? _getAccentColor(_currentDiffIndex) 
                    : Colors.grey[200],
                foregroundColor: _selectedNoteType == noteType 
                    ? Colors.white 
                    : Colors.black,
              ),
              child: Text(noteType),
            )).toList(),
          ),
          
          const SizedBox(height: 15),
          
          // 容错信息
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('音符类型:', style: TextStyle(color: Colors.grey)),
                    Text(_selectedNoteType, style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('占总权重比例:', style: TextStyle(color: Colors.grey)),
                    Text('${(weightRatio * 100).toStringAsFixed(2)}%', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                // 仅当选中非BREAK音符时显示常规判定损失
                if (_selectedNoteType != 'BREAK') ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('GREAT损失:', style: TextStyle(color: Colors.grey)),
                      Text('${greatLoss.toStringAsFixed(4)}%', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('GOOD损失:', style: TextStyle(color: Colors.grey)),
                      Text('${goodLoss.toStringAsFixed(4)}%', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('MISS损失:', style: TextStyle(color: Colors.grey)),
                      Text('${missLoss.toStringAsFixed(4)}%', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('-0.5% 容错 (GREAT):', style: TextStyle(color: Colors.grey)),
                      Text('${tolerance05Great}个', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('-0.5% 容错 (GOOD):', style: TextStyle(color: Colors.grey)),
                      Text('${tolerance05Good}个', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('-0.5% 容错 (MISS):', style: TextStyle(color: Colors.grey)),
                      Text('${tolerance05Miss}个', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('-1% 容错 (GREAT):', style: TextStyle(color: Colors.grey)),
                      Text('${tolerance10Great}个', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('-1% 容错 (GOOD):', style: TextStyle(color: Colors.grey)),
                      Text('${tolerance10Good}个', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('-1% 容错 (MISS):', style: TextStyle(color: Colors.grey)),
                      Text('${tolerance10Miss}个', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
                
                // BREAK音符特殊判定损失（仅当选中BREAK时显示）
                if (_selectedNoteType == 'BREAK') ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('50落损失:', style: TextStyle(color: Colors.grey)),
                      Text('${break50Loss.toStringAsFixed(4)}%', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('100落损失:', style: TextStyle(color: Colors.grey)),
                      Text('${break100Loss.toStringAsFixed(4)}%', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('80% GREAT损失:', style: TextStyle(color: Colors.grey)),
                      Text('${break80Loss.toStringAsFixed(4)}%', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('60% GREAT损失:', style: TextStyle(color: Colors.grey)),
                      Text('${break60Loss.toStringAsFixed(4)}%', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('50% GREAT损失:', style: TextStyle(color: Colors.grey)),
                      Text('${break50gLoss.toStringAsFixed(4)}%', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('GOOD 损失:', style: TextStyle(color: Colors.grey)),
                      Text('${breakGoLoss.toStringAsFixed(4)}%', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('MISS损失:', style: TextStyle(color: Colors.grey)),
                      Text('${missLoss.toStringAsFixed(4)}%', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('-0.5% 容错 (80% GREAT):', style: TextStyle(color: Colors.grey)),
                      Text('${tolerance05Break80}个', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('-0.5% 容错 (60% GREAT):', style: TextStyle(color: Colors.grey)),
                      Text('${tolerance05Break60}个', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('-0.5% 容错 (50% GREAT):', style: TextStyle(color: Colors.grey)),
                      Text('${tolerance05Break50g}个', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('-0.5% 容错 (GOOD):', style: TextStyle(color: Colors.grey)),
                      Text('${tolerance05BreakGo}个', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('-0.5% 容错 (MISS):', style: TextStyle(color: Colors.grey)),
                      Text('${tolerance05Miss}个', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('-1% 容错 (80% GREAT):', style: TextStyle(color: Colors.grey)),
                      Text('${tolerance10Break80}个', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('-1% 容错 (60% GREAT):', style: TextStyle(color: Colors.grey)),
                      Text('${tolerance10Break60}个', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('-1% 容错 (50% GREAT):', style: TextStyle(color: Colors.grey)),
                      Text('${tolerance10Break50g}个', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('-1% 容错 (GOOD):', style: TextStyle(color: Colors.grey)),
                      Text('${tolerance10BreakGo}个', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                   const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('-1% 容错 (MISS):', style: TextStyle(color: Colors.grey)),
                      Text('${tolerance10Miss}个', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  // 构建统计项
  Widget _buildStatItem(String label, String value) {
    // 获取当前难度的强调颜色
    final accentColor = _getAccentColor(_currentDiffIndex);

    // 使用MediaQuery获取屏幕尺寸
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // 根据屏幕尺寸计算字体大小
    final fontSize = screenWidth * 0.04; // 字体大小为屏幕宽度的4%

    final textStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      color: accentColor,
    );

    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 4),
          // 为超出容器宽度的文本添加水平滚动
          (label == '谱面谱师' || label == '曲师' || label == '版本' || label == '类别')
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    // 计算文本宽度
                    final TextPainter textPainter = TextPainter(
                      text: TextSpan(text: value, style: textStyle),
                      maxLines: 1,
                      textDirection: TextDirection.ltr,
                    )..layout(minWidth: 0, maxWidth: double.infinity);

                    final textWidth = textPainter.width;
                    final containerWidth = constraints.maxWidth;

                    // 为了确保不换行，给容器宽度一个安全margin
                    final safeContainerWidth = containerWidth * 0.85;

                    // 如果文本宽度小于安全容器宽度，不需要滚动，但仍然添加点击事件
                    if (textWidth <= safeContainerWidth) {
                      return GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text(label),
                                content: Text(value),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: value));
                                      Navigator.of(context).pop();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('已复制到剪贴板')),
                                      );
                                    },
                                    child: Text('复制'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: Text('关闭'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        child: Text(value, style: textStyle),
                      );
                    }

                    // 否则使用Marquee组件，并添加点击事件
                    return GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: Text(label),
                              content: Text(value),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: value));
                                    Navigator.of(context).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('已复制到剪贴板')),
                                    );
                                  },
                                  child: Text('复制'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: Text('关闭'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: SizedBox(
                        height: screenHeight * 0.03, // 容器高度为屏幕高度的3%
                        child: Marquee(
                          text: value,
                          style: textStyle,
                          scrollAxis: Axis.horizontal,
                          blankSpace: screenWidth * 0.05, // 空白空间为屏幕宽度的5%
                          velocity: screenWidth * 0.08, // 滚动速度为屏幕宽度的8%
                          pauseAfterRound: Duration(seconds: 3),
                        ),
                      ),
                    );
                  },
                )
              : GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text(label),
                          content: Text(value),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: value));
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('已复制到剪贴板')),
                                );
                              },
                              child: Text('复制'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: Text('关闭'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  child: Text(
                    value,
                    style: textStyle,
                  ),
                ),
        ],
      ),
    );
  }

  // 构建音符项
  Widget _buildNoteItem(String type, String count) {
    // 获取当前难度的强调颜色
    final accentColor = _getAccentColor(_currentDiffIndex);
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(6),
      child: Column(
        children: [
          Text(
            type,
            style: TextStyle(
              fontSize: screenWidth * 0.025,
              color: Colors.grey,
            ),
          ),
          Text(
            count,
            style: TextStyle(
              fontSize: screenWidth * 0.035,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }

  // 构建占位符
  Widget _buildPlaceholder() {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: Colors.grey[200],
      ),
      child: Text(
        '-',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[500],
        ),
      ),
    );
  }

  // 构建徽章
  Widget _buildBadge(String text) {
    Color bgColor;
    Color textColor;

    switch (text) {
      case 'app':
        bgColor = Color(0xFFFFF3E0);
        textColor = Color(0xFFF57C00);
        text = 'AP+';
        break;
      case 'ap':
        bgColor = Color(0xFFFFF3E0);
        textColor = Color(0xFFF57C00);
        break;
      case 'fcp':
        bgColor = Color(0xFFD4F4DD);
        textColor = Color(0xFF2E7D32);
        text = 'FC+';
        break;
      case 'fc':
        bgColor = Color(0xFFD4F4DD);
        textColor = Color(0xFF2E7D32);
        break;
      case 'fs':
        bgColor = Color.fromARGB(255, 224, 244, 255);
        textColor = Color.fromARGB(255, 0, 135, 245);
        text = 'FS';
        break;
      case 'fsp':
        bgColor = Color.fromARGB(255, 224, 244, 255);
        textColor = Color.fromARGB(255, 0, 135, 245);
        text = 'FS+';
        break;
      case 'sync':
        bgColor = Color.fromARGB(255, 224, 244, 255);
        textColor = Color.fromARGB(255, 0, 135, 245);
        break;
      case 'fsd':
        bgColor = Color(0xFFFFF3E0);
        textColor = Color(0xFFF57C00);
        text = 'FDX';
        break;
      case 'fsdp':
        bgColor = Color(0xFFFFF3E0);
        textColor = Color(0xFFF57C00);
        text = 'FDX+';
        break;
      default:
        bgColor = Color(0xFFF0F0F0);
        textColor = Color(0xFF666666);
    }

    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: bgColor,
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  // 获取难度标签
  String _getDiffLabel(int index) {
    // 检查难度数量
    int difficultyCount = 0;
    if (_songData != null && _songData!['level'] != null) {
      difficultyCount = _songData!['level'].length;
    }
    
    // 如果难度数量≤2个，显示"U\u00b7TA\u00b7GE​"
    if (difficultyCount <= 2) {
      return 'U\u00b7TA\u00b7GE​';
    }
    
    // 否则返回原来的标签
    switch (index) {
      case 0:
        return 'Basic';
      case 1:
        return 'Advan';
      case 2:
        return 'Expert';
      case 3:
        return 'Master';
      case 4:
        return 'ReMAS';
      default:
        return '';
    }
  }

  // 计算maxScore
  int _calculateMaxScore(int songId, int levelIndex) {
    if (_songData == null) return 0;

    // 查找对应的charts
    List<dynamic> charts = _songData!['charts'];
    if (levelIndex < 0 || levelIndex >= charts.length) return 0;

    dynamic chart = charts[levelIndex];
    if (chart['notes'] == null) return 0;

    // 计算maxScore
    List<dynamic> notes = chart['notes'];
    int notesSum = notes.fold(0, (sum, note) => sum + (note as int));
    return notesSum * 3;
  }

  // 计算最大DX分
  // 当ds数组长度为2时，返回两个难度谱面DX分之和
  // 否则返回当前难度的最大分数
  int _calculateMaxDxScore(int songId, int levelIndex) {
    if (_songData == null) return 0;

    // 检查ds数组长度
    List<dynamic> ds = _songData!['ds'];
    if (ds.length == 2) {
      // 计算两个难度谱面的最大分数之和
      int maxScore1 = _calculateMaxScore(songId, 0);
      int maxScore2 = _calculateMaxScore(songId, 1);
      return maxScore1 + maxScore2;
    } else {
      // 返回当前难度的最大分数
      return _calculateMaxScore(songId, levelIndex);
    }
  }

  // 计算scoreRate
  double _calculateScoreRate(int songId, int levelIndex, int score) {
    int maxScore = _calculateMaxDxScore(songId, levelIndex);
    return maxScore > 0 ? score / maxScore : 0.0;
  }

  // 计算星星等级
  String _calculateStars(int songId, int levelIndex, int score) {
    double scoreRate = _calculateScoreRate(songId, levelIndex, score);

    // 确定星星等级
    if (scoreRate >= 0.97) {
      return '\u2726 5';
    } else if (scoreRate >= 0.95) {
      return '\u2726 4';
    } else if (scoreRate >= 0.93) {
      return '\u2726 3';
    } else if (scoreRate >= 0.90) {
      return '\u2726 2';
    } else if (scoreRate >= 0.85) {
      return '\u2726 1';
    } else {
      return '\u2726 0';
    }
  }

  // 计算星星等级的最低DX分和超出部分
  String _calculateStarsBonus(int songId, int levelIndex, int score) {
    int maxScore = _calculateMaxDxScore(songId, levelIndex);
    double scoreRate = score / maxScore;
    int starLevel = 0;
    double minRate = 0.0;

    // 确定当前星星等级和对应的最低达成率
    if (scoreRate >= 0.97) {
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
      minRate = 0.85; // 0星时计算与1星的差距
    }

    // 计算最低DX分（向上取整）
    int minScore = (maxScore * minRate).ceil();
    // 计算超出部分或差距
    int difference = score - minScore;
    String symbol = difference >= 0 ? '+' : '';

    // 0星时显示1星的差距
    int displayStarLevel = starLevel == 0 ? 1 : starLevel;

    return '\u2726 $displayStarLevel $symbol$difference';
  }

  // 获取星星颜色
  Color _getStarsColor(String stars) {
    switch (stars) {
      case '\u2726 5':
        return Colors.yellow;
      case '\u2726 4':
      case '\u2726 3':
        return Colors.orange;
      case '\u2726 2':
      case '\u2726 1':
        return Colors.green.shade300;
      case '\u2726 0':
        return Colors.grey;
      default:
        return Colors.white;
    }
  }

  // 格式化版本
  String _formatVersion(String version) {
    if (version == 'maimai') {
      return 'maimai';
    }
    if (version == 'maimai PLUS') {
      return 'maimai+';
    }
    if (version == 'maimai \u3067\u3089\u3063\u304f\u3059') {
      return 'DX 2020';
    }
    if (version == 'maimai \u3067\u3089\u3063\u304f\u3059 Splash') {
      return 'DX 2021';
    }
    if (version == 'maimai \u3067\u3089\u3063\u304f\u3059 UNiVERSE') {
      return 'DX 2022';
    }
    if (version == 'maimai \u3067\u3089\u3063\u304f\u3059 FESTiVAL') {
      return 'DX 2023';
    }
    if (version == 'maimai \u3067\u3089\u3063\u304f\u3059 BUDDiES') {
      return 'DX 2024';
    }
    if (version == 'maimai \u3067\u3089\u3063\u304f\u3059 PRiSM') {
      return 'DX 2025';
    }
    if (version.contains(' PLUS')) {
      version = version.replaceFirst(' PLUS', '+');
    }
    if (version.contains('maimai') && version != 'maimai') {
      version = version.replaceFirst('maimai ', '');
    }
    if (version.contains('\u3067\u3089\u3063\u304f\u3059')) {
      version = version.replaceFirst('\u3067\u3089\u3063\u304f\u3059 ', '');
    }
    return version;
  }

  // 跳转到B站
  void _jumpToBilibili() async {
    if (_songData == null) return;

    final songTitle = _songData!['basic_info']['title'];
    final diffLabel = _getDiffLabel(_currentDiffIndex);
    final searchQuery = '$songTitle $diffLabel';

    // B站搜索链接
    final url = Uri.parse('bilibili://search?keyword=${Uri.encodeComponent(searchQuery)}');

    // 尝试打开B站应用
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      // 如果无法打开B站应用，尝试在浏览器中打开
      final webUrl = Uri.parse('https://search.bilibili.com/all?keyword=${Uri.encodeComponent(searchQuery)}');
      if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl);
      }
    }
  }

  // 获取标签颜色
  Color _getTagColor(String group) {
    switch (group) {
      case '配置':
        return Color(0xFFE8F4F8);
      case '评价':
        return Color(0xFFFFF3E0);
      case '难度':
        return Color(0xFFFCE4EC);
      default:
        return Color(0xFFF0E6FF);
    }
  }

  // 获取标签边框颜色
  Color _getTagBorderColor(String group) {
    switch (group) {
      case '配置':
        return Color(0xFFD1E7DD);
      case '评价':
        return Color(0xFFFFE0B2);
      case '难度':
        return Color(0xFFF8BBD0);
      default:
        return Color(0xFFE0D0FF);
    }
  }

  // 获取标签文本颜色
  Color _getTagTextColor(String group) {
    switch (group) {
      case '配置':
        return Color(0xFF388E3C);
      case '评价':
        return Color(0xFFF57C00);
      case '难度':
        return Color(0xFFD81B60);
      default:
        return Color(0xFF664499);
    }
  }

  // 构建评级分布
  Widget _buildRatingDistribution(dynamic currentDiffData) {
    if (currentDiffData == null) return Container();
    
    List<num> dist = currentDiffData is DiffData ? currentDiffData.dist : currentDiffData['dist'];
    if (dist.isEmpty) return Container();
    
    // 评级标签
    List<String> ratingLabels = ['D', 'C', 'B', 'BB', 'BBB', 'A', 'AA', 'AAA', 'S', 'S+', 'SS', 'SS+', 'SSS', 'SSS+'];
    
    // 确保dist长度与标签长度匹配
    if (dist.length > ratingLabels.length) {
      dist = dist.sublist(0, ratingLabels.length);
    } else if (dist.length < ratingLabels.length) {
      while (dist.length < ratingLabels.length) {
        dist.add(0);
      }
    }
    
    // 计算总数量
    num total = dist.reduce((a, b) => a + b);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题和展开收起按钮
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '评级分布(仅供参考)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _getAccentColor(_currentDiffIndex),
              ),
            ),
            IconButton(
              icon: Icon(
                _ratingDistributionExpanded ? Icons.expand_less : Icons.expand_more,
                color: _getAccentColor(_currentDiffIndex),
              ),
              onPressed: () {
                setState(() {
                  _ratingDistributionExpanded = !_ratingDistributionExpanded;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        
        // 分布图表（根据展开状态显示）
        if (_ratingDistributionExpanded) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                for (int i = ratingLabels.length - 1; i >= 0; i--)
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(ratingLabels[i], style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('${dist[i]} / ${total > 0 ? ((dist[i] / total) * 100).toStringAsFixed(2) : '0.00'}%'),
                        ],
                      ),
                      SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: dist[i] > 0 ? dist[i] / total : 0,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(_getAccentColor(_currentDiffIndex)),
                        minHeight: 8,
                      ),
                      SizedBox(height: 12),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // 构建连击分布
  Widget _buildComboDistribution(dynamic currentDiffData) {
    if (currentDiffData == null) return Container();
    
    List<num> fcDist = currentDiffData is DiffData ? currentDiffData.fcDist : currentDiffData['fc_dist'];
    if (fcDist.isEmpty) return Container();
    
    // 连击标签
    List<String> comboLabels = ['无', 'FC', 'FC+', 'AP', 'AP+'];
    
    // 确保fcDist长度与标签长度匹配
    if (fcDist.length > comboLabels.length) {
      fcDist = fcDist.sublist(0, comboLabels.length);
    } else if (fcDist.length < comboLabels.length) {
      while (fcDist.length < comboLabels.length) {
        fcDist.add(0);
      }
    }
    
    // 计算总数量
    num total = fcDist.reduce((a, b) => a + b);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题和展开收起按钮
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '连击分布(仅供参考)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _getAccentColor(_currentDiffIndex),
              ),
            ),
            IconButton(
              icon: Icon(
                _comboDistributionExpanded ? Icons.expand_less : Icons.expand_more,
                color: _getAccentColor(_currentDiffIndex),
              ),
              onPressed: () {
                setState(() {
                  _comboDistributionExpanded = !_comboDistributionExpanded;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        
        // 分布图表（根据展开状态显示）
        if (_comboDistributionExpanded) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                for (int i = comboLabels.length - 1; i >= 0; i--)
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(comboLabels[i], style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('${fcDist[i].toInt()} / ${total > 0 ? ((fcDist[i] / total) * 100).toStringAsFixed(2) : '0.00'}%'),
                        ],
                      ),
                      SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: fcDist[i] > 0 ? fcDist[i] / total : 0,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(_getAccentColor(_currentDiffIndex)),
                        minHeight: 8,
                      ),
                      SizedBox(height: 12),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // 构建别名区域
  Widget _buildAliasSection(String songTitle) {
    // 从 SongAliasManager 获取别名数据
    final aliases = SongAliasManager.instance.aliases[widget.songId] ?? [];

    if (aliases.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          '别名: 无',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        // 显示弹窗查看所有别名
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('${songTitle}的别名'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: aliases
                      .map((alias) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text('- $alias'),
                          ))
                      .toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('关闭'),
                ),
              ],
            );
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '查看别名 (${aliases.length})',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(width: 4),
            Icon(
              Icons.arrow_forward_ios,
              size: 12,
              color: Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }
}