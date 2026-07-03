import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../utils/CommonWidgetUtil.dart';
import '../utils/CoverUtil.dart';
import '../utils/AppTheme.dart';
import '../service/SongMaidataPageService.dart';
import '../service/SongPlayService.dart';
import '../manager/MaidataManager.dart';
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
  bool _isFetchingFullCache = false;
  bool _isExporting = false;
  String _maidataContent = '';
  String? _errorMessage;
  List<String> _inoteList = [];
  String? _selectedInote;
  String? _displayedInote; // 当前显示的难度
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
    _checkAndFetchFullCache();
  }

  Future<void> _checkAndFetchFullCache() async {
    await MaidataManager().initialize();
    
    if (!MaidataManager().isCacheReady) {
      setState(() {
        _isFetchingFullCache = true;
      });
      
      debugPrint('[DEBUG][SongMaidataPage] 全量缓存不存在，开始拉取...');
      
      try {
        await MaidataManager().fetchAndCacheFullMaidata();
        debugPrint('[DEBUG][SongMaidataPage] 全量缓存拉取成功');
      } catch (e) {
        debugPrint('[DEBUG][SongMaidataPage] 全量缓存拉取失败，将使用独立缓存或网络请求: $e');
      } finally {
        setState(() {
          _isFetchingFullCache = false;
        });
      }
    }
    
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

  Future<void> _exportToZip() async {
    if (_maidataContent.isEmpty || _isExporting) return;

    setState(() {
      _isExporting = true;
    });

    // 显示加载对话框
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('正在导出...'),
            ],
          ),
        ),
      );
    }

    try {
      // 1. 获取maidata内容
      final maidataBytes = Uint8List.fromList(_maidataContent.codeUnits);

      // 2. 获取曲绘字节数据
      Uint8List? coverBytes = await _getCoverBytes();

      // 3. 获取音源字节数据
      Uint8List? audioBytes = await _getAudioBytes();

      // 4. 创建zip压缩包
      final archive = Archive();
      archive.add(ArchiveFile.bytes('maidata.txt', maidataBytes));
      if (coverBytes != null) {
        archive.add(ArchiveFile.bytes('bg.png', coverBytes));
      }
      if (audioBytes != null) {
        archive.add(ArchiveFile.bytes('track.mp3', audioBytes));
      }

      final zipData = ZipEncoder().encode(archive);

      // 5. 保存到文件（优先使用系统下载目录，方便用户通过文件管理器直接访问）
      String? dirPath;
      try {
        dirPath = (await getDownloadsDirectory())?.path;
      } catch (_) {
        dirPath = null;
      }
      if (dirPath == null) {
        // iOS / 备选方案：回退到外置存储或应用文档目录
        try {
          dirPath = (await getExternalStorageDirectory())?.path;
        } catch (_) {
          dirPath = null;
        }
      }
      dirPath ??= (await getApplicationDocumentsDirectory()).path;

      final exportDir = Directory('$dirPath/maidata_exports');
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      // 清理文件名中的非法字符
      String safeName = widget.songTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final filePath = '${exportDir.path}/$safeName.zip';
      final file = File(filePath);
      await file.writeAsBytes(zipData);

      // 关闭加载对话框
      if (mounted) {
        Navigator.of(context).pop();
      }

      // 显示成功提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导出成功: $safeName.zip\n保存路径: $filePath'),
            duration: const Duration(seconds: 5),
            backgroundColor: AppColors.successGreen(Theme.of(context).brightness),
          ),
        );
      }
    } catch (e) {
      // 关闭加载对话框
      if (mounted) {
        Navigator.of(context).pop();
      }
      // 显示错误提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导出失败: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: AppColors.errorRed(Theme.of(context).brightness),
          ),
        );
      }
      debugPrint('[DEBUG][SongMaidataPage] 导出zip失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  /// 获取曲绘字节数据（优先本地资源，兜底网络下载）
  Future<Uint8List?> _getCoverBytes() async {
    final songId = widget.songId;

    // 尝试从本地assets加载（依次尝试多种路径）
    final coverPaths = [
      CoverUtil.buildCoverPath(songId),
      CoverUtil.getLocalCoverPath(songId),
      CoverUtil.getLocalCoverPathRetry1(songId),
      CoverUtil.getLocalCoverPathRetry2(songId),
    ];

    for (final path in coverPaths) {
      try {
        final byteData = await rootBundle.load(path);
        return byteData.buffer.asUint8List();
      } catch (_) {
        // 当前路径失败，尝试下一个
      }
    }

    // 本地加载失败，从网络下载
    try {
      final networkUrl = CoverUtil.getNetworkCoverUrl(songId);
      debugPrint('[DEBUG][SongMaidataPage] 从网络获取曲绘: $networkUrl');
      final response = await http.get(Uri.parse(networkUrl));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      debugPrint('[DEBUG][SongMaidataPage] 网络获取曲绘失败: $e');
    }

    return null;
  }

  /// 获取音源字节数据
  Future<Uint8List?> _getAudioBytes() async {
    try {
      // 使用SongPlayService查找落雪歌曲ID
      final songPlayService = SongPlayService();
      final luoXueSongId = await songPlayService.findLuoXueSongId(
        widget.songTitle,
        widget.songType,
      );

      if (luoXueSongId == null) {
        debugPrint('[DEBUG][SongMaidataPage] 未找到落雪歌曲ID，跳过音源导出');
        return null;
      }

      final audioUrl = 'https://assets2.lxns.net/maimai/music/$luoXueSongId.mp3';

      // 先检查本地缓存
      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/music_cache');
      final cacheFilePath = '${cacheDir.path}/$luoXueSongId.mp3';
      final cacheFile = File(cacheFilePath);

      if (await cacheFile.exists()) {
        debugPrint('[DEBUG][SongMaidataPage] 使用缓存的音源: $cacheFilePath');
        return await cacheFile.readAsBytes();
      }

      // 从网络下载
      debugPrint('[DEBUG][SongMaidataPage] 从网络下载音源: $audioUrl');
      final response = await http.get(Uri.parse(audioUrl));
      if (response.statusCode == 200) {
        // 保存到缓存
        if (!await cacheDir.exists()) {
          await cacheDir.create(recursive: true);
        }
        try {
          await cacheFile.writeAsBytes(response.bodyBytes);
        } catch (_) {
          // 缓存写入失败不影响使用
        }
        return response.bodyBytes;
      } else {
        debugPrint('[DEBUG][SongMaidataPage] 下载音源失败，状态码: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[DEBUG][SongMaidataPage] 获取音源失败: $e');
    }

    return null;
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
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    '渲染出的谱面仅供参考，不代表官方谱面。对于高密度谱面，请勿频繁拖动进度条，以免造成应用闪退或卡死。',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
      // ALL选项显示全部内容，其他选项显示对应难度
      _displayedInote = inoteNum == 'ALL' ? null : inoteNum;
    });

    // 切换难度时自动滚动到最顶端
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }
  
  // 提取单个难度的maidata内容
  String _getFilteredMaidata() {
    if (_displayedInote == null || _maidataContent.isEmpty) {
      return _maidataContent;
    }
    
    String targetInote = '&inote_${_displayedInote}';
    String nextInote = '';
    
    // 找到下一个难度的起始位置
    for (String inote in _inoteList) {
      if (inote != _displayedInote) {
        String candidate = '&inote_$inote';
        int targetIndex = _maidataContent.indexOf(targetInote);
        int candidateIndex = _maidataContent.indexOf(candidate);
        
        if (candidateIndex > targetIndex) {
          if (nextInote.isEmpty || candidateIndex < _maidataContent.indexOf('&inote_$nextInote')) {
            nextInote = inote;
          }
        }
      }
    }
    
    int startIndex = _maidataContent.indexOf(targetInote);
    if (startIndex == -1) {
      return _maidataContent;
    }
    
    int endIndex = nextInote.isEmpty 
        ? _maidataContent.length 
        : _maidataContent.indexOf('&inote_$nextInote');
    
    if (endIndex == -1) {
      endIndex = _maidataContent.length;
    }
    
    return _maidataContent.substring(startIndex, endIndex);
  }

  Widget _buildTypeTag(String type, String songId) {
    final brightness = Theme.of(context).brightness;
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
          color: AppColors.warningOrange(brightness),
        ),
      );
    } else {
      return Text(
        'ST',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.linkBlue(brightness),
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
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          );
        } else {
          return Text(
            '获取定数中...',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Theme.of(context).colorScheme.primary;
    final brightness = Theme.of(context).brightness;
    final textPrimaryColor = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          CommonWidgetUtil.buildCommonBgWidget(),
          CommonWidgetUtil.buildCommonChiffonBgWidget(context),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(8, 48, 8, 4),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 标题居中
                    Text(
                      '谱面代码',
                      style: TextStyle(
                        color: textPrimaryColor,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // 返回按钮靠左
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: Icon(Icons.arrow_back, color: textPrimaryColor),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              if (!_isLoading && _maidataContent.isNotEmpty)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildActionButton(
                        label: '复制',
                        icon: Icons.copy,
                        onPressed: _copyToClipboard,
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                      const SizedBox(width: 8),
                      _buildActionButton(
                        label: '渲染',
                        icon: Icons.play_circle_outline,
                        onPressed: _navigateToChartPlay,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      _buildActionButton(
                        label: _isExporting ? '导出中...' : '导出',
                        icon: Icons.download,
                        onPressed: _isExporting ? null : _exportToZip,
                        color: AppColors.successGreen(brightness),
                      ),
                    ],
                  ),
                ),
              Container(
                margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    AppColors.defaultShadow(brightness),
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
                          Text(
                            'INOTE: ',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  // ALL选项
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: ElevatedButton(
                                      onPressed: () => _scrollToInote('ALL'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _selectedInote == 'ALL'
                                            ? Theme.of(context).colorScheme.onSurface
                                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                                        foregroundColor: _selectedInote == 'ALL'
                                            ? Theme.of(context).colorScheme.surface
                                            : Theme.of(context).colorScheme.onSurface,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        textStyle: const TextStyle(fontSize: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: const Text('ALL'),
                                    ),
                                  ),
                                  // 其他难度选项
                                  ..._inoteList.map((inote) {
                                    String difficultyName = _getInoteDifficulty(inote);
                                    Color inoteColor = _getInoteColor(inote);
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: ElevatedButton(
                                        onPressed: () => _scrollToInote(inote),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _selectedInote == inote
                                              ? inoteColor
                                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                                          foregroundColor: _selectedInote == inote
                                              ? Colors.white
                                              : Theme.of(context).colorScheme.onSurface,
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
                                ],
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
                    color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      AppColors.defaultShadow(brightness),
                    ],
                  ),
                  child: _isFetchingFullCache
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircularProgressIndicator(),
                                const SizedBox(height: 16),
                                const Text(
                                  '正在获取全量谱面缓存...',
                                  style: TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '首次进入需要拉取大量数据，请耐心等待',
                                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : _isLoading
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
                                      color: AppColors.errorRed(brightness),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _errorMessage!,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: AppColors.errorRed(brightness),
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
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minWidth: double.infinity,
                                    ),
                                    child: SelectableText(
                                      _getFilteredMaidata(),
                                      style: TextStyle(
                                        fontFamily: 'Courier New',
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSurface,
                                        height: 1.4,
                                      ),
                                      textAlign: TextAlign.left,
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