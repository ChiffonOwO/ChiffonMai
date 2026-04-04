import 'package:flutter/material.dart';
import 'dart:async';
import '../service/CollectionSearchService.dart';
import '../entity/Collection.dart';
import '../manager/CollectionsManager.dart';
import '../utils/CommonWidgetUtil.dart';
import '../utils/CollectionsImageUtil.dart';
import 'CollectionInfoPage.dart';

class CollectionSearchPage extends StatefulWidget {
  const CollectionSearchPage({Key? key}) : super(key: key);

  @override
  _CollectionSearchPageState createState() => _CollectionSearchPageState();
}

class _CollectionSearchPageState extends State<CollectionSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final CollectionSearchService _searchService = CollectionSearchService();
  
  String _selectedType = 'trophies';
  List<Collection> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounceTimer;
  
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

  // 收藏品类型选项
  final List<Map<String, String>> _typeOptions = [
    {'value': 'trophies', 'label': '称号'},
    {'value': 'icons', 'label': '头像'},
    {'value': 'plates', 'label': '姓名框'},
    {'value': 'frames', 'label': '背景'},
  ];

  @override
  void initState() {
    super.initState();
    // 页面初始化时执行一次搜索，显示全部收藏品
    _performSearch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // 执行搜索
  Future<void> _performSearch() async {
    setState(() {
      _isSearching = true;
    });

    try {
      final results = await _searchService.searchCollections(
        _searchController.text,
        _selectedType,
      );
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      print('搜索出错: $e');
      setState(() {
        _searchResults = [];
      });
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  // 防抖搜索
  void _debouncedSearch() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(milliseconds: 600), () {
      _performSearch();
    });
  }

  // 切换收藏品类型
  void _switchType(String type) {
    setState(() {
      _selectedType = type;
    });
    _performSearch();
  }

  // 清除缓存
  Future<void> _clearCache() async {
    try {
      await CollectionsManager().clearAllCache();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('缓存已清除，重新加载数据中...')),
      );
      // 重新执行搜索
      await _performSearch();
    } catch (e) {
      print('清除缓存时出错: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('清除缓存失败')),
      );
    }
  }

  // 根据颜色类型获取背景色
  Color _getColorFromType(String colorType) {
    switch (colorType) {
      case 'Bronze':
        return Color(0xFFCD7F32); // 棕色
      case 'Silver':
        return Color(0xFFC0C0C0); // 银色
      case 'Gold':
        return Color(0xFFFFD700); // 金色
      case 'Rainbow':
        return Color(0xFF9400D3); // 炫彩（紫色作为代表）
      default:
        return Colors.white; // 其他情况使用白色
    }
  }

  // 根据背景色获取文本颜色
  Color _getTextColorForBackground(String colorType) {
    switch (colorType) {
      case 'Bronze':
      case 'Silver':
      case 'Gold':
      case 'Rainbow':
        return Colors.white; // 深色背景使用白色文本
      default:
        return Colors.grey; // 浅色背景使用灰色文本
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // 按钮相关配置
    final buttonHeight = 48.0; // 降低按钮高度
    final buttonBorderRadius = 8.0;

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
                          '收藏品搜索',
                          style: TextStyle(
                            color: textPrimaryColor,
                            fontSize: screenWidth * 0.06,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // 清除缓存按钮
                    IconButton(
                      icon: Icon(Icons.refresh, color: textPrimaryColor),
                      onPressed: _clearCache,
                      tooltip: '清除缓存并重新加载',
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
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: '搜索收藏品名称或达成条件',
                            suffixIcon: IconButton(
                              icon: Icon(Icons.search),
                              onPressed: _performSearch,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                          onChanged: (value) {
                            _debouncedSearch();
                          },
                          onSubmitted: (_) => _performSearch(),
                        ),
                        SizedBox(height: 16),

                        // 类型切换按钮
                        Row(
                          children: _typeOptions.map((option) {
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: ElevatedButton(
                                  onPressed: () => _switchType(option['value']!),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _selectedType == option['value'] 
                                        ? themeColor 
                                        : Colors.grey[200],
                                    foregroundColor: _selectedType == option['value'] 
                                        ? Colors.white 
                                        : Colors.black,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(buttonBorderRadius),
                                    ),
                                    fixedSize: Size(double.infinity, buttonHeight),
                                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                  ),
                                  child: Text(option['label']!),
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        SizedBox(height: 8),
                        // 搜索结果
                        Expanded(
                          child: _isSearching
                              ? Center(child: CircularProgressIndicator())
                              : _searchResults.isEmpty
                                  ? Center(
                                      child: Text('未找到匹配的收藏品'),
                                    )
                                  : ListView.builder(
                                      shrinkWrap: true,
                                      padding: EdgeInsets.zero,
                                      itemCount: _searchResults.length,
                                      itemBuilder: (context, index) {
                                        final collection = _searchResults[index];
                                        return Card(
                                          margin: EdgeInsets.symmetric(vertical: 4.0),
                                          child: InkWell(
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => CollectionInfoPage(
                                                    collectionId: collection.id,
                                                    collectionType: _selectedType,
                                                  ),
                                                ),
                                              );
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.all(16.0),
                                              child: _selectedType == 'icons'
                                                  ? Row(
                                                      children: [
                                                        // 头像图片（小正方形）
                                                        Container(
                                                          width: 60,
                                                          height: 60,
                                                          child: CollectionsImageUtil.getIconImageURL(collection),
                                                        ),
                                                        SizedBox(width: 16),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Text(
                                                                collection.name,
                                                                style: TextStyle(
                                                                  fontSize: 18,
                                                                  fontWeight: FontWeight.bold,
                                                                ),
                                                              ),
                                                              if (collection.description != null)
                                                                Padding(
                                                                  padding: const EdgeInsets.only(top: 8.0),
                                                                  child: Text(collection.description!),
                                                                ),
                                                              if (collection.required != null && collection.required!.isNotEmpty)
                                                                Padding(
                                                                  padding: const EdgeInsets.only(top: 8.0),
                                                                  child: Text(
                                                                    '达成条件: 查看详情',
                                                                    style: TextStyle(
                                                                      color: themeColor,
                                                                      fontSize: 14,
                                                                    ),
                                                                  ),
                                                                ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    )
                                                  : Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        // 姓名框或背景图片（上方显示）
                                                        if (_selectedType == 'plates' || _selectedType == 'frames')
                                                          Container(
                                                            width: double.infinity,
                                                            height: _selectedType == 'plates' ? 100 : 150,
                                                            child: _selectedType == 'plates'
                                                                ? CollectionsImageUtil.getPlateImageURL(collection)
                                                                : CollectionsImageUtil.getFrameImageURL(collection),
                                                          ),
                                                        if (_selectedType == 'plates' || _selectedType == 'frames')
                                                          SizedBox(height: 16),
                                                        Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            // 标题和颜色卡片在同一行
                                                            Row(
                                                              children: [
                                                                Expanded(
                                                                  child: Text(
                                                                    collection.name,
                                                                    style: TextStyle(
                                                                      fontSize: 18,
                                                                      fontWeight: FontWeight.bold,
                                                                    ),
                                                                  ),
                                                                ),
                                                                // 颜色卡片（仅称号）
                                                                if (_selectedType == 'trophies' && collection.color != null)
                                                                  Container(
                                                                    margin: EdgeInsets.only(left: 8),
                                                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                                                    decoration: BoxDecoration(
                                                                      gradient: collection.color == 'Rainbow' 
                                                                          ? LinearGradient(
                                                                              begin: Alignment.centerLeft,
                                                                              end: Alignment.centerRight,
                                                                              colors: [
                                                                                Colors.red,
                                                                                Colors.orange,
                                                                                Colors.yellow,
                                                                                Colors.green,
                                                                                Colors.blue,
                                                                                Colors.indigo,
                                                                                Colors.purple,
                                                                              ],
                                                                            )
                                                                          : null,
                                                                      color: collection.color != 'Rainbow' 
                                                                          ? _getColorFromType(collection.color!)
                                                                          : null,
                                                                      borderRadius: BorderRadius.circular(6),
                                                                      border: Border.all(
                                                                        color: Colors.grey,
                                                                        width: 1,
                                                                      ),
                                                                    ),
                                                                    child: Text(
                                                                      collection.color!,
                                                                      style: TextStyle(
                                                                        fontSize: 12,
                                                                        fontWeight: FontWeight.bold,
                                                                        color: collection.color == 'Rainbow' 
                                                                            ? Colors.white
                                                                            : _getTextColorForBackground(collection.color!),
                                                                      ),
                                                                    ),
                                                                  ),
                                                              ],
                                                            ),
                                                            if (collection.description != null)
                                                              Padding(
                                                                padding: const EdgeInsets.only(top: 8.0),
                                                                child: Text(collection.description!),
                                                              ),
                                                            if (collection.required != null && collection.required!.isNotEmpty)
                                                              Padding(
                                                                padding: const EdgeInsets.only(top: 8.0),
                                                                child: Text(
                                                                  '达成条件: 查看详情',
                                                                  style: TextStyle(
                                                                    color: themeColor,
                                                                    fontSize: 14,
                                                                  ),
                                                                ),
                                                              ),
                                                          ],
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