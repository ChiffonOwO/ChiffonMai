import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../api/ApiUrls.dart';
import '../constant/CacheKeyConstant.dart';

// =============================================================================
// 调试开关
// =============================================================================

/// 设为 false 可关闭所有 Probe 调试日志
const bool _kDebugProbe = true;
void _log(String msg) {
  if (_kDebugProbe) debugPrint('[Probe] $msg');
}

// =============================================================================
// 状态 & 结果模型
// =============================================================================

/// 同步阶段
enum SyncStage {
  authenticating,       // 正在验证 QR 码
  requesting,           // 正在创建抓取任务
  sendingFriendRequest, // Bot 正在发送好友申请
  waitingAcceptance,    // 等待好友申请通过
  scraping,             // 正在抓取成绩数据
  exporting,            // 正在同步到水鱼
  completed,            // 同步完成
  failed,               // 同步失败
  cancelled,            // 用户取消
}

/// 进度信息
class SyncProgress {
  final SyncStage stage;
  final String message;
  final int completedDiffs;
  final int totalDiffs;

  const SyncProgress({
    required this.stage,
    required this.message,
    this.completedDiffs = 0,
    this.totalDiffs = 0,
  });

  /// 0.0 ~ 1.0，无法确定时返回 null
  double? get progress =>
      totalDiffs > 0 ? completedDiffs / totalDiffs : null;

  @override
  String toString() =>
      'SyncProgress(stage: $stage, message: "$message", diffs: $completedDiffs/$totalDiffs)';
}

/// 同步结果
class SyncResult {
  final bool isSuccess;
  final String? errorMessage;
  final String? friendCode;
  final int exportedCount;

  const SyncResult._({
    required this.isSuccess,
    this.errorMessage,
    this.friendCode,
    this.exportedCount = 0,
  });

  factory SyncResult.success({String? friendCode, int exportedCount = 0}) =>
      SyncResult._(isSuccess: true, friendCode: friendCode, exportedCount: exportedCount);

  factory SyncResult.failure(String message, {String? friendCode}) =>
      SyncResult._(isSuccess: false, errorMessage: message, friendCode: friendCode);

  factory SyncResult.cancelled() =>
      SyncResult._(isSuccess: false, errorMessage: '用户取消同步');

  @override
  String toString() {
    if (isSuccess) return 'SyncResult.success(friendCode: $friendCode, exported: $exportedCount)';
    return 'SyncResult.failure("$errorMessage")';
  }
}


// =============================================================================
// DivingFishProbeManager（单例）
// =============================================================================

/// QR 码一键同步水鱼管理器
///
/// 调用 [maimai-score-hub](https://github.com/bakapiano/maimai-score-hub)
/// 的公开 API，完成「扫 QR → NET 抓成绩 → 推送到水鱼」全流程。
///
/// 使用方式：
/// ```dart
/// final result = await DivingFishProbeManager().syncByQrCode(
///   qrCode,
///   onProgress: (p) => print('${p.stage.name}: ${p.message}'),
/// );
/// if (result.isSuccess) {
///   print('同步成功！${result.exportedCount} 条成绩');
/// }
/// ```
class DivingFishProbeManager {
  // ---- 单例 ----
  static final DivingFishProbeManager _instance = DivingFishProbeManager._internal();
  factory DivingFishProbeManager() => _instance;
  DivingFishProbeManager._internal() {
    _log('DivingFishProbeManager 单例初始化');
  }

  // ---- 内部状态 ----
  bool _isSyncing = false;
  bool _cancelled = false;
  String? _authToken;
  String? _friendCode;

  // ---- 配置 ----
  static const _pollInterval = Duration(seconds: 3);
  static const _pollCountLogEvery = 10; // 每 N 次轮询输出一次日志

  // ---- Debug：用于统计轮询次数 ----
  int _pollCount = 0;

  // ===========================================================================
  // 对外 API
  // ===========================================================================

  /// 是否正在同步中
  bool get isSyncing => _isSyncing;

  /// 当前同步的 friendCode（同步成功后可通过此获取）
  String? get currentFriendCode => _friendCode;

  /// 从缓存获取上次同步的好友码
  Future<String?> getCachedFriendCode() async {
    final prefs = await SharedPreferences.getInstance();
    final fc = prefs.getString(CacheKeyConstant.probeFriendCode);
    _log('getCachedFriendCode → ${fc ?? "null"}');
    return fc;
  }

