import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:media_scanner/media_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:simai_flutter/simai_flutter.dart';
import 'package:my_first_flutter_app/service/SongPlayService.dart';
import 'package:my_first_flutter_app/utils/CoverUtil.dart';
import 'package:my_first_flutter_app/utils/ApiClient.dart';

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

class _ChartPlayPageState extends State<ChartPlayPage> {
  SimaiPlayerController? _controller;
  SimaiGameplayController? _gameplayController;
  SimaiVideoMetadata? _videoMetadata;
  SimaiVideoExportOptions _videoExportOptions = const SimaiVideoExportOptions();
  double _chartOffset = 0.0;
  Key _playerKey = UniqueKey();
  String? _audioUrl;
  ImageProvider? _bgImageProvider;

  @override
  void initState() {
    super.initState();
    _loadChart();
  }

  Future<void> _loadChart() async {
    if (widget.maidataContent.isEmpty) {
      debugPrint("Error: maidata content is empty");
      return;
    }

    // 加载音源URL
    await _loadAudioUrl();
    
    // 加载曲绘
    await _loadBackgroundImage();

    try {
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
          debugPrint("No chart found for selected inote_${widget.selectedInote}");
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

      // 确定音频来源：本地文件直接使用，远程URL需下载到临时文件
      String? audioPath;
      if (_audioUrl != null) {
        if (_audioUrl!.startsWith('http://') || _audioUrl!.startsWith('https://')) {
          audioPath = await _downloadAudioToTemp(_audioUrl!);
        } else {
          audioPath = _audioUrl;
        }
      }

      final difficulty = _difficultyForInote(resolvedInote);
      final videoMetadata = _buildVideoMetadata(simaiFile, difficulty);
      final videoOutputPath = await _buildVideoOutputPath();

      setState(() {
        _chartOffset = offset;
        _controller?.dispose();
        _gameplayController?.dispose();
        _controller = SimaiPlayerController(
          chart: chart,
          audioFilePath: audioPath,
          backgroundImageProvider: _bgImageProvider,
          initialChartTime: -_chartOffset,
        )..title = widget.songTitle;
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
    } catch (e) {
      debugPrint("Error loading chart: $e");
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
      msg: '视频已保存到相册：${result.width}×${result.height} · $sizeMb MB',
    );
    // 视频已直接写入相册目录，通知系统刷新相册即可
    if (Platform.isAndroid) {
      MediaScanner.loadMedia(path: result.path);
    }
  }

  // 构建视频导出到系统相册的输出路径（参考图片导出到相册的路径构建方式）
  Future<String?> _buildVideoOutputPath() async {
    try {
      Directory? directory;
      if (Platform.isAndroid) {
        const moviesPath = '/storage/emulated/0/Movies';
        directory = Directory(moviesPath);
        if (!directory.existsSync()) {
          directory.createSync(recursive: true);
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }
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
      debugPrint("Using local audio file: $_audioUrl");
      return;
    }

    try {
      final songPlayService = SongPlayService();
      final luoXueSongId = await songPlayService.findLuoXueSongId(
        widget.songTitle,
        widget.songType,
      );

      if (luoXueSongId != null) {
        _audioUrl = 'https://assets2.lxns.net/maimai/music/$luoXueSongId.mp3';
        debugPrint("Loaded audio URL: $_audioUrl");
      } else {
        debugPrint("No audio found for song: ${widget.songTitle}");
      }
    } catch (e) {
      debugPrint("Error loading audio URL: $e");
    }
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
      debugPrint("Resolved background image provider for song ${widget.songId}");
    } catch (e) {
      debugPrint("Error loading background image: $e");
      _bgImageProvider = null;
    }
  }

  Future<String?> _downloadAudioToTemp(String url) async {
    try {
      final response = await ApiClient.get(Uri.parse(url));
      if (response.statusCode != 200) {
        debugPrint("Failed to download audio: ${response.statusCode}");
        return null;
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/chart_audio_${widget.songId}.mp3');
      await file.writeAsBytes(response.bodyBytes);
      debugPrint("Downloaded audio to: ${file.path}");
      return file.path;
    } catch (e) {
      debugPrint("Error downloading audio: $e");
      return null;
    }
  }

  Future<void> _loadFallbackChart() async {
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
      if (_audioUrl != null) {
        if (_audioUrl!.startsWith('http://') || _audioUrl!.startsWith('https://')) {
          audioPath = await _downloadAudioToTemp(_audioUrl!);
        } else {
          audioPath = _audioUrl;
        }
      }

      setState(() {
        _chartOffset = 0.0;
        _controller?.dispose();
        _gameplayController?.dispose();
        _controller = SimaiPlayerController(
          chart: chart,
          audioFilePath: audioPath,
          backgroundImageProvider: _bgImageProvider,
          initialChartTime: -_chartOffset,
        )..title = widget.songTitle;
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
    }
  }

  @override
  void dispose() {
    _gameplayController?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _controller == null
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SimaiPlayerPage(
              key: _playerKey,
              controller: _controller!,
              gameplayController: _gameplayController,
              videoExportMetadata: _videoMetadata,
              videoExportOptions: _videoExportOptions,
              onVideoExported: _onVideoExported,
              disposeController: false,
            ),
    );
  }
}