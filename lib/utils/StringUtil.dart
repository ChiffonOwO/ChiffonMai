/**
 * 字符串工具类
 * 用于处理字符串相关的操作
 */
class StringUtil {
  /**
   * 格式化版本字符串
   * @param version 版本字符串
   * @return 格式化后的版本字符串
   */
  static String formatVersion(String version) {
    if (version == 'maimai') {
      return 'maimai';
    }
    if (version == 'maimai PLUS') {
      return 'maimai+';
    }
    if (version == 'maimai \u3067\u3089\u3063\u304f\u3059') {
      return 'DX 2020';
    }
    if (version == 'maimai \u3067\u3089\u3063\u304f\u3059 Splash') {
      return 'DX 2021';
    }
    if (version == 'maimai \u3067\u3089\u3063\u304f\u3059 UNiVERSE') {
      return 'DX 2022';
    }
    if (version == 'maimai \u3067\u3089\u3063\u304f\u3059 FESTiVAL') {
      return 'DX 2023';
    }
    if (version == 'maimai \u3067\u3089\u3063\u304f\u3059 BUDDiES') {
      return 'DX 2024';
    }
    if (version == 'maimai \u3067\u3089\u3063\u304f\u3059 PRiSM') {
      return 'DX 2025';
    }
    if (version.contains(' PLUS')) {
      version = version.replaceFirst(' PLUS', '+');
    }
    if (version.contains('maimai') && version != 'maimai') {
      version = version.replaceFirst('maimai ', '');
    }
    if (version.contains('\u3067\u3089\u3063\u304f\u3059')) {
      version = version.replaceFirst('\u3067\u3089\u3063\u304f\u3059 ', '');
    }
    return version;
  }

  static String formatVersion2(String version) {
    if (version == 'maimai') {
      return 'maimai 真';
    }
    if (version == 'maimai PLUS') {
      return 'maimai+ 真';
    }
    if (version == 'maimai GreeN'){
      return 'GreeN 超';
    }
    if (version == 'maimai GreeN PLUS'){
      return 'GreeN+ 檄';
    }
    if (version == 'maimai ORANGE'){
      return 'ORANGE 橙';
    }
    if (version == 'maimai ORANGE PLUS'){
      return 'ORANGE+ 暁';
    }
    if (version == 'maimai PiNK'){
      return 'PiNK 桃';
    }
    if (version == 'maimai PiNK PLUS'){
      return 'PiNK+ 櫻';
    }
    if (version == 'maimai MURASAKi'){
      return 'MURASAKi 紫';
    }
    if (version == 'maimai MURASAKi'){
      return 'MURASAKi 紫';
    }
    if (version == 'maimai MURASAKi PLUS'){
      return 'MURASAKi+ 菫';
    }
    if (version == 'maimai MiLK'){
      return 'MiLK 白';
    }
    if (version == 'MiLK PLUS'){
      return 'MiLK+ 雪';
    }
    if (version == 'maimai FiNALE'){
      return 'FiNALE 輝';
    }
    if (version == 'maimai \u3067\u3089\u3063\u304f\u3059') {
      return 'DX 2020 熊/華';
    }
    if (version == 'maimai \u3067\u3089\u3063\u304f\u3059 Splash') {
      return 'DX 2021 爽/煌';
    }
    if (version == 'maimai \u3067\u3089\u3063\u304f\u3059 UNiVERSE') {
      return 'DX 2022 宙/星';
    }
    if (version == 'maimai \u3067\u3089\u3063\u304f\u3059 FESTiVAL') {
      return 'DX 2023 祭/祝';
    }
    if (version == 'maimai \u3067\u3089\u3063\u304f\u3059 BUDDiES') {
      return 'DX 2024 双/宴';
    }
    if (version == 'maimai \u3067\u3089\u3063\u304f\u3059 PRiSM') {
      return 'DX 2025 镜';
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
      return '\u27266';
    } else if (scoreRate >= 0.98) {
      return '\u27265.5';
    } else if (scoreRate >= 0.97) {
      return '\u27265';
    } else if (scoreRate >= 0.95) {
      return '\u27264';
    } else if (scoreRate >= 0.93) {
      return '\u27263';
    } else if (scoreRate >= 0.90) {
      return '\u27262';
    } else if (scoreRate >= 0.85) {
      return '\u27261';
    } else {
      return '\u27260';
    }
  }

  /**
   * 格式化歌曲类型字符串
   * @param type 歌曲类型字符串
   * @return 格式化后的歌曲类型字符串
   */
  static String formatSongType(String type) {
    return type == "DX" ? "DX" : "ST";
  }
}