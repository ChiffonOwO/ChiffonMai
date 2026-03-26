import 'dart:math';

import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/service/RecommendByTagsService.dart';
import 'package:my_first_flutter_app/entity/RecommendationResult.dart';
import 'package:my_first_flutter_app/page/SongInfoPage.dart';

class RecommendByTags extends StatefulWidget {
  const RecommendByTags({super.key});

  @override
  State<RecommendByTags> createState() => _RecommendByTagsState();
}

class _RecommendByTagsState extends State<RecommendByTags> {
  // 状态变量
  Map<String, List<RecommendationResult>> _recommendations = {};
  bool _isLoading = true;
  String? _errorMessage;
  
  // 新增状态变量
  String _currentTab = 'Best55'; // 当前选中的标签，默认为Best55
  int _currentPage = 1; // 当前页码
  int _pageSize = 10; // 每页显示的推荐项数量
  ScrollController _scrollController = ScrollController(); // 滚动控制器

  @override
  void initState() {
    super.initState();
    // 页面加载后延迟一点时间再获取推荐结果，确保页面先显示
    Future.delayed(Duration(milliseconds: 800), () {
      _fetchRecommendations();
    });
  }

  // 获取推荐结果
  Future<void> _fetchRecommendations() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      // 直接异步执行推荐算法，让UI先显示加载状态
      final result = await recommendSongs();
      
