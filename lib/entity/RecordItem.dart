class RecordItem {
    final double achievements;
    final double ds;
    final int dxScore;
    final String fc;
    final String fs;
    final String level;
    final int levelIndex;
    final String levelLabel;
    final int ra;
    final String rate;
    final int songId;
    final String title;
    final String type;
    
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
      'levelIndex': levelIndex,
      'levelLabel': levelLabel,
      'ra': ra,
      'rate': rate,
      'songId': songId,
      'title': title,
      'type': type,
    };
  }

  factory RecordItem.fromJson(Map<String, dynamic> json) {
    return RecordItem(
      achievements: json['achievements'],
      ds: json['ds'],
      dxScore: json['dxScore'],
      fc: json['fc'],
      fs: json['fs'],
      level: json['level'],
      levelIndex: json['level_index'],
      levelLabel: json['level_label'],
      ra: json['ra'],
      rate: json['rate'],
      songId: json['song_id'],
      title: json['title'],
      type: json['type'],
    );
  }
}