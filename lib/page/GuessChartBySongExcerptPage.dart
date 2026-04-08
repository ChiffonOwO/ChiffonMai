import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:flutter/services.dart';
import 'package:my_first_flutter_app/entity/GuessSong.dart';
import 'package:my_first_flutter_app/entity/Song.dart';
import 'package:my_first_flutter_app/manager/SongAliasManager.dart';
import 'package:my_first_flutter_app/service/GuessChartBySongExcerptService.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:my_first_flutter_app/utils/LuoXueSongUtil.dart';
import 'package:my_first_flutter_app/utils/CoverUtil.dart';

class GuessChartBySongExcerptPage extends StatefulWidget {
  const GuessChartBySongExcerptPage({super.key});

  @override
  State<GuessChartBySongExcerptPage> createState() => _GuessChartBySongExcerptPageState();
}

class _GuessChartBySongExcerptPageState extends State<GuessChartBySongExcerptPage> {
  // 游戏状态
  bool _isGameStarted = false;
  Song? _targetSong;
  int? _luoXueSongId;
  List<GuessSong> _guessHistory = [];
  int _guessCount = 0;
  static const int _maxGuesses = 10;
  bool _isGameOver = false;
  bool _isWon = false;
  
  // 播放时长设置（默认5秒，最长30秒）
  int _playDuration = 5;
  int _currentPlayDuration = 5; // 当前游戏使用的播放时长
  bool _hasPlayed = false;
  int? _audioStartTime; // 存储音频片段的开始时间，每轮游戏只生成一次
  int _elapsedTime = 0; // 记录已经播放的时间
  
  // 音频播放控制
  bool _isPlaying = false;
  double _currentPosition = 0.0;
  double _totalDuration = 0.0;
  Timer? _playbackTimer;
  AudioPlayer? _audioPlayer;
  StreamSubscription<Duration>? _positionSubscription;
  
  // 排序状态
  bool _isAscending = true;

  // 搜索状态
  TextEditingController _searchController = TextEditingController();
  List<Song> _searchResults = [];
  bool _isSearching = false;
  Timer? _searchTimer;
  static const Duration _searchDelay = Duration(milliseconds: 800);
  bool _showSearchResults = false;


  // 歌曲别名管理器
  late SongAliasManager _songAliasManager;

  @override
  void initState() {
    super.initState();
    _songAliasManager = SongAliasManager.instance;
    _initGame();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchTimer?.cancel();
    _playbackTimer?.cancel();
    _positionSubscription?.cancel();
    _audioPlayer?.dispose();
    super.dispose();
  }

  // 初始化游戏
  Future<void> _initGame() async {
    await _songAliasManager.init();
    await _startNewGame();
  }

  // 开始新游戏
  Future<void> _startNewGame() async {
    // 取消播放定时器并停止播放器
    _playbackTimer?.cancel();
    _positionSubscription?.cancel();
    await _audioPlayer?.stop();
    await _audioPlayer?.dispose();
    _audioPlayer = null;
    
    setState(() {
      _isGameStarted = false;
      _isGameOver = false;
      _isWon = false;
      _guessHistory = [];
      _guessCount = 0;
      _searchController.clear();
      _searchResults = [];
      _showSearchResults = false;
      _hasPlayed = false;
      _isPlaying = false;
      _currentPosition = 0.0;
      _totalDuration = 0.0;
      _audioStartTime = null; // 重置音频开始时间
      _elapsedTime = 0; // 重置已播放时间
      _currentPlayDuration = _playDuration; // 应用新的播放时长设置
    });

    // 随机选择目标歌曲
    final result = await GuessChartBySongExcerptService().randomSelectSong();
    if (result != null && result.isNotEmpty) {
      final entry = result.entries.first;
      setState(() {
        _targetSong = entry.key;
        _luoXueSongId = entry.value['luoXueId'];
        _isGameStarted = true;
      });
    }
  }

