import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/service/RandomChartService.dart';
import 'package:my_first_flutter_app/entity/Song.dart';
import 'package:my_first_flutter_app/utils/CoverUtil.dart';
import 'package:my_first_flutter_app/page/SongInfoPage.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';

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
  String _selectedVersion = '全部版本';
  String _selectedGenre = '全部类型';

  // 版本和流派列表
  List<String> _versionList = ['全部版本'];
  List<String> _genreList = ['全部类型'];

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
        version: _selectedVersion,
        genre: _selectedGenre,
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
      print('抽奖失败: $e');
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

  // 曲绘加载使用CoverPathUtil工具类

  @override
  Widget build(BuildContext context) {
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
    final Color textPrimaryColor = Color.fromARGB(255, 84, 97, 97);
    final double borderRadiusSmall = 8.0;
    final BoxShadow defaultShadow = BoxShadow(
      color: Colors.grey.withOpacity(0.5),
      spreadRadius: 2,
      blurRadius: 5,
      offset: Offset(0, 3),
    );

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
                      icon: Icon(Icons.arrow_back, color: textPrimaryColor),
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
                            color: textPrimaryColor,
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
                    color: Colors.white.withOpacity(0.9),
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
                            color: Colors.grey[100],
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
                                          color: Colors.grey,
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
                                                      ? Colors.blue
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
                                                          : Colors.black,
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
                                            color: Colors.grey,
                                          ),
                                        ),
                                        SizedBox(height: spacingSmall),
                                        DropdownButtonFormField<String>(
                                          value: _selectedVersion,
                                          items: _versionList.map((version) {
                                            return DropdownMenuItem<String>(
                                              value: version,
                                              child: Text(
                                                version,
                                                style: TextStyle(
                                                    fontSize: textSizeSmall),
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (value) {
                                            setState(() {
                                              _selectedVersion = value!;
                                            });
                                          },
                                          decoration: InputDecoration(
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      borderRadius),
                                            ),
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                    horizontal: spacingSmall,
                                                    vertical: spacingSmall),
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
                                            color: Colors.grey,
                                          ),
                                        ),
                                        SizedBox(height: spacingSmall),
                                        DropdownButtonFormField<String>(
                                          value: _selectedGenre,
                                          items: _genreList.map((genre) {
                                            return DropdownMenuItem<String>(
                                              value: genre,
                                              child: Text(
                                                genre,
                                                style: TextStyle(
                                                    fontSize: textSizeSmall),
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (value) {
                                            setState(() {
                                              _selectedGenre = value!;
                                            });
                                          },
                                          decoration: InputDecoration(
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      borderRadius),
                                            ),
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                    horizontal: spacingSmall,
                                                    vertical: spacingSmall),
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
                                            color: Colors.grey,
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
                                                              spacingSmall),
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
                                                              spacingSmall),
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

                                  // 抽奖按钮
                                  ElevatedButton(
                                    onPressed: _isDrawing ? null : _drawSongs,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
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
                            color: Colors.grey[100],
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
                                            color: Colors.grey[200],
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
                                                                  Colors.grey,
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
                            color: Colors.grey[100],
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
                                                  color: Colors.grey,
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
                                                    color: Colors.grey[200],
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
