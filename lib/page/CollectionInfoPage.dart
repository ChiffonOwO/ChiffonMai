import 'package:flutter/material.dart';
import 'dart:async';
import '../service/CollectionInfoService.dart';
import '../entity/Collection.dart';
import '../utils/LuoXueToDivingFishUtil.dart';
import '../utils/CommonWidgetUtil.dart';
import '../utils/CollectionsImageUtil.dart';
import '../utils/CoverUtil.dart';
import '../utils/TranslationUtil.dart';
import 'SongInfoPage.dart';

class CollectionInfoPage extends StatefulWidget {
  final int collectionId;
  final String collectionType;

  const CollectionInfoPage({
    Key? key,
    required this.collectionId,
    required this.collectionType,
  }) : super(key: key);

  @override
  _CollectionInfoPageState createState() => _CollectionInfoPageState();
}

class _CollectionInfoPageState extends State<CollectionInfoPage> {
  final CollectionInfoService _infoService = CollectionInfoService();
  Collection? _collection;
  bool _isLoading = true;
  Map<CollectionRequiredSong, dynamic>? _songMap;
  bool _isLoadingSongs = false;
  String? _translatedName;
  String? _translatedDescription;
  bool _isTranslatingName = false;
  bool _isTranslatingDescription = false;

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
  void initState() {
    super.initState();
    _loadCollectionInfo();
  }

  // 加载收藏品详情
  Future<void> _loadCollectionInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final collection = await _infoService.getCollectionById(
        widget.collectionId,
        widget.collectionType,
      );

      setState(() {
        _collection = collection;
      });

