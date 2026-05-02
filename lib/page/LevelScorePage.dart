import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/service/LevelScoreService.dart';
import 'package:my_first_flutter_app/entity/Song.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:my_first_flutter_app/utils/CoverUtil.dart';
import 'package:my_first_flutter_app/utils/StringUtil.dart';
import 'package:my_first_flutter_app/utils/ColorUtil.dart';
import 'package:my_first_flutter_app/page/SongInfoPage.dart';

class LevelScorePage extends StatefulWidget {
  const LevelScorePage({super.key});

  @override
  State<LevelScorePage> createState() => _LevelScorePageState();
}

class _LevelScorePageState extends State<LevelScorePage> {
  final LevelScoreService _service = LevelScoreService();

  // 选择状态
  List<String> _levelOptions = [];
  List<String> _titleTypeOptions = [];
  List<int> _difficultyOptions = [];

  // 缓存的全量等级选项（用于对话框）
  List<String> _allLevelOptionsCache = [];

  String? _selectedLevel;
  String? _selectedTitleType;
  int? _selectedDifficulty;

  bool _isLoading = true;

  // 缓存的歌曲完成状态数据
  List<Map<String, dynamic>>? _cachedSongsWithStatus;
  bool _isSongsLoading = false;

  // 显示模式：true 为列表模式，false 为仅曲绘模式
  bool _showListMode = true;

  // 尺寸参数
  late double _paddingXS;
  late double _paddingS;
  late double _paddingM;
  late double _paddingL;
  late double _borderRadiusSmall;
  late double _textSizeXS;
  late double _textSizeS;
  late double _textSizeM;
  late double _textSizeL;
  late double _coverSize;
  late double _scaleFactor;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  // 初始化数据
  Future<void> _initData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _titleTypeOptions = _service.getTitleTypeOptions();
      _difficultyOptions = _service.getDifficultyOptions();

      // 获取保存的用户选项
      final savedOptions = await _service.getSavedOptions();

      // 设置保存的选项，如果有效则使用，否则使用默认值
      if (_titleTypeOptions.isNotEmpty) {
        final savedTitleType = savedOptions['titleType'] as String;
        _selectedTitleType = _titleTypeOptions.contains(savedTitleType) && savedTitleType.isNotEmpty
            ? savedTitleType
            : _titleTypeOptions[0];
      }
      if (_difficultyOptions.isNotEmpty) {
        final savedDifficulty = savedOptions['difficulty'] as int;
        _selectedDifficulty = _difficultyOptions.contains(savedDifficulty)
            ? savedDifficulty
            : -1;
      }

      // 获取全量等级选项并缓存
      _allLevelOptionsCache = await _service.getAllLevelOptions();

      // 更新等级选项
      await _updateLevelOptions();
      // 设置保存的等级选项
      if (_levelOptions.isNotEmpty) {
        final savedLevel = savedOptions['level'] as String;
        _selectedLevel = _levelOptions.contains(savedLevel) && savedLevel.isNotEmpty
            ? savedLevel
            : _levelOptions[0];
      }

      // 设置保存的显示模式
      _showListMode = savedOptions['showListMode'] as bool;

