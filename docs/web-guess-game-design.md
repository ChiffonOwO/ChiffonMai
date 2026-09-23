# 猜歌游戏 Web 版 · 设计文档（v1，先设计不实现）

> **状态：未来计划，暂不实现**（2026-09-18 设计存档）。本文只做设计，**未创建任何工程代码**；
> 真要动手前，先看文末「需要你拍板的三件事」。
>
> 目标：把 App 的「猜歌游戏」板块搬到网页端，**用户名手输、无需登录**。
> 本文只做设计，不含实现。所有"实测"结论都是本机真实请求得到的，不是推测。

---

## 1. 范围

### 1.1 做什么

| 模块 | 说明 |
| :--- | :--- |
| 单人模式（9 个） | 信息猜歌 / 曲绘 / 模糊曲绘 / 曲绘快闪 / 曲绘拼图 / 歌曲片段 / 别名 / 开字母 / 谱面片段 |
| 多人房间 | 建房、加入、准备、开局、作答、开字母、投降、房主转移；**复用现有 WS 服务端**，零服务端改动（除反代） |
| 用户名 | 手输即可。单人模式甚至可以不要用户名（只用于多人房间与本地记分） |
| 结果分享 | 生成成绩图/分享链接（对应 App 的导出图片能力，Web 端用 canvas 更简单） |

### 1.2 明确不做（v1）

登录、成绩/B50、收藏夹、OCR、同步成绩、排行榜、评论、万花镜门——这些要么需要账号凭据、要么与猜歌无关。
猜歌板块本身**不依赖用户成绩**：曲池来自全曲库（`MaimaiMusicDataManager` 的 music_data），所以「无需登录」在数据上天然成立。

---

## 2. 关键约束（实测）

| 依赖 | 实测结果 | 对 Web 的含义 |
| :--- | :--- | :--- |
| 音源 `https://assets2.lxns.net/maimai/music/{id}.mp3` | `200` `audio/mpeg` 2.3 MB/首，**`Access-Control-Allow-Origin: *`** | ✅ 浏览器可直接 `<audio>` 播放，也能做 WebAudio 分析 |
| 曲库元数据 `diving-fish.com/.../music_data` | `200`，**CORS `*`** | ✅ 前端可直接拉 |
| union 曲库 `union.godserver.cn/api/union/musics` | `200`，**CORS `*`** | ✅ 同上 |
| 别名 `yuzuchan.moe/api/maimaidx/maimaidxalias` | `200/405(HEAD)`，**CORS `*`** | ✅ 同上 |
| 曲绘（App 内置）`assets/cover/*.webp` | **1682 张 / 22.8 MB / 平均 13.9 KB** | ⚠️ 需要托管（或走远端兜底链，见 §5.3） |
| 曲绘兜底 `shama.dxrating.net/images/cover/v2/{imageName}.jpg` | App 内在用；`<img>` 展示不需要 CORS | ✅ 可直接引用 |
| 曲绘兜底2 `net.wmc.pub/cover/{songId}.png` | `200` `image/png` 240 KB，**CORS `*`** | ✅ 但单张偏大，只作最后兜底 |
| 自家后端 `http://chiffonmai.cloud:3000/api/*` | `200`，**没有任何 CORS 头** | ⚠️ 跨域不可用；HTTPS 页面也无法请求 http |
| 自家后端 `https://chiffonmai.cloud/`（443） | `200 text/html` | ✅ 443 上有站点，可同源部署 |
| 多人 WS `ws://chiffonmai.cloud:3000` | 明文 ws | ⛔ **HTTPS 页面连不上**（混合内容），必须加 `wss` 入口 |
| `simai_flutter`（谱面片段模式用） | `src/simai_file.dart` **无条件 `import 'dart:io'`**，且被 `export` 到包主库 | ⛔ **Flutter Web 编译不过**（除非给该包打条件导入补丁/本地 vendor） |
| `flutter_soloud` / `flame` / `audioplayers` / `web_socket_channel` | 均声明支持 web | ✅ |

### 2.1 由此确定的三条硬约束

1. **必须上 HTTPS**：页面一旦是 HTTPS，`ws://`（多人）与 `http://…:3000`（自家 API）都会被浏览器拦掉 → 需要**反向代理**给 WS 和 API 各开一个 TLS 入口（§6.1）。
2. **谱面片段模式不能靠现成包**：Web 端要么自己写渲染器，要么 v1 不做（§5.4）。
3. **不依赖自家后端也能跑起来**：曲库/别名/音源/曲绘四处都是公开且可跨域的，单人模式可以做成**纯静态站点**（连自家服务器都不需要）——这是本设计里最有价值的一点。

