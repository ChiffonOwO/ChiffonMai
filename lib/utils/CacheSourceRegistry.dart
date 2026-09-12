import 'package:shared_preferences/shared_preferences.dart';
import '../api/ApiUrls.dart';
import '../constant/CacheKeyConstant.dart';

/// 应用内一个可被强制刷新的缓存源。
///
/// 设计要点：
/// - [cacheKey] / [timestampKey] 用作 SharedPreferences 查询；
///   cacheKey 用来判断"有没有缓存"，timestampKey 用来算剩余有效期。
/// - [ttlDays] = -1 表示该缓存永不过期（如 MaiTagsManager）；其它正整数 = 有效期天数。
/// - [groupKey] 把多个 UI 行映射到底层同一个缓存组（force refresh 时整组一起刷），
///   例如别名 3 源共享 song_aliases，收藏品 4 类共享 CollectionsManager.refreshAllCollections。
class CacheSourceInfo {
  final String id;
  final String displayName;
  final String description;
  final String apiUrl;
  final String cacheKey;
  final String timestampKey;
  final int ttlDays;
  final String groupKey;

  const CacheSourceInfo({
    required this.id,
    required this.displayName,
    required this.description,
    required this.apiUrl,
    required this.cacheKey,
    required this.timestampKey,
    required this.ttlDays,
    required this.groupKey,
  });
}

/// 全部缓存源注册表（13 条，按用户在「系统 → 刷新数据（高级）」看到的顺序）。
///
/// 多个源共享同一 [groupKey] 时，任意一个被勾选强制刷新即触发整组刷新：
///   - 'songs'         歌曲数据（水鱼 + Union 合并写入 cachedSongs）
///   - 'aliases'       别名 3 源合并写入 song_aliases
///   - 'collections'   收藏品 4 类各自独立缓存但由 CollectionsManager 一并刷新
class CacheSourceRegistry {
  static const List<CacheSourceInfo> all = [
    // ── 歌曲数据 ─────────────────────────────────────────────
    CacheSourceInfo(
      id: 'songs_water_fish',
      displayName: '歌曲数据（水鱼）',
      description: '全量歌曲主库（diving-fish）',
      apiUrl: ApiUrls.MusicDataApi,
      cacheKey: CacheKeyConstant.cachedSongs,
      timestampKey: CacheKeyConstant.cachedSongsTimestamp,
      ttlDays: 7,
      groupKey: 'songs',
    ),
    CacheSourceInfo(
      id: 'songs_union',
      displayName: '歌曲数据（Union）',
      description: '补充独有歌曲（godserver）',
      apiUrl: ApiUrls.UnionMusicDataApi,
      cacheKey: CacheKeyConstant.cachedSongs,
      timestampKey: CacheKeyConstant.cachedSongsTimestamp,
      ttlDays: 7,
      groupKey: 'songs',
    ),

    // ── 难度数据 ─────────────────────────────────────────────
    CacheSourceInfo(
      id: 'diff',
      displayName: '难度数据',
      description: '谱面定数（diving-fish chart_stats）',
      apiUrl: ApiUrls.DiffMusicDataApi,
      cacheKey: CacheKeyConstant.diffMusicData,
      timestampKey: CacheKeyConstant.diffMusicDataTimestamp,
      ttlDays: 7,
      groupKey: 'diff',
    ),

    // ── 标签数据 ─────────────────────────────────────────────
    CacheSourceInfo(
      id: 'tags',
      displayName: '标签数据',
      description: 'DXRating 谱面标签',
      apiUrl: ApiUrls.TagDataApi,
      cacheKey: CacheKeyConstant.maiTagsCache,
      timestampKey: CacheKeyConstant.maiTagsCacheTimestamp,
      ttlDays: -1, // MaiTagsManager 内部标记为永不过期
      groupKey: 'tags',
    ),

    // ── 别名 3 源 ────────────────────────────────────────────
    CacheSourceInfo(
      id: 'alias_yuzuchan',
      displayName: '别名数据源1',
      description: 'yuzuchan.moe',
      apiUrl: ApiUrls.SongAliasApi,
      cacheKey: 'song_aliases',
      timestampKey: 'alias_last_update',
      ttlDays: 7,
      groupKey: 'aliases',
    ),
    CacheSourceInfo(
      id: 'alias_dxrating',
      displayName: '别名数据源2',
      description: 'DXRating',
      apiUrl: ApiUrls.DXRatingSongAliasApi,
      cacheKey: 'song_aliases',
      timestampKey: 'alias_last_update',
      ttlDays: 7,
      groupKey: 'aliases',
    ),
    CacheSourceInfo(
      id: 'alias_maimaihub',
      displayName: '别名数据源3',
      description: 'MaimaiHub',
      apiUrl: ApiUrls.MaimaiHubMusicAliasesUrl,
      cacheKey: 'song_aliases',
      timestampKey: 'alias_last_update',
      ttlDays: 7,
      groupKey: 'aliases',
    ),

    // ── 收藏品 4 类 ──────────────────────────────────────────
    CacheSourceInfo(
      id: 'coll_trophies',
      displayName: '收藏品-称号',
      description: '落雪称号',
      apiUrl: ApiUrls.TrophiesCollectionApi,
      cacheKey: CacheKeyConstant.trophiesCollectionsCacheData,
      timestampKey: 'trophies_collections_last_update',
      ttlDays: 7,
      groupKey: 'collections',
    ),
    CacheSourceInfo(
      id: 'coll_icons',
      displayName: '收藏品-头像',
      description: '落雪头像',
      apiUrl: ApiUrls.IconsCollectionApi,
      cacheKey: CacheKeyConstant.iconsCollectionsCacheData,
      timestampKey: 'icons_collections_last_update',
      ttlDays: 7,
      groupKey: 'collections',
    ),
    CacheSourceInfo(
      id: 'coll_plates',
      displayName: '收藏品-姓名框',
      description: '落雪姓名框',
      apiUrl: ApiUrls.PlatesCollectionApi,
      cacheKey: CacheKeyConstant.platesCollectionsCacheData,
      timestampKey: 'plates_collections_last_update',
      ttlDays: 7,
      groupKey: 'collections',
    ),
    CacheSourceInfo(
      id: 'coll_frames',
      displayName: '收藏品-背景',
      description: '落雪背景',
      apiUrl: ApiUrls.FramesCollectionApi,
      cacheKey: CacheKeyConstant.framesCollectionsCacheData,
      timestampKey: 'frames_collections_last_update',
      ttlDays: 7,
      groupKey: 'collections',
    ),

    // ── Union 元数据 ─────────────────────────────────────
    CacheSourceInfo(
      id: 'union',
      displayName: 'Union 元数据',
      description: 'cn/jp 可游玩地区等',
      apiUrl: ApiUrls.UnionApi,
      cacheKey: CacheKeyConstant.unionCache,
      timestampKey: CacheKeyConstant.unionCacheTimestamp,
      ttlDays: 7,
      groupKey: 'union',
    ),

    // ── maidata（追加列表 + 完整 maidata；TTL 取追加列表的 15 天） ───
    CacheSourceInfo(
      id: 'maidata',
      displayName: 'maidata',
      description: '谱面追加辅助（追加列表 + 完整 maidata）',
      apiUrl: '${ApiUrls.MaidataServerBaseUrl}/maimai',
      cacheKey: CacheKeyConstant.maidataAddedSongs,
      timestampKey: CacheKeyConstant.maidataAddedSongsTimestamp,
      ttlDays: 15,
      groupKey: 'maidata',
    ),
  ];

