import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:my_first_flutter_app/service/RecommendByTagsService.dart';
import 'package:my_first_flutter_app/service/RatingRecommendService.dart';
import 'package:my_first_flutter_app/entity/RecommendationResult.dart';
import 'package:my_first_flutter_app/page/SongInfoPage.dart';
import 'package:my_first_flutter_app/utils/CoverUtil.dart';
import 'package:my_first_flutter_app/utils/StringUtil.dart';
import 'package:flutter/services.dart';
import '../constant/LoadingTipsConstant.dart';
import '../widgets/BackgroundPageScaffold.dart';

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
  bool _isDisposed = false; // 页面是否已销毁，用于取消正在进行的异步操作
  StreamSubscription<String>? _tipSubscription; // 加载提示的流订阅
  String _rangeMode = 'rating';
  int _targetRating = 0;
  double _minDs = 1.0;
  double _maxDs = 15.0;
  bool _rangeSettingsLoaded = false;
  late final TextEditingController _ratingController;
  late final TextEditingController _minDsController;
  late final TextEditingController _maxDsController;

  Color _getBackgroundColor(int diffIndex, int difficultyCount) {
    if (difficultyCount <= 2) {
      return const Color(0xFFE9D8FF);
    }
    switch (diffIndex) {
      case 0:
        return const Color(0xFFE8F5E8);
      case 1:
        return const Color(0xFFFFF8E1);
      case 2:
        return const Color(0xFFFCE4EC);
      case 3:
        return const Color(0xFFE9D8FF);
      case 4:
        return const Color(0xFFF3E5F5);
      default:
        return const Color(0xFFE9D8FF);
    }
  }

  Color _getTypeColor(String type, Brightness brightness) {
    return type == 'DX'
        ? AppColors.warningOrange(brightness)
        : AppColors.linkBlue(brightness);
  }

  Color _getDifficultyBgColor(int levelIndex, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    switch (levelIndex) {
      case 0:
        return isDark ? const Color(0xFF1B3D1B) : Colors.green.shade100;
      case 1:
        return isDark ? const Color(0xFF3D2E00) : Colors.orange.shade100;
      case 2:
        return isDark ? const Color(0xFF4A2020) : Colors.red.shade100;
      case 3:
        return isDark ? const Color(0xFF2A1A3D) : Colors.purple.shade100;
      case 4:
        return isDark ? const Color(0xFF352545) : Colors.purple.shade50;
      default:
        return isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade100;
    }
  }

  Color _getDifficultyTextColor(int levelIndex, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    switch (levelIndex) {
      case 0:
        return isDark ? const Color(0xFF66BB6A) : Colors.green.shade700;
      case 1:
        return isDark ? const Color(0xFFFFB74D) : Colors.orange.shade700;
      case 2:
        return isDark ? const Color(0xFFEF5350) : Colors.red;
      case 3:
        return isDark ? const Color(0xFFCE93D8) : Colors.purple.shade700;
      case 4:
        return isDark ? const Color(0xFFE1BEE7) : Colors.purple.shade400;
      default:
        return isDark ? Colors.grey.shade400 : Colors.grey.shade700;
    }
  }

  @override
  void initState() {
    super.initState();
    _ratingController = TextEditingController();
    _minDsController = TextEditingController();
    _maxDsController = TextEditingController();
    _initializeLoadingTip();
    // 延迟一小段时间再开始获取推荐结果，确保页面能够完全加载并显示加载动画
    // 这样可以避免在首页点击标签时出现卡顿
    Future.delayed(Duration(milliseconds: 1000), () {
      if (!_isDisposed && mounted) {
        _fetchRecommendations();
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _tipSubscription?.cancel();
    // 加载提示用的是**全局静态**定时器：只 cancel 自己的订阅不够，
    // 定时器仍会 3 秒一次地往广播流里推（订阅都取消了，纯属空转，
    // 但会一直活到进程结束）。与项目里其它页面的做法保持一致。
    LoadingTipsConstant.stopAutoSwitch();
    _scrollController.dispose();
    _ratingController.dispose();
    _minDsController.dispose();
    _maxDsController.dispose();
    super.dispose();
  }

  void _initializeLoadingTip() {
    // 立即设置第一条提示，避免初始空白
    setState(() {
      _currentLoadingTip = LoadingTipsConstant.getRandomLoadingTip();
    });
    LoadingTipsConstant.startAutoSwitch();
    _tipSubscription = LoadingTipsConstant.tipStream.listen((newTip) {
      if (mounted && !_isDisposed) {
        setState(() {
          _currentLoadingTip = newTip;
        });
      }
    });
  }

  // 获取推荐结果
  Future<void> _fetchRecommendations() async {
    try {
      if (!mounted || _isDisposed) return;
      if (!_rangeSettingsLoaded) {
        _targetRating = await RatingRecommendService().getUserTotalRating();
        _applyRatingRange();
        _rangeSettingsLoaded = true;
      }
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      // 记录开始时间
      final startTime = DateTime.now();
      
      // 直接异步执行推荐算法，让UI先显示加载状态
      final result = await recommendSongs(
        minDsOverride: _minDs,
        maxDsOverride: _maxDs,
      );
      
      // 计算已用时间
      final elapsedTime = DateTime.now().difference(startTime).inMilliseconds;
      
      // 确保加载动画至少显示2秒，避免闪烁
      if (elapsedTime < 2000) {
        await Future.delayed(Duration(milliseconds: 2000 - elapsedTime));
      }
      
      if (!mounted || _isDisposed) return;
      setState(() {
        _recommendations = _prioritizeByRange(result);
        _isLoading = false;
        _errorMessage = null; // 成功时清除错误信息
      });
    } catch (e) {
      // 即使出错，也要确保加载动画至少显示2秒
      await Future.delayed(Duration(milliseconds: 2000));

      if (!mounted || _isDisposed) return;
      setState(() {
        _errorMessage = '获取推荐结果失败：$e';
        _isLoading = false;
      });
    }
  }

  void _applyRatingRange() {
    final range = RatingRecommendService().calculateDsRange(_targetRating);
    _minDs = range['min']!;
    _maxDs = range['max']!;
    _ratingController.text = _targetRating.toString();
    _minDsController.text = _minDs.toStringAsFixed(1);
    _maxDsController.text = _maxDs.toStringAsFixed(1);
  }

  void _applyManualRange() {
    final minValue = double.tryParse(_minDsController.text);
    final maxValue = double.tryParse(_maxDsController.text);
    if (minValue == null || maxValue == null || minValue > maxValue) return;
    setState(() {
      _minDs = minValue.clamp(1.0, 15.0);
      _maxDs = maxValue.clamp(_minDs, 15.0);
    });
  }

  Map<String, List<RecommendationResult>> _prioritizeByRange(
      Map<String, List<RecommendationResult>> source) {
    final result = <String, List<RecommendationResult>>{};
    for (final entry in source.entries) {
      final items = [...entry.value];
      items.sort((a, b) {
        final aIn = a.ds >= _minDs && a.ds <= _maxDs;
        final bIn = b.ds >= _minDs && b.ds <= _maxDs;
        if (aIn != bIn) return aIn ? -1 : 1;
        return b.similarity.compareTo(a.similarity);
      });
      result[entry.key] = items;
    }
    return result;
  }

  Widget _buildRangeSettings(Brightness brightness) {
    final scheme = Theme.of(context).colorScheme;
    final fieldDecoration = InputDecoration(
      isDense: true,
      filled: true,
      fillColor: scheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
    );
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.tune_rounded, size: 19, color: scheme.primary),
          const SizedBox(width: 8),
          const Expanded(
              child: Text('推荐范围', style: TextStyle(fontWeight: FontWeight.w700))),
          Text('范围内谱面优先',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ]),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.primaryContainer,
                foregroundColor: scheme.onPrimaryContainer,
              ),
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: Text('当前：${_rangeMode == 'rating' ? '目标Rating' : '定数区间'}'),
              onPressed: () {
                setState(() {
                  _rangeMode = _rangeMode == 'rating' ? 'ds' : 'rating';
                  if (_rangeMode == 'rating') _applyRatingRange();
                });
                _fetchRecommendations();
              },
            ),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.primaryContainer,
                foregroundColor: scheme.onPrimaryContainer,
              ),
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: Text('当前：$_currentTab推荐'),
              onPressed: () => setState(() {
                _currentTab = _currentTab == 'Best55' ? 'Best15' : 'Best55';
                _currentPage = 1;
              }),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_rangeMode == 'rating')
          Row(children: [
            Expanded(
              child: TextField(
                controller: _ratingController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: fieldDecoration.copyWith(
                  labelText: '目标 Rating',
                  prefixIcon: const Icon(Icons.star_outline, size: 19),
                ),
                onSubmitted: (_) {
                  _targetRating = int.tryParse(_ratingController.text) ?? 0;
                  _applyRatingRange();
                  _fetchRecommendations();
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: '按目标 Rating 重新计算',
              onPressed: () {
                _targetRating = int.tryParse(_ratingController.text) ?? 0;
                _applyRatingRange();
                _fetchRecommendations();
              },
              icon: const Icon(Icons.refresh_rounded),
            ),
          ])
        else
          Row(children: [
            Expanded(
              child: TextField(
                controller: _minDsController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: fieldDecoration.copyWith(labelText: '最低定数'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('至', style: TextStyle(color: scheme.onSurfaceVariant)),
            ),
            Expanded(
              child: TextField(
                controller: _maxDsController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: fieldDecoration.copyWith(labelText: '最高定数'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: '按定数区间重新计算',
              onPressed: () {
                _applyManualRange();
                _fetchRecommendations();
              },
              icon: const Icon(Icons.refresh_rounded),
            ),
          ]),
        const SizedBox(height: 7),
        Text(
          _rangeMode == 'rating'
              ? '当前定数范围：${_minDs.toStringAsFixed(1)} ~ ${_maxDs.toStringAsFixed(1)}'
              : '当前定数范围：${_minDs.toStringAsFixed(1)} ~ ${_maxDs.toStringAsFixed(1)}',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    // 获取屏幕尺寸
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return BackgroundPageScaffold(
      title: '根据标签推荐',
      resizeToAvoidBottomInset: false,
      contentPadding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom + 10,
      ),
      child: Column(
        children: [
                      _buildRangeSettings(brightness),
                      
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
    );
  }

  // 构建推荐内容
  Widget _buildRecommendationContent(Brightness brightness) {
    final screenWidth = MediaQuery.of(context).size.width;
    List<RecommendationResult> results = _recommendations[_currentTab] ?? [];
    int totalItems = results.length;
    int startIndex = (_currentPage - 1) * _pageSize;
    int endIndex = min(startIndex + _pageSize, totalItems);
    List<RecommendationResult> paginatedResults = [];

    if (startIndex < totalItems) {
      paginatedResults = results.sublist(startIndex, endIndex);
    }

    return Column(
      children: paginatedResults
          .map((result) => _buildResultCard(brightness, result, screenWidth))
          .toList(),
    );
  }

  // 构建单个推荐卡片
  Widget _buildResultCard(
      Brightness brightness, RecommendationResult result, double screenWidth) {
    final bgColor = brightness == Brightness.dark
        ? Colors.black
        : _getBackgroundColor(result.levelIndex, result.difficultyCount);
    final borderColor = brightness == Brightness.dark
        ? _getBackgroundColor(result.levelIndex, result.difficultyCount)
        : bgColor;
    final typeColor = _getTypeColor(result.type, brightness);
    final typeLabel = StringUtil.formatSongType(result.type);

    return GestureDetector(
      onTap: () {
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
        margin: EdgeInsets.only(bottom: screenWidth * 0.03),
        decoration: BoxDecoration(
          color: brightness == Brightness.dark
              ? bgColor
              : bgColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: borderColor,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(9),
                bottomLeft: Radius.circular(9),
              ),
              child: SizedBox(
                width: 80,
                height: 80,
                child: CoverUtil.buildCoverWidget(result.songId, 80),
              ),
            ),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          typeLabel,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: typeColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getDifficultyBgColor(
                                result.levelIndex, brightness),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            result.level,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _getDifficultyTextColor(
                                  result.levelIndex, brightness),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result.songTitle,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '定数 ${result.ds.toStringAsFixed(1)}',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '相似度 ${(result.similarity * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        if (result.ableRiseTotalRating)
                          Text(
                            result.riseTotalRating,
                            style: TextStyle(
                              color: AppColors.successGreen(brightness),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '当前:${result.nowAchievement.toStringAsFixed(4)}% → 目标:${result.minAchievement.toStringAsFixed(4)}%',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    if (!result.ableRiseTotalRating)
                      Text(
                        result.riseTotalRating,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
}
