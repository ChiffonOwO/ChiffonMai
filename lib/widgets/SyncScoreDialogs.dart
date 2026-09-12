import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constant/CacheKeyConstant.dart';
import '../constant/LoadingTipsConstant.dart';
import '../manager/DivingFishProbeManager.dart';
import '../utils/AppTheme.dart';

/// 同步成绩相关的回调上下文：用于让同步对话框在父页面（首页 / 我的）之间复用。
class SyncCallbacks {
  /// 当前缓存的 QQ
  final String cachedQQ;

  /// 同步成功后保存新 QQ
  final Future<void> Function(String qq) onSaveQQ;

  /// 同步成功后保存数据源
  final Future<void> Function(String source) onSaveLastDataSource;

  /// 同步完成后自动刷新本地数据（用于继续展示进度）
  final Future<void> Function({
    required String qq,
    required void Function(double progress, String text) onProgress,
    required bool participateRankings,
    required bool showNickname,
  }) onRefreshAfterSync;

  /// 登录状态变更后通知父页面更新（例如刷新我的页面的登录状态）
  final Future<void> Function() onLoginStateChanged;

  const SyncCallbacks({
    required this.cachedQQ,
    required this.onSaveQQ,
    required this.onSaveLastDataSource,
    required this.onRefreshAfterSync,
    required this.onLoginStateChanged,
  });
}

// ============================================================
// 输入 / 执行 分离的同步流程（用于把进度显示在调用方的按钮上）
// ============================================================

/// 「同步成绩到水鱼」对话框收集到的输入。
class DivingFishSyncInput {
  /// 舞萌|中二登入二维码（SGWCMAID 开头）
  final String qrCode;
  final bool participateRankings;
  final bool showNickname;

  const DivingFishSyncInput({
    required this.qrCode,
    required this.participateRankings,
    required this.showNickname,
  });
}

/// 同步过程中抛出的异常：message 可直接展示给用户。
class SyncFlowException implements Exception {
  final String message;
  const SyncFlowException(this.message);
  @override
  String toString() => message;
}

/// 同步结果：用于调用方决定成功提示文案。
class DivingFishSyncOutcome {
  final int exportedCount;
  final bool localDataRefreshed;
  const DivingFishSyncOutcome({
    required this.exportedCount,
    required this.localDataRefreshed,
  });
}

/// 只收集输入的「同步成绩到水鱼」对话框：二维码 / 排行榜选项。
///
/// 返回 null 表示用户取消；返回非 null 时调用方应执行
/// [executeDivingFishSync]，并把进度显示在自己的按钮上。
///
/// 注意：二维码的「读取剪贴板 / 相册识别 / 扫码」三个按钮需要 setState 刷新
/// 输入框，这里用一个局部 StatefulBuilder 承载，输入项本身是自包含的。
Future<DivingFishSyncInput?> showDivingFishSyncInputDialog(
    BuildContext context) async {
  final brightness = Theme.of(context).brightness;
  final prefs = await SharedPreferences.getInstance();
  var participateRankings =
      prefs.getBool(CacheKeyConstant.participateRankings) ?? false;
  var showNickname = prefs.getBool(CacheKeyConstant.showNickname) ?? false;
  final qrController = TextEditingController();

  if (!context.mounted) return null;

  final result = await showDialog<DivingFishSyncInput>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.qr_code_scanner, size: 22),
              SizedBox(width: 8),
              Text('同步成绩到水鱼'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '在舞萌|中二公众号请求并打开二维码，扫描后将字符串粘贴到下方：',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.greyHint(brightness)),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SyncScoreDialogs._buildClipboardButton(
                        setState, qrController, dialogContext),
                    SyncScoreDialogs._buildGalleryQrButton(
                        setState, qrController),
                    SyncScoreDialogs._buildCameraScanButton(
                        setState, qrController, dialogContext),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qrController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: '舞萌DX | 中二节奏 登入二维码(SGWCMAID...)',
                    hintStyle: TextStyle(
                        fontSize: 13,
                        color: AppColors.greyHint(brightness, shade: 400)),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title:
                      const Text('参与排行榜', style: TextStyle(fontSize: 14)),
                  value: participateRankings,
                  onChanged: (value) {
                    setState(() {
                      participateRankings = value ?? false;
                      if (!participateRankings) showNickname = false;
                    });
                  },
                ),
                if (participateRankings)
                  CheckboxListTile(
                    title: const Text('在排行榜中显示昵称',
                        style: TextStyle(fontSize: 14)),
                    value: showNickname,
                    onChanged: (value) {
                      setState(() => showNickname = value ?? false);
                    },
                  ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.send, size: 18),
                  label: const Text('开始同步'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    minimumSize: const Size.fromHeight(44),
                  ),
                  onPressed: () async {
                    final qrCode = qrController.text.trim();
                    if (qrCode.isEmpty) {
                      Fluttertoast.showToast(
                          msg: '请先粘贴舞萌|中二登入二维码字符串');
                      return;
                    }
                    if (!qrCode.startsWith('SGWCMAID')) {
                      Fluttertoast.showToast(
                          msg: '无效的二维码，请使用舞萌|中二公众号生成的登入二维码');
                      return;
                    }
                    final prefs2 = await SharedPreferences.getInstance();
                    await prefs2.setBool(
                        CacheKeyConstant.participateRankings,
                        participateRankings);
                    await prefs2.setBool(
                        CacheKeyConstant.showNickname, showNickname);
                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop(DivingFishSyncInput(
                      qrCode: qrCode,
                      participateRankings: participateRankings,
                      showNickname: showNickname,
                    ));
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
          ],
        ),
      );
    },
  );

  qrController.dispose();
  return result;
}

