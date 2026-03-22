import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/manager/MaimaiMusicDataManager.dart';
import '../manager/UserPlayDataManager.dart';

class UserScoreSearchService {
  // 单例模式
  static final UserScoreSearchService _instance = UserScoreSearchService._internal();
  factory UserScoreSearchService() => _instance;
  UserScoreSearchService._internal();

  // 从缓存获取用户游玩数据
  Future<Map<String, dynamic>?> getUserPlayData() async {
    final userPlayDataManager = UserPlayDataManager();
    return await userPlayDataManager.getCachedUserPlayData();
  }

  // 获取排序后的歌曲列表
  Future<List<dynamic>> getSortedSongs(Map<String, dynamic> userPlayData, String sortBy) async  {
    if (userPlayData.containsKey('records') && userPlayData['records'] is List) {
      List<dynamic> songs = List.from(userPlayData['records']);
      
      // 根据排序方式进行排序
      switch (sortBy) {
        case 'Rating':
          // 按 ra 降序排序
          songs.sort((a, b) => (b['ra'] ?? 0).compareTo(a['ra'] ?? 0));
          break;
        case '达成率':
          // 按 achievements 降序排序
          songs.sort((a, b) {
            double aAchievements = double.tryParse(a['achievements'].toString()) ?? 0;
            double bAchievements = double.tryParse(b['achievements'].toString()) ?? 0;
            return bAchievements.compareTo(aAchievements);
          });
          break;
        case '定数':
          // 按 ds 降序排序
          songs.sort((a, b) {
            double aDs = double.tryParse(a['ds'].toString()) ?? 0;
            double bDs = double.tryParse(b['ds'].toString()) ?? 0;
            return bDs.compareTo(aDs);
          });
          break;
        case 'DX分达成率':
          // 初始化歌曲缓存
          await _initSongCache();
          
          // 先批量计算所有歌曲的DX达成率（异步）
          // 用Map存储 歌曲 -> 达成率，避免排序时重复计算
          Map<dynamic, double> dxRateMap = {};
          for (var song in songs) {
            double rate = await _calculateDXScoreRate(song);
            dxRateMap[song] = rate;
          }
          // 基于提前计算好的达成率同步排序
          songs.sort((a, b) {
            double aRate = dxRateMap[a] ?? 0;
            double bRate = dxRateMap[b] ?? 0;
            return bRate.compareTo(aRate); // 降序排序
          });
          break;
        default:
          // 默认按 ra 降序排序
          songs.sort((a, b) => (b['ra'] ?? 0).compareTo(a['ra'] ?? 0));
      }
      
      return songs;
    }
    return [];
  }
  
  // 缓存变量
  List<dynamic>? _cachedSongs;

  // 初始化歌曲缓存
  Future<void> _initSongCache() async {
    if (_cachedSongs == null) {
      final manager = MaimaiMusicDataManager();
      if (await manager.hasCachedData()) {
        _cachedSongs = await manager.getCachedSongs();
      }
    }
  }

  // 计算DX分达成率（私有方法）
  Future<double> _calculateDXScoreRate(dynamic record) async {
    if (record == null) return 0.0;
    
    // 获取DX分
    int dxScore = int.tryParse(record['dxScore'].toString()) ?? 0;

    // 获取歌曲ID和难度索引
    String songId = record['song_id'].toString();
    int levelIndex = int.tryParse(record['level_index'].toString()) ?? 0;
    
    // 计算最大DX分 (根据notes总和 * 3)
    int maxScore = 0;

    // 尝试从缓存获取notes信息
    try {
      // 初始化缓存
      await _initSongCache();
      
      if (_cachedSongs != null && _cachedSongs!.isNotEmpty) {
        // 查找对应乐曲
        var song = _cachedSongs!.firstWhere(
          (s) => s.id == songId,
        );
        // 如果找到歌曲，且难度索引有效
        if (song != null && levelIndex >= 0 && levelIndex < song.charts.length) {
          // 获取对应难度的charts
          var chart = song.charts[levelIndex];
          // 计算notes总和
          int notesSum = chart.notes.fold(0, (sum, note) => sum + note);
          maxScore = notesSum * 3;
        }
      }
    } catch (e) {
      print('从缓存获取notes信息时出错: $e');
    }
    // 计算DX分达成率
    return maxScore > 0 ? dxScore / maxScore : 0.0;
  }
  
  // 计算DX分达成率（公共方法）
  Future<double> calculateDXScoreRate(dynamic record) async {
    return await _calculateDXScoreRate(record);
  }

