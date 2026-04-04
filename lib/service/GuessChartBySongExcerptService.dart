import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/entity/GuessSong.dart';
import 'package:my_first_flutter_app/entity/Song.dart';
import 'package:my_first_flutter_app/manager/LuoXueSongsManager.dart';
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
      print('加载歌曲数据失败: $e');
      return null;
    }
  }

  // 随机选择一首歌曲
  Future<Map<Song, dynamic>?> randomSelectSong() async {
    try {
      final songMap = await loadAllSongs();
      if (songMap == null || songMap.isEmpty) {
        return null;
      }

      // 随机选择一首歌曲
      final randomIndex = Random().nextInt(songMap.length);
      final entry = songMap.entries.elementAt(randomIndex);
      
      return {entry.key: entry.value};
    } catch (e) {
      print('随机选择歌曲失败: $e');
      return null;
    }
  }

  // 播放歌曲片段
  Future<void> playSongExcerpt(String luoXueId) async {
    // 此方法已移至 GuessChartBySongExcerptPage 中实现
    // 保留此方法以保持兼容性
    print('playSongExcerpt called for song $luoXueId');
  }

  // 为本局猜测的对象构建所需实体
  static Future<GuessSong> buildGuessSongEntity(Song song) async {
    try {
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
        masterTags: [],
      );
    } catch (e) {
      print('构建GuessSong实体失败: $e');
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

      return guessedSong;
    } catch (e) {
      print('计算猜测结果失败: $e');
      return guessedSong;
    }
  }
}