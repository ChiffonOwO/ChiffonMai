import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:my_first_flutter_app/utils/StringUtil.dart';
import 'package:my_first_flutter_app/utils/ColorUtil.dart';
import '../../service/Best50/PersonalizedDiffBest50Service.dart';
import '../../manager/DivingFish/MaimaiMusicDataManager.dart';
import '../SongInfoPage.dart';
import '../../utils/CoverUtil.dart';
import '../../service/Best50/PersonalizedDiffBest50ConvertToImgService.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:my_first_flutter_app/manager/MaiTagsManager.dart';
import 'package:my_first_flutter_app/entity/DXRating/MaiTagsModel.dart';
import 'package:my_first_flutter_app/utils/ExportQualitySelector.dart';
import 'package:my_first_flutter_app/utils/ImageEncodeUtil.dart';
import 'package:my_first_flutter_app/utils/TextStyleUtil.dart';

class PersonalizedDiffBest50Page extends StatefulWidget {
  const PersonalizedDiffBest50Page({super.key});

  @override
  _PersonalizedDiffBest50PageState createState() => _PersonalizedDiffBest50PageState();
}

class _PersonalizedDiffBest50PageState extends State<PersonalizedDiffBest50Page> {
  Map<String, dynamic>? _diffBest50Data;
  List<Map<String, dynamic>> _diffSongs = [];
  List<dynamic>? _maimaiMusicData;
  bool _isLoading = true;
  int? _selectedTagId;
  String? _selectedTagName;

  // 尺寸相关变量
  late double screenWidth;
  late double cardPadding;
  late double fontSizeBase;

  @override
  void initState() {
    super.initState();
    _loadMusicData();
  }

