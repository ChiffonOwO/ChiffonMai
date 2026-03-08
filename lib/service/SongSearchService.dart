import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:my_first_flutter_app/manager/SongAliasManager.dart';
import 'package:my_first_flutter_app/manager/MaimaiMusicDataManager.dart';
import 'package:my_first_flutter_app/entity/Song.dart';

// 搜索服务
class SongSearchService {
  // 缓存所有歌曲数据
  static List<Song>? cachedSongs;

  // 加载所有歌曲数据（带缓存）
  static Future<List<Song>> loadAllSongs() async {
    // 如果已经缓存，直接返回
    if (cachedSongs != null) {
      return cachedSongs!;
    }

    try {
      // 检查是否已经通过API获取了数据
      if (MaimaiMusicDataManager().hasCachedData()) {
        cachedSongs = MaimaiMusicDataManager().getCachedSongs();
        return cachedSongs!;
      }
      
      // 如果API数据不存在，尝试从资产文件加载JSON数据作为 fallback
      final jsonString = await rootBundle.loadString('assets/maimai_music_data.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      cachedSongs = jsonList.map((json) => Song.fromJson(json)).toList();
      return cachedSongs!;
    } catch (e) {
      print('加载歌曲数据失败: $e');
      return [];
    }
  }

  // 搜索函数
  static Future<List<Song>> searchSongs(String query) async {
    if (query.isEmpty) {
      return [];
    }

    final allSongs = await loadAllSongs();
    final lowerQuery = query.toLowerCase();

    return allSongs.where((song) {
      // 检查标题
      if (song.basicInfo.title.toLowerCase().contains(lowerQuery)) {
        return true;
      }
      // 检查艺术家
      if (song.basicInfo.artist.toLowerCase().contains(lowerQuery)) {
        return true;
      }
      // 检查BPM
      if (song.basicInfo.bpm.toString() == lowerQuery) {
        return true;
      }
      // 检查谱师
      for (var chart in song.charts) {
        if (chart.charter.toLowerCase().contains(lowerQuery)) {
          return true;
        }
      }
      // 检查流派
      if (song.basicInfo.genre.toLowerCase().contains(lowerQuery)) {
        return true;
      }
      // 检查版本
      if (song.basicInfo.from.toLowerCase().contains(lowerQuery)) {
        return true;
      }
      // 检查别名
      final aliases = SongAliasManager.instance.aliases[song.id] ?? [];
      if (aliases.any((alias) => alias.toLowerCase().contains(lowerQuery))) {
        return true;
      }
      return false;
    }).toList();
  }
}