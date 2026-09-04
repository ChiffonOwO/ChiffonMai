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