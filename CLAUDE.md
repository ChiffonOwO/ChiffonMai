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

## 5. 谱面播放页（ChartPlayPage）两个坑

### 5.1 高刷新率

Flutter 引擎**从不**调用 Android 的 `Surface.setFrameRate()`（[flutter/flutter#160952](https://github.com/flutter/flutter/issues/160952)），所以系统默认按 60Hz 合成，只在触摸后短暂升到 120Hz 再衰减——表现为「进页面几秒 120 → 掉 60 → 一交互又回 120」。

由 `lib/utils/RefreshRateUtil.dart` + `MainActivity` 的 `com.example.app/display` 通道解决。**目标刷新率必须取自实际选中的 display mode**，不能用全局最高值（同分辨率约束可能让 120Hz 的 mode 落选）。

### 5.2 侧边栏设置持久化

`lib/service/ChartPlaySettingsStore.dart`

- 控制器是 `ChangeNotifier`，侧边栏每改一次都会 `notifyListeners` → 挂监听 + 600ms 防抖落盘
- **防抖只推迟写盘，不推迟记录**：改动要同步 `remember()` 进内存，否则中途重建控制器会读到过期值
- **`_loadChart()` 必须先 `await ChartPlaySettingsStore().load()` 再建控制器**，否则会拿默认值建控制器、退出时再写回默认值，**把用户设置静默清空**

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

---

## 7. 颜色与主题

- 边框、分隔线、容器描边统一用 `Theme.of(context).colorScheme.outlineVariant`（项目的 `cardTheme` / `dividerTheme` 用的就是它）。
- **不要用写死的中性灰做边框**。历史遗留的 `AppColors.tableBorder(brightness)` 虽然按明暗分支，但两支都是硬编码灰（浅色 `grey.shade300` 对浅底只有约 1.26:1，几乎看不见；深色 `grey.shade700` 却有 3:1），**两边严重不均衡**，而且不跟随用户自定义主题色。新代码别再用它。
- 需要新颜色时加到 `lib/utils/AppTheme.dart` 的 `AppColors`，并接受 `Brightness` 参数。

---

## 8. 验证方式（重要）

**当前开发环境没有连接安卓设备，任何改动都无法真机验证。**

### 默认：只跑 analyze，不要构建 APK

用户已明确要求：**改完只需要跑 `flutter analyze`，不需要 `flutter build apk`**。
打包耗时几分钟且用户自己会构建，每次改动都构建纯属浪费。

```powershell
flutter analyze --no-pub          # 必须零 error
```

### 例外：改动碰到 `android/`（Kotlin / XML）时必须构建

**`flutter analyze` 只看 Dart，完全覆盖不到 Kotlin 和 AndroidManifest。**
本项目实际踩过：`MainActivity.kt` 里一个 `Uri?` 与 `Uri` 的类型不匹配，
`flutter analyze` 全绿，**只有 Gradle 构建才报出来**。

所以：

- 只改 Dart → 跑 analyze 即可，**不要构建**
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

## 9. 其它

- release 构建目前用 debug 签名（`android/app/build.gradle.kts`），所以 `flutter build apk --release` 可直接安装。
- `applicationId` = `com.example.my_first_flutter_app`，但 App 显示名是 `ChiffonMai`。
- 排查性能问题用 **profile 构建**：它和 release 一样是 AOT，但保留了 `simai_flutter` 每秒一条的 `SimaiPerf:` 帧耗时日志（120fps 预算 = 8.33ms/帧）。
