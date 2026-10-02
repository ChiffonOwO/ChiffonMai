import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/ApiUrls.dart';
import '../constant/CacheKeyConstant.dart';
import '../constant/CacheTimestampConstant.dart';
import 'package:jp_transliterate/jp_transliterate.dart';
import 'package:my_first_flutter_app/utils/ApiClient.dart';

class MaidataManager {
  static final MaidataManager _instance = MaidataManager._internal();
  factory MaidataManager() => _instance;
  MaidataManager._internal();

  String _cleanMaidataContent(String content) {
    String result = content.replaceAll(RegExp(r'\[DX\]'), '');
    result = result.replaceAll(RegExp(r'\[SD\]'), '');
    result = result.replaceAll(RegExp(r'\[宴\]'), '');
    result = result.replaceAll(r'$', '');
    return result;
  }

  /// 解码响应体为字符串。优先 UTF-8（覆盖绝大多数 maidata），
  /// 失败时回退到 Shift-JIS。使用原生 String.contains 替代逐字符遍历，
  /// 在全量刷新（1000+ 文件）时可节省数秒 CPU 时间。
  String _decodeContent(List<int> bytes) {
    // 快速路径：尝试 UTF-8（allowMalformed 不会抛异常）
    final utf8Result = utf8.decode(bytes, allowMalformed: true);
    // 仅检查替换字符 U+FFFD，这是编码失败的可靠信号
    if (!utf8Result.contains('�')) {
      return utf8Result;
    }

    // UTF-8 出现替换字符，尝试 Shift-JIS
    try {
      final shiftJisResult = _decodeShiftJis(bytes);
      if (shiftJisResult.isNotEmpty && !shiftJisResult.contains('�')) {
        return shiftJisResult;
      }
    } catch (_) {}

    // 回退到 UTF-8 最佳努力结果
    return utf8Result;
  }

  String _decodeShiftJis(List<int> bytes) {
    StringBuffer result = StringBuffer();
    int i = 0;
    while (i < bytes.length) {
      int byte1 = bytes[i] & 0xFF;

      if (byte1 < 0x80) {
        result.writeCharCode(byte1);
        i++;
      } else if (byte1 >= 0x81 && byte1 <= 0x9F) {
        if (i + 1 < bytes.length) {
          int byte2 = bytes[i + 1] & 0xFF;
          int code = _shiftJisToUnicode(byte1, byte2);
          if (code != 0) {
            result.writeCharCode(code);
          }
          i += 2;
        } else {
          result.writeCharCode(byte1);
          i++;
        }
      } else if (byte1 >= 0xE0 && byte1 <= 0xFC) {
        if (i + 1 < bytes.length) {
          int byte2 = bytes[i + 1] & 0xFF;
          int code = _shiftJisToUnicode(byte1, byte2);
          if (code != 0) {
            result.writeCharCode(code);
          }
          i += 2;
        } else {
          result.writeCharCode(byte1);
          i++;
        }
      } else {
        result.writeCharCode(byte1);
        i++;
      }
    }
    return result.toString();
  }

  int _shiftJisToUnicode(int byte1, int byte2) {
    int offset;
    if (byte1 >= 0x81 && byte1 <= 0x9F) {
      offset = ((byte1 - 0x81) * 0x100);
    } else if (byte1 >= 0xE0 && byte1 <= 0xFC) {
      offset = ((byte1 - 0xC1) * 0x100);
    } else {
      return 0;
    }

    int sjis = offset + byte2;

    if (sjis >= 0x8140 && sjis <= 0x889E) {
      return 0x4E00 +
          (((sjis - 0x8140) ~/ 0x40) * 0x9F) +
          ((sjis - 0x8140) % 0x40) -
          (((sjis - 0x8140) ~/ 0x40) > 7 ? 1 : 0);
    }

    if (sjis >= 0x889F && sjis <= 0x9FFC) {
      return 0x4E00 +
          (((sjis - 0x889F) ~/ 0x40) * 0x9F) +
          ((sjis - 0x889F) % 0x40) +
          0x7D;
    }

    if (sjis >= 0xE040 && sjis <= 0xEAA4) {
      return 0xF900 + (sjis - 0xE040);
    }

    return 0;
  }

