# 开发者指南

> 本页面向想要从源码构建、调试或贡献 ChiffonMai 的开发者。
> 如果你是普通用户，请阅读 [首页使用文档](Home.md)。

## 1. 项目结构

```text
my_first_flutter_app/
├── android/                // Android 原生工程
├── ios/                    // iOS 原生工程（暂未发布）
├── lib/                    // Dart 源码（主入口）
│   ├── api/                // API URL 常量
│   ├── constant/           // 全局常量
│   ├── entity/             // 数据模型（按数据源分子目录）
│   ├── manager/            // 数据管理 / 缓存层
│   ├── page/               // 各功能页面
│   ├── service/            // 业务服务
│   ├── utils/              // 通用工具（主题、缓存、解码等）
│   ├── widgets/            // 公共组件
│   └── main.dart           // 应用入口
├── server/                 // Node.js 自家后端（OAuth 代理 / 排行榜 / 知识库 等）
├── assets/                 // 图片、字体、配置文件
├── fonts/                  // 字体文件
├── test/                   // Flutter 测试
├── pubspec.yaml            // 依赖与资源
├── analysis_options.yaml   // Lint 规则
└── build_apk.ps1           // Windows 一键打包脚本
```

## 2. 关键依赖（pubspec.yaml 节选）

| 依赖 | 用途 |
| :--- | :--- |
| `provider` | 状态管理 |
| `shared_preferences` | 本地键值存储 |
| `cached_network_image` + `flutter_cache_manager` | 网络图片缓存 |
| `just_audio` / `audioplayers` | 音频播放 |
| `simai_flutter` | maidata.txt 解析与谱面播放 |
| `http` / `dio` | HTTP 请求 |
| `web_socket_channel` | 多人猜歌 WebSocket |
| `fl_chart` / `syncfusion_flutter_charts` | 图表 |
| `flutter_map` / `latlong2` | 地图 |
| `image_picker` / `mobile_scanner` | 拍照 / 扫码 |
| `permission_handler` | 权限申请 |
| `google_fonts` | 在线字体 |
| `redis` / `mysql1` | 后端数据库驱动（server 端依赖亦包含） |

## 3. 构建与运行

```bash
# 安装依赖
flutter pub get

# 静态检查
flutter analyze

# 运行
flutter run -d <device_id>

# 打包
flutter build apk --release
flutter build appbundle --release
flutter build ipa       # macOS only
```

Windows 用户可直接：

```powershell
./build_apk.ps1
```

## 4. 数据层约定

App 大量使用 `manager/` 下 Manager 类做本地缓存与按需刷新：

| Manager | 说明 |
| :--- | :--- |
| `MaimaiMusicDataManager` | 全量曲库（来自水鱼 music_data） |
| `UnionUniManager` | union 全量曲库（含可游玩地区、releaseDate） |
| `DiffMusicDataManager` | 谱面定数（chart_stats） |
| `SongAliasManager` | 别名（yuzuchan + dxrating） |
| `MaiTagsManager` | 谱面标签（dxrating） |
| `DXDataManager` | dxrating 全量数据 |
| `UserPlayDataManager` / `UserBest50Manager` | 个人游玩数据 / Best50 |
| `LuoXueUserPlayDataManager` | 落雪游玩数据 |
| `MaidataManager` | 谱面 maidata 缓存 |
| `KnowledgeManager` | 舞萌百科知识库 |
| `MultiplayerManager` | 多人游戏房间管理 |
| `LZYCheckUpdateManager` | 应用更新检查 |

所有缓存键集中在 `lib/constant/CacheKeyConstant.dart` 与 `CacheTimestampConstant.dart`。

## 5. 网络层约定

- **API URL**：`lib/api/ApiUrls.dart`
- **网络客户端**：`lib/utils/ApiClient.dart`（封装 `http`）
- **OAuth 代理**：水鱼 OAuth 走自家后端（`BackendBaseUrl`），其他 API App 直连。
- **服务端**：`server/server.js`（Node.js），部署在 `chiffonmai.cloud`，提供：
  - OAuth 代理（`/api/prober`）
  - 排行榜（`/api/rankings`、`/api/song-rankings`）
  - 知识库（`/api/knowledge`）
  - 评论（`/api/comments`）
  - 谱面评分（`/api/ratings`）
  - B 站播放量缓存（`/api/bilibili`）
  - 万花镜（`/api/kaleidxscope`）

