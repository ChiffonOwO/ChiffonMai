import 'dart:math';

import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/service/RecommendByTagsService.dart';
import 'package:my_first_flutter_app/entity/RecommendationResult.dart';

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
    // 初始化时获取推荐结果
    _fetchRecommendations();
  }

  // 获取推荐结果
  Future<void> _fetchRecommendations() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '无错误信息';
      });
      
      // 调用推荐算法获取结果
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
                  // 切换按钮
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        const SizedBox(width: 16),
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
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 加载状态
                          if (_isLoading)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(40.0),
                                child: Column(
                                  children: [
                                    CircularProgressIndicator(
                                      color: Color.fromARGB(255, 84, 97, 97),
                                    ),
                                    SizedBox(height: 16),
                                    Text('正在计算推荐结果...'),
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
                                    const SizedBox(height: 16),
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
                            Column(
                              children: [
                                _buildRecommendationContent(),
                                const SizedBox(height: 16),
                                _buildPagination(),
                              ],
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

  // 构建推荐内容
  Widget _buildRecommendationContent() {
    // 根据当前选中的标签获取推荐结果
    List<RecommendationResult> results = _recommendations[_currentTab] ?? [];
    
    // 计算分页
    int totalItems = results.length;
    int totalPages = (totalItems / _pageSize).ceil();
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
        const SizedBox(width: 16),
        // 页码显示
        Text(' $_currentPage / $totalPages '),
        const SizedBox(width: 16),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 区域标题
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color.fromARGB(255, 84, 97, 97),
          ),
        ),
        const SizedBox(height: 12),
        
        // 推荐结果列表
        if (results.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              '暂无推荐结果',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                result.level,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 84, 97, 97),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // 定数、相似度
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('定数: ${result.ds}'),
              Text('相似度: ${(result.similarity * 100).toStringAsFixed(1)}%'),
            ],
          ),
          const SizedBox(height: 8),
          // 最低达成率
          Text('当前:${result.nowAchievement.toStringAsFixed(4)}%→目标:${result.minAchievement.toStringAsFixed(4)}%'),
          
          // 提升Rating信息
          if (result.ableRiseTotalRating == true)
          Padding(
            padding: const EdgeInsets.only(top: 8),
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
            padding: const EdgeInsets.only(top: 8),
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
    );
  }
}