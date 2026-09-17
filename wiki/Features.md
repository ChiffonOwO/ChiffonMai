# 功能速查表

> 本页汇总 ChiffonMai 的全部功能入口与简要说明，便于快速定位需要的功能。
> 所有入口均位于 `首页（HomePage）` 中，由 `lib/utils/FeatureRegistry.dart` 集中管理。

## 1. 曲库与数据

| 功能 | 文件 | 说明 |
| :--- | :--- | :--- |
| 乐曲查询 | `lib/page/SongSearchPage.dart` | 检索舞萌曲库，可按名称/曲师/别名/标签/定数筛选 |
| 成绩查询 | `lib/page/UserScoreSearchPage.dart` | 查看个人游玩数据与历史成绩 |
| 牌子进度 | `lib/page/PaiziProgressPage.dart` | 极/将/神/裏極等牌子达成情况，可导出长图 |
| 个性化成绩查询 | `lib/page/PersonalizedScorePage.dart` | 按等级 / 谱师定制查询 |
| 收藏品查询 | `lib/page/Collection/CollectionSearchPage.dart` | 名牌 / 称号 / 边框 / 曲绘 等收藏品 |
| 舞萌百科 | `lib/page/KnowledgeSearchPage.dart` | 舞萌术语 / 知识科普（错位、蛇等） |

## 2. Best50 与排行榜

| 功能 | 文件 | 说明 |
| :--- | :--- | :--- |
| Best50 查询 | `lib/page/Best50/Best50Page.dart` | 常规 Rating 前 50 |
| 拟合 Best50 查询 | `lib/page/Best50/DiffBest50Page.dart` | 拟合分析 |
| 个性化 Best50 查询 | `lib/page/Best50/PersonalizedBest50Page.dart` | 锁血 / AP / 按标签筛选 |
| 个性化拟合 Best50 查询 | `lib/page/Best50/PersonalizedDiffBest50Page.dart` | 个性化 + 定数差值 |
| 排行榜 | `lib/page/RankingList/RatingRankListPage.dart` | 总 Rating / 水鱼 / 落雪 |
| 特殊排行榜 | `lib/page/RankingList/SpecialRankingListPage.dart` | 绝赞数 / 物量 / 平均达成率 等 11 种 |

## 3. 猜歌游戏

| 功能 | 文件 | 说明 |
| :--- | :--- | :--- |
| 无提示猜歌 | `lib/page/GuessChartGame/GuessChartByInfoPage.dart` | 纯记忆挑战 |
| 部分曲绘猜歌 | `lib/page/GuessChartGame/GuessChartByCoverPage.dart` | 随机截取部分曲绘 |
| 模糊曲绘猜歌 | `lib/page/GuessChartGame/GuessChartByBlurredCoverPage.dart` | 模糊曲绘 |
| 歌曲片段猜歌 | `lib/page/GuessChartGame/GuessChartBySongExcerptPage.dart` | 听觉挑战 |
| 别名猜歌 | `lib/page/GuessChartGame/GuessChartByAliaPage.dart` | 别名提示 |
| 开字母猜歌 | `lib/page/GuessChartGame/GuessSongByOpenLettersPage.dart` | 逐字揭示 |
| 多人猜歌 | `lib/page/Multiplayer/MultiplayerLobbyPage.dart` | WebSocket 实时对战 |

## 4. 实用工具

