import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simai_flutter/simai_flutter.dart';

/// 谱面播放页侧边栏设置的一份快照。
///
/// 字段与 `SimaiPlayerController` 暴露的 setter 一一对应；
/// 以后新增设置项时，记得同时改 [capture]、[apply] 和 [toJson]/[fromJson] 三处。
@immutable
class ChartPlaySettings {
  // ---- 显示设置 ----
  final SimaiMirrorMode mirrorMode;
  final SimaiBackgroundMode backgroundMode;
  final double speed;
  final bool rotateSlideStar;
  final bool pinkSlideStar;
  final bool standardBreakSlide;
  final bool showApproachLine;
  final bool showHitEffects;
  final SimaiCenterDisplayMode centerDisplayMode;
  final bool showAchievementRate;
  final bool highlightExNotes;
  final bool showCornerInfo;
  final bool showDetailedPerformanceInfo;

  // ---- 音频设置 ----
  final bool hitSoundEnabled;
  final double musicVolume;
  final int musicOffsetMs;
  final int hitSoundOffsetMs;

  /// 默认值与 `SimaiPlayerController` 的初始值保持一致。
  const ChartPlaySettings({
    this.mirrorMode = SimaiMirrorMode.none,
    this.backgroundMode = SimaiBackgroundMode.judgeLine,
    this.speed = 8.0,
    this.rotateSlideStar = true,
    this.pinkSlideStar = false,
    this.standardBreakSlide = false,
    this.showApproachLine = true,
    this.showHitEffects = true,
    this.centerDisplayMode = SimaiCenterDisplayMode.achievement,
    this.showAchievementRate = true,
    this.highlightExNotes = false,
    this.showCornerInfo = true,
    this.showDetailedPerformanceInfo = false,
    this.hitSoundEnabled = false,
    this.musicVolume = 0.8,
    this.musicOffsetMs = 0,
    this.hitSoundOffsetMs = 0,
  });

  /// 读取控制器当前的全部设置。
  factory ChartPlaySettings.capture(SimaiPlayerController c) {
    return ChartPlaySettings(
      mirrorMode: c.mirrorMode,
      backgroundMode: c.backgroundMode,
      speed: c.speed,
      rotateSlideStar: c.rotateSlideStar,
      pinkSlideStar: c.pinkSlideStar,
      standardBreakSlide: c.standardBreakSlide,
      showApproachLine: c.showApproachLine,
      showHitEffects: c.showHitEffects,
      centerDisplayMode: c.centerDisplayMode,
      showAchievementRate: c.showAchievementRate,
      highlightExNotes: c.highlightExNotes,
      showCornerInfo: c.showCornerInfo,
      showDetailedPerformanceInfo: c.showDetailedPerformanceInfo,
      hitSoundEnabled: c.hitSoundEnabled,
      musicVolume: c.musicVolume,
      musicOffsetMs: c.musicOffsetMs,
      hitSoundOffsetMs: c.hitSoundOffsetMs,
    );
  }

  /// 把这份设置写回控制器。
  ///
  /// 控制器的 setter 自带「值没变就直接 return」，所以这里整体套用不会产生多余的重建。
  void apply(SimaiPlayerController c) {
    c.mirrorMode = mirrorMode;
    c.backgroundMode = backgroundMode;
    c.speed = speed;
    c.rotateSlideStar = rotateSlideStar;
    c.pinkSlideStar = pinkSlideStar;
    c.standardBreakSlide = standardBreakSlide;
    c.showApproachLine = showApproachLine;
    c.showHitEffects = showHitEffects;
    c.centerDisplayMode = centerDisplayMode;
    c.showAchievementRate = showAchievementRate;
    c.highlightExNotes = highlightExNotes;
    c.showCornerInfo = showCornerInfo;
    c.showDetailedPerformanceInfo = showDetailedPerformanceInfo;
    c.hitSoundEnabled = hitSoundEnabled;
    c.musicVolume = musicVolume;
    c.musicOffsetMs = musicOffsetMs;
    c.hitSoundOffsetMs = hitSoundOffsetMs;
  }

  Map<String, dynamic> toJson() => {
        'mirrorMode': mirrorMode.name,
        'backgroundMode': backgroundMode.name,
        'speed': speed,
        'rotateSlideStar': rotateSlideStar,
        'pinkSlideStar': pinkSlideStar,
        'standardBreakSlide': standardBreakSlide,
        'showApproachLine': showApproachLine,
        'showHitEffects': showHitEffects,
        'centerDisplayMode': centerDisplayMode.name,
        'showAchievementRate': showAchievementRate,
        'highlightExNotes': highlightExNotes,
        'showCornerInfo': showCornerInfo,
        'showDetailedPerformanceInfo': showDetailedPerformanceInfo,
        'hitSoundEnabled': hitSoundEnabled,
        'musicVolume': musicVolume,
        'musicOffsetMs': musicOffsetMs,
        'hitSoundOffsetMs': hitSoundOffsetMs,
      };

