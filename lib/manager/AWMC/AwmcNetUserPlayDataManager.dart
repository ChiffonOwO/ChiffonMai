import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/ApiUrls.dart';
import '../../api/DeveloperToken.dart';
import '../../service/AccountSwitchService.dart';
import '../../utils/ApiClient.dart';
import '../../utils/CurrentDataSourceNotifier.dart';
import 'AwmcNetException.dart';

/// AWMC NET.（https://net.wmc.pub）用户成绩管理器 —— 第三个查分数据源。
///
/// ── 它和另外两个源的关系 ──
///   * **水鱼**：走后端 OAuth 代理，按绑定 QQ 读 `/player/records`；
///   * **落雪**：走 OAuth，读 `/api/v0/user/maimai/player/scores` 再转成 [RecordItem]；
///   * **AWMC NET**：**直连**，用 `Developer-Token` 头 + `?qq=` 查
///     `/dev/player/records`，返回的结构与水鱼 `/player/records` **逐字段一致**。
///
/// 正因为结构一致，AWMC NET 不需要像落雪那样单独写一套转换 + Best50 计算：
/// 「归一化 → 写进 `user_play_data` 活动槽 → `UserBest50Manager` 算 Best50」
/// 这条路与水鱼**完全共用**（见 `RefreshDataDialog.refreshAwmcNetDataWithProgress`）。
/// 实测校验：按现有算法取 old-top35 + new-top15 求和，与接口自身的
/// `old_rating + new_rating` 完全相等（10974 + 4616 = 15590）。
///
/// ── 认证 ──
/// 不需要用户登录，也不需要 OAuth：只要有 QQ 号就能查（前提是该 QQ
/// 已在 AWMC NET 绑定过并上传过成绩）。凭据是项目自带的开发者密钥，
/// 与其他凭据一样放在 `lib/api/DeveloperToken.dart`（该文件已 gitignore，
/// 模板见 `DeveloperTokenShow.dart`，CI 由 Secrets 生成）。
class AwmcNetUserPlayDataManager {
  AwmcNetUserPlayDataManager._internal();

  static final AwmcNetUserPlayDataManager _instance =
      AwmcNetUserPlayDataManager._internal();

  factory AwmcNetUserPlayDataManager() => _instance;

  /// 单次查询超时。
  ///
  /// 全量成绩约 1700 条 / 300–400 KB，实测 1–3s；45s 足以覆盖冷启动，
  /// 又不至于在对方服务挂住时让用户干等（水鱼读走的是 15s 默认值）。
  static const Duration timeout = Duration(seconds: 45);

  /// 本源的「上次更新时间」键。
  ///
  /// **按源区分**，绝不能复用 `UserPlayDataManager` 的 `user_play_data_last_update`
  /// —— 那是水鱼的时间戳，共用一个键会让两个源互相覆盖更新时间。
  static const String _lastUpdateKey = 'awmc_net_user_play_data_last_update';

  /// QQ 号格式：5–12 位纯数字（QQ 实际长度 5–11，留一位冗余）。
  static final RegExp _qqPattern = RegExp(r'^\d{5,12}$');

  // ══════════════════════════════════════════════════════════════════════
  //  查询
  // ══════════════════════════════════════════════════════════════════════

  /// 按 QQ 拉取全量成绩。
  ///
  /// 返回**归一化后的水鱼结构**，可直接喂给 `UserBest50Manager.getUserBest50`：
  /// ```json
  /// {"records": [...], "additional_rating": 0, "nickname": "ChiFFoN",
  ///  "rating": 15579, "plate": "", "username": "ChiffonOwO"}
  /// ```
  ///
  /// **失败一律抛 [AwmcNetException]，绝不返回 null。**
  /// 这一点是刻意的：`UserBest50Manager.getUserBest50` 的实现是
  /// `playData ?? await UserPlayDataManager().fetchUserPlayData(qq)` ——
  /// 一旦这里给出 null，它就会拿同一个 QQ 去问**水鱼**，把另一个数据源的
  /// 成绩显示成 AWMC NET 的。宁可抛错，也不要静默串源。
  ///
  /// 仅返回响应数据；刷新协调器验证身份后才提交活动槽与历史。
  Future<Map<String, dynamic>> fetchUserPlayData(
    String qq,
  ) async {
    final id = qq.trim();
    if (id.isEmpty) {
      throw const AwmcNetException('请输入 QQ 号');
    }
    if (!_qqPattern.hasMatch(id)) {
      throw const AwmcNetException('QQ 号格式不对（应为 5–12 位数字）');
    }

    final uri = Uri.parse(ApiUrls.AwmcNetRecordsApi)
        .replace(queryParameters: {'qq': id});

    // 出口固定校验：任何拼装错误都在这里拦下，杜绝把开发者密钥发到别的域名。
    if (uri.host != Uri.parse(ApiUrls.AwmcNetBaseUrl).host) {
      throw AwmcNetException('拒绝请求非 AWMC NET 地址：${uri.host}');
    }

    final http.Response response;
    try {
      final key = DeveloperToken.AwmcNetDeveloperKey;
      response = await ApiClient.get(
        uri,
        headers: {
          // 官方文档的头名（实测 /dev/player/records 认这个）
          'Developer-Token': key,
          // 同一个密钥用 Bearer 也通（实测 200），留个兜底
          'Authorization': 'Bearer $key',
        },
        timeout: timeout,
      );
    } on TimeoutException {
      throw AwmcNetException('AWMC NET 查询超时（${timeout.inSeconds} 秒），请检查网络后重试');
    } catch (e) {
      throw AwmcNetException('AWMC NET 连接失败：$e');
    }

    if (response.statusCode != 200) {
      throw _errorForStatus(response.statusCode, response.body, id);
    }

    final Map<String, dynamic>? data;
    try {
      // 服务端明确返回 UTF-8；用 bodyBytes 解码以免依赖响应头里的 charset。
      data = normalizeRecords(json.decode(utf8.decode(response.bodyBytes)));
    } catch (e) {
      throw AwmcNetException('AWMC NET 返回了无法解析的数据：$e');
    }
    if (data == null) {
      throw const AwmcNetException('AWMC NET 返回的数据结构无法识别（缺少 records）');
    }

    final count = (data['records'] as List).length;
    debugPrint('✓ 已从 AWMC NET 获取成绩（QQ: $id，$count 条已游玩谱面）');
    return data;
  }

