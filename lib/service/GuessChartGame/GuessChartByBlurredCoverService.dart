import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_first_flutter_app/entity/GuessSong.dart';
import 'package:my_first_flutter_app/entity/MaiTagsEntity.dart';
import 'package:my_first_flutter_app/entity/Song.dart';
import 'package:my_first_flutter_app/manager/MaiTagsManager.dart';
import 'package:my_first_flutter_app/manager/MaimaiMusicDataManager.dart';

class GuessChartByBlurredCoverService {
  // 单例模式
  static final GuessChartByBlurredCoverService _instance = GuessChartByBlurredCoverService._internal();
  factory GuessChartByBlurredCoverService() => _instance;
  GuessChartByBlurredCoverService._internal();

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
  // 使用StringUtil.formatVersion方法

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
      debugPrint('加载歌曲数据失败: $e');
      return [];
    }
  }

  // 随机选择1首歌曲(不考虑宴会场谱面，即id为六位数的谱面)
  static Future<Song?> randomSelectSong({
    List<String> selectedVersions = const [],
    double masterMinDx = 1.0,
    double masterMaxDx = 15.0,
    List<String> selectedGenres = const [],
  }) async {
    try {
      final songs = await loadAllSongs();
      if (songs == null || songs.isEmpty) {
        return null;
      }

      // 过滤掉宴会场谱面（id为六位数的谱面）和从maidata追加的歌曲（cids全为0）
      var filteredSongs = songs.where((song) => 
        song.id.length != 6 && 
        !_isMaidataSong(song)
      ).toList();
      
      // 应用过滤条件
      if (selectedVersions.isNotEmpty) {
        filteredSongs = filteredSongs.where((song) => selectedVersions.contains(song.basicInfo.from)).toList();
      }
      
      if (selectedGenres.isNotEmpty) {
        filteredSongs = filteredSongs.where((song) => selectedGenres.contains(song.basicInfo.genre)).toList();
      }
      
      // 过滤Master定数
      filteredSongs = filteredSongs.where((song) {
        if (song.ds.length > 3) {
          try {
            double dx = double.parse(song.ds[3].toString());
            return dx >= masterMinDx && dx <= masterMaxDx;
          } catch (e) {
            return false;
          }
        }
        return false;
      }).toList();
      
      if (filteredSongs.isEmpty) {
        return null;
      }

      // 随机选择一首歌曲
      final randomIndex = DateTime.now().millisecondsSinceEpoch % filteredSongs.length;
      return filteredSongs[randomIndex];
    } catch (e) {
      debugPrint('随机选择歌曲失败: $e');
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
        masterTags: masterTags,
      );
    } catch (e) {
      debugPrint('构建GuessSong实体失败: $e');
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
  static bool _isMaidataSong(Song song) {
    if (song.cids.isEmpty) return false;
    return song.cids.every((cid) => cid == 0);
  }
}