import '../entity/DivingFish/Song.dart';
import '../entity/DivingFish/UserPlayDataEntity.dart';

/// 定数分布数据桶
class DistributionBucket {
  /// 排序键（用于排序）
  final double sortKey;
  /// 定数下限
  final double dsMin;
  /// 定数上限
  final double dsMax;
  /// 显示标签（如 "13" 或 "13+"）
  final String label;
  /// 该区间的所有歌曲
  final List<Song> songs;
  /// 该区间中已游玩的歌曲
  final List<Song> playedSongs;

  DistributionBucket({
    required this.sortKey,
    required this.dsMin,
    required this.dsMax,
    required this.label,
    required this.songs,
    required this.playedSongs,
  });

  int get totalCount => songs.length;
  int get playedCount => playedSongs.length;
  int get unplayedCount => totalCount - playedCount;
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

    // 定数分桶：按 xx 和 xx+ 区分，参考 UserScoreSearchPage 快捷选项
    // xx:  [x.0, x.5]  (如 13.0-13.5)
    // xx+: [x.6, x.9]  (如 13.6-13.9)
    // 15:  [15.0, 15.0]
    final Map<String, DistributionBucket> buckets = {};
    for (int base = 1; base <= 14; base++) {
      // xx 桶
      final keyX = '$base';
      buckets[keyX] = DistributionBucket(
        sortKey: base.toDouble(),
        dsMin: base.toDouble(),
        dsMax: base + 0.5,
        label: keyX,
        songs: [],
        playedSongs: [],
      );
      // xx+ 桶
      final keyXPlus = '$base+';
      buckets[keyXPlus] = DistributionBucket(
        sortKey: base + 0.6,
        dsMin: base + 0.6,
        dsMax: base + 0.9,
        label: keyXPlus,
        songs: [],
        playedSongs: [],
      );
    }
    // 15 桶
    buckets['15'] = DistributionBucket(
      sortKey: 15.0,
      dsMin: 15.0,
      dsMax: 15.0,
      label: '15',
      songs: [],
      playedSongs: [],
    );

    // 遍历所有歌曲
    for (final song in allSongs) {
      if (song.ds.isEmpty) continue;

      // 确定要分析的难度索引
      final indices = levelIndex >= 0
          ? (levelIndex < song.ds.length ? [levelIndex] : <int>[])
          : List.generate(song.ds.length, (i) => i);

      for (final li in indices) {
        final ds = song.ds[li];
        if (ds <= 0 || ds > 15.0) continue;

        // 确定所属桶
        String? bucketKey;
        if (ds == 15.0) {
          bucketKey = '15';
        } else {
          final base = ds.floor();
          final decimal = ds - base;
          if (decimal <= 0.5) {
            bucketKey = '$base';
          } else {
            bucketKey = '$base+';
          }
        }

        final bucket = buckets[bucketKey];
        if (bucket == null) continue;

        bucket.songs.add(song);

        // 检查是否已游玩
        if (playedKeys.contains('${song.id}_$li')) {
          bucket.playedSongs.add(song);
        }
      }
    }

    // 过滤空桶并按 sortKey 排序
    return buckets.values
        .where((b) => b.totalCount > 0)
        .toList()
      ..sort((a, b) => a.sortKey.compareTo(b.sortKey));
  }
}