import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../api/ApiUrls.dart';
import '../entity/DivingFish/Song.dart';
import '../manager/DivingFish/MaimaiMusicDataManager.dart';
import '../page/SongInfoPage.dart';
import '../utils/AppTheme.dart';
import '../utils/AppConstants.dart';
import '../utils/CommonWidgetUtil.dart';
import '../utils/CoverUtil.dart';
import 'package:my_first_flutter_app/utils/ApiClient.dart';

/// 评分记录数据模型
class RatingRecordItem {
  final int id;
  final String songId;
  final int levelIndex;
  final String userId;
  final String? dataSource;
  final String? originalId;
  final double score;
  final double? achievementRate;
  final int? totalRating;
  final int? theoreticalRating;
  final double? weight;
  final String? createdAt;

  RatingRecordItem({
    required this.id,
    required this.songId,
    required this.levelIndex,
    required this.userId,
    this.dataSource,
    this.originalId,
    required this.score,
    this.achievementRate,
    this.totalRating,
    this.theoreticalRating,
    this.weight,
    this.createdAt,
  });

  /// 安全地将 JSON 值转为 double，兼容 String / int / double
  static double _parseDouble(dynamic value, [double fallback = 0.0]) {
    if (value == null) return fallback;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed ?? fallback;
    }
    return fallback;
  }

  /// 安全地将 JSON 值转为 int
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed;
    }
    return null;
  }

  factory RatingRecordItem.fromJson(Map<String, dynamic> json) {
    return RatingRecordItem(
      id: _parseInt(json['id']) ?? 0,
      songId: (json['songId'] ?? json['song_id'] ?? '').toString(),
      levelIndex: _parseInt(json['levelIndex'] ?? json['level_index']) ?? 0,
      userId: (json['userId'] ?? json['user_id'] ?? '').toString(),
      dataSource: json['dataSource'] ?? json['data_source'],
      originalId: json['originalId'] ?? json['original_id'],
      score: _parseDouble(json['score']),
      achievementRate: json['achievementRate'] != null
          ? _parseDouble(json['achievementRate'], 0)
          : json['achievement_rate'] != null
              ? _parseDouble(json['achievement_rate'], 0)
              : null,
      totalRating: _parseInt(json['totalRating'] ?? json['total_rating']),
      theoreticalRating: _parseInt(json['theoreticalRating'] ?? json['theoretical_rating']),
      weight: json['weight'] != null
          ? _parseDouble(json['weight'], 0)
          : null,
      createdAt: json['createdAt'] ?? json['created_at'],
    );
  }
}

/// 最近评分页面：展示最近50条谱面评分记录，每页10条，Redis+MySQL二级缓存
class RecentRatingsPage extends StatefulWidget {
  const RecentRatingsPage({super.key});

  @override
  State<RecentRatingsPage> createState() => _RecentRatingsPageState();
}