---

## 3. 技术选型

### 3.1 两个候选

| | **A. Flutter Web**（新工程，复用 App 代码） | **B. TypeScript SPA**（Vite + React/Svelte） |
| :--- | :--- | :--- |
| 复用现有代码 | ✅ 9 个模式页 + 规则服务共 **20 个文件 / 16,835 行**几乎原样可用 | ❌ 规则要重写（每个模式 150–300 行），UI 全部重写 |
| 谱面片段 | ⛔ 被 `simai_flutter` 的 `dart:io` 卡死；需 vendor 该包并打补丁 | ⚠️ 需自写 simai 解析 + Canvas 渲染（工作量中等） |
| 首屏/包体 | ⚠️ Flutter Web 产物通常 2–4 MB（gzip 后 ~1–1.5 MB），首屏 2–5 s | ✅ 首屏 < 300 ms，包体 < 200 KB |
| 布局 | ⚠️ 现有页面按手机宽度写死（`screenWidth * 0.0x` 字号），桌面端观感差，要改 | ✅ 响应式天然好写 |
| Web 平台坑 | `flutter_cache_manager` 不支持 web、`dart:io` 文件缓存要换、音频要换 `UrlSource` | 无（本来就是 Web） |
| 音频/曲绘能力 | 可用但等于把移动端实现搬到浏览器 | `<audio>` + CSS filter/background-position 一类需求都是"一行"级 |
| 口径一致性 | ✅ 天然一致（同一份代码） | ⚠️ 有漂移风险 → 用 §7 的契约测试压住 |
| 长期维护 | 两套 Flutter 工程 | Web 与 App 各自演进，但规则用 fixtures 对齐 |

### 3.2 建议

**首选 B（TypeScript SPA）**，理由按重要性排序：

1. 这是个「轻量、易分享、秒开」的产品形态，Flutter Web 的包体与首屏在这个场景里是硬伤；
2. 现有页面是移动端布局写死的，搬过来在桌面浏览器上要重做一遍布局，**复用页面这条最大红利被削掉一半**；
3. 谱面片段在两条路上都要额外工作，不构成选 A 的理由；
4. 数据面全部可跨域直连 → Web 端可以零后端（除多人），而 Flutter Web 也享受不到这个好处。

**什么时候该选 A**：如果目标是"用最少的时间把功能搬到网上、口径必须与 App 完全一致、且接受包体与手机版式"，那 A 更快（1–2 周出可用版本），但要么放弃谱面片段，要么给 `simai_flutter` 提一个条件导入的 PR 并临时 `dependency_overrides` 指向本地 fork。

> 下面 §4–§8 按 B 展开；A 的差异点在 §9 单列。

---

## 4. 架构

```
┌────────────────────────────────────────────────────────────┐
│ UI 层（模式页 / 房间页）                                     │
│   InfoGamePage · CoverGamePage · BlurGamePage · …           │
├────────────────────────────────────────────────────────────┤
│ 规则层（纯函数，**与框架无关、可单测**）                       │
│   pickSong(pool, rng) → prompt(state) → judge(guess)        │
│   → score(state) → hints(state)                             │
├────────────────────────────────────────────────────────────┤
│ 数据层                                                      │
│   SongRepository（曲库/别名/定数，IndexedDB + 构建期快照）      │
│   CoverResolver（本地规则 → 远端链）                          │
│   AudioResolver（lxns CDN + Range 区间播放）                  │
├────────────────────────────────────────────────────────────┤
│ 多人层（WebSocket 客户端，协议见 §6.2）                        │
└────────────────────────────────────────────────────────────┘
```

### 4.1 规则层为什么必须"纯"

App 里每个模式的规则散在页面类里（约 1400–1900 行/页），Web 重写时**只重写规则、不重写 UI 逻辑**，并把规则做成纯函数：

```ts
type Round = {
  song: Song;              // 答案
  prompt: Prompt;          // 题面：{kind:'cover'|'blur'|'audio'|'info'|'letters', …}
  startedAt: number;
};

judge(round: Round, input: string, ctx: JudgeCtx): GuessResult;
// GuessResult = { correct: 'exact'|'alias'|'prefix'|false, matchedBy?: string }
```

纯函数化的直接收益：**可以用 App 导出的用例做契约测试**（§7），把"口径漂移"从"不可控"变成"有红灯"。

