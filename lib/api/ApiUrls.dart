// ignore_for_file: constant_identifier_names

class ApiUrls {
  // ── 后端 OAuth 代理 ────────────────────────────────────────────────────
  // 水鱼成绩读取走本后端 /api/prober（后端持有 client_secret 换票并代理），
  // 其余第三方数据源 App 直连。
  static const String BackendBaseUrl = 'https://chiffonmai.cloud';
  static const String ProberBaseUrl = '$BackendBaseUrl/api/prober';

  /// 同步耗时统计代理。Redis 凭据只保留在服务端，App 不再直连 Redis。
  static const String SyncStatsUrl = '$BackendBaseUrl/api/sync-stats';
  static const String LoadingTipsUrl = '$BackendBaseUrl/api/loading-tips';
  static const String FriendLinksUrl = '$BackendBaseUrl/api/friend-links';
  static const String TranslationUrl = '$BackendBaseUrl/api/translate';

  /// App ↔ 后端 OAuth 代理的 API key（与 server 端环境变量 GATEWAY_API_KEY 保持一致）
  /// 只从构建参数注入，源码与默认 APK 不再携带共享密钥。
  static const String ProberApiKey =
      String.fromEnvironment('PROBER_API_KEY', defaultValue: '');

  // ── 水鱼查分器数据（直连） ─────────────────────────────────────────────
  static const String DiffMusicDataApi =
      'https://www.diving-fish.com/api/maimaidxprober/chart_stats';
  static const String MusicDataApi =
      'https://www.diving-fish.com/api/maimaidxprober/music_data';

  /// 更全的歌曲数据API端点（union），作为全量歌曲数据的主要来源
  static const String UnionMusicDataApi =
      'https://union.godserver.cn//api/union/musics';

  /// union 歌曲元数据（含 cn/jp 可游玩地区、releaseDate 等）
  static const String UnionApi = 'https://union.godserver.cn//api/union/uni';
  static const String TagDataApi = 'https://miruku.dxrating.net/api/v1/tags';
  static const String SongAliasApi =
      'https://www.yuzuchan.moe/api/maimaidx/maimaidxalias';
  static const String DXRatingSongAliasApi =
      'https://miruku.dxrating.net/api/v1/aliases';

  /// dxrating 全量数据（曲库/标签/别名/谱面定数等，直连）
  static const String DXDataApi = 'https://miruku.dxrating.net/api/v1/dxdata';

  /// 用户完整游玩数据（经 OAuth 代理）
  static const String UserPlayDataApi = '$ProberBaseUrl/records';

  // ── 落雪（直连） ───────────────────────────────────────────────────────
  static const String TrophiesCollectionApi =
      'https://maimai.lxns.net/api/v0/maimai/trophy/list';
  static const String IconsCollectionApi =
      'https://maimai.lxns.net/api/v0/maimai/icon/list';
  static const String PlatesCollectionApi =
      'https://maimai.lxns.net/api/v0/maimai/plate/list';
  static const String FramesCollectionApi =
      'https://maimai.lxns.net/api/v0/maimai/frame/list';
  static const String LuoXueSongsApi =
      'https://maimai.lxns.net/api/v0/maimai/song/list';

  // ── AWMC NET. 查分器（直连） ───────────────────────────────────────────
  // 官网 https://net.wmc.pub/ ，API 文档 https://net.wmc.pub/docs
  //
  // ⚠️ 与「AWMC 网关」是两个不同的服务，别搞混：
  //   * api.wmc.pub —— 机台账号网关；App 通过服务端代理访问，开发者令牌不下发客户端；
  //   * net.wmc.pub —— 第三方**查分器**；开发者密钥由服务端按 QQ **只读**代理查成绩（本段）。
  static const String AwmcNetBaseUrl = 'https://net.wmc.pub';

  /// 设置页：成绩导入 Token 的生成入口。
  ///
  /// 路径是 `/settings/`（**不是** `/settings`，带尾斜杠），页面**最底部**才是
  /// 「生成/轮换Token」按钮 —— 文案里必须写清"滑到底部"，否则用户在上面找不到。
  static const String AwmcNetSettingsUrl = '$AwmcNetBaseUrl/settings/';