  // 处理搜索输入
  void _handleSearchInput(String value) {
    // 取消之前的定时器
    _searchTimer?.cancel();

    if (value.isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }

    // 设置新的定时器
    _searchTimer = Timer(_searchDelay, () async {
      if (value.isEmpty) return;

      setState(() {
        _isSearching = true;
      });

      // 加载所有歌曲
      final allSongs = await GuessChartBySongExcerptService().loadAllSongs();
      if (allSongs != null) {
        // 搜索歌曲（支持原曲名和别名）
        final results = await _searchSongs(allSongs.keys.toList(), value);
        setState(() {
          _searchResults = results;
          _showSearchResults = results.isNotEmpty;
          _isSearching = false;
        });
      } else {
        setState(() {
          _isSearching = false;
        });
      }
    });
  }

  // 搜索歌曲（支持原曲名和别名）
  Future<List<Song>> _searchSongs(List<Song> songs, String query) async {
    List<Song> results = [];
    query = query.toLowerCase();

    // 搜索原曲名
    results.addAll(songs
        .where((song) => song.basicInfo.title.toLowerCase().contains(query)));

    // 搜索别名
    for (var song in songs) {
      if (!results.contains(song)) {
        // 检查别名
        final songId = song.id;
        final aliases = _songAliasManager.aliases[songId];
        if (aliases != null &&
            aliases.any((alias) => alias.toLowerCase().contains(query))) {
          results.add(song);
        }
      }
    }

    // 限制结果数量
    return results.take(20).toList();
  }

