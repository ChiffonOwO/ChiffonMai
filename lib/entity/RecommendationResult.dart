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
}