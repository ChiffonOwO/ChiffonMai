import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/manager/DivingFish/MaimaiMusicDataManager.dart';
import 'package:my_first_flutter_app/service/SongSearchService.dart';
import 'package:my_first_flutter_app/page/SongInfoPage.dart';
import 'package:my_first_flutter_app/manager/SongAliasManager.dart';
import 'package:my_first_flutter_app/manager/MaiTagsManager.dart';
import 'package:my_first_flutter_app/entity/DXRating/MaiTagsEntity.dart';
import 'dart:async';

import 'package:my_first_flutter_app/utils/CoverUtil.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:my_first_flutter_app/utils/StringUtil.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:my_first_flutter_app/constant/VersionListConstant.dart';
import 'package:my_first_flutter_app/constant/GenreListConstant.dart';

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
  bool _showTagFilter = false;
  bool _showAllFilters = true; // 控制是否显示所有筛选区域
  List<String> _selectedVersions = [];
  List<String> _selectedGenres = [];
  List<int> _selectedTagIds = [];
  
  // 标签数据
  Map<int, String> _tagIdToNameMap = {};
  Map<int, (String, int)> _tagIdToInfoMap = {};
  List<TagGroupItem> _tagGroups = [];
  bool _isLoadingTags = false;
  
  // 歌曲标签信息缓存
  Map<String, List<String>> _songTagInfoCache = {};
  MaiTagsEntity? _cachedTagsEntity;

  // 版本列表
  List<String> _versionList = VersionListConstant.versionOrderList;

  // 流派列表
  List<String> _genreList = GenreListConstant.genreList;

  @override
  void initState() {
    super.initState();
    _loadTagData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _minLevelController.dispose();
    _maxLevelController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  // 加载标签数据
  Future<void> _loadTagData() async {
    setState(() {
      _isLoadingTags = true;
    });
    try {
      final maiTagsEntity = await MaiTagsManager().getTags();
      if (maiTagsEntity != null) {
        _tagGroups = maiTagsEntity.tagGroups;
        _tagIdToNameMap = await MaiTagsManager().getTagIdToNameMap();
        _tagIdToInfoMap = await MaiTagsManager().getTagIdToInfoMap();
      }
    } catch (e) {
      debugPrint('加载标签数据失败: $e');
    } finally {
      setState(() {
        _isLoadingTags = false;
      });
    }
  }

  // 执行搜索
  Future<void> _performSearch(String query) async {
    // 检查是否所有筛选条件都为空
    bool allFiltersEmpty = query.isEmpty &&
        _minLevelController.text.isEmpty &&
        _maxLevelController.text.isEmpty &&
        _selectedVersions.isEmpty &&
        _selectedGenres.isEmpty &&
        _selectedTagIds.isEmpty;

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
        results = await MaimaiMusicDataManager().getCachedSongs() ?? [];
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

      // 应用标签筛选
      if (_selectedTagIds.isNotEmpty) {
        debugPrint('=== 标签筛选开始 ===');
        debugPrint('所选标签ID: $_selectedTagIds');
        
        // 获取标签数据
        final maiTagsManager = MaiTagsManager();
        final tagsEntity = await maiTagsManager.getTags();
        
        // 缓存标签数据供后续使用
        _cachedTagsEntity = tagsEntity;
        
        if (tagsEntity != null) {
          debugPrint('标签数据加载成功，tagSongs数量: ${tagsEntity.tagSongs.length}');
          
          // 预构建高效的搜索映射：(songId, sheetType, sheetDifficulty) -> List<tagId>
          Map<String, Set<int>> tagMap = {};
          for (var tagSong in tagsEntity.tagSongs) {
            String key = '${tagSong.songId}|${tagSong.sheetType}|${tagSong.sheetDifficulty}';
            if (!tagMap.containsKey(key)) {
              tagMap[key] = {};
            }
            tagMap[key]!.add(tagSong.tagId);
          }
          debugPrint('构建了 ${tagMap.length} 个谱面的标签映射');
          
          // 构建所选标签的集合
          Set<int> selectedTagSet = Set.from(_selectedTagIds);
          
          // 获取标签名称映射
          final tagIdToNameMap = await maiTagsManager.getTagIdToNameMap();
          
          // 清空并重建歌曲标签信息缓存
          _songTagInfoCache.clear();
          
          int matchCount = 0;
          filteredResults = filteredResults.where((song) {
            // 获取歌曲标题和类型
            final String songTitle = song.basicInfo.title;
            
            // 根据歌曲类型确定sheetType（支持std, dx, utage）
            String sheetType;
            if (song.type == 'DX') {
              sheetType = 'dx';
            } else if (song.id.length == 6) {
              // UTAGE歌曲的ID长度为6
              sheetType = 'utage';
            } else {
              sheetType = 'std';
            }
            
            // 为当前歌曲构建标签信息
            List<String> tagInfoList = [];
            
            // 遍历所有难度，检查是否有匹配的标签（根据难度索引确定难度名称）
            for (int i = 0; i < song.level.length; i++) {
              // 根据难度索引确定难度名称
              String sheetDifficulty = _getDifficultyByIndex(i);
              String difficultyDisplayName = _getDifficultyDisplayName(i);
              
              // 构建查找键
              String key = '$songTitle|$sheetType|$sheetDifficulty';
              Set<int>? tagIds = tagMap[key];
              
              if (tagIds != null && tagIds.isNotEmpty) {
                // 构建该难度的标签信息（只显示用户所选的标签）
                List<String> tagNames = [];
                for (int tagId in tagIds) {
                  if (selectedTagSet.contains(tagId)) {
                    String? tagName = tagIdToNameMap[tagId];
                    if (tagName != null) {
                      tagNames.add(tagName);
                    }
                  }
                }
                
                if (tagNames.isNotEmpty) {
                  tagInfoList.add('${difficultyDisplayName}：${tagNames.join('、')}');
                }
                
                // 检查是否有交集
                for (int tagId in selectedTagSet) {
                  if (tagIds.contains(tagId)) {
                    matchCount++;
                    debugPrint('匹配成功: 歌曲[$songTitle], 类型[$sheetType], 难度[$sheetDifficulty], 标签ID[$tagId]');
                    // 缓存标签信息
                    _songTagInfoCache[songTitle] = tagInfoList;
                    return true;
                  }
                }
              }
            }
            
            // 即使不匹配筛选条件，也缓存标签信息
            if (tagInfoList.isNotEmpty) {
              _songTagInfoCache[songTitle] = tagInfoList;
            }
            
            return false;
          }).toList();
          
          debugPrint('标签筛选完成，匹配到 $matchCount 首歌曲');
        } else {
          debugPrint('标签数据加载失败！');
          filteredResults = [];
        }
        
        debugPrint('=== 标签筛选结束 ===');
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
                      color: Theme.of(context).colorScheme.onSurface,
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
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        _selectedVersions.map((v) => StringUtil.formatVersion(v)).join(', ');

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
                      color: Theme.of(context).colorScheme.onSurface,
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
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                    StringUtil.formatVersion2(version),
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
                      color: Theme.of(context).colorScheme.onSurface,
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
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
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

  // 构建标签筛选组件
  Widget _buildTagFilter(double screenWidth, double screenHeight) {
    // 生成已选内容文本
    String selectedTagsText = _selectedTagIds
        .map((tagId) => _tagIdToNameMap[tagId] ?? '未知标签')
        .join(', ');

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
                    '标签筛选',
                    style: TextStyle(
                      fontSize: screenWidth * 0.035,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  if (selectedTagsText.isNotEmpty)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: screenWidth * 0.02),
                        child: Text(
                          selectedTagsText,
                          style: TextStyle(
                            fontSize: screenWidth * 0.03,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                _showTagFilter ? Icons.expand_less : Icons.expand_more,
                size: screenWidth * 0.04,
              ),
              onPressed: () {
                setState(() {
                  _showTagFilter = !_showTagFilter;
                });
              },
            ),
          ],
        ),
        if (_showTagFilter)
          Container(
            padding: EdgeInsets.symmetric(vertical: screenHeight * 0.01),
            child: _isLoadingTags
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(screenHeight * 0.02),
                      child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  )
                : _tagGroups.isEmpty
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(screenHeight * 0.02),
                          child: Text(
                            '暂无标签数据',
                            style: TextStyle(
                              fontSize: screenWidth * 0.03,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: _tagGroups.length,
                        itemBuilder: (context, groupIndex) {
                          TagGroupItem group = _tagGroups[groupIndex];
                          // 获取该分组下的所有标签
                          List<int> tagsInGroup = _tagIdToInfoMap.entries
                              .where((entry) => entry.value.$2 == group.id)
                              .map((entry) => entry.key)
                              .toList();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 分组标题
                              Padding(
                                padding: EdgeInsets.only(
                                  top: groupIndex == 0 ? 0 : screenHeight * 0.005,
                                  bottom: screenHeight * 0.008,
                                ),
                                child: Text(
                                  group.localizedName.zhHans,
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.032,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              // 分组下的标签
                              Wrap(
                                spacing: screenWidth * 0.02,
                                runSpacing: screenHeight * 0.008,
                                children: tagsInGroup.map((tagId) {
                                  String tagName = _tagIdToNameMap[tagId] ?? '未知标签';
                                  return FilterChip(
                                    label: Text(
                                      tagName,
                                      style: TextStyle(fontSize: screenWidth * 0.028),
                                    ),
                                    selected: _selectedTagIds.contains(tagId),
                                    onSelected: (selected) {
                                      setState(() {
                                        if (selected) {
                                          _selectedTagIds.add(tagId);
                                        } else {
                                          _selectedTagIds.remove(tagId);
                                        }
                                      });
                                      // 防抖筛选
                                      _debouncedFilter();
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          );
                        },
                      ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final screenWidth = MediaQuery.of(context).size.width;

    final Color textPrimaryColor = Theme.of(context).colorScheme.onSurface;
    final Color cardBgColor = Theme.of(context).colorScheme.surface.withOpacity(0.9);
    final BoxShadow defaultShadow = AppColors.defaultShadow(brightness);
    final double borderRadiusSmall = 8.0;

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
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '歌曲搜索',
                          style: TextStyle(
                            color: textPrimaryColor,
                            fontSize: screenWidth * 0.06,
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
                    borderRadius: BorderRadius.circular(borderRadiusSmall),
                    boxShadow: [defaultShadow],
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
                                hintText: '输入歌曲标题、艺术家、BPM、谱师、别名、歌曲ID',
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

                                    // 标签筛选
                                    _buildTagFilter(screenWidth, screenHeight),
                                    SizedBox(height: screenHeight * 0.01),
                                  ],
                                ),

                              // 搜索结果数量显示
                              if ((_searchController.text.isNotEmpty ||
                                      _selectedVersions.isNotEmpty ||
                                      _selectedGenres.isNotEmpty ||
                                      _selectedTagIds.isNotEmpty ||
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
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                                              _selectedTagIds.clear();
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
                                            backgroundColor: AppColors.errorRed(brightness),
                                            foregroundColor: Colors.white,
                                          ),
                                          child: Text(
                                            '重置',
                                            style: TextStyle(fontSize: tinyFontSize),
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
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                        SizedBox(height: screenHeight * 0.02),
                                        Text(
                                          '正在搜索...',
                                          style: TextStyle(fontSize: baseFontSize, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                                          color: AppColors.errorRed(brightness),
                                          size: screenWidth * 0.12,
                                        ),
                                        SizedBox(height: screenHeight * 0.02),
                                        Text(
                                          _errorMessage!,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: AppColors.errorRed(brightness),
                                            fontSize: baseFontSize,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else if (_allSearchResults.isEmpty &&
                                  _searchController.text.isNotEmpty)
                                Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(screenHeight * 0.1),
                                    child: Text(
                                      '未找到匹配的歌曲',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                            color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(8.0),
                            boxShadow: [AppColors.defaultShadow(brightness)],
                          ),
                          margin: EdgeInsets.all(padding),
                          padding: EdgeInsets.symmetric(
                            vertical: screenHeight * 0.008,
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
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        ],
      )
    );
  }

  // 构建歌曲项
  Widget _buildSongItem(dynamic song) {
    final brightness = Theme.of(context).brightness;

    // 生成匹配信息
    List<Map<String, String>> matchInfo = _getMatchInfo(song);
    
    // 获取标签信息
    List<String> tagInfoList = _getTagInfoForSong(song);

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
          border: Border.all(color: brightness == Brightness.dark ? Colors.grey.shade700 : Colors.grey.shade200),
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).colorScheme.surface,
        ),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade100,
                border: Border.all(color: brightness == Brightness.dark ? Colors.grey.shade700 : Colors.grey.shade200),
                borderRadius: BorderRadius.circular(4),
              ),
              child: CoverUtil.buildCoverWidget(song.id, 80),
              // child: Image.asset(
              //   coverUrl,
              //   fit: BoxFit.cover,
              //   errorBuilder: (context, error, stackTrace) {
              //     // 生成网络曲绘URL
              //     String coverId = song.id.toString();
                  
              //     // 对于6位数的曲绘，只需要去除第一位
              //     if (coverId.length == 6) {
              //       // 去掉第一位
              //       coverId = coverId.substring(1);
              //     } else if (coverId.length < 5) {
              //       // 万位补1，其余位补0
              //       coverId = '1' + '0' * (4 - coverId.length) + coverId;
              //     }
              //     String networkCoverUrl = 'https://www.diving-fish.com/covers/$coverId.png';
                  
              //     return Image.network(
              //       networkCoverUrl,
              //       fit: BoxFit.cover,
              //       errorBuilder: (context, error, stackTrace) {
              //         return Center(
              //           child: Text(
              //             '曲绘',
              //             style: TextStyle(
              //               fontSize: 14,
              //               color: Theme.of(context).colorScheme.onSurfaceVariant,
              //             ),
              //           ),
              //         );
              //       },
              //     );
              //   },
              // ),
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
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ID: ${song.id}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Text(
                        song.id.toString().length == 6 ? 'UTAGE' : (song.type == 'SD' ? 'ST' : 'DX'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: song.id.toString().length == 6 ? const Color(0xFFFF6B8B) : (song.type == 'SD' ? AppColors.linkBlue(brightness) : AppColors.warningOrange(brightness)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 版本和流派
                      Expanded(
                        child: Text(
                          '${StringUtil.formatVersion(song.basicInfo.from)} | ${song.basicInfo.genre}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
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
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.linkBlue(brightness),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ))
                          .toList(),
                    ),
                  
                  if (tagInfoList.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: tagInfoList
                          .map((tagInfo) => Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  tagInfo,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.linkBlue(brightness),
                                  ),
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

  // 获取歌曲的标签信息（显示每个难度与用户所选标签的交集）
  List<String> _getTagInfoForSong(dynamic song) {
    List<String> tagInfoList = [];
    
    // 如果没有缓存的标签实体，返回空
    if (_cachedTagsEntity == null) {
      return tagInfoList;
    }
    
    // 如果没有选择任何标签，返回空
    if (_selectedTagIds.isEmpty) {
      return tagInfoList;
    }
    
    // 构建所选标签的集合
    Set<int> selectedTagSet = Set.from(_selectedTagIds);
    
    // 获取标签名称映射
    Map<int, String> tagIdToNameMap = {};
    for (var tag in _cachedTagsEntity!.tags) {
      tagIdToNameMap[tag.id] = tag.localizedName.zhHans;
    }
    
    // 获取歌曲信息
    final String songTitle = song.basicInfo.title;
    String sheetType;
    if (song.type == 'DX') {
      sheetType = 'dx';
    } else if (song.id.length == 6) {
      sheetType = 'utage';
    } else {
      sheetType = 'std';
    }
    
    // 遍历所有难度，获取与所选标签的交集
    for (int i = 0; i < song.level.length; i++) {
      String sheetDifficulty = _getDifficultyByIndex(i);
      
      // 查找当前谱面的标签
      final List<TagSongItem> tagSongs = _cachedTagsEntity!.tagSongs
          .where((tagSong) =>
              tagSong.songId == songTitle &&
              tagSong.sheetType == sheetType &&
              tagSong.sheetDifficulty == sheetDifficulty)
          .toList();
      
      if (tagSongs.isNotEmpty) {
        // 获取该难度下与所选标签的交集
        List<String> tagNames = [];
        for (var tagSong in tagSongs) {
          if (selectedTagSet.contains(tagSong.tagId)) {
            String? tagName = tagIdToNameMap[tagSong.tagId];
            if (tagName != null) {
              tagNames.add(tagName);
            }
          }
        }
        
        // 如果有交集，显示该难度的标签信息
        if (tagNames.isNotEmpty) {
          String difficultyName = _getDifficultyDisplayName(i);
          tagInfoList.add('${difficultyName}：${tagNames.join('、')}');
        }
      }
    }
    
    return tagInfoList;
  }
  
  // 获取难度显示名称
  String _getDifficultyDisplayName(int index) {
    switch (index) {
      case 0:
        return 'Basic';
      case 1:
        return 'Advanced';
      case 2:
        return 'Expert';
      case 3:
        return 'Master';
      case 4:
        return 'Re:Master';
      default:
        return 'Unknown';
    }
  }
  
  // 获取匹配信息
  List<Map<String, String>> _getMatchInfo(dynamic song) {
    List<Map<String, String>> matchInfos = [];
    String query = _searchController.text.toLowerCase();
    if (query.isEmpty) return matchInfos;

    // 检查歌曲ID匹配
    if (song.id.toString() == _searchController.text) {
      matchInfos.add({'type': '歌曲ID', 'value': song.id.toString()});
    }
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
          .add({'type': '版本', 'value': StringUtil.formatVersion(song.basicInfo.from)});
    }
    // 检查别名匹配
    final aliases = SongAliasManager.instance.aliases[song.title] ?? [];
    final matchingAliases =
        aliases.where((alias) => alias.toLowerCase().contains(query)).toList();
    if (matchingAliases.isNotEmpty) {
      matchInfos.add({'type': '别名', 'value': matchingAliases.join('，')});
    }
    return matchInfos;
  }

  // 根据难度索引获取难度名称（标签数据中使用的格式）
  String _getDifficultyByIndex(int index) {
    switch (index) {
      case 0:
        return 'basic';
      case 1:
        return 'advanced';
      case 2:
        return 'expert';
      case 3:
        return 'master';
      case 4:
        return 'remaster';
      default:
        return 'unknown';
    }
  }
}