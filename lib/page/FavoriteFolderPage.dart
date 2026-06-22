import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_first_flutter_app/entity/FavoriteFolder.dart';
import 'package:my_first_flutter_app/entity/DivingFish/Song.dart';
import 'package:my_first_flutter_app/manager/DivingFish/MaimaiMusicDataManager.dart';
import 'package:my_first_flutter_app/service/FavoriteFolderService.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:my_first_flutter_app/utils/CoverUtil.dart';
import 'package:my_first_flutter_app/utils/StringUtil.dart';
import 'package:my_first_flutter_app/manager/MaiTagsManager.dart';
import 'package:my_first_flutter_app/entity/DXRating/MaiTagsEntity.dart';
import 'SongInfoPage.dart';

/// 收藏夹管理页面：查看所有收藏夹、创建/重命名/删除收藏夹，浏览收藏夹内的谱面
class FavoriteFolderPage extends StatefulWidget {
  const FavoriteFolderPage({super.key});

  @override
  State<FavoriteFolderPage> createState() => _FavoriteFolderPageState();
}

class _FavoriteFolderPageState extends State<FavoriteFolderPage> {
  final FavoriteFolderService _service = FavoriteFolderService();
  List<FavoriteFolder> _folders = [];
  bool _isLoading = true;

  // 样式常量
  final Color textPrimaryColor = const Color.fromARGB(255, 84, 97, 97);
  final double borderRadiusSmall = 8.0;
  final BoxShadow defaultShadow = BoxShadow(
    color: Colors.grey.withOpacity(0.5),
    spreadRadius: 2,
    blurRadius: 5,
    offset: const Offset(0, 3),
  );

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final folders = await _service.getFolders();
    if (mounted) {
      setState(() {
        _folders = folders;
        _isLoading = false;
      });
    }
  }

  /// 显示创建收藏夹对话框
  Future<void> _createFolder() async {
    final nameController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建收藏夹'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '请输入收藏夹名称',
            border: OutlineInputBorder(),
          ),
          inputFormatters: [LengthLimitingTextInputFormatter(30)],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('收藏夹名称不能为空')),
                );
                return;
              }
              Navigator.of(ctx).pop(name);
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await _service.createFolder(result);
      await _loadData();
    }
    // 延迟释放控制器，避免对话框撤销动画期间被使用
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameController.dispose();
    });
  }

  /// 显示重命名收藏夹对话框
  Future<void> _renameFolder(FavoriteFolder folder) async {
    final nameController = TextEditingController(text: folder.name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名收藏夹'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '请输入新名称',
            border: OutlineInputBorder(),
          ),
          inputFormatters: [LengthLimitingTextInputFormatter(30)],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('收藏夹名称不能为空')),
                );
                return;
              }
              Navigator.of(ctx).pop(name);
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await _service.renameFolder(folder.id, result);
      await _loadData();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameController.dispose();
    });
  }

  /// 删除收藏夹
  Future<void> _deleteFolder(FavoriteFolder folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除收藏夹'),
        content: Text(
          '确定要删除收藏夹「${folder.name}」吗？\n收藏夹内的谱面不会被删除，但将不再分组。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.deleteFolder(folder.id);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已删除收藏夹「${folder.name}」')),
        );
      }
    }
  }

  /// 查看收藏夹详情
  void _viewFolder(FavoriteFolder folder) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FavoriteFolderDetailPage(
          folderId: folder.id,
          folderName: folder.name,
        ),
      ),
    );
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
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
                padding: const EdgeInsets.fromLTRB(16, 48, 16, 8),
                child: Row(
                  children: [
                    // 返回按钮
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: textPrimaryColor),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    // 标题
                    Expanded(
                      child: Center(
                        child: Text(
                          '收藏夹',
                          style: TextStyle(
                            color: textPrimaryColor,
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
                  margin: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(borderRadiusSmall),
                    boxShadow: [defaultShadow],
                  ),
                  child: Column(
                    children: [
                      // 新建按钮
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _createFolder,
                            icon: const Icon(Icons.add, size: 20),
                            label: const Text('新建收藏夹'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(255, 84, 97, 97),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(borderRadiusSmall),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // 内容
                      Expanded(
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : _folders.isEmpty
                                ? _buildEmptyState()
                                : _buildFolderList(),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite_border, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            '还没有收藏夹',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            '在乐曲详情页中可以将谱面收藏到收藏夹',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _folders.length,
      itemBuilder: (context, index) {
        final folder = _folders[index];
        return _buildFolderCard(folder);
      },
    );
  }

  Widget _buildFolderCard(FavoriteFolder folder) {
    final chartCount = folder.charts.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _viewFolder(folder),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.pink.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.favorite, color: Colors.pink.shade400, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folder.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$chartCount 个谱面',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                onSelected: (value) {
                  switch (value) {
                    case 'rename':
                      _renameFolder(folder);
                      break;
                    case 'delete':
                      _deleteFolder(folder);
                      break;
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'rename', child: Text('重命名')),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('删除', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 收藏夹详情页：查看收藏夹内的谱面列表
class _FavoriteFolderDetailPage extends StatefulWidget {
  final String folderId;
  final String folderName;

  const _FavoriteFolderDetailPage({
    required this.folderId,
    required this.folderName,
  });

  @override
  State<_FavoriteFolderDetailPage> createState() =>
      _FavoriteFolderDetailPageState();
}

class _FavoriteFolderDetailPageState extends State<_FavoriteFolderDetailPage> {
  final FavoriteFolderService _service = FavoriteFolderService();
  List<FavoriteChart> _charts = [];
  bool _isLoading = true;
  Map<String, Song> _songMap = {};

  // 标签统计相关
  MaiTagsEntity? _tagsEntity;
  Map<String, Map<String, int>> _tagStats = {};
  bool _isLoadingTags = false;

  // 样式常量
  final Color textPrimaryColor = const Color.fromARGB(255, 84, 97, 97);
  final double borderRadiusSmall = 8.0;
  final BoxShadow defaultShadow = BoxShadow(
    color: Colors.grey.withOpacity(0.5),
    spreadRadius: 2,
    blurRadius: 5,
    offset: const Offset(0, 3),
  );

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final charts = await _service.getChartsInFolder(widget.folderId);
    // 加载歌曲详细信息（曲师、版本、流派）
    final songs = await MaimaiMusicDataManager().getCachedSongs();
    final Map<String, Song> songMap = {};
    if (songs != null) {
      for (final song in songs) {
        songMap[song.id] = song;
      }
    }
    if (mounted) {
      setState(() {
        _charts = charts;
        _songMap = songMap;
        _isLoading = false;
      });
    }
    // 加载标签统计数据
    await _loadTagDataAndCalculateStats();
  }

  /// 从收藏夹中移除谱面
  Future<void> _removeChart(FavoriteChart chart) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('移除谱面'),
        content: Text(
          '确定从「${widget.folderName}」中移除「${chart.songTitle}」吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.removeChartFromFolder(widget.folderId, chart.uniqueKey);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已移除')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
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
                padding: const EdgeInsets.fromLTRB(16, 48, 16, 8),
                child: Row(
                  children: [
                    // 返回按钮
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: textPrimaryColor),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    // 标题
                    Expanded(
                      child: Center(
                        child: Text(
                          widget.folderName,
                          style: TextStyle(
                            color: textPrimaryColor,
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
                  margin: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(borderRadiusSmall),
                    boxShadow: [defaultShadow],
                  ),
                  child: Column(
                    children: [
                      // 标签统计按钮（样式、宽度与新建收藏夹一致）
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _showTagStatistics,
                            icon: const Icon(Icons.label_outline, size: 18),
                            label: const Text('标签统计'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(255, 84, 97, 97),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(borderRadiusSmall),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // 内容
                      Expanded(
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : _charts.isEmpty
                                ? _buildEmptyState()
                                : _buildChartList(),
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

  /// 显示标签统计对话框（基于 MaiTagsManager 的标签系统）
  void _showTagStatistics() {
    if (_tagStats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无标签数据')),
      );
      return;
    }

    // 分组颜色映射（与 Best50Page 一致）
    const Map<String, Color> groupColors = {
      '配置': Colors.blue,
      '评价': Colors.amber,
      '难度': Colors.indigo,
    };

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Row(
          children: [
            Icon(Icons.label, size: 22, color: textPrimaryColor),
            const SizedBox(width: 8),
            Text('标签统计', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimaryColor)),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
          child: _isLoadingTags
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _tagStats.entries.map((groupEntry) {
                      final groupName = groupEntry.key;
                      final tagCounts = groupEntry.value;
                      final groupColor = groupColors[groupName] ?? Colors.grey;
                      final total = tagCounts.values.fold(0, (a, b) => a + b);

                      // 对组内标签按数量降序排序
                      final sortedTags = tagCounts.entries.toList()
                        ..sort((a, b) => b.value.compareTo(a.value));

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 分组标题
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: groupColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: groupColor.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    groupName,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: groupColor,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '共 $total 项',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            // 标签统计条
                            ...sortedTags.map((tagEntry) {
                              final percentage = tagEntry.value / _charts.length * 100;
                              final barColor = groupColor.withOpacity(0.7);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 48,
                                      child: Text(
                                        tagEntry.key,
                                        style: const TextStyle(fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: tagEntry.value / _charts.length,
                                          minHeight: 18,
                                          backgroundColor: Colors.grey.shade200,
                                          valueColor: AlwaysStoppedAnimation<Color>(barColor),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    SizedBox(
                                      width: 60,
                                      child: Text(
                                        '${tagEntry.value} (${(percentage).toStringAsFixed(0)}%)',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: textPrimaryColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  // ========== 标签数据加载与统计（基于 MaiTagsManager） ==========

  /// 加载标签数据并计算当前收藏夹各标签出现次数
  Future<void> _loadTagDataAndCalculateStats() async {
    setState(() {
      _isLoadingTags = true;
    });

    try {
      final maiTagsManager = MaiTagsManager();
      _tagsEntity = await maiTagsManager.getTags();

      if (_tagsEntity != null) {
        await _calculateTagGroupStats();
      }
    } catch (e) {
      debugPrint('Error loading tag data: $e');
    } finally {
      setState(() {
        _isLoadingTags = false;
      });
    }
  }

  /// 计算各标签分组下每个标签的出现次数
  Future<void> _calculateTagGroupStats() async {
    if (_tagsEntity == null) return;

    final maiTagsManager = MaiTagsManager();
    final tagIdToNameMap = await maiTagsManager.getTagIdToNameMap();
    final groupIdToNameMap = await maiTagsManager.getGroupIdToNameMap();

    // 构建标签ID → 分组名称 的映射
    Map<int, String> tagIdToGroupName = {};
    for (var tag in _tagsEntity!.tags) {
      tagIdToGroupName[tag.id] = groupIdToNameMap[tag.groupId] ?? '未分类';
    }

    // 获取所有歌曲标题到标签的映射
    Map<String, Set<int>> songTitleToTagIds = {};
    for (var tagSong in _tagsEntity!.tagSongs) {
      String key = '${tagSong.songId}|${tagSong.sheetType}|${tagSong.sheetDifficulty}';
      if (!songTitleToTagIds.containsKey(key)) {
        songTitleToTagIds[key] = {};
      }
      songTitleToTagIds[key]!.add(tagSong.tagId);
    }

    // 遍历收藏夹内的谱面，匹配标签并统计
    Map<String, Map<String, int>> stats = {};
    for (var chart in _charts) {
      String songId = chart.songId;
      int levelIndex = chart.levelIndex;

      // 从 _songMap 获取歌曲信息（与 Best50Page 一致）
      String songTitle = _songMap[songId]?.basicInfo.title ?? '';
      String songType = chart.songType.isNotEmpty
          ? chart.songType
          : (_songMap[songId]?.type ?? 'SD');

      String sheetType = songType == 'DX' ? 'dx' : 'std';
      String difficulty = _getDifficultyByIndex(levelIndex);

      String key = '$songTitle|$sheetType|$difficulty';
      Set<int>? tagIds = songTitleToTagIds[key];

      if (tagIds != null && tagIds.isNotEmpty) {
        for (int tagId in tagIds) {
          String tagName = tagIdToNameMap[tagId] ?? '未知标签';
          String groupName = tagIdToGroupName[tagId] ?? '未分类';

          if (!stats.containsKey(groupName)) {
            stats[groupName] = {};
          }
          if (!stats[groupName]!.containsKey(tagName)) {
            stats[groupName]![tagName] = 0;
          }
          stats[groupName]![tagName] = stats[groupName]![tagName]! + 1;
        }
      }
    }

    setState(() {
      _tagStats = stats;
    });
  }

  /// 将难度索引映射为标签系统使用的难度字符串
  String _getDifficultyByIndex(int index) {
    switch (index) {
      case 0:
        return 'basic';
      case 1:
        return 'advanced';
      case 2:
        return 'expert';
      case 3:
        return 'master';
      case 4:
        return 'remaster';
      default:
        return 'basic';
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite_border, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            '收藏夹为空',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildChartList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _charts.length,
      itemBuilder: (context, index) {
        final chart = _charts[index];
        return _buildChartCard(chart);
      },
    );
  }

  Widget _buildTypeTag(String type, String songId) {
    final isUtage = songId.length == 6;
    if (isUtage) {
      return const Text(
        'UT',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.red,
        ),
      );
    } else if (type == 'DX') {
      return const Text(
        'DX',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.orange,
        ),
      );
    } else {
      return const Text(
        'ST',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.blue,
        ),
      );
    }
  }

  Widget _buildDifficultyTag(String difficultyLabel, int levelIndex, String songId) {
    Color bgColor;
    Color textColor;

    if (songId.length == 6) {
      bgColor = Colors.red.shade100;
      textColor = Colors.red;
    } else {
      switch (levelIndex) {
        case 0: // BASIC
          bgColor = Colors.green.shade100;
          textColor = Colors.green.shade700;
          break;
        case 1: // ADVANCED
          bgColor = Colors.orange.shade100;
          textColor = Colors.orange.shade700;
          break;
        case 2: // EXPERT
          bgColor = Colors.red.shade100;
          textColor = Colors.red;
          break;
        case 3: // MASTER
          bgColor = Colors.purple.shade100;
          textColor = Colors.purple.shade700;
          break;
        case 4: // RE:MASTER
          bgColor = Colors.purple.shade100;
          textColor = Colors.purple.shade300;
          break;
        default:
          bgColor = Colors.grey.shade100;
          textColor = Colors.grey.shade700;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        difficultyLabel,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildChartCard(FavoriteChart chart) {
    final levelNames = [
      'BASIC',
      'ADVANCED',
      'EXPERT',
      'MASTER',
      'RE:MASTER',
      'UTAGE'
    ];
    final bool isUtage = chart.songId.length == 6;
    final String levelName;
    if (isUtage) {
      levelName = 'UTAGE';
    } else {
      levelName = chart.levelIndex >= 0 && chart.levelIndex < levelNames.length
          ? levelNames[chart.levelIndex]
          : 'Lv.${chart.levelIndex}';
    }

    // 获取歌曲详细信息
    final song = _songMap[chart.songId];
    final genre = song?.basicInfo.genre ?? '';
    final version = StringUtil.formatVersion2(song?.basicInfo.from ?? '');
    final songType = chart.songType.isNotEmpty ? chart.songType : (song?.type ?? '');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SongInfoPage(
                songId: chart.songId,
                initialLevelIndex: chart.levelIndex,
                isDefaultLevelIndex: false,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // 左侧：曲绘
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CoverUtil.buildCoverWidget(chart.songId, 60),
              ),
              const SizedBox(width: 12),
              // 右侧：三行信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 第一行：类型标签 + 歌名
                    Row(
                      children: [
                        _buildTypeTag(songType, chart.songId),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            chart.songTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // 第二行：难度标签
                    _buildDifficultyTag(levelName, chart.levelIndex, chart.songId),
                    const SizedBox(height: 4),
                    // 第三行：定数 | 版本 | 流派
                    Text(
                      '${chart.ds.toStringAsFixed(1)} | $version | $genre',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // 移除按钮
              IconButton(
                icon: Icon(Icons.remove_circle_outline, color: Colors.red.shade300),
                tooltip: '从收藏夹移除',
                onPressed: () => _removeChart(chart),
              ),
            ],
          ),
        ),
      ),
    );
  }
}