import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/service/PaiziProgressService.dart';
import 'package:my_first_flutter_app/entity/Collection.dart';
import 'package:my_first_flutter_app/entity/Song.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:my_first_flutter_app/utils/CoverUtil.dart';
import 'package:my_first_flutter_app/utils/CollectionsImageUtil.dart';
import 'package:my_first_flutter_app/utils/StringUtil.dart';
import 'package:my_first_flutter_app/utils/ColorUtil.dart';
import 'package:my_first_flutter_app/page/SongInfoPage.dart';
import 'package:my_first_flutter_app/page/CollectionInfoPage.dart';

// 根据 formatVersion2 的顺序定义首字顺序
const List<String> _firstCharOrder = [
  '真',
  '超',
  '檄',
  '橙',
  '暁',
  '桃',
  '櫻',
  '紫',
  '菫',
  '白',
  '雪',
  '輝',
  '熊',
  '華',
  '爽',
  '煌',
  '宙',
  '星',
  '祭',
  '祝',
  '双',
  '宴',
  '镜',
  '彩',
];

class PaiziProgressPage extends StatefulWidget {
  const PaiziProgressPage({super.key});

  @override
  State<PaiziProgressPage> createState() => _PaiziProgressPageState();
}

class _PaiziProgressPageState extends State<PaiziProgressPage> {
  final PaiziProgressService _service = PaiziProgressService();
  
  // 选择状态
  List<String> _firstCharOptions = [];
  List<String> _titleTypeOptions = [];
  List<int> _difficultyOptions = [];
  
  String? _selectedFirstChar;
  String? _selectedTitleType;
  int? _selectedDifficulty;
  
  Collection? _currentPlate;
  bool _isLoading = true;
  
  // 缓存的歌曲完成状态数据
  List<Map<String, dynamic>>? _cachedSongsWithStatus;
  bool _isSongsLoading = false;

  // 显示模式：true 为列表模式，false 为仅曲绘模式
  bool _showListMode = true;

  // 分割线显示模式：true 使用 _getLevelDisplay（如 15, 14+），false 直接显示定数（如 15.0, 14.5）
  bool _useLevelDisplay = true;

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
      _firstCharOptions = await _service.getFirstCharOptions();

      // 获取保存的用户选项
      final savedOptions = await _service.getSavedOptions();
      
      // 设置保存的选项，如果有效则使用，否则使用默认值
      if (_firstCharOptions.isNotEmpty) {
        final savedFirstChar = savedOptions['firstChar'] as String;
        _selectedFirstChar = _firstCharOptions.contains(savedFirstChar) && savedFirstChar.isNotEmpty
            ? savedFirstChar
            : (_firstCharOptions.contains('真') ? '真' : _firstCharOptions[0]);
      }
      if (_titleTypeOptions.isNotEmpty) {
        final savedTitleType = savedOptions['titleType'] as String;
        _selectedTitleType = _titleTypeOptions.contains(savedTitleType) && savedTitleType.isNotEmpty
            ? savedTitleType
            : _titleTypeOptions[0];
      }

      // 更新难度选项
      await _updateDifficultyOptions();
      
      // 设置保存的难度选项
      final savedDifficulty = savedOptions['difficulty'] as int;
      if (_difficultyOptions.contains(savedDifficulty)) {
        _selectedDifficulty = savedDifficulty;
      }

      // 设置保存的显示模式
      _showListMode = savedOptions['showListMode'] as bool;
      _useLevelDisplay = savedOptions['useLevelDisplay'] as bool;

