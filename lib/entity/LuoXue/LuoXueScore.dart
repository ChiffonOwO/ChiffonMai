class LuoXueScore {
  final num id; // 曲目id
  final String songName; // 曲目名称
  final String level; // 难度标级（14+）
  final num levelIndex; // 难度索引（0-4）
  final num achievements; // 达成率
  final String? fc; // 值可空，连击
  final String? fs; // 值可空，同步
  final num dxScore; // DX分数
  final num dxStar; // DX星数
  final num dxRating; // DXRating
  final String rate; // 评级类型
  final String type; // 谱面类型
  final String playTime; // 值可空，游玩的 UTC 时间，精确到分钟
  final String? uploadTime; // 成绩被同步时的 UTC 时间
  final String lastPlayedTime; // 谱面最后游玩的 UTC 时间

  LuoXueScore({
    required this.id,
    required this.songName,
    required this.level,
    required this.levelIndex,
    required this.achievements,
    this.fc,
    this.fs,
    required this.dxScore,
    required this.dxStar,
    required this.dxRating,
    required this.rate,
    required this.type,
    required this.playTime,
    this.uploadTime,
    required this.lastPlayedTime,
  });

  factory LuoXueScore.fromJson(Map<String, dynamic> json) {
    return LuoXueScore(
      id: json['id'] as num? ?? 0,
      songName: json['song_name'] as String? ?? '',
      level: json['level'] as String? ?? '',
      levelIndex: json['level_index'] as num? ?? 0,
      achievements: json['achievements'] as num? ?? 0,
      fc: json['fc'] as String?,
      fs: json['fs'] as String?,
      dxScore: json['dx_score'] as num? ?? 0,
      dxStar: json['dx_star'] as num? ?? 0,
      dxRating: json['dx_rating'] as num? ?? 0,
      rate: json['rate'] as String? ?? '',
      type: json['type'] as String? ?? '',
      playTime: json['play_time'] as String? ?? '',
      uploadTime: json['upload_time'] as String?,
      lastPlayedTime: json['last_played_time'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'song_name': songName,
      'level': level,
      'level_index': levelIndex,
      'achievements': achievements,
      'fc': fc,
      'fs': fs,
      'dx_score': dxScore,
      'dx_star': dxStar,
      'dx_rating': dxRating,
      'rate': rate,
      'type': type,
      'play_time': playTime,
      'upload_time': uploadTime,
      'last_played_time': lastPlayedTime,
    };
  }

  @override
  String toString() {
    return 'LuoXueScore{id: $id, songName: $songName, level: $level, achievements: $achievements}';
  }
}