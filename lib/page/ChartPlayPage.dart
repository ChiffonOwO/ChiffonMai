import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:simai_flutter/simai_flutter.dart';
import 'package:my_first_flutter_app/service/ChartPlaySettingsStore.dart';
import 'package:my_first_flutter_app/service/LoadingTipsStore.dart';
import 'package:my_first_flutter_app/service/SongPlayService.dart';
import 'package:my_first_flutter_app/api/ApiUrls.dart';
import 'package:my_first_flutter_app/utils/CoverUtil.dart';
import 'package:my_first_flutter_app/utils/PlayerThemeScope.dart';
import 'package:my_first_flutter_app/utils/RefreshRateUtil.dart';
import 'package:my_first_flutter_app/utils/ApiClient.dart';
import 'package:my_first_flutter_app/widgets/SmoothLinearProgressIndicator.dart';
import 'package:my_first_flutter_app/widgets/MarqueeText.dart';

class ChartPlayPage extends StatefulWidget {
  final String maidataContent;
  final String songTitle;
  final String songId;
  final String songType;
  final String? selectedInote;
  final String? bgImagePath;
  final String? audioFilePath;

  const ChartPlayPage({
    super.key,
    required this.maidataContent,
    required this.songTitle,
    required this.songId,
    required this.songType,
    this.selectedInote,
    this.bgImagePath,
    this.audioFilePath,
  });

  @override
  State<ChartPlayPage> createState() => _ChartPlayPageState();
}

