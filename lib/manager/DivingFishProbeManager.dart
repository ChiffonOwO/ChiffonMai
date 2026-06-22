import 'dart:async';
import 'dart:convert';
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
      final jobData = await _loginRequest(_friendCode!);
      _log('  _loginRequest 耗时: ${DateTime.now().difference(requestBefore).inMilliseconds}ms');

      if (jobData == null) {
        _log('✗ Step 2 失败: jobData 为 null');
        return SyncResult.failure('创建抓取任务失败，请稍后重试');
      }
      _log('  jobData 完整响应: $jobData');

      final jobId = jobData['jobId'] as String?;
      final reused = jobData['reused'] == true;
      final idleUpdate = jobData['idleUpdate'] == true;
      final message = jobData.tryGet<String>('message') ?? '';
      _log('  解析 jobId: $jobId');
      _log('  是否复用: $reused, 是否后台更新: $idleUpdate');
      _log('  Hub消息: "$message"');

      if (jobId == null) {
        _log('✗ Step 2 失败: jobId 为 null');
        return SyncResult.failure('Hub 未返回任务 ID');
      }

      if (reused) {
        _log('  提示：检测到已有进行中任务，Hub 返回了复用任务');
        _emit(onProgress, const SyncProgress(
          stage: SyncStage.requesting,
          message: '检测到已有进行中的任务，复用中...',
        ));
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
          _log('  最后 status 响应: $status');
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

      final statusCode = exportData.tryGet<int>('status') ?? 0;
      final exported = exportData.tryGet<int>('exported') ?? 0;
      final scores = exportData.tryGet<int>('scores') ?? 0;
      final exportMsg = (exportData.tryGet<Map<String, dynamic>>('response')
              ?.tryGet<String>('message')) ?? '';
      _log('  status=$statusCode, exported=$exported, scores=$scores, msg="$exportMsg"');

      if (statusCode == 200) {
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
        _log('✗ 水鱼导出失败: $exportMsg');
        return SyncResult.failure(
          '水鱼导出失败：$exportMsg',
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

  // ===========================================================================
  // 分步 API（适合需要手动控制流程的场景）
  // ===========================================================================

  /// 仅做 QR 码认证，获取 token 和 friendCode
  /// 返回 `{ token, user: { id, friendCode } }`
  Future<Map<String, dynamic>?> loginByQr(String qrCode) {
    _log('loginByQr 被调用 (QR长度: ${qrCode.length})');
    return _loginByQr(qrCode);
  }

  /// 仅创建抓取任务
  /// 返回 Hub job 对象（含 jobId）
  Future<Map<String, dynamic>?> loginRequest(String friendCode) {
    _log('loginRequest 被调用 (friendCode: $friendCode)');
    return _loginRequest(friendCode);
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
      final response = await http.patch(
        Uri.parse(ApiUrls.MaimaiHubProfileUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: json.encode({
          'divingFishImportToken': importToken,
          'autoExportDivingFish': true,
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
      final response = await http.get(
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

  /// 用 Diving-Fish 账号密码换取 importToken 并绑定到当前 Hub 用户
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
      final tokenResponse = await http.post(
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

  /// POST /auth/login-by-qr
  Future<Map<String, dynamic>?> _loginByQr(String qrCode) async {
    final url = ApiUrls.MaimaiHubLoginByQrUrl;
    final body = json.encode({'qrCode': qrCode});

    _log('  POST $url');
    _log('  Body: { "qrCode": "${qrCode.length > 30 ? '${qrCode.substring(0, 30)}...' : qrCode}" }');

    try {
      final response = await http.post(
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

  /// POST /auth/login-request
  Future<Map<String, dynamic>?> _loginRequest(String friendCode) async {
    final url = ApiUrls.MaimaiHubLoginRequestUrl;
    final body = json.encode({
      'friendCode': friendCode,
      'skipUpdateScore': false,
      'useIdleUpdate': false,
    });

    _log('  POST $url');
    _log('  Body: { "friendCode": "$friendCode", "skipUpdateScore": false, "useIdleUpdate": false }');

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      _log('  ← HTTP ${response.statusCode} (${response.body.length} 字节)');

      if (response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        _log('  ✓ 返回 jobId=${data['jobId']}, reused=${data['reused']}, '
            'idleUpdate=${data['idleUpdate']}');
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

  /// GET /auth/login-status?jobId=xxx
  Future<Map<String, dynamic>?> _pollJobStatus(String jobId) async {
    final uri = Uri.parse(ApiUrls.MaimaiHubLoginStatusUrl)
        .replace(queryParameters: {'jobId': jobId});

    // 轮询日志由调用方控制频率，这里不重复输出
    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }

      _log('  ✗ login-status HTTP ${response.statusCode}: ${_truncateBody(response.body)}');
      return null;
    } catch (e, stack) {
      _log('  ✗ login-status 网络异常: $e');
      _log('  Stack: $stack');
      return null;
    }
  }

  /// POST /sync/latest/diving-fish
  Future<Map<String, dynamic>?> _exportToDivingFish() async {
    final url = ApiUrls.MaimaiHubSyncDivingFishUrl;
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    _log('  POST $url');
    _log('  Headers: Content-Type=application/json, '
        'Authorization=${_authToken != null ? "Bearer ***" : "无"}');

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
      );

      _log('  ← HTTP ${response.statusCode} (${response.body.length} 字节)');

      if (response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        _log('  ✓ 返回 success=${data['success']}, exported=${data['exported']}, '
            'scores=${data['scores']}');
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

  // ===========================================================================
  // 辅助方法
  // ===========================================================================

  /// 将 Hub 返回的 stage 映射为同步进度
  SyncProgress? _mapStage(String stage, Map<String, dynamic> status) {
    final sp = status.tryGet<Map<String, dynamic>>('scoreProgress');
    final completedDiffs = (sp?.tryGet<List>('completedDiffs')?.length) ?? 0;
    final totalDiffs = sp?.tryGet<int>('totalDiffs') ?? 0;

    _log('  _mapStage: stage=$stage, completedDiffs=$completedDiffs, totalDiffs=$totalDiffs');

    switch (stage) {
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
