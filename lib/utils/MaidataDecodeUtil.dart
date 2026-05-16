import 'package:flutter/foundation.dart';
import '../entity/Song.dart';

class MaidataDecodeUtil {
  // 正则：匹配 {数字} 或 (数字)
  static final RegExp _patternPlaceholder = RegExp(r'^\{\d+}$|^\(\d+\)$');
  // 正则：匹配 &inote_num=数字
  static final RegExp _patternInote = RegExp(r'^&inote_num=\d+$');
  // 正则：匹配 (数字){数字} 形式，如 (216){1}
  static final RegExp _patternParenthesisBrace = RegExp(r'^\(\d+\)\{\d+}$');
  // 正则：匹配 HOLD 模式，如 6h[4:1], Ch[4:3]
  static final RegExp _patternHold = RegExp(r'.*h\[\d+:\d+\].*');
  // 正则：匹配 TOUCH 模式，如 E7, C1f
  static final RegExp _patternTouch = RegExp(r'.*[A-G]\d+f?.*');
  // 正则：匹配纯数字或数字x形式，如 1, 2, 1x, 2x
  static final RegExp _patternTap = RegExp(r'^\d+x?$');
  // 正则：匹配修饰符（用于分割）
  static final RegExp _patternModifiers = RegExp(r'(?=[-<>^vpszwVpq]|pp|qq)');
  // 正则：匹配中括号
  static final RegExp _patternBracket = RegExp(r'.*\[.*\].*');

  static MaidataData decode(String content) {
    Map<String, String> data = {};
    
    // 使用正则表达式处理不同的换行符格式
    List<String> lines = content.split(RegExp(r'\r?\n'));
    
    // 当前正在累积的key（用于处理多行值）
    String? currentKey;
    StringBuffer currentValue = StringBuffer();
    
    for (String line in lines) {
      // 保存原始行（不trim）用于累积
      String originalLine = line;
      line = line.trim();
      
      // 如果当前正在累积多行值
      if (currentKey != null) {
        // 如果遇到新的&开头的行，说明上一个key的值结束了
        if (line.startsWith('&')) {
          // 保存当前累积的值
          String value = currentValue.toString().trim();
          if (value.isNotEmpty) {
            data[currentKey] = value;
            data[currentKey.toLowerCase()] = value;
          }
          
          // 重置累积状态
          currentKey = null;
          currentValue.clear();
        } else {
          // 继续累积值（保留原始格式）
          if (currentValue.isNotEmpty) {
            currentValue.write('\n');
          }
          currentValue.write(originalLine);
          continue;
        }
      }
      
      // 只有在没有累积多行值时才跳过空行
      if (line.isEmpty) {
        continue;
      }
      
      if (line.startsWith('&')) {
        int idx = line.indexOf('=');
        if (idx > 0) {
          String key = line.substring(0, idx);
          String value = idx < line.length - 1 ? line.substring(idx + 1) : '';
          
          // 如果值为空，可能是多行值的开始
          if (value.isEmpty) {
            currentKey = key;
            currentValue.clear();
          } else {
            data[key] = value;
            data[key.toLowerCase()] = value;
          }
        }
      }
    }
    
    // 处理最后一个累积的key
    if (currentKey != null) {
      String value = currentValue.toString().trim();
      if (value.isNotEmpty) {
        data[currentKey] = value;
        data[currentKey.toLowerCase()] = value;
      }
    }
    
    // 额外处理：使用正则表达式直接提取 inote 字段（作为备用方法）
    for (int i = 2; i <= 6; i++) {
      // 尝试使用正则表达式提取 inote 字段
      RegExp inoteRegex = RegExp(r'&inote_' + i.toString() + r'=(.*?)(?=\s*&|$)', 
          multiLine: true, dotAll: true);
      Match? match = inoteRegex.firstMatch(content);
      if (match != null) {
        String inoteValue = match.group(1)?.trim() ?? '';
        if (inoteValue.isNotEmpty) {
          data['&inote_$i'] = inoteValue;
          data['&inote_$i'.toLowerCase()] = inoteValue;
        }
      }
    }

    List<ChartData> charts = [];
    for (int i = 2; i <= 7; i++) {
      // 尝试多种可能的key格式
      String? level = data['&lv_$i'] ?? data['&LV_$i'] ?? data['&Lv_$i'] ?? data['&lv_${i}'];
      String? charter = data['&des_$i'] ?? data['&DES_$i'] ?? data['&Des_$i'];
      
      // 尝试多种可能的inote字段名
      String? inote;
      List<String> inoteKeyVariants = [
        '&inote_$i', '&INOTE_$i', '&Inote_$i', '&iNote_$i',
        '&inote${i}', '&INOTE${i}', '&note_$i', '&Note_$i',
        '&inote_${i}', '&INOTE_${i}',
        '&inote_$i'.toLowerCase(), '&INOTE_$i'.toLowerCase(),
      ];
      for (String key in inoteKeyVariants) {
        if (data.containsKey(key)) {
          inote = data[key];
          break;
        }
      }
      
      NoteStats? stats;
      if (inote != null && inote.isNotEmpty) {
        stats = parseInote(inote);
      }
      
      if (level != null || charter != null || inote != null) {
        charts.add(ChartData(
          difficultyIndex: i,
          level: level ?? '',
          charter: charter ?? '',
          inote: inote ?? '',
          stats: stats,
        ));
      }
    }

    return MaidataData(
      title: data['&title'] ?? '',
      wholeBpm: int.tryParse(data['&wholebpm'] ?? '') ?? 0,
      artist: data['&artist'] ?? '',
      artistId: int.tryParse(data['&artistid'] ?? '') ?? 0,
      shortId: int.tryParse(data['&shortid'] ?? '') ?? 0,
      genre: data['&genre'] ?? '',
      genreId: int.tryParse(data['&genreid'] ?? '') ?? 0,
      cabinet: data['&cabinet'] ?? '',
      version: data['&version'] ?? '',
      charts: charts,
      rawContent: content,
    );
  }