  /// 从 JSON 还原。
  ///
  /// 单个字段坏掉不影响其它字段：枚举认不出来就退回默认值，
  /// 数值越界会按侧边栏滑块的区间夹回去（防止手改 prefs 后出现非法状态）。
  factory ChartPlaySettings.fromJson(Map<String, dynamic> json) {
    const fallback = ChartPlaySettings();
    return ChartPlaySettings(
      mirrorMode: _enumByName(SimaiMirrorMode.values, json['mirrorMode'],
          fallback.mirrorMode),
      backgroundMode: _enumByName(SimaiBackgroundMode.values,
          json['backgroundMode'], fallback.backgroundMode),
      speed: _clampDouble(json['speed'], 3.0, 9.0, fallback.speed),
      rotateSlideStar: _bool(json['rotateSlideStar'], fallback.rotateSlideStar),
      pinkSlideStar: _bool(json['pinkSlideStar'], fallback.pinkSlideStar),
      standardBreakSlide:
          _bool(json['standardBreakSlide'], fallback.standardBreakSlide),
      showApproachLine:
          _bool(json['showApproachLine'], fallback.showApproachLine),
      showHitEffects: _bool(json['showHitEffects'], fallback.showHitEffects),
      centerDisplayMode: _enumByName(SimaiCenterDisplayMode.values,
          json['centerDisplayMode'], fallback.centerDisplayMode),
      showAchievementRate:
          _bool(json['showAchievementRate'], fallback.showAchievementRate),
      highlightExNotes:
          _bool(json['highlightExNotes'], fallback.highlightExNotes),
      showCornerInfo: _bool(json['showCornerInfo'], fallback.showCornerInfo),
      showDetailedPerformanceInfo: _bool(json['showDetailedPerformanceInfo'],
          fallback.showDetailedPerformanceInfo),
      hitSoundEnabled:
          _bool(json['hitSoundEnabled'], fallback.hitSoundEnabled),
      musicVolume:
          _clampDouble(json['musicVolume'], 0.0, 1.0, fallback.musicVolume),
      musicOffsetMs:
          _clampInt(json['musicOffsetMs'], -2000, 2000, fallback.musicOffsetMs),
      hitSoundOffsetMs: _clampInt(
          json['hitSoundOffsetMs'], -200, 200, fallback.hitSoundOffsetMs),
    );
  }

  static T _enumByName<T extends Enum>(List<T> values, Object? raw, T fallback) {
    if (raw is! String) return fallback;
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return fallback;
  }

  static bool _bool(Object? raw, bool fallback) =>
      raw is bool ? raw : fallback;

  static double _clampDouble(
      Object? raw, double min, double max, double fallback) {
    if (raw is! num) return fallback;
    final value = raw.toDouble();
    if (value.isNaN || value.isInfinite) return fallback;
    return value.clamp(min, max).toDouble();
  }

  static int _clampInt(Object? raw, int min, int max, int fallback) {
    if (raw is! num) return fallback;
    return raw.toInt().clamp(min, max);
  }
}

/// 侧边栏设置的本地持久化。
///
/// 播放页每次进入时套用上次保存的值，用户改动后延迟落盘（防抖），
/// 退出页面或 App 切后台时立刻补写一次。
class ChartPlaySettingsStore {
  static final ChartPlaySettingsStore _instance =
      ChartPlaySettingsStore._internal();
  factory ChartPlaySettingsStore() => _instance;
  ChartPlaySettingsStore._internal();

  static const String _key = 'chart_play_settings_v1';

  ChartPlaySettings _settings = const ChartPlaySettings();
  bool _loaded = false;
  Future<ChartPlaySettings>? _loading;

  /// 当前缓存（未加载时是默认值）。
  ChartPlaySettings get settings => _settings;

  bool get isLoaded => _loaded;

  /// 从本地读取。可重复调用，并发调用会复用同一个 Future。
  Future<ChartPlaySettings> load() {
    if (_loaded) return Future.value(_settings);
    return _loading ??= _doLoad();
  }

  Future<ChartPlaySettings> _doLoad() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = json.decode(raw);
        if (decoded is Map<String, dynamic>) {
          _settings = ChartPlaySettings.fromJson(decoded);
        }
      }
    } catch (e) {
      debugPrint('[ChartPlaySettings] 读取失败，使用默认设置: $e');
      _settings = const ChartPlaySettings();
    }
    _loaded = true;
    _loading = null;
    debugPrint('[ChartPlaySettings] 已加载设置: speed=${_settings.speed} '
        'mirror=${_settings.mirrorMode.name}');
    return _settings;
  }

  /// 把当前设置套用到控制器。
  void applyTo(SimaiPlayerController controller) {
    _settings.apply(controller);
  }

  /// 只更新内存中的当前值，不写盘。
  ///
  /// 配合防抖使用：值一改就立刻记下来（这样中途重建控制器也能拿到最新的），
  /// 写盘则推迟到用户停止操作之后。
  void remember(ChartPlaySettings settings) {
    _settings = settings;
    _loaded = true;
  }

  /// 把内存中的当前值写盘。
  Future<void> persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, json.encode(_settings.toJson()));
    } catch (e) {
      debugPrint('[ChartPlaySettings] 保存失败: $e');
    }
  }

  /// 读取控制器当前值并落盘。控制器为 null 时忽略。
  Future<void> saveFrom(SimaiPlayerController? controller) async {
    if (controller == null) return;
    await save(ChartPlaySettings.capture(controller));
  }

  Future<void> save(ChartPlaySettings settings) async {
    remember(settings);
    await persist();
  }

  /// 清空，恢复默认。给设置页的「重置」留的口子。
  Future<void> reset() async {
    _settings = const ChartPlaySettings();
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (e) {
      debugPrint('[ChartPlaySettings] 重置失败: $e');
    }
  }
}
