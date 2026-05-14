import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:jp_transliterate/jp_transliterate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/ApiUrls.dart';
import '../manager/MaimaiMusicDataManager.dart';
import '../manager/MaidataManager.dart';
import '../constant/CacheKeyConstant.dart';
import '../constant/CacheTimestampConstant.dart';

// 匹配结果数据类（支持自定义标题用于构建URL）
class MatchResult {
  final String id;
  final String title;
  final String? customUrlTitle;

  MatchResult(this.id, this.title, [this.customUrlTitle]);

  @override
  String toString() => 'MatchResult(id: $id, title: "$title", customUrlTitle: "$customUrlTitle")';
  
  String get key => customUrlTitle != null ? '$id|$customUrlTitle' : id;
}

class SongMaidataPageService {
  // inote数字到难度名称的映射
  static const Map<String, String> inoteDifficultyMap = {
    '2': 'BASIC',
    '3': 'ADVANCED',
    '4': 'EXPERT',
    '5': 'MASTER',
    '6': 'RE:MASTER',
    '7': 'UTAGE',
  };

  // inote数字到颜色的映射
  static const Map<String, int> inoteColorMap = {
    '2': 0xFF4CAF50,       // BASIC - 绿色
    '3': 0xFFFF9800,       // ADVANCED - 橙色
    '4': 0xFFF44336,       // EXPERT - 红色
    '5': 0xFF9C27B0,       // MASTER - 紫色
    '6': 0xFFCE93D8,       // RE:MASTER - 淡紫色
    '7': 0xFFFF4081,       // UTAGE - 粉色
  };

  // 流派名映射
  static final Map<String, String> _genreMapping = {
    '舞萌': 'maimai',
    '流行&动漫': 'POPSアニメ',
    'niconico & VOCALOID': 'niconicoボーカロイド',
    '其他游戏': 'ゲームバラエティ',
    '东方Project': '東方Project',
    '音击&中二节奏': 'オンゲキCHUNITHM',
  };

  final String songId;
  final String songTitle;
  final String genre;
  final String songType;

  SongMaidataPageService({
    required this.songId,
    required this.songTitle,
    required this.genre,
    required this.songType,
  });