| 功能 | 文件 | 说明 |
| :--- | :--- | :--- |
| 段位表 | `lib/page/RankTable/RankTablePage.dart` | 真代 / 里代等段位 |
| 基于标签推荐 | `lib/page/RecommendByTagsPage.dart` | 谱面标签匹配 |
| 基于目标 Rating 推荐 | `lib/page/RatingRecommendPage.dart` | 上分推荐 |
| 基于定数区间推荐 | `lib/page/DsRangeRecommendPage.dart` | 定数筛选 |
| 随机乐曲 | `lib/page/RandomChartPage.dart` | 随机 1~4 首 |
| 单曲 Rating 计算 | `lib/page/SingleRatingCalculatorPage.dart` | 单曲 Rating 精算 |
| 达成率计算 | `lib/page/AchievementRateCalculatorPage.dart` | 由判定算达成率 |
| 版本对照 | `lib/page/VersionViewPage.dart` | 舞萌版本代号 |
| 达成率反推 | `lib/page/AchievementFullReverseCalculatorPage.dart` | 由达成率反推判定 |
| KALEIDXSCOPE | `lib/page/KaleidXScope/KaleidXScopeSelectPage.dart` | 国服门进度 |
| 曲绘识别 | `lib/page/CoverRecognitionPage.dart` | 拍照识别曲绘 |
| 曲绘兜底链 | `lib/utils/CoverUtil.dart` + `lib/service/DxRatingCoverService.dart` | 本地 → diving-fish → dxrating(shama) → 默认曲绘；随包索引 + 磁盘缓存，详见开发文档 §7.3 |
| 定数分布 | `lib/page/DifficultyDistributionPage.dart` | 谱面定数柱状图 |
| 收藏夹 | `lib/page/FavoriteFolderPage.dart` | 自定义收藏分组 |
| 自定义谱面播放 | `lib/page/PersonalizedChartPlayConfigure.dart` | 加载本地 maidata |
| 每日推荐 | `lib/page/DailyRecommendPage.dart` | 基于已玩记录推荐 |
| 好友对比 | `lib/page/FriendComparePage.dart` | 与好友对比成绩 |
| 全国音游地图 | `lib/page/GlobalArcadeMapPage.dart` | 国内音游机台 |
| 全球音游街机地图 | `lib/page/GlobalArcadeMapPage.dart` | NearCade 全球店铺 |

## 5. 系统 / 账号

| 功能 | 文件 | 说明 |
| :--- | :--- | :--- |
| 刷新数据 | `lib/page/HomePage.dart` | 刷新当前页数据 |
| 刷新 maidata | 同上 | 手动刷新所有 maidata 缓存 |
| 同步成绩到水鱼 | 同上 | 机台 QR / DXNet Bot（**线路1 maimai Score Hub**） |
| 同步成绩到落雪 | 同上 | 机台 QR（**线路1 maimai Score Hub**） |
| 同步线路切换 | `lib/widgets/SyncRouteFooter.dart` | 水鱼 / 落雪各自独立记忆 线路1 maimai Score Hub / 线路2 AWMC 网关；hub 页与首页收藏区共用一份状态（`lib/utils/SyncRouteNotifier.dart`） |
| 同步统计 | `lib/service/SyncStatsService.dart` | 近 100 次的平均耗时与成功率（Redis），跟随上面的线路切换 |
| 登录水鱼 / 登出 | 同上 | OAuth / ImportToken |
| 服务器状态 | `lib/page/MaimaiServerStatusPage.dart` | AWMC 状态查询 |
| 检查更新 | `lib/page/HomePage.dart` | 调 `LZYCheckUpdateManager` |
| 关于本 APP | `lib/page/AboutAppPage.dart` | 应用信息 |
| 问卷调查 | `lib/page/SupportDeveloperPage.dart` | 反馈建议 |
| 支持开发者 | 同上 | 捐赠入口 |
| 账号管理 | 同上 | 已绑定水鱼账号信息 |
| 数据备份 | `lib/page/DataBackupPage.dart` | 导出/导入本地数据 |
| 最近评论 | `lib/page/RecentCommentsPage.dart` | 全站最近 50 条 |
| 最近评分 | `lib/page/RecentRatingsPage.dart` | 全站最近 50 条 |
| AWMC 网关 | `lib/page/Awmc/AwmcConsolePage.dart` | 机台账号查询 / 写入（见下节；**入口当前隐藏**） |
| 主题切换 | `lib/page/HomePage.dart` | 浅色 / 深色 / 纯黑 |

