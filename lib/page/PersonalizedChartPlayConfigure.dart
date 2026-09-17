import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:charset/charset.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:my_first_flutter_app/utils/MaidataDecodeUtil.dart';
import 'package:my_first_flutter_app/service/ChartPackageHistoryStore.dart';
import 'package:path_provider/path_provider.dart';
import 'ChartPlayPage.dart';
import '../widgets/PageTopBar.dart';

// ─────────────────────────────────────────────────────────
// 谱面包导入（.adx / .zip）
//
// .adx 就是改了后缀的 zip（见 AGENTS.md §3），AstroDX 会扫描压缩包、
// 找到含 maidata.txt 的谱面文件夹后安装。所以两种后缀用同一套解压流程。
//
// 压缩包结构有两种，都要支持：
//   平铺：maidata.txt / bg.png / track.mp3
//   套一层文件夹：<曲名>/maidata.txt / <曲名>/bg.png / <曲名>/track.mp3
// ─────────────────────────────────────────────────────────

const _kChartImageExtensions = <String>[
  'png', 'jpg', 'jpeg', 'webp', 'bmp', 'gif',
];

/// 按优先级排列：靠前的扩展名优先被选中
const _kChartAudioExtensions = <String>[
  'mp3', 'wav', 'ogg', 'm4a', 'aac', 'flac',
];

/// 从压缩包里挑出来的谱面三件套（原始字节，还没落盘）
class _ExtractedChartPackage {
  final String maidataFileName;
  final Uint8List maidataBytes;

  /// 曲绘文件名（可能为 null，表示压缩包里没有图）
  final String? imageFileName;
  final Uint8List? imageBytes;

  /// 音源文件名（可能为 null，表示压缩包里没有音源）
  final String? audioFileName;
  final Uint8List? audioBytes;

  const _ExtractedChartPackage({
    required this.maidataFileName,
    required this.maidataBytes,
    this.imageFileName,
    this.imageBytes,
    this.audioFileName,
    this.audioBytes,
  });
}

String _extensionOf(String path) {
  final base = path.split('/').last;
  final dot = base.lastIndexOf('.');
  if (dot < 0 || dot == base.length - 1) return '';
  return base.substring(dot + 1).toLowerCase();
}

/// 在所有候选里挑一个：先按扩展名优先级，再按路径深度浅的优先。
ArchiveFile? _pickArchiveFile(
  List<ArchiveFile> candidates,
  List<String> preferredExtensions,
) {
  if (candidates.isEmpty) return null;
  final sorted = [...candidates]..sort((a, b) {
      final ai = preferredExtensions.indexOf(_extensionOf(a.name));
      final bi = preferredExtensions.indexOf(_extensionOf(b.name));
      final ar = ai < 0 ? preferredExtensions.length : ai;
      final br = bi < 0 ? preferredExtensions.length : bi;
      if (ar != br) return ar.compareTo(br);
      final ad = '/'.allMatches(a.name).length;
      final bd = '/'.allMatches(b.name).length;
      if (ad != bd) return ad.compareTo(bd);
      return a.name.compareTo(b.name);
    });
  return sorted.first;
}

