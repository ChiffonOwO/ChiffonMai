// ignore: file_names
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:my_first_flutter_app/utils/StringUtil.dart';
import 'package:my_first_flutter_app/utils/ColorUtil.dart';
import '../../service/Best50/DiffBest50Service.dart';
import '../../service/Best50/DiffBest50ConvertToImgService.dart';
import '../../manager/DivingFish/MaimaiMusicDataManager.dart';
import '../SongInfoPage.dart';
import '../../utils/TextStyleUtil.dart';
import '../../utils/AppTheme.dart';
import '../../widgets/B50GameCardWidget.dart';
import 'package:my_first_flutter_app/utils/ExportQualitySelector.dart';
import 'package:my_first_flutter_app/utils/ImageEncodeUtil.dart';
import '../../widgets/PageTopBar.dart';

class DiffBest50Page extends StatefulWidget {
  const DiffBest50Page({super.key});

  @override
  _DiffBest50PageState createState() => _DiffBest50PageState();
}

class _DiffBest50PageState extends State<DiffBest50Page> {
  Map<String, dynamic>? _diffBest50Data;
  List<dynamic>? _maimaiMusicData;
  List<Map<String, dynamic>> _diffSongs = [];
  List<Map<String, dynamic>> _diffSdSongs = []; // Best35 - 非当前版本
  List<Map<String, dynamic>> _diffDxSongs = []; // Best15 - 当前版本
  bool _isLoading = true;

  // 拟合Best50模式：0为模式A，1为模式B，2为模式C
  int _currentMode = 0;

  // 尺寸相关变量
  late double screenWidth;
  late double screenHeight;
  late double cardPadding;
  late double fontSizeBase;

  @override
  void initState() {
    super.initState();
    _loadDiffBest50Data();
  }

