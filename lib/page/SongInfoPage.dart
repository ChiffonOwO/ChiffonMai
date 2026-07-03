import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:marquee/marquee.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:media_scanner/media_scanner.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:my_first_flutter_app/manager/SongAliasManager.dart';
import 'package:my_first_flutter_app/manager/DivingFish/MaimaiMusicDataManager.dart';
import 'package:my_first_flutter_app/manager/MaidataManager.dart';
import 'package:my_first_flutter_app/entity/DivingFish/DiffSong.dart';
import 'package:my_first_flutter_app/entity/LuoXue/Collection.dart';
import 'package:my_first_flutter_app/entity/DivingFish/Song.dart';
import 'package:my_first_flutter_app/page/SongMaidataPage.dart';
import 'package:my_first_flutter_app/service/SongInfoService.dart';
import 'package:my_first_flutter_app/service/SongPlayService.dart';
import 'package:my_first_flutter_app/utils/CoverUtil.dart';
import 'package:my_first_flutter_app/utils/CommentTextValidator.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:my_first_flutter_app/utils/StringUtil.dart';
import 'package:my_first_flutter_app/utils/MaidataDecodeUtil.dart';
import 'package:my_first_flutter_app/utils/TextStyleUtil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'Collection/CollectionInfoPage.dart';
import 'SongPlayPage.dart';
import 'RankingList/SongRankingPage.dart';
import 'package:my_first_flutter_app/entity/FavoriteFolder.dart';
import 'package:my_first_flutter_app/service/FavoriteFolderService.dart';
import 'package:my_first_flutter_app/service/RankingList/SongRankingService.dart';
import 'package:my_first_flutter_app/service/BiliSearchService.dart';
import 'package:my_first_flutter_app/service/BiliRedisService.dart';
import 'package:my_first_flutter_app/service/SongInfo/SongScoreShareService.dart';
import 'package:my_first_flutter_app/service/ChartNoteService.dart';
import 'package:my_first_flutter_app/entity/ChartNote.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';

class SongInfoPage extends StatefulWidget {
  final String songId;
  final int initialLevelIndex;
  final bool isDefaultLevelIndex; // 标记是否使用默认值

  const SongInfoPage(
      {super.key,
      required this.songId,
      this.initialLevelIndex = 0,
      this.isDefaultLevelIndex = true});

  @override
  State<SongInfoPage> createState() => _SongInfoPageState();
}

class _SongInfoPageState extends State<SongInfoPage> {
  // 数据加载状态
  bool _isLoading = true;
  Map<String, dynamic>? _songData;
  List<dynamic>? _diffData; // 保持为dynamic类型，兼容Map和DiffData
  Map<String, dynamic>? _userData;
  List<dynamic>? _tagData;
  List<dynamic>? _tagSongsData;

  // Maidata解析的物量统计（优先使用）
  Map<int, List<int>> _maidataNoteCounts =
      {}; // key: 难度索引(0-4), value: [tap, hold, slide, touch, break]
  // Maidata解析的break统计
  Map<int, List<int>> _maidataBreakCounts =
      {}; // key: 难度索引(0-4), value: [trueZettaiTap, trueZettaiHold, protectedZettai, star]
  bool _maidataDecodedSuccessfully = false;
  bool _isBookmarked = false;

  // 谱面笔记相关
  bool _hasNote = false;

  // 参考时长
  int? _referenceDurationSeconds;
  bool _referenceDurationLoading = false;

  // B站谱面确认播放量
  int? _biliPlayCount;
  bool _biliPlayCountLoading = false;
  int? _biliLoadedDiffIndex; // 记录上次加载 B站播放量时的难度索引
  String? _biliBvid; // 当前显示的播放量对应的 BV 号
  bool _biliFromRedis = false; // 是否从 Redis 缓存加载
  bool _biliFromUser = false; // 是否来自用户上传的 BV

  // 舞萌DX 完成度-评级-乘数对照表
  final List<Map<String, dynamic>> maimaiRatingMultiplier = [
    {"completion": 100.5, "rating": "SSS+", "multiplier": 0.224},
    {"completion": 100.4999, "rating": "SSS", "multiplier": 0.222},
    {"completion": 100.0, "rating": "SSS", "multiplier": 0.216},
    {"completion": 99.9999, "rating": "SS+", "multiplier": 0.214},
    {"completion": 99.5, "rating": "SS+", "multiplier": 0.211},
    {"completion": 99.0, "rating": "SS", "multiplier": 0.208},
    {"completion": 98.9999, "rating": "S+", "multiplier": 0.206},
    {"completion": 98.0, "rating": "S+", "multiplier": 0.203},
    {"completion": 97.0, "rating": "S", "multiplier": 0.2},
    {"completion": 96.9999, "rating": "AAA", "multiplier": 0.176},
    {"completion": 94.0, "rating": "AAA", "multiplier": 0.168},
    {"completion": 90.0, "rating": "AA", "multiplier": 0.152},
    {"completion": 80.0, "rating": "A", "multiplier": 0.136},
    {"completion": 79.9999, "rating": "BBB", "multiplier": 0.128},
    {"completion": 75.0, "rating": "BBB", "multiplier": 0.120},
    {"completion": 70.0, "rating": "BB", "multiplier": 0.112},
    {"completion": 60.0, "rating": "B", "multiplier": 0.096},
    {"completion": 50.0, "rating": "C", "multiplier": 0.08},
  ];

  // 当前选中的难度索引
  late int _currentDiffIndex; // 初始值将在initState中设置

  // 表格展开状态
  bool _starScoreTableExpanded = false; // 星星等级表格默认收起
  bool _showNextStarDiff = false; // 是否显示到下一星级的差距
  bool _achievementScoreTableExpanded = false; // 达成率表格默认收起
  bool _tagsTableExpanded = false; // 谱面标签默认收起
  bool _toleranceCalculationExpanded = false; // 容错计算默认收起
  bool _ratingDistributionExpanded = false; // 评级分布默认收起
  bool _comboDistributionExpanded = false; // 连击分布默认收起

  // 容错计算相关
  String _selectedNoteType = 'TAP'; // 当前选中的音符类型
  final List<String> _noteTypes = [
    'TAP',
    'HOLD',
    'SLIDE',
    'TOUCH',
    'BREAK'
  ]; // 五种音符类型
  // 自定义BREAK输入（用于非BREAK音符的容错计算）
  int _break50Count = 0; // 已打出的50落数量
  int _break100Count = 0; // 已打出的100落数量
  int _break80Count = 0; // 已打出的80%GREAT数量
  int _break60Count = 0; // 已打出的60%GREAT数量
  int _break50gCount = 0; // 已打出的50%GREAT数量
  int _breakGoodCount = 0; // 已打出的GOOD数量
  int _breakMissCount = 0; // 已打出的MISS数量
  TextEditingController _break50Controller = TextEditingController();
  TextEditingController _break100Controller = TextEditingController();
  TextEditingController _break80Controller = TextEditingController();
  TextEditingController _break60Controller = TextEditingController();
  TextEditingController _break50gController = TextEditingController();
  TextEditingController _breakGoodController = TextEditingController();
  TextEditingController _breakMissController = TextEditingController();
  // 各音符权重（参考AchievementRateCalculatorPage）
  static const int _tapWeight = 1;
  static const int _holdWeight = 2;
  static const int _slideWeight = 3;
  static const int _touchWeight = 1;
  static const int _breakWeight = 5;

  // 相关收藏品数量
  int _relatedCollectionsCount = 0;

  // 另一种谱面的歌曲ID（如果存在）
  String? _alternativeSongId;

  // 评论相关状态
  List<CommentItem> _comments = [];
  bool _commentsLoading = false;
  int _commentPage = 0;
  static const int _commentsPerPage = 10;
  final TextEditingController _commentInputController = TextEditingController();
  String? _commentError;
  String? _commentDataSource;
  bool _commentRefreshCooldown = false;
  String? _commentOriginalId;
  String? _commentNickname;

  // 谱面评分相关状态
  double? _chartAverageScore;
  int _chartTotalVotes = 0;
  double? _chartUserScore;
  Map<String, dynamic>? _chartUserRatingData;
  Map<String, int>? _chartRatingDistribution; // 评分分布：key 为 "5.0" 等，value 为投票数
  bool _chartRatingLoading = false;
  double _selectedRating = 3.0;
  int? _userTotalRating;
  int? _theoreticalRating;

  @override
  void initState() {
    super.initState();
    _currentDiffIndex = widget.initialLevelIndex;
    _commentInputController.addListener(_onCommentInputChanged);
    _loadData();
  }

  @override
  void dispose() {
    _break50Controller.dispose();
    _break100Controller.dispose();
    _break80Controller.dispose();
    _break60Controller.dispose();
    _break50gController.dispose();
    _breakGoodController.dispose();
    _breakMissController.dispose();
    _commentInputController.dispose();
    super.dispose();
  }

  // 加载所有数据
  Future<void> _loadData() async {
    try {
      // 使用SongInfoService加载数据
      final result = await SongInfoService().loadData(widget.songId);
      _songData = result['songData'];
      _diffData = result['diffData'];
      _userData = result['userData'];
      _tagData = result['tagData'];
      _tagSongsData = result['tagSongsData'];

      // 加载相关收藏品数量
      if (_songData != null) {
        final songTitle = _songData!['basic_info']['title'];
        final songType = _songData!['type'] ?? '';
        await _loadRelatedCollectionsCount(songTitle, songType);

        // 检测是否存在另一种谱面
        await _checkAlternativeSong(songTitle, songType);
      }

      // 从MaidataManager获取并解析物量统计
      await _loadMaidataNoteCounts();

      // 加载参考时长
      _loadReferenceDuration();

      // 加载B站谱面确认播放量
      _loadBiliPlayCount();

      // 加载评论者身份信息
      final identity = await SongInfoService.getCommentIdentity();
      if (identity != null) {
        setState(() {
          _commentDataSource = identity.dataSource;
          _commentOriginalId = identity.originalId;
          _commentNickname = identity.nickname;
        });
      }

      // 加载评论
      _loadComments();

      // 加载谱面评分数据
      _loadChartRating();

      // 预加载用户总Rating和理论Rating
      _preloadRatingData();
    } catch (e) {
      debugPrint('加载数据失败: $e');
    } finally {
      // 调整_currentDiffIndex，确保不超过实际难度数量
      if (_songData != null) {
        final levels = _songData!['level'];
        if (levels != null && levels is List) {
          // 对于难度数量大于等于4个的歌曲，默认选择第4个难度（仅当使用默认值时）
          if (levels.length >= 4 &&
              widget.isDefaultLevelIndex &&
              widget.initialLevelIndex == 0 &&
              _currentDiffIndex == 0) {
            _currentDiffIndex = 3; // 第4个难度（索引为3）
          } else if (_currentDiffIndex >= levels.length) {
            _currentDiffIndex = levels.length - 1;
          }
          // 确保索引不为负数
          if (_currentDiffIndex < 0) {
            _currentDiffIndex = 0;
          }

          // 对于只有2个难度的歌曲，拟合难度的数据跟第一个难度保持相同
          if (levels.length == 2 &&
              _diffData != null &&
              _diffData!.isNotEmpty) {
            _diffData = [_diffData![0], _diffData![0]];
          }
        } else {
          // 如果没有难度数据，设置为0
          _currentDiffIndex = 0;
        }
      }

      // 如果 _currentDiffIndex 在 finally 中被调整了，重新加载 B站播放量
      if (_currentDiffIndex != (_biliLoadedDiffIndex ?? -1)) {
        setState(() {
          _isLoading = false;
        });
        _loadBiliPlayCount();
      } else {
        setState(() {
          _isLoading = false;
        });
      }
      // 检查当前谱面是否已被收藏
      _checkBookmarkStatus();
      // 检查当前谱面是否有笔记
      _checkNoteStatus();
    }
  }

  // 加载相关收藏品数量
  Future<void> _loadRelatedCollectionsCount(
      String songTitle, String songType) async {
    try {
      final relatedCollections =
          await SongInfoService().fetchRelatedCollections(songTitle, songType);
      setState(() {
        _relatedCollectionsCount = relatedCollections.length;
      });
    } catch (e) {
      debugPrint('获取相关收藏品数量时出错: $e');
      setState(() {
        _relatedCollectionsCount = 0;
      });
    }
  }

  // 检测是否存在另一种谱面的歌曲
  Future<void> _checkAlternativeSong(
      String songTitle, String currentType) async {
    try {
      // 获取所有歌曲数据
      final songs = await MaimaiMusicDataManager().getCachedSongs();
      if (songs == null || songs.isEmpty) {
        _alternativeSongId = null;
        return;
      }

      // 确定要查找的另一种类型
      String targetType = currentType == 'DX' ? 'SD' : 'DX';

      // 查找同名但类型不同的歌曲
      final alternativeSong = songs.firstWhere(
        (song) =>
            song.basicInfo.title == songTitle &&
            song.type == targetType &&
            song.id != widget.songId,
        orElse: () => Song(
          id: '',
          title: '',
          type: '',
          ds: [],
          level: [],
          cids: [],
          charts: [],
          basicInfo: BasicInfo(
            title: '',
            artist: '',
            genre: '',
            bpm: 0,
            releaseDate: '',
            from: '',
            isNew: false,
          ),
        ),
      );

      // 如果找到另一种谱面，设置其ID
      if (alternativeSong.id.isNotEmpty) {
        _alternativeSongId = alternativeSong.id;
      } else {
        _alternativeSongId = null;
      }
    } catch (e) {
      debugPrint('检测另一种谱面时出错: $e');
      _alternativeSongId = null;
    }
  }

  // 从MaidataManager加载并解析物量统计
  Future<void> _loadMaidataNoteCounts() async {
    try {
      await MaidataManager().initialize();

      String? maidataContent = MaidataManager().getMaidata(widget.songId);

      // 日志：输出当前歌曲ID
      debugPrint('[MaidataDecode] 正在解析歌曲ID: ${widget.songId}');

      if (maidataContent != null && maidataContent.isNotEmpty) {
        // 日志：输出原始maidata内容长度
        debugPrint('[MaidataDecode] maidata内容长度: ${maidataContent.length}');

        MaidataData maidata = MaidataDecodeUtil.decode(maidataContent);

        // 日志：输出解析后的chart数量
        debugPrint('[MaidataDecode] 解析出 ${maidata.charts.length} 个chart');

        Map<int, List<int>> newNoteCounts = {};
        Map<int, List<int>> newBreakCounts = {};
        for (ChartData chart in maidata.charts) {
          // 难度索引转换：maidata的difficultyIndex是1-6，对应界面显示的0-4（跳过EASY）
          int index = chart.difficultyIndex - 2; // 转换为0-4

          // 日志：输出每个chart的详细信息
          debugPrint(
              '[MaidataDecode] chart[$index] difficultyIndex=${chart.difficultyIndex}, stats=${chart.stats}, breakStats=${chart.breakStats}');

          if (chart.stats != null) {
            NoteStats stats = chart.stats!;
            debugPrint(
                '[MaidataDecode] chart[$index] tap=${stats.tap}, hold=${stats.hold}, slide=${stats.slide}, touch=${stats.touch}, break=${stats.breakNote}');
          }

          if (chart.breakStats != null) {
            BreakStats breakStats = chart.breakStats!;
            debugPrint(
                '[MaidataDecode] chart[$index] trueZettaiTap=${breakStats.trueZettaiTap}, trueZettaiHold=${breakStats.trueZettaiHold}, protectedZettai=${breakStats.protectedZettai}, star=${breakStats.star}');
          }

          if (index >= 0 && index <= 5 && chart.stats != null) {
            NoteStats stats = chart.stats!;
            newNoteCounts[index] = [
              stats.tap,
              stats.hold,
              stats.slide,
              stats.touch,
              stats.breakNote,
            ];
            // 特殊处理6位数ID的UTAGE歌曲：只有一个难度(index=0)，但maidata中是index=5
            if (widget.songId.length == 6 && index == 5) {
              newNoteCounts[0] = [
                stats.tap,
                stats.hold,
                stats.slide,
                stats.touch,
                stats.breakNote,
              ];
            }
          }
          if (index >= 0 && index <= 5 && chart.breakStats != null) {
            BreakStats breakStats = chart.breakStats!;
            newBreakCounts[index] = [
              breakStats.trueZettaiTap,
              breakStats.trueZettaiHold,
              breakStats.protectedZettai,
              breakStats.star,
            ];
            // 特殊处理6位数ID的UTAGE歌曲：只有一个难度(index=0)，但maidata中是index=5
            if (widget.songId.length == 6 && index == 5) {
              newBreakCounts[0] = [
                breakStats.trueZettaiTap,
                breakStats.trueZettaiHold,
                breakStats.protectedZettai,
                breakStats.star,
              ];
            }
          }
        }

        // 更新状态并刷新界面
        if (newNoteCounts.isNotEmpty) {
          setState(() {
            _maidataNoteCounts = newNoteCounts;
            _maidataDecodedSuccessfully = true;
          });
        }
        if (newBreakCounts.isNotEmpty) {
          setState(() {
            _maidataBreakCounts = newBreakCounts;
            _maidataDecodedSuccessfully = true;
          });
        }
      } else {
        // 尝试使用shortId查询
        debugPrint('[MaidataDecode] 主ID查询失败，尝试使用shortId查询');
        if (_songData != null) {
          dynamic shortId =
              _songData!['basic_info']['short_id'] ?? _songData!['shortId'];
          debugPrint('[MaidataDecode] shortId: $shortId');
          if (shortId != null) {
            String shortIdStr = shortId.toString();
            String? maidataByShortId = MaidataManager().getMaidata(shortIdStr);
            if (maidataByShortId != null && maidataByShortId.isNotEmpty) {
              debugPrint(
                  '[MaidataDecode] 通过shortId找到maidata，长度: ${maidataByShortId.length}');
              MaidataData maidata = MaidataDecodeUtil.decode(maidataByShortId);
              debugPrint(
                  '[MaidataDecode] shortId解析出 ${maidata.charts.length} 个chart');
              Map<int, List<int>> newNoteCounts = {};
              Map<int, List<int>> newBreakCounts = {};
              for (ChartData chart in maidata.charts) {
                int index = chart.difficultyIndex - 2;
                debugPrint(
                    '[MaidataDecode][shortId] chart[$index] difficultyIndex=${chart.difficultyIndex}, stats=${chart.stats}, breakStats=${chart.breakStats}');

                if (chart.stats != null) {
                  NoteStats stats = chart.stats!;
                  debugPrint(
                      '[MaidataDecode][shortId] chart[$index] tap=${stats.tap}, hold=${stats.hold}, slide=${stats.slide}, touch=${stats.touch}, break=${stats.breakNote}');
                }

                if (chart.breakStats != null) {
                  BreakStats breakStats = chart.breakStats!;
                  debugPrint(
                      '[MaidataDecode][shortId] chart[$index] trueZettaiTap=${breakStats.trueZettaiTap}, trueZettaiHold=${breakStats.trueZettaiHold}, protectedZettai=${breakStats.protectedZettai}, star=${breakStats.star}');
                }

                if (index >= 0 && index <= 5 && chart.stats != null) {
                  NoteStats stats = chart.stats!;
                  newNoteCounts[index] = [
                    stats.tap,
                    stats.hold,
                    stats.slide,
                    stats.touch,
                    stats.breakNote,
                  ];
                  // 特殊处理6位数ID的UTAGE歌曲：只有一个难度(index=0)，但maidata中是index=5
                  if (widget.songId.length == 6 && index == 5) {
                    newNoteCounts[0] = [
                      stats.tap,
                      stats.hold,
                      stats.slide,
                      stats.touch,
                      stats.breakNote,
                    ];
                  }
                }
                if (index >= 0 && index <= 5 && chart.breakStats != null) {
                  BreakStats breakStats = chart.breakStats!;
                  newBreakCounts[index] = [
                    breakStats.trueZettaiTap,
                    breakStats.trueZettaiHold,
                    breakStats.protectedZettai,
                    breakStats.star,
                  ];
                  // 特殊处理6位数ID的UTAGE歌曲：只有一个难度(index=0)，但maidata中是index=5
                  if (widget.songId.length == 6 && index == 5) {
                    newBreakCounts[0] = [
                      breakStats.trueZettaiTap,
                      breakStats.trueZettaiHold,
                      breakStats.protectedZettai,
                      breakStats.star,
                    ];
                  }
                }
              }

              // 更新状态并刷新界面
              if (newNoteCounts.isNotEmpty) {
                setState(() {
                  _maidataNoteCounts = newNoteCounts;
                  _maidataDecodedSuccessfully = true;
                });
              }
              if (newBreakCounts.isNotEmpty) {
                setState(() {
                  _maidataBreakCounts = newBreakCounts;
                  _maidataDecodedSuccessfully = true;
                });
              }
            }
          }
        }
      }
    } catch (e) {
      // 静默处理，继续使用默认数据
    }
  }

