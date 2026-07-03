import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../entity/ChartNote.dart';

/// 谱面笔记服务：管理谱面笔记的增删改查，数据持久化到 SharedPreferences
class ChartNoteService {
  static final ChartNoteService _instance = ChartNoteService._internal();
  factory ChartNoteService() => _instance;
  ChartNoteService._internal();

  static const String _storageKey = 'chart_notes_data';

  List<ChartNote> _notes = [];
  bool _loaded = false;

  /// 从本地加载所有笔记
  Future<List<ChartNote>> loadNotes() async {
    if (_loaded) return List.unmodifiable(_notes);
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> jsonList = json.decode(jsonStr) as List<dynamic>;
        _notes = jsonList
            .map((e) => ChartNote.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        _notes = [];
      }
      _loaded = true;
    } catch (e) {
      debugPrint('加载谱面笔记数据失败: $e');
      _notes = [];
    }
    return List.unmodifiable(_notes);
  }

  /// 保存所有笔记到本地
  Future<void> _saveNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = json.encode(_notes.map((n) => n.toJson()).toList());
      await prefs.setString(_storageKey, jsonStr);
    } catch (e) {
      debugPrint('保存谱面笔记数据失败: $e');
    }
  }

  /// 获取指定谱面的笔记
  /// [songId] 歌曲ID, [levelIndex] 难度索引
  Future<ChartNote?> getNoteByChart(String songId, int levelIndex) async {
    if (!_loaded) await loadNotes();
    final key = '${songId}_$levelIndex';
    try {
      return _notes.firstWhere((n) => n.uniqueKey == key);
    } catch (_) {
      return null;
    }
  }

  /// 保存或更新笔记（upsert 模式）
  Future<ChartNote> saveNote(ChartNote note) async {
    if (!_loaded) await loadNotes();
    final key = note.uniqueKey;
    final existingIndex = _notes.indexWhere((n) => n.uniqueKey == key);
    if (existingIndex >= 0) {
      // 更新现有笔记
      _notes[existingIndex] = _notes[existingIndex].copyWith(
        content: note.content,
        songTitle: note.songTitle,
        level: note.level,
        ds: note.ds,
      );
      await _saveNotes();
      return _notes[existingIndex];
    } else {
      // 新增笔记
      _notes.add(note);
      await _saveNotes();
      return note;
    }
  }

  /// 删除指定谱面的笔记
  /// 返回 true 表示删除成功，false 表示笔记不存在
  Future<bool> deleteNote(String songId, int levelIndex) async {
    if (!_loaded) await loadNotes();
    final key = '${songId}_$levelIndex';
    final before = _notes.length;
    _notes.removeWhere((n) => n.uniqueKey == key);
    if (_notes.length < before) {
      await _saveNotes();
      return true;
    }
    return false;
  }

  /// 获取某首歌曲的所有笔记
  Future<List<ChartNote>> getNotesForSong(String songId) async {
    if (!_loaded) await loadNotes();
    return _notes
        .where((n) => n.songId == songId)
        .toList()
      ..sort((a, b) => a.levelIndex.compareTo(b.levelIndex));
  }

  /// 获取所有笔记
  Future<List<ChartNote>> getAllNotes() async {
    if (!_loaded) await loadNotes();
    return List.unmodifiable(_notes);
  }

  /// 获取笔记总数
  Future<int> getNoteCount() async {
    if (!_loaded) await loadNotes();
    return _notes.length;
  }

  /// 清除所有笔记
  Future<void> clearAll() async {
    _notes = [];
    _loaded = true;
    await _saveNotes();
  }
}
