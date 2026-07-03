import 'package:uuid/uuid.dart';

/// 谱面笔记实体类
/// 用于存储玩家对特定谱面的个人笔记
class ChartNote {
  final String noteId; // UUID v4
  final String songId; // 歌曲ID
  final int levelIndex; // 难度索引 (0-4)
  final String songTitle; // 歌曲标题（缓存用于显示）
  final String level; // 难度等级标签
  final double ds; // 谱面定数
  final String content; // 笔记内容
  final int createdAt; // 创建时间戳
  int updatedAt; // 更新时间戳

  ChartNote({
    String? noteId,
    required this.songId,
    required this.levelIndex,
    required this.songTitle,
    required this.level,
    required this.ds,
    required this.content,
    int? createdAt,
    int? updatedAt,
  })  : noteId = noteId ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  /// 唯一标识：歌曲ID + 难度索引
  String get uniqueKey => '${songId}_$levelIndex';

  /// 从 JSON 反序列化
  factory ChartNote.fromJson(Map<String, dynamic> json) {
    return ChartNote(
      noteId: json['noteId'] as String,
      songId: json['songId'] as String,
      levelIndex: json['levelIndex'] as int,
      songTitle: json['songTitle'] as String? ?? '',
      level: json['level'] as String? ?? '',
      ds: (json['ds'] as num?)?.toDouble() ?? 0.0,
      content: json['content'] as String? ?? '',
      createdAt: json['createdAt'] as int?,
      updatedAt: json['updatedAt'] as int?,
    );
  }

  /// 序列化为 JSON
  Map<String, dynamic> toJson() {
    return {
      'noteId': noteId,
      'songId': songId,
      'levelIndex': levelIndex,
      'songTitle': songTitle,
      'level': level,
      'ds': ds,
      'content': content,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  /// 创建笔记的副本（用于更新内容）
  ChartNote copyWith({
    String? content,
    String? songTitle,
    String? level,
    double? ds,
  }) {
    return ChartNote(
      noteId: noteId,
      songId: songId,
      levelIndex: levelIndex,
      songTitle: songTitle ?? this.songTitle,
      level: level ?? this.level,
      ds: ds ?? this.ds,
      content: content ?? this.content,
      createdAt: createdAt,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }
}
