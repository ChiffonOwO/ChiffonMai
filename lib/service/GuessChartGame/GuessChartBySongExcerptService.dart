import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/entity/GuessSong.dart';
import 'package:my_first_flutter_app/entity/MaiTagsEntity.dart';
import 'package:my_first_flutter_app/entity/Song.dart';
import 'package:my_first_flutter_app/manager/LuoXueSongsManager.dart';
import 'package:my_first_flutter_app/manager/MaiTagsManager.dart';
import 'package:my_first_flutter_app/manager/MaimaiMusicDataManager.dart';

class GuessChartBySongExcerptService {
  // 单例模式
  static final GuessChartBySongExcerptService _instance = GuessChartBySongExcerptService._internal();
  factory GuessChartBySongExcerptService() => _instance;
  GuessChartBySongExcerptService._internal();

  // 播放时长设置（默认5秒，最长30秒）
  int _playDuration = 5;
  
  // 设置播放时长
  void setPlayDuration(int seconds) {
    _playDuration = min(30, max(1, seconds));
  }
  
  // 获取当前播放时长
  int getPlayDuration() {
    return _playDuration;
  }

  // 加载所有落雪歌曲数据
  Future<Map<Song, dynamic>?> loadAllSongs() async {
    try {
      // 获取落雪歌曲数据
      final luoXueSongsManager = LuoXueSongsManager();
      final luoXueSongEntity = await luoXueSongsManager.getLuoXueSongs();
      
      if (luoXueSongEntity == null || luoXueSongEntity.songs.isEmpty) {
        return null;
      }

      // 获取缓存的歌曲数据
      final maimaiMusicManager = MaimaiMusicDataManager();
      List<Song> cachedSongs = [];
      
      if (await maimaiMusicManager.hasCachedData()) {
        cachedSongs = await maimaiMusicManager.getCachedSongs() ?? [];
      }

      // 构建歌曲映射
      final Map<Song, dynamic> songMap = {};
      
      for (final luoXueSong in luoXueSongEntity.songs) {
        // 检查是否有standard或dx难度
        bool hasStandard = luoXueSong.difficulties.standard != null && luoXueSong.difficulties.standard!.isNotEmpty;
        bool hasDx = luoXueSong.difficulties.dx != null && luoXueSong.difficulties.dx!.isNotEmpty;
        
        if (!hasStandard && !hasDx) {
          continue;
        }

        // 随机选择类型
        String selectedType = hasStandard && hasDx 
            ? (Random().nextBool() ? 'SD' : 'DX') 
            : (hasStandard ? 'SD' : 'DX');

        // 查找对应的缓存歌曲
        Song? matchedSong;
        try {
          matchedSong = cachedSongs.firstWhere(
            (song) => song.basicInfo.title == luoXueSong.title && song.type == selectedType,
            orElse: () => Song(
              id: '',
              title: luoXueSong.title,
              type: selectedType,
              ds: [],
              level: [],
              cids: [],
              charts: [],
              basicInfo: BasicInfo(
                title: luoXueSong.title,
                artist: luoXueSong.artist,
                genre: luoXueSong.genre,
                bpm: luoXueSong.bpm,
                releaseDate: '',
                from: luoXueSong.version.toString(),
                isNew: false,
              ),
            ),
          );
        } catch (e) {
          // 如果查找失败，创建一个默认歌曲
          matchedSong = Song(
            id: '',
            title: luoXueSong.title,
            type: selectedType,
            ds: [],
            level: [],
            cids: [],
            charts: [],
            basicInfo: BasicInfo(
              title: luoXueSong.title,
              artist: luoXueSong.artist,
              genre: luoXueSong.genre,
              bpm: luoXueSong.bpm,
              releaseDate: '',
              from: luoXueSong.version.toString(),
              isNew: false,
            ),
          );
        }

        // 将落雪歌曲信息与缓存歌曲关联
        songMap[matchedSong] = {
          'luoXueId': luoXueSong.id,
          'type': selectedType,
        };
      }

      return songMap;
    } catch (e) {
      debugPrint('加载歌曲数据失败: $e');
      return null;
    }
  }

