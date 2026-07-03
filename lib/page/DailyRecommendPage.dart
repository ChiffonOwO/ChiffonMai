import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/service/DailyRecommendService.dart';
import 'package:my_first_flutter_app/entity/DivingFish/Song.dart';
import 'package:my_first_flutter_app/utils/CoverUtil.dart';
import 'package:my_first_flutter_app/utils/ColorUtil.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:my_first_flutter_app/utils/StringUtil.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'SongInfoPage.dart';

class DailyRecommendPage extends StatefulWidget {
  const DailyRecommendPage({super.key});

  @override
  State<DailyRecommendPage> createState() => _DailyRecommendPageState();
}

class _DailyRecommendPageState extends State<DailyRecommendPage> {
  final DailyRecommendService _service = DailyRecommendService();

  bool _isLoading = true;
  List<_SongDisplay> _songs = [];
  String _todayDate = '';

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  String _getTodayDisplay() {
    final now = DateTime.now();
    final weekDays = ['一', '二', '三', '四', '五', '六', '日'];
    return '${now.year}年${now.month}月${now.day}日 星期${weekDays[now.weekday - 1]}';
  }

  Future<void> _loadRecommendations({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final songs = await _service.getDailyRecommendations(
        forceRefresh: forceRefresh,
      );
      final displaySongs = songs.map((song) {
        final levelIndex = _pickDisplayLevel(song);
        final ds = levelIndex < song.ds.length ? song.ds[levelIndex] : 0.0;
        final level = song.level.isNotEmpty && levelIndex < song.level.length
            ? song.level[levelIndex]
            : '';
        return _SongDisplay(
          song: song,
          levelIndex: levelIndex,
          ds: ds,
          level: level,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _songs = displaySongs;
          _todayDate = _getTodayDisplay();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('加载当日推荐失败: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 为歌曲挑选推荐的难度（优先最高难度）
  int _pickDisplayLevel(Song song) {
    final dsList = song.ds;
    if (dsList.isEmpty) return 0;
    for (int i = dsList.length - 1; i >= 0; i--) {
      if (dsList[i] > 0) return i;
    }
    return dsList.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textPrimaryColor = Theme.of(context).colorScheme.onSurface;
    final cardBgColor = Theme.of(context).colorScheme.surface;
    final cardShadow = AppColors.defaultShadow(brightness);

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
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '当日谱面推荐',
                          style: TextStyle(
                            color: textPrimaryColor,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.refresh, color: textPrimaryColor),
                      tooltip: '换一批',
                      onPressed:
                          _isLoading ? null : () => _loadRecommendations(forceRefresh: true),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: _isLoading
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text(
                              '正在为你挑选今日推荐...',
                              style: TextStyle(
                                color: textPrimaryColor,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _songs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.music_off,
                                    size: 64, color: AppColors.greyHint(brightness)),
                                SizedBox(height: 16),
                                Text(
                                  '暂无可推荐的曲目\n请先在首页刷新数据',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: textPrimaryColor,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      _loadRecommendations(forceRefresh: true),
                                  icon: Icon(Icons.refresh),
                                  label: Text('重试'),
                                ),
                              ],
                            ),
                          )
                        : Container(
                            margin: EdgeInsets.fromLTRB(8, 0, 8, 16),
                            decoration: BoxDecoration(
                              color: cardBgColor,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [cardShadow],
                            ),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Center(
                                    child: Column(
                                      children: [
                                        Text(
                                          _todayDate,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: textPrimaryColor,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          '今日为你推荐以下 4 首曲目，快来挑战吧！',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 24),

                                  ...List.generate(_songs.length, (index) {
                                    final item = _songs[index];
                                    final song = item.song;
                                    final accentColor =
                                        ColorUtil.getCardColor(item.levelIndex);
                                    final diffNames = [
                                      'Basic',
                                      'Advanced',
                                      'Expert',
                                      'Master',
                                      'Re:Master'
                                    ];
                                    final diffName =
                                        diffNames[item.levelIndex.clamp(0, 4)];

                                    return GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => SongInfoPage(
                                              songId: song.id,
                                              initialLevelIndex:
                                                  item.levelIndex,
                                              isDefaultLevelIndex: false,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        margin:
                                            EdgeInsets.only(bottom: 12),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: accentColor.withAlpha(80),
                                            width: 2,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(left: 4),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: CoverUtil
                                                    .buildCoverWidgetWithContextRRect(
                                                  context,
                                                  song.id,
                                                  90,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(12),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      song.basicInfo.title,
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            textPrimaryColor,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    SizedBox(height: 4),
                                                    Text(
                                                      song.basicInfo.artist,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: AppColors
                                                            .secondaryText(brightness),
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    SizedBox(height: 8),
                                                    Wrap(
                                                      spacing: 4,
                                                      runSpacing: 4,
                                                      children: [
                                                        Container(
                                                          padding: EdgeInsets.symmetric(
                                                              horizontal: 8, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: accentColor,
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            '$diffName ${item.level}',
                                                            style: const TextStyle(fontSize: 11,
                                                                fontWeight: FontWeight.bold,
                                                                color: Colors.white),
                                                          ),
                                                        ),
                                                        Container(
                                                          padding: EdgeInsets.symmetric(
                                                              horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            border: Border.all(
                                                                color: accentColor, width: 1.5),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            '定数 ${item.ds.toStringAsFixed(1)}',
                                                            style: TextStyle(fontSize: 11,
                                                                fontWeight: FontWeight.bold,
                                                                color: accentColor),
                                                          ),
                                                        ),
                                                        Container(
                                                          padding: EdgeInsets.symmetric(
                                                              horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            border: Border.all(
                                                              color: song.type == 'DX' ? AppColors.warningOrange(brightness) : AppColors.linkBlue(brightness),
                                                              width: 1.5),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            StringUtil.formatSongType(song.type),
                                                            style: TextStyle(fontSize: 11,
                                                                fontWeight: FontWeight.bold,
                                                                color: song.type == 'DX' ? AppColors.warningOrange(brightness) : AppColors.linkBlue(brightness)),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.all(12),
                                              child: Icon(
                                                Icons.chevron_right,
                                                color: AppColors.greyHint(brightness),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),

                                  SizedBox(height: 16),
                                  Center(
                                    child: Text(
                                      '推荐每日更新，明天再来看看！',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.greyHint(brightness),
                                      ),
                                    ),
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
}

/// 显示用的歌曲数据
class _SongDisplay {
  final Song song;
  final int levelIndex;
  final double ds;
  final String level;

  _SongDisplay({
    required this.song,
    required this.levelIndex,
    required this.ds,
    required this.level,
  });
}