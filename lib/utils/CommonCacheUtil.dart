import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class CommonCacheUtil {
  // 单例模式
  static final CommonCacheUtil _instance = CommonCacheUtil._internal();
  factory CommonCacheUtil() => _instance;
  CommonCacheUtil._internal();

  // 缓存键前缀
  static const String _PREFIX = 'guess_song_';
  static const String _DATE_KEY = 'last_reset_date';

  // 缓存变量名
  static const String _CORRECT_KEY = 'correct_count';
  static const String _WRONG_KEY = 'wrong_count';
  static const String _ACCURACY_KEY = 'accuracy';
  static const String _AVG_TIME_KEY = 'average_time';
  static const String _TOTAL_TIME_KEY = 'total_time';

  /// 初始化缓存（检查是否需要重置）
  Future<void> initCache(String gameId) async {
    await _checkAndResetIfNeeded(gameId);
  }

  /// 检查并在需要时重置数据
  Future<void> _checkAndResetIfNeeded(String gameId) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _getTodayString();
    final lastResetDate = prefs.getString('$_PREFIX${gameId}_$_DATE_KEY');

    if (lastResetDate != today) {
      // 重置数据
      await prefs.setInt('$_PREFIX${gameId}_$_CORRECT_KEY', 0);
      await prefs.setInt('$_PREFIX${gameId}_$_WRONG_KEY', 0);
      await prefs.setDouble('$_PREFIX${gameId}_$_ACCURACY_KEY', 0.0);
      await prefs.setDouble('$_PREFIX${gameId}_$_AVG_TIME_KEY', 0.0);
      await prefs.setInt('$_PREFIX${gameId}_$_TOTAL_TIME_KEY', 0);
      await prefs.setString('$_PREFIX${gameId}_$_DATE_KEY', today);
    }
  }

  /// 获取今天的日期字符串（YYYY-MM-DD）
  String _getTodayString() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  /// 记录成功通关
  Future<void> recordSuccess(String gameId) async {
    await _checkAndResetIfNeeded(gameId);
    final prefs = await SharedPreferences.getInstance();
    
    // 增加正确次数
    final correctCount = prefs.getInt('$_PREFIX${gameId}_$_CORRECT_KEY') ?? 0;
    await prefs.setInt('$_PREFIX${gameId}_$_CORRECT_KEY', correctCount + 1);
  }

  /// 记录失败或投降
  Future<void> recordFailure(String gameId) async {
    await _checkAndResetIfNeeded(gameId);
    final prefs = await SharedPreferences.getInstance();
    
    // 增加错误次数
    final wrongCount = prefs.getInt('$_PREFIX${gameId}_$_WRONG_KEY') ?? 0;
    await prefs.setInt('$_PREFIX${gameId}_$_WRONG_KEY', wrongCount + 1);
  }

  /// 结算一局，更新统计数据
  Future<void> settleGame(String gameId, int timeUsedInSeconds) async {
    await _checkAndResetIfNeeded(gameId);
    final prefs = await SharedPreferences.getInstance();
    
    // 获取当前数据
    final correctCount = prefs.getInt('$_PREFIX${gameId}_$_CORRECT_KEY') ?? 0;
    final wrongCount = prefs.getInt('$_PREFIX${gameId}_$_WRONG_KEY') ?? 0;
    final totalTime = prefs.getInt('$_PREFIX${gameId}_$_TOTAL_TIME_KEY') ?? 0;
    
    // 计算总游戏次数
    final totalGames = correctCount + wrongCount;
    
    // 更新总用时
    final newTotalTime = totalTime + timeUsedInSeconds;
    await prefs.setInt('$_PREFIX${gameId}_$_TOTAL_TIME_KEY', newTotalTime);
    
    // 计算并更新正确率
    if (totalGames > 0) {
      final accuracy = (correctCount / totalGames) * 100;
      await prefs.setDouble('$_PREFIX${gameId}_$_ACCURACY_KEY', accuracy);
    }
    
    // 计算并更新平均用时
    if (totalGames > 0) {
      final avgTime = newTotalTime / totalGames;
      await prefs.setDouble('$_PREFIX${gameId}_$_AVG_TIME_KEY', avgTime);
    }
  }

  /// 获取统计数据
  Future<Map<String, dynamic>> getStats(String gameId) async {
    await _checkAndResetIfNeeded(gameId);
    final prefs = await SharedPreferences.getInstance();
    
    return {
      'correct': prefs.getInt('$_PREFIX${gameId}_$_CORRECT_KEY') ?? 0,
      'wrong': prefs.getInt('$_PREFIX${gameId}_$_WRONG_KEY') ?? 0,
      'accuracy': prefs.getDouble('$_PREFIX${gameId}_$_ACCURACY_KEY') ?? 0.0,
      'avgTime': prefs.getDouble('$_PREFIX${gameId}_$_AVG_TIME_KEY') ?? 0.0,
    };
  }

  /// 手动重置数据
  Future<void> resetStats(String gameId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_PREFIX${gameId}_$_CORRECT_KEY', 0);
    await prefs.setInt('$_PREFIX${gameId}_$_WRONG_KEY', 0);
    await prefs.setDouble('$_PREFIX${gameId}_$_ACCURACY_KEY', 0.0);
    await prefs.setDouble('$_PREFIX${gameId}_$_AVG_TIME_KEY', 0.0);
    await prefs.setInt('$_PREFIX${gameId}_$_TOTAL_TIME_KEY', 0);
    await prefs.setString('$_PREFIX${gameId}_$_DATE_KEY', _getTodayString());
  }
}