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
        return _SongDisplay(song: song);
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


  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textPrimaryColor = Theme.of(context).colorScheme.onSurface;
    final cardBgColor = Theme.of(context).colorScheme.surface;
    final cardShadow = AppColors.defaultShadow(brightness);
    final safeBottom = MediaQuery.of(context).padding.bottom;

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
                            margin: EdgeInsets.fromLTRB(4, 0, 4, 10 + safeBottom),
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

                                    // 用最高难度作为卡片主题色
                                    int highestIdx = 0;
                                    for (int i = song.ds.length - 1; i >= 0; i--) {
                                      if (song.ds[i] > 0) { highestIdx = i; break; }
                                    }
                                    final accentColor = ColorUtil.getCardColor(highestIdx);
                                    final diffNames = ['BASIC', 'ADVANCED', 'EXPERT', 'MASTER', 'Re:MASTER'];
                                    final diffColors = [
                                      Colors.green,
                                      Colors.yellow.shade700,
                                      Colors.red,
                                      Colors.purple,
                                      const Color(0xFFCBA6F7),
                                    ];

                                    // 构建所有难度的定数标签
                                    final diffChips = <Widget>[];
                                    for (int i = 0; i < song.ds.length; i++) {
                                      if (song.ds[i] <= 0) continue;
                                      final diffColor = i < diffColors.length ? diffColors[i] : Colors.grey;
                                      diffChips.add(Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: diffColor.withAlpha(200),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${diffNames[i.clamp(0, 4)]} ${song.ds[i].toStringAsFixed(1)}',
                                          style: const TextStyle(fontSize: 10,
                                            fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ));
                                    }

                                    return GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => SongInfoPage(
                                              songId: song.id,
                                              initialLevelIndex: highestIdx,
                                              isDefaultLevelIndex: false,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        margin: EdgeInsets.only(bottom: 12),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
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
                                                child: CoverUtil.buildCoverWidgetWithContextRRect(
                                                  context, song.id, 90,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Padding(
                                                padding: const EdgeInsets.all(12),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      song.basicInfo.title,
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                        color: textPrimaryColor,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      song.basicInfo.artist,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: AppColors.secondaryText(brightness),
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Wrap(
                                                      spacing: 4,
                                                      runSpacing: 4,
                                                      children: [
                                                        ...diffChips,
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                                              padding: const EdgeInsets.all(12),
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

  _SongDisplay({required this.song});
}