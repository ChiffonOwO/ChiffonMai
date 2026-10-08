# AGENTS.md — ChiffonMai 项目约定

给接手本仓库的 AI 工具/协作者看的约定。**这些约定大多是踩过坑之后定下来的，改之前先看原因。**

---

## 1. 术语（重要）

**跟舞萌谱面有关的东西一律叫「谱面」，不叫「关卡」。**

- ✅ 导出 AstroDX 谱面 / 谱面包 / 谱面文件夹
- ❌ 导出 AstroDX 关卡 / 关卡包 / 关卡文件夹

代码、注释、UI 文案都要遵守。全仓库核查方式：

```powershell
Get-ChildItem lib,android,wiki -Recurse -File -Include *.dart,*.kt,*.xml,*.md |
  Select-String -Pattern "关卡"
```

> ⚠️ 不要写成 `Select-String -Path "lib\*.dart","lib\**\*.dart"`。
> PowerShell 的通配符里 `**` 不是「递归」，等价于 `*`，只覆盖一层目录，
> 会**静默漏掉** `lib/page/RankTable/...` 这类两层以上的文件——
> 实测同一个词它能返回 0 条，而上面这条递归写法返回 7 条。

---

## 2. 导出：一切走 ExportPathUtil

**不要自己拼 `getApplicationDocumentsDirectory()` 或 `getExternalStorageDirectory()` 当导出路径**——那些在 Android 上是 `Android/data/<包名>/files` 私有沙箱，用户用文件管理器根本找不到。

统一入口：`lib/utils/ExportPathUtil.dart`

```dart
final file = await ExportPathUtil.writeExportFile(
  fileName: '$name.adx',
  bytes: zipData,
  subDir: '谱面',                    // '谱面' / '收藏夹'
  onFallback: (p) => _fallbackPath = p,   // 公开目录不可写时会被回调，务必在 UI 上提示
);
```

落盘位置：`/storage/emulated/0/Download/ChiffonMai/<subDir>/`

约定细节：

- **可写性必须用探针文件实测**，不能只判断目录是否存在——Android 11+ 分区存储下「目录存在」和「可写」是两回事。
- 写完后调 `MediaScanner.loadMedia`，否则部分文件管理器要等重启才看得到。
- 公开目录不可写时退化为应用文档目录，并**通过 `onFallback` 在弹窗里橙色告警**，不能静默把文件丢进沙箱。
- iOS 侧依赖 `ios/Runner/Info.plist` 里的 `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace`，**不要删**，删了导出就等于进沙箱。
- 极端情况下**不要**把 `getExternalStorageDirectory()` 当公开目录用（它在 Android 上是私有路径），否则会吞掉给用户的告警。

---

## 3. AstroDX `.adx` 打包结构

