import 'dart:convert';

class SongInfo {
  final int id;
  final int players;
  final String title;
  final Map<String, String>? utTitle; // 多语言标题，如 {"0": "日文标题"}
  final String artist;
  final List<String> albums;
  final bool hasDx;
  final bool hasSd;
  final bool hasUt;
  final String genre;
  final int bpm;
  final String releaseDate;
  final String from;
  final bool cn;
  final bool jp;
  final bool m2l;
  final int firstRomVersion;
  final int dxRomVersion;
  final int sdRomVersion;
  final int utRomVersion;
  final Map<String, Difficulty>? dx;
  final Map<String, Difficulty>? sd;
  final Map<String, Difficulty>? ut;
  final int aboutChuId;
  final bool isLong;

  SongInfo({
    required this.id,
    required this.players,
    required this.title,
    this.utTitle,
    required this.artist,
    required this.albums,
    required this.hasDx,
    required this.hasSd,
    required this.hasUt,
    required this.genre,
    required this.bpm,
    required this.releaseDate,
    required this.from,
    required this.cn,
    required this.jp,
    required this.m2l,
    required this.firstRomVersion,
    required this.dxRomVersion,
    required this.sdRomVersion,
    required this.utRomVersion,
    this.dx,
    this.sd,
    this.ut,
    required this.aboutChuId,
    required this.isLong,
  });

  /// 从 JSON 映射构造对象
  factory SongInfo.fromJson(Map<String, dynamic> json) {
    return SongInfo(
      id: json['id'] as int? ?? 0,
      players: json['players'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      utTitle: (json['utTitle'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, v as String),
      ),
      artist: json['artist'] as String? ?? '',
      albums: (json['albums'] as List<dynamic>?)?.cast<String>() ?? [],
      hasDx: json['hasDx'] as bool? ?? false,
      hasSd: json['hasSd'] as bool? ?? false,
      hasUt: json['hasUt'] as bool? ?? false,
      genre: json['genre'] as String? ?? '',
      bpm: json['bpm'] as int? ?? 0,
      releaseDate: json['releaseDate'] as String? ?? '',
      from: json['from'] as String? ?? '',
      cn: json['cn'] as bool? ?? false,
      jp: json['jp'] as bool? ?? false,
      m2l: json['m2l'] as bool? ?? false,
      firstRomVersion: json['firstRomVersion'] as int? ?? 0,
      dxRomVersion: json['dxRomVersion'] as int? ?? 0,
      sdRomVersion: json['sdRomVersion'] as int? ?? 0,
      utRomVersion: json['utRomVersion'] as int? ?? 0,
      dx: _parseDifficultyMap(json['dx'] as Map<String, dynamic>?),
      sd: _parseDifficultyMap(json['sd'] as Map<String, dynamic>?),
      ut: _parseDifficultyMap(json['ut'] as Map<String, dynamic>?),
      aboutChuId: json['aboutChu_id'] as int? ?? 0,
      isLong: json['isLong'] as bool? ?? false,
    );
  }

  /// 转换为 JSON 映射
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'players': players,
      'title': title,
      'utTitle': utTitle,
      'artist': artist,
      'albums': albums,
      'hasDx': hasDx,
      'hasSd': hasSd,
      'hasUt': hasUt,
      'genre': genre,
      'bpm': bpm,
      'releaseDate': releaseDate,
      'from': from,
      'cn': cn,
      'jp': jp,
      'm2l': m2l,
      'firstRomVersion': firstRomVersion,
      'dxRomVersion': dxRomVersion,
      'sdRomVersion': sdRomVersion,
      'utRomVersion': utRomVersion,
      'dx': _serializeDifficultyMap(dx),
      'sd': _serializeDifficultyMap(sd),
      'ut': _serializeDifficultyMap(ut),
      'aboutChu_id': aboutChuId,
      'isLong': isLong,
    };
  }

  /// 辅助：从 JSON Map 转换为 Map<String, Difficulty>
  static Map<String, Difficulty>? _parseDifficultyMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    return map.map((key, value) => MapEntry(key, Difficulty.fromJson(value as Map<String, dynamic>)));
  }

  /// 辅助：将 Map<String, Difficulty> 序列化为 Map<String, dynamic>
  static Map<String, dynamic>? _serializeDifficultyMap(Map<String, Difficulty>? map) {
    if (map == null) return null;
    return map.map((key, value) => MapEntry(key, value.toJson()));
  }

  /// 从 JSON 数组解析为 List<SongInfo>
  static List<SongInfo> listFromJson(List<dynamic> jsonList) {
    return jsonList.map((e) => SongInfo.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 从 API 响应字符串解析：API 直接返回数组 [{...}]
  static List<SongInfo> parseResponse(String responseBody) {
    final List<dynamic> dataList = json.decode(responseBody) as List<dynamic>;
    return dataList.map((e) => SongInfo.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 将 List<SongInfo> 序列化为 JSON 数组
  static List<Map<String, dynamic>> listToJson(List<SongInfo> list) {
    return list.map((e) => e.toJson()).toList();
  }
}

// ============================================================

/// 单个难度谱面信息（如 DX / SD / UT）
class Difficulty {
  final int id;
  final int levelId; // JSON 中字段名为 level_id
  final String level; // 如 "5", "7", "10", "12"
  final double levelValue; // 如 5.0, 7.2, 10.2, 12.4
  final String noteDesigner;
  final int romVersion;
  final Notes? notes; // 音符统计，可能为 null
  final String? notesPath; // 新增字段，可能为 null
  final bool dx;
  final bool sd;
  final bool ot;

  Difficulty({
    required this.id,
    required this.levelId,
    required this.level,
    required this.levelValue,
    required this.noteDesigner,
    required this.romVersion,
    this.notes,
    this.notesPath,
    required this.dx,
    required this.sd,
    required this.ot,
  });

  factory Difficulty.fromJson(Map<String, dynamic> json) {
    return Difficulty(
      id: json['id'] as int? ?? 0,
      levelId: json['level_id'] as int? ?? 0,
      level: json['level'] as String? ?? '',
      levelValue: (json['level_value'] as num?)?.toDouble() ?? 0.0,
      noteDesigner: json['note_designer'] as String? ?? '',
      romVersion: json['romVersion'] as int? ?? 0,
      notes: json['notes'] != null
          ? Notes.fromJson(json['notes'] as Map<String, dynamic>)
          : null,
      notesPath: json['notesPath'] as String?,
      dx: json['dx'] as bool? ?? false,
      sd: json['sd'] as bool? ?? false,
      ot: json['ot'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'level_id': levelId,
      'level': level,
      'level_value': levelValue,
      'note_designer': noteDesigner,
      'romVersion': romVersion,
      'notes': notes?.toJson(),
      'notesPath': notesPath,
      'dx': dx,
      'sd': sd,
      'ot': ot,
    };
  }
}

// ============================================================

/// 音符统计
class Notes {
  final int? total;
  final int? tap;
  final int? hold;
  final int? slide;
  final int? touch;
  final int? breakCount; // JSON 中字段名为 "break"，序列化时映射

  Notes({
    this.total,
    this.tap,
    this.hold,
    this.slide,
    this.touch,
    this.breakCount,
  });

  factory Notes.fromJson(Map<String, dynamic> json) {
    return Notes(
      total: json['total'] as int?,
      tap: json['tap'] as int?,
      hold: json['hold'] as int?,
      slide: json['slide'] as int?,
      touch: json['touch'] as int?,
      breakCount: json['break'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total': total,
      'tap': tap,
      'hold': hold,
      'slide': slide,
      'touch': touch,
      'break': breakCount,
    };
  }
}