## 5.1 AWMC 网关（敏感功能）

> ⚠️ **本功能当前不进版本库、入口也隐藏了**（`lib/utils/FeatureFlags.dart` 的
> `awmcGateway = false`）：`lib/page/Awmc/`、`lib/service/AWMC/`、
> `lib/entity/AWMC/AwmcUserMusic.dart`、`lib/api/AwmcToken*.dart` 与
> `test/awmc_*_test.dart` 都在 `.gitignore` 里，所以**克隆 / 新机器上是没有这些
> 文件的**（`HomePage` / `SystemHubPage` 仍 import 它们，因此那样的工作区编译不过）。
> 要启用：把 `FeatureFlags.awmcGateway` 改成 `true`，系统 hub、首页搜索 /
> 收藏 / 全部功能里的入口会一起回来。

对接 [AWMC 公共 API](https://wiki.awmc.team/dev/awmc-api)（`https://api.wmc.pub`），
入口在「系统 → AWMC 网关」，也参与首页搜索与星标收藏。

| 分区 | 能力 | 文件 |
| :--- | :--- | :--- |
| 凭据 | 令牌（本机保存 / 构建内置）+ 每次操作当场输入的二维码 | `lib/service/AWMC/AwmcStore.dart` |
| 连通性/用量 | health、quota、usage、失败率、api-tokens（不计费） | `lib/service/AWMC/AwmcApiService.dart` |
| 只读查询 | preview / data / region / music / charge / item-list / kaleidx-scope / game-event | 同上 |
| 第三方同步（线路2） | `/v1/user/music` → `update-lx` / `update-fish` | `lib/page/Awmc/AwmcSyncFlow.dart` |
| 游玩次数缓存 | (musicId, level, playCount) 内存 + prefs | `lib/service/AWMC/AwmcPlayCountStore.dart` |
| 响应实体 | `/v1/user/music` 的响应结构 | `lib/entity/AWMC/AwmcUserMusic.dart` |
| 写入 | `music/upsert`、`music/delete`、`charge`、`ticket/clear` | `lib/page/Awmc/AwmcScoreWritePage.dart` |
| 记录 | 本机审计日志（无二维码/令牌/请求体） | `lib/page/Awmc/AwmcAuditLogPage.dart` |

### 5.1.1 同步成绩的两条线路

「系统 → 同步成绩到水鱼 / 到落雪」各有一个线路切换器（`SyncRouteSwitcher`），
选择结果分别存 `sync_route_diving_fish` / `sync_route_luoxue`
（首页「收藏的功能」区的同名入口也带这个切换器，见 §5.1.3）：

| 线路 | 走法 | 需要什么 |
| :--- | :--- | :--- |
| **线路1 maimai Score Hub** | 原有 scorehub 探针流程（chiffonmai.cloud → 水鱼 / 落雪） | 水鱼登录态 / 落雪 API Key |
| **线路2 AWMC 网关** | 机台二维码直连 `api.wmc.pub` | AWMC 令牌 + 本机已缓存的第三方凭据 |

线路2 的流程（`AwmcSyncFlow`）：

1. **直接复用线路1 的对话框**（`showDivingFishSyncInputDialog` /
   `showLuoXueSyncInputDialog`），一行文案都不多写——两个线路看到的界面完全一样；
2. 凭据读本机缓存，不再让用户重复输入：水鱼用
   `probe_diving_fish_import_token`（线路1 登录/绑定时写入），
   落雪用 `probe_lxns_import_token`（线路1 落雪对话框在用户填写时落盘）；
3. `POST /v1/user/music`（4 Token，顺便刷新「游玩次数」缓存）→
   `POST /v1/update-lx` 或 `/v1/update-fish`（5 Token），共 9 Token。

> ⚠️ 对话框里的「参与排行榜 / 显示昵称」**只对线路1 生效**：
> 官方 `/api/docs` 明确 `/v1/update-fish` 与 `/v1/update-lx` 只接收
> `qrcode` + `token`/`key`。由于界面与线路1 完全相同，这里不再单独加提示文案，
> 差异记在本文档里。

**`/v1/user/music` 的实测口径**（实体见 `AwmcUserMusic.dart`）：
`businessData.userMusicList[].userMusicDetailList[]`，每条
`{musicId, level, playCount, achievement, comboStatus, syncStatus, deluxscoreMax, scoreRank}`；
`musicId` 与水鱼 songId 对齐、`level` 10 = 宴会场、`achievement` 是 ×10000 的整数。

### 5.1.2 游玩次数（playCount）

`AwmcPlayCountStore` 把 `(musicId, level) → playCount` 存内存 + prefs
（键 `awmc_play_counts_v1`，属于可重新拉取的缓存，**不进备份**——它与账号绑定）。
刷新的时机：线路2 同步、AWMC 控制台的「成绩列表」查询、成绩写入页的
「读取现有成绩」——都复用同一份响应，不额外花 Token。

渲染位置：`lib/page/SongInfoPage.dart` 的「玩家最佳成绩」板块，
**`Rating: xxx` 下面单起一行**显示 `游玩次数: N`；该难度没有记录时整行不显示
（`null` 与 `0` 是两回事：上游不会返回 playCount=0 的条目）。

### 5.1.3 同步统计（近 100 次耗时 / 成功率）

两条线路的同步都会把「本次耗时 + 成败」写进项目自己的 Redis
（`SyncStatsService`，与排行榜共用同一台 Redis；实测命令往返已校验）：

```
chiffonmai:sync_stats:<line>:<platform>     # line: scorehub|awmc, platform: fish|lx
  条目 = {"t":<毫秒时间戳>,"d":<耗时毫秒>,"ok":1|0}
  写入 = LPUSH + LTRIM 0 99 + EXPIRE 30d    # 只留最近 100 次
```

只存这三个字段，**不含二维码、令牌、QQ、账号 id**，所以是「所有用户共享」的
整体统计（看到的是全局情况）。

显示位置：`系统 → 同步成绩到水鱼 / 落雪` 每个 tile 的线路切换器下面一行
（`SyncStatsView.summaryLine`）——
`近100次 / 87样本 / 平均12.3s / 成功97%`，点它打开详情弹窗，
并排比较 4 个组合（线路1/线路2 × 水鱼/落雪）；`系统 → AWMC 网关 → 连通性与用量`
里也有同一个入口。

**首页「收藏的功能」区里的同名入口也带这一行 + 线路切换器**（同一个
`SyncRouteFooter`）：两处显示、记忆必须是同一份，所以线路与统计都收在
`lib/utils/SyncRouteNotifier.dart`（单例 `ChangeNotifier`）：
* 线路内存里只有一份，落盘仍走 `SyncRouteStore`（同一套 prefs 键
  `sync_route_diving_fish` / `sync_route_luoxue`）→ 在首页切线路，hub 页立刻跟着变，
  反之亦然；
* 4 个组合的统计只拉一次（`ensureLoaded()` 幂等），谁先加载完另一边直接复用，
  不会两个页面各拉一遍；
* 两个页面的点击都按**当前线路**分发（线路1 → 原有 scorehub 流程 / 线路2 →
  `AwmcSyncFlow`），不存在「显示线路1 却走了线路2」的可能。

> 线路1 水鱼的样本在**对话框内部**上报（`SyncScoreDialogs.showDivingFishSyncDialog`）：
> 只有它知道最终是 `completed` / `failed` / `cancelled`（调用方拿到的是好友码）。
> 放在对话框里，从首页 / 我的 / 系统 hub 任一入口打开都算进同一份统计；
> hub 页按钮流在「缺 ImportToken → 转交对话框」时**不再**记那条失败样本，
> 免得同一次用户操作算成两条（对话框里那一次会上报）。

口径细节：
* Redis 连不上 → 显示「统计不可用」（而不是冒充「暂无记录」）；
* 用户主动取消同步**不计样本**（算失败会拉低成功率、误导看统计的人），
  「只是还没绑定 ImportToken」同理（紧接着会重来一次）；
* 线路1 水鱼/落雪的耗时含抓取 + 推送全程；线路2 的耗时含
  `/v1/user/music` + `update-*` 两次调用；
* 统计是**尽力而为**：写失败只丢一条样本，绝不影响同步本身。

> 这一行**必须够短**：它在 tile footer 里，左边有图标右边有箭头，窄屏（360dp）
> 可用宽度只有 300dp 左右。所以文案用 `/` 分隔、并且是「近100次」而不是
> 「近 100 次」（早先用「·」+ 全角写法会顶出边界，
> `test/sync_stats_view_test.dart` 在 320dp 下钉住了它）。

口径细节：
* Redis 连不上 → 显示「统计不可用」（而不是冒充「暂无记录」）；
* 用户主动取消同步**不计样本**（算失败会拉低成功率、误导看统计的人）；
* 线路1 水鱼/落雪的耗时含抓取 + 推送全程；线路2 的耗时含
  `/v1/user/music` + `update-*` 两次调用；
* 统计是**尽力而为**：写失败只丢一条样本，绝不影响同步本身。

### 安全约定（改动前必读）

1. **令牌的存放**：
   - 真正的值放 `lib/api/AwmcToken.dart`（**已 gitignore**，进版本库的只有
     占位模板 `lib/api/AwmcTokenShow.dart`）。⚠️ 这跟 `DeveloperToken.dart`
     一样属于「clone 后必须自己补一个文件」——新环境从模板复制一份即可，
     否则编译会直接报找不到 `AwmcToken`。
   - 也可用 `--dart-define=AWMC_TOKEN=gw_xxx`（优先级更高，便于临时换令牌）
     或 `--dart-define-from-file=awmc_secret.json`（该文件名也已 gitignore）。
   - 优先级：**本机保存 > 构建内置 > 空**（见 `AwmcCredentials.token`）；
     用户可在「AWMC 网关 → 设置令牌」里本机覆盖、随时清除。
   - `String.fromEnvironment` 是**编译期**常量，换令牌必须重新构建。
     ⚠️ 编译期常量会原样进 AOT 产物，`strings` 就能从 APK 里抠出来——
     **不存在「不可反编译」的客户端存放方式**，内置令牌只适合自己用的构建，
     要发给别人的包请留占位符、让使用者在 App 内自行填写。最稳的是自建后端代理。
2. **令牌不进备份**：`awmc_token` / `awmc_audit_log` 列在
   `DataBackupService._neverBackupKeys`，导出与导入两端都跳过。
3. **二维码完全不保存**：每一次需要二维码的操作（查询 / 同步 / 读取对比 /
   上传 / 删除 / 购票 / 清票）都会**当场重新弹输入框**，输完只在这一次请求里
   用掉，既不落盘也不跨操作复用内存里的那份。
4. **出口固定**：请求地址写死 `https://api.wmc.pub`，并在发请求前校验 host。
5. **写操作**：串行、不自动重试、必须二次确认（勾选确认项才可点执行），
   超时按官方建议取 180s。
6. **脱敏**：所有日志与报错过 `AwmcApiService.redact()`；界面上只显示掩码
   （`test/awmc_ui_test.dart` 会断言界面里不出现完整令牌）。
7. **不实现官方点名的高风险接口**：`kaleidx-scope/upsert`、`item/upsert`、
   `user/upsert-all`；`test/awmc_service_test.dart` 会扫描源码，防止被顺手加回来。

## 6. 友情链接

| 功能 | 文件 | 说明 |
| :--- | :--- | :--- |
| 友情链接 | `lib/page/FriendLinksPage.dart` | 推荐同好/同行项目 |

---

> 若新增/调整功能，请同步更新本页与 `lib/utils/FeatureRegistry.dart`。