import 'package:flutter/material.dart';
import '../service/KnowledgeSearchService.dart';
import '../entity/KnowledgeEntity.dart';
import '../utils/CommonWidgetUtil.dart';
import 'KnowledgeInfoPage.dart';

class KnowledgeSearchPage extends StatefulWidget {
  const KnowledgeSearchPage({Key? key}) : super(key: key);

  @override
  _KnowledgeSearchPageState createState() => _KnowledgeSearchPageState();
}

class _KnowledgeSearchPageState extends State<KnowledgeSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final KnowledgeSearchService _searchService = KnowledgeSearchService();
  List<KnowledgeItem> _searchResults = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadAllKnowledge();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 加载所有知识条目
  Future<void> _loadAllKnowledge() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final results = await _searchService.getAllKnowledge();
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '加载知识数据失败';
        _isLoading = false;
      });
    }
  }

  // 执行搜索
  Future<void> _performSearch() async {
    final keyword = _searchController.text.trim();
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final results = await _searchService.searchKnowledge(keyword);
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '搜索失败';
        _isLoading = false;
      });
    }
  }

  // 清除缓存并重新加载数据
  Future<void> _clearCacheAndReload() async {
    try {
      // 清除缓存
      await _searchService.clearCache();
      // 重新加载数据
      await _loadAllKnowledge();
      // 显示提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('缓存已清除，数据已重新加载')),
      );
    } catch (e) {
      debugPrint('清除缓存时出错: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('清除缓存失败')),
      );
    }
  }

  // 自定义常量
  final Color textPrimaryColor = Color.fromARGB(255, 84, 97, 97);
  final Color themeColor = Colors.blue;
  final double borderRadiusSmall = 8.0;
  final BoxShadow defaultShadow = BoxShadow(
    color: Colors.grey.withOpacity(0.5),
    spreadRadius: 2,
    blurRadius: 5,
    offset: Offset(0, 3),
  );

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

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
                      icon: Icon(Icons.arrow_back, color: textPrimaryColor),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    // 标题
                    Expanded(
                      child: Center(
                        child: Text(
                          '舞萌百科',
                          style: TextStyle(
                            color: textPrimaryColor,
                            fontSize: screenWidth * 0.06,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // 刷新按钮
                    IconButton(
                      icon: Icon(Icons.refresh, color: textPrimaryColor),
                      onPressed: _clearCacheAndReload,
                      tooltip: '清除缓存并刷新数据',
                    ),
                  ],
                ),
              ),

              // 主内容区域
              Expanded(
                child: Container(
                  margin: EdgeInsets.fromLTRB(8, 0, 8, 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(borderRadiusSmall),
                    boxShadow: [defaultShadow],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // 搜索输入框
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: '搜索知识...',
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                  onSubmitted: (_) => _performSearch(),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.search),
                                onPressed: _performSearch,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),

                        // 搜索结果
                        Expanded(
                          child: _isLoading
                              ? Center(child: CircularProgressIndicator())
                              : _errorMessage.isNotEmpty
                                  ? Center(child: Text(_errorMessage, style: TextStyle(color: Colors.red)))
                                  : _searchResults.isEmpty
                                      ? Center(child: Text('未找到相关知识'))
                                      : ListView.builder(
                                          shrinkWrap: true,
                                          padding: EdgeInsets.zero,
                                          itemCount: _searchResults.length,
                                          itemBuilder: (context, index) {
                                            final item = _searchResults[index];
                                            return GestureDetector(
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => KnowledgeInfoPage(
                                                      knowledgeId: item.id,
                                                      knowledgeTitle: item.title,
                                                    ),
                                                  ),
                                                );
                                              },
                                              child: Card(
                                                margin: EdgeInsets.symmetric(vertical: 4.0),
                                                child: Padding(
                                                  padding: const EdgeInsets.all(16.0),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      // 分类标签
                                                      if (item.category != null)
                                                        Container(
                                                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                          decoration: BoxDecoration(
                                                            color: item.category == KnowledgeItem.tagCategory
                                                                ? Colors.blue
                                                                : Colors.green,
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: Text(
                                                            item.category!,
                                                            style: TextStyle(color: Colors.white, fontSize: 12),
                                                          ),
                                                        ),
                                                      SizedBox(height: 8),
                                                      
                                                      // 标题
                                                      Text(
                                                        item.title ?? '无标题',
                                                        style: TextStyle(
                                                          fontSize: 18,
                                                          fontWeight: FontWeight.bold,
                                                          color: textPrimaryColor,
                                                        ),
                                                      ),
                                                      SizedBox(height: 8),
                                                      
                                                      // 内容
                                                      if (item.content != null)
                                                        Text(
                                                          item.content!,
                                                          style: TextStyle(color: Colors.grey[700]),
                                                          maxLines: 3,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}