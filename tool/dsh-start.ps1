<#
.SYNOPSIS
    检查 DeepSeek Harness 是否有更新；有则更新，然后启动。

.DESCRIPTION
    本机 DSH 是「npx 缓存安装」而非全局安装 —— 这类安装**不会自己更新**，
    所以需要一个显式检查 + 更新的入口。

    流程：
      1. npm view 查目标通道版本（纯注册表查询，不下载包体）
      2. 定位 npx 缓存槽，读版本 + 校验安装完整性
      3. 有差异或安装残缺 → 清掉缓存槽 → 启动时 npx 重新安装
         无差异           → 直接启动
      4. 启动 dsh web

    ⚠ 四条来自实测的约束（改动前先读，每条都是踩过的坑）：

    (a) 有更新时必须先删缓存槽。
        npx 按 spec 哈希出固定目录并长期复用，不会因为远端发了新版就自己失效，
        所以只靠 `npx pkg@latest` 可能仍命中旧目录。

    (b) 正在运行的 DSH **绝对不能**删它的缓存槽。
        实测：`Remove-Item -Recurse -Force` 遇到被进程锁住的 libvips-42.dll 时，
        会**删掉数万个文件之后才失败**（实测把 node_modules\@deepseek-ai 整个删空），
        把正在使用的安装搞成残缺状态。
        所以本脚本：目标槽正被占用时**一律不删不装**，只提示你关掉 DSH 后重跑。
        这条保护对 -Repair 同样生效。

    (c) 「是否已安装」不能只看 package.json。
        被 (b) 那种半途失败破坏过的槽会**缺 package.json 和 lib\bin.js**，
        但仍留着上万个其它文件。只看 package.json 会把坏槽判成「未安装」，
        于是脚本以为要全新安装，实际启动时却仍可能命中这个坏槽。

    (d) 一个 spec 对应一个槽，且槽归属只能从槽根的 package.json 里读。
        槽根 `package.json` 的 `_npx.packages` 数组记录了它是为哪个 spec 建的。
        注意 `@deepseek-ai/dsh` 与 `@deepseek-ai/dsh@latest` **是两个不同的槽**，
        所以「正在运行的槽」和「本脚本要操作的槽」可能不是同一个。

.PARAMETER Channel
    更新通道：latest / next / alpha。默认 latest。

.PARAMETER Port
    监听端口。传 0 让系统自动挑空闲端口。默认 3080。

.PARAMETER NoOpen
    不自动打开浏览器。

.PARAMETER CheckOnly
    只报状态、不启动、不改动。

.PARAMETER SkipUpdateCheck
    跳过更新检查，直接用本地缓存启动（离线或想快速启动时用）。

.PARAMETER Repair
    无视版本比较，强制重装：清掉缓存槽后由 npx 重新安装。
    用于版本号看不出来的损坏（缺文件、装到一半失败）。
    仍遵守约束 (b)：正在运行中不会删，会提示先关闭。

.PARAMETER Slot
    明确指定要操作的缓存槽（目录名 / 哈希）。留空 = 自动挑选。
    用 -CheckOnly 先看一眼各槽的哈希与状态，再决定修哪个。

.EXAMPLE
    .\dsh-start.ps1
    按 latest 检查更新（需要时更新）后启动。

.EXAMPLE
    .\dsh-start.ps1 -CheckOnly
    列出所有 DSH 缓存槽的状态（含损坏的），不做任何改动。

.EXAMPLE
    .\dsh-start.ps1 -Slot 1e7f6d9597241db0 -Repair
    销毁指定的损坏槽，让 npx 重新安装（需先关闭正在运行的 DSH）。
#>
[CmdletBinding()]
param(
    [ValidateSet('latest', 'next', 'alpha')]
    [string]$Channel = 'latest',

    [int]$Port = 3080,

    [switch]$NoOpen,
    [switch]$CheckOnly,
    [switch]$SkipUpdateCheck,
    [switch]$Repair,
    [string]$Slot
)

$ErrorActionPreference = 'Stop'