/// 把 [SyncProgress] 的阶段映射为 0-1 的进度值。
double divingFishStageProgress(SyncProgress p) => SyncScoreDialogs._stageProgress(p);

// ============================================================
// 「同步成绩到落雪」的输入 / 执行分离版本
// ============================================================

/// 「同步成绩到落雪」对话框收集到的输入。
class LuoXueSyncInput {
  /// 舞萌|中二登入二维码（SGWCMAID 开头）
  final String qrCode;

  /// 落雪个人 API 密钥；已在本地保存过时为 null（执行时从缓存读取）
  final String? lxnsImportToken;

  const LuoXueSyncInput({
    required this.qrCode,
    required this.lxnsImportToken,
  });
}

/// 只收集输入的「同步成绩到落雪」对话框。
///
/// 返回 null 表示用户取消。已在本地保存过落雪 API 密钥时不再要求重新填写。
Future<LuoXueSyncInput?> showLuoXueSyncInputDialog(BuildContext context) async {
  final brightness = Theme.of(context).brightness;
  final prefs = await SharedPreferences.getInstance();
  final savedToken = prefs.getString(CacheKeyConstant.probeLxnsImportToken);
  final hasSavedToken = savedToken != null && savedToken.isNotEmpty;
  final qrController = TextEditingController();
  final tokenController = TextEditingController();
  String? error;

  if (!context.mounted) return null;

  final result = await showDialog<LuoXueSyncInput>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cloud_sync_outlined, size: 22),
            SizedBox(width: 8),
            Text('同步成绩到落雪'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '在舞萌|中二公众号请求并打开二维码，扫描后将字符串粘贴到下方：',
                style: TextStyle(
                    fontSize: 13, color: AppColors.greyHint(brightness)),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.paste, size: 16),
                label: const Text('读取剪贴板', style: TextStyle(fontSize: 13)),
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  final text = (data?.text ?? '').trim();
                  if (text.isEmpty) {
                    Fluttertoast.showToast(msg: '剪贴板为空');
                    return;
                  }
                  setState(() {
                    qrController.text = text;
                    error = null;
                  });
                  if (text.startsWith('SGWCMAID')) {
                    Fluttertoast.showToast(msg: '已识别到有效二维码字符串，已自动填入');
                  } else {
                    Fluttertoast.showToast(msg: '剪贴板内容不是登入二维码，请确认后再提交');
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qrController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: '舞萌DX | 中二节奏 登入二维码(SGWCMAID...)',
                  hintStyle: TextStyle(
                      fontSize: 13,
                      color: AppColors.greyHint(brightness, shade: 400)),
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 16),
              if (hasSavedToken)
                Row(
                  children: [
                    Icon(Icons.check_circle,
                        size: 16, color: AppColors.successGreen(brightness)),
                    const SizedBox(width: 6),
                    Text('已保存落雪 API 密钥',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.successGreen(brightness))),
                  ],
                )
              else ...[
                Text(
                  '需要落雪个人 API 密钥（落雪咖啡屋 → 设置 → 个人 API 密钥）：',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.greyHint(brightness)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: tokenController,
                  decoration: InputDecoration(
                    labelText: '落雪个人 API 密钥',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!,
                    style: TextStyle(
                        fontSize: 12, color: AppColors.errorRed(brightness))),
              ],
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.send, size: 18),
                label: const Text('开始同步'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  minimumSize: const Size.fromHeight(44),
                ),
                onPressed: () async {
                  final qrCode = qrController.text.trim();
                  if (qrCode.isEmpty) {
                    setState(() => error = '请先粘贴舞萌|中二登入二维码字符串');
                    return;
                  }
                  if (!qrCode.startsWith('SGWCMAID')) {
                    setState(() => error = '无效的二维码，请使用舞萌|中二公众号生成的登入二维码');
                    return;
                  }
                  String? token;
                  if (!hasSavedToken) {
                    token = tokenController.text.trim();
                    if (token.isEmpty) {
                      setState(() => error = '请先填写落雪个人 API 密钥');
                      return;
                    }
                    // 先落盘，执行阶段就不用再传了
                    final prefs2 = await SharedPreferences.getInstance();
                    await prefs2.setString(
                        CacheKeyConstant.probeLxnsImportToken, token);
                  }
                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop(LuoXueSyncInput(
                    qrCode: qrCode,
                    lxnsImportToken: token,
                  ));
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    ),
  );

  qrController.dispose();
  tokenController.dispose();
  return result;
}

