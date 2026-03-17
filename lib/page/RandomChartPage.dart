import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/service/RandomChartService.dart';
import 'package:my_first_flutter_app/entity/Song.dart';

class RandomChartPage extends StatefulWidget {
  const RandomChartPage({super.key});

  @override
  State<RandomChartPage> createState() => _RandomChartPageState();
}

class _RandomChartPageState extends State<RandomChartPage> {
  final RandomChartService _service = RandomChartService();
  
  // 状态变量
  bool _isLoading = false;
  bool _isDrawing = false;
  List<Song> _drawnSongs = [];
  List<List<Song>> _history = [];
  
  // 筛选条件
  int _drawCount = 4;
  double? _minDs;
  double? _maxDs;
  String _selectedVersion = '全部版本';
  String _selectedGenre = '全部类型';
  
  // 版本和流派列表
  List<String> _versionList = ['全部版本'];
  List<String> _genreList = ['全部类型'];
  
  // 输入控制器
  final TextEditingController _minDsController = TextEditingController();
  final TextEditingController _maxDsController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _loadFilterOptions();
  }
  
  // 加载版本和流派列表
  Future<void> _loadFilterOptions() async {
    _versionList = await _service.getVersionList();
    _genreList = await _service.getGenreList();
    setState(() {});
  }
  
  // 执行抽奖
  Future<void> _drawSongs() async {
    setState(() {
      _isDrawing = true;
    });
    
    try {
      // 解析定数范围
      _minDs = _minDsController.text.isNotEmpty ? double.tryParse(_minDsController.text) : null;
      _maxDs = _maxDsController.text.isNotEmpty ? double.tryParse(_maxDsController.text) : null;
      
      // 随机抽取歌曲
      final songs = await _service.randomDrawSongs(
        count: _drawCount,
        minDs: _minDs,
        maxDs: _maxDs,
        version: _selectedVersion,
        genre: _selectedGenre,
      );
      
      setState(() {
        _drawnSongs = songs;
        // 添加到历史记录
        if (songs.isNotEmpty) {
          _history.insert(0, songs);
          // 只保留最近5条历史记录
          if (_history.length > 5) {
            _history = _history.take(5).toList();
          }
        }
      });
    } catch (e) {
      print('抽奖失败: $e');
    } finally {
      setState(() {
        _isDrawing = false;
      });
    }
  }
  
  // 删除历史记录
  void _deleteHistory(int index) {
    setState(() {
      _history.removeAt(index);
    });
  }
  
  // 生成曲绘路径
  String _getCoverPath(String songId) {
    return 'assets/cover/${songId}.webp';
  }
  
  // 生成网络曲绘URL
  String _getNetworkCoverUrl(String songId) {
    String coverId = songId;
    if (coverId.length < 5) {
      // 万位补1，其余位补0
      coverId = '1' + '0' * (4 - coverId.length) + coverId;
    }
    return 'https://www.diving-fish.com/covers/$coverId.png';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // 统一管理的尺寸变量
    final whiteAreaPadding = screenWidth * 0.04; // 白色区域内边距
    final cardPadding = screenWidth * 0.04; // 卡片内边距
    final borderRadius = screenWidth * 0.02; // 边框圆角
    final buttonHeight = screenHeight * 0.06; // 按钮高度
    final iconSize = screenWidth * 0.05; // 图标大小
    final textSizeLarge = screenWidth * 0.045; // 大字号
    final textSizeMedium = screenWidth * 0.035; // 中字号
    final textSizeSmall = screenWidth * 0.03; // 小字号
    final spacingSmall = screenWidth * 0.02; // 小间距
    final spacingMedium = screenWidth * 0.04; // 中间距
    final spacingLarge = screenWidth * 0.06; // 大间距
    final gridItemSpacing = screenWidth * 0.03; // 网格项间距
    final dropDownHeight = screenHeight * 0.05; // 下拉菜单高度
    final textFieldHeight = screenHeight * 0.05; // 文本框高度
    final historyItemHeight = screenWidth * 0.15; // 历史记录项高度
    final songCardAspectRatio = 0.75; // 歌曲卡片宽高比

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false, // 解决输入法挤压背景的问题
      body: Stack(
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

          // 层级3：第二张虚化装饰图
          Center(
            child: Transform.translate(
              offset: const Offset(0, -20),
              child: Transform.scale(
                scale: 1,
                child: Image.asset(
                  'assets/userinfobg.png',
                  fit: BoxFit.cover,
                  opacity: const AlwaysStoppedAnimation(1),
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

          // 页面标题
          const Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "随机抽歌",
                style: TextStyle(
                  color: Color.fromARGB(255, 84, 97, 97),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),

          // 主要内容区域
          Positioned(
            top: screenHeight * 0.15,
            left: screenWidth * 0.02,
            right: screenWidth * 0.02,
            bottom: screenHeight * 0.03,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(borderRadius),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 5.0,
                    offset: Offset(2.0, 2.0),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(whiteAreaPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 筛选条件区域
                    Container(
                      padding: EdgeInsets.all(cardPadding),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(borderRadius),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '筛选条件',
                            style: TextStyle(
                              fontSize: textSizeLarge,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: spacingMedium),
                          
                          // 筛选条件三行布局
                          Column(
                            children: [
                              // 第一行：抽取数量
                              Row(
                                children: [
                                  Text(
                                    '抽取数量',
                                    style: TextStyle(
                                      fontSize: textSizeSmall,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  SizedBox(width: spacingSmall),
                                  Row(
                                    children: [
                                      for (int i = 1; i <= 4; i++)
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _drawCount = i;
                                            });
                                          },
                                          child: Container(
                                            width: screenWidth * 0.08,
                                            height: screenWidth * 0.08,
                                            margin: EdgeInsets.symmetric(horizontal: spacingSmall),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: _drawCount == i ? Colors.blue : Colors.grey[200],
                                            ),
                                            child: Center(
                                              child: Text(
                                                i.toString(),
                                                style: TextStyle(
                                                  fontSize: textSizeSmall,
                                                  fontWeight: _drawCount == i ? FontWeight.bold : FontWeight.normal,
                                                  color: _drawCount == i ? Colors.white : Colors.black,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              SizedBox(height: spacingMedium),
                              
                              // 第二行：版本筛选（单独一行）
                              Container(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '版本筛选',
                                      style: TextStyle(
                                        fontSize: textSizeSmall,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    SizedBox(height: spacingSmall),
                                    DropdownButtonFormField<String>(
                                      value: _selectedVersion,
                                      items: _versionList.map((version) {
                                        return DropdownMenuItem<String>(
                                          value: version,
                                          child: Text(
                                            version,
                                            style: TextStyle(fontSize: textSizeSmall),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedVersion = value!;
                                        });
                                      },
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(borderRadius),
                                        ),
                                        contentPadding: EdgeInsets.symmetric(horizontal: spacingSmall, vertical: spacingSmall),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: spacingMedium),
                              
                              // 第三行：类型筛选（单独一行）
                              Container(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '类型筛选',
                                      style: TextStyle(
                                        fontSize: textSizeSmall,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    SizedBox(height: spacingSmall),
                                    DropdownButtonFormField<String>(
                                      value: _selectedGenre,
                                      items: _genreList.map((genre) {
                                        return DropdownMenuItem<String>(
                                          value: genre,
                                          child: Text(
                                            genre,
                                            style: TextStyle(fontSize: textSizeSmall),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedGenre = value!;
                                        });
                                      },
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(borderRadius),
                                        ),
                                        contentPadding: EdgeInsets.symmetric(horizontal: spacingSmall, vertical: spacingSmall),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: spacingMedium),
                              
                              // 第四行：定数范围
                              Container(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '定数范围',
                                      style: TextStyle(
                                        fontSize: textSizeSmall,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    SizedBox(height: spacingSmall),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _minDsController,
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(
                                              hintText: '最小值',
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(borderRadius),
                                              ),
                                              contentPadding: EdgeInsets.symmetric(horizontal: spacingSmall, vertical: spacingSmall),
                                            ),
                                            style: TextStyle(fontSize: textSizeSmall),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Text('-'),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: TextField(
                                            controller: _maxDsController,
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(
                                              hintText: '最大值',
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(borderRadius),
                                              ),
                                              contentPadding: EdgeInsets.symmetric(horizontal: spacingSmall, vertical: spacingSmall),
                                            ),
                                            style: TextStyle(fontSize: textSizeSmall),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: spacingMedium),
                              
                              // 抽奖按钮
                              ElevatedButton(
                                onPressed: _isDrawing ? null : _drawSongs,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  padding: EdgeInsets.symmetric(vertical: spacingMedium),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(borderRadius),
                                  ),
                                ),
                                child: _isDrawing
                                    ? Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: iconSize,
                                            height: iconSize,
                                            child: const CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          ),
                                          SizedBox(width: spacingSmall),
                                          Text(
                                            '抽奖中...',
                                            style: TextStyle(
                                              fontSize: textSizeMedium,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.refresh),
                                          SizedBox(width: spacingSmall),
                                          Text(
                                            '开始抽奖',
                                            style: TextStyle(
                                              fontSize: textSizeMedium,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: spacingLarge),
                    
                    // 歌曲抽取区域
                    Container(
                      padding: EdgeInsets.all(cardPadding),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(borderRadius),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 抽取结果标题
                          Text(
                            '抽取结果',
                            style: TextStyle(
                              fontSize: textSizeLarge,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          
                          SizedBox(height: spacingLarge),
                          
                          // 歌曲展示区（一行显示，不滚动）
                          Container(
                            height: screenWidth * 0.4, // 减小高度
                            child: Row(
                              children: [
                                for (int i = 0; i < _drawCount; i++)
                                  Expanded(
                                    child: Container(
                                      margin: EdgeInsets.symmetric(horizontal: gridItemSpacing / 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(borderRadius),
                                      ),
                                      child: _drawnSongs.length > i
                                          ? Column(
                                              children: [
                                                // 正方形曲绘
                                                AspectRatio(
                                                  aspectRatio: 1, // 保持正方形
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.vertical(top: Radius.circular(borderRadius)),
                                                    ),
                                                    child: Image.asset(
                                                      _getCoverPath(_drawnSongs[i].id),
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context, error, stackTrace) {
                                                        return Image.network(
                                                          _getNetworkCoverUrl(_drawnSongs[i].id),
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (context, error, stackTrace) {
                                                            return Container(
                                                              color: Colors.grey[300],
                                                              child: const Center(
                                                                child: Text('暂无封面'),
                                                              ),
                                                            );
                                                          },
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),
                                                // 文本部分
                                                Padding(
                                                  padding: const EdgeInsets.all(8.0),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                                    children: [
                                                      Text(
                                                        _drawnSongs[i].basicInfo.title,
                                                        style: TextStyle(
                                                          fontSize: textSizeSmall,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      Text(
                                                        'ID: ${_drawnSongs[i].id}',
                                                        style: TextStyle(
                                                          fontSize: textSizeSmall * 0.8,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Container(
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(borderRadius),
                                              ),
                                              child: const Center(
                                                child: Text('点击抽奖'),
                                              ),
                                            ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          
                          SizedBox(height: spacingLarge),
                          

                        ],
                      ),
                    ),
                    
                    SizedBox(height: spacingLarge),
                    
                    // 历史记录区域
                    Container(
                      padding: EdgeInsets.all(cardPadding),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(borderRadius),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '历史抽取记录',
                            style: TextStyle(
                              fontSize: textSizeLarge,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: spacingMedium),
                          
                          if (_history.isEmpty)
                            const Center(
                              child: Text('暂无历史记录'),
                            )
                          else
                            Column(
                              children: _history.asMap().entries.map((entry) {
                                int index = entry.key;
                                List<Song> songs = entry.value;
                                
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${DateTime.now().toString().substring(0, 16)}',
                                            style: TextStyle(
                                              fontSize: textSizeSmall,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () => _deleteHistory(index),
                                            icon: const Icon(Icons.delete),
                                            iconSize: iconSize * 0.8,
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: spacingSmall),
                                      GridView.count(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        crossAxisCount: 4,
                                        crossAxisSpacing: gridItemSpacing * 0.8,
                                    mainAxisSpacing: gridItemSpacing * 0.8,
                                        children: songs.map((song) {
                                          return Container(
                                            decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius: BorderRadius.circular(borderRadius),
                                          ),
                                            child: Image.asset(
                                              _getCoverPath(song.id),
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return Image.network(
                                                  _getNetworkCoverUrl(song.id),
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return Container(
                                                      color: Colors.grey[300],
                                                    );
                                                  },
                                                );
                                              },
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
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
}