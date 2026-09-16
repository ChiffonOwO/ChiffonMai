import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/ApiUrls.dart';
import '../constant/CacheKeyConstant.dart';
import '../entity/DivingFish/Song.dart';
import '../entity/MaimaiHubOcrResult.dart';
import '../manager/DivingFish/DivingFishOAuthManager.dart';
import '../manager/DivingFish/MaimaiMusicDataManager.dart';
import '../manager/DivingFishProbeManager.dart';
import '../manager/LuoXue/LuoXueOAuthManager.dart';
import '../service/Best50/DiffBest50Service.dart';
import '../service/SongSearchService.dart';
import '../service/DivingFishScoreUploadService.dart';
import '../service/LuoXueScoreUploadService.dart';
import '../service/MaimaiHubOcrService.dart';
import '../utils/ApiClient.dart';
import '../utils/AppConstants.dart';
import '../utils/AppTheme.dart';
import '../utils/CommonWidgetUtil.dart';
import '../utils/CoverUtil.dart';
import '../utils/StringUtil.dart';
import '../widgets/RefreshDataDialog.dart' show launchUrlFallback;

/// 结算画面识别页（拍摄机台结算画面 → 裁剪 → 识别 → 显示结构化成绩）
///
/// 输入不是手机截图，而是**对着机台结算页面拍的照片**，所以文案一律用「拍摄」
/// 而不是「截图」。
///
/// 流程：
///   1. 拍照 / 从相册选图
///   2. 手动框选裁剪
///   3. 调 MaimaiHub `POST /api/v1/me/ocr/recognize`（**需先登录 MaimaiHub**）
///   4. 渲染识别出的曲名候选 / 达成率 / DX分 / 难度 / FC / FS
///
/// 识别由 MaimaiHub 的专用模型完成（曲绘 ArcFace + 标题分类双路匹配），
/// 直接产出结构化成绩，不需要再自己解析文本。
///
/// 注：自家后端 `/api/ocr/score`（百度/腾讯通用 OCR）**已废弃**，本页不再走那条路。
class ScoreOcrPage extends StatefulWidget {
  const ScoreOcrPage({super.key});

  @override
  State<ScoreOcrPage> createState() => _ScoreOcrPageState();
}

/// 玩家对某一条识别结果的修正。
///
/// 识别不可能 100% 准确，与其让错的数字留在界面上，不如每项都允许改。
/// 只存「被改过」的字段，null 表示沿用 OCR 的原始值。
class _OcrItemEdit {
  /// 玩家从曲库里选的歌（覆盖 OCR 的曲名匹配）
  Song? song;

  /// 玩家手填的曲名（曲库里没有这首歌时用）
  String? manualTitle;

  String? difficulty;
  String? fc;
  String? fs;

  double? achievement;
  int? dxScore;

  /// 展示用曲名：优先级 手填曲名 > 玩家选的歌 > OCR 结果
  String? titleOf(String? ocrTitle) =>
      manualTitle ?? song?.basicInfo.title ?? ocrTitle;
}

/// 选歌结果：要么是曲库里的一首歌，要么是一个手填曲名（曲库里没有）
class _SongChoice {
  final Song? song;
  final String? manualTitle;

  const _SongChoice({this.song, this.manualTitle});
}

/// 带实时上限校验的数字输入框。
///
/// 自己持有 controller 才能在「输入非法」时给出持续的红字提示，
/// 并且**不把非法值写回**——否则用户输到一半（比如想打 1005）就会把
/// 中间态当成最终值传给上层。
class _ValidatedNumberField extends StatefulWidget {
  final String label;
  final String hint;
  final String? initial;
  final double? max;
  final String? maxHint;
  final void Function(double? value) onSubmit;

  const _ValidatedNumberField({
    required this.label,
    required this.hint,
    required this.initial,
    required this.onSubmit,
    this.max,
    this.maxHint,
  });

  @override
  State<_ValidatedNumberField> createState() => _ValidatedNumberFieldState();
}

class _ValidatedNumberFieldState extends State<_ValidatedNumberField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial ?? '');
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleChanged(String raw) {
    final t = raw.trim();
    if (t.isEmpty) {
      setState(() => _error = null);
      widget.onSubmit(null); // 空 = 恢复为识别值
      return;
    }

    final v = double.tryParse(t);
    if (v == null) {
      setState(() => _error = '请输入数字');
      return; // 不写回，保留上一次的合法值
    }
    if (v < 0) {
      setState(() => _error = '不能为负数');
      return;
    }
    final max = widget.max;
    if (max != null && v > max) {
      setState(() => _error = '不得超过 ${_f(max)}');
      return;
    }

    setState(() => _error = null);
    widget.onSubmit(v);
  }

  static String _f(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        // 有错就只显示错误；没错时显示上限提示。两个都给会被系统覆盖成红框
        helperText: widget.maxHint,
        helperStyle: TextStyle(
          fontSize: 11,
          color: scheme.onSurfaceVariant,
        ),
        errorText: _error,
        errorStyle: const TextStyle(fontSize: 11),
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      onChanged: _handleChanged,
    );
  }
}

class _ScoreOcrPageState extends State<ScoreOcrPage> {
  final ImagePicker _picker = ImagePicker();
  final MaimaiHubOcrService _service = MaimaiHubOcrService.instance;

  String? _photoPath;
  bool _isRecognizing = false;
  MaimaiHubOcrBatch? _result;
  String? _error;

  /// MaimaiHub 登录态；null 表示还没查完
  bool? _loggedIn;

  /// 水鱼 OAuth 授权状态（读取成绩需要授权本应用）。
  /// **三态**：null = 正在检查 / 无法判断，false = 未授权，true = 已授权。
  /// 判定方式照抄「账号管理」对话框的 `_buildDivingFishAuthSection`。
  bool? _dfAuthorized;

  /// 落雪个人 API 密钥是否**存在本机**。
  ///
  /// 这就是「本页的同步按钮能不能真的传上去」的唯一前提：直传落雪要的是
  /// 密钥本体（`X-User-Token`），而 Hub 只肯返回一个布尔值、不肯把密钥还回来
  /// （见 [DivingFishProbeManager.setLxnsImportToken] 与后端 `PATCH /me`）。
  /// 所以密钥只在 Hub 上有 = 本机传不了。
  bool _lxnsKeyLocal = false;

  /// Hub 是否已绑定落雪密钥。**只能拿来提示，不能当成可同步的条件。**
  ///
  /// 之前这里是个三态 `_lxnsHasToken`，本地没有就问 Hub，Hub 说 true 就显示
  /// 「已设置密钥」—— 于是出现了「界面写着已设置、点同步却说没设置」：
  /// 密钥在云端，本机读不到。现在把这两个事实分开记。
  bool _lxnsKeyOnHub = false;

  /// 落雪状态是否还没查完（查完才显示结论，避免先闪一下「未设置」）
  bool _lxnsChecked = true;

  /// 水鱼授权检查用的 QQ（profile.bind_qq 取不到时回落本地缓存）
  String _authQQ = '';

  /// 识别结果里每张图匹配到的本地曲库数据，key 是 [MaimaiHubOcrItem.index]。
  /// 匹配不到就是没有这一项（曲库未刷新 / OCR 出的曲名跟曲库对不上）。
  final Map<int, Song> _matchedSongs = {};

  /// 本地曲库是不是空的。
  ///
  /// 之前 [_resolveMatchedSongs] 在曲库为空时直接 return，结果是**所有**卡片
  /// 都定位不到歌、两个同步按钮全部变灰，而界面上一句解释都没有；用户只会
  /// 看到账号状态写着「已授权 / 已设置密钥」，以为是登录出了问题。
  /// 记下这个状态，是为了能明确区分「曲库没下载」和「这一首没匹配上」。
  bool _songLibraryEmpty = false;

  /// 玩家对每一条识别结果的修正，key 同上。没有条目 = 没改过。
  final Map<int, _OcrItemEdit> _edits = {};

  /// 正在同步到水鱼的那一条（避免重复点击）
  int? _uploadingIndex;

  /// 正在同步到落雪的那一条（与水鱼的 loading 分开跟踪，
  /// 这样一条在同步水鱼时，另一条仍可显示落雪的进度）
  int? _uploadingLuoXueIndex;

  /// 该项最终生效的歌曲：玩家改过就用玩家的，否则用 OCR 匹配结果
  Song? _songOf(MaimaiHubOcrItem item) =>
      _edits[item.index]?.song ?? _matchedSongs[item.index];

  /// 玩家是否可以改这一条的难度。
  /// 只有定位到具体歌曲、并且知道它有哪些难度时，才能给出合法索引。
  bool _canPickDifficulty(MaimaiHubOcrItem item) {
    final n = _chartCountOf(item);
    return n != null && n > 0;
  }

  /// 该歌曲实际有几个难度谱面（cids 长度就是权威来源）。
  /// 返回 null 表示当前定位不到歌曲，此时无法约束难度索引。
  int? _chartCountOf(MaimaiHubOcrItem item) {
    final song = _songOf(item);
    if (song == null) return null;
    final n = song.cids.length;
    return n == 0 ? null : n;
  }

  /// 难度名 → 索引
  static int? _difficultyIndexOf(String? difficulty) {
    switch (difficulty?.toLowerCase()) {
      case 'basic':
        return 0;
      case 'advanced':
        return 1;
      case 'expert':
        return 2;
      case 'master':
        return 3;
      case 'remaster':
        return 4;
      default:
        return null; // utage 不在 0-4 里（宴谱是独立 song_id，不走这套索引）
    }
  }

  /// 索引 → 玩家看到的难度名
  static String _difficultyNameOf(int index) => switch (index) {
        0 => 'BASIC',
        1 => 'ADVANCED',
        2 => 'EXPERT',
        3 => 'MASTER',
        4 => 'Re:MASTER',
        _ => '难度 $index',
      };

  /// 该歌曲在 [index] 这个难度上的等级（没有则为 null）
  static String? _levelAtIndex(Song song, int index) {
    if (index < 0 || index >= song.level.length) return null;
    final lv = song.level[index].trim();
    return lv.isEmpty ? null : lv;
  }

  /// 该歌曲在 [index] 这个难度上的定数（没有或为 0 则为 null）
  static double? _dsAtIndex(Song song, int index) {
    if (index < 0 || index >= song.ds.length) return null;
    final ds = song.ds[index];
    return ds <= 0 ? null : ds;
  }

  /// 当前生效的难度索引；定位不到难度时返回 null
  int? _difficultyIndexEffective(MaimaiHubOcrItem item) =>
      _difficultyIndexOf(_difficultyOf(item));

