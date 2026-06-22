import 'dart:math';

/// 多人游戏确定性随机工具类
///
/// 所有玩家使用相同的 seed 生成相同的随机参数，确保：
/// - 曲绘截取位置统一
/// - 模糊程度统一
/// - 歌曲片段截取位置统一
class GameSeedUtil {
  /// 从房间ID、回合数和目标歌曲ID生成确定性种子
  static int generateSeed({
    required String roomId,
    required int roundNumber,
    required String targetSongId,
  }) {
    final combined = '$roomId-$roundNumber-$targetSongId';
    return combined.hashCode.abs();
  }

  /// 使用种子生成 [0.0, 1.0) 范围内的随机双精度数
  static double nextDouble(Random random) {
    return random.nextDouble();
  }

  /// 使用种子生成 [min, max) 范围内的随机整数
  static int nextInt(Random random, int min, int max) {
    return min + random.nextInt(max - min);
  }

  /// 创建基于种子的随机数生成器
  static Random createRandom(int seed) {
    return Random(seed);
  }

  /// 生成曲绘截取位置的四个参数 (x1, y1, x2, y2)
  /// 确保截取区域在有效的 0-1 范围内，且宽高合理
  static CropRect generateCropRect({
    required String roomId,
    required int roundNumber,
    required String targetSongId,
  }) {
    final seed = generateSeed(
      roomId: roomId,
      roundNumber: roundNumber,
      targetSongId: targetSongId,
    );
    final random = Random(seed);

    // 截取起始位置 (0~0.7 范围内，留出足够空间给宽高)
    final x1 = random.nextDouble() * 0.7;
    final y1 = random.nextDouble() * 0.7;

    // 截取宽度和高度 (10%~35% 的图片尺寸)
    final width = 0.1 + random.nextDouble() * 0.25;
    final height = 0.1 + random.nextDouble() * 0.25;

    // 确保不超出边界
    final x2 = (x1 + width).clamp(0.0, 1.0);
    final y2 = (y1 + height).clamp(0.0, 1.0);

    return CropRect(x1: x1, y1: y1, x2: x2, y2: y2);
  }

  /// 生成音频片段开始时间（秒）
  /// [totalDuration] 是歌曲的总时长（秒）
  /// [playDuration] 是片段的播放时长（秒）
  static int generateAudioStartTime({
    required String roomId,
    required int roundNumber,
    required String targetSongId,
    required int totalDuration,
    required int playDuration,
  }) {
    final seed = generateSeed(
      roomId: roomId,
      roundNumber: roundNumber,
      targetSongId: targetSongId,
    );
    final random = Random(seed);

    final maxStartTime = totalDuration - playDuration;
    if (maxStartTime <= 0) return 0;
    return random.nextInt(maxStartTime);
  }

  /// 生成模糊程度（0-100）
  /// 使用房间设置的基准模糊程度加上微小的确定性偏移
  static int generateBlurLevel({
    required String roomId,
    required int roundNumber,
    required String targetSongId,
    required int baseBlurLevel,
  }) {
    final seed = generateSeed(
      roomId: roomId,
      roundNumber: roundNumber,
      targetSongId: targetSongId,
    );
    final random = Random(seed);

    // 在基准值的 ±5 范围内微调，确保变化不大但又有随机感
    final offset = random.nextInt(11) - 5; // -5 to +5
    return (baseBlurLevel + offset).clamp(0, 100);
  }
}

/// 曲绘截取区域
class CropRect {
  final double x1;
  final double y1;
  final double x2;
  final double y2;

  const CropRect({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  double get width => x2 - x1;
  double get height => y2 - y1;
}