  static List<String> parseSlideSegments(String segment) {
    List<String> parts = [];
    List<String> splitParts = segment.split(_patternModifiers);

    bool isFirst = true;
    for (String part in splitParts) {
      if (part.isEmpty) continue;

      if (part.contains("[")) {
        parts.add(part);
        isFirst = false;
      } else if (isFirst) {
        parts.add(part);
        isFirst = false;
      }
    }
    return parts;
  }

  static List<String> extractValidSegments(String text) {
    List<String> result = [];

    // 1. 按逗号分割所有片段
    List<String> segments = text.split(",");

    // 2. 遍历清洗
    for (String seg in segments) {
      // 去首尾空白
      String clean = seg.trim();

      // 移除所有 {数字}、(数字)、(小数) 模式
      clean = clean.replaceAll(RegExp(r'\{\d+}'), '');
      clean = clean.replaceAll(RegExp(r'\(\d+\)'), '');
      clean = clean.replaceAll(RegExp(r'\(\d+\.\d+\)'), '');

      // 跳过空字符串
      if (clean.isEmpty) continue;

      // 跳过 {数字} / (数字)
      if (_patternPlaceholder.hasMatch(clean)) continue;

      // 跳过 (数字){数字} 形式
      if (_patternParenthesisBrace.hasMatch(clean)) continue;

      // 跳过单独 E
      if (clean == "E") continue;

      // 跳过 &inote_num=数字
      if (_patternInote.hasMatch(clean)) continue;

      // 如果包含 / 则拆分
      if (clean.contains("/")) {
        List<String> parts = clean.split("/");
        for (String part in parts) {
          String trimmedPart = part.trim();
          if (trimmedPart.isNotEmpty) {
            _processSegment(trimmedPart, result);
          }
        }
      } else {
        _processSegment(clean, result);
      }
    }

    return result;
  }

