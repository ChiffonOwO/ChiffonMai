import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_first_flutter_app/manager/CollectionsManager.dart';
import 'package:my_first_flutter_app/manager/UserPlayDataManager.dart';
import 'package:my_first_flutter_app/entity/Collection.dart';
import 'package:my_first_flutter_app/entity/Song.dart';
import 'package:my_first_flutter_app/utils/LuoXueToDivingFishUtil.dart';

class PaiziProgressService {
  // 单例模式
  static final PaiziProgressService _instance = PaiziProgressService._internal();
  factory PaiziProgressService() => _instance;
  PaiziProgressService._internal();

  // 匹配模式："x極"、"x将"、"x神"、"x舞舞"（x代表一个字符）
  final List<RegExp> _patterns = [
    RegExp(r'^(.{1})極$'),      // x極
    RegExp(r'^(.{1})将$'),      // x将
    RegExp(r'^(.{1})神$'),      // x神
    RegExp(r'^(.{1})舞舞$'),    // x舞舞
  ];

  // 获取所有符合条件的姓名框收藏品
  Future<List<Collection>> getMatchingPlates() async {
    try {
      final collectionsManager = CollectionsManager();
      final collectionData = await collectionsManager.fetchPlatesCollections();
      
      if (collectionData?.plates == null) {
        return [];
      }

      return collectionData!.plates!.where((plate) {
        final name = plate.name;
        return _patterns.any((pattern) => pattern.hasMatch(name));
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // 从收藏品名称中提取第一个字和称号类型
  Map<String, String>? extractNameParts(String name) {
    for (final pattern in _patterns) {
      final match = pattern.firstMatch(name);
      if (match != null) {
        final firstChar = match.group(1);
        String titleType;
        
        if (name.endsWith('極')) {
          titleType = '極';
        } else if (name.endsWith('将')) {
          titleType = '将';
        } else if (name.endsWith('神')) {
          titleType = '神';
        } else if (name.endsWith('舞舞')) {
          titleType = '舞舞';
        } else {
          titleType = '';
        }
        
        if (firstChar != null) {
          return {
            'firstChar': firstChar,
            'titleType': titleType,
          };
        }
      }
    }
    return null;
  }

  // 获取所有第一个字的选项
  Future<List<String>> getFirstCharOptions() async {
    final plates = await getMatchingPlates();
    final Set<String> chars = {};
    
    for (final plate in plates) {
      final parts = extractNameParts(plate.name);
      if (parts != null) {
        chars.add(parts['firstChar']!);
      }
    }
    
    return chars.toList()..sort();
  }

  // 获取称号类型选项
  // 当firstChar为'舞'时，额外添加'霸者'选项
  List<String> getTitleTypeOptions({String? firstChar}) {
    final options = ['極', '将', '大将', '神', '舞舞'];
    if (firstChar == '舞') {
      options.add('霸者');
    }
    return options;
  }

  // 根据第一个字和称号类型获取对应的收藏品
  Future<Collection?> getPlateBySelection(String firstChar, String titleType) async {
    // 特殊处理：霸者称号查找id为6148的收藏品（需要从所有plates中查找）
    if (titleType == '霸者') {
      final collectionsManager = CollectionsManager();
      final collectionData = await collectionsManager.fetchPlatesCollections();
      if (collectionData?.plates == null) {
        return null;
      }
      try {
        return collectionData!.plates!.firstWhere((plate) => plate.id == 6148);
      } catch (e) {
        return null;
      }
    }
    
    // 特殊处理：真将和真大将使用真神的歌曲列表
    if (firstChar == '真' && (titleType == '将' || titleType == '大将')) {
      final plates = await getMatchingPlates();
      try {
        return plates.firstWhere((plate) => plate.name == '真神');
      } catch (e) {
        return null;
      }
    }
    
    // 特殊处理：大将显示将的图片
    String targetTitleType = titleType;
    if (titleType == '大将') {
      targetTitleType = '将';
    }
    
    // 其他称号类型从匹配的plates中查找
    final plates = await getMatchingPlates();
    final targetName = firstChar + targetTitleType;
    
    try {
      return plates.firstWhere((plate) => plate.name == targetName);
    } catch (e) {
      return null;
    }
  }

  // 缓存的记录Map，用于加速查找
  Map<String, Map<String, dynamic>>? _recordsCache;

  // 初始化记录缓存
  Future<void> _initRecordsCache() async {
    if (_recordsCache != null) {
      return;
    }

    final playData = await _getUserPlayData();
    if (playData == null) {
      _recordsCache = {};
      return;
    }

    final records = playData['records'];
    if (!(records is List)) {
      _recordsCache = {};
      return;
    }

    _recordsCache = {};
    for (final item in records) {
      if (item is Map<String, dynamic>) {
        final songId = item['song_id'] as int?;
        // 使用 level_index 字段而不是 level 字段
        final level = item['level_index'] as int?;
        if (songId != null && level != null) {
          final key = '${songId}_$level';
          _recordsCache![key] = item;
        }
      }
    }
  }

  // 判断歌曲是否满足称号要求
  Future<bool> isSongCompleted(int songId, int difficulty, String titleType) async {
    // 确保缓存已初始化
    await _initRecordsCache();

    // 使用缓存查找记录
    final key = '${songId}_$difficulty';
    final record = _recordsCache?[key];

    if (record == null) {
      return false;
    }

    // 根据称号类型判断完成条件
    switch (titleType) {
      case '極':
        // fc字段为非空且非sync
        final fc = record['fc'] as String?;
        return fc != null && fc.isNotEmpty && fc != 'sync';
      
      case '将':
        // achievements字段大于等于100
        final achievements = double.tryParse(record['achievements'].toString()) ?? 0;
        return achievements >= 100;
      
      case '大将':
        // achievements字段大于等于100.5
        final achievements = double.tryParse(record['achievements'].toString()) ?? 0;
        return achievements >= 100.5;
      
      case '神':
        // fc字段为ap或app
        final fc = record['fc'] as String?;
        return fc == 'ap' || fc == 'app';
      
      case '舞舞':
        // fs字段为fsd或fsdp
        final fs = record['fs'] as String?;
        return fs == 'fsd' || fs == 'fsdp';
      
      case '霸者':
        // 达成率大于等于80%
        final achievements = double.tryParse(record['achievements'].toString()) ?? 0;
        return achievements >= 80;
      
      default:
        return false;
    }
  }

  // 获取缓存的用户游玩数据
  Future<Map<String, dynamic>?> _getUserPlayData() async {
    final manager = UserPlayDataManager();
    return await manager.getCachedUserPlayData();
  }

  // 获取所有可用难度选项（去重），包含ALL选项(-1)
  Future<List<int>> getAvailableDifficulties(String firstChar, String titleType) async {
    final plate = await getPlateBySelection(firstChar, titleType);
    if (plate == null || plate.required == null) {
      return [-1];
    }

    final Set<int> difficulties = {-1}; // -1 表示 ALL
    for (final req in plate.required!) {
      if (req.difficulties != null) {
        difficulties.addAll(req.difficulties!);
      }
    }
    
    return difficulties.toList()..sort();
  }

  // 获取难度显示名称（支持ALL）
  String getDifficultyName(int difficulty) {
    if (difficulty == -1) {
      return 'ALL';
    }
    switch (difficulty) {
      case 0: return 'BASIC';
      case 1: return 'ADVANCED';
      case 2: return 'EXPERT';
      case 3: return 'MASTER';
      case 4: return 'RE:MASTER';
      default: return difficulty.toString();
    }
  }

  // 获取歌曲的达成率
  double getSongAchievement(int songId, int difficulty) {
    final key = '${songId}_$difficulty';
    final record = _recordsCache?[key];
    if (record == null) {
      return 0.0;
    }
    return double.tryParse(record['achievements'].toString()) ?? 0.0;
  }

  // 缓存键常量
  static const String _keyFirstChar = 'paizi_progress_first_char';
  static const String _keyTitleType = 'paizi_progress_title_type';
  static const String _keyDifficulty = 'paizi_progress_difficulty';
  static const String _keyShowListMode = 'paizi_progress_show_list_mode';
  static const String _keyUseLevelDisplay = 'paizi_progress_use_level_display';
  static const String _keyFilterMode = 'paizi_progress_filter_mode';

  // 保存用户选择的选项
  Future<void> saveSelectedOptions({
    required String? firstChar,
    required String? titleType,
    required int? difficulty,
    required bool showListMode,
    required bool useLevelDisplay,
    required String? filterMode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFirstChar, firstChar ?? '');
    await prefs.setString(_keyTitleType, titleType ?? '');
    await prefs.setInt(_keyDifficulty, difficulty ?? -1);
    await prefs.setBool(_keyShowListMode, showListMode);
    await prefs.setBool(_keyUseLevelDisplay, useLevelDisplay);
    await prefs.setString(_keyFilterMode, filterMode ?? 'all');
  }

  // 获取保存的用户选项
  Future<Map<String, dynamic>> getSavedOptions() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'firstChar': prefs.getString(_keyFirstChar) ?? '',
      'titleType': prefs.getString(_keyTitleType) ?? '',
      'difficulty': prefs.getInt(_keyDifficulty) ?? -1,
      'showListMode': prefs.getBool(_keyShowListMode) ?? true,
      'useLevelDisplay': prefs.getBool(_keyUseLevelDisplay) ?? true,
      'filterMode': prefs.getString(_keyFilterMode) ?? 'all',
    };
  }

  // 获取指定称号和难度的所有歌曲及其完成状态
  Future<List<Map<String, dynamic>>> getSongsWithCompletionStatus(
    String firstChar,
    String titleType,
    int difficulty,
  ) async {
    final plate = await getPlateBySelection(firstChar, titleType);
    if (plate == null || plate.required == null) {
      return [];
    }

    // 使用 LuoXueToDivingFishUtil 获取正确的歌曲映射
    final songMap = await LuoXueToDivingFishUtil.getSongsFromCache(plate);

    final result = <Map<String, dynamic>>[];

    // ALL模式：遍历所有难度
    if (difficulty == -1) {
      for (final req in plate.required!) {
        if (req.difficulties != null && req.songs != null) {
          for (final diff in req.difficulties!) {
            for (final requiredSong in req.songs!) {
              final Song? song = songMap[requiredSong];
              
              if (song != null) {
                final completed = await isSongCompleted(int.parse(song.id), diff, titleType);
                result.add({
                  'song': song,
                  'completed': completed,
                  'difficulty': diff,
                });
              } else {
                final completed = await isSongCompleted(requiredSong.id, diff, titleType);
                result.add({
                  'song': requiredSong,
                  'completed': completed,
                  'difficulty': diff,
                });
              }
            }
          }
        }
      }
    } else {
      // 指定难度模式
      for (final req in plate.required!) {
        if (req.difficulties != null && !req.difficulties!.contains(difficulty)) {
          continue;
        }

        if (req.songs != null) {
          for (final requiredSong in req.songs!) {
            final Song? song = songMap[requiredSong];
            
            if (song != null) {
              final completed = await isSongCompleted(int.parse(song.id), difficulty, titleType);
              result.add({
                'song': song,
                'completed': completed,
                'difficulty': difficulty,
              });
            } else {
              final completed = await isSongCompleted(requiredSong.id, difficulty, titleType);
              result.add({
                'song': requiredSong,
                'completed': completed,
                'difficulty': difficulty,
              });
            }
          }
        }
      }
    }

    // 按照所选难度下的定数降序排序
    result.sort((a, b) {
      final songA = a['song'];
      final songB = b['song'];
      final diffA = a['difficulty'] as int;
      final diffB = b['difficulty'] as int;
      
      double dsA = -1;
      double dsB = -1;
      
      if (songA is Song && songA.ds != null && diffA < songA.ds.length) {
        dsA = songA.ds[diffA];
      }
      if (songB is Song && songB.ds != null && diffB < songB.ds.length) {
        dsB = songB.ds[diffB];
      }
      
      // 降序排序
      return dsB.compareTo(dsA);
    });

    return result;
  }
}