import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../api/ApiUrls.dart';
import '../constant/CacheKeyConstant.dart';
import '../manager/LuoXue/LuoXueOAuthManager.dart';
import '../utils/ApiClient.dart';

/// 把一条成绩同步到落雪咖啡屋（LXNS）。
///
/// 端点：`POST /api/v0/user/maimai/player/scores`
///
/// ## 认证：OAuth Bearer 优先，个人 API 密钥回退
///
/// 落雪有三套鉴权，个人 API 文档原文写「不可互用」，但**这一组端点**
/// （`/api/v0/user/...`）实测同时认两套：
///
/// | 鉴权方式 | 请求头 | 落雪是否认 | 本服务怎么用 |
/// |---|---|---|---|
/// | OAuth API | `Authorization: Bearer <access_token>` | ✔（scope 含 `write_player` 即可写） | **首选** |
/// | 个人 API | `X-User-Token: <个人密钥>` | ✔（仅作用于 `/api/v0/user/...`） | 没 OAuth 时回退 |
/// | 开发者 API | `Authorization: <开发者密钥>` | ✗（路径是 `/api/v0/maimai/...`） | 不用 |
///
/// 为什么 OAuth 优先 —— 关键证据是落雪官网「手动更改成绩」那个请求：
/// 它带的也是 `Authorization: Bearer`，只不过 token 是会话 JWT（`type:
/// "user_session"`）而不是 OAuth access_token，**两者都是 Bearer**。
/// 这说明这个路径从设计上就以 Bearer 为唯一鉴权载体，个人 API 密钥只是
/// 出于兼容保留的别名头。
///
/// 之前先发的那版死磕 `X-User-Token`，是因为踩了 OAuth 那条路 401 的坑就
/// 推断「这个端点只认个人 API」—— 实际 401 的真凶是
/// `LuoXueOAuthManager.getAuthHeaders()` 在 token 拿不到时**静默**返回不
/// 带 Authorization 的 header（见 `LuoXueOAuthManager.dart:189`），发出去的
/// 请求根本没有凭证，服务端自然 401。换言之 OAuth 路线没坏，只是头部
/// 有可能被悄悄丢掉。
///
/// 本方法不再依赖 `getAuthHeaders()` 那条有坑的链路：自己拿 access token，
/// 有就用 Bearer；没有再回退到本地 `probeLxnsImportToken` 走 X-User-Token。
/// **两条都拿不到时**才抛错，错误信息会告诉用户该走哪条路。
///
/// ## 响应体里有「old → new」字段对比，用上
///
/// 落雪对这条端点的成功响应是：
/// ```json
/// {
///   "success": true,
///   "code": 200,
///   "data": [
///     {
///       "id": 1662,
///       "song_name": "raputa",
///       "achievements": { "new": 100.7506, "old": 100.7505 },
///       "fc": { "old": "fcp" },
///       "fs": { "old": "sync" },
///       "dx_score": { "new": 2397, "old": 2396 },
///       "dx_rating": { "old": 308.4144 }
///     }
///   ]
/// }
/// ```
/// 每个字段值是 `{new?, old?}`，变化才出现、未变则不出现。本方法把它解包
/// 成 [LuoXueUploadResult]，让 UI 能告诉用户「改了还是没改」——
/// 同步一笔不告诉达成率前后对比，体验上像「点了也不知道成没成」。
///
/// ## 与「同步到水鱼」的关键差异（写错了会被服务端拒绝或写错歌，逐条说明）
///
/// 1. **歌曲用数字 `id`，不是曲名。** 水鱼那边要 `title` 让服务端自己反查，
///    落雪要 `id`。本方法从本地曲库反查，反查不到就无法同步。
///
/// 2. **`id` 需要按落雪的编号体系转换。**
///    落雪文档明确写着：「同一首曲目的标准、DX 谱面的曲目 ID 一致，不存在
///    大于 10000 的曲目 ID（如有，请在请求前对 10000 取余处理）」。
///    而本项目曲库来自水鱼（`music_data`），DX 谱面的 id 是五位数（如 11466）；
///    落雪同一首歌的 id 是四位数（1466）。宴会场（> 100000）是例外，
///    不分标准/DX、id 原样使用。
///
/// 3. **`type` 的值域不同。** 落雪是 `standard` / `dx` / `utage`（小写全称），
///    水鱼是 `SD` / `DX`。
///
/// 4. **DX 分数是 `dx_score`（下划线）**，水鱼是 `dxScore`（驼峰）。
///
/// 5. **`play_time` 不用填。** 落雪文档原文：
///    「值可空，游玩的 UTC 时间，精确到分钟；**上传时忽略，仅通过 HTML 上传写入**」。
///    所以 JSON 上传这条路根本写不进游玩时间，不必尝试。
class LuoXueScoreUploadService {
  static final LuoXueScoreUploadService _instance =
      LuoXueScoreUploadService._internal();
  factory LuoXueScoreUploadService() => _instance;
  LuoXueScoreUploadService._internal();