  /// 按 [groupKey] 分组，便于 force refresh 时按组执行。
  static Map<String, List<CacheSourceInfo>> groupedByGroup() {
    final map = <String, List<CacheSourceInfo>>{};
    for (final s in all) {
      map.putIfAbsent(s.groupKey, () => []).add(s);
    }
    return map;
  }
}

/// 读取 [source] 对应缓存时间戳，并格式化为"剩余 X 天 Y 小时 / 已过期..."。
///
/// 返回格式：
///   - ttlDays == -1                       → "永不过期"
///   - 没有缓存                            → "无缓存"
///   - 有缓存但无时间戳                    → "无缓存时间戳"
///   - 在 TTL 内                           → "剩余 X 天 Y 小时"（按粒度截断到天/小时/分钟）
///   - 已过期                              → "已过期 X 天 Y 小时"
Future<String> formatRemainingValidity(CacheSourceInfo source) async {
  if (source.ttlDays == -1) return '永不过期';
  final prefs = await SharedPreferences.getInstance();
  final ts = prefs.getInt(source.timestampKey);
  if (ts == null) {
    final hasCache = prefs.getString(source.cacheKey) != null;
    return hasCache ? '无缓存时间戳' : '无缓存';
  }
  final now = DateTime.now().millisecondsSinceEpoch;
  final ttlMs = source.ttlDays * 24 * 60 * 60 * 1000;
  final remainingMs = ts + ttlMs - now;
  if (remainingMs <= 0) {
    return '已过期 ${_formatDurationShort(-remainingMs)}';
  }
  return '剩余 ${_formatDurationShort(remainingMs)}';
}

String _formatDurationShort(int ms) {
  final days = ms ~/ (24 * 60 * 60 * 1000);
  final hours = (ms % (24 * 60 * 60 * 1000)) ~/ (60 * 60 * 1000);
  final minutes = (ms % (60 * 60 * 1000)) ~/ (60 * 1000);
  if (days > 0) {
    return hours > 0 ? '$days 天 $hours 小时' : '$days 天';
  }
  if (hours > 0) {
    return minutes > 0 ? '$hours 小时 $minutes 分钟' : '$hours 小时';
  }
  return '$minutes 分钟';
}