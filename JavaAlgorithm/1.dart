import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

// RA 筛选配置常量
const int MAX_LIMIT = 70; // 最大筛选数量
const int RA_RANGE_LIMIT = 20; // RA 极差上限

// 难度索引映射（level_index → sheet_difficulty）
final Map<int, String> LEVEL_INDEX_MAP = {
  0: "basic",
  1: "advanced",
  2: "expert",
  3: "master",
  4: "remaster",
};

// 谱面类型映射（type → sheet_type）
final Map<String, String> TYPE_MAP = {
  "SD": "std",
  "DX": "dx",
};

class RecommendByTags extends StatefulWidget {
  const RecommendByTags({super.key});

  @override
  State<RecommendByTags> createState() => _RecommendByTagsState();
}

class _RecommendByTagsState extends State<RecommendByTags> {
  // 状态管理
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, Map<String, int>> _tagCountMap = {};
  List<RecommendationResult> _best55Recommendations = [];
  List<RecommendationResult> _best15Recommendations = [];
  bool _showBest55 = true; // 默认显示Best55
  int _currentPage = 0; // 当前页码
  final int _pageSize = 10; // 每页显示10个数据

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  // 加载推荐数据
  Future<void> _loadRecommendations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 1.检查并下载 maiTags.json
      final String tagFileName = "maiTags.json";
      final File tagFile = File("${Directory.current.path}/$tagFileName");
      print("maiTags.json 文件路径: ${tagFile.path}");
      
      if (!await tagFile.exists()) {
        await downloadMaiTagsFile(tagFileName);
      }

       // 2.读取并筛选玩家游玩记录
      final String playDataFileName = "userPlayData.json";
      final File playDataFile = File("${Directory.current.path}/$playDataFileName");
      print("userPlayData.json 文件路径: ${playDataFile.path}");

