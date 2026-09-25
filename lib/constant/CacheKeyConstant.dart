/// 缓存键常量统一管理
class CacheKeyConstant {
  // 音乐数据相关
  static const String cachedSongs = 'cached_songs';
  static const String cachedSongsTimestamp = 'cached_songs_timestamp';

  // Maidata相关
  static const String maidataFullCache = 'maidata_full_cache';
  static const String maidataFullCacheTimestamp =
      'maidata_full_cache_timestamp';
  static const String maidataAddedSongs = 'maidata_added_songs';
  static const String maidataAddedSongsTimestamp =
      'maidata_added_songs_timestamp';
  static const String maidataIndexCache = 'maidata_index_cache';
  static const String maidataIndexCacheTimestamp =
      'maidata_index_cache_timestamp';

  // Union API 独有歌曲（仅在新API中存在，不参与推荐系统）
  static const String unionExtraSongIds = 'union_extra_song_ids';
  // union 元数据缓存（含 cn/jp 可游玩地区等）
  static const String unionCache = 'union_cache';
  static const String unionCacheTimestamp = 'union_cache_timestamp';

  // 落雪歌曲相关
  static const String luoxueSongsCache = 'luoxue_songs_cache';

  // ===== 随身听相关 =====
  // 悬浮球位置（可拖动，记住用户摆的地方）
  static const String portableBallOffset = 'portable_ball_offset';
  // 是否已经申请过通知权限（首次进随身听页申请一次，不要每次进都弹）
  static const String portableNotificationAsked =
      'portable_notification_asked';

  // 落雪OAuth相关
  static const String luoxueAccessToken = 'luoxue_access_token';
  static const String luoxueRefreshToken = 'luoxue_refresh_token';
  static const String luoxueExpiresAt = 'luoxue_expires_at';
  static const String luoxueTokenType = 'luoxue_token_type';

  // 收藏的功能相关
  static const String favoriteFeatures = 'favorite_features';

  // 收藏数据相关
  static const String trophiesCollectionsCacheData =
      'trophies_collections_cache_data';
  static const String iconsCollectionsCacheData =
      'icons_collections_cache_data';
  static const String platesCollectionsCacheData =
      'plates_collections_cache_data';
  static const String framesCollectionsCacheData =
      'frames_collections_cache_data';

  // 标签数据相关
  static const String maiTagsCache = 'mai_tags_cache';
  static const String maiTagsCacheTimestamp = 'mai_tags_cache_timestamp';

  // 用户数据相关
  static const String userPlayData = 'user_play_data';

  // 自定义 Best50 手动录入数据（50 个固定卡位）
  static const String customBest50Data = 'custom_best50_data_v1';

  // ===== 三账号系统（水鱼 / 落雪 / AWMC NET 各一套缓存）=====
  // 账号元信息（昵称 / Rating / id / 是否有缓存），一个 JSON map
  static const String accountStore = 'account_store_v1';
  // 账号身份存档（昵称 / QQ / id / 评论身份 / 排行榜参与开关）：属于用户数据，进备份
  static const String accountArchiveIdentityPrefix = 'account_archive_identity_';
  // 账号成绩存档（游玩数据 / Best50 / 推荐结果）：可重新拉取，不进备份
  static const String accountArchivePlayPrefix = 'account_archive_play_';
  // 活动槽事务恢复日志（JSON；兼容旧版仅保存目标源 key 的标记），不进备份
  static const String accountRotationPending = 'account_rotation_pending';

  // 舞萌CN探针相关
  static const String maimaiCNUserId = 'maimai_cn_user_id';
  static const String maimaiCNT = 'maimai_cn_t';

  // 难度数据相关
  static const String diffMusicData = 'diff_music_data';
  static const String diffMusicDataTimestamp = 'diff_music_data_timestamp';

  // 推荐结果相关
  static const String recommendationResults = 'recommendation_results';

  // 谱面数据缓存前缀
  static const String maidataCachePrefix = 'maidata_cache_';