/// 解压谱面包，挑出 maidata.txt + 曲绘 + 音源。
/// 认不出 maidata.txt 时返回 null，由调用方给出提示。
_ExtractedChartPackage? _extractChartPackage(Uint8List bytes) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    return null;
  }

  final allFiles = archive.files
      .where((f) => f.isFile && f.name.trim().isNotEmpty)
      .toList();
  if (allFiles.isEmpty) return null;

  // 先按完整文件名精确匹配，再退回「任意以 maidata 开头的文本文件」，
  // 后者是为了容忍 maidata.txt.txt 这类被改坏的后缀。
  ArchiveFile? maidataEntry;
  for (final f in allFiles) {
    if (f.name.split('/').last.toLowerCase() == 'maidata.txt') {
      maidataEntry = f;
      break;
    }
  }
  maidataEntry ??= () {
    for (final f in allFiles) {
      final lower = f.name.toLowerCase();
      if (lower.endsWith('.txt') && lower.split('/').last.startsWith('maidata')) {
        return f;
      }
    }
    return null;
  }();
  if (maidataEntry == null) return null;

  final maidataBytes = maidataEntry.readBytes();
  if (maidataBytes == null) return null;

  final maidataDir = maidataEntry.name.contains('/')
      ? maidataEntry.name.substring(0, maidataEntry.name.lastIndexOf('/') + 1)
      : '';

  // 优先在 maidata.txt 所在目录里找附件；该目录里一个都没有时，
  // 才退回整包搜索（兼容附件被放到别处的野包）。
  List<ArchiveFile> siblingsIn(String dir, bool Function(String) test) =>
      allFiles
          .where((f) =>
              f.name.startsWith(dir) &&
              !f.name.substring(dir.length).contains('/') &&
              test(f.name))
          .toList();

  List<ArchiveFile> pickFrom(bool Function(String) test) {
    final inDir = siblingsIn(maidataDir, test);
    if (inDir.isNotEmpty) return inDir;
    return allFiles.where((f) => test(f.name)).toList();
  }

  final imageEntry = _pickArchiveFile(
    pickFrom((n) => _kChartImageExtensions.contains(_extensionOf(n))),
    _kChartImageExtensions,
  );
  final audioEntry = _pickArchiveFile(
    pickFrom((n) => _kChartAudioExtensions.contains(_extensionOf(n))),
    _kChartAudioExtensions,
  );

  return _ExtractedChartPackage(
    maidataFileName: maidataEntry.name.split('/').last,
    maidataBytes: maidataBytes,
    imageFileName: imageEntry?.name.split('/').last,
    imageBytes: imageEntry?.readBytes(),
    audioFileName: audioEntry?.name.split('/').last,
    audioBytes: audioEntry?.readBytes(),
  );
}

/// 与单文件选择同一套编码策略：先 UTF-8，出现替换字符或抛错则退回 Shift-JIS。
/// 日谱社区大量使用 Shift-JIS，直接按 UTF-8 读会得到一片乱码。
String _decodeMaidataBytes(Uint8List bytes) {
  try {
    final text = utf8.decode(bytes);
    if (text.contains('\uFFFD')) {
      throw const FormatException('UTF-8 decode produced replacement characters');
    }
    return text;
  } catch (_) {
    return shiftJis.decode(bytes);
  }
}

class PersonalizedChartPlayConfigure extends StatefulWidget {
  const PersonalizedChartPlayConfigure({super.key});

  @override
  State<PersonalizedChartPlayConfigure> createState() => _PersonalizedChartPlayConfigureState();
}

class _PersonalizedChartPlayConfigureState extends State<PersonalizedChartPlayConfigure> {
  String? _maidataContent;
  String? _bgImagePath;   // 已复制到应用内部目录的路径
  String? _audioFilePath; // 已复制到应用内部目录的路径
  List<String> _inoteList = [];
  Directory? _workDir;

  /// 正在解压导入谱面包（.adx / .zip）
  bool _isImporting = false;

  /// 最近解析过的谱面包（最多 10 条，见 ChartPackageHistoryStore）
  List<ChartPackageHistoryEntry> _history = [];

