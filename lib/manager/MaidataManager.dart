import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../api/ApiUrls.dart';
import '../constant/CacheKeyConstant.dart';
import '../constant/CacheTimestampConstant.dart';

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

  String _decodeContent(List<int> bytes) {
    try {
      String utf8Result = utf8.decode(bytes);
      if (_isValidUtf8(utf8Result)) {
        return utf8Result;
      }
    } catch (_) {}

    try {
      String shiftJisResult = _decodeShiftJis(bytes);
      if (shiftJisResult.isNotEmpty && !_containsInvalidChars(shiftJisResult)) {
        return shiftJisResult;
      }
    } catch (_) {}

    try {
      String cp932Result = _decodeCp932(bytes);
      if (cp932Result.isNotEmpty && !_containsInvalidChars(cp932Result)) {
        return cp932Result;
      }
    } catch (_) {}

    return utf8.decode(bytes, allowMalformed: true);
  }

  bool _isValidUtf8(String text) {
    for (int i = 0; i < text.length; i++) {
      int code = text.codeUnitAt(i);
      if (code == 0xFFFD || code == 0xFFFE || code == 0xFFFF) {
        return false;
      }
    }
    return true;
  }

  bool _containsInvalidChars(String text) {
    for (int i = 0; i < text.length; i++) {
      int code = text.codeUnitAt(i);
      if ((code >= 0xFDD0 && code <= 0xFDEF) || 
          (code >= 0xFFFE && code <= 0xFFFF)) {
        return true;
      }
    }
    return false;
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
      return 0x4E00 + (((sjis - 0x8140) ~/ 0x40) * 0x9F) + ((sjis - 0x8140) % 0x40) - (((sjis - 0x8140) ~/ 0x40) > 7 ? 1 : 0);
    }
    
    if (sjis >= 0x889F && sjis <= 0x9FFC) {
      return 0x4E00 + (((sjis - 0x889F) ~/ 0x40) * 0x9F) + ((sjis - 0x889F) % 0x40) + 0x7D;
    }
    
    if (sjis >= 0xE040 && sjis <= 0xEAA4) {
      return 0xF900 + (sjis - 0xE040);
    }
    
    return 0;
  }

  String _decodeCp932(List<int> bytes) {
    return _decodeShiftJis(bytes);
  }

  Map<String, String> _cachedMaidata = {};
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    await _loadFromCache();
    _isInitialized = true;
  }

  Future<void> _loadFromCache() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? cachedData = prefs.getString(CacheKeyConstant.maidataFullCache);
      int? timestamp = prefs.getInt(CacheKeyConstant.maidataFullCacheTimestamp);

      if (cachedData != null && timestamp != null) {
        int now = DateTime.now().millisecondsSinceEpoch;

        if (now - timestamp < CacheTimestampConstant.maidataFullCacheMillis) {
          _cachedMaidata = Map<String, String>.from(json.decode(cachedData) as Map);
          debugPrint('[DEBUG][MaidataManager] 已加载全量缓存，共 ${_cachedMaidata.length} 首歌曲');
          return;
        } else {
          debugPrint('[DEBUG][MaidataManager] 全量缓存已过期，删除旧缓存');
          await prefs.remove(CacheKeyConstant.maidataFullCache);
          await prefs.remove(CacheKeyConstant.maidataFullCacheTimestamp);
        }
      }
    } catch (e) {
      debugPrint('[DEBUG][MaidataManager] 加载缓存失败: $e');
    }
  }

  Future<void> fetchAndCacheFullMaidata() async {
    debugPrint('[DEBUG][MaidataManager] 开始获取全量maidata.txt...');
    
    List<String> genrePaths = [
      '${ApiUrls.MaidataServerBaseUrl}/maimai',
      '${ApiUrls.MaidataServerBaseUrl}/niconicoボーカロイド',
      '${ApiUrls.MaidataServerBaseUrl}/ゲームバラエティ',
      '${ApiUrls.MaidataServerBaseUrl}/東方Project',
      '${ApiUrls.MaidataServerBaseUrl}/オンゲキCHUNITHM',
      '${ApiUrls.MaidataServerBaseUrl}/宴会場',
    ];

    _cachedMaidata.clear();
    
    // 第一步：并行获取所有流派的文件夹列表
    debugPrint('[DEBUG][MaidataManager] 并行获取所有流派文件夹列表...');
    final List<List<String>> allFolderLists = await Future.wait(
      genrePaths.map((path) => _getFoldersInPath(path)),
    );
    
    // 收集所有文件夹URL
    List<String> allFolderUrls = [];
    for (int i = 0; i < genrePaths.length; i++) {
      for (final folder in allFolderLists[i]) {
        allFolderUrls.add('${genrePaths[i]}/$folder/maidata.txt');
      }
    }
    debugPrint('[DEBUG][MaidataManager] 共发现 ${allFolderUrls.length} 个maidata.txt，开始并行获取...');

    // 第二步：并行获取所有maidata.txt（控制并发数，避免同时太多请求）
    const int concurrency = 50;
    int totalFetched = 0;
    int completedCount = 0;
    final int totalCount = allFolderUrls.length;

    for (int i = 0; i < allFolderUrls.length; i += concurrency) {
      final batch = allFolderUrls.sublist(
        i,
        (i + concurrency > allFolderUrls.length) ? allFolderUrls.length : i + concurrency,
      );
      
      final results = await Future.wait(
        batch.map((url) => _fetchSingleMaidata(url)),
      );
      
      for (final result in results) {
        if (result != null) {
          _cachedMaidata[result.$1] = result.$2;
          totalFetched++;
        }
      }
      
      completedCount += batch.length;
      debugPrint('[DEBUG][MaidataManager] 获取进度: $completedCount/$totalCount');
    }

    debugPrint('[DEBUG][MaidataManager] 全量缓存获取完成，共 $totalFetched 首歌曲');

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(CacheKeyConstant.maidataFullCache, json.encode(_cachedMaidata));
      await prefs.setInt(CacheKeyConstant.maidataFullCacheTimestamp, DateTime.now().millisecondsSinceEpoch);
      debugPrint('[DEBUG][MaidataManager] 已保存到SharedPreferences');
    } catch (e) {
      debugPrint('[DEBUG][MaidataManager] 保存缓存失败: $e');
    }
  }

  /// 获取单个maidata.txt并返回 (songId, content) 或 null
  Future<(String, String)?> _fetchSingleMaidata(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
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
      final response = await http.get(Uri.parse(path));
      
      if (response.statusCode == 200) {
        RegExp linkRegex = RegExp(r'<a\s+href="([^"]+)/?"');
        Iterable<Match> matches = linkRegex.allMatches(response.body);
        
        for (Match match in matches) {
          String folder = match.group(1)!;
          if (folder.isNotEmpty && !folder.startsWith('.') && !folder.startsWith('/')) {
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

  String? getMaidata(String songId) {
    // 尝试直接查询
    String? content = _cachedMaidata[songId];
    if (content != null) {
      debugPrint('[MaidataManager] getMaidata: 直接查询成功, songId=$songId');
      return _cleanMaidataContent(content);
    }
    
    // 尝试去除前导零的ID
    String trimmedId = songId.replaceFirst(RegExp(r'^0+'), '');
    if (trimmedId.isNotEmpty && trimmedId != songId) {
      content = _cachedMaidata[trimmedId];
      if (content != null) {
        debugPrint('[MaidataManager] getMaidata: 通过去除前导零查询成功, songId=$songId, trimmedId=$trimmedId');
        return _cleanMaidataContent(content);
      }
    }
    
    // 尝试补前导零到5位（常见格式）
    String paddedId = songId.padLeft(5, '0');
    if (paddedId != songId) {
      content = _cachedMaidata[paddedId];
      if (content != null) {
        debugPrint('[MaidataManager] getMaidata: 通过补前导零到5位查询成功, songId=$songId, paddedId=$paddedId');
        return _cleanMaidataContent(content);
      }
    }
    
    // 尝试补前导零到6位（UTAGE歌曲）
    String paddedId6 = songId.padLeft(6, '0');
    if (paddedId6 != songId) {
      content = _cachedMaidata[paddedId6];
      if (content != null) {
        debugPrint('[MaidataManager] getMaidata: 通过补前导零到6位查询成功, songId=$songId, paddedId6=$paddedId6');
        return _cleanMaidataContent(content);
      }
    }
    
    // 调试：输出缓存中所有包含该数字的key
    List<String> matchingKeys = _cachedMaidata.keys.where((key) => key.contains(songId) || songId.contains(key)).toList();
    debugPrint('[MaidataManager] getMaidata: 查询失败, songId=$songId, 缓存中匹配的key: $matchingKeys, 缓存总数: ${_cachedMaidata.length}');
    
    return null;
  }

  bool hasCachedMaidata(String songId) {
    return _cachedMaidata.containsKey(songId);
  }

  int get cachedCount => _cachedMaidata.length;

  bool get isCacheReady => _cachedMaidata.isNotEmpty;

  List<String> getAllMaidataTexts() {
    return _cachedMaidata.values.map((content) => _cleanMaidataContent(content)).toList();
  }
  
  // 根据歌曲ID列表获取对应的maidata（并行优化版）
  Future<List<String>> fetchMaidataForSongIds(List<String> songIds) async {
    debugPrint('[DEBUG][MaidataManager] 开始获取指定歌曲ID的maidata（共 ${songIds.length} 首）');

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

    debugPrint('[DEBUG][MaidataManager] 缓存未命中 ${remainingIds.length} 首，开始并行获取...');

    // 1. 并行获取所有流派路径的文件夹列表
    const genrePaths = <String>[
      '/maimai',
      '/niconicoボーカロイド',
      '/ゲームバラエティ',
      '/東方Project',
      '/オンゲキCHUNITHM',
      '/宴会場',
    ];
    final baseUrl = ApiUrls.MaidataServerBaseUrl;

    final genreResults = await Future.wait(
      genrePaths.map((path) => _getFoldersInPath('$baseUrl$path')),
    );

    // 2. 收集所有 maidata.txt URL
    final List<String> allUrls = [];
    for (int i = 0; i < genrePaths.length; i++) {
      for (final folder in genreResults[i]) {
        allUrls.add('$baseUrl${genrePaths[i]}/$folder/maidata.txt');
      }
    }

    debugPrint('[DEBUG][MaidataManager] 共收集 ${allUrls.length} 个maidata.txt URL，开始并行批量获取...');

    // 3. 并行批量获取（每批 15 个并发），找到所有目标后提前终止
    const batchSize = 15;
    int fetchedCount = 0;

    for (int i = 0; i < allUrls.length && remainingIds.isNotEmpty; i += batchSize) {
      final end = (i + batchSize < allUrls.length) ? i + batchSize : allUrls.length;
      final batch = allUrls.sublist(i, end);

      final batchResults = await Future.wait(
        batch.map((url) => _fetchSingleMaidata(url)),
      );

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

    debugPrint('[DEBUG][MaidataManager] 指定歌曲maidata获取完成，成功获取 $fetchedCount 首（含缓存共 ${result.length} 首）');
    return result;
  }

  Future<void> clearCache() async {
    _cachedMaidata.clear();
    _isInitialized = false;
    
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(CacheKeyConstant.maidataFullCache);
      await prefs.remove(CacheKeyConstant.maidataFullCacheTimestamp);
      debugPrint('[DEBUG][MaidataManager] 缓存已清空');
    } catch (e) {
      debugPrint('[DEBUG][MaidataManager] 清空缓存失败: $e');
    }
  }
}