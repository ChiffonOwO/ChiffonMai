import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:my_first_flutter_app/utils/StringUtil.dart';
import 'package:my_first_flutter_app/utils/ColorUtil.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';
import '../../service/Best50/Best50ConvertToImgService.dart';
import '../../manager/DivingFish/UserBest50Manager.dart';
import '../../manager/DivingFish/MaimaiMusicDataManager.dart';
import '../../manager/DivingFish/UserPlayDataManager.dart';
import '../../manager/MaiTagsManager.dart';
import '../../entity/DXRating/MaiTagsEntity.dart';
import '../SongInfoPage.dart';
import '../../utils/CoverUtil.dart';
import '../../utils/TextStyleUtil.dart';
import '../../entity/DivingFish/RecordItem.dart';

class B50Page extends StatefulWidget {
  final Map<String, dynamic>? b50Data;

  const B50Page({super.key, this.b50Data});

  @override
  _B50PageState createState() => _B50PageState();
}

class _B50PageState extends State<B50Page> {
  Map<String, dynamic>? _b50Data;
  List<Map<String, dynamic>>? _maimaiMusicData;
  List<Map<String, dynamic>> _dxSongs = [];
  List<Map<String, dynamic>> _sdSongs = [];
  List<Map<String, dynamic>> _theoreticalDxSongs = [];
  List<Map<String, dynamic>> _theoreticalSdSongs = [];
  // 存储被截断的相同定数歌曲
  Map<String, dynamic>? _remainingSdSongsInfo; // {ds: 14.7, count: 5, songs: [...]}
  Map<String, dynamic>? _remainingDxSongsInfo;
  bool _isLoading = true;
  bool _isTheoreticalMode = false;
  
  // 标签统计相关
  MaiTagsEntity? _tagsEntity;
  Map<String, Map<String, int>> _tagStats = {}; // 标签分组 → (标签名 → 统计次数)
  bool _isLoadingTags = false;

  @override
  void initState() {
    super.initState();
    _loadB50Data();
  }
  
  @override
  void dispose() {
    super.dispose();
  }