  /// 读取落雪个人 API 密钥（仅在 OAuth Bearer 拿不到时才用）。
  ///
  /// 只能从本地缓存读。Hub 的 `/profile` 只返回 `hasLxnsImportToken` 这个
  /// **布尔值**，不返回密钥本身（后端 `PATCH /me` 是只写不读），所以
  /// 「Hub 说已绑定」这条路在本方法里用不上 —— 这是上一版死磕 X-User-Token
  /// 时栽过的那个跟头。
  Future<String?> _getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString(CacheKeyConstant.probeLxnsImportToken);
    return (t == null || t.isEmpty) ? null : t;
  }

  /// 拿到当前 OAuth access token（可能为 null：未授权、刷新失败都返 null）。
  ///
  /// 故意不直接用 `LuoXueOAuthManager.getAuthHeaders()`：那个方法在 token
  /// 拿不到时会**静默**返回不带 Authorization 的 header（`LuoXueOAuthManager
  /// .dart:189`），所以同样代码会时而带认证头、时而裸发。后者落雪直接 401。
  /// 这里只读 token，让调用方决定怎么用 —— 没有就是没有，不偷渡。
  Future<String?> _getOAuthAccessToken() =>
      LuoXueOAuthManager().getAccessToken();

  /// 落雪 id 体系转换。
  ///
  /// - 宴会场（>= 100000）：原样返回（落雪不分标准/DX，id 直接就是它）
  /// - 其余：对 10000 取余（11466 → 1466）
  ///
  /// 依据与验证：
  /// 1. 落雪文档开头：「同一首曲目的标准、DX 谱面的曲目 ID 一致，不存在大于
  ///    10000 的曲目 ID（如有，请在请求前对 10000 取余处理）」
  /// 2. **实测复核**：拿两边的公开曲目表逐首比对（1332 首）——
  ///    - 取余后曲名一致 **1331** 首
  ///    - 原样使用曲名一致仅 **540** 首（恰为标准曲数量，DX 全部对不上）
  ///    所以取余是对的。
  ///
  /// ⚠ 已知例外：水鱼 383「Link(CoF)」取余后落到落雪 383「Link」——
  /// 落雪没有 "(CoF)" 这个独立条目，两个版本共用一个 id。这种情况无法靠
  /// id 体系区分，属于上游数据差异。
  ///
  /// 注意本项目既有的 `LuoXueToDivingFishUtil` 走的是**反方向**（落雪→水鱼），
  /// 它靠「曲名 + 类型」查本地曲库拿到水鱼 id（见其 `toRecordItem`），
  /// 因此没有 id 数值转换。本方法是正向（水鱼→落雪），必须做数值转换。
  static int toLxnsSongId(int divingFishId) {
    if (divingFishId >= 100000) return divingFishId;
    return divingFishId % 10000;
  }

  /// 水鱼的 `Song.type`（"DX"/"SD"）→ 落雪的 `SongType`
  ///
  /// 宴会场单独判：它靠 id 区间（>= 100000）识别，而不是靠 type。
  static String toLxnsSongType({required int divingFishId, required String type}) {
    if (divingFishId >= 100000) return 'utage';
    return type.toUpperCase() == 'DX' ? 'dx' : 'standard';
  }

  /// 上传一条成绩。
  ///
  /// [divingFishSongId] 传本地曲库里的 id（水鱼体系），本方法内部做转换。
  /// [divingFishType] 传曲库的 `Song.type`（"DX"/"SD"）。
  /// [fc] / [fs] 用落雪值域（fc/fcp/ap/app；fs/fsp/fsd/fsdp/sync）——
  /// 这跟本项目的 `StringUtil.formatFC/formatFS` 输入一致，可直接传。
  ///
  /// 成功返回 [LuoXueUploadResult]，里面带服务端给的 `old → new` 对比；
  /// 失败抛 [LuoXueUploadException]。
  Future<LuoXueUploadResult> uploadRecord({
    required int divingFishSongId,
    required String divingFishType,
    required int levelIndex,
    required double achievement,
    String? fc,
    String? fs,
    int? dxScore,
  }) async {
    final lid = toLxnsSongId(divingFishSongId);
    final type = toLxnsSongType(
      divingFishId: divingFishSongId,
      type: divingFishType,
    );

    // 落雪的 Score 用它自己的 LevelIndex 枚举（0-4），与水鱼一致。
    // 宴会场不在 0-4 体系里，直接传会写错谱面，所以这里挡掉。
    if (type == 'utage') {
      throw const LuoXueUploadException(
          '宴会场谱面不支持同步：落雪的难度索引体系与宴会场不通用');
    }
    if (levelIndex < 0 || levelIndex > 4) {
      throw LuoXueUploadException('难度索引 $levelIndex 超出落雪值域（0-4）');
    }

    final record = <String, dynamic>{
      'id': lid,
      'type': type,
      'level_index': levelIndex,
      'achievements': achievement,
      // 空串在落雪这边是无效值（枚举里没有 ""），所以要传 null 而不是 ''
      if (fc != null && fc.isNotEmpty) 'fc': fc,
      if (fs != null && fs.isNotEmpty) 'fs': fs,
      'dx_score': dxScore ?? 0,
      // play_time 刻意不传：文档说明「上传时忽略」，传了也没用
    };

    // ── 认证 ───────────────────────────────────────────────
    //
    // OAuth Bearer 优先（见类文档「认证」一节），个人 API 密钥回退。
    // 两条都拿不到再抛错，错误信息指明两条出路。
    final oauthToken = await _getOAuthAccessToken();
    final Map<String, String> headers;
    if (oauthToken != null && oauthToken.isNotEmpty) {
      headers = {
        'Authorization': 'Bearer $oauthToken',
        'Content-Type': 'application/json',
      };
    } else {
      final apiKey = await _getApiKey();
      if (apiKey == null) {
        throw const LuoXueUploadException(
            '落雪账号未认证：在「账号管理」完成 OAuth 授权，或在 OCR 页的落雪状态条里粘贴个人 API 密钥');
      }
      headers = {
        'X-User-Token': apiKey,
        'Content-Type': 'application/json',
      };
    }

    // ── 发送 ───────────────────────────────────────────────
    final http.Response resp;
    try {
      resp = await ApiClient.post(
        Uri.parse(ApiUrls.LuoXuePlayerScoresApi),
        headers: headers,
        body: jsonEncode({
          'scores': [record],
        }),
        timeout: const Duration(seconds: 20),
      );
    } on LuoXueUploadException {
      rethrow;
    } catch (e) {
      throw LuoXueUploadException('无法连接落雪咖啡屋：$e');
    }

    // ── 解析响应（鉴权错误优先按 HTTP 状态码判断） ──────
    Map<String, dynamic> body = {};
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is Map) body = Map<String, dynamic>.from(decoded);
    } catch (_) {}
    final detail = body['message']?.toString() ?? body['error']?.toString();

    if (resp.statusCode != 200 || body['success'] != true) {
      if (resp.statusCode == 401) {
        // token 拿到了但被拒。OAuth 写权限缺失/过期、个人密钥错误或过期
        // 都会走这里 —— 用户得重新授权或粘一个新密钥。
        throw LuoXueUploadException(
            detail ?? '落雪授权已失效或密钥无效，请重新授权或粘贴密钥');
      }
      if (resp.statusCode == 403) {
        throw LuoXueUploadException(detail ?? '落雪拒绝了这次写入（权限不足）');
      }
      throw LuoXueUploadException(
          '同步失败（HTTP ${resp.statusCode}）${detail == null ? '' : '：$detail'}');
    }

    // ── 取 data[0] 里的 old/new 对比 ────────────────────
    final data = body['data'];
    if (data is! List || data.isEmpty) {
      // HTTP 200、success=true 但 data 缺 —— 没见过，但万一就崩在明面上。
      throw const LuoXueUploadException('落雪返回格式异常：data 为空');
    }
    final first = data.first;
    if (first is! Map) {
      throw const LuoXueUploadException('落雪返回格式异常：data[0] 不是对象');
    }
    final m = Map<String, dynamic>.from(first);

    double? oldAch;
    double? newAch;
    int? oldDx;
    int? newDx;
    final ach = m['achievements'];
    if (ach is Map) {
      oldAch = (ach['old'] as num?)?.toDouble();
      newAch = (ach['new'] as num?)?.toDouble();
    }
    final dxs = m['dx_score'];
    if (dxs is Map) {
      oldDx = (dxs['old'] as num?)?.toInt();
      newDx = (dxs['new'] as num?)?.toInt();
    }

    debugPrint(
        'LuoXueScoreUpload: id=$lid type=$type level=$levelIndex → ${resp.statusCode} '
        'ach=${oldAch ?? '-'}→${newAch ?? '-'} dx=${oldDx ?? '-'}→${newDx ?? '-'}');

    return LuoXueUploadResult(
      songId: lid,
      songName: m['song_name']?.toString(),
      level: m['level']?.toString(),
      oldAchievement: oldAch,
      newAchievement: newAch,
      oldDxScore: oldDx,
      newDxScore: newDx,
    );
  }
}

