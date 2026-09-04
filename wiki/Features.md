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
| 同步成绩到水鱼 | 同上 | 机台 QR / DXNet Bot |
| 同步成绩到落雪 | 同上 | 机台 QR |
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
| 主题切换 | `lib/page/HomePage.dart` | 浅色 / 深色 / 纯黑 |

## 6. 友情链接

| 功能 | 文件 | 说明 |
| :--- | :--- | :--- |
| 友情链接 | `lib/page/FriendLinksPage.dart` | 推荐同好/同行项目 |

---

> 若新增/调整功能，请同步更新本页与 `lib/utils/FeatureRegistry.dart`。