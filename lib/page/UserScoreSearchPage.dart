import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import '../service/UserScoreSearchService.dart';
import 'HomePage.dart';
import 'SongInfoPage.dart';
import '../utils/CoverUtil.dart';

class UserScoreSearchPage extends StatefulWidget {
  const UserScoreSearchPage({Key? key}) : super(key: key);

  @override
  _UserScoreSearchPageState createState() => _UserScoreSearchPageState();
}

class _UserScoreSearchPageState extends State<UserScoreSearchPage> {
  final UserScoreSearchService _service = UserScoreSearchService();
  
  Map<String, dynamic>? _userPlayData;
  List<dynamic> _sortedSongs = [];
  List<dynamic> _pagedSongs = [];
  bool _isLoading = true;
  Map<String, int>? _stats; // 存储统计数据
  
  int _currentPage = 1;
  int _pageSize = 50;
  final TextEditingController _pageSizeController = TextEditingController(text: '50');
  
  // 筛选按钮相关尺寸变量
  late double _buttonHorizontalSpacing;
  late double _buttonVerticalSpacing;
  late double _buttonBorderRadius;
  late double _buttonWidth;
  late double _buttonHeight;
  late double _buttonFontSize;
  
  // 新增小按钮相关尺寸变量
  late double _smallButtonWidth;
  late double _smallButtonHeight;
  late double _smallButtonFontSize;
  
  // 当前选中的按钮索引
  int _selectedButtonIndex = 0;
  
  // 当前排序方式
  String _currentSortBy = 'Rating'; // 默认选择Rating
  
  // 筛选条件
  Map<String, String> _filterConditions = {
    '版本筛选': '',
    '定数筛选': '',
    '难度筛选': '',
    '达成率筛选': '',
    '连击/同步筛选': '',
  };
  
  // 版本列表
  static List<String> _versionList = [
    'maimai',
    'maimai PLUS',
    'maimai GreeN',
    'maimai GreeN PLUS',
    'maimai ORANGE',
    'maimai ORANGE PLUS',
    'maimai PiNK',
    'maimai PiNK PLUS',
    'maimai MURASAKi',
    'maimai MURASAKi PLUS',
    'maimai MiLK',
    'maimai MiLK PLUS',
    'maimai FiNALE',
    'maimai \u3067\u3089\u3063\u304f\u3059',
    'maimai \u3067\u3089\u3063\u304f\u3059 Splash',
    'maimai \u3067\u3089\u3063\u304f\u3059 UNiVERSE',
    'maimai \u3067\u3089\u3063\u304f\u3059 FESTiVAL',
    'maimai \u3067\u3089\u3063\u304f\u3059 BUDDiES',
    'maimai \u3067\u3089\u3063\u304f\u3059 PRiSM'
  ];
  
