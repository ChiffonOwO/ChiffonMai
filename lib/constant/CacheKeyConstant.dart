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
  
  // 落雪OAuth相关
  static const String luoxueAccessToken = 'luoxue_access_token';
  static const String luoxueRefreshToken = 'luoxue_refresh_token';
  static const String luoxueExpiresAt = 'luoxue_expires_at';
  static const String luoxueTokenType = 'luoxue_token_type';
  
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
  
  // 舞萌CN探针相关
  static const String maimaiCNUserId = 'maimai_cn_user_id';
  static const String maimaiCNT = 'maimai_cn_t';
  
  // 难度数据相关
  static const String diffMusicData = 'diff_music_data';
  
  // 推荐结果相关
  static const String recommendationResults = 'recommendation_results';
  
  // 谱面数据缓存前缀
  static const String maidataCachePrefix = 'maidata_cache_';

  // 猜歌游戏设置相关
  static const String guessChartSelectedVersions = 'guessChart_selectedVersions';
  static const String guessChartMasterMinDx = 'guessChart_masterMinDx';
  static const String guessChartMasterMaxDx = 'guessChart_masterMaxDx';
  static const String guessChartSelectedGenres = 'guessChart_selectedGenres';
  static const String guessChartMaxGuesses = 'guessChart_maxGuesses';
  static const String guessChartTimeLimit = 'guessChart_timeLimit';
  static const String guessChartBlurLevel = 'guessChart_blurLevel';
  static const String guessChartSongCount = 'guessChart_songCount';
  static const String guessChartNonEnglishCharThreshold = 'guessChart_nonEnglishCharThreshold';
  
  // KaleidXScope 标记歌曲相关
  static const String kaleidXBlackGateMarkedSongs = 'kaleidx_black_gate_marked_songs';
  static const String kaleidXBlueGateMarkedSongs = 'kaleidx_blue_gate_marked_songs';
  static const String kaleidXYellowGateMarkedSongs = 'kaleidx_yellow_gate_marked_songs';
  
  // 上次更新使用的数据源
  static const String lastDataSource = 'last_data_source';
  
  // 排行榜相关设置
  static const String participateRankings = 'participate_rankings';
  static const String showNickname = 'show_nickname';
  
  // 排行榜缓存相关
  static const String totalRankingsCache = 'total_rankings_cache';
  static const String totalRankingsCacheTimestamp = 'total_rankings_cache_timestamp';
  static const String shuiyuRankingsCache = 'shuiyu_rankings_cache';
  static const String shuiyuRankingsCacheTimestamp = 'shuiyu_rankings_cache_timestamp';
  static const String luoxueRankingsCache = 'luoxue_rankings_cache';
  static const String luoxueRankingsCacheTimestamp = 'luoxue_rankings_cache_timestamp';
  
  // 免责声明相关
  static const String songRankingDisclaimerShown = 'song_ranking_disclaimer_shown';

  // 歌曲评论缓存相关
  static const String songCommentsCachePrefix = 'song_comments_cache_';
  static const String songCommentsCacheTimestampPrefix = 'song_comments_cache_timestamp_';

  // 评论身份相关
  static const String commentDataSource = 'comment_data_source';
  static const String commentOriginalId = 'comment_original_id';
  static const String commentNickname = 'comment_nickname';

  // 用户身份相关（与HomePage共用，用于自动构建评论身份）
  static const String userNickname = 'userNickname';
  static const String cachedQQ = 'cachedQQ';
  static const String luoxueUserId = 'luoxue_user_id';
  static const String shuiyuUserId = 'shuiyu_user_id';

  // 首页后台初始化时间戳（用于控制初始化频率）
  static const String lastInitializationTimestamp = 'last_initialization_timestamp';

  // 曲绘识别相关
  static const String coverHashCache = 'cover_hash_cache_v5';
  static const String coverHashCacheTimestamp = 'cover_hash_cache_timestamp_v5';

  // 主题设置
  static const String themeMode = 'theme_mode';

  // Maimai Score Hub 探针同步相关
  static const String probeAuthToken = 'probe_auth_token';
  static const String probeFriendCode = 'probe_friend_code';
  static const String probeLastSyncTime = 'probe_last_sync_time';
  static const String probeDivingFishToken = 'probe_diving_fish_token';
  static const String probeDivingFishImportToken = 'probe_diving_fish_import_token';
  static const String probeDivingFishBindQQ = 'probe_diving_fish_bind_qq';
}