### 4.2 数据模型（对齐 App 的字段命名）

```ts
type Song = {
  id: string;                 // 水鱼/maimai songId（与 App 一致，5/6 位数字）
  title: string; type: 'SD'|'DX';
  ds: number[]; level: string[]; cids: number[];
  charts: { notes: [number,number,number,number]; charter: string }[];
  basicInfo: { title: string; artist: string; genre: string; bpm: number;
               releaseDate: string; from: string; isNew: boolean };
  isExtra: boolean;           // 宴会场 / maidata 追加 / union 独有
};
```

`isExtra` 的判定必须与 App 的 `SongFilterUtil` 完全一致（6 位 id、`cids` 全 0、`isExtra` 标志），否则曲池会不一致——这条已在 App 里踩过坑（版本显示口径）。

---

## 5. 单人模式设计（9 个）

| # | 模式 | 题面来源 | 判定要点 | 移植难度 |
| :-- | :--- | :--- | :--- | :--- |
| 1 | 信息猜歌 | 曲库元数据（艺术家/流派/BPM/版本/定数，**曲名遮蔽**） | Wordle 式反馈：BPM ±20、定数 ±0.4、版本相邻世代、标签一致 → 绿/黄/灰 + ↑↓ 箭头 | ★★ |
| 2 | 曲绘猜歌 | 曲绘整图 | 别名匹配 | ★ |
| 3 | 模糊曲绘 | 曲绘 + `filter: blur()`（强度可调） | 同上 | ★ |
| 4 | 曲绘快闪 | 曲绘闪现 N 毫秒后隐藏 | 同上 | ★ |
| 5 | 曲绘拼图 | 曲绘切块逐批揭示（tileCount/tileRevealIntervalMs） | 同上 | ★ |
| 6 | 歌曲片段 | `assets2.lxns.net/maimai/music/{id}.mp3` 随机起点播 N 秒 | 同上 | ★★（要处理播放窗口与倒计时） |
| 7 | 别名猜歌 | 给别名猜曲名（要 `jp_transliterate` 的转写口径） | 反向匹配 | ★★ |
| 8 | 开字母 | 曲名掩码（空格可见、已开字母可见、其余 □），可多首目标 | 支持"回答 曲名/别名"、字母大小写不敏感 | ★★ |
| 9 | 谱面片段 | maidata（`https://chiffonmai.cloud/{genre}`）+ simai 解析 | 需要**谱面渲染器**与音频时间轴同步 | ★★★★（见 §5.4） |

### 5.1 共通设置（对应 `GuessChartCommonSettingsService`，196 行）

- 筛选：版本多选（`VersionListConstant` 的世代白名单 + 排序）、流派多选（排除"宴会场"）、Master 定数区间。
- 抽曲、计分、回合数、限时、每轮题目数 —— **建议原样照抄为一份 `rules.json` 常量表**，避免两端默认值不同。
- 影响：抽不到曲时要给出原因文案（App 的"曲池为空"提示与剔除 extra 的口径要对齐）。

### 5.2 音频播放（模式 6）

- `<audio preload="none" src={url}>` + `currentTime = startOffset` + `setTimeout` 停止；
- 随机起点范围与 App 一致（`random.nextInt(maxStartTime)`，需要一个**可控 rng**，多人模式才可复现）；
- 不做全量预取（1400 首 × 2.3 MB ≈ 3.2 GB）；浏览器缓存 + 可选 Service Worker 缓存最近 N 首；
- 首次播放会有 100–300 ms 缓冲，设计上给"加载中"态，别让计时器先跑。

### 5.3 曲绘解析链（对应 `CoverUtil` + `DxRatingCoverService`）

```
1) 自建静态：/covers/{songId}.webp        ← 首选（22.8 MB 全量可托管）
2) dxrating：shama.dxrating.net/images/cover/v2/{imageName}.jpg
   imageName 需要索引（App 已生成 assets/dxrating_cover_index.json，121 KB / 1677 条，可复用）
3) wmc 兜底：net.wmc.pub/cover/{songId}.png（CORS *，但 240 KB/张）
4) 占位图
```

- 本地静态文件名规则（与 App 一致）：5 位 id 去掉前导 `1`+零（`11312 → 1312.webp`）、6 位去掉前两位（`121634 → 1634.webp`）；
- 缓存策略：`Cache-Control: public, max-age=31536000, immutable` + 文件名带内容哈希（或直接依赖 songId 不变性）。

### 5.4 谱面片段（模式 9）的处理

