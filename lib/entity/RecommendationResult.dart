class RecommendationResult {
  final String songTitle;
  final String level;
  final double ds;
  final double similarity;
  final double minAchievement;
  final bool ableRiseTotalRating;
  final int riseTotalRating;

  RecommendationResult({
    required this.songTitle,
    required this.level,
    required this.ds,
    required this.similarity,
    required this.minAchievement,
    required this.ableRiseTotalRating,
    required this.riseTotalRating,
  });
}