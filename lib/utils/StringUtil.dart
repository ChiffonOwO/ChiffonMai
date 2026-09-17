/**
 * 字符串工具类
 * 用于处理字符串相关的操作
 */
class StringUtil {
  // ═══════════════════════════════════════════════════════════════
  // 版本格式化 — 私有辅助
  // ═══════════════════════════════════════════════════════════════

  /// 版本名归一化：把各数据源的写法统一成「maimai でらっくす X」。
  ///
  /// 需要处理的三种写法（都是实测遇到的）：
  ///   * `maimaiでらっくす`（无空格）——dxrating 的 `songs[].version` 就是这种；
  ///   * `maimai DX X`——历史报文里出现过的英文前缀；
  ///   * 首尾空白。
  ///
  /// **必须先归一化再查表**，否则四个公开函数的粒度会不一致：
  /// 以前 `formatVersion2('maimai DX PRiSM')` 返回短名 `PRiSM`，
  /// 而 `formatVersion2('maimai でらっくす PRiSM')` 返回 `DX 2025 鏡`。
  static String _normalizeVersion(String version) {
    var v = version.trim();
    if (v.isEmpty) return v;
    v = v.replaceFirst('maimaiでらっくす', 'maimai でらっくす');
    if (v == 'maimai DX') return 'maimai でらっくす';
    if (v.startsWith('maimai DX ')) {
      v = 'maimai でらっくす ${v.substring('maimai DX '.length)}';
    }
    // 拼写别名：官方写法是 MAGiCAL（SEGA 9/17 稼働公告），MEGiCAL 按笔误处理。
    // 放在归一化里而不是查表里，保证 extra 路径（只去前缀、不查表）也一致。
    v = v.replaceAll('MEGiCAL', 'MAGiCAL');
    return v;
  }

  /// extra 曲目 / 英文 DX 前缀：把版本名缩成「去前缀 + PLUS→+」。
  ///
  /// 返回 null 表示「这条输入不该走缩写路径」，交给常规查表。设计要点：
  ///   * 先做 ` PLUS`→`+`：`maimai PLUS` 要靠前导空格才能变成 `maimai+`；
  ///   * 再去前缀：`maimai ` → `でらっくす `，于是
  ///     `maimai でらっくす` → `でらっくす`、
  ///     `maimai でらっくす PLUS` → `でらっくす+`、
  ///     `maimai でらっくす Splash` → `Splash`、
  ///     `maimai GreeN` → `GreeN`（旧代也一视同仁地去掉前缀，与 DX 代保持一致）。
  ///
  /// 以前这里先剥 `maimai でらっくす `（带空格），于是
  /// `maimai でらっくす PLUS` 会剩下光秃秃的 `PLUS`、`maimai GreeN` 又原样保留，
  /// 同一条规则下两种结果，属于本次修掉的问题。
  static String? _tryExtraOrDx(String version, bool isExtra) {
    if (!isExtra && !version.startsWith('maimai DX ')) return null;
    var s = version;
    s = s.replaceFirst(' PLUS', '+');
    s = s.replaceFirst('maimai でらっくす ', '');
    s = s.replaceFirst('maimai DX ', '');
    s = s.replaceFirst('maimai ', '');
    s = s.replaceFirst('でらっくす ', '');
    if (s.isEmpty) return null;
    return s;
  }

  /// 旧代版本 → 短名称
  static const Map<String, String> _oldSimple = {
    'maimai': 'maimai',
    'maimai PLUS': 'maimai+',
    // 水鱼写 'MiLK PLUS'（无前缀），union 写 'maimai MiLK PLUS'（有前缀），
    // 两种都要收——否则 union 那 55 首在详名路径会原样吐出原文。
    'MiLK PLUS': 'MiLK+',
    'maimai MiLK PLUS': 'MiLK+',
  };

