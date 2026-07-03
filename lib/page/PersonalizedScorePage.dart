import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:my_first_flutter_app/service/PersonalizedScoreService.dart';
import 'package:my_first_flutter_app/service/PersonalizedScoreConvertToImgService.dart';
import 'package:my_first_flutter_app/constant/LoadingTipsConstant.dart';
import 'package:my_first_flutter_app/entity/DivingFish/Song.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:my_first_flutter_app/utils/CoverUtil.dart';
import 'package:my_first_flutter_app/utils/StringUtil.dart';
import 'package:my_first_flutter_app/utils/ColorUtil.dart';
import 'package:my_first_flutter_app/page/SongInfoPage.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:my_first_flutter_app/utils/AppConstants.dart';

class PersonalizedScorePage extends StatefulWidget {
  const PersonalizedScorePage({super.key});

  @override
  State<PersonalizedScorePage> createState() => _PersonalizedScorePageState();
}

class _PersonalizedScorePageState extends State<PersonalizedScorePage> {
  final PersonalizedScoreService _service = PersonalizedScoreService();

  // 选择状态
  List<String> _levelOptions = [];
  List<String> _titleTypeOptions = [];
  List<int> _difficultyOptions = [];

  // 缓存的全量等级选项（用于对话框）
  List<String> _allLevelOptionsCache = [];

  // 种类模式：'level' 等级模式, 'charter' 谱师模式
  String _mode = 'level';
  
  // 谱师相关
  Map<String, int>? _charterCounts;
  String? _selectedCharter;

  String? _selectedLevel;
  String? _selectedTitleType;
  int? _selectedDifficulty;

  bool _isLoading = true;

  // 缓存的歌曲完成状态数据
  List<Map<String, dynamic>>? _cachedSongsWithStatus;
  bool _isSongsLoading = false;

  // 显示模式：true 为列表模式，false 为仅曲绘模式
  bool _showListMode = true;

  // 过滤模式：'all' 全部, 'completed' 已完成, 'uncompleted' 未完成
  String _filterMode = 'all';

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

      // 获取谱师列表
      _charterCounts = await _service.getCharterCounts();

      // 更新等级选项
      await _updateLevelOptions();
      // 设置保存的等级选项
      if (_levelOptions.isNotEmpty) {
        final savedLevel = savedOptions['level'] as String;
        _selectedLevel = _levelOptions.contains(savedLevel) && savedLevel.isNotEmpty
            ? savedLevel
            : _levelOptions[0];
      }

      // 设置保存的模式
      final savedMode = savedOptions['mode'] as String;
      _mode = ['level', 'charter'].contains(savedMode) ? savedMode : 'level';

      // 设置保存的谱师（如果谱师存在）
      final savedCharter = savedOptions['charter'] as String;
      if (savedCharter.isNotEmpty && _charterCounts != null && _charterCounts!.containsKey(savedCharter)) {
        _selectedCharter = savedCharter;
      } else if (_charterCounts != null && _charterCounts!.isNotEmpty) {
        _selectedCharter = _charterCounts!.keys.first;
      }

      // 设置保存的显示模式
      _showListMode = savedOptions['showListMode'] as bool;

