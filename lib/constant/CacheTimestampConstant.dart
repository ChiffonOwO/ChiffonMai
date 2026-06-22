/// 缓存过期时间常量统一管理
class CacheTimestampConstant {
  // 单位：分钟（-1表示永不过期）
  static const int rankingsCacheMinutes = -1;

  // 默认缓存时间（与首页初始化冷却周期一致，7天）
  static const int defaultCacheDays = 7;
  static const int defaultCacheMillis = defaultCacheDays * 24 * 60 * 60 * 1000;

  // 单位：天
  static const int knowledgeCacheDays = 7;
  static const int maidataFullCacheDays = 7;
  static const int maidataAddedSongsCacheDays = 15;
  static const int luoxueSongCacheDays = 30;
  static const int songMaidataCacheDays = 30;
  static const int maimaiServerStatusCacheDays = 3;
  
  // 单位：分钟
  static const int maimaiServerStatusCacheMinutes = 5;
  
  // 单位：毫秒
  static const int knowledgeCacheMillis = knowledgeCacheDays * 24 * 60 * 60 * 1000;
  static const int maidataFullCacheMillis = maidataFullCacheDays * 24 * 60 * 60 * 1000;
  static const int maidataAddedSongsCacheMillis = maidataAddedSongsCacheDays * 24 * 60 * 60 * 1000;
  static const int luoxueSongCacheMillis = luoxueSongCacheDays * 24 * 60 * 60 * 1000;
  static const int songMaidataCacheMillis = songMaidataCacheDays * 24 * 60 * 60 * 1000;
  
  // Duration 对象
  static const Duration maimaiServerStatusDuration = Duration(minutes: maimaiServerStatusCacheMinutes);
  static const Duration maimaiServerTitleDuration = Duration(days: maimaiServerStatusCacheDays);
  static const Duration luoxueSongDuration = Duration(days: luoxueSongCacheDays);
  
  // KaleidXScope 标记歌曲缓存时间（365天）
  static const int kaleidXMarkedSongsCacheDays = 365;
  static const int kaleidXMarkedSongsCacheMillis = kaleidXMarkedSongsCacheDays * 24 * 60 * 60 * 1000;
  static const Duration kaleidXMarkedSongsDuration = Duration(days: kaleidXMarkedSongsCacheDays);

  // 歌曲评论缓存时间（5分钟）
  static const int songCommentsCacheMinutes = 5;
  static const int songCommentsCacheSeconds = songCommentsCacheMinutes * 60;
}