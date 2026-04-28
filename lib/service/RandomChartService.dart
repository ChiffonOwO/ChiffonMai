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

    // 按照formatVersion2中的顺序排序版本
    final List<String> sortedVersions = _sortVersionsByFormatOrder(versions.toList());

    return ['全部版本'] + sortedVersions;
  }
  
  // 按照formatVersion2中的顺序排序版本
  List<String> _sortVersionsByFormatOrder(List<String> versions) {
    // 定义版本顺序（与formatVersion2中的顺序一致）
    final List<String> versionOrder = [
      'maimai',
      'maimai PLUS',
      'maimai GreeN',
      'maimai GreeN PLUS',
      'maimai ORANGE',
      'maimai ORANGE PLUS',
      'maimai PiNK',
      'maimai PiNK PLUS',
      'maimai MURASAKi',
      'maimai MURASAKi PLUS',
      'maimai MiLK',
      'MiLK PLUS',
      'maimai FiNALE',
      'maimai でらっくす',
      'maimai でらっくす Splash',
      'maimai でらっくす UNiVERSE',
      'maimai でらっくす FESTiVAL',
      'maimai でらっくす BUDDiES',
      'maimai でらっくす PRiSM',
    ];
    
    // 排序版本列表
    versions.sort((a, b) {
      int indexA = versionOrder.indexOf(a);
      int indexB = versionOrder.indexOf(b);
      
      // 如果两个版本都在顺序列表中，按顺序排序
      if (indexA != -1 && indexB != -1) {
        return indexA.compareTo(indexB);
      }
      // 如果只有一个版本在顺序列表中，优先显示
      else if (indexA != -1) {
        return -1;
      }
      else if (indexB != -1) {
        return 1;
      }
      // 如果两个版本都不在顺序列表中，按字符串排序
      else {
        return a.compareTo(b);
      }
    });
    
    return versions;
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

    return ['全部类型'] + genres.toList();
  }
}