  // 随机选择一首歌曲
  Future<Map<Song, dynamic>?> randomSelectSong({
    List<String> selectedVersions = const [],
    double masterMinDx = 1.0,
    double masterMaxDx = 15.0,
    List<String> selectedGenres = const [],
  }) async {
    try {
      final songMap = await loadAllSongs();
      if (songMap == null || songMap.isEmpty) {
        return null;
      }

      // 筛选歌曲
      var filteredEntries = songMap.entries.where((entry) {
        final song = entry.key;
        
        // 过滤掉宴会场谱面（id为六位数的谱面）和从maidata追加的歌曲（cids全为0）
        if (song.id.length == 6 || _isMaidataSong(song)) {
          return false;
        }
        
        // 按版本筛选
        if (selectedVersions.isNotEmpty && !selectedVersions.contains(song.basicInfo.from)) {
          return false;
        }
        
        // 按流派筛选
        if (selectedGenres.isNotEmpty && !selectedGenres.contains(song.basicInfo.genre)) {
          return false;
        }
        
        // 按Master定数筛选
        if (song.ds.length > 3) {
          try {
            final masterDx = double.parse(song.ds[3].toString());
            return masterDx >= masterMinDx && masterDx <= masterMaxDx;
          } catch (e) {
            return false;
          }
        }
        
        return false;
      }).toList();
      
      if (filteredEntries.isEmpty) {
        return null;
      }

      // 随机选择一首歌曲
      final randomIndex = Random().nextInt(filteredEntries.length);
      final entry = filteredEntries[randomIndex];
      
      return {entry.key: entry.value};
    } catch (e) {
      debugPrint('随机选择歌曲失败: $e');
      return null;
    }
  }

  // 播放歌曲片段
  Future<void> playSongExcerpt(String luoXueId) async {
    // 此方法已移至 GuessChartBySongExcerptPage 中实现
    // 保留此方法以保持兼容性
    debugPrint('playSongExcerpt called for song $luoXueId');
  }

  // 从缓存中尝试加载出标签数据并解析
  static Future<MaiTagsEntity?> loadTagData() async {
    try {
      final maiTagsManager = MaiTagsManager();
      
      // 检查是否有缓存数据
      if (await maiTagsManager.hasCachedData()) {
        // 从缓存获取标签数据
        final maiTagsEntity = await maiTagsManager.getTags();
        return maiTagsEntity;
      } else {
        // 初始化标签数据（从网络获取并缓存）
        await maiTagsManager.initializeTags();
        // 再次尝试获取
        final maiTagsEntity = await maiTagsManager.getTags();
        return maiTagsEntity;
      }
    } catch (e) {
      debugPrint('加载标签数据失败: $e');
      return null;
    }
  }

  // 构建 谱面标识 = 谱面ID + 谱面类型 + 谱面难度 到 标签ID列表 的映射
  static Future<Map<String, List<int>>> buildSongIdToTagIdsMap() async {
    try {
      final maiTagsEntity = await loadTagData();
      if (maiTagsEntity != null) {
        final maiTagsManager = MaiTagsManager();
        return maiTagsManager.buildSongIdToTagIdsMap(maiTagsEntity);
      }
      return {};
    } catch (e) {
      debugPrint('构建谱面标识到标签ID列表的映射失败: $e');
      return {};
    }
  }

  // 构建 标签ID → 标签名称 的映射
  static Future<Map<int, String>> buildTagIdToNameMap() async {
    try {
      final maiTagsEntity = await loadTagData();
      if (maiTagsEntity != null) {
        Map<int, String> tagIdToNameMap = {};
        for (var tag in maiTagsEntity.tags) {
          tagIdToNameMap[tag.id] = tag.localizedName.zhHans;
        }
        return tagIdToNameMap;
      }
      return {};
    } catch (e) {
      debugPrint('构建标签ID到名称映射失败: $e');
      return {};
    }
  }