## 6. 添加一个新功能的步骤

1. 在 `lib/page/` 下新建对应页面（StatefulWidget）。
2. 在 `lib/utils/FeatureRegistry.dart` 的 `allCategories` 中注册按钮。
3. 如需远端数据：
   - 在 `lib/api/ApiUrls.dart` 增加 URL。
   - 在 `lib/service/` 新建 Service 类（负责请求与解析）。
   - 在 `lib/entity/` 增加数据模型。
   - 若需要缓存，参照 `lib/manager/` 的现有 Manager 实现。
4. 在首页 `HomePage` 跳转逻辑中按需导入新页面并跳入。
5. 运行 `flutter analyze` 确保无 Lint 错误。
6. 在 `wiki/Features.md` 同步新增条目。

## 7. 主题与样式

- `lib/utils/AppTheme.dart`：浅色 / 深色 / 纯黑三种主题。
- `lib/utils/ThemeManager.dart`：持久化主题设置，支持跟随系统 / 浅色 / 深色 / 纯黑。
- `lib/widgets/ThemeAwareBackground.dart`：根据主题切换背景图。
- `lib/utils/CommonWidgetUtil.dart`：各内页用的 `buildCommonBgWidget()` /
  `buildCommonChiffonBgWidget(context)`（`AppShell` 之外的内页走这一套）。

### 7.0 背景分层（改动前必读）

背景一共两层，**两层的「变暗」都只能作用在自己的图上，不能各铺一层实心矩形**：

| 层 | 内容 | 覆层 |
| :--- | :--- | :--- |
| 底层 | 背景图（`BoxFit.cover`，满屏） | `(15,15,28)` / 白色 × 「背景透明度」，满屏是**正常**的 |
| 上层 | chiffon 装饰图（默认隐藏，滑杆控制） | **不再有覆层** |

- 装饰图 `assets/chiffon2.png` 是 1179×2556 的整屏**透明底**图，
  `BoxFit.contain` 居中铺开后几乎占满主体区域 —— 在它上面再铺一层
  `Positioned.fill(ColoredBox)`，画出来就是一整块纯黑（`BoxFit.cover` 时更是满屏），
  和装饰图自己的透明度**无关**：装饰图设为 0（默认）时照样画。
  表现就是「深色（非纯黑）下主体区域有一块纯黑、还带一条明显的黑边」，
  背景图越亮越刺眼（纯黑模式看不到，因为那条分支直接 return 了）。
- 装饰图的浓淡只由 `ThemeManager().chiffonOpacity`（它自己的滑杆）控制；
  `<= 0` 时直接 `SizedBox.shrink()`，连占位都省掉。
- `test/theme_background_test.dart` 钉住了这件事：树里除背景图那层覆层外
  **不允许再出现任何会画出来的 `ColoredBox`**（两处实现都测）。
- 这类纯视觉问题可以离屏出图来看：`tool/probe_home_bg_test.dart`
  （`flutter test tool/probe_home_bg_test.dart --update-goldens`）会把
  「修复前 / 修复后 / 装饰图打开」三张图写到 `tool/shots/`。
  ⚠️ 探针刻意放 `tool/`：`flutter test` 默认会把 `test/` 下的隐藏文件也一起跑。

### 7.1.1 滚动列表里的卡片底色：用自带 Material，别用 Ink

`Ink` 的 `decoration` 是交给**最近的 `Material`**（滚动页里就是 `Scaffold` 那层）
的 ink 层去画的，而那一层在 `Scrollable` 的滚动 / Android 拉伸回弹
（`StretchingOverscrollIndicator`）变换**之外** —— 表现是「上下滑动时只有文字被
拉伸，卡片本身不动」。列表里的按钮/卡片底色要自带一层 `Material`：

```dart
Material(
  color: scheme.surfaceContainerLow,
  clipBehavior: Clip.antiAlias,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
    side: BorderSide(color: scheme.outlineVariant),
  ),
  child: InkWell(onTap: onTap, child: ...),
)
```

