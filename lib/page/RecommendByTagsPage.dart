import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:my_first_flutter_app/service/RecommendByTagsService.dart';
import 'package:my_first_flutter_app/entity/RecommendationResult.dart';
import 'package:my_first_flutter_app/page/SongInfoPage.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constant/CacheKeyConstant.dart';
import '../constant/LoadingTipsConstant.dart';

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
  String _currentLoadingTip = '';
  
  // 新增状态变量
  String _currentTab = 'Best55'; // 当前选中的标签，默认为Best55
  int _currentPage = 1; // 当前页码
  int _pageSize = 10; // 每页显示的推荐项数量
  ScrollController _scrollController = ScrollController(); // 滚动控制器

  @override
  void initState() {
    super.initState();
    _initializeLoadingTip();
    // 延迟一小段时间再开始获取推荐结果，确保页面能够完全加载并显示加载动画
    // 这样可以避免在首页点击标签时出现卡顿
    Future.delayed(Duration(milliseconds: 1000), () {
      _fetchRecommendations();
    });
  }

  void _initializeLoadingTip() {
    // 立即设置第一条提示，避免初始空白
    setState(() {
      _currentLoadingTip = LoadingTipsConstant.getRandomLoadingTip();
    });
    LoadingTipsConstant.startAutoSwitch();
    LoadingTipsConstant.tipStream.listen((newTip) {
      if (mounted) {
        setState(() {
          _currentLoadingTip = newTip;
        });
      }
    });
  }

  // 获取推荐结果
  Future<void> _fetchRecommendations() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      // 先尝试从缓存读取推荐结果
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedResult = prefs.getString(CacheKeyConstant.recommendationResults);
        if (cachedResult != null) {
          final resultMap = json.decode(cachedResult);
          final best55 = (resultMap['Best55'] as List).map((item) => RecommendationResult.fromJson(item)).toList();
          final best15 = (resultMap['Best15'] as List).map((item) => RecommendationResult.fromJson(item)).toList();
          
          setState(() {
            _recommendations = {
              'Best55': best55,
              'Best15': best15,
            };
            _isLoading = false;
            _errorMessage = null;
          });
          debugPrint('从缓存读取推荐结果成功');
          return;
        }
      } catch (e) {
        debugPrint('从缓存读取推荐结果失败: $e');
      }
      
      // 记录开始时间
      final startTime = DateTime.now();
      
      // 直接异步执行推荐算法，让UI先显示加载状态
      final result = await recommendSongs();
      
      // 计算已用时间
      final elapsedTime = DateTime.now().difference(startTime).inMilliseconds;
      
      // 确保加载动画至少显示2秒，避免闪烁
      if (elapsedTime < 2000) {
        await Future.delayed(Duration(milliseconds: 2000 - elapsedTime));
      }
      
      setState(() {
        _recommendations = result;
        _isLoading = false;
        _errorMessage = null; // 成功时清除错误信息
      });
    } catch (e) {
      // 即使出错，也要确保加载动画至少显示2秒
      await Future.delayed(Duration(milliseconds: 2000));
      
      setState(() {
        _errorMessage = '获取推荐结果失败：$e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    // 获取屏幕尺寸
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    final double borderRadiusSmall = 8.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false, // 防止键盘弹出时调整布局
      body: Stack(
        children: [
          // 背景
          CommonWidgetUtil.buildCommonBgWidget(),
          CommonWidgetUtil.buildCommonChiffonBgWidget(context),

          // 页面内容
          Column(
            children: [
              // 标题栏
              Container(
                padding: EdgeInsets.fromLTRB(16, 48, 16, 8),
                child: Row(
                  children: [
                    // 返回按钮
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    // 标题
                    Expanded(
                      child: Center(
                        child: Text(
                          '根据标签推荐',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: screenWidth * 0.06,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // 占位，保持标题居中
                    SizedBox(width: 48),
                  ],
                ),
              ),

              // 主内容区域
              Expanded(
                child: Container(
                  margin: EdgeInsets.fromLTRB(8, 0, 8, 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(borderRadiusSmall),
                    boxShadow: [AppColors.defaultShadow(brightness)],
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
                          border: Border(bottom: BorderSide(color: AppColors.tableBorder(brightness))),
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
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Theme.of(context).colorScheme.surface,
                                foregroundColor: _currentTab == 'Best55'
                                    ? (brightness == Brightness.dark ? const Color(0xFF1E1E2E) : Colors.white)
                                    : Theme.of(context).colorScheme.onSurface,
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
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Theme.of(context).colorScheme.surface,
                                foregroundColor: _currentTab == 'Best15'
                                    ? (brightness == Brightness.dark ? const Color(0xFF1E1E2E) : Colors.white)
                                    : Theme.of(context).colorScheme.onSurface,
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
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                        SizedBox(height: screenHeight * 0.02), // 间距为屏幕高度的2%
                                        Text('正在计算推荐结果...', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                        SizedBox(height: screenHeight * 0.01), // 间距为屏幕高度的1%
                                        Text(
                                          _currentLoadingTip,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontSize: screenWidth * 0.035, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                        ),
                                        SizedBox(height: screenHeight * 0.01), // 间距为屏幕高度的1%
                                        Text(
                                          '此功能计算量较大，可能会出现卡顿，请耐心等待',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontSize: screenWidth * 0.035, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                        ),
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
                                          color: AppColors.errorRed(brightness),
                                          size: screenWidth * 0.12, // 图标大小为屏幕宽度的12%
                                        ),
                                        SizedBox(height: screenHeight * 0.02), // 间距为屏幕高度的2%
                                        Text(
                                          _errorMessage!,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: AppColors.errorRed(brightness)),
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
                                _buildRecommendationContent(brightness),
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
                            border: Border(top: BorderSide(color: AppColors.tableBorder(brightness))),
                          ),
                          child: _buildPagination(),
                        ),
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

  // 构建推荐内容
  Widget _buildRecommendationContent(Brightness brightness) {
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

    return _buildRecommendationSection(brightness, '${_currentTab}推荐', paginatedResults);
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
  Widget _buildRecommendationSection(Brightness brightness, String title, List<RecommendationResult> results) {
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
            color: Theme.of(context).colorScheme.onSurface,
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
              style: TextStyle(color: AppColors.greyHint(brightness)),
            ),
          )
        else
          Column(
            children: results.map((result) => _buildRecommendationItem(brightness, result)).toList(),
          ),
      ],
    );
  }

  // 构建单个推荐项
  Widget _buildRecommendationItem(Brightness brightness, RecommendationResult result) {
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
          border: Border.all(color: AppColors.tableBorder(brightness)),
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).colorScheme.surface,
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
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  result.level,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
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
                Text('定数: ${result.ds}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                Text('相似度: ${(result.similarity * 100).toStringAsFixed(1)}%', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
            SizedBox(height: screenHeight * 0.01), // 间距为屏幕高度的1%
            // 最低达成率
            Text('当前:${result.nowAchievement.toStringAsFixed(4)}%→目标:${result.minAchievement.toStringAsFixed(4)}%',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),

            // 提升Rating信息
            if (result.ableRiseTotalRating == true)
            Padding(
              padding: EdgeInsets.only(top: screenHeight * 0.01), // 顶部 padding 为屏幕高度的1%
              child: Text(
                'Rating提升: ' + result.riseTotalRating,
                style: TextStyle(
                  color: AppColors.successGreen(brightness),
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
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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