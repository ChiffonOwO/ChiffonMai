import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_first_flutter_app/page/SongInfoPage.dart';
import 'package:my_first_flutter_app/service/DsRangeRecommendService.dart';
import 'package:my_first_flutter_app/service/RatingRecommendService.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:my_first_flutter_app/utils/CoverUtil.dart';
import 'package:my_first_flutter_app/utils/StringUtil.dart';

class DsRangeRecommendPage extends StatefulWidget {
  const DsRangeRecommendPage({super.key});

  @override
  State<DsRangeRecommendPage> createState() => _DsRangeRecommendPageState();
}

class _DsRangeRecommendPageState extends State<DsRangeRecommendPage> {
  bool _isLoading = true;
  bool _isLoadingRating = true;
  List<DsRangeRecommendItem> _results = [];
  String _sortMode = 'avg';
  double _minDs = 1.0;
  double _maxDs = 15.0;
  final TextEditingController _minDsController = TextEditingController();
  final TextEditingController _maxDsController = TextEditingController();
  int _currentPage = 1;
  static const int _pageSize = 10;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadInitialDsRange();
  }

  Future<void> _loadInitialDsRange() async {
    try {
      final rating = await RatingRecommendService().getUserTotalRating();
      final dsRange = RatingRecommendService().calculateDsRange(rating);
      setState(() {
        _minDs = dsRange['min']!;
        _maxDs = dsRange['max']!;
        _minDsController.text = _minDs.toStringAsFixed(1);
        _maxDsController.text = _maxDs.toStringAsFixed(1);
        _isLoadingRating = false;
      });
    } catch (e) {
      setState(() {
        _minDsController.text = _minDs.toStringAsFixed(1);
        _maxDsController.text = _maxDs.toStringAsFixed(1);
        _isLoadingRating = false;
      });
    }
    _loadRecommendations();
  }

  @override
  void dispose() {
    _minDsController.dispose();
    _maxDsController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
    });

    try {
      final results = await DsRangeRecommendService().getRecommendations(
        _minDs,
        _maxDs,
        _sortMode,
      );
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _results = [];
        _isLoading = false;
      });
    }
  }

  void _onMinDsChanged(String value) {
    final parsed = double.tryParse(value);
    if (parsed != null && parsed >= 1.0) {
      _minDs = parsed;
    }
  }

  void _onMaxDsChanged(String value) {
    final parsed = double.tryParse(value);
    if (parsed != null && parsed <= 15.0) {
      _maxDs = parsed;
    }
  }

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
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final screenWidth = MediaQuery.of(context).size.width;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    final totalPages = (_results.length / _pageSize).ceil();
    final startIndex = (_currentPage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize).clamp(0, _results.length);
    final paginatedResults = _results.sublist(startIndex, endIndex);

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          CommonWidgetUtil.buildCommonBgWidget(),
          CommonWidgetUtil.buildCommonChiffonBgWidget(context),
          Column(
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(16, 48, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back,
                          color: Theme.of(context).colorScheme.onSurface),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '基于定数区间推荐',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: screenWidth * 0.06,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  margin: EdgeInsets.fromLTRB(4, 0, 4, 10 + safeBottom),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surface
                        .withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [AppColors.defaultShadow(brightness)],
                  ),
                  child: Column(
                    children: [
                      _buildControlPanel(brightness, screenWidth),
                      Expanded(
                        child: _isLoading || _isLoadingRating
                            ? _buildLoadingState(screenHeight)
                            : _results.isEmpty
                                ? _buildEmptyState(brightness, screenHeight)
                                : _buildResultsList(
                                    brightness, paginatedResults, screenWidth),
                      ),
                      if (!_isLoading &&
                          !_isLoadingRating &&
                          _results.isNotEmpty &&
                          totalPages > 1)
                        _buildPagination(brightness, totalPages, screenWidth),
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

  Widget _buildControlPanel(Brightness brightness, double screenWidth) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.04,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.tableBorder(brightness)),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '定数区间:',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _minDsController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,1}')),
                    ],
                    onChanged: _onMinDsChanged,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                      hintText: '最低',
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '~',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _maxDsController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,1}')),
                    ],
                    onChanged: _onMaxDsChanged,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                      hintText: '最高',
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _loadRecommendations,
                child: const Text('推荐'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSortButton(
                  '平均达成率推荐',
                  'avg',
                  brightness,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSortButton(
                  '定数差值推荐',
                  'diff',
                  brightness,
                ),
              ),
            ],
          ),
          if (_results.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '定数范围: ${_minDs.toStringAsFixed(1)} ~ ${_maxDs.toStringAsFixed(1)}'
                '  |  共 ${_results.length} 条结果',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSortButton(String label, String mode, Brightness brightness) {
    final isSelected = _sortMode == mode;
    return ElevatedButton(
      onPressed: () {
        if (_sortMode != mode) {
          setState(() {
            _sortMode = mode;
          });
          _loadRecommendations();
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected
            ? Theme.of(context).colorScheme.onSurface
            : Theme.of(context).colorScheme.surface,
        foregroundColor: isSelected
            ? (brightness == Brightness.dark
                ? const Color(0xFF1E1E2E)
                : Colors.white)
            : Theme.of(context).colorScheme.onSurface,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13),
      ),
    );
  }

  Widget _buildLoadingState(double screenHeight) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(screenHeight * 0.05),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(height: 16),
            Text(
              '正在加载推荐结果...',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(Brightness brightness, double screenHeight) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(screenHeight * 0.05),
        child: Text(
          '暂无推荐结果，请检查定数区间输入是否正确',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.greyHint(brightness),
          ),
        ),
      ),
    );
  }

  Widget _buildResultsList(Brightness brightness,
      List<DsRangeRecommendItem> results, double screenWidth) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.all(screenWidth * 0.03),
      child: Column(
        children: results
            .map((item) => _buildResultCard(item, brightness, screenWidth))
            .toList(),
      ),
    );
  }

  Widget _buildResultCard(
      DsRangeRecommendItem item, Brightness brightness, double screenWidth) {
    final bgColor = brightness == Brightness.dark
        ? Colors.black
        : _getBackgroundColor(item.levelIndex, item.difficultyCount);
    final borderColor = brightness == Brightness.dark
        ? _getBackgroundColor(item.levelIndex, item.difficultyCount)
        : bgColor;
    final typeColor = _getTypeColor(item.type, brightness);
    final typeLabel = StringUtil.formatSongType(item.type);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SongInfoPage(
              songId: item.songId,
              initialLevelIndex: item.levelIndex,
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
                child: CoverUtil.buildCoverWidget(item.songId, 80),
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
                                item.levelIndex, brightness),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.level,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _getDifficultyTextColor(
                                  item.levelIndex, brightness),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.songTitle,
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
                          '定数 ${item.ds.toStringAsFixed(1)}',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _sortMode == 'avg'
                              ? '平均达成 ${item.avg.toStringAsFixed(2)}%'
                              : '定数差值 ${item.diffDifference >= 0 ? "+" : ""}${item.diffDifference.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: _sortMode == 'diff'
                                ? (item.diffDifference < 0
                                    ? AppColors.successGreen(brightness)
                                    : AppColors.errorRed(brightness))
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (item.userAchievement != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '个人最佳成绩 ${item.userAchievement!.toStringAsFixed(4)}%',
                        style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagination(
      Brightness brightness, int totalPages, double screenWidth) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: 12,
        horizontal: screenWidth * 0.04,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.tableBorder(brightness)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: _currentPage > 1
                ? () {
                    setState(() {
                      _currentPage--;
                    });
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                : null,
            child: const Text('上一页'),
          ),
          SizedBox(width: screenWidth * 0.04),
          Text(' $_currentPage / $totalPages '),
          SizedBox(width: screenWidth * 0.04),
          ElevatedButton(
            onPressed: _currentPage < totalPages
                ? () {
                    setState(() {
                      _currentPage++;
                    });
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                : null,
            child: const Text('下一页'),
          ),
        ],
      ),
    );
  }
}