  /// 全量成绩（返回结构与水鱼 `/player/records` **逐字段一致**）。
  ///
  /// 鉴权：由自家服务端注入 `Developer-Token`，客户端只提交 QQ。
  /// 查询：`?qq=488581724` 或 `?username=ChiffonOwO`（二选一；都没有 → 400 `需要 username 或 qq`）。
  ///
  /// 返回 `{username, nickname, rating, plate, additional_rating, records:[...]}`，
  /// records 每项含 `song_id / title / type / level_index / level_label / level /
  /// ds / achievements / rate / fc / fs / dxScore / ra / is_new` —— 与水鱼完全对齐，
  /// 因此可以直接喂给现有的 `RecordItem.fromJson` 与 `UserBest50Manager` 流程。
  /// （实测：按现有 Best50 算法取 old-top35 + new-top15 求得的和，
  ///  与接口自身的 `old_rating + new_rating` 完全一致。）
  static const String AwmcNetRecordsApi = '$AwmcNetBaseUrl/dev/player/records';

  /// AWMC NET 开发者查询代理；Developer-Token 只保存在服务端。
  static const String AwmcNetRecordsProxyApi =
      '$BackendBaseUrl/api/awmc-net/records';

  /// 曲库（水鱼 `music_data` 兼容格式）。App 用自家曲库缓存，留作备用。
  static const String AwmcNetMusicDataApi = '$AwmcNetBaseUrl/api/music_data';

  /// 成绩导入（机台二维码）。
  ///
  /// 认证：请求头 `Import-Token: <用户自己的成绩导入Token>`。
  /// **项目自带的 bot+developer 密钥在这里无效**（实测 401「程序上传需要提供 Import-Token」），
  /// 所以要用户去 [AwmcNetSettingsUrl] 底部点「生成/轮换Token」自己生成一个。
  ///
  /// 请求：`multipart/form-data`，两个字段**二选一**：
  ///   * `sgwcmaid` —— `SGWCMAID` 开头的机台登入二维码字符串（App 现有扫码流程就能拿到）；
  ///   * `file`     —— 二维码**图片**（实测错误文案是「需要提供 sgwcmaid 或二维码图片」）。
  ///
  /// ⚠️ **同步阻塞、实测约 36 秒**（对方要登机台把整套成绩拉一遍）。
  /// 调用方**必须显式给长超时**（见 `AwmcNetScoreUploadService.timeout`），
  /// 否则 `ApiClient` 默认的 15s 会把一次成功的导入判成超时。
  static const String AwmcNetScoreQrApi = '$AwmcNetBaseUrl/api/score/qr';

  /// 玩家 Rating 趋势（每日一条曲线点）。
  ///
  /// 公开端点，**不需要鉴权** —— 跟 `/dev/player/records` 不同，
  /// 这个端点只要 QQ 就行；它只暴露**该玩家自己**在 AWMC NET 上报过的 Rating 历史，
  /// 不暴露别人的成绩。`days` 范围 1~365，默认 30；超过 365 服务端会 422。
  ///
  /// 响应里 `date` 是 `"YYYY-MM-DD"`（**不带时区**，按本地 0 点处理），
  /// 所以页面曲线会和「今日 0 点」对齐。
  static const String AwmcNetTrendBaseUrl = 'https://net.wmc.pub';
  static String awmcPlayerTrendUrl(String qqid, {int days = 90}) =>
      '$AwmcNetTrendBaseUrl/api/player/$qqid/trend?days=$days';

  // ── 服务器状态 / 街机厅（直连） ────────────────────────────────────────
  static const String ServerStatusApi = 'https://mai.chongxi.us/api/bot';
  static const String ServerStatusTitleApi = 'https://mai.chongxi.us/api/bot';
  static const String NearCadeShopsApi = 'https://nearcade.cn/api/shops';
  static const String NearCadeRegionsApi = 'https://nearcade.cn/api/regions';

  // ── 水鱼登录 / ImportToken（直连，涉及 Cookie 会话，不经网关） ─────────
  static const String DivingFishLoginApi =
      'https://www.diving-fish.com/api/maimaidxprober/login';
  static const String DivingFishProfileApi =
      'https://www.diving-fish.com/api/maimaidxprober/player/profile';
  static const String DivingFishImportTokenApi =
      'https://www.diving-fish.com/api/maimaidxprober/player/import_token';

