import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_first_flutter_app/constant/CacheKeyConstant.dart';

class GuessChartCommonSettingsService {
  // 单例模式
  static final GuessChartCommonSettingsService _instance = GuessChartCommonSettingsService._internal();
  factory GuessChartCommonSettingsService() => _instance;
  GuessChartCommonSettingsService._internal();

  // 默认设置
  static const List<String> defaultSelectedVersions = []; // 空列表表示全部
  static const double defaultMasterMinDx = 1.0;
  static const double defaultMasterMaxDx = 15.0;
  static const List<String> defaultSelectedGenres = []; // 空列表表示全部
  static const int defaultMaxGuesses = 10;
  static const int defaultTimeLimit = 0; // 0表示无限制
  static const int defaultBlurLevel = 50; // 模糊程度，默认50%
  static const int defaultSongCount = 3; // 每次抽取歌曲数，默认3首
  static const int defaultNonEnglishCharThreshold = 50; // 非英文字符占比阈值，默认50%
  static const int defaultFlashDurationMs = 300; // 曲绘快闪时长，默认300ms
  static const int defaultTileCount = 1000; // 拼图猜歌曲绘切块数，默认1000
  static const int defaultTileRevealIntervalMs = 1500; // 拼图猜歌每批小块揭示间隔，默认1500ms
  static const int defaultPeekDurationSeconds = 8; // 谱面片段猜歌的片段时长，默认8秒
  static const List<String> defaultPeekDifficulties = [
    '4'
  ]; // 谱面片段猜歌的难度随机池（inote 编号），默认 EXPERT
  static const int defaultPlayDurationSeconds = 5; // 歌曲片段猜歌的播放时长，默认5秒

  /// 合法的难度编号（inote）。与页面 `GuessChartByChartPeekPage._difficultyNames`
  /// 保持同一套取值：**没有 '1'**（BASIC 是 '2'）。
  /// 原先这里写成 {'1'...'6'}，比实际可选的难度多了一个不存在的 '1'，
  /// 真正接入校验时会放进一个永远取不到谱面的难度。
  static const Set<String> allowedDifficultyInotes = {
    '2', '3', '4', '5', '6'
  };

