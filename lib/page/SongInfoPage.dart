import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class SongInfoPage extends StatefulWidget {
  final String songId;

  const SongInfoPage({super.key, required this.songId});

  @override
  State<SongInfoPage> createState() => _SongInfoPageState();
}

class _SongInfoPageState extends State<SongInfoPage> {
  // 数据加载状态
  bool _isLoading = true;
  Map<String, dynamic>? _songData;
  Map<String, dynamic>? _diffData;
  Map<String, dynamic>? _userData;
  List<dynamic>? _tagData;
  
  // 当前选中的难度索引
  int _currentDiffIndex = 3; // 默认选中Master难度
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // 加载所有数据
  Future<void> _loadData() async {
    try {
      // 加载歌曲基础数据
      final songData = await rootBundle.loadString('assets/maimai_music_data.json');
      final List<dynamic> songList = json.decode(songData);
      _songData = songList.firstWhere(
        (song) => song['id'] == widget.songId,
        orElse: () => null
      );
      
      // 加载难度数据
      final diffData = await rootBundle.loadString('assets/SongDiffData.json');
      final Map<String, dynamic> diffMap = json.decode(diffData);
      _diffData = diffMap['charts'][widget.songId];
      
      // 加载用户数据
      final userData = await rootBundle.loadString('assets/userPlayData.json');
      final Map<String, dynamic> userMap = json.decode(userData);
      _userData = userMap;
      
      // 加载标签数据
      final tagData = await rootBundle.loadString('assets/maiTags.json');
      final Map<String, dynamic> tagMap = json.decode(tagData);
      _tagData = tagMap['tags'];
      
    } catch (e) {
      print('加载数据失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 获取用户最佳成绩
  Map<String, dynamic>? _getUserBestRecord() {
    if (_userData == null || _songData == null) return null;
    
    final records = _userData!['records'];
    if (records == null) return null;
    
    // 找到对应歌曲的记录
    final songRecords = records.where((record) => 
      record['song_id'].toString() == widget.songId
    ).toList();
    
    if (songRecords.isEmpty) return null;
    
    // 按达成率排序，取最高的
    songRecords.sort((a, b) => b['achievements'].compareTo(a['achievements']));
    return songRecords.first;
  }

  // 获取标签分组
  Map<String, List<dynamic>> _getTagsByGroup() {
    final Map<String, List<dynamic>> groupedTags = {
      '配置': [],
      '评价': [],
      '难度': []
    };
    
    if (_tagData != null) {
      for (var tag in _tagData!) {
        int groupId = tag['group_id'] ?? 0;
        String groupName;
        
        switch (groupId) {
          case 1:
            groupName = '配置';
            break;
          case 2:
            groupName = '评价';
            break;
          case 3:
            groupName = '难度';
            break;
          default:
            groupName = '配置';
        }
        
        if (groupedTags.containsKey(groupName)) {
          groupedTags[groupName]!.add(tag);
        }
      }
    }
    
    return groupedTags;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _songData == null) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final basicInfo = _songData!['basic_info'];
    final charts = _songData!['charts'];
    final levels = _songData!['level'];
    final currentChart = charts[_currentDiffIndex];
    final currentDiffData = _diffData != null && _diffData!.length > _currentDiffIndex 
        ? _diffData![_currentDiffIndex] 
        : null;
    final userRecord = _getUserBestRecord();
    final groupedTags = _getTagsByGroup();

    // 生成曲绘URL
    String coverUrl = 'https://www.diving-fish.com/covers/${widget.songId.padLeft(5, '0')}.png';

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
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
                "歌曲详情",
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 卡片区域
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFE9D8FF),
                            Color(0xFFD4BFFF),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 歌曲信息头部
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 封面
                              Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    coverUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey.shade200,
                                        child: Center(
                                          child: Text(
                                            '曲绘',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              
                              const SizedBox(width: 16),
                              
                              // 歌曲信息
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      basicInfo['title'],
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2D1B69),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    
                                    const SizedBox(height: 12),
                                    
                                    // 信息项
                                    _buildInfoItem('类别', basicInfo['genre']),
                                    _buildInfoItem('BPM', basicInfo['bpm'].toString()),
                                    _buildInfoItem('版本', _formatVersion(basicInfo['from'])),
                                    _buildInfoItem('曲师', basicInfo['artist'].split('/').last),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // 难度标签页
                          Row(
                            children: List.generate(
                              levels.length,
                              (index) => Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _currentDiffIndex = index;
                                    });
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      color: _currentDiffIndex == index
                                          ? Color(0xFF9966CC)
                                          : Color(0xFFF0E6FF),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _getDiffLabel(index),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: _currentDiffIndex == index
                                                ? Colors.white
                                                : Color(0xFF664499),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Lv.${levels[index]}',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: _currentDiffIndex == index
                                                ? Colors.white
                                                : Color(0xFF664499),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // 统计信息行
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStatItem('官方定数', currentDiffData?['diff'] ?? '-'),
                              _buildStatItem('拟合难度', currentDiffData != null 
                                  ? currentDiffData['fit_diff'].toStringAsFixed(2) 
                                  : '-'),
                              _buildStatItem('谱面谱师', currentChart['charter']),
                              _buildStatItem('平均达成', currentDiffData != null 
                                  ? '${currentDiffData['avg'].toStringAsFixed(2)}%' 
                                  : '-'),
                            ],
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // 音符分布网格
                          GridView.count(
                            crossAxisCount: 5,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            children: [
                              _buildNoteItem('TAP', currentChart['notes'][0].toString()),
                              _buildNoteItem('HOLD', currentChart['notes'][1].toString()),
                              _buildNoteItem('SLIDE', currentChart['notes'][2].toString()),
                              _buildNoteItem('BREAK', currentChart['notes'][3].toString()),
                              _buildNoteItem('TOUCH', (currentChart['notes'].length > 4 
                                  ? currentChart['notes'][4] 
                                  : 0).toString()),
                            ],
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // 玩家最佳成绩
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '玩家最佳成绩',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      
                                      const SizedBox(height: 8),
                                      
                                      Text(
                                        userRecord != null 
                                            ? '${userRecord['achievements'].toStringAsFixed(4)}%' 
                                            : '无记录',
                                        style: TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                          foreground: Paint()..shader = const LinearGradient(
                                            colors: [
                                              Colors.red,
                                              Colors.yellow,
                                            ],
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                          ).createShader(const Rect.fromLTWH(0, 0, 200, 50)),
                                        ),
                                      ),
                                      
                                      const SizedBox(height: 8),
                                      
                                      Text(
                                        userRecord != null 
                                            ? 'Rating: ${userRecord['ra']}' 
                                            : '',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      
                                      const SizedBox(height: 8),
                                      
                                      Row(
                                        children: [
                                          if (userRecord != null) ...[
                                            if (userRecord['fc'].isNotEmpty) 
                                              _buildBadge(userRecord['fc']),
                                            if (userRecord['fs'].isNotEmpty) 
                                              _buildBadge(userRecord['fs']),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    color: Color(0xFFF0E6FF),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '★',
                                      style: TextStyle(
                                        fontSize: 24,
                                        color: Color(0xFF9966CC),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // 谱面标签
                          Container(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '谱面标签',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2D1B69),
                                  ),
                                ),
                                
                                const SizedBox(height: 10),
                                
                                // 标签分组
                                for (var group in groupedTags.entries)
                                  if (group.value.isNotEmpty)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          group.key,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF664499),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        
                                        const SizedBox(height: 6),
                                        
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: group.value.map((tag) => 
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(20),
                                                color: _getTagColor(group.key),
                                                border: Border.all(
                                                  color: _getTagBorderColor(group.key),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Text(
                                                tag['localized_name']['zh-Hans'],
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: _getTagTextColor(group.key),
                                                ),
                                              ),
                                            ),
                                          ).toList(),
                                        ),
                                        
                                        const SizedBox(height: 12),
                                      ],
                                    ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          

                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 构建信息项
  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            '▌',
            style: TextStyle(
              color: Color(0xFF9966CC),
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // 构建统计项
  Widget _buildStatItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF664499),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D1B69),
            ),
          ),
        ],
      ),
    );
  }

  // 构建音符项
  Widget _buildNoteItem(String type, String count) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text(
            type,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            count,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF664499),
            ),
          ),
        ],
      ),
    );
  }

  // 构建徽章
  Widget _buildBadge(String text) {
    Color bgColor;
    Color textColor;
    
    switch (text) {
      case 'ap':
        bgColor = Color(0xFFD4F4DD);
        textColor = Color(0xFF2E7D32);
        break;
      case 'fcp':
        bgColor = Color(0xFFD4F4DD);
        textColor = Color(0xFF2E7D32);
        break;
      case 'fc':
        bgColor = Color(0xFFD4F4DD);
        textColor = Color(0xFF2E7D32);
        break;
      case 'fsp':
        bgColor = Color(0xFFFFF3E0);
        textColor = Color(0xFFF57C00);
        break;
      case 'sync':
        bgColor = Color(0xFFFFF3E0);
        textColor = Color(0xFFF57C00);
        break;
      default:
        bgColor = Color(0xFFF0F0F0);
        textColor = Color(0xFF666666);
    }
    
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: bgColor,
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  // 获取难度标签
  String _getDiffLabel(int index) {
    switch (index) {
      case 0:
        return 'Basic';
      case 1:
        return 'Advan';
      case 2:
        return 'Expert';
      case 3:
        return 'Master';
      case 4:
        return 'Re:MASTER';
      default:
        return '';
    }
  }

  // 格式化版本
  String _formatVersion(String version) {
    if (version == 'maimai') {
      return 'maimai';
    }
    if (version == 'maimai PLUS') {
      return 'maimai+';
    }
    if (version == 'maimai でらっくす') {
      return 'DX';
    }
    if (version == 'maimai でらっくす PLUS') {
      return 'DX+';
    }
    if (version.contains(' PLUS')) {
      version = version.replaceFirst(' PLUS', '+');
    }
    if (version.contains('maimai') && version != 'maimai') {
      version = version.replaceFirst('maimai ', '');
    }
    if (version.contains('でらっくす')) {
      version = version.replaceFirst('でらっくす ', '');
    }
    return version;
  }

  // 获取标签颜色
  Color _getTagColor(String group) {
    switch (group) {
      case '配置':
        return Color(0xFFE8F4F8);
      case '评价':
        return Color(0xFFFFF3E0);
      case '难度':
        return Color(0xFFFCE4EC);
      default:
        return Color(0xFFF0E6FF);
    }
  }

  // 获取标签边框颜色
  Color _getTagBorderColor(String group) {
    switch (group) {
      case '配置':
        return Color(0xFFD1E7DD);
      case '评价':
        return Color(0xFFFFE0B2);
      case '难度':
        return Color(0xFFF8BBD0);
      default:
        return Color(0xFFE0D0FF);
    }
  }

  // 获取标签文本颜色
  Color _getTagTextColor(String group) {
    switch (group) {
      case '配置':
        return Color(0xFF388E3C);
      case '评价':
        return Color(0xFFF57C00);
      case '难度':
        return Color(0xFFD81B60);
      default:
        return Color(0xFF664499);
    }
  }
}