  /// 水鱼查分器官网主页。
  ///
  /// 用途：引导用户去填「绑定 QQ 号」—— App 需要这个 QQ 才能识别水鱼账号
  /// （`subject_ref = sha256(client_id:qq)`），而它**只能**从 `/player/profile`
  /// 读出来（那个端点只接受登录验证，OAuth 的 `/oauth/userinfo` 不返回 QQ）。
  /// 用户在这里登录后，进「编辑个人资料」即可填写。
  static const String DivingFishProberHomeUrl =
      'https://www.diving-fish.com/maimaidx/prober/';

  /// 更新用户成绩信息（批量端点，同时处理新增与更新）。
  ///
  /// 请求体是 JSON **List**，每项形如：
  /// ```json
  /// {"title": "曲名", "type": "DX", "level_index": 3,
  ///  "achievements": 100.5, "fc": "ap", "fs": "fsd", "dxScore": 2575}
  /// ```
  /// 认证：`Import-Token` 头（或 jwt_token cookie / Bearer）。
  ///
  /// 注意**不要**用 `/player/update_record`（单曲端点）：它内部对
  /// `NewRecord.aio_get()` 的结果有 `assert r`，记录不存在时会抛
  /// AssertionError，只能改已有成绩、无法新增。见水鱼查分器源码
  /// `database/routes/maimai.py`。
  static const String DivingFishUpdateRecordsApi =
      'https://www.diving-fish.com/api/maimaidxprober/player/update_records';

  // ── 更新检查（自家后端，直连） ────────────────────────────────────────
  static const String checkUpdateApi =
      'https://chiffonmai.cloud/app_version.json';

  // 多人游戏服务器地址
  static const String MultiplayerServerUrl = 'wss://chiffonmai.cloud';
  static const String MultiplayerGameServerUrl = 'wss://chiffonmai.cloud';

  // Maidata 服务器地址
  static const String MaidataServerBaseUrl = 'https://chiffonmai.cloud';
  static const String MaidataServerPortUrl = 'https://chiffonmai.cloud';

  // 单曲 maidata 兜底（wmc.pub）
  //
  // 全量 / 单曲本地缓存都没命中时，最后一道兜底：直接按 songId 拉这家的 maidata.txt。
  // 请求结果先由 MaidataManager 做进程级复用，歌曲详情页还会写入单曲缓存，
  // 避免用户反复进入同一首歌曲时重复请求。
  static const String WmcMaidataFallbackBaseUrl = 'https://download.wmc.pub';
  static String wmcMaidataUrl(String songId) =>
      '$WmcMaidataFallbackBaseUrl/s/$songId/maidata.txt';

  /// 单曲音源兜底（wmc.pub）
  ///
  /// 落雪 (`assets2.lxns.net`) 查不到 luoXue song id 时退到这里，
  /// 直接按 maimai songId 拼 `track.mp3`。
  ///
  /// ⚠️ **故意不加进系统中心「maidata 管理」**：音源不像 maidata 那样能
  /// 批量缓存，进程级一次性下载、播完就丢；用户没要求管理入口。
  static String wmcAudioUrl(String songId) =>
      '$WmcMaidataFallbackBaseUrl/s/$songId/track.mp3';

  // 落雪 OAuth 相关地址（落雪自有 OAuth，经网关前先保持直连）
  static const String LuoXueBaseUrl = 'https://maimai.lxns.net';
  static const String LuoXueApiBaseUrl = 'https://maimai.lxns.net/api/v0';
  static const String LuoXueOAuthTokenUrl =
      'https://maimai.lxns.net/api/v0/oauth/token';

  /// 落雪 OAuth 换票代理；client_secret 只留在服务端环境变量，不进入 APK。
  static const String LuoXueOAuthProxyTokenUrl =
      '$BackendBaseUrl/api/luoxue/oauth/token';
  static const String LuoXueOAuthAuthorizeUrl =
      'https://maimai.lxns.net/oauth/authorize';

  // 落雪玩家数据 API（需要落雪 OAuth token，经网关前先保持直连）
  static const String LuoXuePlayerApi =
      'https://maimai.lxns.net/api/v0/user/maimai/player';
  static const String LuoXuePlayerScoresApi =
      'https://maimai.lxns.net/api/v0/user/maimai/player/scores';

