class RecommendationResult {
  final String songTitle;
  final String level;
  final double ds;
  final double similarity;
  final double nowAchievement;
  final double minAchievement;
  final bool ableRiseTotalRating;
  final String riseTotalRating;
  final String songId;
  final int levelIndex;

  RecommendationResult({
    required this.songTitle,
    required this.level,
    required this.ds,
    required this.similarity,
    required this.nowAchievement,
    required this.minAchievement,
    required this.ableRiseTotalRating,
    required this.riseTotalRating,
    required this.songId,
    required this.levelIndex,
  });

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'songTitle': songTitle,
      'level': level,
      'ds': ds,
      'similarity': similarity,
      'nowAchievement': nowAchievement,
      'minAchievement': minAchievement,
      'ableRiseTotalRating': ableRiseTotalRating,
      'riseTotalRating': riseTotalRating,
      'songId': songId,
      'levelIndex': levelIndex,
    };
  }

  // 从JSON创建实例
  factory RecommendationResult.fromJson(Map<String, dynamic> json) {
    return RecommendationResult(
      songTitle: json['songTitle'] ?? '',
      level: json['level'] ?? '',
      ds: json['ds'] ?? 0.0,
      similarity: json['similarity'] ?? 0.0,
      nowAchievement: json['nowAchievement'] ?? 0.0,
      minAchievement: json['minAchievement'] ?? 0.0,
      ableRiseTotalRating: json['ableRiseTotalRating'] ?? false,
      riseTotalRating: json['riseTotalRating'] ?? '',
      songId: json['songId'] ?? '',
      levelIndex: json['levelIndex'] ?? 0,
    );
  }
}