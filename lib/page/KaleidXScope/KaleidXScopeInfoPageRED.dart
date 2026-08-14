import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:my_first_flutter_app/utils/CoverUtil.dart';
import 'package:my_first_flutter_app/utils/StringUtil.dart';
import 'package:my_first_flutter_app/service/KaleidXScope/KaleidXScopeInfoServiceRED.dart'
    as redService;
import 'package:my_first_flutter_app/constant/CacheKeyConstant.dart';
import 'package:my_first_flutter_app/manager/DivingFish/MaimaiMusicDataManager.dart';
import 'package:my_first_flutter_app/entity/DivingFish/Song.dart';
import 'package:my_first_flutter_app/entity/KaleidXScope/KaleidXScopeGate.dart';
import 'package:my_first_flutter_app/page/SongInfoPage.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';

class KaleidXScopeInfoPageRED extends StatefulWidget {
  const KaleidXScopeInfoPageRED({super.key});

  @override
  State<KaleidXScopeInfoPageRED> createState() => _KaleidXScopeInfoPageREDState();
}

class _KaleidXScopeInfoPageREDState extends State<KaleidXScopeInfoPageRED> {
  final redService.KaleidXScopeInfoServiceRED _service =
      redService.KaleidXScopeInfoServiceRED();
  List<Song> _songs = [];
  List<Song> _track1Songs = [];
  List<Song> _track2Songs = [];
  List<Song> _track3Songs = [];
  bool _isLoading = true;
  bool _isMarkMode = false;
  Set<String> _manualMarkedIds = {};
  KaleidXScopeGate? _gateData;

  // 特殊歌曲缓存（动态从 gateData 获取）
  Song? _specialSongPerfect;
  Song? _specialSongHidden;

  late double _borderRadiusSmall;
  late double _defaultShadowBlurRadius;
  late double _defaultShadowOffset;
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

  void _initSizeParams(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double scaleFactor = screenWidth / 375.0;
    _borderRadiusSmall = 8.0 * scaleFactor;
    _defaultShadowBlurRadius = 5.0 * scaleFactor;
    _defaultShadowOffset = 2.0 * scaleFactor;
    _paddingXS = 4.0 * scaleFactor;
    _paddingS = 4.0 * scaleFactor;
    _paddingM = 12.0 * scaleFactor;
    _paddingL = 10.0 * scaleFactor;
    _paddingXL = 48.0 * scaleFactor;
    _textSizeXS = 9.0 * scaleFactor;
    _textSizeS = 11.0 * scaleFactor;
    _textSizeM = 12.0 * scaleFactor;
    _textSizeL = 14.0 * scaleFactor;
    _textSizeXL = 16.0 * scaleFactor;
    _coverSize = 40.0 * scaleFactor;
    _progressBarHeight = 24.0 * scaleFactor;
  }

  BoxShadow defaultShadow(Brightness brightness) => BoxShadow(
        color: brightness == Brightness.dark ? Colors.black.withOpacity(0.3) : Colors.black12,
        blurRadius: _defaultShadowBlurRadius,
        offset: Offset(_defaultShadowOffset, _defaultShadowOffset),
      );

  String _getGateTitle() => '红色之门详情';

  @override
  void initState() {
    super.initState();
    _loadSongs();
    _loadMarkedSongsFromPrefs();
  }

  Future<void> _loadSongs() async {
    setState(() => _isLoading = true);
    try {
      _gateData = await _service.fetchGateData();
      if (_gateData == null) return;

      final songs = await _service.getRedGateSongs();
      setState(() => _songs = songs);

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
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMarkedSongsFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(CacheKeyConstant.kaleidXRedGateMarkedSongs);
      if (cached != null && cached.isNotEmpty) {
        setState(() => _manualMarkedIds = Set.from(cached.split(',')));
      }
    } catch (e) {
      debugPrint('加载标记歌曲缓存失败: $e');
    }
  }