  // 猜歌游戏设置相关
  static const String guessChartSelectedVersions =
      'guessChart_selectedVersions';
  static const String guessChartMasterMinDx = 'guessChart_masterMinDx';
  static const String guessChartMasterMaxDx = 'guessChart_masterMaxDx';
  static const String guessChartSelectedGenres = 'guessChart_selectedGenres';
  static const String guessChartMaxGuesses = 'guessChart_maxGuesses';
  static const String guessChartTimeLimit = 'guessChart_timeLimit';
  static const String guessChartBlurLevel = 'guessChart_blurLevel';
  static const String guessChartSongCount = 'guessChart_songCount';
  static const String guessChartNonEnglishCharThreshold =
      'guessChart_nonEnglishCharThreshold';
  static const String guessChartFlashDuration = 'guessChart_flashDuration';
  static const String guessChartTileCount = 'guessChart_tileCount';
  static const String guessTileRevealInterval = 'guessTile_revealInterval';
  static const String guessChartPeekDuration = 'guessChart_peekDuration';
  static const String guessChartPeekDifficulties =
      'guessChart_peekDifficulties';
  // 歌曲片段猜歌的音频片段播放时长
  static const String guessChartPlayDuration = 'guessChart_playDuration';

  // KaleidXScope 标记歌曲相关
  static const String kaleidXBlackGateMarkedSongs =
      'kaleidx_black_gate_marked_songs';
  static const String kaleidXBlueGateMarkedSongs =
      'kaleidx_blue_gate_marked_songs';
  static const String kaleidXYellowGateMarkedSongs =
      'kaleidx_yellow_gate_marked_songs';
  static const String kaleidXRedGateMarkedSongs =
      'kaleidx_red_gate_marked_songs';

  // 上次更新使用的数据源
  static const String lastDataSource = 'last_data_source';

  // 排行榜相关设置
  static const String participateRankings = 'participate_rankings';
  static const String showNickname = 'show_nickname';
  static const String forceFullRefresh = 'force_full_refresh';

  // 高级刷新模式下用户上次勾选的强制刷新缓存源 ID 列表（来自 CacheSourceRegistry）
  static const String advancedRefreshForceSources =
      'advanced_refresh_force_sources';

  // 排行榜缓存相关
  static const String totalRankingsCache = 'total_rankings_cache';
  static const String totalRankingsCacheTimestamp =
      'total_rankings_cache_timestamp';
  static const String shuiyuRankingsCache = 'shuiyu_rankings_cache';
  static const String shuiyuRankingsCacheTimestamp =
      'shuiyu_rankings_cache_timestamp';
  static const String luoxueRankingsCache = 'luoxue_rankings_cache';
  static const String luoxueRankingsCacheTimestamp =
      'luoxue_rankings_cache_timestamp';
  // AWMC NET.（net.wmc.pub）总 Rating 榜
  static const String awmcRankingsCache = 'awmc_rankings_cache';
  static const String awmcRankingsCacheTimestamp =
      'awmc_rankings_cache_timestamp';

  // 平均值排行榜缓存相关（平均达成率 / 平均DX分数）
  static const String avgRankingsCache = 'avg_rankings_cache';
  static const String avgRankingsCacheTimestamp = 'avg_rankings_cache_timestamp';
  static const String avgRankingsLastMetric = 'avg_rankings_last_metric';

  // 拟合总Rating排行榜缓存相关（按模式拼接 key）
  static const String fittedRankingsCachePrefix = 'fitted_rankings_cache_';
  static const String fittedRankingsCacheTimestampPrefix =
      'fitted_rankings_cache_timestamp_';

  // 免责声明相关
  static const String songRankingDisclaimerShown =
      'song_ranking_disclaimer_shown';

  // 歌曲评论缓存相关
  static const String songCommentsCachePrefix = 'song_comments_cache_';
  static const String songCommentsCacheTimestampPrefix =
      'song_comments_cache_timestamp_';

  // 评论身份相关
  static const String commentDataSource = 'comment_data_source';
  static const String commentOriginalId = 'comment_original_id';
  static const String commentNickname = 'comment_nickname';

  // 用户身份相关（与HomePage共用，用于自动构建评论身份）
  static const String userNickname = 'userNickname';
  static const String cachedQQ = 'cachedQQ';
  static const String luoxueUserId = 'luoxue_user_id';
  static const String shuiyuUserId = 'shuiyu_user_id';

  // 用户当前选中的姓名框 ID（用于姓名框选择与导出图片显示）
  static const String selectedPlateIdCache = 'selected_plate_id_cache';

