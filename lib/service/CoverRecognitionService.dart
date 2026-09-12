import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constant/CacheKeyConstant.dart';
import '../manager/DivingFish/MaimaiMusicDataManager.dart';
import '../utils/CoverUtil.dart';

/// 曲绘识别服务（Tier 2 重构版）
///
/// 与旧版相比：
///   - 后台 isolate 跑 DCT 计算（CPU 密集，不阻塞 UI）
///   - 并行批处理：每批 32 个 cover，多核提速
///   - 文件缓存：写入应用文档目录（绕过 SharedPreferences XML 序列化）
///   - 增量构建：跳过 manifest 中已缓存的 songId
///   - songId → coverId 映射走 [CoverUtil.extractCoverId]（与 SongInfoPage 一致）
///
/// 缓存结构（v3）：songId → {ph: hexString, r/g/b: int}
class CoverRecognitionService {
  static final CoverRecognitionService instance = CoverRecognitionService._();
  CoverRecognitionService._();

  Map<String, Map<String, dynamic>>? _featureCache;

  static const int _cacheVersion = 3;
  static const int _batchSize = 32;

  // ─── 缓存文件 ──────────────────────────────────────────────

  Future<File> _getCacheFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/cover_features_v$_cacheVersion.json');
  }

  Future<Map<String, Map<String, dynamic>>> _loadFeaturesFromFile() async {
    try {
      final file = await _getCacheFile();
      if (!await file.exists()) return {};
      final content = await file.readAsString();
      final decoded = jsonDecode(content);
      if (decoded is Map && decoded['v'] == _cacheVersion) {
        final data = decoded['data'] as Map<String, dynamic>;
        return data.map((k, v) => MapEntry(k, v as Map<String, dynamic>));
      }
    } catch (e) {
      debugPrint('读取曲绘特征缓存失败: $e');
    }
    return {};
  }

  Future<void> _saveFeaturesToFile(
      Map<String, Map<String, dynamic>> features) async {
    try {
      final file = await _getCacheFile();
      final payload = jsonEncode({'v': _cacheVersion, 'data': features});
      await file.writeAsString(payload);
      // 同步写一个时间戳，便于外部观测构建时间
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          CacheKeyConstant.coverHashCacheTimestamp,
          DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('保存曲绘特征缓存失败: $e');
    }
  }

  Future<bool> isHashCacheValid() async {
    try {
      final file = await _getCacheFile();
      if (!await file.exists()) return false;
      final content = await file.readAsString();
      final decoded = jsonDecode(content);
      return decoded is Map && decoded['v'] == _cacheVersion;
    } catch (e) {
      return false;
    }
  }

  // ─── 索引构建（Tier 2：后台 isolate + 批处理 + 增量） ───────────

  /// 预计算 / 增量补齐所有曲绘的 pHash 和颜色特征
  Future<void> precomputeHashes({
    void Function(int current, int total)? onProgress,
  }) async {
    // 1. 读 manifest（songIds）
    final manifestJson =
        await rootBundle.loadString('assets/cover_manifest.json');
    final songIds = (jsonDecode(manifestJson) as List<dynamic>)
        .map((e) => e as String)
        .toList();

    // 2. 读已有缓存
    final existing = await _loadFeaturesFromFile();
    _featureCache = existing;

    // 3. 找出缺失的 songId（增量）
    final missing =
        songIds.where((sid) => !existing.containsKey(sid)).toList();
    if (missing.isEmpty) {
      onProgress?.call(songIds.length, songIds.length);
      debugPrint('[CoverRecognition] 缓存已覆盖全部 ${songIds.length} 个 songId，跳过构建');
      return;
    }
    debugPrint(
        '[CoverRecognition] 增量构建：缺失 ${missing.length} / 共 ${songIds.length}');

    // 4. songId → coverId 映射；同一 coverId 对应的所有 songId 共用一份特征
    final coverToSongIds = <String, List<String>>{};
    for (final sid in missing) {
      final coverId = CoverUtil.extractCoverId(sid);
      if (coverId.isEmpty || coverId == '0') continue;
      coverToSongIds.putIfAbsent(coverId, () => []).add(sid);
    }

    // 5. 主线程预加载 bytes（rootBundle 必须在 main isolate）
    final tasks = <({String coverId, Uint8List bytes})>[];
    for (final coverId in coverToSongIds.keys) {
      try {
        final byteData =
            await rootBundle.load('assets/cover/$coverId.webp');
        tasks.add((coverId: coverId, bytes: byteData.buffer.asUint8List()));
      } catch (_) {
        // 本地无资源，跳过
      }
    }

    // 6. 分批后台 isolate 计算（DCT 在 isolate 内做，UI 不阻塞）
    int processed = 0;
    final total = tasks.length;
    final newFeatures = <String, Map<String, dynamic>>{};

    for (int i = 0; i < tasks.length; i += _batchSize) {
      final batch = tasks.skip(i).take(_batchSize).toList();
      // 单次 compute() 处理一批，多批串行调度（compute 自身已开新 isolate，
      // 并行收益有限，串行更稳且内存友好）
      final batchResults = await compute(_processBatchIsolate, batch);
      for (final entry in batchResults.entries) {
        final sids = coverToSongIds[entry.key] ?? const <String>[];
        for (final sid in sids) {
          newFeatures[sid] = entry.value;
        }
      }
      processed += batch.length;
      onProgress?.call(processed, total);
      // 让 UI 有机会刷新进度
      await Future.delayed(Duration.zero);
    }

    // 7. 合并 + 写文件
    existing.addAll(newFeatures);
    _featureCache = existing;
    await _saveFeaturesToFile(existing);
    debugPrint('[CoverRecognition] 完成，共 ${existing.length} 张曲绘特征');
  }

  /// 单批特征提取（运行在后台 isolate）。
  /// 输入：coverId → image bytes
  /// 输出：coverId → {ph, r, g, b}
  static Map<String, Map<String, dynamic>> _processBatchIsolate(
      List<({String coverId, Uint8List bytes})> batch) {
    final result = <String, Map<String, dynamic>>{};
    for (final task in batch) {
      try {
        final image = img.decodeImage(task.bytes);
        if (image == null) continue;
        // 缩放至 256×256（DCT 输入）
        final resized =
            img.copyResize(image, width: 256, height: 256);

        // 平均颜色
        int sumR = 0, sumG = 0, sumB = 0;
        const pixelCount = 256 * 256;
        for (int y = 0; y < 256; y++) {
          for (int x = 0; x < 256; x++) {
            final p = resized.getPixel(x, y);
            sumR += p.r.toInt();
            sumG += p.g.toInt();
            sumB += p.b.toInt();
          }
        }
        final avgR = sumR ~/ pixelCount;
        final avgG = sumG ~/ pixelCount;
        final avgB = sumB ~/ pixelCount;

        // pHash
        final ph = _computePHashPure(resized);

        result[task.coverId] = {
          'ph': ph,
          'r': avgR,
          'g': avgG,
          'b': avgB,
        };
      } catch (_) {
        continue;
      }
    }
    return result;
  }

  /// 纯函数版 pHash（不依赖实例状态，可被 isolate 直接调用）
  /// 算法：缩放256×256 → 灰度 → 降采样32×32 → DCT(左上8×8) → 中位数 → 64-bit hash
  static String _computePHashPure(img.Image resized) {
    // 灰度
    final gray = Float64List(256 * 256);
    for (int y = 0; y < 256; y++) {
      for (int x = 0; x < 256; x++) {
        final p = resized.getPixel(x, y);
        final r = p.r.toInt();
        final g = p.g.toInt();
        final b = p.b.toInt();
        gray[y * 256 + x] = 0.299 * r + 0.587 * g + 0.114 * b;
      }
    }

    // 降采样到 32×32
    final small = Float64List(32 * 32);
    for (int y = 0; y < 32; y++) {
      for (int x = 0; x < 32; x++) {
        double sum = 0;
        for (int dy = 0; dy < 8; dy++) {
          for (int dx = 0; dx < 8; dx++) {
            sum += gray[(y * 8 + dy) * 256 + (x * 8 + dx)];
          }
        }
        small[y * 32 + x] = sum / 64.0;
      }
    }

    // 2D DCT：取左上 8×8
    final dct8x8 = Float64List(64);
    for (int v = 0; v < 8; v++) {
      for (int u = 0; u < 8; u++) {
        double sum = 0;
        for (int y = 0; y < 32; y++) {
          final cosV = math.cos((2 * y + 1) * v * math.pi / 64);
          for (int x = 0; x < 32; x++) {
            final cosU = math.cos((2 * x + 1) * u * math.pi / 64);
            sum += small[y * 32 + x] * cosU * cosV;
          }
        }
        dct8x8[v * 8 + u] = sum;
      }
    }

    // 中位数（64 个系数）
    final sorted = dct8x8.toList()..sort();
    final median = sorted[32];

    // 64-bit 哈希 → 16 个 hex
    final buffer = StringBuffer();
    for (int i = 0; i < 64; i += 4) {
      int nibble = 0;
      for (int j = 0; j < 4; j++) {
        if (dct8x8[i + j] > median) {
          nibble |= (1 << (3 - j));
        }
      }
      buffer.write(nibble.toRadixString(16));
    }
    return buffer.toString();
  }

  /// 重建曲绘索引
  Future<void> rebuildCache({
    void Function(int current, int total)? onProgress,
  }) async {
    await clearCache();
    await precomputeHashes(onProgress: onProgress);
  }

  Future<void> clearCache() async {
    try {
      final file = await _getCacheFile();
      if (await file.exists()) await file.delete();
      _featureCache = null;
    } catch (e) {
      debugPrint('清除曲绘特征缓存失败: $e');
    }
  }

  // ─── 运行时特征缓存访问 ─────────────────────────────────────

  Future<Map<String, Map<String, dynamic>>> getCachedFeatures() async {
    if (_featureCache != null) return _featureCache!;
    _featureCache = await _loadFeaturesFromFile();
    return _featureCache!;
  }

  // ─── 识别入口（保持原有 API） ─────────────────────────────────

  /// 识别照片中最匹配的曲绘
  Future<Map<String, dynamic>?> recognizeCover(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        debugPrint('照片文件不存在: $imagePath');
        return null;
      }
      final bytes = await file.readAsBytes();
      var photo = img.decodeImage(bytes);
      if (photo == null) {
        debugPrint('无法解码照片: $imagePath');
        return null;
      }
      photo = _preprocessPhoto(photo);

      // 计算照片的 pHash + 平均颜色
      final resized = img.copyResize(photo, width: 256, height: 256);
      int sumR = 0, sumG = 0, sumB = 0;
      const pixelCount = 256 * 256;
      for (int y = 0; y < 256; y++) {
        for (int x = 0; x < 256; x++) {
          final p = resized.getPixel(x, y);
          sumR += p.r.toInt();
          sumG += p.g.toInt();
          sumB += p.b.toInt();
        }
      }
      final photoHash = _computePHashPure(resized);
      final photoR = sumR ~/ pixelCount;
      final photoG = sumG ~/ pixelCount;
      final photoB = sumB ~/ pixelCount;

      // 读缓存
      final cachedFeatures = await getCachedFeatures();
      if (cachedFeatures.isEmpty) {
        debugPrint('曲绘特征缓存为空，请先预计算');
        return null;
      }

      // 比对所有曲绘
      final allMatches = <Map<String, dynamic>>[];
      for (final entry in cachedFeatures.entries) {
        final feat = entry.value;
        final refHash = feat['ph'] as String;
        final refR = feat['r'] as int;
        final refG = feat['g'] as int;
        final refB = feat['b'] as int;

        final hashDist = _hammingDistance(photoHash, refHash);
        final colorDist =
            _colorDistance(photoR, photoG, photoB, refR, refG, refB);

        final hashSim = (64 - hashDist) / 64.0;
        final colorSim = 1.0 - (colorDist / 441.67);

        final combinedSim = 0.55 * hashSim + 0.45 * colorSim;

        allMatches.add({
          'songId': entry.key,
          'hashDistance': hashDist,
          'hashSimilarity': hashSim * 100,
          'colorSimilarity': colorSim * 100,
          'combinedSimilarity': combinedSim,
        });
      }

      allMatches.sort((a, b) =>
          (b['combinedSimilarity'] as double)
              .compareTo(a['combinedSimilarity'] as double));
      final topCandidates = allMatches.take(50).toList();

      // 填充歌曲信息
      final musicManager = MaimaiMusicDataManager();
      final songs = await musicManager.getCachedSongs();
      final songMap = <String, String>{};
      if (songs != null) {
        for (final s in songs) {
          songMap[s.id] = '${s.title}\t${s.basicInfo.artist}';
        }
      }

      for (final match in topCandidates) {
        final sid = match['songId'] as String;
        final combinedSim = match['combinedSimilarity'] as double;
        match['similarity'] = combinedSim * 100;
        final info = songMap[sid];
        if (info != null) {
          final parts = info.split('\t');
          match['songTitle'] = parts[0];
          match['artist'] = parts.length > 1 ? parts[1] : '';
        } else {
          match['songTitle'] = '歌曲 #$sid';
          match['artist'] = '';
        }
      }

      final validCandidates = topCandidates.where((m) {
        final title = m['songTitle'] as String? ?? '';
        return title.isNotEmpty && !title.startsWith('歌曲 #');
      }).toList();

      final best =
          validCandidates.isNotEmpty ? validCandidates.first : topCandidates.first;
      final bestSim = best['similarity'] as double;

      const lowConfidenceThreshold = 50.0;
      final lowConfidence = bestSim < lowConfidenceThreshold;

      if (lowConfidence) {
        debugPrint('最佳匹配综合相似度过低 ($bestSim% < $lowConfidenceThreshold%)，可能并非曲绘照片');
      }

      return {
        'songId': best['songId'],
        'similarity': bestSim,
        'hashSimilarity': best['hashSimilarity'],
        'colorSimilarity': best['colorSimilarity'],
        'songTitle': best['songTitle'],
        'artist': best['artist'],
        'topMatches': topCandidates,
        'lowConfidence': lowConfidence,
      };
    } catch (e) {
      debugPrint('曲绘识别失败: $e');
      return null;
    }
  }

  // ─── 图片预处理 ──────────────────────────────────────────────

  img.Image _preprocessPhoto(img.Image image) {
    final w = image.width;
    final h = image.height;
    img.Image square;
    if (w > h) {
      final offsetX = (w - h) ~/ 2;
      square = img.copyCrop(image, x: offsetX, y: 0, width: h, height: h);
    } else if (h > w) {
      final offsetY = (h - w) ~/ 2;
      square = img.copyCrop(image, x: 0, y: offsetY, width: w, height: w);
    } else {
      square = image;
    }
    return img.copyResize(square, width: 256, height: 256);
  }

  // ─── 距离计算 ────────────────────────────────────────────────

  int _hammingDistance(String hash1, String hash2) {
    if (hash1.length != hash2.length) return 64;
    int distance = 0;
    for (int i = 0; i < hash1.length; i++) {
      try {
        final v1 = int.parse(hash1[i], radix: 16);
        final v2 = int.parse(hash2[i], radix: 16);
        distance += _popCount(v1 ^ v2);
      } catch (e) {
        return 64;
      }
    }
    return distance;
  }

  double _colorDistance(int r1, int g1, int b1, int r2, int g2, int b2) {
    final dr = (r1 - r2).toDouble();
    final dg = (g1 - g2).toDouble();
    final db = (b1 - b2).toDouble();
    return math.sqrt(dr * dr + dg * dg + db * db);
  }

  int _popCount(int n) {
    int count = 0;
    int v = n;
    while (v != 0) {
      v &= (v - 1);
      count++;
    }
    return count;
  }
}