  /// 旧代版本 → 详细名称（带 超/檄 等）
  static const Map<String, String> _oldDetailed = {
    'maimai': 'maimai 真',
    'maimai PLUS': 'maimai+ 真',
    'maimai GreeN': 'GreeN 超',
    'maimai GreeN PLUS': 'GreeN+ 檄',
    'maimai ORANGE': 'ORANGE 橙',
    'maimai ORANGE PLUS': 'ORANGE+ 暁',
    'maimai PiNK': 'PiNK 桃',
    'maimai PiNK PLUS': 'PiNK+ 櫻',
    'maimai MURASAKi': 'MURASAKi 紫',
    'maimai MURASAKi PLUS': 'MURASAKi+ 菫',
    'maimai MiLK': 'MiLK 白',
    'MiLK PLUS': 'MiLK+ 雪',
    'maimai MiLK PLUS': 'MiLK+ 雪', // union 的写法（与上一行同一个版本）
    'maimai FiNALE': 'FiNALE 輝',
  };

  /// extra 曲目专用的 DX 世代显示。
  ///
  /// 口径（用户指定）：
  ///   * **短名**：去前缀的世代名，不带年号 —— `DX`、`DX+`、`Splash`、`BUDDiES+`…
  ///     （带年号的 `DX 2020` / `DX 2020 熊/華` 是 **extra=false 专属**）；
  ///   * **详名**：短名 + 该世代的「一文字」—— `DX 熊`、`Splash 爽`、`CiRCLE+ 廻`…
  ///     即 extra 与 extra=false 的详名只差年号，汉字口径完全一致。
  ///
  /// ⚠️ `MAGiCAL` 的一文字暂无可靠来源（SEGA 只公布了版本名），
  /// 暂按原名输出，等确认后补一行即可。
  static const Map<String, String> _dxExtraSimple = {
    '': 'DX',
    'PLUS': 'DX+',
    'Splash': 'Splash',
    'Splash PLUS': 'Splash+',
    'UNiVERSE': 'UNiVERSE',
    'UNiVERSE PLUS': 'UNiVERSE+',
    'FESTiVAL': 'FESTiVAL',
    'FESTiVAL PLUS': 'FESTiVAL+',
    'BUDDiES': 'BUDDiES',
    'BUDDiES PLUS': 'BUDDiES+',
    'PRiSM': 'PRiSM',
    'PRiSM PLUS': 'PRiSM+',
    'CiRCLE': 'CiRCLE',
    'CiRCLE PLUS': 'CiRCLE+',
    'MAGiCAL': 'MAGiCAL',
  };

  /// extra 曲目专用的 DX 世代详名（短名 + 一文字）。
  static const Map<String, String> _dxExtraDetailed = {
    '': 'DX 熊',
    'PLUS': 'DX+ 華',
    'Splash': 'Splash 爽',
    'Splash PLUS': 'Splash+ 煌',
    'UNiVERSE': 'UNiVERSE 宙',
    'UNiVERSE PLUS': 'UNiVERSE+ 星',
    'FESTiVAL': 'FESTiVAL 祭',
    'FESTiVAL PLUS': 'FESTiVAL+ 祝',
    'BUDDiES': 'BUDDiES 双',
    'BUDDiES PLUS': 'BUDDiES+ 宴',
    'PRiSM': 'PRiSM 鏡',
    'PRiSM PLUS': 'PRiSM+ 彩',
    'CiRCLE': 'CiRCLE 丸',
    'CiRCLE PLUS': 'CiRCLE+ 廻',
    // MAGiCAL：一文字待确认，先与短名一致
    'MAGiCAL': 'MAGiCAL',
  };

