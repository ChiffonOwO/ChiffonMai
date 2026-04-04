/// 落雪歌曲实体根类
/// 包含歌曲列表、流派列表和版本列表
class LuoXueSongEntity {
  final List<LuoXueSong> songs;
  final List<LuoXueGenre> genres;
  final List<LuoXueVersion> versions;

  LuoXueSongEntity({
    required this.songs,
    required this.genres,
    required this.versions,
  });

  factory LuoXueSongEntity.fromJson(Map<String, dynamic> json) {
    return LuoXueSongEntity(
      songs: (json['songs'] as List<dynamic>)
          .map((e) => LuoXueSong.fromJson(e as Map<String, dynamic>))
          .toList(),
      genres: (json['genres'] as List<dynamic>)
          .map((e) => LuoXueGenre.fromJson(e as Map<String, dynamic>))
          .toList(),
      versions: (json['versions'] as List<dynamic>)
          .map((e) => LuoXueVersion.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 落雪歌曲信息类
/// 嵌套在 LuoXueSongEntity 中
class LuoXueSong {
  final int id; // 曲目 ID
  final String title; // 曲名
  final String artist; // 艺术家
  final String genre; // 曲目分类
  final int bpm; // BPM
  final String? map; // 值可空，曲目所属区域
  final int version; // 曲目首次出现版本
  final String? rights; // 值可空，曲目版权信息
  final bool? locked; // 值可空，是否需要解锁，默认值为 false
  final bool? disabled; // 值可空，是否已禁用，默认值为 false
  final LuoXueSongDifficulties difficulties; // 谱面难度

  LuoXueSong({
    required this.id,
    required this.title,
    required this.artist,
    required this.genre,
    required this.bpm,
    this.map,
    required this.version,
    this.rights,
    this.locked,
    this.disabled,
    required this.difficulties,
  });

  factory LuoXueSong.fromJson(Map<String, dynamic> json) {
    return LuoXueSong(
      id: json['id'] as int,
      title: json['title'] as String,
      artist: json['artist'] as String,
      genre: json['genre'] as String,
      bpm: json['bpm'] as int,
      map: json['map'] as String?,
      version: json['version'] as int,
      rights: json['rights'] as String?,
      locked: json['locked'] as bool?,
      disabled: json['disabled'] as bool?,
      difficulties: LuoXueSongDifficulties.fromJson(json['difficulties'] as Map<String, dynamic>),
    );
  }
}

/// 落雪流派信息类
/// 嵌套在 LuoXueSongEntity 中
class LuoXueGenre {
  final int id;
  final String title;
  final String genre;

  LuoXueGenre({
    required this.id,
    required this.title,
    required this.genre,
  });

  factory LuoXueGenre.fromJson(Map<String, dynamic> json) {
    return LuoXueGenre(
      id: json['id'] as int,
      title: json['title'] as String,
      genre: json['genre'] as String,
    );
  }
}

/// 落雪版本信息类
/// 嵌套在 LuoXueSongEntity 中
class LuoXueVersion {
  final int id;
  final String title;
  final int version;

  LuoXueVersion({
    required this.id,
    required this.title,
    required this.version,
  });

  factory LuoXueVersion.fromJson(Map<String, dynamic> json) {
    return LuoXueVersion(
      id: json['id'] as int,
      title: json['title'] as String,
      version: json['version'] as int,
    );
  }
}

/// 落雪歌曲难度集合类
/// 嵌套在 LuoXueSong 中
class LuoXueSongDifficulties {
  final List<LuoXueSongDifficulty>? standard; // 曲目标准谱面难度列表
  final List<LuoXueSongDifficulty>? dx; // 曲目 DX 谱面难度列表
  final List<LuoXueSongDifficultyUtage>? utage; // 可选，宴会场曲目谱面难度列表

  LuoXueSongDifficulties({
    this.standard,
    this.dx,
    this.utage,
  });

  factory LuoXueSongDifficulties.fromJson(Map<String, dynamic> json) {
    return LuoXueSongDifficulties(
      standard: json['standard'] != null
          ? (json['standard'] as List<dynamic>)
              .map((e) => LuoXueSongDifficulty.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      dx: json['dx'] != null
          ? (json['dx'] as List<dynamic>)
              .map((e) => LuoXueSongDifficulty.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      utage: json['utage'] != null
          ? (json['utage'] as List<dynamic>)
              .map((e) => LuoXueSongDifficultyUtage.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
    );
  }
}

/// 落雪歌曲难度信息类
/// 嵌套在 LuoXueSongDifficulties 中
class LuoXueSongDifficulty {
  final String type; // 谱面类型
  final int difficulty; // 难度
  final String level; // 难度标级
  final num levelValue; // 谱面定数
  final String noteDesigner; // 谱师
  final int version; // 谱面首次出现版本
  final LuoXueSongNotes? notes; // 值可空，谱面物量

  LuoXueSongDifficulty({
    required this.type,
    required this.difficulty,
    required this.level,
    required this.levelValue,
    required this.noteDesigner,
    required this.version,
    this.notes,
  });

  factory LuoXueSongDifficulty.fromJson(Map<String, dynamic> json) {
    return LuoXueSongDifficulty(
      type: json['type'] as String,
      difficulty: json['difficulty'] as int,
      level: json['level'] as String,
      levelValue: json['level_value'] as num,
      noteDesigner: json['note_designer'] as String,
      version: json['version'] as int,
      notes: json['notes'] != null
          ? LuoXueSongNotes.fromJson(json['notes'] as Map<String, dynamic>)
          : null,
    );
  }
}



/// 落雪歌曲Utage难度信息类
/// 嵌套在 LuoXueSongDifficulties 中
class LuoXueSongDifficultyUtage {
  final String kanji; // 谱面属性
  final String description; // 谱面描述
  final bool isBuddy; // 是否为BUDDY谱面
  final Object? notes; // 值可空，谱面物量，可以是LuoXueSongNotes或LuoXueBuddyNotes

  LuoXueSongDifficultyUtage({
    required this.kanji,
    required this.description,
    required this.isBuddy,
    this.notes,
  });

  factory LuoXueSongDifficultyUtage.fromJson(Map<String, dynamic> json) {
    return LuoXueSongDifficultyUtage(
      kanji: json['kanji'] as String,
      description: json['description'] as String,
      isBuddy: json['is_buddy'] as bool,
      notes: json['notes'] != null
          ? (() {
              final notesMap = json['notes'] as Map<String, dynamic>;
              // 检查是否为Buddy谱面的notes结构（包含left和right字段）
              if (notesMap.containsKey('left') && notesMap.containsKey('right')) {
                return LuoXueBuddyNotes.fromJson(notesMap);
              } else {
                // 否则视为普通谱面的notes结构
                return LuoXueSongNotes.fromJson(notesMap);
              }
            })()
          : null,
    );
  }
}

/// 落雪歌曲音符信息类
/// 嵌套在 LuoXueSongDifficulty 和 LuoXueSongDifficultyUtage 中
class LuoXueSongNotes {
  final int total;
  final int tap;
  final int hold;
  final int slide;
  final int touch;
  final int breakNote;  // json中的字段名为break，注意映射关系

  LuoXueSongNotes({
    required this.total,
    required this.tap,
    required this.hold,
    required this.slide,
    required this.touch,
    required this.breakNote,
  });

  factory LuoXueSongNotes.fromJson(Map<String, dynamic> json) {
    return LuoXueSongNotes(
      total: json['total'] as int,
      tap: json['tap'] as int,
      hold: json['hold'] as int,
      slide: json['slide'] as int,
      touch: json['touch'] as int,
      breakNote: json['break'] as int, // 注意：json中的字段名为break
    );
  }
}

class LuoXueBuddyNotes{
  final LuoXueSongNotes? left; // 1P 谱面物量
  final LuoXueSongNotes? right; // 2P 谱面物量

  LuoXueBuddyNotes({
    this.left,
    this.right,
  });

  factory LuoXueBuddyNotes.fromJson(Map<String, dynamic> json) {
    return LuoXueBuddyNotes(
      left: json['left'] != null
          ? LuoXueSongNotes.fromJson(json['left'] as Map<String, dynamic>)
          : null,
      right: json['right'] != null
          ? LuoXueSongNotes.fromJson(json['right'] as Map<String, dynamic>)
          : null,
    );
  }
}