$Package = '@deepseek-ai/dsh'
$Spec = "$Package@$Channel"
$PkgPathInSlot = $Package.Replace('/', '\')
$NpxRoot = Join-Path $env:LOCALAPPDATA 'npm-cache\_npx'

# 健康安装里 @deepseek-ai 下的子包数量级（实测 240 个）。
# 明显低于此值即视为安装残缺 —— 只看 package.json 会漏掉被删残的槽（约束 c）。
$MinDeepseekSubpackages = 50

function Write-Step([string]$T) { Write-Host "==> $T" -ForegroundColor Cyan }
function Write-Ok([string]$T) { Write-Host "    $T" -ForegroundColor Green }
function Write-Note([string]$T) { Write-Host "    $T" -ForegroundColor Yellow }
function Write-Bad([string]$T) { Write-Host "    $T" -ForegroundColor Red }

<#
    列出 npx 缓存里所有属于本包的槽（含被删残的）。
    归属靠槽根 package.json 的 _npx.packages 判断（约束 d）——
    不看 node_modules 里的包目录，因为坏槽的那个目录可能已被整个删掉。
#>
function Get-CacheSlots {
    $slots = @()
    if (-not (Test-Path $NpxRoot)) { return $slots }

    foreach ($dir in Get-ChildItem $NpxRoot -Directory -ErrorAction SilentlyContinue) {
        $rootPkg = Join-Path $dir.FullName 'package.json'
        if (-not (Test-Path $rootPkg)) { continue }

        $specs = @()
        try {
            $rj = Get-Content $rootPkg -Raw | ConvertFrom-Json
            if ($rj._npx -and $rj._npx.packages) { $specs = @($rj._npx.packages) }
        } catch { continue }

        # 该槽是否是为本包建的
        $mine = $false
        foreach ($s in $specs) {
            if ($s -eq $Package -or $s -like "$Package@*") { $mine = $true; break }
        }
        if (-not $mine) { continue }

        $pkgDir = Join-Path $dir.FullName "node_modules\$PkgPathInSlot"
        $pkgJson = Join-Path $pkgDir 'package.json'
        $entry = Join-Path $pkgDir 'lib\bin.js'

        $version = $null
        if (Test-Path $pkgJson) {
            try { $version = (Get-Content $pkgJson -Raw | ConvertFrom-Json).version } catch { }
        }

        $subCount = 0
        $dsDir = Join-Path $dir.FullName "node_modules\@deepseek-ai"
        if (Test-Path $dsDir) {
            $subCount = (Get-ChildItem $dsDir -Directory -ErrorAction SilentlyContinue | Measure-Object).Count
        }

        $entryOk = Test-Path $entry
        $slots += [pscustomobject]@{
            Path      = $dir.FullName
            Hash      = $dir.Name
            Specs     = ($specs -join ',')
            Version   = $version
            EntryOk   = $entryOk
            SubCount  = $subCount
            Complete  = ($null -ne $version) -and $entryOk -and ($subCount -ge $MinDeepseekSubpackages)
            FileCount = (Get-ChildItem $dir.FullName -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object).Count
        }
    }
    return $slots
}

<#
    自动挑一个要操作的槽，优先级：
      1. 正被运行中的 DSH 使用的那一个（通常也是用户实际会启动的）
      2. spec 与本次 $Spec 完全匹配的
      3. 第一个完整的
      4. 第一个
#>
function Select-Slot($slots, $runningPaths) {
    if ($slots.Count -eq 0) { return $null }
    $t = $slots | Where-Object { $runningPaths -contains $_.Path } | Select-Object -First 1
    if ($t) { return $t }
    $t = $slots | Where-Object { $_.Specs -eq $Spec } | Select-Object -First 1
    if ($t) { return $t }
    $t = $slots | Where-Object { $_.Complete } | Select-Object -First 1
    if ($t) { return $t }
    return $slots | Select-Object -First 1
}

function Get-RemoteVersion {
    $raw = & npm view "$Package@$Channel" version --json 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($raw)) { return $null }
    return ($raw | ConvertFrom-Json | Out-String).Trim()
}

<#
    返回正在运行的 DSH 进程（含它用的缓存槽路径）。
    命令行里带 `_npx\<hash>\node_modules`，据此判断某槽是否被占用。
#>
function Get-RunningDsh {
    $procs = Get-CimInstance Win32_Process -Filter "Name='node.exe'" -ErrorAction SilentlyContinue
    $running = @()
    foreach ($p in $procs) {
        $cl = $p.CommandLine
        if (-not $cl) { continue }
        if ($cl -notmatch '_npx' -or $cl -notmatch 'deepseek-ai') { continue }
        $slotPath = $null
        $m = [regex]::Match($cl, '_npx\\[^\\]+')
        if ($m.Success) { $slotPath = Join-Path (Split-Path $NpxRoot -Parent) $m.Value }
        $running += [pscustomobject]@{ Pid = $p.ProcessId; Slot = $slotPath }
    }
    return $running
}

# ------------------------------------------------------------------ 检测

Write-Step "检查 DSH 状态（通道：$Channel）"

