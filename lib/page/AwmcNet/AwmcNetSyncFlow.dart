import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constant/CacheKeyConstant.dart';
import '../../service/AWMC/AwmcPlayCountStore.dart';
import '../../service/AwmcNetScoreUploadService.dart';
import '../../service/SyncStatsService.dart';
import '../../utils/CurrentDataSourceNotifier.dart';
import '../../utils/SyncRouteNotifier.dart';
import 'SyncToAwmcNetPage.dart' show showAwmcNetSyncInputDialog;

/// 一次「同步成绩到 AWMC NET」的结果。
class AwmcNetSyncOutcome {
  /// 用户在输入阶段取消（**没有发出任何请求**，因此不计入统计）。
  final bool cancelled;

  /// 导入接口是否成功（HTTP 200）。
  final bool ok;

  /// 接口原始结果（取消时为 null）。
  final AwmcNetQrImportResult? result;

  const AwmcNetSyncOutcome({
    this.cancelled = false,
    this.ok = false,
    this.result,
  });

  static const AwmcNetSyncOutcome userCancelled =
      AwmcNetSyncOutcome(cancelled: true);
}

/// 「同步成绩到 AWMC NET」的完整流程：**输入在对话框、等待进度在按钮上**。
///
/// 与另外两个同步入口（[AwmcSyncFlow] / 线路1 的 `executeDivingFishSync`）保持同一
/// 交互：输入对话框收起之后才开始跑，所以按钮可以安心切成「转圈 + 进度文案」，
/// 用户也不会被一个模态框锁住 30 多秒。
///
/// 调用方只需要：
/// ```dart
/// final outcome = await AwmcNetSyncFlow.run(
///   context,
///   onBusy: (label) => setState(() { _busy = true; _text = label; }),
///   onIdle: () => setState(() { _busy = false; _text = ''; }),
/// );
/// if (!outcome.cancelled) Fluttertoast.showToast(msg: AwmcNetSyncFlow.toastFor(outcome));
/// ```
class AwmcNetSyncFlow {
  AwmcNetSyncFlow._();

  /// 执行一次导入（自己弹输入对话框，自己上报统计）。
  ///
  /// [onBusy] / [onIdle] 用于让调用方在**真正的请求期间**切换按钮进度
  /// （输入框阶段不切换：按钮上转着圈却还弹着对话框会让人以为可以走）。
  static Future<AwmcNetSyncOutcome> run(
    BuildContext context, {
    void Function(String label)? onBusy,
    VoidCallback? onIdle,
  }) async {
    // 1. 输入：二维码 + 成绩导入 Token（对话框只收集，不发请求）
    final input = await showAwmcNetSyncInputDialog(context);
    if (input == null) return AwmcNetSyncOutcome.userCancelled;

    // 2. 顺手刷新**AWMC NET 这个账号自己的**游玩次数。
    //
    //    AWMC NET 查分器没有逐谱面次数（只有 `/api/player/{qq}` 的账号总计），
    //    唯一来源是 AWMC 网关的 `/v1/user/music`（4 Token）—— 而它正好需要
    //    我们手上这张机台二维码。所以跟线路1 一样顺手拉一次：
    //    **尽力而为、绝不 await、失败不弹提示**，别影响真正的导入。
    //
    //    ⚠️ 必须显式写 `source: awmc`：三类账号（水鱼 / 落雪 / AWMC NET）的
    //    次数互不相干，不能落到当时碰巧活动的那个账号名下。
    AwmcPlayCountStore.refreshQuietly(
      input.qr,
      source: RefreshDataSource.awmc,
    );

    // 3. 近 100 次统计：二维码直传自成一个槽位（`direct:awmc`），
    //    不能混进线路1/线路2 —— 它一次要 30 多秒，会把网关那条的平均拉高。
    //    校验没过 / 用户取消的分支在上面就 return 了，所以不会被算成失败样本。
    final attempt = SyncAttemptTracker(
      line: SyncLine.direct,
      platform: SyncPlatform.awmc,
    );
    attempt.start();

    // 4. 进度：接口没有进度事件，只能自己数秒。
    //    实测一次约 36 秒，光转圈会被当成卡死，所以「已等待 N 秒」必须一直动。
    var waited = 0;
    onBusy?.call(_busyLabel(0));
    final ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      waited++;
      onBusy?.call(_busyLabel(waited));
    });

    try {
      final result = await AwmcNetScoreUploadService.instance.importByQr(
        importToken: input.importToken,
        sgwcmaid: input.qr,
      );

      // Token 被服务端判为无效：清掉本机那份，否则用户下次点还是同一个错
      if (result.tokenInvalid) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(CacheKeyConstant.awmcNetImportToken);
      }

      if (attempt.finish(ok: result.ok)) {
        SyncRouteNotifier.instance.refreshStatsSoon();
      }
      return AwmcNetSyncOutcome(ok: result.ok, result: result);
    } finally {
      ticker.cancel();
      onIdle?.call();
    }
  }

  /// 按钮上的进度文案（[HubActionTile.loadingText] / 首页收藏区同一行）。
  static String _busyLabel(int seconds) => '正在导入成绩…已等待 $seconds 秒';

  /// 结果 toast：与另外两个同步入口同口径 —— **只给一个小提示**，不弹结果面板。
  ///
  /// 计数用 `新增/更新/跳过`：实测一次 `新增 9 / 更新 1106 / 跳过 593`，
  /// 「更新」才是大多数，只报「新增」会让用户以为成绩没导进去。
  static String toastFor(AwmcNetSyncOutcome outcome) {
    final r = outcome.result;
    if (r == null) return '导入失败';
    if (!r.ok) return r.errorMessage ?? '导入失败';

    final seconds = (r.elapsedMs / 1000).toStringAsFixed(1);
    final buffer = StringBuffer('导入完成！新增 ${r.imported} / 更新 ${r.updated}');
    if (r.skipped > 0) buffer.write(' / 跳过 ${r.skipped}');
    buffer.write('（$seconds 秒）');
    // `errors` 非空不代表失败（实测 20 条「找不到歌曲」时 HTTP 仍是 200），
    // 但必须说一句，否则用户会以为少掉的成绩是 App 弄丢了。
    if (r.errors.isNotEmpty) {
      buffer.write('；${r.errors.length} 条谱面 AWMC NET 暂未收录');
    }
    return buffer.toString();
  }
}