首页「快捷入口」的四个按钮就是这个坑（已抽成 `lib/page/HubComponents.dart` 里的
`HubQuickAction`，`test/hub_quick_action_test.dart` 钉住「不许用 Ink」+ 副标题不省略）。

> 副标题统一写四个字：窄屏（320dp）每格只有 ~40dp 可用宽度，
> 「Rating 构成」这种会直接变成省略号。

### 7.3 曲绘兜底链（加分项：本地 → diving-fish → dxrating → 默认曲绘）

曲绘只有一个入口：`lib/utils/CoverUtil.dart`
（`buildCoverWidget` / `buildCoverWidgetWithContext` / `resolveCoverProvider`）。
**别在页面里另抄一套嵌套 `errorBuilder`** —— 现在整条链只有一份实现。

| 顺序 | 来源 | 说明 |
| :--- | :--- | :--- |
| 1~4 | 本地 assets | 原始 id / 主路径 / 备用1 / 备用2（5、6 位 id 的剔除规则见文件头注释） |
| 5 | diving-fish | `https://www.diving-fish.com/covers/{coverId}.png` |
| 6 | **dxrating（shama）** | dxdata 的 `imageName` → `/images/cover/v2/{imageName}.jpg` |
| 7 | `assets/cover/0.webp` | 默认曲绘 |

第 6 级是 2026-09 新增的，**不是可有可无**：水鱼的 DX 条目 id 是
`10000 + 基础 id`（如 `10030`），第 5 级按规则会拼成 `10030.png` → **404**，
只有第 6 级（先把 id 归一化回基础 id 再查 imageName）才出得来图。

实测口径（`tool/probe_dxrating_cover_test.dart` 用真实 dxdata 跑过全链路）：

- 覆盖率 **99.8%**（水鱼 1394 首里 1391 首拿得到 imageName，曲名一致 1389）；
- 单张 **14~32 KB** 的 JPEG（diving-fish 是 240~300 KB 的 PNG），约 300~950ms；
- 响应头 `cache-control: public, max-age=31356000, immutable`（一年）——
  服务端明确希望客户端长期缓存。

**缓存与「别对服务器造成压力」**（`lib/service/DxRatingCoverService.dart`）：

1. `assets/dxrating_cover_index.json`：**随包基线索引**（121 KB / 1677 条），
   构建期由 `tool/gen_dxrating_cover_index.cjs` 从真实 dxdata 生成。
   首次启动即可用，完全离线、零服务器压力；
2. 本地更新：基线/本地索引超过 7 天才会尝试更新一次，且**一个 App 会话最多一次**，
   成功后写 `dxrating_cover_index_v1.json`（下次优先用更新的那份）；
3. 两份索引都在有效期内 → **完全不联网**（`chooseIndex()` 把这条规则写成了纯函数并测了）；
4. 曲绘图走独立的 `dxRatingCoverCacheManager`（30 天 / 1000 张磁盘缓存）；
5. 索引里查不到的 songId **不构造 URL**，避免拿注定 404 的地址敲服务器。

> ⚠️ dxdata 有 4MB，实测从 `miruku.dxrating.net` 下载要 **200s+**（≈20KB/s）。
> 所以 `DXDataManager` 的超时是 **300s**（原来是 30s，必然超时——
> 定数历史与索引更新都会静默失败），而且曲绘兜底**绝不能**依赖它：
> 必须靠随包基线条。

#### 显示曲绘时不要自己拼路径（踩过的坑）

`CoverUtil.buildCoverPath(id)` 是 `assets/cover/{id}.webp`，**不做 id 剔除**，
只能用来「拼候选 / 探测资源」；**显示一律用 `buildCoverWidget` /
`buildCoverWidgetWithContext`**（或需要 provider 时用 `resolveCoverProvider`）。

- 反面教材：曲绘识别页的「匹配曲绘」和「识别结果 Top10」缩略图原来直接
  `Image.asset(CoverUtil.buildCoverPath(sid))` —— 5 位（DX 条目，如 `11312` / `10030`）
  与 6 位（宴会场，如 `121634`）的曲绘资源名是**剔除后**的 id
  （`1312.webp` / `30.webp` / `1634.webp`），原始 id 的路径根本不存在，
  于是「识别结果和 Top10 里部分曲绘显示不出来」（而且识别本身是对的，
  因为特征提取走的是 `extractCoverId` 的规则路径）。