  // 分页获取歌曲数据
  List<dynamic> getPagedSongs(List<dynamic> songs, int page, int pageSize) {
    int startIndex = (page - 1) * pageSize;
    int endIndex = startIndex + pageSize;
    if (startIndex >= songs.length) {
      return [];
    }
    if (endIndex > songs.length) {
      endIndex = songs.length;
    }
    return songs.sublist(startIndex, endIndex);
  }
  
  // 筛选歌曲
  Future<List<dynamic>> filterSongs(List<dynamic> songs, Map<String, String> filterConditions) async {
    // 初始化缓存
    await _initSongCache();
    return songs.where((song) {
      // 版本筛选
      if (filterConditions['版本筛选'] != null && filterConditions['版本筛选']!.isNotEmpty) {
        String version = filterConditions['版本筛选']!;
        // 从缓存的音乐数据中获取版本信息
        String songId = song['song_id'].toString();
        bool versionMatch = false;
        
        if (_cachedSongs != null) {
          var foundSong = _cachedSongs!.firstWhere(
            (s) => s.id == songId,
          );
          if (foundSong != null && foundSong.basicInfo.from != '') {
            versionMatch = foundSong.basicInfo.from == version;
          }
        }
        
        if (!versionMatch) {
          return false;
        }
      }
      
      // 定数筛选
      if (filterConditions['定数筛选'] != null && filterConditions['定数筛选']!.isNotEmpty) {
        String dsRange = filterConditions['定数筛选']!;
        if (dsRange.contains('-')) {
          List<String> parts = dsRange.split('-');
          if (parts.length == 2) {
            double minDs = double.tryParse(parts[0]) ?? 1.0;
            double maxDs = double.tryParse(parts[1]) ?? 15.0;
            double songDs = double.tryParse(song['ds'].toString()) ?? 0;
            if (songDs < minDs || songDs > maxDs) {
              return false;
            }
          }
        }
      }
      
      // 难度筛选
      if (filterConditions['难度筛选'] != null && filterConditions['难度筛选']!.isNotEmpty) {
        String difficulty = filterConditions['难度筛选']!;
        Map<String, int> difficultyMap = {
          'BASIC': 0,
          'ADVANCED': 1,
          'EXPERT': 2,
          'MASTER': 3,
          'Re:MASTER': 4,
        };
        int? levelIndex = difficultyMap[difficulty];
        if (levelIndex != null && song['level_index'] != levelIndex) {
          return false;
        }
      }
      
      // 达成率筛选
      if (filterConditions['达成率筛选'] != null && filterConditions['达成率筛选']!.isNotEmpty) {
        String achievementFilter = filterConditions['达成率筛选']!;
        if (achievementFilter.contains('-')) {
          List<String> parts = achievementFilter.split('-');
          if (parts.length == 2) {
            double minAchievement = double.tryParse(parts[0]) ?? 0;
            double maxAchievement = double.tryParse(parts[1]) ?? 101;
            double songAchievement = double.tryParse(song['achievements'].toString()) ?? 0;
            if (songAchievement < minAchievement || songAchievement > maxAchievement) {
              return false;
            }
          }
        }
      }
      
      // 连击/同步筛选
      if (filterConditions['连击/同步筛选'] != null && filterConditions['连击/同步筛选']!.isNotEmpty) {
        String comboFilter = filterConditions['连击/同步筛选']!;
        if (comboFilter == 'FC+') {
          String fc = song['fc'].toString().toLowerCase();
          if (fc != 'fc' && fc != 'fcp' && fc != 'ap' && fc != 'app') {
            return false;
          }
        } else if (comboFilter == 'AP+') {
          String fc = song['fc'].toString().toLowerCase();
          if (fc != 'ap' && fc != 'app') {
            return false;
          }
        } else if (comboFilter == 'FS+') {
          String fs = song['fs'].toString().toLowerCase();
          if (fs != 'fs' && fs != 'fsp' && fs != 'fsd' && fs != 'fsdp') {
            return false;
          }
        } else if (comboFilter == 'FDX+') {
          String fs = song['fs'].toString().toLowerCase();
          if (fs != 'fsd' && fs != 'fsdp') {
            return false;
          }
        }
      }
      
      return true;
    }).toList();
  }

  // 根据 level_index 获取对应的颜色
  Color getBorderColor(int levelIndex) {
    switch (levelIndex) {
      case 0: // BASIC
        return Colors.green;
      case 1: // ADVANCED
        return Colors.yellow;
      case 2: // EXPERT
        return Colors.red;
      case 3: // MASTER
        return Colors.purple.shade400;
      case 4: // Re:MASTER
        return Colors.purple.shade200; 
      default:
        return Colors.grey;
    }
  }
}