  // 处理版本字符串，使其在前端简化展示
  static String _formatVersion(String version) {
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
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  // 初始化按钮尺寸变量
  void _initButtonSizes(double screenWidth) {
    _buttonHorizontalSpacing = screenWidth * 0.015;
    _buttonVerticalSpacing = screenWidth * 0.008;
    _buttonBorderRadius = screenWidth * 0.01;
    _buttonWidth = screenWidth * 0.28; // 增加按钮宽度，从0.2增加到0.28
    _buttonHeight = screenWidth * 0.15;
    _buttonFontSize = screenWidth * 0.035; // 增大字体大小，从0.03增加到0.035
    
    // 初始化新增小按钮尺寸
    _smallButtonWidth = screenWidth * 0.12;
    _smallButtonHeight = screenWidth * 0.08;
    _smallButtonFontSize = screenWidth * 0.035;
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      _userPlayData = await _service.getUserPlayData();
      if (_userPlayData != null) {
        _sortedSongs = await _service.getSortedSongs(_userPlayData!, _currentSortBy);
        // 应用筛选条件
        _sortedSongs = await _service.filterSongs(_sortedSongs, _filterConditions);
        _updatePagedSongs();
        // 计算统计数据
        _stats = await _calculateStats();
      }
    } catch (e) {
      print('加载数据出错: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // 显示排序方式对话框
  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('选择排序方式'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    title: Text('Rating'),
                    value: 'Rating',
                    groupValue: _currentSortBy,
                    onChanged: (value) {
                      setState(() {
                        _currentSortBy = value!;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: Text('达成率'),
                    value: '达成率',
                    groupValue: _currentSortBy,
                    onChanged: (value) {
                      setState(() {
                        _currentSortBy = value!;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: Text('定数'),
                    value: '定数',
                    groupValue: _currentSortBy,
                    onChanged: (value) {
                      setState(() {
                        _currentSortBy = value!;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: Text('DX分达成率'),
                    value: 'DX分达成率',
                    groupValue: _currentSortBy,
                    onChanged: (value) {
                      setState(() {
                        _currentSortBy = value!;
                      });
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              child: Text('取消'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('确认'),
              onPressed: () {
                Navigator.of(context).pop();
                _loadData(); // 重新加载数据
              },
            ),
          ],
        );
      },
    );
  }
  
  // 显示版本筛选对话框
  void _showVersionFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String selectedVersion = _filterConditions['版本筛选'] ?? '';
        return AlertDialog(
          title: Text('版本筛选'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Container(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RadioListTile<String>(
                        title: Text('全部'),
                        value: '',
                        groupValue: selectedVersion,
                        onChanged: (value) {
                          setState(() {
                            selectedVersion = value!;
                          });
                        },
                      ),
                      ..._versionList.map((version) {
                        return RadioListTile<String>(
                          title: Text(_formatVersion(version)),
                          value: version,
                          groupValue: selectedVersion,
                          onChanged: (value) {
                            setState(() {
                              selectedVersion = value!;
                            });
                          },
                        );
                      }).toList(),
                    ],
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              child: Text('取消'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('确认'),
              onPressed: () {
                setState(() {
                  _filterConditions['版本筛选'] = selectedVersion;
                });
                Navigator.of(context).pop();
                _loadData(); // 重新加载数据
              },
            ),
          ],
        );
      },
    );
  }
  
  // 显示定数筛选对话框
  void _showDsFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String currentRange = _filterConditions['定数筛选'] ?? '';
        TextEditingController minController = TextEditingController();
        TextEditingController maxController = TextEditingController();
        
        // 解析当前范围
        if (currentRange.contains('-')) {
          List<String> parts = currentRange.split('-');
          if (parts.length == 2) {
            minController.text = parts[0];
            maxController.text = parts[1];
          }
        }
        
        return AlertDialog(
          title: Text('定数筛选'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minController,
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: '下界',
                            hintText: '1.0',
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: maxController,
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: '上界',
                            hintText: '15.0',
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text('最多一位小数，留空表示默认值', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              child: Text('取消'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('确认'),
              onPressed: () {
                String minText = minController.text.trim();
                String maxText = maxController.text.trim();
                String range = '';
                
                if (minText.isNotEmpty || maxText.isNotEmpty) {
                  range = '$minText-$maxText';
                }
                
                setState(() {
                  _filterConditions['定数筛选'] = range;
                });
                Navigator.of(context).pop();
                _loadData(); // 重新加载数据
              },
            ),
          ],
        );
      },
    );
  }
  
  // 显示难度筛选对话框
  void _showDifficultyFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String selectedDifficulty = _filterConditions['难度筛选'] ?? '';
        List<String> difficulties = ['', 'BASIC', 'ADVANCED', 'EXPERT', 'MASTER', 'Re:MASTER'];
        return AlertDialog(
          title: Text('难度筛选'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: difficulties.map((difficulty) {
                  return RadioListTile<String>(
                    title: Text(difficulty.isEmpty ? '全部' : difficulty),
                    value: difficulty,
                    groupValue: selectedDifficulty,
                    onChanged: (value) {
                      setState(() {
                        selectedDifficulty = value!;
                      });
                    },
                  );
                }).toList(),
              );
            },
          ),
          actions: [
            TextButton(
              child: Text('取消'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('确认'),
              onPressed: () {
                setState(() {
                  _filterConditions['难度筛选'] = selectedDifficulty;
                });
                Navigator.of(context).pop();
                _loadData(); // 重新加载数据
              },
            ),
          ],
        );
      },
    );
  }
  
  // 显示达成率筛选对话框
  void _showAchievementFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String currentRange = _filterConditions['达成率筛选'] ?? '';
        TextEditingController minController = TextEditingController();
        TextEditingController maxController = TextEditingController();
        
