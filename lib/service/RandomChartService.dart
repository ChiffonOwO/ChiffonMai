import 'dart:math';
import 'package:my_first_flutter_app/entity/Song.dart';
import 'package:my_first_flutter_app/manager/MaimaiMusicDataManager.dart';

class RandomChartService {
  // 单例模式
  static final RandomChartService _instance = RandomChartService._internal();
  factory RandomChartService() => _instance;
  RandomChartService._internal();

  // 随机抽取歌曲
  Future<List<Song>> randomDrawSongs({
    int count = 4,
    double? minDs,
    double? maxDs,
    String? version,
    String? genre,
  }) async {
    // 获取所有歌曲
    final manager = MaimaiMusicDataManager();
    final allSongs = await manager.getCachedSongs();
    
    if (allSongs == null || allSongs.isEmpty) {
      return [];
    }

    // 过滤歌曲
    List<Song> filteredSongs = allSongs.where((song) {
      // 定数过滤
      if (minDs != null || maxDs != null) {
        // 检查是否有符合条件的难度
        bool hasValidDs = false;
        for (double ds in song.ds) {
          bool meetsMin = minDs == null || ds >= minDs;
          bool meetsMax = maxDs == null || ds <= maxDs;
          if (meetsMin && meetsMax) {
            hasValidDs = true;
            break;
          }
        }
        if (!hasValidDs) {
          return false;
        }
      }

      // 版本过滤
      if (version != null && version != '全部版本') {
        if (song.basicInfo.from != version) {
          return false;
        }
      }

      // 流派过滤
      if (genre != null && genre != '全部类型') {
        if (song.basicInfo.genre != genre) {
          return false;
        }
      }

      return true;
    }).toList();

    // 如果过滤后没有歌曲，返回空列表
    if (filteredSongs.isEmpty) {
      return [];
    }

    // 随机抽取歌曲
    final random = Random();
    final result = <Song>[];
    final usedIndices = <int>{};

    for (int i = 0; i < count && usedIndices.length < filteredSongs.length; i++) {
      int index;
      do {
        index = random.nextInt(filteredSongs.length);
      } while (usedIndices.contains(index));
      
      usedIndices.add(index);
      result.add(filteredSongs[index]);
    }

    return result;
  }

  // 获取版本列表
  Future<List<String>> getVersionList() async {
    final manager = MaimaiMusicDataManager();
    final allSongs = await manager.getCachedSongs();
    
    if (allSongs == null || allSongs.isEmpty) {
      return [];
    }

    final versions = <String>{};
    for (var song in allSongs) {
      versions.add(song.basicInfo.from);
    }

    return ['全部版本'] + versions.toList()..sort();
  }

  // 获取流派列表
  Future<List<String>> getGenreList() async {
    final manager = MaimaiMusicDataManager();
    final allSongs = await manager.getCachedSongs();
    
    if (allSongs == null || allSongs.isEmpty) {
      return [];
    }

    final genres = <String>{};
    for (var song in allSongs) {
      genres.add(song.basicInfo.genre);
    }

    return ['全部类型'] + genres.toList()..sort();
  }
}