  /// 把 HTTP 错误码翻成带人话文案的异常。
  AwmcNetException _errorForStatus(int status, String body, String qq) {
    // 服务端错误体形如 {"message": "no such user"} 或 {"detail": ...}
    var detail = '';
    try {
      final decoded = json.decode(body);
      if (decoded is Map) {
        detail = (decoded['message'] ?? decoded['detail'] ?? '').toString();
      }
    } catch (_) {
      // 非 JSON（网关错误页等）：正文没有参考价值，忽略
    }

    switch (status) {
      case 400:
        // 实测：不存在的 QQ → 400 {"message":"no such user"}
        if (detail.contains('no such user') || detail.contains('不存在')) {
          return AwmcNetException(
            'AWMC NET 上没有 QQ $qq 的数据。\n'
            '请确认该 QQ 已在 net.wmc.pub 绑定并上传过成绩。',
          );
        }
        return AwmcNetException(
            'AWMC NET 拒绝了请求：${detail.isEmpty ? '参数不合法' : detail}');
      case 401:
      case 403:
        return AwmcNetException(
          'AWMC NET 开发者密钥无效或已失效（HTTP $status）'
          '${detail.isEmpty ? '' : '：$detail'}',
        );
      case 429:
        return const AwmcNetException('AWMC NET 请求过于频繁，请稍后重试');
    }
    if (status >= 500) {
      return AwmcNetException('AWMC NET 服务端异常（HTTP $status），请稍后重试');
    }
    return AwmcNetException(
        'AWMC NET 返回未知状态：HTTP $status${detail.isEmpty ? '' : '（$detail）'}');
  }

  /// 归一化成水鱼 `/player/records` 结构。
  ///
  /// 两个处理：
  ///   1. **丢掉未游玩的谱面**。AWMC NET 会把整个曲库都列出来，实测 1681 条里
  ///      有 2 条 `achievements == 0`（真打过的谱面最低是 0.099，不会是 0）。
  ///      水鱼的 records 只含打过的谱面；不过滤的话，单曲排行榜会把
  ///      「0% 未游玩」当成绩批量上传，平均达成率也会被拉低。
  ///   2. 只透传下游真正读的字段，顺便给 `additional_rating` 等兜底默认值。
  ///
  /// 返回 null 表示结构无法识别（调用方会转成 [AwmcNetException]）。
  @visibleForTesting
  static Map<String, dynamic>? normalizeRecords(dynamic decoded) {
    dynamic payload = decoded;
    // 容错：万一以后外面套了一层 { data: {...} }
    if (decoded is Map && decoded['data'] is Map) {
      payload = decoded['data'];
    }
    if (payload is! Map) return null;

    final rawRecords = payload['records'];
    if (rawRecords is! List) return null;

    final records = <Map<String, dynamic>>[];
    for (final item in rawRecords) {
      if (item is! Map) continue;
      final record = Map<String, dynamic>.from(item);
      final achievements = record['achievements'];
      final value = achievements is num
          ? achievements.toDouble()
          : double.tryParse('$achievements') ?? 0;
      if (value <= 0) continue;
      records.add(record);
    }

    return <String, dynamic>{
      'records': records,
      // AWMC NET 不提供段位（实测恒为 0），与水鱼同名字段对齐即可
      'additional_rating': payload['additional_rating'] ?? 0,
      'nickname': payload['nickname'] ?? '',
      'rating': payload['rating'] ?? 0,
      'plate': payload['plate'] ?? '',
      'username': payload['username'] ?? '',
    };
  }

  // ══════════════════════════════════════════════════════════════════════
  //  缓存
  // ══════════════════════════════════════════════════════════════════════

  /// 本源上次成功刷新的时间（ms）。没有数据时返回 null。
  Future<int?> getLastUpdateTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lastUpdateKey);
  }

  /// 清除 AWMC NET 的账号数据与存档。
  ///
  /// AWMC NET 没有登录态（凭据是项目自带的开发者密钥），所以「登出」
  /// 等价于「清掉这个源缓存的成绩」——交给 [AccountSwitchService] 处理，
  /// 它会按当前活动源决定要不要回落到另一个账号，**不要**在这里直接
  /// 删 `user_play_data`（那可能正装的是水鱼的数据）。
  Future<void> logout() async {
    await AccountSwitchService.onAccountLoggedOut(RefreshDataSource.awmc);
    debugPrint('✓ 已清除 AWMC NET 账号数据');
  }
}
