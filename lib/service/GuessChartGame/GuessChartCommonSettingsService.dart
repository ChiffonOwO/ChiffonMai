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
    );
  }

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

    return true;
  }
}