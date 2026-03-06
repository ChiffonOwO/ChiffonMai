import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:my_first_flutter_app/service/SongAliasManager.dart';

// 歌曲数据模型
class Song {
  final String id;
  final String title;
  final String type;
  final List<double> ds;
  final List<String> level;
  final List<int> cids;
  final List<Chart> charts;
  final BasicInfo basicInfo;

  Song({
    required this.id,
    required this.title,
    required this.type,
    required this.ds,
    required this.level,
    required this.cids,
    required this.charts,
    required this.basicInfo,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'],
      title: json['title'],
      type: json['type'],
      ds: List<double>.from(json['ds'].map((x) => x.toDouble())),
      level: List<String>.from(json['level']),
      cids: List<int>.from(json['cids'].map((x) => x is int ? x : int.parse(x.toString()))),
      charts: List<Chart>.from(json['charts'].map((x) => Chart.fromJson(x))),
      basicInfo: BasicInfo.fromJson(json['basic_info']),
    );
  }
}

class Chart {
  final List<int> notes;
  final String charter;

  Chart({
    required this.notes,
    required this.charter,
  });

  factory Chart.fromJson(Map<String, dynamic> json) {
    return Chart(
      notes: List<int>.from(json['notes'].map((x) => x)),
      charter: json['charter'],
    );
  }
}

class BasicInfo {
  final String title;
  final String artist;
  final String genre;
  final int bpm;
  final String releaseDate;
  final String from;
  final bool isNew;

  BasicInfo({
    required this.title,
    required this.artist,
    required this.genre,
    required this.bpm,
    required this.releaseDate,
    required this.from,
    required this.isNew,
  });

  factory BasicInfo.fromJson(Map<String, dynamic> json) {
    return BasicInfo(
      title: json['title'],
      artist: json['artist'],
      genre: json['genre'],
      bpm: json['bpm'],
      releaseDate: json['release_date'],
      from: json['from'],
      isNew: json['is_new'],
    );
  }
}

// 搜索服务
class SongSearchService {
  // 缓存所有歌曲数据
  static List<Song>? _cachedSongs;

  // 加载所有歌曲数据（带缓存）
  static Future<List<Song>> loadAllSongs() async {
    // 如果已经缓存，直接返回
    if (_cachedSongs != null) {
      return _cachedSongs!;
    }

    try {
      // 从资产文件加载JSON数据
      final jsonString = await rootBundle.loadString('assets/maimai_music_data.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      _cachedSongs = jsonList.map((json) => Song.fromJson(json)).toList();
      return _cachedSongs!;
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