      await _loadCurrentPlate();
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
      firstChar: _selectedFirstChar,
      titleType: _selectedTitleType,
      difficulty: _selectedDifficulty,
      showListMode: _showListMode,
      useLevelDisplay: _useLevelDisplay,
    );
    super.dispose();
  }

  // 更新难度选项
  Future<void> _updateDifficultyOptions() async {
    if (_selectedFirstChar != null && _selectedTitleType != null) {
      final newDifficultyOptions = await _service.getAvailableDifficulties(
        _selectedFirstChar!,
        _selectedTitleType!,
      );
      
      // 保存当前选中的难度
      final currentDifficulty = _selectedDifficulty;
      
      _difficultyOptions = newDifficultyOptions;
      
      // 如果当前选中的难度仍然在新列表中，则保持选中；否则选择第一个
      if (_difficultyOptions.isNotEmpty) {
        if (currentDifficulty != null && _difficultyOptions.contains(currentDifficulty)) {
          _selectedDifficulty = currentDifficulty;
        } else {
          _selectedDifficulty = _difficultyOptions[0];
        }
      }
    }
  }

  // 加载当前选中的收藏品
  Future<void> _loadCurrentPlate() async {
    if (_selectedFirstChar != null && _selectedTitleType != null) {
      final plate = await _service.getPlateBySelection(
        _selectedFirstChar!,
        _selectedTitleType!,
      );
      setState(() {
        _currentPlate = plate;
      });
    }
  }

  // 加载歌曲完成状态（带缓存）
  Future<void> _loadSongsWithStatus() async {
    if (_selectedFirstChar == null || _selectedTitleType == null || _selectedDifficulty == null) {
      return;
    }

    setState(() {
      _isSongsLoading = true;
    });

    try {
      final result = await _service.getSongsWithCompletionStatus(
        _selectedFirstChar!,
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

  // 根据定数计算等级显示
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

  // 获取难度颜色
  Color _getDifficultyColor(int difficulty) {
    if (difficulty == -1) return Colors.black;
    switch (difficulty) {
      case 0: return Colors.green;
      case 1: return Color(0xFFFFCC00); // ADVANCED - 深黄色
      case 2: return Colors.pink;
      case 3: return Colors.purple;
      case 4: return Colors.purple.shade200; // RE:MASTER - 紫色浅色调
      default: return Colors.grey;
    }
  }

  // 获取完成状态颜色
  Color _getCompletionColor(bool completed) {
    return completed ? Colors.green : Colors.grey;
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
                          '牌子进度',
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
        // 第一个选择：第一个字（点击弹出对话框）
        Text(
          '选择首字',
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
          onPressed: () => _showFirstCharDialog(),
          child: Text(
            _selectedFirstChar ?? '请选择首字',
            style: TextStyle(fontSize: _textSizeM),
          ),
        ),

        SizedBox(height: _paddingM),

        // 第二个选择：称号类型
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
                  _cachedSongsWithStatus = null; // 清空缓存
                });
                await _updateDifficultyOptions();
                await _loadCurrentPlate();
                await _loadSongsWithStatus(); // 加载新数据
              },
              child: Text(
                type,
                style: TextStyle(fontSize: _textSizeM),
              ),
            );
          }).toList(),
        ),

        SizedBox(height: _paddingM),

        // 第三个选择：难度
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
                  _cachedSongsWithStatus = null; // 清空缓存
                });
                await _loadSongsWithStatus(); // 加载新数据
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

  // 获取按顺序排列的首字选项
  List<String> _getOrderedFirstCharOptions() {
    // 按照 formatVersion2 的顺序排列
    final ordered = <String>[];
    for (final char in _firstCharOrder) {
      if (_firstCharOptions.contains(char)) {
        ordered.add(char);
      }
    }
    // 添加不在顺序列表中的其他首字
    for (final char in _firstCharOptions) {
      if (!ordered.contains(char)) {
        ordered.add(char);
      }
    }
    return ordered;
  }

  // 显示首字选择对话框
  void _showFirstCharDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Center(child: Text('选择首字')),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          content: Container(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 8,
                childAspectRatio: 2.0,
              ),
              itemCount: _getOrderedFirstCharOptions().length,
              itemBuilder: (context, index) {
                final char = _getOrderedFirstCharOptions()[index];
                return Container(
                  alignment: Alignment.center,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedFirstChar == char
                          ? Colors.blue
                          : Colors.grey[100]!,
                      alignment: Alignment.center,
                      padding: EdgeInsets.all(4),
                      minimumSize: Size(50, 50),
                    ),
                    onPressed: () async {
                      Navigator.of(context).pop();
                      setState(() {
                        _selectedFirstChar = char;
                        _cachedSongsWithStatus = null; // 清空缓存
                      });
                      await _updateDifficultyOptions();
                      await _loadCurrentPlate();
                      await _loadSongsWithStatus(); // 加载新数据
                    },
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        char,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _selectedFirstChar == char ? Colors.white : Colors.grey[700],
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
    if (_currentPlate == null || _currentPlate!.required == null || _currentPlate!.required!.isEmpty) {
      return Center(
        child: Text(
          '暂无数据',
          style: TextStyle(
            fontSize: _textSizeM,
            color: Colors.grey[500]!,
          ),
        ),
      );
    }

    // 显示加载状态
    if (_isSongsLoading) {
      return Center(child: CircularProgressIndicator());
    }

    // 检查缓存数据
    if (_cachedSongsWithStatus == null || _cachedSongsWithStatus!.isEmpty) {
      return Center(
        child: Text(
          '当前难度没有匹配的歌曲',
          style: TextStyle(
            fontSize: _textSizeM,
            color: Colors.grey[500]!,
          ),
        ),
      );
    }

    final songsWithStatus = _cachedSongsWithStatus!;

        // 按等级/定数分组歌曲
            Map<String, List<Map<String, dynamic>>> groupedSongs = {};
            for (final item in songsWithStatus) {
              final dynamic song = item['song'];
              final diffIndex = item['difficulty'] as int;
              String levelKey = '未知';
              if (song is Song) {
                if (song.ds != null && song.ds.length > diffIndex) {
                  final ds = song.ds[diffIndex];
                  // 根据显示模式选择分组方式
                  levelKey = _useLevelDisplay ? _getLevelDisplay(ds) : ds.toStringAsFixed(1);
                }
              }
              if (!groupedSongs.containsKey(levelKey)) {
                groupedSongs[levelKey] = [];
              }
              groupedSongs[levelKey]!.add(item);
            }

            // 按等级/定数降序排序
            final sortedLevelKeys = groupedSongs.keys.toList()
              ..sort((a, b) {
                double parseLevel(String level) {
                  if (_useLevelDisplay) {
                    // Level 格式：15, 14+, 14 等
                    if (level == '15') return 15.0;
                    if (level.endsWith('+')) {
                      return double.parse(level.substring(0, level.length - 1)) + 0.5;
                    }
                    return double.tryParse(level) ?? 0.0;
                  } else {
                    // 定数格式：15.0, 14.5 等
                    return double.tryParse(level) ?? 0.0;
                  }
                }
                return parseLevel(b).compareTo(parseLevel(a)); // 降序
              });

            // 构建带等级分隔线的歌曲列表
            List<Widget> songWidgets = [];
            for (final levelKey in sortedLevelKeys) {
              // 对每个定数内的歌曲按定数降序排序
              final levelSongs = groupedSongs[levelKey]!
                ..sort((a, b) {
                  double getDs(Map<String, dynamic> item) {
                    final dynamic song = item['song'];
                    final diffIndex = item['difficulty'] as int;
                    if (song is Song) {
                      if (song.ds != null && song.ds.length > diffIndex) {
                        return song.ds[diffIndex];
                      }
                    }
                    return 0.0;
                  }
                  return getDs(b).compareTo(getDs(a)); // 降序
                });
              
              // 添加等级/定数分隔线
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
                    '${_useLevelDisplay ? 'Lv.' : ''}${levelKey} | 共 ${levelSongs.length} 首歌曲',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: _textSizeM,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );

              // 添加该等级的歌曲卡片
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
                    itemCount: levelSongs.length,
                  itemBuilder: (context, index) {
                    final item = levelSongs[index];
                    final dynamic song = item['song'];
                    final isCompleted = item['completed'] as bool;

                    // 获取歌曲ID（支持 Song 和 CollectionRequiredSong）
                    String songId;
                    String songTitle;
                    String songType;
                    String songDs = '';
                    int initialLevelIndex = _selectedDifficulty ?? 3;
                    if (song is Song) {
                      songId = song.id;
                      songTitle = song.title;
                      songType = song.type;
                      // 获取当前难度对应的定数
                      final diffIndex = item['difficulty'] as int;
                      initialLevelIndex = diffIndex;
                      if (song.ds != null && song.ds.length > diffIndex) {
                        songDs = song.ds[diffIndex].toStringAsFixed(1);
                      }
                    } else if (song is CollectionRequiredSong) {
                      songId = song.id.toString();
                      songTitle = song.title;
                      songType = song.type;
                    } else {
                      songId = '';
                      songTitle = '未知';
                      songType = '';
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

            // 计算统计数据
            final totalCount = songsWithStatus.length;
            final completedCount = songsWithStatus.where((item) => item['completed'] as bool).length;
            final completionRate = totalCount > 0 ? (completedCount / totalCount * 100) : 0;
            
            // 计算平均达成率
            double totalAchievement = 0.0;
            for (final item in songsWithStatus) {
              final dynamic song = item['song'];
              final diff = item['difficulty'] as int;
              if (song is Song) {
                totalAchievement += _service.getSongAchievement(int.parse(song.id), diff);
              }
            }
            final averageAchievement = totalCount > 0 ? totalAchievement / totalCount : 0.0;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 收藏品图片（可点击跳转）
                Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CollectionInfoPage(
                            collectionId: _currentPlate!.id,
                            collectionType: 'plates',
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 280 * _scaleFactor,
                      height: 140 * _scaleFactor,
                      child: CollectionsImageUtil.getPlateImageURL(_currentPlate!),
                    ),
                  ),
                ),
                SizedBox(height: _paddingS), // 减少间距
                // 收藏品名称
                Center(
                  child: Text(
                    _currentPlate!.name,
                    style: TextStyle(
                      fontSize: _textSizeL,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700]!,
                    ),
                  ),
                ),
                SizedBox(height: _paddingS),

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
                        '${_currentPlate!.name}(${_getDifficultyName(_selectedDifficulty ?? 3)})统计',
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

                // 切换按钮区域
                Container(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // 分割线显示模式切换按钮
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[200]!,
                          foregroundColor: Colors.black,
                          minimumSize: Size(100 * _scaleFactor, 36 * _scaleFactor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(_borderRadiusSmall),
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _useLevelDisplay = !_useLevelDisplay;
                          });
                        },
                        child: Text(
                          _useLevelDisplay ? '等级显示' : '定数显示',
                          style: TextStyle(fontSize: _textSizeS),
                        ),
                      ),
                      SizedBox(width: _paddingS),
                      // 显示模式切换按钮
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[200]!,
                          foregroundColor: Colors.black,
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
                          _showListMode ? '列表' : '曲绘',
                          style: TextStyle(fontSize: _textSizeS),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: _paddingS),

                // 歌曲展示区域
                _showListMode ? 
                  // 带等级分隔线的歌曲列表
                  Column(children: songWidgets) :
                  // 仅曲绘模式
                  _buildCoverOnlyView(songsWithStatus),
              ],
            );
      }

  // 构建仅曲绘视图
  Widget _buildCoverOnlyView(List<Map<String, dynamic>> songsWithStatus) {
    // 按等级/定数分组歌曲
    Map<String, List<Map<String, dynamic>>> groupedSongs = {};
    for (final item in songsWithStatus) {
      final dynamic song = item['song'];
      final diffIndex = item['difficulty'] as int;
      String levelKey = '未知';
      if (song is Song) {
        if (song.ds != null && song.ds.length > diffIndex) {
          final ds = song.ds[diffIndex];
          // 根据显示模式选择分组方式
          levelKey = _useLevelDisplay ? _getLevelDisplay(ds) : ds.toStringAsFixed(1);
        }
      }
      if (!groupedSongs.containsKey(levelKey)) {
        groupedSongs[levelKey] = [];
      }
      groupedSongs[levelKey]!.add(item);
    }

    // 按等级/定数降序排序
    final sortedLevelKeys = groupedSongs.keys.toList()
      ..sort((a, b) {
        double parseLevel(String level) {
          if (_useLevelDisplay) {
            if (level == '15') return 15.0;
            if (level.endsWith('+')) {
              return double.parse(level.substring(0, level.length - 1)) + 0.5;
            }
            return double.tryParse(level) ?? 0.0;
          } else {
            return double.tryParse(level) ?? 0.0;
          }
        }
        return parseLevel(b).compareTo(parseLevel(a));
      });

    // 构建视图
    List<Widget> widgets = [];
    for (final levelKey in sortedLevelKeys) {
      final levelSongs = groupedSongs[levelKey]!
        ..sort((a, b) {
          double getDs(Map<String, dynamic> item) {
            final dynamic song = item['song'];
            final diffIndex = item['difficulty'] as int;
            if (song is Song) {
              if (song.ds != null && song.ds.length > diffIndex) {
                return song.ds[diffIndex];
              }
            }
            return 0.0;
          }
          return getDs(b).compareTo(getDs(a));
        });

      // 添加等级/定数分隔线
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
            '${_useLevelDisplay ? 'Lv.' : ''}${levelKey} | 共 ${levelSongs.length} 首歌曲',
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
            itemCount: levelSongs.length,
            itemBuilder: (context, index) {
              final item = levelSongs[index];
              final dynamic song = item['song'];
              final isCompleted = item['completed'] as bool;

              String songId = '';
              int initialLevelIndex = _selectedDifficulty ?? 3;
              if (song is Song) {
                songId = song.id;
                initialLevelIndex = item['difficulty'] as int;
              } else if (song is CollectionRequiredSong) {
                songId = song.id.toString();
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