import 'dart:convert';
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
          print('[DEBUG][MaidataManager] 已加载全量缓存，共 ${_cachedMaidata.length} 首歌曲');
          return;
        } else {
          print('[DEBUG][MaidataManager] 全量缓存已过期，删除旧缓存');
          await prefs.remove(CacheKeyConstant.maidataFullCache);
          await prefs.remove(CacheKeyConstant.maidataFullCacheTimestamp);
        }
      }
    } catch (e) {
      print('[DEBUG][MaidataManager] 加载缓存失败: $e');
    }
  }

  Future<void> fetchAndCacheFullMaidata() async {
    print('[DEBUG][MaidataManager] 开始获取全量maidata.txt...');
    
    List<String> genrePaths = [
      '${ApiUrls.MaidataServerBaseUrl}/maimai',
      '${ApiUrls.MaidataServerBaseUrl}/niconicoボーカロイド',
      '${ApiUrls.MaidataServerBaseUrl}/ゲームバラエティ',
      '${ApiUrls.MaidataServerBaseUrl}/東方Project',
      '${ApiUrls.MaidataServerBaseUrl}/オンゲキCHUNITHM',
      '${ApiUrls.MaidataServerBaseUrl}/宴会場',
    ];

    _cachedMaidata.clear();
    int totalFetched = 0;

    for (String genrePath in genrePaths) {
      print('[DEBUG][MaidataManager] 处理流派路径: $genrePath');
      
      try {
        List<String> folders = await _getFoldersInPath(genrePath);
        print('[DEBUG][MaidataManager] 发现 ${folders.length} 个文件夹');

        for (String folder in folders) {
          String maidataUrl = '$genrePath/$folder/maidata.txt';
          
          try {
            final response = await http.get(Uri.parse(maidataUrl));
            
            if (response.statusCode == 200) {
              String content = _decodeContent(response.bodyBytes);
              String? songId = _extractSongId(content);
              
              if (songId != null) {
                _cachedMaidata[songId] = content;
                totalFetched++;
                print('[DEBUG][MaidataManager] 缓存歌曲: $songId');
              } else {
                print('[DEBUG][MaidataManager] 无法从 $maidataUrl 提取歌曲ID');
              }
            }
          } catch (e) {
            print('[DEBUG][MaidataManager] 获取 $maidataUrl 失败: $e');
          }
        }
      } catch (e) {
        print('[DEBUG][MaidataManager] 获取流派路径 $genrePath 的文件夹列表失败: $e');
      }
    }

    print('[DEBUG][MaidataManager] 全量缓存获取完成，共 $totalFetched 首歌曲');

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(CacheKeyConstant.maidataFullCache, json.encode(_cachedMaidata));
      await prefs.setInt(CacheKeyConstant.maidataFullCacheTimestamp, DateTime.now().millisecondsSinceEpoch);
      print('[DEBUG][MaidataManager] 已保存到SharedPreferences');
    } catch (e) {
      print('[DEBUG][MaidataManager] 保存缓存失败: $e');
    }
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
      print('[DEBUG][MaidataManager] 获取文件夹列表失败: $e');
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
    String? content = _cachedMaidata[songId];
    if (content != null) {
      return _cleanMaidataContent(content);
    }
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
  
  // 根据歌曲ID列表获取对应的maidata
  Future<List<String>> fetchMaidataForSongIds(List<String> songIds) async {
    print('[DEBUG][MaidataManager] 开始获取指定歌曲ID的maidata（共 ${songIds.length} 首）');
    
    List<String> result = [];
    List<String> remainingIds = List.from(songIds);
    
    // 先检查本地缓存中是否已有
    for (String songId in songIds) {
      if (_cachedMaidata.containsKey(songId)) {
        result.add(_cleanMaidataContent(_cachedMaidata[songId]!));
        remainingIds.remove(songId);
      }
    }
    
    // 如果还有需要获取的
    if (remainingIds.isNotEmpty) {
      List<String> genrePaths = [
        '${ApiUrls.MaidataServerBaseUrl}/maimai',
        '${ApiUrls.MaidataServerBaseUrl}/niconicoボーカロイド',
        '${ApiUrls.MaidataServerBaseUrl}/ゲームバラエティ',
        '${ApiUrls.MaidataServerBaseUrl}/東方Project',
        '${ApiUrls.MaidataServerBaseUrl}/オンゲキCHUNITHM',
        '${ApiUrls.MaidataServerBaseUrl}/宴会場',
      ];
      
      for (String genrePath in genrePaths) {
        if (remainingIds.isEmpty) break;
        
        try {
          List<String> folders = await _getFoldersInPath(genrePath);
          
          for (String folder in folders) {
            if (remainingIds.isEmpty) break;
            
            String maidataUrl = '$genrePath/$folder/maidata.txt';
            
            try {
              final response = await http.get(Uri.parse(maidataUrl));
              
              if (response.statusCode == 200) {
                String content = _decodeContent(response.bodyBytes);
                String? songId = _extractSongId(content);
                
                if (songId != null && remainingIds.contains(songId)) {
                  _cachedMaidata[songId] = content;
                  result.add(_cleanMaidataContent(content));
                  remainingIds.remove(songId);
                  print('[DEBUG][MaidataManager] 获取到指定歌曲: $songId');
                }
              }
            } catch (e) {
              print('[DEBUG][MaidataManager] 获取 $maidataUrl 失败: $e');
            }
          }
        } catch (e) {
          print('[DEBUG][MaidataManager] 获取流派路径 $genrePath 的文件夹列表失败: $e');
        }
      }
    }
    
    print('[DEBUG][MaidataManager] 指定歌曲maidata获取完成，成功获取 ${result.length} 首');
    return result;
  }

  Future<void> clearCache() async {
    _cachedMaidata.clear();
    _isInitialized = false;
    
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(CacheKeyConstant.maidataFullCache);
      await prefs.remove(CacheKeyConstant.maidataFullCacheTimestamp);
      print('[DEBUG][MaidataManager] 缓存已清空');
    } catch (e) {
      print('[DEBUG][MaidataManager] 清空缓存失败: $e');
    }
  }
}