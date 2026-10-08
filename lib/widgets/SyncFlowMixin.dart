import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constant/CacheKeyConstant.dart';
import '../page/Awmc/AwmcSyncFlow.dart';
import '../page/AwmcNet/AwmcNetSyncFlow.dart';
import '../page/AwmcNet/SyncToAwmcNetPage.dart' show AwmcNetSyncInput;
import '../service/AccountStore.dart';
import '../service/SyncRouteStore.dart';
import '../service/SyncStatsService.dart';
import '../service/MultiScoreSyncRunner.dart';
import '../utils/SyncRouteNotifier.dart';
import '../utils/SecureCredentialStore.dart';
import 'SyncScoreDialogs.dart'
    show
        SyncCallbacks,
        SyncFlowException,
        DivingFishSyncInput,
        LuoXueSyncInput,
        SyncScoreDialogs,
        showDivingFishSyncInputDialog,
        executeDivingFishSync,
        showLuoXueSyncInputDialog,
        executeLuoXueSync,
        showMultiScoreSyncInputDialog;
import 'ErrorMessageDialog.dart';

/// 「同步成绩到水鱼 / 落雪 / AWMC NET」三个入口的**按钮上进度**编排。
///
/// ## 为什么要有这个 mixin
///
/// 「系统」hub 页与首页「收藏的功能」区显示的是同一批入口、同一套线路切换器
/// （[SyncRouteFooter]）、同一套统计行（[SyncStatsFooter]）。但**点击之后的编排**
/// 曾经各写了一遍，于是同一功能在两处表现完全不同：
///
///   * 水鱼：hub 页进度打在按钮上；收藏区走 `showDivingFishSyncDialog` 弹模态框。
///   * 落雪：hub 页进度打在按钮上；收藏区 `UpdateLuoXueScorePage.show` 跳页，什么进度都没有。
///   * 三个入口在收藏区还都缺少 `_anyBusy` 互斥，能同时点起两个同步互相踩缓存。
///
/// 现在三个流程只此一份，两个页面 mixin 进来即可，行为不可能再走歪。
///
/// ## 交互约定（三个入口一致）
///
/// * **需要用户输入的部分**（二维码、账号密码、排行榜选项）走对话框；
/// * **耗时等待**（抓取 → 推送 → 刷新本地数据）期间对话框立即关闭，
///   进度以 `loadingText` 打在**按钮**上，不锁整页 —— AWMC NET 一次要 30 多秒，
///   用模态框把整页锁住太难受。
mixin SyncFlowMixin<T extends StatefulWidget> on State<T> {
  // ===== 按钮上进度显示所需的状态 =====
  bool _syncingDivingFish = false;
  String _syncText = '';
  bool _syncingLuoXue = false;
  String _luoXueText = '';
  bool _syncingAwmcNet = false;
  String _awmcNetText = '';
  bool _syncingMulti = false;
  String _multiSyncText = '';
  double? _divingFishProgress;
  double? _luoXueProgress;
  double? _awmcNetProgress;
  double? _multiSyncProgress;

  double? get divingFishProgress => _divingFishProgress;
  double? get luoXueProgress => _luoXueProgress;
  double? get awmcNetProgress => _awmcNetProgress;
  double? get multiSyncProgress => _multiSyncProgress;

  /// 水鱼按钮：进行中。
  bool get syncingDivingFish => _syncingDivingFish;

  /// 水鱼按钮：进度文案。
  String get syncText => _syncText;

  /// 落雪按钮：进行中。
  bool get syncingLuoXue => _syncingLuoXue;

  /// 落雪按钮：进度文案。
  String get luoXueText => _luoXueText;

  /// AWMC NET 按钮：进行中。
  bool get syncingAwmcNet => _syncingAwmcNet;

  /// AWMC NET 按钮：进度文案。
  String get awmcNetText => _awmcNetText;

  bool get syncingMulti => _syncingMulti;
  String get multiSyncText => _multiSyncText;

  /// 三个同步入口是否都空闲。
  ///
  /// 宿主页面可以把它并进自己更宽的「任意长任务进行中」判断里
  /// （「系统」hub 页还有刷新数据、刷新 maidata 等任务）。
  bool get syncFlowsIdle =>
      !_syncingDivingFish &&
      !_syncingLuoXue &&
      !_syncingAwmcNet &&
      !_syncingMulti;

  /// 四个同步入口中是否有任意一个正在执行。
  bool get anySyncBusy => !syncFlowsIdle;

  /// 任意长任务进行中：用于禁用其它入口，避免并发操作互相踩缓存。
  ///
  /// 由宿主页面实现 —— 各页面的长任务集合不同。
  bool get anyBusy;

  /// 同步流程回调（QQ 落盘 / 同步后刷新本地数据 / 登录态变化）。
  ///
  /// 由宿主页面按自己的刷新逻辑提供；做成 getter 而不是字段，是为了让它每次
  /// 用到时才构造。
  SyncCallbacks get syncCallbacks;

  /// 统一改三个入口的按钮进度（不碰对话框）。
  ///
  /// 拆成「取计数 / 取文案 / 写回」三步是为了避免在表达式里对整个
  /// `this` 做空判断 —— 那样会把 mixin 自身也判进去，读起来莫名其妙。
  void _updateSyncState({
    bool? divingFish,
    String? divingFishText,
    bool? luoXue,
    String? luoXueText,
    bool? awmcNet,
    String? awmcNetText,
    bool? multi,
    String? multiText,
    double? divingFishProgress,
    double? luoXueProgress,
    double? awmcNetProgress,
    double? multiProgress,
  }) {
    if (!mounted) return;
    setState(() {
      // 新任务和结束任务都清除上次的进度，等待网关响应时不伪造百分比。
      if (divingFish != null && divingFish != _syncingDivingFish)
        _divingFishProgress = null;
      if (luoXue != null && luoXue != _syncingLuoXue) _luoXueProgress = null;
      if (awmcNet != null && awmcNet != _syncingAwmcNet)
        _awmcNetProgress = null;
      if (multi != null && multi != _syncingMulti) _multiSyncProgress = null;
      if (divingFishProgress != null) _divingFishProgress = divingFishProgress;
      if (luoXueProgress != null) _luoXueProgress = luoXueProgress;
      if (awmcNetProgress != null) _awmcNetProgress = awmcNetProgress;
      if (multiProgress != null) _multiSyncProgress = multiProgress;
      if (divingFish != null) _syncingDivingFish = divingFish;
      if (divingFishText != null) _syncText = divingFishText;
      if (luoXue != null) _syncingLuoXue = luoXue;
      if (luoXueText != null) _luoXueText = luoXueText;
      if (awmcNet != null) _syncingAwmcNet = awmcNet;
      if (awmcNetText != null) _awmcNetText = awmcNetText;
      if (multi != null) _syncingMulti = multi;
      if (multiText != null) _multiSyncText = multiText;
    });
  }

  // ===== 水鱼 =====

  /// 同步成绩到水鱼（线路2 maimai Score Hub）：输入（二维码 / 排行榜选项）
  /// 在对话框完成，点「开始同步」后对话框立即关闭，抓取 → 推送 → 刷新本地数据
  /// 的进度全部显示在按钮上。
  ///
  /// 调用方负责按当前线路决定走这个还是 [syncToDivingFishViaAwmc]。
  Future<void> syncToDivingFishWithButton() async {
    if (anyBusy) return;

    final hasJwt = (await SecureCredentialStore.read(
                CacheKeyConstant.probeDivingFishToken) ??
            '')
        .isNotEmpty;

    if (!hasJwt) {
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('提示'),
          content: const Text('请先登录你的水鱼账号，再使用同步功能。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('去登录'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      await SyncScoreDialogs.showDivingFishLoginDialog(context, syncCallbacks);
      final hasJwt2 = (await SecureCredentialStore.read(
                  CacheKeyConstant.probeDivingFishToken) ??
              '')
          .isNotEmpty;
      if (!hasJwt2 || !mounted) return;
    }

    final prefs = await SharedPreferences.getInstance();
    final bindQQ =
        prefs.getString(CacheKeyConstant.probeDivingFishBindQQ) ?? '';
    final cachedQQ = (await AccountStore.loadAll())['shuiyu']?.id;
    if (bindQQ.isNotEmpty && cachedQQ != null && bindQQ != cachedQQ) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('账号不匹配'),
          content: Text(
            '当前登录水鱼账号绑定的 QQ（$bindQQ）与本机缓存的 QQ（$cachedQQ）不一致。\n\n请先登出当前水鱼账号，登录正确的账号后再同步。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('确定'),
            ),
          ],
        ),
      );
      return;
    }

    if (!mounted) return;
    final input = await showDivingFishSyncInputDialog(context);
    if (input == null || !mounted) return;

    _updateSyncState(divingFish: true, divingFishText: '正在同步成绩...');
    // 记录本次同步耗时 / 成败（Redis，尽力而为）
    final stopwatch = Stopwatch()..start();
    var syncOk = false;
    // 缺 ImportToken 时会转交给对话框再走一遍完整流程（那一次由对话框上报），
    // 这里就不再记一条，免得同一次用户操作算成两条样本
    var handedOffToDialog = false;
    try {
      final outcome = await executeDivingFishSync(
        syncCallbacks,
        input,
        onProgress: (p, t) => _updateSyncState(
          divingFishText: '$t ${(p * 100).round()}%',
          divingFishProgress: p,
        ),
      );
      syncOk = true;
      if (!mounted) return;
      Fluttertoast.showToast(
          msg: outcome.localDataRefreshed
              ? '同步完成！${outcome.exportedCount} 条成绩已同步，本地数据已刷新'
              : '同步完成！${outcome.exportedCount} 条成绩已推送到水鱼');
    } on SyncFlowException catch (e) {
      if (!mounted) return;
      await showErrorMessageDialog(context, message: e.message);
      if (!mounted) return;
      // 需要 ImportToken 时按钮上没法输入账号密码，回到原有的对话框完成绑定；
      // 二维码已经抓过一次，直接复用，避免让用户重新粘贴。
      if (e.message.contains('ImportToken')) {
        handedOffToDialog = true;
        await SyncScoreDialogs.showDivingFishSyncDialog(
          context,
          syncCallbacks,
          presetQrCode: input.qrCode,
        );
      }
    } catch (e) {
      if (mounted) {
        await showErrorMessageDialog(context, message: '同步失败：$e');
      }
    } finally {
      stopwatch.stop();
      if (!handedOffToDialog) {
        unawaited(SyncStatsService.record(
          line: SyncLine.scoreHub,
          platform: SyncPlatform.divingFish,
          durationMs: stopwatch.elapsedMilliseconds,
          ok: syncOk,
        ));
        SyncRouteNotifier.instance.refreshStatsSoon();
      }
      _updateSyncState(divingFish: false, divingFishText: '');
    }
  }

  /// 线路1（AWMC 网关）同步到水鱼：二维码 + 用户的水鱼凭据，网关开发者密钥由服务端代理注入。
  Future<void> syncToDivingFishViaAwmc() async {
    if (anyBusy) return;
    final outcome = await AwmcSyncFlow.run(
      context,
      target: AwmcSyncTarget.divingFish,
      onBusy: (label) =>
          _updateSyncState(divingFish: true, divingFishText: label),
      onProgress: (p, text) => _updateSyncState(
          divingFishText: '$text ${(p * 100).round()}%', divingFishProgress: p),
      onIdle: () => _updateSyncState(divingFish: false, divingFishText: ''),
    );
    if (!mounted || outcome.cancelled) return;
    if (outcome.ok) {
      Fluttertoast.showToast(
          msg: AwmcSyncFlow.successToast(AwmcSyncTarget.divingFish, outcome));
      if (outcome.refreshError != null && mounted) {
        await showErrorMessageDialog(
          context,
          message: '同步成功，但刷新数据失败：${outcome.refreshError}',
        );
      }
    } else if (outcome.message != null) {
      await showErrorMessageDialog(context, message: outcome.message!);
    }
    // 统计是异步写进 Redis 的，稍等一下再刷新，让这一行尽快反映本次结果
    SyncRouteNotifier.instance.refreshStatsSoon();
  }

  // ===== 落雪 =====

  /// 同步成绩到落雪（线路2 maimai Score Hub）：输入在对话框完成，进度显示在按钮上。
  Future<void> syncToLuoXueWithButton() async {
    if (anyBusy) return;
    final input = await showLuoXueSyncInputDialog(context);
    if (input == null || !mounted) return;

    _updateSyncState(luoXue: true, luoXueText: '正在同步成绩...');
    final stopwatch = Stopwatch()..start();
    var syncOk = false;
    try {
      final count = await executeLuoXueSync(input, onProgress: (p, t) {
        _updateSyncState(
            luoXueText: '$t ${(p * 100).round()}%', luoXueProgress: p);
      });
      syncOk = true;
      if (!mounted) return;
      Fluttertoast.showToast(msg: '同步完成！共 $count 条成绩已导出到落雪');
    } on SyncFlowException catch (e) {
      if (mounted) {
        await showErrorMessageDialog(context, message: e.message);
      }
    } catch (e) {
      if (mounted) {
        await showErrorMessageDialog(context, message: '同步失败：$e');
      }
    } finally {
      stopwatch.stop();
      unawaited(SyncStatsService.record(
        line: SyncLine.scoreHub,
        platform: SyncPlatform.luoXue,
        durationMs: stopwatch.elapsedMilliseconds,
        ok: syncOk,
      ));
      SyncRouteNotifier.instance.refreshStatsSoon();
      _updateSyncState(luoXue: false, luoXueText: '');
    }
  }

  /// 线路1（AWMC 网关）同步到落雪：二维码 + 用户的落雪凭据，网关开发者密钥由服务端代理注入。
  Future<void> syncToLuoXueViaAwmc() async {
    if (anyBusy) return;
    final outcome = await AwmcSyncFlow.run(
      context,
      target: AwmcSyncTarget.luoXue,
      onBusy: (label) => _updateSyncState(luoXue: true, luoXueText: label),
      onProgress: (p, text) => _updateSyncState(
          luoXueText: '$text ${(p * 100).round()}%', luoXueProgress: p),
      onIdle: () => _updateSyncState(luoXue: false, luoXueText: ''),
    );
    if (!mounted || outcome.cancelled) return;
    if (outcome.ok) {
      Fluttertoast.showToast(
          msg: AwmcSyncFlow.successToast(AwmcSyncTarget.luoXue, outcome));
      if (outcome.refreshError != null && mounted) {
        await showErrorMessageDialog(
          context,
          message: '同步成功，但刷新数据失败：${outcome.refreshError}',
        );
      }
    } else if (outcome.message != null) {
      await showErrorMessageDialog(context, message: outcome.message!);
    }
    SyncRouteNotifier.instance.refreshStatsSoon();
  }

  // ===== AWMC NET（机台二维码直传，没有线路概念） =====

  /// 同步成绩到 AWMC NET：**输入在对话框完成，等待进度显示在按钮上**
  /// ——与上面四个入口完全一致（早先是对话框里转圈等 30 多秒）。
  Future<void> syncToAwmcNetWithButton() async {
    if (anyBusy) return;
    final outcome = await AwmcNetSyncFlow.run(
      context,
      onBusy: (label) => _updateSyncState(awmcNet: true, awmcNetText: label),
      onProgress: (p, text) => _updateSyncState(
          awmcNetText: '$text ${(p * 100).round()}%', awmcNetProgress: p),
      onIdle: () => _updateSyncState(awmcNet: false, awmcNetText: ''),
    );
    if (!mounted || outcome.cancelled) return;
    final message = AwmcNetSyncFlow.toastFor(outcome);
    if (outcome.ok) {
      Fluttertoast.showToast(msg: message);
      if (outcome.refreshError != null && mounted) {
        await showErrorMessageDialog(
          context,
          message: '同步成功，但刷新数据失败：${outcome.refreshError}',
        );
      }
    } else {
      await showErrorMessageDialog(context, message: message);
    }
  }

  /// 一次输入二维码，顺序调用三个已经配置好的查分器。
  /// 每个平台独立记录成功/失败，最后一次性把汇总结果告诉用户。
  Future<void> syncToMultiplePlatforms() async {
    if (anyBusy) return;
    final input = await showMultiScoreSyncInputDialog(context);
    if (input == null || !mounted || anyBusy) return;

    _updateSyncState(multi: true, multiText: '准备同步…');
    final successes = <String>[];
    final failures = <String>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      final participate =
          prefs.getBool(CacheKeyConstant.participateRankings) ?? false;
      final nickname = prefs.getBool(CacheKeyConstant.showNickname) ?? false;
      var completedPlatforms = 0;

      final results = await MultiScoreSyncRunner.run(
        platforms: input.platforms,
        execute: (platform) async {
          final routeLabel = platform == SyncPlatform.awmc
              ? '二维码直传'
              : input.routeOf(platform) == SyncRouteStore.routeAwmc
                  ? '线路1'
                  : '线路2';
          _updateSyncState(
              multiText: '正在同步到${platform.label}（$routeLabel）…',
              multiProgress: completedPlatforms / input.platforms.length);
          try {
            if (platform != SyncPlatform.awmc &&
                input.routeOf(platform) == SyncRouteStore.routeAwmc) {
              final target = platform == SyncPlatform.divingFish
                  ? AwmcSyncTarget.divingFish
                  : AwmcSyncTarget.luoXue;
              final outcome = await AwmcSyncFlow.runWithInput(
                qrCode: input.qrCode,
                target: target,
                onBusy: (text) =>
                    _updateSyncState(multiText: '${platform.label}（线路1）：$text'),
                onProgress: (p, text) => _updateSyncState(
                    multiText:
                        '${platform.label}（线路1）：$text ${(p * 100).round()}%',
                    multiProgress:
                        (completedPlatforms + p) / input.platforms.length),
              );
              if (!outcome.ok) {
                throw SyncFlowException(outcome.message ?? '线路1同步失败');
              }
              final count = outcome.cachedRecords > 0
                  ? '，${outcome.cachedRecords} 条'
                  : '';
              final warning = outcome.readErrorMessage == null
                  ? ''
                  : '（游玩次数未更新：${outcome.readErrorMessage}）';
              return '${platform.label}（线路1$count）$warning';
            }
            switch (platform) {
              case SyncPlatform.divingFish:
                final result = await executeDivingFishSync(
                  syncCallbacks,
                  DivingFishSyncInput(
                    qrCode: input.qrCode,
                    participateRankings: participate,
                    showNickname: nickname,
                  ),
                  onProgress: (p, text) => _updateSyncState(
                      multiText: '水鱼（线路2）：$text ${(p * 100).round()}%',
                      multiProgress:
                          (completedPlatforms + p) / input.platforms.length),
                );
                return '水鱼（线路2，${result.exportedCount} 条）';
              case SyncPlatform.luoXue:
                final token = await SecureCredentialStore.read(
                    CacheKeyConstant.probeLxnsImportToken);
                final count = await executeLuoXueSync(
                  LuoXueSyncInput(qrCode: input.qrCode, lxnsImportToken: token),
                  onProgress: (p, text) => _updateSyncState(
                      multiText: '落雪（线路2）：$text ${(p * 100).round()}%',
                      multiProgress:
                          (completedPlatforms + p) / input.platforms.length),
                );
                return '落雪（线路2，$count 条）';
              case SyncPlatform.awmc:
                final token = await SecureCredentialStore.read(
                    CacheKeyConstant.awmcNetImportToken);
                if (token == null || token.isEmpty) {
                  throw const SyncFlowException('未设置 AWMC NET 成绩导入 Token');
                }
                final outcome = await AwmcNetSyncFlow.runWithInput(
                  AwmcNetSyncInput(qr: input.qrCode, importToken: token),
                  onBusy: (label) =>
                      _updateSyncState(multiText: 'AWMC NET：$label'),
                  onIdle: () {},
                );
                if (!outcome.ok) {
                  throw SyncFlowException(AwmcNetSyncFlow.toastFor(outcome));
                }
                return 'AWMC NET';
            }
          } finally {
            completedPlatforms++;
            _updateSyncState(
                multiProgress: completedPlatforms / input.platforms.length);
          }
        },
      );
      for (final result in results) {
        if (result.ok) {
          successes.add(result.message);
        } else {
          failures.add('${result.platform.label}：${result.message}');
        }
      }

      if (!mounted) return;
      if (failures.isEmpty) {
        Fluttertoast.showToast(msg: '多端同步完成：${successes.join('、')}');
      } else {
        await showErrorMessageDialog(
          context,
          message:
              '已完成：${successes.isEmpty ? '无' : successes.join('、')}\n\n失败：\n${failures.join('\n')}',
        );
      }
    } finally {
      _updateSyncState(multi: false, multiText: '');
      SyncRouteNotifier.instance.refreshStatsSoon();
    }
  }

  /// 按 [SyncRouteStore] 里记住的线路分发水鱼同步。
  ///
  /// 两个页面都要做这个分支，集中在这里免得一边改一边忘。
  Future<void> syncToDivingFishByCurrentRoute() async {
    if (SyncRouteNotifier.instance.routeOf(SyncPlatform.divingFish) ==
        SyncRouteStore.routeAwmc) {
      await syncToDivingFishViaAwmc();
    } else {
      await syncToDivingFishWithButton();
    }
  }

  /// 按 [SyncRouteStore] 里记住的线路分发落雪同步。
  Future<void> syncToLuoXueByCurrentRoute() async {
    if (SyncRouteNotifier.instance.routeOf(SyncPlatform.luoXue) ==
        SyncRouteStore.routeAwmc) {
      await syncToLuoXueViaAwmc();
    } else {
      await syncToLuoXueWithButton();
    }
  }
}