App 的实现链是：`MaidataManager`（缓存 maidata）→ `SimaiFile` 取 `inote_4` → `SimaiConvert.deserialize` → `simai_flutter` 的渲染器 → **与音频时钟同步**播放片段。

Web 端三个选项：

| 方案 | 工作量 | 评价 |
| :--- | :--- | :--- |
| **v1 不做** | 0 | ✅ 推荐：8 个模式已覆盖绝大部分玩法；这个模式本身也最依赖谱面库缓存 |
| 自写 simai 解析 + Canvas 渲染 | 中（解析器 ~300 行、渲染 ~500 行，simai 语法是公开文本格式） | ✅ v2 首选；能与音频时间轴精确同步，还绕开了 `dart:io` |
| 服务端预渲染片段（图片/视频） | 中高（要复用 Dart 渲染引擎出图） | ❌ 存储与带宽不划算，且失去"实时谱面滚动"的观感 |

---

## 6. 多人部分

### 6.1 网络入口（唯一需要动服务端的地方）

现有：App 直连 `ws://chiffonmai.cloud:3000`（明文、无 TLS）。
Web 端需要：

```
浏览器 ──wss://chiffonmai.cloud/ws──► 反向代理 ──► ws://127.0.0.1:3000
浏览器 ──https://chiffonmai.cloud/api/*──► 反代 ──► http://127.0.0.1:3000
浏览器 ──https://chiffonmai.cloud/guess/*──► 静态文件（Web 前端产物）
```

要点：
- **协议完全不变**（同样的 JSON 消息），只是换了个入口；App 继续用 `:3000`，两代客户端可同时在房间内；
- 同源部署后 `/api/*` 的 CORS 问题自动消失（也可以用反代加 `Access-Control-Allow-Origin`，但没必要）；
- 反代必须带 `Upgrade`/`Connection` 头透传，并放宽 `proxy_read_timeout`（同步成绩等长请求会挂很久）。

Caddy 示例（比 nginx 少踩坑）：

```
chiffonmai.cloud {
    handle /guess/* { root * /srv/web; file_server }
    handle /ws*     { reverse_proxy 127.0.0.1:3000 }
    handle /api/*   { reverse_proxy 127.0.0.1:3000 }
}
```

### 6.2 复用现有协议（不需要新写服务端）

客户端 → 服务端：`initialize{nickname, resumePlayerId?}`、`create_room`、`join_room`、`update_ready`、`start_game`、`start_next_round`、`submit_guess`、`open_letter`、`leave_room`、`surrender`、`heartbeat`。

服务端 → 客户端：`initialized{playerId, resumed?}`、`room_created`、`room_joined`、`room_updated`、`join_failed`、`player_joined`、`player_left`、`player_offline`、`player_online`、`host_changed`、`round_start`、`round_over`、`game_over`、`game_state_updated`、`guess_received`、`letter_opened`、`error`、`left_room`、`heartbeat`。

已经具备且 Web 端直接受益的能力（本文档写作时刚落地）：
- **断线宽限期 120 s**：切后台/断网不立刻踢人，座位与分数保留，回来带 `resumePlayerId` 即可复位；
- `room.getState()` 里每个玩家带 `connected` 字段 → Web 端可以直接把掉线玩家置灰（App 暂时没用这个字段，Web 端先用起来）。

### 6.3 身份

服务端本来就只认 `nickname`（`initialize` 里没有账号概念），**与"用户名手输、无需登录"完全吻合**。
Web 端把昵称存 `localStorage`，玩家 ID（`playerId`）与"上次所在房间"也存本地，用于断线复位（与 App 同一套逻辑）。

---

## 7. 口径一致性（本设计里最容易被忽略、又最贵的一块）

Web 重写规则的最大风险是"看起来一样、判定不同"。用**契约测试**压住：

1. 从 App 导出 fixtures（一次性脚本，Node 即可读 Dart 侧已有的 JSON）：
   - `pool.json`：给定 settings（版本/流派/定数区间）→ 期望曲池的 `songId` 列表（含 extra 剔除结果）；
   - `judge.json`：给定答案 + 一批输入（精确/别名/大小写/全半角/近似）→ 期望判定结果；
   - `hints.json`：给定答案与猜测 → 期望的绿/黄/灰与箭头；
   - `letters.json`：给定曲名与已开字母 → 期望掩码串；
   - `translit.json`：别名转写（`jp_transliterate`）的输入输出对。
