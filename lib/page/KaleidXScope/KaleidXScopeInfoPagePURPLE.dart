import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:my_first_flutter_app/utils/CoverUtil.dart';
import 'package:my_first_flutter_app/utils/StringUtil.dart';
import 'package:my_first_flutter_app/service/KaleidXScope/KaleidXScopeInfoServicePURPLE.dart'
    as purpleService;
import 'package:my_first_flutter_app/service/KaleidXScope/KaleidXScopeSelectService.dart';
import 'package:my_first_flutter_app/manager/DivingFish/MaimaiMusicDataManager.dart';
import 'package:my_first_flutter_app/entity/DivingFish/Song.dart';
import 'package:my_first_flutter_app/page/SongInfoPage.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';

class KaleidXScopeInfoPagePURPLE extends StatefulWidget {
  const KaleidXScopeInfoPagePURPLE({
    super.key,
  });

  @override
  State<KaleidXScopeInfoPagePURPLE> createState() =>
      _KaleidXScopeInfoPagePURPLEState();
}

class _KaleidXScopeInfoPagePURPLEState extends State<KaleidXScopeInfoPagePURPLE> {
  final purpleService.KaleidXScopeInfoServicePURPLE _service =
      purpleService.KaleidXScopeInfoServicePURPLE();
  List<Song> _songs = [];
  List<Song> _track1Songs = [];
  List<Song> _track2Songs = [];
  List<Song> _track3Songs = [];
  bool _isLoading = true;

  // 特殊歌曲缓存（隐藏歌曲）
  Song? _specialSong11749;

  // 自定义常量
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
    final double scaleFactor = screenWidth / 375.0;

    _borderRadiusSmall = 8.0 * scaleFactor;
    _defaultShadowBlurRadius = 5.0 * scaleFactor;
    _defaultShadowOffset = 2.0 * scaleFactor;

    _paddingXS = 4.0 * scaleFactor;
    _paddingS = 8.0 * scaleFactor;
    _paddingM = 12.0 * scaleFactor;
    _paddingL = 16.0 * scaleFactor;
    _paddingXL = 48.0 * scaleFactor;

    _textSizeXS = 9.0 * scaleFactor;
    _textSizeS = 11.0 * scaleFactor;
    _textSizeM = 12.0 * scaleFactor;
    _textSizeL = 14.0 * scaleFactor;
    _textSizeXL = 16.0 * scaleFactor;

