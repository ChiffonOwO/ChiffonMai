import 'dart:convert';

// 最内层：charts 数组中的单个对象
class Chart {
  final List<int> notes;
  final String charter;

  // 构造函数（可空字段加 ?，非空字段加 required）
  Chart({
    required this.notes,
    required this.charter,
  });

  // 从 JSON 解析 Chart 对象
  factory Chart.fromJson(Map<String, dynamic> json) {
    return Chart(
      // 解析数组：List<dynamic> 转 List<int>
      notes: (json['notes'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [],
      // 空值兜底
      charter: json['charter'] ?? '',
    );
  }

  // 转为 JSON
  Map<String, dynamic> toJson() {
    return {
      'notes': notes,
      'charter': charter,
    };
  }
}

// 内层：basic_info 对象
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
      title: json['title'] ?? '',
      artist: json['artist'] ?? '',
      genre: json['genre'] ?? '',
      bpm: json['bpm'] ?? 0,
      releaseDate: json['release_date'] ?? '', // 注意 JSON 字段名和 Dart 变量名的映射
      from: json['from'] ?? '',
      isNew: json['is_new'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'artist': artist,
      'genre': genre,
      'bpm': bpm,
      'release_date': releaseDate,
      'from': from,
      'is_new': isNew,
    };
  }
}

// 外层：单个歌曲对象（对应 JSON 中的一个 {}）
class Song {
  final String id;
  final String title;
  final String type;
  final List<double> ds;
  final List<String> level;
  final List<int> cids;
  final List<Chart> charts; // 嵌套 Chart 数组
  final BasicInfo basicInfo; // 嵌套 BasicInfo 对象

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
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      type: json['type'] ?? '',
      // 解析 double 数组
      ds: (json['ds'] as List<dynamic>?)?.map((e) => e as double).toList() ?? [],
      // 解析 String 数组
      level: (json['level'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      // 解析 int 数组
      cids: (json['cids'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [],
      // 解析 Chart 数组：遍历每个元素，调用 Chart.fromJson
      charts: (json['charts'] as List<dynamic>?)
              ?.map((chartJson) => Chart.fromJson(chartJson as Map<String, dynamic>))
              .toList() ?? [],
      // 解析嵌套的 BasicInfo 对象
      basicInfo: BasicInfo.fromJson(json['basic_info'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'ds': ds,
      'level': level,
      'cids': cids,
      // 数组转 JSON：遍历调用 Chart.toJson
      'charts': charts.map((chart) => chart.toJson()).toList(),
      'basic_info': basicInfo.toJson(),
    };
  }
}