import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:marquee/marquee.dart';
import 'package:my_first_flutter_app/service/SongAliasManager.dart';
import 'package:my_first_flutter_app/service/MaimaiMusicDataManager.dart';

class SongInfoPage extends StatefulWidget {
  final String songId;

  const SongInfoPage({super.key, required this.songId});

  @override
  State<SongInfoPage> createState() => _SongInfoPageState();
}

class _SongInfoPageState extends State<SongInfoPage> {
  // 数据加载状态
  bool _isLoading = true;
  Map<String, dynamic>? _songData;
  List<dynamic>? _diffData;
  Map<String, dynamic>? _userData;
  List<dynamic>? _tagData;
  List<dynamic>? _tagSongsData;

  // 当前选中的难度索引
  int _currentDiffIndex = 3; // 默认选中Master难度

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // 加载所有数据
  Future<void> _loadData() async {
    try {
      // 加载歌曲基础数据
      if (MaimaiMusicDataManager().hasCachedData()) {
        final songs = MaimaiMusicDataManager().getCachedSongs();
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
        _songData = songList.firstWhere((song) => song['id'] == widget.songId,
            orElse: () => null);
      }

      // 加载难度数据
      final diffData = await rootBundle.loadString('assets/songDiffData.json');
      final Map<String, dynamic> diffMap = json.decode(diffData);
      _diffData = diffMap['charts'][widget.songId];

      // 加载用户数据
      final userData = await rootBundle.loadString('assets/userPlayData.json');
      final Map<String, dynamic> userMap = json.decode(userData);
      _userData = userMap;

      // 加载标签数据
      final tagData = await rootBundle.loadString('assets/maiTags.json');
      final Map<String, dynamic> tagMap = json.decode(tagData);
      _tagData = tagMap['tags'];
      _tagSongsData = tagMap['tagSongs'];
    } catch (e) {
      print('加载数据失败: $e');
    } finally {
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

    // 生成曲绘路径
    String coverPath = 'assets/cover/${widget.songId}.webp';

    // 生成fallback的cover_id
    String generateCoverId(String songId) {
      if (songId.length >= 5) {
        // 如果长度大于等于5，万位补1
        int songIdInt = int.parse(songId);
        int tenThousandPlace = (songIdInt ~/ 10000) + 1;
        int remaining = songIdInt % 10000;
        return '${tenThousandPlace}${remaining.toString().padLeft(4, '0')}';
      } else {
        // 如果长度小于5，补1在万位，其余补0
        return '1${songId.padLeft(4, '0')}';
      }
    }

    String coverId = generateCoverId(widget.songId);
    String networkCoverUrl = 'https://www.diving-fish.com/covers/$coverId.png';

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
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
            top: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "歌曲详情",
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
            top: 40,
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
            top: MediaQuery.of(context).size.height * 0.15,
            left: MediaQuery.of(context).size.width * 0.02,
            right: MediaQuery.of(context).size.width * 0.02,
            bottom: MediaQuery.of(context).size.height * 0.05,
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
                              // 封面
                              Container(
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
                                  child: Image.asset(
                                    coverPath,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Image.network(networkCoverUrl,
                                          fit: BoxFit.cover, errorBuilder:
                                              (context, error, stackTrace) {
                                        // 网络资源也请求失败，显示默认占位符 assets/cover/0.webp
                                        return Image.asset(
                                          'assets/cover/0.webp',
                                          fit: BoxFit.cover,
                                        );
                                      });
                                    },
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
                                    // 当歌曲名长度大于13时，使用Marquee实现自动循环滚动
                                    (basicInfo['title'].length > 13)
                                        ? SizedBox(
                                            height: 40,
                                            child: Marquee(
                                              text: basicInfo['title'],
                                              style: TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold,
                                                color: accentColor,
                                              ),
                                              scrollAxis: Axis.horizontal,
                                              blankSpace: 20.0,
                                              velocity: 30.0,
                                              pauseAfterRound:
                                                  Duration(seconds: 3),
                                            ),
                                          )
                                        : Text(
                                            basicInfo['title'],
                                            style: TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              color: accentColor,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),

                                    const SizedBox(height: 12),
                                    // 显示歌曲别名
                                    _buildAliasSection(basicInfo['title']),

                                    const SizedBox(height: 12),
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
                                      ? currentDiffData['fit_diff']
                                          .toStringAsFixed(2)
                                      : '-'),
                              _buildStatItem('谱面谱师', currentChart['charter']),
                              _buildStatItem(
                                  '平均达成',
                                  currentDiffData != null
                                      ? '${currentDiffData['avg'].toStringAsFixed(2)}%'
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
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                      const SizedBox(height: 8),
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
                                      Row(
                                        children: [
                                          Text('连击,同步：'),
                                          if (userRecord != null) ...[
                                            if (userRecord['fc'].isNotEmpty)
                                              _buildBadge(userRecord['fc']),
                                            if (userRecord['fs'].isNotEmpty)
                                              _buildBadge(userRecord['fs']),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    color: themeColor,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '★',
                                      style: TextStyle(
                                        fontSize: 24,
                                        color: accentColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // 谱面标签
                          Container(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '谱面标签',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: accentColor,
                                  ),
                                ),

                                const SizedBox(height: 10),

                                // 标签分组
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
                            ),
                          ),

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

                    // 如果文本宽度小于安全容器宽度，不需要滚动
                    if (textWidth <= safeContainerWidth) {
                      return Text(value, style: textStyle);
                    }

                    // 否则使用Marquee组件
                    return SizedBox(
                      height: screenHeight * 0.03, // 容器高度为屏幕高度的3%
                      child: Marquee(
                        text: value,
                        style: textStyle,
                        scrollAxis: Axis.horizontal,
                        blankSpace: screenWidth * 0.05, // 空白空间为屏幕宽度的5%
                        velocity: screenWidth * 0.08, // 滚动速度为屏幕宽度的8%
                        pauseAfterRound: Duration(seconds: 3),
                      ),
                    );
                  },
                )
              : Text(
                  value,
                  style: textStyle,
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