/// 一次落雪同步的结果，给 UI 用来显示「同步前后对比」。
///
/// 数据来源：落雪对 `POST /api/v0/user/maimai/player/scores` 的成功响应
/// 里 `data[0]` 的字段对比（`{old?, new?}`，无变化则不出现）。
class LuoXueUploadResult {
  /// 服务端认定的曲目 id（已经在 [LuoXueScoreUploadService.toLxnsSongId] 里
  /// 转过体系）。
  final int songId;
  final String? songName;
  final String? level;
  /// 同步前的达成率（服务端原值）；未同步过则为 null。
  final double? oldAchievement;
  /// 同步后的达成率。
  final double? newAchievement;
  /// 同步前的 DX 分。
  final int? oldDxScore;
  /// 同步后的 DX 分。
  final int? newDxScore;

  const LuoXueUploadResult({
    required this.songId,
    this.songName,
    this.level,
    this.oldAchievement,
    this.newAchievement,
    this.oldDxScore,
    this.newDxScore,
  });

  /// 是否真的改了什么。落雪会在「无变化」时只返 `{old: x}` 不返 `{new: x}`
  ///（或者两边值相等根本不出现这个字段），所以光看 `new != null` 不够。
  bool get changed =>
      (oldAchievement != null && oldAchievement != newAchievement) ||
      (oldDxScore != null && oldDxScore != newDxScore);
}

class LuoXueUploadException implements Exception {
  final String message;
  const LuoXueUploadException(this.message);
  @override
  String toString() => message;
}