  // 处理猜测
  Future<void> _handleGuess(Song guessedSong) async {
    if (_isGameOver) return;

    // 检查是否已经猜过这首歌
    bool hasGuessed = _guessHistory.any((guess) => guess.songId == int.parse(guessedSong.id));
    if (hasGuessed) {
      // 显示提示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已经猜过这首歌了！'),
          duration: Duration(seconds: 2),
        ),
      );
      // 清空输入框
      _searchController.clear();
      _searchResults = [];
      _showSearchResults = false;
      return;
    }

    // 构建猜测实体
    var guessSong = await GuessChartBySongExcerptService.buildGuessSongEntity(guessedSong);
    // 计算猜测结果
    guessSong = await GuessChartBySongExcerptService.calculateGuessResult(
        guessSong, _targetSong!);

    // 更新猜测历史
    setState(() {
      _guessHistory.add(guessSong);
      _guessCount++;
      _searchController.clear();
      _searchResults = [];
      _showSearchResults = false;
    });

    // 检查游戏是否结束
    if (guessedSong.basicInfo.title == _targetSong!.basicInfo.title) {
      // 停止播放音乐
      _playbackTimer?.cancel();
      await _audioPlayer?.stop();
      await _audioPlayer?.dispose();
      _audioPlayer = null;
      
      setState(() {
        _isGameOver = true;
        _isWon = true;
        _isPlaying = false;
      });
    } else if (_guessCount >= _maxGuesses) {
      // 停止播放音乐
      _playbackTimer?.cancel();
      await _audioPlayer?.stop();
      await _audioPlayer?.dispose();
      _audioPlayer = null;
      
      setState(() {
        _isGameOver = true;
        _isWon = false;
        _isPlaying = false;
      });
    }
  }

  // 构建搜索结果项
  Widget _buildSearchResultItem(Song song) {
    // 获取别名
    final aliases = _songAliasManager.aliases[song.id] ?? [];
    String aliasText = aliases.isNotEmpty ? aliases.join('、') : '';

    return GestureDetector(
      onTap: () {
        _handleGuess(song);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 曲绘
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CoverUtil.buildCoverWidgetWithContext(context, song.id, 60),
              ),
            ),
            const SizedBox(width: 12),
            // 右侧信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题
                  Row(
                    children: [
                      Text(
                        song.type == 'SD' ? 'ST' : song.type,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: song.type == 'SD' ? Colors.blue : Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          song.basicInfo.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  // 作者
                  Text(
                    song.basicInfo.artist,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // 别名
                  if (aliasText.isNotEmpty)
                    Text(
                      aliasText,
                      style: TextStyle(fontSize: 14, color: Colors.blue),
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
  }

  // 构建猜测历史项
  Widget _buildGuessHistoryItem(
      GuessSong guessSong, int index, Song? guessedSong) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '猜测 #${index + 1}',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 12),

          // 第一行：曲绘，曲名
          Row(
            children: [
              // 曲绘
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CoverUtil.buildCoverWidgetWithContext(context, guessSong.songId.toString(), 60),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoItem('曲名', guessSong.title,
                    guessSong.titleBgColor ?? Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 第二行：类型，BPM，曲师
          Row(
            children: [
              Expanded(
                flex: 1,
                child: _buildInfoItem(
                    '类型', guessSong.type == 'SD' ? 'ST' : guessSong.type, guessSong.typeBgColor ?? Colors.grey),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: _buildInfoItem('BPM', guessSong.bpm.toString(),
                    guessSong.bpmBgColor ?? Colors.grey,
                    arrow: guessSong.bpmArrow),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: guessSong.artistBgColor ?? Colors.grey,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '曲师',
                        style:
                            const TextStyle(fontSize: 10, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        guessSong.artist,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 第三行：Master定数，Master谱师
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildInfoItem('Master定数', guessSong.masterDs,
                    guessSong.masterLevelBgColor ?? Colors.grey,
                    arrow: guessSong.masterLevelArrow),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: _buildInfoItem('Master谱师', guessSong.masterCharter,
                    guessSong.masterCharterBgColor ?? Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 第四行：ReMaster定数，ReMaster谱师
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildInfoItem(
                    'ReMaster定数',
                    guessSong.remasterDs.isNotEmpty
                        ? guessSong.remasterDs
                        : '-',
                    guessSong.remasterLevelBgColor ?? Colors.grey,
                    arrow: guessSong.remasterLevelArrow),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: guessSong.remasterCharterBgColor ?? Colors.grey,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ReMaster谱师',
                        style:
                            const TextStyle(fontSize: 10, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        guessSong.remasterCharter.isNotEmpty
                            ? guessSong.remasterCharter
                            : '-',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 第五行：流派，版本
          Row(
            children: [
              Expanded(
                child: _buildInfoItem('流派', guessSong.genre,
                    guessSong.genreBgColor ?? Colors.grey),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: guessSong.versionBgColor ?? Colors.grey,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '版本',
                        style:
                            const TextStyle(fontSize: 10, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _formatVersion(guessSong.version),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (guessSong.versionArrow != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Text(
                                guessSong.versionArrow!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: guessSong.versionArrow == '↑'
                                      ? Colors.blue
                                      : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // 构建信息项
  Widget _buildInfoItem(String label, String value, Color color,
      {String? arrow}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.white),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (arrow != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    arrow,
                    style: TextStyle(
                      fontSize: 12,
                      color: arrow == '↑' ? Colors.blue : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // 显示规则说明对话框
  void _showRulesDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('规则说明'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('绿色 - 该属性与你猜的完全一致。'),
                const SizedBox(height: 8),
                const Text('黄色 - 该属性与你猜的"接近"：'),
                const SizedBox(height: 4),
                const Text('灰色 - 该属性与你猜的"差距较大"：'),
                const SizedBox(height: 8),
                const Text('BPM 相差在 ±20 范围内；'),
                const Text('Master 难度或 Re:Master 难度相差在 ±0.4范围内；'),
                const Text('版本相差一个世代（例如 maimai ← maimai PLUS → maimai GreeN）。'),
                const SizedBox(height: 16),
                const Text('箭头：'),
                const SizedBox(height: 4),
                const Text('↑ - 目标值比你猜的更高'),
                const Text('↓ - 目标值比你猜的更低'),
                const SizedBox(height: 16),
                const Text('设计思路借鉴：'),
                GestureDetector(
                  onTap: () async {
                    final url = Uri.parse('https://maimai.yukineko2233.top/');
                    // 1. 检查是否能打开该链接
                    if (await canLaunchUrl(url)) {
                      // 2. 指定跳转到外部浏览器（关键：mode 参数）
                      await launchUrl(
                        url,
                        mode: LaunchMode.externalApplication, // 强制跳浏览器
                      );
                    } else {
                      // 提示用户无法打开
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('无法打开该链接')),
                      );
                    }
                  },
                  child: const Text(
                    'https://maimai.yukineko2233.top/',
                    style: TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  // 显示播放时长设置对话框
  void _showPlayDurationSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        int tempPlayDuration = _playDuration;
        return AlertDialog(
          title: const Text('播放时长设置'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '播放时长: $tempPlayDuration 秒 (下局游戏生效)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Slider(
                    value: tempPlayDuration.toDouble(),
                    min: 1,
                    max: 30,
                    divisions: 29,
                    onChanged: (value) {
                      setState(() {
                        tempPlayDuration = value.toInt();
                      });
                    },
                  ),
                  const Text('最长30秒'),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _playDuration = tempPlayDuration;
                });
                Navigator.of(context).pop();
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  // 格式化版本
  String _formatVersion(String version) {
    if (version == 'maimai') {
      return 'maimai';
    }
    if (version == 'maimai PLUS') {
      return 'maimai+';
    }
    if (version == 'maimai \u3067\u3089\u3063\u304f\u3059') {
      return 'DX 2020';
    }
    if (version == 'maimai \u3067\u3089\u3063\u304f\u3059 Splash') {
      return 'DX 2021';
    }
    if (version == 'maimai \u3067\u3089\u3063\u304f\u3059 UNiVERSE') {
      return 'DX 2022';
    }
    if (version == 'maimai \u3067\u3089\u3063\u304f\u3059 FESTiVAL') {
      return 'DX 2023';
    }
    if (version == 'maimai \u3067\u3089\u3063\u304f\u3059 BUDDiES') {
      return 'DX 2024';
    }
    if (version == 'maimai \u3067\u3089\u3063\u304f\u3059 PRiSM') {
      return 'DX 2025';
    }
    if (version.contains(' PLUS')) {
      version = version.replaceFirst(' PLUS', '+');
    }
    if (version.contains('maimai') && version != 'maimai') {
      version = version.replaceFirst('maimai ', '');
    }
    if (version.contains('\u3067\u3089\u3063\u304f\u3059')) {
      version = version.replaceFirst('\u3067\u3089\u3063\u304f\u3059 ', '');
    }
    return version;
  }

  // 播放歌曲片段
  Future<void> _playSongExcerpt() async {
    if (_luoXueSongId != null) {
      try {
        // 立即更新UI状态
        setState(() {
          _isPlaying = true;
          _totalDuration = _currentPlayDuration.toDouble();
          // 重置进度为0，确保每次播放都从开始计算
          _currentPosition = 0.0;
          _elapsedTime = 0;
        });
        
        // 取消之前的定时器和订阅
        _playbackTimer?.cancel();
        _positionSubscription?.cancel();
        
        // 获取音乐文件
        final luoXueSongUtil = LuoXueSongUtil();
        final file = await luoXueSongUtil.getMusicFile(_luoXueSongId!.toString());
        
        if (file != null) {
          // 获取歌曲时长
          final duration = await luoXueSongUtil.getSongDuration(_luoXueSongId!.toString());
          if (duration != null) {
            // 生成音频开始时间（每轮游戏只生成一次）
            if (_audioStartTime == null) {
              final maxStartTime = duration.inSeconds - _currentPlayDuration;
              if (maxStartTime > 0) {
                final random = Random();
                _audioStartTime = random.nextInt(maxStartTime);
              } else {
                _audioStartTime = 0;
              }
            }
          } else {
            if (_audioStartTime == null) {
              _audioStartTime = 0;
            }
          }
          
          // 重新初始化播放器
          if (_audioPlayer != null) {
            await _audioPlayer!.dispose();
          }
          _audioPlayer = AudioPlayer();
          
          // 设置文件路径
          await _audioPlayer!.setSource(DeviceFileSource(file.path));
          // 确保seek到正确位置
          await _audioPlayer!.seek(Duration(seconds: _audioStartTime!));
          // 开始播放
          await _audioPlayer!.play(DeviceFileSource(file.path));
          
          // 记录播放开始时间
          final playStartTime = DateTime.now();
          
          // 使用定时器来更新进度和控制播放时长
          _playbackTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
            if (_isPlaying) {
              // 计算已播放时间
              final elapsed = DateTime.now().difference(playStartTime).inMilliseconds / 1000;
              
              setState(() {
                _currentPosition = elapsed;
                _elapsedTime = elapsed.toInt();
              });
              
              // 检查是否达到播放时长
              if (elapsed >= _currentPlayDuration) {
                timer.cancel();
                _handlePlaybackComplete();
              }
            } else {
              timer.cancel();
            }
          });
          
          // 监听播放器位置变化，确保进度条与实际播放同步
          _positionSubscription = _audioPlayer!.onPositionChanged.listen((position) {
            if (_isPlaying) {
              // 计算相对于片段开始的位置
              final relativePosition = position.inMilliseconds / 1000 - _audioStartTime!;
              if (relativePosition >= 0) {
                setState(() {
                  _currentPosition = relativePosition;
                  _elapsedTime = relativePosition.toInt();
                });
                
                // 检查是否达到播放时长
                if (relativePosition >= _currentPlayDuration) {
                  _playbackTimer?.cancel();
                  _handlePlaybackComplete();
                }
              }
            }
          });
        } else {
          // 文件不存在，处理播放失败
          _handlePlaybackComplete();
          return;
        }
      } catch (e) {
        print('播放歌曲失败: $e');
        _handlePlaybackComplete();
      }
    }
  }
  
  // 处理播放完成
  void _handlePlaybackComplete() {
    // 取消定时器和订阅
    _playbackTimer?.cancel();
    _positionSubscription?.cancel();
    
    // 停止播放器
    if (_audioPlayer != null) {
      _audioPlayer!.stop();
    }
    
    // 更新状态
    setState(() {
      _isPlaying = false;
      _hasPlayed = true;
      _currentPosition = _totalDuration;
      _elapsedTime = _currentPlayDuration;
    });
  }
  
  // 暂停播放
  void _pausePlayback() {
    _playbackTimer?.cancel();
    _positionSubscription?.cancel();
    _audioPlayer?.pause();
    setState(() {
      _isPlaying = false;
    });
  }
  
  // 拖动进度条
  void _onSeek(double value) {
    setState(() {
      _currentPosition = value;
      _elapsedTime = value.toInt();
    });
    // 如果播放器存在，更新播放位置
    if (_audioPlayer != null) {
      _audioPlayer!.seek(Duration(seconds: _audioStartTime! + _elapsedTime));
    }
  }

  // 构建音乐播放器组件
  Widget _buildMusicPlayer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue[400]!, Colors.purple[500]!],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 播放进度条
          Slider(
            value: _currentPosition,
            min: 0.0,
            max: _totalDuration > 0 ? _totalDuration : _currentPlayDuration.toDouble(),
            onChanged: _onSeek,
            onChangeEnd: (value) {
              // 拖动结束后可以添加逻辑
            },
            activeColor: Colors.white,
            inactiveColor: Colors.white.withOpacity(0.5),
          ),
          
          // 时间显示
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_currentPosition.toStringAsFixed(1)}秒',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
              Text(
                '${_totalDuration > 0 ? _totalDuration : _currentPlayDuration}秒',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // 播放/暂停按钮
          ElevatedButton(
            onPressed: _isPlaying ? _pausePlayback : _playSongExcerpt,
            child: Text(_isPlaying ? '暂停' : (_hasPlayed ? '重新播放' : '播放歌曲片段')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 获取屏幕尺寸
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // 自定义常量
    final Color textPrimaryColor = Color.fromARGB(255, 84, 97, 97);
    final double borderRadiusSmall = 8.0;
    final BoxShadow defaultShadow = BoxShadow(
      color: Colors.black12,
      blurRadius: 5.0,
      offset: Offset(2.0, 2.0),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false, // 防止键盘弹出时挤压背景
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
                          '猜歌（音频片段）',
                          style: TextStyle(
                            color: textPrimaryColor,
                            fontSize: screenWidth * 0.06,
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
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(borderRadiusSmall),
                    boxShadow: [defaultShadow],
                  ),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _showSearchResults = false;
                      });
                    },
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // 边距
                        double padding = screenWidth * 0.04;

                        return Column(
                          children: [
                            // 主要内容
                            Expanded(
                              child: SingleChildScrollView(
                                padding: EdgeInsets.all(padding),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _isGameStarted
                                        ? Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              // 游戏状态
                                              Container(
                                                padding: const EdgeInsets.all(16),
                                                decoration: BoxDecoration(
                                              color: Colors.blue[50],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '猜测次数: $_guessCount/$_maxGuesses',
                                                  style: TextStyle(
                                                      fontSize:
                                                          screenWidth * 0.04),
                                                ),
                                                if (_isGameOver)
                                                  Text(
                                                    _isWon
                                                        ? '恭喜你猜对了！'
                                                        : '游戏结束，你没有猜对',
                                                    style: TextStyle(
                                                      fontSize:
                                                          screenWidth * 0.04,
                                                      fontWeight: FontWeight.bold,
                                                      color: _isWon
                                                          ? Colors.green
                                                          : Colors.red,
                                                    ),
                                                  ),
                                                if (_isGameOver && !_isWon)
                                                  Text(
                                                    '正确答案: ${_targetSong?.basicInfo.title}',
                                                    style: TextStyle(
                                                      fontSize:
                                                          screenWidth * 0.04,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 20),

                                          // 音乐播放器
                                          if (_targetSong != null)
                                            Center(
                                              child: Column(
                                                children: [
                                                  _buildMusicPlayer(),
                                                  const SizedBox(height: 16),
                                                ],
                                              ),
                                            ),
                                          
                                          // 搜索输入框和结果
                                          Container(
                                            child: Column(
                                              children: [
                                                Container(
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(8),
                                                    border: Border.all(
                                                        color: Colors.grey[300]!),
                                                  ),
                                                  child: TextField(
                                                    controller: _searchController,
                                                    onChanged: _handleSearchInput,
                                                    enabled: !_isGameOver,
                                                    decoration: const InputDecoration(
                                                      hintText: '输入歌曲名称或别名',
                                                      border: InputBorder.none,
                                                      contentPadding:
                                                          EdgeInsets.all(12),
                                                    ),
                                                  ),
                                                ),
                                                // 搜索结果
                                                if (_showSearchResults && _searchResults.isNotEmpty)
                                                  Container(
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: Colors.grey[300]!),
                                                      color: Colors.white,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black.withOpacity(0.2),
                                                          blurRadius: 10,
                                                          offset: Offset(0, 5),
                                                        ),
                                                      ],
                                                    ),
                                                    constraints: BoxConstraints(maxHeight: screenHeight * 0.3),
                                                    child: ListView.builder(
                                                      itemCount: _searchResults.length,
                                                      itemBuilder: (context, index) {
                                                        return _buildSearchResultItem(_searchResults[index]);
                                                      },
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),

                                          // 搜索中状态
                                          if (_isSearching)
                                            Container(
                                              margin:
                                                  const EdgeInsets.only(top: 8),
                                              padding: const EdgeInsets.all(16),
                                              child: const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                            ),

                                          // 按钮区域
                                          Container(
                                            margin:
                                                const EdgeInsets.only(top: 12),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                // 规则按钮
                                                IconButton(
                                                  icon: const Icon(
                                                      Icons.info_outline,
                                                      color: Color.fromARGB(
                                                          255, 84, 97, 97),
                                                      size: 24),
                                                  onPressed: _showRulesDialog,
                                                ),
                                                const SizedBox(width: 6),
                                                // 播放时长设置按钮
                                                IconButton(
                                                  icon: const Icon(
                                                      Icons.settings,
                                                      color: Color.fromARGB(
                                                          255, 84, 97, 97),
                                                      size: 24),
                                                  onPressed: _showPlayDurationSettingsDialog,
                                                ),
                                                const SizedBox(width: 6),
                                                // 刷新按钮
                                                IconButton(
                                                  icon: const Icon(Icons.refresh,
                                                      color: Color.fromARGB(
                                                          255, 84, 97, 97),
                                                      size: 24),
                                                  onPressed: _startNewGame,
                                                ),
                                                const SizedBox(width: 6),
                                                // 排序按钮
                                                IconButton(
                                                  icon: Icon(
                                                    _isAscending
                                                        ? Icons.sort_by_alpha
                                                        : Icons
                                                            .sort_by_alpha_outlined,
                                                    color: Color.fromARGB(
                                                        255, 84, 97, 97),
                                                    size: 24,
                                                  ),
                                                  onPressed: () {
                                                    setState(() {
                                                      _isAscending = !_isAscending;
                                                    });
                                                  },
                                                ),
                                                const SizedBox(width: 6),
                                                // 投降按钮
                                                if (!_isGameOver)
                                                  TextButton(
                                                    onPressed: () {
                                                      setState(() {
                                                        _isGameOver = true;
                                                        _isWon = false;
                                                      });
                                                    },
                                                    child: const Text('投降'),
                                                  ),
                                                const SizedBox(width: 6),
                                                // 开始新游戏按钮
                                                if (_isGameOver)
                                                  TextButton(
                                                    onPressed: _startNewGame,
                                                    child: const Text('新游戏'),
                                                  ),
                                                const SizedBox(width: 6),
                                              ],
                                            ),
                                          ),
                                          
                                          // 游戏结果显示
                                          if (_isGameOver && _targetSong != null)
                                            Container(
                                              margin: const EdgeInsets.only(top: 20),
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: Colors.green[50],
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    _isWon ? '恭喜你猜对了！' : '本局答案',
                                                    style: TextStyle(
                                                      fontSize: screenWidth * 0.04,
                                                      fontWeight: FontWeight.bold,
                                                      color: _isWon ? Colors.green : Colors.blue,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Row(
                                                    children: [
                                                      // 曲绘
                                                      Container(
                                                        width: 60,
                                                        height: 60,
                                                        decoration: BoxDecoration(
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: ClipRRect(
                                                          borderRadius: BorderRadius.circular(4),
                                                          child: CoverUtil.buildCoverWidgetWithContext(context, _targetSong!.id, 60),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            // 第一行：类型 曲名
                                                            Row(
                                                              children: [
                                                                Text(
                                                                  _targetSong!.type == 'SD' ? 'ST' : _targetSong!.type,
                                                                  style: TextStyle(
                                                                    fontSize: screenWidth * 0.035,
                                                                    fontWeight: FontWeight.bold,
                                                                    color: _targetSong!.type == 'SD' ? Colors.blue : Colors.orange,
                                                                  ),
                                                                ),
                                                                const SizedBox(width: 8),
                                                                Expanded(
                                                                  child: Text(
                                                                    _targetSong!.basicInfo.title,
                                                                    style: TextStyle(
                                                                      fontSize: screenWidth * 0.035,
                                                                      fontWeight: FontWeight.bold,
                                                                    ),
                                                                    overflow: TextOverflow.ellipsis,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            // 第二行：曲师 | 流派
                                                            Text(
                                                              '${_targetSong!.basicInfo.artist} | ${_targetSong!.basicInfo.genre}',
                                                              style: TextStyle(
                                                                fontSize: screenWidth * 0.03,
                                                                color: Colors.grey,
                                                              ),
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                            // 第三行：masterDs | remasterDs | version
                                                            Text(
                                                              '${_targetSong!.ds.length > 3 ? _targetSong!.ds[3].toString() : '-'} | ${_targetSong!.ds.length > 4 ? _targetSong!.ds[4].toString() : '-'} | ${_formatVersion(_targetSong!.basicInfo.from)}',
                                                              style: TextStyle(
                                                                fontSize: screenWidth * 0.03,
                                                                color: Colors.grey,
                                                              ),
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          const SizedBox(height: 20),

                                          // 猜测历史
                                          if (_guessHistory.isNotEmpty)
                                            Container(
                                              margin: const EdgeInsets.only(top: 20),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  Text(
                                                    '猜测历史',
                                                    style: TextStyle(
                                                      fontSize: screenWidth * 0.05,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Column(
                                                    children: (
                                                      _isAscending 
                                                        ? _guessHistory 
                                                        : [..._guessHistory].reversed.toList()
                                                    )
                                                        .asMap()
                                                        .entries
                                                        .map((entry) =>
                                                            _buildGuessHistoryItem(
                                                                entry.value,
                                                                _guessHistory.indexOf(entry.value),
                                                                null))
                                                        .toList(),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ])
                                        : const Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
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