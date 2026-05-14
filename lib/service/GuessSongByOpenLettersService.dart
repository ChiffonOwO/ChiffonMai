import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:my_first_flutter_app/entity/Song.dart';
import 'package:my_first_flutter_app/manager/MaimaiMusicDataManager.dart';
import 'package:my_first_flutter_app/manager/SongAliasManager.dart';

class GuessSongByOpenLettersService {
  // 随机选择指定数量的歌曲
  static Future<List<Song>> randomSelectSongs(
    int count,
    {List<String> selectedVersions = const [],
    double masterMinDx = 1.0,
    double masterMaxDx = 15.0,
    List<String> selectedGenres = const [],
    int nonEnglishCharThreshold = 50,
  }) async {
    try {
      final songs = await loadAllSongs();
      if (songs == null || songs.isEmpty) {
        return [];
      }

      // 过滤掉宴会场谱面（id为六位数的谱面）和从maidata追加的歌曲（cids全为0）
      var filteredSongs = songs.where((song) => 
        song.id.length != 6 && 
        !_isMaidataSong(song)
      ).toList();
      
      // 按版本筛选
      if (selectedVersions.isNotEmpty) {
        filteredSongs = filteredSongs.where((song) => selectedVersions.contains(song.basicInfo.from)).toList();
      }
      
      // 按流派筛选
      if (selectedGenres.isNotEmpty) {
        filteredSongs = filteredSongs.where((song) => selectedGenres.contains(song.basicInfo.genre)).toList();
      }
      
      // 按Master定数筛选
      filteredSongs = filteredSongs.where((song) {
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
      
      // 按非英文字符占比筛选
      if (nonEnglishCharThreshold > 0) {
        filteredSongs = filteredSongs.where((song) {
          double ratio = _calculateNonEnglishCharRatio(song.basicInfo.title);
          return ratio < nonEnglishCharThreshold / 100.0;
        }).toList();
      }
      
      if (filteredSongs.isEmpty) {
        return [];
      }

      // 随机打乱歌曲列表
      filteredSongs.shuffle(Random());
      
      // 返回指定数量的歌曲
      return filteredSongs.take(count).toList();
    } catch (e) {
      print('随机选择歌曲失败: $e');
      return [];
    }
  }
  
  // 处理开字母请求（累积进度）
  static Map<String, String> openLetter(String letter, List<Song> targetSongs, Map<String, String> currentMaskedTitles) {
    Map<String, String> result = {};
    
    for (var song in targetSongs) {
      String title = song.basicInfo.title;
      String currentMask = currentMaskedTitles[song.id] ?? _maskTitle(title, '');
      String newMask = _updateMask(currentMask, title, letter);
      result[song.id] = newMask;
    }
    
    return result;
  }
  
  // 生成初始掩码
  static String _maskTitle(String title, String letter) {
    String result = '';
    for (int i = 0; i < title.length; i++) {
      if (title[i] == ' ' || (letter.isNotEmpty && (title[i] == letter || title[i].toLowerCase() == letter.toLowerCase()))) {
        result += title[i];
      } else {
        result += '□';
      }
    }
    return result;
  }
  
  // 更新掩码（累积进度）
  static String _updateMask(String currentMask, String title, String letter) {
    String result = '';
    for (int i = 0; i < title.length; i++) {
      if (currentMask[i] != '□') {
        // 保留已经显示的字符
        result += currentMask[i];
      } else if (title[i] == ' ' || (letter.isNotEmpty && (title[i] == letter || title[i].toLowerCase() == letter.toLowerCase()))) {
        // 显示空格或匹配的字符（大小写不敏感）
        result += title[i];
      } else {
        // 保持掩码
        result += '□';
      }
    }
    return result;
  }
  
  // 检查猜曲是否正确（支持别名）
  static bool checkAnswer(String answer, List<Song> targetSongs) {
    for (var song in targetSongs) {
      // 检查原曲名
      if (song.basicInfo.title == answer) {
        return true;
      }
      
      // 检查别名
      final aliases = SongAliasManager.instance.aliases[song.id] ?? [];
      if (aliases.contains(answer)) {
        return true;
      }
    }
    return false;
  }
  
  // 搜索歌曲（支持原曲名和别名）
  static Future<List<Song>> searchSongs(String query) async {
    final allSongs = await loadAllSongs();
    if (allSongs == null || allSongs.isEmpty) {
      return [];
    }
    
    List<Song> results = [];
    query = query.toLowerCase();

    // 搜索原曲名
    results.addAll(allSongs
        .where((song) => song.basicInfo.title.toLowerCase().contains(query)));

    // 搜索别名
    for (var song in allSongs) {
      if (!results.contains(song)) {
        // 检查别名
        final songId = song.id;
        final aliases = SongAliasManager.instance.aliases[songId];
        if (aliases != null &&
            aliases.any((alias) => alias.toLowerCase().contains(query))) {
          results.add(song);
        }
      }
    }

    // 限制结果数量
    return results.take(20).toList();
  }
  
  // 判断是否是从maidata追加的歌曲（cids全为0表示从maidata解析）
  static bool _isMaidataSong(Song song) {
    if (song.cids.isEmpty) return false;
    return song.cids.every((cid) => cid == 0);
  }
  
  // 计算非英文字符占比（包括日语和其他非英文字符，除空格外）
  static double _calculateNonEnglishCharRatio(String title) {
    if (title.isEmpty) return 0.0;
    
    int totalChars = title.replaceAll(' ', '').length;
    if (totalChars == 0) return 0.0;
    
    int nonEnglishChars = 0;
    for (int i = 0; i < title.length; i++) {
      String char = title[i];
      if (char != ' ' && !RegExp(r'^[a-zA-Z0-9]+$').hasMatch(char)) {
        nonEnglishChars++;
      }
    }
    
    return nonEnglishChars / totalChars;
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
      final jsonString = await rootBundle.loadString('assets/maimai_music_data.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      final List<Song> songs = jsonList.map((json) => Song.fromJson(json)).toList();
      return songs;
    } catch (e) {
      print('加载歌曲数据失败: $e');
      return [];
    }
  }
}