- `test/cover_path_rules_test.dart` 用**真实打包资源**钉住了规则
  （原始 id 路径不存在、剔除后的存在），并且会扫描 `lib/` 拦下
  `Image.asset/AssetImage/Image.network(buildCoverPath(...))` 这种写法。
- 那两个猜歌服务里没人调用的 `generateCoverId / getCoverPath / getNetworkCoverUrl`
  已删除（同样的错误规则，留着迟早被误用）。

#### 按钮配色：别把「浅色」当底色配白字

深色模式下 `colorScheme.onSurface` 是**近白色**、`primary` 也是浅色调，
所以「底色取主题里的浅色 + 文字写死 `Colors.white`」在深色模式下就是**白底白字**，
完全看不清（浅色模式看不出来，因为那时 onSurface / primary 是深色）。

- 反面教材：曲绘识别页的「开始识别 / 重新识别」原来
  `backgroundColor: c(=onSurface)` + `foregroundColor: Colors.white`。
- 正确做法：前景取与底色**成对**的那个角色 —— 底色是 `onSurface` 就用 `surface`
  （或 `primary` 配 `onPrimary`、`error` 配 `onError`）。
  这条已经抽成 `lib/widgets/CoverActionButton.dart`，
  `test/cover_action_button_test.dart` 用 **WCAG 对比度 ≥ 4.5:1** 在
  浅色 / 深色 / 纯黑三种主题下把主按钮、次要按钮、「识别中…」转圈都测了一遍。

### 7.4 顶部标题栏（`PageTopBar`）

「返回按钮 + 标题 + 右侧槽」这套标题栏原本在 **48 个页面**里各抄了一份，
结构逐字节相同，而且是**完全透明**的（标题直接浮在页面背景上，「没有底」）：

```dart
Container(
  padding: EdgeInsets.fromLTRB(16, 48, 16, 8),
  child: Row(children: [
    IconButton(icon: Icon(Icons.arrow_back, color: 某种文字色), onPressed: pop),
    Expanded(child: Center(child: Text(title, style: ...))),
    右侧槽（SizedBox(width: 48) / 透明占位按钮 / 真按钮）,
  ]),
)
```

抄多了的后果是「改一处得改 48 处」，而且已经漂移出 3 种文字色来源、2 种字号、
2 种占位写法。现在统一走 `lib/widgets/PageTopBar.dart`，**样式照「Rating 排行榜」页
那个 `AppBar` 抄**：

| 项目 | Rating 排行榜页（`AppBar` + `appBarTheme`） | `PageTopBar` 默认 |
| :--- | :--- | :--- |
| 底色 | `Scaffold.backgroundColor` = `AppColors.cardBackground(brightness)` | 同左（透明 AppBar 透出该底色） |
| 标题 | `titleTextStyle`：`primary` / 20 / bold | 同左 |
| 标题位置 | `centerTitle: true`（在整条 bar 里居中） | 同左（`Stack` 居中，两个 action 也不会挤偏） |
| 图标 | `iconTheme`：`primary` | 同左（整条 bar 一个 `IconTheme`，页面不必再写 `color:`） |
| 阴影 / 分隔线 | `elevation: 0`，无分隔线 | 同左（要细线传 `showDivider: true`） |
| 顶部偏移 | AppBar 自己处理状态栏 | **48dp** 手写补偿（与迁移前一致） |

```dart
PageTopBar(
  title: '歌曲详情',
  actions: [IconButton(...)],                   // 可选
  fontSize: 24,                                 // 可选；默认 20
  padding: EdgeInsets.fromLTRB(16, 48, 16, 4),  // 可选；默认 (16,48,16,8)
  onBack: _stopAndPop,                          // 可选；默认 Navigator.maybePop
  titleAlign: PageTopBarTitleAlign.start,       // 可选；默认 center
)
```