      setState(() {
        _recommendations = result;
        _isLoading = false;
        _errorMessage = null; // 成功时清除错误信息
      });
    } catch (e) {
      setState(() {
        _errorMessage = '获取推荐结果失败：$e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 获取屏幕尺寸
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
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
              offset: Offset(0, -screenHeight * 0.02), // 垂直向上偏移屏幕高度的2%
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
          Positioned(
            top: screenHeight * 0.08, // 距离顶部为屏幕高度的8%
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "根据标签推荐",
                style: TextStyle(
                  color: Color.fromARGB(255, 84, 97, 97),
                  fontSize: screenWidth * 0.06, // 字体大小为屏幕宽度的6%
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),

          // 返回按钮
          Positioned(
            top: screenHeight * 0.05, // 距离顶部为屏幕高度的5%
            left: screenWidth * 0.03, // 距离左侧为屏幕宽度的3%
            child: IconButton(
              icon: Icon(Icons.arrow_back,
                  color: Color.fromARGB(255, 84, 97, 97), 
                  size: screenWidth * 0.06), // 图标大小为屏幕宽度的6%
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),

          // 主要内容区域
          Positioned(
            top: screenHeight * 0.15, // 距离顶部为屏幕高度的15%
            left: screenWidth * 0.03, // 距离左侧为屏幕宽度的3%
            right: screenWidth * 0.03, // 距离右侧为屏幕宽度的3%
            bottom: screenHeight * 0.03, // 距离底部为屏幕高度的3%
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
                  // 切换按钮
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.04, // 水平 padding 为屏幕宽度的4%
                      vertical: screenHeight * 0.01, // 垂直 padding 为屏幕高度的1%
                    ),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _currentTab = 'Best55';
                              _currentPage = 1; // 切换标签时重置页码
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _currentTab == 'Best55' 
                                ? const Color.fromARGB(255, 84, 97, 97) 
                                : Colors.grey.shade200,
                            foregroundColor: _currentTab == 'Best55' 
                                ? Colors.white 
                                : const Color.fromARGB(255, 84, 97, 97),
                          ),
                          child: const Text('Best55推荐'),
                        ),
                        SizedBox(width: screenWidth * 0.04), // 间距为屏幕宽度的4%
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _currentTab = 'Best15';
                              _currentPage = 1; // 切换标签时重置页码
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _currentTab == 'Best15' 
                                ? const Color.fromARGB(255, 84, 97, 97) 
                                : Colors.grey.shade200,
                            foregroundColor: _currentTab == 'Best15' 
                                ? Colors.white 
                                : const Color.fromARGB(255, 84, 97, 97),
                          ),
                          child: const Text('Best15推荐'),
                        ),
                      ],
                    ),
                  ),
                  
                  // 内容区域
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: EdgeInsets.all(screenWidth * 0.04), // padding 为屏幕宽度的4%
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 加载状态
                          if (_isLoading)
                            Center(
                              child: Padding(
                                padding: EdgeInsets.all(screenHeight * 0.05), // padding 为屏幕高度的5%
                                child: Column(
                                  children: [
                                    CircularProgressIndicator(
                                      color: Color.fromARGB(255, 84, 97, 97),
                                    ),
                                    SizedBox(height: screenHeight * 0.02), // 间距为屏幕高度的2%
                                    Text('正在计算推荐结果...'),
                                  ],
                                ),
                              ),
                            )
                          // 错误状态
                          else if (_errorMessage != null)
                            Center(
                              child: Padding(
                                padding: EdgeInsets.all(screenHeight * 0.05), // padding 为屏幕高度的5%
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: Colors.red,
                                      size: screenWidth * 0.12, // 图标大小为屏幕宽度的12%
                                    ),
                                    SizedBox(height: screenHeight * 0.02), // 间距为屏幕高度的2%
                                    Text(
                                      _errorMessage!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                    SizedBox(height: screenHeight * 0.02), // 间距为屏幕高度的2%
                                    ElevatedButton(
                                      onPressed: _fetchRecommendations,
                                      child: const Text('重试'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          // 展示推荐结果
                          else
                            _buildRecommendationContent(),
                        ],
                      ),
                    ),
                  ),
                  
                  // 分页组件 - 固定在滚动区域下方
                  if (!_isLoading && _errorMessage == null)
                    Container(
                      padding: EdgeInsets.symmetric(
                        vertical: screenHeight * 0.015, // 垂直 padding 为屏幕高度的1.5%
                        horizontal: screenWidth * 0.04, // 水平 padding 为屏幕宽度的4%
                      ),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: Colors.grey.shade200)),
                      ),
                      child: _buildPagination(),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 构建推荐内容
  Widget _buildRecommendationContent() {
    // 根据当前选中的标签获取推荐结果
    List<RecommendationResult> results = _recommendations[_currentTab] ?? [];
    
    // 计算分页
    int totalItems = results.length;
    //int totalPages = (totalItems / _pageSize).ceil();
    int startIndex = (_currentPage - 1) * _pageSize;
    int endIndex = min(startIndex + _pageSize, totalItems);
    List<RecommendationResult> paginatedResults = [];
    
    if (startIndex < totalItems) {
      paginatedResults = results.sublist(startIndex, endIndex);
    }
    
    return _buildRecommendationSection('${_currentTab}推荐', paginatedResults);
  }
  
  // 构建分页组件
  Widget _buildPagination() {
    final screenWidth = MediaQuery.of(context).size.width;
    
    List<RecommendationResult> results = _recommendations[_currentTab] ?? [];
    int totalItems = results.length;
    int totalPages = (totalItems / _pageSize).ceil();
    
    if (totalPages <= 1) {
      return Container(); // 只有一页时不显示分页
    }
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 上一页按钮
        ElevatedButton(
          onPressed: _currentPage > 1
              ? () {
                  setState(() {
                    _currentPage--;
                    // 滚动到顶端
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  });
                }
              : null,
          child: const Text('上一页'),
        ),
        SizedBox(width: screenWidth * 0.04), // 间距为屏幕宽度的4%
        // 页码显示
        Text(' $_currentPage / $totalPages '),
        SizedBox(width: screenWidth * 0.04), // 间距为屏幕宽度的4%
        // 下一页按钮
        ElevatedButton(
          onPressed: _currentPage < totalPages
              ? () {
                  setState(() {
                    _currentPage++;
                    // 滚动到顶端
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  });
                }
              : null,
          child: const Text('下一页'),
        ),
      ],
    );
  }

  // 构建推荐区域
  Widget _buildRecommendationSection(String title, List<RecommendationResult> results) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 区域标题
        Text(
          title,
          style: TextStyle(
            fontSize: screenWidth * 0.045, // 字体大小为屏幕宽度的4.5%
            fontWeight: FontWeight.bold,
            color: Color.fromARGB(255, 84, 97, 97),
          ),
        ),
        SizedBox(height: screenHeight * 0.015), // 间距为屏幕高度的1.5%
        
        // 推荐结果列表
        if (results.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: screenHeight * 0.025), // 垂直 padding 为屏幕高度的2.5%
            child: Text(
              '暂无推荐结果',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          )
        else
          Column(
            children: results.map((result) => _buildRecommendationItem(result)).toList(),
          ),
      ],
    );
  }

  // 构建单个推荐项
  Widget _buildRecommendationItem(RecommendationResult result) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return GestureDetector(
      onTap: () {
        // 导航到SongInfoPage
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SongInfoPage(
              songId: result.songId,
              initialLevelIndex: result.levelIndex,
            ),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: screenHeight * 0.015), // 底部 margin 为屏幕高度的1.5%
        padding: EdgeInsets.all(screenWidth * 0.03), // padding 为屏幕宽度的3%
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 歌曲标题和难度
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    result.songTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: screenWidth * 0.04, // 字体大小为屏幕宽度的4%
                    ),
                  ),
                ),
                Text(
                  result.level,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color.fromARGB(255, 84, 97, 97),
                    fontSize: screenWidth * 0.035, // 字体大小为屏幕宽度的3.5%
                  ),
                ),
              ],
            ),
            SizedBox(height: screenHeight * 0.01), // 间距为屏幕高度的1%
            
            // 定数、相似度
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('定数: ${result.ds}'),
                Text('相似度: ${(result.similarity * 100).toStringAsFixed(1)}%'),
              ],
            ),
            SizedBox(height: screenHeight * 0.01), // 间距为屏幕高度的1%
            // 最低达成率
            Text('当前:${result.nowAchievement.toStringAsFixed(4)}%→目标:${result.minAchievement.toStringAsFixed(4)}%'),
            
            // 提升Rating信息
            if (result.ableRiseTotalRating == true)
            Padding(
              padding: EdgeInsets.only(top: screenHeight * 0.01), // 顶部 padding 为屏幕高度的1%
              child: Text(
                'Rating提升: ' + result.riseTotalRating,
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (result.ableRiseTotalRating == false)
            Padding(
              padding: EdgeInsets.only(top: screenHeight * 0.01), // 顶部 padding 为屏幕高度的1%
              child: Text(
                result.riseTotalRating,
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}