class _RecentRatingsPageState extends State<RecentRatingsPage> {
  bool _isLoading = true;
  List<RatingRecordItem> _ratings = [];
  Map<String, Song> _songMap = {};
  int _currentPage = 1;
  static const int _pageSize = 10;
  final ScrollController _scrollController = ScrollController();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadSongCache();
    await _loadRatings();
  }

  Future<void> _loadSongCache() async {
    try {
      final songs = await MaimaiMusicDataManager().getCachedSongs();
      if (songs != null) {
        _songMap = {for (final s in songs) s.id: s};
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadRatings({bool refresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final url = '${ApiUrls.RatingsRecentUrl}?page=$_currentPage&pageSize=$_pageSize${refresh ? '&refresh=true' : ''}';
      final response = await ApiClient.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          final List<dynamic> data = result['data'] ?? [];
          setState(() {
            _ratings = data.map((json) => RatingRecordItem.fromJson(json)).toList();
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = result['error'] ?? '加载失败';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = '请求失败 (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '网络错误: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    _currentPage = 1;
    await _loadRatings(refresh: true);
  }

  Song? _getSong(String songId) => _songMap[songId];

  String _getSongTitle(String songId) {
    final song = _getSong(songId);
    return song?.title ?? songId;
  }

  // ---- 类型 & 难度标签（与 SpecialRankingListPage 完全一致） ----

  Widget _buildTypeTag(String type, String songId, Brightness brightness) {
    bool isUtage = songId.length == 6;

    Color bgColor;
    Color textColor;

    if (isUtage) {
      bgColor = brightness == Brightness.dark
          ? Colors.red.withValues(alpha: 0.2)
          : Colors.red.shade100;
      textColor = brightness == Brightness.dark
          ? Colors.red[300]!
          : Colors.red;
    } else if (type == 'DX') {
      bgColor = brightness == Brightness.dark
          ? Colors.orange.withValues(alpha: 0.2)
          : Colors.orange.shade100;
      textColor = brightness == Brightness.dark
          ? Colors.orange[300]!
          : Colors.orange;
    } else {
      bgColor = brightness == Brightness.dark
          ? Colors.blue.withValues(alpha: 0.2)
          : Colors.blue.shade100;
      textColor = brightness == Brightness.dark
          ? Colors.blue[300]!
          : Colors.blue;
    }

    final label = isUtage ? 'UT' : (type == 'DX' ? 'DX' : 'ST');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildDifficultyTag(int difficultyIndex, String songId, Brightness brightness) {
    Color bgColor;
    Color textColor;
    const labels = ['BASIC', 'ADVANCED', 'EXPERT', 'MASTER', 'RE:MASTER'];
    final label = (difficultyIndex >= 0 && difficultyIndex < labels.length)
        ? labels[difficultyIndex]
        : '?';

    if (songId.length == 6) {
      bgColor = brightness == Brightness.dark
          ? Colors.red.withValues(alpha: 0.2)
          : Colors.red.shade100;
      textColor = brightness == Brightness.dark
          ? Colors.red[300]!
          : Colors.red;
    } else {
      switch (difficultyIndex) {
        case 0:
          bgColor = brightness == Brightness.dark
              ? Colors.green.withValues(alpha: 0.2)
              : Colors.green.shade100;
          textColor = brightness == Brightness.dark
              ? Colors.green[300]!
              : Colors.green.shade700;
          break;
        case 1:
          bgColor = brightness == Brightness.dark
              ? Colors.orange.withValues(alpha: 0.2)
              : Colors.orange.shade100;
          textColor = brightness == Brightness.dark
              ? Colors.orange[300]!
              : Colors.orange.shade700;
          break;
        case 2:
          bgColor = brightness == Brightness.dark
              ? Colors.red.withValues(alpha: 0.2)
              : Colors.red.shade100;
          textColor = brightness == Brightness.dark
              ? Colors.red[300]!
              : Colors.red;
          break;
        case 3:
          bgColor = brightness == Brightness.dark
              ? Colors.purple.withValues(alpha: 0.2)
              : Colors.purple.shade100;
          textColor = brightness == Brightness.dark
              ? Colors.purple[200]!
              : Colors.purple.shade700;
          break;
        case 4:
          bgColor = brightness == Brightness.dark
              ? Colors.purple.withValues(alpha: 0.2)
              : Colors.purple.shade100;
          textColor = brightness == Brightness.dark
              ? Colors.purple[200]!
              : Colors.purple.shade300;
          break;
        default:
          bgColor = brightness == Brightness.dark
              ? Colors.grey.withValues(alpha: 0.2)
              : Colors.grey.shade100;
          textColor = brightness == Brightness.dark
              ? Colors.grey[400]!
              : Colors.grey.shade700;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return '刚刚';
      if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
      if (diff.inHours < 24) return '${diff.inHours}小时前';
      if (diff.inDays < 7) return '${diff.inDays}天前';
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return timestamp;
    }
  }

  Widget _buildStars(double score, Brightness brightness, {double starSize = 16}) {
    final fullStars = score.floor();
    final hasHalf = (score - fullStars) >= 0.25;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        IconData icon;
        Color color;

        if (index < fullStars) {
          icon = Icons.star;
          color = AppColors.warningOrange(brightness);
        } else if (index == fullStars && hasHalf) {
          icon = Icons.star_half;
          color = AppColors.warningOrange(brightness);
        } else {
          icon = Icons.star_border;
          color = AppColors.greyHint(brightness, shade: 400);
        }

        return Icon(icon, size: starSize, color: color);
      }),
    );
  }

  String _getUserIdDisplay(RatingRecordItem rating) {
    final ds = rating.dataSource ?? '';
    if (ds == 'shuiyu') return '水鱼用户';
    if (ds == 'luoxue') return '落雪用户';
    final uid = rating.userId;
    return uid.length > 8 ? '${uid.substring(0, 8)}...' : uid;
  }

  void _navigateToSong(String songId, int levelIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SongInfoPage(
          songId: songId,
          initialLevelIndex: levelIndex,
          isDefaultLevelIndex: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final screenWidth = MediaQuery.of(context).size.width;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final Color textPrimaryColor = Theme.of(context).colorScheme.onSurface;
    final Color cardBgColor = Theme.of(context).colorScheme.surface.withValues(alpha: 0.9);
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
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '最近评分',
                          style: TextStyle(
                            color: textPrimaryColor,
                            fontSize: screenWidth * 0.055,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.refresh, color: textPrimaryColor),
                      onPressed: _isLoading ? null : _refresh,
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Container(
                  margin: EdgeInsets.fromLTRB(4, 0, 4, 10 + safeBottom),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                    boxShadow: [defaultShadow],
                  ),
                  child: _isLoading
                      ? _buildLoading(brightness)
                      : _errorMessage != null
                          ? _buildError(brightness)
                          : _ratings.isEmpty
                              ? _buildEmpty(brightness)
                              : _buildRatingList(brightness, screenWidth),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoading(Brightness brightness) {
    return Center(
      child: CircularProgressIndicator(color: AppColors.linkBlue(brightness)),
    );
  }

  Widget _buildError(Brightness brightness) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: AppColors.errorRed(brightness)),
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            style: TextStyle(color: AppColors.errorRed(brightness), fontSize: 14),
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _refresh, child: const Text('重试')),
        ],
      ),
    );
  }

  Widget _buildEmpty(Brightness brightness) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_border_outlined, size: 56, color: AppColors.greyHint(brightness)),
          const SizedBox(height: 12),
          Text(
            '暂无评分记录',
            style: TextStyle(color: AppColors.greyHint(brightness), fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingList(Brightness brightness, double screenWidth) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.03, vertical: 8),
            itemCount: _ratings.length,
            itemBuilder: (context, index) {
              final rating = _ratings[index];
              return _buildRatingCard(rating, brightness, screenWidth);
            },
          ),
        ),
        _buildPagination(brightness),
      ],
    );
  }

  Widget _buildRatingCard(RatingRecordItem rating, Brightness brightness, double screenWidth) {
    final songId = rating.songId;
    final song = _getSong(songId);
    final levelIndex = rating.levelIndex;

    return GestureDetector(
      onTap: () => _navigateToSong(songId, levelIndex),
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.buttonBorder(brightness), width: 0.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 曲绘
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 56,
                height: 56,
                child: CoverUtil.buildCoverWidget(songId, 56),
              ),
            ),
            SizedBox(width: 10),
            // 右侧内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 第一行：类型标签 + 难度标签 + 时间
                  Row(
                    children: [
                      if (song != null)
                        _buildTypeTag(song.type, songId, brightness),
                      if (song != null) const SizedBox(width: 6),
                      _buildDifficultyTag(levelIndex, songId, brightness),
                      const Spacer(),
                      Icon(Icons.access_time, size: 10, color: AppColors.greyHint(brightness, shade: 600)),
                      const SizedBox(width: 2),
                      Text(
                        _formatTime(rating.createdAt),
                        style: TextStyle(fontSize: 10, color: AppColors.greyHint(brightness, shade: 600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // 第二行：歌曲标题
                  Text(
                    _getSongTitle(songId),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // 星级评分 + 分数
                  Row(
                    children: [
                      _buildStars(rating.score, brightness, starSize: 16),
                      const SizedBox(width: 6),
                      Text(
                        rating.score.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.warningOrange(brightness),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '/ 5.0',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.greyHint(brightness, shade: 600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // 用户
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 10, color: AppColors.greyHint(brightness, shade: 600)),
                      const SizedBox(width: 2),
                      Text(
                        _getUserIdDisplay(rating),
                        style: TextStyle(fontSize: 10, color: AppColors.greyHint(brightness, shade: 600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 箭头提示可点击
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(Icons.chevron_right, size: 18, color: AppColors.greyHint(brightness, shade: 400)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagination(Brightness brightness) {
    const int totalRecords = 50;
    final totalPages = (totalRecords / _pageSize).ceil();

    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.tableBorder(brightness), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: _currentPage > 1
                ? () {
                    setState(() => _currentPage--);
                    _scrollController.animateTo(0, duration: Duration(milliseconds: 300), curve: Curves.easeOut);
                    _loadRatings();
                  }
                : null,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              textStyle: TextStyle(fontSize: 13),
            ),
            child: const Text('上一页'),
          ),
          const SizedBox(width: 16),
          Text(
            '$_currentPage / $totalPages',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: _currentPage < totalPages
                ? () {
                    setState(() => _currentPage++);
                    _scrollController.animateTo(0, duration: Duration(milliseconds: 300), curve: Curves.easeOut);
                    _loadRatings();
                  }
                : null,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              textStyle: TextStyle(fontSize: 13),
            ),
            child: const Text('下一页'),
          ),
        ],
      ),
    );
  }
}
