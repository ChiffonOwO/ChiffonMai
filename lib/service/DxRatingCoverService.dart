import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import '../entity/DXRating/DXDataEntity.dart';
import '../manager/DXDataManager.dart';

/// 一份索引（`基础 songId → imageName`）及其生成时间。
typedef CoverIndexSource = ({Map<String, String> index, DateTime? at});

/// 曲绘的**最后一道网络兜底**：dxrating（shama）曲绘图。
///
/// 由来：dxdata（`https://miruku.dxrating.net/api/v1/dxdata`）里每首歌都有一个
/// `imageName`（64 位十六进制），拿它去请求
/// `https://shama.dxrating.net/images/cover/v2/<imageName>.jpg` 就能拿到曲绘。
/// 实测（1769 首歌的 dxdata 与水鱼 1394 首交叉验证，见
/// `tool/probe_dxrating_cover_test.dart`）：
///   * 映射命中 **99.8%**（1391/1394），曲名一致 1389 —— 命中即能出图；
///   * 响应是 `image/jpeg`，单张只有 **14~32 KB**（diving-fish 的 PNG 是 240~300 KB），
///     约 300~950ms，响应头带 `cache-control: public, max-age=31356000, immutable`；
///   * 还能救回 diving-fish 拿不到的歌：水鱼的 DX 条目 id 是 `10000 + 基础 id`
///     （如 `10030`），`https://www.diving-fish.com/covers/10030.png` 是 **404**，
///     而 dxrating 这条路能出图。
///
/// **缓存与减压**（重要，dxdata 实测 4MB / 下载 200s+）：
///   1. **随包基线**：`assets/dxrating_cover_index.json`（121 KB / 1677 条，
///      由 `tool/gen_dxrating_cover_index.cjs` 在构建期生成）。首次启动即可用，
///      不联网、不占服务器；
///   2. **本地更新**：运行时若基线过期，尽力更新一次并落盘（`dxrating_cover_index_v1.json`），
///      之后优先用这份更新的；
///   3. 两份索引都在 [cacheTtl] 内时**完全不联网**；
///   4. 曲绘图走 `dxRatingCoverCacheManager`（独立磁盘缓存，30 天 / 1000 张）；
///   5. 索引里查不到的 songId **不构造 URL**（返回 null），
///      避免拿注定 404 的地址去敲服务器。
class DxRatingCoverService {
  DxRatingCoverService._();

  static final DxRatingCoverService instance = DxRatingCoverService._();

  /// 曲绘图基址。
  static const String baseUrl = 'https://shama.dxrating.net/images/cover/v2';

  /// 随包基线索引（构建期由 dxdata 生成）。
  static const String bundledAssetPath = 'assets/dxrating_cover_index.json';

  /// 索引文件 / 结构的版本号（结构变了就 +1，旧文件会被忽略并重建）。
  static const int cacheVersion = 1;

  /// 索引有效期：两份索引都超过它就尝试更新一次。
  static const Duration cacheTtl = Duration(days: 7);

  /// 内存索引：基础 songId → imageName。
  Map<String, String> _index = const {};
  bool _indexLoaded = false;

  /// 索引已就绪、且本次会话不需要再更新。
  bool _satisfied = false;

  /// 单飞：并发调用只跑一次加载。
  Future<void>? _loading;

  /// 本次会话是否已经尝试过更新索引（失败也不反复重试）。
  bool _networkAttempted = false;

  /// 索引是否已就绪（就绪后 [imageNameFor] 才能同步命中）。
  bool get isLoaded => _indexLoaded;

  /// 索引条数（调试 / 测试用）。
  int get indexSize => _index.length;

  // ===========================================================================
  // 查询
  // ===========================================================================

  /// songId → imageName；索引未就绪或没这首歌时返回 null。
  ///
  /// 水鱼的 DX 条目 id 是 `10000 + 基础 id`，dxdata 里同一首歌的 std/dx 谱面
  /// internalId 也可能是两者之一，所以查询与建索引都先归一化到基础 id。
  String? imageNameFor(String songId) {
    if (!_indexLoaded) return null;
    return _index[normalizeSongId(songId)];
  }

  /// songId → dxrating 曲绘 URL；没有映射时返回 null（**不要**拿 null 去请求）。
  String? coverUrlFor(String songId) {
    final imageName = imageNameFor(songId);
    if (imageName == null || imageName.isEmpty) return null;
    return '$baseUrl/$imageName.jpg';
  }

