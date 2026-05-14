import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/manager/MaimaiMusicDataManager.dart';
import '../manager/UserPlayDataManager.dart';
import '../entity/Song.dart';

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
        case 'DX分数达成率':
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
  List<Song>? _cachedSongs;

  // 初始化歌曲缓存（公共方法）
  Future<void> initSongCache() async {
    if (_cachedSongs == null) {
      final manager = MaimaiMusicDataManager();
      if (await manager.hasCachedData()) {
        _cachedSongs = await manager.getCachedSongs();
        print('缓存初始化成功，共 ${_cachedSongs?.length ?? 0} 首歌曲');
      } else {
        print('无缓存数据，尝试从API获取...');
        // 尝试从API获取数据
        bool success = await manager.fetchAndUpdateMusicData();
        if (success) {
          _cachedSongs = await manager.getCachedSongs();
          print('从API获取数据成功，共 ${_cachedSongs?.length ?? 0} 首歌曲');
        } else {
          print('从API获取数据失败');
        }
      }
    }
  }

  // 初始化歌曲缓存（私有方法）
  Future<void> _initSongCache() async {
    await initSongCache();
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
        var song = _cachedSongs!.where((s) => s.id == songId).firstOrNull;
        // 如果找到歌曲
        if (song != null) {
          // 检查ds数组长度
          if (song.ds.length == 2) {
            // 对于ds数组长度为2的特殊歌曲，计算两个难度谱面的最大分数之和
            if (song.charts.length >= 2) {
              // 计算第一个难度谱面的最大分数
              var chart1 = song.charts[0];
              int notesSum1 = chart1.notes.fold(0, (sum, note) => sum + note);
              int maxScore1 = notesSum1 * 3;
              
              // 计算第二个难度谱面的最大分数
              var chart2 = song.charts[1];
              int notesSum2 = chart2.notes.fold(0, (sum, note) => sum + note);
              int maxScore2 = notesSum2 * 3;
              
              // 总最大分数为两个难度谱面的最大分数之和
              maxScore = maxScore1 + maxScore2;
                                    }
          } else if (levelIndex >= 0 && levelIndex < song.charts.length) {
            // 对于普通歌曲，使用当前难度的最大分数
            // 获取对应难度的charts
            var chart = song.charts[levelIndex];
            // 计算notes总和
            int notesSum = chart.notes.fold(0, (sum, note) => sum + note);
            maxScore = notesSum * 3;
                    }
        } else {
          print('未找到歌曲: $songId');
        }
      } else {
        print('缓存未初始化或为空');
      }
    } catch (e) {
      print('从缓存获取notes信息时出错: $e');
    }
    // 计算DX分达成率
    double rate = maxScore > 0 ? dxScore / maxScore : 0.0;
    // 仅在调试模式下打印
    // print('计算DX分达成率: songId=$songId, levelIndex=$levelIndex, dxScore=$dxScore, maxScore=$maxScore, rate=$rate');
    return rate;
  }
  
  // 计算DX分达成率（公共方法）
  Future<double> calculateDXScoreRate(dynamic record) async {
    return await _calculateDXScoreRate(record);
  }

  // 计算DX分达成率（同步公共方法）
  double calculateDXScoreRateSync(dynamic record) {
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
      // 仅使用已初始化的缓存
      if (_cachedSongs != null && _cachedSongs!.isNotEmpty) {
        // 查找对应乐曲
        var song = _cachedSongs!.where((s) => s.id == songId).firstOrNull;
        // 如果找到歌曲
        if (song != null) {
          // 检查ds数组长度
          if (song.ds.length == 2) {
            // 对于ds数组长度为2的特殊歌曲，计算两个难度谱面的最大分数之和
            if (song.charts.length >= 2) {
              // 计算第一个难度谱面的最大分数
              var chart1 = song.charts[0];
              int notesSum1 = chart1.notes.fold(0, (sum, note) => sum + note);
              int maxScore1 = notesSum1 * 3;
              
              // 计算第二个难度谱面的最大分数
              var chart2 = song.charts[1];
              int notesSum2 = chart2.notes.fold(0, (sum, note) => sum + note);
              int maxScore2 = notesSum2 * 3;
              
              // 总最大分数为两个难度谱面的最大分数之和
              maxScore = maxScore1 + maxScore2;
                                    }
          } else if (levelIndex >= 0 && levelIndex < song.charts.length) {
            // 对于普通歌曲，使用当前难度的最大分数
            // 获取对应难度的charts
            var chart = song.charts[levelIndex];
            // 计算notes总和
            int notesSum = chart.notes.fold(0, (sum, note) => sum + note);
            maxScore = notesSum * 3;
                    }
        } else {
          print('未找到歌曲: $songId');
        }
      } else {
        print('缓存未初始化或为空');
      }
    } catch (e) {
      print('从缓存获取notes信息时出错: $e');
    }
    // 计算DX分达成率
    double rate = maxScore > 0 ? dxScore / maxScore : 0.0;
    //print('计算DX分达成率: songId=$songId, levelIndex=$levelIndex, dxScore=$dxScore, maxScore=$maxScore, rate=$rate');
    return rate;
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
          var foundSong = _cachedSongs!.where((s) => s.id == songId).firstOrNull;
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
        
        // 处理UTAGE选项，筛选ID为6位数的歌曲
        if (difficulty == 'UTAGE') {
          String songId = song['song_id'].toString();
          if (songId.length != 6 || int.tryParse(songId) == null) {
            return false;
          }
        } else {
          Map<String, int> difficultyMap = {
            'BASIC': 0,
            'ADVANCED': 1,
            'EXPERT': 2,
            'MASTER': 3,
            'Re:MASTER': 4,
          };
          int? levelIndex = difficultyMap[difficulty];
          if (levelIndex != null) {
            // 检查难度是否匹配
            if (song['level_index'] != levelIndex) {
              return false;
            }
            
            // 选择BASIC的时候，过滤掉ID为6位数的歌曲
            if (difficulty == 'BASIC') {
              String songId = song['song_id'].toString();
              if (songId.length == 6 && int.tryParse(songId) != null) {
                return false;
              }
            }
          }
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
        if (comboFilter == '无连击评价') {
          // 无连击评价 (fc为"")
          String fc = song['fc'].toString().toLowerCase();
          if (fc != "") {
            return false;
          }
        } else if (comboFilter == 'FC') {
          // FC(fc为"fc")
          String fc = song['fc'].toString().toLowerCase();
          if (fc != 'fc') {
            return false;
          }
        } else if (comboFilter == 'FC+') {
          // FC+(fc为"fcp")
          String fc = song['fc'].toString().toLowerCase();
          if (fc != 'fcp') {
            return false;
          }
        } else if (comboFilter == 'AP') {
          // AP(fc为"ap")
          String fc = song['fc'].toString().toLowerCase();
          if (fc != 'ap') {
            return false;
          }
        } else if (comboFilter == 'AP+') {
          // AP+(fc为"app")
          String fc = song['fc'].toString().toLowerCase();
          if (fc != 'app') {
            return false;
          }
        } else if (comboFilter == '无同步评价') {
          // 无同步评价(fs为"")
          String fs = song['fs'].toString().toLowerCase();
          if (fs != "") {
            return false;
          }
        } else if (comboFilter == 'SYNC') {
          // SYNC(fs为"sync")
          String fs = song['fs'].toString().toLowerCase();
          if (fs != 'sync') {
            return false;
          }
        } else if (comboFilter == 'FS') {
          // FS(fs为"fs")
          String fs = song['fs'].toString().toLowerCase();
          if (fs != 'fs') {
            return false;
          }
        } else if (comboFilter == 'FS+') {
          // FS+(fs为"fsp")
          String fs = song['fs'].toString().toLowerCase();
          if (fs != 'fsp') {
            return false;
          }
        } else if (comboFilter == 'FDX') {
          // FDX(fs为"fsd")
          String fs = song['fs'].toString().toLowerCase();
          if (fs != 'fsd') {
            return false;
          }
        } else if (comboFilter == 'FDX+') {
          // FDX+(fs为"fsdp")
          String fs = song['fs'].toString().toLowerCase();
          if (fs != 'fsdp') {
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