  // 处理歌曲标题
  String _sanitizeTitle(String title) {
    return title
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '')
        .toUpperCase();
  }

  // 根据歌曲名从index.json查找所有可能的匹配结果
  Future<List<MatchResult>> findAllMatches() async {
    List<MatchResult> allMatches = [];
    Set<String> addedIds = {};
    
    try {
      final response = await http.get(Uri.parse('${ApiUrls.MaidataServerPortUrl}/index.json'));
      
      if (response.statusCode == 200) {
        Map<String, dynamic> indexData = Map<String, dynamic>.from(
          (await compute(_parseJson, response.body)) as Map,
        );
        
        String originalTitle = songTitle;
        String sanitizedTitle = _sanitizeTitle(originalTitle);
        
        print('[DEBUG][Maidata] 原始歌曲名: "$originalTitle"');
        print('[DEBUG][Maidata] 处理后歌曲名: "$sanitizedTitle"');
        
        // 策略1: 使用sanitizeTitle精确匹配
        print('[DEBUG][Maidata] 执行策略1: sanitizeTitle精确匹配');
        for (var entry in indexData.entries) {
          String id = entry.key;
          dynamic title = entry.value;
          if (title is String && _sanitizeTitle(title) == sanitizedTitle) {
            MatchResult match = MatchResult(id, title);
            if (!addedIds.contains(match.key)) {
              allMatches.add(match);
              addedIds.add(match.key);
              print('[DEBUG][Maidata] 策略1匹配: ID=$id, 标题="$title"');
            }
          }
        }
        
        // 策略2: 使用jp_transliterate将中文汉字转为日语音读
        print('[DEBUG][Maidata] 执行策略2: jp_transliterate日语音读');
        try {
          if (JpTransliterate.isKanji(input: originalTitle)) {
            final transliterationData = await JpTransliterate.transliterate(kanji: originalTitle);
            String katakanaResult = transliterationData.katakana;
            
            print('[DEBUG][Maidata] jp_transliterate结果: "$originalTitle" -> "$katakanaResult"');
            
            if (katakanaResult.isNotEmpty && katakanaResult != originalTitle) {
              String sanitizedResult = _sanitizeTitle(katakanaResult);
              int originalIdLength = songId.length;
              
              bool foundSameLengthInStrategy1 = allMatches.any((m) => m.id.length == originalIdLength);
              if (foundSameLengthInStrategy1) {
                MatchResult strategy1Match = allMatches.firstWhere(
                  (m) => m.id.length == originalIdLength,
                  orElse: () => MatchResult('', '')
                );
                if (strategy1Match.id.isNotEmpty) {
                  MatchResult newMatch = MatchResult(strategy1Match.id, strategy1Match.title, katakanaResult);
                  if (!addedIds.contains(newMatch.key)) {
                    allMatches.add(newMatch);
                    addedIds.add(newMatch.key);
                    print('[DEBUG][Maidata] 策略2匹配: 使用策略1的ID=${strategy1Match.id}(同位数), 使用片假名标题="$katakanaResult"');
                  }
                }
              }
              
              List<MatchResult> tempMatches = [];
              for (var entry in indexData.entries) {
                String id = entry.key;
                dynamic title = entry.value;
                if (title is String) {
                  MatchResult newMatch = MatchResult(id, title, katakanaResult);
                  if (!addedIds.contains(newMatch.key)) {
                    String indexTitle = _sanitizeTitle(title);
                    if (indexTitle == sanitizedResult ||
                        indexTitle.contains(sanitizedResult) ||
                        sanitizedResult.contains(indexTitle)) {
                      tempMatches.add(newMatch);
                    }
                  }
                }
              }
              
              if (tempMatches.isNotEmpty) {
                for (var match in tempMatches) {
                  allMatches.add(match);
                  addedIds.add(match.key);
                  print('[DEBUG][Maidata] 策略2匹配: ID=${match.id}, 使用片假名标题="$katakanaResult"');
                }
              }
              
              bool hasAnyMatch = allMatches.any((m) => m.id.length == originalIdLength);
              if (!hasAnyMatch) {
                MatchResult newMatch = MatchResult(songId, katakanaResult, katakanaResult);
                if (!addedIds.contains(newMatch.key)) {
                  print('[DEBUG][Maidata] 策略2: 未找到同位数匹配，直接使用片假名构建URL');
                  allMatches.add(newMatch);
                  addedIds.add(newMatch.key);
                }
              }
            } else {
              print('[DEBUG][Maidata] 策略2: 未产生有效片假名');
            }
          } else {
            print('[DEBUG][Maidata] 策略2: 输入不包含汉字，跳过');
          }
        } catch (e) {
          print('[DEBUG][Maidata] 策略2: jp_transliterate异常: $e');
        }
        
        if (allMatches.length > 1) {
          int originalIdLength = songId.length;
          print('[DEBUG][Maidata] 原ID位数: $originalIdLength');
          
          allMatches.sort((a, b) {
            int aScore = a.id.length == originalIdLength ? 1 : 0;
            int bScore = b.id.length == originalIdLength ? 1 : 0;
            if (aScore != bScore) {
              return bScore.compareTo(aScore);
            }
            return a.id.length.compareTo(b.id.length);
          });
          
          print('[DEBUG][Maidata] 排序后的匹配结果: ${allMatches.map((m) => m.id).toList()}');
        }
      }
    } catch (e) {
      print('[DEBUG][Maidata] 获取index.json失败: $e');
    }
    
    return allMatches;
  }

  static Map<String, dynamic> _parseJson(String jsonString) {
    return Map<String, dynamic>.from(json.decode(jsonString) as Map);
  }

  String _buildMaidataUrl(String songId, {String? customTitle, String? serverTitle}) {
    String mappedGenre = _genreMapping[genre] ?? genre;
    String titleToUse = customTitle ?? serverTitle ?? songTitle;
    String sanitizedTitle = _sanitizeTitle(titleToUse);
    
    String fileName = songId;
    fileName += '_$sanitizedTitle';
    
    if (songType == 'DX') {
      fileName += '_DX';
    }
    
    return '${ApiUrls.MaidataServerPortUrl}/$mappedGenre/$fileName/maidata.txt';
  }

  Future<String?> fetchMaidata({
    required void Function(List<String>) onInoteParsed,
  }) async {
    // 首先检查全量缓存
    await MaidataManager().initialize();
    if (MaidataManager().isCacheReady) {
      String? fullCacheContent = MaidataManager().getMaidata(songId);
      if (fullCacheContent != null) {
        print('[DEBUG][Maidata] 使用全量缓存内容');
        List<String> inoteList = _parseInoteList(fullCacheContent);
        onInoteParsed(inoteList);
        return fullCacheContent;
      }
    }
    
    // 其次检查独立缓存
    String? cachedContent = await getCachedMaidata(onInoteParsed: onInoteParsed);
    if (cachedContent != null) {
      print('[DEBUG][Maidata] 使用独立缓存内容');
      return cachedContent;
    }
    
    List<MatchResult> matches = await findAllMatches();
    
    if (matches.isEmpty) {
      return null;
    }
    
    print('[DEBUG][Maidata] 找到 ${matches.length} 个匹配结果');
    
    String? serverTitle;
    for (int i = 0; i < matches.length; i++) {
      MatchResult match = matches[i];
      serverTitle = match.title;
      
      String url = _buildMaidataUrl(match.id, customTitle: match.customUrlTitle, serverTitle: serverTitle);
      print('[DEBUG][Maidata] 尝试第 ${i + 1}/${matches.length} 个匹配: $url');
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        String content = _decodeResponse(response);
        await cacheMaidata(content);
        
        List<String> inoteList = _parseInoteList(content);
        onInoteParsed(inoteList);
        
        print('[DEBUG][Maidata] 请求成功！');
        return content;
      } else if (response.statusCode == 404) {
        print('[DEBUG][Maidata] 404 - 尝试下一个匹配...');
        continue;
      } else {
        return null;
      }
    }
    
    print('[DEBUG][Maidata] 所有匹配均失败，尝试后备机制...');
    return await tryFallbackSearch(onInoteParsed: onInoteParsed);
  }

  Future<String?> getCachedMaidata({
    required void Function(List<String>) onInoteParsed,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String cacheKey = '${CacheKeyConstant.maidataCachePrefix}$songId';
      String? cacheData = prefs.getString(cacheKey);
      
      if (cacheData != null) {
        Map<String, dynamic> data = json.decode(cacheData);
        int timestamp = data['timestamp'] as int;
        String content = data['content'] as String;
        
        int now = DateTime.now().millisecondsSinceEpoch;
        
        if (now - timestamp < CacheTimestampConstant.songMaidataCacheMillis) {
          print('[DEBUG][Maidata] 缓存有效，时间戳: $timestamp');
          List<String> inoteList = _parseInoteList(content);
          onInoteParsed(inoteList);
          return content;
        } else {
          print('[DEBUG][Maidata] 缓存已过期，删除旧缓存');
          await prefs.remove(cacheKey);
        }
      }
    } catch (e) {
      print('[DEBUG][Maidata] 获取缓存失败: $e');
    }
    return null;
  }

  Future<void> cacheMaidata(String content) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String cacheKey = '${CacheKeyConstant.maidataCachePrefix}$songId';
      
      Map<String, dynamic> data = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'content': content,
      };
      
      await prefs.setString(cacheKey, json.encode(data));
      print('[DEBUG][Maidata] 已缓存maidata内容');
    } catch (e) {
      print('[DEBUG][Maidata] 缓存失败: $e');
    }
  }

  List<String> _parseInoteList(String content) {
    List<String> inoteList = [];
    RegExp regex = RegExp(r'&inote_(\d+)');
    Iterable<Match> matches = regex.allMatches(content);
    
    for (Match match in matches) {
      String inoteNum = match.group(1)!;
      if (inoteDifficultyMap.containsKey(inoteNum) && !inoteList.contains(inoteNum)) {
        inoteList.add(inoteNum);
      }
    }
    
    inoteList.sort((a, b) => int.parse(a).compareTo(int.parse(b)));
    print('[DEBUG][Maidata] 解析到 ${inoteList.length} 个inote: $inoteList');
    return inoteList;
  }

  String _decodeResponse(http.Response response) {
    List<int> bytes = response.bodyBytes;
    
    try {
      String utf8String = utf8.decode(bytes);
      if (!utf8String.contains('\uFFFD')) {
        print('[DEBUG][Maidata] 使用UTF-8编码');
        return utf8String;
      }
    } catch (e) {
      print('[DEBUG][Maidata] UTF-8解码失败: $e');
    }
    
    try {
      String shiftJisString = _decodeShiftJis(bytes);
      if (shiftJisString.isNotEmpty && !shiftJisString.contains('\uFFFD')) {
        print('[DEBUG][Maidata] 使用Shift-JIS编码');
        return shiftJisString;
      }
    } catch (e) {
      print('[DEBUG][Maidata] Shift-JIS解码失败: $e');
    }
    
    try {
      String gbkString = _decodeGbk(bytes);
      if (gbkString.isNotEmpty && !gbkString.contains('\uFFFD')) {
        print('[DEBUG][Maidata] 使用GBK编码');
        return gbkString;
      }
    } catch (e) {
      print('[DEBUG][Maidata] GBK解码失败: $e');
    }
    
    try {
      String eucJpString = _decodeEucJp(bytes);
      if (eucJpString.isNotEmpty && !eucJpString.contains('\uFFFD')) {
        print('[DEBUG][Maidata] 使用EUC-JP编码');
        return eucJpString;
      }
    } catch (e) {
      print('[DEBUG][Maidata] EUC-JP解码失败: $e');
    }
    
    print('[DEBUG][Maidata] 使用默认ISO-8859-1编码');
    return response.body;
  }

  String _decodeShiftJis(List<int> bytes) {
    List<int> result = [];
    int i = 0;
    while (i < bytes.length) {
      int byte = bytes[i] & 0xFF;
      if (byte <= 0x7F) {
        result.add(byte);
        i++;
      } else if (byte >= 0x81 && byte <= 0x9F) {
        if (i + 1 < bytes.length) {
          int secondByte = bytes[i + 1] & 0xFF;
          int codePoint = _shiftJisToUnicode(byte, secondByte);
          if (codePoint != 0) {
            result.addAll(_codePointToUtf8(codePoint));
          } else {
            result.add(0xFFFD);
          }
        }
        i += 2;
      } else if (byte >= 0xE0 && byte <= 0xFC) {
        if (i + 1 < bytes.length) {
          int secondByte = bytes[i + 1] & 0xFF;
          int codePoint = _shiftJisToUnicode(byte, secondByte);
          if (codePoint != 0) {
            result.addAll(_codePointToUtf8(codePoint));
          } else {
            result.add(0xFFFD);
          }
        }
        i += 2;
      } else {
        result.add(0xFFFD);
        i++;
      }
    }
    return utf8.decode(result);
  }

  String _decodeGbk(List<int> bytes) {
    List<int> result = [];
    int i = 0;
    while (i < bytes.length) {
      int byte = bytes[i] & 0xFF;
      if (byte <= 0x7F) {
        result.add(byte);
        i++;
      } else {
        if (i + 1 < bytes.length) {
          int secondByte = bytes[i + 1] & 0xFF;
          int codePoint = _gbkToUnicode(byte, secondByte);
          if (codePoint != 0) {
            result.addAll(_codePointToUtf8(codePoint));
          } else {
            result.add(0xFFFD);
          }
        }
        i += 2;
      }
    }
    return utf8.decode(result);
  }

  String _decodeEucJp(List<int> bytes) {
    List<int> result = [];
    int i = 0;
    while (i < bytes.length) {
      int byte = bytes[i] & 0xFF;
      if (byte <= 0x7F) {
        result.add(byte);
        i++;
      } else if (byte >= 0xA1 && byte <= 0xFE) {
        if (i + 1 < bytes.length) {
          int secondByte = bytes[i + 1] & 0xFF;
          if (secondByte >= 0xA1 && secondByte <= 0xFE) {
            int codePoint = _eucJpToUnicode(byte, secondByte);
            if (codePoint != 0) {
              result.addAll(_codePointToUtf8(codePoint));
            } else {
              result.add(0xFFFD);
            }
          }
        }
        i += 2;
      } else {
        result.add(0xFFFD);
        i++;
      }
    }
    return utf8.decode(result);
  }

  int _shiftJisToUnicode(int byte1, int byte2) {
    int row = byte1;
    int col = byte2;
    
    if (row >= 0x81 && row <= 0x9F) {
      row -= 0x81;
    } else if (row >= 0xE0 && row <= 0xFC) {
      row -= 0xC1;
    } else {
      return 0;
    }
    
    if (col <= 0x9F) {
      col -= 0x40;
    } else {
      col -= 0x41;
    }
    
    int offset = row * 188 + col;
    
    if (offset < 0 || offset >= _shiftJisTable.length) {
      return 0;
    }
    
    return _shiftJisTable[offset];
  }

  int _gbkToUnicode(int byte1, int byte2) {
    int offset = ((byte1 - 0x81) << 8) | (byte2 - 0x40);
    if (offset < 0 || offset >= _gbkTable.length) {
      return 0;
    }
    return _gbkTable[offset];
  }

  int _eucJpToUnicode(int byte1, int byte2) {
    int row = byte1 - 0xA1;
    int col = byte2 - 0xA1;
    
    if (row >= 0 && row < 94 && col >= 0 && col < 94) {
      int offset = row * 94 + col;
      if (offset < _jis0208Table.length) {
        return _jis0208Table[offset];
      }
    }
    return 0;
  }

  List<int> _codePointToUtf8(int codePoint) {
    if (codePoint <= 0x7F) {
      return [codePoint];
    } else if (codePoint <= 0x7FF) {
      return [
        0xC0 | ((codePoint >> 6) & 0x1F),
        0x80 | (codePoint & 0x3F)
      ];
    } else if (codePoint <= 0xFFFF) {
      return [
        0xE0 | ((codePoint >> 12) & 0x0F),
        0x80 | ((codePoint >> 6) & 0x3F),
        0x80 | (codePoint & 0x3F)
      ];
    } else {
      return [
        0xF0 | ((codePoint >> 18) & 0x07),
        0x80 | ((codePoint >> 12) & 0x3F),
        0x80 | ((codePoint >> 6) & 0x3F),
        0x80 | (codePoint & 0x3F)
      ];
    }
  }

  Future<String?> tryFallbackSearch({
    required void Function(List<String>) onInoteParsed,
  }) async {
    print('[DEBUG][Maidata] 开始后备搜索...');
    
    try {
      String mappedGenre = _genreMapping[genre] ?? genre;
      print('[DEBUG][Maidata] 搜索流派: $mappedGenre');
      
      String genreUrl = '${ApiUrls.MaidataServerPortUrl}/$mappedGenre/';
      print('[DEBUG][Maidata] 尝试获取文件夹列表: $genreUrl');
      
      final response = await http.get(Uri.parse(genreUrl));
      if (response.statusCode != 200) {
        print('[DEBUG][Maidata] 无法获取文件夹列表: ${response.statusCode}');
        return null;
      }
      
      List<String> folders = _parseFolderList(response.body);
      print('[DEBUG][Maidata] 找到 ${folders.length} 个文件夹');
      
      if (folders.isEmpty) {
        return null;
      }
      
      List<String> candidateIds = await _getCandidateIds();
      print('[DEBUG][Maidata] 候选ID列表: $candidateIds');
      
      for (String folder in folders) {
        String maidataUrl = '$genreUrl$folder/maidata.txt';
        print('[DEBUG][Maidata] 检查: $maidataUrl');
        
        try {
          final maidataResponse = await http.get(Uri.parse(maidataUrl));
          
          if (maidataResponse.statusCode == 200) {
            String content = _decodeResponse(maidataResponse);
            
            for (String id in candidateIds) {
              if (content.contains('&shortid=$id')) {
                print('[DEBUG][Maidata] 找到匹配的maidata.txt! shortid=$id');
                
                await cacheMaidata(content);
                
                List<String> inoteList = _parseInoteList(content);
                onInoteParsed(inoteList);
                
                return content;
              }
            }
          }
        } catch (e) {
          print('[DEBUG][Maidata] 检查文件夹 $folder 时出错: $e');
          continue;
        }
      }
      
      return null;
      
    } catch (e) {
      print('[DEBUG][Maidata] 后备搜索失败: $e');
      return null;
    }
  }

  List<String> _parseFolderList(String htmlContent) {
    List<String> folders = [];
    RegExp linkRegex = RegExp(r'<a\s+href="([^"]+)/?"');
    
    Iterable<Match> matches = linkRegex.allMatches(htmlContent);
    for (Match match in matches) {
      String folder = match.group(1)!;
      if (folder.isNotEmpty && !folder.startsWith('.') && !folder.startsWith('/')) {
        folders.add(folder);
      }
    }
    
    return folders.toSet().toList();
  }

  Future<List<String>> _getCandidateIds() async {
    List<String> candidateIds = [];
    
    try {
      final response = await http.get(Uri.parse('${ApiUrls.MaidataServerPortUrl}/index.json'));
      
      if (response.statusCode == 200) {
        Map<String, dynamic> indexData = Map<String, dynamic>.from(
          (await compute(_parseJson, response.body)) as Map,
        );
        
        String originalTitle = songTitle;
        String sanitizedTitle = _sanitizeTitle(originalTitle);
        
        for (var entry in indexData.entries) {
          String id = entry.key;
          dynamic title = entry.value;
          if (title is String) {
            String indexTitle = _sanitizeTitle(title);
            if (indexTitle == sanitizedTitle ||
                indexTitle.contains(sanitizedTitle) ||
                sanitizedTitle.contains(indexTitle)) {
              candidateIds.add(id);
            }
          }
        }
      }
    } catch (e) {
      print('[DEBUG][Maidata] 获取候选ID失败: $e');
    }
    
    candidateIds.add(songId);
    
    return candidateIds.toSet().toList();
  }

  Future<List<String>> getSongDsList() async {
    List<String> dsList = [];
    try {
      final songs = await MaimaiMusicDataManager().getCachedSongs();
      if (songs != null) {
        for (var song in songs) {
          if (song.id.toString() == songId) {
            dsList = song.ds.map((ds) => ds.toString()).toList();
            break;
          }
        }
      }
    } catch (e) {
      print('[DEBUG][Maidata] 获取定数失败: $e');
    }

    if (dsList.isEmpty) {
      dsList = ['-', '-', '-', '-', '-'];
    } else {
      bool isUtage = songId.length == 6;
      if (!isUtage && dsList.length < 5) {
        while (dsList.length < 5) {
          dsList.add('-');
        }
      }
    }

    return dsList;
  }

  static final List<int> _shiftJisTable = [];
  static final List<int> _gbkTable = [];
  static final List<int> _jis0208Table = [];
}