  /// 换了歌曲之后，把难度约束到新歌真实存在的范围内。
  ///
  /// 必须做这一步：水鱼的更新接口按 `cids[level_index]` 取谱面，
  /// 传一个该歌曲不存在的索引会被服务端丢进 `continue` —— 请求返回成功，
  /// 但成绩没写进去。与其静默失败，不如在选歌时就纠正。
  void _applySongChange(MaimaiHubOcrItem item, _SongChoice picked) {
    final edit = _edits.putIfAbsent(item.index, () => _OcrItemEdit());
    edit.song = picked.song;
    edit.manualTitle = picked.manualTitle;

    final song = picked.song;
    if (song == null) {
      edit.difficulty = null;
      return;
    }
    final count = song.cids.length;
    if (count <= 0) {
      edit.difficulty = null;
      return;
    }
    final current = _difficultyIndexOf(edit.difficulty);
    if (current == null || current >= count) {
      // 原难度在新歌上没有 → 取最高难度（第 count-1 个）作为兜底
      edit.difficulty = _difficultyNameOf(count - 1).toLowerCase();
    }
  }

  String? _difficultyOf(MaimaiHubOcrItem item) =>
      _edits[item.index]?.difficulty ?? item.difficulty;

  String? _fcOf(MaimaiHubOcrItem item) => _edits[item.index]?.fc ?? item.fc;

  /// 同步标记统一转成**水鱼的值域**（fs / fsp / fsd / fsdp / sync）。
  ///
  /// OCR 走的是 MaimaiHub，它的 `fs` 取值是 fdx / fdxp；水鱼的更新接口
  /// 只认 fsd / fsdp（见 prober 源码 `std_fs`，它内部也做了 fdx→fsd 的映射）。
  /// 这里统一成水鱼的写法，显示交给 [StringUtil.formatFS]（fsd→FDX、fsdp→FDX+）。
  String? _fsOf(MaimaiHubOcrItem item) {
    final raw = _edits[item.index]?.fs ?? item.fs;
    switch (raw) {
      case 'fdx':
        return 'fsd';
      case 'fdxp':
        return 'fsdp';
      default:
        return raw;
    }
  }

  double? _achievementOf(MaimaiHubOcrItem item) =>
      _edits[item.index]?.achievement ?? item.achievement;

  int? _dxScoreOf(MaimaiHubOcrItem item) =>
      _edits[item.index]?.dxScore ?? item.dxScore;

  // ========== 取值上限（用于输入实时校验）==========

  /// 达成率上限。
  ///
  /// 普通曲上限 101%（100.5% 之后按 0.5% 进位，理论最高到 101）；
  /// 宴会场（song_id ≥ 100000）在服务端是 `101 * 难度数`——宴谱内部有多张子谱，
  /// 达成率是它们相加的结果，所以上限随难度数放大。
  /// 依据水鱼查分器源码 `max_achievements()`。
  double? _maxAchievementOf(MaimaiHubOcrItem item) {
    final song = _songOf(item);
    if (song == null) return null;
    final id = int.tryParse(song.id);
    if (id == null) return 101;
    if (id < 100000) return 101;
    final count = song.cids.length;
    return count == 0 ? 101 : 101.0 * count;
  }

  /// DX 分数上限 = 该谱面音符总数 × 3。
  /// 与全项目其余页面（Best50 / 歌曲详情 / 排行榜）的算法保持一致。
  int? _maxDxScoreOf(MaimaiHubOcrItem item) {
    final song = _songOf(item);
    final idx = _difficultyIndexEffective(item);
    if (song == null || idx == null) return null;
    if (idx < 0 || idx >= song.charts.length) return null;
    final notes = song.charts[idx].notes;
    if (notes.isEmpty) return null;
    final total = notes.fold<int>(0, (sum, n) => sum + n);
    return total == 0 ? null : total * 3;
  }

  // ========== 同步到水鱼 ==========

  /// 该条是否具备同步条件：定位到歌曲、有合法难度、有达成率
  bool _canSync(MaimaiHubOcrItem item) => _syncBlockReason(item) == null;

  /// 这一条**为什么**不能同步；能同步时返回 null。
  ///
  /// 存在的意义是「别让按钮无缘无故变灰」。之前这两个按钮的可用性只体现在
  /// 变灰上，用户看到账号状态写着「已授权 / 已设置密钥」却点不动按钮，
  /// 完全不知道卡在哪一步 —— 实际原因在 OCR 数据这一侧，与登录状态无关。
  /// 现在把原因直接写在按钮下面。
  ///
  /// 注意：这些原因**全部**与登录状态无关，账号问题在点下去之后才由
  /// [_syncToDivingFish] / [_syncToLuoXue] 提示。
  String? _syncBlockReason(MaimaiHubOcrItem item) {
    if (_songOf(item) == null) {
      // 曲库为空时这条是通杀所有卡片的，单独给一句能直接照做的提示
      return _songLibraryEmpty
          ? '本地曲库为空，无法定位曲目。请先到首页刷新曲库'
          : '没匹配到曲目，点「编辑此项」手动指定';
    }
    final idx = _difficultyIndexEffective(item);
    if (idx == null) {
      return '难度识别不出来（宴会场谱面不支持同步）';
    }
    final count = _chartCountOf(item);
    if (count == null) {
      return '曲库里这首歌没有谱面信息';
    }
    if (idx >= count) {
      return '这首歌没有第 ${idx + 1} 个难度（只有 $count 个谱面）';
    }
    if (_achievementOf(item) == null) {
      return '缺少达成率，点「编辑此项」补上';
    }
    return null;
  }

  Future<void> _syncToDivingFish(MaimaiHubOcrItem item) async {
    if (_uploadingIndex != null) return;

    final song = _songOf(item);
    final idx = _difficultyIndexEffective(item);
    final achievement = _achievementOf(item);
    if (song == null || idx == null || achievement == null) return;

    final token =
        await DivingFishProbeManager().getCachedDivingFishImportToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      Fluttertoast.showToast(msg: '还没有水鱼 Import-Token，请先到「登录水鱼」完成登录');
      return;
    }

