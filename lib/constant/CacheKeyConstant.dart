/// 缓存键常量统一管理
class CacheKeyConstant {
  // 音乐数据相关
  static const String cachedSongs = 'cached_songs';
  
  // Maidata相关
  static const String maidataFullCache = 'maidata_full_cache';
  static const String maidataFullCacheTimestamp = 'maidata_full_cache_timestamp';
  static const String maidataAddedSongs = 'maidata_added_songs';
  static const String maidataAddedSongsTimestamp = 'maidata_added_songs_timestamp';
  
  // 知识数据相关
  static const String knowledgeData = 'knowledge_data';
  static const String knowledgeTimestamp = 'knowledge_timestamp';
  
  // 落雪歌曲相关
  static const String luoxueSongsCache = 'luoxue_songs_cache';
  
  // 收藏数据相关
  static const String trophiesCollectionsCacheData = 'trophies_collections_cache_data';
  static const String iconsCollectionsCacheData = 'icons_collections_cache_data';
  static const String platesCollectionsCacheData = 'plates_collections_cache_data';
  static const String framesCollectionsCacheData = 'frames_collections_cache_data';
  
  // 标签数据相关
  static const String maiTagsCache = 'mai_tags_cache';
  static const String maiTagsCacheTimestamp = 'mai_tags_cache_timestamp';
  
  // 用户数据相关
  static const String userPlayData = 'user_play_data';
  
  // 难度数据相关
  static const String diffMusicData = 'diff_music_data';
  
  // 推荐结果相关
  static const String recommendationResults = 'recommendation_results';
  
  // 谱面数据缓存前缀
  static const String maidataCachePrefix = 'maidata_cache_';
}