      if (await playDataFile.exists()) {
        // 筛选 RA 数据
        final List<Record> filteredRecords = await filterRaData(playDataFile);
        if (filteredRecords.isNotEmpty) {
          // 按分组统计标签出现次数
          await countTagsByGroup(filteredRecords, tagFile);

          // 进行曲目推荐
          await recommendSongs(playDataFile, tagFile, filteredRecords);
        } else {
          _errorMessage = "未找到有效的RA数据";
        }
      } else {
        _errorMessage = "测试数据文件不存在，请先准备数据文件";
      }
    } catch (e) {
      _errorMessage = "加载失败：$e";
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 更新标签计数映射
  void _updateTagCountMap(Map<String, Map<String, int>> map) {
    setState(() {
      _tagCountMap = map;
    });
  }

  // 更新推荐结果
  void _updateRecommendations(List<RecommendationResult> best55, List<RecommendationResult> best15) {
    setState(() {
      _best55Recommendations = best55;
      _best15Recommendations = best15;
      _currentPage = 0; // 重置页码
    });
  }

  // 切换推荐类型
  void _toggleRecommendationType() {
    setState(() {
      _showBest55 = !_showBest55;
      _currentPage = 0; // 重置页码
    });
  }

  // 切换页码
  void _changePage(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  // 获取当前显示的推荐列表
  List<RecommendationResult> get _currentRecommendations {
    return _showBest55 ? _best55Recommendations : _best15Recommendations;
  }

  // 获取总页数
  int get _totalPages {
    final count = _currentRecommendations.length;
    return (count + _pageSize - 1) ~/ _pageSize;
  }

  // 获取当前页的数据
  List<RecommendationResult> get _currentPageData {
    final start = _currentPage * _pageSize;
    final end = start + _pageSize;
    if (start >= _currentRecommendations.length) return [];
    return _currentRecommendations.sublist(start, end > _currentRecommendations.length ? _currentRecommendations.length : end);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Stack(
          children: [
            // 层级1：基础背景图
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/background.png'),
                  fit: BoxFit.cover,
                  opacity: 1.0,
                ),
              ),
            ),

            // 层级2：第一张虚化装饰图
            Center(
              child: Transform.translate(
                offset: const Offset(0, -20),
                child: Transform.scale(
                  scale: 1,
                  child: Image.asset(
                    'assets/chiffon2.png',
                    fit: BoxFit.cover,
                    opacity: const AlwaysStoppedAnimation(1),
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
                  "根据标签推荐",
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
                icon: const Icon(Icons.arrow_back, color: Color.fromARGB(255, 84, 97, 97), size: 24),
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
              bottom: 20,
              child: Column(
                children: [
                  // 上方：标签统计区域
                  Expanded(
                    flex: 1,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
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
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _errorMessage.isNotEmpty
                              ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
                              : SingleChildScrollView(
                                  padding: const EdgeInsets.all(16.0),
                                  child: _buildTagCountSection(),
                                ),
                    ),
                  ),

                  // 切换按钮
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    child: ElevatedButton(
                      onPressed: _toggleRecommendationType,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _showBest55 ? Colors.blue : Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      ),
                      child: Text(_showBest55 ? "切换到 Best15 推荐" : "切换到 Best55 推荐"),
                    ),
                  ),

                  // 下方：推荐结果区域
                  Expanded(
                    flex: 2,
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
                          // 推荐标题
                          Container(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              _showBest55 ? "Best55 推荐结果" : "Best15 推荐结果",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),

                          // 推荐列表
                          Expanded(
                            child: _isLoading
                                ? const Center(child: CircularProgressIndicator())
                                : _errorMessage.isNotEmpty
                                    ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
                                    : _buildRecommendationList(),
                          ),

                          // 分页控件
                          if (!_isLoading && _errorMessage.isEmpty && _currentRecommendations.isNotEmpty)
                            _buildPagination(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建标签统计区域
  Widget _buildTagCountSection() {
    if (_tagCountMap.isEmpty) {
      return const Center(child: Text("未找到标签统计数据"));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "按分类统计各标签出现次数",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ..._tagCountMap.entries.map((entry) {
          final groupName = entry.key;
          final tagCountMap = entry.value;
          
          // 按出现次数降序排序
          final sortedTagEntries = tagCountMap.entries.toList()
            ..sort((e1, e2) => e2.value.compareTo(e1.value));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                groupName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: sortedTagEntries.map((tagEntry) {
                  return Chip(
                    label: Text(
                      "${tagEntry.key}: ${tagEntry.value}",
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Colors.blue[100],
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          );
        }).toList(),
      ],
    );
  }

  // 构建推荐列表
  Widget _buildRecommendationList() {
    final pageData = _currentPageData;
    
    if (pageData.isEmpty) {
      return const Center(child: Text("无推荐结果"));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: pageData.length,
      itemBuilder: (context, index) {
        final item = pageData[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8.0),
            color: Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.songTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    "相似度: ${item.similarity.toStringAsFixed(2)}",
                    style: const TextStyle(fontSize: 14, color: Colors.blue),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    "定数: ${item.difficulty.toStringAsFixed(1)}",
                    style: const TextStyle(fontSize: 14, color: Colors.green),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // 构建分页控件
  Widget _buildPagination() {
    final totalPages = _totalPages;
    if (totalPages <= 1) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _currentPage > 0 ? () => _changePage(_currentPage - 1) : null,
            icon: const Icon(Icons.chevron_left),
            disabledColor: Colors.grey[300],
          ),
          ...List.generate(totalPages, (index) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: ElevatedButton(
                onPressed: () => _changePage(index),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _currentPage == index ? Colors.blue : Colors.grey[200],
                  foregroundColor: _currentPage == index ? Colors.white : Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text((index + 1).toString()),
              ),
            );
          }),
          IconButton(
            onPressed: _currentPage < totalPages - 1 ? () => _changePage(_currentPage + 1) : null,
            icon: const Icon(Icons.chevron_right),
            disabledColor: Colors.grey[300],
          ),
        ],
      ),
    );
  }
}

/// 修复：HttpClientResponse 转字节数组（替代不存在的 toBytes 方法）
Future<Uint8List> responseToBytes(HttpClientResponse response) async {
  final bytesBuilder = BytesBuilder();
  await for (var chunk in response) {
    bytesBuilder.add(chunk);
  }
  return bytesBuilder.toBytes();
}

/// 下载 maiTags.json 文件（修复 toBytes 方法问题）
Future<void> downloadMaiTagsFile(String fileName) async {
  final String url = "https://derrakuma.dxrating.net/functions/v1/combined-tags";
  
  final Map<String, String> headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxidHBubWRmZnVpbWlra3Nydm5zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MDYwMzMxNzAsImV4cCI6MjAyMTYwOTE3MH0.rrzOisCZGz2gkp-yh61-_HDY7YqL3lTc4XsOPzuAVDU",
    "authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxidHBubWRmZnVpbWlra3Nydm5zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MDYwMzMxNzAsImV4cCI6MjAyMTYwOTE3MH0.rrzOisCZGz2gkp-yh61-_HDY7YqL3lTc4XsOPzuAVDU",
    "origin": "https://dxrating.net",
    "referer": "https://dxrating.net/",
    "x-client-info": "supabase-js-web/2.49.1",
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36 Edg/131.0.0.0",
    "Accept": "*/*",
    "Accept-Encoding": "gzip, deflate, br",
    "Accept-Language": "zh-CN,zh;q=0.9,en-GB;q=0.8,en-US;q=0.7,en;q=0.6",
  };

  try {
    final HttpClient client = HttpClient();
    final HttpClientRequest request = await client.postUrl(Uri.parse(url));
    headers.forEach((key, value) => request.headers.add(key, value));
    
    final HttpClientResponse response = await request.close();
    print("状态码: ${response.statusCode}");
    print("响应头: ${response.headers}");

    // 修复：使用自定义的 responseToBytes 方法替代 toBytes()
    List<int> responseBytes = await responseToBytes(response);
    final String? contentEncoding = response.headers.value("content-encoding");
    
    if (contentEncoding != null) {
      switch (contentEncoding.toLowerCase()) {
        case "gzip":
          responseBytes = gzip.decode(responseBytes);
          break;
        case "br":
          // Dart 标准库不直接支持 brotli，需额外依赖：pub add brotli
          // import 'package:brotli/brotli.dart';
          // responseBytes = brotli.decode(responseBytes);
          break;
        case "deflate":
          responseBytes = zlib.decode(responseBytes);
          break;
      }
    }

    final String body = utf8.decode(responseBytes);
    print("响应内容（前500字符）: ${body.length > 500 ? body.substring(0, 500) : body}");

    final File file = File(fileName);
    await file.writeAsString(body, encoding: utf8);
    print("✅ 完整响应已以 UTF-8 编码保存到 $fileName");

  } catch (e) {
    print("请求失败: $e");
  }
}

/// 筛选 RA 数据核心逻辑（修复 JSON 类型不匹配问题）
Future<List<Record>> filterRaData(File playDataFile) async {
  final List<Record> filteredRecords = [];
  try {
    // 读取并解析玩家游玩记录 JSON
    final String jsonContent = await playDataFile.readAsString(encoding: utf8);
    final dynamic rootNode = json.decode(jsonContent); // 修复：先定义为 dynamic 避免类型错误

    // 提取 records 数组（修复：兼容 Map/List 两种根节点）
    List<dynamic> recordsNode = [];
    if (rootNode is Map<String, dynamic> && rootNode.containsKey("records") && rootNode["records"] is List) {
      recordsNode = rootNode["records"] as List<dynamic>;
    } else if (rootNode is List<dynamic>) {
      recordsNode = rootNode;
    } else {
      print("❌ JSON 文件中未找到有效的 records 数组");
      return filteredRecords;
    }

    // 转换为 Record 列表并过滤无效数据
    final List<Record> recordList = [];
    for (final node in recordsNode) {
      if (node is Map<String, dynamic> && node.containsKey("ra") && node["ra"] is num) {
        final Record record = Record(
          achievements: node.containsKey("achievements") ? (node["achievements"] as num).toDouble() : 0.0,
          ds: node.containsKey("ds") ? (node["ds"] as num).toDouble() : 0.0,
          dxScore: node.containsKey("dxScore") ? (node["dxScore"] as int) : 0,
          fc: node.containsKey("fc") ? (node["fc"] as String) : "",
          fs: node.containsKey("fs") ? (node["fs"] as String) : "",
          level: node.containsKey("level") ? (node["level"] as String) : "",
          levelIndex: node.containsKey("level_index") ? (node["level_index"] as int) : 0,
          levelLabel: node.containsKey("level_label") ? (node["level_label"] as String) : "",
          ra: (node["ra"] as num).toInt(),
          rate: node.containsKey("rate") ? (node["rate"] as String) : "",
          songId: node.containsKey("song_id") ? (node["song_id"] as int) : 0,
          title: node.containsKey("title") ? (node["title"] as String) : "",
          type: node.containsKey("type") ? (node["type"] as String) : "",
        );
        recordList.add(record);
      }
    }

    if (recordList.isEmpty) {
      print("❌ 未找到有效 RA 数据的 records");
      return filteredRecords;
    }

    // 按 RA 降序排序
    recordList.sort((r1, r2) => r2.ra.compareTo(r1.ra));

    // 取前 MAX_LIMIT 个数据
    final List<Record> top100Records = recordList.take(MAX_LIMIT).toList();

    // 筛选 RA 极差 ≤ 20 的数据
    final int maxRa = top100Records.first.ra;
    final int minRaThreshold = maxRa - RA_RANGE_LIMIT;

    for (final record in top100Records) {
      if (record.ra >= minRaThreshold) {
        filteredRecords.add(record);
      } else {
        break;
      }
    }

    // 输出筛选结果
    print("✅ RA 筛选结果统计：");
    print("   最大 RA：$maxRa");
    print("   最小 RA：${filteredRecords.isEmpty ? 0 : filteredRecords.last.ra}");
    print("   RA 极差：${filteredRecords.isEmpty ? 0 : maxRa - filteredRecords.last.ra}");
    print("   筛选数量：${filteredRecords.length}");
    print("----------------------------------------");

    // 打印排名信息
    for (int i = 0; i < filteredRecords.length; i++) {
      final Record r = filteredRecords[i];
      print("排名 ${i + 1} | RA: ${r.ra} | 标题: ${r.title} | 难度: ${r.level} | FC: ${r.fc}");
    }

    // 保存筛选结果到文件
    final File filteredFile = File("filtered_records.json");
    final String filteredJson = json.encode(filteredRecords.map((e) => e.toJson()).toList());
    await filteredFile.writeAsString(filteredJson, encoding: utf8);
    print("----------------------------------------");
    print("✅ 筛选结果已保存到 filtered_records.json");

  } catch (e) {
    print("❌ 筛选 RA 数据失败：$e");
  }
  return filteredRecords;
}

/// 按分组统计筛选后谱面中各标签的出现次数
Future<void> countTagsByGroup(List<Record> filteredRecords, File tagFile) async {
  try {
    // 1. 读取并解析 maiTags.json
    final String tagJson = await tagFile.readAsString(encoding: utf8);
    final dynamic tagRootNode = json.decode(tagJson); // 修复：先定义为 dynamic

    // 第一步：构建 分组ID → 分组名称 的映射
    final Map<int, String> groupIdToNameMap = {};
    final List<dynamic>? tagGroupsNode = tagRootNode is Map<String, dynamic> 
        ? tagRootNode["tagGroups"] as List<dynamic>? 
        : null;
    
    if (tagGroupsNode == null) {
      print("❌ maiTags.json 中未找到有效的 tagGroups 数组");
      return;
    }

    for (final groupNode in tagGroupsNode) {
      if (groupNode is Map<String, dynamic>) {
        final int groupId = groupNode["id"] as int? ?? -1;
        if (groupId == -1) continue;

        // 获取分组中文名称（优先 zh-Hans）
        String groupName = "";
        final Map<String, dynamic>? localizedName = groupNode["localized_name"] as Map<String, dynamic>?;
        if (localizedName != null) {
          if (localizedName.containsKey("zh-Hans")) {
            groupName = (localizedName["zh-Hans"] as String).trim();
          } else if (localizedName.containsKey("en")) {
            groupName = (localizedName["en"] as String).trim();
          }
        }

        if (groupName.isNotEmpty) {
          groupIdToNameMap[groupId] = groupName;
        }
      }
    }

    // 第二步：构建 标签ID → (标签名称, 分组ID) 的映射
    final Map<int, TagInfo> tagIdToInfoMap = {};
    final List<dynamic>? tagsNode = tagRootNode is Map<String, dynamic>
        ? tagRootNode["tags"] as List<dynamic>?
        : null;
    
    if (tagsNode == null) {
      print("❌ maiTags.json 中未找到有效的 tags 数组");
      return;
    }

    for (final tagNode in tagsNode) {
      if (tagNode is Map<String, dynamic>) {
        final int tagId = tagNode["id"] as int? ?? -1;
        final int groupId = tagNode["group_id"] as int? ?? -1;
        if (tagId == -1 || groupId == -1) continue;

        // 获取标签中文名称
        String tagName = "";
        final Map<String, dynamic>? localizedName = tagNode["localized_name"] as Map<String, dynamic>?;
        if (localizedName != null && localizedName.containsKey("zh-Hans")) {
          tagName = (localizedName["zh-Hans"] as String).trim();
        }
        if (tagName.isEmpty) continue;

        // 存储标签信息
        tagIdToInfoMap[tagId] = TagInfo(tagName, groupId);
      }
    }

    // 第三步：构建 谱面标识 → 标签ID列表 的映射
    final Map<String, List<int>> songToTagIdsMap = {};
    final List<dynamic>? tagSongsNode = tagRootNode is Map<String, dynamic>
        ? tagRootNode["tagSongs"] as List<dynamic>?
        : null;
    
    if (tagSongsNode == null) {
      print("❌ maiTags.json 中未找到有效的 tagSongs 数组");
      return;
    }

    for (final tagSongNode in tagSongsNode) {
      if (tagSongNode is Map<String, dynamic>) {
        final String songId = (tagSongNode["song_id"] as String?)?.trim() ?? "";
        final String sheetType = (tagSongNode["sheet_type"] as String?)?.trim() ?? "";
        final String sheetDifficulty = (tagSongNode["sheet_difficulty"] as String?)?.trim() ?? "";
        final int tagId = tagSongNode["tag_id"] as int? ?? -1;

        if (songId.isEmpty || sheetType.isEmpty || sheetDifficulty.isEmpty || tagId == -1) {
          continue;
        }

        final String songKey = "$songId#$sheetType#$sheetDifficulty";
        if (!songToTagIdsMap.containsKey(songKey)) {
          songToTagIdsMap[songKey] = [];
        }
        songToTagIdsMap[songKey]!.add(tagId);
      }
    }

    // 第四步：遍历筛选后的RA谱面，按分组统计标签出现次数
    final Map<String, Map<String, int>> groupTagCountMap = {};
    final Set<String> processedSongKeys = {};

    for (final record in filteredRecords) {
      final String songTitle = record.title.trim();
      final String sheetType = TYPE_MAP[record.type.trim()] ?? "";
      final String sheetDifficulty = LEVEL_INDEX_MAP[record.levelIndex] ?? "";

      if (songTitle.isEmpty || sheetType.isEmpty || sheetDifficulty.isEmpty) {
        print("⚠️ 谱面 $songTitle（类型：${record.type}，难度索引：${record.levelIndex}）字段不完整，跳过标签统计");
        continue;
      }

      final String songKey = "$songTitle#$sheetType#$sheetDifficulty";
      if (processedSongKeys.contains(songKey)) {
        continue;
      }
      processedSongKeys.add(songKey);

      // 获取该谱面的所有标签ID
      final List<int> tagIds = songToTagIdsMap[songKey] ?? [];
      for (final tagId in tagIds) {
        final TagInfo? tagInfo = tagIdToInfoMap[tagId];
        if (tagInfo == null) continue;

        // 获取分组名称
        final String groupName = groupIdToNameMap[tagInfo.groupId] ?? "未知分组";
        // 初始化分组的标签统计Map
        if (!groupTagCountMap.containsKey(groupName)) {
          groupTagCountMap[groupName] = {};
        }
        final Map<String, int> tagCountMap = groupTagCountMap[groupName]!;

        // 累加标签出现次数
        tagCountMap[tagInfo.tagName] = (tagCountMap[tagInfo.tagName] ?? 0) + 1;
      }
    }

    // 第五步：输出统计结果
    print("✅ 按分组统计标签出现次数（筛选后RA谱面）：");
    print("----------------------------------------");
    
    for (final MapEntry<String, Map<String, int>> groupEntry in groupTagCountMap.entries) {
      final String groupName = groupEntry.key;
      final Map<String, int> tagCountMap = groupEntry.value;

      // 按出现次数降序排序
      final List<MapEntry<String, int>> sortedTagEntries = tagCountMap.entries.toList()
        ..sort((e1, e2) => e2.value.compareTo(e1.value));

      // 拼接输出字符串
      final String tagStr = sortedTagEntries
        .map((e) => "${e.key} - ${e.value}")
        .join(" | ");

      print("$groupName：$tagStr");
    }

    // 补充统计信息
    print("----------------------------------------");
    print("参与统计的唯一谱面数：${processedSongKeys.length}");
    
    int totalTagType = 0;
    int totalTagCount = 0;
    for (final Map<String, int> tagCountMap in groupTagCountMap.values) {
      totalTagType += tagCountMap.length;
      totalTagCount += tagCountMap.values.fold(0, (sum, val) => sum + val);
    }
    
    print("总标签种类数：$totalTagType");
    print("所有标签总出现次数：$totalTagCount");

    // 更新UI状态
    final state = WidgetsBinding.instance.focusManager.primaryFocus?.context?.findAncestorStateOfType<_RecommendByTagsState>();
    if (state != null) {
      state._updateTagCountMap(groupTagCountMap);
    }

  } catch (e) {
    print("❌ 按分组统计标签出现次数失败：$e");
  }
}

/// 推荐算法实现
Future<void> recommendSongs(File playDataFile, File tagFile, List<Record> filteredRecords) async {
  try {
    // 1. 检查筛选数据
    print("(1) 使用已筛选的玩家单曲Rating前70位数据...");
    if (filteredRecords.isEmpty) {
      print("❌ 没有足够的有效数据进行推荐");
      return;
    }

    // 2. 计算玩家能力向量
    print("(2) 根据标签的出现频率计算玩家的能力向量...");
    final Map<String, Map<String, double>> playerAbilityVectors = 
      await calculatePlayerAbilityVectors(filteredRecords, tagFile);
    
    // 输出向量信息
    print("\n========================================");
    print("玩家能力向量分析：");
    print("========================================");
    print("配置向量 (group_id=1) 维度: ${playerAbilityVectors["config"]?.length ?? 0}");
    print("难度向量 (group_id=2) 维度: ${playerAbilityVectors["difficulty"]?.length ?? 0}");
    print("评价向量 (group_id=3) 维度: ${playerAbilityVectors["evaluation"]?.length ?? 0}");
    print("========================================");
    print("能力向量计算完成！");
    print("========================================");

    // 3. 获取Best55、Best35、Best15数据
    print("(3) 获取玩家的Best55和Best15数据...");
    final List<Record> allRecords = await getAllRecords(playDataFile);
    final List<Record> best55 = getBestNRecords(allRecords, 55, false);
    final List<Record> best35 = getBestNRecords(best55, 35, false);
    final List<Record> best15 = getBestNRecords(allRecords, 15, true);
    
    // 输出调试信息
    print("\n========================================");
    print("调试信息 - Best55数据：");
    print("========================================");
    showRecords(best55, "Best55");
    
    print("\n========================================");
    print("调试信息 - Best35数据：");
    print("========================================");
    showRecords(best35, "Best35");
    
    print("\n========================================");
    print("调试信息 - Best15数据：");
    print("========================================");
    showRecords(best15, "Best15");

    // 4. 获取Rating范围
    print("(4) 获取Best55、Best35和Best15的单曲Rating范围...");
    final RaRange best55Range = getRaRange(best55);
    final RaRange best35Range = getRaRange(best35);
    final RaRange best15Range = getRaRange(best15);
    
    // 输出Rating范围
    print("\n========================================");
    print("Rating范围分析：");
    print("========================================");
    print("Best55 Rating范围: ${best55Range.minRa} — ${best55Range.maxRa}");
    print("Best35 Rating范围: ${best35Range.minRa} — ${best35Range.maxRa}");
    print("Best15 Rating范围: ${best15Range.minRa} — ${best15Range.maxRa}");
    print("========================================");

    // 5. 定位定数范围
    print("(5) 根据Rating范围定位到可供上分的定数范围...");
    final DifficultyRange best55DiffRange = getDifficultyRange(best35Range);
    final DifficultyRange best15DiffRange = getDifficultyRange(best15Range);

    // 6. 计算推荐结果
    print("(6) 计算谱面考察点向量并进行相似度计算...");
    
    // 6.1 Best55推荐
    print("(6.1) 计算Best55推荐结果...");
    final List<RecommendationResult> best55Recommendations = await calculateRecommendations(
      allRecords, tagFile, playerAbilityVectors, best55DiffRange, false
    );
    
    // 6.2 Best15推荐
    print("(6.2) 计算Best15推荐结果...");
    final List<RecommendationResult> best15Recommendations = await calculateRecommendations(
      allRecords, tagFile, playerAbilityVectors, best15DiffRange, true
    );

    // 7. 展现推荐结果
    print("(7) 展现推荐结果...");
    
    print("(7.1) 展现Best55推荐结果...");
    showRecommendations(best55Recommendations, "Best55");
    
    print("(7.2) 展现Best15推荐结果...");
    showRecommendations(best15Recommendations, "Best15");

    // 8. 输出定数范围
    print("(8) 输出合适的定数范围...");
    showDifficultyRange(best55DiffRange, "Best55");
    showDifficultyRange(best15DiffRange, "Best15");

    // 更新UI状态
    final state = WidgetsBinding.instance.focusManager.primaryFocus?.context?.findAncestorStateOfType<_RecommendByTagsState>();
    if (state != null) {
      state._updateRecommendations(best55Recommendations, best15Recommendations);
    }

  } catch (e) {
    print("❌ 推荐算法执行失败：$e");
  }
}

/// 获取所有记录（修复 JSON 类型不匹配）
Future<List<Record>> getAllRecords(File playDataFile) async {
  final List<Record> records = [];
  try {
    final String jsonContent = await playDataFile.readAsString(encoding: utf8);
    final dynamic rootNode = json.decode(jsonContent); // 修复：定义为 dynamic

    List<dynamic> recordsNode = [];
    if (rootNode is Map<String, dynamic> && rootNode.containsKey("records") && rootNode["records"] is List) {
      recordsNode = rootNode["records"] as List<dynamic>;
    } else if (rootNode is List<dynamic>) {
      recordsNode = rootNode;
    } else {
      return records;
    }

    for (final node in recordsNode) {
      if (node is Map<String, dynamic> && node.containsKey("ra") && node["ra"] is num) {
        final Record record = Record(
          achievements: node.containsKey("achievements") ? (node["achievements"] as num).toDouble() : 0.0,
          ds: node.containsKey("ds") ? (node["ds"] as num).toDouble() : 0.0,
          dxScore: node.containsKey("dxScore") ? (node["dxScore"] as int) : 0,
          fc: node.containsKey("fc") ? (node["fc"] as String) : "",
          fs: node.containsKey("fs") ? (node["fs"] as String) : "",
          level: node.containsKey("level") ? (node["level"] as String) : "",
          levelIndex: node.containsKey("level_index") ? (node["level_index"] as int) : 0,
          levelLabel: node.containsKey("level_label") ? (node["level_label"] as String) : "",
          ra: (node["ra"] as num).toInt(),
          rate: node.containsKey("rate") ? (node["rate"] as String) : "",
          songId: node.containsKey("song_id") ? (node["song_id"] as int) : 0,
          title: node.containsKey("title") ? (node["title"] as String) : "",
          type: node.containsKey("type") ? (node["type"] as String) : "",
        );
        records.add(record);
      }
    }
  } catch (e) {
    print("❌ 读取所有记录失败：$e");
  }
  return records;
}

/// 获取前N个记录（修复 JSON 解析类型问题）
List<Record> getBestNRecords(List<Record> records, int n, bool isNewOnly) {
  try {
    // 读取maimai_music_data.json
    final File musicDataFile = File("${Directory.current.path}/maimai_music_data.json");
    if (!musicDataFile.existsSync()) {
      print("⚠️ maimai_music_data.json 文件不存在，使用默认排序");
      return records.toList()
        ..sort((r1, r2) => r2.ra.compareTo(r1.ra))
        ..take(n)
        .toList();
    }

    final String musicJson = musicDataFile.readAsStringSync(encoding: utf8);
    final dynamic musicDataRoot = json.decode(musicJson);
    final List<dynamic> musicDataArray = musicDataRoot is List<dynamic> 
        ? musicDataRoot 
        : [];
    
    // 构建songId到isNew的映射
    final Map<int, bool> songIdToIsNewMap = {};
    for (final songNode in musicDataArray) {
      if (songNode is Map<String, dynamic> && songNode.containsKey("id") && songNode.containsKey("basic_info")) {
        try {
          final dynamic idValue = songNode["id"];
          final int songId = idValue is String ? int.parse(idValue) : (idValue as int);
          final Map<String, dynamic> basicInfo = songNode["basic_info"] as Map<String, dynamic>;
          final bool isNew = basicInfo.containsKey("is_new") && basicInfo["is_new"] as bool;
          songIdToIsNewMap[songId] = isNew;
        } catch (_) {
          // 跳过非数字ID
          continue;
        }
      }
    }
    
    // 过滤并排序
    return records.where((record) {
      final bool? isNew = songIdToIsNewMap[record.songId];
      if (!isNewOnly) {
        // Best55：只包含is_new为false的歌曲
        return isNew != null && !isNew;
      } else {
        // Best15：只包含is_new为true的歌曲
        return isNew != null && isNew;
      }
    }).toList()
      ..sort((r1, r2) => r2.ra.compareTo(r1.ra))
      ..take(n)
      .toList();
  } catch (e) {
      print("❌ 读取音乐数据失败：$e");
    // 出错时返回所有记录的前N个
    return records.toList()
      ..sort((r1, r2) => r2.ra.compareTo(r1.ra))
      ..take(n)
      .toList();
  }
}

/// 获取Rating范围
RaRange getRaRange(List<Record> records) {
  if (records.isEmpty) {
    return RaRange(0, 0);
  }
  
  int minRa = records.first.ra;
  int maxRa = records.first.ra;
  
  for (final record in records) {
    if (record.ra < minRa) minRa = record.ra;
    if (record.ra > maxRa) maxRa = record.ra;
  }
  
  return RaRange(minRa, maxRa);
}

/// 计算玩家能力向量（占位实现，需补充完整逻辑）
Future<Map<String, Map<String, double>>> calculatePlayerAbilityVectors(
  List<Record> filteredRecords, File tagFile
) async {
  // 此处为占位实现，需根据实际业务逻辑补充
  return {
    "config": {},
    "difficulty": {},
    "evaluation": {},
  };
}

/// 计算推荐结果（占位实现，需补充完整逻辑）
Future<List<RecommendationResult>> calculateRecommendations(
  List<Record> allRecords,
  File tagFile,
  Map<String, Map<String, double>> playerAbilityVectors,
  DifficultyRange diffRange,
  bool isNewOnly
) async {
  // 此处为占位实现，需根据实际业务逻辑补充
  return [];
}

/// 展示记录列表
void showRecords(List<Record> records, String title) {
  if (records.isEmpty) {
    print("$title 无数据");
    return;
  }
  
  for (int i = 0; i < records.length; i++) {
    final Record r = records[i];
    print("排名 ${i+1} | RA: ${r.ra} | 标题: ${r.title} | 定数: ${r.ds}");
  }
}

/// 展示推荐结果
void showRecommendations(List<RecommendationResult> recommendations, String title) {
  if (recommendations.isEmpty) {
    print("$title 无推荐结果");
    return;
  }
  
  print("$title 推荐列表：");
  for (int i = 0; i < recommendations.length; i++) {
    final RecommendationResult res = recommendations[i];
    print("推荐 ${i+1} | 标题: ${res.songTitle} | 相似度: ${res.similarity.toStringAsFixed(2)} | 定数: ${res.difficulty}");
  }
}

/// 展示定数范围
void showDifficultyRange(DifficultyRange range, String title) {
  print("$title 推荐定数范围：${range.minDiff.toStringAsFixed(1)} — ${range.maxDiff.toStringAsFixed(1)}");
}

/// 获取定数范围（占位实现，需补充完整逻辑）
DifficultyRange getDifficultyRange(RaRange raRange) {
  // 根据Rating计算定数范围的核心逻辑
  return DifficultyRange(
    (raRange.minRa / 22.4).floorToDouble(),
    (raRange.maxRa / 21.6).ceilToDouble()
  );
}

// 数据模型类

/// 游玩记录实体
class Record {
  final double achievements;
  final double ds;
  final int dxScore;
  final String fc;
  final String fs;
  final String level;
  final int levelIndex;
  final String levelLabel;
  final int ra;
  final String rate;
  final int songId;
  final String title;
  final String type;

  Record({
    required this.achievements,
    required this.ds,
    required this.dxScore,
    required this.fc,
    required this.fs,
    required this.level,
    required this.levelIndex,
    required this.levelLabel,
    required this.ra,
    required this.rate,
    required this.songId,
    required this.title,
    required this.type,
  });

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      "achievements": achievements,
      "ds": ds,
      "dxScore": dxScore,
      "fc": fc,
      "fs": fs,
      "level": level,
      "level_index": levelIndex,
      "level_label": levelLabel,
      "ra": ra,
      "rate": rate,
      "song_id": songId,
      "title": title,
      "type": type,
    };
  }
}

/// 标签信息实体
class TagInfo {
  final String tagName;
  final int groupId;

  TagInfo(this.tagName, this.groupId);
}

/// Rating范围实体
class RaRange {
  final int minRa;
  final int maxRa;

  RaRange(this.minRa, this.maxRa);
}

/// 难度（定数）范围实体
class DifficultyRange {
  final double minDiff;
  final double maxDiff;

  DifficultyRange(this.minDiff, this.maxDiff);
}

/// 推荐结果实体
class RecommendationResult {
  final String songTitle;
  final double similarity;
  final double difficulty;

  RecommendationResult({
    required this.songTitle,
    required this.similarity,
    required this.difficulty,
  });
}