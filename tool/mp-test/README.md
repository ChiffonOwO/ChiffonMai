# 多人猜歌游戏 —— 测试资产

## 这些脚本在测什么

多人猜歌（`lib/page/Multiplayer/`）是**前后端协议耦合**的功能：客户端发
`{action, payload}`，服务端回报文。两边字段对不上时，静态检查（`flutter analyze`）
一条都发现不了，真机上的表现还往往是「倒计时不对」「提示一直是空的」这类不报错的怪象。

所以这里的思路是**在协议层端到端测**：用 Node 模拟 App 的 WebSocket 行为，
直接跟服务端对话，验证九种模式（`info` / `cover` / `blurred` / `audio` / `alia` /
`letters` / `flash` / `tileReveal` / `chartPeek`）的完整对局流程。

## 怎么跑

```powershell
# 1) 先起本地测试服（默认 3999）
node tool/mp-test/mp_harness.js

# 2) 另开一个终端跑验证
node tool/mp-test/mp_verify.js       # 服务端修复验证（69 项）
node tool/mp-test/mp_regress.js      # 回归补充：刷分 / 计时 / timeLimit（9 项）
node tool/mp-test/mp_guess_rules.js  # 计分与结算规则：投降 / 次数耗尽 / 独占计分 / 胜负（23 项）
$env:MP_MODE='letters'; node tool/mp-test/mp_lifecycle.js   # 单模式完整生命周期
node tool/mp-test/mp_anti_cheat.js   # 防刷分验证（打印本回合得分）

# 3) Dart 侧解析契约测试
flutter test test/multiplayer_payload_test.dart
```

也可以直接指向其它服务器（如线上）：

```powershell
node tool/mp-test/mp_verify.js ws://chiffonmai.cloud:3000
```

## 关于 mp_harness.js

它**不是** `server.js` 的副本，而是运行时从 `server/server.js` 派生出来的测试服：
读源文件 → 打上「跳过 MySQL / Redis / 拟合定数缓存 + 换端口 + 敏感项改读环境变量」
几处测试专用改动 → 写到 `server/.mp_harness.runtime.js` 再启动。

这么做是为了避免**副本漂移**：如果这里是 server.js 的一份拷贝，改了 server.js
却忘了同步，测试会对着旧逻辑全绿 —— 这种假绿比不测更危险。派生失败时脚本会直接退出。

注意 `server/server.js` 被 `server/.gitignore` 排除（含 client_secret、数据库口令），
所以换机器后需要先把 server.js 放回 `server/` 才能跑这些测试。

## 文件职责

| 文件 | 说明 |
|---|---|
| `mp_harness.js` | 派生并启动本地测试服（端口 3999） |
| `mp_verify.js` | 服务端修复验证：定数筛选 / 精确判定 / 计时计分 / 拒绝回合后提交 / letters 全流程 / 九模式冒烟 + 模式专属参数（含 flash/tileReveal/chartPeek 的越界夹取与难度池清洗） |
| `mp_lifecycle.js` | 单模式完整生命周期：开局 → 各回合 → 游戏结束 → 重开（`MP_MODE` 选模式） |
| `mp_regress.js` | 回归补充：重复提交不刷分、`timeLimit` 随报文下发、`timeSpent` 真实计时 |
| `mp_guess_rules.js` | 计分与结算规则：投降拦截 / 共享次数耗尽即结束 / letters 每首只给最先猜中者 / 胜负与平局 |
| `mp_anti_cheat.js` | 单独复现/验证「同一首重复计入分数」的防刷分修复 |
| `mp_capture.js` | 抓取真实服务端报文 → `test/fixtures/mp_payloads.json`（Dart 契约测试的输入） |
| `mp_ws.js` | 解析 `ws` 依赖（依赖装在 `server/node_modules`） |
| `server.fix.patch` | 服务端修复补丁（因为 server.js 不进版本库，用它把改动带到部署环境） |

## 服务端修复怎么部署

`server/server.js` 不在版本库里，所以上面的服务端修复**不会随 git 提交**。
部署时二选一：