  // 为本局猜测的对象构建所需实体
  static Future<GuessSong> buildGuessSongEntity(Song song) async {
    try {
      // 获取标签数据
      final tagIdToNameMap = await buildTagIdToNameMap();
      final songIdToTagIdsMap = await buildSongIdToTagIdsMap();

      // 构建谱面标识
      String songKey = '${song.title}#${song.type == 'DX' ? 'dx' : 'std'}#master';
      // 获取Master难度的标签
      final tagIds = songIdToTagIdsMap[songKey] ?? [];
      final masterTags = tagIds.map((tagId) => tagIdToNameMap[tagId] ?? '').where((tag) => tag.isNotEmpty).toList();
      // 构建GuessSong实体
      return GuessSong(
        songId: song.id.isNotEmpty ? int.tryParse(song.id) ?? 0 : 0,
        title: song.basicInfo.title,
        type: song.type,
        bpm: song.basicInfo.bpm,
        artist: song.basicInfo.artist,
        masterDs: song.ds.length > 3 ? song.ds[3].toString() : '',
        masterCharter: song.charts.length > 3 ? song.charts[3].charter : '',
        remasterDs: song.ds.length > 4 ? song.ds[4].toString() : '',
        remasterCharter: song.charts.length > 4 ? song.charts[4].charter : '',
        genre: song.basicInfo.genre,
        version: song.basicInfo.from,
        masterTags: masterTags,
      );
    } catch (e) {
      debugPrint('构建GuessSong实体失败: $e');
      // 返回默认值
      return GuessSong(
        songId: song.id.isNotEmpty ? int.tryParse(song.id) ?? 0 : 0,
        title: song.basicInfo.title,
        type: song.type,
        bpm: song.basicInfo.bpm,
        artist: song.basicInfo.artist,
        masterDs: song.ds.length > 3 ? song.ds[3].toString() : '',
        masterCharter: song.charts.length > 3 ? song.charts[3].charter : '',
        remasterDs: song.ds.length > 4 ? song.ds[4].toString() : '',
        remasterCharter: song.charts.length > 4 ? song.charts[4].charter : '',
        genre: song.basicInfo.genre,
        version: song.basicInfo.from,
        masterTags: [],
      );
    }
  }

