import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/service/SongSearchService.dart';
import 'package:my_first_flutter_app/page/SongInfoPage.dart';
import 'package:my_first_flutter_app/manager/SongAliasManager.dart';
import 'dart:async';

class SongSearchPage extends StatefulWidget {
  const SongSearchPage({super.key});

  @override
  State<SongSearchPage> createState() => _SongSearchPageState();
}

class _SongSearchPageState extends State<SongSearchPage> {
  // 状态变量
  List<dynamic> _allSearchResults = []; // 所有搜索结果
  List<dynamic> _currentPageResults = []; // 当前页的结果
  bool _isSearching = false;
  String? _errorMessage;
  TextEditingController _searchController = TextEditingController();
  Timer? _searchTimer;

  // 分页相关
  int _currentPage = 1;
  int _pageSize = 15;
  int _totalItems = 0;
  int _totalPages = 0;

  // 筛选相关
  TextEditingController _minLevelController = TextEditingController();
  TextEditingController _maxLevelController = TextEditingController();
  bool _showLevelFilter = false;
  bool _showVersionFilter = false;
  bool _showGenreFilter = false;
  bool _showAllFilters = true; // 控制是否显示所有筛选区域
  List<String> _selectedVersions = [];
  List<String> _selectedGenres = [];

  // 版本列表
  List<String> _versionList = [
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

  // 流派列表
  List<String> _genreList = [
    '舞萌',
    '流行&动漫',
    'niconico & VOCALOID',
    '其他游戏',
    '东方Project',
    '音击&中二节奏'
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _minLevelController.dispose();
    _maxLevelController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  // 执行搜索
  Future<void> _performSearch(String query) async {
    // 检查是否所有筛选条件都为空
    bool allFiltersEmpty = query.isEmpty &&
        _minLevelController.text.isEmpty &&
        _maxLevelController.text.isEmpty &&
        _selectedVersions.isEmpty &&
        _selectedGenres.isEmpty;

    if (allFiltersEmpty) {
      setState(() {
        _allSearchResults = [];
        _currentPageResults = [];
        _currentPage = 1;
        _totalItems = 0;
        _totalPages = 0;
        _isSearching = false;
        _errorMessage = null;
      });
      return;
    }

    try {
      setState(() {
        _isSearching = true;
        _errorMessage = null;
      });

      // 调用搜索服务
      List<dynamic> results;
      if (query.isEmpty) {
        // 当输入框为空时，获取所有歌曲
        results = await SongSearchService.loadAllSongs();
      } else {
        // 当输入框不为空时，执行搜索
        results = await SongSearchService.searchSongs(query);
      }

      // 应用筛选条件
      List<dynamic> filteredResults = results;

      // 应用定数筛选
      if (_minLevelController.text.isNotEmpty ||
          _maxLevelController.text.isNotEmpty) {
        // 处理边界值
        double? minLevel = double.tryParse(_minLevelController.text);
        double? maxLevel = double.tryParse(_maxLevelController.text);

        // 如果没写下界但写了上界，则将下界设为1.0
        if (minLevel == null && maxLevel != null) {
          minLevel = 1.0;
        }
        // 如果写了下界但没写上界，则将上界设为15.0
        if (minLevel != null && maxLevel == null) {
          maxLevel = 15.0;
        }

        filteredResults = filteredResults.where((song) {
          // 检查是否有符合条件的难度
          for (double ds in song.ds) {
            bool meetsMin = minLevel == null || ds >= minLevel;
            bool meetsMax = maxLevel == null || ds <= maxLevel;
            if (meetsMin && meetsMax) {
              return true;
            }
          }
          return false;
        }).toList();
      }

      // 应用版本筛选
      if (_selectedVersions.isNotEmpty) {
        filteredResults = filteredResults.where((song) {
          return _selectedVersions.contains(song.basicInfo.from);
        }).toList();
      }

      // 应用流派筛选
      if (_selectedGenres.isNotEmpty) {
        filteredResults = filteredResults.where((song) {
          return _selectedGenres.contains(song.basicInfo.genre);
        }).toList();
      }

      setState(() {
        _allSearchResults = filteredResults;
        _totalItems = filteredResults.length;
        _totalPages = (_totalItems + _pageSize - 1) ~/ _pageSize; // 计算总页数
        _currentPage = 1; // 重置到第一页
        _updateCurrentPageResults(); // 更新当前页结果
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '搜索失败：$e';
        _isSearching = false;
      });
    }
  }

  // 更新当前页的结果
  void _updateCurrentPageResults() {
    int startIndex = (_currentPage - 1) * _pageSize;
    int endIndex = startIndex + _pageSize;
    if (endIndex > _totalItems) {
      endIndex = _totalItems;
    }
    _currentPageResults = _allSearchResults.sublist(startIndex, endIndex);
  }

  // 切换到指定页码
  void _goToPage(int page) {
    if (page < 1) page = 1;
    if (page > _totalPages) page = _totalPages;
    setState(() {
      _currentPage = page;
      _updateCurrentPageResults();
    });
  }

  // 防抖搜索
  void _debouncedSearch(String query) {
    // 取消之前的定时器
    _searchTimer?.cancel();

    // 设置新的定时器，1000毫秒后执行搜索
    _searchTimer = Timer(const Duration(milliseconds: 1000), () {
      _performSearch(query);
    });
  }

  // 执行筛选搜索
  void _performFilteredSearch() {
    _performSearch(_searchController.text);
  }

  // 防抖筛选
  void _debouncedFilter() {
    // 取消之前的定时器
    _searchTimer?.cancel();

    // 设置新的定时器，1000毫秒后执行筛选
    _searchTimer = Timer(const Duration(milliseconds: 1000), () {
      // 即使没有输入内容也执行搜索
      _performSearch(_searchController.text);
    });
  }

  // 构建定数筛选组件
  Widget _buildLevelFilter(double screenWidth, double screenHeight) {
    // 生成已选内容文本
    String selectedLevelText = '';
    if (_minLevelController.text.isNotEmpty ||
        _maxLevelController.text.isNotEmpty) {
      selectedLevelText =
          '${_minLevelController.text.isEmpty ? '1.0' : _minLevelController.text} - ${_maxLevelController.text.isEmpty ? '15.0' : _maxLevelController.text}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Row(
                children: [
                  Text(
                    '定数筛选',
                    style: TextStyle(
                      fontSize: screenWidth * 0.035,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (selectedLevelText.isNotEmpty)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: screenWidth * 0.02),
                        child: Text(
                          selectedLevelText,
                          style: TextStyle(
                            fontSize: screenWidth * 0.03,
                            color: Colors.grey,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                _showLevelFilter ? Icons.expand_less : Icons.expand_more,
                size: screenWidth * 0.04,
              ),
              onPressed: () {
                setState(() {
                  _showLevelFilter = !_showLevelFilter;
                });
              },
            ),
          ],
        ),
        if (_showLevelFilter)
          Container(
            padding: EdgeInsets.symmetric(vertical: screenHeight * 0.01),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minLevelController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '最小值',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    ),
                    onChanged: (value) {
                      _debouncedFilter();
                    },
                  ),
                ),
                SizedBox(width: screenWidth * 0.02),
                Expanded(
                  child: TextField(
                    controller: _maxLevelController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '最大值',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    ),
                    onChanged: (value) {
                      _debouncedFilter();
                    },
                  ),
                ),
                SizedBox(width: screenWidth * 0.02),
                ElevatedButton(
                  onPressed: _performFilteredSearch,
                  child: Text('搜索'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // 构建版本筛选组件
  Widget _buildVersionFilter(double screenWidth, double screenHeight) {
    // 生成已选内容文本
    String selectedVersionsText =
        _selectedVersions.map((v) => _formatVersion(v)).join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Row(
                children: [
                  Text(
                    '版本筛选',
                    style: TextStyle(
                      fontSize: screenWidth * 0.035,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (selectedVersionsText.isNotEmpty)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: screenWidth * 0.02),
                        child: Text(
                          selectedVersionsText,
                          style: TextStyle(
                            fontSize: screenWidth * 0.03,
                            color: Colors.grey,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                _showVersionFilter ? Icons.expand_less : Icons.expand_more,
                size: screenWidth * 0.04,
              ),
              onPressed: () {
                setState(() {
                  _showVersionFilter = !_showVersionFilter;
                });
              },
            ),
          ],
        ),
        if (_showVersionFilter)
          Container(
            padding: EdgeInsets.symmetric(vertical: screenHeight * 0.01),
            child: Wrap(
              spacing: screenWidth * 0.02,
              runSpacing: screenHeight * 0.01,
              children: _versionList.map((version) {
                return FilterChip(
                  label: Text(
                    _formatVersion(version),
                    style: TextStyle(fontSize: screenWidth * 0.03),
                  ),
                  selected: _selectedVersions.contains(version),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedVersions.add(version);
                      } else {
                        _selectedVersions.remove(version);
                      }
                    });
                    // 防抖筛选
                    _debouncedFilter();
                  },
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  // 构建流派筛选组件
  Widget _buildGenreFilter(double screenWidth, double screenHeight) {
    // 生成已选内容文本
    String selectedGenresText = _selectedGenres.join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Row(
                children: [
                  Text(
                    '流派筛选',
                    style: TextStyle(
                      fontSize: screenWidth * 0.035,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (selectedGenresText.isNotEmpty)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: screenWidth * 0.02),
                        child: Text(
                          selectedGenresText,
                          style: TextStyle(
                            fontSize: screenWidth * 0.03,
                            color: Colors.grey,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                _showGenreFilter ? Icons.expand_less : Icons.expand_more,
                size: screenWidth * 0.04,
              ),
              onPressed: () {
                setState(() {
                  _showGenreFilter = !_showGenreFilter;
                });
              },
            ),
          ],
        ),
        if (_showGenreFilter)
          Container(
            padding: EdgeInsets.symmetric(vertical: screenHeight * 0.01),
            child: Wrap(
              spacing: screenWidth * 0.02,
              runSpacing: screenHeight * 0.01,
              children: _genreList.map((genre) {
                return FilterChip(
                  label: Text(
                    genre,
                    style: TextStyle(fontSize: screenWidth * 0.03),
                  ),
                  selected: _selectedGenres.contains(genre),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedGenres.add(genre);
                      } else {
                        _selectedGenres.remove(genre);
                      }
                    });
                    // 防抖筛选
                    _debouncedFilter();
                  },
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false, // 防止键盘弹出时挤压背景
      body: Stack(
        children: [
          // 层级1：基础背景图 - 占满整个屏幕，作为页面最底层背景
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background.png'), // 背景图资源
                fit: BoxFit.cover, // 覆盖整个容器，拉伸/裁剪适配
                opacity: 1.0, // 不透明
              ),
            ),
          ),

          // 层级2：第一张虚化装饰图 - 居中显示，轻微向上偏移
          Center(
            child: Transform.translate(
              offset: const Offset(0, -20), // 垂直向上偏移20px
              child: Transform.scale(
                scale: 1, // 不缩放
                child: Image.asset(
                  'assets/chiffon2.png',
                  fit: BoxFit.cover,
                  opacity: const AlwaysStoppedAnimation(1), // 固定不透明
                ),
              ),
            ),
          ),

          // 页面标题
          const Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "歌曲搜索",
                style: TextStyle(
                  color: Color.fromARGB(255, 84, 97, 97),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),

          // 返回按钮
          Positioned(
            top: 20,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_back,
                  color: Color.fromARGB(255, 84, 97, 97), size: 24),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),

          // 主要内容区域
          Positioned(
            top: 80,
            left: 10,
            right: 10,
            bottom: 40,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8.0),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 5.0,
                    offset: Offset(2.0, 2.0),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // 根据设备尺寸计算字体大小
                  double screenWidth = MediaQuery.of(context).size.width;
                  double screenHeight = MediaQuery.of(context).size.height;

                  // 基础字体大小
                  double baseFontSize = screenWidth * 0.04;
                  double smallFontSize = screenWidth * 0.035;
                  double tinyFontSize = screenWidth * 0.03;

                  // 边距
                  double padding = screenWidth * 0.04;

                  return Column(
                    children: [
                      // 搜索输入框
                      Padding(
                        padding: EdgeInsets.all(padding),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            // 防抖搜索
                            _debouncedSearch(value);
                          },
                          decoration: InputDecoration(
                            hintText: '输入歌曲标题、艺术家、BPM、谱师、别名',
                            hintStyle: TextStyle(fontSize: smallFontSize),
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                          style: TextStyle(fontSize: baseFontSize),
                        ),
                      ),

                      // 筛选条件、条目总数和搜索结果一起滚动
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.only(left: padding, right: padding, bottom: padding),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 筛选按钮区域
                              if (_showAllFilters)
                                Column(
                                  children: [
                                    // 定数筛选
                                    _buildLevelFilter(screenWidth, screenHeight),
                                    SizedBox(height: screenHeight * 0.01),

                                    // 版本筛选
                                    _buildVersionFilter(screenWidth, screenHeight),
                                    SizedBox(height: screenHeight * 0.01),

                                    // 流派筛选
                                    _buildGenreFilter(screenWidth, screenHeight),
                                    SizedBox(height: screenHeight * 0.01),
                                  ],
                                ),

                              // 搜索结果数量显示
                              if ((_searchController.text.isNotEmpty ||
                                      _selectedVersions.isNotEmpty ||
                                      _selectedGenres.isNotEmpty ||
                                      _minLevelController.text.isNotEmpty ||
                                      _maxLevelController.text.isNotEmpty) &&
                                  !_isSearching &&
                                  _errorMessage == null)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '找到 $_totalItems 首乐曲，每页 15 首',
                                            style: TextStyle(
                                              fontSize: smallFontSize,
                                              color: Colors.grey,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        SizedBox(width: screenWidth * 0.02),
                                        ElevatedButton(
                                          onPressed: () {
                                            setState(() {
                                              _searchController.clear();
                                              _minLevelController.clear();
                                              _maxLevelController.clear();
                                              _selectedVersions.clear();
                                              _selectedGenres.clear();
                                              _showAllFilters = true;
                                              _performSearch('');
                                            });
                                          },
                                          style: ElevatedButton.styleFrom(
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            padding: EdgeInsets.symmetric(
                                              horizontal: screenWidth * 0.02,
                                              vertical: screenHeight * 0.005,
                                            ),
                                            minimumSize: Size(screenWidth * 0.15, 30),
                                            backgroundColor: Colors.redAccent,
                                            foregroundColor: Colors.white,
                                          ),
                                          child: Text(
                                            '重置',
                                            style: TextStyle(
                                              fontSize: tinyFontSize,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: screenWidth * 0.01),
                                        ElevatedButton(
                                          onPressed: () {
                                            setState(() {
                                              _showAllFilters = !_showAllFilters;
                                            });
                                          },
                                          style: ElevatedButton.styleFrom(
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            padding: EdgeInsets.symmetric(
                                              horizontal: screenWidth * 0.02,
                                              vertical: screenHeight * 0.005,
                                            ),
                                            minimumSize: Size(screenWidth * 0.15, 30),
                                          ),
                                          child: Text(
                                            _showAllFilters ? '收起' : '展开',
                                            style: TextStyle(
                                              fontSize: tinyFontSize,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              
                              SizedBox(height: screenHeight * 0.01),
                              // 加载状态
                              if (_isSearching)
                                Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(screenHeight * 0.1),
                                    child: Column(
                                      children: [
                                        CircularProgressIndicator(
                                          color:
                                              Color.fromARGB(255, 84, 97, 97),
                                        ),
                                        SizedBox(height: screenHeight * 0.02),
                                        Text(
                                          '正在搜索...',
                                          style:
                                              TextStyle(fontSize: baseFontSize),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              // 错误状态
                              else if (_errorMessage != null)
                                Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(screenHeight * 0.1),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          color: Colors.red,
                                          size: screenWidth * 0.12,
                                        ),
                                        SizedBox(height: screenHeight * 0.02),
                                        Text(
                                          _errorMessage!,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontSize: baseFontSize,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              // 无结果状态
                              else if (_allSearchResults.isEmpty &&
                                  _searchController.text.isNotEmpty)
                                Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(screenHeight * 0.1),
                                    child: Text(
                                      '未找到匹配的歌曲',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: baseFontSize,
                                      ),
                                    ),
                                  ),
                                )
                              // 展示搜索结果
                              else if (_currentPageResults.isNotEmpty)
                                Column(
                                  children: [
                                    // 搜索结果列表
                                    ..._currentPageResults
                                        .map((song) => _buildSongItem(song))
                                        .toList(),
                                  ],
                                )
                              // 初始状态
                              else
                                Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(screenHeight * 0.1),
                                    child: Text(
                                      '请输入搜索关键词',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: baseFontSize,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      // 分页控件
                      if (_totalPages > 1)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(8.0),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 3.0,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          margin: EdgeInsets.all(padding),
                          padding: EdgeInsets.symmetric(
                            vertical: screenHeight * 0.015,
                            horizontal: screenWidth * 0.05,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // 上一页按钮
                              IconButton(
                                onPressed: _currentPage > 1
                                    ? () => _goToPage(_currentPage - 1)
                                    : null,
                                icon: const Icon(Icons.chevron_left),
                              ),

                              // 页码显示
                              Text(
                                '$_currentPage / $_totalPages',
                                style: TextStyle(
                                  fontSize: smallFontSize,
                                  color: Colors.grey,
                                ),
                              ),

                              // 下一页按钮
                              IconButton(
                                onPressed: _currentPage < _totalPages
                                    ? () => _goToPage(_currentPage + 1)
                                    : null,
                                icon: const Icon(Icons.chevron_right),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 构建歌曲项
  Widget _buildSongItem(dynamic song) {
    // 生成曲绘路径
    String coverUrl = 'assets/cover/${song.id.toString()}.webp';

    // 生成匹配信息
    List<Map<String, String>> matchInfo = _getMatchInfo(song);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SongInfoPage(songId: song.id.toString()),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: Row(
          children: [
            // 曲绘
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Image.asset(
                coverUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // 生成网络曲绘URL
                  String coverId = song.id.toString();
                  if (coverId.length < 5) {
                    // 万位补1，其余位补0
                    coverId = '1' + '0' * (4 - coverId.length) + coverId;
                  }
                  String networkCoverUrl = 'https://www.diving-fish.com/covers/$coverId.png';
                  
                  return Image.network(
                    networkCoverUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Text(
                          '曲绘',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(width: 12),

            // 右侧信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 第一行：歌曲名和ID
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          song.basicInfo.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ID: ${song.id}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 第二行：版本、流派
                  Text(
                    '${_formatVersion(song.basicInfo.from)} | ${song.basicInfo.genre}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // 匹配信息
                  if (matchInfo.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: matchInfo
                          .map((info) => Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '${info['type']}：${info['value']}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.blue,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ))
                          .toList(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 获取匹配信息
  List<Map<String, String>> _getMatchInfo(dynamic song) {
    List<Map<String, String>> matchInfos = [];
    String query = _searchController.text.toLowerCase();
    if (query.isEmpty) return matchInfos;

    // 检查标题匹配
    if (song.basicInfo.title.toLowerCase().contains(query)) {
      matchInfos.add({'type': '歌名', 'value': song.basicInfo.title});
    }
    // 检查艺术家匹配
    if (song.basicInfo.artist.toLowerCase().contains(query)) {
      matchInfos.add({'type': '艺术家', 'value': song.basicInfo.artist});
    }
    // 检查BPM匹配
    if (song.basicInfo.bpm.toString().contains(query)) {
      matchInfos.add({'type': 'BPM', 'value': song.basicInfo.bpm.toString()});
    }
    // 检查谱师匹配
    for (var chart in song.charts) {
      if (chart.charter.toLowerCase().contains(query)) {
        matchInfos.add({'type': '谱师', 'value': chart.charter});
        break; // 只添加第一个匹配的谱师
      }
    }
    // 检查流派匹配
    if (song.basicInfo.genre.toLowerCase().contains(query)) {
      matchInfos.add({'type': '流派', 'value': song.basicInfo.genre});
    }
    // 检查版本匹配
    if (song.basicInfo.from.toLowerCase().contains(query)) {
      matchInfos
          .add({'type': '版本', 'value': _formatVersion(song.basicInfo.from)});
    }
    // 检查别名匹配
    final aliases = SongAliasManager.instance.aliases[song.id] ?? [];
    final matchingAliases =
        aliases.where((alias) => alias.toLowerCase().contains(query)).toList();
    if (matchingAliases.isNotEmpty) {
      matchInfos.add({'type': '别名', 'value': matchingAliases.join('，')});
    }
    return matchInfos;
  }

  // 处理版本字符串，使其在前端简化展示
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
}