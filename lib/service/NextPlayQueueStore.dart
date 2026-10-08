import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 「下次想玩」队列。每条记录都有自己的 occurrenceId，因此允许同一首歌重复加入。
class NextPlayQueueStore extends ChangeNotifier {
  static final instance = NextPlayQueueStore._();
  NextPlayQueueStore._();
  static const _key = 'next_play_queue_v1';

  List<NextPlayEntry> _entries = const [];
  Future<void>? _loading;
  Future<void>? _writing;

  List<NextPlayEntry> get entries => List.unmodifiable(_entries);

  Future<void> ensureLoaded() =>
      _loading ??= _load().whenComplete(() => _loading = null);

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw);
      if (list is List) {
        final parsed = <NextPlayEntry>[];
        for (final item in list) {
          if (item is Map) {
            final entry = NextPlayEntry.tryParse(item);
            if (entry != null) parsed.add(entry);
          }
        }
        _entries = parsed;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('读取下次想玩队列失败: $e');
    }
  }

  Future<void> add({
    required String songId,
    required String title,
    String artist = '',
    String? type,
    int? coverId,
    List<int> difficultyIndices = const [],
    String note = '',
    int count = 1,
  }) async {
    await ensureLoaded();
    final entries = <NextPlayEntry>[];
    for (var i = 0; i < count.clamp(1, 99); i++) {
      entries.add(NextPlayEntry(
        occurrenceId:
            '${DateTime.now().microsecondsSinceEpoch}_${_entries.length + i}',
        songId: songId,
        title: title,
        artist: artist,
        type: type,
        coverId: coverId,
        difficultyIndices: difficultyIndices,
        note: note,
      ));
    }
    _entries = [..._entries, ...entries];
    notifyListeners();
    await _save();
  }

  Future<void> remove(String occurrenceId) async {
    await ensureLoaded();
    _entries = _entries.where((e) => e.occurrenceId != occurrenceId).toList();
    notifyListeners();
    await _save();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    await ensureLoaded();
    if (oldIndex < 0 || oldIndex >= _entries.length) return;
    if (newIndex > oldIndex) newIndex--;
    newIndex = newIndex.clamp(0, _entries.length - 1).toInt();
    final next = [..._entries];
    final item = next.removeAt(oldIndex);
    next.insert(newIndex, item);
    _entries = next;
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    final snapshot = jsonEncode([for (final e in _entries) e.toJson()]);
    _writing = (_writing ?? Future<void>.value()).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, snapshot);
    });
    await _writing;
  }
}

class NextPlayEntry {
  final String occurrenceId;
  final String songId;
  final String title;
  final String artist;
  final String? type;
  final int? coverId;
  final List<int> difficultyIndices;
  final String note;

  const NextPlayEntry({
    required this.occurrenceId,
    required this.songId,
    required this.title,
    required this.artist,
    this.type,
    this.coverId,
    this.difficultyIndices = const [],
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'occurrenceId': occurrenceId,
        'songId': songId,
        'title': title,
        'artist': artist,
        if (type != null) 'type': type,
        if (coverId != null) 'coverId': coverId,
        'difficultyIndices': difficultyIndices,
        if (note.trim().isNotEmpty) 'note': note.trim(),
      };

  static NextPlayEntry? tryParse(Map item) {
    final occurrenceId = item['occurrenceId'];
    final songId = item['songId'];
    final title = item['title'];
    if (occurrenceId is! String || songId is! String || title is! String) {
      return null;
    }
    return NextPlayEntry(
      occurrenceId: occurrenceId,
      songId: songId,
      title: title,
      artist: item['artist'] is String ? item['artist'] as String : '',
      type: item['type'] is String ? item['type'] as String : null,
      coverId: item['coverId'] is int ? item['coverId'] as int : null,
      difficultyIndices: item['difficultyIndices'] is List
          ? (item['difficultyIndices'] as List)
              .whereType<num>()
              .map((e) => e.toInt())
              .toList()
          : const [],
      note: item['note'] is String ? item['note'] as String : '',
    );
  }
}