$slots = @(Get-CacheSlots)
$running = @(Get-RunningDsh)
$runningPaths = @($running | Where-Object { $_.Slot } | ForEach-Object { $_.Slot })

if ($running.Count -gt 0) {
    Write-Note "运行中：PID $(($running.Pid) -join ', ')"
    foreach ($r in $running) {
        if ($r.Slot) { Write-Note "  使用槽 $((Split-Path $r.Slot -Leaf))" }
    }
}

if ($slots.Count -eq 0) {
    Write-Ok "本地 : (未安装任何 DSH 槽)"
} else {
    foreach ($s in $slots) {
        $inUse = $runningPaths -contains $s.Path
        $mark = if ($inUse) { '  [正在使用]' } else { '' }
        if ($s.Complete) {
            Write-Ok "$($s.Hash)  $($s.Version)  spec=$($s.Specs)$mark"
        } else {
            Write-Bad "$($s.Hash)  安装不完整  spec=$($s.Specs)$mark"
            Write-Note "    版本=$($s.Version)  入口=$(if($s.EntryOk){'有'}else{'缺'})  @deepseek-ai子包=$($s.SubCount)  文件数=$($s.FileCount)"
        }
    }
}

# 目标槽：-Slot 指定优先，否则自动挑
$target = $null
if ($Slot) {
    $target = $slots | Where-Object { $_.Hash -ieq $Slot } | Select-Object -First 1
    if (-not $target) {
        Write-Bad "指定的槽 '$Slot' 不属于 $Package（用 -CheckOnly 看可用槽）"
        return
    }
} else {
    $target = Select-Slot $slots $runningPaths
}

$targetInUse = $false
if ($target) { $targetInUse = $runningPaths -contains $target.Path }

if ($target) {
    Write-Note "本次操作对象：$($target.Hash)"
}

# ---------------------------------------------------------------- 是否需要更新

$remote = $null
$needUpdate = $false
$reason = ''

if ($Repair) {
    $needUpdate = $true
    $reason = "强制重装指定槽 $($target.Hash)（-Repair）"
}
elseif ($SkipUpdateCheck) {
    Write-Note "已跳过更新检查（-SkipUpdateCheck）"
}
else {
    try { $remote = Get-RemoteVersion } catch { }

    if ([string]::IsNullOrWhiteSpace($remote)) {
        Write-Note "拿不到远端版本（可能离线），跳过版本比较"
        if ($target -and -not $target.Complete) {
            $needUpdate = $true
            $reason = "安装不完整，需要重装"
        }
    }
    else {
        Write-Ok "远端 : $remote"
        if ($null -eq $target) {
            $needUpdate = $true
            $reason = "本地未安装，将安装 $remote"
        }
        elseif (-not $target.Complete) {
            $needUpdate = $true
            $reason = "安装不完整，需要重新安装 $remote"
        }
        elseif ($target.Version -ne $remote) {
            $needUpdate = $true
            $reason = "发现更新：$($target.Version) -> $remote"
        }
        else {
            Write-Ok "已是最新，无需更新"
        }
    }
}

# ------------------------------------------------- 能否安全执行（约束 b）

$canUpdate = $true
if ($needUpdate) {
    Write-Step $reason

    if ($targetInUse) {
        # 正在用的槽不能删：实测会删掉数万文件后才失败，把安装搞残
        $canUpdate = $false
        Write-Bad "这份安装正被运行中的 DSH 使用，无法安全改动。"
        Write-Note "请先关闭正在运行的 DSH，然后重新执行本脚本。"
        Write-Note "本次不再改动，直接启动现有版本。"
    }
}

if ($needUpdate -and $canUpdate -and $target) {
    try {
        Remove-Item $target.Path -Recurse -Force -ErrorAction Stop
        Write-Ok "已清除缓存槽 $($target.Hash)（启动时 npx 会重新安装）"
    } catch {
        $canUpdate = $false
        Write-Bad "清除缓存失败：$($_.Exception.Message)"
        Write-Note "为避免再留下残缺安装，本次不重新安装，直接启动现有版本。"
    }
}

if ($CheckOnly) {
    Write-Step "仅检查模式，不启动"
    return
}

# ------------------------------------------------------------------ 启动

$dshArgs = @('--yes', $Spec, 'web', '--port', $Port)
if ($NoOpen) { $dshArgs += '--no-open' }
$openHint = if ($NoOpen) { ' --no-open' } else { '' }

Write-Step "启动 DSH：npx $Spec web --port $Port$openHint"
Write-Host ""

& npx @dshArgs
exit $LASTEXITCODE