  /// DX 代（日文格式）后缀 → 短名称。
  ///
  /// 命名口径（与国服世代对齐，这也是详名里出现「熊/華」这种一对汉字的原因）：
  ///   * 国服把「世代 + 它的 PLUS」算作同一年度版本，所以
  ///     `Splash` 与 `Splash PLUS` 都属 `DX 2021`；但**显示上仍然区分**，
  ///     PLUS 用 `Splash+`（定数历史表里两个版本会是两列，不能合并成同名）；
  ///   * `PRiSM PLUS` 是例外：国服把它单独立为 `舞萌DX 2026`，所以它有自己的年号；
  ///   * `CiRCLE` 起国服还没上线，没有年号，直接用世代名（`CiRCLE` / `CiRCLE+` /
  ///     `MAGiCAL`）。
  static const Map<String, String> _dxSimple = {
    '': 'DX 2020',
    'PLUS': 'でらっくす+',
    'Splash': 'DX 2021',
    'Splash PLUS': 'Splash+',
    'UNiVERSE': 'DX 2022',
    'UNiVERSE PLUS': 'UNiVERSE+',
    'FESTiVAL': 'DX 2023',
    'FESTiVAL PLUS': 'FESTiVAL+',
    'BUDDiES': 'DX 2024',
    'BUDDiES PLUS': 'BUDDiES+',
    'PRiSM': 'DX 2025',
    'PRiSM PLUS': 'DX 2026',
    // 国服尚未上线（水鱼数据里还没有）：没有年号，直接用世代名
    'CiRCLE': 'CiRCLE',
    'CiRCLE PLUS': 'CiRCLE+',
    'MAGiCAL': 'MAGiCAL',
  };

  /// DX 代（日文格式）后缀 → 详细名称（带 熊/華 等）。
  ///
  /// 与 [_dxSimple] 同一口径；PLUS 世代给「短名 + 自己的汉字」，
  /// 保持与基础世代可区分（基础世代的 `DX 20xx X/Y` 里的 Y 是 PLUS 的汉字）。
  static const Map<String, String> _dxDetailed = {
    '': 'DX 2020 熊/華',
    'PLUS': 'でらっくす+ 華',
    'Splash': 'DX 2021 爽/煌',
    'Splash PLUS': 'Splash+ 煌',
    'UNiVERSE': 'DX 2022 宙/星',
    'UNiVERSE PLUS': 'UNiVERSE+ 星',
    'FESTiVAL': 'DX 2023 祭/祝',
    'FESTiVAL PLUS': 'FESTiVAL+ 祝',
    'BUDDiES': 'DX 2024 双/宴',
    'BUDDiES PLUS': 'BUDDiES+ 宴',
    'PRiSM': 'DX 2025 鏡',
    'PRiSM PLUS': 'DX 2026 彩',
    'CiRCLE': 'CiRCLE 丸',
    'CiRCLE PLUS': 'CiRCLE+',
    'MAGiCAL': 'MAGiCAL',
  };

  /// 日文 DX 代 lookup（含 PLUS 变体，用于 -WithFlag 系列）
  static String? _lookupDxWithPlus(String version, Map<String, String> map) {
    const prefixWithSpace = 'maimai でらっくす ';
    const prefixNoSpace = 'maimai でらっくす';
    String suffix;
    if (version.startsWith(prefixWithSpace)) {
      suffix = version.substring(prefixWithSpace.length);
    } else if (version == prefixNoSpace) {
      suffix = '';
    } else {
      return null;
    }
    if (map.containsKey(suffix)) return map[suffix];
    // 对 2020-2024：同时检查 "X" 和 "X PLUS"
    if (!suffix.endsWith(' PLUS')) {
      final plusKey = '$suffix PLUS';
      if (map.containsKey(plusKey)) return map[plusKey];
    }
    return null;
  }

  /// 日文 DX 代 lookup（精确匹配，用于 formatVersion / formatVersion2）
  static String? _lookupDxExact(String version, Map<String, String> map) {
    const prefixWithSpace = 'maimai でらっくす ';
    const prefixNoSpace = 'maimai でらっくす';
    String suffix;
    if (version.startsWith(prefixWithSpace)) {
      suffix = version.substring(prefixWithSpace.length);
    } else if (version == prefixNoSpace) {
      suffix = '';
    } else {
      return null;
    }
    return map[suffix];
  }