  Future<void> _loadMusicData() async {
    try {
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
              'is_extra': song.isExtra,
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
            }).toList() as List<dynamic>;
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading music data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDiffBest50Data() async {
    if (_selectedTagId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final service = PersonalizedDiffBest50Service();
      final data = await service.getTagDiffBest50Data(_selectedTagId!);

      setState(() {
        _diffBest50Data = data;
        _diffSongs = List<Map<String, dynamic>>.from(data?['diffBest50'] ?? []);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading diff best50 data: $e');
      setState(() {
        _diffBest50Data = null;
        _diffSongs = [];
        _isLoading = false;
      });
    }
  }

  // 显示标签选择对话框
  void _showTagSelectionDialog() async {
    final tagsEntity = await MaiTagsManager().getTags();
    if (tagsEntity == null || tagsEntity.tags.isEmpty) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('提示'),
            content: Text('没有找到标签数据'),
            actions: [
              TextButton(
                child: Text('确定'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          );
        },
      );
      return;
    }

    // 构建分组ID → 分组名称映射
    final Map<int, String> groupIdToName = {};
    for (var group in tagsEntity.tagGroups) {
      groupIdToName[group.id] = group.localizedName.zhHans;
    }

    // 按分组整理标签
    final Map<String, List<TagItem>> groupedTags = {};
    for (var tag in tagsEntity.tags) {
      final groupName = groupIdToName[tag.groupId] ?? '其他';
      groupedTags.putIfAbsent(groupName, () => []);
      groupedTags[groupName]!.add(tag);
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('选择标签'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: groupedTags.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          entry.key,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      ...entry.value.map((tag) {
                        return ListTile(
                          title: Text(tag.localizedName.zhHans),
                          subtitle: Text(tag.localizedDescription.zhHans, maxLines: 1, overflow: TextOverflow.ellipsis),
                          dense: true,
                          selected: _selectedTagId == tag.id,
                          onTap: () {
                            setState(() {
                              _selectedTagId = tag.id;
                              _selectedTagName = tag.localizedName.zhHans;
                            });
                            Navigator.of(context).pop();
                            _loadDiffBest50Data();
                          },
                        );
                      }),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              child: Text('取消'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  // 请求存储权限
  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      PermissionStatus storageStatus = await Permission.storage.status;
      PermissionStatus photosStatus = await Permission.photos.status;
      PermissionStatus videosStatus = await Permission.videos.status;

      if (storageStatus.isGranted || photosStatus.isGranted || videosStatus.isGranted) {
        return true;
      }

      Map<Permission, PermissionStatus> statuses = await [
        Permission.storage,
        Permission.photos,
        Permission.videos,
      ].request();

      bool storageGranted = statuses[Permission.storage]?.isGranted ?? false;
      bool photosGranted = statuses[Permission.photos]?.isGranted ?? false;
      bool videosGranted = statuses[Permission.videos]?.isGranted ?? false;

      return storageGranted || photosGranted || videosGranted;
    } else {
      PermissionStatus status = await Permission.storage.request();
      return status.isGranted;
    }
  }

  // 导出为图片
  Future<void> _exportToImage() async {
    try {
      if (_diffSongs.isEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('提示'),
            content: Text('没有数据可导出'),
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

      bool hasPermission = await _requestStoragePermission();
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

      // 先弹出质量选择器
      final quality = await ExportQualitySelector.show(
        context,
        estimatedPngSize: ImageEncodeUtil.estimatePngSize(songCount: _diffSongs.length),
      );
      if (quality == null) return;

      // 显示加载指示器
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

      String title = '个性化拟合Best50 - ${_selectedTagName ?? '标签'}';

      final file = await PersonalizedDiffBest50ConvertToImg.convertToImage(
        context,
        title,
        _diffBest50Data,
        _diffSongs,
        _maimaiMusicData,
        jpegQuality: quality.jpegQuality,
      );

      // 关闭加载指示器
      Navigator.pop(context);

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
                onPressed: () => Navigator.pop(context),
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
                onPressed: () => Navigator.pop(context),
                child: Text('确定'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('导出失败'),
          content: Text('导出过程中出现错误：\n$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('确定'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    screenWidth = MediaQuery.of(context).size.width;
    cardPadding = screenWidth * 0.02;
    fontSizeBase = screenWidth * 0.035;

    final double borderRadiusSmall = 8.0;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
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
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '个性化拟合Best50查询',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
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

              // 内容区域
              Expanded(
                child: Stack(
                  children: [
                    // 加载中状态
                    if (_isLoading && _selectedTagId != null)
                      Container(
                        color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: Theme.of(context).colorScheme.onSurface),
                              SizedBox(height: 16),
                              Text(
                                '正在计算个性化拟合Best50...',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // 内容
                    Container(
                      margin: EdgeInsets.fromLTRB(4, 0, 4, 10 + safeBottom),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(borderRadiusSmall),
                        boxShadow: [AppColors.defaultShadow(brightness)],
                      ),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(screenWidth * 0.03),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 标签选择按钮
                            ElevatedButton(
                              onPressed: _showTagSelectionDialog,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.linkBlue(brightness),
                                padding: EdgeInsets.symmetric(vertical: 12.0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                              ),
                              child: Text(
                                _selectedTagName != null
                                    ? '选择标签: $_selectedTagName'
                                    : '选择标签',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.04,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            SizedBox(height: 12.0),

                            // 未选择标签时的提示
                            if (_selectedTagId == null)
                              _buildEmptyHint(),

                            // 已选择标签且有数据时显示
                            if (_selectedTagId != null && _diffBest50Data != null && _diffSongs.isNotEmpty) ...[
                              _buildRatingSection(),
                              SizedBox(height: 12.0),
                              _buildExportButton(),
                              SizedBox(height: 12.0),
                              _buildSectionTitle('基于拟合难度的个性化Best50', context),
                              SizedBox(height: screenWidth * 0.02),
                              _buildDataCardGrid(),
                            ],

                            // 已选择标签但无数据时显示
                            if (_selectedTagId != null && _diffBest50Data != null && _diffSongs.isEmpty && !_isLoading)
                              _buildNoDataHint(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 未选择标签时的提示
  Widget _buildEmptyHint() {
    return Container(
      padding: EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.label_outline,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          SizedBox(height: 16),
          Text(
            '请先选择一个标签',
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            '选择标签后，将显示包含该标签且有游玩记录\n在拟合定数下RA前50的谱面',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // 无数据提示
  Widget _buildNoDataHint() {
    return Container(
      padding: EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.refresh,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          SizedBox(height: 16),
          Text(
            '暂无标签"$_selectedTagName"的拟合Best50数据',
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            '该标签可能没有对应的游玩记录',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // 构建评分区域
  Widget _buildRatingSection() {
    int diffRatingSum = _diffBest50Data?['diffRatingSum'] ?? 0;
    double diffRatingAverage = _diffSongs.isNotEmpty ? diffRatingSum / _diffSongs.length : 0.0;

    // 计算平均达成率
    double achievementsSum = _diffSongs.fold(0.0,
        (sum, song) => sum + (double.tryParse(song['achievements'].toString()) ?? 0.0));
    double averageAchievement = _diffSongs.isNotEmpty ? achievementsSum / _diffSongs.length : 0.0;

    // 计算平均scoreRate
    double scoreRateSum = _diffSongs.fold(0.0, (sum, song) {
      int songId = song['song_id'] ?? 0;
      int levelIndex = song['level_index'] ?? 0;
      int score = song['dxScore'] ?? 0;
      return sum + _calculateScoreRate(songId, levelIndex, score);
    });
    double averageScoreRate = _diffSongs.isNotEmpty ? scoreRateSum / _diffSongs.length : 0.0;

    // 计算暂无拟合定数的歌曲数量
    int noFitDiffCount = _diffSongs.where((song) {
      return song['use_official_diff'] ?? false;
    }).length;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2.0),
        borderRadius: BorderRadius.circular(8.0),
      ),
      padding: EdgeInsets.all(12.0),
      child: Row(
        children: [
          // 左侧评分
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '拟合总Rating',
                  style: TextStyle(
                    fontSize: screenWidth * 0.045,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: 4.0),
                RichText(
                  text: TextSpan(
                    children: [
                      TextStyleUtil.span(
                        diffRatingSum.toString(),
                        TextStyle(
                          fontSize: screenWidth * 0.045,
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextStyleUtil.span(
                        '(平均${diffRatingAverage.toStringAsFixed(1)})',
                        TextStyle(
                          fontSize: screenWidth * 0.03,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8.0),
                Text(
                  '标签: $_selectedTagName',
                  style: TextStyle(
                    fontSize: screenWidth * 0.035,
                    fontWeight: FontWeight.bold,
                    color: AppColors.linkBlue(Theme.of(context).brightness),
                  ),
                ),
                Text(
                  '共${_diffSongs.length}张谱面',
                  style: TextStyle(
                    fontSize: screenWidth * 0.035,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (noFitDiffCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      '${noFitDiffCount}首暂无拟合定数，按照官方定数计算',
                      style: TextStyle(
                        fontSize: screenWidth * 0.028,
                        color: AppColors.warningOrange(Theme.of(context).brightness),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 右侧达成率
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '平均达成率/DX分达成率',
                  style: TextStyle(
                    fontSize: screenWidth * 0.04,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                _buildDualDecimalText(averageAchievement, averageScoreRate * 100),
                SizedBox(height: 8.0),
                Text(
                  '在拟合定数下计算单曲Rating\n取前50的谱面',
                  style: TextStyle(
                    fontSize: screenWidth * 0.028,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 构建区域标题
  Widget _buildSectionTitle(String title, BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2.0),
        borderRadius: BorderRadius.circular(8.0),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      padding: EdgeInsets.all(screenWidth * 0.02),
      child: Center(
        child: Text(
          title,
          style: TextStyle(
            fontSize: screenWidth * 0.04,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  // 构建数据卡片网格
  Widget _buildDataCardGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: screenWidth * 0.01,
        mainAxisSpacing: screenWidth * 0.01,
        childAspectRatio: 1.75,
      ),
      itemCount: _diffSongs.length,
      itemBuilder: (context, index) {
        return _buildDataGameCard(_diffSongs[index]);
      },
    );
  }

  // 根据数据构建游戏卡片
  Widget _buildDataGameCard(Map<String, dynamic> songData) {
    double achievementRate = double.tryParse(songData['achievements'].toString()) ?? 0.0;
    int score = songData['dxScore'] ?? 0;
    String fc = songData['fc'] ?? '';
    String fs = songData['fs'] ?? '';
    double difficulty = double.tryParse(songData['fit_diff'].toString()) ?? 0.0;
    String rate = songData['rate'] ?? '';
    int levelIndex = songData['level_index'] ?? 0;
    int rating = songData['diffRating'] ?? 0;
    String type = songData['type'] ?? '';
    String title = songData['title'] ?? '未知歌曲';
    int songId = songData['song_id'] ?? 0;

    // 计算星星等级
    double scoreRate = _calculateScoreRate(songId, levelIndex, score);
    String stars = StringUtil.formatStars(scoreRate);
    Color starsColor = ColorUtil.getStarsColor(stars);

    // 映射FC属性
    String fcText = '-';
    if (fc.isNotEmpty) {
      switch (fc) {
        case 'fcp': fcText = 'FC+'; break;
        case 'fc': fcText = 'FC'; break;
        case 'ap': fcText = 'AP'; break;
        case 'app': fcText = 'AP+'; break;
      }
    }

    // 映射FS属性
    String fsText = '-';
    if (fs.isNotEmpty) {
      switch (fs) {
        case 'fsd': fsText = 'FDX'; break;
        case 'fsp': fsText = 'FS+'; break;
        case 'fs': fsText = 'FS'; break;
        case 'sync': fsText = 'SC'; break;
        case 'fsdp': fsText = 'FDX+'; break;
      }
    }

    // 映射Rate属性
    String rateText = StringUtil.formatRate(rate);

    // 构建完整grade
    String grade = '$rateText | $fcText | $fsText';

    // 获取卡片颜色
    Color cardColor;
    if (songId.toString().length == 6) {
      cardColor = AppColors.utageCard();
    } else {
      cardColor = _getCardColor(levelIndex);
    }

    bool dxMode = type == 'DX';
    bool isUtage = songId.toString().length == 6;
    bool useOfficialDiff = songData['use_official_diff'] ?? false;

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
        useOfficialDiff: useOfficialDiff,
      ),
    );
  }

  // 构建游戏卡片
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
    bool useOfficialDiff = false,
  }) {
    final brightness = Theme.of(context).brightness;
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        border: Border.all(color: Colors.black, width: 2.0),
        borderRadius: BorderRadius.circular(8.0),
      ),
      padding: EdgeInsets.all(cardPadding),
      child: LayoutBuilder(
        builder: (context, constraints) {
          double songNameFontSize = fontSizeBase;
          double decimalMainFontSize = screenWidth * 0.04;
          double decimalSmallFontSize = screenWidth * 0.03;
          double otherFontSize = screenWidth * 0.025;
          double gradeFontSize = screenWidth * 0.022;
          double dxFontSize = screenWidth * 0.025;
          double coverSize = screenWidth * 0.12;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 曲绘和难度
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
                        Text('UT', style: TextStyle(fontSize: dxFontSize, fontWeight: FontWeight.bold, color: Colors.red)),
                      if (dxMode && !isUtage)
                        Text('DX', style: TextStyle(fontSize: dxFontSize, fontWeight: FontWeight.bold, color: AppColors.warningOrange(brightness))),
                      if (!dxMode && !isUtage)
                        Text('ST', style: TextStyle(fontSize: dxFontSize, fontWeight: FontWeight.bold, color: AppColors.linkBlue(brightness))),
                      SizedBox(width: screenWidth * 0.01),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            difficulty.toStringAsFixed(2).split('.')[0],
                            style: TextStyle(fontSize: decimalMainFontSize * 0.9, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            '.${difficulty.toStringAsFixed(2).split('.')[1]}',
                            style: TextStyle(fontSize: decimalSmallFontSize * 0.9, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          if (useOfficialDiff)
                            Text('*', style: TextStyle(fontSize: decimalSmallFontSize * 0.7, fontWeight: FontWeight.bold, color: Colors.yellow)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(width: screenWidth * 0.02),

              // 右侧信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      songName,
                      style: TextStyle(fontSize: songNameFontSize, fontWeight: FontWeight.bold, color: Colors.white),
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
                          style: TextStyle(fontSize: decimalMainFontSize, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          '.${achievementRate.toStringAsFixed(4).split('.')[1]}%',
                          style: TextStyle(fontSize: decimalSmallFontSize, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          '$rating | $score | ',
                          style: TextStyle(fontSize: otherFontSize, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          stars,
                          style: TextStyle(fontSize: otherFontSize, color: starsColor, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Text(
                      grade,
                      style: TextStyle(fontSize: gradeFontSize, fontWeight: FontWeight.bold, color: Colors.white),
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

  // 构建小数文本
  Widget _buildDecimalText(double value, BuildContext context,
      {bool isPercentage = false, int decimalPlaces = 4, Color color = Colors.white}) {
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
          style: TextStyle(fontSize: screenWidth * 0.045, fontWeight: FontWeight.w800, color: color),
        ),
        Text(
          '$decimalPart$percentageSymbol',
          style: TextStyle(fontSize: screenWidth * 0.03, fontWeight: FontWeight.w800, color: color),
        ),
      ],
    );
  }

  // 构建双小数文本
  Widget _buildDualDecimalText(double value1, double value2,
      {int decimalPlaces1 = 4, int decimalPlaces2 = 2, Color? color}) {
    final resolvedColor = color ?? Theme.of(context).colorScheme.onSurface;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDecimalText(value1, context, decimalPlaces: decimalPlaces1, color: resolvedColor),
        Text('/', style: TextStyle(fontSize: screenWidth * 0.04, fontWeight: FontWeight.bold, color: resolvedColor)),
        _buildDecimalText(value2, context, decimalPlaces: decimalPlaces2, color: resolvedColor),
      ],
    );
  }

  // 根据level_index获取卡片颜色
  Color _getCardColor(int levelIndex) {
    List<Color> colors = [
      Colors.green,
      Colors.yellow,
      Colors.red,
      Colors.purple.shade400,
      Colors.purple.shade200,
    ];
    return colors[levelIndex.clamp(0, 4)];
  }

  // 计算scoreRate
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

  // 构建导出按钮
  Widget _buildExportButton() {
    return ElevatedButton(
      onPressed: () async {
        try {
          await _exportToImage();
        } catch (e) {
          debugPrint('Error in personalized diff export: $e');
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.linkBlue(Theme.of(context).brightness),
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
              fontSize: screenWidth * 0.04,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
