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
  /// 用户在该谱面的最佳达成率（可选，来自玩家数据）
  final double? achievement;
  /// 用户游玩该谱面的次数（可选，来自玩家数据）
  final int? playCount;

  FavoriteChart({
    required this.songId,
    required this.levelIndex,
    required this.songTitle,
    required this.level,
    required this.ds,
    this.songType = '',
    int? addedAt,
    this.achievement,
    this.playCount,
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
      achievement: json['achievement']?.toDouble(),
      playCount: json['playCount'],
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'songId': songId,
      'levelIndex': levelIndex,
      'songTitle': songTitle,
      'level': level,
      'ds': ds,
      'songType': songType,
      'addedAt': addedAt,
    };
    if (achievement != null) map['achievement'] = achievement;
    if (playCount != null) map['playCount'] = playCount;
    return map;
  }

  /// 生成唯一键用于去重：songId + '_' + levelIndex
  String get uniqueKey => '${songId}_$levelIndex';

  /// 创建带有更新成绩信息的副本
  FavoriteChart copyWith({double? achievement, int? playCount}) {
    return FavoriteChart(
      songId: songId,
      levelIndex: levelIndex,
      songTitle: songTitle,
      level: level,
      ds: ds,
      songType: songType,
      addedAt: addedAt,
      achievement: achievement ?? this.achievement,
      playCount: playCount ?? this.playCount,
    );
  }

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

/// 排序选项
enum FavoriteSortOption {
  byDsDesc,    // 定数 高→低
  byDsAsc,     // 定数 低→高
  byDateNewest, // 添加时间 新→旧
  byDateOldest, // 添加时间 旧→新
  byTitle,      // 按歌名 A-Z
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
