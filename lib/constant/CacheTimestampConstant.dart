/// 缓存过期时间常量统一管理
class CacheTimestampConstant {
  // 单位：天
  static const int knowledgeCacheDays = 1;
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
}