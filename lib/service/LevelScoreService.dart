import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_first_flutter_app/manager/MaimaiMusicDataManager.dart';
import 'package:my_first_flutter_app/manager/UserPlayDataManager.dart';
import 'package:my_first_flutter_app/entity/Song.dart';

class LevelScoreService {
  // 单例模式
  static final LevelScoreService _instance = LevelScoreService._internal();
  factory LevelScoreService() => _instance;
  LevelScoreService._internal();

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
        final level = item['level_index'] as int?;
        if (songId != null && level != null) {
          final key = '${songId}_$level';
          _recordsCache![key] = item;
        }
      }
    }
  }

  // 获取缓存的用户游玩数据
  Future<Map<String, dynamic>?> _getUserPlayData() async {
    final manager = UserPlayDataManager();
    return await manager.getCachedUserPlayData();
  }

  // 获取所有歌曲
  Future<List<Song>?> getAllSongs() async {
    final musicManager = MaimaiMusicDataManager();
    return await musicManager.getCachedSongs();
  }

  // 根据等级类型获取歌曲及其完成状态
  Future<List<Map<String, dynamic>>> getSongsByLevel(
    String levelKey, // 如 "1", "1+", "15"
    String titleType, // '極', '将', '神'
    int difficulty, // 难度索引 0-4，-1 表示 ALL
  ) async {
    await _initRecordsCache();

    final songs = await getAllSongs();
    if (songs == null) {
      return [];
    }

    // 获取每个歌曲的完成状态
    final result = <Map<String, dynamic>>[];
    
    for (final song in songs) {
      // 排除id为6位数的谱面
      if (song.id.length == 6 && int.tryParse(song.id) != null) {
        continue;
      }

      // ALL模式：为每个符合条件的难度生成独立条目
      if (difficulty == -1) {
        for (int i = 0; i < song.ds.length; i++) {
          if (_getLevelDisplay(song.ds[i]) == levelKey) {
            final completed = isSongCompletedSync(int.parse(song.id), i, titleType);
            result.add({
              'song': song,
              'completed': completed,
              'difficulty': i, // 保存具体难度索引
            });
          }
        }
      } else {
        // 指定难度模式
        if (difficulty < song.ds.length && _getLevelDisplay(song.ds[difficulty]) == levelKey) {
          final completed = await isSongCompleted(int.parse(song.id), difficulty, titleType);
          result.add({
            'song': song,
            'completed': completed,
            'difficulty': difficulty,
          });
        }
      }
    }

    // 按定数降序排序
    result.sort((a, b) {
      final songA = a['song'] as Song;
      final songB = b['song'] as Song;
      final diffA = a['difficulty'] as int;
      final diffB = b['difficulty'] as int;
      double dsA = songA.ds.length > diffA ? songA.ds[diffA] : -1;
      double dsB = songB.ds.length > diffB ? songB.ds[diffB] : -1;
      return dsB.compareTo(dsA);
    });

    return result;
  }

  // 同步版本的isSongCompleted，用于ALL模式下的批量检查
  bool isSongCompletedSync(int songId, int difficulty, String titleType) {
    final key = '${songId}_$difficulty';
    final record = _recordsCache?[key];

    if (record == null) {
      return false;
    }

    switch (titleType) {
      case '極':
        final fc = record['fc'] as String?;
        return fc != null && fc.isNotEmpty && fc != 'sync';

      case '将':
        final achievements = double.tryParse(record['achievements'].toString()) ?? 0;
        return achievements >= 100;

      case '神':
        final fc = record['fc'] as String?;
        return fc == 'ap' || fc == 'app';

      case '全97':
        final achievements = double.tryParse(record['achievements'].toString()) ?? 0;
        return achievements >= 97;

      case '全98':
        final achievements = double.tryParse(record['achievements'].toString()) ?? 0;
        return achievements >= 98;

      case '全99':
        final achievements = double.tryParse(record['achievements'].toString()) ?? 0;
        return achievements >= 99;

      case '全99.5':
        final achievements = double.tryParse(record['achievements'].toString()) ?? 0;
        return achievements >= 99.5;

      default:
        return false;
    }
  }

  // 判断歌曲是否满足称号要求
  Future<bool> isSongCompleted(int songId, int difficulty, String titleType) async {
    await _initRecordsCache();
    return isSongCompletedSync(songId, difficulty, titleType);
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

  // 根据定数计算等级显示（x或x+）
  String _getLevelDisplay(double ds) {
    if (ds >= 15.0) {
      return '15';
    }
    int integerPart = ds.floor();
    double decimalPart = ds - integerPart;
    if (decimalPart <= 0.5) {
      return '$integerPart';
    } else {
      return '${integerPart}+';
    }
  }

  // 获取所有可用的等级选项（按指定难度）
  Future<List<String>> getLevelOptions(int difficulty) async {
    final songs = await getAllSongs();
    if (songs == null) {
      return [];
    }

    final Set<String> levels = {};
    for (final song in songs) {
      // 排除id为6位数的谱面
      if (song.id.length == 6 && int.tryParse(song.id) != null) {
        continue;
      }
      if (difficulty < song.ds.length) {
        levels.add(_getLevelDisplay(song.ds[difficulty]));
      }
    }

    // 按等级排序
    return levels.toList()..sort((a, b) {
      double parseLevel(String level) {
        if (level == '15') return 15.0;
        if (level.endsWith('+')) {
          return double.parse(level.substring(0, level.length - 1)) + 0.5;
        }
        return double.tryParse(level) ?? 0.0;
      }
      return parseLevel(b).compareTo(parseLevel(a)); // 降序
    });
  }

  // 缓存的全量等级选项
  List<String>? _allLevelOptionsCache;

  // 获取所有难度的所有等级选项（全量）
  Future<List<String>> getAllLevelOptions() async {
    // 如果已有缓存，直接返回
    if (_allLevelOptionsCache != null) {
      return _allLevelOptionsCache!;
    }

    final songs = await getAllSongs();
    if (songs == null) {
      return [];
    }

    final Set<String> levels = {};
    for (final song in songs) {
      // 排除id为6位数的谱面
      if (song.id.length == 6 && int.tryParse(song.id) != null) {
        continue;
      }
      // 遍历所有难度
      for (final ds in song.ds) {
        levels.add(_getLevelDisplay(ds));
      }
    }

    // 按等级排序
    _allLevelOptionsCache = levels.toList()..sort((a, b) {
      double parseLevel(String level) {
        if (level == '15') return 15.0;
        if (level.endsWith('+')) {
          return double.parse(level.substring(0, level.length - 1)) + 0.5;
        }
        return double.tryParse(level) ?? 0.0;
      }
      return parseLevel(b).compareTo(parseLevel(a)); // 降序
    });

    return _allLevelOptionsCache!;
  }

  // 清空全量等级选项缓存
  void clearAllLevelOptionsCache() {
    _allLevelOptionsCache = null;
  }

  // 获取称号类型选项
  List<String> getTitleTypeOptions() {
    return ['極', '将', '神', '全97', '全98', '全99', '全99.5'];
  }

  // 获取难度选项
  List<int> getDifficultyOptions() {
    return [-1, 0, 1, 2, 3, 4];
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

  // 缓存键常量
  static const String _keyLevel = 'level_score_level';
  static const String _keyTitleType = 'level_score_title_type';
  static const String _keyDifficulty = 'level_score_difficulty';
  static const String _keyShowListMode = 'level_score_show_list_mode';

  // 保存用户选择的选项
  Future<void> saveSelectedOptions({
    required String? level,
    required String? titleType,
    required int? difficulty,
    required bool showListMode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLevel, level ?? '');
    await prefs.setString(_keyTitleType, titleType ?? '');
    await prefs.setInt(_keyDifficulty, difficulty ?? -1);
    await prefs.setBool(_keyShowListMode, showListMode);
  }

  // 获取保存的用户选项
  Future<Map<String, dynamic>> getSavedOptions() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'level': prefs.getString(_keyLevel) ?? '',
      'titleType': prefs.getString(_keyTitleType) ?? '',
      'difficulty': prefs.getInt(_keyDifficulty) ?? -1,
      'showListMode': prefs.getBool(_keyShowListMode) ?? true,
    };
  }
}