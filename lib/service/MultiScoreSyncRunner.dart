import 'SyncStatsService.dart';

class MultiScoreSyncResult {
  final SyncPlatform platform;
  final String message;
  final bool ok;

  const MultiScoreSyncResult({
    required this.platform,
    required this.message,
    required this.ok,
  });
}

/// 多端同步固定按水鱼 → 落雪 → AWMC NET 串行执行。
/// 不提前创建 Future；一个目标失败后仍继续下一个勾选的目标。
class MultiScoreSyncRunner {
  static Future<List<MultiScoreSyncResult>> run({
    required Set<SyncPlatform> platforms,
    required Future<String> Function(SyncPlatform platform) execute,
  }) async {
    final results = <MultiScoreSyncResult>[];
    for (final platform in SyncPlatform.values) {
      if (!platforms.contains(platform)) continue;
      try {
        final message = await execute(platform);
        results.add(MultiScoreSyncResult(platform: platform, message: message, ok: true));
      } catch (error) {
        results.add(MultiScoreSyncResult(platform: platform, message: '$error', ok: false));
      }
    }
    return results;
  }
}