  // 保存设置
  Future<void> saveSettings({
    required List<String> selectedVersions,
    required double masterMinDx,
    required double masterMaxDx,
    required List<String> selectedGenres,
    required int maxGuesses,
    required int timeLimit,
    int? blurLevel,
    int? songCount,
    int? nonEnglishCharThreshold,
    int? flashDurationMs,
    int? tileCount,
    int? tileRevealIntervalMs,
    int? peekDurationSeconds,
    List<String>? peekDifficulties,
    int? playDurationSeconds,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(CacheKeyConstant.guessChartSelectedVersions, selectedVersions);
    await prefs.setDouble(CacheKeyConstant.guessChartMasterMinDx, masterMinDx);
    await prefs.setDouble(CacheKeyConstant.guessChartMasterMaxDx, masterMaxDx);
    await prefs.setStringList(CacheKeyConstant.guessChartSelectedGenres, selectedGenres);
    await prefs.setInt(CacheKeyConstant.guessChartMaxGuesses, maxGuesses);
    await prefs.setInt(CacheKeyConstant.guessChartTimeLimit, timeLimit);
    if (blurLevel != null) {
      await prefs.setInt(CacheKeyConstant.guessChartBlurLevel, blurLevel);
    }
    if (songCount != null) {
      await prefs.setInt(CacheKeyConstant.guessChartSongCount, songCount);
    }
    if (nonEnglishCharThreshold != null) {
      await prefs.setInt(CacheKeyConstant.guessChartNonEnglishCharThreshold, nonEnglishCharThreshold);
    }
    if (flashDurationMs != null) {
      await prefs.setInt(CacheKeyConstant.guessChartFlashDuration, flashDurationMs);
    }
    if (tileCount != null) {
      await prefs.setInt(CacheKeyConstant.guessChartTileCount, tileCount);
    }
    if (tileRevealIntervalMs != null) {
      await prefs.setInt(CacheKeyConstant.guessTileRevealInterval, tileRevealIntervalMs);
    }
    if (peekDurationSeconds != null) {
      await prefs.setInt(CacheKeyConstant.guessChartPeekDuration, peekDurationSeconds);
    }
    if (peekDifficulties != null) {
      await prefs.setStringList(CacheKeyConstant.guessChartPeekDifficulties, peekDifficulties);
    }
    if (playDurationSeconds != null) {
      await prefs.setInt(CacheKeyConstant.guessChartPlayDuration, playDurationSeconds);
    }
  }

  // 加载设置
  Future<Map<String, dynamic>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'selectedVersions': prefs.getStringList(CacheKeyConstant.guessChartSelectedVersions) ?? defaultSelectedVersions,
      'masterMinDx': prefs.getDouble(CacheKeyConstant.guessChartMasterMinDx) ?? defaultMasterMinDx,
      'masterMaxDx': prefs.getDouble(CacheKeyConstant.guessChartMasterMaxDx) ?? defaultMasterMaxDx,
      'selectedGenres': prefs.getStringList(CacheKeyConstant.guessChartSelectedGenres) ?? defaultSelectedGenres,
      'maxGuesses': prefs.getInt(CacheKeyConstant.guessChartMaxGuesses) ?? defaultMaxGuesses,
      'timeLimit': prefs.getInt(CacheKeyConstant.guessChartTimeLimit) ?? defaultTimeLimit,
      'blurLevel': prefs.getInt(CacheKeyConstant.guessChartBlurLevel) ?? defaultBlurLevel,
      'songCount': prefs.getInt(CacheKeyConstant.guessChartSongCount) ?? defaultSongCount,
      'nonEnglishCharThreshold': prefs.getInt(CacheKeyConstant.guessChartNonEnglishCharThreshold) ?? defaultNonEnglishCharThreshold,
      'flashDurationMs': prefs.getInt(CacheKeyConstant.guessChartFlashDuration) ?? defaultFlashDurationMs,
      'tileCount': prefs.getInt(CacheKeyConstant.guessChartTileCount) ?? defaultTileCount,
      'tileRevealIntervalMs': prefs.getInt(CacheKeyConstant.guessTileRevealInterval) ?? defaultTileRevealIntervalMs,
      'peekDurationSeconds': prefs.getInt(CacheKeyConstant.guessChartPeekDuration) ?? defaultPeekDurationSeconds,
      'peekDifficulties': prefs.getStringList(CacheKeyConstant.guessChartPeekDifficulties) ?? defaultPeekDifficulties,
      'playDurationSeconds': prefs.getInt(CacheKeyConstant.guessChartPlayDuration) ?? defaultPlayDurationSeconds,
    };
  }

  // 重置为默认设置
  Future<void> resetToDefault() async {
    await saveSettings(
      selectedVersions: defaultSelectedVersions,
      masterMinDx: defaultMasterMinDx,
      masterMaxDx: defaultMasterMaxDx,
      selectedGenres: defaultSelectedGenres,
      maxGuesses: defaultMaxGuesses,
      timeLimit: defaultTimeLimit,
      blurLevel: defaultBlurLevel,
      songCount: defaultSongCount,
      nonEnglishCharThreshold: defaultNonEnglishCharThreshold,
      flashDurationMs: defaultFlashDurationMs,
      tileCount: defaultTileCount,
      tileRevealIntervalMs: defaultTileRevealIntervalMs,
      peekDurationSeconds: defaultPeekDurationSeconds,
      peekDifficulties: defaultPeekDifficulties,
      playDurationSeconds: defaultPlayDurationSeconds,
    );
  }

  /// 默认设置，**与 [loadSettings] 同结构、同 key**。
  ///
  /// 这是「重置」类 UI 的唯一真源：各页面不要自己硬编码默认值。
  /// 原先 9 个页面的「重置所有设置」按钮各自手写一份字面量，结果是
  /// 歌曲片段页的重置漏了播放时长（同页另一个重置入口却有），
  /// 而且新增设置项时极易漏改某一页。改从这里取值就不会再漂移。
  ///
  /// `test/guess_settings_test.dart` 会断言它和 [resetToDefault] 之后
  /// [loadSettings] 的结果一致，防止两边再次走偏。
  Map<String, dynamic> defaultSettings() => {
        'selectedVersions': List<String>.from(defaultSelectedVersions),
        'masterMinDx': defaultMasterMinDx,
        'masterMaxDx': defaultMasterMaxDx,
        'selectedGenres': List<String>.from(defaultSelectedGenres),
        'maxGuesses': defaultMaxGuesses,
        'timeLimit': defaultTimeLimit,
        'blurLevel': defaultBlurLevel,
        'songCount': defaultSongCount,
        'nonEnglishCharThreshold': defaultNonEnglishCharThreshold,
        'flashDurationMs': defaultFlashDurationMs,
        'tileCount': defaultTileCount,
        'tileRevealIntervalMs': defaultTileRevealIntervalMs,
        'peekDurationSeconds': defaultPeekDurationSeconds,
        'peekDifficulties': List<String>.from(defaultPeekDifficulties),
        'playDurationSeconds': defaultPlayDurationSeconds,
      };

  // 验证设置
  bool validateSettings(Map<String, dynamic> settings) {
    // 检查MASTER定数范围
    double minDx = settings['masterMinDx'] ?? defaultMasterMinDx;
    double maxDx = settings['masterMaxDx'] ?? defaultMasterMaxDx;
    if (minDx < 1.0 || maxDx > 15.0 || minDx > maxDx) {
      return false;
    }

    // 检查猜测次数
    int maxGuesses = settings['maxGuesses'] ?? defaultMaxGuesses;
    if (maxGuesses < 1 && maxGuesses != 0) { // 0表示无限制
      return false;
    }

    // 检查时间限制
    int timeLimit = settings['timeLimit'] ?? defaultTimeLimit;
    if (timeLimit < 0) {
      return false;
    }

    // 检查模糊程度
    int blurLevel = settings['blurLevel'] ?? defaultBlurLevel;
    if (blurLevel < 0 || blurLevel > 100) {
      return false;
    }

    // 检查歌曲数量
    int songCount = settings['songCount'] ?? defaultSongCount;
    if (songCount < 1 || songCount > 10) {
      return false;
    }

    // 检查非英文字符占比阈值
    int nonEnglishCharThreshold = settings['nonEnglishCharThreshold'] ?? defaultNonEnglishCharThreshold;
    if (nonEnglishCharThreshold < 0 || nonEnglishCharThreshold > 100) {
      return false;
    }

    // 检查快闪时长
    int flashDurationMs = settings['flashDurationMs'] ?? defaultFlashDurationMs;
    if (flashDurationMs < 100 || flashDurationMs > 3000) {
      return false;
    }

    // 检查拼图切块数
    int tileCount = settings['tileCount'] ?? defaultTileCount;
    if (tileCount < 100 || tileCount > 10000) {
      return false;
    }

    // 检查小块揭示间隔
    int tileRevealIntervalMs = settings['tileRevealIntervalMs'] ?? defaultTileRevealIntervalMs;
    if (tileRevealIntervalMs < 100 || tileRevealIntervalMs > 10000) {
      return false;
    }

    // 检查谱面片段时长
    int peekDurationSeconds = settings['peekDurationSeconds'] ?? defaultPeekDurationSeconds;
    if (peekDurationSeconds < 3 || peekDurationSeconds > 60) {
      return false;
    }

    // 检查谱面片段难度池（允许的 inote 编号）
    final List<String> peekDifficulties =
        (settings['peekDifficulties'] as List?)?.cast<String>() ?? defaultPeekDifficulties;
    if (peekDifficulties.isEmpty ||
        peekDifficulties.any((d) => !allowedDifficultyInotes.contains(d))) {
      return false;
    }

    // 检查歌曲片段播放时长
    final int playDurationSeconds =
        settings['playDurationSeconds'] ?? defaultPlayDurationSeconds;
    if (playDurationSeconds < 1 || playDurationSeconds > 30) {
      return false;
    }

    return true;
  }
}
