import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../api/ApiUrls.dart';
import '../entity/DivingFish/Song.dart';
import '../manager/DivingFish/MaimaiMusicDataManager.dart';
import '../page/SongInfoPage.dart';
import '../service/SongInfoService.dart';
import '../utils/AppTheme.dart';
import '../utils/AppConstants.dart';
import '../utils/CommonWidgetUtil.dart';
import '../utils/CoverUtil.dart';
import 'package:my_first_flutter_app/utils/ApiClient.dart';

/// 最近评论页面：展示最近50条评论，每页10条，Redis+MySQL二级缓存
class RecentCommentsPage extends StatefulWidget {
  const RecentCommentsPage({super.key});

  @override
  State<RecentCommentsPage> createState() => _RecentCommentsPageState();
}

class _RecentCommentsPageState extends State<RecentCommentsPage> {
  bool _isLoading = true;
  List<CommentItem> _comments = [];
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
    await _loadComments();
  }

  Future<void> _loadSongCache() async {
    try {
      final songs = await MaimaiMusicDataManager().getCachedSongs();
      if (songs != null) {
        _songMap = {for (final s in songs) s.id: s};
      }
    } catch (_) {
      // 歌曲缓存加载失败不影响评论显示
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadComments({bool refresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final url = '${ApiUrls.CommentsRecentUrl}?page=$_currentPage&pageSize=$_pageSize${refresh ? '&refresh=true' : ''}';
      final response = await ApiClient.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          final List<dynamic> data = result['data'] ?? [];
          setState(() {
            _comments = data.map((json) => CommentItem.fromJson(json)).toList();
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
    await _loadComments(refresh: true);
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
    final label = _getDifficultyLabel(difficultyIndex);

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

  String _getDifficultyLabel(int? levelIndex) {
    const labels = ['BASIC', 'ADVANCED', 'EXPERT', 'MASTER', 'Re:MASTER'];
    if (levelIndex == null || levelIndex < 0 || levelIndex >= labels.length) {
      return '?';
    }
    return labels[levelIndex];
  }

  void _navigateToSong(String songId, int? levelIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SongInfoPage(
          songId: songId,
          initialLevelIndex: levelIndex ?? 0,
          isDefaultLevelIndex: levelIndex == null,
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
                          '最近评论',
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
                          : _comments.isEmpty
                              ? _buildEmpty(brightness)
                              : _buildCommentList(brightness, screenWidth),
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
          Icon(Icons.comment_outlined, size: 56, color: AppColors.greyHint(brightness)),
          const SizedBox(height: 12),
          Text(
            '暂无评论',
            style: TextStyle(color: AppColors.greyHint(brightness), fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentList(Brightness brightness, double screenWidth) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.03, vertical: 8),
            itemCount: _comments.length,
            itemBuilder: (context, index) {
              final comment = _comments[index];
              return _buildCommentCard(comment, brightness, screenWidth);
            },
          ),
        ),
        _buildPagination(brightness),
      ],
    );
  }

  Widget _buildCommentCard(CommentItem comment, Brightness brightness, double screenWidth) {
    final songId = comment.songId;
    final song = _getSong(songId);
    final levelIndex = comment.levelIndex ?? 0;

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
                        _formatTime(comment.createdAt),
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
                  const SizedBox(height: 4),
                  // 评论内容
                  Text(
                    comment.content,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // 用户
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 10, color: AppColors.greyHint(brightness, shade: 600)),
                      const SizedBox(width: 2),
                      Text(
                        comment.nickname ?? '匿名用户',
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
                    _loadComments();
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
                    _loadComments();
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