- 需要退回旧观感：`barBackground: Colors.transparent, showDivider: false`。
- `test/page_top_bar_test.dart` 钉住上面整张表（三种主题、居中行为、图标色、可覆盖项）。
- 对照图：`flutter test tool/probe_topbar_test.dart --update-goldens`
  （`tool/shots/topbar_rating_ref.png` 是基准页，`topbar_about.png` 是迁移后的真实页面）。

> 迁移是脚本 + 人工混合做的：38 个文件的块是逐字节相同，用
> `tool/migrate_topbar.cjs`（严格模板匹配，不匹配就跳过）批量替换，
> 剩下的（标题是变量/三元、右侧有真按钮、返回逻辑不是简单 pop、
> bar 里带搜索框或批量工具栏）逐个手工改。**脚本已删**，只留下结论：
> 想再批量改一次这种「48 份复制粘贴」的 UI，先想清楚模板是否严格一致。

#### 与标准 `AppBar` 的差别（实测，别再靠肉眼猜）

`tool/probe_topbar_vs_appbar_test.dart` 会把两者都渲染出来并打印数字，
当前结论（状态栏按 32dp 模拟）：

| 项目 | 标准 `AppBar` | `PageTopBar` |
| :--- | :--- | :--- |
| bar 高度 | 状态栏 + `kToolbarHeight(56)` = 88 | 48 padding + 48 工具栏 + 8 = **104** |
| 状态栏自适应 | `SafeArea(bottom:false)`，图标 top 16→48 随状态栏变 | **写死 48**，图标 top 恒为 60 |
| 标题居中 | `centerMiddle`，放不下时夹紧到按钮旁（各留 16） | 同左（**改用 `NavigationToolbar` 后一致**） |
| 长标题 + 2 action | 不重叠 | 不重叠（修复前会压到按钮上） |
| 标题语义 | `Semantics(header: true, namesRoute: true)` | 同左（已补） |
| 左右边距 | 按钮贴边（无横向内边距） | 保留各页面原有的 16dp 页边距 |
| 返回按钮 | 只在路由可 pop 时出现（本地化 tooltip、`leadingWidth` 56） | 默认总显示（`showBack: false` 可关），tooltip 写死「返回」 |
| 其他 | `bottom` 槽（TabBar/进度条）、`flexibleSpace`、scrolled-under 变色、drawer 自动汉堡键、`SystemUiOverlayStyle` | 都没有（本 App 的 `appBarTheme` 把 elevation 设 0、背景 transparent，scrolled-under 的差异实际看不到） |

**没有直接改用 `AppBar` 的原因**：这 48 个页面的 bar 在 `body` 的 `Stack` 里
（背景图在它后面透出来）。换成 `Scaffold.appBar` 要把 bar 挪出 body、每页都要改
结构（`Stack`/`Column`/`Expanded` 的相对关系），且没有真机能验证；
`PageTopBar` 是**原位替换**，迁移机械、观感可控。

将来若要更进一步（比如让 bar 自适应状态栏高度），只改这一个组件即可：
关键实现是内部的 `SizedBox(height: barHeight) + NavigationToolbar`。

### 7.1 二维码输入的公共组件

凡是让用户输入 `SGWCMAID...` 的地方（同步成绩到水鱼 / 落雪、AWMC 网关等），
都必须用 `lib/widgets/QrQuickFillButtons.dart`，不要再各自抄一份：

```dart
QrQuickFillButtons(
  controller: qrController,                       // 目标输入框
  onFilled: () => setState(() => error = null),   // 可选：填入后清旧错误
  enabled: !isBusy,                               // 可选：请求中禁用
)
```

- 三件套：**读取剪贴板 / 从相册识别 / 扫描二维码**（`QrScannerPage` 也在这个文件里）。
- 历史教训：这套代码曾在 `SyncScoreDialogs`、`HomePage`、`UpdateLuoXueScorePage`
  里各有一份，口径不一致——「同步成绩到落雪」甚至只剩一个剪贴板按钮。
  现在由 `test/sync_qr_buttons_test.dart` 钉住「两个同步对话框都必须有三个按钮」。

### 7.2 功能开关（代码留着、入口先不给看）

`lib/utils/FeatureFlags.dart` 集中放这类开关：

