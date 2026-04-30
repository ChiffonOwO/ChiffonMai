import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:my_first_flutter_app/utils/CoverUtil.dart';
import 'package:my_first_flutter_app/utils/StringUtil.dart';
import 'package:my_first_flutter_app/service/KaleidXScope/KaleidXScopeInfoServiceBLUE.dart'
    as blueService;
import 'package:my_first_flutter_app/service/KaleidXScope/KaleidXScopeSelectService.dart';
import 'package:my_first_flutter_app/manager/UserPlayDataManager.dart';
import 'package:my_first_flutter_app/manager/MaimaiMusicDataManager.dart';
import 'package:my_first_flutter_app/entity/Song.dart';
import 'package:my_first_flutter_app/page/SongInfoPage.dart';

class KaleidXScopeInfoPageBLUE extends StatefulWidget {
  const KaleidXScopeInfoPageBLUE({
    super.key,
  });

  @override
  State<KaleidXScopeInfoPageBLUE> createState() =>
      _KaleidXScopeInfoPageBLUEState();
}

class _KaleidXScopeInfoPageBLUEState extends State<KaleidXScopeInfoPageBLUE> {
  final blueService.KaleidXScopeInfoServiceBLUE _service =
      blueService.KaleidXScopeInfoServiceBLUE();
  final UserPlayDataManager _playDataManager = UserPlayDataManager();
  List<Song> _songs = [];
  List<Song> _track1Songs = [];
  List<Song> _track2Songs = [];
  List<Song> _track3Songs = [];
  bool _isLoading = true;
  bool _showCompleted = false;
  Set<String> _completedSongIds = {};

  // 特殊歌曲缓存（只在页面初始化时加载一次）
  Song? _specialSong11739;
  Song? _specialSong11740;

  // 自定义常量
  final Color textPrimaryColor = Color.fromARGB(255, 84, 97, 97);
  late double _borderRadiusSmall;
  late double _defaultShadowBlurRadius;
  late double _defaultShadowOffset;

  // 尺寸参数（基于MediaQuery）
  late double _paddingXS;
  late double _paddingS;
  late double _paddingM;
  late double _paddingL;
  late double _paddingXL;
  late double _textSizeXS;
  late double _textSizeS;
  late double _textSizeM;
  late double _textSizeL;
  late double _textSizeXL;
  late double _coverSize;
  late double _progressBarHeight;

  // 初始化尺寸参数
  void _initSizeParams(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double scaleFactor = screenWidth / 375.0; // 以375px宽度为基准

    // 圆角
    _borderRadiusSmall = 8.0 * scaleFactor;

    // 阴影
    _defaultShadowBlurRadius = 5.0 * scaleFactor;
    _defaultShadowOffset = 2.0 * scaleFactor;

    // 内边距
    _paddingXS = 4.0 * scaleFactor;
    _paddingS = 8.0 * scaleFactor;
    _paddingM = 12.0 * scaleFactor;
    _paddingL = 16.0 * scaleFactor;
    _paddingXL = 48.0 * scaleFactor;

    // 字体大小
    _textSizeXS = 9.0 * scaleFactor;
    _textSizeS = 11.0 * scaleFactor;
    _textSizeM = 12.0 * scaleFactor;
    _textSizeL = 14.0 * scaleFactor;
    _textSizeXL = 16.0 * scaleFactor;

    // 曲绘尺寸
    _coverSize = 40.0 * scaleFactor;

    // 进度条高度
    _progressBarHeight = 24.0 * scaleFactor;
  }

  BoxShadow get defaultShadow => BoxShadow(
        color: Colors.black12,
        blurRadius: _defaultShadowBlurRadius,
        offset: Offset(_defaultShadowOffset, _defaultShadowOffset),
      );

  // 获取标题
  String _getGateTitle() {
    return '蓝色之门详情';
  }

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final songs = await _service.getBlueGateSongs();
      setState(() {
        _songs = songs;
      });

      // 加载完成歌曲ID
      await _loadCompletedSongs();

      // 加载Track歌曲
      final trackSongs = await _service.loadTrackSongs();
      setState(() {
        _track1Songs = trackSongs['track1'] ?? [];
        _track2Songs = trackSongs['track2'] ?? [];
        _track3Songs = trackSongs['track3'] ?? [];
      });

