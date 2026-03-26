/**
 * 为maiTag.json设计的实体类
 */

class MaiTagsEntity {
  final List<TagItem> tags;
  final List<TagGroupItem> tagGroups;
  final List<TagSongItem> tagSongs;

  MaiTagsEntity({
    required this.tags,
    required this.tagGroups,
    required this.tagSongs,
  });

  factory MaiTagsEntity.fromJson(Map<String, dynamic> json) {
    return MaiTagsEntity(
      tags: List<TagItem>.from(
        json['tags'].map((item) => TagItem.fromJson(item)),
      ),
      tagGroups: List<TagGroupItem>.from(
        json['tagGroups'].map((item) => TagGroupItem.fromJson(item)),
      ),
      tagSongs: List<TagSongItem>.from(
        json['tagSongs'].map((item) => TagSongItem.fromJson(item)),
      ),
    );
  }
}

// 一级嵌套实体
class TagItem {
  final int id;
  final LocalizedName localizedName;
  final LocalizedDescription localizedDescription;
  final int groupId;

  TagItem({
    required this.id,
    required this.localizedName,
    required this.localizedDescription,
    required this.groupId,
  });

  factory TagItem.fromJson(Map<String, dynamic> json) {
    return TagItem(
      id: json['id'],
      localizedName: LocalizedName.fromJson(json['localized_name']),
      localizedDescription: LocalizedDescription.fromJson(json['localized_description']),
      groupId: json['group_id'],
    );
  }
}


class TagGroupItem {
  final int id;
  final LocalizedName localizedName;
  final String color;

  TagGroupItem({
    required this.id,
    required this.localizedName,
    required this.color,
  });

  factory TagGroupItem.fromJson(Map<String, dynamic> json) {
    return TagGroupItem(
      id: json['id'],
      localizedName: LocalizedName.fromJson(json['localized_name']),
      color: json['color'],
    );
  }
}

class TagSongItem {
  final String songId;
  final String sheetType;
  final String sheetDifficulty;
  final int tagId;

  TagSongItem({
    required this.songId,
    required this.sheetType,
    required this.sheetDifficulty,
    required this.tagId,
  });

  factory TagSongItem.fromJson(Map<String, dynamic> json) {
    return TagSongItem(
      songId: json['song_id'],
      sheetType: json['sheet_type'],
      sheetDifficulty: json['sheet_difficulty'],
      tagId: json['tag_id'],
    );
  }
}

// 二级嵌套实体
class LocalizedName {
  final String en;
  final String ja;
  final String ko;
  final String zhHans;

  LocalizedName({
    required this.en,
    required this.ja,
    required this.ko,
    required this.zhHans,
  });

  factory LocalizedName.fromJson(Map<String, dynamic> json) {
    return LocalizedName(
      en: json['en'],
      ja: json['ja'],
      ko: json['ko'],
      zhHans: json['zh-Hans'],
    );
  }
}

class LocalizedDescription {
  final String en;
  final String ja;
  final String ko;
  final String zhHans;

  LocalizedDescription({
    required this.en,
    required this.ja,
    required this.ko,
    required this.zhHans,
  });

  factory LocalizedDescription.fromJson(Map<String, dynamic> json) {
    return LocalizedDescription(
      en: json['en'],
      ja: json['ja'],
      ko: json['ko'],
      zhHans: json['zh-Hans'],
    );
  }
}