  /// 通用后缀处理：PLUS → +，去除 maimai / でらっくす 前缀
  static String _genericFallback(String version) {
    if (version.contains(' PLUS')) {
      version = version.replaceFirst(' PLUS', '+');
    }
    if (version.contains('maimai') && version != 'maimai') {
      version = version.replaceFirst('maimai ', '');
    }
    if (version.contains('でらっくす')) {
      version = version.replaceFirst('でらっくす ', '');
    }
    return version;
  }

  // ═══════════════════════════════════════════════════════════════
  // 公开 API
  // ═══════════════════════════════════════════════════════════════

  static String formatVersion(String version) {
    version = _normalizeVersion(version);
    final r = _tryExtraOrDx(version, false);
    if (r != null) return r;
    if (_oldSimple.containsKey(version)) return _oldSimple[version]!;
    final dx = _lookupDxExact(version, _dxSimple);
    if (dx != null) return dx;
    return _genericFallback(version);
  }

  static String formatVersion2(String version) {
    version = _normalizeVersion(version);
    final r = _tryExtraOrDx(version, false);
    if (r != null) return r;
    if (_oldDetailed.containsKey(version)) return _oldDetailed[version]!;
    final dx = _lookupDxExact(version, _dxDetailed);
    if (dx != null) return dx;
    return version;
  }

  static String formatVersionWithFlag(String version, bool isExtra) {
    version = _normalizeVersion(version);
    // extra 曲目的 DX 基础两代：DX / DX+（不带年号，年号是 extra=false 专属）
    if (isExtra) {
      final dxBase = _lookupDxExact(version, _dxExtraSimple);
      if (dxBase != null) return dxBase;
    }
    final r = _tryExtraOrDx(version, isExtra);
    if (r != null) return r;
    if (_oldSimple.containsKey(version)) return _oldSimple[version]!;
    final dx = _lookupDxWithPlus(version, _dxSimple);
    if (dx != null) return dx;
    return _genericFallback(version);
  }

  static String formatVersion2WithFlag(String version, bool isExtra) {
    version = _normalizeVersion(version);
    // extra 曲目的详名：短名 + 一文字（不带年号，年号是 extra=false 专属）。
    // 旧代没有年号，详名与 extra=false 完全一致，所以先查旧代表。
    if (isExtra) {
      final dxExtra = _lookupDxExact(version, _dxExtraDetailed);
      if (dxExtra != null) return dxExtra;
      if (_oldDetailed.containsKey(version)) return _oldDetailed[version]!;
    }
    final r = _tryExtraOrDx(version, isExtra);
    if (r != null) return r;
    if (_oldDetailed.containsKey(version)) return _oldDetailed[version]!;
    final dx = _lookupDxWithPlus(version, _dxDetailed);
    if (dx != null) return dx;
    return version;
  }

  /**
   * 格式化FC字符串
   * @param fc FC字符串
   * @return 格式化后的FC字符串
   */
  static String formatFC(String fc) {
    if (fc == 'fcp') {
      return 'FC+';
    } else if (fc == 'fc') {
      return 'FC';
    } else if (fc == 'ap') {
      return 'AP';
    } else if (fc == 'app') {
      return 'AP+';
    }
    return fc;
  }

  /**
   * 格式化FS字符串
   * @param fs FS字符串
   * @return 格式化后的FS字符串
   */
  static String formatFS(String fs) {
    if (fs == 'fsd') {
      return 'FDX';
    } else if (fs == 'fsp') {
      return 'FS+';
    } else if (fs == 'fs') {
      return 'FS';
    } else if (fs == 'sync') {
      return 'SC';
    } else if (fs == 'fsdp') {
      return 'FDX+';
    }
    return fs;
  }

