import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/CommonWidgetUtil.dart';
import '../utils/CoverUtil.dart';
import '../service/SongMaidataPageService.dart';
import 'ChartPlayPage.dart';

class SongMaidataPage extends StatefulWidget {
  final String songId;
  final String songTitle;
  final String genre;
  final String songType;
  final int difficultyIndex;

  const SongMaidataPage({
    super.key,
    required this.songId,
    required this.songTitle,
    required this.genre,
    required this.songType,
    required this.difficultyIndex,
  });

  @override
  State<SongMaidataPage> createState() => _SongMaidataPageState();
}

class _SongMaidataPageState extends State<SongMaidataPage> {
  bool _isLoading = true;
  String _maidataContent = '';
  String? _errorMessage;
  List<String> _inoteList = [];
  String? _selectedInote;
  final ScrollController _scrollController = ScrollController();

  late SongMaidataPageService _service;

  @override
  void initState() {
    super.initState();
    _service = SongMaidataPageService(
      songId: widget.songId,
      songTitle: widget.songTitle,
      genre: widget.genre,
      songType: widget.songType,
    );
    _fetchMaidata();
  }

  Future<void> _fetchMaidata() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String? content = await _service.fetchMaidata(
        onInoteParsed: (inoteList) {
          setState(() {
            _inoteList = inoteList;
            _selectedInote = null;
          });
        },
      );

      if (content != null) {
        setState(() {
          _maidataContent = content;
        });
      } else {
        setState(() {
          _errorMessage = '未找到匹配的谱面代码';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '获取谱面代码失败: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _copyToClipboard() {
    if (_maidataContent.isEmpty) return;

    Clipboard.setData(ClipboardData(text: _maidataContent));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制到剪贴板')),
    );
  }

  void _navigateToChartPlay() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('提示'),
          content: const Text('该功能对设备要求较高，可能会造成应用卡顿或闪退，是否继续？'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showDifficultySelector();
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  void _showDifficultySelector() {
    if (_inoteList.isEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChartPlayPage(
            maidataContent: _maidataContent,
            songTitle: widget.songTitle,
            songId: widget.songId,
            songType: widget.songType,
            selectedInote: null,
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('选择难度'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    '渲染出的谱面仅供参考，不代表官方谱面。对于高密度谱面，请勿频繁拖动进度条，以免造成应用闪退或卡死。',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
                ..._inoteList.map((inote) {
                  String difficultyName = _getInoteDifficulty(inote);
                  Color inoteColor = _getInoteColor(inote);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChartPlayPage(
                              maidataContent: _maidataContent,
                              songTitle: widget.songTitle,
                              songId: widget.songId,
                              songType: widget.songType,
                              selectedInote: inote,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: inoteColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        textStyle: const TextStyle(fontSize: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(difficultyName),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getInoteDifficulty(String inoteNum) {
    return SongMaidataPageService.inoteDifficultyMap[inoteNum] ?? inoteNum;
  }

  Color _getInoteColor(String inoteNum) {
    int colorValue = SongMaidataPageService.inoteColorMap[inoteNum] ?? 0xFF9E9E9E;
    return Color(colorValue);
  }

  void _scrollToInote(String inoteNum) {
    setState(() {
      _selectedInote = inoteNum;
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      String targetText = '&inote_$inoteNum';
      int targetIndex = _maidataContent.indexOf(targetText);

      if (targetIndex != -1) {
        double lineHeight = 18.0;
        int linesBefore = _maidataContent.substring(0, targetIndex).split('\n').length;
        double targetPosition = linesBefore * lineHeight;
        double offsetPosition = targetPosition - (lineHeight * 6);
        offsetPosition = offsetPosition < 0 ? 0 : offsetPosition;

        _scrollController.animateTo(
          offsetPosition,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Widget _buildTypeTag(String type, String songId) {
    bool isUtage = songId.length == 6;

    if (isUtage) {
      return Text(
        'UTAGE',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.red,
        ),
      );
    } else if (type == 'DX') {
      return Text(
        'DX',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.orange,
        ),
      );
    } else {
      return Text(
        'ST',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade300,
        ),
      );
    }
  }

  Widget _buildDsDisplay() {
    return FutureBuilder<List<String>>(
      future: _service.getSongDsList(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          List<String> dsList = snapshot.data!;
          return Text(
            dsList.join(' / '),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          );
        } else {
          return const Text(
            '获取定数中...',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          );
        }
      },
    );
  }

  Widget _buildInfoTag(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Colors.purple;
    final textPrimaryColor = const Color.fromARGB(255, 84, 97, 97);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          CommonWidgetUtil.buildCommonBgWidget(),
          CommonWidgetUtil.buildCommonChiffonBgWidget(context),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 48, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: textPrimaryColor),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '谱面代码',
                          style: TextStyle(
                            color: textPrimaryColor,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    if (!_isLoading && _maidataContent.isNotEmpty)
                      ElevatedButton(
                        onPressed: _copyToClipboard,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 2,
                          ),
                          textStyle: const TextStyle(fontSize: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('复制'),
                      ),
                    if (!_isLoading && _maidataContent.isNotEmpty)
                      const SizedBox(width: 8),
                    if (!_isLoading && _maidataContent.isNotEmpty)
                      ElevatedButton(
                        onPressed: _navigateToChartPlay,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 2,
                          ),
                          textStyle: const TextStyle(fontSize: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('渲染'),
                      ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 5.0,
                      offset: Offset(2.0, 2.0),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CoverUtil.buildCoverWidgetWithContext(context, widget.songId.toString(), 80),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _buildTypeTag(widget.songType, widget.songId),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      widget.songTitle,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: themeColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _buildInfoTag('歌曲ID', widget.songId),
                              const SizedBox(height: 8),
                              _buildDsDisplay(),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_inoteList.isNotEmpty)
                      const SizedBox(height: 12),
                    if (_inoteList.isNotEmpty)
                      Row(
                        children: [
                          const Text(
                            'INOTE: ',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _inoteList.map((inote) {
                                  String difficultyName = _getInoteDifficulty(inote);
                                  Color inoteColor = _getInoteColor(inote);
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: ElevatedButton(
                                      onPressed: () => _scrollToInote(inote),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _selectedInote == inote
                                            ? inoteColor
                                            : Colors.grey[200],
                                        foregroundColor: _selectedInote == inote
                                            ? Colors.white
                                            : Colors.black,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        textStyle: const TextStyle(fontSize: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: Text(difficultyName),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 5.0,
                        offset: Offset(2.0, 2.0),
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(),
                        )
                      : _errorMessage != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      size: 48,
                                      color: Colors.red,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _errorMessage!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.red,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: _fetchMaidata,
                                      child: const Text('重试'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : _maidataContent.isEmpty
                              ? const Center(
                                  child: Text('暂无谱面代码数据'),
                                )
                              : SingleChildScrollView(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.all(16),
                                  child: SelectableText(
                                    _maidataContent,
                                    style: const TextStyle(
                                      fontFamily: 'Courier New',
                                      fontSize: 12,
                                      color: Colors.black87,
                                      height: 1.4,
                                    ),
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