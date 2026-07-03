import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:media_scanner/media_scanner.dart';
import '../../service/Collection/CollectionInfoService.dart';
import '../../entity/LuoXue/Collection.dart';
import '../../utils/LuoXueToDivingFishUtil.dart';
import '../../utils/CommonWidgetUtil.dart';
import '../../utils/CollectionsImageUtil.dart';
import '../../utils/CoverUtil.dart';
import '../../utils/StringUtil.dart';
import '../../utils/TranslationUtil.dart';
import '../../utils/AppTheme.dart';
import '../SongInfoPage.dart';

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
  bool _isSavingImage = false;

  // 获取图片URL
  String? _getImageUrl() {
    if (_collection == null) return null;
    const String imageBaseUrl = 'https://assets2.lxns.net/maimai';
    switch (widget.collectionType) {
      case 'icons':
        return '$imageBaseUrl/icon/${_collection!.id}.png';
      case 'plates':
        return '$imageBaseUrl/plate/${_collection!.id}.png';
      case 'frames':
        return '$imageBaseUrl/frame/${_collection!.id}.png';
      default:
        return null;
    }
  }

  // 请求存储权限
  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      PermissionStatus storageStatus = await Permission.storage.status;
      PermissionStatus photosStatus = await Permission.photos.status;
      PermissionStatus videosStatus = await Permission.videos.status;

      if (storageStatus.isGranted || photosStatus.isGranted || videosStatus.isGranted) {
        return true;
      }

      Map<Permission, PermissionStatus> statuses = await [
        Permission.storage,
        Permission.photos,
        Permission.videos,
      ].request();

      bool storageGranted = statuses[Permission.storage]?.isGranted ?? false;
      bool photosGranted = statuses[Permission.photos]?.isGranted ?? false;
      bool videosGranted = statuses[Permission.videos]?.isGranted ?? false;

      return storageGranted || photosGranted || videosGranted;
    } else {
      PermissionStatus status = await Permission.storage.request();
      return status.isGranted;
    }
  }

  // 保存图片到相册
  Future<void> _saveImageToGallery() async {
    String? imageUrl = _getImageUrl();
    if (imageUrl == null) {
      _showToast('该收藏品没有图片');
      return;
    }

    setState(() {
      _isSavingImage = true;
    });

    try {
      bool hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('权限不足'),
            content: Text('需要存储权限才能保存图片到相册，请在设置中开启权限'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('确定'),
              ),
            ],
          ),
        );
        return;
      }

      // 下载图片
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        _showToast('图片下载失败');
        return;
      }

      Uint8List imageBytes = response.bodyBytes;

      // 保存到相册
      Directory? directory;
      if (Platform.isAndroid) {
        String picturesPath = '/storage/emulated/0/Pictures';
        directory = Directory(picturesPath);
        if (!directory.existsSync()) {
          directory.createSync(recursive: true);
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      final file = File('${directory.path}/collection_${_collection!.id}_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(imageBytes);

      // 通知系统刷新相册
      if (Platform.isAndroid) {
        await MediaScanner.loadMedia(path: file.path);
      }

      _showToast('图片已保存到相册');
    } catch (e) {
      debugPrint('保存图片失败: $e');
      _showToast('保存图片失败: $e');
    } finally {
      setState(() {
        _isSavingImage = false;
      });
    }
  }

  // 显示Toast提示
  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // 复制图片链接到剪贴板
  Future<void> _copyImageUrl() async {
    String? imageUrl = _getImageUrl();
    if (imageUrl == null) {
      _showToast('该收藏品没有图片链接');
      return;
    }

    try {
      await Clipboard.setData(ClipboardData(text: imageUrl));
      _showToast('链接已复制到剪贴板');
    } catch (e) {
      debugPrint('复制链接失败: $e');
      _showToast('复制链接失败');
    }
  }

  // 自定义常量
  final Color themeColor = Colors.blue;
  final double borderRadiusSmall = 8.0;

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
      debugPrint('加载收藏品详情时出错: $e');
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
      debugPrint('翻译名称失败: $e');
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
      debugPrint('翻译描述失败: $e');
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
      debugPrint('加载歌曲信息时出错: $e');
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

  // 获取定数显示（第3,4,5个定数，第5个没有显示为-）
  String _getDsDisplay(List<double>? dsList) {
    if (dsList == null || dsList.isEmpty) {
      return '- / - / -';
    }
    String ds3 = dsList.length > 2 ? dsList[2].toStringAsFixed(1) : '-';
    String ds4 = dsList.length > 3 ? dsList[3].toStringAsFixed(1) : '-';
    String ds5 = dsList.length > 4 ? dsList[4].toStringAsFixed(1) : '-';
    return '$ds3 / $ds4 / $ds5';
  }

  // 获取难度显示
  Widget _getDifficultiesDisplay(List<int> difficulties) {
    final Map<int, Map<String, dynamic>> difficultyMap = {
      0: {'label': 'BASIC', 'color': AppColors.difficultyForegroundByIndex(0), 'bgColor': AppColors.difficultyBackgroundByIndex(0)},
      1: {'label': 'ADVANCED', 'color': AppColors.difficultyForegroundByIndex(1), 'bgColor': AppColors.difficultyBackgroundByIndex(1)},
      2: {'label': 'EXPERT', 'color': AppColors.difficultyForegroundByIndex(2), 'bgColor': AppColors.difficultyBackgroundByIndex(2)},
      3: {'label': 'MASTER', 'color': AppColors.difficultyForegroundByIndex(3), 'bgColor': AppColors.difficultyBackgroundByIndex(3)},
      4: {'label': 'RE:MASTER', 'color': AppColors.difficultyForegroundByIndex(4), 'bgColor': AppColors.difficultyBackgroundByIndex(4)},
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
      'ap': {'label': 'AP', 'color': AppColors.achievementForeground('AP'), 'bgColor': AppColors.achievementBackground('AP')},
      'app': {'label': 'AP+', 'color': AppColors.achievementForeground('AP+'), 'bgColor': AppColors.achievementBackground('AP+')},
      'fc': {'label': 'FC', 'color': AppColors.achievementForeground('FC'), 'bgColor': AppColors.achievementBackground('FC')},
      'fcp': {'label': 'FC+', 'color': AppColors.achievementForeground('FC+'), 'bgColor': AppColors.achievementBackground('FC+')},
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
      'fs': {'label': 'FS', 'color': AppColors.achievementForeground('FS'), 'bgColor': AppColors.achievementBackground('FS')},
      'fsp': {'label': 'FS+', 'color': AppColors.achievementForeground('FS+'), 'bgColor': AppColors.achievementBackground('FS+')},
      'fsd': {'label': 'FDX', 'color': AppColors.achievementForeground('FDX'), 'bgColor': AppColors.achievementBackground('FDX')},
      'fsdp': {'label': 'FDX+', 'color': AppColors.achievementForeground('FDX+'), 'bgColor': AppColors.achievementBackground('FDX+')},
      'sync': {'label': 'SYNC', 'color': AppColors.achievementForeground('SYNC'), 'bgColor': AppColors.achievementBackground('SYNC')},
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
    final Set<String> seenSongs = {}; // 用于统计唯一歌曲数量
    final List<Widget> uniqueSongLists = [];

    for (final requiredItem in requiredList) {
      if (requiredItem.songs != null && requiredItem.songs!.isNotEmpty) {
        // 将歌曲列表转换为唯一字符串，用于去重
        final songListKey = requiredItem.songs!.map((song) => '${song.id}:${song.title}:${song.type}').join(',');
        
        if (!seenSongLists.contains(songListKey)) {
          seenSongLists.add(songListKey);
          
          // 统计唯一歌曲数量
          for (final song in requiredItem.songs!) {
            seenSongs.add('${song.id}:${song.title}:${song.type}');
          }
          
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
                    // 获取定数列表
                    List<double> dsList = [];
                    if (song != null && song.ds != null && song.ds is List) {
                      dsList = song.ds;
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
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.tableBorder(Theme.of(context).brightness),
                            width: 1,
                          ),
                        ),
                        padding: EdgeInsets.all(4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // 曲绘
                            Container(
                              width: 40,
                              height: 40,
                              child: CoverUtil.buildCoverWidgetWithContext(
                                context,
                                song?.id.toString() ?? requiredSong.id.toString(),
                                40,
                              ),
                            ),
                            SizedBox(width: 6),
                            // 歌曲信息
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    requiredSong.title,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 1),
                                  // 第二行：类型|版本
                                  Text(
                                    '${_getTypeDisplay(requiredSong.type)} | ${song != null ? StringUtil.formatVersion2(song.basicInfo.from) : '-'}',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 1),
                                  // 第三行：第3,4,5个定数（EXPERT/MASTER/RE:MASTER）
                                  Text(
                                    _getDsDisplay(dsList),
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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

    // 添加歌曲数量显示
    if (seenSongs.isNotEmpty) {
      uniqueSongLists.insert(0, Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '总计 ${seenSongs.length} 首歌曲',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 8),
        ],
      ));
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

    // 检查描述中是否包含 RANK 信息
    if (_collection?.description != null) {
      final description = _collection!.description!;
      final rankRegex = RegExp(r'RANK\s*(S+\+?)');
      final match = rankRegex.firstMatch(description);
      String requiredRate = '';
      
      // 检查是否包含 CLEAR 字样
      bool hasClear = description.toLowerCase().contains('clear');
      // 检查是否包含 RANK A 字样
      bool hasRankA = description.toLowerCase().contains('rank a');
      
      if (match != null) {
        final rank = match.group(1);
        
        // 根据 RANK 级别确定所需最低达成率
        switch (rank) {
          case 'S':
            requiredRate = '97%';
            break;
          case 'S+':
            requiredRate = '98%';
            break;
          case 'SS':
            requiredRate = '99%';
            break;
          case 'SS+':
            requiredRate = '99.5%';
            break;
          case 'SSS':
            requiredRate = '100%';
            break;
          case 'SSS+':
            requiredRate = '100.5%';
            break;
        }
      } else if (hasClear || hasRankA) {
        // 如果没有 RANK 信息但有 CLEAR 或 RANK A 字样，设置为 80%
        requiredRate = '80%';
      }
      
      if (requiredRate.isNotEmpty) {
        // 根据达成率确定颜色
        Color rateColor = Colors.grey[800]!;
        if (requiredRate == '80%') {
          rateColor = AppColors.errorRed(Theme.of(context).brightness);
        } else if (['97%', '98%', '99%', '99.5%'].contains(requiredRate)) {
          rateColor = AppColors.linkBlue(Theme.of(context).brightness);
        } else if (['100%', '100.5%'].contains(requiredRate)) {
          rateColor = AppColors.warningOrange(Theme.of(context).brightness);
        }
        
        mergedConditions.add(
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '所需最低达成率:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: rateColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: rateColor, width: 1),
                  ),
                  child: Text(
                    requiredRate,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: rateColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      
      // 检查是否包含 SPEED SONIC 字样
      bool hasSpeedSonic = description.toLowerCase().contains('speed sonic');
      if (hasSpeedSonic) {
        mergedConditions.add(
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '所需游玩流速:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.linkBlue(Theme.of(context).brightness).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.linkBlue(Theme.of(context).brightness), width: 1),
                  ),
                  child: Text(
                    'SONIC',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.linkBlue(Theme.of(context).brightness),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
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
    final brightness = Theme.of(context).brightness;
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
                      icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
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
                            color: Theme.of(context).colorScheme.onSurface,
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
                    color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(borderRadiusSmall),
                    boxShadow: [AppColors.defaultShadow(brightness)],
                  ),
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator())
                      : _collection == null
                          ? Center(child: Text('未找到收藏品信息'))
                          : Padding(
                              padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
                              child: ListView(
                                key: Key('collection_${widget.collectionId}_${widget.collectionType}'),
                                children: [
                                  // 收藏品图片
                                  if (widget.collectionType == 'icons')
                                    Column(
                                      children: [
                                        Container(
                                          width: double.infinity,
                                          height: 200,
                                          child: CollectionsImageUtil.getIconImageURL(_collection!),
                                        ),
                                        SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: themeColor,
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                ),
                                                onPressed: _isSavingImage ? null : _saveImageToGallery,
                                                child: _isSavingImage
                                                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                                                    : Row(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          Icon(Icons.save_alt, size: 16),
                                                          SizedBox(width: 4),
                                                          Text('保存到相册'),
                                                        ],
                                                      ),
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                ),
                                                onPressed: _copyImageUrl,
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.link, size: 16),
                                                    SizedBox(width: 4),
                                                    Text('复制链接'),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  if (widget.collectionType == 'plates')
                                    Column(
                                      children: [
                                        Container(
                                          width: double.infinity,
                                          height: 150,
                                          child: CollectionsImageUtil.getPlateImageURL(_collection!),
                                        ),
                                        SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: themeColor,
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                ),
                                                onPressed: _isSavingImage ? null : _saveImageToGallery,
                                                child: _isSavingImage
                                                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                                                    : Row(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          Icon(Icons.save_alt, size: 16),
                                                          SizedBox(width: 4),
                                                          Text('保存到相册'),
                                                        ],
                                                      ),
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                ),
                                                onPressed: _copyImageUrl,
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.link, size: 16),
                                                    SizedBox(width: 4),
                                                    Text('复制链接'),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  if (widget.collectionType == 'frames')
                                    Column(
                                      children: [
                                        Container(
                                          width: double.infinity,
                                          height: 200,
                                          child: CollectionsImageUtil.getFrameImageURL(_collection!),
                                        ),
                                        SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: themeColor,
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                ),
                                                onPressed: _isSavingImage ? null : _saveImageToGallery,
                                                child: _isSavingImage
                                                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                                                    : Row(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          Icon(Icons.save_alt, size: 16),
                                                          SizedBox(width: 4),
                                                          Text('保存到相册'),
                                                        ],
                                                      ),
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                ),
                                                onPressed: _copyImageUrl,
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.link, size: 16),
                                                    SizedBox(width: 4),
                                                    Text('复制链接'),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  if (widget.collectionType == 'trophies')
                                    SizedBox(height: 0),

                                  // 收藏品名称
                                  Text(
                                    _collection!.name,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  // 收藏品ID
                                  Text(
                                    'ID: ${widget.collectionId}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontStyle: FontStyle.italic,
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                                              color: AppColors.tableBorder(brightness),
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
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontStyle: FontStyle.italic,
                                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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