class _ChartPlayPageState extends State<ChartPlayPage>
    with WidgetsBindingObserver {
  SimaiPlayerController? _controller;
  SimaiGameplayController? _gameplayController;
  SimaiVideoMetadata? _videoMetadata;
  SimaiVideoExportOptions _videoExportOptions = const SimaiVideoExportOptions();
  double _chartOffset = 0.0;
  Key _playerKey = UniqueKey();
  String? _audioUrl;
  List<String> _audioUrls = const <String>[];
  ImageProvider? _bgImageProvider;
  bool _ignoreAudioLookupResult = false;
  bool _isLeaving = false;
  bool _hasLoggedPlayerBuild = false;
  Timer? _loadingDiagnosticTimer;
  Timer? _loadingTipTimer;
  String _loadingStage = '正在准备谱面…';
  double? _loadingProgress;
  double _loadingSpeed = 0;
  String _loadingTip = '';

  /// 设置落盘防抖：侧边栏每拖一下滑块都会 notifyListeners，
  /// 不防抖会写爆 SharedPreferences。
  Timer? _settingsSaveDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 播放页存活期间强制深色主题：simai_flutter 的游玩/导出页 Scaffold 没有背景色，
    // 浅色主题下 push 转入时会闪一帧浅色。
    PlayerThemeScope.forceDarkTheme.value = true;
    // 谱面播放对帧率敏感：Flutter 引擎不会主动向系统要高刷，
    // 不投这一票就会一直在「几秒 120 → 掉 60」之间反复。
    RefreshRateUtil.requestMax();
    // 锁竖屏：见 AGENTS.md § 5.3。SimaiPlayerPage 在横屏会自动进入
    // SystemUiMode.immersiveSticky，那个模式会把屏幕边缘右滑全部吃掉用来
    // 显示系统栏，导致返回手势永远不会派发 back 事件给 App —— 锁竖屏让它
    // 永远走非全屏分支，返回手势才能用。
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    // 提前把上次的侧边栏设置读进内存，等控制器建好就能直接套用
    ChartPlaySettingsStore().load();
    // 短期心跳仅输出到调试日志：计时器也停住时，说明 Dart 主线程被阻塞，
    // 并非单纯某个资源 Future 没有完成。最多记录 20 秒，不持续轮询。
    final diagnosticWatch = Stopwatch()..start();
    _loadingDiagnosticTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      debugPrint(
        '[ChartPlay] heartbeat elapsed=${diagnosticWatch.elapsedMilliseconds}ms '
        'controller=${_controller != null}',
      );
      if (timer.tick >= 4) timer.cancel();
    });
    _loadingTip = LoadingTipsStore.instance.randomText();
    _loadingTipTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      final tip = LoadingTipsStore.instance.randomText();
      if (tip.isNotEmpty) setState(() => _loadingTip = tip);
    });
    unawaited(LoadingTipsStore.instance.ensureLoaded().then((_) {
      if (!mounted) return;
      final tip = LoadingTipsStore.instance.randomText();
      if (tip.isNotEmpty) setState(() => _loadingTip = tip);
    }));
    _loadChart();
  }

  void _setLoadingStatus(
    String stage, {
    double? progress,
    double speed = 0,
  }) {
    if (!mounted) return;
    setState(() {
      _loadingStage = stage;
      _loadingProgress = progress;
      _loadingSpeed = speed;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 从后台回来时渲染 Surface 可能已经重建，补投票一次
      RefreshRateUtil.requestMax();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // 切后台/被划掉前立刻把设置写下去，别等 dispose
      _flushSettingsNow();
    }
  }

  /// 建控制器：统一在这里套用上次保存的侧边栏设置并挂上变更监听。
  /// `_loadChart` 和 `_loadFallbackChart` 都走这里，避免两处漏改。
  SimaiPlayerController _createController(
    MaiChart chart,
    String? audioPath,
  ) {
    final controller = SimaiPlayerController(
      chart: chart,
      audioFilePath: audioPath,
      backgroundImageProvider: _bgImageProvider,
      initialChartTime: -_chartOffset,
    )..title = widget.songTitle;

    // 沿用上次的设置（控制器 setter 自带「值没变就 return」，不会有多余重建）
    ChartPlaySettingsStore().applyTo(controller);

    // 用户改设置 → 控制器的 setter 会 notifyListeners → 防抖落盘
    controller.addListener(_scheduleSettingsSave);
    return controller;
  }

  void _scheduleSettingsSave() {
    final controller = _controller;
    if (controller == null) return;

    // 同步抓取当前值并记进内存（防抖只推迟「写盘」，不推迟「记下来」），
    // 这样即使中途重建了控制器，也不会读到已经过期的旧设置。
    ChartPlaySettingsStore().remember(ChartPlaySettings.capture(controller));

    _settingsSaveDebounce?.cancel();
    _settingsSaveDebounce = Timer(const Duration(milliseconds: 600), () {
      ChartPlaySettingsStore().persist();
    });
  }

  /// 立刻落盘（取消未到期的防抖），用于退出页面/切后台。
  void _flushSettingsNow() {
    _settingsSaveDebounce?.cancel();
    _settingsSaveDebounce = null;
    ChartPlaySettingsStore().saveFrom(_controller);
  }

  /// 播放器仍在初始化时，重复点击左上角返回会让异步 GameWidget 与控制器
  /// 同时销毁。只接受第一次返回请求，避免重复 pop 叠加资源销毁。
  void _leavePlayerPage() {
    if (_isLeaving || !mounted) return;
    _isLeaving = true;
    unawaited(Navigator.of(context).maybePop<void>());
  }

  Future<void> _loadChart() async {
    debugPrint('[ChartPlay] load-start songId=${widget.songId}');
    _setLoadingStatus('正在读取谱面设置…');
    if (widget.maidataContent.isEmpty) {
      debugPrint('[ChartPlay] load-abort: maidata content is empty');
      return;
    }

    // 必须等设置读完再建控制器。
    // _createController 是同步读内存里的设置的，如果这里不等，
    // 一旦 SharedPreferences 读得比建控制器慢，就会拿默认值建控制器，
    // 退出时再把默认值写回去——用户的设置就被默默清掉了。
    await ChartPlaySettingsStore().load();
    if (!mounted || _isLeaving) return;
    debugPrint('[ChartPlay] settings-ready');

    // 音源是可选资源，不能让曲库接口或音源服务阻塞谱面播放器的创建。
    // 猜歌页面本身就是无声渲染；播放页在音源不可用时也应先显示谱面。
    _ignoreAudioLookupResult = false;
    _setLoadingStatus('正在查找音频文件…');
    try {
      await _loadAudioUrl().timeout(const Duration(seconds: 8));
    } on TimeoutException {
      debugPrint('加载落雪音源索引超时，改试 AWMC 音源');
      _audioUrl = ApiUrls.wmcAudioUrl(widget.songId);
      _audioUrls = <String>[_audioUrl!];
    } catch (e) {
      debugPrint('加载落雪音源索引失败，改试 AWMC 音源: $e');
      _audioUrl = ApiUrls.wmcAudioUrl(widget.songId);
      _audioUrls = <String>[_audioUrl!];
    }

    if (!mounted || _isLeaving) return;
    debugPrint('[ChartPlay] audio-lookup-ready hasUrl=${_audioUrl != null}');

    // 加载曲绘
    _setLoadingStatus('正在准备曲绘…');
    await _loadBackgroundImage();
    if (!mounted || _isLeaving) return;
    debugPrint(
      '[ChartPlay] background-ready hasProvider=${_bgImageProvider != null}',
    );

    try {
      _setLoadingStatus('正在解析谱面数据…');
      var simaiFile = SimaiFile(widget.maidataContent);

      String? chartText;
      String? resolvedInote;
      String? firstStr;

      // 如果用户选择了难度，直接使用该难度
      if (widget.selectedInote != null) {
        chartText = simaiFile.getValue("inote_${widget.selectedInote}");
        if (chartText != null) {
          resolvedInote = widget.selectedInote;
          debugPrint("Found chart for selected inote_${widget.selectedInote}");
        } else {
          debugPrint(
              "No chart found for selected inote_${widget.selectedInote}");
        }
      } else {
        // 否则按优先级查找
        List<String> inotePriorities = ['4', '3', '5', '2', '6', '7', '1'];
        for (var inoteNum in inotePriorities) {
          chartText = simaiFile.getValue("inote_$inoteNum");
          if (chartText != null) {
            resolvedInote = inoteNum;
            debugPrint("Found chart for inote_$inoteNum");
            break;
          }
        }
      }

      if (chartText == null) {
        debugPrint("No chart found in maidata");
        _loadFallbackChart();
        return;
      }

      firstStr = simaiFile.getValue("first");
      double offset = 0.0;
      if (firstStr != null) {
        offset = double.tryParse(firstStr) ?? 0.0;
      }

      final chart = SimaiConvert.deserialize(chartText);
      debugPrint(
        '[ChartPlay] chart-parsed notes=${chart.noteCollections.length} '
        'timings=${chart.timingChanges.length}',
      );

      // 确定音频来源：本地文件直接使用，远程URL需下载到临时文件
      String? audioPath;
      if (_audioUrls.isNotEmpty) {
        for (final url in _audioUrls) {
          if (url.startsWith('http://') || url.startsWith('https://')) {
            audioPath = await _downloadAudioToTemp(url);
          } else {
            audioPath = url;
          }
          if (audioPath != null) break;
        }
      }

      final difficulty = _difficultyForInote(resolvedInote);
      final videoMetadata = _buildVideoMetadata(simaiFile, difficulty);
      final videoOutputPath = await _buildVideoOutputPath();
      if (!mounted || _isLeaving) return;

      late final SimaiPlayerController controller;
      setState(() {
        _chartOffset = offset;
        _controller?.removeListener(_scheduleSettingsSave);
        _controller?.dispose();
        _gameplayController?.dispose();
        controller = _createController(chart, audioPath);
        _controller = controller;
        _gameplayController = SimaiGameplayController(
          chart: chart,
          audioFilePath: audioPath,
          backgroundImageProvider: _bgImageProvider,
          initialChartTime: -_chartOffset,
          title: widget.songTitle,
        );
        _videoMetadata = videoMetadata;
        _videoExportOptions = SimaiVideoExportOptions(
          outputPath: videoOutputPath,
        );
        _playerKey = UniqueKey();
      });
      debugPrint(
        '[ChartPlay] controller-published audioPath=${audioPath != null} '
        'background=${_bgImageProvider != null}',
      );
    } catch (e, stack) {
      debugPrint('[ChartPlay] chart-load-error: $e\n$stack');
      if (!mounted || _isLeaving) return;
      _loadFallbackChart();
    }
  }

  SimaiChartDifficulty? _difficultyForInote(String? inoteNum) {
    switch (inoteNum) {
      case '2':
        return SimaiChartDifficulty.basic;
      case '3':
        return SimaiChartDifficulty.advanced;
      case '4':
        return SimaiChartDifficulty.expert;
      case '5':
        return SimaiChartDifficulty.master;
      case '6':
        return SimaiChartDifficulty.reMaster;
      default:
        return null;
    }
  }

  SimaiVideoMetadata? _buildVideoMetadata(
    SimaiFile simaiFile,
    SimaiChartDifficulty? difficulty,
  ) {
    if (difficulty == null || _bgImageProvider == null) return null;
    try {
      return SimaiVideoMetadata.fromSimaiFile(
        simaiFile,
        coverImageProvider: _bgImageProvider!,
        difficulty: difficulty,
      );
    } catch (e) {
      debugPrint("Video export metadata unavailable: $e");
      return null;
    }
  }

  void _onVideoExported(SimaiVideoExportResult result) {
    final sizeMb = (result.fileSizeBytes / (1024 * 1024)).toStringAsFixed(1);
    debugPrint(
      'Video exported: ${result.width}x${result.height} '
      '(${result.duration.inSeconds}s, $sizeMb MB) -> ${result.path}',
    );
    Fluttertoast.showToast(
      msg: '视频已生成，请在导出页点击“保存到相册”：'
          '${result.width}×${result.height} · $sizeMb MB',
    );
  }

  // Android 11+ 的 Movies 是分区存储目录，第三方库直接在其中创建临时文件
  // 会被系统拒绝（EPERM）。让 simai_flutter 使用应用临时目录，再通过它的
  // “保存到相册”流程交给 MediaStore 写入公开媒体库。
  Future<String?> _buildVideoOutputPath() async {
    try {
      if (Platform.isAndroid) return null;

      final directory = await getApplicationDocumentsDirectory();
      final safeTitle = widget.songTitle.replaceAll(
        RegExp(r'[\\/:*?"<>|]'),
        '_',
      );
      return '${directory.path}/simai_${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.mp4';
    } catch (e) {
      debugPrint('构建视频输出路径失败: $e');
      return null;
    }
  }

  Future<void> _loadAudioUrl() async {
    // 优先使用本地音频文件
    if (widget.audioFilePath != null && widget.audioFilePath!.isNotEmpty) {
      _audioUrl = widget.audioFilePath;
      _audioUrls = <String>[widget.audioFilePath!];
      debugPrint("Using local audio file: $_audioUrl");
      return;
    }

    // 第一站：落雪音源（按 songId / title+type 找 luoXue song id）。
    try {
      final songPlayService = SongPlayService();
      String? luoXueSongId;

      // 宴会场歌曲（6 位数 songId）：曲绘实际用的是 cover id，
      // 落雪那边的歌曲 ID 与曲绘 ID 一致，所以用 cover id 就能找到对应的落雪歌曲。
      // 例如: songId=100018 -> coverId=18 -> 落雪歌曲 id=18
      if (widget.songId.length == 6) {
        final coverId = CoverUtil.extractCoverId(widget.songId);
        if (coverId.isNotEmpty && coverId != '0') {
          luoXueSongId =
              await songPlayService.findLuoXueSongIdByCoverId(coverId);
        }
      }

      // 兜底：通过 title 和 type 查找（非宴会场歌曲，或宴会场 cover id 查不到时）
      luoXueSongId ??= await songPlayService.findLuoXueSongId(
        widget.songTitle,
        widget.songType,
      );

      if (luoXueSongId != null) {
        if (_ignoreAudioLookupResult) return;
        _audioUrl = 'https://assets2.lxns.net/maimai/music/$luoXueSongId.mp3';
        _audioUrls = <String>[
          _audioUrl!,
          ApiUrls.wmcAudioUrl(widget.songId),
        ];
        debugPrint("Loaded audio URL: $_audioUrl");
        return;
      }
      debugPrint("No luoXue audio found for song: ${widget.songTitle}");
    } catch (e) {
      debugPrint("Error loading audio URL from luoXue: $e");
    }

    // 落雪索引没有这首歌时，尝试 AWMC/WMC 的同 songId 音源。
    if (!_ignoreAudioLookupResult) {
      _audioUrl = ApiUrls.wmcAudioUrl(widget.songId);
      _audioUrls = <String>[_audioUrl!];
      debugPrint("Loaded AWMC fallback audio URL: $_audioUrl");
      return;
    }
    // 找不到可用音源时保持无声播放。
    debugPrint("No audio found for song: ${widget.songTitle}");
  }

  Future<void> _loadBackgroundImage() async {
    // 优先使用本地背景图片
    if (widget.bgImagePath != null && widget.bgImagePath!.isNotEmpty) {
      _bgImageProvider = FileImage(File(widget.bgImagePath!));
      debugPrint("Using local background image: ${widget.bgImagePath}");
      return;
    }

    try {
      _bgImageProvider = await CoverUtil.resolveCoverProvider(widget.songId);
      debugPrint(
          "Resolved background image provider for song ${widget.songId}");
    } catch (e) {
      debugPrint("Error loading background image: $e");
      _bgImageProvider = null;
    }
  }

  Future<String?> _downloadAudioToTemp(String url) async {
    _setLoadingStatus('正在下载音频文件…');
    try {
      final response = await ApiClient.getStream(Uri.parse(url));
      if (response.statusCode != 200) {
        debugPrint("Failed to download audio: ${response.statusCode}");
        await response.stream.drain<void>();
        return null;
      }
      final contentType = response.headers['content-type']?.toLowerCase();
      if (contentType != null &&
          (contentType.contains('text/html') ||
              contentType.contains('application/json'))) {
        debugPrint('音源响应不是音频文件: $contentType');
        await response.stream.drain<void>();
        return null;
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/chart_audio_${widget.songId}.mp3');
      final part = File('${file.path}.part');
      if (await part.exists()) await part.delete();
      final sink = part.openWrite();
      final compressed = response.headers['content-encoding'];
      final total = compressed == null || compressed == 'identity'
          ? response.contentLength
          : null;
      var received = 0;
      final prefix = <int>[];
      var validated = false;
      final stopwatch = Stopwatch()..start();
      try {
        await for (final chunk
            in response.stream.timeout(const Duration(seconds: 30))) {
          received += chunk.length;
          if (!validated) {
            prefix.addAll(chunk);
            if (prefix.length >= 3) {
              final isId3 = prefix[0] == 0x49 &&
                  prefix[1] == 0x44 &&
                  prefix[2] == 0x33;
              final isFrame = prefix[0] == 0xff &&
                  (prefix[1] & 0xe0) == 0xe0;
              if (!isId3 && !isFrame) {
                throw const FormatException('音源响应不是有效的 MP3');
              }
              validated = true;
              sink.add(prefix);
            }
          } else {
            sink.add(chunk);
          }
          final elapsed = stopwatch.elapsedMicroseconds / 1000000;
          _setLoadingStatus(
            '正在下载音频文件…',
            progress: total != null && total > 0
                ? (received / total).clamp(0.0, 1.0)
                : null,
            speed: elapsed > 0 ? received / elapsed : 0,
          );
        }
        await sink.close();
      } catch (_) {
        await sink.close();
        rethrow;
      }
      if (!validated || received < 1024) {
        debugPrint('音源文件过小或不完整: $received bytes');
        await part.delete();
        return null;
      }
      if (await file.exists()) await file.delete();
      await part.rename(file.path);
      _setLoadingStatus('音频文件准备完成', progress: 1);
      debugPrint("Downloaded audio to: ${file.path}");
      return file.path;
    } catch (e) {
      debugPrint("Error downloading audio: $e");
      return null;
    }
  }

  Future<void> _loadFallbackChart() async {
    if (!mounted || _isLeaving) return;
    const sampleChart = """
&inote_1=(140){4}
1,2,3,4,5,6,7,8,
1h[4:1],2h[4:1],3h[4:1],4h[4:1],
1b,2b,3b,4b,
C,A1,A2,A3,A4,A5,A6,A7,A8,
B1,B2,B3,B4,B5,B6,B7,B8,
1-4[4:1],2-5[4:1],
E
""";

    var simaiFile = SimaiFile(sampleChart);
    var chartText = simaiFile.getValue("inote_1");
    if (chartText != null) {
      final chart = SimaiConvert.deserialize(chartText);

      // 确定音频来源
      String? audioPath;
      for (final url in _audioUrls) {
        if (url.startsWith('http://') || url.startsWith('https://')) {
          audioPath = await _downloadAudioToTemp(url);
        } else {
          audioPath = url;
        }
        if (audioPath != null) break;
      }

      late final SimaiPlayerController controller;
      if (!mounted || _isLeaving) return;
      setState(() {
        _chartOffset = 0.0;
        _controller?.removeListener(_scheduleSettingsSave);
        _controller?.dispose();
        _gameplayController?.dispose();
        controller = _createController(chart, audioPath);
        _controller = controller;
        _gameplayController = SimaiGameplayController(
          chart: chart,
          audioFilePath: audioPath,
          backgroundImageProvider: _bgImageProvider,
          initialChartTime: -_chartOffset,
          title: widget.songTitle,
        );
        _videoMetadata = null;
        _playerKey = UniqueKey();
      });
      debugPrint('[ChartPlay] fallback-controller-published');
    }
  }

  @override
  void dispose() {
    _isLeaving = true;
    _loadingDiagnosticTimer?.cancel();
    _loadingTipTimer?.cancel();
    debugPrint('[ChartPlay] dispose');
    WidgetsBinding.instance.removeObserver(this);
    // 离开播放页恢复 App 原本的主题
    PlayerThemeScope.forceDarkTheme.value = false;
    // 离开播放页就把刷新率交还系统，避免整个 App 一直顶着高刷耗电
    RefreshRateUtil.restore();
    // 解除 initState 里的竖屏锁，让其它页面（视频播放等）能正常横屏
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // 先把设置读出来写下去，再拆控制器——saveFrom 需要读控制器的当前值。
    // 这里不能 await，但 saveFrom 是同步跑到第一个 await 才挂起的，
    // capture 一定发生在 dispose 之前。
    _settingsSaveDebounce?.cancel();
    _settingsSaveDebounce = null;
    ChartPlaySettingsStore().saveFrom(_controller);
    _controller?.removeListener(_scheduleSettingsSave);
    _gameplayController?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller != null && !_hasLoggedPlayerBuild) {
      _hasLoggedPlayerBuild = true;
      debugPrint('[ChartPlay] SimaiPlayerPage-build');
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: _controller == null
          ? _buildLoadingView()
          : SimaiPlayerPage(
              key: _playerKey,
              controller: _controller!,
              gameplayController: _gameplayController,
              videoExportMetadata: _videoMetadata,
              videoExportOptions: _videoExportOptions,
              onVideoExported: _onVideoExported,
              onBack: _leavePlayerPage,
              disposeController: false,
            ),
    );
  }

  Widget _buildLoadingView() {
    final scheme = Theme.of(context).colorScheme;
    final speedText = _loadingSpeed > 0
        ? '${(_loadingSpeed / 1024).toStringAsFixed(0)} KB/s'
        : '';
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.music_note_rounded,
                  color: Colors.white70, size: 42),
              const SizedBox(height: 18),
              Text(
                _loadingStage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              const SizedBox(height: 12),
              SmoothLinearProgressIndicator(
                value: _loadingProgress,
                color: scheme.primary,
                backgroundColor: Colors.white24,
                minHeight: 5,
              ),
              if (speedText.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(speedText,
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
              if (_loadingTip.isNotEmpty) ...[
                const SizedBox(height: 22),
                SizedBox(
                  height: 20,
                  child: MarqueeText(
                    key: ValueKey(_loadingTip),
                    text: _loadingTip,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      height: 1.5,
                    ),
                    gap: 28,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
