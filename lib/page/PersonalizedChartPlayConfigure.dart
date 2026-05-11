import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'ChartPlayPage.dart';

class PersonalizedChartPlayConfigure extends StatefulWidget {
  const PersonalizedChartPlayConfigure({super.key});

  @override
  State<PersonalizedChartPlayConfigure> createState() => _PersonalizedChartPlayConfigureState();
}

class _PersonalizedChartPlayConfigureState extends State<PersonalizedChartPlayConfigure> {
  String? _maidataContent;
  File? _bgImageFile;
  File? _audioFile;
  List<String> _inoteList = [];

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

  Future<void> _selectMaidataFile() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );
    if (result != null) {
      File file = File(result.files.single.path!);
      try {
        String content = await file.readAsString();
        setState(() {
          _maidataContent = content;
          _inoteList = _parseInoteList(content);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已加载maidata，解析到 ${_inoteList.length} 个难度')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('读取失败: $e')),
        );
      }
    }
  }

  Future<void> _selectBgImage() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.image,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
    );
    if (result != null) {
      setState(() {
        _bgImageFile = File(result.files.single.path!);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已选择曲绘')),
      );
    }
  }

  Future<void> _selectAudioFile() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.audio,
      allowedExtensions: ['mp3', 'wav', 'ogg'],
    );
    if (result != null) {
      setState(() {
        _audioFile = File(result.files.single.path!);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已选择音源')),
      );
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
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    '渲染出的谱面仅供参考，不代表官方谱面。对于高密度谱面，请勿频繁拖动进度条，以免造成应用闪退或卡死。',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
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
      _bgImageFile = null;
      _audioFile = null;
      _inoteList = [];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已清除选择')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('自定义谱面播放'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              '上传自定义谱面',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
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
              selectedFile: _bgImageFile?.path.split('\\').last,
              onPressed: _selectBgImage,
              required: false,
            ),
            const SizedBox(height: 16),

            _buildFileSelector(
              title: '选择音源文件',
              description: '可选，谱面背景音乐（mp3/wav/ogg）',
              icon: Icons.audio_file,
              selectedFile: _audioFile?.path.split('\\').last,
              onPressed: _selectAudioFile,
              required: false,
            ),
            const SizedBox(height: 24),

            if (_maidataContent != null && _inoteList.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('解析到的难度:', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
                      backgroundColor: Colors.grey[700],
                      foregroundColor: Colors.white,
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
                      backgroundColor: Colors.blue,
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
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('使用说明:', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('1. 点击"选择maidata.txt"上传谱面数据文件', style: TextStyle(color: Colors.grey)),
                  Text('2. 可选：上传曲绘图片和音源文件', style: TextStyle(color: Colors.grey)),
                  Text('3. 系统会自动解析谱面中的难度', style: TextStyle(color: Colors.grey)),
                  Text('4. 选择想要渲染的难度后即可开始播放', style: TextStyle(color: Colors.grey)),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selectedFile != null ? Colors.green : Colors.grey[600]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: selectedFile != null ? Colors.green : Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        if (required) const Text(' *', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                    Text(description, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          if (selectedFile != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('已选择: $selectedFile', style: const TextStyle(color: Colors.green, fontSize: 12), overflow: TextOverflow.ellipsis),
            ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
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