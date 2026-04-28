import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';
import '../service/KnowledgeInfoService.dart';
import '../entity/KnowledgeEntity.dart';
import '../utils/CommonWidgetUtil.dart';
import '../utils/ColorUtil.dart';
import '../utils/CoverUtil.dart';
import '../manager/MaimaiMusicDataManager.dart';
import '../manager/UserPlayDataManager.dart';
import '../entity/Song.dart';
import '../entity/RecordItem.dart';
import 'SongInfoPage.dart';

class KnowledgeInfoPage extends StatefulWidget {
  final String? knowledgeId;
  final String? knowledgeTitle;

  const KnowledgeInfoPage({
    Key? key,
    this.knowledgeId,
    this.knowledgeTitle,
  }) : super(key: key);

  @override
  _KnowledgeInfoPageState createState() => _KnowledgeInfoPageState();
}

class _KnowledgeInfoPageState extends State<KnowledgeInfoPage> {
  final KnowledgeInfoService _infoService = KnowledgeInfoService();
  final MaimaiMusicDataManager _musicManager = MaimaiMusicDataManager();
  final UserPlayDataManager _playDataManager = UserPlayDataManager();
  KnowledgeItem? _knowledgeItem;
  List<Song>? _cachedSongs;
  List<RecordItem>? _recordItems;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // 加载所有数据
  Future<void> _loadData() async {
    await Future.wait([
      _loadKnowledgeInfo(),
      _loadCachedSongs(),
      _loadRecordItems(),
    ]);
  }

  // 加载缓存的歌曲数据
  Future<void> _loadCachedSongs() async {
    try {
      // 检查是否有缓存数据
      bool hasCache = await _musicManager.hasCachedData();
      if (!hasCache) {
        // 如果没有缓存，尝试从API获取
        await _musicManager.fetchAndUpdateMusicData();
      }
      // 获取缓存的歌曲数据
      _cachedSongs = await _musicManager.getCachedSongs();
    } catch (e) {
      print('加载缓存歌曲数据失败: $e');
    }
  }

  // 加载用户游玩数据
  Future<void> _loadRecordItems() async {
    try {
      // 从缓存获取用户游玩数据
      final playData = await _playDataManager.getCachedUserPlayData();
      if (playData != null && playData['records'] is List) {
        // 解析records数组为RecordItem列表
        _recordItems = (playData['records'] as List)
            .map((record) => RecordItem.fromJson(record))
            .toList();
      }
    } catch (e) {
      print('加载用户游玩数据失败: $e');
    }
  }

  // 加载知识详情
  Future<void> _loadKnowledgeInfo() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      KnowledgeItem? item;
      if (widget.knowledgeId != null) {
        item = await _infoService.getKnowledgeById(widget.knowledgeId!);
      } else if (widget.knowledgeTitle != null) {
        item = await _infoService.getKnowledgeByTitle(widget.knowledgeTitle!);
      }

