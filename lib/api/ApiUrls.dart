// ignore_for_file: constant_identifier_names

class ApiUrls {
  // ── 后端 OAuth 代理 ────────────────────────────────────────────────────
  // 水鱼成绩读取走本后端 /api/prober（后端持有 client_secret 换票并代理），
  // 其余第三方数据源 App 直连。
  static const String BackendBaseUrl = 'http://chiffonmai.cloud:3000';
  static const String ProberBaseUrl = '$BackendBaseUrl/api/prober';

  /// App ↔ 后端 OAuth 代理的 API key（与 server 端环境变量 GATEWAY_API_KEY 保持一致）
  static const String ProberApiKey = 'chiffonmaiowo';

  // ── 水鱼查分器数据（直连） ─────────────────────────────────────────────
  static const String DiffMusicDataApi = 'https://www.diving-fish.com/api/maimaidxprober/chart_stats';
  static const String MusicDataApi = 'https://www.diving-fish.com/api/maimaidxprober/music_data';
  /// 更全的歌曲数据API端点（union），作为全量歌曲数据的主要来源
  static const String UnionMusicDataApi = 'https://union.godserver.cn//api/union/musics';
  /// union 歌曲元数据（含 cn/jp 可游玩地区、releaseDate 等）
  static const String UnionUniApi = 'https://union.godserver.cn//api/union/uni';
  static const String TagDataApi = 'https://miruku.dxrating.net/api/v1/tags';
  static const String SongAliasApi = 'https://www.yuzuchan.moe/api/maimaidx/maimaidxalias';
  static const String DXRatingSongAliasApi = 'https://miruku.dxrating.net/api/v1/aliases';
  /// 用户完整游玩数据（经 OAuth 代理）
  static const String UserPlayDataApi = '$ProberBaseUrl/records';

  // ── 落雪（直连） ───────────────────────────────────────────────────────
  static const String TrophiesCollectionApi = 'https://maimai.lxns.net/api/v0/maimai/trophy/list';
  static const String IconsCollectionApi = 'https://maimai.lxns.net/api/v0/maimai/icon/list';
  static const String PlatesCollectionApi = 'https://maimai.lxns.net/api/v0/maimai/plate/list';
  static const String FramesCollectionApi = 'https://maimai.lxns.net/api/v0/maimai/frame/list';
  static const String LuoXueSongsApi = 'https://maimai.lxns.net/api/v0/maimai/song/list';

  // ── 服务器状态 / 街机厅（直连） ────────────────────────────────────────
  static const String ServerStatusApi = 'https://status.awmc.cc/api/status-page/heartbeat/maimai';
  static const String ServerStatusTitleApi = 'https://status.awmc.cc/api/status-page/maimai';
  static const String NearCadeShopsApi = 'https://nearcade.cn/api/shops';
  static const String NearCadeRegionsApi = 'https://nearcade.cn/api/regions';

  // ── 水鱼登录 / ImportToken（直连，涉及 Cookie 会话，不经网关） ─────────
  static const String DivingFishLoginApi = 'https://www.diving-fish.com/api/maimaidxprober/login';
  static const String DivingFishProfileApi = 'https://www.diving-fish.com/api/maimaidxprober/player/profile';
  static const String DivingFishImportTokenApi = 'https://www.diving-fish.com/api/maimaidxprober/player/import_token';

  // ── 更新检查 / 知识库（自家后端，直连） ───────────────────────────────
  static const String checkUpdateApi = 'https://chiffonmai.cloud/app_version.json';
  static const String knowledgeApi = 'http://chiffonmai.cloud:3000/api/knowledge';

  // 多人游戏服务器地址
  static const String MultiplayerServerUrl = 'ws://chiffonmai.cloud:3000';
  static const String MultiplayerGameServerUrl = 'ws://chiffonmai.cloud:3000';

  // Maidata 服务器地址
  static const String MaidataServerBaseUrl = 'https://chiffonmai.cloud';
  static const String MaidataServerPortUrl = 'https://chiffonmai.cloud';

  // 落雪 OAuth 相关地址（落雪自有 OAuth，经网关前先保持直连）
  static const String LuoXueBaseUrl = 'https://maimai.lxns.net';
  static const String LuoXueApiBaseUrl = 'https://maimai.lxns.net/api/v0';
  static const String LuoXueOAuthTokenUrl = 'https://maimai.lxns.net/api/v0/oauth/token';
  static const String LuoXueOAuthAuthorizeUrl = 'https://maimai.lxns.net/oauth/authorize';

  // 落雪玩家数据 API（需要落雪 OAuth token，经网关前先保持直连）
  static const String LuoXuePlayerApi = 'https://maimai.lxns.net/api/v0/user/maimai/player';
  static const String LuoXuePlayerScoresApi = 'https://maimai.lxns.net/api/v0/user/maimai/player/scores';

  // 排行榜 API 地址（自家后端）
  static const String RankingsBaseUrl = 'http://chiffonmai.cloud:3000/api/rankings';
  static const String RankingsUpdateUrl = '$RankingsBaseUrl/update';

  // 单曲排行榜 API 地址（达成率/DX分数）（自家后端）
  static const String SongRankingsBaseUrl = 'http://chiffonmai.cloud:3000/api/song-rankings';