    _coverSize = 40.0 * scaleFactor;
    _progressBarHeight = 24.0 * scaleFactor;
  }

  BoxShadow get defaultShadow => BoxShadow(
        color: Colors.black12,
        blurRadius: _defaultShadowBlurRadius,
        offset: Offset(_defaultShadowOffset, _defaultShadowOffset),
      );

  // 获取标题
  String _getGateTitle() {
    return '紫色之门详情';
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
      final songs = await _service.getPurpleGateSongs();
      setState(() {
        _songs = songs;
      });

      final trackSongs = await _service.loadTrackSongs();
      setState(() {
        _track1Songs = trackSongs['track1'] ?? [];
        _track2Songs = trackSongs['track2'] ?? [];
        _track3Songs = trackSongs['track3'] ?? [];
      });

      await _loadSpecialSongs();
    } catch (e) {
      debugPrint('加载歌曲失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSpecialSongs() async {
    final allSongs = await MaimaiMusicDataManager().getCachedSongs();
    if (allSongs == null) return;

    try {
      _specialSong11749 = allSongs.firstWhere(
        (song) => song.id.toString() == '11749',
      );
    } catch (e) {
      _specialSong11749 = null;
    }
  }

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

  String _getDsDisplay(List<double> dsList) {
    String ds3 = dsList.length > 2 ? dsList[2].toStringAsFixed(1) : '-';
    String ds4 = dsList.length > 3 ? dsList[3].toStringAsFixed(1) : '-';
    String ds5 = dsList.length > 4 ? dsList[4].toStringAsFixed(1) : '-';
    return '$ds3 / $ds4 / $ds5';
  }

  // 构建挑战进度区域
  Widget _buildChallengeProgress() {
    final brightness = Theme.of(context).brightness;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 解锁方法说明区域
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(_borderRadiusSmall),
            border: Border.all(color: AppColors.tableBorder(brightness), width: 1),
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
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              SizedBox(height: _paddingS),
              Text(
                '紫门门扉',
                style: TextStyle(
                  fontSize: _textSizeM,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple[700],
                ),
              ),
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: _textSizeS,
                    color: AppColors.greyHint(brightness),
                  ),
                  children: [
                    TextSpan(text: '完成'),
                    TextSpan(
                      text: '紫蔷薇区域10',
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
                '设置[アウル]为队长，单人连续游玩3首 / 双人连续游玩4首下方曲目池中的歌曲。不限难度，不能重复',
                style: TextStyle(
                  fontSize: _textSizeS,
                  color: AppColors.greyHint(brightness),
                ),
              ),
              Text(
                '可：选择/不可：跳过，段位认定和宴会场',
                style: TextStyle(
                  fontSize: _textSizeS,
                  color: AppColors.greyHint(brightness),
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
                  color: AppColors.greyHint(brightness),
                ),
              ),
              Text(
                '第二首：所有区域内的完美挑战曲',
                style: TextStyle(
                  fontSize: _textSizeS,
                  color: AppColors.greyHint(brightness),
                ),
              ),
              Text(
                '第三首：固定，即为隐藏歌曲',
                style: TextStyle(
                  fontSize: _textSizeS,
                  color: AppColors.greyHint(brightness),
                ),
              ),
              SizedBox(height: _paddingS),
              Text(
                '紫の扉的隐藏歌曲为',
                style: TextStyle(
                  fontSize: _textSizeM,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              _buildSpecialSongCard(11749),
            ],
          ),
        ),
        SizedBox(height: _paddingL),

        // 紫门挑战
        _buildChallengeSection(purpleService.KaleidXScopeInfoServicePURPLE.purpleGateChallenge),
        SizedBox(height: _paddingL),
        Divider(color: AppColors.tableBorder(brightness), thickness: 1),
        SizedBox(height: _paddingS),
      ],
    );
  }

  // 构建单个挑战区域
  Widget _buildChallengeSection(Map<String, dynamic> challenge) {
    final brightness = Theme.of(context).brightness;
    final String name = challenge['name'];
    final List<dynamic> phases = challenge['phases'];
    final double progressBarFontSize = 10.0 * (MediaQuery.of(context).size.width / 375.0);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(_borderRadiusSmall),
        border: Border.all(color: AppColors.tableBorder(brightness), width: 1),
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
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          SizedBox(height: _paddingS),

          // 进度条
          Container(
            height: _progressBarHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_progressBarHeight / 2),
              border: Border.all(color: AppColors.tableBorder(brightness), width: 1),
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
                      color: AppColors.greyHint(brightness),
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
                      color: Theme.of(context).colorScheme.onSurface,
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

  // 构建特殊歌曲卡片
  Widget _buildSpecialSongCard(int songId) {
    final brightness = Theme.of(context).brightness;
    final Song? song = songId == 11749 ? _specialSong11749 : null;

    if (song == null) {
      return Container(
        height: 50 * (MediaQuery.of(context).size.width / 375.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(_borderRadiusSmall),
          border: Border.all(color: AppColors.tableBorder(brightness), width: 1),
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
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(_borderRadiusSmall),
            border: Border.all(color: AppColors.tableBorder(brightness), width: 1),
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
                        color: AppColors.greyHint(brightness),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: _paddingXS * 0.25),
                    Text(
                      _getDsDisplay(song.ds),
                      style: TextStyle(
                        fontSize: _textSizeXS,
                        color: AppColors.greyHint(brightness),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ));
  }

  // 渲染歌曲卡片列表
  Widget _buildSongList() {
    final brightness = Theme.of(context).brightness;
    if (_songs.isEmpty) {
      return Center(child: Text('暂无歌曲数据'));
    }

    return Column(
      children: [
        // 门扉图片
        Center(
          child: Image.asset(
            'assets/kaleidxscope/purple.webp',
            width: MediaQuery.of(context).size.width - 64,
            fit: BoxFit.contain,
          ),
        ),
        SizedBox(height: _paddingS),

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
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                      initialLevelIndex: 3,
                    ),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(_borderRadiusSmall),
                  border: Border.all(
                    color: AppColors.greyHint(brightness),
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
                              color: AppColors.greyHint(brightness),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: _paddingXS * 0.25),
                          Text(
                            _getDsDisplay(song.ds),
                            style: TextStyle(
                              fontSize: _textSizeXS,
                              color: AppColors.greyHint(brightness),
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
            Divider(color: AppColors.tableBorder(brightness), thickness: 1),
            SizedBox(height: _paddingS),
            Text(
              'Track随机曲目',
              style: TextStyle(
                fontSize: _textSizeXL,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: _paddingXS),

            _buildTrackSection('Track 1', _track1Songs),
            SizedBox(height: _paddingS),
            _buildTrackSection('Track 2', _track2Songs),
            SizedBox(height: _paddingS),
            _buildTrackSection('Track 3', _track3Songs),
            SizedBox(height: _paddingS),
          ],
        ),
      ],
    );
  }

  // 构建Track区域
  Widget _buildTrackSection(String title, List<Song> songs) {
    final brightness = Theme.of(context).brightness;
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
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(_borderRadiusSmall),
                  border: Border.all(
                    color: AppColors.greyHint(brightness),
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
                              color: AppColors.greyHint(brightness),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: _paddingXS * 0.25),
                          Text(
                            _getDsDisplay(song.ds),
                            style: TextStyle(
                              fontSize: _textSizeXS,
                              color: AppColors.greyHint(brightness),
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
    final brightness = Theme.of(context).brightness;
    _initSizeParams(context);

    final double titleFontSize = 24.0 * (MediaQuery.of(context).size.width / 375.0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          CommonWidgetUtil.buildCommonBgWidget(),
          CommonWidgetUtil.buildCommonChiffonBgWidget(context),
          Column(
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(_paddingL, _paddingXL, _paddingL, _paddingS),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          _getGateTitle(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: _paddingXL),
                  ],
                ),
              ),
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