  Map<String, String> _cachedMaidata = {};
  Map<String, dynamic>? _indexData;
  bool _isInitialized = false;

  /// songId → URL 映射缓存，避免增量刷新时重新抓取目录列表
  Map<String, String> _idToUrlMap = {};

  /// 单曲 maidata 内存兜底：本地全量/单曲缓存都没命中时，从
  /// [ApiUrls.wmcMaidataUrl] 拉一份回来塞这里。
  /// **只在内存**——进程死掉即丢；用户可以在系统中心「maidata 管理」里清空。
  /// 原因：单首曲子的兜底来源不在自家服务器上，长期落盘可能会跟上游漂移，
  /// 下次启动重新按需拉一次更稳。
  final Map<String, String> _wmcFallbackCache = {};

  /// 全量缓存文件路径（应用私有目录，不占 SharedPreferences 的 XML 空间）
  Future<File> _getCacheFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/maidata_full_cache.json');
  }

  /// URL 映射缓存文件
  Future<File> _getUrlMapFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/maidata_url_map.json');
  }

  /// 加载 songId→URL 映射（如果存在）
  Future<void> _loadUrlMap() async {
    try {
      final file = await _getUrlMapFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        _idToUrlMap = await compute((String jsonStr) {
          return Map<String, String>.from(json.decode(jsonStr) as Map);
        }, content);
      }
    } catch (e) {
      debugPrint('[DEBUG][MaidataManager] 加载URL映射失败: $e');
      _idToUrlMap = {};
    }
  }

  /// 保存 songId→URL 映射
  Future<void> _saveUrlMap() async {
    try {
      final file = await _getUrlMapFile();
      await file.writeAsString(json.encode(_idToUrlMap));
    } catch (e) {
      debugPrint('[DEBUG][MaidataManager] 保存URL映射失败: $e');
    }
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    await Future.wait([
      _loadFromCache(),
      _loadUrlMap(),
    ]);
    _isInitialized = true;
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp =
          prefs.getInt(CacheKeyConstant.maidataFullCacheTimestamp);

      if (timestamp != null) {
        final now = DateTime.now().millisecondsSinceEpoch;

        if (now - timestamp < CacheTimestampConstant.maidataFullCacheMillis) {
          final file = await _getCacheFile();
          if (await file.exists()) {
            // 文件 I/O + JSON 解码在后台 isolate 中执行，避免阻塞 UI 线程
            final content = await file.readAsString();
            _cachedMaidata = await compute((String jsonStr) {
              return Map<String, String>.from(json.decode(jsonStr) as Map);
            }, content);
            debugPrint(
                '[DEBUG][MaidataManager] 已加载全量缓存（文件），共 ${_cachedMaidata.length} 首歌曲');
            return;
          }
        } else {
          debugPrint('[DEBUG][MaidataManager] 全量缓存已过期，删除旧缓存');
          await prefs.remove(CacheKeyConstant.maidataFullCacheTimestamp);
          final file = await _getCacheFile();
          if (await file.exists()) {
            await file.delete();
          }
        }
      }

      // 兼容旧版：尝试从 SharedPreferences 迁移旧数据
      final legacyData = prefs.getString(CacheKeyConstant.maidataFullCache);
      if (legacyData != null) {
        debugPrint(
            '[DEBUG][MaidataManager] 检测到旧版 SharedPreferences 缓存，正在迁移到文件...');
        _cachedMaidata = await compute((String jsonStr) {
          return Map<String, String>.from(json.decode(jsonStr) as Map);
        }, legacyData);
        // 异步写入文件并清理旧数据
        final file = await _getCacheFile();
        await file.writeAsString(legacyData);
        await prefs.setInt(CacheKeyConstant.maidataFullCacheTimestamp,
            DateTime.now().millisecondsSinceEpoch);
        await prefs.remove(CacheKeyConstant.maidataFullCache);
        debugPrint(
            '[DEBUG][MaidataManager] 旧缓存已迁移到文件，共 ${_cachedMaidata.length} 首歌曲');
        return;
      }
    } catch (e) {
      debugPrint('[DEBUG][MaidataManager] 加载缓存失败: $e');
    }
  }

  /// 全量拉取 maidata 并落盘。
  ///
  /// [onProgress] 分两个阶段：
  ///   * 阶段 1（发现）：7 个流派的文件夹列表并行返回，此时总数还不存在，
  ///     逐个流派上报「已发现数」且 `total` 为 0。板块目录本身要好几秒，
  ///     不做这一档的话按钮上会一直空着，看起来像没点动。
  ///   * 阶段 2（下载）：总数已确定，按「已下载 / 总数」上报。
  ///
  /// 文件数上千、`concurrency` 又是 100，按每批结束上报即可，不必逐文件回调，
  /// 再叠一层 250ms 节流，避免高频 `setState` 把整页拖垮。
  Future<void> fetchAndCacheFullMaidata({
    void Function(int current, int total)? onProgress,
  }) async {
    debugPrint('[DEBUG][MaidataManager] 开始获取全量maidata.txt...');

    final List<String> genrePaths = [
      '${ApiUrls.MaidataServerBaseUrl}/maimai',
      '${ApiUrls.MaidataServerBaseUrl}/niconicoボーカロイド',
      '${ApiUrls.MaidataServerBaseUrl}/ゲームバラエティ',
      '${ApiUrls.MaidataServerBaseUrl}/東方Project',
      '${ApiUrls.MaidataServerBaseUrl}/オンゲキCHUNITHM',
      '${ApiUrls.MaidataServerBaseUrl}/宴会場',
      '${ApiUrls.MaidataServerBaseUrl}/POPSアニメ',
    ];

    _cachedMaidata.clear();

    const int concurrency = 100;
    int totalFetched = 0;
    final Map<String, String> newUrlMap = {}; // 重建 songId→URL 映射

    // 阶段 2 的「已下载 / 总数」。声明在 [report] 之前，供其闭包引用。
    int urlsDiscovered = 0;
    int urlsTotal = 0;

    // 进度上报。**先累计、后节流显示**：计数本身永远是最新值，
    // 被节流掉的只是「回调次数」。
    //
    // 这一点不能反过来写：阶段 2 是 7 个流派**并行**下载，若在累加之前就
    // 按 250ms 提前 return，那第一个流派刷满窗口之后，其余流派紧接着完成的
    // 几批连 `urlsDiscovered` 都不会加，按钮上的数字就卡住不动了。
    int lastProgressMs = 0;
    void report({bool force = false}) {
      final callback = onProgress;
      if (callback == null) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (!force && now - lastProgressMs < 250) return;
      lastProgressMs = now;
      callback(urlsDiscovered, urlsTotal);
    }

    // ── 阶段 1：先并行拿到各流派的文件夹列表，汇总出**准确的总文件数** ──
    //
    // 原实现是「每个流派的列表一到手就开始下载它自己的文件」的流水线，
    // 重叠了这部分 IO；但那样总数是随各流派陆续返回而增长的：进度会先报成
    // 300/120（超过 100%），再跳成 300/5000。
    // 收益（省下几次目录请求的等待）远小于「进度看起来是错的」的代价，
    // 所以改成两阶段 —— 目录请求本身仍是并行的。
    int foldersFound = 0;
    final genreFolders = await Future.wait(
      genrePaths.map((genrePath) async {
        final folders = await _getFoldersInPath(genrePath);
        // 总数还没确定，先按「已发现」给个反馈，免得按钮上一直空着
        foldersFound += folders.length;
        if (onProgress != null) {
          onProgress(foldersFound, 0);
        }
        return (genrePath, folders);
      }),
    );

    urlsTotal = genreFolders.fold<int>(
      0,
      (sum, entry) => sum + entry.$2.length,
    );

    // ── 阶段 2：总数已定，并行下载 ──
    report(force: true);

    final allGenreResults = await Future.wait(
      genreFolders.map((entry) async {
        final genrePath = entry.$1;
        final folders = entry.$2;
        if (folders.isEmpty) return <(String, String)>[];

        final urls = folders.map((f) => '$genrePath/$f/maidata.txt').toList();
        final results = <(String, String)>[];

        for (int i = 0; i < urls.length; i += concurrency) {
          final end =
              (i + concurrency > urls.length) ? urls.length : i + concurrency;
          final batch = urls.sublist(i, end);
          final batchResults =
              await Future.wait(batch.map((url) => _fetchSingleMaidata(url)));
          for (int j = 0; j < batchResults.length; j++) {
            final r = batchResults[j];
            if (r != null) {
              results.add(r);
              // 记录 songId→URL 映射，供增量刷新使用
              newUrlMap[r.$1] = batch[j];
              urlsDiscovered++;
            }
          }
          report();
        }
        return results;
      }),
    );

    // 收尾补报一次：最后几批可能被 250ms 节流吃掉，没这一步按钮上会停在中间数字。
    report(force: true);

    // 汇总所有流派结果写入缓存
    for (final genreResults in allGenreResults) {
      for (final (songId, content) in genreResults) {
        _cachedMaidata[songId] = content;
        totalFetched++;
      }
    }

    // 保存 URL 映射。
    _idToUrlMap = newUrlMap;
    await _saveUrlMap();

    debugPrint('[DEBUG][MaidataManager] 全量缓存获取完成，共 $totalFetched 首歌曲');

    // JSON 编码在后台 isolate 中执行，写入文件而非 SharedPreferences。
    // 必须等待落盘完成后再结束刷新，否则下一次刷新会再次判断为缓存无效。
    // 文件直接写入比 SharedPreferences XML 快 10-100 倍（尤其是几十 MB 的大数据）
    final cacheCopy = Map<String, String>.from(_cachedMaidata);
    final encoded = await compute((Map<String, String> data) {
      return json.encode(data);
    }, cacheCopy);
    final file = await _getCacheFile();
    await file.writeAsString(encoded);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      CacheKeyConstant.maidataFullCacheTimestamp,
      DateTime.now().millisecondsSinceEpoch,
    );
    await prefs.remove(CacheKeyConstant.maidataFullCache);
    final sizeMB = (encoded.length / 1024 / 1024).toStringAsFixed(1);
    debugPrint(
      '[DEBUG][MaidataManager] 已保存到文件（共 ${_cachedMaidata.length} 首，约 $sizeMB MB）',
    );

    // 同时刷新index缓存，确保shortId映射是最新的
    _fetchAndCacheIndex();
  }

  /// 获取单个maidata.txt并返回 (songId, content) 或 null
  Future<(String, String)?> _fetchSingleMaidata(String url) async {
    try {
      final response = await ApiClient.get(Uri.parse(url));
      if (response.statusCode == 200) {
        String content = _decodeContent(response.bodyBytes);
        String? songId = _extractSongId(content);
        if (songId != null) {
          return (songId, content);
        }
      }
    } catch (e) {
      debugPrint('[DEBUG][MaidataManager] 获取 $url 失败: $e');
    }
    return null;
  }

  Future<List<String>> _getFoldersInPath(String path) async {
    List<String> folders = [];

    try {
      final response = await ApiClient.get(Uri.parse(path));

      if (response.statusCode == 200) {
        String decodedBody = _decodeContent(response.bodyBytes);
        RegExp linkRegex = RegExp(r'<a\s+href="([^"]+)/?"');
        Iterable<Match> matches = linkRegex.allMatches(decodedBody);

        for (Match match in matches) {
          String folder = match.group(1)!;
          if (folder.isNotEmpty &&
              !folder.startsWith('.') &&
              !folder.startsWith('/')) {
            folders.add(folder);
          }
        }
      }
    } catch (e) {
      debugPrint('[DEBUG][MaidataManager] 获取文件夹列表失败: $e');
    }

    return folders.toSet().toList();
  }

  String? _extractSongId(String content) {
    RegExp shortIdRegex = RegExp(r'&shortid=(\d+)');
    Match? match = shortIdRegex.firstMatch(content);

    if (match != null) {
      return match.group(1);
    }

    RegExp idRegex = RegExp(r'&id=(\d+)');
    match = idRegex.firstMatch(content);

    if (match != null) {
      return match.group(1);
    }

    return null;
  }

  /// 严格按 songId 精确命中。
  ///
  /// 不再做"去前导零 / 补前导零到 5 位 / 补前导零到 6 位"等变体查询。
  /// 谱面代码中的 shortId 必须与 SongInfoPage 传入的 songId 一致；
  /// 找不到就返回 null，不要用别的 ID 来顶替。
  String? getMaidata(String songId) {
    final content = _cachedMaidata[songId];
    if (content != null) {
      debugPrint('[MaidataManager] getMaidata: 严格命中, songId=$songId');
      return _cleanMaidataContent(content);
    }
    debugPrint(
        '[MaidataManager] getMaidata: 严格查询失败, songId=$songId, 缓存总数: ${_cachedMaidata.length}');
    return null;
  }

  bool hasCachedMaidata(String songId) {
    return _cachedMaidata.containsKey(songId);
  }

  int get cachedCount => _cachedMaidata.length;

  bool get isCacheReady => _cachedMaidata.isNotEmpty;

  /// 检查全量 maidata 缓存是否在有效期内（TTL）
  Future<bool> isFullCacheValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp =
          prefs.getInt(CacheKeyConstant.maidataFullCacheTimestamp);
      if (timestamp == null) return false;

      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - timestamp >= CacheTimestampConstant.maidataFullCacheMillis) {
        return false;
      }

      final file = await _getCacheFile();
      return await file.exists();
    } catch (e) {
      debugPrint('[MaidataManager] 检查缓存有效性失败: $e');
      return false;
    }
  }

  List<String> getAllMaidataTexts() {
    return _cachedMaidata.values
        .map((content) => _cleanMaidataContent(content))
        .toList();
  }

  // 根据歌曲ID列表获取对应的maidata（URL映射 + 流水线优化版）
  Future<List<String>> fetchMaidataForSongIds(List<String> songIds) async {
    debugPrint(
        '[DEBUG][MaidataManager] 开始获取指定歌曲ID的maidata（共 ${songIds.length} 首）');

    final List<String> result = [];
    final Set<String> remainingIds = Set.from(songIds);

    // 先检查本地缓存中是否已有
    for (final String songId in songIds) {
      if (_cachedMaidata.containsKey(songId)) {
        result.add(_cleanMaidataContent(_cachedMaidata[songId]!));
        remainingIds.remove(songId);
      }
    }

    if (remainingIds.isEmpty) {
      debugPrint('[DEBUG][MaidataManager] 全部命中缓存，无需网络请求');
      return result;
    }

    int fetchedCount = 0;

    // 优先通过 URL 映射直接获取（跳过目录抓取）
    final List<String> directUrls = [];
    for (final id in remainingIds) {
      final url = _idToUrlMap[id];
      if (url != null) {
        directUrls.add(url);
      }
    }

    if (directUrls.isNotEmpty) {
      debugPrint(
          '[DEBUG][MaidataManager] URL映射命中 $directUrls.length 首，直接获取（跳过目录扫描）...');

      const mapBatchSize = 80;
      for (int i = 0; i < directUrls.length; i += mapBatchSize) {
        final end = (i + mapBatchSize < directUrls.length)
            ? i + mapBatchSize
            : directUrls.length;
        final batch = directUrls.sublist(i, end);
        final batchResults =
            await Future.wait(batch.map((url) => _fetchSingleMaidata(url)));

        for (final r in batchResults) {
          if (r == null) continue;
          final (songId, content) = r;
          if (remainingIds.remove(songId)) {
            _cachedMaidata[songId] = content;
            result.add(_cleanMaidataContent(content));
            fetchedCount++;
          }
        }
      }
    }

    if (remainingIds.isEmpty) {
      debugPrint('[DEBUG][MaidataManager] 全部通过URL映射获取完成（共 $fetchedCount 首）');
      return result;
    }

    debugPrint(
        '[DEBUG][MaidataManager] URL映射未覆盖 ${remainingIds.length} 首，回退到目录扫描...');

    // 回退：扫描目录查找剩余歌曲
    final baseUrl = ApiUrls.MaidataServerBaseUrl;
    const genrePaths = <String>[
      '/maimai',
      '/niconicoボーカロイド',
      '/ゲームバラエティ',
      '/東方Project',
      '/オンゲキCHUNITHM',
      '/宴会場',
    ];

    await Future.wait(
      genrePaths.map((path) async {
        if (remainingIds.isEmpty) return;

        final folders = await _getFoldersInPath('$baseUrl$path');
        if (folders.isEmpty || remainingIds.isEmpty) return;

        final urls =
            folders.map((f) => '$baseUrl$path/$f/maidata.txt').toList();

        const batchSize = 50;
        for (int i = 0;
            i < urls.length && remainingIds.isNotEmpty;
            i += batchSize) {
          final end =
              (i + batchSize < urls.length) ? i + batchSize : urls.length;
          final batch = urls.sublist(i, end);

          final batchResults =
              await Future.wait(batch.map((url) => _fetchSingleMaidata(url)));

          for (int j = 0; j < batchResults.length; j++) {
            final r = batchResults[j];
            if (r == null) continue;
            final (songId, content) = r;
            // 同时更新 URL 映射供下次使用
            _idToUrlMap[songId] = batch[j];
            if (remainingIds.remove(songId)) {
              _cachedMaidata[songId] = content;
              result.add(_cleanMaidataContent(content));
              fetchedCount++;
            }
          }
        }
      }),
    );

    // 异步保存更新后的 URL 映射
    _saveUrlMap();

    debugPrint(
        '[DEBUG][MaidataManager] 指定歌曲maidata获取完成，成功获取 $fetchedCount 首（含缓存共 ${result.length} 首）');
    return result;
  }

  // ========== index.json 缓存，用于 songId → shortId 映射 ==========

  /// 获取缓存的index数据（shortId → title 映射），如果缓存过期则从服务器拉取
  Future<Map<String, dynamic>> getIndex() async {
    if (_indexData != null && _indexData!.isNotEmpty) {
      return _indexData!;
    }
    await _loadIndexFromCache();
    if (_indexData != null && _indexData!.isNotEmpty) {
      return _indexData!;
    }
    await _fetchAndCacheIndex();
    return _indexData ?? {};
  }

  Future<void> _loadIndexFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(CacheKeyConstant.maidataIndexCache);
      final timestamp =
          prefs.getInt(CacheKeyConstant.maidataIndexCacheTimestamp);
      if (cachedData != null && timestamp != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - timestamp < CacheTimestampConstant.maidataFullCacheMillis) {
          _indexData =
              Map<String, dynamic>.from(json.decode(cachedData) as Map);
          debugPrint(
              '[DEBUG][MaidataManager] 已加载index缓存，共 ${_indexData!.length} 条');
          return;
        }
      }
    } catch (e) {
      debugPrint('[DEBUG][MaidataManager] 加载index缓存失败: $e');
    }
  }

  Future<void> _fetchAndCacheIndex() async {
    try {
      final response = await ApiClient.get(
          Uri.parse('${ApiUrls.MaidataServerPortUrl}/index.json'));
      if (response.statusCode == 200) {
        String content = _decodeContent(response.bodyBytes);
        _indexData = Map<String, dynamic>.from(json.decode(content) as Map);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            CacheKeyConstant.maidataIndexCache, json.encode(_indexData));
        await prefs.setInt(CacheKeyConstant.maidataIndexCacheTimestamp,
            DateTime.now().millisecondsSinceEpoch);
        debugPrint(
            '[DEBUG][MaidataManager] index.json已缓存，共 ${_indexData!.length} 条');
      }
    } catch (e) {
      debugPrint('[DEBUG][MaidataManager] 获取index.json失败: $e');
    }
  }

  /// 根据歌曲标题在index中查找所有匹配的shortId
  List<String> findShortIdsForTitle(String title) {
    if (_indexData == null) return [];
    final sanitized = title
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '')
        .toUpperCase();
    List<String> result = [];
    for (var entry in _indexData!.entries) {
      dynamic value = entry.value;
      String indexTitle = '';
      if (value is String) {
        indexTitle = value;
      } else if (value is Map) {
        indexTitle = (value['title'] ?? value['name'] ?? '').toString();
      }
      String sanitizedIndexTitle = indexTitle
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
          .replaceAll(RegExp(r'\s+'), '')
          .toUpperCase();
      if (sanitizedIndexTitle == sanitized ||
          sanitizedIndexTitle.contains(sanitized) ||
          sanitized.contains(sanitizedIndexTitle)) {
        result.add(entry.key);
      }
    }
    return result;
  }

  /// 根据歌曲标题在index中查找所有匹配的shortId（含日语音读回退）
  Future<List<String>> findShortIdsForTitleKana(String title) async {
    // 先尝试简单匹配
    List<String> result = findShortIdsForTitle(title);
    if (result.isNotEmpty) return result;

    // 简单匹配失败，尝试jp_transliterate日语音读
    try {
      final katakanaTitle = await _tryTransliterate(title);
      if (katakanaTitle != null && katakanaTitle != title) {
        final katakanaResult = findShortIdsForTitle(katakanaTitle);
        if (katakanaResult.isNotEmpty) {
          debugPrint(
              '[MaidataManager] 日语音读匹配成功: "$title" -> "$katakanaTitle", 找到 ${katakanaResult.length} 个shortId');
          return katakanaResult;
        }
      }
    } catch (e) {
      debugPrint('[MaidataManager] 日语音读匹配异常: $e');
    }

    return [];
  }

  Future<String?> _tryTransliterate(String title) async {
    if (JpTransliterate.isKanji(input: title)) {
      final data = await JpTransliterate.transliterate(kanji: title);
      String katakana = data.katakana;
      if (katakana.isNotEmpty) {
        // 清理片假名结果以便匹配
        return katakana
            .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
            .replaceAll(RegExp(r'\s+'), '')
            .toUpperCase();
      }
    }
    return null;
  }

  /// 尝试通过多个shortId查找maidata（用于fallback）
  String? getMaidataByShortIds(List<String> shortIds) {
    for (final sid in shortIds) {
      String? content = getMaidata(sid);
      if (content != null) return content;
    }
    return null;
  }

  Future<void> clearCache() async {
    _cachedMaidata.clear();
    _indexData = null;
    _isInitialized = false;

    try {
      // 删除文件缓存
      final file = await _getCacheFile();
      if (await file.exists()) {
        await file.delete();
      }
      // 清除 SharedPreferences 中的时间戳及可能的旧版全量缓存
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(CacheKeyConstant.maidataFullCache);
      await prefs.remove(CacheKeyConstant.maidataFullCacheTimestamp);
      await prefs.remove(CacheKeyConstant.maidataIndexCache);
      await prefs.remove(CacheKeyConstant.maidataIndexCacheTimestamp);
      debugPrint('[DEBUG][MaidataManager] 缓存已清空');
    } catch (e) {
      debugPrint('[DEBUG][MaidataManager] 清空缓存失败: $e');
    }
  }

  // ============== 单曲兜底（wmc.pub，内存级） ==============

  /// 兜底来源：本地全量/单曲缓存都没命中时，从 wmc.pub 拉一份。
  /// 先查内存，再发请求；命中即写入内存缓存。
  /// 返回清理后的 maidata 文本（跟 [getMaidata] 一样去掉了 `[DX]`/`[SD]`/`[宴]`/尾 `$`）。
  Future<String?> getMaidataFromWmcFallback(String songId) async {
    final cached = _wmcFallbackCache[songId];
    if (cached != null) {
      debugPrint('[MaidataManager] wmc 兜底命中内存, songId=$songId');
      return _cleanMaidataContent(cached);
    }
    try {
      final url = ApiUrls.wmcMaidataUrl(songId);
      debugPrint('[MaidataManager] wmc 兜底请求: $url');
      final response = await ApiClient.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final content = _decodeContent(response.bodyBytes);
        // 必须能解析出 shortId 才算命中，否则当成垃圾丢掉
        if (_extractSongId(content) == songId) {
          _wmcFallbackCache[songId] = content;
          debugPrint('[MaidataManager] wmc 兜底命中, songId=$songId, '
              '内存缓存共 ${_wmcFallbackCache.length} 首');
          return _cleanMaidataContent(content);
        } else {
          debugPrint('[MaidataManager] wmc 兜底返回但 shortId 不匹配, songId=$songId');
        }
      } else {
        debugPrint('[MaidataManager] wmc 兜底非 200, songId=$songId, '
            'status=${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[MaidataManager] wmc 兜底请求失败, songId=$songId: $e');
    }
    return null;
  }

  /// 清空 wmc 兜底缓存（用户在系统中心「maidata 管理」里点按钮）。
  void clearWmcFallbackCache() {
    final n = _wmcFallbackCache.length;
    _wmcFallbackCache.clear();
    debugPrint('[MaidataManager] 已清空 wmc 兜底缓存，共 $n 首');
  }

  /// 内存里现存的 wmc 兜底曲数（只用于 UI 显示状态）。
  int get wmcFallbackCacheCount => _wmcFallbackCache.length;
}
