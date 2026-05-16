import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/utils/CoverUtil.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:my_first_flutter_app/service/SongPlayService.dart';
import 'package:my_first_flutter_app/manager/MaimaiMusicDataManager.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

class SongPlayPage extends StatefulWidget {
  final String songId;
  final String songTitle;
  final String songType;

  const SongPlayPage({
    super.key,
    required this.songId,
    required this.songTitle,
    required this.songType,
  });

  @override
  State<SongPlayPage> createState() => _SongPlayPageState();
}

class _SongPlayPageState extends State<SongPlayPage> {
  // 播放状态
  bool _isPlaying = false;
  // 播放进度
  double _progress = 0.0;
  // 总时长（秒）
  int _totalDuration = 180; // 默认3分钟
  // 当前时长（秒）
  int _currentDuration = 0;
  // 落雪歌曲ID
  String? _luoXueSongId;
  // 加载状态
  bool _isLoading = true;
  // 播放器
  AudioPlayer? _audioPlayer;
  // 定时器
  Timer? _timer;
  // 音频URL
  String? _audioUrl;
  // 缓存文件路径
  String? _cachedFilePath;
  // 曲师信息
  String _artist = '';

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _loadLuoXueSongId();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer?.dispose();
    super.dispose();
  }

  // 加载落雪歌曲ID
  Future<void> _loadLuoXueSongId() async {
    try {
      // 加载曲师信息
      await _loadArtistInfo();

      final songPlayService = SongPlayService();
      _luoXueSongId = await songPlayService.findLuoXueSongId(
        widget.songTitle,
        widget.songType,
      );

      // 如果找到落雪歌曲ID，构建音频URL
      if (_luoXueSongId != null) {
        _audioUrl =
            'https://assets2.lxns.net/maimai/music/${_luoXueSongId}.mp3';
        // 检查是否有缓存文件
        _cachedFilePath = await _getCachedFilePath(_luoXueSongId!);
        // 尝试获取音频时长
        _loadAudioDuration();
      }
    } catch (e) {
      debugPrint('加载落雪歌曲ID失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 加载曲师信息
  Future<void> _loadArtistInfo() async {
    try {
      final musicManager = MaimaiMusicDataManager();
      if (await musicManager.hasCachedData()) {
        final songs = await musicManager.getCachedSongs();
        if (songs != null) {
          final song = songs.firstWhere(
            (s) => s.id == widget.songId,
          );
          setState(() {
            _artist = song.basicInfo.artist;
          });
        }
      }
    } catch (e) {
      debugPrint('加载曲师信息失败: $e');
    }
  }

  // 获取缓存文件路径
  Future<String> _getCachedFilePath(String songId) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/music_cache');
      if (!cacheDir.existsSync()) {
        cacheDir.createSync(recursive: true);
      }
      return '${cacheDir.path}/${songId}.mp3';
    } catch (e) {
      debugPrint('获取缓存目录失败: $e');
      return '';
    }
  }

  // 检查缓存是否存在
  Future<bool> _isCached(String songId) async {
    try {
      final filePath = await _getCachedFilePath(songId);
      return File(filePath).existsSync();
    } catch (e) {
      debugPrint('检查缓存失败: $e');
      return false;
    }
  }

  // 下载并缓存音频文件
  Future<void> _downloadAndCacheAudio() async {
    if (_luoXueSongId == null || _audioUrl == null) return;

    try {
      // 检查是否已缓存
      bool isCached = await _isCached(_luoXueSongId!);
      if (isCached) {
        debugPrint('音频已缓存，使用缓存文件');
        _cachedFilePath = await _getCachedFilePath(_luoXueSongId!);
        return;
      }

      debugPrint('开始下载并缓存音频: $_audioUrl');
      // 下载音频文件
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(Uri.parse(_audioUrl!));
      final response = await request.close();

      if (response.statusCode == HttpStatus.ok) {
        final filePath = await _getCachedFilePath(_luoXueSongId!);
        final file = File(filePath);
        final sink = file.openWrite();
        await sink.addStream(response);
        await sink.close();
        _cachedFilePath = filePath;
        debugPrint('音频缓存成功: $filePath');
      } else {
        debugPrint('下载音频失败: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('缓存音频失败: $e');
    }
  }

  // 加载音频时长
  Future<void> _loadAudioDuration() async {
    if (_audioUrl == null || _audioPlayer == null) return;

    try {
      // 检查并下载缓存
      await _downloadAndCacheAudio();

      // 确定使用的音频源
      String audioSource =
          _cachedFilePath != null && _cachedFilePath!.isNotEmpty
              ? _cachedFilePath!
              : _audioUrl!;

      debugPrint('开始加载音频时长: $audioSource');
      // 预加载音频以获取时长
      if (_cachedFilePath != null && _cachedFilePath!.isNotEmpty) {
        await _audioPlayer!.setSource(DeviceFileSource(_cachedFilePath!));
      } else {
        await _audioPlayer!.setSourceUrl(_audioUrl!);
      }

      // 主动获取时长
      Duration? duration = await _audioPlayer!.getDuration();
      if (duration != null) {
        debugPrint('主动获取到音频时长: ${duration.inSeconds}秒');
        setState(() {
          _totalDuration = duration.inSeconds;
        });
      }

      // 监听时长变化
      _audioPlayer!.onDurationChanged.listen((Duration duration) {
        debugPrint('获取到音频时长: ${duration.inSeconds}秒');
        setState(() {
          _totalDuration = duration.inSeconds;
        });
      });
      // 监听播放完成
      _audioPlayer!.onPlayerComplete.listen((_) {
        setState(() {
          _isPlaying = false;
          _currentDuration = _totalDuration;
          _progress = 1.0;
        });
        _timer?.cancel();
      });
      // 监听播放器状态变化
      _audioPlayer!.onPlayerStateChanged.listen((PlayerState state) {
        debugPrint('播放器状态变化: $state');
      });
    } catch (e) {
      debugPrint('加载音频时长失败: $e');
    }
  }

  // 播放/暂停音乐
  void _togglePlayPause() async {
    if (_audioUrl == null || _audioPlayer == null) return;

    try {
      if (_isPlaying) {
        // 暂停
        await _audioPlayer!.pause();
        _timer?.cancel();
      } else {
        // 播放
        if (_currentDuration == 0) {
          // 首次播放
          if (_cachedFilePath != null && _cachedFilePath!.isNotEmpty) {
            await _audioPlayer!.play(DeviceFileSource(_cachedFilePath!));
          } else {
            await _audioPlayer!.play(UrlSource(_audioUrl!));
          }
        } else {
          // 继续播放
          await _audioPlayer!.resume();
        }
        _startPlayback();
      }

      setState(() {
        _isPlaying = !_isPlaying;
      });
    } catch (e) {
      debugPrint('播放控制失败: $e');
    }
  }

  // 开始播放
  void _startPlayback() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      if (_audioPlayer != null) {
        _audioPlayer!.getCurrentPosition().then((Duration? position) {
          if (position != null) {
            setState(() {
              _currentDuration = position.inSeconds;
              _progress =
                  _totalDuration > 0 ? _currentDuration / _totalDuration : 0;
            });
          }
        });
        // 定期检查并更新时长
        _audioPlayer!.getDuration().then((Duration? duration) {
          if (duration != null && duration.inSeconds > 0) {
            setState(() {
              _totalDuration = duration.inSeconds;
            });
          }
        });
      }
    });
  }

  // 格式化时间
  String _formatDuration(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
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
                          '播放音乐',
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(borderRadiusSmall),
                    boxShadow: [defaultShadow],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 加载状态
                        if (_isLoading) ...[
                          Center(
                            child: CircularProgressIndicator(),
                          ),
                          SizedBox(height: 20),
                          Center(
                            child: Text('正在加载音乐...'),
                          ),
                        ] else if (_luoXueSongId == null) ...[
                          Center(
                            child: Icon(
                              Icons.music_off,
                              size: 100,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(height: 20),
                          Center(
                            child: Text('该歌曲暂无音乐资源'),
                          ),
                        ] else ...[
                          // 曲绘
                          Center(
                            child: Container(
                              width: MediaQuery.of(context).size.width * 0.7,
                              height: MediaQuery.of(context).size.width * 0.7,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: CoverUtil.buildCoverWidgetWithContext(
                                  context,
                                  widget.songId,
                                  300,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 32),

                          // 歌曲名
                          Center(
                            child: Text(
                              widget.songTitle,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: textPrimaryColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(height: 8),

                          // 曲师信息
                          Center(
                            child: Text(
                              _artist.isNotEmpty ? _artist : '未知曲师',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          SizedBox(height: 48),

                          // 进度条
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Column(
                              children: [
                                // 进度条
                                Slider(
                                  value: _progress,
                                  onChanged: (value) {
                                    setState(() {
                                      _progress = value;
                                      _currentDuration =
                                          (_totalDuration * value).round();
                                    });
                                  },
                                  onChangeEnd: (value) async {
                                    // 拖动结束后跳转到指定位置
                                    if (_audioPlayer != null) {
                                      int seekPosition =
                                          (_totalDuration * value).round() *
                                              1000; // 转换为毫秒
                                      await _audioPlayer!.seek(
                                          Duration(milliseconds: seekPosition));
                                    }
                                  },
                                  activeColor: Colors.blue,
                                  inactiveColor: Colors.grey,
                                ),
                                // 时间显示
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_formatDuration(_currentDuration)),
                                    Text(_formatDuration(_totalDuration)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 48),

                          // 播放控制按钮
                          Center(
                            child: ElevatedButton.icon(
                              onPressed: _togglePlayPause,
                              icon: Icon(
                                _isPlaying ? Icons.pause : Icons.play_arrow,
                                size: 32,
                              ),
                              label: Text(
                                _isPlaying ? '暂停' : '播放',
                                style: TextStyle(fontSize: 18),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 48,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                            ),
                          ),
                        ],
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