  /**
   * 格式化等级字符串
   * @param rate 等级字符串
   * @return 格式化后的等级字符串
   */
  static String formatRate(String rate) {
    if (rate == 'sssp') {
      return 'SSS+';
    } else if (rate == 'sss') {
      return 'SSS';
    } else if (rate == 'ssp') {
      return 'SS+';
    } else if (rate == 'ss') {
      return 'SS';
    } else if (rate == 'sp') {
      return 'S+';
    } else if (rate == 's') {
      return 'S';
    } else if (rate == 'aaa') {
      return 'AAA';
    } else if (rate == 'aa') {
      return 'AA';
    } else if (rate == 'a') {
      return 'A';
    } else if (rate == 'bbb') {
      return 'BBB';
    } else if (rate == 'bb') {
      return 'BB';
    } else if (rate == 'b') {
      return 'B';
    } else if (rate == 'c') {
      return 'C';
    } else if (rate == 'd') {
      return 'D';
    }
    return rate;
  }

  /**
   * 由达成率反推评级代码（用于 assets/gamrank/<code>.png）。
   * 阈值与 ScoreOcrPage 的 _achievementGrade 保持一致。
   * @param achievement 达成率（百分比数值，如 100.5）
   * @return 评级代码（sssp/sss/ssp/ss/.../d）
   */
  static String rateCodeFromAchievement(double achievement) {
    if (achievement >= 100.5) return 'sssp';
    if (achievement >= 100.0) return 'sss';
    if (achievement >= 99.5) return 'ssp';
    if (achievement >= 99.0) return 'ss';
    if (achievement >= 98.0) return 'sp';
    if (achievement >= 97.0) return 's';
    if (achievement >= 94.0) return 'aaa';
    if (achievement >= 90.0) return 'aa';
    if (achievement >= 80.0) return 'a';
    if (achievement >= 75.0) return 'bbb';
    if (achievement >= 70.0) return 'bb';
    if (achievement >= 60.0) return 'b';
    if (achievement >= 50.0) return 'c';
    return 'd';
  }

  /**
   * 格式化星星等级字符串
   * @param scoreRate 得分率
   * @return 格式化后的星星等级字符串
   */
  static String formatStars(num scoreRate) {
    if (scoreRate >= 0.99) {
      return '✦6';
    } else if (scoreRate >= 0.98) {
      return '✦5.5';
    } else if (scoreRate >= 0.97) {
      return '✦5';
    } else if (scoreRate >= 0.95) {
      return '✦4';
    } else if (scoreRate >= 0.93) {
      return '✦3';
    } else if (scoreRate >= 0.90) {
      return '✦2';
    } else if (scoreRate >= 0.85) {
      return '✦1';
    } else {
      return '✦0';
    }
  }

  /**
   * 格式化歌曲类型字符串
   * @param type 歌曲类型字符串
   * @return 格式化后的歌曲类型字符串
   */
  static String formatSongType(String type) {
    if (type == "DX") return "DX";
    if (type == "SD") return "ST";
    if (type == "utage") return "UTAGE";
    return "ST";
  }

  /**
   * 获取歌曲类型显示文本
   * @param type 歌曲类型字符串
   * @return 格式化后的类型显示文本
   */
  static String getTypeDisplay(String type) {
    if (type == 'DX') return 'DX';
    if (type == 'SD') return 'ST';
    if (type == 'utage') return 'UTAGE';
    return type;
  }

  /**
   * 将全角字符转换为半角字符
   * @param input 输入字符串
   * @return 转换后的半角字符串
   *
   * 全角字符范围：U+FF00-U+FFEF
   * 转换规则：全角字符的 Unicode 值减去 0xFEE0 得到对应的半角字符
   */
  static String toHalfWidth(String input) {
    if (input.isEmpty) {
      return input;
    }

    StringBuffer result = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      int charCode = input.codeUnitAt(i);
      // 全角空格特殊处理（U+3000 -> U+0020）
      if (charCode == 0x3000) {
        result.writeCharCode(0x0020);
      }
      // 其他全角字符（U+FF01-U+FF5E）转换为半角
      else if (charCode >= 0xFF01 && charCode <= 0xFF5E) {
        result.writeCharCode(charCode - 0xFEE0);
      }
      // 保持其他字符不变
      else {
        result.writeCharCode(charCode);
      }
    }
    return result.toString();
  }
}
