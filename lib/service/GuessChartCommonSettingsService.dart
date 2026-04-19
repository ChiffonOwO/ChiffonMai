import 'package:shared_preferences/shared_preferences.dart';

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
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('guessChart_selectedVersions', selectedVersions);
    await prefs.setDouble('guessChart_masterMinDx', masterMinDx);
    await prefs.setDouble('guessChart_masterMaxDx', masterMaxDx);
    await prefs.setStringList('guessChart_selectedGenres', selectedGenres);
    await prefs.setInt('guessChart_maxGuesses', maxGuesses);
    await prefs.setInt('guessChart_timeLimit', timeLimit);
    if (blurLevel != null) {
      await prefs.setInt('guessChart_blurLevel', blurLevel);
    }
    if (songCount != null) {
      await prefs.setInt('guessChart_songCount', songCount);
    }
  }

  // 加载设置
  Future<Map<String, dynamic>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'selectedVersions': prefs.getStringList('guessChart_selectedVersions') ?? defaultSelectedVersions,
      'masterMinDx': prefs.getDouble('guessChart_masterMinDx') ?? defaultMasterMinDx,
      'masterMaxDx': prefs.getDouble('guessChart_masterMaxDx') ?? defaultMasterMaxDx,
      'selectedGenres': prefs.getStringList('guessChart_selectedGenres') ?? defaultSelectedGenres,
      'maxGuesses': prefs.getInt('guessChart_maxGuesses') ?? defaultMaxGuesses,
      'timeLimit': prefs.getInt('guessChart_timeLimit') ?? defaultTimeLimit,
      'blurLevel': prefs.getInt('guessChart_blurLevel') ?? defaultBlurLevel,
      'songCount': prefs.getInt('guessChart_songCount') ?? defaultSongCount,
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

    return true;
  }
}