/// 执行「同步成绩到落雪」：抓取机台成绩 → 导出到落雪。
Future<int> executeLuoXueSync(
  LuoXueSyncInput input, {
  required void Function(double progress, String text) onProgress,
}) async {
  onProgress(0.05, '准备同步...');
  final result = await DivingFishProbeManager().syncByCabinetQrToLxns(
    input.qrCode,
    lxnsImportToken: input.lxnsImportToken,
    onProgress: (p) => onProgress(divingFishStageProgress(p), p.message),
  );
  if (!result.isSuccess) {
    throw SyncFlowException(result.errorMessage ?? '同步失败');
  }
  onProgress(1.0, '同步完成！共 ${result.exportedCount} 条成绩已导出到落雪');
  return result.exportedCount;
}

/// 执行「同步成绩到水鱼」：抓取成绩 → 推送到水鱼 → 刷新本地数据。
///
/// [onProgress] 用于把进度与状态文案推给调用方的按钮。
/// 失败时抛 [SyncFlowException]，调用方 catch 后自行提示。
///
/// 关于水鱼 ImportToken 绑定：绑定需要输入账号密码，没法在按钮上完成，
/// 所以这里抛出的消息带有 [SyncFlowException] 标记，
/// 调用方捕获后可再次调用 [SyncScoreDialogs.showDivingFishSyncDialog]
/// 进入绑定流程（该对话框仍然保留完整的绑定 + 同步能力）。
Future<DivingFishSyncOutcome> executeDivingFishSync(
  SyncCallbacks callbacks,
  DivingFishSyncInput input, {
  required void Function(double progress, String text) onProgress,
}) async {
  onProgress(0.05, '准备同步...');
  final result = await DivingFishProbeManager().syncByCabinetQr(
    input.qrCode,
    onProgress: (p) => onProgress(divingFishStageProgress(p), p.message),
  );

  if (!result.isSuccess) {
    final msg = result.errorMessage ?? '同步失败';
    if (msg == '用户取消同步') {
      throw const SyncFlowException('同步已取消');
    }
    if (msg.contains('divingFishImportToken') || msg.contains('missing')) {
      throw const SyncFlowException(
          '需要先绑定水鱼账号以获取 ImportToken，请重新点击「同步成绩到水鱼」完成绑定');
    }
    throw SyncFlowException(msg);
  }

  onProgress(0.70, '同步成功！正在刷新本地数据...');

  String? qq = callbacks.cachedQQ.isNotEmpty ? callbacks.cachedQQ : null;
  qq ??= await DivingFishProbeManager().fetchBindQQ();
  final hasQQ = qq != null && qq.isNotEmpty;

  var refreshed = false;
  if (hasQQ) {
    await callbacks.onSaveQQ(qq!);
    await callbacks.onSaveLastDataSource('shuiyu');
    await callbacks.onRefreshAfterSync(
      qq: qq,
      onProgress: (p, t) => onProgress(p, t),
      participateRankings: input.participateRankings,
      showNickname: input.showNickname,
    );
    refreshed = true;
  }

  onProgress(1.0, refreshed ? '全部完成！本地数据已刷新' : '同步完成！（需先登录水鱼才能自动刷新本地数据）');
  return DivingFishSyncOutcome(
    exportedCount: result.exportedCount,
    localDataRefreshed: refreshed,
  );
}