  /// 正在从历史里重新解析的那一条（用于只让被点的那条显示 loading）
  String? _historyBusyPath;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final store = ChartPackageHistoryStore();
    await store.load();
    if (!mounted) return;
    setState(() {
      // 顺手剔除归档文件已经不在了的记录（用户可能清理过应用目录）
      _history = store.entries.where(store.exists).toList();
    });
  }

  static const Map<String, String> inoteDifficultyMap = {
    '2': 'BASIC',
    '3': 'ADVANCED',
    '4': 'EXPERT',
    '5': 'MASTER',
    '6': 'Re:MASTER',
    '7': 'UTAGE',
  };

  static const Map<String, int> inoteColorMap = {
    '2': 0xFF4CAF50,
    '3': 0xFFFF9800,
    '4': 0xFFF44336,
    '5': 0xFF9C27B0,
    '6': 0xFFCE93D8,
    '7': 0xFFFF4081,
  };

  List<String> _parseInoteList(String content) {
    List<String> inoteList = [];
    RegExp regex = RegExp(r'&inote_(\d+)');
    Iterable<Match> matches = regex.allMatches(content);
    for (Match match in matches) {
      String inoteNum = match.group(1)!;
      if (inoteDifficultyMap.containsKey(inoteNum) && !inoteList.contains(inoteNum)) {
        inoteList.add(inoteNum);
      }
    }
    inoteList.sort((a, b) => int.parse(a).compareTo(int.parse(b)));
    return inoteList;
  }

  /// 获取（或创建）自定义谱面播放的临时工作目录
  Future<Directory> _getWorkDir() async {
    if (_workDir != null) return _workDir!;
    final appDir = await getApplicationDocumentsDirectory();
    _workDir = Directory('${appDir.path}/custom_chart_play');
    if (!_workDir!.existsSync()) {
      _workDir!.createSync(recursive: true);
    }
    return _workDir!;
  }

  /// 将用户选择的文件复制到应用内部目录，避免 Android scoped storage 限制
  Future<String> _copyToAppDir(File sourceFile, String prefix) async {
    final workDir = await _getWorkDir();
    final ext = sourceFile.path.split('.').last;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final destPath = '${workDir.path}/${prefix}_$timestamp.$ext';
    final destFile = File(destPath);
    await sourceFile.copy(destFile.path);
    return destPath;
  }

  Future<void> _selectMaidataFile() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );
      if (result != null) {
        final file = File(result.files.single.path!);
        try {
          final bytes = await file.readAsBytes();
          // 编码策略与谱面包导入共用 _decodeMaidataBytes：先 UTF-8，
          // 出现替换字符或抛错则退回 Shift-JIS（日谱社区常用编码）。
          final content = _decodeMaidataBytes(bytes);

          setState(() {
            _maidataContent = content;
            _inoteList = _parseInoteList(content);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已加载maidata，解析到 ${_inoteList.length} 个难度')),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('读取失败: 文件编码不受支持，请使用UTF-8或Shift-JIS编码')),
          );
          debugPrint('maidata read error: $e');
        }
      }
    } catch (e) {
      debugPrint('文件选择失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法打开文件选择器: $e')),
        );
      }
    }
  }

  Future<void> _selectBgImage() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.image,
      );
      if (result != null && mounted) {
        final sourceFile = File(result.files.single.path!);
        try {
          final appPath = await _copyToAppDir(sourceFile, 'bg');
          setState(() => _bgImagePath = appPath);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已选择曲绘')),
          );
        } catch (e) {
          debugPrint('bg image copy error: $e');
          // fallback：直接使用原始路径
          setState(() => _bgImagePath = sourceFile.path);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已选择曲绘（使用原始路径）')),
          );
        }
      }
    } catch (e) {
      debugPrint('图片选择失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法打开图片选择器: $e')),
        );
      }
    }
  }

  Future<void> _selectAudioFile() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.audio,
      );
      if (result != null && mounted) {
        final sourceFile = File(result.files.single.path!);
        try {
          final appPath = await _copyToAppDir(sourceFile, 'audio');
          setState(() => _audioFilePath = appPath);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已选择音源')),
          );
        } catch (e) {
          debugPrint('audio file copy error: $e');
          // fallback：直接使用原始路径
          setState(() => _audioFilePath = sourceFile.path);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已选择音源（使用原始路径）')),
          );
        }
      }
    } catch (e) {
      debugPrint('音频选择失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法打开音频选择器: $e')),
        );
      }
    }
  }

  /// 从历史记录里一键重新解析某个谱面包。
  Future<void> _reparseFromHistory(ChartPackageHistoryEntry entry) async {
    if (_isImporting || _historyBusyPath != null) return;
    setState(() => _historyBusyPath = entry.archivedPath);
    try {
      final file = File(entry.archivedPath);
      if (!file.existsSync()) {
        // 归档文件被清掉了：从历史里移除这条并刷新列表，别让用户点了没反应
        await ChartPackageHistoryStore().remove(entry);
        if (!mounted) return;
        setState(() => _history.removeWhere(
            (e) => e.archivedPath == entry.archivedPath));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('「${entry.displayName}」的文件已不存在，已从列表移除')),
        );
        return;
      }
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      // 已经是归档副本了，不要再归档一次
      await _importChartPackage(bytes, entry.displayName);
    } catch (e) {
      debugPrint('从历史重新解析失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('重新解析失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _historyBusyPath = null);
    }
  }

  /// 长按历史条目：删除这条记录及其归档文件
  Future<void> _confirmRemoveHistory(ChartPackageHistoryEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这条记录'),
        content: Text('将从「最近解析」中移除「${entry.displayName}」，并删除它的存档文件。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed(Theme.of(context).brightness),
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ChartPackageHistoryStore().remove(entry);
    if (!mounted) return;
    setState(() =>
        _history.removeWhere((e) => e.archivedPath == entry.archivedPath));
  }

  /// 选择一个谱面包（.adx / .zip），解压后把三件套一次性填进表单。
  ///
  /// 相比分别选三个文件，这样用户只要从文件管理器里挑一个包就行。
  Future<void> _pickChartPackage() async {
    if (_isImporting) return;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['adx', 'zip'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final picked = result.files.single;
      if (!mounted) return;

      // withData 在部分 Android 机型上会返回 null，退回按路径读
      Uint8List? bytes = picked.bytes;
      if (bytes == null) {
        final path = picked.path;
        if (path == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('读不到这个文件的内容，请换一个来源重试')),
          );
          return;
        }
        bytes = await File(path).readAsBytes();
        if (!mounted) return;
      }

      // 归档由 _importChartPackage 在解压成功后才做：
      // 选到无效压缩包时不该在「最近解析」里留一条坏记录。
      await _importChartPackage(bytes, picked.name, archiveAs: picked.name);
    } catch (e) {
      debugPrint('谱面包导入失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败：$e')),
        );
      }
    }
  }

  /// 解压导入。[archiveAs] 非空时，把这份压缩包存进「最近解析」历史。
  Future<void> _importChartPackage(
    Uint8List bytes,
    String fileName, {
    String? archiveAs,
  }) async {
    setState(() => _isImporting = true);
    try {
      final extracted = _extractChartPackage(bytes);
      if (extracted == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('这个压缩包里没找到 maidata.txt，不是有效的谱面包')),
          );
        }
        return;
      }

      String maidataContent;
      try {
        maidataContent = _decodeMaidataBytes(extracted.maidataBytes);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('maidata.txt 编码不受支持，请使用 UTF-8 或 Shift-JIS 编码的谱面包')),
          );
        }
        debugPrint('maidata decode error: $e');
        return;
      }

      // 复用同一个工作目录：导入会覆盖上一轮的文件，先清掉避免累积
      final workDir = await _getWorkDir();
      try {
        if (workDir.existsSync()) {
          workDir.deleteSync(recursive: true);
        }
      } catch (e) {
        debugPrint('清理工作目录失败: $e');
      }
      workDir.createSync(recursive: true);

      final stamp = DateTime.now().millisecondsSinceEpoch;
      String? bgPath;
      if (extracted.imageBytes != null && extracted.imageFileName != null) {
        final ext = _extensionOf(extracted.imageFileName!);
        final dest = File('${workDir.path}/bg_$stamp.$ext');
        await dest.writeAsBytes(extracted.imageBytes!);
        bgPath = dest.path;
      }
      String? audioPath;
      if (extracted.audioBytes != null && extracted.audioFileName != null) {
        final ext = _extensionOf(extracted.audioFileName!);
        final dest = File('${workDir.path}/audio_$stamp.$ext');
        await dest.writeAsBytes(extracted.audioBytes!);
        audioPath = dest.path;
      }

      if (!mounted) return;
      setState(() {
        _maidataContent = maidataContent;
        _inoteList = _parseInoteList(maidataContent);
        _bgImagePath = bgPath;
        _audioFilePath = audioPath;
      });

      // 解压成功才归档进「最近解析」——选到坏包时不该在历史里留记录
      if (archiveAs != null) {
        try {
          final store = ChartPackageHistoryStore();
          await store.archive(bytes, archiveAs);
          if (mounted) {
            setState(() => _history = store.entries.where(store.exists).toList());
          }
        } catch (e) {
          // 归档失败不影响本次解析结果，只是没法记进历史
          debugPrint('谱面包归档失败: $e');
        }
      }

      final missing = <String>[
        if (bgPath == null) '曲绘',
        if (audioPath == null) '音源',
      ];
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(missing.isEmpty
              ? '已从 $fileName 导入三件套，解析到 ${_inoteList.length} 个难度'
              : '已导入 maidata（${_inoteList.length} 个难度）；包内没有${missing.join('和')}，可手动补选'),
        ),
      );
    } finally {
      // 页面已销毁时 _isImporting 随 State 一起消失，不必再赋值
      if (mounted) setState(() => _isImporting = false);
    }
  }

  /// 「最近解析」卡片：列出最近 10 个谱面包，点击即一键重新解析。
  ///
  /// 长按可删除单条（会同时删掉它的存档文件）。
  Widget _buildHistoryCard(Brightness brightness) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text('最近解析',
                  style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('${_history.length}/${ChartPackageHistoryStore.maxEntries}',
                  style: TextStyle(
                      color: scheme.onSurfaceVariant, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Text('点击即可按存档重新解析；长按可删除',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 8),
          ..._history.map((entry) {
            final busy = _historyBusyPath == entry.archivedPath;
            return InkWell(
              onTap: busy ? null : () => _reparseFromHistory(entry),
              onLongPress: busy ? null : () => _confirmRemoveHistory(entry),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: busy
                          ? CircularProgressIndicator(
                              strokeWidth: 2, color: scheme.primary)
                          : Icon(Icons.folder_zip_outlined,
                              size: 20, color: scheme.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _formatHistoryTime(entry.importedAt),
                            style: TextStyle(
                                fontSize: 11, color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.replay,
                        size: 18, color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// 相对时间：刚刚 / N 分钟前 / N 小时前 / N 天前 / 具体日期
  String _formatHistoryTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays < 30) return '${diff.inDays} 天前';
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }

  void _startPlayback() {
    if (_maidataContent == null || _maidataContent!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择maidata文件')),
      );
      return;
    }
    if (_inoteList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未找到有效难度')),
      );
      return;
    }

    // 播放页要显示的曲名取自 maidata 的 &title，而不是写死一个「自定义谱面」：
    // maidata 里没有 &title 时才退回这个名字。
    final songTitle =
        MaidataDecodeUtil.quickExtractTitle(_maidataContent!) ?? '自定义谱面';

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
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    songTitle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    '渲染出的谱面仅供参考，不代表官方谱面。对于高密度谱面，请勿频繁拖动进度条，以免造成应用闪退或卡死。',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ),
                ..._inoteList.map((inote) {
                  String difficultyName = inoteDifficultyMap[inote] ?? inote;
                  Color inoteColor = Color(inoteColorMap[inote] ?? 0xFF9E9E9E);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChartPlayPage(
                              maidataContent: _maidataContent!,
                              songTitle: songTitle,
                              songId: 'custom',
                              songType: 'custom',
                              selectedInote: inote,
                              bgImagePath: _bgImagePath,
                              audioFilePath: _audioFilePath,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: inoteColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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

  void _clearSelection() {
    setState(() {
      _maidataContent = null;
      _bgImagePath = null;
      _audioFilePath = null;
      _inoteList = [];
      _isImporting = false;
    });
    // 清理临时工作目录
    if (_workDir != null && _workDir!.existsSync()) {
      try {
        _workDir!.deleteSync(recursive: true);
        _workDir = null;
      } catch (e) {
        debugPrint('cleanup work dir error: $e');
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已清除选择')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      // 不要用 backgroundColor: AppColors.scaffoldBackground(brightness)：
      // 它在浅色模式返回 Colors.transparent，而本页是被 Navigator.push 出来的
      // 独立路由，底下没有 AppShell 的背景兜底，于是浅色模式下整页会漏出窗口底色（黑）。
      //
      // 同理，这里也不能用 Scaffold.appBar 放标题栏：Scaffold 会把 appBar 排在
      // body 之外，于是「透明 appBar + 只铺在 body 里的背景」= 标题栏和状态栏那一段
      // 底下什么都没有，浅色模式下顶栏依旧是黑的。
      //
      // 正确做法与全项目其余页面一致：标题栏画在同一个 Stack 里。
      body: Stack(
        children: [
          CommonWidgetUtil.buildCommonBgWidget(),
          Column(
            children: [
              // 标题栏（与 DataBackupPage / SongMaidataPage 同款写法）
              PageTopBar(
                title: '自定义谱面播放',
              ),

              // 主内容
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        '上传自定义谱面',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),

                      // 一键导入：直接从 .adx / .zip 谱面包里解出三件套
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.linkBlue(brightness).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.folder_zip_outlined,
                                    color: AppColors.linkBlue(brightness)),
                                const SizedBox(width: 8),
                                Text('从谱面包导入',
                                    style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('选择一个 .adx 或 .zip 谱面包，自动解出 maidata.txt / 曲绘 / 音源',
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontSize: 12)),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isImporting ? null : _pickChartPackage,
                                icon: _isImporting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.unarchive_outlined),
                                label: Text(_isImporting ? '正在解压...' : '选择谱面包'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.linkBlue(brightness),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (_history.isNotEmpty) ...[
                        _buildHistoryCard(brightness),
                        const SizedBox(height: 24),
                      ],

                      Text(
                        '或分别选择下面三个文件',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12),
                      ),
                      const SizedBox(height: 12),

                      _buildFileSelector(
                        title: '选择maidata.txt',
                        description: '必须选择，包含谱面数据的txt文件',
                        icon: Icons.description,
                        selectedFile: _maidataContent != null ? '已选择maidata文件' : null,
                        onPressed: _selectMaidataFile,
                        required: true,
                      ),
                      const SizedBox(height: 16),

                      _buildFileSelector(
                        title: '选择曲绘图片',
                        description: '可选，谱面背景图片（png/jpg）',
                        icon: Icons.image,
                        selectedFile: _bgImagePath?.split('\\').last,
                        onPressed: _selectBgImage,
                        required: false,
                      ),
                      const SizedBox(height: 16),

                      _buildFileSelector(
                        title: '选择音源文件',
                        description: '可选，谱面背景音乐（mp3/wav/ogg）',
                        icon: Icons.audio_file,
                        selectedFile: _audioFilePath?.split('\\').last,
                        onPressed: _selectAudioFile,
                        required: false,
                      ),
                      const SizedBox(height: 24),

                      if (_maidataContent != null && _inoteList.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('解析到的难度:', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                children: _inoteList.map((inote) {
                                  String difficultyName = inoteDifficultyMap[inote] ?? inote;
                                  Color inoteColor = Color(inoteColorMap[inote] ?? 0xFF9E9E9E);
                                  return Chip(
                                    label: Text(difficultyName),
                                    backgroundColor: inoteColor,
                                    labelStyle: const TextStyle(color: Colors.white),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),

                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _clearSelection,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                foregroundColor: Theme.of(context).colorScheme.onSurface,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('清除选择'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _startPlayback,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.linkBlue(Theme.of(context).brightness),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('开始播放'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('使用说明:', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('方式一：点「选择谱面包」直接选一个 .adx / .zip，三件套一次填好', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                            Text('方式二：点「最近解析」里的记录，一键重新解析之前用过的谱面包', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                            Text('方式三：分别选择 maidata.txt、曲绘、音源三个文件', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                            Text('1. maidata.txt 为必选，其余两个可留空', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                            Text('2. 系统会自动解析谱面中的难度', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                            Text('3. 选择想要渲染的难度后即可开始播放', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),

                      // 底部留给系统手势条
                      SizedBox(height: 10 + safeBottom),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFileSelector({
    required String title,
    required String description,
    required IconData icon,
    String? selectedFile,
    required VoidCallback onPressed,
    required bool required,
  }) {
    final fsBrightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selectedFile != null ? AppColors.successGreen(fsBrightness) : AppColors.tableBorder(fsBrightness)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: selectedFile != null ? AppColors.successGreen(fsBrightness) : AppColors.greyHint(fsBrightness)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
                        if (required) Text(' *', style: TextStyle(color: AppColors.errorRed(fsBrightness))),
                      ],
                    ),
                    Text(description, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          if (selectedFile != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('已选择: $selectedFile', style: TextStyle(color: AppColors.successGreen(fsBrightness), fontSize: 12), overflow: TextOverflow.ellipsis),
            ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.linkBlue(fsBrightness),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(selectedFile != null ? '重新选择' : '选择文件'),
          ),
        ],
      ),
    );
  }
}