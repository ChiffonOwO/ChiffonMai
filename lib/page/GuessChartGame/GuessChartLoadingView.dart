import 'package:flutter/material.dart';

import '../../manager/DivingFish/MaimaiMusicDataManager.dart';
import '../../service/ConnectivityService.dart';

/// 单人猜歌页「开局取曲」失败时的兜底视图。
///
/// 背景（真实故障）：所有单人猜歌页原先都是
///
/// ```dart
/// _targetSong = await XxxService.randomSelectSong(...);
/// if (_targetSong != null) { setState(() => _isGameStarted = true); }
/// ```
///
/// **没有 else 分支**。一旦抽曲返回 null（曲库缓存为空 —— 例如恢复备份后
/// `cachedSongs` 被清掉、或首次拉取失败、或筛选条件过严），
/// `_isGameStarted` 永远是 false，页面就永久停在 `CircularProgressIndicator`
/// 上：没有报错、没有重试，用户只能杀进程。曲库为空时 App 重启也救不回来，
/// 因为首页的自动初始化有 7 天冷却期（见 HomePage._InitInterval）。
///
/// 唯一幸免的是谱面片段猜歌 —— 它每条失败路径都会把 `_isGameStarted` 置 true
/// 并显示 `_unavailableReason`，所以只有它「正常进入」。
///
/// 现在各页统一采用**谱面片段猜歌那套思路**（见 [GuessChartNoSongNotice]）：
/// 抽不到曲也照常进入游戏界面，只把题面区换成原因说明，
/// 于是搜索框、规则 / 设置 / 刷新 / 排序 / 投降全都还在。
/// 本组件只留给「首次取曲还没结束」的加载态使用（`message` 为空）。
class GuessChartLoadingView extends StatefulWidget {
  /// 抽曲失败时的提示文案。**空字符串 = 首次取曲还没结束**，
  /// 此时只显示转圈，不显示任何按钮。
  final String message;

  /// 「重新拉取曲库」回调。返回 true 表示这次重试已经解决了问题
  /// （调用方负责重新抽曲并把 `_isGameStarted` 置 true）。
  final Future<bool> Function()? onRetry;

  /// 「打开设置」回调（可选）。各页传「打开设置对话框 + 改完重开一局」。
  ///
  /// 与 [onRetry] 不是二选一：曲库为空时两个按钮都给 ——
  /// 既能补拉数据，也能顺手放宽条件。
  final Future<bool> Function()? onOpenSettings;

  /// 首次取曲期间显示的小字提示（可选，例如歌曲片段页的随机加载小贴士）。
  final String? loadingTip;

  const GuessChartLoadingView({
    super.key,
    required this.message,
    this.onRetry,
    this.onOpenSettings,
    this.loadingTip,
  });

  /// 曲库缓存为空时的文案 —— 这是最需要自救按钮的一种失败。
  static const String emptyLibraryMessage = '曲库缓存为空，暂时抽不出曲目';

  static const String filterTooStrictMessage = '当前筛选条件抽不到曲目，请在设置中放宽条件';

  /// 此刻曲库缓存是否为空（用于区分「没数据」和「筛得太死」）。
  ///
  /// 只看缓存，不发网络请求 —— 失败文案要立刻出来，
  /// 真正去拉数据是用户点「重新拉取曲库」之后的事。
  static Future<bool> isSongLibraryEmpty() async {
    return !await MaimaiMusicDataManager().hasCachedData();
  }

  /// 重新拉取曲库缓存。true = 已经拿到曲库（可以再抽一次）。
  ///
  /// 用 `forceNetwork: true`：失败态下缓存时间戳不可信（可能刚被清掉、
  /// 也可能是旧的），只有强刷才能保证「点一下真的去拿了」。
  static Future<bool> refreshSongLibrary() async {
    if (!await ConnectivityService().hasConnection()) {
      return false;
    }
    return MaimaiMusicDataManager().fetchAndUpdateMusicData(forceNetwork: true);
  }

  @override
  State<GuessChartLoadingView> createState() => _GuessChartLoadingViewState();
}

