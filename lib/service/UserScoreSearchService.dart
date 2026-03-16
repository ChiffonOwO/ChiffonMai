import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/service/SongSearchService.dart';
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
  List<dynamic> getSortedSongs(Map<String, dynamic> userPlayData, String sortBy) {
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
          // 按 DX分达成率 降序排序
          songs.sort((a, b) {
            // 计算DX分达成率
            double aRate = _calculateDXScoreRate(a);
            double bRate = _calculateDXScoreRate(b);
            return bRate.compareTo(aRate);
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
  
  // 计算DX分达成率（私有方法）
  double _calculateDXScoreRate(dynamic record) {
    if (record == null) return 0.0;
    
    // 获取DX分
    int dxScore = int.tryParse(record['dxScore'].toString()) ?? 0;

    // 获取歌曲ID和难度索引
    String songId = record['song_id'].toString();
    int levelIndex = int.tryParse(record['level_index'].toString()) ?? 0;
    
    // 计算最大DX分 (根据notes总和 * 3)
    int maxScore = 0;

    // 尝试从cachedSongs中获取notes信息
    try {
      if (SongSearchService.cachedSongs != null && SongSearchService.cachedSongs!.isNotEmpty) {
        // 查找对应乐曲
        var song = SongSearchService.cachedSongs!.firstWhere(
          (s) => s.id == songId,
        );
        // 如果找到歌曲，且难度索引有效
        if (levelIndex >= 0 && levelIndex < song.charts.length) {
          // 获取对应难度的charts
          var chart = song.charts[levelIndex];
          // 计算notes总和
          int notesSum = chart.notes.fold(0, (sum, note) => sum + note);
          maxScore = notesSum * 3;
        }
      }
    } catch (e) {
      print('从cachedSongs获取notes信息时出错: $e');
    }
    // 计算DX分达成率
    return maxScore > 0 ? dxScore / maxScore : 0.0;
  }
  
  // 计算DX分达成率（公共方法）
  double calculateDXScoreRate(dynamic record) {
    return _calculateDXScoreRate(record);
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