  @override
  void didUpdateWidget(B50Page oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.b50Data != null && widget.b50Data != oldWidget.b50Data) {
      _updateB50Data(widget.b50Data!);
    }
  }

  Future<void> _loadB50Data() async {
    try {
      // 加载maimai音乐数据
      if (await MaimaiMusicDataManager().hasCachedData()) {
        final songs = await MaimaiMusicDataManager().getCachedSongs();
        if (songs != null) {
          setState(() {
            _maimaiMusicData = songs.map((song) => {
              'id': song.id,
              'title': song.title,
              'type': song.type,
              'ds': song.ds,
              'level': song.level,
              'cids': song.cids,
              'charts': song.charts.map((chart) => {
                'notes': chart.notes,
                'charter': chart.charter
              }).toList(),
              'basic_info': {
                'title': song.basicInfo.title,
                'artist': song.basicInfo.artist,
                'genre': song.basicInfo.genre,
                'bpm': song.basicInfo.bpm,
                'release_date': song.basicInfo.releaseDate,
                'from': song.basicInfo.from,
                'is_new': song.basicInfo.isNew
              }
            }).toList();
          });
        }
      } else {
        final maimaiContents =
            await rootBundle.loadString('assets/maimai_music_data.json');
        final maimaiJsonData = json.decode(maimaiContents);

        setState(() {
          _maimaiMusicData = maimaiJsonData;
        });
      }

      // 直接使用外部传入的B50数据
      if (widget.b50Data != null) {
        _updateB50Data(widget.b50Data!);
      } else {
        // 尝试加载缓存的Best50数据
        final best50Manager = UserBest50Manager();
        final cachedBest50Data = await best50Manager.getCachedBest50Data();
        
        if (cachedBest50Data != null) {
          _updateB50Data(cachedBest50Data);
        } else {
          // 尝试从用户游玩数据计算Best50（落雪数据源场景）
          await _calculateBest50FromPlayData();
        }
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 从用户游玩数据计算Best50（落雪数据源场景）
  Future<void> _calculateBest50FromPlayData() async {
    try {
      final userPlayDataManager = UserPlayDataManager();
      final userPlayData = await userPlayDataManager.getCachedUserPlayData();
      
      if (userPlayData == null || userPlayData['records'] == null) {
        setState(() {
          _b50Data = null;
          _dxSongs = [];
          _sdSongs = [];
          _isLoading = false;
        });
        return;
      }

      final records = userPlayData['records'] as List;
      if (records.isEmpty) {
        setState(() {
          _b50Data = null;
          _dxSongs = [];
          _sdSongs = [];
          _isLoading = false;
        });
        return;
      }

      // 将records转换为RecordItem列表
      List<RecordItem> recordItems = records
          .map((item) => RecordItem.fromJson(item as Map<String, dynamic>))
          .toList();

      // 根据歌曲的is_new字段分组
      List<RecordItem> oldSongs = []; // is_new = false
      List<RecordItem> newSongs = [];  // is_new = true

      for (var record in recordItems) {
        bool isNew = _isSongNew(record.songId);
        if (isNew) {
          newSongs.add(record);
        } else {
          oldSongs.add(record);
        }
      }

      // 按ra降序排序并取前N个
      oldSongs.sort((a, b) => b.ra.compareTo(a.ra));
      newSongs.sort((a, b) => b.ra.compareTo(a.ra));

      // Best35: is_new=false 的前35首
      List<RecordItem> best35 = oldSongs.take(35).toList();
      // Best15: is_new=true 的前15首
      List<RecordItem> best15 = newSongs.take(15).toList();

      // 计算总rating
      int totalRating = best35.fold(0, (sum, item) => sum + item.ra) + 
                         best15.fold(0, (sum, item) => sum + item.ra);

      // 转换为Map格式
      List<Map<String, dynamic>> sdSongsMap = best35.map((item) => item.toJson()).toList();
      List<Map<String, dynamic>> dxDongsMap = best15.map((item) => item.toJson()).toList();

      setState(() {
        _b50Data = {
          'rating': totalRating,
          'additional_rating': 0,
          'charts': {
            'sd': sdSongsMap,
            'dx': dxDongsMap,
          }
        };
        _sdSongs = sdSongsMap;
        _dxSongs = dxDongsMap;
        _isLoading = false;
      });

      debugPrint('✅ 从游玩数据计算Best50完成: Best35=${best35.length}首, Best15=${best15.length}首, 总Rating=$totalRating');
    } catch (e) {
      debugPrint('Error calculating Best50 from play data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 根据歌曲ID判断是否为新曲（is_new=true）
  bool _isSongNew(int songId) {
    if (_maimaiMusicData == null) return false;
    
    try {
      // 使用 where() 和 firstWhereOrNull 替代 orElse 返回 null
      var song = _maimaiMusicData!.firstWhere(
        (item) => item['id'] == songId.toString(),
      );
      
      if (song['basic_info'] != null) {
        return song['basic_info']['is_new'] == true;
      }
    } catch (e) {
      // 歌曲未找到时返回 false
      debugPrint('Song $songId not found in music data');
    }
    
    return false;
  }

  void _updateB50Data(Map<String, dynamic> newData) {
    setState(() {
      _b50Data = newData;
      _dxSongs = newData['charts']?['dx'] != null
          ? List<Map<String, dynamic>>.from(newData['charts']['dx'])
          : [];
      _sdSongs = newData['charts']?['sd'] != null
          ? List<Map<String, dynamic>>.from(newData['charts']['sd'])
          : [];
      _isLoading = false;
    });
    _calculateTheoreticalBest50();
    _loadTagDataAndCalculateStats();
  }

  // 计算理论Rating Best50
  void _calculateTheoreticalBest50() {
    if (_maimaiMusicData == null) return;

    List<Map<String, dynamic>> allSongs = [];

    for (var song in _maimaiMusicData!) {
      int songId = int.parse(song['id']);
      String type = song['type'];
      bool isNew = song['basic_info']?['is_new'] == true;
      List<dynamic> charts = song['charts'];
      List<dynamic> cids = song['cids'] ?? [];

      // 过滤条件：
      // 1. 过滤掉id为6位数的歌曲（songId >= 100000，宴会场谱面）
      // 2. 过滤掉从maidata追加的歌曲（cids全为0）
      bool isMaidataSong = cids.isNotEmpty && cids.every((cid) => cid == 0);
      if (songId >= 100000 || isMaidataSong) {
        continue;
      }

      for (int levelIndex = 0; levelIndex < charts.length; levelIndex++) {
        dynamic chart = charts[levelIndex];
        List<dynamic> notes = chart['notes'];
        int notesSum = notes.fold(0, (sum, note) => sum + (note as int));
        int maxScore = notesSum * 3;
        double ds = double.parse(song['ds'][levelIndex].toString());

        // 计算理论Rating：ds * 0.224 * 100.5 向下取整
        int ra = (ds * 0.224 * 100.5).floor();

        allSongs.add({
          'song_id': songId,
          'title': song['title'],
          'type': type,
          'level_index': levelIndex,
          'ds': ds,
          'ra': ra,
          'achievements': 101.0,
          'dxScore': maxScore,
          'fc': 'app',
          'fs': 'fsdp',
          'rate': 'sssp',
          'is_new': isNew,
          'stars': '\u27266',
        });
      }
    }

    // 按is_new分组（DX新歌和SD老歌）
    List<Map<String, dynamic>> newSongs = allSongs.where((s) => s['is_new'] == true).toList();
    List<Map<String, dynamic>> oldSongs = allSongs.where((s) => s['is_new'] == false).toList();

    // 按ra降序排序
    newSongs.sort((a, b) => b['ra'].compareTo(a['ra']));
    oldSongs.sort((a, b) => b['ra'].compareTo(a['ra']));

    // 取Best15和Best35，并计算剩余相同定数的歌曲
    _theoreticalDxSongs = _takeWithRemaining(newSongs, 15, (info) => _remainingDxSongsInfo = info);
    _theoreticalSdSongs = _takeWithRemaining(oldSongs, 35, (info) => _remainingSdSongsInfo = info);
  }

  // 取前limit个元素，并计算剩余相同定数的歌曲
  List<Map<String, dynamic>> _takeWithRemaining(
      List<Map<String, dynamic>> songs,
      int limit,
      void Function(Map<String, dynamic>?) onRemaining,
  ) {
    if (songs.length <= limit) {
      onRemaining(null);
      return songs.toList();
    }

    // 取前limit个
    List<Map<String, dynamic>> taken = songs.take(limit).toList();
    
    // 获取最后一个元素的ds值
    double lastDs = taken.last['ds'] ?? 0.0;
    
    // 找出所有被截断的相同ds的歌曲
    List<Map<String, dynamic>> remaining = songs.skip(limit).where((s) {
      return (s['ds'] ?? 0.0) == lastDs;
    }).toList();

    if (remaining.isNotEmpty) {
      onRemaining({
        'ds': lastDs,
        'count': remaining.length,
        'songs': remaining,
      });
    } else {
      onRemaining(null);
    }

    return taken;
  }

  // 切换理论模式
  void _toggleTheoreticalMode() {
    setState(() {
      _isTheoreticalMode = !_isTheoreticalMode;
    });
  }

  // 加载标签数据并计算统计
  Future<void> _loadTagDataAndCalculateStats() async {
    setState(() {
      _isLoadingTags = true;
    });
    
    try {
      final maiTagsManager = MaiTagsManager();
      _tagsEntity = await maiTagsManager.getTags();
      
      if (_tagsEntity != null) {
        await _calculateTagGroupStats();
      }
    } catch (e) {
      debugPrint('Error loading tag data: $e');
    } finally {
      setState(() {
        _isLoadingTags = false;
      });
    }
  }

  // 计算各标签统计
  Future<void> _calculateTagGroupStats() async {
    if (_tagsEntity == null || _maimaiMusicData == null) {
      return;
    }
    
    final maiTagsManager = MaiTagsManager();
    final tagIdToNameMap = await maiTagsManager.getTagIdToNameMap();
    final groupIdToNameMap = await maiTagsManager.getGroupIdToNameMap();
    
    // 构建标签ID → 分组名称 的映射
    Map<int, String> tagIdToGroupName = {};
    for (var tag in _tagsEntity!.tags) {
      tagIdToGroupName[tag.id] = groupIdToNameMap[tag.groupId] ?? '未分类';
    }
    
    // 获取所有歌曲标题到标签的映射
    Map<String, Set<int>> songTitleToTagIds = {};
    for (var tagSong in _tagsEntity!.tagSongs) {
      String key = '${tagSong.songId}|${tagSong.sheetType}|${tagSong.sheetDifficulty}';
      if (!songTitleToTagIds.containsKey(key)) {
        songTitleToTagIds[key] = {};
      }
      songTitleToTagIds[key]!.add(tagSong.tagId);
    }
    
    // 统计各标签的出现次数
    Map<String, Map<String, int>> stats = {};
    List<Map<String, dynamic>> allSongs = [
      ...(_isTheoreticalMode ? _theoreticalSdSongs : _sdSongs),
      ...(_isTheoreticalMode ? _theoreticalDxSongs : _dxSongs)
    ];
    
    for (var song in allSongs) {
      int songId = song['song_id'];
      int levelIndex = song['level_index'];
      
      int index = _maimaiMusicData!.indexWhere((m) => int.parse(m['id']) == songId);
      Map<String, dynamic> songData = index >= 0 ? _maimaiMusicData![index] : {};
      
      String songTitle = songData['basic_info']?['title'] ?? '';
      String songType = songData['type'] ?? 'SD';
      
      String sheetType = songType == 'DX' ? 'dx' : 'std';
      String difficulty = _getDifficultyByIndex(levelIndex);
      
      String key = '$songTitle|$sheetType|$difficulty';
      Set<int>? tagIds = songTitleToTagIds[key];
      
      if (tagIds != null && tagIds.isNotEmpty) {
        for (int tagId in tagIds) {
          String tagName = tagIdToNameMap[tagId] ?? '未知标签';
          String groupName = tagIdToGroupName[tagId] ?? '未分类';
          
          if (!stats.containsKey(groupName)) {
            stats[groupName] = {};
          }
          if (!stats[groupName]!.containsKey(tagName)) {
            stats[groupName]![tagName] = 0;
          }
          stats[groupName]![tagName] = stats[groupName]![tagName]! + 1;
        }
      }
    }
    
    setState(() {
      _tagStats = stats;
    });
  }

  // 根据难度索引获取难度名称
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

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_b50Data == null || (_dxSongs.isEmpty && _sdSongs.isEmpty)) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/background.png'),
                  fit: BoxFit.cover,
                  opacity: 1.0,
                ),
              ),
            ),
            Center(
              child: Transform.translate(
                offset: const Offset(0, -20),
                child: Transform.scale(
                  scale: 1,
                  child: Image.asset(
                    'assets/chiffon2.png',
                    fit: BoxFit.cover,
                    opacity: const AlwaysStoppedAnimation(1),
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).size.height * 0.12,
              left: MediaQuery.of(context).size.width * 0.02,
              right: MediaQuery.of(context).size.width * 0.02,
              bottom: MediaQuery.of(context).size.height * 0.03,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12.0),
                  boxShadow: [
                    BoxShadow(
                      color: brightness == Brightness.dark ? Colors.black.withValues(alpha: 0.3) : Colors.black12,
                      blurRadius: 8.0,
                      offset: Offset(2.0, 2.0),
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.refresh,
                        size: 64,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      SizedBox(height: 16),
                      Text(
                        '暂无Best50数据',
                        style: TextStyle(
                          fontSize: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '请返回首页点击"刷新数据"按钮获取',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  "Best50查询",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              left: 10,
              child: GestureDetector(
                onTap: () {
                  debugPrint('返回按钮被点击');
                  Navigator.pop(context);
                },
                child: Container(
                  padding: EdgeInsets.all(16),
                  color: Colors.transparent,
                  child: Icon(Icons.arrow_back,
                      color: Theme.of(context).colorScheme.onSurface, size: 28),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final Color textPrimaryColor = Theme.of(context).colorScheme.onSurface;
    final double borderRadiusSmall = 8.0;
    final BoxShadow defaultShadow = AppColors.defaultShadow(brightness);

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
                    _isTheoreticalMode ? '理论Rating Best50' : 'Best50查询',
                    style: TextStyle(
                      color: textPrimaryColor,
                      fontSize: MediaQuery.of(context).size.width * 0.06,
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
                    color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(borderRadiusSmall),
                    boxShadow: [defaultShadow],
                  ),
                  child: SingleChildScrollView(
                    padding:
                        EdgeInsets.all(MediaQuery.of(context).size.width * 0.03),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildRatingSection(),
                        SizedBox(height: 12.0),
                        if (!_isTheoreticalMode) _buildTagStatsSection(context),
                        if (!_isTheoreticalMode) SizedBox(height: 12.0),
                        _buildActionButtons(),
                        SizedBox(height: 12.0),
                        _buildSectionTitle(_isTheoreticalMode ? '理论Best35 | 非当前版本最高定数' : 'Best35 | 非当前版本最好成绩', context),
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.015),
                        _buildDataCardGrid(
                          _isTheoreticalMode ? _theoreticalSdSongs : _sdSongs, 
                          1.75,
                          remainingInfo: _isTheoreticalMode ? _remainingSdSongsInfo : null,
                        ),
                        SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                        _buildSectionTitle(_isTheoreticalMode ? '理论Best15 | 当前版本最高定数' : 'Best15 | 当前版本最好成绩', context),
                        SizedBox(height: 12.0),
                        _buildDataCardGrid(
                          _isTheoreticalMode ? _theoreticalDxSongs : _dxSongs, 
                          1.75,
                          remainingInfo: _isTheoreticalMode ? _remainingDxSongsInfo : null,
                        ),
                      ],
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

  // Best50 历史快照
  static const String _snapshotKey = 'b50_snapshots';
  List<Map<String, dynamic>> _snapshots = [];

  Future<void> _loadSnapshots() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_snapshotKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        _snapshots = (json.decode(jsonStr) as List).map((e) => e as Map<String, dynamic>).toList();
      }
    } catch (_) {}
  }

  Future<void> _saveSnapshot() async {
    if (_b50Data == null) return;
    try {
      await _loadSnapshots();
      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      _snapshots.insert(0, {
        'date': dateStr,
        'timestamp': now.millisecondsSinceEpoch,
        'rating': _b50Data!['rating'] ?? 0,
        'charts': {'sd': _sdSongs, 'dx': _dxSongs},
      });
      // 最多保留 10 条
      if (_snapshots.length > 10) _snapshots = _snapshots.take(10).toList();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_snapshotKey, json.encode(_snapshots));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Best50 记录已保存 ($dateStr)'), duration: Duration(seconds: 1)));
      }
    } catch (e) {
      debugPrint('保存快照失败: $e');
    }
  }

  Future<void> _deleteSnapshot(int index) async {
    try {
      _snapshots.removeAt(index);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_snapshotKey, json.encode(_snapshots));
    } catch (_) {}
  }

  void _showSnapshotDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final dialogBrightness = Theme.of(ctx).brightness;
          return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.history, size: 22, color: Theme.of(ctx).colorScheme.onSurface),
              SizedBox(width: 8),
              Text('Best50 历史记录'),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            child: _snapshots.isEmpty
                ? Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('暂无保存的记录，点击"保存当前记录"按钮保存', style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _snapshots.length,
                    itemBuilder: (ctx, i) {
                      final s = _snapshots[i];
                      return Container(
                        margin: EdgeInsets.only(bottom: 6),
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.tableBorder(dialogBrightness)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.bookmark, color: AppColors.linkBlue(dialogBrightness), size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Rating: ${s['rating']}',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text(s['date'] ?? '',
                                    style: TextStyle(fontSize: 11, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () async {
                                Navigator.pop(ctx);
                                final charts = s['charts'];
                                setState(() {
                                  _b50Data = {'rating': s['rating'], 'charts': charts};
                                  _sdSongs = List<Map<String, dynamic>>.from(charts['sd'] ?? []);
                                  _dxSongs = List<Map<String, dynamic>>.from(charts['dx'] ?? []);
                                });
                              },
                              child: Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(Icons.remove_red_eye, size: 18, color: AppColors.linkBlue(dialogBrightness)),
                              ),
                            ),
                            GestureDetector(
                              onTap: () async {
                                await _deleteSnapshot(i);
                                setDialogState(() {});
                              },
                              child: Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(Icons.delete_outline, size: 18, color: AppColors.errorRed(dialogBrightness)),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('关闭')),
          ],
        );},
      ),
    );
  }

  Widget _buildRatingSection() {
    // 选择显示的数据
    List<Map<String, dynamic>> currentSdSongs = _isTheoreticalMode ? _theoreticalSdSongs : _sdSongs;
    List<Map<String, dynamic>> currentDxSongs = _isTheoreticalMode ? _theoreticalDxSongs : _dxSongs;

    // 计算Rating
    int best35Sum =
        currentSdSongs.fold(0, (sum, song) => sum + ((song['ra'] ?? 0) as int));
    double best35Average =
        currentSdSongs.isNotEmpty ? best35Sum / currentSdSongs.length : 0.0;

    int best15Sum =
        currentDxSongs.fold(0, (sum, song) => sum + ((song['ra'] ?? 0) as int));
    double best15Average =
        currentDxSongs.isNotEmpty ? best15Sum / currentDxSongs.length : 0.0;

    int rating = _isTheoreticalMode ? best35Sum + best15Sum : (_b50Data?['rating'] ?? 0);
    double ratingAverage = (best35Sum + best15Sum) / 50;

    // 理论模式下使用固定值
    double best50AchievementAverage;
    double best35AchievementAverage;
    double best15AchievementAverage;
    double best50ScoreRateAverage;
    double best35ScoreRateAverage;
    double best15ScoreRateAverage;

    if (_isTheoreticalMode) {
      best50AchievementAverage = 101.0;
      best35AchievementAverage = 101.0;
      best15AchievementAverage = 101.0;
      best50ScoreRateAverage = 1.0;
      best35ScoreRateAverage = 1.0;
      best15ScoreRateAverage = 1.0;
    } else {
      double sdAchievementsSum = currentSdSongs.fold(0.0,
          (sum, song) => sum + (double.parse(song['achievements'].toString())));
      double dxAchievementsSum = currentDxSongs.fold(0.0,
          (sum, song) => sum + (double.parse(song['achievements'].toString())));

      best50AchievementAverage =
          (sdAchievementsSum + dxAchievementsSum) / (currentSdSongs.length + currentDxSongs.length);
      best35AchievementAverage =
          currentSdSongs.isNotEmpty ? sdAchievementsSum / currentSdSongs.length : 0.0;
      best15AchievementAverage =
          currentDxSongs.isNotEmpty ? dxAchievementsSum / currentDxSongs.length : 0.0;

      double sdScoreRateSum = currentSdSongs.fold(0.0, (sum, song) {
        int songId = song['song_id'];
        int levelIndex = song['level_index'];
        int score = song['dxScore'];
        return sum + _calculateScoreRate(songId, levelIndex, score);
      });

      double dxScoreRateSum = currentDxSongs.fold(0.0, (sum, song) {
        int songId = song['song_id'];
        int levelIndex = song['level_index'];
        int score = song['dxScore'];
        return sum + _calculateScoreRate(songId, levelIndex, score);
      });

      best50ScoreRateAverage = (currentSdSongs.length + currentDxSongs.length) > 0
          ? (sdScoreRateSum + dxScoreRateSum) /
              (currentSdSongs.length + currentDxSongs.length)
          : 0.0;

      best35ScoreRateAverage =
          currentSdSongs.isNotEmpty ? sdScoreRateSum / currentSdSongs.length : 0.0;
      best15ScoreRateAverage =
          currentDxSongs.isNotEmpty ? dxScoreRateSum / currentDxSongs.length : 0.0;
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2.0),
        borderRadius: BorderRadius.circular(8.0),
      ),
      padding: EdgeInsets.all(12.0),
      // 理论模式下使用单列居中布局，否则使用双列布局
      child: _isTheoreticalMode
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '理论Rating',
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width * 0.05,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: 8.0),
                RichText(
                  text: TextSpan(
                    children: [
                      TextStyleUtil.span(
                        rating.toString(),
                        TextStyle(
                          fontSize: MediaQuery.of(context).size.width * 0.05,
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextStyleUtil.span(
                        ' (平均${ratingAverage.toStringAsFixed(1)})',
                        TextStyle(
                          fontSize: MediaQuery.of(context).size.width * 0.035,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Best 35',
                          style: TextStyle(
                            fontSize: MediaQuery.of(context).size.width * 0.038,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        SizedBox(height: 4.0),
                        RichText(
                          text: TextSpan(
                            children: [
                              TextStyleUtil.span(
                                best35Sum.toString(),
                                TextStyle(
                                  fontSize: MediaQuery.of(context).size.width * 0.04,
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextStyleUtil.span(
                                ' (平均${best35Average.toStringAsFixed(1)})',
                                TextStyle(
                                  fontSize: MediaQuery.of(context).size.width * 0.028,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Best 15',
                          style: TextStyle(
                            fontSize: MediaQuery.of(context).size.width * 0.038,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        SizedBox(height: 4.0),
                        RichText(
                          text: TextSpan(
                            children: [
                              TextStyleUtil.span(
                                best15Sum.toString(),
                                TextStyle(
                                  fontSize: MediaQuery.of(context).size.width * 0.04,
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextStyleUtil.span(
                                ' (平均${best15Average.toStringAsFixed(1)})',
                                TextStyle(
                                  fontSize: MediaQuery.of(context).size.width * 0.028,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rating',
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width * 0.045,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(height: 4.0),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextStyleUtil.span(
                              rating.toString(),
                              TextStyle(
                                fontSize: MediaQuery.of(context).size.width * 0.04,
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextStyleUtil.span(
                              '(平均${ratingAverage.toStringAsFixed(1)})',
                              TextStyle(
                                fontSize: MediaQuery.of(context).size.width * 0.03,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 8.0),
                      Text(
                        'Best 35',
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width * 0.04,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextStyleUtil.span(
                              best35Sum.toString(),
                              TextStyle(
                                fontSize: MediaQuery.of(context).size.width * 0.04,
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextStyleUtil.span(
                              '(平均${best35Average.toStringAsFixed(1)})',
                              TextStyle(
                                fontSize: MediaQuery.of(context).size.width * 0.03,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 8.0),
                      Text(
                        'Best 15',
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width * 0.04,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextStyleUtil.span(
                              best15Sum.toString(),
                              TextStyle(
                                fontSize: MediaQuery.of(context).size.width * 0.04,
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextStyleUtil.span(
                              '(平均${best15Average.toStringAsFixed(1)})',
                              TextStyle(
                                fontSize: MediaQuery.of(context).size.width * 0.03,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Best 50 平均达成率/DX分达成率',
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width * 0.035,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      _buildDualDecimalText(
                          best50AchievementAverage, best50ScoreRateAverage * 100),
                      SizedBox(height: 8.0),
                      Text(
                        'Best 35 平均达成率/DX分达成率',
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width * 0.035,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      _buildDualDecimalText(
                          best35AchievementAverage, best35ScoreRateAverage * 100),
                      SizedBox(height: 8.0),
                      Text(
                        'Best 15 平均达成率/DX分达成率',
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width * 0.035,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      _buildDualDecimalText(
                          best15AchievementAverage, best15ScoreRateAverage * 100),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // 构建标签统计区域
  Widget _buildTagStatsSection(BuildContext context) {
    final tagBrightness = Theme.of(context).brightness;

    if (_isLoadingTags) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2.0),
          borderRadius: BorderRadius.circular(8.0),
        ),
        padding: EdgeInsets.all(16.0),
        child: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      );
    }

    if (_tagStats.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2.0),
          borderRadius: BorderRadius.circular(8.0),
        ),
        padding: EdgeInsets.all(16.0),
        child: Center(
          child: Text(
            '暂无标签数据',
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.width * 0.035,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    // 分组颜色映射
    Map<String, Color> groupColors = {
      '配置': AppColors.linkBlue(tagBrightness),
      '评价': Colors.amber[700]!,
      '难度': AppColors.linkBlue(tagBrightness),
    };

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2.0),
        borderRadius: BorderRadius.circular(8.0),
      ),
      padding: EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '标签统计',
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.width * 0.04,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 8.0),
          ..._tagStats.entries.map((groupEntry) {
            String groupName = groupEntry.key;
            Map<String, int> tagCounts = groupEntry.value;
            Color groupColor = groupColors[groupName] ?? Theme.of(context).colorScheme.onSurfaceVariant;

            // 对组内标签按数量降序排序
            List<MapEntry<String, int>> sortedTags = tagCounts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 分组标题
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  margin: EdgeInsets.only(top: 8.0),
                  decoration: BoxDecoration(
                    color: groupColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6.0),
                    border: Border.all(color: groupColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    groupName,
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).size.width * 0.035,
                      fontWeight: FontWeight.bold,
                      color: groupColor,
                    ),
                  ),
                ),
                SizedBox(height: 6.0),
                // 该分组下的标签统计条
                ...sortedTags.map((tagEntry) {
                  double percentage = (tagEntry.value / 50) * 100;
                  Color barColor = groupColor.withOpacity(0.7);

                  return Padding(
                    padding: EdgeInsets.only(bottom: 4.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            tagEntry.key,
                            style: TextStyle(
                              fontSize: MediaQuery.of(context).size.width * 0.03,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 8.0),
                        Expanded(
                          flex: 6,
                          child: Container(
                            height: 20.0,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            child: FractionallySizedBox(
                              widthFactor: percentage / 100,
                              alignment: Alignment.centerLeft,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: barColor,
                                  borderRadius: BorderRadius.circular(10.0),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8.0),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${tagEntry.value}(${(percentage).toStringAsFixed(0)}%)',
                            style: TextStyle(
                              fontSize: MediaQuery.of(context).size.width * 0.03,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                SizedBox(height: 4.0),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2.0),
        borderRadius: BorderRadius.circular(8.0),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      child: Center(
        child: Text(
          title,
          style: TextStyle(
            fontSize: MediaQuery.of(context).size.width * 0.04,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  // 构建"查看剩余"卡片
  Widget _buildRemainingCard(Map<String, dynamic> remainingInfo) {
    final remainingBrightness = Theme.of(context).brightness;
    double ds = remainingInfo['ds'] ?? 0.0;
    int count = remainingInfo['count'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2.0),
        borderRadius: BorderRadius.circular(8.0),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: TextButton(
        onPressed: () {
          _showRemainingSongsDialog(remainingInfo, '');
        },
        style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6.0),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.music_note, color: AppColors.linkBlue(remainingBrightness), size: MediaQuery.of(context).size.width * 0.06),
            SizedBox(height: 4.0),
            Text(
              '剩余$count首',
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width * 0.03,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              '${ds.toStringAsFixed(1)}',
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width * 0.028,
                color: AppColors.linkBlue(remainingBrightness),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 显示剩余歌曲对话框
  void _showRemainingSongsDialog(Map<String, dynamic> remainingInfo, String sectionName) {
    double ds = remainingInfo['ds'] ?? 0.0;
    List<Map<String, dynamic>> songs = remainingInfo['songs'] ?? [];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${sectionName}剩余谱面 (定数 ${ds.toStringAsFixed(1)})'),
        contentPadding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: songs.length,
              itemBuilder: (context, index) {
                var song = songs[index];
                String difficultyLabel = _getDifficultyLabel(song['level_index'] ?? 0);
                String type = song['type'] ?? '';
                bool isDxMode = type == 'DX';
                
                return ListTile(
                  contentPadding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                  leading: CoverUtil.buildCoverWidgetWithContext(context, song['song_id'].toString(), 50),
                  title: Row(
                    children: [
                      Text(
                        isDxMode ? 'DX' : 'ST',
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width * 0.04,
                          fontWeight: FontWeight.bold,
                          color: isDxMode ? AppColors.warningOrange(Theme.of(context).brightness) : AppColors.linkBlue(Theme.of(context).brightness),
                        ),
                      ),
                      SizedBox(width: 8.0),
                      Expanded(
                        child: Text(
                          song['title'] ?? '未知歌曲',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: MediaQuery.of(context).size.width * 0.04,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text('$difficultyLabel | ${song['ds']} | RA: ${song['ra']}'),
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('关闭'),
          ),
        ],
      ),
    );
  }

  // 获取难度标签
  String _getDifficultyLabel(int levelIndex) {
    List<String> labels = ['Basic', 'Advanced', 'Expert', 'Master', 'Re:Master'];
    return levelIndex >= 0 && levelIndex < labels.length ? labels[levelIndex] : 'Unknown';
  }

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
    Color starsColor = Colors.white,
  }) {
    final gameBrightness = Theme.of(context).brightness;
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        border: Border.all(color: Colors.black, width: 2.0),
        borderRadius: BorderRadius.circular(8.0),
      ),
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.02),
      child: LayoutBuilder(
        builder: (context, constraints) {
          double screenWidth = MediaQuery.of(context).size.width;

          double songNameFontSize = screenWidth * 0.035;
          double decimalMainFontSize = screenWidth * 0.04;
          double decimalSmallFontSize = screenWidth * 0.03;
          double otherFontSize = screenWidth * 0.025;
          double gradeFontSize = screenWidth * 0.022;
          double dxFontSize = screenWidth * 0.025;

          double coverSize = screenWidth * 0.12;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: coverSize,
                    height: coverSize,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border.all(color: Colors.black, width: 1.0),
                    ),
                    child: songId != null
                        ? CoverUtil.buildCoverWidgetWithContext(context, songId.toString(), coverSize)
                        : Center(
                            child: Text('曲绘',
                                style: TextStyle(fontSize: coverSize * 0.24)),
                          ),
                  ),
                  SizedBox(height: screenWidth * 0.01),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
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
                            color: AppColors.warningOrange(gameBrightness),
                          ),
                        ),
                      if (!dxMode && !isUtage)
                        Text(
                          'ST',
                          style: TextStyle(
                            fontSize: dxFontSize,
                            fontWeight: FontWeight.bold,
                            color: AppColors.linkBlue(gameBrightness),
                          ),
                        ),
                      SizedBox(width: screenWidth * 0.01),
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
                ],
              ),
              SizedBox(width: screenWidth * 0.02),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      songName,
                      style: TextStyle(
                        fontSize: songNameFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    SizedBox(height: screenWidth * 0.007),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          achievementRate.toStringAsFixed(4).split('.')[0],
                          style: TextStyle(
                            fontSize: decimalMainFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '.${achievementRate.toStringAsFixed(4).split('.')[1]}%',
                          style: TextStyle(
                            fontSize: decimalSmallFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          '$rating | $score | ',
                          style: TextStyle(
                            fontSize: otherFontSize,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          stars,
                          style: TextStyle(
                            fontSize: otherFontSize,
                            color: starsColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      grade,
                      style: TextStyle(
                        fontSize: gradeFontSize,
                        fontWeight: FontWeight.bold,
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
    );
  }

  Widget _buildDecimalText(double value, BuildContext context,
      {bool isPercentage = false,
      int decimalPlaces = 4,
      Color color = Colors.white}) {
    String text = value.toStringAsFixed(decimalPlaces);

    List<String> parts = text.split('.');
    String integerPart = parts[0];
    String decimalPart = parts.length > 1 ? '.${parts[1]}' : '';
    String percentageSymbol = isPercentage ? '%' : '';

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          integerPart,
          style: TextStyle(
            fontSize: MediaQuery.of(context).size.width * 0.045,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          '$decimalPart$percentageSymbol',
          style: TextStyle(
            fontSize: MediaQuery.of(context).size.width * 0.035,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildDualDecimalText(double value1, double value2,
      {int decimalPlaces1 = 4,
      int decimalPlaces2 = 2,
      Color? color}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedColor = color ?? Theme.of(context).colorScheme.onSurface;
        double fontSize = MediaQuery.of(context).size.width * 0.04;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDecimalText(value1, context,
                decimalPlaces: decimalPlaces1, color: resolvedColor),
            Text(
              '/',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: resolvedColor,

              ),
            ),
            _buildDecimalText(value2, context,
                decimalPlaces: decimalPlaces2, color: resolvedColor),
          ],
        );
      },
    );
  }

  Widget _buildDataCardGrid(
      List<Map<String, dynamic>> songs, 
      double childAspectRatio, 
      {Map<String, dynamic>? remainingInfo}) {
    int itemCount = songs.length + (remainingInfo != null ? 1 : 0);
    
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: MediaQuery.of(context).size.width * 0.01,
        mainAxisSpacing: MediaQuery.of(context).size.width * 0.01,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index < songs.length) {
          return _buildDataGameCard(songs[index]);
        } else {
          // 最后一个位置显示"查看剩余"卡片
          return _buildRemainingCard(remainingInfo!);
        }
      },
    );
  }

  Widget _buildDataGameCard(Map<String, dynamic> songData) {
    double achievementRate = double.parse(songData['achievements'].toString());
    int score = songData['dxScore'];
    String fc = songData['fc'] ?? '';
    String fs = songData['fs'] ?? '';
    double difficulty = double.parse(songData['ds'].toString());
    String rate = songData['rate'];
    int levelIndex = songData['level_index'];
    int rating = songData['ra'];
    String type = songData['type'];
    String title = songData['title'];
    int songId = songData['song_id'];

    // 理论模式下使用固定值
    double scoreRate = _isTheoreticalMode ? 1.0 : _calculateScoreRate(songId, levelIndex, score);
    String stars = _isTheoreticalMode ? '\u27266' : StringUtil.formatStars(scoreRate);
    Color starsColor = _isTheoreticalMode ? Colors.yellow : ColorUtil.getStarsColor(stars);

    String fcText = _isTheoreticalMode ? 'AP+' : (fc.isNotEmpty ? StringUtil.formatFC(fc) : '-');
    String fsText = _isTheoreticalMode ? 'FDX+' : (fs.isNotEmpty ? StringUtil.formatFS(fs) : '-');
    String rateText = _isTheoreticalMode ? 'SSS+' : StringUtil.formatRate(rate);

    String grade = '$rateText | $fcText | $fsText';

      Color cardColor;
      if (songId.toString().length == 6) {
        cardColor = AppColors.utageCard;
      } else {
        cardColor = ColorUtil.getCardColor(levelIndex);
      }

      bool dxMode = type == 'DX';
      bool isUtage = songId.toString().length == 6;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SongInfoPage(
              songId: songId.toString(),
              initialLevelIndex: levelIndex,
              isDefaultLevelIndex: false,
            ),
          ),
        );
      },
      child: _buildGameCard(
        cardColor: cardColor,
        songName: title,
        achievementRate: achievementRate,
        difficulty: difficulty,
        dxMode: dxMode,
        isUtage: isUtage,
        score: score,
        rating: rating,
        stars: stars,
        grade: grade,
        songId: songId,
        starsColor: starsColor,
      ),
    );
  }

  double _calculateScoreRate(int songId, int levelIndex, int score) {
    if (_maimaiMusicData == null) return 0.0;

    int songIndex = _maimaiMusicData!.indexWhere(
      (item) => item['id'] == songId.toString(),
    );

    if (songIndex == -1) return 0.0;
    dynamic songData = _maimaiMusicData![songIndex];

    if (songData['charts'] == null) return 0.0;

    List<dynamic> charts = songData['charts'];
    if (levelIndex < 0 || levelIndex >= charts.length) return 0.0;

    dynamic chart = charts[levelIndex];
    if (chart['notes'] == null) return 0.0;

    List<dynamic> notes = chart['notes'];
    int notesSum = notes.fold(0, (sum, note) => sum + (note as int));
    int maxScore = notesSum * 3;

    return maxScore > 0 ? score / maxScore : 0.0;
  }

  Widget _buildActionButtons() {
    final actionBrightness = Theme.of(context).brightness;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => _saveSnapshot(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.linkBlue(actionBrightness),
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.save, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text('保存当前记录', style: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.033,
                      color: Colors.white, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  await _loadSnapshots();
                  _showSnapshotDialog();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.linkBlue(actionBrightness),
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.history, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text('历史记录', style: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.033,
                      color: Colors.white, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
              debugPrint('=== EXPORT BUTTON CLICKED ===');
              try {
                await _exportToImage();
              } catch (e) {
                debugPrint('Error in export: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.linkBlue(actionBrightness),
              padding: EdgeInsets.symmetric(vertical: 12.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image, color: Colors.white),
                SizedBox(width: 8.0),
                Text(
                  '导出为图片',
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width * 0.035,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: 8.0),
        Expanded(
          child: ElevatedButton(
            onPressed: _toggleTheoreticalMode,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isTheoreticalMode ? AppColors.warningOrange(actionBrightness) : AppColors.successGreen(actionBrightness),
              padding: EdgeInsets.symmetric(vertical: 12.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.trending_up, color: Colors.white),
                SizedBox(width: 8.0),
                Text(
                  _isTheoreticalMode ? '返回实际Best50' : '查看理论Rating B50',
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width * 0.035,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
    ],
    );
  }

  // 请求存储权限
  Future<bool> _requestStoragePermission() async {
    debugPrint('Page: _requestStoragePermission called');
    debugPrint('Page: Platform.isAndroid = ${Platform.isAndroid}');
    
    if (Platform.isAndroid) {
      debugPrint('Page: Running on Android');
      
      // 策略：同时请求 storage 和 photos 权限，确保覆盖所有 Android 版本
      // Android 13+ 需要 photos/videos 权限
      // Android 12 及以下需要 storage 权限
      
      // 先检查已有权限状态
      debugPrint('Page: Checking existing permissions...');
      PermissionStatus storageStatus = await Permission.storage.status;
      PermissionStatus photosStatus = await Permission.photos.status;
      PermissionStatus videosStatus = await Permission.videos.status;
      
      debugPrint('Page: Storage status = $storageStatus');
      debugPrint('Page: Photos status = $photosStatus');
      debugPrint('Page: Videos status = $videosStatus');
      
      // 如果任何一个权限已授予，直接返回成功
      if (storageStatus.isGranted || photosStatus.isGranted || videosStatus.isGranted) {
        debugPrint('Page: At least one permission already granted');
        return true;
      }
      
      // 请求权限：同时请求 storage 和 photos
      debugPrint('Page: Requesting storage, photos and videos permissions...');
      Map<Permission, PermissionStatus> statuses = await [
        Permission.storage,
        Permission.photos,
        Permission.videos,
      ].request();
      
      bool storageGranted = statuses[Permission.storage]?.isGranted ?? false;
      bool photosGranted = statuses[Permission.photos]?.isGranted ?? false;
      bool videosGranted = statuses[Permission.videos]?.isGranted ?? false;
      
      debugPrint('Page: Storage granted = $storageGranted');
      debugPrint('Page: Photos granted = $photosGranted');
      debugPrint('Page: Videos granted = $videosGranted');
      
      return storageGranted || photosGranted || videosGranted;
    } else {
      // 非 Android 平台
      debugPrint('Page: Non-Android platform');
      PermissionStatus status = await Permission.storage.request();
      return status.isGranted;
    }
  }

  Future<void> _exportToImage() async {
    try {
      debugPrint('=== EXPORT TO IMAGE STARTED ===');
      debugPrint('Current context: $context');
      
      // 先请求存储权限
      debugPrint('Step 1: Requesting storage permission from page...');
      bool hasPermission = await _requestStoragePermission();
      debugPrint('Step 1 completed: hasPermission = $hasPermission');
      
      if (!hasPermission) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('权限不足'),
            content: Text('需要存储权限才能导出图片到相册，请在设置中开启权限'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('确定'),
              ),
            ],
          ),
        );
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('导出中'),
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16.0),
              Text('正在生成图片...'),
            ],
          ),
        ),
      );

      final file = await B50ConvertToImg.convertToImage(
        context,
        _b50Data,
        _isTheoreticalMode ? _theoreticalSdSongs : _sdSongs,
        _isTheoreticalMode ? _theoreticalDxSongs : _dxSongs,
        _maimaiMusicData,
        isTheoreticalMode: _isTheoreticalMode,
      );

      // 先关闭"导出中"对话框
      Navigator.of(context, rootNavigator: true).pop();

      if (file != null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('导出成功'),
            content: Text('图片已保存到：\n${file.path}'),
            actions: [
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: file.path));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('路径已复制到剪贴板')),
                  );
                },
                child: Text('复制路径'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                child: Text('确定'),
              ),
            ],
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('导出失败'),
            content: Text('图片导出失败，请重试'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                child: Text('确定'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // 确保关闭任何打开的对话框
      try {
        Navigator.of(context, rootNavigator: true).pop();
      } catch (_) {}
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('导出失败'),
          content: Text('图片导出失败：${e.toString()}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
              child: Text('确定'),
            ),
          ],
        ),
      );
    }
  }
}