  // 排行榜 API 地址（自家后端）
  static const String RankingsBaseUrl = 'https://chiffonmai.cloud/api/rankings';
  static const String SpecialRankingsUrl =
      'https://chiffonmai.cloud/api/special-rankings';
  static const String RankingsUpdateUrl = '$RankingsBaseUrl/update';

  // 单曲排行榜 API 地址（达成率/DX分数）（自家后端）
  static const String SongRankingsBaseUrl =
      'https://chiffonmai.cloud/api/song-rankings';
  static const String SongRankingsBulkUpdateUrl =
      '$SongRankingsBaseUrl/bulk-update';

  /// 某玩家已存储的全部单曲成绩（新增接口，服务端需实现）
  /// GET /api/song-rankings/player/{playerId} -> { success, data: [...] }
  static const String SongRankingsPlayerUrl = '$SongRankingsBaseUrl/player';

  /// 玩家全量成绩的平均值排行榜（平均达成率 / 平均DX得分达成率）
  /// GET /api/song-rankings/averages -> { success, data: [{ playerId, playerName,
  /// dataSource, avgAchievement, avgDxAchievement, achievementCount, dxCount, updateTime }] }
  static const String SongRankingsAveragesUrl = '$SongRankingsBaseUrl/averages';

  /// 拟合总Rating排行榜（服务端拉取最新 chart_stats 并按 A/B/C 模式计算）
  /// GET /api/song-rankings/fitted-ranking?mode=a|b|c&userId=... -> { success, data: [...], total, currentUser }
  static const String SongRankingsFittedUrl =
      '$SongRankingsBaseUrl/fitted-ranking';

  // 万花镜 API 地址（自家后端）
  static const String KaleidXScopeBaseUrl =
      'https://chiffonmai.cloud/api/kaleidxscope';

  // 歌曲评论 API 地址（自家后端）
  static const String CommentsBaseUrl = 'https://chiffonmai.cloud/api/comments';
  static const String CommentsBySongUrl = '$CommentsBaseUrl/song';
  static const String CommentsByUserUrl = '$CommentsBaseUrl/user';
  static const String CommentsCreateUrl = '$CommentsBaseUrl/create';
  static const String CommentsClearCacheUrl = '$CommentsBaseUrl/clear-cache';
  static const String CommentsRecentUrl = '$CommentsBaseUrl/recent';

  // B站播放量 Redis 缓存 API（自家后端）
  static const String BiliRedisBaseUrl =
      'https://chiffonmai.cloud/api/bilibili';
  static const String BiliRedisSaveUrl = '$BiliRedisBaseUrl/play-count';
  static const String BiliRedisGetUrl = '$BiliRedisBaseUrl/play-count';
  static const String BiliRedisUploadBvUrl = '$BiliRedisBaseUrl/upload-bv';
  static const String BiliValidateBvUrl = '$BiliRedisBaseUrl/validate-bv';
  static const String RefDurationGetUrl =
      '$BiliRedisBaseUrl/reference-duration';
  static const String RefDurationSaveUrl =
      '$BiliRedisBaseUrl/reference-duration';

  // 谱面评分 API 地址（自家后端）
  static const String RatingsBaseUrl = 'https://chiffonmai.cloud/api/ratings';

  // 注：自家后端的成绩截图 OCR（POST /api/ocr/score，转发百度/腾讯）已废弃，
  // 识别改走 maimai Score Hub 的专用模型，见 MaimaiHubOcrRecognizeUrl。

  // maimai Score Hub API 地址（QR码查分 → 同步水鱼）（第三方，有独立鉴权，保持直连）
  // 基于 assets/maimai-score-hub-api.yaml (v1.0.0)
  static const String MaimaiHubBaseUrl = 'https://maimai.bakapiano.com/api/v1';

  // ── Auth 认证 ──
  static const String MaimaiHubLoginByQrUrl = '$MaimaiHubBaseUrl/auth/qr-login';
  static const String MaimaiHubLoginRequestsUrl =
      '$MaimaiHubBaseUrl/auth/login-requests';
  static const String MaimaiHubPasswordLoginUrl =
      '$MaimaiHubBaseUrl/auth/password-login';

  // ── Users / 个人中心 ──
  static const String MaimaiHubProfileUrl = '$MaimaiHubBaseUrl/me';
  static const String MaimaiHubPasswordUrl = '$MaimaiHubBaseUrl/me/password';
  static const String MaimaiHubDivingFishTokenUrl =
      '$MaimaiHubBaseUrl/me/prober-tokens/diving-fish';
  static const String MaimaiHubCabinetUrl = '$MaimaiHubBaseUrl/me/cabinet';

