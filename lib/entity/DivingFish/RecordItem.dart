class RecordItem {
    final num achievements; // 达成率
    final double ds; // 定数（14.9）
    final int dxScore; // DX分数
    final String fc; // 连击
    final String fs; // 同步
    final String level; // 难度标级（14+）
    final int levelIndex; // 难度索引
    final String levelLabel; // 难度（Master）
    final int ra; // Rating
    final String rate; // 评级类型
    final int songId; // 曲目id
    final String title; // 曲目名称
    final String type; // 音乐类型（SD/DX）
    
    RecordItem({
      required this.achievements,
      required this.ds,
      required this.dxScore,
      required this.fc,
      required this.fs,
      required this.level,
      required this.levelIndex,
      required this.levelLabel,
      required this.ra,
      required this.rate,
      required this.songId,
      required this.title,
      required this.type,
    });

    Map<String, dynamic> toJson() {
    return {
      'achievements': achievements,
      'ds': ds,
      'dxScore': dxScore,
      'fc': fc,
      'fs': fs,
      'level': level,
      'level_index': levelIndex,
      'level_label': levelLabel,
      'ra': ra,
      'rate': rate,
      'song_id': songId,
      'title': title,
      'type': type,
    };
  }

  factory RecordItem.fromJson(Map<String, dynamic> json) {
    return RecordItem(
      achievements: json['achievements'] ?? 0,
      ds: json['ds'] ?? 0.0,
      dxScore: json['dxScore'] ?? 0,
      fc: json['fc'] ?? '',
      fs: json['fs'] ?? '',
      level: json['level'] ?? '',
      levelIndex: json['level_index'] ?? 0,
      levelLabel: json['level_label'] ?? '',
      ra: json['ra'] ?? 0,
      rate: json['rate'] ?? '',
      songId: json['song_id'] ?? 0,
      title: json['title'] ?? '未知歌曲',
      type: json['type'] ?? '',
    );
  }
  @override
  String toString() {
    return 'RecordItem(achievements: $achievements, ds: $ds, dxScore: $dxScore, fc: $fc, fs: $fs, level: $level, levelIndex: $levelIndex, levelLabel: $levelLabel, ra: $ra, rate: $rate, songId: $songId, title: $title, type: $type)';
  }
}