      // 加载歌曲完成状态数据
      await _loadSongsWithStatus();
    } catch (e) {
      debugPrint('初始化数据时出错: $e');
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
      mode: _mode,
      charter: _selectedCharter,
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
    if (_selectedTitleType == null || _selectedDifficulty == null) {
      return;
    }

    setState(() {
      _isSongsLoading = true;
    });

    try {
      List<Map<String, dynamic>> result;
      
      if (_mode == 'level') {
        // 等级模式
        if (_selectedLevel == null) return;
        result = await _service.getSongsByLevel(
          _selectedLevel!,
          _selectedTitleType!,
          _selectedDifficulty!,
        );
      } else {
        // 谱师模式
        if (_selectedCharter == null) return;
        result = await _service.getSongsByCharter(
          _selectedCharter!,
          _selectedTitleType!,
          _selectedDifficulty!,
        );
      }
      
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
    final brightness = Theme.of(context).brightness;
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
                      icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    // 标题
                    Expanded(
                      child: Center(
                        child: Text(
                          '个性化成绩查询',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: screenWidth * 0.06,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // 占位（保持标题居中）
                    SizedBox(width: 48),
                  ],
                ),
              ),

              // 主内容区域
              Expanded(
                child: Container(
                  margin: EdgeInsets.fromLTRB(_paddingS, 0, _paddingS, _paddingL),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(_borderRadiusSmall),
                    boxShadow: [
                      AppConstants.defaultShadow(brightness),
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

                              // 导出为图片按钮
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.linkBlue(brightness),
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: _paddingS),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(_borderRadiusSmall),
                                    ),
                                  ),
                                  icon: Icon(Icons.image, size: _textSizeL + 4),
                                  label: Text(
                                    '导出为图片',
                                    style: TextStyle(fontSize: _textSizeM, fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: () async {
                                    debugPrint('=== PERSONALIZED SCORE EXPORT BUTTON CLICKED ===');
                                    try {
                                      await _exportToImage();
                                    } catch (e) {
                                      debugPrint('Error in export: $e');
                                    }
                                  },
                                ),
                              ),

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
        // 选择种类
        Text(
          '选择种类',
          style: TextStyle(
            fontSize: _textSizeM,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: _paddingXS),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.surface,
            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
            minimumSize: Size(double.infinity, 40 * _scaleFactor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_borderRadiusSmall),
            ),
          ),
          onPressed: () => _showModeDialog(),
          child: Text(
            _mode == 'level' ? '等级' : '谱师',
            style: TextStyle(fontSize: _textSizeM),
          ),
        ),

        SizedBox(height: _paddingM),

        // 选择等级/谱师
        Text(
          _mode == 'level' ? '选择等级' : '选择谱师',
          style: TextStyle(
            fontSize: _textSizeM,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: _paddingXS),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.surface,
            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
            minimumSize: Size(double.infinity, 40 * _scaleFactor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_borderRadiusSmall),
            ),
          ),
          onPressed: () => _mode == 'level' ? _showLevelDialog() : _showCharterDialog(),
          child: Text(
            _mode == 'level' 
                ? (_selectedLevel != null ? 'Lv.${_selectedLevel}' : '请选择等级')
                : (_selectedCharter != null ? _selectedCharter! : '请选择谱师'),
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
            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                    ? AppColors.linkBlue(Theme.of(context).brightness)
                    : Theme.of(context).colorScheme.surface,
                foregroundColor: _selectedTitleType == type
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurfaceVariant,
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
            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                    : Theme.of(context).colorScheme.surface,
                foregroundColor: _selectedDifficulty == diff
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurfaceVariant,
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

  // 显示模式选择对话框
  void _showModeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Center(child: Text('选择种类')),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Center(child: Text('等级')),
                  selected: _mode == 'level',
                  onTap: () async {
                    Navigator.of(context).pop();
                    setState(() {
                      _mode = 'level';
                      _cachedSongsWithStatus = null;
                    });
                    await _loadSongsWithStatus();
                  },
                ),
                ListTile(
                  title: Center(child: Text('谱师')),
                  selected: _mode == 'charter',
                  onTap: () async {
                    Navigator.of(context).pop();
                    setState(() {
                      _mode = 'charter';
                      _cachedSongsWithStatus = null;
                    });
                    // 如果没有选中的谱师，设置默认谱师
                    if (_selectedCharter == null && _charterCounts != null && _charterCounts!.isNotEmpty) {
                      setState(() {
                        _selectedCharter = _charterCounts!.keys.first;
                      });
                    }
                    await _loadSongsWithStatus();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 显示谱师选择对话框
  void _showCharterDialog() {
    if (_charterCounts == null || _charterCounts!.isEmpty) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('提示'),
            content: Text('没有找到谱师数据'),
            actions: [
              TextButton(
                child: Text('确定'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
      return;
    }

    // 按出现次数排序
    List<MapEntry<String, int>> sortedCharters = _charterCounts!.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('选择谱师'),
          content: SingleChildScrollView(
            child: ListBody(
              children: sortedCharters.map((entry) {
                return ListTile(
                  title: Text('${entry.key} (${entry.value}谱面)'),
                  selected: _selectedCharter == entry.key,
                  onTap: () async {
                    Navigator.of(context).pop();
                    setState(() {
                      _selectedCharter = entry.key;
                      _cachedSongsWithStatus = null;
                    });
                    await _loadSongsWithStatus();
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              child: Text('取消'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
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
                          ? AppColors.linkBlue(Theme.of(context).brightness)
                          : Theme.of(context).colorScheme.surface,
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
                          color: _selectedLevel == level ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
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
          _mode == 'level' ? '当前等级没有匹配的歌曲' : '当前谱师没有匹配的歌曲',
          style: TextStyle(
            fontSize: _textSizeM,
            color: AppColors.greyHint(Theme.of(context).brightness),
          ),
        ),
      );
    }

    final songsWithStatus = _cachedSongsWithStatus!;

    // 根据过滤模式过滤歌曲
    List<Map<String, dynamic>> filteredSongs = songsWithStatus;
    if (_filterMode == 'completed') {
      filteredSongs = songsWithStatus.where((item) => item['completed'] as bool).toList();
    } else if (_filterMode == 'uncompleted') {
      filteredSongs = songsWithStatus.where((item) => !(item['completed'] as bool)).toList();
    }

    // 检查过滤后是否有数据（保留过滤后的列表用于后续使用，但不提前返回）

    // 按定数每0.1进行分组（精确到0.1）
    Map<String, List<Map<String, dynamic>>> groupedSongs = {};
    for (final item in filteredSongs) {
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
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(color: AppColors.tableBorder(Theme.of(context).brightness), width: 1),
            borderRadius: BorderRadius.circular(_borderRadiusSmall),
          ),
          padding: EdgeInsets.symmetric(vertical: _paddingXS, horizontal: _paddingM),
          margin: EdgeInsets.only(bottom: _paddingXS),
          child: Text(
            '${dsKey} | 共 ${dsSongs.length} 首歌曲',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: _textSizeM,
              color: Theme.of(context).colorScheme.onSurface,
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
                    color: isCompleted ? Colors.lightGreen[100]! : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(_borderRadiusSmall),
                    border: Border.all(
                      color: isCompleted ? Colors.green : AppColors.tableBorder(Theme.of(context).brightness),
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
                                color: isCompleted ? Colors.black87 : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 2),
                            Text(
                              '${StringUtil.formatSongType(songType)} / ${songDs.isNotEmpty ? songDs : '-'}',
                              style: TextStyle(
                                fontSize: _textSizeXS,
                                color: isCompleted ? Colors.black54 : Theme.of(context).colorScheme.onSurfaceVariant,
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

    // 根据模式获取标题
    String title;
    if (_mode == 'level') {
      title = 'Lv.${_selectedLevel}(${difficultyName})的${_selectedTitleType}称号统计';
    } else {
      title = '谱师${_selectedCharter}(${difficultyName})的${_selectedTitleType}称号统计';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 统计区域（表格形式）
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.tableBorder(Theme.of(context).brightness), width: 1.0),
            borderRadius: BorderRadius.circular(_borderRadiusSmall),
          ),
          padding: EdgeInsets.all(_paddingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Text(
                title,
                style: TextStyle(
                  fontSize: _textSizeL,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
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
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          '$totalCount',
                          style: TextStyle(
                            fontSize: _textSizeL,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
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
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          '$completedCount',
                          style: TextStyle(
                            fontSize: _textSizeL,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
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
                          '未完成',
                          style: TextStyle(
                            fontSize: _textSizeM,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          '${totalCount - completedCount}',
                          style: TextStyle(
                            fontSize: _textSizeL,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
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
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          '${completionRate.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: _textSizeL,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
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
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          '${averageAchievement.toStringAsFixed(2)}%',
                          style: TextStyle(
                            fontSize: _textSizeL,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
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

        // 切换显示模式按钮区域
        Container(
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // 过滤按钮
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  minimumSize: Size(100 * _scaleFactor, 36 * _scaleFactor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_borderRadiusSmall),
                  ),
                ),
                onPressed: () {
                  setState(() {
                    // 循环切换：全部 -> 已完成 -> 未完成 -> 全部
                    if (_filterMode == 'all') {
                      _filterMode = 'completed';
                    } else if (_filterMode == 'completed') {
                      _filterMode = 'uncompleted';
                    } else {
                      _filterMode = 'all';
                    }
                  });
                },
                child: Text(
                  '当前: ${_filterMode == 'all' ? '全部' : _filterMode == 'completed' ? '已完成' : '未完成'}',
                  style: TextStyle(fontSize: _textSizeS),
                ),
              ),
              SizedBox(width: _paddingS),
              // 曲绘/列表切换按钮
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  minimumSize: Size(100 * _scaleFactor, 36 * _scaleFactor),
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
                  '当前: ${_showListMode ? '列表' : '曲绘'}',
                  style: TextStyle(fontSize: _textSizeS),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: _paddingS),

        // 歌曲展示区域
        filteredSongs.isEmpty ?
          // 过滤后无数据时显示提示
          Center(
            child: Text(
              _filterMode == 'completed' ? '暂无已完成歌曲' : _filterMode == 'uncompleted' ? '暂无未完成歌曲' : (_mode == 'level' ? '当前等级没有匹配的歌曲' : '当前谱师没有匹配的歌曲'),
              style: TextStyle(
                fontSize: _textSizeM,
                color: AppColors.greyHint(Theme.of(context).brightness),
              ),
            ),
          ) :
          _showListMode ?
            // 带定数分隔线的歌曲列表
            Column(children: songWidgets) :
            // 仅曲绘模式
            _buildCoverOnlyView(filteredSongs),
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
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(color: AppColors.tableBorder(Theme.of(context).brightness), width: 1),
            borderRadius: BorderRadius.circular(_borderRadiusSmall),
          ),
          padding: EdgeInsets.symmetric(vertical: _paddingXS, horizontal: _paddingM),
          margin: EdgeInsets.only(bottom: _paddingXS),
          child: Text(
            '${dsKey} | 共 ${dsSongs.length} 首歌曲',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: _textSizeM,
              color: Theme.of(context).colorScheme.onSurface,
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

  // 请求存储权限
  Future<bool> _requestStoragePermission() async {
    debugPrint('PersonalizedScorePage: _requestStoragePermission called');
    
    if (Platform.isAndroid) {
      debugPrint('PersonalizedScorePage: Running on Android');
      
      PermissionStatus storageStatus = await Permission.storage.status;
      PermissionStatus photosStatus = await Permission.photos.status;
      PermissionStatus videosStatus = await Permission.videos.status;
      
      debugPrint('PersonalizedScorePage: Storage status = $storageStatus');
      debugPrint('PersonalizedScorePage: Photos status = $photosStatus');
      debugPrint('PersonalizedScorePage: Videos status = $videosStatus');
      
      if (storageStatus.isGranted || photosStatus.isGranted || videosStatus.isGranted) {
        debugPrint('PersonalizedScorePage: At least one permission already granted');
        return true;
      }
      
      debugPrint('PersonalizedScorePage: Requesting storage, photos and videos permissions...');
      Map<Permission, PermissionStatus> statuses = await [
        Permission.storage,
        Permission.photos,
        Permission.videos,
      ].request();
      
      bool storageGranted = statuses[Permission.storage]?.isGranted ?? false;
      bool photosGranted = statuses[Permission.photos]?.isGranted ?? false;
      bool videosGranted = statuses[Permission.videos]?.isGranted ?? false;
      
      debugPrint('PersonalizedScorePage: Storage granted = $storageGranted');
      debugPrint('PersonalizedScorePage: Photos granted = $photosGranted');
      debugPrint('PersonalizedScorePage: Videos granted = $videosGranted');
      
      return storageGranted || photosGranted || videosGranted;
    } else {
      debugPrint('PersonalizedScorePage: Non-Android platform');
      PermissionStatus status = await Permission.storage.request();
      return status.isGranted;
    }
  }

  Future<void> _exportToImage() async {
    StreamSubscription<String>? _tipSubscription;
    try {
      debugPrint('=== PERSONALIZED SCORE EXPORT TO IMAGE STARTED ===');
      debugPrint('Current context: $context');

      debugPrint('Step 1: Requesting storage permission from page...');
      bool hasPermission = await _requestStoragePermission();
      debugPrint('Step 1 completed: hasPermission = $hasPermission');

      if (!hasPermission) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('权限不足'),
            content: Text('需要存储权限才能导出图片到相册，请在设置中开启权限'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('确定'),
              ),
            ],
          ),
        );
        return;
      }

      String _progressMessage = '正在准备导出...';
      double _progressValue = 0.0;
      String _currentLoadingTip = LoadingTipsConstant.getRandomLoadingTip();
      bool _isFirstBuild = true;
      void Function(void Function())? _updateDialog;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              _updateDialog = setDialogState;
              if (_isFirstBuild) {
                _isFirstBuild = false;
                LoadingTipsConstant.startAutoSwitch(3);
                _tipSubscription = LoadingTipsConstant.tipStream.listen((tip) {
                  try {
                    _updateDialog?.call(() {
                      _currentLoadingTip = tip;
                    });
                  } catch (_) {}
                });
              }
              return AlertDialog(
                title: Text('导出中'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Text(_progressMessage),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.0),
                    LinearProgressIndicator(value: _progressValue > 0 ? _progressValue : null),
                    SizedBox(height: 12.0),
                    Text(
                      _currentLoadingTip,
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          );
        },
      );

      final file = await PersonalizedScoreConvertToImg.convertToImage(
        context,
        selectedLevel: _selectedLevel,
        selectedCharter: _selectedCharter,
        mode: _mode,
        selectedTitleType: _selectedTitleType,
        selectedDifficulty: _selectedDifficulty,
        cachedSongsWithStatus: _cachedSongsWithStatus,
        filterMode: _filterMode,
        getDifficultyName: _getDifficultyName,
        getLevelDisplay: _getLevelDisplay,
        getSongAchievement: _service.getSongAchievement,
        onProgress: (message, progress) {
          _progressMessage = message;
          _progressValue = progress;
          _updateDialog?.call(() {});
        },
      );

      _tipSubscription?.cancel();
      LoadingTipsConstant.stopAutoSwitch();
      Navigator.of(context, rootNavigator: true).pop();

      if (file != null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('导出成功'),
            content: Text('图片已保存到：\n${file.path}'),
            actions: [
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: file.path));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('路径已复制到剪贴板')),
                  );
                },
                child: Text('复制路径'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                child: Text('确定'),
              ),
            ],
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('导出失败'),
            content: Text('图片导出失败，请重试'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                child: Text('确定'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _tipSubscription?.cancel();
      LoadingTipsConstant.stopAutoSwitch();
      try {
        Navigator.of(context, rootNavigator: true).pop();
      } catch (_) {}
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('导出失败'),
          content: Text('图片导出失败：${e.toString()}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
              child: Text('确定'),
            ),
          ],
        ),
      );
    }
  }
}