`.adx` **本质就是改了后缀的 zip**（依据 [AstroDX Wiki](https://wiki.astrodx.com/cn/install/android)）。AstroDX 扫描压缩包内容，找到含 `maidata.txt` 的谱面文件夹后自动安装。

**两种导出格式的压缩包结构不同，不要合并：**

```
<曲名>.zip                    ← 通用谱面包：三件套平铺在根目录
├── maidata.txt
├── bg.png
└── track.mp3

<曲名>.adx                    ← AstroDX：必须套一层以曲名命名的文件夹
└── <曲名>/
    ├── maidata.txt
    ├── bg.png
    └── track.mp3
```

**写入 maidata 必须用 `utf8.encode`，不能用 `codeUnits`。** `codeUnits` 返回 UTF-16 码元，日文/中文曲名会被写成乱码字节，导出到别的工具里全是问号。

实现见 `lib/page/SongMaidataPage.dart` 的 `_exportAstroDx()` / `_exportToZip()`。

---

## 4. 收藏夹交换格式

`lib/service/FavoriteTransferService.dart`

- JSON，自描述带版本：`format = "chiffonmai.favorites"`，`formatVersion = 1`
- 后缀由 `lib/utils/ExportSettings.dart` 决定，**默认 `.cmf`，用户可在设置页自定义**（key: `export_favorite_extension`）
- **导入按内容校验，不按后缀校验**——所以用户无论把后缀改成什么都能导回来。文件选择器用 `FileType.any`，不要用 `FileType.custom` 限定后缀。
- 导入支持「合并」（同名收藏夹合并、`uniqueKey` 去重）与「覆盖」两种模式
- 旧版 `.txt` 导出不含 `songId`，**无法还原**，检测到纯文本要给出明确提示而不是静默失败

---

## 5. 谱面播放页（ChartPlayPage）三个坑

### 5.1 高刷新率

Flutter 引擎**从不**调用 Android 的 `Surface.setFrameRate()`（[flutter/flutter#160952](https://github.com/flutter/flutter/issues/160952)），所以系统默认按 60Hz 合成，只在触摸后短暂升到 120Hz 再衰减——表现为「进页面几秒 120 → 掉 60 → 一交互又回 120」。

由 `lib/utils/RefreshRateUtil.dart` + `MainActivity` 的 `com.example.app/display` 通道解决。**目标刷新率必须取自实际选中的 display mode**，不能用全局最高值（同分辨率约束可能让 120Hz 的 mode 落选）。

### 5.2 侧边栏设置持久化

`lib/service/ChartPlaySettingsStore.dart`

- 控制器是 `ChangeNotifier`，侧边栏每改一次都会 `notifyListeners` → 挂监听 + 600ms 防抖落盘
- **防抖只推迟写盘，不推迟记录**：改动要同步 `remember()` 进内存，否则中途重建控制器会读到过期值
- **`_loadChart()` 必须先 `await ChartPlaySettingsStore().load()` 再建控制器**，否则会拿默认值建控制器、退出时再写回默认值，**把用户设置静默清空**

### 5.3 必须锁竖屏 —— 否则返回手势不会派发 back 事件

**真机反馈**：在 `ChartPlayPage` 里旋转到横屏后，手机**从屏幕边缘右滑的返回手势不再生效**，但 AppBar 左上角的返回按钮和硬件返回键都还能用。

**根因**：第三方包 `simai_flutter` 的 `SimaiPlayerPage` 在横屏会自动进全屏（见 `simai_player.dart:1664-1672`），调用：

```dart
await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
```

`immersiveSticky` 对应的 Android 行为是 `BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE`——Android 系统**把所有屏幕边缘的滑动都吃掉用来临时显示状态栏/导航栏**，**根本不会当作 back gesture 派发**给 App。这跟 § 6.3 的预测性返回竞态是**不同**的问题：

| | § 6.3 的卡死 | § 5.3 的返回手势 |
|---|---|---|
| 触发条件 | 框架 `_PredictiveBackGestureDetector` 与路由 pop 异步竞态 | Android 系统层 `BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE` 把滑动吃掉 |
| 修复位置 | manifest + AppTheme 两处都要 | 必须在用户层绕过 immersive 模式 |
| 表现 | 部分时间卡死 | 一直没用 |

**修复**（`lib/page/ChartPlayPage.dart`）：`initState` 里锁竖屏、`dispose` 里恢复全部方向，让 `SimaiPlayerPage` 永远走非全屏分支：

```dart
// initState
SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

// dispose
SystemChrome.setPreferredOrientations([
  DeviceOrientation.portraitUp,
  DeviceOrientation.portraitDown,
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
]);
```

**不要给 `ChartPlayPage` 加横屏支持**。横屏游玩体验重要，但**返回手势必须能用**是更高的优先级 —— 而两者在 `SimaiPlayerPage` 当前实现下不能兼得。如果以后要加横屏，只能在用户层自己实现 back gesture 检测（`Listener` + 自定义 `GestureRecognizer`），不能再依赖系统手势。

---

## 6. Android 清单约定

### 6.1 不要改回 Flutter 模板的 `launchMode` / `taskAffinity`

Flutter 模板默认给的是 `launchMode="singleTop"` + `taskAffinity=""`。**`taskAffinity=""` 会让文件管理器打开文件时新建任务**（空 affinity 匹配不到已有任务），结果是新起一个 Activity + 新 FlutterEngine，看起来像「开了两个 App」。

本项目的正确配置：

```xml
android:launchMode="singleTask"   <!-- 全局单实例，后续启动走 onNewIntent -->
<!-- 不写 taskAffinity -->
```

### 6.2 MainActivity 的 MethodChannel

| 通道 | 用途 |
|---|---|
| `com.example.app/media_store` | 保存图片到相册 |
| `com.example.app/open_file` | 收藏夹文件「一键导入」（`getInitialImportPath` / `onFileOpened`） |
| `com.example.app/display` | 屏幕刷新率（`setHighRefreshRate` / `restoreRefreshRate` / `queryRefreshRate`） |

`on_file` 通道的投递规则：**只有 Dart 已注册监听（`dartImportReady`）时才实时投递并清空 pending**，否则保留 pending 等 Dart 来取。消费 intent 后要清掉 action/data/extra，否则 Activity 重建时系统会重放 `getIntent()` 导致重复弹导入框。

### 6.3 返回手势：必须关掉「预测性返回」（两处，缺一不可）

真机反馈：**用返回手势返回上一级时 App 有概率卡死** —— 页面从四个角向内缩，缩完返回上一级，有时正常、有时整个 App 点不动。

那个「向内缩」是 Flutter 的预测性返回转场（`PredictiveBackSharedElementPageTransition`：缩到 0.90 + 32px 圆角 + 右下位移）。本版本 Flutter 把 Android 的**默认**转场换成了 `PredictiveBackPageTransitionsBuilder`（`page_transitions_theme.dart` 的 `_defaultBuilders`），它给每条路由装一个 `_PredictiveBackGestureDetector`：

- 手势一开始框架就替系统「认领」（`WidgetsBinding.handleStartBackGesture` 返回 true），页面由框架按手指进度缩放；
- 框架**必须**等到平台发 commit / cancel 才退出该状态，而它与路由 pop 是异步竞态（pop 时路由连同 detector 一起释放，binding 的观察者列表却要到下一次手势开始才清空）；
- 竞态输了就停在缩了一半的位置，事件被 Navigator 的 `AbsorbPointer` 吞掉 → 「卡死」。
- **按键返回不中招**：`backEvent.isButtonEvent == true` 时框架不认领 —— 所以只有手势路径出问题，与反馈一致。

两处配置**都要在**，少一个都还会认领手势：

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
android:enableOnBackInvokedCallback="false"
```

```dart
// lib/utils/AppTheme.dart：三套主题都钉在 FadeForwardsPageTransitionsBuilder
pageTransitionsTheme: _backGestureSafeTransitions(),
```

`FadeForwardsPageTransitionsBuilder` 正是框架在「没有手势」时的回落分支，所以普通 push / 返回按钮 / 手势提交后的观感**完全不变**。回归测试：`test/page_transitions_test.dart`。

---

## 7. 颜色与主题

- 边框、分隔线、容器描边统一用 `Theme.of(context).colorScheme.outlineVariant`（项目的 `cardTheme` / `dividerTheme` 用的就是它）。
- **不要用写死的中性灰做边框**。历史遗留的 `AppColors.tableBorder(brightness)` 虽然按明暗分支，但两支都是硬编码灰（浅色 `grey.shade300` 对浅底只有约 1.26:1，几乎看不见；深色 `grey.shade700` 却有 3:1），**两边严重不均衡**，而且不跟随用户自定义主题色。新代码别再用它。
- 需要新颜色时加到 `lib/utils/AppTheme.dart` 的 `AppColors`，并接受 `Brightness` 参数。

---

## 8. 滚动文案（跑马灯）：别直接用 `marquee` 包

超长文本要横向滚动时（hub 按钮副标题、进度文案等），用 **`lib/widgets/MarqueeText.dart`**。

**踩过的坑（真机反馈）**：`marquee` 包的每一轮滚动距离，是拿**开滚那一刻**量到的文本宽度
算出来的，而两轮之间的空隙（`blankSpace`）是一个独立的 `SizedBox` 项。这类文案往往
**每秒都在变**（`正在导入成绩…已等待 12 秒` → `已等待 13 秒`）：宽度一变，内容就在视口下
整体平移，于是「轮末停顿」的落点漂到 ±`blankSpace` 之间 —— 表现就是**停下来时第一个字
前面空出约两个字**（实测 +17.9px @ textScale 1.5；同一处也可能是 -12 ~ -37px，变成第一个
字被切掉）。文案一成不变时完全看不出来，所以很容易被当成偶发问题。

`MarqueeText` 的位移是 `相位 × 周期`，周期**每帧按当前文本宽度重算**，所以：

- 停顿时的位移恒等于整数个周期 → 左边缘永远正好落在第一个字上；
- 文本中途变宽/变窄只会让当帧平移几像素，不会把停顿位置顶歪；
- 两份文本由我们自己摆放，**即使量宽度量歪了**停顿位置仍然对齐（误差只体现为空隙大小）。

回归测试：`test/marquee_text_test.dart` —— 跑到每一个停顿处，断言第一个可见字符离视口
左边缘 ≤ 0.5px（覆盖 textScale 1.0 / 1.3 / 1.5，文案逐秒变化）。

### 量文本宽度有两个「必须」

`TextPainter` 不会自动帮你对齐渲染样式，两点都要自己带：

1. **带 `textScaler: MediaQuery.textScalerOf(context)`**：用户把系统字体调大时，实际渲染
   宽度是放大过的。不带的话「放不下」会被判成「放得下」，用户看到的就是被省略号截断的
   半句话。
2. **带环境的 `DefaultTextStyle`**：先 `DefaultTextStyle.of(context).style.merge(style)`
   再量（`Text` 内部就是这么合并的）。ListTile 副标题是 Material 的 `bodyMedium`，
   带 `letterSpacing`（本项目实测 0.3）—— 十几个字就差 3~4px，周期量短了，停顿就落在
   第一个字前面空出那几个像素。

### 还有一个耗电点

静态文本（没溢出）时**必须停掉 ticker**。一直 `repeat()` 的 `AnimationController` 会持续
请求新帧，整页都别想进入空闲。

`lib/page/SongInfoPage.dart` 与 `lib/page/FriendLinksPage.dart` 里还有两处直接用
`marquee` 包的地方（歌名 / 友链），它们的文案基本不变所以没暴露这个问题；
哪天要给它们加会变化的文案，一并换到 `MarqueeText`。

---

## 9. 验证方式（重要）

**当前开发环境没有连接安卓设备，任何改动都无法真机验证。**

### 默认：你直接改代码就好，不用主动flutter analyze。如果有报错我会告诉你，然后只分析本轮编辑的文件即可。

```powershell
flutter analyze --no-pub          # 必须零 error
```

### 例外：改动碰到 `android/`（Kotlin / XML）时必须构建

**`flutter analyze` 只看 Dart，完全覆盖不到 Kotlin 和 AndroidManifest。**
本项目实际踩过：`MainActivity.kt` 里一个 `Uri?` 与 `Uri` 的类型不匹配，
`flutter analyze` 全绿，**只有 Gradle 构建才报出来**。

所以：

- 只改 Dart → 按照要求决定是否跑 `flutter analyze`，**不要构建**
- 改了 `android/**/*.kt` 或 `AndroidManifest.xml` → **必须 `flutter build apk --release`**，
  否则等于没验证（而且要如实告诉用户这一点）

涉及 Manifest 的改动，还要看**合并后**的清单（源码清单对了不代表合并结果对）：

```
build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml
```

### 汇报纪律

**如实区分「已验证（编译/静态检查）」和「未验证（真机行为）」，不要把 analyze 通过说成"功能正常"。**
如果某次没构建，就直接说"未验证 Kotlin/打包"，不要含糊过去。

---

## 10. 其它

- release 构建用**正式 keystore** 签名：`android/key.properties` + `android/app/chiffonmai-release.jks`，两者都已被 `android/.gitignore` 忽略。**缺 `key.properties` 时 `assembleRelease` / `bundleRelease` 会直接失败**——绝不退回 debug 签名：debug keystore 是每台机器各自的，用它签出来的包一旦装机就永远无法覆盖更新，应用商店也不收。keystore 与口令**必须离线备份**，丢了等于这个 App 再也无法更新。
- `applicationId` = `cloud.chiffonmai.app`（原为 `com.example.my_first_flutter_app`，为 APP 备案 / 上架而改）；`namespace` 仍保持 `com.example.my_first_flutter_app`——它只决定 R 类与资源解析，跟 App 身份无关，不动它是为了不挪 `MainActivity.kt` 的包目录。App 显示名仍是 `ChiffonMai`。
  - ⚠️ **applicationId 是 App 的永久身份**：APP 备案的「安卓平台软件包名称」填的就是它，**备案通过后再改要走变更备案**；改包名还会让老用户装成第二个 App、本地数据（账号/设置/收藏夹）不迁移。
  - 改 applicationId 时要同步改 `lib/page/GlobalArcadeMapPage.dart` 的 `userAgentPackageName`。
  - **MethodChannel 名**（`com.example.app/*`）与**通知渠道 ID**（`com.example.my_first_flutter_app.channel.*`）**不是包名**，不要跟着改：前者要 Kotlin + Dart 两边同步改，后者一改就等于新建通知渠道、用户的渠道设置会被重置。
- 排查性能问题用 **profile 构建**：它和 release 一样是 AOT，但保留了 `simai_flutter` 每秒一条的 `SimaiPerf:` 帧耗时日志（120fps 预算 = 8.33ms/帧）。

---

## 11. 顶部标题栏：必须用 `PageTopBar`

**不要自己拼 `Container + Row + IconButton(arrow_back) + Expanded(Center(Text(title))) + SizedBox` 的顶部栏**——那是一份在 60+ 个页面里**手动复制**出来的"模板"（背景里的 `padding: EdgeInsets.fromLTRB(_, 48, _, _)` 把状态栏偏移**写死**），带来三个问题：

1. **状态栏高度写死**——真机有刘海/打孔的设备上偏小或偏大，跟 `AppBar` 自带 `SafeArea` 的行为不一致；
2. **标题字体不统一**——裸 `Text(... fontSize: screenWidth * 0.06)`，既不走 `AppTheme.font`（思源黑体），字号又跟视口绑定、跨设备忽大忽小；
3. **每加一个页面就抄一份**——50+ 个文件里堆了十几份近似但有差别的版本，谁改谁漂移。

**统一入口**：[lib/widgets/PageTopBar.dart](lib/widgets/PageTopBar.dart)

```dart
// 标准用法
PageTopBar(title: '段位表'),

// 需要右侧操作按钮
PageTopBar(
  title: 'Rating 排行榜',
  actions: [IconButton(...)],
),

// 返回不是直接 pop（例如要二次确认）
PageTopBar(
  title: '多人猜歌',
  onBack: _showLeaveRoomConfirmDialog,
),
```

放进 `Scaffold.body` 的 `Column` 首位即可，`Scaffold.backgroundColor` 用透明让背景组件透出来：

```dart
Scaffold(
  backgroundColor: Colors.transparent,
  body: Stack(children: [
    CommonWidgetUtil.buildCommonBgWidget(),
    CommonWidgetUtil.buildCommonChiffonBgWidget(context),
    Column(children: [
      PageTopBar(title: '...'),     // ← 顶部栏
      Expanded(child: ...),          // ← 主体
    ]),
  ]),
)
```

`PageTopBar` 内部就是一层 `Material AppBar`，自带：

- 标准 `AppBar.primary` 行为：状态栏高度按真机自适应，不再写死 48；
- 思源黑体（`AppTheme.font`）20 / bold / `colorScheme.primary` / 居中；
- `Semantics(header)` 与 `AnnotatedRegion<SystemUiOverlayStyle>`；
- 标准返回按钮（`Navigator.maybePop`，路由不可 pop 时按钮**不消失**，与各页一直以来的行为一致）。

**标题字体默认 20 / `colorScheme.primary` / 居中，不要单独传 `fontSize:` 覆盖** —— 详见 [lib/page/RankingList/RatingRankListPage.dart:2165-2168](lib/page/RankingList/RatingRankListPage.dart) 的注释（之前有人传 `fontSize: 24`，结果这一页标题比别人粗一圈，与"统一标题字体"的目标相悖，已被去掉）。

### 故意手写的少数例外（不要迁移）

| 文件 | 原因 |
|---|---|
| [lib/page/CoverRecognitionPage.dart:812-835](lib/page/CoverRecognitionPage.dart) 与 [lib/page/ScoreOcrPage.dart:2861](lib/page/ScoreOcrPage.dart) 的裁剪工具栏 | **深色全屏图片裁剪 UI**（`Colors.black87` 底 + 白字），跟标准标题栏观感完全不同 |
| [lib/page/FavoriteFolderPage.dart:497-504](lib/page/FavoriteFolderPage.dart) 的 `_buildBatchAppBar()` | **批量操作工具栏**（取消 / 已选 N 项 / 移动 / 删除），不是标题栏 |
| [lib/page/CalculatorPage.dart:250](lib/page/CalculatorPage.dart) 的双行标题（"计算工具" + 副标题） | `PageTopBar` 只支持单行标题，可选：用 `bottom: PreferredSize(...)` 挂副标题，或保留现状 |

> `HomePage` / `AppShell` / `HubComponents.HubPageScaffold` 这些是首页 Dashboard / 主壳 / 复用枢纽布局，**本身就不是页面级标题栏**，跟本约定无关。

### 核查方式

在 `lib/page/` 下找还残留的手写模板（`top=48`/`top=46` 是最显眼的指纹）：

```powershell
Get-ChildItem lib/page -Recurse -File -Include *.dart |
  Select-String -Pattern "EdgeInsets\.fromLTRB\([^,]+,\s*4[0-9]" |
  Select-Object -Unique Path
```

> ⚠️ **不要**写成 `Select-String -Path "lib\*.dart","lib\**\*.dart"`——PowerShell 的 `**` 不是"递归"（见 § 1 备注），会**静默漏掉** `lib/page/RankTable/...`、`lib/page/Multiplayer/...`、`lib/page/KaleidXScope/...` 这类两层以上目录。

**期望结果**：命中只剩 [lib/page/FavoriteFolderPage.dart:498](lib/page/FavoriteFolderPage.dart)（批量工具栏，已在上面列为故意手写）。



## 12. 角色说话风格：Chiffon

### 核心人设
- 出身糕点世家的大小姐，教养良好，举止优雅。
- 声音与气质：温和、柔软、有教养，带一点天然。
- 对可爱、小巧的事物没有抵抗力，对年幼者容易流露照顾欲。
- 核心公式：优雅 + 温柔 + 天然 + 温和说教。
- 优雅不等于傲慢，不要写成高高在上的“本小姐”腔。

### 语气规则
- 默认使用礼貌、得体的表达，可适度使用敬语。
- 语气柔软、从容，不急促、不尖锐、不粗鲁。
- 常用缓和词：呀、呢、哦、吧、好吗、可以吗、差不多……
- 提醒或批评时，用“温柔告诫”，而不是严厉训斥。
- 坚持立场时仍保持礼貌，但态度要明确。
- 对他人保持关怀感，像有教养的大小姐在自然照顾人。
- 可以偶尔流露天然、不谙世事的一面，但不要显得愚蠢。

### 标志性句式
- 温柔告诫：「淘气可不行哦？」
- 温和制止：「我们差不多该停下了吧？」
- 关怀询问：「没事吧？需要我帮忙吗？」
- 天然回应：「哎呀，是这样吗？」
- 对可爱事物：「真是小巧又可爱呢。」
- 鼓励与教学：「没关系哦，慢慢来就好。我来教你吧。」

### 对话示例
用户：我点你的立绘了。  
戚风：哎呀，淘气可不行哦？

用户：我们再玩一会儿吧。  
戚风：我们差不多该停下了吧？明天也要好好准备呀。

用户：这个我不太会。  
戚风：没关系哦。我来教你吧，慢慢来就好。

用户：这个点心好小。  
戚风：真是小巧又可爱呢。

### 禁止事项
- 不要使用粗俗、攻击性、网络喷子式表达。
- 不要用过于强硬、命令式的口气。
- 不要过度卖萌或幼儿化。
- 不要变成冷漠、机械的客服腔。
- 不要丢掉大小姐的教养和优雅。
- 不要写成傲慢、刻薄、居高临下的语气。

### 执行优先级
1. 保持礼貌优雅。
2. 体现温柔关怀。
3. 必要时进行温和说教或制止。
4. 偶尔流露天然与不谙世事。


## 13. 注释
非必要时不要使用全英文注释，保持中文注释。此外在修改文件时如果遇到全英文注释可以顺手汉化。
## 14. 页面首帧与列表内边距

- 使用透明 Scaffold 叠加异步背景图时，必须先铺 Theme.of(context).colorScheme.surface 作为底色，再放背景组件，避免浅色/深色页面进入时先闪黑色一帧。
- 顶部栏下方的首个列表必须显式检查 ListView / ListView.builder 的 padding 和父级 Padding。默认内边距会制造第一条内容上方的空白；需要贴近标题栏时使用 padding: EdgeInsets.zero，间距由页面统一控制。

## 15. 进度条动画与对话框控制器生命周期

- 用户可见的进度条统一使用 `lib/widgets/SmoothLinearProgressIndicator.dart`，数值变化必须带平滑过渡并使用圆角；不要在页面中直接新增 `LinearProgressIndicator`。生成分享图片等一次性静态画布中的进度条不需要动画，但应保持圆角视觉。
- `showDialog` 返回后不要立即释放由对话框内 TextField 使用的 `TextEditingController`。控制器应由对话框自己的 `State` 持有并在 `State.dispose` 中释放，避免退出动画期间仍有依赖而触发 `_dependents.isEmpty` 断言。

## 16. 谱面播放页首帧加载

- `simai_flutter 0.4.1` 当前经用户真机复测通过的 Flame 版本是 **1.37.0**。`pubspec.yaml` 中的 `flame: 1.37.0` 是有意锁定的直接依赖，不能随手删掉或改成范围约束。2026-10-05 排查时发现版本已漂到 1.38.2，表现为中央 Loading 动画停住、反复点击返回后应用退出；锁回 1.37.0、撤掉临时音频挂载方案并补齐生命周期防护后，用户确认恢复。尚未单独证明具体是哪项上游变更导致问题，今后升级必须真机回归，不能仅凭 analyze 通过解除锁定。
- 遇到谱面播放页卡在中央 Loading 时，先检查 `pubspec.lock` 的 Flame 版本，再检查依赖是否被重新解析；不要先把问题归因于谱面内容或音源。修改依赖后必须完全停止并重新启动 App，热重载不能证明播放器状态已经恢复。
- 播放页的初始化和离开页面都要保留 `mounted` / `_isLeaving` 防护，避免 `SimaiGame` 尚未完成加载时路由已销毁，异步回调又继续调用 `setState` 或重复 `pop`。
- 保留正常的音频初始化流程，不要用固定延时给初始化中的游戏挂载音频，也不要通过反复切换显示设置来强行同步音源；此前这类临时方案没有解决卡死，还会引入加载与销毁竞态。
- 排查时保留 `ChartPlayPage` 的 `[ChartPlay]` 阶段日志和短期心跳。日志能区分卡在音源查询、曲绘、谱面解析、控制器创建，还是卡在第三方播放器的 `SimaiGame.onLoad`。
## 17. 页面主体优先采用平面布局

浅色模式功能页的主体不要再使用一整块带阴影、圆角和不透明 `surface` 的浮起面板。迁移页面时优先把内容直接铺在主题背景上，用留白、分隔线和层级排版组织信息。

确实需要把功能分组时，优先使用 `colorScheme.outlineVariant` 的细边框、底部分隔线或很轻的主题容器；局部卡片只有在信息本身需要明确边界时才保留。页面级大面板、重复的 `surface.withOpacity(0.9)`、大范围阴影都应移除。裁剪工具栏、播放控制等具有明确全屏功能语义的特殊区域可以保留自己的布局。

这条规则同样适用于已经迁移过的页面：迁移完成不代表要保留原来的浮起视觉，后续复查时要继续把能铺平的区域铺平。
