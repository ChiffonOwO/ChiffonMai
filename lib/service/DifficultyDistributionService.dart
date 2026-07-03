import '../entity/DivingFish/Song.dart';
import '../entity/DivingFish/UserPlayDataEntity.dart';

/// 定数分布数据桶
class DistributionBucket {
  /// 定数下限（如 13.0）
  final double dsMin;
  /// 定数上限（如 13.5）
  final double dsMax;
  /// 该区间的所有歌曲
  final List<Song> songs;
  /// 该区间中已游玩的歌曲
  final List<Song> playedSongs;

  DistributionBucket({
    required this.dsMin,
    required this.dsMax,
    required this.songs,
    required this.playedSongs,
  });

  int get totalCount => songs.length;
  int get playedCount => playedSongs.length;
  int get unplayedCount => totalCount - playedCount;

  /// 定数标签（如 "13.0-13.4"）
  String get label => '${dsMin.toStringAsFixed(1)}-${(dsMax - 0.1).toStringAsFixed(1)}';
}

/// 定数分布计算服务
class DifficultyDistributionService {
  static final DifficultyDistributionService _instance =
      DifficultyDistributionService._internal();
  factory DifficultyDistributionService() => _instance;
  DifficultyDistributionService._internal();

  /// 计算指定难度级别的定数分布
  /// [levelIndex] 难度索引: 0-4 对应 BASIC~RE:MASTER, -1 表示全部
  /// [allSongs] 全曲库
  /// [userPlayData] 可选，用户游玩数据（用于区分已玩/未玩）
  static List<DistributionBucket> calculateDistribution({
    required int levelIndex,
    required List<Song> allSongs,
    UserPlayDataEntity? userPlayData,
  }) {
    // 收集已游玩谱面的唯一键
    final Set<String> playedKeys = {};
    if (userPlayData != null) {
      for (final record in userPlayData.records) {
        playedKeys.add('${record.songId}_${record.levelIndex}');
      }
    }

    // 定数分桶：从 1.0 到 15.0，步长 1.0（减少柱子数量，避免拥挤）
    final Map<int, DistributionBucket> buckets = {};
    for (double ds = 1.0; ds < 15.0; ds += 1.0) {
      final idx = (ds * 10).round();
      buckets[idx] = DistributionBucket(
        dsMin: ds,
        dsMax: ds + 0.5,
        songs: [],
        playedSongs: [],
      );
    }

    // 遍历所有歌曲
    for (final song in allSongs) {
      if (song.ds.isEmpty) continue;

      // 确定要分析的难度索引
      final indices = levelIndex >= 0
          ? (levelIndex < song.ds.length ? [levelIndex] : <int>[])
          : List.generate(song.ds.length, (i) => i);

      for (final li in indices) {
        final ds = song.ds[li];
        if (ds <= 0 || ds >= 15.0) continue;

        // 向下取整到最近的 0.5
        final bucketIdx = ((ds * 10) ~/ 5) * 5;
        final bucket = buckets[bucketIdx];
        if (bucket == null) continue;

        // 避免同一首歌重复计数（在 "全部" 模式下同一首歌多个难度各算一次）
        bucket.songs.add(song);

        // 检查是否已游玩
        if (playedKeys.contains('${song.id}_$li')) {
          bucket.playedSongs.add(song);
        }
      }
    }

    // 过滤空桶并按 dsMin 排序
    return buckets.values
        .where((b) => b.totalCount > 0)
        .toList()
      ..sort((a, b) => a.dsMin.compareTo(b.dsMin));
  }
}