  Future<void> _saveMarkedSongsToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        CacheKeyConstant.kaleidXRedGateMarkedSongs,
        _manualMarkedIds.join(','),
      );
    } catch (e) {
      debugPrint('保存标记歌曲缓存失败: $e');
    }
  }

  Future<void> _loadSpecialSongs() async {
    if (_gateData == null) return;
    final allSongs = await MaimaiMusicDataManager().getCachedSongs();
    if (allSongs == null) return;
    for (final ss in _gateData!.specialSongs) {
      try {
        final song = allSongs.firstWhere((s) => s.id.toString() == ss.songId.toString());
        if (ss.role == 'perfect') {
          _specialSongPerfect = song;
        } else if (ss.role == 'hidden') {
          _specialSongHidden = song;
        }
      } catch (e) { /* song not in cache */ }
    }
  }

  String _getTypeDisplay(String type) {
    switch (type.toLowerCase()) {
      case 'dx': return 'DX';
      case 'standard': case 'sd': return 'ST';
      default: return type;
    }
  }

  String _getDsDisplay(List<double> dsList) {
    String ds3 = dsList.length > 2 ? dsList[2].toStringAsFixed(1) : '-';
    String ds4 = dsList.length > 3 ? dsList[3].toStringAsFixed(1) : '-';
    String ds5 = dsList.length > 4 ? dsList[4].toStringAsFixed(1) : '-';
    return '$ds3 / $ds4 / $ds5';
  }

  Color _getDifficultyColor(String type) {
    switch (type) {
      case 'BASIC': return Colors.green;
      case 'ADVANCED': return Colors.blue;
      case 'EXPERT': return Colors.red;
      case 'MASTER': return Colors.purple;
      case 'Re:MASTER': return Colors.red;
      default: return AppColors.greyHint(Theme.of(context).brightness);
    }
  }

  Color _getDifficultyTextColor(String type) {
    switch (type) {
      case 'BASIC': return Colors.green;
      case 'ADVANCED': return Colors.blue;
      case 'EXPERT': return Colors.red;
      case 'MASTER': return Colors.purple;
      case 'Re:MASTER': return Colors.red;
      default: return AppColors.greyHint(Theme.of(context).brightness);
    }
  }

  // ─── 解锁方法区域 ───
  Widget _buildUnlockSection() {
    final brightness = Theme.of(context).brightness;
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
          Text('解锁方法', style: TextStyle(fontSize: _textSizeL, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
          SizedBox(height: _paddingS),
          Text(
            _gateData?.doorName ?? '赤门（红色之门）门扉',
            style: TextStyle(fontSize: _textSizeM, fontWeight: FontWeight.bold, color: Colors.red[700]),
          ),
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: _textSizeS, color: AppColors.greyHint(brightness)),
              children: [
                // TextSpan(text: '完成'),
                TextSpan(text: _gateData?.prerequisite ?? '（未设置）', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: '（门扉必要条件）'),
              ],
            ),
          ),
          SizedBox(height: _paddingS),
          Text('钥匙（挑战所需的物品）', style: TextStyle(fontSize: _textSizeM, fontWeight: FontWeight.bold, color: Colors.orange[700])),
          if (_gateData?.keyRequirement != null)
            Text(_gateData!.keyRequirement!, style: TextStyle(fontSize: _textSizeS, color: AppColors.greyHint(brightness))),
          if (_gateData?.guideNote != null && _gateData!.guideNote!.isNotEmpty)
            Text(_gateData!.guideNote!, style: TextStyle(fontSize: _textSizeS, color: AppColors.greyHint(brightness))),
          SizedBox(height: _paddingS),
          Text('KALEIDXSCOPE模式', style: TextStyle(fontSize: _textSizeM, fontWeight: FontWeight.bold, color: Colors.purple[700])),
          Text('第一首：${_gateData?.track1Desc ?? "（未设置）"}', style: TextStyle(fontSize: _textSizeS, color: AppColors.greyHint(brightness))),
          Text('第二首：${_gateData?.track2Desc ?? "（未设置）"}', style: TextStyle(fontSize: _textSizeS, color: AppColors.greyHint(brightness))),
          Text('第三首：${_gateData?.track3Desc ?? "（未设置）"}', style: TextStyle(fontSize: _textSizeS, color: AppColors.greyHint(brightness))),
          if (_specialSongPerfect != null) ...[
            SizedBox(height: _paddingS),
            Text('完美挑战曲为', style: TextStyle(fontSize: _textSizeM, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
            _buildSpecialSongCard(_specialSongPerfect!),
          ],
          if (_specialSongHidden != null) ...[
            SizedBox(height: _paddingS),
            Text('${_gateData?.doorName ?? "赤の扉"}的隐藏歌曲为', style: TextStyle(fontSize: _textSizeM, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
            _buildSpecialSongCard(_specialSongHidden!),
          ],
        ],
      ),
    );
  }

  // ─── 挑战进度区域 ───
  Widget _buildChallengeProgress() {
    final brightness = Theme.of(context).brightness;
    final challenges = _gateData?.challenges ?? [];
    if (challenges.isEmpty) return const SizedBox.shrink();

    return Column(
      children: challenges.map((challenge) {
        final phases = challenge.phases;
        final double progressBarFontSize = 10.0 * (MediaQuery.of(context).size.width / 375.0);

        return Padding(
          padding: EdgeInsets.only(bottom: _paddingL),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(_borderRadiusSmall),
              border: Border.all(color: AppColors.tableBorder(brightness), width: 1),
            ),
            padding: EdgeInsets.all(_paddingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(challenge.name, style: TextStyle(fontSize: _textSizeL, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                SizedBox(height: _paddingS),
                Container(
                  height: _progressBarHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_progressBarHeight / 2),
                    border: Border.all(color: AppColors.tableBorder(brightness), width: 1),
                  ),
                  child: Row(
                    children: phases.map((phase) {
                      final Color color = _getDifficultyColor(phase.difficulty);
                      return Expanded(
                        child: Container(
                          color: color,
                          child: Center(
                            child: Text(phase.difficulty, style: TextStyle(fontSize: progressBarFontSize, fontWeight: FontWeight.bold, color: brightness == Brightness.dark ? Colors.white : Colors.black87)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                SizedBox(height: _paddingXS),
                Column(
                  children: phases.map((phase) {
                    final Color textColor = _getDifficultyTextColor(phase.difficulty);
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: _paddingXS * 0.5),
                      child: Row(
                        children: [
                          Text('${phase.startDate}${phase.endDate != null ? ' - ${phase.endDate}' : ' - 后续'}:', style: TextStyle(fontSize: _textSizeS, color: AppColors.greyHint(brightness))),
                          SizedBox(width: _paddingXS),
                          Text(phase.difficulty, style: TextStyle(fontSize: _textSizeS, fontWeight: FontWeight.bold, color: textColor)),
                          SizedBox(width: _paddingXS),
                          Text('LIFE ${phase.lifeTarget}', style: TextStyle(fontSize: _textSizeS, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── 特殊歌曲卡片 ───
  Widget _buildSpecialSongCard(Song song) {
    final brightness = Theme.of(context).brightness;
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => SongInfoPage(songId: song.id, initialLevelIndex: 3)));
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
            Container(width: _coverSize, height: _coverSize, child: CoverUtil.buildCoverWidgetWithContext(context, song.id, _coverSize)),
            SizedBox(width: _paddingXS * 1.5),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(song.title, style: TextStyle(fontSize: _textSizeS, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                  SizedBox(height: _paddingXS * 0.25),
                  Text('${_getTypeDisplay(song.type)} | ${StringUtil.formatVersion2WithFlag(song.basicInfo.from, song.isExtra)}', style: TextStyle(fontSize: _textSizeXS, color: AppColors.greyHint(brightness)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  SizedBox(height: _paddingXS * 0.25),
                  Text(_getDsDisplay(song.ds), style: TextStyle(fontSize: _textSizeXS, color: AppColors.greyHint(brightness))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 歌曲列表 ───
  Widget _buildSongList() {
    final brightness = Theme.of(context).brightness;

    return Column(
      children: [
        Center(
          child: Image.asset('assets/kaleidxscope/red.webp', width: MediaQuery.of(context).size.width - 64, fit: BoxFit.contain),
        ),
        SizedBox(height: _paddingS),
        _buildUnlockSection(),
        SizedBox(height: _paddingL),
        _buildChallengeProgress(),
        if (_songs.isNotEmpty) ...[
          Container(
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, border: Border.all(color: AppColors.tableBorder(brightness), width: 1), borderRadius: BorderRadius.circular(_borderRadiusSmall)),
            padding: EdgeInsets.symmetric(horizontal: _paddingS, vertical: _paddingXS * 0.5),
            child: Center(child: Text('曲目池 | 总计 ${_songs.length} 首歌曲', style: TextStyle(fontSize: _textSizeL, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant))),
          ),
          SizedBox(height: _paddingS),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: _paddingS),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () => setState(() => _isMarkMode = !_isMarkMode),
                  style: ElevatedButton.styleFrom(backgroundColor: _isMarkMode ? Colors.green : AppColors.tableBorder(brightness), foregroundColor: _isMarkMode ? Colors.white : Colors.black, padding: EdgeInsets.symmetric(horizontal: _paddingM, vertical: _paddingXS), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: Text(_isMarkMode ? '标记模式' : '仅查看', style: TextStyle(fontSize: _textSizeS)),
                ),
              ],
            ),
          ),
          if (_isMarkMode)
            Padding(
              padding: EdgeInsets.only(top: _paddingXS),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.info, size: _textSizeS, color: Colors.green), SizedBox(width: _paddingXS), Text('切换到标记模式，点击卡片可切换显示完成状态', style: TextStyle(fontSize: _textSizeXS, color: Colors.green))]),
            ),
          SizedBox(height: _paddingS),
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: _paddingXS, mainAxisSpacing: _paddingXS, childAspectRatio: 2.0),
            itemCount: _songs.length,
            itemBuilder: (context, index) {
              final song = _songs[index];
              final bool isMarked = _manualMarkedIds.contains(song.id.toString());
              return GestureDetector(
                onTap: () {
                  if (_isMarkMode) {
                    setState(() {
                      final songIdStr = song.id.toString();
                      if (_manualMarkedIds.contains(songIdStr)) { _manualMarkedIds.remove(songIdStr); } else { _manualMarkedIds.add(songIdStr); }
                    });
                    _saveMarkedSongsToPrefs();
                  } else {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => SongInfoPage(songId: song.id, initialLevelIndex: 3)));
                  }
                },
                child: Container(
                  decoration: BoxDecoration(color: isMarked ? Colors.lightGreen[100] : Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(_borderRadiusSmall), border: Border.all(color: isMarked ? Colors.green : AppColors.greyHint(brightness), width: 1)),
                  padding: EdgeInsets.all(_paddingXS),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(width: _coverSize, height: _coverSize, child: CoverUtil.buildCoverWidgetWithContext(context, song.id, _coverSize)),
                      SizedBox(width: _paddingXS * 1.5),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(song.title, style: TextStyle(fontSize: _textSizeS, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                          SizedBox(height: _paddingXS * 0.25),
                          Text('${_getTypeDisplay(song.type)} | ${StringUtil.formatVersion2WithFlag(song.basicInfo.from, song.isExtra)}', style: TextStyle(fontSize: _textSizeXS, color: AppColors.greyHint(brightness)), maxLines: 1, overflow: TextOverflow.ellipsis),
                          SizedBox(height: _paddingXS * 0.25),
                          Text(_getDsDisplay(song.ds), style: TextStyle(fontSize: _textSizeXS, color: AppColors.greyHint(brightness)), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ]),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
        // Track 区域
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: _paddingS),
            Divider(color: AppColors.tableBorder(brightness), thickness: 1),
            SizedBox(height: _paddingS),
            Text('Track随机曲目', style: TextStyle(fontSize: _textSizeXL, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
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

  Widget _buildTrackSection(String title, List<Song> songs) {
    final brightness = Theme.of(context).brightness;
    if (songs.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, border: Border.all(color: AppColors.tableBorder(brightness), width: 1), borderRadius: BorderRadius.circular(_borderRadiusSmall)),
          padding: EdgeInsets.symmetric(horizontal: _paddingS, vertical: _paddingXS * 0.5),
          child: Center(child: Text('$title | 总计 ${songs.length} 首歌曲', style: TextStyle(fontSize: _textSizeL, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant))),
        ),
        SizedBox(height: _paddingS),
        GridView.builder(
          shrinkWrap: true, physics: NeverScrollableScrollPhysics(), padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: _paddingXS, mainAxisSpacing: _paddingXS, childAspectRatio: 2.0),
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            return GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SongInfoPage(songId: song.id, initialLevelIndex: 3))),
              child: Container(
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(_borderRadiusSmall), border: Border.all(color: AppColors.greyHint(brightness), width: 1)),
                padding: EdgeInsets.all(_paddingXS),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(width: _coverSize, height: _coverSize, child: CoverUtil.buildCoverWidgetWithContext(context, song.id, _coverSize)),
                    SizedBox(width: _paddingXS * 1.5),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(song.title, style: TextStyle(fontSize: _textSizeS, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                        SizedBox(height: _paddingXS * 0.25),
                        Text('${_getTypeDisplay(song.type)} | ${StringUtil.formatVersion2WithFlag(song.basicInfo.from, song.isExtra)}', style: TextStyle(fontSize: _textSizeXS, color: AppColors.greyHint(brightness)), maxLines: 1, overflow: TextOverflow.ellipsis),
                        SizedBox(height: _paddingXS * 0.25),
                        Text(_getDsDisplay(song.ds), style: TextStyle(fontSize: _textSizeXS, color: AppColors.greyHint(brightness)), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ]),
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
                    IconButton(icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface), onPressed: () => Navigator.of(context).pop()),
                    Expanded(child: Center(child: Text(_getGateTitle(), style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: titleFontSize, fontWeight: FontWeight.bold)))),
                    SizedBox(width: _paddingXL),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  margin: EdgeInsets.fromLTRB(_paddingS, 0, _paddingS, _paddingL),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(_borderRadiusSmall), boxShadow: [defaultShadow(brightness)]),
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(padding: EdgeInsets.symmetric(horizontal: _paddingL, vertical: _paddingS), child: _buildSongList()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
