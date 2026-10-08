import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/ApiUrls.dart';
import '../utils/ApiClient.dart';

/// 服务端加载语录目录与本地显示偏好的唯一入口。
class LoadingTipsStore extends ChangeNotifier {
  static final LoadingTipsStore instance = LoadingTipsStore._();
  LoadingTipsStore._();

  static const _cacheKey = 'loading_tips_catalogue_v1';
  static const _disabledKey = 'loading_tips_disabled_ids_v1';
  static const _fetchedAtKey = 'loading_tips_fetched_at_v1';
  static const _localKey = 'loading_tips_local_v1';

  final _random = Random();
  List<LoadingTip> _catalogue = const [];
  Set<String> _disabled = <String>{};
  List<LoadingTip> _localTips = const [];
  Future<void>? _loading;

  List<LoadingTip> get catalogue => List.unmodifiable(_catalogue);

  /// 按页面展示顺序返回全部语录：本地新增排在云端目录之前。
  List<LoadingTip> get allTips => List.unmodifiable([
        ..._localTips,
        ..._catalogue,
      ]);
  List<String> get enabledTexts => [
        for (final tip in allTips)
          if (!_disabled.contains(tip.id)) tip.text,
      ];
  int get enabledCount => enabledTexts.length;
  int get totalCount => _localTips.length + _catalogue.length;
  Set<String> get disabledIds => Set.unmodifiable(_disabled);
  List<LoadingTip> get localTips => List.unmodifiable(_localTips);
  bool get isLoaded => _catalogue.isNotEmpty || _localTips.isNotEmpty;

  Future<void> ensureLoaded() =>
      _loading ??= _load().whenComplete(() => _loading = null);

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    final disabled = prefs.getStringList(_disabledKey) ?? const <String>[];
    final local = prefs.getString(_localKey);
    if (local != null) {
      try {
        _localTips = _decode(local);
      } catch (_) {}
    }
    _disabled = disabled.toSet();
    if (cached != null) {
      try {
        _catalogue = _decode(cached);
        notifyListeners();
      } on FormatException {
        // 旧目录缓存损坏时重新获取，不让管理页面停在加载状态。
      }
    }
    final fetchedAt = prefs.getInt(_fetchedAtKey) ?? 0;
    if (DateTime.now().millisecondsSinceEpoch - fetchedAt <
            const Duration(hours: 12).inMilliseconds &&
        cached != null) return;
    await refresh();
  }

  Future<bool> refresh() async {
    try {
      final response = await ApiClient.get(Uri.parse(ApiUrls.LoadingTipsUrl));
      if (response.statusCode < 200 || response.statusCode >= 300) return false;
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final raw = decoded is Map<String, dynamic> ? decoded['tips'] : decoded;
      if (raw is! List) return false;
      final next = <LoadingTip>[];
      for (final item in raw) {
        if (item is Map && item['id'] is String && item['text'] is String) {
          final id = (item['id'] as String).trim();
          final text = (item['text'] as String).trim();
          if (id.isNotEmpty &&
              text.isNotEmpty &&
              next.every((e) => e.id != id)) {
            next.add(LoadingTip(id: id, text: text));
          }
        }
      }
      // 服务端可以停用全部语录；空目录也属于合法的刷新结果。
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _cacheKey, jsonEncode([for (final e in next) e.toJson()]));
      await prefs.setInt(_fetchedAtKey, DateTime.now().millisecondsSinceEpoch);
      _catalogue = next;
      // 刷新云端目录时保留本地语录的停用状态。
      _disabled = _disabled
          .where((id) =>
              next.any((e) => e.id == id) || _localTips.any((e) => e.id == id))
          .toSet();
      await prefs.setStringList(_disabledKey, _disabled.toList());
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('获取加载语录失败: $e');
      return false;
    }
  }

  Future<void> setEnabled(String id, bool enabled) async {
    await ensureLoaded();
    if (enabled) {
      _disabled.remove(id);
    } else {
      _disabled.add(id);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_disabledKey, _disabled.toList());
    notifyListeners();
  }

  Future<void> setAllEnabled(bool enabled) async {
    await ensureLoaded();
    _disabled = enabled ? <String>{} : {for (final tip in allTips) tip.id};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_disabledKey, _disabled.toList());
    notifyListeners();
  }

  Future<void> addLocalTip(String text) async {
    await ensureLoaded();
    final value = text.trim();
    if (value.isEmpty) return;
    final tip = LoadingTip(
        id: 'local_${DateTime.now().microsecondsSinceEpoch}', text: value);
    _localTips = [..._localTips, tip];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _localKey, jsonEncode([for (final item in _localTips) item.toJson()]));
    notifyListeners();
  }

  Future<void> removeLocalTip(String id) async {
    await ensureLoaded();
    _localTips = _localTips.where((tip) => tip.id != id).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _localKey, jsonEncode([for (final item in _localTips) item.toJson()]));
    _disabled.remove(id);
    notifyListeners();
  }

  Future<String?> submitCloudTip(String text) async {
    final value = text.trim();
    if (value.isEmpty) return null;
    try {
      final response = await ApiClient.post(
        Uri.parse(ApiUrls.LoadingTipsUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': value}),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      return json is Map && json['tip_id'] is String
          ? json['tip_id'] as String
          : null;
    } catch (e) {
      debugPrint('上传加载语录失败: $e');
      return null;
    }
  }

  String randomText() {
    final texts = enabledTexts;
    return texts.isEmpty ? '' : texts[_random.nextInt(texts.length)];
  }

  List<LoadingTip> _decode(String cached) {
    final raw = jsonDecode(cached);
    if (raw is! List) throw const FormatException('加载语录缓存格式无效');
    final result = <LoadingTip>[];
    final ids = <String>{};
    for (final item in raw) {
      if (item is! Map || item['id'] is! String || item['text'] is! String) {
        continue;
      }
      final id = (item['id'] as String).trim();
      final text = (item['text'] as String).trim();
      if (id.isNotEmpty && text.isNotEmpty && ids.add(id)) {
        result.add(LoadingTip(id: id, text: text));
      }
    }
    return result;
  }
}

class LoadingTip {
  final String id;
  final String text;
  const LoadingTip({required this.id, required this.text});
  Map<String, String> toJson() => {'id': id, 'text': text};
}