  /// 把 songId 归一化成基础 id。
  ///
  /// dxdata 里 DX 谱面的 `internalId` = `10000 + 基础 id`（实测：君の知らない物語
  /// std=181 / dx=10181），水鱼的 DX 条目同理（`11663`「系ぎて」的基础 id 是 1663），
  /// 所以 `10000~19999` 一律减 10000。6 位（宴会场，100000+）与普通 id 原样。
  ///
  /// 这条规则与 `CoverUtil.getLocalCoverPath` 对 5 位 id 的「去掉开头的 1 和
  /// 连续的 0」等价（整数减法天然去掉前导零），两套 id 口径必须一致，
  /// `test/dxrating_cover_test.dart` 钉住了这一点。
  static String normalizeSongId(String songId) {
    final trimmed = songId.trim();
    final n = int.tryParse(trimmed);
    if (n == null) return trimmed;
    if (n >= 10000 && n < 20000) return '${n - 10000}';
    return '$n';
  }

  // ===========================================================================
  // 索引构建
  // ===========================================================================

  /// 从 dxdata 构建 `基础 songId → imageName`。
  ///
  /// 一首歌的每个谱面都带 internalId，归一化后都指向同一个 imageName
  /// （曲绘是按歌的，不按难度）。
  static Map<String, String> buildIndex(DXDataEntity data) {
    final index = <String, String>{};
    for (final song in data.songs) {
      final imageName = song.imageName;
      if (imageName.isEmpty) continue;
      for (final sheet in song.sheets) {
        if (sheet.internalId <= 0) continue;
        index.putIfAbsent(normalizeSongId('${sheet.internalId}'), () => imageName);
      }
    }
    return index;
  }

  // ===========================================================================
  // 加载（随包基线 / 本地更新优先，尽量不联网）
  // ===========================================================================

  /// 确保索引可用。重复调用安全（单飞）。
  ///
  /// [allowNetwork] = false 时只读基线 + 本地缓存，不联网。
  Future<void> ensureLoaded({bool allowNetwork = true}) {
    if (_satisfied) return Future.value();
    if (!allowNetwork && _indexLoaded) return Future.value();
    return _loading ??= _load(allowNetwork: allowNetwork).whenComplete(() {
      _loading = null;
    });
  }

  Future<void> _load({required bool allowNetwork}) async {
    final cached = await _readLocalIndex(); // 用户机器上更新过的
    final bundled = await _readBundledIndex(); // 随包基线
    final choice = chooseIndex(
      cached: cached,
      bundled: bundled,
      now: DateTime.now(),
      ttl: debugCacheTtlOverride ?? cacheTtl,
    );

    final picked = choice.picked;
    if (picked != null) {
      _index = picked.index;
      _indexLoaded = true;
    }

    // 还在有效期内 → 直接用，完全不联网
    if (!choice.needsUpdate) {
      _satisfied = true;
      debugPrint('[DxCover] 索引就绪：${_index.length} 条'
          '（${choice.useCached ? '本地更新' : '随包基线'}）');
      return;
    }

    // 过期 / 两份都没有 → 一个会话一次的机会去更新
    if (!allowNetwork || _networkAttempted) return;
    _networkAttempted = true;
    try {
      final loader = debugDxDataLoader;
      final data =
          loader != null ? await loader() : await DXDataManager().load();
      if (data == null) {
        debugPrint('[DxCover] dxdata 拉取失败，继续用现有索引（${_index.length} 条）');
        return;
      }
      final fresh = buildIndex(data);
      if (fresh.isEmpty) {
        debugPrint('[DxCover] dxdata 没有可用的 imageName，保留现有索引');
        return;
      }
      _index = fresh;
      _indexLoaded = true;
      _satisfied = true;
      await _writeLocalIndex(fresh);
      debugPrint('[DxCover] 索引已更新：${fresh.length} 条');
    } catch (e) {
      debugPrint('[DxCover] 索引更新失败（忽略）: $e');
    }
  }

