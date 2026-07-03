import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/service/RandomChartService.dart';
import 'package:my_first_flutter_app/entity/DivingFish/Song.dart';
import 'package:my_first_flutter_app/utils/CoverUtil.dart';
import 'package:my_first_flutter_app/page/SongInfoPage.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:my_first_flutter_app/utils/StringUtil.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';

class RandomChartPage extends StatefulWidget {
  const RandomChartPage({super.key});

  @override
  State<RandomChartPage> createState() => _RandomChartPageState();
}

class _RandomChartPageState extends State<RandomChartPage> {
  final RandomChartService _service = RandomChartService();

  // 状态变量
  bool _isDrawing = false;
  List<Song> _drawnSongs = [];
  List<List<Song>> _history = [];

  // 筛选条件
  int _drawCount = 4;
  double? _minDs;
  double? _maxDs;
  List<String> _selectedVersions = [];
  List<String> _selectedGenres = [];
  bool _requireMaster = false;
  bool _excludeSixDigitId = false;

  // 版本和流派列表
  List<String> _versionList = [];
  List<String> _genreList = [];

  // 输入控制器
  final TextEditingController _minDsController = TextEditingController();
  final TextEditingController _maxDsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFilterOptions();
  }

  // 加载版本和流派列表
  Future<void> _loadFilterOptions() async {
    _versionList = await _service.getVersionList();
    _genreList = await _service.getGenreList();
    setState(() {});
  }

  // 执行抽奖
  Future<void> _drawSongs() async {
    setState(() {
      _isDrawing = true;
    });

    try {
      // 解析定数范围
      _minDs = _minDsController.text.isNotEmpty
          ? double.tryParse(_minDsController.text)
          : null;
      _maxDs = _maxDsController.text.isNotEmpty
          ? double.tryParse(_maxDsController.text)
          : null;

      // 随机抽取歌曲
      final songs = await _service.randomDrawSongs(
        count: _drawCount,
        minDs: _minDs,
        maxDs: _maxDs,
        versions: _selectedVersions.isEmpty ? null : _selectedVersions,
        genres: _selectedGenres.isEmpty ? null : _selectedGenres,
        requireMaster: _requireMaster,
        excludeSixDigitId: _excludeSixDigitId,
      );

      setState(() {
        _drawnSongs = songs;
        // 添加到历史记录
        if (songs.isNotEmpty) {
          _history.insert(0, songs);
          // 只保留最近5条历史记录
          if (_history.length > 5) {
            _history = _history.take(5).toList();
          }
        }
      });
    } catch (e) {
      debugPrint('抽奖失败: $e');
    } finally {
      setState(() {
        _isDrawing = false;
      });
    }
  }

  // 删除历史记录
  void _deleteHistory(int index) {
    setState(() {
      _history.removeAt(index);
    });
  }

  // 显示版本选择对话框
  void _showVersionSelector() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        List<String> tempSelected = List.from(_selectedVersions);
        
        return AlertDialog(
          title: Text('选择版本'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Container(
                width: double.maxFinite,
                height: 300,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // 全选/全不选按钮
                      Row(
                        children: [
                          Checkbox(
                            value: tempSelected.length == _versionList.length,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  tempSelected = List.from(_versionList);
                                } else {
                                  tempSelected.clear();
                                }
                              });
                            },
                          ),
                          Text('全选'),
                        ],
                      ),
                      Divider(),
                      // 版本列表
                      Column(
                        children: _versionList.map((version) {
                          return CheckboxListTile(
                            title: Text(StringUtil.formatVersion2(version)),
                            value: tempSelected.contains(version),
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  tempSelected.add(version);
                                } else {
                                  tempSelected.remove(version);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('取消'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedVersions = tempSelected;
                });
                Navigator.of(context).pop();
              },
              child: Text('确定'),
            ),
          ],
        );
      },
    );
  }

  // 显示类型选择对话框
  void _showGenreSelector() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        List<String> tempSelected = List.from(_selectedGenres);
        
        return AlertDialog(
          title: Text('选择类型'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Container(
                width: double.maxFinite,
                height: 300,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // 全选/全不选按钮
                      Row(
                        children: [
                          Checkbox(
                            value: tempSelected.length == _genreList.length,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  tempSelected = List.from(_genreList);
                                } else {
                                  tempSelected.clear();
                                }
                              });
                            },
                          ),
                          Text('全选'),
                        ],
                      ),
                      Divider(),
                      // 类型列表
                      Column(
                        children: _genreList.map((genre) {
                          return CheckboxListTile(
                            title: Text(genre),
                            value: tempSelected.contains(genre),
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  tempSelected.add(genre);
                                } else {
                                  tempSelected.remove(genre);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('取消'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedGenres = tempSelected;
                });
                Navigator.of(context).pop();
              },
              child: Text('确定'),
            ),
          ],
        );
      },
    );
  }

  // 曲绘加载使用CoverPathUtil工具类

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final screenWidth = MediaQuery.of(context).size.width;

    // 统一管理的尺寸变量
    final whiteAreaPadding = screenWidth * 0.04; // 白色区域内边距
    final cardPadding = screenWidth * 0.04; // 卡片内边距
    final borderRadius = screenWidth * 0.02; // 边框圆角
    final iconSize = screenWidth * 0.05; // 图标大小
    final textSizeLarge = screenWidth * 0.045; // 大字号
    final textSizeMedium = screenWidth * 0.035; // 中字号
    final textSizeSmall = screenWidth * 0.03; // 小字号
    final spacingSmall = screenWidth * 0.02; // 小间距
    final spacingMedium = screenWidth * 0.04; // 中间距
    final spacingLarge = screenWidth * 0.06; // 大间距
    final gridItemSpacing = screenWidth * 0.03; // 网格项间距

    // 自定义常量
    final double borderRadiusSmall = 8.0;
    final BoxShadow defaultShadow = AppColors.defaultShadow(brightness);

    return Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false, // 解决输入法挤压背景的问题
        body: Stack(children: [
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
                      icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    // 标题
                    Expanded(
                      child: Center(
                        child: Text(
                          '随机抽歌',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
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
                  margin: EdgeInsets.fromLTRB(8, 0, 8, 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(borderRadiusSmall),
                    boxShadow: [defaultShadow],
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(whiteAreaPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 筛选条件区域
                        Container(
                          padding: EdgeInsets.all(cardPadding),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(borderRadius),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '筛选条件',
                                style: TextStyle(
                                  fontSize: textSizeLarge,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: spacingMedium),

                              // 筛选条件三行布局
                              Column(
                                children: [
                                  // 第一行：抽取数量
                                  Row(
                                    children: [
                                      Text(
                                        '抽取数量',
                                        style: TextStyle(
                                          fontSize: textSizeSmall,
                                          color: AppColors.greyHint(brightness),
                                        ),
                                      ),
                                      SizedBox(width: spacingSmall),
                                      Row(
                                        children: [
                                          for (int i = 1; i <= 4; i++)
                                            GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  _drawCount = i;
                                                });
                                              },
                                              child: Container(
                                                width: screenWidth * 0.08,
                                                height: screenWidth * 0.08,
                                                margin: EdgeInsets.symmetric(
                                                    horizontal: spacingSmall),
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: _drawCount == i
                                                      ? AppColors.linkBlue(brightness)
                                                      : Colors.grey[200],
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    i.toString(),
                                                    style: TextStyle(
                                                      fontSize: textSizeSmall,
                                                      fontWeight: _drawCount ==
                                                              i
                                                          ? FontWeight.bold
                                                          : FontWeight.normal,
                                                      color: _drawCount == i
                                                          ? Colors.white
                                                          : Theme.of(context).colorScheme.onSurface,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: spacingMedium),

                                  // 第二行：版本筛选（单独一行）
                                  Container(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '版本筛选',
                                          style: TextStyle(
                                            fontSize: textSizeSmall,
                                            color: AppColors.greyHint(brightness),
                                          ),
                                        ),
                                        SizedBox(height: spacingSmall),
                                        InkWell(
                                          onTap: _showVersionSelector,
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: spacingSmall,
                                                vertical: spacingSmall),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                  color: AppColors.tableBorder(brightness)),
                                              borderRadius: BorderRadius.circular(
                                                  borderRadius),
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    _selectedVersions.isEmpty
                                                        ? '全部版本'
                                                        : '已选 ${_selectedVersions.length} 个版本',
                                                    style: TextStyle(
                                                        fontSize: textSizeSmall),
                                                  ),
                                                ),
                                                Icon(Icons.arrow_drop_down,
                                                    size: 16),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: spacingMedium),

                                  // 第三行：类型筛选（单独一行）
                                  Container(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '类型筛选',
                                          style: TextStyle(
                                            fontSize: textSizeSmall,
                                            color: AppColors.greyHint(brightness),
                                          ),
                                        ),
                                        SizedBox(height: spacingSmall),
                                        InkWell(
                                          onTap: _showGenreSelector,
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: spacingSmall,
                                                vertical: spacingSmall),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                  color: AppColors.tableBorder(brightness)),
                                              borderRadius: BorderRadius.circular(
                                                  borderRadius),
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    _selectedGenres.isEmpty
                                                        ? '全部类型'
                                                        : '已选 ${_selectedGenres.length} 个类型',
                                                    style: TextStyle(
                                                        fontSize: textSizeSmall),
                                                  ),
                                                ),
                                                Icon(Icons.arrow_drop_down,
                                                    size: 16),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: spacingMedium),

                                  // 第四行：定数范围
                                  Container(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '定数范围',
                                          style: TextStyle(
                                            fontSize: textSizeSmall,
                                            color: AppColors.greyHint(brightness),
                                          ),
                                        ),
                                        SizedBox(height: spacingSmall),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller: _minDsController,
                                                keyboardType:
                                                    TextInputType.number,
                                                decoration: InputDecoration(
                                                  hintText: '最小值',
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            borderRadius),
                                                  ),
                                                  contentPadding:
                                                      EdgeInsets.symmetric(
                                                          horizontal:
                                                              spacingSmall,
                                                          vertical:
                                                              spacingSmall * 1.5),
                                                ),
                                                style: TextStyle(
                                                    fontSize: textSizeSmall),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Text('-'),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: TextField(
                                                controller: _maxDsController,
                                                keyboardType:
                                                    TextInputType.number,
                                                decoration: InputDecoration(
                                                  hintText: '最大值',
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            borderRadius),
                                                  ),
                                                  contentPadding:
                                                      EdgeInsets.symmetric(
                                                          horizontal:
                                                              spacingSmall,
                                                          vertical:
                                                              spacingSmall * 1.5),
                                                ),
                                                style: TextStyle(
                                                    fontSize: textSizeSmall),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: spacingMedium),

                                  // 快捷选项
                                  Container(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '快捷选项',
                                          style: TextStyle(
                                            fontSize: textSizeSmall,
                                            color: AppColors.greyHint(brightness),
                                          ),
                                        ),
                                        SizedBox(height: spacingSmall),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed: () async {
                                                  debugPrint('[RandomChartPage] 点击MASTER上级快捷按钮');
                                                  // 确保版本和流派列表已加载
                                                  if (_versionList.isEmpty || _genreList.isEmpty) {
                                                    debugPrint('[RandomChartPage] 列表未加载，重新加载...');
                                                    await _loadFilterOptions();
                                                  }
                                                  debugPrint('[RandomChartPage] _versionList长度: ${_versionList.length}');
                                                  debugPrint('[RandomChartPage] _genreList长度: ${_genreList.length}');
                                                  setState(() {
                                                    _minDsController.text = '13.2';
                                                    _maxDsController.text = '14.4';
                                                    _requireMaster = true;
                                                    _excludeSixDigitId = true;
                                                    // 自动选中所有版本
                                                    _selectedVersions = List.from(_versionList);
                                                    // 自动选中所有类型，排除"\u5bb4\u4f1a\u5834"
                                                    _selectedGenres = _genreList.where((genre) => genre != '\u5bb4\u4f1a\u5834').toList();
                                                  });
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppColors.linkBlue(brightness).withValues(alpha: 0.3),
                                                  foregroundColor: AppColors.linkBlue(brightness),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            borderRadius),
                                                  ),
                                                  padding: EdgeInsets.symmetric(
                                                      vertical: spacingSmall),
                                                ),
                                                child: Text(
                                                  'MASTER 上级',
                                                  style: TextStyle(
                                                      fontSize: textSizeSmall,
                                                      fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: spacingSmall),
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed: () async {
                                                  debugPrint('[RandomChartPage] 点击MASTER超上级快捷按钮');
                                                  // 确保版本和流派列表已加载
                                                  if (_versionList.isEmpty || _genreList.isEmpty) {
                                                    debugPrint('[RandomChartPage] 列表未加载，重新加载...');
                                                    await _loadFilterOptions();
                                                  }
                                                  setState(() {
                                                    _minDsController.text = '14.5';
                                                    _maxDsController.text = '14.9';
                                                    _requireMaster = true;
                                                    _excludeSixDigitId = true;
                                                    // 自动选中所有版本
                                                    _selectedVersions = List.from(_versionList);
                                                    // 自动选中所有类型，排除"\u5bb4\u4f1a\u5834"
                                                    _selectedGenres = _genreList.where((genre) => genre != '\u5bb4\u4f1a\u5834').toList();
                                                  });
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppColors.linkBlue(brightness).withValues(alpha: 0.3),
                                                  foregroundColor: AppColors.linkBlue(brightness),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            borderRadius),
                                                  ),
                                                  padding: EdgeInsets.symmetric(
                                                      vertical: spacingSmall),
                                                ),
                                                child: Text(
                                                  'MASTER 超上级',
                                                  style: TextStyle(
                                                      fontSize: textSizeSmall,
                                                      fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: spacingMedium),

                                  // 抽奖按钮
                                  ElevatedButton(
                                    onPressed: _isDrawing ? null : _drawSongs,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.linkBlue(brightness),
                                      padding: EdgeInsets.symmetric(
                                          vertical: spacingMedium),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(borderRadius),
                                      ),
                                    ),
                                    child: _isDrawing
                                        ? Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              SizedBox(
                                                width: iconSize,
                                                height: iconSize,
                                                child:
                                                    const CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2,
                                                ),
                                              ),
                                              SizedBox(width: spacingSmall),
                                              Text(
                                                '抽奖中...',
                                                style: TextStyle(
                                                  fontSize: textSizeMedium,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          )
                                        : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(Icons.refresh),
                                              SizedBox(width: spacingSmall),
                                              Text(
                                                '开始抽奖',
                                                style: TextStyle(
                                                  fontSize: textSizeMedium,
                                                  fontWeight: FontWeight.bold,
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

                        SizedBox(height: spacingLarge),

                        // 歌曲抽取区域
                        Container(
                          padding: EdgeInsets.all(cardPadding),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(borderRadius),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 抽取结果标题
                              Text(
                                '抽取结果',
                                style: TextStyle(
                                  fontSize: textSizeLarge,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              SizedBox(height: spacingLarge),

                               // 歌曲展示区（一行显示，不滚动）
                              Container(
                                height: screenWidth * 0.3, // 减小高度
                                child: Row(
                                  children: [
                                    for (int i = 0; i < _drawCount; i++)
                                      Expanded(
                                        child: Container(
                                          margin: EdgeInsets.symmetric(
                                              horizontal: gridItemSpacing / 2),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                            borderRadius: BorderRadius.circular(
                                                borderRadius),
                                          ),
                                          child: _drawnSongs.length > i
                                              ? Column(
                                                  children: [
                                                    // 正方形曲绘
                                                    AspectRatio(
                                                      aspectRatio: 1, // 保持正方形
                                                      child: GestureDetector(
                                                        onTap: () {
                                                          Navigator.push(
                                                            context,
                                                            MaterialPageRoute(
                                                              builder: (context) =>
                                                                  SongInfoPage(
                                                                songId: _drawnSongs[
                                                                        i]
                                                                    .id
                                                                    .toString(),
                                                                initialLevelIndex:
                                                                    0,
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                        child: Container(
                                                          decoration:
                                                              BoxDecoration(
                                                            borderRadius:
                                                                BorderRadius.vertical(
                                                                    top: Radius
                                                                        .circular(
                                                                            borderRadius)),
                                                          ),
                                                          child: CoverUtil
                                                              .buildCoverWidgetWithContext(
                                                                  context,
                                                                  _drawnSongs[i]
                                                                      .id,
                                                                  100),
                                                        ),
                                                      ),
                                                    ),
                                                    // 文本部分
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              8.0),
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .stretch,
                                                        children: [
                                                          Text(
                                                            _drawnSongs[i]
                                                                .basicInfo
                                                                .title,
                                                            style: TextStyle(
                                                              fontSize:
                                                                  textSizeSmall,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                          Text(
                                                            'ID: ${_drawnSongs[i].id}',
                                                            style: TextStyle(
                                                              fontSize:
                                                                  textSizeSmall *
                                                                      0.8,
                                                              color:
                                                                  AppColors.greyHint(brightness),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              : Container(
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            borderRadius),
                                                  ),
                                                  child: const Center(
                                                    child: Text('点击抽奖'),
                                                  ),
                                                ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              SizedBox(height: spacingLarge),
                            ],
                          ),
                        ),

                        SizedBox(height: spacingLarge),

                        // 历史记录区域
                        Container(
                          padding: EdgeInsets.all(cardPadding),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(borderRadius),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '历史抽取记录',
                                style: TextStyle(
                                  fontSize: textSizeLarge,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: spacingMedium),
                              if (_history.isEmpty)
                                const Center(
                                  child: Text('暂无历史记录'),
                                )
                              else
                                Column(
                                  children:
                                      _history.asMap().entries.map((entry) {
                                    int index = entry.key;
                                    List<Song> songs = entry.value;

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                '${DateTime.now().toString().substring(0, 16)}',
                                                style: TextStyle(
                                                  fontSize: textSizeSmall,
                                                  color: AppColors.greyHint(brightness),
                                                ),
                                              ),
                                              IconButton(
                                                onPressed: () =>
                                                    _deleteHistory(index),
                                                icon: const Icon(Icons.delete),
                                                iconSize: iconSize * 0.8,
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: spacingSmall),
                                          GridView.count(
                                            shrinkWrap: true,
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            crossAxisCount: 4,
                                            crossAxisSpacing:
                                                gridItemSpacing * 0.8,
                                            mainAxisSpacing:
                                                gridItemSpacing * 0.8,
                                            children: songs.map((song) {
                                              return GestureDetector(
                                                onTap: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          SongInfoPage(
                                                        songId:
                                                            song.id.toString(),
                                                        initialLevelIndex: 0,
                                                      ),
                                                    ),
                                                  );
                                                },
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            borderRadius),
                                                  ),
                                                  child: CoverUtil
                                                      .buildCoverWidgetWithContext(
                                                          context, song.id, 50),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
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
        ]));
  }
}