      setState(() {
        _knowledgeItem = item;
        _isLoading = false;
        if (item == null) {
          _errorMessage = '未找到知识详情';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = '加载知识详情失败';
        _isLoading = false;
      });
    }
  }

  // 跳转到歌曲详情页面
  void _navigateToSong(String songId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SongInfoPage(
          songId: songId,
        ),
      ),
    );
  }

  // 构建游戏卡片（曲绘在左，数据在右）
  Widget _buildGameCard({
    required Color cardColor,
    String songName = '未知歌曲',
    double achievementRate = 0.0,
    double difficulty = 0.0,
    bool dxMode = false,
    bool isUtage = false,
    int score = 0,
    int rating = 0,
    String stars = '',
    String grade = '',
    int? songId,
  }) {
    // 计算卡片宽度，确保显示为2列
    double screenWidth = MediaQuery.of(context).size.width;
    double cardWidth = (screenWidth - 64) / 2; // 64 = 16*4 (左右边距和中间间距)
    
    return GestureDetector(
      onTap: () => _navigateToSong(songId?.toString() ?? ''),
      child: Container(
        width: cardWidth,
        decoration: BoxDecoration(
          color: cardColor,
          border: Border.all(color: Colors.black, width: 2.0),
          borderRadius: BorderRadius.circular(8.0),
        ),
        padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.02),
        child: LayoutBuilder(
          builder: (context, constraints) {
            double screenWidth = MediaQuery.of(context).size.width;

            // 根据宽度动态调整字体大小
            double songNameFontSize = screenWidth * 0.035;
            double decimalMainFontSize = screenWidth * 0.04;
            double decimalSmallFontSize = screenWidth * 0.03;
            double otherFontSize = screenWidth * 0.025;
            double dxFontSize = screenWidth * 0.025;

            double coverSize = screenWidth * 0.12;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 左侧：曲绘
                Container(
                  width: coverSize,
                  height: coverSize,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black, width: 1.0),
                  ),
                  child: songId != null
                      ? CoverUtil.buildCoverWidgetWithContext(context, songId.toString(), coverSize)
                      : Center(
                          child: Text('曲绘',
                              style: TextStyle(fontSize: coverSize * 0.24)),
                        ),
                ),
                SizedBox(width: screenWidth * 0.02),
                // 右侧：数据
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 歌名
                      Text(
                        songName,
                        style: TextStyle(
                          fontSize: songNameFontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.left,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: screenWidth * 0.005),
                      // 歌曲类型和难度
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isUtage)
                            Text(
                              'UT',
                              style: TextStyle(
                                fontSize: dxFontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          if (dxMode && !isUtage)
                            Text(
                              'DX',
                              style: TextStyle(
                                fontSize: dxFontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          if (!dxMode && !isUtage)
                            Text(
                              'ST',
                              style: TextStyle(
                                fontSize: dxFontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade300,
                              ),
                            ),
                          SizedBox(width: screenWidth * 0.01),
                          // 难度显示
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                difficulty.toString().split('.')[0],
                                style: TextStyle(
                                  fontSize: decimalMainFontSize * 0.9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              if (difficulty.toString().split('.').length > 1)
                                Text(
                                  '.${difficulty.toString().split('.')[1]}',
                                  style: TextStyle(
                                    fontSize: decimalSmallFontSize * 0.9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: screenWidth * 0.005),
                      // 达成率
                      Text(
                        '达成率: ${achievementRate.toStringAsFixed(2)}%',
                        style: TextStyle(
                          fontSize: otherFontSize,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // 自定义常量
  final Color textPrimaryColor = Color.fromARGB(255, 84, 97, 97);
  final Color themeColor = Colors.blue;
  final double borderRadiusSmall = 8.0;
  final BoxShadow defaultShadow = BoxShadow(
    color: Colors.grey.withOpacity(0.5),
    spreadRadius: 2,
    blurRadius: 5,
    offset: Offset(0, 3),
  );

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false, // 防止键盘弹出时调整布局
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
                          '知识详情',
                          style: TextStyle(
                            color: textPrimaryColor,
                            fontSize: screenWidth * 0.06,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // 占位按钮
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.transparent),
                      onPressed: () {},
                    ),
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
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator())
                      : _errorMessage.isNotEmpty
                          ? Center(
                              child: Text(_errorMessage,
                                  style: TextStyle(color: Colors.red)))
                          : _knowledgeItem == null
                              ? Center(child: Text('未找到知识详情'))
                              : Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // 分类标签
                                        if (_knowledgeItem!.category != null)
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: _knowledgeItem!.category ==
                                                      KnowledgeItem.tagCategory
                                                  ? Colors.blue
                                                  : Colors.green,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              _knowledgeItem!.category!,
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12),
                                            ),
                                          ),
                                        SizedBox(height: 8),

                                        // 标题
                                        Text(
                                          _knowledgeItem!.title ?? '无标题',
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: textPrimaryColor,
                                            height: 1.2, // 最小行高
                                          ),
                                          softWrap: true,
                                          textHeightBehavior:
                                              TextHeightBehavior(
                                            applyHeightToFirstAscent: false,
                                            applyHeightToLastDescent: false,
                                          ),
                                        ),

                                        // 内容（使用markdown_widget解析）
                                        if (_knowledgeItem!.content != null)
                                          Container(
                                            width: double.infinity,
                                            padding: EdgeInsets.zero,
                                            margin: EdgeInsets.zero,
                                            child: MarkdownWidget(
                                              data: _knowledgeItem!.content!,
                                              config: MarkdownConfig(
                                                configs: [
                                                  LinkConfig(
                                                    onTap: (url) {
                                                      // 处理链接点击
                                                      print(
                                                          'Link tapped: $url');
                                                    },
                                                  ),
                                                  CodeConfig(),
                                                ],
                                              ),
                                              shrinkWrap: true,
                                              physics:
                                                  NeverScrollableScrollPhysics(),
                                              padding: EdgeInsets.zero,
                                            ),
                                          ),
                                        SizedBox(height: 16),

                                        // 推荐歌曲
                                        if (_knowledgeItem!.recommendSongs !=
                                                null &&
                                            _knowledgeItem!
                                                .recommendSongs!.isNotEmpty)
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '推荐歌曲',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: textPrimaryColor,
                                                ),
                                              ),
                                              SizedBox(height: 12),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: _knowledgeItem!
                                                    .recommendSongs!
                                                    .map((song) {
                                                  // 计算卡片颜色和难度
                                                  int levelIndex = 0;
                                                  if (song.levelIndex != null) {
                                                    try {
                                                      levelIndex = int.parse(song.levelIndex!);
                                                    } catch (e) {
                                                      levelIndex = 0;
                                                    }
                                                  }
                                                  Color cardColor = ColorUtil.getCardColor(levelIndex);
                                                  
                                                  // 从缓存中获取歌曲信息
                                                  Song? songInfo;
                                                  if (_cachedSongs != null) {
                                                    songInfo = _cachedSongs!.firstWhere(
                                                      (s) => s.id == song.id,
                                                    );
                                                  }
                                                  
                                                  // 确定歌曲类型
                                                  bool dxMode = false;
                                                  bool isUtage = false;
                                                  if (songInfo != null) {
                                                    dxMode = songInfo.type == 'DX';
                                                    isUtage = songInfo.type == 'UTAGE';
                                                  }
                                                  
                                                  // 获取定数
                                                  double difficulty = 0.0;
                                                  if (songInfo != null && songInfo.ds.isNotEmpty) {
                                                    // 确保levelIndex在有效范围内
                                                    if (levelIndex >= 0 && levelIndex < songInfo.ds.length) {
                                                      difficulty = songInfo.ds[levelIndex];
                                                    } else {
                                                      // 如果levelIndex超出范围，使用第一个难度值
                                                      difficulty = songInfo.ds[0];
                                                    }
                                                  }
                                                  
                                                  // 获取达成率
                                                  double achievementRate = 0.0;
                                                  if (_recordItems != null && song.id != null) {
                                                    try {
                                                      int songId = int.parse(song.id!);
                                                      // 查找对应的RecordItem
                                                      final recordItem = _recordItems!.firstWhere(
                                                        (record) => record.songId == songId && record.levelIndex == levelIndex,
                                                      );
                                                      achievementRate = recordItem.achievements.toDouble();
                                                                                                        } catch (e) {
                                                      print('解析歌曲ID失败: $e');
                                                    }
                                                  }
                                                  
                                                  // 构建游戏卡片
                                                  return _buildGameCard(
                                                    cardColor: cardColor,
                                                    songName: songInfo?.title ?? '歌曲 ${song.id}',
                                                    achievementRate: achievementRate,
                                                    difficulty: difficulty,
                                                    dxMode: dxMode,
                                                    isUtage: isUtage,
                                                    score: 0, // 实际项目中应该从缓存数据中获取
                                                    rating: 0, // 实际项目中应该从缓存数据中获取
                                                    stars: '', // 实际项目中应该从缓存数据中获取
                                                    grade: '', // 实际项目中应该从缓存数据中获取
                                                    songId: int.tryParse(song.id ?? '0'),
                                                  );
                                                }).toList(),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
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
}