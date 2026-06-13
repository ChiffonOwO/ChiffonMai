import 'package:uuid/uuid.dart';

/// 被收藏的谱面记录
class FavoriteChart {
  final String songId;
  final int levelIndex;
  final String songTitle;
  final String level;
  final double ds;
  final String songType;
  final int addedAt;

  FavoriteChart({
    required this.songId,
    required this.levelIndex,
    required this.songTitle,
    required this.level,
    required this.ds,
    this.songType = '',
    int? addedAt,
  }) : addedAt = addedAt ?? DateTime.now().millisecondsSinceEpoch;

  factory FavoriteChart.fromJson(Map<String, dynamic> json) {
    return FavoriteChart(
      songId: json['songId'] ?? '',
      levelIndex: json['levelIndex'] ?? 0,
      songTitle: json['songTitle'] ?? '',
      level: json['level'] ?? '',
      ds: (json['ds'] ?? 0.0).toDouble(),
      songType: json['songType'] ?? '',
      addedAt: json['addedAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'songId': songId,
      'levelIndex': levelIndex,
      'songTitle': songTitle,
      'level': level,
      'ds': ds,
      'songType': songType,
      'addedAt': addedAt,
    };
  }

  /// 生成唯一键用于去重：songId + '_' + levelIndex
  String get uniqueKey => '${songId}_$levelIndex';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FavoriteChart &&
          runtimeType == other.runtimeType &&
          songId == other.songId &&
          levelIndex == other.levelIndex;

  @override
  int get hashCode => Object.hash(songId, levelIndex);
}

/// 收藏夹
class FavoriteFolder {
  final String id;
  String name;
  List<FavoriteChart> charts;
  final int createdAt;
  int updatedAt;

  FavoriteFolder({
    String? id,
    required this.name,
    List<FavoriteChart>? charts,
    int? createdAt,
    int? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        charts = charts ?? [],
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  factory FavoriteFolder.fromJson(Map<String, dynamic> json) {
    return FavoriteFolder(
      id: json['id'],
      name: json['name'] ?? '',
      charts: (json['charts'] as List<dynamic>?)
              ?.map((e) => FavoriteChart.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'charts': charts.map((c) => c.toJson()).toList(),
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}