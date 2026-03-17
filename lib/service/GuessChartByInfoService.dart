
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:my_first_flutter_app/entity/Song.dart';
import 'package:my_first_flutter_app/manager/MaimaiMusicDataManager.dart';

/**
 * 猜谱面服务类
 */

class GuessChartByInfoService {
  // 单例模式
  static final GuessChartByInfoService _instance = GuessChartByInfoService._internal();
  factory GuessChartByInfoService() => _instance;
  GuessChartByInfoService._internal();

  // 加载所有歌曲数据（带缓存）
  static Future<List<Song>?> loadAllSongs() async {
    try {
      // 检查是否已经通过API获取了数据（包括本地缓存）
      if (await MaimaiMusicDataManager().hasCachedData()) {
        final songs = await MaimaiMusicDataManager().getCachedSongs();
        return songs;
      }
      
      // 如果API数据不存在，尝试从资产文件加载JSON数据作为 fallback
      final jsonString = await rootBundle.loadString('assets/maimai_music_data.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      final List<Song> songs = jsonList.map((json) => Song.fromJson(json)).toList();
      return songs;
    } catch (e) {
      print('加载歌曲数据失败: $e');
      return [];
    }
  }
  
  // 加载所有标签数据（带缓存）


  // 随机选择1首歌曲
  
} 