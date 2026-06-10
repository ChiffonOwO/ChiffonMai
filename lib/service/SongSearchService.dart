import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:my_first_flutter_app/manager/SongAliasManager.dart';
import 'package:my_first_flutter_app/manager/DivingFish/MaimaiMusicDataManager.dart';
import 'package:my_first_flutter_app/manager/MaiTagsManager.dart';
import 'package:my_first_flutter_app/entity/DivingFish/Song.dart';

// 搜索服务
class SongSearchService {
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
      debugPrint('加载歌曲数据失败: $e');
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

    return allSongs!.where((song) {
      // 检查歌曲ID（精确匹配）
      if (song.id.toString() == query) {
        return true;
      }
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
      final aliases = SongAliasManager.instance.aliases[song.title] ?? [];
      if (aliases.any((alias) => alias.toLowerCase().contains(lowerQuery))) {
        return true;
      }
      return false;
    }).toList();
  }

  // 根据标签筛选歌曲（支持复选，满足所选标签集中的一个即可）
  static Future<List<Song>> filterSongsByTags(List<int> selectedTagIds) async {
    if (selectedTagIds.isEmpty) {
      return [];
    }

    final allSongs = await loadAllSongs();
    if (allSongs == null || allSongs.isEmpty) {
      return [];
    }

    // 获取歌曲ID到标签ID列表的映射
    final songIdToTagIdsMap = await MaiTagsManager().getSongIdToTagIdsMap();
    
    // 筛选满足条件的歌曲
    return allSongs.where((song) {
      // 检查歌曲的任意谱面是否包含所选标签中的任意一个
      // 构建可能的谱面标识组合（谱面ID + 谱面类型 + 谱面难度）
      List<String> possibleKeys = [];
      
      // ST歌曲（song.id长度为5）
      if (song.id.length == 5) {
        // ST歌曲有4个难度：Basic, Advanced, Expert, Master
        for (String diff in ['Basic', 'Advanced', 'Expert', 'Master']) {
          possibleKeys.add('${song.id}#ST#$diff');
        }
      }
      // DX歌曲（song.id长度为5，type为'DX'）
      if (song.id.length == 5 && song.type == 'DX') {
        // DX歌曲额外有4个难度：Basic, Advanced, Expert, Master
        for (String diff in ['Basic', 'Advanced', 'Expert', 'Master']) {
          possibleKeys.add('${song.id}#DX#$diff');
        }
      }
      // UTAGE歌曲（song.id长度为6）
      if (song.id.length == 6) {
        // UTAGE歌曲通常只有一个谱面类型
        for (String diff in ['Basic', 'Advanced', 'Expert', 'Master']) {
          possibleKeys.add('${song.id}#UTAGE#$diff');
        }
      }

      // 检查是否有任意一个谱面标识对应的标签列表包含所选标签中的任意一个
      for (String key in possibleKeys) {
        List<int>? tagIds = songIdToTagIdsMap[key];
        if (tagIds != null && tagIds.isNotEmpty) {
          // 检查是否有交集（满足所选标签中的任意一个即可）
          for (int selectedTagId in selectedTagIds) {
            if (tagIds.contains(selectedTagId)) {
              return true;
            }
          }
        }
      }
      
      return false;
    }).toList();
  }
}