        // 解析当前范围
        if (currentRange.contains('-')) {
          List<String> parts = currentRange.split('-');
          if (parts.length == 2) {
            minController.text = parts[0];
            maxController.text = parts[1];
          }
        }
        
        return AlertDialog(
          title: Text('达成率筛选'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minController,
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: '下界',
                            hintText: '0',
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: maxController,
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: '上界',
                            hintText: '101',
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text('最多四位小数，留空表示默认值', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              child: Text('取消'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('确认'),
              onPressed: () {
                String minText = minController.text.trim();
                String maxText = maxController.text.trim();
                String range = '';
                
                if (minText.isNotEmpty || maxText.isNotEmpty) {
                  range = '$minText-$maxText';
                }
                
                setState(() {
                  _filterConditions['达成率筛选'] = range;
                });
                Navigator.of(context).pop();
                _loadData(); // 重新加载数据
              },
            ),
          ],
        );
      },
    );
  }
  
  // 显示连击/同步筛选对话框
  void _showComboFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String selectedFilter = _filterConditions['连击/同步筛选'] ?? '';
        List<String> filters = ['全部', '无连击评价', 'FC', 'FC+', 'AP', 'AP+', '无同步评价', 'SYNC', 'FS', 'FS+', 'FDX', 'FDX+'];
        List<String> filterValues = ['全部', '无连击评价', 'FC', 'FC+', 'AP', 'AP+', '无同步评价', 'SYNC', 'FS', 'FS+', 'FDX', 'FDX+'];
        return AlertDialog(
          title: Text('连击/同步筛选'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Container(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(filters.length, (index) {
                      return RadioListTile<String>(
                        title: Text(filters[index]),
                        value: filterValues[index],
                        groupValue: selectedFilter,
                        onChanged: (value) {
                          setState(() {
                            selectedFilter = value!;
                          });
                        },
                      );
                    }),
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              child: Text('取消'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('确认'),
              onPressed: () {
                setState(() {
                  _filterConditions['连击/同步筛选'] = selectedFilter;
                });
                Navigator.of(context).pop();
                _loadData(); // 重新加载数据
              },
            ),
          ],
        );
      },
    );
  }
  
  void _updatePagedSongs() {
    _pagedSongs = _service.getPagedSongs(_sortedSongs, _currentPage, _pageSize);
  }
  
  void _changePage(int page) {
    setState(() {
      _currentPage = page;
      _updatePagedSongs();
    });
  }
  
  void _changePageSize() {
    int newPageSize = int.tryParse(_pageSizeController.text) ?? 50;
    if (newPageSize > 0) {
      setState(() {
        _pageSize = newPageSize;
        _currentPage = 1;
        _updatePagedSongs();
      });
    }
  }
  
  int _getTotalPages() {
    return (_sortedSongs.length / _pageSize).ceil();
  }

  // 计算统计数据
  Future<Map<String, int>> _calculateStats() async {
    if (_sortedSongs.isEmpty) {
      return {
        'total': 0,
        'sssp': 0,
        'sss': 0,
        'fc': 0,
        'ap': 0,
        'fs': 0,
        'fdx': 0,
        'star5': 0,
        'star4': 0,
        'star3': 0,
        'star2': 0,
        'star1': 0,
      };
    }
    
    List<dynamic> records = _sortedSongs;
    int total = records.length;
    int sssp = 0; // ≥SSS+
    int sss = 0;  // ≥SSS
    int fc = 0;   // FC/FC+
    int ap = 0;   // AP/AP+
    int fs = 0;   // FS/FS+
    int fdx = 0;  // FDX/FDX+
    int star5 = 0; // 5星
    int star4 = 0; // 4星
    int star3 = 0; // 3星
    int star2 = 0; // 2星
    int star1 = 0; // 1星
    
    // 计算星数时，先缓存DX分达成率，避免重复计算
    Map<dynamic, double> dxRateMap = {};
    
    for (var record in records) {
      // 统计成绩等级
      if (record.containsKey('achievements')) {
        double achievements = double.tryParse(record['achievements'].toString()) ?? 0;
        if (achievements >= 100.5) {
          sssp++;
        } else if (achievements >= 100.0) {
          sss++;
        }
      }
      
      // 统计FC/AP
      if (record.containsKey('fc')) {
        String fcValue = record['fc'].toString().toLowerCase();
        if (fcValue == 'fc' || fcValue == 'fcp') {
          fc++;
        }
        if (fcValue == 'ap' || fcValue == 'app') {
          ap++;
        }
      }
      
      // 统计FS/FDX
      if (record.containsKey('fs')) {
        String fsValue = record['fs'].toString().toLowerCase();
        if (fsValue == 'fs' || fsValue == 'fsp') {
          fs++;
        }
        if (fsValue == 'fsd' || fsValue == 'fsdp') {
          fdx++;
        }
      }
    }
    
    // 单独计算星数，避免在主循环中阻塞
    for (var record in records) {
      // 统计星数
      if (record.containsKey('dxScore')) {
        // ignore: unused_local_variable
        int dxScore = int.tryParse(record['dxScore'].toString()) ?? 0;
        // 计算DX分达成率
        double rate;
        if (dxRateMap.containsKey(record)) {
          rate = dxRateMap[record]!;
        } else {
          rate = await _calculateDXScoreRate(record);
          dxRateMap[record] = rate;
        }
        if (rate >= 0.97) {
          star5++;
        } else if (rate >= 0.95) {
          star4++;
        } else if (rate >= 0.93) {
          star3++;
        } else if (rate >= 0.90) {
          star2++;
        } else if (rate >= 0.85) {
          star1++;
        }
      }
    }
    
    return {
      'total': total,
      'sssp': sssp,
      'sss': sss,
      'fc': fc,
      'ap': ap,
      'fs': fs,
      'fdx': fdx,
      'star5': star5,
      'star4': star4,
      'star3': star3,
      'star2': star2,
      'star1': star1,
    };
  }
  
  // 使用UserScoreSearchService中的方法计算DX分达成率
  Future<double> _calculateDXScoreRate(dynamic record) {
    return _service.calculateDXScoreRate(record);
  }
  
  // 构建星数统计项
  Widget _buildStarStatItem(String label, int value, String stars) {
    Color textColor = _getStarsColor(stars);
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(6),
        color: Colors.grey[50],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 2),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  // 获取星星颜色
  Color _getStarsColor(String stars) {
    switch (stars) {
      case '✦ 5':
        return Colors.yellow;
      case '✦ 4':
      case '✦ 3':
        return Colors.orange;
      case '✦ 2':
      case '✦ 1':
        return Colors.green.shade300;
      default:
        return Colors.white;
    }
  }
  
  // 构建统计项
  Widget _buildStatItem(String label, int value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(6),
        color: Colors.grey[50],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 2),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // ignore: unused_local_variable
    final stats =  _calculateStats();
    
    // 初始化按钮尺寸
    _initButtonSizes(screenWidth);

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false, // 防止键盘弹出时调整布局
      body: Stack(
        children: [

          CommonWidgetUtil.buildCommonBgWidget(),
          CommonWidgetUtil.buildCommonChiffonBgWidget(context),
        
          // 页面内容
          Column(
            children: [
              // 标题栏
              Container(
                padding: EdgeInsets.fromLTRB(16, 48, 16, 16),
                child: Row(
                  children: [
                    // 返回按钮
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: AppConstants.textPrimaryColor),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    // 标题
                    Expanded(
                      child: Center(
                        child: Text(
                          '成绩查询',
                          style: TextStyle(
                            color: AppConstants.textPrimaryColor,
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
                  margin: EdgeInsets.fromLTRB(8, 0, 8, 16), // 进一步减小上边距，从4减小到0
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9), // 增加白色不透明度，使背景更深
                    borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                    boxShadow: const [AppConstants.defaultShadow],
                  ),
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator())
                      : _userPlayData == null
                          ? Center(child: Text('没有找到缓存数据'))
                          : Column(
                              children: [
                                // 可滚动内容区域
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: Column(
                                      children: [
                                        // 统计显示区域
                                        Container(
                                          padding: EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                                          ),
                                          child: Column(
                                            children: [
                                              // 第一行统计数据
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                children: [
                                                  Expanded(child: _buildStatItem('总谱面数', _stats!['total']!)),
                                                  SizedBox(width: 8),
                                                  Expanded(child: _buildStatItem('SSS+', _stats!['sssp']!)),
                                                  SizedBox(width: 8),
                                                  Expanded(child: _buildStatItem('SSS', _stats!['sss']!)),
                                                  SizedBox(width: 8),
                                                ],
                                              ),
                                              SizedBox(height: 8),
                                              // 第二行统计数据
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                children: [
                                                  Expanded(child: _buildStatItem('FC/FC+', _stats!['fc']!)),
                                                  SizedBox(width: 8),
                                                  Expanded(child: _buildStatItem('AP/AP+', _stats!['ap']!)),
                                                  SizedBox(width: 8),
                                                  Expanded(child: _buildStatItem('FS/FS+', _stats!['fs']!)),
                                                  SizedBox(width: 8),
                                                  Expanded(child: _buildStatItem('FDX/FDX+', _stats!['fdx']!)),
                                                ],
                                              ),
                                              SizedBox(height: 8),
                                              // 第三行统计数据（星数）
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                children: [
                                                  Expanded(child: _buildStarStatItem('✦ 5', _stats!['star5']!, '✦ 5')),
                                                  SizedBox(width: 8),
                                                  Expanded(child: _buildStarStatItem('✦ 4', _stats!['star4']!, '✦ 4')),
                                                  SizedBox(width: 8),
                                                  Expanded(child: _buildStarStatItem('✦ 3', _stats!['star3']!, '✦ 3')), 
                                                  SizedBox(width: 8),
                                                  Expanded(child: _buildStarStatItem('✦ 2', _stats!['star2']!, '✦ 2')),
                                                  SizedBox(width: 8),
                                                  Expanded(child: _buildStarStatItem('✦ 1', _stats!['star1']!, '✦ 1')),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        
                                        // 筛选按钮区域
                                        Container(
                                          padding: EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                                          ),
                                          child: Wrap(
                                            spacing: _buttonHorizontalSpacing, // 水平间距
                                            runSpacing: _buttonVerticalSpacing, // 垂直间距
                                            children: [
                                              ElevatedButton(
                                                onPressed: _showSortDialog,
                                                style: ElevatedButton.styleFrom(
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(_buttonBorderRadius), // 圆角
                                                  ),
                                                  fixedSize: Size(_buttonWidth, _buttonHeight), // 按钮尺寸
                                                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8), // 调整内边距
                                                ),
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text('排序方式', 
                                                      style: TextStyle(fontSize: _buttonFontSize),
                                                      maxLines: 1,
                                                    ),
                                                    SizedBox(height: 2),
                                                    Text(_currentSortBy, 
                                                      style: TextStyle(fontSize: _buttonFontSize * 0.8, color: Colors.black),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ), // 文字尺寸
                                              ),
                                              ElevatedButton(
                                                onPressed: _showVersionFilterDialog,
                                                style: ElevatedButton.styleFrom(
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(_buttonBorderRadius),
                                                  ),
                                                  fixedSize: Size(_buttonWidth, _buttonHeight),
                                                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8), // 调整内边距
                                                ),
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text('版本筛选', 
                                                      style: TextStyle(fontSize: _buttonFontSize),
                                                      maxLines: 1,
                                                    ),
                                                    SizedBox(height: 2),
                                                    Text(_filterConditions['版本筛选'] != null && _filterConditions['版本筛选']!.isNotEmpty
                                                        ? _formatVersion(_filterConditions['版本筛选']!)
                                                        : '', 
                                                      style: TextStyle(fontSize: _buttonFontSize * 0.8, color: Colors.black),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              ElevatedButton(
                                                onPressed: _showDsFilterDialog,
                                                style: ElevatedButton.styleFrom(
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(_buttonBorderRadius),
                                                  ),
                                                  fixedSize: Size(_buttonWidth, _buttonHeight),
                                                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8), // 调整内边距
                                                ),
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text('定数筛选', 
                                                      style: TextStyle(fontSize: _buttonFontSize),
                                                      maxLines: 1,
                                                    ),
                                                    SizedBox(height: 2),
                                                    Text(_filterConditions['定数筛选'] ?? '', 
                                                      style: TextStyle(fontSize: _buttonFontSize * 0.8, color: Colors.black),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              ElevatedButton(
                                                onPressed: _showDifficultyFilterDialog,
                                                style: ElevatedButton.styleFrom(
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(_buttonBorderRadius),
                                                  ),
                                                  fixedSize: Size(_buttonWidth, _buttonHeight),
                                                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8), // 调整内边距
                                                ),
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text('难度筛选', 
                                                      style: TextStyle(fontSize: _buttonFontSize),
                                                      maxLines: 1,
                                                    ),
                                                    SizedBox(height: 2),
                                                    Text(_filterConditions['难度筛选'] ?? '', 
                                                      style: TextStyle(fontSize: _buttonFontSize * 0.8, color: Colors.black),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              ElevatedButton(
                                                onPressed: _showAchievementFilterDialog,
                                                style: ElevatedButton.styleFrom(
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(_buttonBorderRadius),
                                                  ),
                                                  fixedSize: Size(_buttonWidth, _buttonHeight),
                                                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8), // 调整内边距
                                                ),
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text('达成率筛选', 
                                                      style: TextStyle(fontSize: _buttonFontSize),
                                                      maxLines: 1,
                                                    ),
                                                    SizedBox(height: 2),
                                                    Text(_filterConditions['达成率筛选'] ?? '', 
                                                      style: TextStyle(fontSize: _buttonFontSize * 0.8, color: Colors.black),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              ElevatedButton(
                                                onPressed: _showComboFilterDialog,
                                                style: ElevatedButton.styleFrom(
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(_buttonBorderRadius),
                                                  ),
                                                  fixedSize: Size(_buttonWidth, _buttonHeight),
                                                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8), // 调整内边距
                                                ),
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text('连击/同步筛选', 
                                                      style: TextStyle(fontSize: _buttonFontSize),
                                                      maxLines: 1,
                                                    ),
                                                    SizedBox(height: 2),
                                                    Text(_filterConditions['连击/同步筛选'] ?? '', 
                                                      style: TextStyle(fontSize: _buttonFontSize * 0.8, color: Colors.black),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        
                                        // 每页显示数量设置
                                        Container(
                                          padding: EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                                          ),
                                          child: Row(
                                            children: [
                                              // 四个小按钮组合
                                              Row(
                                                children: [
                                                  ElevatedButton(
                                                    onPressed: () {
                                                      setState(() {
                                                        _selectedButtonIndex = 0;
                                                      });
                                                    },
                                                    style: ElevatedButton.styleFrom(
                                                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                      minimumSize: Size(_smallButtonWidth, _smallButtonHeight),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(2), // 方形按钮
                                                      ),
                                                      backgroundColor: _selectedButtonIndex == 0 ? Colors.blue : null,
                                                    ),
                                                    child: Text('评级', 
                                                      style: TextStyle(
                                                        fontSize: _smallButtonFontSize, 
                                                        color: _selectedButtonIndex == 0 ? Colors.white : Colors.black,
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(width: 4),
                                                  ElevatedButton(
                                                    onPressed: () {
                                                      setState(() {
                                                        _selectedButtonIndex = 1;
                                                      });
                                                    },
                                                    style: ElevatedButton.styleFrom(
                                                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                      minimumSize: Size(_smallButtonWidth, _smallButtonHeight),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(2), // 方形按钮
                                                      ),
                                                      backgroundColor: _selectedButtonIndex == 1 ? Colors.blue : null,
                                                    ),
                                                    child: Text('连击', 
                                                      style: TextStyle(
                                                        fontSize: _smallButtonFontSize, 
                                                        color: _selectedButtonIndex == 1 ? Colors.white : Colors.black,
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(width: 4),
                                                  ElevatedButton(
                                                    onPressed: () {
                                                      setState(() {
                                                        _selectedButtonIndex = 2;
                                                      });
                                                    },
                                                    style: ElevatedButton.styleFrom(
                                                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                      minimumSize: Size(_smallButtonWidth, _smallButtonHeight),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(2), // 方形按钮
                                                      ),
                                                      backgroundColor: _selectedButtonIndex == 2 ? Colors.blue : null,
                                                    ),
                                                    child: Text('同步', 
                                                      style: TextStyle(
                                                        fontSize: _smallButtonFontSize, 
                                                        color: _selectedButtonIndex == 2 ? Colors.white : Colors.black,
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(width: 4),
                                                  ElevatedButton(
                                                    onPressed: () {
                                                      setState(() {
                                                        _selectedButtonIndex = 3;
                                                      });
                                                    },
                                                    style: ElevatedButton.styleFrom(
                                                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                      minimumSize: Size(_smallButtonWidth, _smallButtonHeight),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(2), // 方形按钮
                                                      ),
                                                      backgroundColor: _selectedButtonIndex == 3 ? Colors.blue : null,
                                                    ),
                                                    child: Text('得分', 
                                                      style: TextStyle(
                                                        fontSize: _smallButtonFontSize, 
                                                        color: _selectedButtonIndex == 3 ? Colors.white : Colors.black,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Spacer(), // 中间占位，将右侧内容推到右边
                                              // 每页显示输入框
                                              Row(
                                                children: [
                                                  Text('每页显示 ', style: TextStyle(fontSize: 12)), // 减小字体大小
                                                  Container(
                                                    width: screenWidth * 0.12, // 略微增加输入框宽度，从0.1增加到0.12
                                                    height: 24, // 固定高度，减小输入框高度
                                                    child: TextField(
                                                      controller: _pageSizeController,
                                                      keyboardType: TextInputType.number,
                                                      onSubmitted: (_) => _changePageSize(),
                                                      decoration: InputDecoration(
                                                        border: OutlineInputBorder(),
                                                        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 0), // 进一步减小内边距
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        
                                        // 歌曲列表
                                        Container(
                                          padding: EdgeInsets.all(8),
                                          constraints: BoxConstraints(
                                            minHeight: 300, // 设置最小高度确保内容显示
                                          ),
                                          child: GridView.builder(
                                            shrinkWrap: true, // 允许GridView根据内容大小调整
                                            physics: NeverScrollableScrollPhysics(), // 禁用内部滚动，由外部SingleChildScrollView控制
                                            padding: EdgeInsets.all(2), // 进一步减小内边距，从4减少到2
                                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: 5, // 保持每行5个曲绘
                                              crossAxisSpacing: 2, // 使用固定值2作为水平间距
                                              mainAxisSpacing: 2, // 使用固定值2作为垂直间距
                                              childAspectRatio: 1.0, // 确保图片显示为正方形
                                            ),
                                            itemCount: _pagedSongs.length,
                                            itemBuilder: (context, index) {
                                              final song = _pagedSongs[index];
                                              final levelIndex = song['level_index'] ?? 0;
                                              final borderColor = _service.getBorderColor(levelIndex);
                                              
                                              // 计算每个网格项的大小，确保正方形显示
                                              final itemSize = (screenWidth - 4 - (4 * 2)) / 5; // 4是左右边距（各2），4是间隔数（因为是5列），每个间隔2像素
                                              
                                              // 获取要显示的信息
                                              String displayText = '';
                                              Color displayColor = Colors.white;
                                              
                                              switch (_selectedButtonIndex) {
                                                case 0: // 评级
                                                  if (song.containsKey('achievements')) {
                                                    double achievements = double.tryParse(song['achievements'].toString()) ?? 0;
                                                    if (achievements >= 100.5) {
                                                      displayText = 'SSS+';
                                                      displayColor = Colors.yellow;
                                                    } else if (achievements >= 100.0) {
                                                      displayText = 'SSS';
                                                      displayColor = Colors.yellow;
                                                    } else if (achievements >= 99.5) {
                                                      displayText = 'SS+';
                                                      displayColor = Colors.orange;
                                                    } else if (achievements >= 99.0) {
                                                      displayText = 'SS';
                                                      displayColor = Colors.orange;
                                                    } else if (achievements >= 98.0) {
                                                      displayText = 'S+';
                                                      displayColor = Colors.orange;
                                                    } else if (achievements >= 97.0) {
                                                      displayText = 'S';
                                                      displayColor = Colors.orange;
                                                    } else if (achievements >= 94.0) {
                                                      displayText = 'AAA';
                                                      displayColor = Colors.red;
                                                    } else if (achievements >= 90.0) {
                                                      displayText = 'AA';
                                                      displayColor = Colors.red;
                                                    } else if (achievements >= 80.0) {
                                                      displayText = 'A';
                                                      displayColor = Colors.red;
                                                    } else if (achievements >= 75.0) {
                                                      displayText = 'BBB';
                                                      displayColor = Colors.blue;
                                                    } else if (achievements >= 70.0) {
                                                      displayText = 'BB';
                                                      displayColor = Colors.blue;
                                                    } else if (achievements >= 60.0) {
                                                      displayText = 'B';
                                                      displayColor = Colors.blue;
                                                    } else if (achievements >= 50.0) {
                                                      displayText = 'C';
                                                      displayColor = Colors.grey;
                                                    } else {
                                                      displayText = 'D';
                                                      displayColor = Colors.grey;
                                                    }
                                                  }
                                                  break;
                                                case 1: // 连击
                                                  if (song.containsKey('fc')) {
                                                    String fc = song['fc'].toString().toLowerCase();
                                                    if (fc == 'app') {
                                                      displayText = 'AP+';
                                                      displayColor = Colors.yellow;
                                                    } else if (fc == 'ap') {
                                                      displayText = 'AP';
                                                      displayColor = Colors.orange;
                                                    } else if (fc == 'fcp') {
                                                      displayText = 'FC+';
                                                      displayColor = Colors.green;
                                                    } else if (fc == 'fc') {
                                                      displayText = 'FC';
                                                      displayColor = Colors.blue;
                                                    }
                                                  }
                                                  break;
                                                case 2: // 同步
                                                  if (song.containsKey('fs')) {
                                                    String fs = song['fs'].toString().toLowerCase();
                                                    if (fs == 'fsdp') {
                                                      displayText = 'FDX+';
                                                      displayColor = Colors.yellow;
                                                    } else if (fs == 'fsd') {
                                                      displayText = 'FDX';
                                                      displayColor = Colors.orange;
                                                    } else if (fs == 'fsp') {
                                                      displayText = 'FS+';
                                                      displayColor = Colors.green;
                                                    } else if (fs == 'fs') {
                                                      displayText = 'FS';
                                                      displayColor = Colors.blue;
                                                    }
                                                  }
                                                  break;
                                                case 3: // 得分
                                                  if (song.containsKey('ra')) {
                                                    displayText = song['ra'].toString();
                                                    displayColor = Colors.white;
                                                  }
                                                  break;
                                              }
                                              
                                              return GestureDetector(
                                                onTap: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => SongInfoPage(
                                                        songId: song['song_id'].toString(),
                                                        initialLevelIndex: levelIndex,
                                                      ),
                                                    ),
                                                  );
                                                },
                                                child: Container(
                                                  width: itemSize,
                                                  height: itemSize,
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: Color(borderColor.value),
                                                      width: 2,
                                                    ),
                                                    borderRadius: BorderRadius.circular(8),
                                                    color: Color(borderColor.value).withOpacity(0.3), // 给四个角添加与边框相同颜色的背景
                                                  ),
                                                  child: Stack(
                                                    fit: StackFit.expand,
                                                    children: [
                                                      CoverUtil.buildCoverWidgetWithContextRRect(
                                                        context, 
                                                        song['song_id']?.toString() ?? '', 
                                                        double.infinity
                                                      ),
                                                      // 叠加显示信息
                                                      if (displayText.isNotEmpty) 
                                                        Container(
                                                          decoration: BoxDecoration(
                                                            color: Colors.black.withOpacity(0.4),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Center(
                                                            child: Text(
                                                              displayText,
                                                              style: TextStyle(
                                                                color: displayColor,
                                                                fontSize: itemSize * 0.2,
                                                                fontWeight: FontWeight.bold,
                                                              ),
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
                                      ],
                                    ),
                                  ),
                                ),
                                
                                // 固定的分页控件
                                Container(
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    border: Border(top: BorderSide(color: Colors.grey[300]!)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ElevatedButton(
                                        onPressed: _currentPage > 1
                                            ? () => _changePage(_currentPage - 1)
                                            : null,
                                        child: Text('上一页', style: TextStyle(color: Colors.black)),
                                      ),
                                      SizedBox(width: 16),
                                      Text('$_currentPage / ${_getTotalPages()}', style: TextStyle(color: Colors.black)),
                                      SizedBox(width: 16),
                                      ElevatedButton(
                                        onPressed: _currentPage < _getTotalPages()
                                            ? () => _changePage(_currentPage + 1)
                                            : null,
                                        child: Text('下一页', style: TextStyle(color: Colors.black)),
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