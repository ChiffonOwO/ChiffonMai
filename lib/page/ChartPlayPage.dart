import 'package:flutter/material.dart';
import 'package:simai_flutter/simai_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:my_first_flutter_app/service/SongPlayService.dart';
import 'package:my_first_flutter_app/utils/CoverUtil.dart';

class ChartPlayPage extends StatefulWidget {
  final String maidataContent;
  final String songTitle;
  final String songId;
  final String songType;
  final String? selectedInote;

  const ChartPlayPage({
    super.key,
    required this.maidataContent,
    required this.songTitle,
    required this.songId,
    required this.songType,
    this.selectedInote,
  });

  @override
  State<ChartPlayPage> createState() => _ChartPlayPageState();
}

class _ChartPlayPageState extends State<ChartPlayPage> {
  SimaiPlayerController? _controller;
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
    _loadBackgroundImage();

    try {
      var simaiFile = SimaiFile(widget.maidataContent);

      String? chartText;
      String? firstStr;

      // 如果用户选择了难度，直接使用该难度
      if (widget.selectedInote != null) {
        chartText = simaiFile.getValue("inote_${widget.selectedInote}");
        if (chartText != null) {
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
      setState(() {
        _chartOffset = offset;
        _controller?.dispose();
        
        Source? audioSource;
        if (_audioUrl != null) {
          audioSource = UrlSource(_audioUrl!);
        }

        _controller = SimaiPlayerController(
          chart: chart,
          audioSource: audioSource,
          backgroundImageProvider: _bgImageProvider,
          initialChartTime: -_chartOffset,
        )..title = widget.songTitle;
        _playerKey = UniqueKey();
      });
    } catch (e) {
      debugPrint("Error loading chart: $e");
      _loadFallbackChart();
    }
  }

  Future<void> _loadAudioUrl() async {
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

  void _loadBackgroundImage() {
    try {
      String coverPath = CoverUtil.buildCoverPath(widget.songId);
      _bgImageProvider = AssetImage(coverPath);
      debugPrint("Loaded background image: $coverPath");
    } catch (e) {
      debugPrint("Error loading background image: $e");
      _bgImageProvider = null;
    }
  }

  void _loadFallbackChart() {
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
      setState(() {
        _chartOffset = 0.0;
        _controller?.dispose();
        
        Source? audioSource;
        if (_audioUrl != null) {
          audioSource = UrlSource(_audioUrl!);
        }

        _controller = SimaiPlayerController(
          chart: chart,
          audioSource: audioSource,
          backgroundImageProvider: _bgImageProvider,
          initialChartTime: -_chartOffset,
        )..title = widget.songTitle;
        _playerKey = UniqueKey();
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _controller == null
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SimaiPlayerPage(key: _playerKey, controller: _controller!),
    );
  }
}