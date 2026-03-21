import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_first_flutter_app/entity/GuessSong.dart';
import 'package:my_first_flutter_app/entity/Song.dart';
import 'package:my_first_flutter_app/manager/MaimaiMusicDataManager.dart';

class GuessChartByCoverService {
  // 单例模式
  static final GuessChartByCoverService _instance = GuessChartByCoverService._internal();
  factory GuessChartByCoverService() => _instance;
  GuessChartByCoverService._internal();

  // 版本列表
  static List<String> _versionList = [
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
    'maimai MiLK PLUS',
    'maimai FiNALE',
    'maimai \u3067\u3089\u3063\u304f\u3059',
    'maimai \u3067\u3089\u3063\u304f\u3059 Splash',
    'maimai \u3067\u3089\u3063\u304f\u3059 UNiVERSE',
    'maimai \u3067\u3089\u3063\u304f\u3059 FESTiVAL',
    'maimai \u3067\u3089\u3063\u304f\u3059 BUDDiES',
    'maimai \u3067\u3089\u3063\u304f\u3059 PRiSM'
  ];

  // 处理版本字符串，使其在前端简化展示
  static String _formatVersion(String version) {
    if (version == 'maimai') {
      return 'maimai';
    }
    if (version == 'maimai PLUS') {
      return 'maimai+';
    }
    if (version == 'maimai \u3067\u3089\u3063\u304f\u3059') {
      return 'DX 2020';
    }
    if (version == 'maimai \u3067\u3089\u3063\u304f\u3059 Splash') {
      return 'DX 2021';
    }
    if (version == 'maimai \u3067\u3089\u3063\u304f\u3059 UNiVERSE') {
      return 'DX 2022';
    }
    if (version == 'maimai \u3067\u3089\u3063\u304f\u3059 FESTiVAL') {
      return 'DX 2023';
    }
    if (version == 'maimai \u3067\u3089\u3063\u304f\u3059 BUDDiES') {
      return 'DX 2024';
    }
    if (version == 'maimai \u3067\u3089\u3063\u304f\u3059 PRiSM') {
      return 'DX 2025';
    }
    if (version.contains(' PLUS')) {
      version = version.replaceFirst(' PLUS', '+');
    }
    if (version.contains('maimai') && version != 'maimai') {
      version = version.replaceFirst('maimai ', '');
    }
    if (version.contains('\u3067\u3089\u3063\u304f\u3059')) {
      version = version.replaceFirst('\u3067\u3089\u3063\u304f\u3059 ', '');
    }
    return version;
  }

  // 加载所有歌曲数据（带缓存）
  static Future<List<Song>?> loadAllSongs() async {
    try {
      // 检查是否已经通过API获取了数据（包括本地缓存）
      if (await MaimaiMusicDataManager().hasCachedData()) {
        final songs = await MaimaiMusicDataManager().getCachedSongs();
        return songs;
      }

      // 如果API数据不存在，尝试从资产文件加载JSON数据作为 fallback
      final jsonString =
          await rootBundle.loadString('assets/maimai_music_data.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      final List<Song> songs =
          jsonList.map((json) => Song.fromJson(json)).toList();
      return songs;
    } catch (e) {
      print('加载歌曲数据失败: $e');
      return [];
    }
  }

  // 随机选择1首歌曲(不考虑宴会场谱面，即id为六位数的谱面)
  static Future<Song?> randomSelectSong() async {
    try {
      final songs = await loadAllSongs();
      if (songs == null || songs.isEmpty) {
        return null;
      }

      // 过滤掉宴会场谱面（id为六位数的谱面）
      final filteredSongs = songs.where((song) => song.id.length != 6).toList();
      if (filteredSongs.isEmpty) {
        return null;
      }

      // 随机选择一首歌曲
      final randomIndex = DateTime.now().millisecondsSinceEpoch % filteredSongs.length;
      return filteredSongs[randomIndex];
    } catch (e) {
      print('随机选择歌曲失败: $e');
      return null;
    }
  }

  // 生成fallback的cover_id
  static String generateCoverId(String songId) {
    if (songId.length == 6) {
      // 对于6位数的曲绘，只去除第一位，保留后续的0
      return songId.substring(1);
    } else if (songId.length >= 5) {
      // 如果长度大于等于5，万位补1
      int songIdInt = int.parse(songId);
      int tenThousandPlace = (songIdInt ~/ 10000) + 1;
      int remaining = songIdInt % 10000;
      return '${tenThousandPlace}${remaining.toString().padLeft(4, '0')}';
    } else {
      // 如果长度小于5，补1在万位，其余补0
      return '1${songId.padLeft(4, '0')}';
    }
  }

  // 获取曲绘路径
  static String getCoverPath(String songId) {
    return 'assets/cover/${songId}.webp';
  }

  // 获取网络曲绘URL
  static String getNetworkCoverUrl(String songId) {
    String coverId = generateCoverId(songId);
    return 'https://www.diving-fish.com/covers/$coverId.png';
  }

  // 为本局猜测的对象构建所需实体
  static Future<GuessSong> buildGuessSongEntity(Song song) async {
    try {
      // 构建GuessSong实体
      return GuessSong(
        songId: int.parse(song.id),
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
        songId: int.parse(song.id),
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
        // 版本相差一个世代（例如 maimai → maimai PLUS）
        final guessedVersionIndex = _versionList.indexOf(guessedSong.version);
        final targetVersionIndex = _versionList.indexOf(targetSong.basicInfo.from);
        if (guessedVersionIndex != -1 && targetVersionIndex != -1) {
          if ((guessedVersionIndex - targetVersionIndex).abs() == 1) {
            guessedSong.versionBgColor = Colors.yellow;
          } else {
            guessedSong.versionBgColor = Colors.grey;
          }
          // 版本箭头：索引越小版本越早，所以如果猜的版本索引小于目标版本索引，说明猜晚了，需要↑表示目标版本更早
          guessedSong.versionArrow = guessedVersionIndex > targetVersionIndex ? '猜晚了' : '猜早了';
        } else {
          guessedSong.versionBgColor = Colors.grey;
          guessedSong.versionArrow = null;
        }
      }

      return guessedSong;
    } catch (e) {
      print('计算猜测结果失败: $e');
      return guessedSong;
    }
  }
}