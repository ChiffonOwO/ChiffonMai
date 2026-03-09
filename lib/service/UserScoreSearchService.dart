import 'dart:convert';
import 'package:flutter/material.dart';
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
  List<dynamic> getSortedSongs(Map<String, dynamic> userPlayData) {
    if (userPlayData.containsKey('records') && userPlayData['records'] is List) {
      List<dynamic> songs = List.from(userPlayData['records']);
      // 按 ra 降序排序
      songs.sort((a, b) => (b['ra'] ?? 0).compareTo(a['ra'] ?? 0));
      return songs;
    }
    return [];
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