  /// 从缓存获取上次同步时间戳
  Future<int?> getLastSyncTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(CacheKeyConstant.probeLastSyncTime);
    _log('getLastSyncTimestamp → ${ts != null ? DateTime.fromMillisecondsSinceEpoch(ts).toIso8601String() : "null"}');
    return ts;
  }

  /// 清除缓存的认证信息
  Future<void> clearAuth() async {
    _log('clearAuth — 清除 token + friendCode');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(CacheKeyConstant.probeAuthToken);
    await prefs.remove(CacheKeyConstant.probeFriendCode);
    _authToken = null;
    _friendCode = null;
  }

  /// 确保 _authToken 可用：优先用内存中的，其次从 SharedPreferences 缓存恢复
  Future<bool> _ensureAuthToken() async {
    if (_authToken != null) return true;

    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(CacheKeyConstant.probeAuthToken);
    if (cached != null && cached.isNotEmpty) {
      _authToken = cached;
      _friendCode = prefs.getString(CacheKeyConstant.probeFriendCode);
      _log('_ensureAuthToken: 从缓存恢复了 token (friendCode=$_friendCode)');
      return true;
    }

    _log('_ensureAuthToken: 无缓存 token');
    return false;
  }

  // ===========================================================================
  // 核心方法：一键同步
  // ===========================================================================

  /// 通过 QR 码一键同步成绩到水鱼
  ///
  /// [qrCode] 舞萌 DX 机台上扫到的 QR 码字符串
  /// [onProgress] 进度回调，可用于更新 UI
  /// [timeout] 最大等待时间，默认 8 分钟
  Future<SyncResult> syncByQrCode(
    String qrCode, {
    void Function(SyncProgress progress)? onProgress,
    Duration timeout = const Duration(minutes: 8),
  }) async {
    final methodStart = DateTime.now();
    _log('══════════════════════════════════════════');
    _log('syncByQrCode 开始');
    _log('  QR长度: ${qrCode.length} 字符');
    _log('  QR前20字符: ${qrCode.length > 20 ? '${qrCode.substring(0, 20)}...' : qrCode}');
    _log('  超时设置: ${timeout.inMinutes} 分钟');
    _log('  当前状态: isSyncing=$_isSyncing, hasToken=${_authToken != null}, friendCode=$_friendCode');

    // ---- 防并发 ----
    if (_isSyncing) {
      _log('⚠ 拒绝：同步已在进行中');
      return SyncResult.failure('同步已在进行中，请稍后重试');
    }
    _isSyncing = true;
    _cancelled = false;
    _pollCount = 0;

    try {
      // ===== Step 1: QR 码认证 =====
      _log('── Step 1: QR 码认证 ──');
      _emit(onProgress, const SyncProgress(
        stage: SyncStage.authenticating,
        message: '正在验证二维码...',
      ));

      final loginBefore = DateTime.now();
      final loginData = await _loginByQr(qrCode);
      _log('  _loginByQr 耗时: ${DateTime.now().difference(loginBefore).inMilliseconds}ms');

      if (loginData == null) {
        _log('✗ Step 1 失败: loginData 为 null');
        return SyncResult.failure('二维码无效或已过期，请重新扫描');
      }
      _log('  loginData 完整响应: $loginData');

      _authToken = loginData['token'] as String?;
      _friendCode = (loginData['user'] as Map<String, dynamic>?)?.tryGet<String>('friendCode');

      _log('  解析 token: ${_authToken != null ? "${_authToken!.substring(0, _authToken!.length > 15 ? 15 : _authToken!.length)}..." : "null"}');
      _log('  解析 friendCode: $_friendCode');

      if (_authToken == null || _friendCode == null) {
        _log('✗ Step 1 失败: token 或 friendCode 为 null');
        return SyncResult.failure('Hub 响应异常——缺少 token 或 friendCode，请稍后重试');
      }

      _log('✓ 认证成功，friendCode=$_friendCode');

      // ===== Step 2: 创建抓取任务 =====
      _log('── Step 2: 创建抓取任务 ──');
      _emit(onProgress, const SyncProgress(
        stage: SyncStage.requesting,
        message: '正在创建抓取任务...',
      ));

      final requestBefore = DateTime.now();
      var jobData = await _createDxnetJob(jobType: 'update_score');
      _log('  _createDxnetJob(update_score) 耗时: ${DateTime.now().difference(requestBefore).inMilliseconds}ms');

      if (jobData == null) {
        _log('✗ Step 2 失败: jobData 为 null');
        return SyncResult.failure('创建抓取任务失败，请稍后重试');
      }
      _log('  jobData 完整响应: $jobData');

      // ── 处理 needs_friendship：先建立好友关系 ──
      if (jobData['_needsFriendship'] == true) {
        _log('  需要先建立好友关系');
        final friendRequestBefore = DateTime.now();

        // Step 2a: 创建好友请求 job
        _emit(onProgress, const SyncProgress(
          stage: SyncStage.sendingFriendRequest,
          message: 'Bot 正在发送好友申请...',
        ));

        final friendResult = await _createDxnetJob(jobType: 'send_friend_request');
        if (friendResult == null || friendResult['_needsFriendship'] == true) {
          _log('✗ Step 2a 失败: 创建好友请求 job 失败');
          return SyncResult.failure('创建好友请求失败，请稍后重试');
        }

        final friendJobId = friendResult['jobId'] as String?;
        _log('  好友请求 jobId: $friendJobId');
        if (friendJobId == null) {
          return SyncResult.failure('Hub 未返回好友请求任务 ID');
        }

        // Step 2b: 等待好友关系建立
        final friendResult2 = await _pollUntilDone(
          friendJobId,
          timeout: const Duration(minutes: 5),
          onProgress: onProgress,
        );

        if (_cancelled) {
          _log('⊗ 用户取消（好友请求阶段）');
          return SyncResult.cancelled();
        }

        if (friendResult2 == null) {
          _log('✗ 好友请求超时');
          return SyncResult.failure(
            '好友请求超时——请在 NET / 机台上通过好友申请后重试',
          );
        }

        final friendServerStatus = friendResult2.tryGet<String>('status') ?? '';
        if (friendServerStatus == 'failed' || friendServerStatus == 'canceled') {
          final errMsg = friendResult2.tryGet<String>('message') ?? '好友请求失败';
          _log('✗ 好友请求终止: status=$friendServerStatus, msg=$errMsg');
          return SyncResult.failure(errMsg);
        }

        _log('✓ 好友关系已建立，耗时 ${DateTime.now().difference(friendRequestBefore).inSeconds}s');

        // Step 2c: 好友就绪后重试 update_score
        _emit(onProgress, const SyncProgress(
          stage: SyncStage.requesting,
          message: '好友已添加，正在创建抓取任务...',
        ));

        jobData = await _createDxnetJob(
          jobType: 'update_score',
          friendshipJobId: friendJobId,
        );

        if (jobData == null || jobData['_needsFriendship'] == true) {
          _log('✗ Step 2c 失败: 重试 update_score 失败');
          return SyncResult.failure('创建抓取任务失败，请稍后重试');
        }
        _log('  jobData (retry) 完整响应: $jobData');
      }

      final jobId = jobData['jobId'] as String?;
      _log('  解析 jobId: $jobId');

      if (jobId == null) {
        _log('✗ Step 2 失败: jobId 为 null');
        return SyncResult.failure('Hub 未返回任务 ID');
      }

      _log('✓ 任务创建成功，jobId=$jobId');

      // ===== Step 3: 轮询等待完成 =====
      _log('── Step 3: 开始轮询 ──');
      _log('  轮询间隔: ${_pollInterval.inSeconds}s, 超时: ${timeout.inMinutes}min');
      final startTime = DateTime.now();
      String? lastStage;
      String? lastServerStatus;
      int lastCompletedDiffs = -1;

      while (!_cancelled) {
        _pollCount++;

        // 超时检查
        final elapsed = DateTime.now().difference(startTime);
        if (elapsed > timeout) {
          _log('✗ 轮询超时: 已耗时 ${elapsed.inSeconds}s, 共轮询 $_pollCount 次');
          return SyncResult.failure(
            '同步超时——成绩抓取耗时超过 ${timeout.inMinutes} 分钟，'
            '可能是 Bot 好友申请未被通过。请在 NET 上确认好友申请后重试。',
          );
        }

        // 轮询
        final pollBefore = DateTime.now();
        final status = await _pollJobStatus(jobId);
        final pollTime = DateTime.now().difference(pollBefore).inMilliseconds;

        if (status == null) {
          _log('✗ 轮询 #$_pollCount 失败: status 为 null (耗时 ${pollTime}ms)');
          return SyncResult.failure('查询任务状态失败，请检查网络后重试');
        }

        final serverStatus = status.tryGet<String>('status') ?? '';
        final stage = status.tryGet<String>('stage') ?? '';
        final done = status.tryGet<bool>('done') ?? false;
        final statusMsg = status.tryGet<String>('message') ?? '';

        // 解析分数进度
        final sp = status.tryGet<Map<String, dynamic>>('scoreProgress');
        final completedDiffs = (sp?.tryGet<List>('completedDiffs')?.length) ?? 0;
        final totalDiffs = sp?.tryGet<int>('totalDiffs') ?? 0;

        // 只在状态变化 或 抓取进度变化 或 每 N 次 时输出详细日志
        final diffsChanged = completedDiffs != lastCompletedDiffs;
        final stageChanged = stage != lastStage || serverStatus != lastServerStatus;
        final shouldLog = stageChanged || diffsChanged || (_pollCount % _pollCountLogEvery == 1);

        if (shouldLog) {
          _log('  轮询 #$_pollCount (耗时${pollTime}ms): done=$done, status=$serverStatus, '
              'stage=$stage, diffs=$completedDiffs/$totalDiffs'
              '${statusMsg.isNotEmpty ? ', msg="$statusMsg"' : ''}');
        }

        lastStage = stage;
        lastServerStatus = serverStatus;
        lastCompletedDiffs = completedDiffs;

        // 失败
        if (serverStatus == 'failed' || serverStatus == 'canceled') {
          final msg = status.tryGet<String>('message') ?? '任务失败';
          _log('✗ 任务终止: status=$serverStatus, msg="$msg"');
          _log('  完整 status 响应: $status');
          return SyncResult.failure(msg);
        }

        // 完毕
        if (done || serverStatus == 'completed') {
          _log('✓ 抓取完成: 共轮询 $_pollCount 次, 总耗时 ${elapsed.inSeconds}s');
          _log('════════════ 抓取完成 - 完整返回字段 ════════════');
          _log('  done: $done');
          _log('  status: $serverStatus');
          _log('  stage: $stage');
          _log('  message: $statusMsg');
          _log('  scoreProgress:');
          if (sp != null) {
            _log('    totalDiffs: ${sp.tryGet<int>('totalDiffs')}');
            _log('    completedDiffs: ${sp.tryGet<List>('completedDiffs')}');
          }
          _log('  ── 原始 JSON ──');
          _log('  ${const JsonEncoder.withIndent('    ').convert(status)}');
          _log('══════════════════════════════════════════════');
          break;
        }

        // 进度文案
        if (stageChanged) {
          final progress = _mapStage(stage, status);
          if (progress != null) {
            _log('  → 阶段切换: $stage → ${progress.message}');
            _emit(onProgress, progress);
          }
        } else if (diffsChanged && totalDiffs > 0) {
          // 同阶段但抓取进度有更新，刷新进度
          _log('  → 抓取进度: $completedDiffs/$totalDiffs');
          final progress = _mapStage(stage, status);
          if (progress != null) {
            _emit(onProgress, progress);
          }
        }

        await Future.delayed(_pollInterval);
      }

      if (_cancelled) {
        _log('⊗ 用户取消: 已轮询 $_pollCount 次, 耗时 ${DateTime.now().difference(startTime).inSeconds}s');
        return SyncResult.cancelled();
      }

      // ===== Step 4: 导出到水鱼 ──
      _log('── Step 4: 导出到水鱼 ──');

      // 尝试将本地缓存的水鱼 importToken 绑定到 Hub
      _log('  尝试绑定本地缓存的水鱼 importToken...');
      final bindResult = await _bindCachedImportTokenToHub();
      _log('  绑定结果: $bindResult');

      _emit(onProgress, const SyncProgress(
        stage: SyncStage.exporting,
        message: '正在同步到水鱼...',
      ));

      final exportBefore = DateTime.now();
      final exportData = await _exportToDivingFish();
      _log('  _exportToDivingFish 耗时: ${DateTime.now().difference(exportBefore).inMilliseconds}ms');

      if (exportData == null) {
        _log('✗ Step 4 失败: exportData 为 null');
        return SyncResult.failure(
          '成绩抓取成功，但同步水鱼失败。可稍后手动重试导出。',
          friendCode: _friendCode,
        );
      }
      _log('  exportData 完整响应: $exportData');

      final exportJob = exportData.tryGet<Map<String, dynamic>>('job');
      final exportResult = exportJob?.tryGet<Map<String, dynamic>>('result');
      final divingFish = exportResult?.tryGet<Map<String, dynamic>>('divingFish');
      final diveStatus = divingFish?.tryGet<String>('status') ?? '';
      final exported = divingFish?.tryGet<int>('exported') ?? 0;
      final scores = divingFish?.tryGet<int>('scores') ?? 0;
      final exportMsg = divingFish?.tryGet<String>('message') ?? '';
      _log('  diveStatus=$diveStatus, exported=$exported, scores=$scores, msg="$exportMsg"');

      if (diveStatus == 'success') {
        await _cacheSyncState();
        _log('✓ 缓存同步状态完成');
        _log('══════════════════════════════════════════');
        _log('syncByQrCode 成功完成');
        _log('  总耗时: ${DateTime.now().difference(methodStart).inSeconds}s');
        _log('  friendCode: $_friendCode');
        _log('  导出成绩数: $exported');
        _log('══════════════════════════════════════════');

        _emit(onProgress, SyncProgress(
          stage: SyncStage.completed,
          message: '同步完成！共同步 $exported 条成绩',
          completedDiffs: 1,
          totalDiffs: 1,
        ));

        return SyncResult.success(
          friendCode: _friendCode,
          exportedCount: exported,
        );
      } else {
        _log('✗ 水鱼导出失败 (diveStatus=$diveStatus): $exportMsg');
        return SyncResult.failure(
          '水鱼导出失败：${exportMsg.isNotEmpty ? exportMsg : diveStatus}',
          friendCode: _friendCode,
        );
      }
    } catch (e, stack) {
      _log('✗ 同步异常');
      _log('  异常类型: ${e.runtimeType}');
      _log('  异常信息: $e');
      _log('  堆栈跟踪: $stack');
      return SyncResult.failure('同步异常：$e');
    } finally {
      _isSyncing = false;
      _log('  最终状态: isSyncing=$_isSyncing, cancelled=$_cancelled');
    }
  }

  /// 取消当前正在进行的同步
  void cancelSync() {
    _log('cancelSync 被调用 (当前轮询次数: $_pollCount)');
    _cancelled = true;
  }

  /// 通过机台 QR 码（SGWCMAID 开头）一键同步成绩到水鱼
  ///
  /// 使用 Maimai Score Hub 的 cabinet-score-jobs API，
  /// 无需 Bot 好友关系即可直接从机台抓取成绩。
  ///
  /// [qrCode] 机台上扫到的 QR 码字符串（以 SGWCMAID 开头）
  /// [onProgress] 进度回调
  /// [timeout] 最大等待时间，默认 5 分钟
  Future<SyncResult> syncByCabinetQr(
    String qrCode, {
    void Function(SyncProgress progress)? onProgress,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final methodStart = DateTime.now();
    _log('══════════════════════════════════════════');
    _log('syncByCabinetQr 开始');
    _log('  QR长度: ${qrCode.length} 字符');
    _log('  QR前30字符: ${qrCode.length > 30 ? '${qrCode.substring(0, 30)}...' : qrCode}');
    _log('  超时设置: ${timeout.inMinutes} 分钟');

    if (_isSyncing) {
      _log('⚠ 拒绝：同步已在进行中');
      return SyncResult.failure('同步已在进行中，请稍后重试');
    }

    // 恢复或检查认证 token
    final hasToken = await _ensureAuthToken();
    if (!hasToken) {
      _log('✗ 无认证 token，无法使用机台直同步');
      return SyncResult.failure(
        '尚未建立认证，请先使用「同步成绩到水鱼」完成一次 NET QR 同步',
      );
    }

    _isSyncing = true;
    _cancelled = false;
    _pollCount = 0;

    try {
      // ===== Step 1: 创建 Cabinet Score Job =====
      _log('── Step 1: 创建 Cabinet Score Job ──');
      _emit(onProgress, const SyncProgress(
        stage: SyncStage.requesting,
        message: '正在提交机台二维码...',
      ));

      final createResult = await _createCabinetScoreJob(qrCode);
      if (createResult == null) {
        _log('✗ 创建 Cabinet Job 失败');
        return SyncResult.failure('提交机台二维码失败，请检查网络后重试');
      }

      final jobId = createResult['jobId'] as String?;
      if (jobId == null) {
        _log('✗ 创建响应缺少 jobId');
        return SyncResult.failure('Hub 未返回任务 ID');
      }
      _log('✓ Cabinet Job 创建成功，jobId=$jobId');

      // 检查是否已完成
      final initialJob = createResult.tryGet<Map<String, dynamic>>('job');
      final initialStatus = initialJob?.tryGet<String>('status') ?? '';
      if (initialStatus == 'completed') {
        _log('✓ Cabinet Job 已完成（即时返回），scoreCount=${initialJob?.tryGet<int>('scoreCount')}');

        // 导出到水鱼
        return await _doExportPhase(onProgress, methodStart);
      }

      // ===== Step 2: 轮询等待完成 =====
      _log('── Step 2: 开始轮询 Cabinet Job ──');
      final startTime = DateTime.now();
      String? lastStage;
      String? lastStatus;
      int lastDetailsFetched = -1;

      while (!_cancelled) {
        _pollCount++;

        final elapsed = DateTime.now().difference(startTime);
        if (elapsed > timeout) {
          _log('✗ Cabinet Job 轮询超时: ${elapsed.inSeconds}s, 共 $_pollCount 次');
          return SyncResult.failure(
            '同步超时——机台成绩抓取耗时超过 ${timeout.inMinutes} 分钟，请稍后重试',
          );
        }

        final pollBefore = DateTime.now();
        final job = await _pollCabinetJobStatus(jobId);
        final pollTime = DateTime.now().difference(pollBefore).inMilliseconds;

        if (job == null) {
          _log('✗ Cabinet 轮询 #$_pollCount 失败 (耗时 ${pollTime}ms)');
          return SyncResult.failure('查询任务状态失败，请检查网络后重试');
        }

        final status = job.tryGet<String>('status') ?? '';
        final stage = job.tryGet<String>('stage') ?? '';
        final cp = job.tryGet<Map<String, dynamic>>('progress');
        final detailsFetched = cp?.tryGet<int>('detailsFetched') ?? 0;
        final errorObj = job.tryGet<Map<String, dynamic>>('error');
        final errorMsg = errorObj?.tryGet<String>('message') ?? '';

        final stageChanged = stage != lastStage || status != lastStatus;
        final progressChanged = detailsFetched != lastDetailsFetched;
        final shouldLog = stageChanged || progressChanged || (_pollCount % _pollCountLogEvery == 1);

        if (shouldLog) {
          _log('  Cabinet 轮询 #$_pollCount (耗时${pollTime}ms): status=$status, '
              'stage=$stage, detailsFetched=$detailsFetched'
              '${errorMsg.isNotEmpty ? ', error="$errorMsg"' : ''}');
        }

        lastStage = stage;
        lastStatus = status;
        lastDetailsFetched = detailsFetched;

        // 失败
        if (status == 'failed') {
          _log('✗ Cabinet Job 失败: $errorMsg');
          _log('  完整 job 响应: $job');
          return SyncResult.failure(errorMsg.isNotEmpty ? errorMsg : '机台同步失败');
        }

        // 完毕
        if (status == 'completed') {
          final scoreCount = job.tryGet<int>('scoreCount') ?? 0;
          _log('✓ Cabinet Job 完成: 共轮询 $_pollCount 次, '
              '总耗时 ${elapsed.inSeconds}s, scoreCount=$scoreCount');
          break;
        }

        // 进度更新
        if (stageChanged) {
          final progress = _mapStage(stage, job);
          if (progress != null) {
            _log('  → 阶段切换: $stage → ${progress.message}');
            _emit(onProgress, progress);
          }
        } else if (progressChanged) {
          _log('  → 抓取进度: detailsFetched=$detailsFetched');
          final progress = _mapStage(stage, job);
          if (progress != null) {
            _emit(onProgress, progress);
          }
        }

        await Future.delayed(_pollInterval);
      }

      if (_cancelled) {
        _log('⊗ 用户取消 (Cabinet): 已轮询 $_pollCount 次');
        return SyncResult.cancelled();
      }

      // ===== Step 3: 导出到水鱼 =====
      return await _doExportPhase(onProgress, methodStart);

    } catch (e, stack) {
      _log('✗ Cabinet 同步异常');
      _log('  异常类型: ${e.runtimeType}');
      _log('  异常信息: $e');
      _log('  堆栈跟踪: $stack');
      return SyncResult.failure('同步异常：$e');
    } finally {
      _isSyncing = false;
      _log('  最终状态: isSyncing=$_isSyncing, cancelled=$_cancelled');
    }
  }

  /// 导出到水鱼 + 缓存（syncByQrCode 和 syncByCabinetQr 共用）
  Future<SyncResult> _doExportPhase(
    void Function(SyncProgress)? onProgress,
    DateTime methodStart,
  ) async {
    _log('── 导出阶段: 同步到水鱼 ──');

    final bindResult = await _bindCachedImportTokenToHub();
    _log('  绑定 importToken 结果: $bindResult');

    _emit(onProgress, const SyncProgress(
      stage: SyncStage.exporting,
      message: '正在同步到水鱼...',
    ));

    final exportBefore = DateTime.now();
    final exportData = await _exportToDivingFish();
    _log('  _exportToDivingFish 耗时: ${DateTime.now().difference(exportBefore).inMilliseconds}ms');

    if (exportData == null) {
      _log('✗ 导出失败: exportData 为 null');
      return SyncResult.failure(
        '成绩抓取成功，但同步水鱼失败。可稍后手动重试导出。',
        friendCode: _friendCode,
      );
    }
    _log('  exportData 完整响应: $exportData');

    final exportJob = exportData.tryGet<Map<String, dynamic>>('job');
    final exportResult = exportJob?.tryGet<Map<String, dynamic>>('result');
    final divingFish = exportResult?.tryGet<Map<String, dynamic>>('divingFish');
    final diveStatus = divingFish?.tryGet<String>('status') ?? '';
    final exported = divingFish?.tryGet<int>('exported') ?? 0;
    final scores = divingFish?.tryGet<int>('scores') ?? 0;
    final exportMsg = divingFish?.tryGet<String>('message') ?? '';
    _log('  diveStatus=$diveStatus, exported=$exported, scores=$scores, msg="$exportMsg"');

    if (diveStatus == 'success') {
      await _cacheSyncState();
      _log('✓ 缓存同步状态完成');
      _log('══════════════════════════════════════════');
      _log('同步成功完成');
      _log('  总耗时: ${DateTime.now().difference(methodStart).inSeconds}s');
      _log('  friendCode: $_friendCode');
      _log('  导出成绩数: $exported');
      _log('══════════════════════════════════════════');

      _emit(onProgress, SyncProgress(
        stage: SyncStage.completed,
        message: '同步完成！共同步 $exported 条成绩',
        completedDiffs: 1,
        totalDiffs: 1,
      ));

      return SyncResult.success(
        friendCode: _friendCode,
        exportedCount: exported,
      );
    } else {
      _log('✗ 水鱼导出失败 (diveStatus=$diveStatus): $exportMsg');
      return SyncResult.failure(
        '水鱼导出失败：${exportMsg.isNotEmpty ? exportMsg : diveStatus}',
        friendCode: _friendCode,
      );
    }
  }

  // ===========================================================================
  // 分步 API（适合需要手动控制流程的场景）
  // ===========================================================================

  /// 仅做 QR 码认证，获取 token 和 friendCode
  /// 返回 `{ token, user: { id, friendCode } }`
  Future<Map<String, dynamic>?> loginByQr(String qrCode) {
    _log('loginByQr 被调用 (QR长度: ${qrCode.length})');
    return _loginByQr(qrCode);
  }

  /// 创建抓取任务（POST /me/dxnet-jobs）
  ///
  /// 为当前已认证用户创建 update_score job。
  /// 需要先调用 [loginByQr] 获得 token。
  /// 返回 `{ jobId, job }`。
  Future<Map<String, dynamic>?> loginRequest(String friendCode) {
    _log('loginRequest 被调用 (friendCode: $friendCode)');
    return _createDxnetJob(jobType: 'update_score');
  }

  /// 仅查询一次任务状态
  Future<Map<String, dynamic>?> pollJobStatus(String jobId) {
    _log('pollJobStatus 被调用 (jobId: $jobId)');
    return _pollJobStatus(jobId);
  }

  /// 仅执行水鱼导出（前提是已有抓取结果）
  Future<Map<String, dynamic>?> exportToDivingFish() {
    _log('exportToDivingFish 被调用 (hasToken: ${_authToken != null})');
    return _exportToDivingFish();
  }

  // ===========================================================================
  // 水鱼账号绑定
  // ===========================================================================

  /// 直接从 Diving-Fish API 登录获取 JWT 和 importToken
  ///
  /// 两步流程：
  ///   1. POST /login → 从 Set-Cookie 提取 jwt_token
  ///   2. GET /player/profile (带 jwt_token cookie) → 提取 import_token
  ///
  /// 成功后自动缓存 jwt_token 和 import_token 到本地。
  /// 返回 `{ username, importToken, jwtToken, nickname, additionalRating, plate }` 等用户资料
  Future<Map<String, dynamic>?> loginDivingFishDirect(
    String username,
    String password,
  ) async {
    _log('loginDivingFishDirect: username=$username');

    // ===== Step 1: 登录拿 JWT =====
    _log('── Step 1: 登录 ──');
    _log('  POST ${ApiUrls.DivingFishLoginApi}');

    String? jwtToken;

    try {
      final loginResponse = await http.post(
        Uri.parse(ApiUrls.DivingFishLoginApi),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'password': password,
        }),
      );

      _log('  ← HTTP ${loginResponse.statusCode} (${loginResponse.body.length} 字节)');

      if (loginResponse.statusCode != 200) {
        _log('  ✗ 登录失败: ${loginResponse.statusCode} ${loginResponse.body}');
        return null;
      }

      final data = json.decode(loginResponse.body) as Map<String, dynamic>;
      final errcode = data.tryGet<int>('errcode');
      if (errcode != null && errcode != 0) {
        final msg = data.tryGet<String>('message') ?? '未知错误';
        _log('  ✗ 登录失败 (errcode=$errcode): $msg');
        return null;
      }

      // 从 Set-Cookie 提取 jwt_token
      final setCookie = loginResponse.headers['set-cookie'] ?? '';
      _log('  Set-Cookie: ${setCookie.length > 200 ? '${setCookie.substring(0, 200)}...' : setCookie}');
      jwtToken = _extractJwtFromCookie(setCookie);

      if (jwtToken == null) {
        _log('  ✗ 登录成功但未在 Cookie 中找到 jwt_token');
        return null;
      }
      _log('  ✓ JWT 提取成功 (长度: ${jwtToken.length})');
    } catch (e, stack) {
      _log('  ✗ 登录异常: $e');
      _log('  Stack: $stack');
      return null;
    }

    // ===== Step 2: 用 JWT 拿 profile =====
    _log('── Step 2: 获取 importToken ──');
    _log('  GET ${ApiUrls.DivingFishProfileApi}');

    try {
      final profileResponse = await http.get(
        Uri.parse(ApiUrls.DivingFishProfileApi),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'jwt_token=$jwtToken',
        },
      );

      _log('  ← HTTP ${profileResponse.statusCode} (${profileResponse.body.length} 字节)');
      _log('  Response: ${_truncateBody(profileResponse.body)}');

      if (profileResponse.statusCode == 200) {
        final profile = json.decode(profileResponse.body) as Map<String, dynamic>;
        final importToken = profile.tryGet<String>('import_token') ?? '';
        final nickname = profile.tryGet<String>('nickname') ?? '';
        final plate = profile.tryGet<String>('plate') ?? '';
        final additionalRating = profile.tryGet<int>('additional_rating') ?? 0;

        _log('  importToken: ${importToken.isNotEmpty ? "*** (长度: ${importToken.length})" : "空!"}');
        _log('  nickname=$nickname, plate=$plate, additionalRating=$additionalRating');

        if (importToken.isEmpty) {
          _log('  ✗ 未找到 import_token');
          return null;
        }

        // 缓存到本地
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(CacheKeyConstant.probeDivingFishToken, jwtToken);
        await prefs.setString(CacheKeyConstant.probeDivingFishImportToken, importToken);
        final bindQQ = profile.tryGet<String>('bind_qq') ?? '';
        if (bindQQ.isNotEmpty) {
          await prefs.setString(CacheKeyConstant.probeDivingFishBindQQ, bindQQ);
          _log('  bind_qq 已缓存: $bindQQ');
        }
        _log('  ✓ JWT 和 importToken 已缓存');

        // 返回合并结果
        return {
          ...profile,
          'jwtToken': jwtToken,
          'importToken': importToken,
        };
      } else {
        _log('  ✗ profile 请求失败: ${profileResponse.statusCode}');
        return null;
      }
    } catch (e, stack) {
      _log('  ✗ profile 请求异常: $e');
      _log('  Stack: $stack');
      return null;
    }
  }

  /// 获取本地缓存的水鱼 importToken（如果有）
  Future<String?> getCachedDivingFishImportToken() async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString(CacheKeyConstant.probeDivingFishImportToken);
    _log('getCachedDivingFishImportToken → ${t != null ? "***" : "null"}');
    return t;
  }

  /// 获取水鱼绑定的 QQ 号
  ///
  /// 优先读取本地缓存，若无则用 JWT 调 profile 接口
  Future<String?> fetchBindQQ() async {
    _log('fetchBindQQ 被调用');
    final prefs = await SharedPreferences.getInstance();

    // 优先读本地缓存（loginDivingFishDirect 时写入）
    final cached = prefs.getString(CacheKeyConstant.probeDivingFishBindQQ);
    if (cached != null && cached.isNotEmpty) {
      _log('  ✓ 命中本地缓存: $cached');
      return cached;
    }

    // 回退：用 JWT 调 API
    final jwtToken = prefs.getString(CacheKeyConstant.probeDivingFishToken);
    if (jwtToken == null || jwtToken.isEmpty) {
      _log('  ✗ 无缓存 JWT，无法获取 bind_qq');
      return null;
    }

    try {
      _log('  GET ${ApiUrls.DivingFishProfileApi}');
      final response = await http.get(
        Uri.parse(ApiUrls.DivingFishProfileApi),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'jwt_token=$jwtToken',
        },
      );

      _log('  ← HTTP ${response.statusCode}');
      if (response.statusCode == 200) {
        final profile = json.decode(response.body) as Map<String, dynamic>;
        final bindQQ = profile.tryGet<String>('bind_qq') ?? '';
        _log('  bind_qq=$bindQQ');
        if (bindQQ.isNotEmpty) {
          await prefs.setString(CacheKeyConstant.probeDivingFishBindQQ, bindQQ);
        }
        return bindQQ.isNotEmpty ? bindQQ : null;
      }
      _log('  ✗ profile 请求失败: ${response.statusCode} ${response.body}');
      return null;
    } catch (e, stack) {
      _log('  ✗ 异常: $e');
      _log('  Stack: $stack');
      return null;
    }
  }

  /// 将本地缓存的水鱼 importToken 绑定到 Hub（需已通过 QR 认证）
  ///
  /// 调用时机：QR 认证成功后、同步导出前
  Future<bool> _bindCachedImportTokenToHub() async {
    if (_authToken == null) return false;
    final importToken = await getCachedDivingFishImportToken();
    if (importToken == null) {
      _log('_bindCachedImportTokenToHub: 无本地缓存 token');
      return false;
    }

    _log('_bindCachedImportTokenToHub: 将缓存 importToken 同步到 Hub...');
    try {
      final response = await _patchFollowRedirects(
        Uri.parse(ApiUrls.MaimaiHubProfileUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: json.encode({
          'divingFishImportToken': importToken,
          'autoUpdate': true,
        }),
      );

      _log('  ← HTTP ${response.statusCode}');
      if (response.statusCode == 200) {
        _log('  ✓ importToken 已同步到 Hub');
        return true;
      }
      _log('  ✗ 同步失败: ${response.body}');
      return false;
    } catch (e, stack) {
      _log('  ✗ 异常: $e');
      _log('  Stack: $stack');
      return false;
    }
  }

  /// 检查当前 Hub 用户是否已绑定水鱼 importToken
  ///
  /// 需先调用 [loginByQr] 拿到 token，否则返回 null
  Future<bool?> hasDivingFishImportToken() async {
    _log('hasDivingFishImportToken 被调用');
    if (_authToken == null) {
      _log('  ⚠ authToken 为 null，无法查询');
      return null;
    }

    try {
      final response = await _getFollowRedirects(
        Uri.parse(ApiUrls.MaimaiHubProfileUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
      );

      _log('  ← HTTP ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final has = data.tryGet<bool>('hasDivingFishImportToken') ?? false;
        _log('  hasDivingFishImportToken=$has');
        return has;
      }
      _log('  ✗ 查询失败: ${response.body}');
      return null;
    } catch (e, stack) {
      _log('  ✗ 异常: $e');
      _log('  Stack: $stack');
      return null;
    }
  }

  /// 检查当前 Hub 用户是否已绑定落雪 importToken
  ///
  /// 需先调用 [loginByQr] 拿到 token（或从缓存恢复），否则返回 null
  Future<bool?> hasLxnsImportToken() async {
    _log('hasLxnsImportToken 被调用');
    if (_authToken == null) {
      _log('  ⚠ authToken 为 null，无法查询');
      return null;
    }

    try {
      final response = await _getFollowRedirects(
        Uri.parse(ApiUrls.MaimaiHubProfileUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
      );

      _log('  ← HTTP ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final has = data.tryGet<bool>('hasLxnsImportToken') ?? false;
        _log('  hasLxnsImportToken=$has');
        return has;
      }
      _log('  ✗ 查询失败: ${response.body}');
      return null;
    } catch (e, stack) {
      _log('  ✗ 异常: $e');
      _log('  Stack: $stack');
      return null;
    }
  }

  /// 设置或清除落雪 importToken
  ///
  /// [token] 落雪个人 API 密钥（importToken），传 null 或空字符串表示清除
  Future<bool> setLxnsImportToken(String? token) async {
    _log('setLxnsImportToken: ${token != null ? "***" : "null（清除）"}');
    if (_authToken == null) {
      _log('  ✗ authToken 为 null');
      return false;
    }

    try {
      final response = await _patchFollowRedirects(
        Uri.parse(ApiUrls.MaimaiHubProfileUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: json.encode({'lxnsImportToken': token}),
      );

      _log('  ← HTTP ${response.statusCode}');
      if (response.statusCode == 200) {
        _log('  ✓ lxnsImportToken 已${token != null ? "设置" : "清除"}');
        return true;
      }
      _log('  ✗ 失败: ${response.body}');
      return false;
    } catch (e, stack) {
      _log('  ✗ 异常: $e');
      _log('  Stack: $stack');
      return false;
    }
  }

  /// 用水鱼账号密码换取 importToken 并绑定到当前 Hub 用户
  ///
  /// [username] 水鱼用户名
  /// [password] 水鱼密码
  /// 返回 true 表示绑定成功
  Future<bool> bindDivingFishAccount(String username, String password) async {
    _log('bindDivingFishAccount: username=$username');
    if (_authToken == null) {
      _log('  ✗ authToken 为 null，无法绑定');
      return false;
    }

    try {
      // Step A: 用水鱼账号换取 importToken
      _log('  POST ${ApiUrls.MaimaiHubDivingFishTokenUrl}');
      final tokenResponse = await _postFollowRedirects(
        Uri.parse(ApiUrls.MaimaiHubDivingFishTokenUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: json.encode({
          'username': username,
          'password': password,
        }),
      );

      _log('  ← HTTP ${tokenResponse.statusCode}');
      if (tokenResponse.statusCode == 201) {
        final data = json.decode(tokenResponse.body) as Map<String, dynamic>;
        _log('  ✓ importToken 获取成功: ${data['importToken'] != null ? "***" : "null"}');
      } else {
        _log('  ✗ 换取 token 失败: ${tokenResponse.body}');
        return false;
      }

      // Step B: 验证绑定状态
      final hasToken = await hasDivingFishImportToken();
      _log('  绑定后验证: hasToken=$hasToken');
      return hasToken == true;
    } catch (e, stack) {
      _log('  ✗ 异常: $e');
      _log('  Stack: $stack');
      return false;
    }
  }

  // ===========================================================================
  // 内部实现
  // ===========================================================================

  /// POST /auth/qr-login
  Future<Map<String, dynamic>?> _loginByQr(String qrCode) async {
    final url = ApiUrls.MaimaiHubLoginByQrUrl;
    final body = json.encode({'qrCode': qrCode});

    _log('  POST $url');
    _log('  Body: { "qrCode": "${qrCode.length > 30 ? '${qrCode.substring(0, 30)}...' : qrCode}" }');

    try {
      final response = await _postFollowRedirects(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      _log('  ← HTTP ${response.statusCode} (${response.body.length} 字节)');

      if (response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final user = data['user'];
        final friendCode = user is Map<String, dynamic> ? user.tryGet<String>('friendCode') : null;
        _log('  ✓ 返回 token=${data['token'] != null ? '***' : 'null'}, friendCode=${friendCode ?? 'null'}');
        return data;
      }

      _log('  ✗ 状态码异常: ${response.statusCode}');
      _log('  Response body: ${_truncateBody(response.body)}');
      return null;
    } catch (e, stack) {
      _log('  ✗ 网络异常: $e');
      _log('  Stack: $stack');
      return null;
    }
  }

  /// POST /me/dxnet-jobs (authorized)
  ///
  /// 为当前已认证用户创建 DXNet job。
  /// [jobType] — "update_score" 或 "send_friend_request"
  /// [friendshipJobId] — update_score 时可传入已完成的好友请求 job ID
  ///
  /// 成功 (201) 返回 `{ jobId, job }`。
  /// needs_friendship (400) 返回 `{ _needsFriendship: true, ... }`。
  /// 其他错误返回 null。
  Future<Map<String, dynamic>?> _createDxnetJob({
    required String jobType,
    String? friendshipJobId,
  }) async {
    if (_authToken == null) {
      _log('  ✗ _createDxnetJob: authToken 为 null');
      return null;
    }

    final url = ApiUrls.MaimaiHubDxnetJobsUrl;
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_authToken',
    };
    final bodyMap = <String, dynamic>{'jobType': jobType};
    if (friendshipJobId != null) {
      bodyMap['friendshipJobId'] = friendshipJobId;
    }
    final body = json.encode(bodyMap);

    _log('  POST $url');
    _log('  Body: $bodyMap');

    try {
      final response = await _postFollowRedirects(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      _log('  ← HTTP ${response.statusCode} (${response.body.length} 字节)');

      if (response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        _log('  ✓ 返回 jobId=${data['jobId']}');
        return data;
      }

      if (response.statusCode == 400) {
        final err = json.decode(response.body) as Map<String, dynamic>;
        final code = err.tryGet<String>('code') ?? '';
        _log('  ← 400 code=$code, message=${err['message']}');
        if (code == 'needs_friendship') {
          return {
            '_needsFriendship': true,
            'recommendedBotFriendCode': err.tryGet<String>('recommendedBotFriendCode'),
            'message': err.tryGet<String>('message') ?? '',
          };
        }
        return null;
      }

      _log('  ✗ 状态码异常: ${response.statusCode}');
      _log('  Response body: ${_truncateBody(response.body)}');
      return null;
    } catch (e, stack) {
      _log('  ✗ 网络异常: $e');
      _log('  Stack: $stack');
      return null;
    }
  }

  /// 简化版轮询：等待 job 完成或失败
  ///
  /// 使用 [_pollJobStatus] 轮询，适合作业链中的中间等待（如等待好友请求完成）。
  /// [timeout] 最大等待时间，默认 5 分钟。
  /// 返回最终 job 状态，超时返回 null。
  Future<Map<String, dynamic>?> _pollUntilDone(
    String jobId, {
    Duration timeout = const Duration(minutes: 5),
    void Function(SyncProgress)? onProgress,
  }) async {
    final startTime = DateTime.now();
    String? lastStage;

    while (!_cancelled) {
      _pollCount++;

      if (DateTime.now().difference(startTime) > timeout) {
        _log('  _pollUntilDone 超时: jobId=$jobId, 耗时 ${DateTime.now().difference(startTime).inSeconds}s');
        return null;
      }

      final status = await _pollJobStatus(jobId);
      if (status == null) return null;

      final serverStatus = status.tryGet<String>('status') ?? '';
      final stage = status.tryGet<String>('stage') ?? '';
      final done = status.tryGet<bool>('done') ?? false;

      if (stage != lastStage) {
        lastStage = stage;
        _log('  _pollUntilDone: stage=$stage, status=$serverStatus');
        if (onProgress != null) {
          final progress = _mapStage(stage, status);
          if (progress != null) onProgress(progress);
        }
      }

      if (serverStatus == 'failed' || serverStatus == 'canceled' ||
          done || serverStatus == 'completed') {
        return status;
      }

      await Future.delayed(_pollInterval);
    }

    return null; // cancelled
  }

  /// GET /me/dxnet-jobs/{jobId} (authorized)
  ///
  /// 使用带认证的 job 端点获取完整 Job 对象（含 stage / scoreProgress），
  /// 并补充兼容字段 [done]（由 status 推导）和 [message]（映射自 error）。
  Future<Map<String, dynamic>?> _pollJobStatus(String jobId) async {
    final uri = Uri.parse('${ApiUrls.MaimaiHubDxnetJobsUrl}/$jobId');
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    // 轮询日志由调用方控制频率，这里不重复输出
    try {
      final response = await _getFollowRedirects(uri, headers: headers);

      if (response.statusCode == 200) {
        final job = json.decode(response.body) as Map<String, dynamic>;
        final jobStatus = job.tryGet<String>('status') ?? '';
        // 补充兼容字段：旧代码依赖 done / message
        return {
          ...job,
          'done': jobStatus == 'completed' ||
              jobStatus == 'failed' ||
              jobStatus == 'canceled',
          'message': job.tryGet<String>('error') ?? '',
        };
      }

      _log('  ✗ dxnet-jobs HTTP ${response.statusCode}: ${_truncateBody(response.body)}');
      return null;
    } catch (e, stack) {
      _log('  ✗ dxnet-jobs 网络异常: $e');
      _log('  Stack: $stack');
      return null;
    }
  }

  /// 从 HttpClientResponse 提取头信息
  Map<String, String> _extractRespHeaders(HttpClientResponse resp) {
    final h = <String, String>{};
    resp.headers.forEach((n, vs) => h[n] = vs.join(', '));
    return h;
  }

  /// 通用请求，禁止自动重定向，手动跟随 307/308 以保留 Authorization 头
  Future<http.Response> _requestNoAutoRedirect(
    String method,
    Uri uri, {
    Map<String, String> headers = const {},
    String body = '',
    int maxRedirects = 5,
  }) async {
    final client = HttpClient();
    try {
      var currentUri = uri;
      for (int i = 0; i < maxRedirects; i++) {
        final req = await client.openUrl(method, currentUri);
        req.followRedirects = false;
        headers.forEach((k, v) => req.headers.set(k, v));
        if (body.isNotEmpty) {
          req.write(body);
        }
        final resp = await req.close();

        final code = resp.statusCode;
        final location = resp.headers.value('location');
        final respBody = await resp.transform(utf8.decoder).join();

        if ((code == 307 || code == 308) && location != null) {
          currentUri = currentUri.resolve(location);
          _log('  ↳ $method $code 重定向 → $currentUri');
          continue;
        }

        return http.Response(
          respBody,
          code,
          headers: _extractRespHeaders(resp),
          request: http.Request(method, currentUri),
        );
      }
      throw Exception('重定向次数超过上限 ($maxRedirects)');
    } finally {
      client.close();
    }
  }

  /// GET 请求，跟随 307/308 重定向且保留 Authorization 头
  Future<http.Response> _getFollowRedirects(
    Uri uri, {
    Map<String, String> headers = const {},
    int maxRedirects = 5,
  }) => _requestNoAutoRedirect('GET', uri, headers: headers, maxRedirects: maxRedirects);

  /// POST 请求，跟随 307/308 重定向且保留请求体和 Authorization 头
  Future<http.Response> _postFollowRedirects(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
    int maxRedirects = 5,
  }) => _requestNoAutoRedirect('POST', uri, headers: headers, body: body, maxRedirects: maxRedirects);

  /// PATCH 请求，跟随 307/308 重定向
  Future<http.Response> _patchFollowRedirects(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
    int maxRedirects = 5,
  }) => _requestNoAutoRedirect('PATCH', uri, headers: headers, body: body, maxRedirects: maxRedirects);

  /// POST /me/cabinet-score-jobs (authorized)
  ///
  /// 为当前已认证用户创建机台 QR 直同步任务。
  /// 返回 `{ jobId, job }`，失败返回 null。
  Future<Map<String, dynamic>?> _createCabinetScoreJob(String qrCode) async {
    if (_authToken == null) {
      _log('  ✗ _createCabinetScoreJob: authToken 为 null');
      return null;
    }

    final url = ApiUrls.MaimaiHubCabinetScoreJobsUrl;
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_authToken',
    };
    final body = json.encode({'qrCode': qrCode});

    _log('  POST $url');
    _log('  Body: { "qrCode": "${qrCode.length > 20 ? '${qrCode.substring(0, 20)}...' : qrCode}" }');

    try {
      final response = await _postFollowRedirects(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      _log('  ← HTTP ${response.statusCode} (${response.body.length} 字节)');

      if (response.statusCode == 202) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        _log('  ✓ 返回 jobId=${data['jobId']}');
        return data;
      }

      _log('  ✗ 状态码异常: ${response.statusCode}');
      _log('  Response body: ${_truncateBody(response.body)}');
      return null;
    } catch (e, stack) {
      _log('  ✗ 网络异常: $e');
      _log('  Stack: $stack');
      return null;
    }
  }

  /// GET /me/cabinet-score-jobs/{jobId} (authorized)
  ///
  /// 查询机台 QR 直同步 job 状态。
  Future<Map<String, dynamic>?> _pollCabinetJobStatus(String jobId) async {
    final uri = Uri.parse('${ApiUrls.MaimaiHubCabinetScoreJobsUrl}/$jobId');
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    try {
      final response = await _getFollowRedirects(uri, headers: headers);

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }

      _log('  ✗ cabinet-score-jobs HTTP ${response.statusCode}: ${_truncateBody(response.body)}');
      return null;
    } catch (e, stack) {
      _log('  ✗ cabinet-score-jobs 网络异常: $e');
      _log('  Stack: $stack');
      return null;
    }
  }

  /// GET /me/cabinet-score-jobs/active (authorized)
  ///
  /// 查询当前活跃的机台同步 job。
  Future<Map<String, dynamic>?> getActiveCabinetScoreJob() async {
    if (_authToken == null) return null;

    final uri = Uri.parse(ApiUrls.MaimaiHubCabinetScoreJobsActiveUrl);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_authToken',
    };

    _log('  GET ${ApiUrls.MaimaiHubCabinetScoreJobsActiveUrl}');

    try {
      final response = await _getFollowRedirects(uri, headers: headers);
      _log('  ← HTTP ${response.statusCode}');

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e, stack) {
      _log('  ✗ 网络异常: $e');
      _log('  Stack: $stack');
      return null;
    }
  }

  /// POST /me/sync/latest/exports/lxns → 轮询至完成
  ///
  /// 导出最近一次同步的成绩到落雪（LXNS）。
  /// 返回格式 `{ job: exportJob }`（与 _exportToDivingFish 兼容）。
  Future<Map<String, dynamic>?> _exportToLxns() async {
    final url = ApiUrls.MaimaiHubSyncLxnsUrl;
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    _log('  POST $url');

    try {
      // ── Step A: 创建导出任务 ──
      final response = await _postFollowRedirects(
        Uri.parse(url), headers: headers, body: '');

      _log('  ← HTTP ${response.statusCode} (${response.body.length} 字节)');

      if (response.statusCode != 201) {
        _log('  ✗ 创建 LXNS 导出任务失败: ${response.statusCode}');
        _log('  Response body: ${_truncateBody(response.body)}');
        return null;
      }

      final createData = json.decode(response.body) as Map<String, dynamic>;
      final exportJobId = createData['exportJobId'] as String?;
      _log('  ✓ LXNS 导出任务已创建，exportJobId=$exportJobId, status=${createData['status']}');

      if (exportJobId == null) {
        _log('  ✗ 创建响应缺少 exportJobId');
        return createData;
      }

      // ── Step B: 轮询等待导出完成 ──
      final pollUrl = '${ApiUrls.MaimaiHubSyncExportJobsUrl}/$exportJobId';
      final startTime = DateTime.now();
      const pollTimeout = Duration(minutes: 2);
      const pollInterval = Duration(seconds: 2);
      String? lastPollStatus;

      while (!_cancelled) {
        if (DateTime.now().difference(startTime) > pollTimeout) {
          _log('  ✗ LXNS 导出轮询超时');
          return null;
        }

        await Future.delayed(pollInterval);

        final pollResponse = await _getFollowRedirects(Uri.parse(pollUrl), headers: headers);

        if (pollResponse.statusCode == 200) {
          final exportJob = json.decode(pollResponse.body) as Map<String, dynamic>;
          final expStatus = exportJob.tryGet<String>('status') ?? '';

          if (expStatus != lastPollStatus) {
            lastPollStatus = expStatus;
            final lxns = exportJob.tryGet<Map<String, dynamic>>('result')
                ?.tryGet<Map<String, dynamic>>('lxns');
            _log('  LXNS 导出轮询: status=$expStatus, '
                'lxns.status=${lxns?.tryGet<String>('status')}, '
                'exported=${lxns?.tryGet<int>('exported')}');
          }

          if (expStatus == 'completed' || expStatus == 'partial_failed') {
            _log('  ✓ LXNS 导出完成 (status=$expStatus)');
            return {'job': exportJob};
          }

          if (expStatus == 'failed' || expStatus == 'skipped') {
            _log('  ✗ LXNS 导出失败 (status=$expStatus)');
            return {'job': exportJob};
          }
        } else {
          _log('  ✗ LXNS 导出轮询 HTTP ${pollResponse.statusCode}');
        }
      }

      return null;
    } catch (e, stack) {
      _log('  ✗ LXNS 导出网络异常: $e');
      _log('  Stack: $stack');
      return null;
    }
  }

  /// 仅执行落雪导出（前提是已有抓取结果）
  Future<Map<String, dynamic>?> exportToLxns() {
    _log('exportToLxns 被调用 (hasToken: ${_authToken != null})');
    return _exportToLxns();
  }

  /// 通过机台 QR 码同步成绩并导出到落雪（LXNS）
  ///
  /// 合并 cabinet sync + LXNS export，适用于「同步成绩到落雪」功能。
  /// 与 [syncByCabinetQr] 的区别：导出到落雪而非水鱼。
  Future<SyncResult> syncByCabinetQrToLxns(
    String qrCode, {
    void Function(SyncProgress progress)? onProgress,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    _log('══════════════════════════════════════════');
    _log('syncByCabinetQrToLxns 开始');
    _log('  QR长度: ${qrCode.length} 字符');

    if (_isSyncing) {
      _log('⚠ 拒绝：同步已在进行中');
      return SyncResult.failure('同步已在进行中，请稍后重试');
    }

    // 恢复或检查认证 token
    final hasToken = await _ensureAuthToken();
    if (!hasToken) {
      _log('✗ 无认证 token，无法使用机台直同步');
      return SyncResult.failure(
        '尚未建立认证，请先使用「同步成绩到水鱼」完成一次 NET QR 同步',
      );
    }

    _isSyncing = true;
    _cancelled = false;
    _pollCount = 0;

    try {
      // ===== Step 1: 创建 Cabinet Score Job =====
      _emit(onProgress, const SyncProgress(
        stage: SyncStage.requesting,
        message: '正在提交机台二维码...',
      ));

      final createResult = await _createCabinetScoreJob(qrCode);
      if (createResult == null) {
        return SyncResult.failure('提交机台二维码失败，请检查网络后重试');
      }

      final jobId = createResult['jobId'] as String?;
      if (jobId == null) {
        return SyncResult.failure('Hub 未返回任务 ID');
      }
      _log('✓ Cabinet Job 创建成功，jobId=$jobId');

      final initialJob = createResult.tryGet<Map<String, dynamic>>('job');
      final initialStatus = initialJob?.tryGet<String>('status') ?? '';

      if (initialStatus != 'completed') {
        // ===== Step 2: 轮询等待完成 =====
        final startTime = DateTime.now();
        String? lastStage;
        String? lastStatus;
        int lastDetailsFetched = -1;

        while (!_cancelled) {
          _pollCount++;
          final elapsed = DateTime.now().difference(startTime);
          if (elapsed > timeout) {
            return SyncResult.failure('同步超时——机台成绩抓取耗时超过 ${timeout.inMinutes} 分钟');
          }

          final job = await _pollCabinetJobStatus(jobId);
          if (job == null) {
            return SyncResult.failure('查询任务状态失败，请检查网络后重试');
          }

          final status = job.tryGet<String>('status') ?? '';
          final stage = job.tryGet<String>('stage') ?? '';
          final cp = job.tryGet<Map<String, dynamic>>('progress');
          final detailsFetched = cp?.tryGet<int>('detailsFetched') ?? 0;
          final errorObj = job.tryGet<Map<String, dynamic>>('error');
          final errorMsg = errorObj?.tryGet<String>('message') ?? '';

          final stageChanged = stage != lastStage || status != lastStatus;
          final progressChanged = detailsFetched != lastDetailsFetched;

          if (stageChanged || progressChanged || (_pollCount % _pollCountLogEvery == 1)) {
            _log('  Cabinet 轮询 #$_pollCount: status=$status, stage=$stage, detailsFetched=$detailsFetched');
          }

          lastStage = stage;
          lastStatus = status;
          lastDetailsFetched = detailsFetched;

          if (status == 'failed') {
            return SyncResult.failure(errorMsg.isNotEmpty ? errorMsg : '机台同步失败');
          }

          if (status == 'completed') {
            final scoreCount = job.tryGet<int>('scoreCount') ?? 0;
            _log('✓ Cabinet Job 完成，scoreCount=$scoreCount');
            break;
          }

          if (stageChanged) {
            final progress = _mapStage(stage, job);
            if (progress != null) _emit(onProgress, progress);
          } else if (progressChanged) {
            final progress = _mapStage(stage, job);
            if (progress != null) _emit(onProgress, progress);
          }

          await Future.delayed(_pollInterval);
        }

        if (_cancelled) return SyncResult.cancelled();
      }

      // ===== Step 3: 导出到落雪 =====
      _log('── 检查落雪 token ──');
      final hasLxns = await hasLxnsImportToken();
      if (hasLxns != true) {
        _log('✗ 未设置落雪 importToken');
        return SyncResult.failure('尚未设置落雪个人 API 密钥，请在同步页面或账号管理中设置');
      }

      _log('── 导出到落雪 ──');
      _emit(onProgress, const SyncProgress(
        stage: SyncStage.exporting,
        message: '正在同步到落雪...',
      ));

      final exportData = await _exportToLxns();
      if (exportData == null) {
        return SyncResult.failure('成绩抓取成功，但同步落雪失败。可稍后手动重试导出。');
      }

      final exportJob = exportData.tryGet<Map<String, dynamic>>('job');
      final exportResult = exportJob?.tryGet<Map<String, dynamic>>('result');
      final lxns = exportResult?.tryGet<Map<String, dynamic>>('lxns');
      final lxnsStatus = lxns?.tryGet<String>('status') ?? '';
      final exported = lxns?.tryGet<int>('exported') ?? 0;
      final exportMsg = lxns?.tryGet<String>('message') ?? '';

      if (lxnsStatus == 'success') {
        await _cacheSyncState();
        _log('✓ 落雪导出成功: exported=$exported');
        _emit(onProgress, SyncProgress(
          stage: SyncStage.completed,
          message: '同步完成！共同步 $exported 条成绩到落雪',
          completedDiffs: 1,
          totalDiffs: 1,
        ));
        return SyncResult.success(exportedCount: exported);
      } else {
        return SyncResult.failure(
          '落雪导出失败：${exportMsg.isNotEmpty ? exportMsg : lxnsStatus}',
        );
      }
    } catch (e, stack) {
      _log('✗ LXNS 同步异常: $e');
      _log('  Stack: $stack');
      return SyncResult.failure('同步异常：$e');
    } finally {
      _isSyncing = false;
    }
  }

  /// POST /me/sync/latest/exports/diving-fish → 轮询至完成
  ///
  /// 导出是异步任务：先创建 export job（POST），
  /// 再轮询 GET /me/sync/prober-export-jobs/{exportJobId} 等待完成。
  /// 返回格式 `{ job: exportJob }`（与调用方兼容）。
  Future<Map<String, dynamic>?> _exportToDivingFish() async {
    final url = ApiUrls.MaimaiHubSyncDivingFishUrl;
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    _log('  POST $url');

    try {
      // ── Step A: 创建导出任务 ──
      final response = await _postFollowRedirects(
        Uri.parse(url),
        headers: headers,
        body: '',
      );

      _log('  ← HTTP ${response.statusCode} (${response.body.length} 字节)');

      if (response.statusCode != 201) {
        _log('  ✗ 创建导出任务失败: ${response.statusCode}');
        _log('  Response body: ${_truncateBody(response.body)}');
        return null;
      }

      final createData = json.decode(response.body) as Map<String, dynamic>;
      final exportJobId = createData['exportJobId'] as String?;
      _log('  ✓ 导出任务已创建，exportJobId=$exportJobId, '
          'status=${createData['status']}');

      if (exportJobId == null) {
        _log('  ✗ 创建响应缺少 exportJobId');
        return createData; // 容错：原样返回
      }

      // ── Step B: 轮询等待导出完成 ──
      final pollUrl = '${ApiUrls.MaimaiHubSyncExportJobsUrl}/$exportJobId';
      final startTime = DateTime.now();
      const pollTimeout = Duration(minutes: 2);
      const pollInterval = Duration(seconds: 2);
      String? lastPollStatus;

      while (!_cancelled) {
        if (DateTime.now().difference(startTime) > pollTimeout) {
          _log('  ✗ 导出轮询超时（${pollTimeout.inMinutes} 分钟）');
          return null;
        }

        await Future.delayed(pollInterval);

        final pollResponse = await _getFollowRedirects(Uri.parse(pollUrl), headers: headers);

        if (pollResponse.statusCode == 200) {
          final exportJob = json.decode(pollResponse.body) as Map<String, dynamic>;
          final expStatus = exportJob.tryGet<String>('status') ?? '';

          if (expStatus != lastPollStatus) {
            lastPollStatus = expStatus;
            final df = exportJob.tryGet<Map<String, dynamic>>('result')
                ?.tryGet<Map<String, dynamic>>('divingFish');
            _log('  导出轮询: status=$expStatus, '
                'divingFish.status=${df?.tryGet<String>('status')}, '
                'exported=${df?.tryGet<int>('exported')}');
          }

          if (expStatus == 'completed' || expStatus == 'partial_failed') {
            _log('  ✓ 导出完成 (status=$expStatus)');
            return {'job': exportJob};
          }

          if (expStatus == 'failed' || expStatus == 'skipped') {
            _log('  ✗ 导出失败 (status=$expStatus)');
            return {'job': exportJob};
          }
        } else {
          _log('  ✗ 导出轮询 HTTP ${pollResponse.statusCode}');
        }
      }

      // cancelled
      return null;
    } catch (e, stack) {
      _log('  ✗ 网络异常: $e');
      _log('  Stack: $stack');
      return null;
    }
  }

  // ===========================================================================
  // 辅助方法
  // ===========================================================================

  /// 将 Hub 返回的 stage 映射为同步进度
  ///
  /// [status] 可以是 DXNet job 或 Cabinet job 的返回体；
  /// 优先读取 [scoreProgress]（DXNet），其次读取 [progress]（Cabinet）。
  SyncProgress? _mapStage(String stage, Map<String, dynamic> status) {
    // DXNet 风格进度
    final sp = status.tryGet<Map<String, dynamic>>('scoreProgress');
    final completedDiffs = (sp?.tryGet<List>('completedDiffs')?.length) ?? 0;
    final totalDiffs = sp?.tryGet<int>('totalDiffs') ?? 0;

    // Cabinet 风格进度
    final cp = status.tryGet<Map<String, dynamic>>('progress');
    final detailsFetched = cp?.tryGet<int>('detailsFetched') ?? 0;
    final cabinetScoreCount = status.tryGet<int>('scoreCount') ?? 0;

    _log('  _mapStage: stage=$stage, dxCompletedDiffs=$completedDiffs/$totalDiffs, '
        'detailsFetched=$detailsFetched, scoreCount=$cabinetScoreCount');

    switch (stage) {
      // ── DXNet 阶段 ──
      case 'send_request':
        return SyncProgress(
          stage: SyncStage.sendingFriendRequest,
          message: 'Bot 正在发送好友申请...',
          completedDiffs: completedDiffs,
          totalDiffs: totalDiffs,
        );
      case 'wait_acceptance':
        return SyncProgress(
          stage: SyncStage.waitingAcceptance,
          message: '等待你在 NET / 机台上通过好友申请',
          completedDiffs: completedDiffs,
          totalDiffs: totalDiffs,
        );
      case 'update_score':
        return SyncProgress(
          stage: SyncStage.scraping,
          message: totalDiffs > 0
              ? '正在抓取成绩... ($completedDiffs/$totalDiffs)'
              : '正在抓取成绩...',
          completedDiffs: completedDiffs,
          totalDiffs: totalDiffs,
        );
      case 'fetch_friend_list':
        return SyncProgress(
          stage: SyncStage.scraping,
          message: '正在拉取好友列表...',
          completedDiffs: completedDiffs,
          totalDiffs: totalDiffs,
        );

      // ── Cabinet 阶段（机台 QR 直同步） ──
      case 'queued':
        return SyncProgress(
          stage: SyncStage.requesting,
          message: '任务已排队，等待处理...',
        );
      case 'qr_auth':
        return SyncProgress(
          stage: SyncStage.authenticating,
          message: '正在验证机台二维码...',
        );
      case 'preview':
        return SyncProgress(
          stage: SyncStage.scraping,
          message: '正在预览数据...',
        );
      case 'login':
        return SyncProgress(
          stage: SyncStage.scraping,
          message: '正在登录机台...',
        );
      case 'get_music':
        return SyncProgress(
          stage: SyncStage.scraping,
          message: detailsFetched > 0
              ? '正在获取谱面成绩... ($detailsFetched 条)'
              : '正在获取谱面成绩...',
          completedDiffs: detailsFetched,
          totalDiffs: cabinetScoreCount,
        );
      case 'logout':
        return SyncProgress(
          stage: SyncStage.scraping,
          message: '正在登出机台...',
        );
      case 'cleanup':
        return SyncProgress(
          stage: SyncStage.scraping,
          message: '正在清理...',
        );
      case 'persist':
        return SyncProgress(
          stage: SyncStage.exporting,
          message: cabinetScoreCount > 0
              ? '正在保存成绩... ($cabinetScoreCount 条)'
              : '正在保存成绩...',
          completedDiffs: cabinetScoreCount,
          totalDiffs: cabinetScoreCount,
        );
      default:
        _log('  _mapStage: 未识别的 stage "$stage"，返回 null');
        return null;
    }
  }

  /// 发送进度回调
  void _emit(
    void Function(SyncProgress)? callback,
    SyncProgress progress,
  ) {
    _log('  → emit: $progress');
    callback?.call(progress);
  }

  /// 将同步状态写入缓存
  Future<void> _cacheSyncState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_authToken != null) {
        await prefs.setString(CacheKeyConstant.probeAuthToken, _authToken!);
      }
      if (_friendCode != null) {
        await prefs.setString(CacheKeyConstant.probeFriendCode, _friendCode!);
      }
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(CacheKeyConstant.probeLastSyncTime, nowMs);
      _log('  _cacheSyncState 完成: friendCode=$_friendCode, timestamp=$nowMs');
    } catch (e, stack) {
      _log('  ✗ 缓存同步状态失败: $e');
      _log('  Stack: $stack');
    }
  }

  /// 从 Set-Cookie 头中提取 jwt_token
  static String? _extractJwtFromCookie(String setCookie) {
    if (setCookie.isEmpty) return null;
    // Diving-Fish 的 jwt_token 通常在 cookie 中
    // 格式: jwt_token=eyJ...; Path=/; HttpOnly
    final match = RegExp(r'jwt_token=([^;]+)').firstMatch(setCookie);
    if (match != null) {
      _log('  _extractJwtFromCookie: 找到 jwt_token');
      return match.group(1);
    }
    // 有些实现可能用不同的 cookie 名
    final match2 = RegExp(r'token=([^;]+)').firstMatch(setCookie);
    if (match2 != null) {
      _log('  _extractJwtFromCookie: 找到 token');
      return match2.group(1);
    }
    _log('  _extractJwtFromCookie: 未找到 jwt_token，完整 Set-Cookie: $setCookie');
    return null;
  }

  /// 截断过长的响应体，方便日志查看
  static String _truncateBody(String body) {
    if (body.length <= 300) return body;
    return '${body.substring(0, 300)}... (共 ${body.length} 字符)';
  }
}


// =============================================================================
// 扩展：让 Map 读取更安全
// =============================================================================

extension SafeMapAccess on Map<String, dynamic> {
  T? tryGet<T>(String key) {
    final val = this[key];
    if (val is T) return val;
    if (T == int && val is num) return val.toInt() as T;
    if (T == double && val is num) return val.toDouble() as T;
    if (T == String && val != null) return val.toString() as T;
    if (T == bool && val != null) {
      if (val is bool) return val as T;
      if (val is String) {
        final lower = val.toLowerCase();
        if (lower == 'true') return true as T;
        if (lower == 'false') return false as T;
      }
    }
    return null;
  }
}