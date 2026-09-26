import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constant/CacheKeyConstant.dart';
import '../page/Awmc/AwmcSyncFlow.dart';
import '../page/AwmcNet/AwmcNetSyncFlow.dart';
import '../service/AccountStore.dart';
import '../service/SyncRouteStore.dart';
import '../service/SyncStatsService.dart';
import '../utils/SyncRouteNotifier.dart';
import 'SyncScoreDialogs.dart'
    show
        SyncCallbacks,
        SyncFlowException,
        SyncScoreDialogs,
        showDivingFishSyncInputDialog,
        executeDivingFishSync,
        showLuoXueSyncInputDialog,
        executeLuoXueSync;

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

  /// 三个同步入口是否都空闲。
  ///
  /// 宿主页面可以把它并进自己更宽的「任意长任务进行中」判断里
  /// （「系统」hub 页还有刷新数据、刷新 maidata 等任务）。
  bool get syncFlowsIdle =>
      !_syncingDivingFish && !_syncingLuoXue && !_syncingAwmcNet;

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
  }) {
    if (!mounted) return;
    setState(() {
      if (divingFish != null) _syncingDivingFish = divingFish;
      if (divingFishText != null) _syncText = divingFishText;
      if (luoXue != null) _syncingLuoXue = luoXue;
      if (luoXueText != null) _luoXueText = luoXueText;
      if (awmcNet != null) _syncingAwmcNet = awmcNet;
      if (awmcNetText != null) _awmcNetText = awmcNetText;
    });
  }

  // ===== 水鱼 =====

  /// 同步成绩到水鱼（线路1）：输入（二维码 / 排行榜选项）在对话框完成，
  /// 点「开始同步」后对话框立即关闭，抓取 → 推送 → 刷新本地数据的进度
  /// 全部显示在按钮上。
  ///
  /// 调用方负责按当前线路决定走这个还是 [syncToDivingFishViaAwmc]。
  Future<void> syncToDivingFishWithButton() async {
    if (anyBusy) return;

    final prefs = await SharedPreferences.getInstance();
    final hasJwt =
        (prefs.getString(CacheKeyConstant.probeDivingFishToken) ?? '')
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
      final prefs2 = await SharedPreferences.getInstance();
      final hasJwt2 =
          (prefs2.getString(CacheKeyConstant.probeDivingFishToken) ?? '')
              .isNotEmpty;
      if (!hasJwt2 || !mounted) return;
    }

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
      Fluttertoast.showToast(msg: e.message);
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
      if (mounted) Fluttertoast.showToast(msg: '同步失败：$e');
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

  /// 线路2 同步到水鱼：二维码 + 网关令牌 → `/v1/user/music` + `/v1/update-fish`。
  Future<void> syncToDivingFishViaAwmc() async {
    if (anyBusy) return;
    final outcome = await AwmcSyncFlow.run(
      context,
      target: AwmcSyncTarget.divingFish,
      onBusy: (label) => _updateSyncState(divingFish: true, divingFishText: label),
      onIdle: () => _updateSyncState(divingFish: false, divingFishText: ''),
    );
    if (!mounted || outcome.cancelled) return;
    if (outcome.ok) {
      Fluttertoast.showToast(
          msg: AwmcSyncFlow.successToast(AwmcSyncTarget.divingFish, outcome));
    } else if (outcome.message != null) {
      Fluttertoast.showToast(msg: outcome.message!);
    }
    // 统计是异步写进 Redis 的，稍等一下再刷新，让这一行尽快反映本次结果
    SyncRouteNotifier.instance.refreshStatsSoon();
  }

  // ===== 落雪 =====

  /// 同步成绩到落雪（线路1）：输入在对话框完成，进度显示在按钮上。
  Future<void> syncToLuoXueWithButton() async {
    if (anyBusy) return;
    final input = await showLuoXueSyncInputDialog(context);
    if (input == null || !mounted) return;

    _updateSyncState(luoXue: true, luoXueText: '正在同步成绩...');
    final stopwatch = Stopwatch()..start();
    var syncOk = false;
    try {
      final count = await executeLuoXueSync(input, onProgress: (p, t) {
        _updateSyncState(luoXueText: '$t ${(p * 100).round()}%');
      });
      syncOk = true;
      if (!mounted) return;
      Fluttertoast.showToast(msg: '同步完成！共 $count 条成绩已导出到落雪');
    } on SyncFlowException catch (e) {
      if (mounted) Fluttertoast.showToast(msg: e.message);
    } catch (e) {
      if (mounted) Fluttertoast.showToast(msg: '同步失败：$e');
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

  /// 线路2 同步到落雪：二维码 + 网关令牌 → `/v1/user/music` + `/v1/update-lx`。
  Future<void> syncToLuoXueViaAwmc() async {
    if (anyBusy) return;
    final outcome = await AwmcSyncFlow.run(
      context,
      target: AwmcSyncTarget.luoXue,
      onBusy: (label) => _updateSyncState(luoXue: true, luoXueText: label),
      onIdle: () => _updateSyncState(luoXue: false, luoXueText: ''),
    );
    if (!mounted || outcome.cancelled) return;
    if (outcome.ok) {
      Fluttertoast.showToast(
          msg: AwmcSyncFlow.successToast(AwmcSyncTarget.luoXue, outcome));
    } else if (outcome.message != null) {
      Fluttertoast.showToast(msg: outcome.message!);
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
      onBusy: (label) =>
          _updateSyncState(awmcNet: true, awmcNetText: label),
      onIdle: () => _updateSyncState(awmcNet: false, awmcNetText: ''),
    );
    if (!mounted || outcome.cancelled) return;
    Fluttertoast.showToast(msg: AwmcNetSyncFlow.toastFor(outcome));
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
