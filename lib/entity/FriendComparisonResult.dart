/// 单张谱面的好友对比项
class ChartComparisonItem {
  final int songId;
  final String songTitle;
  final int levelIndex;
  final String levelLabel; // "Master", "Expert" 等
  final double ds;
  final String type; // "SD" / "DX"
  final double myAchievements;
  final double friendAchievements;
  final int myRa;
  final int friendRa;
  final String myRate; // SSS+, SS, 等
  final String friendRate;
  final String myFc;
  final String friendFc;
  final String myFs;
  final String friendFs;
  final int myDxScore;
  final int friendDxScore;

  ChartComparisonItem({
    required this.songId,
    required this.songTitle,
    required this.levelIndex,
    required this.levelLabel,
    required this.ds,
    required this.type,
    required this.myAchievements,
    required this.friendAchievements,
    required this.myRa,
    required this.friendRa,
    required this.myRate,
    required this.friendRate,
    required this.myFc,
    required this.friendFc,
    required this.myFs,
    required this.friendFs,
    required this.myDxScore,
    required this.friendDxScore,
  });

  /// 达成率差距（正数=好友更高）
  double get achievementDiff => friendAchievements - myAchievements;

  /// RA 差距（正数=好友更高）
  int get raDiff => friendRa - myRa;

  /// 我是否赢了
  bool get isMyWin => myAchievements > friendAchievements;

  /// 平局
  bool get isTie => myAchievements == friendAchievements;

  /// 好友是否赢了
  bool get isFriendWin => friendAchievements > myAchievements;
}

/// 好友对比总结果
class ComparisonResult {
  final List<ChartComparisonItem> commonCharts; // 共同谱面对比详情
  final int myTotalCharts; // 我的总谱面数
  final int friendTotalCharts; // 好友总谱面数
  final int commonCount; // 共同谱面数
  final int myWinCount; // 我赢的谱面数
  final int friendWinCount; // 好友赢的谱面数
  final int tieCount; // 平局数
  final String friendNickname; // 好友昵称
  final int friendRating; // 好友 Rating
  final int myRating; // 我的 Rating

  ComparisonResult({
    required this.commonCharts,
    required this.myTotalCharts,
    required this.friendTotalCharts,
    required this.commonCount,
    required this.myWinCount,
    required this.friendWinCount,
    required this.tieCount,
    required this.friendNickname,
    required this.friendRating,
    required this.myRating,
  });
}