  // 首页后台初始化时间戳（用于控制初始化频率）
  static const String lastInitializationTimestamp =
      'last_initialization_timestamp';

  // 曲绘识别相关
  static const String coverHashCache = 'cover_hash_cache_v5';
  static const String coverHashCacheTimestamp = 'cover_hash_cache_timestamp_v5';

  // 主题设置
  static const String themeMode = 'theme_mode';
  static const String pureBlackEnabled = 'pure_black_enabled';
  static const String lightOverlayOpacity = 'light_overlay_opacity';
  // 自定义主题 seed 色（int, ARGB），null = 使用 AppTheme 默认
  static const String themeSeedColor = 'theme_seed_color';
  // 自定义背景图绝对路径（应用文档目录下），null/空 = 使用 assets/background.png
  static const String customBackgroundPath = 'custom_background_path';
  // chiffon2.png 装饰图透明度（0.0 ~ 1.0），默认 0.40
  static const String chiffonOpacity = 'chiffon_opacity';

  // 首页个人信息展示风格（true=卡片式，false=经典式）
  static const String profileCardStyle = 'profile_card_style';

  // ===== AWMC 网关（api.wmc.pub）相关 =====
  // 用户本机保存的网关令牌（gw_...）；空表示未设置。
  // 注意：机台 qrcode **不落盘**，只在一次会话的内存里保存。
  static const String awmcToken = 'awmc_token';
  // AWMC 调用审计日志（JSON 数组，不含 qrcode / 令牌 / 请求体）
  static const String awmcAuditLog = 'awmc_audit_log';
  // 游玩次数缓存（/v1/user/music 的 (musicId, level, playCount)）：
  // 属于可重新拉取的缓存，且与具体账号绑定，不进备份。
  //
  // ⚠️ **按数据源分开存**（`awmc_play_counts_v1_<source>`）：水鱼 / 落雪 / AWMC NET
  // 在账号系统里是三类**互不相干**的账号，机台游玩次数自然也各算各的 ——
  // 共用一个键的话，换到另一个账号后谱面详情与 PC50 会显示**上一个账号**的次数。
  /// 按源区分的游玩次数键前缀（后面接 `RefreshDataSource.key`）。
  static const String awmcPlayCountsPrefix = 'awmc_play_counts_v1_';

  /// 旧版的**共享**游玩次数键：只用于「首次读取时迁移到对应源」与备份排除，
  /// 任何地方都不要再往里写。
  static const String awmcPlayCountsLegacy = 'awmc_play_counts_v1';

  // ===== AWMC NET. 查分器（net.wmc.pub）=====
  // 按源区分的身份标记（`awmc:<QQ>`），与 shuiyuUserId / luoxueUserId 对等。
  // 作用见 AccountStore._resolveActiveId：共用的 cachedQQ 在异常路径下会被别的源串号。
  static const String awmcUserId = 'awmc_user_id';

  /// AWMC NET 的成绩导入 Token（用户在 net.wmc.pub 官网「个人资料」里生成）。
  ///
  /// 它**等同该账号的上传权限**，所以：日志、错误文案、审计记录里都不要回显它。
  /// 备份取舍上跟 `probeLxnsImportToken` 保持一致（不在 `_cacheExactKeys` 里，
  /// 会随备份一起导出/还原）。
  static const String awmcNetImportToken = 'awmc_net_import_token';

  // ===== 同步成绩的线路选择 =====
  // 0（或缺失）= 线路1 maimai Score Hub（原有 scorehub 流程），1 = 线路2 AWMC 网关
  static const String syncRouteDivingFish = 'sync_route_diving_fish';
  static const String syncRouteLuoXue = 'sync_route_luoxue';

  // Maimai Score Hub 探针同步相关
  static const String probeAuthToken = 'probe_auth_token';
  static const String probeFriendCode = 'probe_friend_code';
  static const String probeLastSyncTime = 'probe_last_sync_time';
  static const String probeDivingFishToken = 'probe_diving_fish_token';
  static const String probeDivingFishImportToken =
      'probe_diving_fish_import_token';
  static const String probeDivingFishBindQQ = 'probe_diving_fish_bind_qq';
  static const String probeLxnsImportToken = 'probe_lxns_import_token';
}
