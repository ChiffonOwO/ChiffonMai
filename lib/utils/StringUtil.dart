/**
 * 字符串工具类
 * 用于处理字符串相关的操作
 */
class StringUtil {
  // ═══════════════════════════════════════════════════════════════
  // 版本格式化 — 私有辅助
  // ═══════════════════════════════════════════════════════════════

  /// 处理 isExtra / maimai DX 前缀 → 返回短名称。
  /// 未命中返回 null，由调用方继续常规 lookup。
  static String? _tryExtraOrDx(String version, bool isExtra) {
    if (isExtra || version.startsWith('maimai DX ')) {
      version = version.replaceFirst('maimai でらっくす ', '');
      version = version.replaceFirst('maimai DX ', '');
      version = version.replaceFirst(' PLUS', '+');
      return version;
    }
    return null;
  }

  /// 旧代版本 → 短名称
  static const Map<String, String> _oldSimple = {
    'maimai': 'maimai',
    'maimai PLUS': 'maimai+',
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
    'maimai FiNALE': 'FiNALE 輝',
  };

  /// DX 代（日文格式）后缀 → 短名称
  static const Map<String, String> _dxSimple = {
    '': 'DX 2020',
    'Splash': 'DX 2021',
    'UNiVERSE': 'DX 2022',
    'FESTiVAL': 'DX 2023',
    'BUDDiES': 'DX 2024',
    'PRiSM': 'DX 2025',
    'PRiSM PLUS': 'DX 2026',
  };

  /// DX 代（日文格式）后缀 → 详细名称（带 熊/華 等）
  static const Map<String, String> _dxDetailed = {
    '': 'DX 2020 熊/華',
    'Splash': 'DX 2021 爽/煌',
    'UNiVERSE': 'DX 2022 宙/星',
    'FESTiVAL': 'DX 2023 祭/祝',
    'BUDDiES': 'DX 2024 双/宴',
    'PRiSM': 'DX 2025 鏡',
    'PRiSM PLUS': 'DX 2026 彩',
  };

  /// 日文 DX 代 lookup（含 PLUS 变体，用于 -WithFlag 系列）
  static String? _lookupDxWithPlus(String version, Map<String, String> map) {
    const prefix = 'maimai でらっくす ';
    if (!version.startsWith(prefix)) return null;
    var suffix = version.substring(prefix.length);
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
    const prefix = 'maimai でらっくす ';
    if (!version.startsWith(prefix)) return null;
    final suffix = version.substring(prefix.length);
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
    final r = _tryExtraOrDx(version, false);
    if (r != null) return r;
    if (_oldSimple.containsKey(version)) return _oldSimple[version]!;
    final dx = _lookupDxExact(version, _dxSimple);
    if (dx != null) return dx;
    return _genericFallback(version);
  }

  static String formatVersion2(String version) {
    final r = _tryExtraOrDx(version, false);
    if (r != null) return r;
    if (_oldDetailed.containsKey(version)) return _oldDetailed[version]!;
    final dx = _lookupDxExact(version, _dxDetailed);
    if (dx != null) return dx;
    return version;
  }

  static String formatVersionWithFlag(String version, bool isExtra) {
    final r = _tryExtraOrDx(version, isExtra);
    if (r != null) return r;
    if (_oldSimple.containsKey(version)) return _oldSimple[version]!;
    final dx = _lookupDxWithPlus(version, _dxSimple);
    if (dx != null) return dx;
    return _genericFallback(version);
  }

  static String formatVersion2WithFlag(String version, bool isExtra) {
    final r = _tryExtraOrDx(version, isExtra);
    if (r != null) return r;
    if (_oldDetailed.containsKey(version)) return _oldDetailed[version]!;
    final dx = _lookupDxWithPlus(version, _dxDetailed);
    if (dx != null) return dx;
    // 日文 CiRCLE（仅 API 数据有，无 "maimai DX" 前缀）
    const prefix = 'maimai でらっくす ';
    if (version.startsWith(prefix)) {
      final s = version.substring(prefix.length);
      if (s == 'CiRCLE') return 'CiRCLE';
      if (s == 'CiRCLE PLUS') return 'CiRCLE+';
    }
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