  Future<void> _loadDiffBest50Data() async {
    try {
      // 加载maimai音乐数据
      // 直接使用缓存的API数据
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
            }).toList();
          });
        }
      }

      // 根据模式计算DiffBest50数据
      final diffBest50Service = DiffBest50Service();
      late final diffBest50Data;
      switch (_currentMode) {
        case 0:
          diffBest50Data = await diffBest50Service.calculateDiffBest50();  // 模式A：按拟合Rating重新排序
          break;
        case 1:
          diffBest50Data = await diffBest50Service.calculateDiffBest50ModeB();  // 模式B：保持原有排名
          break;
        case 2:
          diffBest50Data = await diffBest50Service.calculateDiffBest50ModeC();  // 模式C：分别在SD/DX中取前50
          break;
        default:
          diffBest50Data = await diffBest50Service.calculateDiffBest50();
      }
      
      setState(() {
        _diffBest50Data = diffBest50Data;
        _diffSongs = List<Map<String, dynamic>>.from(diffBest50Data['diffBest50'] ?? []);
        _diffSdSongs = List<Map<String, dynamic>>.from(diffBest50Data['diffSdSongs'] ?? []);
        _diffDxSongs = List<Map<String, dynamic>>.from(diffBest50Data['diffDxSongs'] ?? []);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 切换拟合模式
  void _toggleMode() {
    setState(() {
      _currentMode = (_currentMode + 1) % 3;
      _isLoading = true;
    });
    _loadDiffBest50Data();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    // 初始化尺寸相关变量
    screenWidth = MediaQuery.of(context).size.width;
    screenHeight = MediaQuery.of(context).size.height;
    cardPadding = screenWidth * 0.02;
    fontSizeBase = screenWidth * 0.035;

    final double borderRadiusSmall = 8.0;

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
              // 标题栏（始终显示）
              PageTopBar(
                title: '拟合Best50查询',
                actions: [
                // 模式切换按钮（始终显示）
                ElevatedButton(
                style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.surface,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                minimumSize: Size(100 * 0.9, 36 * 0.9),
                shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
                ),
                ),
                onPressed: _toggleMode,
                child: Text(
                '模式${['A', 'B', 'C'][_currentMode]}',
                style: TextStyle(fontSize: 12),
                ),
                ),
                ],
              ),

              // 内容区域
              Expanded(
                child: Stack(
                  children: [
                    // 加载中状态（覆盖层）
                    if (_isLoading)
                      Container(
                        color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: Theme.of(context).colorScheme.onSurface),
                              SizedBox(height: 16),
                              Text(
                                '正在计算拟合Best50...',
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
                    if (!_isLoading)
                      _buildContent(brightness, borderRadiusSmall),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 构建内容区域
  Widget _buildContent(Brightness brightness, double borderRadiusSmall) {
    // 如果没有数据，显示空状态
    if (_diffBest50Data == null || _diffSongs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.refresh,
              size: 64,
              color: AppColors.greyHint(brightness),
            ),
            SizedBox(height: 16),
            Text(
              '暂无拟合Best50数据',
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
      );
    }

    // 主内容区域
    final safeBottom = MediaQuery.of(context).padding.bottom; // 系统底部导航栏高度
    return Container(
      margin: EdgeInsets.fromLTRB(4, 0, 4, 10 + safeBottom),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(borderRadiusSmall),
        boxShadow: [AppColors.defaultShadow(brightness)],
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.03),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 评分区域
            _buildRatingSection(),
            SizedBox(height: 12.0),

            // 导出按钮
            _buildExportButton(),
            SizedBox(height: 12.0),

            // 根据模式显示不同内容
            _currentMode == 0 ?
            // 模式A：不分SD/DX，统一显示
            Column(
              children: [
                _buildSectionTitle('基于拟合难度的Best50', context),
                SizedBox(height: MediaQuery.of(context).size.height * 0.015),
                _buildDataCardGrid(_diffSongs, B50GameCardWidget.designAspectRatio),
              ],
            ) :
            // 模式B/C：分离显示Best35和Best15
            Column(
              children: [
                // Best35 标题区域
                _buildSectionTitle(_currentMode == 1 ? 'Best35 | 非当前版本最好成绩' : '非当前版本前35 | 拟合Rating排名', context),
                SizedBox(height: MediaQuery.of(context).size.height * 0.015),
                _buildDataCardGrid(_diffSdSongs, B50GameCardWidget.designAspectRatio),
                SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                // Best15 标题区域
                _buildSectionTitle(_currentMode == 1 ? 'Best15 | 当前版本最好成绩' : '当前版本前15 | 拟合Rating排名', context),
                SizedBox(height: 12.0),
                _buildDataCardGrid(_diffDxSongs, B50GameCardWidget.designAspectRatio),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 构建评分区域
  Widget _buildRatingSection() {
    // 计算各项指标
    int diffRatingSum = _diffBest50Data?['diffRatingSum'] ?? 0;
    int best50Diff = _diffBest50Data?['best50Diff'] ?? 0;
    double diffRatingAverage = _diffSongs.isNotEmpty ? diffRatingSum / _diffSongs.length : 0.0;

    // 计算平均达成率
    double achievementsSum = _diffSongs.fold(0.0,
        (sum, song) => sum + (double.parse(song['achievements'].toString())));
    double diffBest50AchievementAverage = 
        _diffSongs.isNotEmpty ? achievementsSum / _diffSongs.length : 0.0;

    // 计算平均scoreRate
    double scoreRateSum = _diffSongs.fold(0.0, (sum, song) {
      int songId = song['song_id'];
      int levelIndex = song['level_index'];
      int score = song['dxScore'];
      return sum + _calculateScoreRate(songId, levelIndex, score);
    });

    double diffBest50ScoreRateAverage = _diffSongs.isNotEmpty 
        ? scoreRateSum / _diffSongs.length 
        : 0.0;

    // 计算暂无拟合定数的歌曲数量（使用官方定数的歌曲）
    int noFitDiffCount = _diffSongs.where((song) {
      return song['use_official_diff'] ?? false;
    }).length;

    final ratingBrightness = Theme.of(context).brightness;
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
                        diffRatingSum.toString(),
                        TextStyle(
                          fontSize: MediaQuery.of(context).size.width * 0.045,
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextStyleUtil.span(
                        '(平均${diffRatingAverage.toStringAsFixed(1)})',
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
                  '与Best50差值',
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width * 0.045,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,

                  ),
                ),
                Text(
                  '${best50Diff > 0 ? '+' : ''}$best50Diff',
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width * 0.045,
                    color: best50Diff >= 0 ? AppColors.successGreen(ratingBrightness) : AppColors.errorRed(ratingBrightness),
                    fontWeight: FontWeight.bold,

                  ),
                ),
                // 显示暂无拟合定数的歌曲数量
                if (noFitDiffCount > 0)
                  SizedBox(height: 8.0),
                if (noFitDiffCount > 0)
                  Text(
                    '${noFitDiffCount}首暂无拟合定数，按照官方定数计算',
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).size.width * 0.035,
                      color: AppColors.warningOrange(ratingBrightness),

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
                  '拟合Best50 平均达成率/DX分数达成率',
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width * 0.04,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,

                  ),
                ),
                _buildDualDecimalText(
                    diffBest50AchievementAverage,
                    diffBest50ScoreRateAverage * 100,
                    scoreRate: diffBest50ScoreRateAverage),
                SizedBox(height: 8.0),
                // 模式说明
                Text(
                  _currentMode == 0
                      ? '模式A：不分类Best35和Best15，直接获取拟合定数下的Rating前50的谱面'
                      : (_currentMode == 1
                          ? "模式B：将您的Best35和Best15中的所有谱面的定数都替换为其拟合定数，然后计算Rating并降序排序"
                          : '模式C：在非当前版本中取拟合定数下的Rating前35的谱面，在当前版本中取拟合定数下Rating前15的谱面'),
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width * 0.028,
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
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.02),
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

  // 构建游戏卡片（委托至通用 widget B50GameCardWidget，
  // 字号按卡片**实际**宽度自适应（`scale: autoScale`）。
  // 注：原 useOfficialDiff（黄星标记）已废弃，统一不在卡片中显示。
  Widget _buildGameCard({
    required Color cardColor,
    String songName = '未知歌曲',
    double achievementRate = 0.0,
    double difficulty = 0.0,
    bool dxMode = false,
    bool isUtage = false,
    int score = 0,
    int maxScore = 0,
    int rating = 0,
    String stars = '',
    String fc = '',
    String fs = '',
    String rate = '',
    int? songId,
    Color starsColor = Colors.white,
    int maxIdLength = 5,
  }) {
    final int id = songId ?? 0;

    return B50GameCardWidget(
      cardColor: cardColor,
      songName: songName,
      achievementRate: achievementRate,
      difficulty: difficulty,
      dxMode: dxMode,
      isUtage: isUtage,
      score: score,
      maxScore: maxScore,
      rating: rating,
      stars: stars,
      fc: fc,
      fs: fs,
      rate: rate,
      songId: id,
      starsColor: starsColor,
      maxIdLength: maxIdLength,
      // 字号按卡片**实际**宽度自适应：别拿屏幕宽度估（容器 padding /
      // 网格间距都会从可用宽里扣掉）。
      scale: B50GameCardWidget.autoScale,
    );
  }

  // 构建小数文本，整数部分字号大，小数部分和百分号字号小且底部对齐
  Widget _buildDecimalText(double value, BuildContext context,
      {bool isPercentage = false,
      int decimalPlaces = 4,
      Color color = Colors.white}) {
    String text = value.toStringAsFixed(decimalPlaces);

    // 分割整数部分和小数部分
    List<String> parts = text.split('.');
    String integerPart = parts[0];
    String decimalPart = parts.length > 1 ? '.${parts[1]}' : '';
    String percentageSymbol = isPercentage ? '%' : '';

    // 整数与小数共用基线，数字底边自然齐平（与 B50 卡片一致）
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        // 整数部分
        Text(
          integerPart,
          style: TextStyle(
            fontSize: MediaQuery.of(context).size.width * 0.045,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        // 小数部分和百分号
        Text(
          '$decimalPart$percentageSymbol',
          style: TextStyle(
            fontSize: MediaQuery.of(context).size.width * 0.03,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  // 构建双小数文本，如 "100.1234/97.54"
  Widget _buildDualDecimalText(double value1, double value2,
      {int decimalPlaces1 = 4,
      int decimalPlaces2 = 2,
      Color? color,
      double? scoreRate}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedColor = color ?? Theme.of(context).colorScheme.onSurface;
        double fontSize = MediaQuery.of(context).size.width * 0.04;

        final starsText =
            scoreRate != null ? StringUtil.formatStars(scoreRate) : null;
        final starsColor =
            scoreRate != null ? ColorUtil.getStarsColor(starsText!) : null;

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
            // DX 分达成率右侧添加星级（achievement / dxScore% / ✦x）
            if (starsText != null) ...[
              Text(
                '/',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: resolvedColor,
                ),
              ),
              Text(
                starsText,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: starsColor,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  // 构建数据驱动的卡片网格
  Widget _buildDataCardGrid(
      List<Map<String, dynamic>> songs, double childAspectRatio) {
    // 按当前列表里实际最大 ID 位数作为占位宽度：无 6 位则严格用 5 位，5 位 ID 与 chip 之间不留空
    final int maxIdLength = songs.isEmpty
        ? 5
        : songs
            .map((s) => s['song_id'].toString().length)
            .reduce((a, b) => a > b ? a : b);
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero, // 移除默认padding
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: MediaQuery.of(context).size.width * 0.01,
        mainAxisSpacing: MediaQuery.of(context).size.width * 0.01,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: songs.length,
      itemBuilder: (context, index) {
        return _buildDataGameCard(songs[index], maxIdLength: maxIdLength);
      },
    );
  }

  // 根据数据构建游戏卡片
  Widget _buildDataGameCard(Map<String, dynamic> songData, {required int maxIdLength}) {
    // 解析数据
    double achievementRate = double.parse(songData['achievements'].toString());
    int score = songData['dxScore'];
    String fc = songData['fc'] ?? '';
    String fs = songData['fs'] ?? '';
    double difficulty = double.parse(songData['fit_diff'].toString());
    String rate = songData['rate'];
    int levelIndex = songData['level_index'];
    int rating = songData['diffRating'];
    String type = songData['type'];
    String title = songData['title'];
    int songId = songData['song_id'];

    // 计算星星等级
    double scoreRate = _calculateScoreRate(songId, levelIndex, score);
    String stars = StringUtil.formatStars(scoreRate);
    Color starsColor = ColorUtil.getStarsColor(stars);

    // 计算该难度下的满分 (notes * 3)，通用卡片需要展示 分数/满分
    int maxScore = _calculateMaxScore(songId, levelIndex);

    // 获取卡片颜色
      Color cardColor;
      // 对于6位数ID的歌曲，使用粉色
      if (songId.toString().length == 6) {
        cardColor = AppColors.utageCard(); // 加深的粉色
      } else {
        cardColor = _getCardColor(levelIndex);
      }

    // 判断是否为DX模式或UT模式
      bool dxMode = type == 'DX';
      bool isUtage = songId.toString().length == 6; // 6位数ID为UTAGE

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SongInfoPage(
              songId: songId.toString(),
              initialLevelIndex: levelIndex,
              isDefaultLevelIndex: false, // 防止默认跳转到Master难度
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
        maxScore: maxScore,
        rating: rating,
        stars: stars,
        fc: fc,
        fs: fs,
        rate: rate,
        songId: songId,
        starsColor: starsColor,
        maxIdLength: maxIdLength,
      ),
    );
  }

  // 根据level_index获取卡片颜色
  Color _getCardColor(int levelIndex) {
    List<Color> colors = [
      Colors.green, // level_index 0
      Colors.yellow, // level_index 1
      Colors.red, // level_index 2
      Colors.purple.shade400, // level_index 3
      Colors.purple.shade200, // level_index 4
    ];
    return colors[levelIndex.clamp(0, 4)];
  }

  // 计算scoreRate
  double _calculateScoreRate(int songId, int levelIndex, int score) {
    if (_maimaiMusicData == null) return 0.0;

    // 查找对应的歌曲
    int songIndex = _maimaiMusicData!.indexWhere(
      (item) => item['id'] == songId.toString(),
    );

    if (songIndex == -1) return 0.0;
    dynamic songData = _maimaiMusicData![songIndex];

    if (songData['charts'] == null) return 0.0;

    // 查找对应的charts
    List<dynamic> charts = songData['charts'];
    if (levelIndex < 0 || levelIndex >= charts.length) return 0.0;

    dynamic chart = charts[levelIndex];
    if (chart['notes'] == null) return 0.0;

    // 计算maxScore
    List<dynamic> notes = chart['notes'];
    int notesSum = notes.fold(0, (sum, note) => sum + (note as int));
    int maxScore = notesSum * 3;

    // 计算scoreRate
    return maxScore > 0 ? score / maxScore : 0.0;
  }

  // 计算指定歌曲/难度的满分（notes * 3），供通用卡片展示 分数/满分
  int _calculateMaxScore(int songId, int levelIndex) {
    if (_maimaiMusicData == null) return 0;
    final songIndex = _maimaiMusicData!.indexWhere(
      (item) => item['id'] == songId.toString(),
    );
    if (songIndex == -1) return 0;
    final songData = _maimaiMusicData![songIndex];
    if (songData['charts'] == null) return 0;
    final List<dynamic> charts = songData['charts'];
    if (levelIndex < 0 || levelIndex >= charts.length) return 0;
    final chart = charts[levelIndex];
    if (chart['notes'] == null) return 0;
    final List<dynamic> notes = chart['notes'];
    final notesSum = notes.fold<int>(0, (sum, note) => sum + (note as int));
    return notesSum * 3;
  }



  // 构建导出按钮
  Widget _buildExportButton() {
    return ElevatedButton(
      onPressed: () async {
        debugPrint('=== DIFF EXPORT BUTTON CLICKED ===');
        try {
          await _exportToImage();
        } catch (e) {
          debugPrint('Error in diff export: $e');
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
              fontSize: MediaQuery.of(context).size.width * 0.04,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // 请求存储权限
  Future<bool> _requestStoragePermission() async {
    debugPrint('Page: _requestStoragePermission called');
    debugPrint('Page: Platform.isAndroid = ${Platform.isAndroid}');
    
    if (Platform.isAndroid) {
      debugPrint('Page: Running on Android');
      
      // 策略：同时请求 storage、photos 和 videos 权限，确保覆盖所有 Android 版本
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
      
      // 请求权限：同时请求 storage、photos 和 videos
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

  // 导出为图片
  Future<void> _exportToImage() async {
    try {
      // 先请求存储权限
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

      // 显示质量选择器
      final quality = await ExportQualitySelector.show(
        context,
        estimatedPngSize: ImageEncodeUtil.estimatePngSize(songCount: 50),
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

      // 调用导出方法
      final file = await DiffBest50ConvertToImg.convertToImage(
        context,
        _diffBest50Data,
        _diffSongs,
        _maimaiMusicData,
        currentMode: _currentMode,
        jpegQuality: quality.jpegQuality,
      );

      // 关闭加载指示器
      Navigator.pop(context);

      // 显示导出结果
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
      // 关闭加载指示器
      Navigator.pop(context);
      
      // 显示错误信息
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
}