  // 加载参考时长（从落雪音频获取）
  Future<void> _loadReferenceDuration() async {
    if (_referenceDurationLoading) return;
    _referenceDurationLoading = true;

    try {
      final songId = widget.songId;
      final songTitle = _songData!['basic_info']['title'];

      // 1. 先查 Redis 缓存
      final cached = await BiliRedisService().getCachedReferenceDuration(
        songId: songId,
      );

      if (cached != null && mounted) {
        setState(() {
          _referenceDurationSeconds = cached;
          _referenceDurationLoading = false;
        });
        debugPrint('[RefDuration] Redis 缓存命中: ${cached}s');
        return;
      }

      // 2. Redis 未命中，通过落雪获取
      final songType = _songData!['type'] ?? '';

      final songPlayService = SongPlayService();
      final luoXueSongId =
          await songPlayService.findLuoXueSongId(songTitle, songType);

      if (luoXueSongId == null) {
        setState(() {
          _referenceDurationLoading = false;
        });
        return;
      }

      final audioUrl =
          'https://assets2.lxns.net/maimai/music/$luoXueSongId.mp3';

      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/music_cache');
      if (!cacheDir.existsSync()) {
        cacheDir.createSync(recursive: true);
      }
      final cachedFilePath = '${cacheDir.path}/$luoXueSongId.mp3';

      // 检查本地文件缓存
      final cachedFile = File(cachedFilePath);
      if (!cachedFile.existsSync()) {
        // 下载音频文件
        final httpClient = HttpClient();
        final request = await httpClient.getUrl(Uri.parse(audioUrl));
        final response = await request.close();

        if (response.statusCode == HttpStatus.ok) {
          final sink = cachedFile.openWrite();
          await sink.addStream(response);
          await sink.close();
        } else {
          setState(() {
            _referenceDurationLoading = false;
          });
          return;
        }
      }

      // 使用 AudioPlayer 获取时长
      final audioPlayer = AudioPlayer();
      await audioPlayer.setSource(DeviceFileSource(cachedFilePath));

      final duration = await audioPlayer.getDuration();
      if (duration != null && mounted) {
        final seconds = duration.inSeconds;
        setState(() {
          _referenceDurationSeconds = seconds;
          _referenceDurationLoading = false;
        });

        // 3. 保存到 Redis（30天）
        BiliRedisService().saveReferenceDuration(
          songId: songId,
          songTitle: songTitle,
          durationSeconds: seconds,
        );
      } else {
        setState(() {
          _referenceDurationLoading = false;
        });
      }

      audioPlayer.dispose();
    } catch (e) {
      debugPrint('加载参考时长失败: $e');
      if (mounted) {
        setState(() {
          _referenceDurationLoading = false;
        });
      }
    }
  }