  // ── Sync / 成绩同步 ──
  static const String MaimaiHubSyncLatestUrl =
      '$MaimaiHubBaseUrl/me/sync/latest';
  static const String MaimaiHubSyncDivingFishUrl =
      '$MaimaiHubBaseUrl/me/sync/latest/exports/diving-fish';
  static const String MaimaiHubSyncLxnsUrl =
      '$MaimaiHubBaseUrl/me/sync/latest/exports/lxns';
  static const String MaimaiHubSyncExportJobsUrl =
      '$MaimaiHubBaseUrl/me/sync/prober-export-jobs';

  // ── Cabinet Score Jobs / 机台QR直同步 ──
  static const String MaimaiHubCabinetScoreJobsUrl =
      '$MaimaiHubBaseUrl/me/cabinet-score-jobs';
  static const String MaimaiHubCabinetScoreJobsActiveUrl =
      '$MaimaiHubBaseUrl/me/cabinet-score-jobs/active';

  // ── DXNet Jobs / 抓取任务 ──
  static const String MaimaiHubDxnetJobsUrl = '$MaimaiHubBaseUrl/me/dxnet-jobs';
  static const String MaimaiHubDxnetActiveJobUrl =
      '$MaimaiHubBaseUrl/me/dxnet-jobs/active';
  static const String MaimaiHubDxnetFriendshipUrl =
      '$MaimaiHubBaseUrl/me/dxnet-jobs/friendship';

  // ── Score Exports / 成绩导出 ──
  static const String MaimaiHubScoreExportsBest50Url =
      '$MaimaiHubBaseUrl/me/score-exports/best50';
  static const String MaimaiHubScoreExportsLevelUrl =
      '$MaimaiHubBaseUrl/me/score-exports/level';
  static const String MaimaiHubScoreExportsVersionUrl =
      '$MaimaiHubBaseUrl/me/score-exports/version';

  // ── Catalog / 曲目目录与别名 ──
  /// 曲目目录：`[{ id, title, ... }]`。用来把别名接口的 musicId 映射成曲名。
  static const String MaimaiHubMusicCatalogUrl =
      '$MaimaiHubBaseUrl/catalog/music';

  /// 曲目别名：`{ revision, aliases: [{ musicId, aliases: [...] }] }`
  static const String MaimaiHubMusicAliasesUrl =
      '$MaimaiHubBaseUrl/catalog/music/aliases';

  // ── OCR / 结算画面识别 ──
  // maimai Score Hub 的 OCR 是独立 FastAPI 服务（仓库 ocr-api/），只监听 127.0.0.1:19100，
  // **App 无法直连**，必须经 backend 的 /me/ocr/recognize 代理，用 maimai Score Hub 用户 token 鉴权。
  //
  // 注意：这条路径**不在 maimaihubapi.yaml 里**——ts-rest 代码生成不覆盖 multipart 接口，
  // 所以 spec 里搜不到 ocr，但接口是真实存在的（无 token 时返回 401 "Missing bearer token"）。
  //
  /// 结算画面识别：multipart/form-data，字段名 `images`（可重复，1..20 张，单张 ≤8MiB）
  static const String MaimaiHubOcrRecognizeUrl =
      '$MaimaiHubBaseUrl/me/ocr/recognize';

  /// 确认后的成绩更新：`{ scores: [{ musicId, chartIndex, achievement, dxScore, fc, fs }] }`，单次 ≤500
  static const String MaimaiHubSyncScoresUrl =
      '$MaimaiHubBaseUrl/me/sync/scores';

  // ── App / 状态 ──
  static const String MaimaiHubHealthUrl = '$MaimaiHubBaseUrl/health';
  static const String MaimaiHubStatisticsUrl = '$MaimaiHubBaseUrl/statistics';
  static const String RatingsByChartUrl = '$RatingsBaseUrl/chart';
  static const String RatingsCreateUrl = '$RatingsBaseUrl/create';
  static const String RatingsDeleteUrl = RatingsBaseUrl;
  static const String RatingsRecentUrl = '$RatingsBaseUrl/recent';
}