2. Web 端同一批 JSON 跑断言（Vitest）；
3. CI 里跑：**App 侧改动规则 → 重新导出 fixtures → Web 侧红/绿立刻可见**。

> 这一步不写，Web 版迟早会和 App 走偏（项目里已经有"版本显示口径"这种前车之鉴）。

---

## 8. 里程碑（每个都有可验收标准）

| 阶段 | 内容 | 验收标准 |
| :--- | :--- | :--- |
| **M0** 骨架 + 数据层 | Vite 工程、路由、曲库/别名/定数快照构建脚本（Node 拉取 + 归一化，产物进静态目录）、CoverResolver | 打开页面能列出全曲库；曲绘 100% 有图（含兜底链）；构建产物 < 500 KB |
| **M1** 三个模式 | 曲绘 / 模糊曲绘 / 信息猜歌（含设置面板 + 判定 + 计分） | 与 App 用同一份 settings 抽到同一曲池；fixtures 全绿 |
| **M2** 全 8 模式 | 快闪 / 拼图 / 歌曲片段 / 别名 / 开字母 | 每个模式有 fixtures；移动端浏览器可玩 |
| **M3** 多人 | WS 客户端 + 房间页（复用 §6.2 协议）+ 断线复位 + 掉线置灰 | 与 App 客户端**同房对战**通过；拔网 30 s 后回来仍在原座位 |
| **M4** 打磨 | 结果图/分享链接、成绩本地记录（localStorage）、无障碍与键盘操作 | 分享出去的链接在新窗口可复现同一局（seed 化） |
| **v2 候选** | 谱面片段（自写渲染器）、TS 化更多模式、PWA 离线 | — |

---

## 9. 若选 Flutter Web（方案 A）的差异点

- 复用：`lib/page/GuessChartGame/*`（9 页）、`lib/service/GuessChartGame/*`、`SongAliasManager`、`MaimaiMusicDataManager`、`SongFilterUtil`、`VersionListConstant`；
- 必须处理：
  1. `simai_flutter` 的 `dart:io`（条件导入补丁 / vendor / 放弃该模式）；
  2. `flutter_cache_manager`（`DxRatingCoverImage` 在用）不支持 web → 换 `cached_network_image` 或直连；
  3. `LuoXueSongUtil` 用 `dart:io` + 本地文件缓存播放音频 → web 分支改用 `UrlSource`；
  4. `MaidataManager` 用 `path_provider` 落盘 → web 分支改 `localStorage`/IndexedDB；
  5. 布局：所有页面用 `MediaQuery.size.width * 0.0x` 定字号 → 桌面端需要包一层最大宽度约束或重做；
  6. 页面里若引用了 App 专有单例（同步/OCR/收藏等），要剪掉依赖。
- 仍然必须做 §6.1 的反向代理（wss/同源），这一步两条路线完全一样。

---

## 10. 风险清单

| 风险 | 影响 | 缓解 |
| :--- | :--- | :--- |
| 音源/曲绘是第三方资源（lxns CDN、dxrating、wmc） | 被限速/改路径/热链策略变化会导致模式不可用 | 自建静态曲绘（22.8 MB 成本极低）+ 音频**按需**拉取并做兜底；把解析链写成数据驱动，改路径不用发版 |
| 口径漂移（判定的"接近"阈值、转写、别名） | 同一题两端判定不同，玩家立刻发现 | §7 fixtures + CI |
| 多人反代配错（Upgrade 未透传 / 超时过短） | 房间里随机掉线，极难排查 | 用 Caddy 默认配置；上线前用 `websocat`/浏览器脚本压 30 分钟长连接 |
| 桌面端体验（键盘作答、回车提交、无触摸） | 网页版的主要使用场景就是桌面 | M1 起就要求键盘可玩；输入框自动聚焦、Enter 提交、Esc 重开 |
| 版权/合规 | 曲绘与音源均为第三方资源，公开站点可能被投诉 | 曲绘优先自建（自有资源）；音频只做"按需播放"不做分发/缓存；页脚注明来源（与 App 一致） |
| 谱面片段永远做不完 | 拖累整体进度 | v1 明确不做，v2 再评估 |

---

## 11. 需要你拍板的三件事

1. **选型**：TypeScript SPA（推荐）还是 Flutter Web（复用优先）？
2. **多人是否进 v1**：进了就必须先做 §6.1 的反向代理（wss + 同源 `/api`），这是唯一需要动服务器的部分。
3. **曲绘自建还是全走远端**：自建要多 22.8 MB 静态资源（推荐，观感与稳定性最好）。