| 开关 | 控制的入口 | 相关代码是否进版本库 |
| :--- | :--- | :--- |
| `awmcGateway` | 「系统 → AWMC 网关」+ 首页搜索 / 收藏 / 全部功能里的同名入口 | **否**（见 `.gitignore` 的 AWMC 段） |

约定：

- 入口的定义只有三处，都要跟着开关走：`FeatureRegistry`（首页搜索 / 收藏 /
  全部功能的数据源）、`SystemHubPage` 的 tile、`HomePage._handleFeatureTap`
  的分支；`test/feature_flags_test.dart` 钉住「入口是否出现 == 开关的值」。
- 开关用 `static final bool` 而不是 `const`：`const false` 会让
  `if (FeatureFlags.xxx)` 里的代码被判成 dead code，平白多出一堆分析警告。
- ⚠️ 隐藏入口 **不等于** 解耦：`HomePage` / `SystemHubPage` 仍然 import
  `Awmc/*`，所以把被 ignore 的文件删掉（或换台机器 clone）会**编译不过**。
  真要发布一个不含 AWMC 的版本，得先把这些 import 与接线一起摘掉。
- 清理工作区时注意：被 ignore 的文件不怕 `git clean -fd`，但
  **`git clean -xdf` 会连它们一起删**（未跟踪文件本来也在删除范围内）。

新增页面时，建议：

- 颜色通过 `Theme.of(context).colorScheme` 引用，避免硬编码。
- 字体使用 `GoogleFonts.notoSansSc`，已在 `main.dart` 注入。

## 8. 国际化

当前以简体中文为主，词条散落在代码中。后续若引入多语言，可通过 Flutter 官方 `intl` 接入。

## 9. 测试

```bash
flutter test
```

测试目录位于 `test/`，目前主要覆盖 `unit/` / `widget/` 测试。建议新增功能时同步补齐。

### 9.1 两个踩过的坑

1. **窄屏断言必须用 `tester.view`，不要用 `setSurfaceSize`**：
   `tester.binding.setSurfaceSize(Size(320, 640))` 在本版本里**不会反映到
   `MediaQuery.of(context).size`**，于是「320dp 窄屏不溢出」这类断言会静默失效
   （实际仍按默认 800dp 渲染，怎么都不会溢出）。正确写法：

   ```dart
   tester.view.physicalSize = const Size(960, 1920); // 320dp × dpr 3
   tester.view.devicePixelRatio = 3.0;
   addTearDown(tester.view.reset);
   ```
   顺手断言一句 `expect(tester.getSize(find.byType(MaterialApp)).width, lessThanOrEqualTo(321))`，
   免得以后再退化。

2. **主题切换有 200ms 过渡**：连着渲染两种主题再断言颜色时，直接取值会拿到
   插值中的颜色。`await tester.pumpAndSettle();` 之后再断言
   （见 `test/page_top_bar_test.dart` 的三种主题用例）。

### 9.2 纯视觉改动的验证方式

没有真机时，用离屏出图（`runAsync` + `matchesGoldenFile`）做 before/after 对照：

- `tool/probe_home_bg_test.dart`：背景分层（那块纯黑）
- `tool/probe_topbar_test.dart`：顶部标题栏（`TOPBAR_PHASE=before/after` 各跑一次）
- `tool/probe_dxrating_cover_test.dart`：曲绘兜底链的真实数据全链路

这些探针刻意放 `tool/`：`flutter test` 默认会把 `test/` 下的隐藏文件也一起跑，
而它们要读系统字体、还要跟 golden 比对，不适合进默认测试套件。
像素差异可以用 `System.Drawing` 逐点比对量化
（顶部栏那三个变体实测都是 **0 像素差异**）。

## 10. 提交流程

1. Fork 仓库 → 创建特性分支。
2. 提交前确保：
   - `flutter analyze` 通过；
   - `flutter test` 通过；
   - 新功能 / Bugfix 同步更新 `wiki/`。
3. PR 标题建议：`feat: ...` / `fix: ...` / `refactor: ...` / `docs: ...`。

## 11. 反馈渠道

- 邮箱：`chiffonowo@foxmail.com`
- 仓库：`D:/flutterProjects/my_first_flutter_app`（GitHub: ChiffonOwO/my_first_flutter_app）