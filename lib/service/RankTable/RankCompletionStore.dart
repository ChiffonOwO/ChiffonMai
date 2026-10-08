import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum RankCompletion { unplayed, passed, failed, redPassed }

class RankCompletionStore extends ChangeNotifier {
  RankCompletionStore._();
  static final instance = RankCompletionStore._();
  final Map<String, RankCompletion> _values = {};
  final Map<String, double> _achievements = {};
  SharedPreferences? _prefs;
  Future<void>? _loading;
  static const _prefix = 'rank_completion_v1_';
  static const _achievementPrefix = 'rank_completion_achievement_v1_';
  RankCompletion status(String rank) =>
      _values[rank] ?? RankCompletion.unplayed;
  Future<void> load() => _loading ??= _load();
  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    for (final key
        in _prefs!.getKeys().where((key) => key.startsWith(_prefix))) {
      final value = _prefs!.getInt(key) ?? 0;
      // v1 的前三个索引保持不变，新增赤合格放在末尾，兼容旧记录。
      if (value >= 0 && value <= 3) {
        _values.putIfAbsent(
            key.substring(_prefix.length),
            () => switch (value) {
                  0 => RankCompletion.unplayed,
                  1 => RankCompletion.passed,
                  2 => RankCompletion.failed,
                  _ => RankCompletion.redPassed,
                });
      }
    }
    for (final key in _prefs!
        .getKeys()
        .where((key) => key.startsWith(_achievementPrefix))) {
      final value = _prefs!.getDouble(key);
      if (value != null && value >= 0 && value <= 404) {
        _achievements[key.substring(_achievementPrefix.length)] = value;
      }
    }
    notifyListeners();
  }

  Future<void> setStatus(String rank, RankCompletion status) async {
    await load();
    _values[rank] = status;
    notifyListeners();
    await _prefs!.setInt('$_prefix$rank', status.index);
    if (status == RankCompletion.unplayed) {
      _achievements.remove(rank);
      await _prefs!.remove('$_achievementPrefix$rank');
    }
  }

  /// 一次保存完成状态和总达成率，减少弹窗退出期间的重复通知与重建。
  Future<void> setCompletion(
      String rank, RankCompletion status, double? value) async {
    await load();
    _values[rank] = status;
    if (status == RankCompletion.unplayed || value == null) {
      _achievements.remove(rank);
    } else {
      _achievements[rank] = value.clamp(0, 404).toDouble();
    }
    await _prefs!.setInt('$_prefix$rank', status.index);
    if (status == RankCompletion.unplayed || value == null) {
      await _prefs!.remove('$_achievementPrefix$rank');
    } else {
      await _prefs!.setDouble(
          '$_achievementPrefix$rank', value.clamp(0, 404).toDouble());
    }
    notifyListeners();
  }

  double? achievement(String rank) => _achievements[rank];

  Future<void> setAchievement(String rank, double? value) async {
    await load();
    if (value == null || value < 0 || value > 404) {
      _achievements.remove(rank);
      await _prefs!.remove('$_achievementPrefix$rank');
    } else {
      _achievements[rank] = value;
      await _prefs!.setDouble('$_achievementPrefix$rank', value);
    }
    notifyListeners();
  }
}