    setState(() => _uploadingIndex = item.index);
    try {
      final result = await DivingFishScoreUploadService().uploadRecord(
        importToken: token,
        title: song.basicInfo.title,
        type: song.type,
        levelIndex: idx,
        achievement: achievement,
        fc: _fcOf(item),
        fs: _fsOf(item),
        dxScore: _dxScoreOf(item),
      );
      if (!mounted) return;
      Fluttertoast.showToast(
        msg: result.isNew
            ? '已新增到水鱼：${song.basicInfo.title}'
            : '已更新水鱼成绩：${song.basicInfo.title}',
      );
    } on ScoreUploadException catch (e) {
      if (mounted) Fluttertoast.showToast(msg: e.message);
    } catch (e) {
      if (mounted) Fluttertoast.showToast(msg: '同步失败：$e');
    } finally {
      if (mounted) setState(() => _uploadingIndex = null);
    }
  }

  /// 同步到落雪咖啡屋。
  ///
  /// 与水鱼那条路最大的不同：落雪要**数字曲目 id**，而水鱼的 id 体系跟落雪
  /// 不一致（见 [LuoXueScoreUploadService.toLxnsSongId]）。这里从本地曲库
  /// 的 `Song.id` 解析出 int 再交给 service 转换；解析不出来就说明这条
  /// 定位不到具体曲目，直接拒绝而不是硬传。
  ///
  /// 认证由 service 内部决定：OAuth Bearer 优先，个人 API 密钥回退。本页面
  /// 只在「两条都拿不到」时弹粘贴框 —— OAuth 已经授权过的用户走 OAuth 那条
  /// 路，没有被打扰。
  Future<void> _syncToLuoXue(MaimaiHubOcrItem item) async {
    if (_uploadingLuoXueIndex != null) return;

    final song = _songOf(item);
    final idx = _difficultyIndexEffective(item);
    final achievement = _achievementOf(item);
    if (song == null || idx == null || achievement == null) return;

    final songId = int.tryParse(song.id);
    if (songId == null) {
      Fluttertoast.showToast(msg: '无法解析曲目 ID，不能同步到落雪');
      return;
    }

    // OAuth 没有、本地密钥也没有 —— 就地让用户粘一个，避免弹个 toast 让人
    // 自己去找入口。两条路都有的话就走 OAuth，不打扰用户。
    final hasOAuth = await LuoXueOAuthManager().getAccessToken() != null;
    if (!hasOAuth && !_lxnsKeyLocal) {
      await _promptForLxnsKey();
      if (!mounted) return;
      // 粘了也不代表能用（空字符串会被拦下）。再确认一次，避免空跑一次上传
      final again =
          await LuoXueOAuthManager().getAccessToken() != null || _lxnsKeyLocal;
      if (!again) return;
    }

    setState(() => _uploadingLuoXueIndex = item.index);
    try {
      final result = await LuoXueScoreUploadService().uploadRecord(
        divingFishSongId: songId,
        divingFishType: song.type,
        levelIndex: idx,
        achievement: achievement,
        fc: _fcOf(item),
        fs: _fsOf(item),
        dxScore: _dxScoreOf(item),
      );
      if (!mounted) return;
      Fluttertoast.showToast(
        msg: _composeLuoXueToast(song.basicInfo.title, result),
        toastLength: Toast.LENGTH_LONG,
      );
    } on LuoXueUploadException catch (e) {
      if (mounted) Fluttertoast.showToast(msg: e.message);
    } catch (e) {
      if (mounted) Fluttertoast.showToast(msg: '同步失败：$e');
    } finally {
      if (mounted) setState(() => _uploadingLuoXueIndex = null);
    }
  }

  /// 把落雪的 `old → new` 对比拼成一条人话的 Toast。
  ///
  /// 服务端的约定：每个字段值是 `{old?, new?}`，**有变化才出现**。所以
  /// - `oldAch != null && newAch != null && oldAch != newAch` → 改了
  /// - `oldAch == null && newAch != null` → 新增（之前没成绩）
  /// - 两个都 null → 服务端没回这个字段（异常路径，已在 service 拦下）
  String _composeLuoXueToast(String title, LuoXueUploadResult r) {
    final lines = <String>[];
    if (r.changed) {
      lines.add('已更新到落雪：$title');
    } else {
      lines.add('已同步到落雪（无变化）：$title');
    }
    if (r.oldAchievement != null && r.newAchievement != null) {
      lines.add(
          '达成率 ${_formatAchievement(r.oldAchievement!)}% → ${_formatAchievement(r.newAchievement!)}%');
    } else if (r.newAchievement != null) {
      lines.add('达成率 ${_formatAchievement(r.newAchievement!)}%');
    }
    if (r.oldDxScore != null && r.newDxScore != null) {
      lines.add('DX 分 ${r.oldDxScore} → ${r.newDxScore}');
    } else if (r.newDxScore != null) {
      lines.add('DX 分 ${r.newDxScore}');
    }
    return lines.join('\n');
  }

  /// 达成率显示精度。落雪那边是 4 位小数（`100.7506`），项目其它处一般取
  /// 3 位，跟着一致就行；100.0 这种整数没小数尾巴看着也别扭。
  static String _formatAchievement(double v) {
    final s = v.toStringAsFixed(3);
    return s.endsWith('.000') ? v.toStringAsFixed(0) : s;
  }

  @override
  void initState() {
    super.initState();
    _checkLogin();
    _refreshAuthStatus();
  }

  Future<void> _checkLogin() async {
    final ok = await _service.isAvailable();
    if (mounted) setState(() => _loggedIn = ok);
  }

  // ========== 上传目标账号状态 ==========
  //
  // 判定方式**照抄「账号管理」对话框**（HomePage `_showAccountManageDialog`），
  // 不自己发明第二套标准 —— 否则同一个账号在两个页面会显示不同结论：
  //
  //   水鱼 → `DivingFishOAuthManager.checkAuthorization(qq)`
  //          检查的是「本应用有没有被授权读取该 QQ 的成绩」，不是「有没有 token」。
  //          没有 OAuth 授权时，写入同样会被服务端拒绝。
  //   落雪 → 本机密钥 (`probeLxnsImportToken`) 优先；其次问 Hub
  //          （`DivingFishProbeManager.hasLxnsImportToken()`，只返布尔）。
  //          状态条上看到的「已设置密钥」= 本机有，跟上传能用的条件一致；
  //          「云端已绑定·本机缺密钥」= Hub 有但本机没有，**不能直接同步**。
  //          两条路（OAuth / X-User-Token）真要发起同步时由 service 自己决定。

  /// 读取两个上传目标的账号状态。
  ///
  /// 识别完成后再刷一次——用户可能刚在别处登录/授权过。
  /// 全程 try/catch：这些都是网络查询，失败不能让整页崩，只显示「未确认」。
  Future<void> _refreshAuthStatus() async {
    setState(() {
      _dfAuthorized = null; // 重新进入"检查中"
      _lxnsChecked = false;
    });

    // ── 水鱼：先拿 QQ，再查授权状态 ──
    bool? dfAuth;
    String qq = '';
    try {
      final prefs = await SharedPreferences.getInstance();
      qq = prefs.getString('cachedQQ') ?? '';

      final jwt = prefs.getString(CacheKeyConstant.probeDivingFishToken) ?? '';
      if (jwt.isNotEmpty) {
        // 与账号管理一致：优先用 profile 里的 bind_qq
        try {
          final resp = await ApiClient.get(
            Uri.parse(ApiUrls.DivingFishProfileApi),
            headers: {
              'Content-Type': 'application/json',
              'Cookie': 'jwt_token=$jwt',
            },
          );
          if (resp.statusCode == 200) {
            final p = json.decode(resp.body) as Map<String, dynamic>;
            final bindQQ = p['bind_qq']?.toString() ?? '';
            if (bindQQ.isNotEmpty) qq = bindQQ;
          }
        } catch (e) {
          debugPrint('[ScoreOcr] 拉取水鱼 profile 失败: $e');
        }
      }

      dfAuth = qq.isEmpty
          ? null // 没有 QQ 就没法查授权，显示「未确认」而不是「未授权」
          : await DivingFishOAuthManager().checkAuthorization(qq);
    } catch (e) {
      debugPrint('[ScoreOcr] 查询水鱼授权状态失败: $e');
      dfAuth = null;
    }

    // ── 落雪：分两个事实查，别混成一个 ──
    //
    // 「本机有密钥」= 本页可以直传；「Hub 有密钥」= 只有 Hub 能代传，
    // 本页的同步按钮用不上它。账号管理对话框也是先查本地再问 Hub，
    // 但它那边两个来源都算「已设置」；在本页那样会撒谎。
    bool keyLocal = false;
    bool keyOnHub = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final local = prefs.getString(CacheKeyConstant.probeLxnsImportToken);
      keyLocal = local != null && local.isNotEmpty;
      if (!keyLocal) {
        keyOnHub = await DivingFishProbeManager().hasLxnsImportToken() == true;
      }
    } catch (e) {
      debugPrint('[ScoreOcr] 查询落雪密钥状态失败: $e');
    }

    if (!mounted) return;
    setState(() {
      _authQQ = qq;
      _dfAuthorized = dfAuth;
      _lxnsKeyLocal = keyLocal;
      _lxnsKeyOnHub = keyOnHub;
      _lxnsChecked = true;
    });
  }

  /// 点状态条。
  ///
  ///   - 水鱼：`openBindingLink(qq)` 直接打开授权链接（照抄账号管理，不是只弹提示）
  ///   - 落雪：**本机有密钥**才去开绑定页；没有密钥就直接开粘贴框。
  ///     本页的同步走直传，非要本机有密钥不可，所以把「粘贴密钥」放在第一次
  ///     点击就能到的地方 —— 让用户先去网页拿密钥、再自己找地方粘贴、
  ///     回来发现还是不行，就是之前那条死路。
  Future<void> _onAuthChipTap({required bool isDivingFish}) async {
    if (isDivingFish) {
      if (_authQQ.isEmpty) {
        Fluttertoast.showToast(msg: '未找到 QQ 号，请先到「系统 → 登录水鱼」登录');
        return;
      }
      final ok = await DivingFishOAuthManager().openBindingLink(_authQQ);
      if (!mounted) return;
      Fluttertoast.showToast(msg: ok ? '已打开授权链接，完成授权后返回即可' : '发起授权失败，请稍后重试');
      if (ok) await _refreshAuthStatus();
      return;
    }

    if (_lxnsKeyLocal) {
      // 已有密钥还点：当作「去落雪看看/换一个」的入口
      await _openLxnsProfilePage();
      return;
    }
    await _promptForLxnsKey();
  }

  /// 打开落雪的第三方绑定页（个人 API 密钥就在那个页面生成）
  Future<void> _openLxnsProfilePage() async {
    final uri = Uri.parse('https://maimai.lxns.net/user/profile?tab=thirdparty');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        // canLaunchUrl 之后已经跨了 async gap，用 context 前必须查 mounted
        launchUrlFallback(uri.toString(), context);
      }
    } catch (e) {
      debugPrint('[ScoreOcr] 打开落雪绑定页失败：$e');
      if (mounted) launchUrlFallback(uri.toString(), context);
    }
  }

  /// 在本页直接粘贴落雪个人 API 密钥。
  ///
  /// 为什么要有这个框：直传落雪要的是密钥本体，而 Hub 只返回
  /// `hasLxnsImportToken` 这个布尔值（后端 `PATCH /me` 是只写不读），
  /// 所以「密钥只在云端」这种状态下本机无论如何都传不了，必须让用户
  /// 在本机存一份。之前唯一的入口在首页「账号管理」里，太绕。
  ///
  /// 保存后照账号管理的做法顺手同步给 Hub；那一步是**尽力而为**，
  /// 失败也不提示、不拦流程 —— 本地直传根本不依赖 Hub。
  Future<void> _promptForLxnsKey() async {
    final text = await showDialog<String>(
      context: context,
      // 用一个 StatefulWidget 承载对话框内容：controller 由它的 State 持有、
      // 在 dispose() 里释放，时机由框架保证正好在退出动画之后。
      // 直接在 showDialog 之后立刻 controller.dispose() 会让 TextField
      // 在退出动画期间被强行解除监听，触发 framework.dart 里的
      // `_dependents.isEmpty` 断言。
      builder: (_) => _LxnsKeyPromptDialog(cloudOnlyHint: _lxnsKeyOnHub),
    );
    if (!mounted) return;
    // 取消（null）和被保存按钮拦下的空串要分开处理：后者什么都不做会让人
    // 以为保存成功了
    if (text == null) return;
    if (text.isEmpty) {
      Fluttertoast.showToast(msg: '密钥为空，没有保存');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(CacheKeyConstant.probeLxnsImportToken, text);
    // 顺手同步给 Hub。失败也不影响本机直传，所以不 await、不报错。
    unawaited(DivingFishProbeManager().setLxnsImportToken(text));

    if (!mounted) return;
    Fluttertoast.showToast(msg: '落雪密钥已保存到本机，可以同步了');
    await _refreshAuthStatus();
  }

  // ========== 选图 ==========

  void _showSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.tableBorder(Theme.of(context).brightness),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text('选择图片来源',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, size: 28),
              title: const Text('拍照'),
              subtitle: const Text('对着机台结算页面拍一张'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, size: 28),
              title: const Text('从相册选择'),
              subtitle: const Text('选取已经拍好的结算画面'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          Fluttertoast.showToast(msg: '需要相机权限');
          await openAppSettings();
        }
        return;
      }
    }
    try {
      final photo = await _picker.pickImage(source: source, imageQuality: 95);
      if (photo != null && mounted) {
        final cropped = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (_) => _OcrImageCropPage(imagePath: photo.path),
          ),
        );
        if (!mounted) return;
        if (cropped != null) {
          setState(() {
            _photoPath = cropped;
            _result = null;
            _error = null;
          });
        } else {
          // 用户取消裁剪，回退到原图
          setState(() {
            _photoPath = photo.path;
            _result = null;
            _error = null;
          });
        }
      }
    } catch (e) {
      if (mounted) Fluttertoast.showToast(msg: '选取图片失败: $e');
    }
  }

  // ========== OCR ==========

  Future<void> _recognize() async {
    final p = _photoPath;
    if (p == null) return;
    setState(() {
      _isRecognizing = true;
      _error = null;
      _result = null;
      _matchedSongs.clear();
      _edits.clear();
    });
    try {
      final result = await _service.recognize([File(p)]);
      if (!mounted) return;
      setState(() {
        _result = result;
        _isRecognizing = false;
        _loggedIn = true;
      });
      // 用本地曲库补全曲绘 / 版本 / 流派 / 定数。识别本身不依赖它，
      // 所以单独 await，失败也不影响成绩展示。
      await _resolveMatchedSongs(result);
      // 顺手刷新两个上传目标的账号状态：用户可能刚在别处登录过
      await _refreshAuthStatus();
      if (!mounted) return;
      if (!result.hasAnySuccess) {
        Fluttertoast.showToast(msg: '没有识别出成绩，可裁剪得更贴近结算区域后重试');
      }
    } on MaimaiHubOcrException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isRecognizing = false;
        // 401 会被翻译成「登录状态已失效」，顺手刷新登录态提示
        if (e.message.contains('登录')) _loggedIn = false;
      });
      Fluttertoast.showToast(msg: e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isRecognizing = false;
      });
      Fluttertoast.showToast(msg: '识别出错: $e');
    }
  }

  /// 把识别出的曲名映射到本地曲库的 [Song]，用于补全曲绘 / 版本 / 流派 / 定数。
  ///
  /// 匹配规则（与全项目其他地方「按歌名找歌」的做法一致，不另造一套）：
  ///   1. 严格同名（含 DX / 标准区分）
  ///   2. 大小写无关的同名
  ///   3. 曲名完全相同但有多个版本时，优先取 DX 版（结算画面里 DX 谱更常见）
  ///
  /// 曲库没有的一律跳过——OCR 出来的曲名可能是活动新曲或拼写差异，
  /// 这时宁可不显示，也不要硬塞一个错的曲绘。
  Future<void> _resolveMatchedSongs(MaimaiHubOcrBatch batch) async {
    final songs = await MaimaiMusicDataManager().getCachedSongs();
    if (!mounted) return;

    // 曲库拿不到就**记下来并告诉用户**，不要静默返回 —— 静默的话所有卡片的
    // 同步按钮会一起变灰，看起来像是登录失效。
    if (songs == null || songs.isEmpty) {
      setState(() {
        _songLibraryEmpty = true;
        _matchedSongs.clear();
      });
      return;
    }

    final matched = <int, Song>{};
    for (final item in batch.results) {
      final best = item.bestCandidate;
      if (best == null) continue;
      final song = _findSong(songs, best.title, item.isDx);
      if (song != null) matched[item.index] = song;
    }

    // 曲绘可能走网络兜底，提前预热，避免滚动时闪一下
    for (final song in matched.values) {
      unawaited(CoverUtil.resolveCoverProvider(song.id)
          .then((_) {}, onError: (_) {}));
    }

    if (!mounted) return;
    setState(() {
      _songLibraryEmpty = false;
      _matchedSongs
        ..clear()
        ..addAll(matched);
    });
  }

  static Song? _findSong(List<Song> songs, String title, bool? isDx) {
    final target = title.trim();
    if (target.isEmpty) return null;

    final exact = <Song>[];
    final loose = <Song>[];
    final lowerTarget = target.toLowerCase();
    for (final s in songs) {
      if (s.basicInfo.title == target) {
        exact.add(s);
      } else if (s.basicInfo.title.toLowerCase() == lowerTarget) {
        loose.add(s);
      }
    }
    final pool = exact.isNotEmpty ? exact : loose;
    if (pool.isEmpty) return null;
    if (pool.length == 1) return pool.first;

    // 同名多版本：按 OCR 给的 DX 标识挑，没有标识就优先 DX
    if (isDx != null) {
      for (final s in pool) {
        if ((s.type.toUpperCase() == 'DX') == isDx) return s;
      }
    }
    for (final s in pool) {
      if (s.type.toUpperCase() == 'DX') return s;
    }
    return pool.first;
  }

  void _reset() => setState(() {
        _photoPath = null;
        _result = null;
        _error = null;
        _songLibraryEmpty = false;
        _matchedSongs.clear();
        _edits.clear();
      });

  // ========== 结果修正 ==========

  static const List<String> _fcOptions = ['fc', 'fcp', 'ap', 'app'];

  /// 同步标记的**水鱼值域**（见 prober 源码 `std_fs`）：
  /// fs / fsp / fsd / fsdp / sync，外加空字符串表示无。
  /// 显示交给 StringUtil.formatFS（fsd→FDX、fsdp→FDX+、sync→SC）。
  static const List<String> _fsOptions = ['fs', 'fsp', 'fsd', 'fsdp', 'sync'];

  /// 空选项：选中表示「清空这一项」
  static const String _emptyOption = '';

  Future<void> _showEditSheet(MaimaiHubOcrItem item) async {
    final scheme = Theme.of(context).colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          void apply(void Function(_OcrItemEdit e) change) {
            setSheetState(() =>
                change(_edits.putIfAbsent(item.index, () => _OcrItemEdit())));
            if (mounted) setState(() {});
          }

          /// 选歌要顺带纠正难度，统一走 _applySongChange
          void applySong(_SongChoice picked) =>
              apply((e) => _applySongChange(item, picked));

          final edit = _edits[item.index];
          final best = item.bestCandidate;
          final diffIndex = _difficultyIndexEffective(item);
          final chartCount = _chartCountOf(item);
          final effectiveTitle =
              edit?.titleOf(best?.title) ?? best?.title ?? '未识别出曲名';

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('修正识别结果',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface)),
                  const SizedBox(height: 4),
                  Text('识别不可能百分百准确，这里改过的值会直接替换卡片上的显示',
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 16),

                  // ── 歌曲：与自定义 Best50 一致的带曲绘输入框 ──
                  _sheetSongField(
                    cover: _buildSongCover(item),
                    value: effectiveTitle,
                    onTap: () async {
                      final picked = await _showSongPicker(item);
                      if (picked == null) return;
                      applySong(picked);
                    },
                    onClear: edit?.song != null || edit?.manualTitle != null
                        ? () => apply((e) {
                              e.song = null;
                              e.manualTitle = null;
                            })
                        : null,
                  ),

                  const SizedBox(height: 12),

                  // ── 难度：与自定义 Best50 一致，默认展开并直接列出真实难度 ──
                  Text('难度',
                      style: TextStyle(
                          fontSize: 13, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  if (!_canPickDifficulty(item))
                    Text(
                      '先选定一首歌曲，才能列出它实际有的难度',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.warningOrange(
                              Theme.of(context).brightness)),
                    )
                  else
                    Builder(builder: (context) {
                      // 绑定成非空局部变量，Dart 才能把它提升为非空类型
                      final song = _songOf(item)!;
                      final count = chartCount!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              for (var i = 0; i < count; i++)
                                ChoiceChip(
                                  label: Text(_difficultyNameOf(i)),
                                  selected: diffIndex == i,
                                  // 带出等级/定数，方便确认选对了没
                                  tooltip: [
                                    _levelAtIndex(song, i),
                                    _dsAtIndex(song, i) == null
                                        ? null
                                        : '定数 ${_dsAtIndex(song, i)!.toStringAsFixed(1)}',
                                  ].whereType<String>().join(' · '),
                                  onSelected: (_) => apply((e) =>
                                      e.difficulty =
                                          _difficultyNameOf(i).toLowerCase()),
                                ),
                            ],
                          ),
                          // 当前选中难度的标级 / 定数
                          if (diffIndex != null &&
                              diffIndex >= 0 &&
                              diffIndex < count)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                '${_difficultyNameOf(diffIndex)}'
                                '${_levelAtIndex(song, diffIndex) == null ? '' : ' · ${_levelAtIndex(song, diffIndex)}'}'
                                '${_dsAtIndex(song, diffIndex) == null ? '' : ' · 定数 ${_dsAtIndex(song, diffIndex)!.toStringAsFixed(1)}'}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant),
                              ),
                            ),
                        ],
                      );
                    }),
                  const SizedBox(height: 4),

                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: _sheetNumberField(
                            label: '达成率 (%)',
                            hint: item.achievement?.toStringAsFixed(4) ?? '—',
                            initial: edit?.achievement?.toString(),
                            max: _maxAchievementOf(item),
                            maxHint: _maxAchievementOf(item) == null
                                ? null
                                : '上限 ${_formatNumber(_maxAchievementOf(item)!)}%',
                            onSubmit: (v) => apply((e) => e.achievement = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _sheetNumberField(
                            label: 'DX 分数',
                            hint: item.dxScore?.toString() ?? '—',
                            initial: edit?.dxScore?.toString(),
                            max: _maxDxScoreOf(item)?.toDouble(),
                            maxHint: _maxDxScoreOf(item) == null
                                ? null
                                : '上限 ${_maxDxScoreOf(item)}',
                            onSubmit: (v) =>
                                apply((e) => e.dxScore = v?.round()),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // RA 实时预览（定位到歌曲+难度、且已填达成率时显示）
                  Builder(builder: (context) {
                    final song = _songOf(item);
                    final idx = _difficultyIndexEffective(item);
                    final ach = _achievementOf(item);
                    final ds = (song != null && idx != null)
                        ? _dsAtIndex(song, idx)
                        : null;
                    if (ds == null || ach == null) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'RA：${DiffBest50Service().calculateSingleRating(ds, ach)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 12),
                  _sheetChoiceRow(
                    label: '连击',
                    options: _fcOptions,
                    current: _fcOf(item),
                    labelOf: (v) => StringUtil.formatFC(v),
                    onPick: (v) => apply((e) => e.fc = v),
                    onClear: edit?.fc != null
                        ? () => apply((e) => e.fc = null)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _sheetChoiceRow(
                    label: '同步',
                    options: _fsOptions,
                    current: _fsOf(item),
                    // 仅此处把 sync 显示成 SYNC（formatFS 的通用显示仍是 SC）
                    labelOf: (v) => v == 'sync' ? 'SYNC' : StringUtil.formatFS(v),
                    onPick: (v) => apply((e) => e.fs = v),
                    onClear: edit?.fs != null
                        ? () => apply((e) => e.fs = null)
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '「空」表示不设置该标记。同步标记会按水鱼的值域提交（FS / FS+ / FDX / FDX+ / SYNC）。',
                    style:
                        TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                  ),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.restart_alt, size: 18),
                      label: const Text('恢复为识别结果'),
                      onPressed: (edit == null)
                          ? null
                          : () {
                              setSheetState(() => _edits.remove(item.index));
                              if (mounted) setState(() {});
                            },
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('完成'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 歌曲字段左侧的曲绘；未定位到歌曲时显示占位图标。
  Widget _buildSongCover(MaimaiHubOcrItem item) {
    final scheme = Theme.of(context).colorScheme;
    final song = _songOf(item);
    if (song == null) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4.0),
        ),
        child: Icon(Icons.music_note, size: 22, color: scheme.onSurfaceVariant),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(4.0),
      child: CoverUtil.buildCoverWidget(song.id, 40),
    );
  }

  /// 歌曲输入框：与自定义 Best50 一致——左侧曲绘 + 「歌曲」小标签 + 曲名 + 右侧箭头。
  Widget _sheetSongField({
    required Widget cover,
    required String value,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outline),
          borderRadius: BorderRadius.circular(4.0),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Row(
          children: [
            cover,
            const SizedBox(width: 10.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('歌曲',
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant)),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, color: scheme.onSurface),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              IconButton(
                icon: Icon(Icons.close,
                    size: 16, color: scheme.onSurfaceVariant),
                tooltip: '恢复为识别结果',
                onPressed: onClear,
                visualDensity: VisualDensity.compact,
              ),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  /// 数字输入字段：实时校验上限，超限时红字报错并且**不写入**。
  ///
  /// 留空表示「恢复为识别值」。上限为 null 时不做校验（定位不到歌曲/难度）。
  Widget _sheetNumberField({
    required String label,
    required String hint,
    required String? initial,
    required void Function(double? value) onSubmit,
    double? max,
    String? maxHint,
  }) {
    return _ValidatedNumberField(
      label: label,
      hint: hint,
      initial: initial,
      max: max,
      maxHint: maxHint,
      onSubmit: onSubmit,
    );
  }

  /// 把上限数字格式化得干净些：整数不带小数点，否则保留 1 位
  static String _formatNumber(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  /// 一组互斥的标记按钮（FC / FS）
  Widget _sheetChoiceRow({
    required String label,
    required List<String> options,
    required String? current,
    required String Function(String) labelOf,
    required void Function(String) onPick,
    VoidCallback? onClear,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: TextStyle(fontSize: 14, color: scheme.onSurface)),
            const Spacer(),
            if (onClear != null)
              TextButton(
                onPressed: onClear,
                child: const Text('清除', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            // 空选项：选中表示这一项为空（不设置连击/同步标记）
            ChoiceChip(
              label: const Text('空'),
              selected: current == null || current == _emptyOption,
              onSelected: (_) => onPick(_emptyOption),
            ),
            for (final o in options)
              ChoiceChip(
                label: Text(labelOf(o)),
                selected: current == o,
                onSelected: (_) => onPick(o),
              ),
          ],
        ),
      ],
    );
  }

  /// 选歌：先给 OCR 的候选，再给本地曲库全量（带搜索）。
  ///
  /// 搜索框逻辑与自定义 Best50 选曲器一致：`SongSearchService.searchSongs`
  /// （歌名/ID/曲师/谱师/流派/版本/别名/BPM），500ms 防抖 + 搜索中指示。
  Future<_SongChoice?> _showSongPicker(MaimaiHubOcrItem item) async {
    final songs = await MaimaiMusicDataManager().getCachedSongs() ?? [];
    if (!mounted) return null;

    final candidates = item.candidates
        .map((c) => c.title)
        .where((t) => t.trim().isNotEmpty)
        .toList();

    var query = '';
    var results = <Song>[];
    var searching = false;
    Timer? debounce;

    try {
      return await showModalBottomSheet<_SongChoice>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetCtx) => StatefulBuilder(
          builder: (ctx, setSheetState) {
            final brightness = Theme.of(ctx).brightness;
            final scheme = Theme.of(ctx).colorScheme;
            final q = query.trim();
            final filtered = q.isEmpty ? songs : results;

            Future<void> runSearch(String value) async {
              final r = await SongSearchService.searchSongs(value);
              if (!ctx.mounted || value != query) return;
              setSheetState(() {
                results = r;
                searching = false;
              });
            }

            return SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.82,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: TextField(
                      autofocus: false,
                      decoration: const InputDecoration(
                        hintText: '歌名/BPM/谱师/曲师/别名/歌曲ID/...',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) {
                        debounce?.cancel();
                        setSheetState(() {
                          query = v;
                          searching = v.trim().isNotEmpty;
                          if (v.trim().isEmpty) results = [];
                        });
                        if (v.trim().isEmpty) return;
                        debounce = Timer(
                          const Duration(milliseconds: 500),
                          () => runSearch(v),
                        );
                      },
                    ),
                  ),
                  if (candidates.isNotEmpty)
                    SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          for (final t in candidates)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ActionChip(
                                label: Text(t),
                                avatar: const Icon(Icons.auto_awesome, size: 16),
                                onPressed: () {
                                  final m = _findSong(songs, t, item.isDx);
                                  Navigator.pop(
                                    ctx,
                                    _SongChoice(
                                      song: m,
                                      // 曲库里没有这个曲名时退化成手填曲名
                                      manualTitle: m == null ? t : null,
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  const Divider(height: 1),
                  Expanded(
                    child: searching
                        ? const Center(child: CircularProgressIndicator())
                        : filtered.isEmpty
                            ? Center(
                                child: Text(
                                  q.isEmpty ? '暂无歌曲数据' : '未找到匹配的歌曲',
                                  style:
                                      TextStyle(color: scheme.onSurfaceVariant),
                                ),
                              )
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (_, i) =>
                                    _buildPickerRow(ctx, filtered[i], brightness),
                              ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    } finally {
      debounce?.cancel();
    }
  }

  /// 选曲结果行：曲目类型（ST/DX/UTAGE）放在歌名前，颜色/字号与其它页面一致。
  Widget _buildPickerRow(BuildContext ctx, Song song, Brightness brightness) {
    final bool isUtage = song.id.length == 6;
    final String typeLabel =
        isUtage ? 'UTAGE' : (song.type == 'SD' ? 'ST' : 'DX');
    final Color typeColor = isUtage
        ? const Color(0xFFFF6B8B)
        : (song.type == 'SD'
            ? AppColors.linkBlue(brightness)
            : AppColors.warningOrange(brightness));
    const double nameFontSize = 16.0;

    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: CoverUtil.buildCoverWidget(song.id, 44),
      ),
      title: Row(
        children: [
          Text(
            typeLabel,
            style: TextStyle(
              fontSize: nameFontSize,
              fontWeight: FontWeight.bold,
              color: typeColor,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              song.basicInfo.title,
              style: const TextStyle(fontSize: nameFontSize),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      subtitle: Text(
        '${song.basicInfo.artist} · ${StringUtil.formatVersion2(song.basicInfo.from)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => Navigator.pop(ctx, _SongChoice(song: song, manualTitle: null)),
    );
  }

  // ========== UI 框架 ==========

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final sw = MediaQuery.of(context).size.width;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final c = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          CommonWidgetUtil.buildCommonBgWidget(),
          CommonWidgetUtil.buildCommonChiffonBgWidget(context),
          // crossAxisAlignment 必须显式写 stretch。
          //
          // 默认值 center 下，Expanded 只撑满主轴（竖直），横轴仍是松约束——
          // 里面那张内容卡片会**按内容宽度收缩**：识别成功后因为结果卡片有
          // width: double.infinity 而撑满，空状态/识别中则会缩到引导文字的宽度，
          // 看起来就是「卡片忽宽忽窄」。加了 stretch 后卡片恒等于屏幕宽度。
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _buildTitleBar(sw, c),
            Expanded(
              child: Container(
                // 左右不留边、贴满屏幕宽度。
                //
                // 全 App 有 41 个页面用的是 `fromLTRB(4, 0, 4, 10 + safeBottom)`，
                // 本页**有意偏离**那个标准：结算画面以横向信息为主（曲名、达成率、
                // 六项成绩字段），卡片越宽越好读。这是本页唯一的例外，改回去只需
                // 把下面的 0 换回 4。
                margin: EdgeInsets.fromLTRB(0, 0, 0, 10 + safeBottom),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [AppConstants.defaultShadow(brightness)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildContent(sw, c),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildTitleBar(double sw, Color c) => Container(
        padding: const EdgeInsets.fromLTRB(16, 48, 16, 8),
        child: Row(children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: c),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Center(
              child: Text(
                '结算画面识别',
                style: TextStyle(
                    color: c, fontSize: sw * 0.06, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.transparent),
            onPressed: null,
          ),
        ]),
      );

  Widget _buildContent(double sw, Color c) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(sw * 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (_loggedIn == false) ...[
            _buildLoginBanner(sw, c),
            const SizedBox(height: 16),
          ],
          if (_isRecognizing) ...[
            _buildRecognizing(sw, c),
          ] else if (_result != null) ...[
            _buildResultList(sw, c),
            const SizedBox(height: 16),
            _buildActionButtons(sw, c),
          ] else if (_photoPath != null) ...[
            _buildPhotoPreview(sw, c),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _buildErrorBanner(sw, c),
            ],
            const SizedBox(height: 16),
            _buildActionButtons(sw, c),
          ] else ...[
            _buildGuide(sw, c),
            const SizedBox(height: 16),
            _buildActionButtons(sw, c),
          ],
        ],
      ),
    );
  }

  Widget _buildRecognizing(double sw, Color c) => Padding(
        padding: EdgeInsets.all(sw * 0.06),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('正在识别成绩',
                style: TextStyle(
                    color: c,
                    fontSize: sw * 0.045,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('曲绘 + 标题双路匹配，通常需要几秒',
                style: TextStyle(
                    color: c.withValues(alpha: 0.6), fontSize: sw * 0.032)),
            const SizedBox(height: 32),
          ],
        ),
      );

  Widget _buildGuide(double sw, Color c) => Column(
        children: [
          const SizedBox(height: 24),
          Icon(Icons.document_scanner,
              size: sw * 0.18, color: c.withValues(alpha: 0.35)),
          const SizedBox(height: 12),
          Text('对着机台结算页面拍一张照片',
              style: TextStyle(
                  color: c, fontSize: sw * 0.045, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('自动识别曲名、达成率、DX 分数、难度与 FC/FS\n尽量拍正、拍清，识别更准',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: c.withValues(alpha: 0.5), fontSize: sw * 0.03)),
        ],
      );

  Widget _buildPhotoPreview(double sw, Color c) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: sw * 0.7,
            constraints: BoxConstraints(maxHeight: sw * 1.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.withValues(alpha: 0.3), width: 2),
              boxShadow: [
                AppConstants.defaultShadow(Theme.of(context).brightness)
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(File(_photoPath!), fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 10),
          Text('图片已就绪，点击下方「识别」开始',
              style: TextStyle(
                  color: c.withValues(alpha: 0.5), fontSize: sw * 0.03)),
        ],
      );

  Widget _buildErrorBanner(double sw, Color c) => Container(
        width: sw * 0.85,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.errorRed(Theme.of(context).brightness)
              .withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.errorRed(Theme.of(context).brightness)
                .withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline,
                color: AppColors.errorRed(Theme.of(context).brightness)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_error ?? '',
                  style: TextStyle(
                      color: c.withValues(alpha: 0.85), fontSize: sw * 0.032)),
            ),
          ],
        ),
      );

  /// 未登录 MaimaiHub 时的提示横幅。
  ///
  /// 识别接口必须带用户 token，未登录必然 401，所以提前说清楚，
  /// 免得用户截好图才在最后一步失败。
  Widget _buildLoginBanner(double sw, Color c) {
    final warn = AppColors.warningOrange(Theme.of(context).brightness);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warn.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: warn.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, color: warn),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '未登录 MaimaiHub，无法识别。'
              '请先到「首页 → 同步成绩」完成 MaimaiHub 登录后回来重试。',
              style: TextStyle(
                  color: c.withValues(alpha: 0.85), fontSize: sw * 0.032),
            ),
          ),
        ],
      ),
    );
  }

  // ========== 结构化识别结果 ==========

  Widget _buildResultList(double sw, Color c) {
    final batch = _result!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              batch.hasAnySuccess ? Icons.check_circle : Icons.error_outline,
              color: batch.hasAnySuccess
                  ? AppColors.successGreen(Theme.of(context).brightness)
                  : AppColors.errorRed(Theme.of(context).brightness),
            ),
            const SizedBox(width: 8),
            Text(
              batch.hasAnySuccess
                  ? '识别完成 · ${batch.okCount}/${batch.results.length} 张成功'
                  : '未能识别出成绩',
              style: TextStyle(
                  color: c, fontSize: sw * 0.04, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...batch.results.map((item) => _buildResultCard(item, sw, c)),
      ],
    );
  }

  /// 单个账号状态小胶囊。
  ///
  /// [ready] 三态：true=就绪（绿）/ false=未就绪（橙）/ null=未确认（灰）
  Widget _buildAuthChip({
    required String label,
    required bool? ready,
    required String readyText,
    required String notReadyText,
    String? unknownText,
    /// `ready == false` 但仍有一种「半可用」的独立状态时用（落雪的
    /// 「云端已绑定、本机没有」）。给文案就会显示成橙色警告态。
    String? warnText,
    required VoidCallback onTap,
    required double sw,
  }) {
    final brightness = Theme.of(context).brightness;
    final Color color;
    final String status;
    final IconData icon;

    if (ready == true) {
      color = AppColors.successGreen(brightness);
      status = readyText;
      icon = Icons.check_circle_outline;
    } else if (warnText != null) {
      color = AppColors.warningOrange(brightness);
      status = warnText;
      icon = Icons.cloud_done_outlined;
    } else if (ready == false) {
      color = AppColors.warningOrange(brightness);
      status = notReadyText;
      icon = Icons.error_outline;
    } else {
      color = AppColors.greyHint(brightness);
      status = unknownText ?? '未确认';
      icon = Icons.help_outline;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              '$label $status',
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w600),
            ),
            // 未就绪时给一个可点的暗示
            if (ready != true) ...[
              const SizedBox(width: 3),
              Icon(Icons.chevron_right, size: 13, color: color),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(MaimaiHubOcrItem item, double sw, Color c) {
    final brightness = Theme.of(context).brightness;
    final scheme = Theme.of(context).colorScheme;
    final best = item.bestCandidate;
    // 生效的歌曲 / 难度 / 成绩：玩家改过就用改后的，否则用 OCR 的原始结果
    final song = _songOf(item);
    final difficulty = _difficultyOf(item);
    final diffIndex = _difficultyIndexOf(difficulty);
    final achievement = _achievementOf(item);
    final dxScore = _dxScoreOf(item);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 顶部：难度 / 谱面类型 / 置信度 ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                _buildDifficultyBadge(item, brightness),
                if (item.isDx != null) ...[
                  const SizedBox(width: 6),
                  _buildChip(item.isDx! ? 'DX' : '标准', scheme.primary),
                ],
                const Spacer(),
                if (best != null)
                  _buildChip(
                    best.confidence == null
                        ? '置信度 —'
                        : '置信度 ${(best.confidence! * 100).toStringAsFixed(1)}%',
                    _confidenceColor(best.confidence, brightness),
                  ),
              ],
            ),
          ),

          // ── 曲名（左侧带曲绘 + 曲库基础信息）──────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 曲绘：只在能定位到歌曲时才有（否则宁可不显示）
                if (song != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CoverUtil.buildCoverWidget(song.id, 96),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (best != null)
                        Text(
                          _edits[item.index]?.titleOf(best.title) ?? best.title,
                          style: TextStyle(
                              color: c,
                              fontSize: sw * 0.052,
                              fontWeight: FontWeight.bold,
                              height: 1.2),
                        )
                      else
                        Text('未识别出曲名',
                            style: TextStyle(
                                color: AppColors.errorRed(brightness),
                                fontSize: sw * 0.042,
                                fontWeight: FontWeight.bold)),
                      // 曲师：曲库匹配到才有
                      if (song != null &&
                          song.basicInfo.artist.trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          song.basicInfo.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: c.withValues(alpha: 0.65),
                              fontSize: sw * 0.032),
                        ),
                      ],
                      // 版本 / 流派 / 等级 / 定数
                      if (song != null) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (song.basicInfo.from.trim().isNotEmpty)
                              _buildChip(
                                  // formatVersion2 把 API 里的完整版本名（如
                                  // "maimai でらっくす BUDDiES PLUS"）收成短名（"BUDDiES+"）
                                  StringUtil.formatVersion2(
                                      song.basicInfo.from),
                                  scheme.primary),
                            if (song.basicInfo.genre.trim().isNotEmpty)
                              _buildChip(song.basicInfo.genre, scheme.tertiary),
                            if (diffIndex != null &&
                                _levelAtIndex(song, diffIndex) != null)
                              _buildChip('等级 ${_levelAtIndex(song, diffIndex)}',
                                  scheme.secondary),
                            if (diffIndex != null &&
                                _dsAtIndex(song, diffIndex) != null)
                              _buildChip(
                                  '定数 ${_dsAtIndex(song, diffIndex)!.toStringAsFixed(1)}',
                                  scheme.secondary),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 命中来源（曲绘 / 标题）
          if (best != null && best.sources.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                '命中来源：${best.sources.map(_sourceLabel).join(' + ')}',
                style: TextStyle(
                    color: c.withValues(alpha: 0.5), fontSize: sw * 0.028),
              ),
            ),
          ],

          // ── 核心数字：达成率 + DX 分数（改了就用改后的值）──────────
          const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                    child: _buildHeroStat(
                  label: '达成率',
                  // 达成率是玩家最关心的数字，单独放大并按评级上色
                  value: achievement == null
                      ? '—'
                      : '${achievement.toStringAsFixed(4)}%',
                  grade: _achievementGrade(achievement),
                  color: achievement == null
                      ? c.withValues(alpha: 0.4)
                      : AppColors.ratingColorOnSurface(
                          _achievementGrade(achievement), brightness),
                  sw: sw,
                  c: c,
                )),
                Container(
                  width: 1,
                  height: sw * 0.11,
                  color: scheme.outlineVariant,
                ),
                Expanded(
                    child: _buildHeroStat(
                  label: 'DX 分数',
                  value: dxScore?.toString() ?? '—',
                  color: c,
                  sw: sw,
                  c: c,
                )),
              ],
            ),
          ),

          // ── 成就徽章：只在确实有数据时出现（改了就用改后的值）──────
          if (_fcBadge(_fcOf(item)) != null ||
              _fsBadge(_fsOf(item)) != null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  if (_fcBadge(_fcOf(item)) != null)
                    _buildAchievementBadge(_fcBadge(_fcOf(item))!, brightness),
                  if (_fcBadge(_fcOf(item)) != null &&
                      _fsBadge(_fsOf(item)) != null)
                    const SizedBox(width: 6),
                  if (_fsBadge(_fsOf(item)) != null)
                    _buildAchievementBadge(_fsBadge(_fsOf(item))!, brightness),
                ],
              ),
            ),
          ],

          // ── 操作区 ────────────────────────────────────────────
          //
          // 两行布局（按用户要求）：
          //   第一行：[编辑此项] [同步到水鱼] [同步到落雪]
          //   第二行：[水鱼 已登录] [落雪 已登录]
          //
          // 用 Wrap 而不是 Row：窄屏上三个按钮可能放不下，Wrap 会自动换行而
          // 不是溢出（Row 会直接抛 overflow）。状态行同理。
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showEditSheet(item),
                  icon: const Icon(Icons.edit_note, size: 18),
                  label: const Text('编辑此项'),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _canSync(item) && _uploadingIndex != item.index
                      ? () => _syncToDivingFish(item)
                      : null,
                  icon: _uploadingIndex == item.index
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload_outlined, size: 18),
                  label:
                      Text(_uploadingIndex == item.index ? '同步中...' : '同步到水鱼'),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
                OutlinedButton.icon(
                  // 落雪要数字曲目 id，且 id 体系与水鱼不同（服务层负责转换）。
                  // 与「同步到水鱼」共用 _canSync 的前置条件。
                  onPressed:
                      _canSync(item) && _uploadingLuoXueIndex != item.index
                          ? () => _syncToLuoXue(item)
                          : null,
                  icon: _uploadingLuoXueIndex == item.index
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_sync_outlined, size: 18),
                  label: Text(
                      _uploadingLuoXueIndex == item.index ? '同步中...' : '同步到落雪'),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          // ── 同步不可用的原因 ──────────────────────────────────
          //
          // 就贴在按钮下面：这两个按钮为什么会变灰，答案必须紧挨着它们，
          // 否则用户只会去怀疑账号状态（那里写着「已授权」）。
          if (item.isOk && _syncBlockReason(item) != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      size: sw * 0.032,
                      color: AppColors.warningOrange(brightness)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '暂不能同步：${_syncBlockReason(item)}',
                      style: TextStyle(
                        color: AppColors.warningOrange(brightness),
                        fontSize: sw * 0.028,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 账号状态另起一行，就贴在两个同步按钮下面。
          //
          // 放这里的用意：这两个按钮点下去会不会白点，取决于有没有登录；
          // 状态紧挨着按钮，用户读到「未登录」的同一眼就能看到该点哪儿。
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildAuthChip(
                  label: '水鱼',
                  // 三态：null=检查中 / false=未授权 / true=已授权
                  ready: _dfAuthorized,
                  readyText: '已授权',
                  notReadyText: '未授权',
                  unknownText: '检查中…',
                  onTap: () => _onAuthChipTap(isDivingFish: true),
                  sw: sw,
                ),
                _buildAuthChip(
                  label: '落雪',
                  // 「已设置密钥」只看**本机**有没有密钥 —— 本页走直传，
                  // 密钥只在 Hub 上是传不上去的。之前这里把 Hub 的布尔值
                  // 也算「已设置」，才会出现「界面说已设置、点同步说没设置」。
                  ready: _lxnsChecked ? _lxnsKeyLocal : null,
                  readyText: '已设置密钥',
                  notReadyText: '未设置密钥·点此粘贴',
                  warnText:
                      (_lxnsChecked && _lxnsKeyOnHub) ? '云端已绑定·本机缺密钥' : null,
                  unknownText: '检查中…',
                  onTap: () => _onAuthChipTap(isDivingFish: false),
                  sw: sw,
                ),
              ],
            ),
          ),

          // ── 其它候选 ──────────────────────────────────────────
          if (item.candidates.length > 1) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: scheme.outlineVariant),
                ),
              ),
              child: Text(
                '其它候选：${item.candidates.skip(1).map((x) => x.title).join(' · ')}',
                style: TextStyle(
                    color: c.withValues(alpha: 0.55),
                    fontSize: sw * 0.028,
                    height: 1.4),
              ),
            ),
          ] else
            const SizedBox(height: 14),

          // ── 失败原因 ──────────────────────────────────────────
          if (!item.isOk && item.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Text(item.error!,
                  style: TextStyle(
                      color: AppColors.errorRed(brightness),
                      fontSize: sw * 0.03)),
            ),
        ],
      ),
    );
  }

  /// 核心数字（达成率 / DX 分数）：大号数值 + 小号标签
  Widget _buildHeroStat({
    required String label,
    required String value,
    required Color color,
    required double sw,
    required Color c,
    String? grade,
  }) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: sw * 0.058,
                      fontWeight: FontWeight.bold,
                      height: 1.1)),
              if (grade != null) ...[
                const SizedBox(width: 6),
                Text(grade,
                    style: TextStyle(
                        color: color,
                        fontSize: sw * 0.032,
                        fontWeight: FontWeight.bold)),
              ],
            ],
          ),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(
                  color: c.withValues(alpha: 0.5), fontSize: sw * 0.026)),
        ],
      );

  /// 难度徽章（带难度配色，复用项目里 difficulty*ByIndex 的色板）
  Widget _buildDifficultyBadge(MaimaiHubOcrItem item, Brightness brightness) {
    // 用修正后的难度：玩家改了难度，徽章要跟着变
    final effective = _difficultyOf(item);
    final label = _difficultyLabel(effective);
    if (label == null) return const SizedBox.shrink();
    final index = _difficultyIndex(effective);
    // utage 不在 0-4 索引里，用中性色兜底
    final fg = index == null
        ? AppColors.greyHint(brightness)
        : AppColors.difficultyForegroundByIndex(index, brightness: brightness);
    final bg = index == null
        ? AppColors.greyHint(brightness).withValues(alpha: 0.15)
        : AppColors.difficultyBackgroundByIndex(index, brightness: brightness);
    // 等级优先取曲库里该难度的真实值（玩家换歌/换难度后 OCR 的 level 就不可信了）
    final idx = _difficultyIndexOf(effective);
    final song = _songOf(item);
    final level = (idx != null && song != null)
        ? (_levelAtIndex(song, idx) ?? item.level)
        : item.level;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        level == null ? label : '$label $level',
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  /// FC / FS 成就徽章（复用 achievement* 配色，和其它页面一致）
  Widget _buildAchievementBadge(String text, Brightness brightness) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.achievementBackground(text),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color:
                  AppColors.achievementForeground(text).withValues(alpha: 0.5),
              width: 0.8),
        ),
        child: Text(text,
            style: TextStyle(
                color: AppColors.achievementForeground(text),
                fontSize: 11,
                fontWeight: FontWeight.bold)),
      );

  Widget _buildChip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.55), width: 0.8),
        ),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      );

  String _sourceLabel(String source) {
    switch (source) {
      case 'cover':
        return '曲绘';
      case 'title':
        return '标题';
      default:
        return source;
    }
  }

  Color _confidenceColor(double? confidence, Brightness brightness) {
    if (confidence == null) return AppColors.greyHint(brightness);
    if (confidence >= 0.9) return AppColors.successGreen(brightness);
    if (confidence >= 0.7) return AppColors.warningOrange(brightness);
    return AppColors.errorRed(brightness);
  }

  /// 服务端 difficulty → 展示文案；未知值返回 null（不渲染徽章）
  String? _difficultyLabel(String? difficulty) {
    switch (difficulty) {
      case 'basic':
        return 'BASIC';
      case 'advanced':
        return 'ADVANCED';
      case 'expert':
        return 'EXPERT';
      case 'master':
        return 'MASTER';
      case 'remaster':
        return 'Re:MASTER';
      case 'utage':
        return '宴会场';
      default:
        return null;
    }
  }

  /// 服务端 difficulty → 难度色索引（0-4）。
  /// 宴会场不在这个体系里，返回 null 由调用方兜底。
  int? _difficultyIndex(String? difficulty) {
    switch (difficulty) {
      case 'basic':
        return 0;
      case 'advanced':
        return 1;
      case 'expert':
        return 2;
      case 'master':
        return 3;
      case 'remaster':
        return 4;
      default:
        return null;
    }
  }

  /// 达成率 → 评级文案（阈值沿用项目里 UserScoreSearchPage 的口径）。
  /// 传入 null 时返回 null。
  String? _achievementGrade(double? achievement) {
    if (achievement == null) return null;
    if (achievement >= 100.5) return 'SSS+';
    if (achievement >= 100.0) return 'SSS';
    if (achievement >= 99.5) return 'SS+';
    if (achievement >= 99.0) return 'SS';
    if (achievement >= 98.0) return 'S+';
    if (achievement >= 97.0) return 'S';
    if (achievement >= 94.0) return 'AAA';
    if (achievement >= 90.0) return 'AA';
    if (achievement >= 80.0) return 'A';
    if (achievement >= 75.0) return 'BBB';
    if (achievement >= 70.0) return 'BB';
    if (achievement >= 60.0) return 'B';
    if (achievement >= 50.0) return 'C';
    return 'D';
  }

  /// 连击标记徽章文案；无数据返回 null（不渲染徽章）
  String? _fcBadge(String? fc) {
    switch (fc) {
      case 'fc':
        return 'FC';
      case 'fcp':
        return 'FC+';
      case 'ap':
        return 'AP';
      case 'app':
        return 'AP+';
      default:
        return null;
    }
  }

  /// 同步标记徽章文案；无数据返回 null（不渲染徽章）。
  ///
  /// 值域统一成水鱼的写法（fs/fsp/fsd/fsdp/sync），显示直接用
  /// [StringUtil.formatFS]：fsd→FDX、fsdp→FDX+、sync→SC。
  String? _fsBadge(String? fs) {
    if (fs == null || fs.isEmpty) return null;
    const known = {'fs', 'fsp', 'fsd', 'fsdp', 'sync'};
    if (!known.contains(fs)) return null;
    return StringUtil.formatFS(fs);
  }

  Widget _buildActionButtons(double sw, Color c) {
    final hasPhoto = _photoPath != null;
    final hasResult = _result != null;
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: _showSourcePicker,
          icon: const Icon(Icons.add_a_photo),
          label: Text(hasPhoto ? '换一张' : '选择图片'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
        if (hasPhoto && !hasResult)
          ElevatedButton.icon(
            onPressed: _isRecognizing ? null : _recognize,
            icon: const Icon(Icons.document_scanner),
            label: const Text('开始识别'),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  AppColors.successGreen(Theme.of(context).brightness),
              foregroundColor: Colors.white,
            ),
          ),
        if (hasResult)
          ElevatedButton.icon(
            onPressed: _recognize,
            icon: const Icon(Icons.refresh),
            label: const Text('再次识别'),
          ),
        if (hasPhoto || hasResult)
          OutlinedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.refresh),
            label: const Text('清除重选'),
          ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────