class _GuessChartLoadingViewState extends State<GuessChartLoadingView> {
  bool _retrying = false;
  bool _openingSettings = false;

  Future<void> _handleRetry() async {
    if (_retrying) return;
    final onRetry = widget.onRetry;
    if (onRetry == null) return;

    setState(() => _retrying = true);
    bool solved = false;
    try {
      solved = await onRetry();
    } catch (e) {
      debugPrint('[GuessChartLoadingView] 重试失败: $e');
    }
    if (!mounted) return;
    setState(() => _retrying = false);

    if (!solved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('重新拉取曲库失败，请检查网络后重试'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  /// 「打开设置」：调用方负责弹设置对话框并在改完后重开一局。
  ///
  /// 这里**不**在失败时弹 SnackBar：用户可能只是点了「取消」，
  /// 并没有发生任何失败；而设置里的「确定」自己已经有「设置已保存」提示。
  Future<void> _handleOpenSettings() async {
    if (_openingSettings) return;
    final onOpenSettings = widget.onOpenSettings;
    if (onOpenSettings == null) return;

    setState(() => _openingSettings = true);
    try {
      await onOpenSettings();
    } catch (e) {
      debugPrint('[GuessChartLoadingView] 打开设置失败: $e');
    }
    // 重开成功的话这个失败视图已经从树上摘掉了，mounted 为 false
    if (!mounted) return;
    setState(() => _openingSettings = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 还没有失败文案 → 首次取曲进行中，只转圈
    final loading = widget.message.isEmpty;
    final canRetry = !loading && widget.onRetry != null;
    final canOpenSettings = !loading && widget.onOpenSettings != null;
    final textStyle = TextStyle(
      fontSize: 14,
      height: 1.5,
      color: scheme.onSurfaceVariant,
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            else
              Icon(Icons.cloud_off_outlined, size: 36, color: scheme.outline),
            if (loading) ...[
              if ((widget.loadingTip ?? '').isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  widget.loadingTip!,
                  textAlign: TextAlign.center,
                  style: textStyle,
                ),
              ],
            ] else ...[
              const SizedBox(height: 16),
              Text(widget.message,
                  textAlign: TextAlign.center, style: textStyle),
            ],
            if (canRetry || canOpenSettings) ...[
              const SizedBox(height: 20),
              // 两个动作可能同时存在（曲库为空：既能补拉数据，也能放宽条件），
              // 用 Wrap 避免窄屏溢出
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (canRetry)
                    FilledButton.tonalIcon(
                      onPressed: _retrying ? null : _handleRetry,
                      icon: _retrying
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh, size: 18),
                      label: Text(_retrying ? '正在拉取曲库...' : '重新拉取曲库'),
                    ),
                  if (canOpenSettings)
                    OutlinedButton.icon(
                      onPressed: _openingSettings ? null : _handleOpenSettings,
                      icon: _openingSettings
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.settings, size: 18),
                      label: const Text('打开设置'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 「抽不到曲」时填进**题面区**的提示块。
///
/// 用法与谱面片段猜歌一致：抽不到曲也照常进入游戏界面，只是把题面
/// （曲绘 / 别名 / 音频 / 遮蔽曲名）换成这块原因说明 ——
/// 搜索框照旧能搜、规则 / 设置 / 刷新 / 排序 / 投降 5 个按钮照旧能点，
/// 用户不必退出去再进来就能改条件重抽。
///
/// 之所以不把整页换成加载/失败视图：那样设置入口（齿轮长在游戏内容里）
/// 就点不到了，「请在设置中放宽条件」等于废话。
class GuessChartNoSongNotice extends StatelessWidget {
  /// 失败原因（复用 [_loadFailureMessage] 的文案常量）。
  final String message;

  /// 题面区高度。各页题面大小不一（曲绘 200、音频条…），按需传。
  final double height;

  const GuessChartNoSongNotice({
    super.key,
    required this.message,
    this.height = 160,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: height,
      width: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        // 边框统一走 outlineVariant（见 AGENTS.md 第 7 条）
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 32, color: scheme.outline),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