  static void _processSegment(String segment, List<String> result) {
    bool hasModifier = segment.contains(RegExp(r'[-<>^vpqszwV]')) ||
        segment.contains("pp") ||
        segment.contains("qq");

    if (hasModifier) {
      List<String> parsedParts = parseSlideSegments(segment);
      result.addAll(parsedParts);
    } else {
      result.add(segment);
    }
  }

  static NoteType classifyNote(String note) {
    if (note.contains("b")) {
      return NoteType.BREAK;
    }
    if (_patternHold.hasMatch(note)) {
      return NoteType.HOLD;
    }
    if (_patternTouch.hasMatch(note)) {
      return NoteType.TOUCH;
    }
    if (_patternTap.hasMatch(note)) {
      return NoteType.TAP;
    }
    if (_patternBracket.hasMatch(note)) {
      return NoteType.SLIDE;
    }
    //debugPrint("[DEBUG] Unknown type: '$note'");
    return NoteType.SLIDE;
  }

  static List<int> countNoteTypes(List<String> notes) {
    List<int> counts = List.filled(NoteType.values.length, 0);
    for (String note in notes) {
      NoteType type = classifyNote(note);
      counts[type.index]++;
    }
    return counts;
  }

  static List<List<String>> collectByType(List<String> notes) {
    List<List<String>> result = List.generate(NoteType.values.length, (_) => []);
    for (String note in notes) {
      NoteType type = classifyNote(note);
      result[type.index].add(note);
    }
    return result;
  }

  static void debugPrintGroups(List<String> notes) {
    List<List<String>> groups = collectByType(notes);
    List<NoteType> types = NoteType.values;
    debugPrint('===== 各类型字符组集合 =====');
    for (int i = 0; i < types.length; i++) {
      List<String> group = groups[i];
      debugPrint('${types[i]}: 共 ${group.length} 个');
      int batchSize = 30;
      for (int j = 0; j < group.length; j += batchSize) {
        int end = j + batchSize;
        if (end > group.length) end = group.length;
        List<String> batch = group.sublist(j, end);
        debugPrint('  [${j+1}-$end]: ${batch.join(', ')}');
      }
      if (i < types.length - 1) {
        debugPrint('----------------------------');
      }
    }
  }

  static NoteStats parseInote(String inote) {
    List<String> validSegments = extractValidSegments(inote);
    List<int> counts = countNoteTypes(validSegments);
    
    //debugPrintGroups(validSegments);
    
    return NoteStats(
      total: validSegments.length,
      tap: counts[NoteType.TAP.index],
      hold: counts[NoteType.HOLD.index],
      slide: counts[NoteType.SLIDE.index],
      breakNote: counts[NoteType.BREAK.index],
      touch: counts[NoteType.TOUCH.index],
    );
  }

  static Song toSong(MaidataData maidata) {
    List<double> ds = [];
    List<String> level = [];
    List<int> cids = [];
    List<Chart> charts = [];
    
    List<int> availableDifficulties = maidata.charts
        .map((c) => c.difficultyIndex)
        .where((idx) => idx >= 2 && idx <= 7)
        .toList()
        ..sort();
    
    bool hasFewDifficulties = availableDifficulties.length <= 2;
    
    for (int diffIdx in availableDifficulties) {
      ChartData chartData = maidata.charts.firstWhere(
        (c) => c.difficultyIndex == diffIdx,
      );
      
      double? dsValue = _parseLevelToDs(chartData.level);
      ds.add(dsValue ?? 0.0);
      
      String levelStr;
      if (hasFewDifficulties) {
        levelStr = _convertDsToLevelUncertain(dsValue ?? 0.0);
      } else {
        levelStr = _convertDsToLevel(dsValue ?? 0.0);
      }
      level.add(levelStr);
      
      cids.add(0);
      
      List<int> notes = [];
      if (chartData.stats != null) {
        notes = [
          chartData.stats!.tap,
          chartData.stats!.hold,
          chartData.stats!.slide,
          chartData.stats!.breakNote,
          chartData.stats!.touch,
        ];
      } else {
        notes = [0, 0, 0, 0, 0];
      }
      
      charts.add(Chart(
        notes: notes,
        charter: chartData.charter,
      ));
    }
    
    String type = _determineType(maidata.cabinet);
    
    return Song(
      id: maidata.shortId.toString(),
      title: maidata.title,
      type: type,
      ds: ds,
      level: level,
      cids: cids,
      charts: charts,
      basicInfo: BasicInfo(
        title: maidata.title,
        artist: maidata.artist,
        genre: _mapGenre(maidata.genre),
        bpm: maidata.wholeBpm,
        releaseDate: '',
        from: maidata.version,
        isNew: false,
      ),
    );
  }
  