  /// 在「随包基线」与「本地更新」之间挑一份，并判断是否需要联网更新。
  ///
  /// 规则（`test/dxrating_cover_test.dart` 直接测这个纯函数）：
  ///   * 两份都有 → 用生成时间较新的那份（本地更新没写时间时优先本地）；
  ///   * 只有一份 → 用它；
  ///   * 两者都没有、或选中的那份超过 [ttl] → 需要联网更新。
  @visibleForTesting
  static ({CoverIndexSource? picked, bool useCached, bool needsUpdate})
      chooseIndex({
    required CoverIndexSource? cached,
    required CoverIndexSource? bundled,
    required DateTime now,
    Duration ttl = cacheTtl,
  }) {
    final useCached = cached != null &&
        (bundled == null ||
            bundled.at == null ||
            (cached.at != null && !bundled.at!.isAfter(cached.at!)));
    final picked = useCached ? cached : bundled;
    final at = picked?.at;
    final needsUpdate = at == null || now.difference(at) > ttl;
    return (picked: picked, useCached: useCached, needsUpdate: needsUpdate);
  }

  // ===========================================================================
  // 索引文件
  // ===========================================================================

  /// 仅供测试：替换本地索引目录（默认 `getApplicationDocumentsDirectory()`）。
  @visibleForTesting
  static Directory? debugCacheDirOverride;

  /// 仅供测试：替换 dxdata 拉取实现，用来断言「没有联网」。
  @visibleForTesting
  static Future<DXDataEntity?> Function()? debugDxDataLoader;

  /// 仅供测试：覆盖索引有效期（默认 [cacheTtl]）。
  ///
  /// 随包基线是构建期生成的、通常很新，所以「需要更新」的分支只有把有效期
  /// 调成 0 才测得到。
  @visibleForTesting
  static Duration? debugCacheTtlOverride;

  /// 本地更新索引的文件（不在版本库里，也不进备份）。
  static Future<File> cacheFile() async {
    final dir = debugCacheDirOverride ?? await getApplicationDocumentsDirectory();
    return File('${dir.path}/dxrating_cover_index_v$cacheVersion.json');
  }

  /// 解析索引 JSON（随包基线与本地更新的格式一致）。
  ///
  /// 基线用 `generatedAt`、本地更新用 `savedAt`，两个都认。
  static CoverIndexSource? parseIndexJson(String text) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map || decoded['v'] != cacheVersion) return null;
      final raw = decoded['images'];
      if (raw is! Map) return null;
      final index = <String, String>{
        for (final entry in raw.entries)
          if (entry.value is String) '${entry.key}': entry.value as String,
      };
      if (index.isEmpty) return null;
      final atMs = ((decoded['savedAt'] ?? decoded['generatedAt']) is num)
          ? ((decoded['savedAt'] ?? decoded['generatedAt']) as num).toInt()
          : null;
      final atText = decoded['generatedAt'];
      final at = atMs != null
          ? DateTime.fromMillisecondsSinceEpoch(atMs)
          : (atText is String ? DateTime.tryParse(atText) : null);
      return (index: index, at: at);
    } catch (e) {
      debugPrint('[DxCover] 解析索引失败（忽略）: $e');
      return null;
    }
  }

  Future<CoverIndexSource?> _readLocalIndex() async {
    try {
      final file = await cacheFile();
      if (!await file.exists()) return null;
      return parseIndexJson(await file.readAsString());
    } catch (e) {
      debugPrint('[DxCover] 读取本地索引失败（忽略）: $e');
      return null;
    }
  }

  Future<void> _writeLocalIndex(Map<String, String> index) async {
    try {
      final file = await cacheFile();
      await file.writeAsString(jsonEncode({
        'v': cacheVersion,
        'savedAt': DateTime.now().millisecondsSinceEpoch,
        'count': index.length,
        'images': index,
      }));
    } catch (e) {
      debugPrint('[DxCover] 写入本地索引失败（忽略）: $e');
    }
  }

  Future<CoverIndexSource?> _readBundledIndex() async {
    try {
      return parseIndexJson(await rootBundle.loadString(bundledAssetPath));
    } catch (e) {
      debugPrint('[DxCover] 读取随包基线索引失败（忽略）: $e');
      return null;
    }
  }

  // ===========================================================================
  // 测试辅助
  // ===========================================================================

  /// 仅供测试：直接注入索引。
  @visibleForTesting
  void debugSetIndex(Map<String, String> index) {
    _index = Map.unmodifiable(index);
    _indexLoaded = true;
    _satisfied = true;
  }

  /// 仅供测试：复位内存状态（不动磁盘缓存，也不动随包基线）。
  @visibleForTesting
  void debugResetForTest() {
    _index = const {};
    _indexLoaded = false;
    _satisfied = false;
    _loading = null;
    _networkAttempted = false;
    debugCacheDirOverride = null;
    debugDxDataLoader = null;
    debugCacheTtlOverride = null;
  }
}