```powershell
# 方式 A：把补丁应用到部署用的 server.js
cd server
git apply tool/mp-test/server.fix.patch     # 或在项目根用 --directory=server

# 方式 B：直接用修好的 server.js 覆盖部署环境那份（注意保留对方的环境变量/密钥）
```

补丁基于 `server/server.js.bak-20260914-223514` 生成，已验证可 `git apply --check` 通过。

### 改完 server.js 后必须重新生成补丁

补丁不会自动跟着 `server.js` 走。改完服务端代码，**一定要重新生成并自检**，
否则部署环境拿到的还是旧逻辑（测试却全绿 —— 因为测试直接读 `server.js`）。

```powershell
# 在临时目录里以 bak 为基线重新 diff（不要在项目内建仓，避免污染工作区）
$tmp = Join-Path $env:TEMP ("pgen_" + [guid]::NewGuid().ToString("N").Substring(0,8))
$base = Join-Path $tmp 'base'; New-Item -ItemType Directory -Path $base -Force | Out-Null
Copy-Item server/server.js.bak-* (Join-Path $base 'server.js')
Push-Location $base; git init -q .; git config core.autocrlf false
git add server.js; git -c user.email=a@b -c user.name=c commit -q -m base; Pop-Location
Copy-Item server/server.js (Join-Path $base 'server.js') -Force
Push-Location $base; git config core.autocrlf false
git diff --no-color --output=(Join-Path $tmp 'new.patch'); Pop-Location
```

两个必须注意的坑（都踩过）：

1. **不要用 PowerShell 的 `>` 重定向写补丁**。它会写成 UTF-16，`git apply` 直接报
   `No valid patches in input`。用 `git diff --output=` 或 `[System.IO.File]::WriteAllText`
   （显式 UTF-8 无 BOM）。
2. **行尾必须统一**。`server.js` 历史上是 CRLF，但混进过裸 LF；`apply_patch` 新增的行
   是 LF，会让补丁与工作区因行尾差异而哈希不一致。改完先归一化成纯 CRLF 再生成补丁：

   ```powershell
   $p='server/server.js'
   $t=[System.IO.File]::ReadAllText($p,[System.Text.Encoding]::UTF8)
   [System.IO.File]::WriteAllText($p, ($t -replace "`r`n","`n") -replace "`n","`r`n",
     (New-Object System.Text.UTF8Encoding($false)))
   ```

   归一化后 `node --check server/server.js` 必须通过，再生成补丁。

生成后**务必验证补丁能精确重建 `server.js`**（比对 SHA256），别只看 `git apply` 退出码
—— 行尾差异会让 `git apply` 成功但内容不一致：

```powershell
# 用 bak + 新补丁重放，SHA256 应与当前 server.js 完全相同
```

## 已知边界

- 这些测试只覆盖**协议与逻辑**，不覆盖真机 UI 渲染（本项目开发环境无安卓设备）。
- `cover` / `blurred` / `audio` 三种模式的**画面呈现**（截取区域、模糊程度、音频播放）
  依赖客户端本地曲绘与音源，协议测试只能确认「参数正确下发、开局正常」。
- `flash` / `tileReveal` / `chartPeek` 同样只在协议层验证「参数回传 + 越界夹取」。
  它们的题面完全由客户端渲染，且必须**各端一致**：
  - `flash`：时长来自房间设置（不参与随机），回合开始闪现一次后消失。
  - `tileReveal`：揭示顺序由 `GameSeedUtil.generateTileRevealOrder`（房间+回合+曲目）
    确定性洗牌，切块数与揭示间隔来自房间设置。
  - `chartPeek`：难度用 `eligibleInotesFor`（难度池 ∩ 房间定数范围）筛出后再用
    `GameSeedUtil.pickDeterministic` 挑一个，片段窗口用 `generateClipWindow`
    （两者都加盐隔离随机源）。谱面取自**客户端本地 maidata 缓存**，本机没有时用
    `MaidataManager.fetchMaidataForSongIds` 按需拉一次；服务端不下发谱面文本，
    因此这一模式的真机表现无法只靠协议测试覆盖。
- `audio` 模式的音源 id 规则（`水鱼 id % 10000`）是**线上实测**得出的结论，
  记录在 `lib/page/Multiplayer/GameRoomPage.dart` 的 `toLxnsMusicId` 注释里。