      // 如果有达成条件，加载相关歌曲信息
      if (collection != null && 
          collection.required != null && 
          collection.required!.isNotEmpty) {
        _loadSongInfo(collection);
      }
    } catch (e) {
      print('加载收藏品详情时出错: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 检测是否为英文或日文字符
  bool _isEnglishOrJapanese(String text) {
    // 检查是否包含拉丁字母或日文字符（平假名、片假名）
    final englishRegex = RegExp(r'[a-zA-Z]');
    final japaneseHiraganaKatakanaRegex = RegExp(r'[\u3040-\u309F\u30A0-\u30FF]');
    
    return englishRegex.hasMatch(text) || japaneseHiraganaKatakanaRegex.hasMatch(text);
  }

  // 检测是否为英文
  bool _isEnglish(String text) {
    // 检查是否包含拉丁字母
    final englishRegex = RegExp(r'[a-zA-Z]');
    return englishRegex.hasMatch(text);
  }

  // 检测是否为日语
  bool _isJapanese(String text) {
    // 检查是否包含日文字符（平假名、片假名）
    final japaneseHiraganaKatakanaRegex = RegExp(r'[\u3040-\u309F\u30A0-\u30FF]');
    return japaneseHiraganaKatakanaRegex.hasMatch(text);
  }

  // 检测是否同时包含英语和日语
  bool _isEnglishAndJapanese(String text) {
    return _isEnglish(text) && _isJapanese(text);
  }

  // 翻译收藏品名称
  Future<void> _translateName() async {
    if (_collection?.name == null) return;
    
    setState(() {
      _isTranslatingName = true;
    });
    
    try {
      String? translated = await TranslateService.translate(_collection!.name, from: 'auto', to: 'zh');
      if (translated != null) {
        setState(() {
          _translatedName = translated;
        });
      }
    } catch (e) {
      print('翻译名称失败: $e');
    } finally {
      setState(() {
        _isTranslatingName = false;
      });
    }
  }

  // 翻译收藏品描述
  Future<void> _translateDescription() async {
    if (_collection?.description == null) return;
    
    setState(() {
      _isTranslatingDescription = true;
    });
    
    try {
      String? translated = await TranslateService.translate(_collection!.description!, from: 'auto', to: 'zh');
      if (translated != null) {
        setState(() {
          _translatedDescription = translated;
        });
      }
    } catch (e) {
      print('翻译描述失败: $e');
    } finally {
      setState(() {
        _isTranslatingDescription = false;
      });
    }
  }

  // 加载相关歌曲信息
  Future<void> _loadSongInfo(Collection collection) async {
    setState(() {
      _isLoadingSongs = true;
    });

    try {
      final songMap = await LuoXueToDivingFishUtil.getSongsFromCache(collection);
      setState(() {
        _songMap = songMap;
      });
    } catch (e) {
      print('加载歌曲信息时出错: $e');
    } finally {
      setState(() {
        _isLoadingSongs = false;
      });
    }
  }

  // 获取类型标签
  String _getTypeLabel() {
    switch (widget.collectionType) {
      case 'trophies':
        return '称号';
      case 'icons':
        return '头像';
      case 'plates':
        return '姓名框';
      case 'frames':
        return '背景';
      default:
        return '';
    }
  }

  // 获取歌曲类型显示
  String _getTypeDisplay(String type) {
    switch (type.toLowerCase()) {
      case 'dx':
        return 'DX';
      case 'standard':
        return 'ST';
      case 'sd':
        return 'ST';
      default:
        return type;
    }
  }

  // 获取难度显示
  Widget _getDifficultiesDisplay(List<int> difficulties) {
    final Map<int, Map<String, dynamic>> difficultyMap = {
      0: {'label': 'BASIC', 'color': Color(0xFF4CAF50), 'bgColor': Color(0xFFE8F5E8)},
      1: {'label': 'ADVANCED', 'color': Color(0xFFFF9800), 'bgColor': Color(0xFFFFF8E1)},
      2: {'label': 'EXPERT', 'color': Color(0xFFE91E63), 'bgColor': Color(0xFFFCE4EC)},
      3: {'label': 'MASTER', 'color': Color(0xFF9966CC), 'bgColor': Color(0xFFE9D8FF)},
      4: {'label': 'RE:MASTER', 'color': Color(0xFF9C27B0), 'bgColor': Color(0xFFF3E5F5)},
    };
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: difficulties.map((d) {
        final difficultyInfo = difficultyMap[d] ?? {'label': d.toString(), 'color': Colors.grey, 'bgColor': Colors.grey[100]};
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: difficultyInfo['bgColor'],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: difficultyInfo['color'], width: 1),
          ),
          child: Text(
            difficultyInfo['label'],
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: difficultyInfo['color'],
            ),
          ),
        );
      }).toList(),
    );
  }

  // 获取FC显示
  Widget _getFcDisplay(String fc) {
    final Map<String, Map<String, dynamic>> fcMap = {
      'ap': {'label': 'AP', 'color': Color(0xFFFF9800), 'bgColor': Color(0xFFFFE0B2)},
      'app': {'label': 'AP+', 'color': Color(0xFFF57C00), 'bgColor': Color(0xFFFFCC80)},
      'fc': {'label': 'FC', 'color': Color(0xFF4CAF50), 'bgColor': Color(0xFFE8F5E8)},
      'fcp': {'label': 'FC+', 'color': Color(0xFF2E7D32), 'bgColor': Color(0xFFC8E6C9)},
    };
    
    final fcInfo = fcMap[fc] ?? {'label': fc, 'color': Colors.grey, 'bgColor': Colors.grey[100]};
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: fcInfo['bgColor'],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fcInfo['color'], width: 1),
      ),
      child: Text(
        fcInfo['label'],
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: fcInfo['color'],
        ),
      ),
    );
  }

  // 获取FS显示
  Widget _getFsDisplay(String fs) {
    final Map<String, Map<String, dynamic>> fsMap = {
      'fs': {'label': 'FS', 'color': Color(0xFF1976D2), 'bgColor': Color(0xFFE3F2FD)},
      'fsp': {'label': 'FS+', 'color': Color(0xFF1565C0), 'bgColor': Color(0xFFBBDEFB)},
      'fsd': {'label': 'FDX', 'color': Color(0xFFFF9800), 'bgColor': Color(0xFFFFE0B2)},
      'fsdp': {'label': 'FDX+', 'color': Color(0xFFF57C00), 'bgColor': Color(0xFFFFCC80)},
      'sync': {'label': 'SYNC', 'color': Color(0xFFFF5722), 'bgColor': Color(0xFFFFE0B2)},
    };
    
    final fsInfo = fsMap[fs] ?? {'label': fs, 'color': Colors.grey, 'bgColor': Colors.grey[100]};
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: fsInfo['bgColor'],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fsInfo['color'], width: 1),
      ),
      child: Text(
        fsInfo['label'],
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: fsInfo['color'],
        ),
      ),
    );
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

  // 获取唯一的歌曲列表
  List<Widget> _getUniqueSongLists(List<CollectionRequired> requiredList) {
    final Set<String> seenSongLists = {};
    final List<Widget> uniqueSongLists = [];

    for (final requiredItem in requiredList) {
      if (requiredItem.songs != null && requiredItem.songs!.isNotEmpty) {
        // 将歌曲列表转换为唯一字符串，用于去重
        final songListKey = requiredItem.songs!.map((song) => '${song.id}:${song.title}:${song.type}').join(',');
        
        if (!seenSongLists.contains(songListKey)) {
          seenSongLists.add(songListKey);
          
          uniqueSongLists.add(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GridView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 4, // 进一步减小横向间距
                    mainAxisSpacing: 4, // 进一步减小纵向间距
                    childAspectRatio: 2.0, // 调整比例，使卡片更紧凑
                  ),
                  itemCount: requiredItem.songs!.length,
                  itemBuilder: (context, index) {
                    final requiredSong = requiredItem.songs![index];
                    final song = _songMap?[requiredSong];
                    // 获取MASTER和REMASTER定数
                    String masterDs = '-';
                    String remasterDs = '-';
                    if (song != null && song.ds != null && song.ds is List) {
                      if (song.ds.length > 3) {
                        masterDs = song.ds[3].toStringAsFixed(1);
                      }
                      if (song.ds.length > 4) {
                        remasterDs = song.ds[4].toStringAsFixed(1);
                      }
                    }
                    return GestureDetector(
                      onTap: () {
                        // 跳转到歌曲详情页面，默认选择MASTER难度
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SongInfoPage(
                              songId: song?.id.toString() ?? requiredSong.id.toString(),
                              initialLevelIndex: 3, // 3 代表 MASTER 难度
                            ),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.grey,
                            width: 1,
                          ),
                        ),
                        padding: EdgeInsets.all(4), // 进一步减小内边距
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center, // 垂直居中对齐
                          children: [
                            // 曲绘
                            Container(
                              width: 40, // 增大曲绘尺寸
                              height: 40, // 增大曲绘尺寸
                              child: CoverUtil.buildCoverWidgetWithContext(
                                context,
                                song?.id.toString() ?? requiredSong.id.toString(),
                                40,
                              ),
                            ),
                            SizedBox(width: 6), // 调整间距，适应增大的曲绘尺寸
                            // 歌曲信息
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center, // 垂直居中
                                children: [
                                  Text(
                                    requiredSong.title,
                                    style: TextStyle(
                                      fontSize: 11, // 进一步减小字体大小
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 1), // 进一步减小间距
                                  Text(
                                    '${_getTypeDisplay(requiredSong.type)} | $masterDs | $remasterDs',
                                    style: TextStyle(
                                      fontSize: 9, // 进一步减小字体大小
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: 12), // 减小底部间距
              ],
            ),
          );
        }
      }
    }

    return uniqueSongLists;
  }

  // 合并所需条件
  List<Widget> _getMergedRequiredConditions(List<CollectionRequired> requiredList) {
    final Set<String> seenFc = {};
    final Set<String> seenFs = {};
    final Set<int> allDifficulties = {};
    final List<Widget> mergedConditions = [];

    // 收集所有难度
    for (final requiredItem in requiredList) {
      if (requiredItem.difficulties != null && requiredItem.difficulties!.isNotEmpty) {
        allDifficulties.addAll(requiredItem.difficulties!);
      }
    }

    // 显示合并后的难度
    if (allDifficulties.isNotEmpty) {
      final sortedDifficulties = allDifficulties.toList()..sort();
      mergedConditions.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '所需难度:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              _getDifficultiesDisplay(sortedDifficulties),
            ],
          ),
        ),
      );
    }

    // 处理所需连击和同步
    for (final requiredItem in requiredList) {
      // 处理fc字段
      if (requiredItem.fc != null) {
        // 定义同步类型的fc值
        final syncTypes = ['fs', 'fsp', 'fsd', 'fsdp', 'sync'];
        
        if (syncTypes.contains(requiredItem.fc!)) {
          // fc字段是同步类型，显示到所需同步里
          if (!seenFs.contains(requiredItem.fc!)) {
            seenFs.add(requiredItem.fc!);
            mergedConditions.add(
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '所需同步:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    _getFsDisplay(requiredItem.fc!),
                  ],
                ),
              ),
            );
          }
        } else {
          // fc字段是连击类型，显示到所需连击里
          if (!seenFc.contains(requiredItem.fc!)) {
            seenFc.add(requiredItem.fc!);
            mergedConditions.add(
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '所需连击:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    _getFcDisplay(requiredItem.fc!),
                  ],
                ),
              ),
            );
          }
        }
      }

      // 处理所需同步（fs字段）
      if (requiredItem.fs != null) {
        if (!seenFs.contains(requiredItem.fs!)) {
          seenFs.add(requiredItem.fs!);
          mergedConditions.add(
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '所需同步:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  _getFsDisplay(requiredItem.fs!),
                ],
              ),
            ),
          );
        }
      }
    }

    // 添加底部间距
    if (mergedConditions.isNotEmpty) {
      mergedConditions.add(SizedBox(height: 16));
    }

    return mergedConditions;
  }

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
                          '${_getTypeLabel()}详情',
                          style: TextStyle(
                            color: textPrimaryColor,
                            fontSize: screenWidth * 0.06,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // 占位按钮
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.transparent),
                      onPressed: () {},
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
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator())
                      : _collection == null
                          ? Center(child: Text('未找到收藏品信息'))
                          : Padding(
                              padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
                              child: ListView(
                                children: [
                                  // 收藏品图片
                                  if (widget.collectionType == 'icons')
                                    Container(
                                      width: double.infinity,
                                      height: 200,
                                      child: CollectionsImageUtil.getIconImageURL(_collection!),
                                    ),
                                  if (widget.collectionType == 'plates')
                                    Container(
                                      width: double.infinity,
                                      height: 150,
                                      child: CollectionsImageUtil.getPlateImageURL(_collection!),
                                    ),
                                  if (widget.collectionType == 'frames')
                                    Container(
                                      width: double.infinity,
                                      height: 200,
                                      child: CollectionsImageUtil.getFrameImageURL(_collection!),
                                    ),
                                  if (widget.collectionType == 'trophies')
                                    SizedBox(height: 0),

                                  // 收藏品名称
                                  Text(
                                    _collection!.name,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: textPrimaryColor,
                                    ),
                                  ),
                                  // 如果名称包含英文或日文，显示翻译按钮和结果
                                  if (_isEnglishOrJapanese(_collection!.name))
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (_translatedName != null)
                                          Text(
                                            _translatedName!,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontStyle: FontStyle.italic,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        if (_isTranslatingName)
                                          const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        else if (_translatedName != null)
                                          Text(
                                            '由腾讯云翻译自${_isEnglishAndJapanese(_collection!.name) ? '日语+英语' : _isEnglish(_collection!.name) ? '英语' : '日语'}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          )
                                        else
                                          TextButton(
                                            onPressed: _translateName,
                                            child: const Text('翻译为中文'),
                                          ),
                                      ],
                                    ),
                                  SizedBox(height: 16),

                                  // 颜色（仅称号）
                                  if (widget.collectionType == 'trophies' && _collection!.color != null)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '底色:',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            gradient: _collection!.color == 'Rainbow' 
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
                                            color: _collection!.color != 'Rainbow' 
                                                ? _getColorFromType(_collection!.color!)
                                                : null,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: Colors.grey,
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            _collection!.color!,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: _collection!.color == 'Rainbow' 
                                                  ? Colors.white
                                                  : _getTextColorForBackground(_collection!.color!),
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: 16),
                                      ],
                                    ),

                                  // 收藏品描述
                                  if (_collection!.description != null)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '描述:',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          _collection!.description!,
                                          style: TextStyle(
                                            fontSize: 16,
                                          ),
                                        ),
                                        // 如果描述包含英文或日文，显示翻译按钮和结果
                                        if (_isEnglishOrJapanese(_collection!.description!))
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              if (_translatedDescription != null)
                                                Text(
                                                  _translatedDescription!,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontStyle: FontStyle.italic,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              if (_isTranslatingDescription)
                                                const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: CircularProgressIndicator(strokeWidth: 2),
                                                )
                                              else if (_translatedDescription != null)
                                                Text(
                                                  '由腾讯云翻译自${_isEnglishAndJapanese(_collection!.description!) ? '日语+英语' : _isEnglish(_collection!.description!) ? '英语' : '日语'}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey,
                                                  ),
                                                )
                                              else
                                                TextButton(
                                                  onPressed: _translateDescription,
                                                  child: const Text('翻译为中文'),
                                                ),
                                            ],
                                          ),
                                        SizedBox(height: 16),
                                      ],
                                    ),

                                  // 所需条件
                                  if (_collection!.required != null && _collection!.required!.isNotEmpty)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '所需条件:',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        ..._getMergedRequiredConditions(_collection!.required!),
                                      ],
                                    ),

                                  // 歌曲列表
                                  if (_collection!.required != null && _collection!.required!.isNotEmpty)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '歌曲列表:',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        // 处理重复歌曲列表的情况
                                        ..._getUniqueSongLists(_collection!.required!),
                                      ],
                                    ),

                                  // 加载歌曲信息的状态
                                  if (_isLoadingSongs)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 16),
                                      child: Center(child: CircularProgressIndicator()),
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