  // 万花镜 API 地址（自家后端）
  static const String KaleidXScopeBaseUrl = 'http://chiffonmai.cloud:3000/api/kaleidxscope';

  // 歌曲评论 API 地址（自家后端）
  static const String CommentsBaseUrl = 'http://chiffonmai.cloud:3000/api/comments';
  static const String CommentsBySongUrl = '$CommentsBaseUrl/song';
  static const String CommentsByUserUrl = '$CommentsBaseUrl/user';
  static const String CommentsCreateUrl = '$CommentsBaseUrl/create';
  static const String CommentsClearCacheUrl = '$CommentsBaseUrl/clear-cache';
  static const String CommentsRecentUrl = '$CommentsBaseUrl/recent';

  // B站播放量 Redis 缓存 API（自家后端）
  static const String BiliRedisBaseUrl = 'http://chiffonmai.cloud:3000/api/bilibili';
  static const String BiliRedisSaveUrl = '$BiliRedisBaseUrl/play-count';
  static const String BiliRedisGetUrl = '$BiliRedisBaseUrl/play-count';
  static const String BiliRedisUploadBvUrl = '$BiliRedisBaseUrl/upload-bv';
  static const String BiliValidateBvUrl = '$BiliRedisBaseUrl/validate-bv';
  static const String RefDurationGetUrl = '$BiliRedisBaseUrl/reference-duration';
  static const String RefDurationSaveUrl = '$BiliRedisBaseUrl/reference-duration';

  // 谱面评分 API 地址（自家后端）
  static const String RatingsBaseUrl = 'http://chiffonmai.cloud:3000/api/ratings';

  // Maimai Score Hub API 地址（QR码查分 → 同步水鱼）（第三方，有独立鉴权，保持直连）
  // 基于 assets/maimaihubapi.yaml (v1.0.0)
  static const String MaimaiHubBaseUrl = 'https://maimai.bakapiano.com/api/v1';

  // ── Auth 认证 ──
  static const String MaimaiHubLoginByQrUrl = '$MaimaiHubBaseUrl/auth/qr-login';
  static const String MaimaiHubLoginRequestsUrl = '$MaimaiHubBaseUrl/auth/login-requests';
  static const String MaimaiHubPasswordLoginUrl = '$MaimaiHubBaseUrl/auth/password-login';

  // ── Users / 个人中心 ──
  static const String MaimaiHubProfileUrl = '$MaimaiHubBaseUrl/me';
  static const String MaimaiHubPasswordUrl = '$MaimaiHubBaseUrl/me/password';
  static const String MaimaiHubDivingFishTokenUrl = '$MaimaiHubBaseUrl/me/prober-tokens/diving-fish';
  static const String MaimaiHubCabinetUrl = '$MaimaiHubBaseUrl/me/cabinet';

  // ── Sync / 成绩同步 ──
  static const String MaimaiHubSyncLatestUrl = '$MaimaiHubBaseUrl/me/sync/latest';
  static const String MaimaiHubSyncDivingFishUrl = '$MaimaiHubBaseUrl/me/sync/latest/exports/diving-fish';
  static const String MaimaiHubSyncLxnsUrl = '$MaimaiHubBaseUrl/me/sync/latest/exports/lxns';
  static const String MaimaiHubSyncExportJobsUrl = '$MaimaiHubBaseUrl/me/sync/prober-export-jobs';

  // ── Cabinet Score Jobs / 机台QR直同步 ──
  static const String MaimaiHubCabinetScoreJobsUrl = '$MaimaiHubBaseUrl/me/cabinet-score-jobs';
  static const String MaimaiHubCabinetScoreJobsActiveUrl = '$MaimaiHubBaseUrl/me/cabinet-score-jobs/active';

  // ── DXNet Jobs / 抓取任务 ──
  static const String MaimaiHubDxnetJobsUrl = '$MaimaiHubBaseUrl/me/dxnet-jobs';
  static const String MaimaiHubDxnetActiveJobUrl = '$MaimaiHubBaseUrl/me/dxnet-jobs/active';
  static const String MaimaiHubDxnetFriendshipUrl = '$MaimaiHubBaseUrl/me/dxnet-jobs/friendship';

  // ── Score Exports / 成绩导出 ──
  static const String MaimaiHubScoreExportsBest50Url = '$MaimaiHubBaseUrl/me/score-exports/best50';
  static const String MaimaiHubScoreExportsLevelUrl = '$MaimaiHubBaseUrl/me/score-exports/level';
  static const String MaimaiHubScoreExportsVersionUrl = '$MaimaiHubBaseUrl/me/score-exports/version';

  // ── App / 状态 ──
  static const String MaimaiHubHealthUrl = '$MaimaiHubBaseUrl/health';
  static const String MaimaiHubStatisticsUrl = '$MaimaiHubBaseUrl/statistics';
  static const String RatingsByChartUrl = '$RatingsBaseUrl/chart';
  static const String RatingsCreateUrl = '$RatingsBaseUrl/create';
  static const String RatingsDeleteUrl = RatingsBaseUrl;
  static const String RatingsRecentUrl = '$RatingsBaseUrl/recent';
}