      // 加载歌曲完成状态数据
      await _loadSongsWithStatus();
    } catch (e) {
      print('初始化数据时出错: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    // 保存用户选择的选项
    _service.saveSelectedOptions(
      level: _selectedLevel,
      titleType: _selectedTitleType,
      difficulty: _selectedDifficulty,
      showListMode: _showListMode,
    );
    super.dispose();
  }

  // 更新等级选项
  Future<void> _updateLevelOptions() async {
    if (_selectedDifficulty == null) {
      return;
    }

    List<String> newLevelOptions;
    
    // ALL模式下使用全量等级选项
    if (_selectedDifficulty == -1) {
      newLevelOptions = _allLevelOptionsCache;
    } else {
      newLevelOptions = await _service.getLevelOptions(_selectedDifficulty!);
    }
    
    setState(() {
      _levelOptions = newLevelOptions;
    });
  }

  // 加载歌曲完成状态（带缓存）
  Future<void> _loadSongsWithStatus() async {
    if (_selectedLevel == null || _selectedTitleType == null || _selectedDifficulty == null) {
      return;
    }

    setState(() {
      _isSongsLoading = true;
    });

    try {
      final result = await _service.getSongsByLevel(
        _selectedLevel!,
        _selectedTitleType!,
        _selectedDifficulty!,
      );
      setState(() {
        _cachedSongsWithStatus = result;
      });
    } catch (e) {
      setState(() {
        _cachedSongsWithStatus = null;
      });
    } finally {
      setState(() {
        _isSongsLoading = false;
      });
    }
  }

  // 获取难度显示名称
  String _getDifficultyName(int difficulty) {
    return _service.getDifficultyName(difficulty);
  }

  // 获取难度颜色
  Color _getDifficultyColor(int difficulty) {
    switch (difficulty) {
      case -1: return Colors.black;
      case 0: return Colors.green;
      case 1: return Color(0xFFFFCC00);
      case 2: return Colors.pink;
      case 3: return Colors.purple;
      case 4: return Colors.purple.shade200;
      default: return Colors.grey;
    }
  }

  // 获取完成状态颜色
  Color _getCompletionColor(bool completed) {
    return completed ? Colors.green : Colors.grey;
  }

  // 根据定数获取等级显示（精确到0.1）
  String _getDsLevelDisplay(double ds) {
    return ds.toStringAsFixed(1);
  }

  // 根据定数计算等级显示（x或x+）
  String _getLevelDisplay(double ds) {
    if (ds >= 15.0) {
      return '15';
    }
    int integerPart = ds.floor();
    double decimalPart = ds - integerPart;
    if (decimalPart <= 0.5) {
      return '$integerPart';
    } else {
      return '${integerPart}+';
    }
  }

  @override
  Widget build(BuildContext context) {
    // 初始化尺寸参数
    final screenWidth = MediaQuery.of(context).size.width;
    _scaleFactor = screenWidth / 375.0;
    _paddingXS = 4.0 * _scaleFactor;
    _paddingS = 8.0 * _scaleFactor;
    _paddingM = 12.0 * _scaleFactor;
    _paddingL = 16.0 * _scaleFactor;
    _borderRadiusSmall = 8.0 * _scaleFactor;
    _textSizeXS = 9.0 * _scaleFactor;
    _textSizeS = 11.0 * _scaleFactor;
    _textSizeM = 12.0 * _scaleFactor;
    _textSizeL = 14.0 * _scaleFactor;
    _coverSize = 56.0 * _scaleFactor;

    return Scaffold(
      backgroundColor: Colors.transparent,
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
                padding: EdgeInsets.fromLTRB(_paddingM, 48, _paddingM, _paddingS),
                child: Row(
                  children: [
                    // 返回按钮
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Color.fromARGB(255, 84, 97, 97)),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    // 标题
                    Expanded(
                      child: Center(
                        child: Text(
                          '等级極/将/神查询',
                          style: TextStyle(
                            color: Color.fromARGB(255, 84, 97, 97),
                            fontSize: screenWidth * 0.06,
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
                  margin: EdgeInsets.fromLTRB(_paddingS, 0, _paddingS, _paddingL),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(_borderRadiusSmall),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 5.0 * _scaleFactor,
                        offset: Offset(2.0 * _scaleFactor, 2.0 * _scaleFactor),
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          padding: EdgeInsets.all(_paddingM),
                          child: Column(
                            children: [
                              // 选择区域
                              _buildSelectionSection(),

                              SizedBox(height: _paddingL),

                              // 曲绘和完成情况显示区域
                              _buildSongListSection(),
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

  // 构建选择区域
  Widget _buildSelectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 选择等级
        Text(
          '选择等级',
          style: TextStyle(
            fontSize: _textSizeM,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700]!,
          ),
        ),
        SizedBox(height: _paddingXS),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[100]!,
            foregroundColor: Colors.grey[700]!,
            minimumSize: Size(double.infinity, 40 * _scaleFactor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_borderRadiusSmall),
            ),
          ),
          onPressed: () => _showLevelDialog(),
          child: Text(
            _selectedLevel != null ? 'Lv.${_selectedLevel}' : '请选择等级',
            style: TextStyle(fontSize: _textSizeM),
          ),
        ),

        SizedBox(height: _paddingM),

        // 选择称号类型
        Text(
          '选择称号类型',
          style: TextStyle(
            fontSize: _textSizeM,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700]!,
          ),
        ),
        SizedBox(height: _paddingXS),
        Wrap(
          spacing: _paddingS,
          runSpacing: _paddingXS,
          children: _titleTypeOptions.map((type) {
            return ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedTitleType == type
                    ? Colors.blue
                    : Colors.grey[100]!,
                foregroundColor: _selectedTitleType == type
                    ? Colors.white
                    : Colors.grey[700]!,
                minimumSize: Size(64 * _scaleFactor, 40 * _scaleFactor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_borderRadiusSmall),
                ),
              ),
              onPressed: () async {
                setState(() {
                  _selectedTitleType = type;
                  _cachedSongsWithStatus = null;
                });
                await _loadSongsWithStatus();
              },
              child: Text(
                type,
                style: TextStyle(fontSize: _textSizeM),
              ),
            );
          }).toList(),
        ),

        SizedBox(height: _paddingM),

        // 选择难度
        Text(
          '选择难度',
          style: TextStyle(
            fontSize: _textSizeM,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700]!,
          ),
        ),
        SizedBox(height: _paddingXS),
        Wrap(
          spacing: _paddingS,
          runSpacing: _paddingXS,
          children: _difficultyOptions.map((diff) {
            return ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedDifficulty == diff
                    ? _getDifficultyColor(diff)
                    : Colors.grey[100]!,
                foregroundColor: _selectedDifficulty == diff
                    ? Colors.white
                    : Colors.grey[700]!,
                minimumSize: Size(80 * _scaleFactor, 40 * _scaleFactor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_borderRadiusSmall),
                ),
              ),
              onPressed: () async {
                setState(() {
                  _selectedDifficulty = diff;
                  _cachedSongsWithStatus = null;
                });
                await _updateLevelOptions();
                // 更新选中的等级
                if (_levelOptions.contains(_selectedLevel)) {
                  // 保持当前选中
                } else if (_levelOptions.isNotEmpty) {
                  setState(() {
                    _selectedLevel = _levelOptions.isNotEmpty ? _levelOptions[0] : null;
                  });
                }
                await _loadSongsWithStatus();
              },
              child: Text(
                _getDifficultyName(diff),
                style: TextStyle(fontSize: _textSizeS),
              ),
            );
          }).toList(),
        ),

        SizedBox(height: _paddingM),
      ],
    );
  }

  // 显示等级选择对话框（使用缓存的全量等级选项）
  void _showLevelDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Center(child: Text('选择等级')),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          content: Container(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 12,
                crossAxisSpacing: 8,
                childAspectRatio: 1.5,
              ),
              itemCount: _allLevelOptionsCache.length,
              itemBuilder: (context, index) {
                final level = _allLevelOptionsCache[index];
                return Container(
                  alignment: Alignment.center,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedLevel == level
                          ? Colors.blue
                          : Colors.grey[100]!,
                      alignment: Alignment.center,
                      padding: EdgeInsets.all(4),
                      minimumSize: Size(50, 40),
                    ),
                    onPressed: () async {
                    Navigator.of(context).pop();
                    setState(() {
                      _selectedLevel = level;
                      _cachedSongsWithStatus = null;
                    });
                    // 更新等级选项（确保当前选中的等级在选项列表中）
                    await _updateLevelOptions();
                    await _loadSongsWithStatus();
                  },
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Lv.$level',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _selectedLevel == level ? Colors.white : Colors.grey[700],
                        ),
                      ),
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

  // 构建歌曲列表区域
  Widget _buildSongListSection() {
    // 显示加载状态
    if (_isSongsLoading) {
      return Center(child: CircularProgressIndicator());
    }

    // 检查缓存数据
    if (_cachedSongsWithStatus == null || _cachedSongsWithStatus!.isEmpty) {
      return Center(
        child: Text(
          '当前等级没有匹配的歌曲',
          style: TextStyle(
            fontSize: _textSizeM,
            color: Colors.grey[500]!,
          ),
        ),
      );
    }

    final songsWithStatus = _cachedSongsWithStatus!;

    // 按定数每0.1进行分组（精确到0.1）
    Map<String, List<Map<String, dynamic>>> groupedSongs = {};
    for (final item in songsWithStatus) {
      final song = item['song'] as Song;
      final diffIndex = item['difficulty'] as int;
      String dsKey = '未知';
      
      if (song.ds != null && song.ds.length > diffIndex) {
        dsKey = _getDsLevelDisplay(song.ds[diffIndex]);
      }
      
      if (!groupedSongs.containsKey(dsKey)) {
        groupedSongs[dsKey] = [];
      }
      groupedSongs[dsKey]!.add(item);
    }

    // 按定数降序排序
    final sortedDsKeys = groupedSongs.keys.toList()
      ..sort((a, b) {
        double parseDs(String ds) => double.tryParse(ds) ?? 0.0;
        return parseDs(b).compareTo(parseDs(a));
      });

    // 构建带定数分隔线的歌曲列表
    List<Widget> songWidgets = [];
    for (final dsKey in sortedDsKeys) {
      final dsSongs = groupedSongs[dsKey]!;

      // 添加定数分隔线（灰底黑框）
      songWidgets.add(
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[200]!,
            border: Border.all(color: Colors.black, width: 1),
            borderRadius: BorderRadius.circular(_borderRadiusSmall),
          ),
          padding: EdgeInsets.symmetric(vertical: _paddingXS, horizontal: _paddingM),
          margin: EdgeInsets.only(bottom: _paddingXS),
          child: Text(
            '${dsKey} | 共 ${dsSongs.length} 首歌曲',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: _textSizeM,
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );

      // 添加该定数的歌曲卡片
      songWidgets.add(
        Container(
          margin: EdgeInsets.only(bottom: _paddingXS),
          child: GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: _paddingXS,
              mainAxisSpacing: _paddingXS,
              childAspectRatio: 2.0,
            ),
            itemCount: dsSongs.length,
            itemBuilder: (context, index) {
              final item = dsSongs[index];
              final song = item['song'] as Song;
              final isCompleted = item['completed'] as bool;

              final songId = song.id;
              final songTitle = song.title;
              final songType = song.type;
              
              // 获取歌曲定数显示和初始难度索引
              final diffIndex = item['difficulty'] as int;
              String songDs = '';
              int initialLevelIndex = diffIndex;
              
              if (song.ds != null && song.ds.length > diffIndex) {
                songDs = song.ds[diffIndex].toStringAsFixed(1);
              }

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SongInfoPage(
                        songId: songId,
                        initialLevelIndex: initialLevelIndex,
                      ),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isCompleted ? Colors.lightGreen[100]! : Colors.grey[100]!,
                    borderRadius: BorderRadius.circular(_borderRadiusSmall),
                    border: Border.all(
                      color: isCompleted ? Colors.green : Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                  padding: EdgeInsets.all(_paddingXS),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 曲绘
                      Container(
                        width: _coverSize,
                        height: _coverSize,
                        child: CoverUtil.buildCoverWidgetWithContext(
                          context,
                          songId,
                          _coverSize,
                        ),
                      ),
                      SizedBox(width: _paddingS),
                      // 信息
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              songTitle,
                              style: TextStyle(
                                fontSize: _textSizeS,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 2),
                            Text(
                              '${StringUtil.formatSongType(songType)} / ${songDs.isNotEmpty ? songDs : '-'}',
                              style: TextStyle(
                                fontSize: _textSizeXS,
                                color: Colors.grey[600]!,
                              ),
                            ),
                            SizedBox(height: 2),
                            // 完成状态
                            Row(
                              children: [
                                Icon(
                                  isCompleted ? Icons.check_circle : Icons.circle_outlined,
                                  color: _getCompletionColor(isCompleted),
                                  size: _textSizeM,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  isCompleted ? '已完成' : '未完成',
                                  style: TextStyle(
                                    fontSize: _textSizeXS,
                                    color: _getCompletionColor(isCompleted),
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
              );
            },
          ),
        ),
      );
    }

    // 计算完成统计
    final totalCount = songsWithStatus.length;
    final completedCount = songsWithStatus.where((item) => item['completed'] as bool).length;
    final completionRate = totalCount > 0 ? (completedCount / totalCount * 100) : 0;

    // 计算平均达成率
    double totalAchievement = 0.0;
    for (final item in songsWithStatus) {
      final song = item['song'] as Song;
      final diff = item['difficulty'] as int;
      if (diff == -1) {
        // ALL模式下取所有符合条件难度的平均达成率
        double songTotalAchievement = 0.0;
        int count = 0;
        for (int i = 0; i < song.ds.length; i++) {
          if (_getLevelDisplay(song.ds[i]) == _selectedLevel) {
            songTotalAchievement += _service.getSongAchievement(int.parse(song.id), i);
            count++;
          }
        }
        if (count > 0) {
          totalAchievement += songTotalAchievement / count;
        }
      } else {
        totalAchievement += _service.getSongAchievement(int.parse(song.id), diff);
      }
    }
    final averageAchievement = totalCount > 0 ? totalAchievement / totalCount : 0.0;

    // 获取难度显示名称
    final difficultyName = _selectedDifficulty == -1 ? 'ALL' : _getDifficultyName(_selectedDifficulty!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 统计区域（表格形式）
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 1.0),
            borderRadius: BorderRadius.circular(_borderRadiusSmall),
          ),
          padding: EdgeInsets.all(_paddingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Text(
                'Lv.${_selectedLevel}(${difficultyName})的${_selectedTitleType}称号统计',
                style: TextStyle(
                  fontSize: _textSizeL,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: _paddingS),
              // 表格行
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '总歌曲数',
                          style: TextStyle(
                            fontSize: _textSizeM,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          '$totalCount',
                          style: TextStyle(
                            fontSize: _textSizeL,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '已完成',
                          style: TextStyle(
                            fontSize: _textSizeM,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          '$completedCount',
                          style: TextStyle(
                            fontSize: _textSizeL,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '完成率',
                          style: TextStyle(
                            fontSize: _textSizeM,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          '${completionRate.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: _textSizeL,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '平均达成率',
                          style: TextStyle(
                            fontSize: _textSizeM,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          '${averageAchievement.toStringAsFixed(2)}%',
                          style: TextStyle(
                            fontSize: _textSizeL,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: _paddingS),

        // 切换显示模式按钮
        Container(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[200]!,
              foregroundColor: Colors.black,
              minimumSize: Size(120 * _scaleFactor, 36 * _scaleFactor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_borderRadiusSmall),
              ),
            ),
            onPressed: () {
              setState(() {
                _showListMode = !_showListMode;
              });
            },
            child: Text(
              '当前:${_showListMode ? '列表' : '曲绘'}',
              style: TextStyle(fontSize: _textSizeS),
            ),
          ),
        ),
        SizedBox(height: _paddingS),

        // 歌曲展示区域
        _showListMode ?
          // 带定数分隔线的歌曲列表
          Column(children: songWidgets) :
          // 仅曲绘模式
          _buildCoverOnlyView(songsWithStatus),
      ],
    );
  }

  // 构建仅曲绘视图
  Widget _buildCoverOnlyView(List<Map<String, dynamic>> songsWithStatus) {
    // 按定数每0.1进行分组
    Map<String, List<Map<String, dynamic>>> groupedSongs = {};
    for (final item in songsWithStatus) {
      final song = item['song'] as Song;
      final diffIndex = item['difficulty'] as int;
      String dsKey = '未知';
      
      if (song.ds != null && song.ds.length > diffIndex) {
        dsKey = _getDsLevelDisplay(song.ds[diffIndex]);
      }
      
      if (!groupedSongs.containsKey(dsKey)) {
        groupedSongs[dsKey] = [];
      }
      groupedSongs[dsKey]!.add(item);
    }

    // 按定数降序排序
    final sortedDsKeys = groupedSongs.keys.toList()
      ..sort((a, b) {
        double parseDs(String ds) => double.tryParse(ds) ?? 0.0;
        return parseDs(b).compareTo(parseDs(a));
      });

    // 构建视图
    List<Widget> widgets = [];
    for (final dsKey in sortedDsKeys) {
      final dsSongs = groupedSongs[dsKey]!;

      // 添加定数分隔线（灰底黑框）
      widgets.add(
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[200]!,
            border: Border.all(color: Colors.black, width: 1),
            borderRadius: BorderRadius.circular(_borderRadiusSmall),
          ),
          padding: EdgeInsets.symmetric(vertical: _paddingXS, horizontal: _paddingM),
          margin: EdgeInsets.only(bottom: _paddingXS),
          child: Text(
            '${dsKey} | 共 ${dsSongs.length} 首歌曲',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: _textSizeM,
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );

      // 添加曲绘网格
      widgets.add(
        Container(
          margin: EdgeInsets.only(bottom: _paddingXS),
          child: GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: _paddingXS,
              mainAxisSpacing: _paddingXS,
              childAspectRatio: 1.0,
            ),
            itemCount: dsSongs.length,
            itemBuilder: (context, index) {
              final item = dsSongs[index];
              final song = item['song'] as Song;
              final isCompleted = item['completed'] as bool;

              final songId = song.id;
              
              // 使用条目自己的难度索引
              final initialLevelIndex = item['difficulty'] as int;

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SongInfoPage(
                        songId: songId,
                        initialLevelIndex: initialLevelIndex,
                      ),
                    ),
                  );
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 曲绘（不带边框）
                    CoverUtil.buildCoverWidgetWithContextRRect(
                      context,
                      songId,
                      _coverSize,
                    ),
                    // 完成状态对钩（居中显示）
                    if (isCompleted)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(8.0 * _scaleFactor),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: _coverSize * 0.4,
                          ),
                        ),
                      ),
                    // 难度边框（放在最顶层，不被完成状态覆盖）
                    Container(
                      width: _coverSize,
                      height: _coverSize,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: ColorUtil.getCoverBorderColor(initialLevelIndex),
                          width: 2.0 * _scaleFactor,
                        ),
                        borderRadius: BorderRadius.circular(8.0 * _scaleFactor),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    }

    return Column(children: widgets);
  }
}