  static String _convertDsToLevelUncertain(double ds) {
    if (ds <= 0) return '?';
    
    int integerPart = ds.floor();
    double decimalPart = ds - integerPart;
    
    if (decimalPart >= 0.6) {
      return '${integerPart}+?';
    } else {
      return '${integerPart}?';
    }
  }
  
  static String _mapGenre(String genre) {
    final Map<String, String> genreMapping = {
      'maimai': '舞萌',
      'POPSアニメ': '流行&动漫',
      'niconicoボーカロイド': 'niconico & VOCALOID',
      'ゲームバラエティ': '其他游戏',
      '東方Project': '东方Project',
      'オンゲキCHUNITHM': '音击&中二节奏',
    };
    return genreMapping[genre] ?? genre;
  }
  
  static String _determineType(String cabinet) {
    if (cabinet.toUpperCase() == 'DX') {
      return 'DX';
    } else if (cabinet.toUpperCase() == 'SD') {
      return 'SD';
    } else {
      return 'UTAGE';
    }
  }
  
  static double? _parseLevelToDs(String levelStr) {
    if (levelStr.isEmpty) return null;
    
    String str = levelStr.replaceAll('?', '');
    
    if (str.contains('+')) {
      String numPart = str.replaceAll('+', '');
      int? intPart = int.tryParse(numPart);
      if (intPart != null) {
        return intPart + 0.6;
      }
    }
    
    double? parsed = double.tryParse(str);
    if (parsed != null) {
      return parsed;
    }
    
    return null;
  }
  
  static String _convertDsToLevel(double ds) {
    if (ds <= 0) return '?';
    
    int integerPart = ds.floor();
    double decimalPart = ds - integerPart;
    
    if (decimalPart >= 0.6) {
      return '${integerPart}+';
    } else {
      return '$integerPart';
    }
  }
}

enum NoteType {
  TAP,
  HOLD,
  SLIDE,
  BREAK,
  TOUCH,
}

class NoteStats {
  final int total;
  final int tap;
  final int hold;
  final int slide;
  final int breakNote;
  final int touch;

  NoteStats({
    required this.total,
    required this.tap,
    required this.hold,
    required this.slide,
    required this.breakNote,
    required this.touch,
  });

  @override
  String toString() {
    return 'NoteStats{total: $total, tap: $tap, hold: $hold, slide: $slide, break: $breakNote, touch: $touch}';
  }
}

class ChartData {
  final int difficultyIndex;
  final String level;
  final String charter;
  final String inote;
  final NoteStats? stats;

  ChartData({
    required this.difficultyIndex,
    required this.level,
    required this.charter,
    required this.inote,
    this.stats,
  });

  String get difficultyName {
    switch (difficultyIndex) {
      case 1: return 'EASY';
      case 2: return 'BASIC';
      case 3: return 'ADVANCED';
      case 4: return 'EXPERT';
      case 5: return 'MASTER';
      case 6: return 'RE:MASTER';
      default: return 'UNKNOWN';
    }
  }
}

class MaidataData {
  final String title;
  final int wholeBpm;
  final String artist;
  final int artistId;
  final int shortId;
  final String genre;
  final int genreId;
  final String cabinet;
  final String version;
  final List<ChartData> charts;
  final String rawContent;

  MaidataData({
    required this.title,
    required this.wholeBpm,
    required this.artist,
    required this.artistId,
    required this.shortId,
    required this.genre,
    required this.genreId,
    required this.cabinet,
    required this.version,
    required this.charts,
    required this.rawContent,
  });
}