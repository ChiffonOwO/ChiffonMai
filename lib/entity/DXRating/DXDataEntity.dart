import 'MaiTagsModel.dart';

class DXDataEntity {
  final int schemaVersion;
  final String updatedAt;
  final List<DXDataCategory> categories;
  final List<DXDataVersion> versions;
  final List<DXDataType> types;
  final List<DXDataDifficulty> difficulties;
  final List<DXDataServer> servers;
  final List<DXDataSong> songs;
  final List<DXDataTagGroup> tagGroups;
  final List<DXDataTag> tags;
  final List<DXDataTagSong> tagSongs;
  final List<DXDataAlias> aliases;

  DXDataEntity({
    required this.schemaVersion,
    required this.updatedAt,
    required this.categories,
    required this.versions,
    required this.types,
    required this.difficulties,
    required this.servers,
    required this.songs,
    required this.tagGroups,
    required this.tags,
    required this.tagSongs,
    required this.aliases,
  });

  factory DXDataEntity.fromJson(Map<String, dynamic> json) {
    return DXDataEntity(
      schemaVersion: json['schemaVersion'] as int,
      updatedAt: json['updatedAt'] as String,
      categories: (json['categories'] as List<dynamic>)
          .map((e) => DXDataCategory.fromJson(e as Map<String, dynamic>))
          .toList(),
      versions: (json['versions'] as List<dynamic>)
          .map((e) => DXDataVersion.fromJson(e as Map<String, dynamic>))
          .toList(),
      types: (json['types'] as List<dynamic>)
          .map((e) => DXDataType.fromJson(e as Map<String, dynamic>))
          .toList(),
      difficulties: (json['difficulties'] as List<dynamic>)
          .map((e) => DXDataDifficulty.fromJson(e as Map<String, dynamic>))
          .toList(),
      servers: (json['servers'] as List<dynamic>)
          .map((e) => DXDataServer.fromJson(e as Map<String, dynamic>))
          .toList(),
      songs: (json['songs'] as List<dynamic>)
          .map((e) => DXDataSong.fromJson(e as Map<String, dynamic>))
          .toList(),
      tagGroups: (json['tagGroups'] as List<dynamic>)
          .map((e) => DXDataTagGroup.fromJson(e as Map<String, dynamic>))
          .toList(),
      tags: (json['tags'] as List<dynamic>)
          .map((e) => DXDataTag.fromJson(e as Map<String, dynamic>))
          .toList(),
      tagSongs: (json['tagSongs'] as List<dynamic>)
          .map((e) => DXDataTagSong.fromJson(e as Map<String, dynamic>))
          .toList(),
      aliases: (json['aliases'] as List<dynamic>)
          .map((e) => DXDataAlias.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class DXDataCategory {
  final String category;

  DXDataCategory({required this.category});

  factory DXDataCategory.fromJson(Map<String, dynamic> json) {
    return DXDataCategory(
      category: json['category'] as String,
    );
  }
}

class DXDataVersion {
  final String version;
  final String abbr;
  final String releaseDate;

  DXDataVersion({
    required this.version,
    required this.abbr,
    required this.releaseDate,
  });

  factory DXDataVersion.fromJson(Map<String, dynamic> json) {
    return DXDataVersion(
      version: json['version'] as String,
      abbr: json['abbr'] as String,
      releaseDate: json['releaseDate'] as String,
    );
  }
}

class DXDataType {
  final String type;
  final String name;
  final String abbr;
  final String? iconUrl;
  final int? iconHeight;

  DXDataType({
    required this.type,
    required this.name,
    required this.abbr,
    this.iconUrl,
    this.iconHeight,
  });

  factory DXDataType.fromJson(Map<String, dynamic> json) {
    return DXDataType(
      type: json['type'] as String,
      name: json['name'] as String,
      abbr: json['abbr'] as String,
      iconUrl: json['iconUrl'] as String?,
      iconHeight: json['iconHeight'] as int?,
    );
  }
}

class DXDataDifficulty {
  final String difficulty;
  final String name;
  final String? color;

  DXDataDifficulty({
    required this.difficulty,
    required this.name,
    this.color,
  });

  factory DXDataDifficulty.fromJson(Map<String, dynamic> json) {
    return DXDataDifficulty(
      difficulty: json['difficulty'] as String,
      name: json['name'] as String,
      color: json['color'] as String?,
    );
  }
}

class DXDataServer {
  final String id;
  final String name;

  DXDataServer({required this.id, required this.name});

  factory DXDataServer.fromJson(Map<String, dynamic> json) {
    return DXDataServer(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }
}

class DXDataSong {
  final String id;
  final String category;
  final String title;
  final String artist;
  final double bpm;
  final String imageName;
  final String version;
  final bool isNew;
  final bool isLocked;
  final List<DXDataSheet> sheets;
  final List<String> searchAcronyms;

  DXDataSong({
    required this.id,
    required this.category,
    required this.title,
    required this.artist,
    required this.bpm,
    required this.imageName,
    required this.version,
    required this.isNew,
    required this.isLocked,
    required this.sheets,
    required this.searchAcronyms,
  });

  factory DXDataSong.fromJson(Map<String, dynamic> json) {
    return DXDataSong(
      id: json['id'] as String,
      category: json['category'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      bpm: (json['bpm'] as num?)?.toDouble() ?? 0.0,
      imageName: json['imageName'] as String,
      version: json['version'] as String,
      isNew: json['isNew'] as bool,
      isLocked: json['isLocked'] as bool,
      sheets: (json['sheets'] as List<dynamic>)
          .map((e) => DXDataSheet.fromJson(e as Map<String, dynamic>))
          .toList(),
      searchAcronyms: (json['searchAcronyms'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );
  }
}

class DXDataSheet {
  final String id;
  final String type;
  final String difficulty;
  final String level;
  final double internalLevelValue;
  final Map<String, double> multiverInternalLevelValue;
  final String noteDesigner;
  final DXDataNoteCounts noteCounts;
  final List<String> serverIds;
  final bool isSpecial;
  final String version;
  final int internalId;
  final String releaseDate;

  DXDataSheet({
    required this.id,
    required this.type,
    required this.difficulty,
    required this.level,
    required this.internalLevelValue,
    required this.multiverInternalLevelValue,
    required this.noteDesigner,
    required this.noteCounts,
    required this.serverIds,
    required this.isSpecial,
    required this.version,
    required this.internalId,
    required this.releaseDate,
  });

  factory DXDataSheet.fromJson(Map<String, dynamic> json) {
    return DXDataSheet(
      id: json['id'] as String,
      type: json['type'] as String,
      difficulty: json['difficulty'] as String,
      level: json['level'] as String,
      internalLevelValue: (json['internalLevelValue'] as num).toDouble(),
      multiverInternalLevelValue: _parseMultiverLevel(
          json['multiverInternalLevelValue']),
      noteDesigner: json['noteDesigner'] as String? ?? '',
      noteCounts: DXDataNoteCounts.fromJson(
          json['noteCounts'] as Map<String, dynamic>),
      serverIds: (json['serverIds'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      isSpecial: json['isSpecial'] as bool,
      version: json['version'] as String,
      internalId: json['internalId'] as int? ?? 0,
      releaseDate: json['releaseDate'] as String,
    );
  }
}

class DXDataNoteCounts {
  final int tap;
  final int hold;
  final int slide;
  final int? touch;
  final int breakCount;
  final int total;

  DXDataNoteCounts({
    required this.tap,
    required this.hold,
    required this.slide,
    this.touch,
    required this.breakCount,
    required this.total,
  });

  factory DXDataNoteCounts.fromJson(Map<String, dynamic> json) {
    return DXDataNoteCounts(
      tap: json['tap'] as int? ?? 0,
      hold: json['hold'] as int? ?? 0,
      slide: json['slide'] as int? ?? 0,
      touch: json['touch'] as int?,
      breakCount: json['break'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
    );
  }
}

class DXDataTagGroup {
  final int id;
  final LocalizedName localizedName;
  final String color;

  DXDataTagGroup({
    required this.id,
    required this.localizedName,
    required this.color,
  });

  factory DXDataTagGroup.fromJson(Map<String, dynamic> json) {
    return DXDataTagGroup(
      id: json['id'] as int,
      localizedName:
          LocalizedName.fromJson(json['localized_name'] as Map<String, dynamic>),
      color: json['color'] as String,
    );
  }
}

class DXDataTag {
  final int id;
  final LocalizedName localizedName;
  final LocalizedDescription localizedDescription;
  final int groupId;

  DXDataTag({
    required this.id,
    required this.localizedName,
    required this.localizedDescription,
    required this.groupId,
  });

  factory DXDataTag.fromJson(Map<String, dynamic> json) {
    return DXDataTag(
      id: json['id'] as int,
      localizedName:
          LocalizedName.fromJson(json['localized_name'] as Map<String, dynamic>),
      localizedDescription: LocalizedDescription.fromJson(
          json['localized_description'] as Map<String, dynamic>),
      groupId: json['group_id'] as int,
    );
  }
}

class DXDataTagSong {
  final String songId;
  final String sheetId;
  final String sheetType;
  final String sheetDifficulty;
  final int tagId;

  DXDataTagSong({
    required this.songId,
    required this.sheetId,
    required this.sheetType,
    required this.sheetDifficulty,
    required this.tagId,
  });

  factory DXDataTagSong.fromJson(Map<String, dynamic> json) {
    return DXDataTagSong(
      songId: json['song_id'] as String,
      sheetId: json['sheet_id'] as String,
      sheetType: json['sheet_type'] as String,
      sheetDifficulty: json['sheet_difficulty'] as String,
      tagId: json['tag_id'] as int,
    );
  }
}

class DXDataAlias {
  final String songId;
  final String name;

  DXDataAlias({required this.songId, required this.name});

  factory DXDataAlias.fromJson(Map<String, dynamic> json) {
    return DXDataAlias(
      songId: json['song_id'] as String,
      name: json['name'] as String,
    );
  }
}

/// 解析 sheet 的 multiverInternalLevelValue（版本 → 定数 映射）。
Map<String, double> _parseMultiverLevel(dynamic raw) {
  if (raw is! Map) return const {};
  final result = <String, double>{};
  raw.forEach((key, value) {
    if (value is num) {
      result[key.toString()] = value.toDouble();
    }
  });
  return result;
}