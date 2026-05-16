import 'dart:convert';
import 'dart:convert' show utf8;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../api/ApiUrls.dart';
import '../entity/LuoXueSongEntity.dart';
import '../entity/Song.dart';
import '../constant/CacheKeyConstant.dart';

class LuoXueSongsManager {
  // 单例模式
  static final LuoXueSongsManager _instance = LuoXueSongsManager._internal();
  factory LuoXueSongsManager() => _instance;
  LuoXueSongsManager._internal();

  // 落雪歌曲实体
  LuoXueSongEntity? _luoXueSongEntity;

  // 获取落雪歌曲数据
  Future<LuoXueSongEntity?> getLuoXueSongs() async {
    try {
      // 尝试从缓存加载
      final cachedData = await _loadFromCache();
      if (cachedData != null) {
        _luoXueSongEntity = cachedData;
        return _luoXueSongEntity;
      }

      // 从API获取
      final response = await http.get(Uri.parse(ApiUrls.LuoXueSongsApi));
      if (response.statusCode == 200) {
        String responseBody;
        try {
          responseBody = utf8.decode(response.bodyBytes);
        } catch (e) {
          // 如果 UTF-8 解析失败，尝试使用 Latin1 编码
          debugPrint('UTF-8 解析失败，尝试使用 Latin1 编码: $e');
          responseBody = response.body;
        }
        final jsonData = json.decode(responseBody);
        _luoXueSongEntity = LuoXueSongEntity.fromJson(jsonData);
        
        // 保存到缓存
        await _saveToCache(_luoXueSongEntity!);
        return _luoXueSongEntity;
      } else {
        debugPrint('Failed to fetch LuoXue songs: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching LuoXue songs: $e');
      return null;
    }
  }

  // 将落雪歌曲映射到缓存的歌曲集
  Map<Song, LuoXueSong> mapLuoXueSongsToCachedSongs(List<Song> cachedSongs) {
    final Map<Song, LuoXueSong> mapping = {};

    if (_luoXueSongEntity == null) return mapping;

    for (final luoXueSong in _luoXueSongEntity!.songs) {
      // 处理 standard 类型（对应 SD）
      if (luoXueSong.difficulties.standard != null && luoXueSong.difficulties.standard!.isNotEmpty) {
        final matchedSong = cachedSongs.firstWhere(
          (song) => song.title == luoXueSong.title && song.type == 'SD',
          orElse: () => Song(
            id: '',
            title: luoXueSong.title,
            type: 'SD',
            ds: [],
            level: [],
            cids: [],
            charts: [],
            basicInfo: BasicInfo(
              title: luoXueSong.title,
              artist: luoXueSong.artist,
              genre: luoXueSong.genre,
              bpm: luoXueSong.bpm,
              releaseDate: '',
              from: '',
              isNew: false,
            ),
          ),
        );
        mapping[matchedSong] = luoXueSong;
      }

      // 处理 dx 类型（对应 DX）
      if (luoXueSong.difficulties.dx != null && luoXueSong.difficulties.dx!.isNotEmpty) {
        final matchedSong = cachedSongs.firstWhere(
          (song) => song.title == luoXueSong.title && song.type == 'DX',
          orElse: () => Song(
            id: '',
            title: luoXueSong.title,
            type: 'DX',
            ds: [],
            level: [],
            cids: [],
            charts: [],
            basicInfo: BasicInfo(
              title: luoXueSong.title,
              artist: luoXueSong.artist,
              genre: luoXueSong.genre,
              bpm: luoXueSong.bpm,
              releaseDate: '',
              from: '',
              isNew: false,
            ),
          ),
        );
        mapping[matchedSong] = luoXueSong;
      }
    }

    return mapping;
  }

  // 从缓存加载
  Future<LuoXueSongEntity?> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(CacheKeyConstant.luoxueSongsCache);
      if (cachedData != null) {
        final jsonData = json.decode(cachedData);
        return LuoXueSongEntity.fromJson(jsonData);
      }
      return null;
    } catch (e) {
      debugPrint('Error loading from cache: $e');
      return null;
    }
  }

  // 保存到缓存
  Future<void> _saveToCache(LuoXueSongEntity entity) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonData = _entityToJson(entity);
      await prefs.setString(CacheKeyConstant.luoxueSongsCache, json.encode(jsonData));
    } catch (e) {
      debugPrint('Error saving to cache: $e');
    }
  }

  // 将实体转换为JSON（因为实体类没有toJson方法）
  Map<String, dynamic> _entityToJson(LuoXueSongEntity entity) {
    return {
      'songs': entity.songs.map((song) => _songToJson(song)).toList(),
      'genres': entity.genres.map((genre) => _genreToJson(genre)).toList(),
      'versions': entity.versions.map((version) => _versionToJson(version)).toList(),
    };
  }

  Map<String, dynamic> _songToJson(LuoXueSong song) {
    return {
      'id': song.id,
      'title': song.title,
      'artist': song.artist,
      'genre': song.genre,
      'bpm': song.bpm,
      'map': song.map,
      'version': song.version,
      'rights': song.rights,
      'locked': song.locked,
      'disabled': song.disabled,
      'difficulties': _difficultiesToJson(song.difficulties),
    };
  }

  Map<String, dynamic> _difficultiesToJson(LuoXueSongDifficulties difficulties) {
    return {
      'standard': difficulties.standard?.map((d) => _difficultyToJson(d)).toList(),
      'dx': difficulties.dx?.map((d) => _difficultyToJson(d)).toList(),
      'utage': difficulties.utage?.map((u) => _utageToJson(u)).toList(),
    };
  }

  Map<String, dynamic> _difficultyToJson(LuoXueSongDifficulty difficulty) {
    return {
      'type': difficulty.type,
      'difficulty': difficulty.difficulty,
      'level': difficulty.level,
      'levelValue': difficulty.levelValue,
      'noteDesigner': difficulty.noteDesigner,
      'version': difficulty.version,
      'notes': difficulty.notes != null ? _notesToJson(difficulty.notes!) : null,
    };
  }

  Map<String, dynamic> _utageToJson(LuoXueSongDifficultyUtage utage) {
    return {
      'kanji': utage.kanji,
      'description': utage.description,
      'isBuddy': utage.isBuddy,
      'notes': utage.notes != null ? _anyNotesToJson(utage.notes!) : null,
    };
  }

  Map<String, dynamic> _anyNotesToJson(Object notes) {
    if (notes is LuoXueSongNotes) {
      return _notesToJson(notes);
    } else if (notes is LuoXueBuddyNotes) {
      return _buddyNotesToJson(notes);
    }
    return {};
  }

  Map<String, dynamic> _buddyNotesToJson(LuoXueBuddyNotes notes) {
    return {
      'left': notes.left != null ? _notesToJson(notes.left!) : null,
      'right': notes.right != null ? _notesToJson(notes.right!) : null,
    };
  }

  Map<String, dynamic> _notesToJson(LuoXueSongNotes notes) {
    return {
      'total': notes.total,
      'tap': notes.tap,
      'hold': notes.hold,
      'slide': notes.slide,
      'touch': notes.touch,
      'break': notes.breakNote, // 注意：JSON中的字段名为break
    };
  }

  Map<String, dynamic> _genreToJson(LuoXueGenre genre) {
    return {
      'id': genre.id,
      'title': genre.title,
      'genre': genre.genre,
    };
  }

  Map<String, dynamic> _versionToJson(LuoXueVersion version) {
    return {
      'id': version.id,
      'title': version.title,
      'version': version.version,
    };
  }

  // 清除缓存
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(CacheKeyConstant.luoxueSongsCache);
      _luoXueSongEntity = null;
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }
}