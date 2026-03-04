import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/service/SongSearchService.dart';
import 'package:my_first_flutter_app/page/SongInfoPage.dart';
import 'dart:async';


class SongSearchPage extends StatefulWidget {
  const SongSearchPage({super.key});

  @override
  State<SongSearchPage> createState() => _SongSearchPageState();
}

class _SongSearchPageState extends State<SongSearchPage> {
  // 状态变量
  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  String? _errorMessage;
  TextEditingController _searchController = TextEditingController();
  Timer? _searchTimer;

  @override
  void dispose() {
    _searchController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  // 执行搜索
  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _errorMessage = null;
      });
      return;
    }

    try {
      setState(() {
        _isSearching = true;
        _errorMessage = null;
      });

      // 调用搜索服务
      final results = await SongSearchService.searchSongs(query);

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '搜索失败：$e';
        _isSearching = false;
      });
    }
  }

  // 防抖搜索
  void _debouncedSearch(String query) {
    // 取消之前的定时器
    _searchTimer?.cancel();
    
    // 设置新的定时器，300毫秒后执行搜索
    _searchTimer = Timer(const Duration(milliseconds: 1000), () {
      _performSearch(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false, // 防止键盘弹出时挤压背景
      body: Stack(
        children: [
          // 层级1：基础背景图 - 占满整个屏幕，作为页面最底层背景
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background.png'), // 背景图资源
                fit: BoxFit.cover, // 覆盖整个容器，拉伸/裁剪适配
                opacity: 1.0, // 不透明
              ),
            ),
          ),

          // 层级2：第一张虚化装饰图 - 居中显示，轻微向上偏移
          Center(
            child: Transform.translate(
              offset: const Offset(0, -20), // 垂直向上偏移20px
              child: Transform.scale(
                scale: 1, // 不缩放
                child: Image.asset(
                  'assets/chiffon2.png',
                  fit: BoxFit.cover,
                  opacity: const AlwaysStoppedAnimation(1), // 固定不透明
                ),
              ),
            ),
          ),

          // 页面标题
          const Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "歌曲搜索",
                style: TextStyle(
                  color: Color.fromARGB(255, 84, 97, 97),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),

          // 返回按钮
          Positioned(
            top: 40,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_back,
                  color: Color.fromARGB(255, 84, 97, 97), size: 24),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),

          // 主要内容区域
          Positioned(
            top: 120,
            left: 20,
            right: 20,
            bottom: 80,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8.0),
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
                  // 搜索输入框
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        // 防抖搜索
                        _debouncedSearch(value);
                      },
                      decoration: InputDecoration(
                        hintText: '输入歌曲标题、艺术家、BPM或谱师',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                    ),
                  ),

                  // 搜索结果区域
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 加载状态
                          if (_isSearching)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(40.0),
                                child: Column(
                                  children: [
                                    CircularProgressIndicator(
                                      color: Color.fromARGB(255, 84, 97, 97),
                                    ),
                                    SizedBox(height: 16),
                                    Text('正在搜索...'),
                                  ],
                                ),
                              ),
                            )
                          // 错误状态
                          else if (_errorMessage != null)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(40.0),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      color: Colors.red,
                                      size: 48,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _errorMessage!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          // 无结果状态
                          else if (_searchResults.isEmpty &&
                              _searchController.text.isNotEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(40.0),
                                child: Text(
                                  '未找到匹配的歌曲',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            )
                          // 展示搜索结果
                          else if (_searchResults.isNotEmpty)
                            Column(
                              children: _searchResults
                                  .map((song) => _buildSongItem(song))
                                  .toList(),
                            )
                          // 初始状态
                          else
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(40.0),
                                child: Text(
                                  '请输入搜索关键词',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 构建歌曲项
  Widget _buildSongItem(dynamic song) {
    // 生成曲绘URL
    String coverUrl =
        'https://www.diving-fish.com/covers/${song.id.toString().padLeft(5, '0')}.png';

    // 生成匹配信息
    String matchInfo = _getMatchInfo(song);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SongInfoPage(songId: song.id.toString()),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: Row(
          children: [
            // 曲绘
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Image.network(
                coverUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Text(
                      '曲绘',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),

            // 右侧信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 第一行：歌曲名和ID
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          song.basicInfo.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ID: ${song.id}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 第二行：版本、流派
                  Text(
                    '${_formatVersion(song.basicInfo.from)} | ${song.basicInfo.genre}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // 第三行：匹配信息
                  if (matchInfo.isNotEmpty)
                    Text(
                      matchInfo,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.blue,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 获取匹配信息
  String _getMatchInfo(dynamic song) {
    String query = _searchController.text.toLowerCase();
    if (query.isEmpty) return '';

    // 检查标题匹配
    if (song.basicInfo.title.toLowerCase().contains(query)) {
      return '匹配：歌曲标题';
    }
    // 检查艺术家匹配
    if (song.basicInfo.artist.toLowerCase().contains(query)) {
      return '匹配：艺术家';
    }
    // 检查BPM匹配
    if (song.basicInfo.bpm.toString().contains(query)) {
      return '匹配：BPM';
    }
    // 检查谱师匹配
    for (var chart in song.charts) {
      if (chart.charter.toLowerCase().contains(query)) {
        return '匹配：谱师';
      }
    }
    // 检查流派匹配
    if (song.basicInfo.genre.toLowerCase().contains(query)) {
      return '匹配：流派';
    }
    // 检查版本匹配
    if (song.basicInfo.from.toLowerCase().contains(query)) {
      return '匹配：版本';
    }
    return '';
  }

  // 处理版本字符串，使其在前端简化展示
  String _formatVersion(String version) {
    if (version == 'maimai') {
      return 'maimai';
    }
    if (version == 'maimai PLUS') {
      return 'maimai+';
    }
    if (version == 'maimai \u3067\u3089\u3063\u304f\u3059') {
      return 'DX';
    }
    if (version == 'maimai \u3067\u3089\u3063\u304f\u3059 PLUS') {
      return 'DX+';
    }
    if (version.contains(' PLUS')) {
      version = version.replaceFirst(' PLUS', '+');
    }
    if (version.contains('maimai') && version != 'maimai') {
      version = version.replaceFirst('maimai ', '');
    }
    if (version.contains('\u3067\u3089\u3063\u304f\u3059')) {
      version = version.replaceFirst('\u3067\u3089\u3063\u304f\u3059 ', '');
    }
    return version;
  }
}