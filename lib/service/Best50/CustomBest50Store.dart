import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constant/CacheKeyConstant.dart';

/// 自定义 Best50 的单条成绩。
///
/// 只持久化「用户输入 + 谱面快照」，派生字段（ra / 评级 / 星数）不落盘，
/// 渲染时按当前公式重算，避免缓存与公式版本不一致。
class CustomBest50Entry {
  final int songId;
  final String title;
  final String type; // SD / DX
  final int levelIndex;
  final String level; // 标级（14+）
  final double ds; // 定数
  final double achievements; // 达成率
  final int dxScore; // DX 分数
  final String fc;
  final String fs;

  const CustomBest50Entry({
    required this.songId,
    required this.title,
    required this.type,
    required this.levelIndex,
    required this.level,
    required this.ds,
    required this.achievements,
    required this.dxScore,
    this.fc = '',
    this.fs = '',
  });

  CustomBest50Entry copyWith({
    int? songId,
    String? title,
    String? type,
    int? levelIndex,
    String? level,
    double? ds,
    double? achievements,
    int? dxScore,
    String? fc,
    String? fs,
  }) {
    return CustomBest50Entry(
      songId: songId ?? this.songId,
      title: title ?? this.title,
      type: type ?? this.type,
      levelIndex: levelIndex ?? this.levelIndex,
      level: level ?? this.level,
      ds: ds ?? this.ds,
      achievements: achievements ?? this.achievements,
      dxScore: dxScore ?? this.dxScore,
      fc: fc ?? this.fc,
      fs: fs ?? this.fs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'song_id': songId,
      'title': title,
      'type': type,
      'level_index': levelIndex,
      'level': level,
      'ds': ds,
      'achievements': achievements,
      'dxScore': dxScore,
      'fc': fc,
      'fs': fs,
    };
  }

  factory CustomBest50Entry.fromJson(Map<String, dynamic> json) {
    return CustomBest50Entry(
      songId: (json['song_id'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      levelIndex: (json['level_index'] as num?)?.toInt() ?? 0,
      level: json['level']?.toString() ?? '',
      ds: (json['ds'] as num?)?.toDouble() ?? 0.0,
      achievements: (json['achievements'] as num?)?.toDouble() ?? 0.0,
      dxScore: (json['dxScore'] as num?)?.toInt() ?? 0,
      fc: json['fc']?.toString() ?? '',
      fs: json['fs']?.toString() ?? '',
    );
  }
}

/// 自定义 Best50 本地存储（固定 50 个卡位，空位为 null）。
class CustomBest50Store {
  static const int slotCount = 50;

  static final CustomBest50Store _instance = CustomBest50Store._internal();
  factory CustomBest50Store() => _instance;
  CustomBest50Store._internal();

  final List<CustomBest50Entry?> _entries = List<CustomBest50Entry?>.filled(
    slotCount,
    null,
  );

  bool _loaded = false;
  Future<void>? _loading;

  List<CustomBest50Entry?> get entries => List<CustomBest50Entry?>.unmodifiable(_entries);

  Future<void> load() {
    if (_loaded) return Future.value();
    return _loading ??= _doLoad();
  }

  Future<void> _doLoad() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(CacheKeyConstant.customBest50Data);
      if (raw != null && raw.isNotEmpty) {
        final decoded = json.decode(raw);
        if (decoded is List) {
          for (int i = 0; i < slotCount && i < decoded.length; i++) {
            final item = decoded[i];
            if (item is Map<String, dynamic>) {
              _entries[i] = CustomBest50Entry.fromJson(item);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('加载自定义Best50失败: $e');
    } finally {
      _loaded = true;
      _loading = null;
    }
  }

  Future<void> setEntry(int index, CustomBest50Entry? entry) async {
    if (index < 0 || index >= slotCount) return;
    _entries[index] = entry;
    await _persist();
  }

  /// 用新列表整体覆盖 50 个卡位（一键排序用），只落盘一次。
  Future<void> setEntries(List<CustomBest50Entry?> entries) async {
    for (int i = 0; i < slotCount; i++) {
      _entries[i] = i < entries.length ? entries[i] : null;
    }
    await _persist();
  }

  Future<void> clearAll() async {
    for (int i = 0; i < slotCount; i++) {
      _entries[i] = null;
    }
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        CacheKeyConstant.customBest50Data,
        json.encode(_entries.map((e) => e?.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('保存自定义Best50失败: $e');
    }
  }
}