/// 同步对话框集合：用于在水鱼 / 落雪 / 我的 等位置复用
class SyncScoreDialogs {
  /// 显示水鱼同步对话框
  ///
  /// [presetQrCode] 非空时直接进入「绑定水鱼账号」阶段并复用该二维码，
  /// 用于按钮驱动流程在缺少 ImportToken 时回到这里补绑定。
  static Future<String?> showDivingFishSyncDialog(
      BuildContext context, SyncCallbacks callbacks,
      {String? presetQrCode}) async {
    final brightness = Theme.of(context).brightness;
    final TextEditingController qrController =
        TextEditingController(text: presetQrCode ?? '');
    final TextEditingController dfUserController = TextEditingController();
    final TextEditingController dfPassController = TextEditingController();
    bool isSyncing = false;
    // 带 presetQrCode 进来时直接从「绑定水鱼账号」阶段开始
    bool needDivingFishToken = presetQrCode != null;
    bool isBinding = false;
    String statusText = '';
    String? bindingError;
    double? progress;
    SyncStage? currentStage;

    bool participateRankings = false;
    bool showNickname = false;

    Future<void> loadRankingSettings() async {
      final prefs = await SharedPreferences.getInstance();
      participateRankings =
          prefs.getBool(CacheKeyConstant.participateRankings) ?? false;
      showNickname = prefs.getBool(CacheKeyConstant.showNickname) ?? false;
    }

    Future<void> saveRankingSettings() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
          CacheKeyConstant.participateRankings, participateRankings);
      await prefs.setBool(CacheKeyConstant.showNickname, showNickname);
    }

    await loadRankingSettings();

    // 闭包外持有 timer/subscription/loading tip 状态，弹窗关闭后统一释放避免泄漏
    Timer? autoCloseTimer;
    StreamSubscription<String>? tipSub;
    final stopLoadingTips = () {
      autoCloseTimer?.cancel();
      autoCloseTimer = null;
      LoadingTipsConstant.stopAutoSwitch();
      tipSub?.cancel();
      tipSub = null;
    };

    final String? result = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        int countdown = 3;
        String currentTip = LoadingTipsConstant.getRandomLoadingTip();
        return StatefulBuilder(
          builder: (context, setState) {
            final isDone = currentStage == SyncStage.completed ||
                currentStage == SyncStage.failed ||
                currentStage == SyncStage.cancelled;

            if (isDone && autoCloseTimer == null) {
              void tick() {
                countdown--;
                if (countdown > 0) {
                  setState(() {});
                  autoCloseTimer = Timer(const Duration(seconds: 1), tick);
                } else {
                  if (Navigator.of(dialogContext).canPop()) {
                    Navigator.of(dialogContext).pop();
                  }
                }
              }

              autoCloseTimer = Timer(const Duration(seconds: 1), tick);
            }

            return PopScope(
              canPop: !isSyncing && !isBinding,
              child: AlertDialog(
                title: Row(
                  children: [
                    Icon(
                      needDivingFishToken ? Icons.link : Icons.qr_code_scanner,
                      color: Theme.of(context).colorScheme.onSurface,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(needDivingFishToken ? '绑定水鱼账号' : '同步成绩到水鱼'),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ===== 阶段 1：输入 QR 码 =====
                      if (!isSyncing && !needDivingFishToken) ...[
                        Text(
                          '在舞萌|中二公众号请求并打开二维码，扫描后将字符串粘贴到下方：',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.greyHint(brightness)),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildClipboardButton(
                                setState, qrController, dialogContext),
                            _buildGalleryQrButton(setState, qrController),
                            _buildCameraScanButton(
                                setState, qrController, dialogContext),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: qrController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: '舞萌DX | 中二节奏 登入二维码(SGWCMAID...)',
                            hintStyle: TextStyle(
                                fontSize: 13,
                                color:
                                    AppColors.greyHint(brightness, shade: 400)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          title: const Text('参与排行榜',
                              style: TextStyle(fontSize: 14)),
                          value: participateRankings,
                          onChanged: (value) {
                            setState(() {
                              participateRankings = value ?? false;
                              if (!participateRankings) showNickname = false;
                            });
                          },
                        ),
                        if (participateRankings)
                          CheckboxListTile(
                            title: const Text('在排行榜中显示昵称',
                                style: TextStyle(fontSize: 14)),
                            value: showNickname,
                            onChanged: (value) {
                              setState(() {
                                showNickname = value ?? false;
                              });
                            },
                          ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.send, size: 18),
                          label: const Text('开始同步'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor:
                                Theme.of(context).colorScheme.onPrimary,
                            minimumSize: const Size.fromHeight(44),
                          ),
                          onPressed: () async {
                            final qrCode = qrController.text.trim();
                            if (qrCode.isEmpty) {
                              Fluttertoast.showToast(msg: '请先粘贴舞萌|中二登入二维码字符串');
                              return;
                            }
                            await saveRankingSettings();
                            setState(() {
                              isSyncing = true;
                              statusText = '准备同步...';
                              currentStage = SyncStage.authenticating;
                            });

                            LoadingTipsConstant.startAutoSwitch(3);
                            tipSub?.cancel();
                            tipSub =
                                LoadingTipsConstant.tipStream.listen((tip) {
                              setState(() => currentTip = tip);
                            });

                            if (!qrCode.startsWith('SGWCMAID')) {
                              setState(() {
                                currentStage = SyncStage.failed;
                                statusText = '无效的二维码，请使用舞萌|中二公众号生成的登入二维码';
                                isSyncing = false;
                              });
                              LoadingTipsConstant.stopAutoSwitch();
                              tipSub?.cancel();
                              return;
                            }

                            final result =
                                await DivingFishProbeManager().syncByCabinetQr(
                              qrCode,
                              onProgress: (p) {
                                setState(() {
                                  currentStage = p.stage;
                                  statusText = p.message;
                                  progress = _stageProgress(p);
                                });
                              },
                            );

                            LoadingTipsConstant.stopAutoSwitch();
                            tipSub?.cancel();

                            if (result.isSuccess) {
                              setState(() {
                                currentStage = SyncStage.exporting;
                                statusText = '同步成功！正在刷新本地数据...';
                                progress = 0.70;
                              });

                              String? qq = callbacks.cachedQQ.isNotEmpty
                                  ? callbacks.cachedQQ
                                  : null;
                              if (qq == null) {
                                qq = await DivingFishProbeManager()
                                    .fetchBindQQ();
                              }
                              final hasQQ = qq != null && qq.isNotEmpty;
                              if (hasQQ) {
                                await callbacks.onSaveQQ(qq);
                                await callbacks.onSaveLastDataSource('shuiyu');
                              }

                              if (hasQQ) {
                                await callbacks.onRefreshAfterSync(
                                  qq: qq!,
                                  onProgress: (p, t) {
                                    setState(() {
                                      progress = p;
                                      statusText = t;
                                    });
                                  },
                                  participateRankings: participateRankings,
                                  showNickname: showNickname,
                                );
                              } else {
                                setState(() {
                                  progress = 0.70;
                                });
                              }

                              setState(() {
                                currentStage = SyncStage.completed;
                                progress = 1.0;
                                if (hasQQ) {
                                  statusText =
                                      '全部完成！${result.exportedCount} 条成绩已同步，本地数据已刷新';
                                } else {
                                  statusText =
                                      '同步完成！${result.exportedCount} 条成绩已推送到水鱼\n（需先登录水鱼才能自动刷新本地数据）';
                                }
                              });
                            } else if (result.errorMessage == '用户取消同步') {
                              setState(() {
                                currentStage = SyncStage.cancelled;
                                statusText = '同步已取消';
                              });
                            } else {
                              final msg = result.errorMessage ?? '';
                              if (msg.contains('divingFishImportToken') ||
                                  msg.contains('missing')) {
                                needDivingFishToken = true;
                                isSyncing = false;
                              } else {
                                setState(() {
                                  currentStage = SyncStage.failed;
                                  statusText = msg;
                                });
                              }
                            }
                          },
                        ),
                      ],

                      // ===== 阶段 2：绑定水鱼账号 =====
                      if (needDivingFishToken && !isSyncing) ...[
                        Text(
                          '需要绑定你的水鱼账号以获取 ImportToken：',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.greyHint(brightness)),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: dfUserController,
                          decoration: InputDecoration(
                            labelText: '水鱼用户名',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: dfPassController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: '水鱼密码',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        if (bindingError != null) ...[
                          const SizedBox(height: 8),
                          Text(bindingError!,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.errorRed(brightness))),
                        ],
                      ],

                      // ===== 进度显示 =====
                      if (isSyncing) ...[
                        const SizedBox(height: 12),
                        Text(statusText,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: currentStage == SyncStage.failed
                                    ? AppColors.errorRed(brightness)
                                    : currentStage == SyncStage.completed ||
                                            currentStage == SyncStage.cancelled
                                        ? AppColors.successGreen(brightness)
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface)),
                        if (currentStage != SyncStage.completed &&
                            currentStage != SyncStage.failed &&
                            currentStage != SyncStage.cancelled) ...[
                          const SizedBox(height: 10),
                          if (progress != null)
                            LinearProgressIndicator(
                                value: progress,
                                color: Theme.of(context).colorScheme.primary)
                          else
                            LinearProgressIndicator(
                                color: Theme.of(context).colorScheme.primary),
                          const SizedBox(height: 12),
                          Center(
                            child: Text(
                              currentTip,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.greyHint(brightness,
                                      shade: 600)),
                            ),
                          ),
                        ],
                        if (currentStage == SyncStage.completed) ...[
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              '成绩已同步！可前往水鱼查看',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.greyHint(brightness,
                                      shade: 600)),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                actions: [
                  if (!isSyncing && !needDivingFishToken)
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('关闭'),
                    ),
                  if (isSyncing &&
                      (currentStage == SyncStage.completed ||
                          currentStage == SyncStage.failed ||
                          currentStage == SyncStage.cancelled))
                    TextButton(
                      onPressed: () {
                        autoCloseTimer?.cancel();
                        final fc = currentStage == SyncStage.completed
                            ? DivingFishProbeManager().currentFriendCode
                            : null;
                        Navigator.of(dialogContext).pop(fc);
                      },
                      child: Text(countdown > 0 ? '确定 ($countdown)' : '确定'),
                    ),
                  if (needDivingFishToken && !isSyncing) ...[
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('跳过'),
                    ),
                    ElevatedButton.icon(
                      icon: isBinding
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.link, size: 18),
                      label: Text(isBinding ? '绑定中...' : '绑定并同步'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                      ),
                      onPressed: isBinding
                          ? null
                          : () async {
                              final username = dfUserController.text.trim();
                              final password = dfPassController.text.trim();
                              if (username.isEmpty || password.isEmpty) {
                                setState(() {
                                  bindingError = '请输入水鱼用户名和密码';
                                });
                                return;
                              }
                              setState(() {
                                isBinding = true;
                                isSyncing = true;
                                currentStage = SyncStage.exporting;
                                progress = 0.68;
                                bindingError = null;
                              });
                              final ok = await DivingFishProbeManager()
                                  .bindDivingFishAccount(username, password);

                              if (!ok) {
                                setState(() {
                                  isBinding = false;
                                  isSyncing = false;
                                  bindingError = '绑定失败，请检查用户名密码是否正确';
                                });
                                return;
                              }

                              // 绑定成功 → 同步缓存水鱼 JWT（用于后续 fetchBindQQ）
                              final loginResult = await DivingFishProbeManager()
                                  .loginDivingFishDirect(username, password);
                              if (loginResult == null) {
                                setState(() {
                                  isBinding = false;
                                  isSyncing = false;
                                  bindingError = '水鱼登录成功但获取账号资料失败，请稍后重试';
                                });
                                return;
                              }

                              final exportResult =
                                  await DivingFishProbeManager()
                                      .exportLatestToDivingFish(
                                onProgress: (p) {
                                  setState(() {
                                    currentStage = p.stage;
                                    statusText = p.message;
                                    progress = _stageProgress(p);
                                  });
                                },
                                bindCachedImportToken: false,
                              );
                              if (exportResult.isSuccess) {
                                setState(() {
                                  statusText = '同步成功！正在刷新本地数据...';
                                  progress = 0.70;
                                });
                                String? qq = callbacks.cachedQQ.isNotEmpty
                                    ? callbacks.cachedQQ
                                    : null;
                                if (qq == null) {
                                  qq = await DivingFishProbeManager()
                                      .fetchBindQQ();
                                }
                                final hasQQ = qq != null && qq.isNotEmpty;
                                if (hasQQ) {
                                  await callbacks.onSaveQQ(qq);
                                  await callbacks
                                      .onSaveLastDataSource('shuiyu');
                                  await callbacks.onRefreshAfterSync(
                                    qq: qq,
                                    onProgress: (p, t) {
                                      setState(() {
                                        progress = p;
                                        statusText = t;
                                      });
                                    },
                                    participateRankings: participateRankings,
                                    showNickname: showNickname,
                                  );
                                }
                                setState(() {
                                  isBinding = false;
                                  currentStage = SyncStage.completed;
                                  progress = 1.0;
                                  statusText = hasQQ
                                      ? '全部完成！${exportResult.exportedCount} 条成绩已同步，本地数据已刷新'
                                      : '同步完成！${exportResult.exportedCount} 条成绩已推送到水鱼\n（需先登录水鱼才能自动刷新本地数据）';
                                });
                                final fc =
                                    DivingFishProbeManager().currentFriendCode;
                                Navigator.of(dialogContext).pop(fc);
                              } else {
                                setState(() {
                                  isBinding = false;
                                  isSyncing = false;
                                  currentStage = SyncStage.failed;
                                  bindingError =
                                      exportResult.errorMessage ?? '导出失败，请稍后重试';
                                });
                              }
                            },
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );

    // 弹窗关闭（无论成功失败或被系统返回）后统一释放资源，避免 Timer/Subscription/Controller 泄漏
    stopLoadingTips();
    qrController.dispose();
    dfUserController.dispose();
    dfPassController.dispose();

    return result;
  }

  /// 显示水鱼登录对话框
  static Future<void> showDivingFishLoginDialog(
      BuildContext context, SyncCallbacks callbacks) async {
    final brightness = Theme.of(context).brightness;
    final TextEditingController userController = TextEditingController();
    final TextEditingController passController = TextEditingController();
    bool isLoggingIn = false;
    bool loginSuccess = false;
    String? importedToken;
    String statusText = '';
    String? errorMsg;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    loginSuccess ? Icons.check_circle : Icons.login,
                    color: loginSuccess
                        ? AppColors.successGreen(brightness)
                        : Theme.of(context).colorScheme.onSurface,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(loginSuccess ? '登录成功' : '登录水鱼'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!loginSuccess) ...[
                      Text(
                        '输入你的 Diving-Fish 水鱼账号密码以获取 ImportToken：',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.greyHint(brightness)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: userController,
                        decoration: InputDecoration(
                          labelText: '用户名',
                          hintText: 'Diving-Fish 用户名',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: passController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: '密码',
                          hintText: 'Diving-Fish 密码',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                      ),
                      if (errorMsg != null) ...[
                        const SizedBox(height: 8),
                        Text(errorMsg!,
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.errorRed(brightness))),
                      ],
                    ] else ...[
                      Icon(Icons.check_circle,
                          color: AppColors.successGreen(brightness), size: 48),
                      const SizedBox(height: 12),
                      Text(
                        statusText.isNotEmpty ? statusText : '登录成功',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text('ImportToken 已获取并缓存',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.greyHint(brightness))),
                      const SizedBox(height: 4),
                      Text('Token: ${importedToken ?? "***"}',
                          style: TextStyle(
                              fontSize: 11,
                              color:
                                  AppColors.greyHint(brightness, shade: 600))),
                      const SizedBox(height: 4),
                      Text('现在可以使用"同步成绩"功能一键同步到水鱼了',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.greyHint(brightness))),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(loginSuccess ? '完成' : '取消'),
                ),
                if (!loginSuccess)
                  ElevatedButton.icon(
                    icon: isLoggingIn
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.login, size: 18),
                    label: Text(isLoggingIn ? '登录中...' : '登录'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    onPressed: isLoggingIn
                        ? null
                        : () async {
                            final username = userController.text.trim();
                            final password = passController.text.trim();
                            if (username.isEmpty || password.isEmpty) {
                              setState(() => errorMsg = '请输入用户名和密码');
                              return;
                            }
                            setState(() {
                              isLoggingIn = true;
                              errorMsg = null;
                            });
                            final result = await DivingFishProbeManager()
                                .loginDivingFishDirect(username, password);
                            if (result != null &&
                                result.tryGet<String>('importToken') != null) {
                              final token =
                                  result.tryGet<String>('importToken') ?? '';
                              final nickname =
                                  result.tryGet<String>('nickname') ?? '';
                              final plate =
                                  result.tryGet<String>('plate') ?? '';
                              setState(() {
                                isLoggingIn = false;
                                loginSuccess = true;
                                importedToken = token.isNotEmpty
                                    ? '${token.substring(0, token.length > 12 ? 12 : token.length)}...'
                                    : '***';
                                statusText =
                                    '欢迎，$nickname${plate.isNotEmpty ? " ($plate)" : ""}';
                              });
                              final bindQQ =
                                  result.tryGet<String>('bind_qq') ?? '';
                              if (bindQQ.isNotEmpty) {
                                await callbacks.onSaveQQ(bindQQ);
                              }
                              await callbacks.onLoginStateChanged();
                            } else {
                              setState(() {
                                isLoggingIn = false;
                                errorMsg = '登录失败：用户名或密码错误';
                              });
                            }
                          },
                  ),
              ],
            );
          },
        );
      },
    );

    // 弹窗关闭后释放 controllers，避免泄漏
    userController.dispose();
    passController.dispose();
  }

  // ===== 内部辅助 =====

  static double _stageProgress(SyncProgress p) {
    switch (p.stage) {
      case SyncStage.authenticating:
        return 0.02;
      case SyncStage.requesting:
        return 0.10;
      case SyncStage.sendingFriendRequest:
        return 0.18;
      case SyncStage.waitingAcceptance:
        return 0.25;
      case SyncStage.scraping:
        return 0.25 + (p.progress ?? 0) * 0.40;
      case SyncStage.exporting:
        return 0.68;
      default:
        return 0.0;
    }
  }

  static Widget _buildClipboardButton(StateSetter setState,
      TextEditingController qrCtrl, BuildContext dialogContext) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.paste, size: 16),
      label: const Text('读取剪贴板', style: TextStyle(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      onPressed: () async {
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        final text = data?.text ?? '';
        if (text.trim().startsWith('SGWCMAID')) {
          setState(() {
            qrCtrl.text = text.trim();
          });
          Fluttertoast.showToast(msg: '已识别到有效二维码字符串，已自动填入');
        } else if (text.isNotEmpty) {
          final confirmed = await showDialog<bool>(
            context: dialogContext,
            builder: (ctx) => AlertDialog(
              title: const Text('提示'),
              content: const Text('剪贴板内容不是有效的登入二维码，仍要填入吗？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('填入'),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            setState(() {
              qrCtrl.text = text;
            });
          }
        } else {
          Fluttertoast.showToast(msg: '剪贴板为空');
        }
      },
    );
  }

  static Widget _buildGalleryQrButton(
      StateSetter setState, TextEditingController qrCtrl) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.photo_library, size: 16),
      label: const Text('从相册识别', style: TextStyle(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      onPressed: () async {
        try {
          final picker = ImagePicker();
          final pickedFile = await picker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 100,
          );
          if (pickedFile == null) return;
          final controller = MobileScannerController();
          try {
            final barcodes = await controller.analyzeImage(pickedFile.path);
            if (barcodes != null && barcodes.barcodes.isNotEmpty) {
              final qrText = barcodes.barcodes.first.rawValue ?? '';
              if (qrText.isNotEmpty) {
                setState(() {
                  qrCtrl.text = qrText;
                });
                Fluttertoast.showToast(msg: '已识别到二维码，已自动填入');
              } else {
                Fluttertoast.showToast(msg: '未能从图片中识别到二维码内容');
              }
            } else {
              Fluttertoast.showToast(msg: '未在图片中检测到二维码');
            }
          } finally {
            controller.dispose();
          }
        } catch (e) {
          Fluttertoast.showToast(msg: '识别失败: $e');
        }
      },
    );
  }

  static Widget _buildCameraScanButton(StateSetter setState,
      TextEditingController qrCtrl, BuildContext dialogContext) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.qr_code_scanner, size: 16),
      label: const Text('扫描二维码', style: TextStyle(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      onPressed: () async {
        try {
          final qrText = await Navigator.push<String>(
            dialogContext,
            MaterialPageRoute(builder: (_) => const QrScannerPage()),
          );
          if (qrText != null && qrText.isNotEmpty) {
            setState(() {
              qrCtrl.text = qrText;
            });
            Fluttertoast.showToast(msg: '已识别到二维码，已自动填入');
          }
        } catch (e) {
          Fluttertoast.showToast(msg: '扫描失败: $e');
        }
      },
    );
  }
}

/// 摄像头扫二维码页面
class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  bool _hasPopped = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('扫描二维码'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: MobileScanner(
        onDetect: (BarcodeCapture capture) {
          if (_hasPopped) return;
          final barcode = capture.barcodes.firstOrNull;
          if (barcode != null &&
              barcode.rawValue != null &&
              barcode.rawValue!.isNotEmpty) {
            _hasPopped = true;
            Navigator.pop(context, barcode.rawValue);
          }
        },
        errorBuilder: (context, error) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('摄像头错误: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('返回'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
