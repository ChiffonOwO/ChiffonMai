import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/CommonWidgetUtil.dart';
import '../utils/CoverUtil.dart';
import '../utils/AppTheme.dart';
import '../utils/ExportPathUtil.dart';
import '../service/SongMaidataPageService.dart';
import '../service/SongPlayService.dart';
import '../manager/MaidataManager.dart';
import 'ChartPlayPage.dart';
import 'package:my_first_flutter_app/utils/ApiClient.dart';

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
  /// 公开目录不可写时，记录实际落盘的私有路径，用于在成功弹窗里提示用户
  String? _fallbackPath;
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

  /// 谱面导出：先让用户选目标格式
  Future<void> _showExportOptions() async {
    if (_maidataContent.isEmpty || _isExporting) return;

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(ctx).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.folder_zip_outlined),
              title: const Text('导出压缩包 (.zip)'),
              subtitle: const Text('maidata.txt + 曲绘 + 音源，通用谱面包'),
              onTap: () => Navigator.of(ctx).pop('zip'),
            ),
            ListTile(
              leading: const Icon(Icons.sports_esports_outlined),
              title: const Text('导出 AstroDX 谱面 (.adx)'),
              subtitle: const Text('用 AstroDX 打开即可自动安装谱面'),
              onTap: () => Navigator.of(ctx).pop('adx'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!mounted || choice == null) return;
    if (choice == 'zip') {
      await _exportToZip();
    } else if (choice == 'adx') {
      await _exportAstroDx();
    }
  }

  /// 收集谱面三件套：maidata 文本、曲绘、音源
  Future<_ChartExportAssets> _collectExportAssets() async {
    // 必须用 utf8.encode，不能用 codeUnits。
    // codeUnits 返回的是 UTF-16 码元，日文/中文标题会被写成乱码字节，
    // 导出的 maidata.txt 到别的工具里就是一堆问号。
    final maidataBytes = Uint8List.fromList(utf8.encode(_maidataContent));
    final coverBytes = await _getCoverBytes();
    final audioBytes = await _getAudioBytes();
    return _ChartExportAssets(
      maidataBytes: maidataBytes,
      coverBytes: coverBytes,
      audioBytes: audioBytes,
    );
  }

  /// 导出通用 zip 压缩包（三件套平铺在压缩包根目录）
  Future<void> _exportToZip() async {
    if (_maidataContent.isEmpty || _isExporting) return;
    await _runExport(() async {
      final assets = await _collectExportAssets();

      final archive = Archive();
      archive.add(ArchiveFile.bytes('maidata.txt', assets.maidataBytes));
      if (assets.coverBytes != null) {
        archive.add(ArchiveFile.bytes('bg.png', assets.coverBytes!));
      }
      if (assets.audioBytes != null) {
        archive.add(ArchiveFile.bytes('track.mp3', assets.audioBytes!));
      }

      final zipData = ZipEncoder().encode(archive);
      final safeName =
          ExportPathUtil.sanitizeFileName(widget.songTitle, fallback: 'chart');
      final file = await ExportPathUtil.writeExportFile(
        fileName: '$safeName.zip',
        bytes: zipData,
        subDir: '谱面',
        onFallback: (p) => _fallbackPath = p,
      );
      return (file.path, '$safeName.zip', assets.missingHint);
    });
  }

  /// 导出 AstroDX 谱面包（.adx）
  ///
  /// `.adx` 本质就是「改了后缀的 zip」：AstroDX 会扫描压缩包内容，
  /// 找到包含 maidata.txt 的谱面文件夹后自动安装。
  /// 因此三件套必须套在一层以曲名命名的文件夹里，
  /// 而不能像通用 zip 那样平铺在压缩包根目录。
  Future<void> _exportAstroDx() async {
    if (_maidataContent.isEmpty || _isExporting) return;
    await _runExport(() async {
      final assets = await _collectExportAssets();
      final safeName =
          ExportPathUtil.sanitizeFileName(widget.songTitle, fallback: 'chart');

      final archive = Archive();
      archive
          .add(ArchiveFile.bytes('$safeName/maidata.txt', assets.maidataBytes));
      if (assets.coverBytes != null) {
        archive.add(ArchiveFile.bytes('$safeName/bg.png', assets.coverBytes!));
      }
      if (assets.audioBytes != null) {
        archive
            .add(ArchiveFile.bytes('$safeName/track.mp3', assets.audioBytes!));
      }

      final zipData = ZipEncoder().encode(archive);
      final file = await ExportPathUtil.writeExportFile(
        fileName: '$safeName.adx',
        bytes: zipData,
        subDir: '谱面',
        onFallback: (p) => _fallbackPath = p,
      );
      return (file.path, '$safeName.adx', assets.missingHint);
    });
  }

  /// 统一的导出流程：进度弹窗 → 执行 → 成功/失败提示
  Future<void> _runExport(
    Future<(String path, String fileName, String? warning)> Function() job,
  ) async {
    setState(() => _isExporting = true);
    _fallbackPath = null;

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
      final (path, fileName, warning) = await job();

      if (mounted) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        await _showExportSuccessDialog(path, fileName, warning: warning);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导出失败: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: AppColors.errorRed(Theme.of(context).brightness),
          ),
        );
      }
      debugPrint('[DEBUG][SongMaidataPage] 导出失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  /// 显示导出成功对话框：展示导出路径并提供复制按钮
  Future<void> _showExportSuccessDialog(
    String filePath,
    String fileName, {
    String? warning,
  }) async {
    await showDialog(
      context: context,
      builder: (ctx) {
        bool copied = false;
        return StatefulBuilder(
          builder: (ctx, setLocalState) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade600, size: 22),
                const SizedBox(width: 8),
                const Text('导出成功'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '已导出 $fileName',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '文件已保存到：',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.maxFinite,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Theme.of(ctx).dividerColor,
                      width: 1,
                    ),
                  ),
                  child: SelectableText(
                    filePath,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      height: 1.4,
                    ),
                  ),
                ),
                if (_fallbackPath != null || warning != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.maxFinite,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border:
                          Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_fallbackPath != null)
                          const Text(
                            '公开目录不可写，文件已保存到应用私有目录，'
                            '可能无法在系统文件管理器中直接找到。',
                            style: TextStyle(fontSize: 12, height: 1.4),
                          ),
                        if (_fallbackPath != null && warning != null)
                          const SizedBox(height: 4),
                        if (warning != null)
                          Text(
                            warning,
                            style: const TextStyle(fontSize: 12, height: 1.4),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: filePath));
                  if (!ctx.mounted) return;
                  setLocalState(() => copied = true);
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('路径已复制到剪贴板')),
                  );
                },
                icon: Icon(
                  copied ? Icons.check : Icons.copy,
                  size: 16,
                  color: copied ? Colors.green.shade600 : null,
                ),
                label: Text(
                  copied ? '已复制' : '复制路径',
                  style: copied
                      ? TextStyle(color: Colors.green.shade600)
                      : null,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('关闭'),
              ),
            ],
          ),
        );
      },
    );
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
      final response = await ApiClient.get(Uri.parse(networkUrl));
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
      final response = await ApiClient.get(Uri.parse(audioUrl));
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

  @override
  Widget build(BuildContext context) {
    final themeColor = Theme.of(context).colorScheme.primary;
    final brightness = Theme.of(context).brightness;
    final textPrimaryColor = Theme.of(context).colorScheme.onSurface;
    final safeBottom = MediaQuery.of(context).padding.bottom;

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
                    // 操作按钮靠右
                    if (!_isLoading && _maidataContent.isNotEmpty)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.copy, color: textPrimaryColor, size: 20),
                              onPressed: _copyToClipboard,
                              tooltip: '复制',
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                            ),
                            IconButton(
                              icon: Icon(_isExporting ? Icons.hourglass_empty : Icons.download, color: textPrimaryColor, size: 20),
                              onPressed: _isExporting ? null : _showExportOptions,
                              tooltip: '导出',
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                            ),
                            IconButton(
                              icon: Icon(Icons.play_circle_outline, color: textPrimaryColor, size: 20),
                              onPressed: _navigateToChartPlay,
                              tooltip: '渲染',
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(4, 0, 4, 8),
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
                  margin: EdgeInsets.fromLTRB(4, 0, 4, 10 + safeBottom),
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

/// 一次导出需要的三件套
class _ChartExportAssets {
  final Uint8List maidataBytes;
  final Uint8List? coverBytes;
  final Uint8List? audioBytes;

  _ChartExportAssets({
    required this.maidataBytes,
    this.coverBytes,
    this.audioBytes,
  });

  /// 缺件提示。缺少音源/曲绘时 AstroDX 仍能装谱，但游玩体验不完整，
  /// 所以这里不阻断导出，只在成功弹窗里提醒。
  String? get missingHint {
    final missing = <String>[];
    if (coverBytes == null) missing.add('曲绘');
    if (audioBytes == null) missing.add('音源');
    if (missing.isEmpty) return null;
    return '未能获取${missing.join('、')}，压缩包里只有谱面数据，'
        '导入后需要自行补齐才能正常游玩。';
  }
}