import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import '../constant/CacheKeyConstant.dart';
import '../manager/DivingFish/MaimaiMusicDataManager.dart';

/// 曲绘识别服务
/// 使用pHash（DCT感知哈希）+ 颜色特征进行图像相似度比对
class CoverRecognitionService {
  static final CoverRecognitionService instance = CoverRecognitionService._();
  CoverRecognitionService._();

  // 缓存：songId → {ph: pHash, r: avgR, g: avgG, b: avgB}
  Map<String, Map<String, dynamic>>? _featureCache;

  static const int _cacheVersion = 2;

  /// 检查特征缓存是否有效
  Future<bool> isHashCacheValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = prefs.getString(CacheKeyConstant.coverHashCache);
      if (cacheData == null || cacheData.isEmpty) return false;
      final decoded = jsonDecode(cacheData);
      if (decoded is Map && decoded['v'] == _cacheVersion) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('检查曲绘特征缓存失败: $e');
      return false;
    }
  }

  /// 获取缓存的特征映射
  Future<Map<String, Map<String, dynamic>>> getCachedFeatures() async {
    if (_featureCache != null) return _featureCache!;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = prefs.getString(CacheKeyConstant.coverHashCache);
      if (cacheJson != null && cacheJson.isNotEmpty) {
        final decoded = jsonDecode(cacheJson);
        if (decoded is Map && decoded['v'] == _cacheVersion) {
          final data = decoded['data'] as Map<String, dynamic>;
          _featureCache = data.map((k, v) =>
              MapEntry(k, v as Map<String, dynamic>));
          return _featureCache!;
        }
      }
    } catch (e) {
      debugPrint('读取曲绘特征缓存失败: $e');
    }
    return {};
  }

  /// 预计算所有曲绘的pHash和颜色特征并缓存
  Future<void> precomputeHashes({
    void Function(int current, int total)? onProgress,
  }) async {
    final manifestJson =
        await rootBundle.loadString('assets/cover_manifest.json');
    final songIds = (jsonDecode(manifestJson) as List<dynamic>)
        .map((e) => e as String)
        .toList();

    final Map<String, Map<String, dynamic>> features = {};
    final total = songIds.length;

    for (int i = 0; i < total; i++) {
      final songId = songIds[i];
      final path = 'assets/cover/$songId.webp';

      img.Image? decoded;

      // 先尝试本地资源
      try {
        final byteData = await rootBundle.load(path);
        final bytes = byteData.buffer.asUint8List();
        if (bytes.isNotEmpty) {
          decoded = img.decodeImage(bytes);
          if (decoded == null) {
            debugPrint('本地曲绘无法解码: $path，尝试网络获取');
          }
        } else {
          debugPrint('本地曲绘为空: $path，尝试网络获取');
        }
      } catch (e) {
        debugPrint('加载本地曲绘失败: $path, 错误: $e，尝试网络获取');
      }

      // 本地失败则从网络获取
      if (decoded == null) {
        decoded = await _tryLoadFromNetwork(songId);
      }

      if (decoded != null) {
        features[songId] = {
          'ph': _computePHash(decoded),
          'r': _avgColorR,
          'g': _avgColorG,
          'b': _avgColorB,
        };
      } else {
        debugPrint('跳过曲绘（本地和网络均不可用）: $path');
      }

      onProgress?.call(i + 1, total);

      if (i % 10 == 0) {
        await Future.delayed(Duration.zero);
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'v': _cacheVersion,
        'data': features,
      };
      await prefs.setString(
          CacheKeyConstant.coverHashCache, jsonEncode(cacheData));
      await prefs.setInt(CacheKeyConstant.coverHashCacheTimestamp,
          DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('保存曲绘特征缓存失败: $e');
    }

    _featureCache = features;
  }

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

      // 预处理：中心裁剪为正方形，统一尺寸
      photo = _preprocessPhoto(photo);

      // 计算照片的pHash和平均颜色
      final photoHash = _computePHash(photo);
      final photoR = _avgColorR;
      final photoG = _avgColorG;
      final photoB = _avgColorB;

      // 获取缓存的曲绘特征
      final cachedFeatures = await getCachedFeatures();
      if (cachedFeatures.isEmpty) {
        debugPrint('曲绘特征缓存为空，请先预计算');
        return null;
      }

      // 比对所有曲绘，计算综合相似度
      final allMatches = <Map<String, dynamic>>[];
      for (final entry in cachedFeatures.entries) {
        final feat = entry.value;
        final refHash = feat['ph'] as String;
        final refR = feat['r'] as int;
        final refG = feat['g'] as int;
        final refB = feat['b'] as int;

        final hashDist = _hammingDistance(photoHash, refHash);
        final colorDist = _colorDistance(photoR, photoG, photoB, refR, refG, refB);

        // pHash相似度: 0..1
        final hashSim = (64 - hashDist) / 64.0;
        // 颜色相似度: 0..1
        final colorSim = 1.0 - (colorDist / 441.67); // 441.67 = max RGB euclidean distance

        // 加权融合: pHash 55% + 颜色 45%
        final combinedSim = 0.55 * hashSim + 0.45 * colorSim;

        allMatches.add({
          'songId': entry.key,
          'hashDistance': hashDist,
          'hashSimilarity': hashSim * 100,
          'colorSimilarity': colorSim * 100,
          'combinedSimilarity': combinedSim,
        });
      }

      // 按综合相似度降序排序
      allMatches.sort((a, b) =>
          (b['combinedSimilarity'] as double)
              .compareTo(a['combinedSimilarity'] as double));
      // 取足够多的候选（50条），确保前端过滤掉无效/重复条目后仍能补全10个
      final topCandidates = allMatches.take(50).toList();

      // 获取歌曲信息
      final musicManager = MaimaiMusicDataManager();
      final songs = await musicManager.getCachedSongs();
      final songMap = <String, String>{};
      if (songs != null) {
        for (final s in songs) {
          songMap[s.id] = '${s.title}\t${s.basicInfo.artist}';
        }
      }

      // 填充歌曲信息并计算相似度
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

      // 从有效候选（有真实歌名）中取最佳匹配，确保顶部结果区域合法
      final validCandidates = topCandidates.where((m) {
        final title = m['songTitle'] as String? ?? '';
        return title.isNotEmpty && !title.startsWith('歌曲 #');
      }).toList();

      // 极端情况：所有候选都无效，回退到原始第一名
      final best = validCandidates.isNotEmpty ? validCandidates.first : topCandidates.first;
      final bestSim = best['similarity'] as double;

      // 低置信度阈值：综合相似度 < 50% 视为不可靠
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

  /// 重建曲绘索引
  Future<void> rebuildCache({
    void Function(int current, int total)? onProgress,
  }) async {
    await clearCache();
    await precomputeHashes(onProgress: onProgress);
  }

  // ─── 网络曲绘获取 ───

  /// 构建水鱼曲绘网络URL
  /// 规则：ID在10001~11000区间 → id-10000；补足5位零填充
  static String _getCoverUrl(String songId) {
    final id = int.tryParse(songId) ?? 0;
    int coverId = id;
    if (coverId > 10000 && coverId <= 11000) {
      coverId -= 10000;
    }
    final padded = coverId.toString().padLeft(5, '0');
    return 'https://www.diving-fish.com/covers/$padded.png';
  }

  /// 从网络获取曲绘图片
  Future<img.Image?> _tryLoadFromNetwork(String songId) async {
    try {
      final url = _getCoverUrl(songId);
      debugPrint('尝试从网络获取曲绘: $url');
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final decoded = img.decodeImage(response.bodyBytes);
        if (decoded != null) {
          debugPrint('网络获取曲绘成功: $songId');
          return decoded;
        }
      }
      debugPrint('网络获取曲绘失败: $songId (status=${response.statusCode})');
    } catch (e) {
      debugPrint('网络获取曲绘异常: $songId, 错误: $e');
    }
    return null;
  }

  // ─── 图片预处理 ───

  /// 预处理用户照片：中心裁剪为正方形，缩放至256×256
  img.Image _preprocessPhoto(img.Image image) {
    final w = image.width;
    final h = image.height;

    // 中心裁剪为正方形
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

    // 缩放到256×256（与曲绘参考尺寸一致）
    return img.copyResize(square, width: 256, height: 256);
  }

  // ─── pHash (DCT感知哈希) ───

  // 临时变量：在 _computePHash 中顺便计算平均颜色
  int _avgColorR = 0;
  int _avgColorG = 0;
  int _avgColorB = 0;

  /// 计算Perceptual Hash (pHash)
  /// 算法：缩放256×256 → 灰度 → DCT → 取左上8×8 → 与中位数比较 → 64-bit hash
  /// 同时计算平均RGB颜色存入 _avgColorR/G/B
  String _computePHash(img.Image image) {
    // 先缩放至256×256（保证DCT输入一致）
    final resized = img.copyResize(image, width: 256, height: 256);

    // 灰度 + 同时累计平均RGB
    final gray = Float64List(256 * 256);
    int sumR = 0, sumG = 0, sumB = 0;
    final pixelCount = 256 * 256;

    for (int y = 0; y < 256; y++) {
      for (int x = 0; x < 256; x++) {
        final p = resized.getPixel(x, y);
        final r = p.r.toInt();
        final g = p.g.toInt();
        final b = p.b.toInt();
        gray[y * 256 + x] = 0.299 * r + 0.587 * g + 0.114 * b;
        sumR += r;
        sumG += g;
        sumB += b;
      }
    }
    _avgColorR = sumR ~/ pixelCount;
    _avgColorG = sumG ~/ pixelCount;
    _avgColorB = sumB ~/ pixelCount;

    // 降采样到32×32用于DCT
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

    // 2D DCT: 只计算左上角8×8
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

    // 用全部64个DCT系数计算中位数（标准做法：包含DC分量）
    final sorted = dct8x8.toList()..sort();
    final median = sorted[32]; // 64个元素，中位数在索引32

    // 生成64-bit哈希
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

  // ─── 距离计算 ───

  /// 计算两个pHash之间的Hamming距离
  int _hammingDistance(String hash1, String hash2) {
    if (hash1.length != hash2.length) return 64;
    int distance = 0;
    for (int i = 0; i < hash1.length; i++) {
      try {
        final val1 = int.parse(hash1[i], radix: 16);
        final val2 = int.parse(hash2[i], radix: 16);
        distance += _popCount(val1 ^ val2);
      } catch (e) {
        return 64;
      }
    }
    return distance;
  }

  /// 计算两个RGB颜色之间的Euclidean距离
  double _colorDistance(int r1, int g1, int b1, int r2, int g2, int b2) {
    final dr = (r1 - r2).toDouble();
    final dg = (g1 - g2).toDouble();
    final db = (b1 - b2).toDouble();
    return math.sqrt(dr * dr + dg * dg + db * db);
  }

  /// popcount
  int _popCount(int n) {
    int count = 0;
    int v = n;
    while (v != 0) {
      v &= (v - 1);
      count++;
    }
    return count;
  }

  // ─── 缓存管理 ───

  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(CacheKeyConstant.coverHashCache);
      await prefs.remove(CacheKeyConstant.coverHashCacheTimestamp);
      _featureCache = null;
    } catch (e) {
      debugPrint('清除曲绘特征缓存失败: $e');
    }
  }
}