  // 格式化参考时长显示
  String _formatReferenceDuration() {
    if (_referenceDurationSeconds == null) {
      return _referenceDurationLoading ? '...' : '-';
    }
    final minutes = _referenceDurationSeconds! ~/ 60;
    final seconds = _referenceDurationSeconds! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  // 加载B站谱面确认播放量
  Future<void> _loadBiliPlayCount() async {
    if (_biliPlayCountLoading) return;
    _biliPlayCountLoading = true;
    _biliLoadedDiffIndex = _currentDiffIndex;
    final targetDiffIndex = _currentDiffIndex;

    try {
      final songId = widget.songId;
      final songTitle = _songData!['basic_info']['title'];

      // 1. 首先尝试从 Redis 缓存获取
      final cached = await BiliRedisService().getCachedPlayCount(
        songId: songId,
        diffIndex: targetDiffIndex,
      );

      if (cached != null && mounted && _biliLoadedDiffIndex == targetDiffIndex) {
        final cachedPlayCount = cached['play_count'] as int?;
        final cachedBvid = cached['bvid'] as String?;
        final source = cached['source'] as String?;
        if (cachedPlayCount != null && cachedPlayCount > 0) {
          setState(() {
            _biliPlayCount = cachedPlayCount;
            _biliBvid = cachedBvid;
            _biliFromRedis = true;
            _biliFromUser = source == 'user_upload';
            _biliPlayCountLoading = false;
          });
          debugPrint('[BiliRedis] 使用 Redis 缓存播放量: $cachedPlayCount, BV: $cachedBvid, source: $source');
          return;
        }
      }

      // 2. Redis 未命中，通过 B站 API 搜索
      final playCount = await BiliSearchService().fetchMaxPlayCount(
        songTitle,
        targetDiffIndex,
      );

      if (mounted && _biliLoadedDiffIndex == targetDiffIndex) {
        final result = BiliSearchService().lastSearchResult;
        final bvid = result?.bvid;
        setState(() {
          _biliPlayCount = playCount;
          _biliBvid = bvid;
          _biliFromRedis = false;
          _biliFromUser = false;
          _biliPlayCountLoading = false;
        });

        // 3. 搜索成功，将结果保存到 Redis
        if (playCount != null && playCount > 0) {
          BiliRedisService().savePlayCount(
            songId: songId,
            songTitle: songTitle,
            diffIndex: targetDiffIndex,
            playCount: playCount,
            bvid: bvid,
          );
        }
      } else {
        _biliPlayCountLoading = false;
      }
    } catch (e) {
      debugPrint('加载B站播放量失败: $e');
      if (mounted) {
        setState(() {
          _biliPlayCountLoading = false;
        });
      }
    }
  }

  // 格式化B站播放量显示
  String _formatBiliPlayCount() {
    if (_biliPlayCount == null) {
      return _biliPlayCountLoading ? '...' : '-';
    }
    final n = _biliPlayCount!;
    if (n >= 10000) {
      return '${(n / 10000).toStringAsFixed(1)}万';
    }
    return n.toString();
  }

  /// 获取来源标签（仅在对话框中显示）
  String _getBiliSourceLabel() {
    if (_biliFromUser) return '用户上传';
    if (_biliFromRedis) return 'Redis 缓存';
    return '自动获取';
  }

  /// 构建 B站播放量统计项（带 BV 上传功能）
  Widget _buildBiliPlayCountStat() {
    final screenWidth = MediaQuery.of(context).size.width;
    final brightness = Theme.of(context).brightness;
    final accentColor = _getAccentColor(_currentDiffIndex, brightness);
    final fontSize = screenWidth * 0.04;

    return Expanded(
      child: GestureDetector(
        onTap: _showBvUploadDialog,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'B站播放',
              style: TextStyle(
                fontSize: 12,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    _formatBiliPlayCount(),
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  _biliBvid != null ? Icons.edit : Icons.upload_file,
                  size: fontSize * 0.6,
                  color: accentColor.withValues(alpha: 0.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 显示 BV 号上传对话框
  void _showBvUploadDialog() {
    if (_songData == null) return;

    final songTitle = _songData!['basic_info']['title'];
    final songId = widget.songId;
    final diffIndex = _currentDiffIndex;
    final diffLabel = _getDiffLabel(diffIndex);
    final bvController = TextEditingController(text: _biliBvid ?? '');
    bool isValidating = false;
    String? validationMessage;
    bool? validationPassed;
    int? validatedPlayCount;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final brightness = Theme.of(context).brightness;
            return AlertDialog(
              title: const Text('B站谱面确认播放量'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 歌曲信息
                    Text(
                      '歌曲: $songTitle',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('难度: $diffLabel'),
                    const SizedBox(height: 8),
                    // 当前播放量信息
                    if (_biliPlayCount != null) ...[
                      Text('当前播放量: ${_formatBiliPlayCount()}'),
                      if (_biliBvid != null) Text('BV号: ${_biliBvid}'),
                      Text('来源: ${_getBiliSourceLabel()}',
                          style: TextStyle(
                            color: _biliFromUser ? AppColors.linkBlue(brightness)
                                : (_biliFromRedis ? AppColors.warningOrange(brightness) : AppColors.successGreen(brightness)),
                            fontSize: 12,
                          )),
                      const Divider(),
                    ] else if (_biliPlayCountLoading) ...[
                      const Text('正在加载播放量...'),
                      const SizedBox(height: 8),
                    ] else ...[
                      Text('暂无播放量数据',
                          style: TextStyle(color: AppColors.errorRed(brightness))),
                      const Divider(),
                    ],
                    // 手动上传区域
                    const Text('手动上传 BV 号:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      '当自动获取播放量失败时，可手动输入该歌曲谱面确认视频的 BV 号',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: bvController,
                      decoration: InputDecoration(
                        hintText: '例如: BV1xx411c7mD',
                        border: const OutlineInputBorder(),
                        suffixIcon: bvController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  bvController.clear();
                                  setDialogState(() {});
                                },
                              )
                            : null,
                      ),
                      onChanged: (_) {
                        // 清除之前的校验结果
                        if (validationMessage != null) {
                          setDialogState(() {
                            validationMessage = null;
                            validationPassed = null;
                            validatedPlayCount = null;
                          });
                        }
                      },
                    ),
                    // 校验结果
                    if (validationMessage != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: validationPassed == true
                              ? AppColors.successGreen(brightness)
                              : AppColors.errorRed(brightness),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              validationPassed == true
                                  ? Icons.check_circle
                                  : Icons.error,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                validationMessage!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // 校验通过后显示播放量
                    if (validatedPlayCount != null && validationPassed == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        '播放量: ${validatedPlayCount! >= 10000 ? "${(validatedPlayCount! / 10000).toStringAsFixed(1)}万" : validatedPlayCount.toString()}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.successGreen(brightness),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                // 校验按钮
                TextButton(
                  onPressed: isValidating
                      ? null
                      : () async {
                          final bvid = bvController.text.trim();
                          if (bvid.isEmpty) {
                            setDialogState(() {
                              validationMessage = '请输入 BV 号';
                              validationPassed = false;
                            });
                            return;
                          }
                          if (!RegExp(r'^BV[a-zA-Z0-9]{10}$').hasMatch(bvid)) {
                            setDialogState(() {
                              validationMessage = 'BV 号格式不正确（应为 BV + 10位字符）';
                              validationPassed = false;
                            });
                            return;
                          }

                          setDialogState(() => isValidating = true);

                          try {
                            final result = await BiliSearchService()
                                .validateBvForSong(bvid, songTitle);

                            if (result == null) {
                              setDialogState(() {
                                validationMessage = '校验失败: 无法获取视频信息（BV 号可能不存在）';
                                validationPassed = false;
                                isValidating = false;
                              });
                            } else if (result.passed) {
                              setDialogState(() {
                                validationMessage = '校验通过！视频标题: "${result.videoInfo.title}"';
                                validationPassed = true;
                                validatedPlayCount = result.videoInfo.playCount;
                                isValidating = false;
                              });
                            } else {
                              setDialogState(() {
                                validationMessage = '校验失败: 视频标题 "${result.videoInfo.title}" 不包含歌曲名 "$songTitle"';
                                validationPassed = false;
                                isValidating = false;
                              });
                            }
                          } catch (e) {
                            setDialogState(() {
                              validationMessage = '校验异常: $e';
                              validationPassed = false;
                              isValidating = false;
                            });
                          }
                        },
                  child: isValidating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('校验 BV 号'),
                ),
                // 确认上传按钮（只有校验通过后才可点击）
                TextButton(
                  onPressed: (validationPassed == true && !isValidating)
                      ? () async {
                          final bvid = bvController.text.trim();
                          final playCount = validatedPlayCount;

                          // 保存到本地状态
                          setState(() {
                            _biliPlayCount = playCount ?? _biliPlayCount;
                            _biliBvid = bvid;
                            _biliFromRedis = false;
                            _biliFromUser = true;
                          });

                          // 保存到 Redis 服务器
                          BiliRedisService().uploadUserBv(
                            songId: songId,
                            songTitle: songTitle,
                            diffIndex: diffIndex,
                            bvid: bvid,
                            playCount: playCount,
                          );

                          Navigator.of(dialogContext).pop();
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text('BV 号已上传'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      : null,
                  child: const Text('确认上传'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 获取音符数量，优先使用Maidata解析的结果
  List<int> _getNoteCounts(Map<String, dynamic> currentChart) {
    // 优先使用Maidata解析的物量统计
    if (_maidataNoteCounts.containsKey(_currentDiffIndex)) {
      List<int> counts = _maidataNoteCounts[_currentDiffIndex]!;
      // 检查是否所有值都为0（可能是解析失败）
      bool allZero = counts.every((count) => count == 0);
      if (!allZero) {
        return counts;
      }
    }

    // 否则使用默认的notes数据
    List<int> notes = List.filled(5, 0);
    List<dynamic> chartNotes = currentChart['notes'];
    notes[0] = chartNotes.length > 0
        ? (chartNotes[0] is int
            ? chartNotes[0]
            : int.tryParse(chartNotes[0].toString()) ?? 0)
        : 0;
    notes[1] = chartNotes.length > 1
        ? (chartNotes[1] is int
            ? chartNotes[1]
            : int.tryParse(chartNotes[1].toString()) ?? 0)
        : 0;
    notes[2] = chartNotes.length > 2
        ? (chartNotes[2] is int
            ? chartNotes[2]
            : int.tryParse(chartNotes[2].toString()) ?? 0)
        : 0;
    if (chartNotes.length > 4) {
      notes[3] = chartNotes[3] is int
          ? chartNotes[3]
          : int.tryParse(chartNotes[3].toString()) ?? 0;
      notes[4] = chartNotes[4] is int
          ? chartNotes[4]
          : int.tryParse(chartNotes[4].toString()) ?? 0;
    } else if (chartNotes.length > 3) {
      notes[4] = chartNotes[3] is int
          ? chartNotes[3]
          : int.tryParse(chartNotes[3].toString()) ?? 0;
    }
    return notes;
  }

  // 获取用户最佳成绩
  Map<String, dynamic>? _getUserBestRecord() {
    if (_userData == null || _songData == null) return null;

    final records = _userData!['records'];
    if (records == null) return null;

    // 找到对应歌曲的记录
    final songRecord = records
        .where((record) =>
            record['song_id'].toString() == widget.songId &&
            record['level_index'].toString() == _currentDiffIndex.toString())
        .toList();

    return songRecord.isNotEmpty ? songRecord.first : null;
  }

  // 获取标签分组
  Map<String, List<dynamic>> _getTagsByGroup() {
    final Map<String, List<dynamic>> groupedTags = {
      '配置': [],
      '评价': [],
      '难度': []
    };

    if (_tagData != null && _tagSongsData != null && _songData != null) {
      // 获取当前曲目的相关信息
      final String songTitle = _songData!['basic_info']['title'];
      final String songType = _songData!['type'];
      final String sheetType = songType == 'DX' ? 'dx' : 'std';

      // 映射难度索引到sheet_difficulty
      String sheetDifficulty;
      switch (_currentDiffIndex) {
        case 0:
          sheetDifficulty = 'basic';
          break;
        case 1:
          sheetDifficulty = 'advanced';
          break;
        case 2:
          sheetDifficulty = 'expert';
          break;
        case 3:
          sheetDifficulty = 'master';
          break;
        case 4:
          sheetDifficulty = 'remaster';
          break;
        default:
          sheetDifficulty = 'master';
      }

      // 过滤出当前曲目的当前难度的标签ID
      final List<int> tagIds = _tagSongsData!
          .where((item) =>
              item['song_id'] == songTitle &&
              item['sheet_type'] == sheetType &&
              item['sheet_difficulty'] == sheetDifficulty)
          .map((item) => item['tag_id'] as int)
          .toList();

      // 根据标签ID获取标签详情
      for (int tagId in tagIds) {
        final tag = _tagData!.firstWhere((t) => t['id'] == tagId,
            orElse: () => <String, Object>{});

        if (tag != null) {
          int groupId = tag['group_id'] ?? 0;
          String groupName;

          switch (groupId) {
            case 1:
              groupName = '配置';
              break;
            case 2:
              groupName = '难度';
              break;
            case 3:
              groupName = '评价';
              break;
            default:
              groupName = '配置';
          }

          if (groupedTags.containsKey(groupName)) {
            groupedTags[groupName]!.add(tag);
          }
        }
      }
    }

    return groupedTags;
  }

  // 根据难度索引获取主题颜色
  Color _getThemeColor(int diffIndex, Brightness brightness) {
    // 检查难度数量
    int difficultyCount = 0;
    if (_songData != null && _songData!['level'] != null) {
      difficultyCount = _songData!['level'].length;
    }

    // 对于6位数ID的歌曲，使用独特的粉色主题
    if (widget.songId.length == 6) {
      return AppColors.utageBackground;
    }

    // 对于只有1或2个难度的歌曲，所有难度的背景全部采用粉色
    if (difficultyCount <= 2) {
      return AppColors.difficultyBackgroundByIndex(3, brightness: brightness); // Master
    }

    return AppColors.difficultyBackgroundByIndex(diffIndex, brightness: brightness);
  }

  // 根据难度索引获取次要主题颜色
  Color _getSecondaryThemeColor(int diffIndex, Brightness brightness) {
    // 检查难度数量
    int difficultyCount = 0;
    if (_songData != null && _songData!['level'] != null) {
      difficultyCount = _songData!['level'].length;
    }

    // 对于6位数ID的歌曲，使用独特的粉色主题
    if (widget.songId.length == 6) {
      return AppColors.utageCard;
    }

    // 对于只有1或2个难度的歌曲，所有难度的背景全部采用粉色
    if (difficultyCount <= 2) {
      return AppColors.difficultySecondaryBgByIndex(3, brightness: brightness); // Master
    }

    return AppColors.difficultySecondaryBgByIndex(diffIndex, brightness: brightness);
  }

  // 根据难度索引获取强调颜色
  Color _getAccentColor(int diffIndex, Brightness brightness) {
    // 检查难度数量
    int difficultyCount = 0;
    if (_songData != null && _songData!['level'] != null) {
      difficultyCount = _songData!['level'].length;
    }

    // 对于6位数ID的歌曲，使用独特的粉色主题
    if (widget.songId.length == 6) {
      return AppColors.utageAccent;
    }

    // 对于只有1或2个难度的歌曲，所有难度的背景全部采用粉色
    if (difficultyCount <= 2) {
      return AppColors.difficultyForegroundByIndex(3, brightness: brightness); // Master
    }

    return AppColors.difficultyForegroundByIndex(diffIndex, brightness: brightness);
  }

  // 计算单曲Rating
  int _calculateSingleRating(double difficulty, double completion) {
    // 特别处理：如果达成率大于100.5，则按100.5计算
    double adjustedCompletion = completion > 100.5 ? 100.5 : completion;
    double calculationCompletion = completion > 100.5 ? 100.5 : completion;

    // 查找对应的评级和乘数
    Map<String, dynamic>? selectedRating;

    // 遍历表格查找正确的区间
    for (var item in maimaiRatingMultiplier) {
      if (adjustedCompletion >= item['completion']) {
        selectedRating = item;
        break;
      }
    }

    // 如果没有找到（不应该发生），使用默认值
    selectedRating ??= {"rating": "D", "multiplier": 0.016};

    double multiplier = selectedRating['multiplier'];

    // 计算单曲Rating
    double singleRating = difficulty * multiplier * calculationCompletion;
    return singleRating.floor(); // 取整数部分（向下取整）
  }

  // 构建星星等级最低DX分对照表
  Widget _buildStarScoreTable() {
    if (_songData == null) return Container();

    final brightness = Theme.of(context).brightness;

    int maxScore =
        _calculateMaxDxScore(int.parse(widget.songId), _currentDiffIndex);

    // 星星等级对应的最低达成率（降序排列）
    List<Map<String, dynamic>> starLevels = [
      {"star": 6, "rate": 0.99, "color": Colors.yellow},
      {"star": 5.5, "rate": 0.98, "color": Colors.yellow},
      {"star": 5, "rate": 0.97, "color": Colors.yellow},
      {"star": 4, "rate": 0.95, "color": AppColors.warningOrange(brightness)},
      {"star": 3, "rate": 0.93, "color": AppColors.warningOrange(brightness)},
      {"star": 2, "rate": 0.90, "color": brightness == Brightness.dark ? Colors.green.shade300 : Colors.green.shade300},
      {"star": 1, "rate": 0.85, "color": brightness == Brightness.dark ? Colors.green.shade300 : Colors.green.shade300},
    ];

    // 计算每个星星等级的最低DX分
    List<Map<String, dynamic>> starScoreData = [];
    for (var item in starLevels) {
      num star = item['star'];
      double rate = item['rate'];
      Color color = item['color'];
      int minScore = (maxScore * rate).ceil();
      starScoreData.add(
          {"star": star, "rate": rate, "minScore": minScore, "color": color});
    }

    // 获取玩家最佳成绩
    final userRecord = _getUserBestRecord();

    // 如果存在玩家最佳成绩，将其添加到表格中
    if (userRecord != null && userRecord['dxScore'] != null) {
      int userScore = userRecord['dxScore'];

      // 找到合适的插入位置
      int insertIndex = 0;
      while (insertIndex < starScoreData.length &&
          userScore < starScoreData[insertIndex]['minScore']) {
        insertIndex++;
      }

      // 计算玩家成绩对应的达成率
      double userRate = userScore / maxScore;

      // 确定玩家成绩的颜色
      Color userColor = AppColors.linkBlue(brightness);

      // 插入玩家成绩
      starScoreData.insert(insertIndex, {
        "star": "玩家",
        "rate": userRate,
        "minScore": userScore,
        "color": userColor,
        "isUserRecord": true
      });
    }

    // 计算提升值
    for (int i = starScoreData.length - 1; i > 0; i--) {
      int currentScore = starScoreData[i]['minScore'];
      int nextScore = starScoreData[i - 1]['minScore'];
      starScoreData[i]['delta'] = nextScore - currentScore;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题和展开收起按钮（整行可点击）
        InkWell(
          onTap: () {
            setState(() {
              _starScoreTableExpanded = !_starScoreTableExpanded;
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '星数-DX分数对照表',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _getAccentColor(_currentDiffIndex, brightness),
                  ),
                ),
                Icon(
                  _starScoreTableExpanded ? Icons.expand_less : Icons.expand_more,
                  color: _getAccentColor(_currentDiffIndex, brightness),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // 表格内容（根据展开状态显示）
        if (_starScoreTableExpanded) ...[
          // 表头
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.tableBorder(brightness))),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3, // 星数列占3份
                  child: Text('星数',
                      style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
                Expanded(
                  flex: 2, // DX分数列占2份
                  child: Text('DX分数',
                      style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.center),
                ),
                Expanded(
                  flex: 1, // MAX-列占1份
                  child: Text('MAX-',
                      style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.end),
                ),
              ],
            ),
          ),

          // 表格内容
          Column(
            children: starScoreData.asMap().entries.map((entry) {
              var item = entry.value;
              dynamic star = item['star'];
              double rate = item['rate'];
              int minScore = item['minScore'];
              int? delta = item['delta'];
              Color color = item['color'];
              bool isUserRecord = item['isUserRecord'] ?? false;

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.greyHint(brightness))),
                  color:
                      isUserRecord ? AppColors.linkBlue(brightness) : Colors.transparent,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3, // 星数列占3份
                      child: Row(
                        children: [
                          Text(
                            star == "玩家" ? '玩家' : '\u2726 ${star.toString()}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isUserRecord ? Colors.white : color,
                              shadows: [
                                Shadow(
                                  color: isUserRecord ? Colors.white.withOpacity(0.5) : color.withOpacity(0.5),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${(rate * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                                fontSize: 16, color: isUserRecord ? Colors.white : Theme.of(context).colorScheme.onSurface),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2, // 最低DX分数列占2份
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (delta != null)
                            Text(
                              '↑$delta',
                              style: TextStyle(
                                  fontSize: 14, color: isUserRecord ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          Text(
                            minScore.toString(),
                            style: TextStyle(
                              fontSize: 16,
                              color: isUserRecord ? Colors.white : Theme.of(context).colorScheme.onSurface,
                              fontWeight: isUserRecord
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 1, // MAX-列占1份
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '-${maxScore - minScore}',
                            style: TextStyle(
                              fontSize: 16,
                              color: isUserRecord ? Colors.white : Theme.of(context).colorScheme.onSurface,
                              fontWeight: isUserRecord
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  // 构建达成率-得分对照表
  Widget _buildAchievementScoreTable() {
    if (_songData == null) return Container();

    final brightness = Theme.of(context).brightness;

    // 检查歌曲id是否为6位数
    bool isSixDigitId = widget.songId.length == 6;

    double difficulty =
        double.tryParse(_songData!['ds'][_currentDiffIndex].toString()) ?? 0.0;

    // 计算每个达成率对应的得分
    List<Map<String, dynamic>> scoreData = [];
    for (var item in maimaiRatingMultiplier) {
      double completion = item['completion'];
      String rating = item['rating'];
      // 如果是6位数id的歌曲，得分设为0
      int score =
          isSixDigitId ? 0 : _calculateSingleRating(difficulty, completion);
      scoreData
          .add({"completion": completion, "rating": rating, "score": score});
    }

    // 对于定数大于等于12.0的谱面，添加额外的达成率点（比基准达成率高1分）
    // 但6位数id的歌曲不添加额外达成率点
    if (difficulty >= 12.0 && !isSixDigitId) {
      // 定义需要添加额外点的基准达成率
      List<double> baseCompletions = [97.0, 98.0, 99.0, 99.5, 100.0];

      for (double baseCompletion in baseCompletions) {
        // 找到基准达成率对应的得分
        var baseItem = scoreData.firstWhere(
          (item) => item['completion'] == baseCompletion,
        );

        int baseScore = baseItem['score'];
        int targetScore = baseScore + 1;

        // 二分查找找到需要的达成率
        double lowerBound = baseCompletion;
        double upperBound = baseCompletion;

        // 确定上界
        switch (baseCompletion) {
          case 97.0:
            upperBound = 98.0;
            break;
          case 98.0:
            upperBound = 98.9999;
            break;
          case 99.0:
            upperBound = 99.5;
            break;
          case 99.5:
            upperBound = 99.9999;
            break;
          case 100.0:
            upperBound = 100.4999;
            break;
        }

        // 二分查找
        double mid = lowerBound;
        int iterations = 0;
        while (upperBound - lowerBound > 0.0001 && iterations < 100) {
          mid = (lowerBound + upperBound) / 2;
          int currentScore = _calculateSingleRating(difficulty, mid);

          if (currentScore < targetScore) {
            lowerBound = mid;
          } else {
            upperBound = mid;
          }
          iterations++;
        }

        // 添加新的达成率点
        if (_calculateSingleRating(difficulty, mid) >= targetScore) {
          // 查找对应的评级
          String rating = "";
          for (var item in maimaiRatingMultiplier) {
            if (mid >= item['completion']) {
              rating = item['rating'];
              break;
            }
          }

          scoreData
              .add({"completion": mid, "rating": rating, "score": targetScore});
        }
      }

      // 按达成率降序排序
      scoreData.sort((a, b) => b['completion'].compareTo(a['completion']));
    }

    // 获取玩家最佳成绩
    final userRecord = _getUserBestRecord();

    // 如果存在玩家最佳成绩，将其添加到表格中
    if (userRecord != null &&
        userRecord['achievements'] != null &&
        userRecord['ra'] != null) {
      double userCompletion = userRecord['achievements'];
      int userScore = userRecord['ra'];

      // 找到合适的插入位置：对比玩家的达成率与每一行的达成率
      int insertIndex = 0;
      while (insertIndex < scoreData.length &&
          userCompletion < scoreData[insertIndex]['completion']) {
        insertIndex++;
      }

      // 插入玩家成绩（暂时不计算差距值）
      scoreData.insert(insertIndex, {
        "completion": userCompletion,
        "rating": "玩家",
        "score": userScore,
        "isUserRecord": true
      });
    }

    // 计算得分提升值
    for (int i = scoreData.length - 1; i > 0; i--) {
      int currentScore = scoreData[i]['score'];
      int nextScore = scoreData[i - 1]['score'];
      scoreData[i]['delta'] = nextScore - currentScore;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题和展开收起按钮（整行可点击）
        InkWell(
          onTap: () {
            setState(() {
              _achievementScoreTableExpanded =
                  !_achievementScoreTableExpanded;
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '达成率-得分对照表',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _getAccentColor(_currentDiffIndex, brightness),
                  ),
                ),
                Icon(
                  _achievementScoreTableExpanded
                      ? Icons.expand_less
                      : Icons.expand_more,
                  color: _getAccentColor(_currentDiffIndex, brightness),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // 表格内容（根据展开状态显示）
        if (_achievementScoreTableExpanded) ...[
          // 表头
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.tableBorder(brightness))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('达成率',
                    style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                Text('得分',
                    style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),

          // 表格内容
          Column(
            children: scoreData.asMap().entries.map((entry) {
              var item = entry.value;
              dynamic rating = item['rating'];
              double completion = item['completion'];
              int score = item['score'];
              int? delta = item['delta'];
              bool isUserRecord = item['isUserRecord'] ?? false;

              // 获取评级颜色
              Color ratingColor = Theme.of(context).colorScheme.onSurface;
              if (rating == "玩家") {
                ratingColor = Colors.white;
              } else {
                switch (rating) {
                  case 'SSS+':
                  case 'SSS':
                    ratingColor = Colors.yellow;
                    break;
                  case 'SS+':
                  case 'SS':
                    ratingColor = Color(0xFFFFAA00);
                    break;
                  case 'S+':
                  case 'S':
                    ratingColor = Color(0xFFFF9900);
                    break;
                  case 'AAA':
                  case 'AA':
                  case 'A':
                    ratingColor = Color(0xFFFF4444);
                    break;
                  case 'BBB':
                  case 'BB':
                  case 'B':
                    ratingColor = Color(0xFF44AAFF);
                    break;
                  case 'C':
                    ratingColor = Color(0xFFFF4444);
                    break;
                }
              }

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.greyHint(brightness))),
                  color:
                      isUserRecord ? AppColors.linkBlue(brightness) : Colors.transparent,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          rating.toString(),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: ratingColor,
                            shadows: [
                              Shadow(
                                color: isUserRecord ? Colors.white.withOpacity(0.5) : ratingColor.withOpacity(0.5),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${completion.toStringAsFixed(4)}%',
                          style: TextStyle(
                              fontSize: 16, color: isUserRecord ? Colors.white : Theme.of(context).colorScheme.onSurface),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (delta != null)
                          Text(
                            '↑$delta',
                            style: TextStyle(
                                fontSize: 14, color: isUserRecord ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        Text(
                          score.toString(),
                          style: TextStyle(
                            fontSize: 16,
                            color: isUserRecord ? Colors.white : Theme.of(context).colorScheme.onSurface,
                            fontWeight: isUserRecord
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _songData == null) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final basicInfo = _songData!['basic_info'];
    final charts = _songData!['charts'];
    final levels = _songData!['level'];
    final currentChart = charts[_currentDiffIndex];
    final currentDiffData =
        _diffData != null && _diffData!.length > _currentDiffIndex
            ? _diffData![_currentDiffIndex]
            : null;
    final userRecord = _getUserBestRecord();
    final groupedTags = _getTagsByGroup();

    // 获取当前难度的主题颜色
    final brightness = Theme.of(context).brightness;
    final themeColor = _getThemeColor(_currentDiffIndex, brightness);
    final secondaryThemeColor = _getSecondaryThemeColor(_currentDiffIndex, brightness);
    final accentColor = _getAccentColor(_currentDiffIndex, brightness);

    // 自定义常量
    final Color textPrimaryColor = Theme.of(context).colorScheme.onSurface;
    final double borderRadiusSmall = 8.0;
    final BoxShadow defaultShadow = AppColors.defaultShadow(brightness);

    // 曲绘将使用CoverPathUtil工具类加载

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
                          '歌曲详情',
                          style: TextStyle(
                            color: textPrimaryColor,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // 占位，保持标题居中
                    SizedBox(width: 48),
                  ],
                ),
              ),

              // 主内容区域
              Expanded(
                child: Container(
                  margin: EdgeInsets.fromLTRB(8, 0, 8, 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(borderRadiusSmall),
                    boxShadow: [defaultShadow],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 卡片区域
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                themeColor,
                                secondaryThemeColor,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 歌曲信息头部
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 封面（可点击放大）
                                  GestureDetector(
                                    onTap: () {
                                      // 显示放大的封面
                                      showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return Dialog(
                                            child: Container(
                                              padding: EdgeInsets.all(16),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    basicInfo['title'],
                                                    style: TextStyle(
                                                      fontSize: 20,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: accentColor,
                                                    ),
                                                  ),
                                                  SizedBox(height: 16),
                                                  Container(
                                                    width: 250,
                                                    height: 250,
                                                    child: ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      child: CoverUtil
                                                          .buildCoverWidgetWithContext(
                                                              context,
                                                              widget.songId
                                                                  .toString(),
                                                              300),
                                                    ),
                                                  ),
                                                  SizedBox(height: 16),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceEvenly,
                                                    children: [
                                                      ElevatedButton(
                                                        onPressed: () async {
                                                          await _saveCoverToGallery(
                                                              widget.songId
                                                                  .toString(),
                                                              basicInfo['title']
                                                                      ?.toString() ??
                                                                  'cover');
                                                        },
                                                        child: Text('保存到相册'),
                                                        style: ElevatedButton
                                                            .styleFrom(
                                                          backgroundColor:
                                                              accentColor,
                                                          foregroundColor:
                                                              Colors.white,
                                                        ),
                                                      ),
                                                      ElevatedButton(
                                                        onPressed: () {
                                                          Navigator.of(context)
                                                              .pop();
                                                        },
                                                        child: Text('关闭'),
                                                        style: ElevatedButton
                                                            .styleFrom(
                                                          backgroundColor: AppColors.greyHint(brightness),
                                                          foregroundColor:
                                                              Colors.white,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                    child: Container(
                                      width: MediaQuery.of(context).size.width *
                                          0.3,
                                      height:
                                          MediaQuery.of(context).size.width *
                                              0.3,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                                            blurRadius: 4,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: CoverUtil
                                            .buildCoverWidgetWithContext(
                                                context,
                                                widget.songId.toString(),
                                                120),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 16),

                                  // 歌曲信息
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        // 根据标题长度决定是否使用滚动
                                        GestureDetector(
                                          onTap: () {
                                            showDialog(
                                              context: context,
                                              builder: (BuildContext context) {
                                                return AlertDialog(
                                                  title: Text('歌曲标题'),
                                                  content:
                                                      Text(basicInfo['title']),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () {
                                                        Clipboard.setData(
                                                            ClipboardData(
                                                                text: basicInfo[
                                                                    'title']));
                                                        Navigator.of(context)
                                                            .pop();
                                                        ScaffoldMessenger.of(
                                                                context)
                                                            .showSnackBar(
                                                          SnackBar(
                                                              content: Text(
                                                                  '已复制到剪贴板')),
                                                        );
                                                      },
                                                      child: Text('复制'),
                                                    ),
                                                    TextButton(
                                                      onPressed: () {
                                                        Navigator.of(context)
                                                            .pop();
                                                      },
                                                      child: Text('关闭'),
                                                    ),
                                                  ],
                                                );
                                              },
                                            );
                                          },
                                          child: LayoutBuilder(
                                            builder: (context, constraints) {
                                              final style = TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold,
                                                color: accentColor,
                                              );

                                              // 计算文本宽度
                                              final TextPainter textPainter =
                                                  TextPainter(
                                                text: TextSpan(
                                                    text: basicInfo['title'],
                                                    style: style),
                                                maxLines: 1,
                                                textDirection:
                                                    TextDirection.ltr,
                                              )..layout(
                                                      minWidth: 0,
                                                      maxWidth:
                                                          double.infinity);

                                              final textWidth =
                                                  textPainter.width;
                                              final safeWidth =
                                                  constraints.maxWidth;

                                              // 如果文本宽度小于安全宽度，不需要滚动
                                              if (textWidth <= safeWidth) {
                                                return Text(
                                                  basicInfo['title'],
                                                  style: style,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                );
                                              } else {
                                                // 否则使用Marquee组件
                                                return SizedBox(
                                                  height: 40,
                                                  child: Marquee(
                                                    text: basicInfo['title'],
                                                    style: style,
                                                    scrollAxis: Axis.horizontal,
                                                    blankSpace: 20.0,
                                                    velocity: 30.0,
                                                    pauseAfterRound:
                                                        Duration(seconds: 3),
                                                  ),
                                                );
                                              }
                                            },
                                          ),
                                        ),

                                        const SizedBox(height: 12),
                                        // 显示歌曲别名
                                        _buildAliasSection(basicInfo['title']),

                                        const SizedBox(height: 8),

                                        // 显示类型和序号
                                        Row(
                                          children: [
                                            Text(
                                              widget.songId.length == 6
                                                  ? 'UTAGE'
                                                  : '${_songData!['type'] == 'SD' ? 'ST' : _songData!['type']}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: widget.songId.length == 6
                                                    ? Color(0xFFFF6B8B)
                                                    : (_songData!['type'] ==
                                                            'SD'
                                                        ? AppColors.linkBlue(brightness)
                                                        : AppColors.warningOrange(brightness)),
                                              ),
                                            ),
                                            Text(
                                              '  #${widget.songId}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                            // 如果存在另一种谱面，显示切换按钮
                                            if (_alternativeSongId != null)
                                              GestureDetector(
                                                onTap: () {
                                                  Navigator.pushReplacement(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          SongInfoPage(
                                                        songId:
                                                            _alternativeSongId!,
                                                        initialLevelIndex:
                                                            _currentDiffIndex,
                                                        isDefaultLevelIndex:
                                                            false,
                                                      ),
                                                    ),
                                                  );
                                                },
                                                child: Container(
                                                  margin: const EdgeInsets.only(
                                                      left: 8),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: _songData!['type'] ==
                                                            'SD'
                                                        ? AppColors.warningOrange(brightness)
                                                        : AppColors.linkBlue(brightness),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
                                                        blurRadius: 2,
                                                        offset: Offset(1, 1),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .swap_horizontal_circle,
                                                        size: 14,
                                                        color: Colors.white,
                                                      ),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        _songData!['type'] ==
                                                                'SD'
                                                            ? 'DX'
                                                            : 'ST',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 10),

                              // 难度标签页
                              Row(
                                children: List.generate(
                                  levels.length,
                                  (index) => Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        BiliSearchService().cancel();
                                        setState(() {
                                          _currentDiffIndex = index;
                                          _biliPlayCount = null;
                                          _biliPlayCountLoading = false;
                                          _biliBvid = null;
                                          _biliFromRedis = false;
                                          _biliFromUser = false;
                                        });
                                        _loadChartRating();
                                        _loadComments();
                                        _checkBookmarkStatus();
                                        _checkNoteStatus();
                                        _loadBiliPlayCount();
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 2),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8, horizontal: 4),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          color: _currentDiffIndex == index
                                              ? accentColor
                                              : themeColor,
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              _getDiffLabel(index),
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    0.025,
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    _currentDiffIndex == index
                                                        ? Colors.white
                                                        : accentColor,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Lv.${levels[index]}',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    0.03,
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    _currentDiffIndex == index
                                                        ? Colors.white
                                                        : accentColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 10),

                              // 统计信息行 - 第一行
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildStatItem('类别', basicInfo['genre']),
                                  _buildStatItem(
                                      'BPM', basicInfo['bpm'].toString()),
                                  _buildStatItem(
                                      '参考时长', _formatReferenceDuration()),
                                  _buildBiliPlayCountStat(),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // 统计信息行 - 第二行
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildStatItem('曲师',
                                      basicInfo['artist'].split('/').last),
                                  _buildStatItem(
                                      '版本',
                                      StringUtil.formatVersion2(
                                          basicInfo['from'])),
                                  _buildStatItem(
                                      '谱面谱师', currentChart['charter']),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // 统计信息行 - 第三行
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildStatItem(
                                      '官方定数',
                                      _songData!['ds'][_currentDiffIndex]
                                          .toStringAsFixed(1)),
                                  _buildStatItem(
                                      '拟合定数',
                                      currentDiffData != null
                                          ? (currentDiffData is DiffData
                                                  ? currentDiffData.fitDiff
                                                  : currentDiffData['fit_diff'])
                                              .toStringAsFixed(2)
                                          : '-'),
                                  Builder(builder: (ctx) {
                                      if (currentDiffData == null) {
                                        return _buildStatItem('定数差值', '-');
                                      }
                                      final ds = (_songData!['ds'][_currentDiffIndex] as num).toDouble();
                                      final fd = currentDiffData is DiffData
                                          ? currentDiffData.fitDiff
                                          : (currentDiffData['fit_diff'] as num).toDouble();
                                      final diff = fd - ds;
                                      return _buildStatItem(
                                        '定数差值',
                                        '${diff >= 0 ? "+" : ""}${diff.toStringAsFixed(2)}',
                                        valueColor: diff < 0 ? AppColors.successGreen(brightness) : AppColors.errorRed(brightness),
                                      );
                                    }),
                                  _buildStatItem(
                                      '平均达成',
                                      currentDiffData != null
                                          ? '${(currentDiffData is DiffData ? currentDiffData.avg : currentDiffData['avg']).toStringAsFixed(2)}%'
                                          : '-'),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // 音符分布网格（优先使用Maidata解析的物量统计）
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                      child: _buildNoteItem(
                                          'TAP',
                                          _getNoteCounts(currentChart)[0]
                                              .toString())),
                                  SizedBox(width: 4),
                                  Expanded(
                                      child: _buildNoteItem(
                                          'HOLD',
                                          _getNoteCounts(currentChart)[1]
                                              .toString())),
                                  SizedBox(width: 4),
                                  Expanded(
                                      child: _buildNoteItem(
                                          'SLIDE',
                                          _getNoteCounts(currentChart)[2]
                                              .toString())),
                                  SizedBox(width: 4),
                                  Expanded(
                                      child: _buildNoteItem(
                                          'BREAK',
                                          _getNoteCounts(currentChart)[4]
                                              .toString())),
                                  SizedBox(width: 4),
                                  Expanded(
                                      child: _buildNoteItem(
                                          'TOUCH',
                                          _getNoteCounts(currentChart)[3]
                                              .toString())),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // Break统计区域
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                      child: _buildBreakItem(
                                          '真绝赞TAP', _getBreakCountDisplay(0))),
                                  SizedBox(width: 4),
                                  Expanded(
                                      child: _buildBreakItem(
                                          '真绝赞HOLD', _getBreakCountDisplay(1))),
                                  SizedBox(width: 4),
                                  Expanded(
                                      child: _buildBreakItem(
                                          '保护套绝赞', _getBreakCountDisplay(2))),
                                  SizedBox(width: 4),
                                  Expanded(
                                      child: _buildBreakItem(
                                          '绝赞星星', _getBreakCountDisplay(3))),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // 玩家最佳成绩
                              Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    // 标题 + 分享按钮
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '玩家最佳成绩',
                                            style: TextStyle(
                                              fontSize: MediaQuery.of(context).size.width * 0.035,
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                        if (userRecord != null)
                                          GestureDetector(
                                            onTap: () => _shareScoreCard(
                                              userRecord: userRecord,
                                              basicInfo: basicInfo,
                                              levels: levels,
                                            ),
                                            child: Container(
                                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Theme.of(context).colorScheme.primary,
                                                    Theme.of(context).colorScheme.primary.withOpacity(0.85),
                                                  ],
                                                ),
                                                borderRadius: BorderRadius.circular(14),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Theme.of(context).colorScheme.primary.withAlpha(60),
                                                    blurRadius: 6,
                                                    offset: Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.share, size: 14, color: Theme.of(context).colorScheme.onPrimary),
                                                  SizedBox(width: 4),
                                                  Text('分享成绩',
                                                    style: TextStyle(fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                        color: Theme.of(context).colorScheme.onPrimary)),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),

                                    // 内容（始终展开）
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // 达成率行 + 收藏按钮
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      userRecord != null
                                                          ? '${userRecord['achievements'].toStringAsFixed(4)}%'
                                                          : '无记录',
                                                      style: TextStyle(
                                                        fontSize:
                                                            MediaQuery.of(context)
                                                                    .size
                                                                    .width *
                                                                0.08,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        foreground: Paint()
                                                          ..shader = LinearGradient(
                                                            colors: [
                                                              AppColors.errorRed(brightness),
                                                              Colors.yellow,
                                                            ],
                                                            begin: Alignment
                                                                .centerLeft,
                                                            end: Alignment
                                                                .centerRight,
                                                          ).createShader(
                                                              Rect.fromLTWH(
                                                                  0,
                                                                  0,
                                                                  MediaQuery.of(
                                                                              context)
                                                                          .size
                                                                          .width *
                                                                      0.5,
                                                                  50)),
                                                      ),
                                                    ),
                                                  ),
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      GestureDetector(
                                                        onTap: () => _showBookmarkDialog(),
                                                        child: Padding(
                                                          padding: EdgeInsets.all(3),
                                                          child: Icon(
                                                            _isBookmarked ? Icons.favorite : Icons.favorite_border,
                                                            color: Colors.pink.shade400, size: 23),
                                                        ),
                                                      ),
                                                      GestureDetector(
                                                        onTap: () => _showNoteDialog(),
                                                        child: Padding(
                                                          padding: EdgeInsets.all(3),
                                                          child: Icon(
                                                            _hasNote ? Icons.note : Icons.note_add_outlined,
                                                            color: Colors.amber.shade700, size: 23),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                userRecord != null
                                                    ? 'Rating: ${userRecord['ra']}'
                                                    : '',
                                                style: TextStyle(
                                                  fontSize:
                                                      MediaQuery.of(context)
                                                              .size
                                                              .width *
                                                          0.042,
                                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              if (userRecord != null) ...[
                                                RichText(
                                                  text: TextSpan(
                                                    children: [
                                                      TextStyleUtil.span(
                                                        'DX分数: ${userRecord['dxScore']} / ${_calculateMaxDxScore(int.parse(widget.songId), _currentDiffIndex)}  ',
                                                        TextStyle(
                                                          fontSize: MediaQuery.of(
                                                                      context)
                                                                  .size
                                                                  .width *
                                                              0.042,
                                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                        ),
                                                      ),
                                                      TextStyleUtil.span(
                                                        '(MAX -${_calculateMaxDxScore(int.parse(widget.songId), _currentDiffIndex) - userRecord['dxScore']})',
                                                        TextStyle(
                                                          fontSize: MediaQuery.of(
                                                                      context)
                                                                  .size
                                                                  .width *
                                                              0.042,
                                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    RichText(
                                                      text: TextSpan(
                                                        children: [
                                                          TextStyleUtil.span(
                                                            'DX分数达成率: ',
                                                            TextStyle(
                                                              fontSize: MediaQuery.of(
                                                                          context)
                                                                      .size
                                                                      .width *
                                                                  0.042,
                                                              color:
                                                                  Theme.of(context).colorScheme.onSurfaceVariant,
                                                            ),
                                                          ),
                                                          TextStyleUtil.span(
                                                            '${(userRecord['dxScore'] / _calculateMaxDxScore(int.parse(widget.songId), _currentDiffIndex) * 100).toStringAsFixed(2)}%  ',
                                                            TextStyle(
                                                              fontSize: MediaQuery.of(
                                                                          context)
                                                                      .size
                                                                      .width *
                                                                  0.042,
                                                              color: _getStarsColor(_calculateStars(
                                                                  int.parse(widget
                                                                      .songId),
                                                                  _currentDiffIndex,
                                                                  userRecord[
                                                                      'dxScore'])),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    GestureDetector(
                                                      onTap: () {
                                                        setState(() {
                                                          _showNextStarDiff =
                                                              !_showNextStarDiff;
                                                        });
                                                      },
                                                      child: Text(
                                                        _showNextStarDiff
                                                            ? _calculateNextStarDiff(
                                                                int.parse(widget
                                                                    .songId),
                                                                _currentDiffIndex,
                                                                userRecord[
                                                                    'dxScore'])
                                                            : _calculateStarsBonus(
                                                                int.parse(widget
                                                                    .songId),
                                                                _currentDiffIndex,
                                                                userRecord[
                                                                    'dxScore']),
                                                        style: TextStyle(
                                                          fontSize: MediaQuery.of(
                                                                      context)
                                                                  .size
                                                                  .width *
                                                              0.042,
                                                          color: _getStarsColor(
                                                              _calculateStars(
                                                                  int.parse(widget
                                                                      .songId),
                                                                  _currentDiffIndex,
                                                                  userRecord[
                                                                      'dxScore'])),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                const SizedBox(height: 8),
                                              ],
                                              Row(
                                                children: [
                                                  Text('连击,同步：'),
                                                  if (userRecord != null) ...[
                                                    userRecord['fc'].isNotEmpty
                                                        ? _buildBadge(
                                                            userRecord['fc'])
                                                        : _buildPlaceholder(),
                                                    userRecord['fs'].isNotEmpty
                                                        ? _buildBadge(
                                                            userRecord['fs'])
                                                        : _buildPlaceholder(),
                                                  ] else ...[
                                                    _buildPlaceholder(),
                                                    _buildPlaceholder(),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: 12),

                              // 按钮行（跳转到B站、播放音乐、查看谱面代码和查看收藏品）
                              Container(
                                margin: const EdgeInsets.only(top: 0),
                                child: GridView.builder(
                                  shrinkWrap: true,
                                  physics: NeverScrollableScrollPhysics(),
                                  padding: EdgeInsets.zero,
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                    childAspectRatio: 3.0,
                                  ),
                                  itemCount: 6,
                                  itemBuilder: (context, index) {
                                    switch (index) {
                                      case 0:
                                        return ElevatedButton(
                                          onPressed: _jumpToBilibili,
                                          child: const Text('B站谱面确认'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.pink,
                                            foregroundColor: Colors.white,
                                            padding: EdgeInsets.symmetric(
                                                vertical: 6, horizontal: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        );
                                      case 1:
                                        return ElevatedButton(
                                          onPressed: _playMusic,
                                          child: const Text('播放音乐'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.linkBlue(brightness),
                                            foregroundColor: Colors.white,
                                            padding: EdgeInsets.symmetric(
                                                vertical: 6, horizontal: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        );
                                      case 2:
                                        return ElevatedButton(
                                          onPressed: _viewMaidata,
                                          child: const Text('查看谱面代码'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.successGreen(brightness),
                                            foregroundColor: Colors.white,
                                            padding: EdgeInsets.symmetric(
                                                vertical: 6, horizontal: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        );
                                      case 3:
                                        return ElevatedButton(
                                          onPressed: _viewRelatedCollectibles,
                                          child: Text(
                                              '相关收藏品 $_relatedCollectionsCount'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.purple,
                                            foregroundColor: Colors.white,
                                            padding: EdgeInsets.symmetric(
                                                vertical: 6, horizontal: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        );
                                      case 4:
                                        return ElevatedButton(
                                          onPressed: _viewAchievementRanking,
                                          child: const Text('达成率排行榜'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.warningOrange(brightness),
                                            foregroundColor: Colors.white,
                                            padding: EdgeInsets.symmetric(
                                                vertical: 6, horizontal: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        );
                                      case 5:
                                        return ElevatedButton(
                                          onPressed: _viewDxScoreRanking,
                                          child: const Text('DX分数排行榜'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.linkBlue(brightness),
                                            foregroundColor: Colors.white,
                                            padding: EdgeInsets.symmetric(
                                                vertical: 6, horizontal: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        );
                                      default:
                                        return Container();
                                    }
                                  },
                                ),
                              ),

                              const SizedBox(height: 20),

                              // 评级分布
                              _buildRatingDistribution(currentDiffData),

                              const SizedBox(height: 20),

                              // 连击分布
                              _buildComboDistribution(currentDiffData),

                              const SizedBox(height: 20),

                              // 谱面标签
                              Container(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 标题和展开收起按钮（整行可点击）
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          _tagsTableExpanded =
                                              !_tagsTableExpanded;
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '谱面标签(仅供参考)',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: accentColor,
                                              ),
                                            ),
                                            Icon(
                                              _tagsTableExpanded
                                                  ? Icons.expand_less
                                                  : Icons.expand_more,
                                              color: accentColor,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 10),

                                    // 标签分组（根据展开状态显示）
                                    if (_tagsTableExpanded) ...[
                                      for (var group in groupedTags.entries)
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              group.key,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: accentColor,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            if (group.value.isNotEmpty)
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: group.value
                                                    .map(
                                                      (tag) => GestureDetector(
                                                        onTap: () {
                                                          final description =
                                                              tag['description']
                                                                  ?.toString();
                                                          if (description !=
                                                                  null &&
                                                              description
                                                                  .isNotEmpty) {
                                                            showDialog(
                                                              context: context,
                                                              builder: (ctx) =>
                                                                  AlertDialog(
                                                                contentPadding:
                                                                    const EdgeInsets
                                                                        .symmetric(
                                                                        horizontal:
                                                                            20,
                                                                        vertical:
                                                                            16),
                                                                shape: RoundedRectangleBorder(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            12)),
                                                                content: Column(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    Text(
                                                                      tag['name']
                                                                              ?.toString() ??
                                                                          '',
                                                                      style:
                                                                          TextStyle(
                                                                        fontSize:
                                                                            16,
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        color: Theme.of(ctx).colorScheme.onSurface,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                        height:
                                                                            8),
                                                                    Text(
                                                                      description,
                                                                      style:
                                                                          TextStyle(
                                                                        fontSize:
                                                                            14,
                                                                        color: Theme.of(ctx).colorScheme.onSurface,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                        height:
                                                                            12),
                                                                    RichText(
                                                                      text:
                                                                          TextSpan(
                                                                        style: const TextStyle(
                                                                            fontSize:
                                                                                11),
                                                                        children: [
                                                                          TextSpan(
                                                                            text:
                                                                                '标签数据来源自 ',
                                                                            style:
                                                                                TextStyle(color: AppColors.greyHint(brightness)),
                                                                          ),
                                                                          TextSpan(
                                                                            text:
                                                                                'https://dxrating.net/',
                                                                            style:
                                                                                TextStyle(
                                                                              color: AppColors.linkBlue(brightness),
                                                                              decoration: TextDecoration.underline,
                                                                            ),
                                                                            recognizer: TapGestureRecognizer()
                                                                              ..onTap = () async {
                                                                                final uri = Uri.parse('https://dxrating.net/');
                                                                                if (await canLaunchUrl(uri)) {
                                                                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                                                                }
                                                                              },
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                                actions: [
                                                                  TextButton(
                                                                    onPressed: () =>
                                                                        Navigator.of(ctx)
                                                                            .pop(),
                                                                    child:
                                                                        const Text(
                                                                            '关闭'),
                                                                  ),
                                                                ],
                                                              ),
                                                            );
                                                          }
                                                        },
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            horizontal: 12,
                                                            vertical: 6,
                                                          ),
                                                          decoration:
                                                              BoxDecoration(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        20),
                                                            color: _getTagColor(
                                                                group.key),
                                                            border: Border.all(
                                                              color:
                                                                  _getTagBorderColor(
                                                                      group
                                                                          .key),
                                                              width: 1,
                                                            ),
                                                          ),
                                                          child: Text(
                                                            tag['name']
                                                                    ?.toString() ??
                                                                '未知标签',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              color:
                                                                  _getTagTextColor(
                                                                      group
                                                                          .key),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                    .toList(),
                                              )
                                            else
                                              Text(
                                                '当前分类暂无标签',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                            const SizedBox(height: 12),
                                          ],
                                        ),
                                    ],
                                  ],
                                ),
                              ),

                              const SizedBox(height: 20),

                              // 容错计算
                              _buildToleranceCalculation(),

                              const SizedBox(height: 20),

                              // 星星等级最低DX分对照表
                              _buildStarScoreTable(),

                              const SizedBox(height: 20),

                              // 达成率-得分对照表
                              _buildAchievementScoreTable(),

                              const SizedBox(height: 20),

                              // 谱面评分
                              _buildChartRatingSection(accentColor),

                              const SizedBox(height: 20),

                              // 评论区
                              _buildCommentsSection(),

                              const SizedBox(height: 20),
                            ],
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

  void _onCommentInputChanged() {
    if (_commentError != null) {
      setState(() => _commentError = null);
    }
  }

  // ============== 谱面评分相关方法 ==============

  Future<void> _preloadRatingData() async {
    final totalRating = await SongInfoService.getUserTotalRating();
    final theoreticalRating = await SongInfoService.getTheoreticalRating();
    if (mounted) {
      setState(() {
        _userTotalRating = totalRating;
        _theoreticalRating = theoreticalRating;
      });
    }
  }

  Future<void> _loadChartRating() async {
    setState(() {
      _chartRatingLoading = true;
    });

    try {
      // 1. 先通过API获取加权平均分和总投票数
      final result = await SongInfoService.getChartRating(
        songId: widget.songId,
        levelIndex: _currentDiffIndex,
      );

      // 2. 直接从 MySQL 查询用户自己的评分行
      final userRatingFromMySQL =
          await SongInfoService.getUserChartRatingFromMySQL(
        songId: widget.songId,
        levelIndex: _currentDiffIndex,
      );

      if (result['success'] == true) {
        setState(() {
          _chartAverageScore = result['averageScore'] != null
              ? (result['averageScore'] as num).toDouble()
              : null;
          _chartTotalVotes = result['totalVotes'] ?? 0;
          // 解析评分分布数据
          final distRaw = result['distribution'];
          if (distRaw is Map) {
            _chartRatingDistribution = {};
            for (var entry in distRaw.entries) {
              final key = entry.key.toString();
              final val = entry.value;
              if (val is int) {
                _chartRatingDistribution![key] = val;
              } else if (val is num) {
                _chartRatingDistribution![key] = val.toInt();
              }
            }
          }
          // 优先使用从 MySQL 直接查询的用户评分行数据
          _chartUserRatingData = userRatingFromMySQL ?? result['userRating'] as Map<String, dynamic>?;
          _chartUserScore = _chartUserRatingData != null &&
                  _chartUserRatingData!['score'] != null
              ? (_chartUserRatingData!['score'] as num).toDouble()
              : null;
          if (_chartUserScore != null) {
            _selectedRating = _chartUserScore!;
          }
          _chartRatingLoading = false;
        });
      } else {
        setState(() {
          // 即使 API 失败，也尝试从 MySQL 获取用户评分
          _chartUserRatingData = userRatingFromMySQL;
          _chartUserScore = _chartUserRatingData != null &&
                  _chartUserRatingData!['score'] != null
              ? (_chartUserRatingData!['score'] as num).toDouble()
              : null;
          if (_chartUserScore != null) {
            _selectedRating = _chartUserScore!;
          }
          _chartRatingLoading = false;
        });
      }
    } catch (e) {
      debugPrint('加载谱面评分失败: $e');
      // 失败时也尝试直接从 MySQL 获取用户评分
      try {
        final userRatingFromMySQL =
            await SongInfoService.getUserChartRatingFromMySQL(
          songId: widget.songId,
          levelIndex: _currentDiffIndex,
        );
        setState(() {
          _chartUserRatingData = userRatingFromMySQL;
          _chartUserScore = _chartUserRatingData != null &&
                  _chartUserRatingData!['score'] != null
              ? (_chartUserRatingData!['score'] as num).toDouble()
              : null;
          if (_chartUserScore != null) {
            _selectedRating = _chartUserScore!;
          }
          _chartRatingLoading = false;
        });
      } catch (_) {
        setState(() {
          _chartRatingLoading = false;
        });
      }
    }
  }

  String? _getChartRatingValidationMessage() {
    final userRecord = SongInfoService()
        .getUserBestRecord(_userData, widget.songId, _currentDiffIndex);

    if (userRecord == null) {
      return '至少游玩过一次该谱面才能参与打分';
    }

    double achievement = 0.0;
    if (userRecord['achievements'] != null) {
      achievement = (userRecord['achievements'] as num).toDouble();
    }

    List<dynamic> ds = _songData?['ds'] ?? [];
    bool isUtage = ds.length == 2 && widget.songId.length == 6;
    double maxAchievement = isUtage ? 202.0 : 101.0;

    if (achievement <= 0 || achievement > maxAchievement) {
      return '成绩不合法，请检查';
    }

    int totalRating = _userTotalRating ?? 0;
    int theoreticalRating = _theoreticalRating ?? 0;

    if (totalRating <= 0 || theoreticalRating <= 0) {
      return '成绩不合法，请检查';
    }

    return null;
  }

  Future<void> _submitChartRating() async {
    if (_commentDataSource == null || _commentOriginalId == null) {
      Fluttertoast.showToast(msg: '请先在首页刷新数据以获取用户身份');
      return;
    }

    final userRecord = SongInfoService()
        .getUserBestRecord(_userData, widget.songId, _currentDiffIndex);
    double achievementRate = 0.0;
    if (userRecord != null && userRecord['achievements'] != null) {
      achievementRate = (userRecord['achievements'] as num).toDouble();
    }

    int totalRating = _userTotalRating ?? 0;
    int theoreticalRating = _theoreticalRating ?? 1;

    if (theoreticalRating == 0) theoreticalRating = 1;

    try {
      final result = await SongInfoService.submitChartRating(
        songId: widget.songId,
        levelIndex: _currentDiffIndex,
        score: _selectedRating,
        achievementRate: achievementRate,
        totalRating: totalRating,
        theoreticalRating: theoreticalRating,
      );

      if (result['success'] == true) {
        Fluttertoast.showToast(msg: '评分提交成功');
        _loadChartRating();
      } else {
        Fluttertoast.showToast(msg: result['message'] ?? '评分提交失败');
      }
    } catch (e) {
      debugPrint('提交谱面评分失败: $e');
      Fluttertoast.showToast(msg: '评分提交失败');
    }
  }

  Future<void> _deleteChartRating() async {
    if (_commentDataSource == null || _commentOriginalId == null) {
      Fluttertoast.showToast(msg: '请先在首页刷新数据以获取用户身份');
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        final brightness = Theme.of(ctx).brightness;
        return AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除您的评分吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                final result = await SongInfoService.deleteChartRating(
                  songId: widget.songId,
                  levelIndex: _currentDiffIndex,
                );
                if (result['success'] == true) {
                  Fluttertoast.showToast(msg: '评分删除成功');
                  _loadChartRating();
                } else {
                  Fluttertoast.showToast(msg: result['message'] ?? '评分删除失败');
                }
              } catch (e) {
                debugPrint('删除谱面评分失败: $e');
                Fluttertoast.showToast(msg: '评分删除失败');
              }
            },
            child: Text('删除', style: TextStyle(color: AppColors.errorRed(brightness))),
          ),
        ],
      );
      },
    );
  }

  Widget _buildChartRatingSection(Color accentColor) {
    final brightness = Theme.of(context).brightness;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : AppColors.greyHint(brightness).withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star_rounded, color: accentColor, size: 20),
              const SizedBox(width: 8),
              Text(
                '谱面评分',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '($_chartTotalVotes人评分)',
                        style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(width: 4),
                      if (_chartRatingDistribution != null)
                        GestureDetector(
                          onTap: () => _showRatingDistributionDialog(accentColor),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.bar_chart_rounded,
                                    size: 14, color: accentColor),
                                const SizedBox(width: 4),
                                Text(
                                  '分布',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: accentColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(width: 4),
                      IconButton(
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.refresh, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        onPressed: _loadChartRating,
                        tooltip: '刷新评分',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.linkBlue(brightness).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: AppColors.linkBlue(brightness)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '评分仅供参考，请客观公正地评价谱面，自觉维护社区环境',
                    style: TextStyle(fontSize: 11, color: AppColors.linkBlue(brightness)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          if (_chartRatingLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            // 总评分显示
            Row(
              children: [
                Text(
                  _chartAverageScore != null
                      ? _chartAverageScore!.toStringAsFixed(2)
                      : '-',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: _chartAverageScore != null
                        ? _getRatingColor(_chartAverageScore!)
                        : AppColors.ratingColor("D"),
                  ),
                ),
                const SizedBox(width: 12),
                if (_chartAverageScore != null)
                  Row(
                    children: List.generate(
                      5,
                      (index) {
                        double fill = _chartAverageScore! - index;
                        if (fill >= 1) {
                          return Icon(Icons.star_rounded,
                              color: _getRatingColor(_chartAverageScore!),
                              size: 24);
                        } else if (fill > 0) {
                          return Icon(Icons.star_half_rounded,
                              color: _getRatingColor(_chartAverageScore!),
                              size: 24);
                        } else {
                          return Icon(Icons.star_outline_rounded,
                              color: AppColors.greyHint(brightness), size: 24);
                        }
                      },
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // 我的最近评分卡片（直接从 MySQL 查询）
            if (_chartUserRatingData != null &&
                _chartUserRatingData!['score'] != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accentColor.withOpacity(0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.history_rounded,
                            color: accentColor, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '我的最近评分',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 星级 + 评分
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                (_chartUserRatingData!['score'] as num)
                                    .toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: _getRatingColor(
                                      (_chartUserRatingData!['score'] as num)
                                          .toDouble()),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Row(
                                children: List.generate(
                                  5,
                                  (index) {
                                    double fill =
                                        (_chartUserRatingData!['score'] as num)
                                                .toDouble() -
                                            index;
                                    if (fill >= 1) {
                                      return Icon(Icons.star_rounded,
                                          color: _getRatingColor(
                                              (_chartUserRatingData!['score']
                                                      as num)
                                                  .toDouble()),
                                          size: 16);
                                    } else if (fill > 0) {
                                      return Icon(Icons.star_half_rounded,
                                          color: _getRatingColor(
                                              (_chartUserRatingData!['score']
                                                      as num)
                                                  .toDouble()),
                                          size: 16);
                                    } else {
                                      return Icon(Icons.star_outline_rounded,
                                          color: AppColors.greyHint(brightness), size: 16);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 时间信息
                        if (_chartUserRatingData!['createdAt'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.greyHint(brightness)),
                            ),
                            child: Text(
                              _formatChartRatingTime(
                                  _chartUserRatingData!['createdAt']),
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),

            // 用户评分区域
            if (_commentDataSource != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _chartUserScore != null ? '我的评分（点击修改）' : '为这个谱面评分',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: _selectedRating,
                            min: 1.0,
                            max: 5.0,
                            divisions: 8,
                            activeColor: accentColor,
                            label: _selectedRating.toStringAsFixed(1),
                            onChanged: (value) {
                              setState(() {
                                _selectedRating = value;
                              });
                            },
                          ),
                        ),
                        Container(
                          width: 48,
                          alignment: Alignment.center,
                          child: Text(
                            _selectedRating.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final validationMsg =
                            _getChartRatingValidationMessage();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (validationMsg != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded,
                                        size: 16, color: AppColors.errorRed(brightness)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        validationMsg,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.errorRed(brightness),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (_chartUserScore != null)
                                  TextButton(
                                    onPressed: _deleteChartRating,
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.errorRed(brightness),
                                    ),
                                    child: const Text('删除评分'),
                                  ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 100,
                                  child: ElevatedButton(
                                    onPressed: validationMsg == null
                                        ? _submitChartRating
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: accentColor,
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor: AppColors.greyHint(brightness),
                                      disabledForegroundColor: AppColors.greyHint(brightness),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Text(
                                      _chartUserScore != null ? '更新' : '提交',
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ] else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.warningOrange(brightness),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.warningOrange(brightness)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: AppColors.warningOrange(brightness)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '请在首页刷新数据以获取身份后再评分',
                        style:
                            TextStyle(fontSize: 13, color: AppColors.warningOrange(brightness)),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Color _getRatingColor(double score) {
    if (score >= 5.5) return Colors.yellow;
    if (score >= 4.0) return AppColors.ratingColor('S');
    if (score >= 3.0) return AppColors.ratingColor('A');
    if (score >= 2.0) return AppColors.ratingColor('B');
    return AppColors.ratingColor('D');
  }

  // 显示评分分布对话框
  void _showRatingDistributionDialog(Color accentColor) {
    final dist = _chartRatingDistribution;
    if (dist == null || _chartTotalVotes == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无评分数据'), duration: Duration(seconds: 1)),
      );
      return;
    }

    // 评分等级从高到低（5.0 到 1.0）
    final List<String> scoreKeys = [
      '5.0', '4.5', '4.0', '3.5', '3.0',
      '2.5', '2.0', '1.5', '1.0'
    ];

    // 找到最大样本数用于计算进度条长度
    int maxCount = 0;
    for (var key in scoreKeys) {
      final c = dist[key] ?? 0;
      if (c > maxCount) maxCount = c;
    }

    final brightness = Theme.of(context).brightness;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: accentColor),
              const SizedBox(width: 8),
              const Text('评分分布'),
            ],
          ),
          content: Container(
            width: 400,
            constraints: const BoxConstraints(maxHeight: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 总评分人数
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '共 $_chartTotalVotes 人评分',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      if (_chartAverageScore != null)
                        Text(
                          '均分 ${_chartAverageScore!.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _getRatingColor(_chartAverageScore!),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // 横向进度条分布
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: scoreKeys.map((key) {
                        final count = dist[key] ?? 0;
                        final double percentage =
                            maxCount > 0 ? count / maxCount : 0.0;
                        final double ratingValue = double.parse(key);
                        final Color barColor =
                            _getRatingColor(ratingValue);

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              // 星级标签
                              SizedBox(
                                width: 60,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.star_rounded,
                                      color: barColor,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      key,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // 进度条
                              Expanded(
                                child: Stack(
                                  children: [
                                    Container(
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.surface,
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                    ),
                                    FractionallySizedBox(
                                      widthFactor: percentage > 0
                                          ? percentage.clamp(0.02, 1.0)
                                          : 0.0,
                                      child: Container(
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: barColor.withOpacity(0.85),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // 人数
                              SizedBox(
                                width: 40,
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('关闭', style: TextStyle(color: accentColor)),
            ),
          ],
        );
      },
    );
  }

  // 格式化评分时间
  String _formatChartRatingTime(dynamic rawTime) {
    try {
      if (rawTime == null) return '';
      DateTime time;
      if (rawTime is String) {
        time = DateTime.parse(rawTime);
      } else if (rawTime is int) {
        // 可能是时间戳
        time = DateTime.fromMillisecondsSinceEpoch(rawTime);
      } else {
        return rawTime.toString();
      }
      DateTime now = DateTime.now();
      Duration diff = now.difference(time);

      if (diff.inMinutes < 1) return '刚刚';
      if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
      if (diff.inHours < 24) return '${diff.inHours}小时前';
      if (diff.inDays < 7) return '${diff.inDays}天前';
      return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  // ============== 评论相关方法 ==============

  // 加载评论列表
  Future<void> _loadComments({bool serverRefresh = false}) async {
    setState(() {
      _commentsLoading = true;
    });

    try {
      final comments = await SongInfoService.getCommentsForSong(widget.songId,
          levelIndex: _currentDiffIndex,
          forceRefresh: true,
          serverRefresh: serverRefresh);
      setState(() {
        _comments = comments;
        _commentPage = 0;
        _commentsLoading = false;
      });
      debugPrint(
          'SongInfoPage: 评论加载完成，数量=${comments.length}，levelIndex=$_currentDiffIndex');
    } catch (e) {
      debugPrint('SongInfoPage: 评论加载失败: $e');
      setState(() {
        _commentsLoading = false;
      });
    }
  }

  // 提交评论（自动构建评论身份）
  Future<void> _submitComment() async {
    final content = _commentInputController.text.trim();
    if (content.isEmpty) {
      setState(() => _commentError = '内容不能为空');
      return;
    }
    if (content.length > 500) {
      setState(() => _commentError = '评论内容不能超过500字');
      return;
    }

    final validationError = await CommentTextValidator.validate(content);
    if (validationError != null) {
      setState(() => _commentError = validationError);
      return;
    }

    // 如果尚未加载身份信息，自动从HomePage缓存构建
    if (_commentDataSource == null || _commentOriginalId == null) {
      final identity = await SongInfoService.getCommentIdentity();
      if (identity != null) {
        setState(() {
          _commentDataSource = identity.dataSource;
          _commentOriginalId = identity.originalId;
          _commentNickname = identity.nickname;
        });
      } else {
        Fluttertoast.showToast(msg: '请先在首页刷新数据以获取用户身份');
        return;
      }
    }

    _doSubmitComment(content);
  }

  // 实际执行提交评论
  Future<void> _doSubmitComment(String content) async {
    if (_commentDataSource == null || _commentOriginalId == null) {
      Fluttertoast.showToast(msg: '请先设置身份信息');
      return;
    }

    final result = await SongInfoService.createComment(
      songId: widget.songId,
      levelIndex: _currentDiffIndex,
      dataSource: _commentDataSource!,
      originalId: _commentOriginalId!,
      nickname: _commentNickname,
      content: content,
    );

    if (result['success'] == true) {
      _commentInputController.clear();
      setState(() => _commentError = null);
      Fluttertoast.showToast(msg: '评论发布成功');
      // 重新加载评论
      _loadComments();
    } else {
      Fluttertoast.showToast(msg: result['message'] ?? '评论发布失败');
    }
  }

  // 删除评论
  Future<void> _deleteComment(int commentId) async {
    if (_commentDataSource == null || _commentOriginalId == null) {
      Fluttertoast.showToast(msg: '无法删除：身份信息缺失');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final brightness = Theme.of(ctx).brightness;
        return AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条评论吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('删除', style: TextStyle(color: AppColors.errorRed(brightness))),
          ),
        ],
      );
      },
    );

    if (confirm != true) return;

    final result = await SongInfoService.deleteComment(
      commentId: commentId,
      songId: widget.songId,
      levelIndex: _currentDiffIndex,
      dataSource: _commentDataSource!,
      originalId: _commentOriginalId!,
    );

    if (result['success'] == true) {
      Fluttertoast.showToast(msg: '评论删除成功');
      _loadComments();
    } else {
      Fluttertoast.showToast(msg: result['message'] ?? '评论删除失败');
    }
  }

  // 格式化时间
  String _formatDateTime(String? createdAtStr) {
    if (createdAtStr == null || createdAtStr.isEmpty) return '';
    try {
      // 尝试解析多种可能的时间格式
      DateTime dt;
      if (createdAtStr.contains('T')) {
        dt = DateTime.parse(createdAtStr);
      } else {
        dt = DateTime.parse(createdAtStr.replaceAll(' ', 'T'));
      }
      // 转换为本地时间
      dt = dt.toLocal();
      return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return createdAtStr;
    }
  }

  // 检查是否为当前用户的评论
  bool _isOwnComment(CommentItem comment) {
    if (_commentDataSource == null || _commentOriginalId == null) return false;
    return comment.dataSource == _commentDataSource &&
        comment.originalId == _commentOriginalId;
  }

  // 获取当前页评论
  List<CommentItem> get _pageComments {
    final start = _commentPage * _commentsPerPage;
    final end = (start + _commentsPerPage).clamp(0, _comments.length);
    if (start >= _comments.length) return [];
    return _comments.sublist(start, end);
  }

  int get _totalPages => (_comments.length / _commentsPerPage).ceil();

  Widget _buildPageButton({required IconData icon, VoidCallback? onTap}) {
    final brightness = Theme.of(context).brightness;
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.linkBlue(brightness).withOpacity(0.1)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: enabled
                ? AppColors.linkBlue(brightness).withOpacity(0.3)
                : AppColors.tableBorder(brightness),
          ),
        ),
        child: Icon(icon,
            size: 20,
            color: enabled ? AppColors.linkBlue(brightness) : AppColors.greyHint(brightness)),
      ),
    );
  }

  // 构建评论区域
  Widget _buildCommentsSection() {
    final brightness = Theme.of(context).brightness;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : AppColors.greyHint(brightness).withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.comment, color: AppColors.linkBlue(brightness), size: 20),
              const SizedBox(width: 8),
              Text(
                '评论',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${_comments.length})',
                style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.refresh,
                    size: 20,
                    color: _commentRefreshCooldown
                        ? AppColors.greyHint(brightness)
                        : Theme.of(context).colorScheme.onSurfaceVariant),
                onPressed: _commentRefreshCooldown
                    ? null
                    : () {
                        setState(() {
                          _commentRefreshCooldown = true;
                        });
                        SongInfoService.clearAllCommentsCache();
                        _loadComments(serverRefresh: true);
                        Fluttertoast.showToast(msg: '已刷新评论');
                        Future.delayed(const Duration(seconds: 3), () {
                          if (mounted) {
                            setState(() {
                              _commentRefreshCooldown = false;
                            });
                          }
                        });
                      },
                tooltip: '刷新评论',
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.linkBlue(brightness).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: AppColors.linkBlue(brightness)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '他人评论仅供参考，请文明发言，自觉维护网络环境',
                    style: TextStyle(fontSize: 11, color: AppColors.linkBlue(brightness)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // 评论输入框
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                // 自动构建的身份信息显示
                if (_commentDataSource != null) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.account_circle,
                        size: 18,
                        color: AppColors.linkBlue(brightness),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$_commentDataSource:$_commentOriginalId${_commentNickname != null ? ' ($_commentNickname)' : ''}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ] else
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.warningOrange(brightness),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.warningOrange(brightness)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: AppColors.warningOrange(brightness)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '请在首页刷新数据以获取评论身份',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.warningOrange(brightness)),
                          ),
                        ),
                      ],
                    ),
                  ),
                TextField(
                  controller: _commentInputController,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText: '输入您的评论内容...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.tableBorder(brightness)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.tableBorder(brightness)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.linkBlue(brightness)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    isDense: true,
                    counterStyle:
                        TextStyle(fontSize: 11, color: AppColors.greyHint(brightness)),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
                if (_commentError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _commentError!,
                      style: TextStyle(fontSize: 12, color: AppColors.errorRed(brightness)),
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 100,
                      child: ElevatedButton(
                        onPressed: _submitComment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.linkBlue(brightness),
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          '发表',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 评论列表
          if (_commentsLoading)
            Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: AppColors.linkBlue(brightness)),
              ),
            )
          else if (_comments.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(
                children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 40, color: AppColors.greyHint(brightness)),
                  const SizedBox(height: 12),
                  Text(
                    '暂无评论，快来发表第一条评论吧！',
                    style: TextStyle(fontSize: 14, color: AppColors.greyHint(brightness)),
                  ),
                ],
              ),
            )
          else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _pageComments.length,
              separatorBuilder: (ctx, idx) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Divider(color: AppColors.greyHint(brightness), height: 1),
              ),
              itemBuilder: (ctx, idx) {
                final comment = _pageComments[idx];
                final isOwn = _isOwnComment(comment);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isOwn
                              ? AppColors.linkBlue(brightness).withOpacity(0.1)
                              : AppColors.greyHint(brightness),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          Icons.person,
                          size: 20,
                          color: isOwn
                              ? AppColors.linkBlue(brightness)
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  comment.nickname ??
                                      '${comment.dataSource}:${comment.originalId}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                if (isOwn) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.linkBlue(brightness)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '我',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.linkBlue(brightness),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 8),
                                Text(
                                  _formatDateTime(comment.createdAt),
                                  style: TextStyle(
                                      fontSize: 11, color: AppColors.greyHint(brightness)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              comment.content,
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurface,
                                height: 1.5,
                              ),
                            ),
                            if (isOwn) ...[
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onTap: () => _deleteComment(comment.id),
                                  child: Text(
                                    '删除',
                                    style: TextStyle(
                                        fontSize: 12, color: AppColors.errorRed(brightness)),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            // 分页控制
            if (_totalPages > 1)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildPageButton(
                      icon: Icons.chevron_left,
                      onTap: _commentPage > 0
                          ? () => setState(() => _commentPage--)
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.linkBlue(brightness).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${_commentPage + 1} / $_totalPages',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.linkBlue(brightness),
                        ),
                      ),
                    ),
                    _buildPageButton(
                      icon: Icons.chevron_right,
                      onTap: _commentPage < _totalPages - 1
                          ? () => setState(() => _commentPage++)
                          : null,
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  // 构建容错计算区域
  Widget _buildToleranceCalculation() {
    if (_songData == null) return Container();

    final brightness = Theme.of(context).brightness;
    final currentChart = _songData!['charts'][_currentDiffIndex];
    // 优先使用Maidata解析的物量统计
    List<int> noteCounts = _getNoteCounts(currentChart);

    // 计算总音符权重
    int totalTap = noteCounts[0];
    int totalHold = noteCounts[1];
    int totalSlide = noteCounts[2];
    int totalTouch = noteCounts[3];
    int totalBreak = noteCounts[4];

    int totalWeight = totalTap * _tapWeight +
        totalHold * _holdWeight +
        totalSlide * _slideWeight +
        totalTouch * _touchWeight +
        totalBreak * _breakWeight;

    // 获取当前选中音符的信息
    int noteCount = 0;
    int noteWeight = 0;
    switch (_selectedNoteType) {
      case 'TAP':
        noteCount = totalTap;
        noteWeight = _tapWeight;
        break;
      case 'HOLD':
        noteCount = totalHold;
        noteWeight = _holdWeight;
        break;
      case 'SLIDE':
        noteCount = totalSlide;
        noteWeight = _slideWeight;
        break;
      case 'TOUCH':
        noteCount = totalTouch;
        noteWeight = _touchWeight;
        break;
      case 'BREAK':
        noteCount = totalBreak;
        noteWeight = _breakWeight;
        break;
    }

    double weightRatio =
        totalWeight > 0 ? (noteCount * noteWeight) / totalWeight : 0;

    // 计算判定损失（参考AchievementRateCalculatorPage）
    double greatLoss =
        totalWeight > 0 ? (0.20 * 100.00 * noteWeight / totalWeight) : 0;
    double goodLoss =
        totalWeight > 0 ? (0.50 * 100.00 * noteWeight / totalWeight) : 0;
    double missLoss =
        totalWeight > 0 ? (1.00 * 100.00 * noteWeight / totalWeight) : 0;

    // BREAK音符特殊判定损失
    // 50落：基础部分权重相同，额外部分损失0.25 (1.0 - 0.75)
    double break50Loss = noteCount > 0 ? 0.25 / noteCount : 0; // 50落 -> 损失25%
    // 100落：基础部分权重相同，额外部分损失0.50 (1.0 - 0.50)
    double break100Loss = noteCount > 0 ? 0.5 / noteCount : 0; // 100落 -> 损失50%
    double break80Loss = totalWeight > 0
        ? (0.20 * 100.00 * noteWeight / totalWeight)
        : 0; // 80% -> 损失20%
    double break60Loss = totalWeight > 0
        ? (0.40 * 100.00 * noteWeight / totalWeight)
        : 0; // 60% -> 损失40%
    double break50gLoss = totalWeight > 0
        ? (0.50 * 100.00 * noteWeight / totalWeight)
        : 0; // 50% -> 损失50%
    double breakGoLoss = totalWeight > 0
        ? (0.60 * 100.00 * noteWeight / totalWeight)
        : 0; // 40% -> 损失60%

    // 计算容错数量
    int tolerance05Miss = missLoss > 0 ? (0.5 / missLoss).floor() : 0;
    int tolerance10Miss = missLoss > 0 ? (1.0 / missLoss).floor() : 0;

    // BREAK音符容错数量
    int tolerance05Break80 = break80Loss > 0 ? (0.5 / break80Loss).floor() : 0;
    int tolerance05Break60 = break60Loss > 0 ? (0.5 / break60Loss).floor() : 0;
    int tolerance05Break50g =
        break50gLoss > 0 ? (0.5 / break50gLoss).floor() : 0;
    int tolerance05BreakGo = breakGoLoss > 0 ? (0.5 / breakGoLoss).floor() : 0;
    int tolerance10Break80 = break80Loss > 0 ? (1.0 / break80Loss).floor() : 0;
    int tolerance10Break60 = break60Loss > 0 ? (1.0 / break60Loss).floor() : 0;
    int tolerance10Break50g =
        break50gLoss > 0 ? (1.0 / break50gLoss).floor() : 0;
    int tolerance10BreakGo = breakGoLoss > 0 ? (1.0 / breakGoLoss).floor() : 0;

    // 自定义BREAK输入相关的调整计算（用于非BREAK音符）
    // 计算已输入的BREAK判定的总损失（占整体的百分比），与BREAK选项卡保持一致
    // 注意：BREAK判定损失必须使用BREAK权重（_breakWeight=5），而非当前选中音符的权重
    double breakInputLoss = 0;
    if (totalBreak > 0) {
      breakInputLoss =
          (_break50Count * 0.25 + _break100Count * 0.50) / totalBreak;
    }
    if (totalWeight > 0) {
      breakInputLoss +=
          _break80Count * (0.20 * 100.00 * _breakWeight / totalWeight) +
              _break60Count * (0.40 * 100.00 * _breakWeight / totalWeight) +
              _break50gCount * (0.50 * 100.00 * _breakWeight / totalWeight) +
              _breakGoodCount * (0.60 * 100.00 * _breakWeight / totalWeight) +
              _breakMissCount * (1.00 * 100.00 * _breakWeight / totalWeight);
    }

    // 调整后的容错数量（扣除自定义BREAK损失后）
    double remainingBudget05 = (0.5 - breakInputLoss).clamp(0, 0.5);
    double remainingBudget10 = (1.0 - breakInputLoss).clamp(0, 1.0);
    double remainingBudget15 = (1.5 - breakInputLoss).clamp(0, 1.5);
    double remainingBudget20 = (2.0 - breakInputLoss).clamp(0, 2.0);

    int adjustedTolerance05Great = (greatLoss > 0 && remainingBudget05 > 0)
        ? (remainingBudget05 / greatLoss).floor()
        : 0;
    int adjustedTolerance05Good = (goodLoss > 0 && remainingBudget05 > 0)
        ? (remainingBudget05 / goodLoss).floor()
        : 0;
    int adjustedTolerance05Miss = (missLoss > 0 && remainingBudget05 > 0)
        ? (remainingBudget05 / missLoss).floor()
        : 0;
    int adjustedTolerance10Great = (greatLoss > 0 && remainingBudget10 > 0)
        ? (remainingBudget10 / greatLoss).floor()
        : 0;
    int adjustedTolerance10Good = (goodLoss > 0 && remainingBudget10 > 0)
        ? (remainingBudget10 / goodLoss).floor()
        : 0;
    int adjustedTolerance10Miss = (missLoss > 0 && remainingBudget10 > 0)
        ? (remainingBudget10 / missLoss).floor()
        : 0;
    int adjustedTolerance15Great = (greatLoss > 0 && remainingBudget15 > 0)
        ? (remainingBudget15 / greatLoss).floor()
        : 0;
    int adjustedTolerance15Good = (goodLoss > 0 && remainingBudget15 > 0)
        ? (remainingBudget15 / goodLoss).floor()
        : 0;
    int adjustedTolerance15Miss = (missLoss > 0 && remainingBudget15 > 0)
        ? (remainingBudget15 / missLoss).floor()
        : 0;
    int adjustedTolerance20Great = (greatLoss > 0 && remainingBudget20 > 0)
        ? (remainingBudget20 / greatLoss).floor()
        : 0;
    int adjustedTolerance20Good = (goodLoss > 0 && remainingBudget20 > 0)
        ? (remainingBudget20 / goodLoss).floor()
        : 0;
    int adjustedTolerance20Miss = (missLoss > 0 && remainingBudget20 > 0)
        ? (remainingBudget20 / missLoss).floor()
        : 0;

    // 校验输入提示
    String? breakInputError;
    final int totalInputCount = _break50Count +
        _break100Count +
        _break80Count +
        _break60Count +
        _break50gCount +
        _breakGoodCount +
        _breakMissCount;
    if (_break50Count < 0 ||
        _break100Count < 0 ||
        _break80Count < 0 ||
        _break60Count < 0 ||
        _break50gCount < 0 ||
        _breakGoodCount < 0 ||
        _breakMissCount < 0) {
      breakInputError = '数量不能为负数';
    } else if (totalInputCount > totalBreak) {
      breakInputError = '已打出总数（$totalInputCount）不能超过BREAK总数（$totalBreak）';
    } else if (breakInputLoss >= 2.0) {
      breakInputError =
          'BREAK损失已达${breakInputLoss.toStringAsFixed(2)}%，超过SS(-2%)上限，无法继续容错';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题和展开收起按钮（整行可点击）
        InkWell(
          onTap: () {
            setState(() {
              _toleranceCalculationExpanded =
                  !_toleranceCalculationExpanded;
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '容错计算',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _getAccentColor(_currentDiffIndex, brightness),
                  ),
                ),
                Icon(
                  _toleranceCalculationExpanded
                      ? Icons.expand_less
                      : Icons.expand_more,
                  color: _getAccentColor(_currentDiffIndex, brightness),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // 表格内容（根据展开状态显示）
        if (_toleranceCalculationExpanded) ...[
          // 音符类型选择器
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _noteTypes
                .where((noteType) => !(noteType == 'TOUCH' && totalTouch == 0))
                .map((noteType) => ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedNoteType = noteType;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedNoteType == noteType
                            ? _getAccentColor(_currentDiffIndex, brightness)
                            : AppColors.greyHint(brightness),
                        foregroundColor: _selectedNoteType == noteType
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                      child: Text(noteType),
                    ))
                .toList(),
          ),

          const SizedBox(height: 15),

          // 容错信息
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.greyHint(brightness)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('音符类型:', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    Text(_selectedNoteType,
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('占总权重比例:', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    Text('${(weightRatio * 100).toStringAsFixed(2)}%',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                // 仅当选中非BREAK音符时显示常规判定损失和自定义BREAK输入
                if (_selectedNoteType != 'BREAK') ...[
                  // 自定义BREAK损失输入区域
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warningOrange(brightness),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.warningOrange(brightness)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('已打出的BREAK损失',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.warningOrange(brightness))),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _break50Controller,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: '50落数量',
                                  hintText: '0',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                  border: OutlineInputBorder(),
                                  errorText: _break50Count < 0 ||
                                          totalInputCount > totalBreak
                                      ? '无效'
                                      : null,
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _break50Count = int.tryParse(value) ?? 0;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _break100Controller,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: '100落数量',
                                  hintText: '0',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                  border: OutlineInputBorder(),
                                  errorText: _break100Count < 0 ||
                                          totalInputCount > totalBreak
                                      ? '无效'
                                      : null,
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _break100Count = int.tryParse(value) ?? 0;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _break80Controller,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: '80%GREAT数量',
                                  hintText: '0',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                  border: OutlineInputBorder(),
                                  errorText: _break80Count < 0 ||
                                          totalInputCount > totalBreak
                                      ? '无效'
                                      : null,
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _break80Count = int.tryParse(value) ?? 0;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _break60Controller,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: '60%GREAT数量',
                                  hintText: '0',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                  border: OutlineInputBorder(),
                                  errorText: _break60Count < 0 ||
                                          totalInputCount > totalBreak
                                      ? '无效'
                                      : null,
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _break60Count = int.tryParse(value) ?? 0;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _break50gController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: '50%GREAT数量',
                                  hintText: '0',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                  border: OutlineInputBorder(),
                                  errorText: _break50gCount < 0 ||
                                          totalInputCount > totalBreak
                                      ? '无效'
                                      : null,
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _break50gCount = int.tryParse(value) ?? 0;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _breakGoodController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'GOOD数量',
                                  hintText: '0',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                  border: OutlineInputBorder(),
                                  errorText: _breakGoodCount < 0 ||
                                          totalInputCount > totalBreak
                                      ? '无效'
                                      : null,
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _breakGoodCount = int.tryParse(value) ?? 0;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _breakMissController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'MISS数量',
                                  hintText: '0',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                  border: OutlineInputBorder(),
                                  errorText: _breakMissCount < 0 ||
                                          totalInputCount > totalBreak
                                      ? '无效'
                                      : null,
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _breakMissCount = int.tryParse(value) ?? 0;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        // 校验错误提示
                        if (breakInputError != null) ...[
                          const SizedBox(height: 4),
                          Text(breakInputError,
                              style:
                                  TextStyle(color: AppColors.errorRed(brightness), fontSize: 12)),
                        ],
                        // BREAK损失摘要
                        if (_break50Count > 0 ||
                            _break100Count > 0 ||
                            _break80Count > 0 ||
                            _break60Count > 0 ||
                            _break50gCount > 0 ||
                            _breakGoodCount > 0 ||
                            _breakMissCount > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text('BREAK总损失: ',
                                  style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                              Text('${breakInputLoss.toStringAsFixed(4)}%',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: breakInputLoss >= 2.0
                                          ? AppColors.errorRed(brightness)
                                          : AppColors.warningOrange(brightness))),
                            ],
                          ),
                          Row(
                            children: [
                              Text('剩余预算(SSS+): ',
                                  style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                              Text('${remainingBudget05.toStringAsFixed(4)}%',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: remainingBudget05 <= 0
                                          ? AppColors.errorRed(brightness)
                                          : AppColors.successGreen(brightness))),
                            ],
                          ),
                          Row(
                            children: [
                              Text('剩余预算(SSS): ',
                                  style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                              Text('${remainingBudget10.toStringAsFixed(4)}%',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: remainingBudget10 <= 0
                                          ? AppColors.errorRed(brightness)
                                          : AppColors.successGreen(brightness))),
                            ],
                          ),
                          Row(
                            children: [
                              Text('剩余预算(SS+): ',
                                  style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                              Text('${remainingBudget15.toStringAsFixed(4)}%',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: remainingBudget15 <= 0
                                          ? AppColors.errorRed(brightness)
                                          : AppColors.successGreen(brightness))),
                            ],
                          ),
                          Row(
                            children: [
                              Text('剩余预算(SS): ',
                                  style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                              Text('${remainingBudget20.toStringAsFixed(4)}%',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: remainingBudget20 <= 0
                                          ? AppColors.errorRed(brightness)
                                          : AppColors.successGreen(brightness))),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // 损失部分：三列两行布局
                  // 第一行：标题
                  Row(
                    children: [
                      Expanded(
                          child: Text('GREAT损失',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('GOOD损失',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('MISS损失',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              textAlign: TextAlign.center)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 第二行：值
                  Row(
                    children: [
                      Expanded(
                          child: Text('${greatLoss.toStringAsFixed(4)}%',
                              style: TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('${goodLoss.toStringAsFixed(4)}%',
                              style: TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('${missLoss.toStringAsFixed(4)}%',
                              style: TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 容错部分 SSS+：三列两行布局
                  // 第一行：标题
                  Row(
                    children: [
                      Expanded(
                          child: Text('SSS+容错(GREAT)',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('SSS+容错(GOOD)',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('SSS+容错(MISS)',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              textAlign: TextAlign.center)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 第二行：值
                  Row(
                    children: [
                      Expanded(
                          child: Text('${adjustedTolerance05Great}个',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: (_break50Count > 0 ||
                                              _break100Count > 0) &&
                                          adjustedTolerance05Great == 0
                                      ? AppColors.errorRed(brightness)
                                      : null),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('${adjustedTolerance05Good}个',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: (_break50Count > 0 ||
                                              _break100Count > 0) &&
                                          adjustedTolerance05Good == 0
                                      ? AppColors.errorRed(brightness)
                                      : null),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('${adjustedTolerance05Miss}个',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: (_break50Count > 0 ||
                                              _break100Count > 0) &&
                                          adjustedTolerance05Miss == 0
                                      ? AppColors.errorRed(brightness)
                                      : null),
                              textAlign: TextAlign.center)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 容错部分 SSS：三列两行布局
                  // 第一行：标题
                  Row(
                    children: [
                      Expanded(
                          child: Text('SSS容错(GREAT)',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('SSS容错(GOOD)',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('SSS容错(MISS)',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              textAlign: TextAlign.center)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 第二行：值
                  Row(
                    children: [
                      Expanded(
                          child: Text('${adjustedTolerance10Great}个',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: (_break50Count > 0 ||
                                              _break100Count > 0) &&
                                          adjustedTolerance10Great == 0
                                      ? AppColors.errorRed(brightness)
                                      : null),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('${adjustedTolerance10Good}个',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: (_break50Count > 0 ||
                                              _break100Count > 0) &&
                                          adjustedTolerance10Good == 0
                                      ? AppColors.errorRed(brightness)
                                      : null),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('${adjustedTolerance10Miss}个',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: (_break50Count > 0 ||
                                              _break100Count > 0) &&
                                          adjustedTolerance10Miss == 0
                                      ? AppColors.errorRed(brightness)
                                      : null),
                              textAlign: TextAlign.center)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 容错部分 SS+：三列两行布局
                  // 第一行：标题
                  Row(
                    children: [
                      Expanded(
                          child: Text('SS+容错(GREAT)',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('SS+容错(GOOD)',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('SS+容错(MISS)',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              textAlign: TextAlign.center)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 第二行：值
                  Row(
                    children: [
                      Expanded(
                          child: Text('${adjustedTolerance15Great}个',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: (_break50Count > 0 ||
                                              _break100Count > 0) &&
                                          adjustedTolerance15Great == 0
                                      ? AppColors.errorRed(brightness)
                                      : null),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('${adjustedTolerance15Good}个',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: (_break50Count > 0 ||
                                              _break100Count > 0) &&
                                          adjustedTolerance15Good == 0
                                      ? AppColors.errorRed(brightness)
                                      : null),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('${adjustedTolerance15Miss}个',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: (_break50Count > 0 ||
                                              _break100Count > 0) &&
                                          adjustedTolerance15Miss == 0
                                      ? AppColors.errorRed(brightness)
                                      : null),
                              textAlign: TextAlign.center)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 容错部分 SS：三列两行布局
                  // 第一行：标题
                  Row(
                    children: [
                      Expanded(
                          child: Text('SS容错(GREAT)',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('SS容错(GOOD)',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('SS容错(MISS)',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              textAlign: TextAlign.center)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 第二行：值
                  Row(
                    children: [
                      Expanded(
                          child: Text('${adjustedTolerance20Great}个',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: (_break50Count > 0 ||
                                              _break100Count > 0) &&
                                          adjustedTolerance20Great == 0
                                      ? AppColors.errorRed(brightness)
                                      : null),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('${adjustedTolerance20Good}个',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: (_break50Count > 0 ||
                                              _break100Count > 0) &&
                                          adjustedTolerance20Good == 0
                                      ? AppColors.errorRed(brightness)
                                      : null),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('${adjustedTolerance20Miss}个',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: (_break50Count > 0 ||
                                              _break100Count > 0) &&
                                          adjustedTolerance20Miss == 0
                                      ? AppColors.errorRed(brightness)
                                      : null),
                              textAlign: TextAlign.center)),
                    ],
                  ),
                ],

                // BREAK音符特殊判定损失（仅当选中BREAK时显示）
                if (_selectedNoteType == 'BREAK') ...[
                  // 损失部分
                  // 第一行：50落、100落
                  Row(
                    children: [
                      Expanded(
                          child: Text('50落损失',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('100落损失',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              textAlign: TextAlign.center)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 第二行：值
                  Row(
                    children: [
                      Expanded(
                          child: Text('${break50Loss.toStringAsFixed(4)}%',
                              style: TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('${break100Loss.toStringAsFixed(4)}%',
                              style: TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 第三行：三种GREAT
                  Row(
                    children: [
                      Expanded(
                          child: Text('80%GREAT损失',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('60%GREAT损失',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('50%GREAT损失',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              textAlign: TextAlign.center)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 第四行：值
                  Row(
                    children: [
                      Expanded(
                          child: Text('${break80Loss.toStringAsFixed(4)}%',
                              style: TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('${break60Loss.toStringAsFixed(4)}%',
                              style: TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('${break50gLoss.toStringAsFixed(4)}%',
                              style: TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 第五行：GOOD、MISS
                  Row(
                    children: [
                      Expanded(
                          child: Text('GOOD损失',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('MISS损失',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              textAlign: TextAlign.center)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 第六行：值
                  Row(
                    children: [
                      Expanded(
                          child: Text('${breakGoLoss.toStringAsFixed(4)}%',
                              style: TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('${missLoss.toStringAsFixed(4)}%',
                              style: TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 容错部分 -0.5%：三列两行布局（5项分2组）
                  // 第一行：标题
                  Row(
                    children: [
                      Expanded(
                          child: Text('-0.5%容错80%GREAT',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('-0.5%容错60%GREAT',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('-0.5%容错50%GREAT',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              textAlign: TextAlign.center)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 第二行：值
                  Row(
                    children: [
                      Expanded(
                          child: Text('${tolerance05Break80}个',
                              style: TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('${tolerance05Break60}个',
                              style: TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('${tolerance05Break50g}个',
                              style: TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 第三行：标题
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text('-0.5%容错',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                textAlign: TextAlign.center),
                            Text('GOOD',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text('-0.5%容错',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                textAlign: TextAlign.center),
                            Text('MISS',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 第四行：值
                  Row(
                    children: [
                      Expanded(
                          child: Text('${tolerance05BreakGo}个',
                              style: TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('${tolerance05Miss}个',
                              style: TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 容错部分 -1%：三列两行布局（5项分2组）
                  // 第一行：标题
                  Row(
                    children: [
                      Expanded(
                          child: Text('-1%容错80%GREAT',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('-1%容错60%GREAT',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('-1%容错50%GREAT',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              textAlign: TextAlign.center)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 第二行：值
                  Row(
                    children: [
                      Expanded(
                          child: Text('${tolerance10Break80}个',
                              style: TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('${tolerance10Break60}个',
                              style: TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('${tolerance10Break50g}个',
                              style: TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 第三行：标题
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text('-1%容错',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                textAlign: TextAlign.center),
                            Text('GOOD',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text('-1%容错',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                textAlign: TextAlign.center),
                            Text('MISS',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 第四行：值
                  Row(
                    children: [
                      Expanded(
                          child: Text('${tolerance10BreakGo}个',
                              style: TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center)),
                      Expanded(
                          child: Text('${tolerance10Miss}个',
                              style: TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  // 构建统计项
  Widget _buildStatItem(String label, String value, {Color? valueColor}) {
    // 获取当前难度的强调颜色
    final brightness = Theme.of(context).brightness;
    final accentColor = _getAccentColor(_currentDiffIndex, brightness);

    // 使用MediaQuery获取屏幕尺寸
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // 根据屏幕尺寸计算字体大小
    final fontSize = screenWidth * 0.04; // 字体大小为屏幕宽度的4%

    final textStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      color: valueColor ?? accentColor,
    );

    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 4),
          // 为超出容器宽度的文本添加水平滚动
          (label == '谱面谱师' || label == '曲师' || label == '类别')
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    // 计算文本宽度
                    final TextPainter textPainter = TextPainter(
                      text: TextSpan(text: value, style: textStyle),
                      maxLines: 1,
                      textDirection: TextDirection.ltr,
                    )..layout(minWidth: 0, maxWidth: double.infinity);

                    final textWidth = textPainter.width;
                    final containerWidth = constraints.maxWidth;

                    // 文本宽度未超过容器宽度时不需要滚动
                    final safeContainerWidth = containerWidth;

                    // 如果文本宽度小于安全容器宽度，不需要滚动，但仍然添加点击事件
                    if (textWidth <= safeContainerWidth) {
                      return GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text(label),
                                content: Text(value),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Clipboard.setData(
                                          ClipboardData(text: value));
                                      Navigator.of(context).pop();
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(content: Text('已复制到剪贴板')),
                                      );
                                    },
                                    child: Text('复制'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: Text('关闭'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        child: Text(value, style: textStyle),
                      );
                    }

                    // 否则使用Marquee组件，并添加点击事件
                    return GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: Text(label),
                              content: Text(value),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Clipboard.setData(
                                        ClipboardData(text: value));
                                    Navigator.of(context).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('已复制到剪贴板')),
                                    );
                                  },
                                  child: Text('复制'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: Text('关闭'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: SizedBox(
                        height: screenHeight * 0.03, // 容器高度为屏幕高度的3%
                        child: Marquee(
                          text: value,
                          style: textStyle,
                          scrollAxis: Axis.horizontal,
                          blankSpace: screenWidth * 0.05, // 空白空间为屏幕宽度的5%
                          velocity: screenWidth * 0.08, // 滚动速度为屏幕宽度的8%
                          pauseAfterRound: Duration(seconds: 3),
                        ),
                      ),
                    );
                  },
                )
              : GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text(label),
                          content: Text(value),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: value));
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('已复制到剪贴板')),
                                );
                              },
                              child: Text('复制'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: Text('关闭'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: textStyle,
                      maxLines: 1,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  // 构建音符项
  Widget _buildNoteItem(String type, String count) {
    // 获取当前难度的强调颜色
    final brightness = Theme.of(context).brightness;
    final accentColor = _getAccentColor(_currentDiffIndex, brightness);
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(6),
      child: Column(
        children: [
          Text(
            type,
            style: TextStyle(
              fontSize: screenWidth * 0.025,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            count,
            style: TextStyle(
              fontSize: screenWidth * 0.035,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }

  // 获取Break统计显示值，maidata解析失败时使用兜底方案
  String _getBreakCountDisplay(int index) {
    // 如果maidata解析成功，优先使用解析结果
    if (_maidataDecodedSuccessfully &&
        _maidataBreakCounts.containsKey(_currentDiffIndex)) {
      List<int> counts = _maidataBreakCounts[_currentDiffIndex]!;
      bool allZero = counts.every((count) => count == 0);
      // 只有当解析出的绝赞数量不全为0时，才使用maidata结果
      if (!allZero && index >= 0 && index < counts.length) {
        return counts[index].toString();
      }
    }

    // 兜底方案：解析失败或解析结果全为0时
    if (_songData != null) {
      String songType = _songData!['type'] ?? '';
      // ST谱面（type为SD）
      if (songType == 'SD') {
        // 获取当前难度的break音符数量
        int breakCount = 0;
        try {
          final currentChart = _songData!['charts'][_currentDiffIndex];
          if (currentChart != null && currentChart['notes'] != null) {
            List<dynamic> notes = currentChart['notes'];
            // ST谱面（SD类型）的notes数组只有4个元素，break在索引3
            // DX谱面的notes数组有5个元素，break在索引4
            int breakIndex = notes.length >= 5 ? 4 : 3;
            if (notes.length > breakIndex) {
              breakCount = notes[breakIndex] is int ? notes[breakIndex] : 0;
            }
          }
        } catch (e) {
          debugPrint('[SongInfoPage] Error getting break count: $e');
        }

        // 真绝赞TAP（index 0）设为总绝赞数量，其余为0
        if (index == 0) {
          return breakCount.toString();
        } else {
          return '0';
        }
      }
    }

    // 默认返回'-'
    return '-';
  }

  // 构建Break统计项
  Widget _buildBreakItem(String type, String count) {
    final screenWidth = MediaQuery.of(context).size.width;
    final brightness = Theme.of(context).brightness;

    Color textColor;
    switch (type) {
      case '真绝赞TAP':
        textColor = AppColors.errorRed(brightness);
        break;
      case '真绝赞HOLD':
        textColor = const Color(0xFFFF6B6B); // 浅红色
        break;
      case '保护套绝赞':
        textColor = AppColors.linkBlue(brightness);
        break;
      case '绝赞星星':
        textColor = Colors.yellow[700] ?? Colors.yellow;
        break;
      default:
        textColor = Theme.of(context).colorScheme.onSurface;
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(6),
      child: Column(
        children: [
          Text(
            type,
            style: TextStyle(
              fontSize: screenWidth * 0.022,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            count,
            style: TextStyle(
              fontSize: screenWidth * 0.035,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  // 请求存储权限
  Future<PermissionStatus> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      PermissionStatus storageStatus = await Permission.storage.status;
      PermissionStatus photosStatus = await Permission.photos.status;
      PermissionStatus videosStatus = await Permission.videos.status;

      if (storageStatus.isGranted ||
          photosStatus.isGranted ||
          videosStatus.isGranted) {
        return PermissionStatus.granted;
      }

      Map<Permission, PermissionStatus> statuses = await [
        Permission.storage,
        Permission.photos,
        Permission.videos,
      ].request();

      bool storageGranted = statuses[Permission.storage]?.isGranted ?? false;
      bool photosGranted = statuses[Permission.photos]?.isGranted ?? false;
      bool videosGranted = statuses[Permission.videos]?.isGranted ?? false;

      return (storageGranted || photosGranted || videosGranted)
          ? PermissionStatus.granted
          : PermissionStatus.denied;
    } else {
      PermissionStatus status = await Permission.storage.request();
      return status;
    }
  }

  /// 安全转换为 double，兼容 String/int/double/num
  double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  /// 安全转换为 int，兼容 String/int/double/num
  int _safeToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  // 导出成绩分享卡片
  Future<void> _shareScoreCard({
    required Map<String, dynamic> userRecord,
    required Map<String, dynamic> basicInfo,
    required List<dynamic> levels,
  }) async {
    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('正在生成分享卡片...'),
          ],
        ),
      ),
    );

    try {
      // 获取数据（安全类型转换，处理API可能返回String的情况）
      final songId = widget.songId;
      final songTitle = basicInfo['title'] ?? '';
      final artist = basicInfo['artist'] ?? '';
      final songType = _songData!['type'] ?? 'SD';
      final levelStr = (levels[_currentDiffIndex] ?? '').toString();
      final achievements = _safeToDouble(userRecord['achievements']);
      final ra = _safeToInt(userRecord['ra']);
      final dxScore = _safeToInt(userRecord['dxScore']);
      final maxDxScore = _calculateMaxDxScore(
        int.parse(songId),
        _currentDiffIndex,
      );
      final fc = userRecord['fc'] ?? '';
      final fs = userRecord['fs'] ?? '';
      final rawRate = userRecord['rate'] ?? '';
      final genre = basicInfo['genre'] ?? '';
      final bpm = _safeToInt(basicInfo['bpm']);
      final ds = _safeToDouble(
        _songData!['ds'] != null && (_songData!['ds'] as List).length > _currentDiffIndex
            ? (_songData!['ds'] as List)[_currentDiffIndex]
            : 0.0);

      // 调用导出服务
      final file = await SongScoreShareService.convertToImage(
        context,
        songId: songId,
        songTitle: songTitle,
        artist: artist,
        songType: songType,
        levelIndex: _currentDiffIndex,
        levelStr: levelStr,
        ds: ds,
        genre: genre,
        bpm: bpm,
        achievements: achievements,
        ra: ra,
        dxScore: dxScore,
        maxDxScore: maxDxScore,
        fc: fc,
        fs: fs,
        rawRate: rawRate,
      );

      // 关闭加载对话框
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // 显示结果
      if (file != null) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 8),
                Text('导出成功'),
              ],
            ),
            content: Text(
              '成绩分享卡片已保存到相册\n\n'
              '歌曲: $songTitle\n'
              '达成率: ${achievements.toStringAsFixed(4)}%\n'
              'Rating: $ra',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('确定'),
              ),
            ],
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.error, color: Colors.red, size: 28),
                SizedBox(width: 8),
                Text('导出失败'),
              ],
            ),
            content: Text('成绩分享卡片生成失败，请检查存储权限后重试。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('确定'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // 关闭加载对话框
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      debugPrint('分享卡片生成失败: $e');
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error, color: Colors.red, size: 28),
              SizedBox(width: 8),
              Text('导出失败'),
            ],
          ),
          content: Text('生成分享卡片时发生错误：$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('确定'),
            ),
          ],
        ),
      );
    }
  }

  // 保存封面到相册
  Future<void> _saveCoverToGallery(String songId, String title) async {
    try {
      // 请求存储权限
      PermissionStatus status = await _requestStoragePermission();
      if (!status.isGranted) {
        Fluttertoast.showToast(
          msg: '需要存储权限才能保存图片',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.orange,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        return;
      }

      // 获取封面图片数据
      ByteData? byteData;
      try {
        // 尝试从assets加载
        String coverPath = CoverUtil.buildCoverPath(songId);
        byteData = await rootBundle.load(coverPath);
      } catch (e) {
        // 尝试其他路径
        try {
          String coverPath = CoverUtil.getLocalCoverPath(songId);
          byteData = await rootBundle.load(coverPath);
        } catch (e2) {
          try {
            String coverPath = CoverUtil.getLocalCoverPathRetry1(songId);
            byteData = await rootBundle.load(coverPath);
          } catch (e3) {
            Fluttertoast.showToast(
              msg: '无法加载封面图片',
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              timeInSecForIosWeb: 1,
              backgroundColor: Colors.red,
              textColor: Colors.white,
              fontSize: 16.0,
            );
            return;
          }
        }
      }

      if (byteData == null) {
        Fluttertoast.showToast(
          msg: '无法加载封面图片',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        return;
      }

      Uint8List pngBytes = byteData.buffer.asUint8List();

      // 保存到相册
      Directory? directory;
      if (status.isGranted) {
        try {
          String picturesPath = '/storage/emulated/0/Pictures';
          directory = Directory(picturesPath);
          if (!directory.existsSync()) {
            directory.createSync(recursive: true);
          }
        } catch (e) {
          directory = null;
        }
      }

      if (directory == null) {
        directory = await getApplicationDocumentsDirectory();
      }

      String fileName =
          '${title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(pngBytes);

      // 通知系统相册
      if (Platform.isAndroid) {
        await MediaScanner.loadMedia(path: file.path);
      }

      Fluttertoast.showToast(
        msg: '曲绘已保存到相册',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.green,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: '保存失败: $e',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  // 构建占位符
  Widget _buildPlaceholder() {
    final brightness = Theme.of(context).brightness;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: AppColors.greyHint(brightness),
      ),
      child: Text(
        '-',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.greyHint(brightness),
        ),
      ),
    );
  }

  // 构建徽章
  Widget _buildBadge(String text) {
    Color bgColor;
    Color textColor;

    switch (text) {
      case 'app':
        bgColor = AppColors.achievementBackground('AP+');
        textColor = AppColors.achievementForeground('AP+');
        text = 'AP+';
        break;
      case 'ap':
        bgColor = AppColors.achievementBackground('AP');
        textColor = AppColors.achievementForeground('AP');
        break;
      case 'fcp':
        bgColor = AppColors.achievementBackground('FC+');
        textColor = AppColors.achievementForeground('FC+');
        text = 'FC+';
        break;
      case 'fc':
        bgColor = AppColors.achievementBackground('FC');
        textColor = AppColors.achievementForeground('FC');
        break;
      case 'fs':
        bgColor = AppColors.achievementBackground('FS');
        textColor = AppColors.achievementForeground('FS');
        text = 'FS';
        break;
      case 'fsp':
        bgColor = AppColors.achievementBackground('FS+');
        textColor = AppColors.achievementForeground('FS+');
        text = 'FS+';
        break;
      case 'sync':
        bgColor = AppColors.achievementBackground('SYNC');
        textColor = AppColors.achievementForeground('SYNC');
        break;
      case 'fsd':
        bgColor = AppColors.achievementBackground('FDX');
        textColor = AppColors.achievementForeground('FDX');
        text = 'FDX';
        break;
      case 'fsdp':
        bgColor = AppColors.achievementBackground('FDX+');
        textColor = AppColors.achievementForeground('FDX+');
        text = 'FDX+';
        break;
      default:
        bgColor = AppColors.achievementBackground('');
        textColor = AppColors.achievementForeground('');
    }

    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: bgColor,
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  // 获取难度标签
  String _getDiffLabel(int index) {
    // 检查难度数量
    int difficultyCount = 0;
    if (_songData != null && _songData!['level'] != null) {
      difficultyCount = _songData!['level'].length;
    }

    // 如果难度数量≤2个，显示"U\u00b7TA\u00b7GE​"
    if (difficultyCount <= 2) {
      return 'U\u00b7TA\u00b7GE​';
    }

    // 否则返回原来的标签
    switch (index) {
      case 0:
        return 'Basic';
      case 1:
        return 'Advan';
      case 2:
        return 'Expert';
      case 3:
        return 'Master';
      case 4:
        return 'Re:MAS';
      default:
        return '';
    }
  }

  // 计算maxScore
  int _calculateMaxScore(int songId, int levelIndex) {
    if (_songData == null) return 0;

    // 查找对应的charts
    List<dynamic> charts = _songData!['charts'];
    if (levelIndex < 0 || levelIndex >= charts.length) return 0;

    dynamic chart = charts[levelIndex];
    if (chart['notes'] == null) return 0;

    // 计算maxScore
    List<dynamic> notes = chart['notes'];
    int notesSum = notes.fold(0, (sum, note) => sum + (note as int));
    return notesSum * 3;
  }

  // 计算最大DX分
  // 当ds数组长度为2时，返回两个难度谱面DX分之和
  // 否则返回当前难度的最大分数
  int _calculateMaxDxScore(int songId, int levelIndex) {
    if (_songData == null) return 0;

    // 检查ds数组长度
    List<dynamic> ds = _songData!['ds'];
    if (ds.length == 2) {
      // 计算两个难度谱面的最大分数之和
      int maxScore1 = _calculateMaxScore(songId, 0);
      int maxScore2 = _calculateMaxScore(songId, 1);
      return maxScore1 + maxScore2;
    } else {
      // 返回当前难度的最大分数
      return _calculateMaxScore(songId, levelIndex);
    }
  }

  // 计算scoreRate
  double _calculateScoreRate(int songId, int levelIndex, int score) {
    int maxScore = _calculateMaxDxScore(songId, levelIndex);
    return maxScore > 0 ? score / maxScore : 0.0;
  }

  // 计算星星等级
  String _calculateStars(int songId, int levelIndex, int score) {
    double scoreRate = _calculateScoreRate(songId, levelIndex, score);

    // 确定星星等级
    if (scoreRate >= 0.99) {
      return '\u2726 6';
    } else if (scoreRate >= 0.98) {
      return '\u2726 5.5';
    } else if (scoreRate >= 0.97) {
      return '\u2726 5';
    } else if (scoreRate >= 0.95) {
      return '\u2726 4';
    } else if (scoreRate >= 0.93) {
      return '\u2726 3';
    } else if (scoreRate >= 0.90) {
      return '\u2726 2';
    } else if (scoreRate >= 0.85) {
      return '\u2726 1';
    } else {
      return '\u2726 0';
    }
  }

  // 计算星星等级的最低DX分和超出部分
  String _calculateStarsBonus(int songId, int levelIndex, int score) {
    int maxScore = _calculateMaxDxScore(songId, levelIndex);
    double scoreRate = score / maxScore;
    dynamic starLevel = 0;
    double minRate = 0.0;

    // 确定当前星星等级和对应的最低达成率
    if (scoreRate >= 0.99) {
      starLevel = 6;
      minRate = 0.99;
    } else if (scoreRate >= 0.98) {
      starLevel = 5.5;
      minRate = 0.98;
    } else if (scoreRate >= 0.97) {
      starLevel = 5;
      minRate = 0.97;
    } else if (scoreRate >= 0.95) {
      starLevel = 4;
      minRate = 0.95;
    } else if (scoreRate >= 0.93) {
      starLevel = 3;
      minRate = 0.93;
    } else if (scoreRate >= 0.90) {
      starLevel = 2;
      minRate = 0.90;
    } else if (scoreRate >= 0.85) {
      starLevel = 1;
      minRate = 0.85;
    } else {
      starLevel = 0;
      minRate = 0.85; // 0星时计算与1星的差距
    }

    // 计算最低DX分（向上取整）
    int minScore = (maxScore * minRate).ceil();
    // 计算超出部分或差距
    int difference = score - minScore;
    String symbol = difference >= 0 ? '+' : '';

    // 0星时显示1星的差距
    dynamic displayStarLevel = starLevel == 0 ? 1 : starLevel;

    return '\u2726 $displayStarLevel $symbol$difference';
  }

  // 计算到下一星级还需要多少分
  String _calculateNextStarDiff(int songId, int levelIndex, int score) {
    int maxScore = _calculateMaxDxScore(songId, levelIndex);
    double scoreRate = score / maxScore;

    // 定义各星级对应的最低达成率
    Map<dynamic, double> starRates = {
      0: 0.85, // 1星最低
      1: 0.85, // 1星
      2: 0.90, // 2星
      3: 0.93, // 3星
      4: 0.95, // 4星
      5: 0.97, // 5星
      5.5: 0.98, // 5.5星
      6: 0.99, // 6星
    };

    // 确定当前星星等级
    dynamic currentStar = 0;
    if (scoreRate >= 0.99) {
      currentStar = 6;
    } else if (scoreRate >= 0.98) {
      currentStar = 5.5;
    } else if (scoreRate >= 0.97) {
      currentStar = 5;
    } else if (scoreRate >= 0.95) {
      currentStar = 4;
    } else if (scoreRate >= 0.93) {
      currentStar = 3;
    } else if (scoreRate >= 0.90) {
      currentStar = 2;
    } else if (scoreRate >= 0.85) {
      currentStar = 1;
    } else {
      currentStar = 0;
    }

    // 确定下一星级
    List<dynamic> starOrder = [0, 1, 2, 3, 4, 5, 5.5, 6];
    int currentIndex = starOrder.indexOf(currentStar);

    // 如果已经是最高星级，显示已满
    if (currentIndex >= starOrder.length - 1) {
      return '\u2726 6 已满';
    }

    // 获取下一星级和对应的最低分数
    dynamic nextStar = starOrder[currentIndex + 1];
    double nextRate = starRates[nextStar]!;
    int nextMinScore = (maxScore * nextRate).ceil();

    // 计算还需要多少分
    int diff = nextMinScore - score;

    return '\u2726 $nextStar -$diff';
  }

  // 获取星星颜色
  Color _getStarsColor(String stars) {
    switch (stars) {
      case '\u2726 6':
      case '\u2726 5.5':
      case '\u2726 5':
        return Colors.yellow;
      case '\u2726 4':
      case '\u2726 3':
        return Colors.orange;
      case '\u2726 2':
      case '\u2726 1':
        return Colors.green.shade300;
      case '\u2726 0':
        return Colors.grey;
      default:
        return Colors.white;
    }
  }

  // 跳转到B站
  void _jumpToBilibili() async {
    if (_songData == null) return;

    final songTitle = _songData!['basic_info']['title'];
    final diffLabel = _getDiffLabel(_currentDiffIndex);
    final searchQuery = '$songTitle $diffLabel';

    // B站搜索链接
    final url = Uri.parse(
        'bilibili://search?keyword=${Uri.encodeComponent(searchQuery)}');

    // 尝试打开B站应用
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      // 如果无法打开B站应用，尝试在浏览器中打开
      final webUrl = Uri.parse(
          'https://search.bilibili.com/all?keyword=${Uri.encodeComponent(searchQuery)}');
      if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl);
      }
    }
  }

  // 播放音乐
  void _playMusic() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SongPlayPage(
          songId: widget.songId,
          songTitle: _songData!['basic_info']['title'],
          songType: _songData!['type'],
        ),
      ),
    );
  }

  // 查看相关收藏品
  void _viewRelatedCollectibles() {
    if (_songData == null) return;

    final songTitle = _songData!['basic_info']['title'];
    _fetchRelatedCollections(songTitle);
  }

  // 获取相关收藏品
  Future<void> _fetchRelatedCollections(String songTitle) async {
    try {
      // 显示加载对话框
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            child: Container(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('正在加载相关收藏品...'),
                ],
              ),
            ),
          );
        },
      );

      // 获取歌曲类型
      final songType = _songData!['type'] ?? '';

      // 使用SongInfoService获取相关收藏品
      final relatedCollections =
          await SongInfoService().fetchRelatedCollections(songTitle, songType);

      // 关闭加载对话框
      Navigator.of(context).pop();

      // 显示相关收藏品
      _showRelatedCollectionsDialog(songTitle, relatedCollections);
    } catch (e) {
      debugPrint('获取相关收藏品时出错: $e');
      // 关闭加载对话框
      Navigator.of(context).pop();
      // 显示错误信息
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('错误'),
            content: Text('获取相关收藏品时出错，请稍后重试'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('关闭'),
              ),
            ],
          );
        },
      );
    }
  }

  // 检查当前谱面的收藏夹状态
  // 检查当前谱面是否有笔记
  Future<void> _checkNoteStatus() async {
    try {
      final service = ChartNoteService();
      final note = await service.getNoteByChart(
        widget.songId,
        _currentDiffIndex,
      );
      if (mounted) {
        setState(() {
          _hasNote = note != null;
        });
      }
    } catch (e) {
      debugPrint('检查谱面笔记状态失败: $e');
    }
  }

  // 显示谱面笔记对话框
  Future<void> _showNoteDialog() async {
    final service = ChartNoteService();
    final existingNote = await service.getNoteByChart(
      widget.songId,
      _currentDiffIndex,
    );

    if (!mounted) return;

    final basicInfo = _songData!['basic_info'];
    final songTitle = basicInfo['title'] ?? '';
    final levels = _songData!['level'];
    final isUtage = widget.songId.length == 6;
    final rawLevel = (levels[_currentDiffIndex] ?? '').toString();
    const diffNames = ['BASIC', 'ADVANCED', 'EXPERT', 'MASTER', 'RE:MASTER'];
    final diffName = isUtage ? 'UTAGE' : diffNames[_currentDiffIndex.clamp(0, 4)];

    final TextEditingController controller = TextEditingController(
      text: existingNote?.content ?? '',
    );
    bool isEditing = existingNote != null;

    showDialog(
      context: context,
      builder: (ctx) {
        final brightness = Theme.of(ctx).brightness;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    isEditing ? Icons.note : Icons.note_add_outlined,
                    color: Colors.amber.shade700,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isEditing ? '谱面笔记' : '添加谱面笔记',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 300,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 谱面信息（与收藏页面一致）
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CoverUtil.buildCoverWidgetWithContext(context, widget.songId, 60),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 第一行：类型标签 + 歌名
                                Row(
                                  children: [
                                    _buildNoteTypeTag(),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text(songTitle,
                                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                        maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 4),
                                // 第二行：难度标签
                                _buildNoteDiffTag(diffName),
                                SizedBox(height: 4),
                                // 第三行：类别
                                Text(
                                  basicInfo['genre'] ?? '',
                                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      // 笔记内容（限制行数避免键盘弹出时溢出）
                      TextField(
                        controller: controller,
                        maxLines: 4,
                        maxLength: 2000,
                        decoration: InputDecoration(
                          hintText: '在这里写下你对这个谱面的笔记...\n例如：结尾的滑星要注意手顺',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.amber.shade700, width: 2)),
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      // 时间信息
                      if (existingNote != null) ...[
                        SizedBox(height: 8),
                        Text(
                          '创建于: ${_formatTimestamp(existingNote.createdAt)}'
                          '${existingNote.updatedAt != existingNote.createdAt ? '\n更新于: ${_formatTimestamp(existingNote.updatedAt)}' : ''}',
                          style: TextStyle(fontSize: 11, color: AppColors.greyHint(brightness))),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                // 删除按钮（仅在有笔记时显示）
                if (existingNote != null)
                  TextButton(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: ctx,
                        builder: (confirmCtx) => AlertDialog(
                          title: Text('确认删除'),
                          content: Text('确定要删除这个谱面的笔记吗？此操作不可撤销。'),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(confirmCtx).pop(false),
                              child: Text('取消'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(confirmCtx).pop(true),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.errorRed(brightness),
                              ),
                              child: Text('删除'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await service.deleteNote(
                          widget.songId,
                          _currentDiffIndex,
                        );
                        if (mounted) {
                          setState(() {
                            _hasNote = false;
                          });
                        }
                        Navigator.of(ctx).pop();
                      }
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: Text('删除'),
                  ),
                // 取消按钮
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('取消'),
                ),
                // 保存按钮
                ElevatedButton(
                  onPressed: (controller.text.trim().isNotEmpty)
                      ? () async {
                          final note = ChartNote(
                            songId: widget.songId,
                            levelIndex: _currentDiffIndex,
                            songTitle: songTitle,
                            level: '$diffName $rawLevel',
                            ds: _getCurrentDs(),
                            content: controller.text.trim(),
                          );
                          await service.saveNote(note);
                          if (mounted) {
                            setState(() {
                              _hasNote = true;
                            });
                          }
                          Navigator.of(ctx).pop();
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 获取当前难度的定数
  double _getCurrentDs() {
    if (_songData != null && _songData!['ds'] != null) {
      final dsList = _songData!['ds'] as List<dynamic>;
      if (_currentDiffIndex < dsList.length) {
        return (dsList[_currentDiffIndex] as num).toDouble();
      }
    }
    return 0.0;
  }

  // 格式化时间戳
  String _formatTimestamp(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // 笔记对话框：类型标签
  Widget _buildNoteTypeTag() {
    final isUtage = widget.songId.length == 6;
    if (isUtage) {
      return Text('UT', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.red));
    }
    final songType = _songData!['type'] ?? 'SD';
    if (songType == 'DX') {
      return Text('DX', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.warningOrange(Theme.of(context).brightness)));
    }
    return Text('ST', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.linkBlue(Theme.of(context).brightness)));
  }

  // 笔记对话框：难度标签
  Widget _buildNoteDiffTag(String diffLabel) {
    final isUtage = widget.songId.length == 6;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    Color bgColor, textColor;
    if (isUtage) {
      bgColor = isDark ? const Color(0xFF4A2020) : Colors.red.shade100;
      textColor = isDark ? const Color(0xFFEF5350) : Colors.red;
    } else {
      switch (_currentDiffIndex) {
        case 0: bgColor = isDark ? const Color(0xFF1B3D1B) : Colors.green.shade100; textColor = isDark ? const Color(0xFF66BB6A) : Colors.green.shade700; break;
        case 1: bgColor = isDark ? const Color(0xFF3D2E00) : Colors.orange.shade100; textColor = isDark ? const Color(0xFFFFB74D) : Colors.orange.shade700; break;
        case 2: bgColor = isDark ? const Color(0xFF4A2020) : Colors.red.shade100; textColor = isDark ? const Color(0xFFEF5350) : Colors.red; break;
        case 3: bgColor = isDark ? const Color(0xFF2A1A3D) : Colors.purple.shade100; textColor = isDark ? const Color(0xFFCE93D8) : Colors.purple.shade700; break;
        case 4: bgColor = isDark ? const Color(0xFF2A1A3D) : Colors.purple.shade100; textColor = isDark ? const Color(0xFFCE93D8) : Colors.purple.shade300; break;
        default: bgColor = isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade100; textColor = isDark ? Colors.grey.shade400 : Colors.grey.shade700;
      }
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(4)),
      child: Text(diffLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
    );
  }

  Future<void> _checkBookmarkStatus() async {
    final uniqueKey = '${widget.songId}_$_currentDiffIndex';
    final folderIds = await FavoriteFolderService().findFoldersContainingChart(uniqueKey);
    if (mounted) {
      setState(() {
        _isBookmarked = folderIds.isNotEmpty;
      });
    }
  }

  // 显示收藏夹选择对话框
  void _showBookmarkDialog() {
    if (_songData == null) return;

    final songTitle = _songData!['basic_info']['title'] ?? '';
    final levels = _songData!['level'] as List?;
    final levelStr = (levels != null && _currentDiffIndex < levels.length)
        ? levels[_currentDiffIndex].toString()
        : '';
    final dss = _songData!['ds'] as List?;
    final dsValue = (dss != null && _currentDiffIndex < dss.length)
        ? (dss[_currentDiffIndex] as num).toDouble()
        : 0.0;
    final songType = _songData!['type'] ?? '';

    final chart = FavoriteChart(
      songId: widget.songId,
      levelIndex: _currentDiffIndex,
      songTitle: songTitle,
      level: levelStr,
      ds: dsValue,
      songType: songType,
    );

    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return _BookmarkFolderSelectorDialog(chart: chart);
      },
    ).then((_) {
      // 对话框关闭后刷新状态
      _checkBookmarkStatus();
      if (mounted) setState(() {});
    });
  }

  // 显示相关收藏品对话框
  void _showRelatedCollectionsDialog(
      String songTitle, List<Map<String, dynamic>> relatedCollections) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final dialogWidth = screenWidth * 0.98; // 对话框宽度为屏幕宽度的98%

        return AlertDialog(
          title: Text('${songTitle}的相关收藏品'),
          contentPadding: relatedCollections.isEmpty
              ? EdgeInsets.all(20.0)
              : EdgeInsets.all(8.0), // 未找到时使用默认内边距
          content: Container(
            width: dialogWidth,
            child: SingleChildScrollView(
              child: relatedCollections.isEmpty
                  ? Container(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text('未找到与该歌曲相关的收藏品'),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: relatedCollections.map((item) {
                        return GestureDetector(
                          onTap: () {
                            // 跳转到收藏品详情页面
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CollectionInfoPage(
                                  collectionId:
                                      (item['collection'] as Collection).id,
                                  collectionType: item['type'],
                                ),
                              ),
                            );
                          },
                          child: Container(
                            margin: EdgeInsets.only(bottom: 12),
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[200]!),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getCollectionTypeColor(
                                            item['type']),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        _getCollectionTypeName(item['type']),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        item['name'],
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: Colors.grey[400],
                                    ),
                                  ],
                                ),
                                if (item['description'] != null &&
                                    item['description'].isNotEmpty)
                                  Padding(
                                    padding: EdgeInsets.only(top: 8),
                                    child: Text(
                                      item['description'],
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  // 获取收藏品类型名称
  String _getCollectionTypeName(String type) {
    switch (type) {
      case 'trophies':
        return '称号';
      case 'icons':
        return '头像';
      case 'plates':
        return '姓名框';
      case 'frames':
        return '背景';
      default:
        return '未知类型';
    }
  }

  // 获取收藏品类型颜色
  Color _getCollectionTypeColor(String type) {
    final brightness = Theme.of(context).brightness;
    switch (type) {
      case 'trophies':
        return AppColors.warningOrange(brightness);
      case 'icons':
        return AppColors.linkBlue(brightness);
      case 'plates':
        return AppColors.successGreen(brightness);
      case 'frames':
        return Colors.purple; // 语义色，保持不变
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  // 获取标签颜色
  Color _getTagColor(String group) => AppColors.tagGroupBackground(group);

  // 获取标签边框颜色
  Color _getTagBorderColor(String group) => AppColors.tagGroupBorder(group);

  // 获取标签文本颜色
  Color _getTagTextColor(String group) => AppColors.tagGroupText(group);

  // 构建评级分布
  Widget _buildRatingDistribution(dynamic currentDiffData) {
    if (currentDiffData == null) return Container();
    final brightness = Theme.of(context).brightness;

    List<num> dist = currentDiffData is DiffData
        ? currentDiffData.dist
        : currentDiffData['dist'];
    if (dist.isEmpty) return Container();

    // 评级标签
    List<String> ratingLabels = [
      'D',
      'C',
      'B',
      'BB',
      'BBB',
      'A',
      'AA',
      'AAA',
      'S',
      'S+',
      'SS',
      'SS+',
      'SSS',
      'SSS+'
    ];

    // 确保dist长度与标签长度匹配
    if (dist.length > ratingLabels.length) {
      dist = dist.sublist(0, ratingLabels.length);
    } else if (dist.length < ratingLabels.length) {
      while (dist.length < ratingLabels.length) {
        dist.add(0);
      }
    }

    // 计算总数量
    num total = dist.reduce((a, b) => a + b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题和展开收起按钮（整行可点击）
        InkWell(
          onTap: () {
            setState(() {
              _ratingDistributionExpanded = !_ratingDistributionExpanded;
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '评级分布(仅供参考)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _getAccentColor(_currentDiffIndex, brightness),
                  ),
                ),
                Icon(
                  _ratingDistributionExpanded
                      ? Icons.expand_less
                      : Icons.expand_more,
                  color: _getAccentColor(_currentDiffIndex, brightness),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // 分布图表（根据展开状态显示）
        if (_ratingDistributionExpanded) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                for (int i = ratingLabels.length - 1; i >= 0; i--)
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(ratingLabels[i],
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                              '${dist[i]} / ${total > 0 ? ((dist[i] / total) * 100).toStringAsFixed(2) : '0.00'}%'),
                        ],
                      ),
                      SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: dist[i] > 0 ? dist[i] / total : 0,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                            _getAccentColor(_currentDiffIndex, brightness)),
                        minHeight: 8,
                      ),
                      SizedBox(height: 12),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // 构建连击分布
  Widget _buildComboDistribution(dynamic currentDiffData) {
    if (currentDiffData == null) return Container();
    final brightness = Theme.of(context).brightness;

    List<num> fcDist = currentDiffData is DiffData
        ? currentDiffData.fcDist
        : currentDiffData['fc_dist'];
    if (fcDist.isEmpty) return Container();

    // 连击标签
    List<String> comboLabels = ['无', 'FC', 'FC+', 'AP', 'AP+'];

    // 确保fcDist长度与标签长度匹配
    if (fcDist.length > comboLabels.length) {
      fcDist = fcDist.sublist(0, comboLabels.length);
    } else if (fcDist.length < comboLabels.length) {
      while (fcDist.length < comboLabels.length) {
        fcDist.add(0);
      }
    }

    // 计算总数量
    num total = fcDist.reduce((a, b) => a + b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题和展开收起按钮（整行可点击）
        InkWell(
          onTap: () {
            setState(() {
              _comboDistributionExpanded = !_comboDistributionExpanded;
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '连击分布(仅供参考)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _getAccentColor(_currentDiffIndex, brightness),
                  ),
                ),
                Icon(
                  _comboDistributionExpanded
                      ? Icons.expand_less
                      : Icons.expand_more,
                  color: _getAccentColor(_currentDiffIndex, brightness),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // 分布图表（根据展开状态显示）
        if (_comboDistributionExpanded) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                for (int i = comboLabels.length - 1; i >= 0; i--)
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(comboLabels[i],
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                              '${fcDist[i].toInt()} / ${total > 0 ? ((fcDist[i] / total) * 100).toStringAsFixed(2) : '0.00'}%'),
                        ],
                      ),
                      SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: fcDist[i] > 0 ? fcDist[i] / total : 0,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                            _getAccentColor(_currentDiffIndex, brightness)),
                        minHeight: 8,
                      ),
                      SizedBox(height: 12),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // 构建别名区域
  Widget _buildAliasSection(String songTitle) {
    final brightness = Theme.of(context).brightness;
    // 从 SongAliasManager 获取别名数据
    final aliases = SongAliasManager.instance.aliases[songTitle] ?? [];

    if (aliases.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          '别名: 无',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        // 显示弹窗查看所有别名
        showDialog(
          context: context,
          builder: (BuildContext context) {
            final brightness = Theme.of(context).brightness;
            return AlertDialog(
              title: Text('${songTitle}的别名'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: aliases
                      .map((alias) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text('- $alias'),
                          ))
                      .toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('关闭'),
                ),
              ],
            );
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.tableBorder(brightness), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '查看别名 (${aliases.length})',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(width: 4),
            Icon(
              Icons.arrow_forward_ios,
              size: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  // 查看谱面代码（跳转到maidata页面）
  void _viewMaidata() {
    if (_songData == null) return;

    final songTitle = _songData!['basic_info']['title'];
    final genre = _songData!['basic_info']['genre'];
    final songType = _songData!['type'];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SongMaidataPage(
          songId: widget.songId,
          songTitle: songTitle,
          genre: genre,
          songType: songType,
          difficultyIndex: _currentDiffIndex,
        ),
      ),
    );
  }

  void _viewAchievementRanking() {
    if (_songData == null) return;

    final songTitle = _songData!['basic_info']['title'];
    final songType = _songData!['type'];
    final artist = _songData!['basic_info']['artist'] ?? '';
    final from = _songData!['basic_info']['from'] ?? '';

    double difficultyDs = 0.0;
    if (_songData!['ds'] != null && _songData!['ds'] is List) {
      List<dynamic> dsList = _songData!['ds'];
      if (_currentDiffIndex >= 0 && _currentDiffIndex < dsList.length) {
        difficultyDs = (dsList[_currentDiffIndex] as num).toDouble();
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SongRankingPage(
          songId: widget.songId,
          difficultyIndex: _currentDiffIndex,
          rankingType: RankingType.achievementRate,
          songTitle: songTitle,
          difficultyLabel: _getDiffLabel(_currentDiffIndex),
          songType: songType,
          artist: artist,
          genre: '',
          from: from,
          difficultyDs: difficultyDs,
        ),
      ),
    );
  }

  void _viewDxScoreRanking() {
    if (_songData == null) return;

    final songTitle = _songData!['basic_info']['title'];
    final songType = _songData!['type'];
    final artist = _songData!['basic_info']['artist'] ?? '';
    final from = _songData!['basic_info']['from'] ?? '';

    double difficultyDs = 0.0;
    if (_songData!['ds'] != null && _songData!['ds'] is List) {
      List<dynamic> dsList = _songData!['ds'];
      if (_currentDiffIndex >= 0 && _currentDiffIndex < dsList.length) {
        difficultyDs = (dsList[_currentDiffIndex] as num).toDouble();
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SongRankingPage(
          songId: widget.songId,
          difficultyIndex: _currentDiffIndex,
          rankingType: RankingType.dxScore,
          songTitle: songTitle,
          difficultyLabel: _getDiffLabel(_currentDiffIndex),
          songType: songType,
          artist: artist,
          genre: '',
          from: from,
          difficultyDs: difficultyDs,
        ),
      ),
    );
  }
}

/// 收藏夹选择对话框：选择要将当前谱面加入哪些收藏夹
class _BookmarkFolderSelectorDialog extends StatefulWidget {
  final FavoriteChart chart;

  const _BookmarkFolderSelectorDialog({required this.chart});

  @override
  State<_BookmarkFolderSelectorDialog> createState() =>
      _BookmarkFolderSelectorDialogState();
}

class _BookmarkFolderSelectorDialogState
    extends State<_BookmarkFolderSelectorDialog> {
  final FavoriteFolderService _service = FavoriteFolderService();
  List<FavoriteFolder> _folders = [];
  Set<String> _selectedFolderIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final folders = await _service.getFolders();
    // 查找当前谱面已在哪些收藏夹中
    final containingIds =
        await _service.findFoldersContainingChart(widget.chart.uniqueKey);
    if (mounted) {
      setState(() {
        _folders = List<FavoriteFolder>.from(folders);
        _selectedFolderIds = containingIds.toSet();
        _isLoading = false;
      });
    }
  }

  /// 创建新收藏夹
  Future<void> _createNewFolder() async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建收藏夹'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '请输入收藏夹名称',
            border: OutlineInputBorder(),
          ),
          inputFormatters: [LengthLimitingTextInputFormatter(30)],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final text = nameController.text.trim();
              if (text.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('名称不能为空')),
                );
                return;
              }
              Navigator.of(ctx).pop(text);
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
    // 延迟释放控制器，避免对话框撤销动画期间被使用
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameController.dispose();
    });
    if (name != null && name.isNotEmpty) {
      final newFolder = await _service.createFolder(name);
      // 自动将当前谱面加入新创建的收藏夹
      await _service.addChartToFolder(newFolder.id, widget.chart);
      if (mounted) {
        setState(() {
          _folders.add(newFolder);
          _selectedFolderIds.add(newFolder.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已创建收藏夹「$name」并将当前谱面加入')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final screenWidth = MediaQuery.of(context).size.width;
    final levelNames = ['BASIC', 'ADVANCED', 'EXPERT', 'MASTER', 'RE:MASTER', 'UTAGE'];
    final bool isUtage = widget.chart.songId.length == 6;
    final String levelName;
    if (isUtage) {
      levelName = 'UTAGE';
    } else {
      levelName = widget.chart.levelIndex >= 0 &&
              widget.chart.levelIndex < levelNames.length
          ? levelNames[widget.chart.levelIndex]
          : 'Lv.${widget.chart.levelIndex}';
    }

    return AlertDialog(
      scrollable: true,
      title: const Text('收藏到收藏夹'),
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: screenWidth * 0.9,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 当前谱面信息：左侧曲绘 + 右侧歌名+定数
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: brightness == Brightness.dark ? const Color(0xFF2A2010) : Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  // 左侧：曲绘
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CoverUtil.buildCoverWidget(widget.chart.songId, 60),
                  ),
                  const SizedBox(width: 12),
                  // 右侧：两行信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 第一行：类型标签 + 歌名
                        Row(
                          children: [
                            _buildTypeTag(widget.chart.songType, widget.chart.songId),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                widget.chart.songTitle,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // 第二行：难度标签 + 定数
                        Row(
                          children: [
                            _buildDifficultyTag(levelName, widget.chart.levelIndex, widget.chart.songId),
                            const SizedBox(width: 6),
                            Text(
                              'Lv.${widget.chart.ds.toStringAsFixed(1)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // 收藏夹列表
            _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  )
                : _folders.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(Icons.favorite_border,
                                size: 48, color: AppColors.greyHint(brightness)),
                            const SizedBox(height: 8),
                            Text(
                              '还没有收藏夹',
                              style: TextStyle(
                                  fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '请先创建收藏夹',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.greyHint(brightness)),
                            ),
                          ],
                        ),
                      )
                    : ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: screenWidth * 0.9,
                        ),
                        child: ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          children: _folders.map((folder) {
                            final isSelected =
                                _selectedFolderIds.contains(folder.id);
                            return CheckboxListTile(
                              title: Text(
                                folder.name,
                                style: const TextStyle(fontSize: 14),
                              ),
                              subtitle: Text(
                                '${folder.charts.length} 个谱面',
                                style: TextStyle(
                                    fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                              ),
                              value: isSelected,
                              dense: true,
                              onChanged: (checked) async {
                                if (checked == true) {
                                  final added = await _service.addChartToFolder(
                                      folder.id, widget.chart);
                                  if (added && mounted) {
                                    setState(() {
                                      _selectedFolderIds.add(folder.id);
                                    });
                                  }
                                } else {
                                  final removed =
                                      await _service.removeChartFromFolder(
                                          folder.id, widget.chart.uniqueKey);
                                  if (removed && mounted) {
                                    setState(() {
                                      _selectedFolderIds.remove(folder.id);
                                    });
                                  }
                                }
                              },
                            );
                          }).toList(),
                        ),
                      ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: const Text('新建收藏夹'),
          onPressed: _createNewFolder,
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('完成'),
        ),
      ],
    );
  }

  /// 构建类型标签（DX/ST/UT）
  Widget _buildTypeTag(String type, String songId) {
    final brightness = Theme.of(context).brightness;
    final isUtage = songId.length == 6;
    if (isUtage) {
      return const Text(
        'UT',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.red,
        ),
      );
    } else if (type == 'DX') {
      return Text(
        'DX',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.warningOrange(brightness),
        ),
      );
    } else {
      return Text(
        'ST',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.linkBlue(brightness),
        ),
      );
    }
  }

  /// 构建难度标签（Basic/Advanced/Expert/Master/Re:MASTER）
  Widget _buildDifficultyTag(String difficultyLabel, int levelIndex, String songId) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    Color bgColor;
    Color textColor;

    if (songId.length == 6) {
      bgColor = isDark ? const Color(0xFF4A2020) : Colors.red.shade100;
      textColor = isDark ? const Color(0xFFEF5350) : Colors.red;
    } else {
      switch (levelIndex) {
        case 0: // BASIC
          bgColor = isDark ? const Color(0xFF1B3D1B) : Colors.green.shade100;
          textColor = isDark ? const Color(0xFF66BB6A) : Colors.green.shade700;
          break;
        case 1: // ADVANCED
          bgColor = isDark ? const Color(0xFF3D2E00) : Colors.orange.shade100;
          textColor = isDark ? const Color(0xFFFFB74D) : Colors.orange.shade700;
          break;
        case 2: // EXPERT
          bgColor = isDark ? const Color(0xFF4A2020) : Colors.red.shade100;
          textColor = isDark ? const Color(0xFFEF5350) : Colors.red;
          break;
        case 3: // MASTER
          bgColor = isDark ? const Color(0xFF2A1A3D) : Colors.purple.shade100;
          textColor = isDark ? const Color(0xFFCE93D8) : Colors.purple.shade700;
          break;
        case 4: // RE:MASTER
          bgColor = isDark ? const Color(0xFF2A1A3D) : Colors.purple.shade100;
          textColor = isDark ? const Color(0xFFCE93D8) : Colors.purple.shade700;
          break;
        default:
          bgColor = isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade100;
          textColor = isDark ? Colors.grey.shade400 : Colors.grey.shade700;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        difficultyLabel.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}