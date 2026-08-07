import 'dart:convert';
import 'dart:io';
import 'package:charset/charset.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:path_provider/path_provider.dart';
import 'ChartPlayPage.dart';

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

  static const Map<String, String> inoteDifficultyMap = {
    '2': 'BASIC',
    '3': 'ADVANCED',
    '4': 'EXPERT',
    '5': 'MASTER',
    '6': 'RE:MASTER',
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

          // 自动检测编码：先尝试 UTF-8，失败则尝试 Shift-JIS（日谱社区常用编码）
          String content;
          try {
            content = utf8.decode(bytes);
            // 检查是否含有替换字符（解码失败标志）
            if (content.contains('�')) {
              throw const FormatException('UTF-8 decode produced replacement characters');
            }
          } catch (_) {
            // UTF-8 失败，尝试 Shift-JIS
            debugPrint('UTF-8 decode failed, trying Shift-JIS...');
            content = shiftJis.decode(bytes);
          }

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
                              songTitle: '自定义谱面',
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
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground(brightness),
      appBar: AppBar(
        title: const Text('自定义谱面播放'),
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              '上传自定义谱面',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

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
                  Text('1. 点击"选择maidata.txt"上传谱面数据文件', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  Text('2. 可选：上传曲绘图片和音源文件', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  Text('3. 系统会自动解析谱面中的难度', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  Text('4. 选择想要渲染的难度后即可开始播放', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
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