      // 加载特殊歌曲（只在初始化时加载一次）
      await _loadSpecialSongs();
    } catch (e) {
      print('加载歌曲失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 加载特殊歌曲（完美挑战曲和隐藏歌曲）
  Future<void> _loadSpecialSongs() async {
    final allSongs = await MaimaiMusicDataManager().getCachedSongs();
    if (allSongs == null) return;

    try {
      _specialSong11739 = allSongs.firstWhere(
        (song) => song.id.toString() == '11739',
      );
    } catch (e) {
      _specialSong11739 = null;
    }

    try {
      _specialSong11740 = allSongs.firstWhere(
        (song) => song.id.toString() == '11740',
      );
    } catch (e) {
      _specialSong11740 = null;
    }
  }

  // 加载已完成歌曲ID
  Future<void> _loadCompletedSongs() async {
    try {
      final userPlayData = await _playDataManager.getCachedUserPlayData();
      if (userPlayData != null && userPlayData['records'] is List) {
        final records = userPlayData['records'] as List;
        final Set<String> completedIds = {};
        for (final record in records) {
          if (record is Map<String, dynamic>) {
            final songId = record['song_id']?.toString();
            if (songId != null) {
              completedIds.add(songId);
            }
          }
        }
        setState(() {
          _completedSongIds = completedIds;
        });
      }
    } catch (e) {
      print('加载完成歌曲失败: $e');
    }
  }

  // 检查歌曲是否已完成
  bool _isSongCompleted(String songId) {
    return _completedSongIds.contains(songId);
  }

  // 获取类型显示
  String _getTypeDisplay(String type) {
    switch (type.toLowerCase()) {
      case 'dx':
        return 'DX';
      case 'standard':
      case 'sd':
        return 'ST';
      default:
        return type;
    }
  }

  // 获取定数显示（第3,4,5个定数，第5个没有显示为-）
  String _getDsDisplay(List<double> dsList) {
    String ds3 = dsList.length > 2 ? dsList[2].toStringAsFixed(1) : '-';
    String ds4 = dsList.length > 3 ? dsList[3].toStringAsFixed(1) : '-';
    String ds5 = dsList.length > 4 ? dsList[4].toStringAsFixed(1) : '-';
    return '$ds3 / $ds4 / $ds5';
  }

  // 构建挑战进度区域
  Widget _buildChallengeProgress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 解锁方法说明区域
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(_borderRadiusSmall),
            border: Border.all(color: Colors.grey[300]!, width: 1),
          ),
          padding: EdgeInsets.all(_paddingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '解锁方法',
                style: TextStyle(
                  fontSize: _textSizeL,
                  fontWeight: FontWeight.bold,
                  color: textPrimaryColor,
                ),
              ),
              SizedBox(height: _paddingS),
              Text(
                '青门（蓝色之门）门扉',
                style: TextStyle(
                  fontSize: _textSizeM,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: _textSizeS,
                    color: Colors.grey[600],
                  ),
                  children: [
                    TextSpan(text: '完成'),
                    TextSpan(
                      text: '天空街区域6',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: '（门扉必要条件）'),
                  ],
                ),
              ),
              SizedBox(height: _paddingS),
              Text(
                '钥匙（挑战所需的物品）',
                style: TextStyle(
                  fontSize: _textSizeM,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[700],
                ),
              ),
              Text(
                '需要完成下方曲目池内的29首歌曲',
                style: TextStyle(
                  fontSize: _textSizeS,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                '可：跳过（Track Skip）/不可：段位认定和宴会场',
                style: TextStyle(
                  fontSize: _textSizeS,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: _paddingS),
              Text(
                'KALEIDXSCOPE模式',
                style: TextStyle(
                  fontSize: _textSizeM,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple[700],
                ),
              ),
              Text(
                '第一首：所有区域歌曲',
                style: TextStyle(
                  fontSize: _textSizeS,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                '第二首：所有区域内的完美挑战曲',
                style: TextStyle(
                  fontSize: _textSizeS,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                '第三首：固定，即为隐藏歌曲',
                style: TextStyle(
                  fontSize: _textSizeS,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: _paddingS),
              Text(
                '完美挑战曲为',
                style: TextStyle(
                  fontSize: _textSizeM,
                  fontWeight: FontWeight.bold,
                  color: textPrimaryColor,
                ),
              ),
              _buildSpecialSongCard(11739),
              SizedBox(height: _paddingS),
              Text(
                '青门（蓝色之门）的隐藏歌曲为',
                style: TextStyle(
                  fontSize: _textSizeM,
                  fontWeight: FontWeight.bold,
                  color: textPrimaryColor,
                ),
              ),
              _buildSpecialSongCard(11740),
            ],
          ),
        ),
        SizedBox(height: _paddingL),

        // 蓝色之门挑战
        _buildChallengeSection(blueService.KaleidXScopeInfoServiceBLUE.blueGateChallenge),
        SizedBox(height: _paddingL),

        // 天空街完美挑战
        _buildChallengeSection(blueService.KaleidXScopeInfoServiceBLUE.skyStreetChallenge),
        SizedBox(height: _paddingL),
        Divider(color: Colors.grey[300], thickness: 1),
        SizedBox(height: _paddingS),
      ],
    );
  }

  // 构建特殊歌曲卡片（使用缓存的歌曲数据）
  Widget _buildSpecialSongCard(int songId) {
    // 根据ID获取缓存的歌曲
    final Song? song = songId == 11739 ? _specialSong11739 : _specialSong11740;

    // 如果歌曲还未加载完成，显示加载状态
    if (song == null) {
      return Container(
        height: 50 * (MediaQuery.of(context).size.width / 375.0),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(_borderRadiusSmall),
          border: Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SongInfoPage(
                songId: song.id,
                initialLevelIndex: 3,
              ),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(_borderRadiusSmall),
            border: Border.all(color: Colors.grey[300]!, width: 1),
          ),
          padding: EdgeInsets.all(_paddingXS),
          child: Row(
            children: [
              Container(
                width: _coverSize,
                height: _coverSize,
                child:
                    CoverUtil.buildCoverWidgetWithContext(context, song.id, _coverSize),
              ),
              SizedBox(width: _paddingXS * 1.5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      style: TextStyle(
                        fontSize: _textSizeS,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: _paddingXS * 0.25),
                    Text(
                      '${_getTypeDisplay(song.type)} | ${StringUtil.formatVersion2(song.basicInfo.from)}',
                      style: TextStyle(
                        fontSize: _textSizeXS,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: _paddingXS * 0.25),
                    Text(
                      _getDsDisplay(song.ds),
                      style: TextStyle(
                        fontSize: _textSizeXS,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ));
  }

  // 构建单个挑战区域
  Widget _buildChallengeSection(Map<String, dynamic> challenge) {
    final String name = challenge['name'];
    final List<dynamic> phases = challenge['phases'];
    final double progressBarFontSize = 10.0 * (MediaQuery.of(context).size.width / 375.0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(_borderRadiusSmall),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      padding: EdgeInsets.all(_paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: _textSizeL,
              fontWeight: FontWeight.bold,
              color: textPrimaryColor,
            ),
          ),
          SizedBox(height: _paddingS),

          // 进度条
          Container(
            height: _progressBarHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_progressBarHeight / 2),
              border: Border.all(color: Colors.grey[300]!, width: 1),
            ),
            child: Row(
              children: phases.map((phase) {
                final String type = phase['type'];
                final Color color =
                    KaleidXScopeSelectService.getDifficultyColor(type);

                return Expanded(
                  child: Container(
                    color: color,
                    child: Center(
                      child: Text(
                        '$type',
                        style: TextStyle(
                          fontSize: progressBarFontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // 阶段详情
          SizedBox(height: _paddingXS),
          Column(
            children: phases.map((phase) {
              final String type = phase['type'];
              final String startDate = phase['startDate'];
              final String? endDate = phase['endDate'];
              final int lifeTarget = phase['lifeTarget'];
              final Color color =
                  KaleidXScopeSelectService.getDifficultyColor(type);

            return Padding(
              padding: EdgeInsets.symmetric(vertical: _paddingXS * 0.5),
              child: Row(
                children: [
                  Text(
                    '${startDate}${endDate != null ? ' - $endDate' : ' - 后续'}:',
                    style: TextStyle(
                      fontSize: _textSizeS,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(width: _paddingS),
                  Text(
                    type,
                    style: TextStyle(
                      fontSize: _textSizeS,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  SizedBox(width: _paddingXS),
                  Text(
                    'LIFE $lifeTarget',
                    style: TextStyle(
                      fontSize: _textSizeS,
                      fontWeight: FontWeight.bold,
                      color: textPrimaryColor,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    ));
  }

  // 渲染歌曲卡片列表
  Widget _buildSongList() {
    if (_songs.isEmpty) {
      return Center(child: Text('暂无歌曲数据'));
    }

    return Column(
      children: [
        // 门扉图片
        Center(
          child: Image.asset(
            'assets/kaleidxscope/blue.webp',
            width: MediaQuery.of(context).size.width - 64,
            fit: BoxFit.contain,
          ),
        ),
        SizedBox(height: _paddingS),

        // 挑战进度区域
        _buildChallengeProgress(),

        // 曲目池标题区域
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black, width: 1),
            borderRadius: BorderRadius.circular(_borderRadiusSmall),
          ),
          padding: EdgeInsets.symmetric(horizontal: _paddingS, vertical: _paddingXS * 0.5),
          child: Center(
            child: Text(
              '曲目池 | 总计 ${_songs.length} 首歌曲',
              style: TextStyle(
                fontSize: _textSizeL,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
        ),
        SizedBox(height: _paddingS),

        // 显示完成情况勾选框
        Padding(
          padding: EdgeInsets.symmetric(horizontal: _paddingS),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Checkbox(
                value: _showCompleted,
                onChanged: (value) {
                  setState(() {
                    _showCompleted = value ?? false;
                  });
                },
              ),
              Text(
                '显示完成情况',
                style: TextStyle(
                  fontSize: _textSizeM,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        // 歌曲卡片网格
        GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: _paddingXS,
            mainAxisSpacing: _paddingXS,
            childAspectRatio: 2.0,
          ),
          itemCount: _songs.length,
          itemBuilder: (context, index) {
            final song = _songs[index];
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SongInfoPage(
                      songId: song.id,
                      initialLevelIndex: 3, // MASTER 难度
                    ),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: _showCompleted && _isSongCompleted(song.id)
                      ? Colors.lightGreen[100]
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(_borderRadiusSmall),
                  border: Border.all(
                    color: _showCompleted && _isSongCompleted(song.id)
                        ? Colors.green
                        : Colors.grey,
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
                        song.id,
                        _coverSize,
                      ),
                    ),
                    SizedBox(width: _paddingXS * 1.5),
                    // 歌曲信息
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            song.title,
                            style: TextStyle(
                              fontSize: _textSizeS,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: _paddingXS * 0.25),
                          // 第二行：类型|版本
                          Text(
                            '${_getTypeDisplay(song.type)} | ${StringUtil.formatVersion2(song.basicInfo.from)}',
                            style: TextStyle(
                              fontSize: _textSizeXS,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: _paddingXS * 0.25),
                          // 第三行：第3,4,5个定数（EXPERT/MASTER/RE:MASTER）
                          Text(
                            _getDsDisplay(song.ds),
                            style: TextStyle(
                              fontSize: _textSizeXS,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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

        // Track区域
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: _paddingS),
            Divider(color: Colors.grey[300], thickness: 1),
            SizedBox(height: _paddingS),
            Text(
              'Track随机曲目',
              style: TextStyle(
                fontSize: _textSizeXL,
                fontWeight: FontWeight.bold,
                color: textPrimaryColor,
              ),
            ),
            SizedBox(height: _paddingXS),

            // Track1
            _buildTrackSection('Track 1', _track1Songs),

            SizedBox(height: _paddingS),

            // Track2
            _buildTrackSection('Track 2', _track2Songs),

            SizedBox(height: _paddingS),
            // Track3
            _buildTrackSection('Track 3', _track3Songs),

            SizedBox(height: _paddingS),
          ],
        ),
      ],
    );
  }

  // 构建Track区域
  Widget _buildTrackSection(String title, List<Song> songs) {
    if (songs.isEmpty) {
      return Container();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black, width: 1),
            borderRadius: BorderRadius.circular(_borderRadiusSmall),
          ),
          padding: EdgeInsets.symmetric(horizontal: _paddingS, vertical: _paddingXS * 0.5),
          child: Center(
            child: Text(
              '${title} | 总计 ${songs.length} 首歌曲',
              style: TextStyle(
                fontSize: _textSizeL,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
        ),
        SizedBox(height: _paddingS),
        GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: _paddingXS,
            mainAxisSpacing: _paddingXS,
            childAspectRatio: 2.0,
          ),
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SongInfoPage(
                      songId: song.id,
                      initialLevelIndex: 3,
                    ),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(_borderRadiusSmall),
                  border: Border.all(
                    color: Colors.grey,
                    width: 1,
                  ),
                ),
                padding: EdgeInsets.all(_paddingXS),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: _coverSize,
                      height: _coverSize,
                      child: CoverUtil.buildCoverWidgetWithContext(
                        context,
                        song.id,
                        _coverSize,
                      ),
                    ),
                    SizedBox(width: _paddingXS * 1.5),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            song.title,
                            style: TextStyle(
                              fontSize: _textSizeS,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: _paddingXS * 0.25),
                          Text(
                            '${_getTypeDisplay(song.type)} | ${StringUtil.formatVersion2(song.basicInfo.from)}',
                            style: TextStyle(
                              fontSize: _textSizeXS,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: _paddingXS * 0.25),
                          Text(
                            _getDsDisplay(song.ds),
                            style: TextStyle(
                              fontSize: _textSizeXS,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // 初始化尺寸参数
    _initSizeParams(context);

    final double titleFontSize = 24.0 * (MediaQuery.of(context).size.width / 375.0);

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
                padding: EdgeInsets.fromLTRB(_paddingL, _paddingXL, _paddingL, _paddingS),
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
                          _getGateTitle(),
                          style: TextStyle(
                            color: textPrimaryColor,
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // 占位
                    SizedBox(width: _paddingXL),
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
                    boxShadow: [defaultShadow],
                  ),
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                              horizontal: _paddingL, vertical: _paddingS),
                          child: _buildSongList(),
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