// 落雪密钥粘贴对话框
//
// 为什么单独抽出来做一个 StatefulWidget：TextEditingController 必须在
// TextField 卸载**之后**才能 dispose，否则退出动画跑的时候 TextField 还在
// 监听，强行 dispose 会触发 framework.dart 的 `_dependents.isEmpty` 断言。
// 把 controller 放进自己的 State、让它在 dispose() 里自释放，时机就由
// 框架兜底，不用手动 `addPostFrameCallback` 赌一帧。
// ────────────────────────────────────────────────────────

/// 「粘贴落雪密钥」对话框。
class _LxnsKeyPromptDialog extends StatefulWidget {
  /// Hub 已绑定但本机没有密钥时为 true，对话框里额外给一行橙色说明
  /// 「本机读不到密钥，同步仍不可用」。
  final bool cloudOnlyHint;
  const _LxnsKeyPromptDialog({required this.cloudOnlyHint});

  @override
  State<_LxnsKeyPromptDialog> createState() => _LxnsKeyPromptDialogState();
}

class _LxnsKeyPromptDialogState extends State<_LxnsKeyPromptDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openLxnsProfilePage() async {
    final uri = Uri.parse('https://maimai.lxns.net/user/profile?tab=thirdparty');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        launchUrlFallback(uri.toString(), context);
      }
    } catch (e) {
      debugPrint('[ScoreOcr] 打开落雪绑定页失败：$e');
      if (mounted) launchUrlFallback(uri.toString(), context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.vpn_key_outlined, size: 22),
          SizedBox(width: 8),
          Text('落雪个人 API 密钥'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '同步成绩需要密钥存在本机。到「落雪咖啡屋 → 账号详情 → 个人 API 密钥」'
              '生成后，粘贴到这里：',
              style: TextStyle(
                  fontSize: 13, color: AppColors.greyHint(brightness)),
            ),
            if (widget.cloudOnlyHint) ...[
              const SizedBox(height: 10),
              Text(
                '云端已绑定过密钥，但本机读不到它，所以同步仍不可用 —— 请在这里再粘一次。',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.warningOrange(brightness),
                    height: 1.35),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.paste, size: 16),
              label: const Text('读取剪贴板', style: TextStyle(fontSize: 13)),
              onPressed: () async {
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                final t = (data?.text ?? '').trim();
                if (t.isEmpty) {
                  Fluttertoast.showToast(msg: '剪贴板为空');
                  return;
                }
                _controller.text = t;
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '粘在此处（形如 KVV1nwdHG5LWl6Gm-5TNq...）',
                hintStyle: TextStyle(
                    fontSize: 13,
                    color: AppColors.greyHint(brightness, shade: 400)),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: _openLxnsProfilePage,
          child: const Text('去落雪生成'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('保存'),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────
// 内嵌的精简版裁剪页（与 CoverRecognitionPage 的 _ImageCropPage 同等行为，
// 但保持本页独立，不改动 CoverRecognitionPage）
// ────────────────────────────────────────────────────────

enum _OcrCropHandle { none, body, topLeft, topRight, bottomLeft, bottomRight }

class _OcrImageCropPage extends StatefulWidget {
  final String imagePath;
  const _OcrImageCropPage({required this.imagePath});

  @override
  State<_OcrImageCropPage> createState() => _OcrImageCropPageState();
}

class _OcrImageCropPageState extends State<_OcrImageCropPage> {
  ui.Image? _image;
  bool _loading = true;
  Rect _imageRect = Rect.zero;
  Rect _cropRect = Rect.zero;
  _OcrCropHandle _activeHandle = _OcrCropHandle.none;
  Offset? _dragStart;
  Rect? _cropRectStart;

  final double _handleSize = 24;
  final double _minCropSize = 50;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final bytes = await File(widget.imagePath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (mounted) {
      setState(() {
        _image = frame.image;
        _loading = false;
      });
    }
  }

  Rect _calcImageRect(Size container) {
    if (_image == null) return Rect.zero;
    final iw = _image!.width.toDouble();
    final ih = _image!.height.toDouble();
    final scale = (container.width / iw) < (container.height / ih)
        ? container.width / iw
        : container.height / ih;
    final dw = iw * scale;
    final dh = ih * scale;
    final dx = (container.width - dw) / 2;
    final dy = (container.height - dh) / 2;
    return Rect.fromLTWH(dx, dy, dw, dh);
  }

  void _initCropRect() {
    final size = math.min(_imageRect.width, _imageRect.height) * 0.7;
    setState(() {
      _cropRect = Rect.fromLTWH(
        _imageRect.left + (_imageRect.width - size) / 2,
        _imageRect.top + (_imageRect.height - size) / 2,
        size,
        size,
      );
    });
  }

  MouseCursor _cursorForHandle(_OcrCropHandle h) => switch (h) {
        _OcrCropHandle.topLeft ||
        _OcrCropHandle.bottomRight =>
          SystemMouseCursors.resizeUpLeftDownRight,
        _OcrCropHandle.topRight ||
        _OcrCropHandle.bottomLeft =>
          SystemMouseCursors.resizeUpRightDownLeft,
        _OcrCropHandle.body => SystemMouseCursors.move,
        _ => SystemMouseCursors.basic,
      };

  _OcrCropHandle _hitTest(Offset p) {
    const r = 20.0;
    if ((p - _cropRect.topLeft).distance < r) return _OcrCropHandle.topLeft;
    if ((p - _cropRect.topRight).distance < r) return _OcrCropHandle.topRight;
    if ((p - _cropRect.bottomLeft).distance < r) {
      return _OcrCropHandle.bottomLeft;
    }
    if ((p - _cropRect.bottomRight).distance < r) {
      return _OcrCropHandle.bottomRight;
    }
    if (_cropRect.contains(p)) return _OcrCropHandle.body;
    return _OcrCropHandle.none;
  }

  void _onPanStart(DragStartDetails d) {
    _activeHandle = _hitTest(d.localPosition);
    _dragStart = d.localPosition;
    _cropRectStart = _cropRect;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_activeHandle == _OcrCropHandle.none ||
        _cropRectStart == null ||
        _dragStart == null) {
      return;
    }
    final delta = d.localPosition - _dragStart!;
    final r = _cropRectStart!;
    Rect newRect;
    switch (_activeHandle) {
      case _OcrCropHandle.body:
        var dx = r.left + delta.dx;
        var dy = r.top + delta.dy;
        if (dx < _imageRect.left) dx = _imageRect.left;
        if (dy < _imageRect.top) dy = _imageRect.top;
        if (dx + r.width > _imageRect.right) dx = _imageRect.right - r.width;
        if (dy + r.height > _imageRect.bottom) {
          dy = _imageRect.bottom - r.height;
        }
        newRect = Rect.fromLTWH(dx, dy, r.width, r.height);
      case _OcrCropHandle.topLeft:
        final maxDelta =
            math.max(r.width - delta.dx, r.height - delta.dy).toDouble();
        final size = maxDelta.clamp(
            _minCropSize,
            math
                .min(r.right - _imageRect.left, r.bottom - _imageRect.top)
                .toDouble());
        newRect = Rect.fromLTWH(
          (r.right - size)
              .clamp(_imageRect.left, _imageRect.right - _minCropSize),
          (r.bottom - size)
              .clamp(_imageRect.top, _imageRect.bottom - _minCropSize),
          size,
          size,
        );
      case _OcrCropHandle.topRight:
        final maxDelta =
            math.max(r.width + delta.dx, r.height - delta.dy).toDouble();
        final size = maxDelta.clamp(
            _minCropSize,
            math
                .min(_imageRect.right - r.left, r.bottom - _imageRect.top)
                .toDouble());
        newRect = Rect.fromLTWH(
          r.left.clamp(_imageRect.left, _imageRect.right - _minCropSize),
          (r.bottom - size)
              .clamp(_imageRect.top, _imageRect.bottom - _minCropSize),
          size,
          size,
        );
      case _OcrCropHandle.bottomLeft:
        final maxDelta =
            math.max(r.width - delta.dx, r.height + delta.dy).toDouble();
        final size = maxDelta.clamp(
            _minCropSize,
            math
                .min(r.right - _imageRect.left, _imageRect.bottom - r.top)
                .toDouble());
        newRect = Rect.fromLTWH(
          (r.right - size)
              .clamp(_imageRect.left, _imageRect.right - _minCropSize),
          r.top.clamp(_imageRect.top, _imageRect.bottom - _minCropSize),
          size,
          size,
        );
      case _OcrCropHandle.bottomRight:
        final maxDelta =
            math.max(r.width + delta.dx, r.height + delta.dy).toDouble();
        final size = maxDelta.clamp(
            _minCropSize,
            math
                .min(_imageRect.right - r.left, _imageRect.bottom - r.top)
                .toDouble());
        newRect = Rect.fromLTWH(
          r.left.clamp(_imageRect.left, _imageRect.right - _minCropSize),
          r.top.clamp(_imageRect.top, _imageRect.bottom - _minCropSize),
          size,
          size,
        );
      case _OcrCropHandle.none:
        return;
    }
    setState(() => _cropRect = newRect);
  }

  void _onPanEnd(DragEndDetails d) {
    _activeHandle = _OcrCropHandle.none;
    _dragStart = null;
    _cropRectStart = null;
  }

  Future<String?> _doCrop() async {
    if (_image == null) return widget.imagePath;
    final scaleX = _image!.width / _imageRect.width;
    final scaleY = _image!.height / _imageRect.height;
    final x = ((_cropRect.left - _imageRect.left) * scaleX)
        .round()
        .clamp(0, _image!.width);
    final y = ((_cropRect.top - _imageRect.top) * scaleY)
        .round()
        .clamp(0, _image!.height);
    final w = (_cropRect.width * scaleX).round().clamp(1, _image!.width - x);
    final h = (_cropRect.height * scaleY).round().clamp(1, _image!.height - y);
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return widget.imagePath;
      final cropped = img.copyCrop(decoded, x: x, y: y, width: w, height: h);
      final outPath =
          '${Directory.systemTemp.path}/ocr_crop_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(outPath).writeAsBytes(img.encodeJpg(cropped, quality: 92));
      return outPath;
    } catch (e) {
      debugPrint('OCR 裁剪出错: $e');
      return widget.imagePath;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _image == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: kToolbarHeight,
              color: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon:
                        const Icon(Icons.close, color: Colors.white, size: 20),
                    label:
                        const Text('取消', style: TextStyle(color: Colors.white)),
                  ),
                  const Spacer(),
                  const Text('拖动角点框选成绩区域',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      final out = await _doCrop();
                      if (mounted) navigator.pop(out);
                    },
                    icon:
                        const Icon(Icons.check, color: Colors.green, size: 20),
                    label: const Text('确认',
                        style: TextStyle(
                            color: Colors.green, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(builder: (ctx, c) {
                final actualSize = Size(c.maxWidth, c.maxHeight);
                _imageRect = _calcImageRect(actualSize);
                if (_cropRect.isEmpty || _cropRect == Rect.zero) {
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _initCropRect());
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }
                return GestureDetector(
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: MouseRegion(
                    cursor: _activeHandle != _OcrCropHandle.none
                        ? _cursorForHandle(_activeHandle)
                        : SystemMouseCursors.basic,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: RawImage(image: _image, fit: BoxFit.contain),
                        ),
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _OcrCropOverlayPainter(
                              imageRect: _imageRect,
                              cropRect: _cropRect,
                              handleSize: _handleSize,
                              handleBorderColor:
                                  Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
            Container(
              height: 48,
              color: Colors.black87,
              alignment: Alignment.center,
              child: Text(
                '拖拽四角调整范围  |  拖拽框内移动位置',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OcrCropOverlayPainter extends CustomPainter {
  final Rect imageRect;
  final Rect cropRect;
  final double handleSize;
  final Color handleBorderColor;
  _OcrCropOverlayPainter({
    required this.imageRect,
    required this.cropRect,
    required this.handleSize,
    required this.handleBorderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final mask = Paint()..color = Colors.black.withValues(alpha: 0.55);
    canvas.drawRect(
        Rect.fromLTRB(
            imageRect.left, imageRect.top, imageRect.right, cropRect.top),
        mask);
    canvas.drawRect(
        Rect.fromLTRB(
            imageRect.left, cropRect.bottom, imageRect.right, imageRect.bottom),
        mask);
    canvas.drawRect(
        Rect.fromLTRB(
            imageRect.left, cropRect.top, cropRect.left, cropRect.bottom),
        mask);
    canvas.drawRect(
        Rect.fromLTRB(
            cropRect.right, cropRect.top, imageRect.right, cropRect.bottom),
        mask);

    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(cropRect, border);

    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    final thirdW = cropRect.width / 3;
    final thirdH = cropRect.height / 3;
    for (int i = 1; i < 3; i++) {
      canvas.drawLine(Offset(cropRect.left + thirdW * i, cropRect.top),
          Offset(cropRect.left + thirdW * i, cropRect.bottom), grid);
      canvas.drawLine(Offset(cropRect.left, cropRect.top + thirdH * i),
          Offset(cropRect.right, cropRect.top + thirdH * i), grid);
    }

    final handle = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final handleBorder = Paint()
      ..color = handleBorderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final corner in [
      cropRect.topLeft,
      cropRect.topRight,
      cropRect.bottomLeft,
      cropRect.bottomRight,
    ]) {
      final r = Rect.fromCenter(
          center: corner, width: handleSize, height: handleSize);
      canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(4)), handle);
      canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(4)), handleBorder);
    }
  }

  @override
  bool shouldRepaint(covariant _OcrCropOverlayPainter old) =>
      cropRect != old.cropRect || imageRect != old.imageRect;
}