  // 根据用户猜测和目标歌曲，返回颜色提示并填入用户猜测实体
  static Future<GuessSong> calculateGuessResult(GuessSong guessedSong, Song targetSong) async {
    try {
      // 获取标签数据
      final tagIdToNameMap = await buildTagIdToNameMap();
      final songIdToTagIdsMap = await buildSongIdToTagIdsMap();

      // 构建目标歌曲的谱面标识
      String targetSongKey = '${targetSong.title}#${targetSong.type == 'DX' ? 'dx' : 'std'}#master';
      // 获取目标歌曲Master难度的标签
      final targetTagIds = songIdToTagIdsMap[targetSongKey] ?? [];
      final targetTags = targetTagIds.map((tagId) => tagIdToNameMap[tagId] ?? '').where((tag) => tag.isNotEmpty).toList();
      
      // 构建猜测歌曲的谱面标识
      String guessedSongKey = '${guessedSong.title}#${guessedSong.type == 'DX' ? 'dx' : 'std'}#master';
      // 获取猜测歌曲Master难度的标签
      final guessedTagIds = songIdToTagIdsMap[guessedSongKey] ?? [];
      final guessedTags = guessedTagIds.map((tagId) => tagIdToNameMap[tagId] ?? '').where((tag) => tag.isNotEmpty).toList();
      
      // 设置猜测歌曲的标签
      guessedSong.masterTags = guessedTags;

      // 计算各属性的颜色
      guessedSong.titleBgColor = guessedSong.title == targetSong.basicInfo.title ? Colors.green : Colors.grey;
      guessedSong.typeBgColor = guessedSong.type == targetSong.type ? Colors.green : Colors.grey;
      
      // BPM比较
      if (guessedSong.bpm == targetSong.basicInfo.bpm) {
        guessedSong.bpmBgColor = Colors.green;
        guessedSong.bpmArrow = null;
      } else if ((guessedSong.bpm - targetSong.basicInfo.bpm).abs() <= 20) {
        guessedSong.bpmBgColor = Colors.yellow;
        guessedSong.bpmArrow = guessedSong.bpm < targetSong.basicInfo.bpm ? '↑' : '↓';
      } else {
        guessedSong.bpmBgColor = Colors.grey;
        guessedSong.bpmArrow = guessedSong.bpm < targetSong.basicInfo.bpm ? '↑' : '↓';
      }

      guessedSong.artistBgColor = guessedSong.artist == targetSong.basicInfo.artist ? Colors.green : Colors.grey;

      // Master难度比较
      if (guessedSong.masterDs == (targetSong.ds.length > 3 ? targetSong.ds[3].toString() : '')) {
        guessedSong.masterLevelBgColor = Colors.green;
        guessedSong.masterLevelArrow = null;
      } else {
        try {
          final guessedLevel = double.tryParse(guessedSong.masterDs);
          final targetLevel = double.tryParse(targetSong.ds.length > 3 ? targetSong.ds[3].toString() : '');
          if (guessedLevel != null && targetLevel != null) {
            if ((guessedLevel - targetLevel).abs() <= 0.4) {
              guessedSong.masterLevelBgColor = Colors.yellow;
            } else {
              guessedSong.masterLevelBgColor = Colors.grey;
            }
            guessedSong.masterLevelArrow = guessedLevel < targetLevel ? '↑' : '↓';
          } else {
            guessedSong.masterLevelBgColor = Colors.grey;
            guessedSong.masterLevelArrow = null;
          }
        } catch (e) {
          guessedSong.masterLevelBgColor = Colors.grey;
          guessedSong.masterLevelArrow = null;
        }
      }

      guessedSong.masterCharterBgColor = guessedSong.masterCharter == (targetSong.charts.length > 3 ? targetSong.charts[3].charter : '') ? Colors.green : Colors.grey;

      // Re:Master难度比较
      if (guessedSong.remasterDs == (targetSong.ds.length > 4 ? targetSong.ds[4].toString() : '')) {
        guessedSong.remasterLevelBgColor = Colors.green;
        guessedSong.remasterLevelArrow = null;
      } else {
        try {
          final guessedLevel = double.tryParse(guessedSong.remasterDs);
          final targetLevel = double.tryParse(targetSong.ds.length > 4 ? targetSong.ds[4].toString() : '');
          if (guessedLevel != null && targetLevel != null) {
            if ((guessedLevel - targetLevel).abs() <= 0.4) {
              guessedSong.remasterLevelBgColor = Colors.yellow;
            } else {
              guessedSong.remasterLevelBgColor = Colors.grey;
            }
            guessedSong.remasterLevelArrow = guessedLevel < targetLevel ? '↑' : '↓';
          } else {
            guessedSong.remasterLevelBgColor = Colors.grey;
            guessedSong.remasterLevelArrow = null;
          }
        } catch (e) {
          guessedSong.remasterLevelBgColor = Colors.grey;
          guessedSong.remasterLevelArrow = null;
        }
      }

      guessedSong.remasterCharterBgColor = guessedSong.remasterCharter == (targetSong.charts.length > 4 ? targetSong.charts[4].charter : '') ? Colors.green : Colors.grey;
      guessedSong.genreBgColor = guessedSong.genre == targetSong.basicInfo.genre ? Colors.green : Colors.grey;
      
      // 版本比较
      if (guessedSong.version == targetSong.basicInfo.from) {
        guessedSong.versionBgColor = Colors.green;
        guessedSong.versionArrow = null;
      } else {
        guessedSong.versionBgColor = Colors.grey;
        guessedSong.versionArrow = null;
      }

      // 标签比较
      guessedSong.tagBgColors = guessedSong.masterTags?.map((tag) {
        return targetTags.contains(tag) ? Colors.green : Colors.grey;
      }).toList();

      return guessedSong;
    } catch (e) {
      debugPrint('计算猜测结果失败: $e');
      return guessedSong;
    }
  }
  
  // 判断是否是从maidata追加的歌曲（cids全为0表示从maidata解析）
  bool _isMaidataSong(Song song) {
    if (song.cids.isEmpty) return false;
    return song.cids.every((cid) => cid == 0);
  }
}