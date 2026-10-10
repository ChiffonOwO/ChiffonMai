/*
 * 随身听曲库仓库：以「落雪曲库」为基础，再追加 AWMC/Union 独有曲目，交给
 * [buildPortableLibrary] 做映射，结果进程内缓存 + 落盘缓存。
 *
 * 为什么要自己落盘缓存：
 *   - 映射结果（约 1087 首）是**两份曲库的交集**，纯计算得来，变动很慢；
 *   - 落雪曲库有数百 KB~数 MB，每次进随身听页都重新映射会卡 UI 线程。
 *
 * 缓存失效：`clearCache()`（在「刷新数据」流程里调用），以及水鱼/落雪曲库本身
 * 被清理时。缓存里带 `version` 字段，映射规则变了就把版本号 +1，旧缓存自动作废。
 */
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/ApiUrls.dart';
import '../../entity/DivingFish/Song.dart';
import '../../entity/LuoXue/LuoXueSongEntity.dart';
import '../../entity/Portable/PortableSong.dart';
import '../../manager/DivingFish/MaimaiMusicDataManager.dart';
import '../../manager/LuoXue/LuoXueSongsManager.dart';
import '../../manager/SongAliasManager.dart';
import '../../utils/ApiClient.dart';
import '../../utils/LuoXueSongUtil.dart';
import '../../utils/SongQueryMatcher.dart';
import 'PortableSongMapService.dart';

class PortableSongLibrary {
  PortableSongLibrary._internal();
  static final PortableSongLibrary _instance = PortableSongLibrary._internal();
  factory PortableSongLibrary() => _instance;

  /// 映射规则版本。**改动 [buildPortableLibrary] 的规则时必须 +1**，
  /// 否则老用户读到的是旧规则算出来的缓存（少歌 / 串歌）。
  /// v1: 初始版本（id / id+10000 + 曲名校验，音源取余）。
  /// v2: 排除宴会场曲目（`PortableLibraryResult.excludedUtageCount`）。
  /// v4: 追加 AWMC 独有曲目，并记录其音源优先级。
  /// v5: Union 全量作为 AWMC/落雪之外的补充索引。
  static const int cacheVersion = 5;

  static const String _prefsKey = 'portable_song_library_v$cacheVersion';

  List<PortableSong>? _songs;
  int _skippedCount = 0;
  int _excludedUtageCount = 0;
  int _divingFishSongCount = 0;
  Future<List<PortableSong>>? _loadFuture;

  /// 已在内存里的曲库（未加载则返回 null）。给同步 UI 判断用。
  List<PortableSong>? get songsOrNull => _songs;

  /// 上次构建时被跳过的曲目数（落雪有、水鱼无）。
  int get skippedCount => _skippedCount;

  /// 上次构建时因为「是宴会场」被排除的曲目数。
  int get excludedUtageCount => _excludedUtageCount;

  bool get isLoaded => _songs != null;

  /// 加载曲库（内存 → 落盘 → 重新构建）。
  Future<List<PortableSong>> load() async {
    final cached = _songs;
    if (cached != null) return cached;
    final inFlight = _loadFuture;
    if (inFlight != null) return inFlight;

    final future = _load();
    _loadFuture = future;
    try {
      return await future;
    } finally {
      _loadFuture = null;
    }
  }

  Future<List<PortableSong>> _load() async {
    // ① 落盘缓存
    final fromDisk = await _loadFromDisk();
    if (fromDisk != null) {
      _songs = fromDisk.songs;
      _skippedCount = fromDisk.skippedCount;
      _excludedUtageCount = fromDisk.excludedUtageCount;
      _divingFishSongCount = fromDisk.divingFishSongCount;
      return fromDisk.songs;
    }

    // ② 重新构建
    final result = await rebuild();
    return result;
  }

  /// 强制重新构建（忽略落盘缓存），并写回缓存。
  Future<List<PortableSong>> rebuild() async {
    // 四份目录互不依赖，并行拉取，Union 补充不会把随身听首帧再拖慢数秒。
    final lxnsFuture = _loadLuoXueSongs();
    final awmcFuture = _loadAwmcSongs();
    final divingFishFuture = _loadDivingFishSongs();
    final unionFuture = _loadUnionSongs();
    final lxnsSongs = await lxnsFuture;
    final awmcSongs = await awmcFuture;
    final divingFishSongs = await divingFishFuture;
    final unionSongs = await unionFuture;
    if (lxnsSongs.isEmpty && awmcSongs.isEmpty && unionSongs.isEmpty) {
      debugPrint('[Portable] 落雪、AWMC 与 Union 曲库都为空，随身听曲库无法构建');
      _songs = const <PortableSong>[];
      return _songs!;
    }

    // 映射是纯 CPU 计算（1344 首），放后台 isolate 免得卡首帧。
    final result = await compute(
      _buildInIsolate,
      _PortableBuildInput(
        lxnsSongs,
        divingFishSongs,
        awmcSongs,
        unionSongs,
      ),
    );

    _songs = result.songs;
    _skippedCount = result.skippedCount;
    _excludedUtageCount = result.excludedUtageCount;
    _divingFishSongCount = result.divingFishSongCount;
    debugPrint('[Portable] 曲库构建完成：可播放 ${result.songs.length} 首，'
        '排除宴会场 ${result.excludedUtageCount} 首，'
        '跳过 ${result.skippedCount} 首（水鱼无对应条目），'
        '追加 AWMC/Union 补充 ${result.songs.where((song) => song.isAwmcExtra).length} 首');
    await _saveToDisk(result);
    return _songs!;
  }

  /// 按乐曲查询页（`SongSearchPage`）的规则搜索随身听曲库。
  ///
  /// 规则本身在 `utils/SongQueryMatcher.dart` 里，与乐曲查询页共用同一份实现
  /// （需求原话是「照搬」）。差别只有一条：随身听条目里没有「谱师」和「版本」
  /// 这两个字段，所以搜不到它们 —— 详见 [matchesPortableSongQuery] 的注释。
  ///
  /// [query] 为空时返回全部（随身听是播放器，空搜索框应该显示完整列表，
  /// 而不是像乐曲查询页那样返回空 —— 那一页空查询等于「没搜」）。
  List<PortableSong> search(String query) {
    final all = _songs ?? const <PortableSong>[];
    final normalized = normalizeSongQuery(query);
    if (normalized.isEmpty) return all;
    return all
        .where((song) => matchesPortableSongQuery(
              song,
              normalized,
              aliases:
                  SongAliasManager.instance.aliases[song.title] ?? const [],
            ))
        .toList();
  }

  /// 有没有这首歌 —— 给「歌曲详情页点播放」这类只有一个水鱼 id 的入口用。
  ///
  /// 同一个 id 在库里可能对应多条记录（水鱼和落雪是两套编号体系），先用精确 id 匹配，
  /// 匹配不到再用 `id % 10000` 归一化匹配。归一化是安全的，因为：
  /// * 规范水鱼 id → 相同，
  /// * 水鱼 DX 6 位 id（100030）→ 30 = 落雪 id，
  /// * 宴会场 6 位 id（100018）→ 18 = 落雪 id。
  ///
  /// 另有一条按「曲名 + 类型」的兜底匹配，因为同一个曲名在水鱼里可能对应多条记录
  /// —— 例如 383「Link(CoF)」和 10383「Link」是两首不同的曲子。
  PortableSong? findSong({
    String? songId,
    String? title,
    String? type,
  }) {
    final all = _songs;
    if (all == null || all.isEmpty) return null;

    final normalizedId =
        songId == null ? null : _normalizeSongIdForLookup(songId);
    if (normalizedId != null) {
      for (final song in all) {
        if (song.divingFishId == songId) return song;
      }
      for (final song in all) {
        if (song.audioId == normalizedId) return song;
      }
    }

    final wantedTitle = title == null ? null : normalizePortableTitle(title);
    if (wantedTitle == null || wantedTitle.isEmpty) return null;

    final wantedType = type == null || type.isEmpty ? null : type;
    for (final song in all) {
      if (normalizePortableTitle(song.title) != wantedTitle) continue;
      if (wantedType == null) return song;
      // 库是按落雪曲目去重的（一首一行），没有自己的「类型」字段；
      // 用 DX 标记代替判断：要 SD 时优先非 DX，要 DX 时优先 DX。
      if (wantedType == 'DX' && song.hasDx) return song;
      if (wantedType != 'DX' && !song.hasDx) return song;
    }
    // 类型对不上时退回「只要曲名对得上」，总比完全不播强
    for (final song in all) {
      if (normalizePortableTitle(song.title) == wantedTitle) return song;
    }
    return null;
  }

  /// 解析歌曲详情页的播放请求。
  ///
  /// 曲库索引是给列表展示用的缓存，落雪或 AWMC 的目录更新存在短暂不同步时，
  /// 不能把「索引里没有」直接当成「音源不存在」。详情页还掌握水鱼的原始
  /// `songId`，因此在索引未命中时保留这个 id，交给播放器按 AWMC 的
  /// `/s/{songId}/track.mp3` 兜底尝试。这样像 11968 这类谱面播放可用、曲库
  /// 索引尚未收录的歌曲也能播放。
  ///
  /// 该条目仍然使用 [PortableAudioCache] 的永久本地缓存；如果两个音源都不可用，
  /// 播放器才会把失败反馈给页面。
  PortableSong? resolveForPlayback({
    required String songId,
    String? title,
    String? type,
    String? artist,
    String? genre,
    int? bpm,
  }) {
    final rawId = int.tryParse(songId.trim());
    final audioId = rawId == null ? 0 : LuoXueSongUtil.toLxnsMusicId(songId);
    final indexed = findSong(songId: songId, title: title, type: type);
    if (indexed != null) {
      // findSong 为了列表兼容会按 audioId 取余匹配。详情页如果传入的是
      // 11968，而索引里只有 1968，必须把原始 id 带到 WMC 兜底 URL，不能
      // 把它悄悄改成 /s/1968/track.mp3。
      if (rawId == null || indexed.divingFishId == songId.trim()) {
        return indexed;
      }
      if (audioId <= 0 || indexed.audioId != audioId) return indexed;
      return PortableSong(
        lxnsId: indexed.lxnsId,
        divingFishId: songId.trim(),
        audioId: indexed.audioId,
        title: indexed.title,
        artist: indexed.artist,
        genre: indexed.genre,
        bpm: indexed.bpm,
        difficultyConstants: indexed.difficultyConstants,
        hasDx: indexed.hasDx,
        isAwmcExtra: indexed.isAwmcExtra,
      );
    }

    if (rawId == null || rawId <= 0) return null;
    if (audioId <= 0) return null;

    final fallback = PortableSong(
      // 落雪曲绘和本地缓存使用取余后的 id；AWMC 音源仍使用原始 songId。
      lxnsId: audioId,
      divingFishId: songId.trim(),
      audioId: audioId,
      title: title?.trim().isNotEmpty == true ? title!.trim() : '未知歌曲',
      artist: artist?.trim() ?? '',
      genre: genre?.trim() ?? '',
      bpm: bpm ?? 0,
      hasDx: type?.toUpperCase() == 'DX',
      isAwmcExtra: true,
    );
    _rememberPlaybackSong(fallback);
    return fallback;
  }

  /// 播放详情页可能先于曲库索引拿到一首新歌。把这条已确认可尝试播放的
  /// AWMC 条目加入内存/落盘索引，返回随身听后定位按钮就能找到它。
  void _rememberPlaybackSong(PortableSong song) {
    final all = _songs;
    if (all == null ||
        all.any((item) =>
            item.lxnsId == song.lxnsId &&
            item.divingFishId == song.divingFishId)) {
      return;
    }
    final updated = <PortableSong>[...all, song]..sort((a, b) {
        final byTitle = normalizePortableTitle(a.title)
            .compareTo(normalizePortableTitle(b.title));
        if (byTitle != 0) return byTitle;
        return a.lxnsId.compareTo(b.lxnsId);
      });
    _songs = List<PortableSong>.unmodifiable(updated);
    unawaited(_saveToDisk(PortableLibraryResult(
      songs: _songs!,
      skippedCount: _skippedCount,
      divingFishSongCount: _divingFishSongCount,
      excludedUtageCount: _excludedUtageCount,
    )));
  }

  /// 与 `DxRatingCoverService.normalizeSongId` 同口径：10000~19999 减 10000。
  static int? _normalizeSongIdForLookup(String raw) {
    final n = int.tryParse(raw.trim());
    if (n == null || n <= 0) return null;
    if (n >= 10000 && n < 20000) return n - 10000;
    return n;
  }

  /// 按落雪 id 精确取一首（随身听列表内部用）。
  PortableSong? findByLxnsId(int lxnsId) {
    final all = _songs;
    if (all == null) return null;
    for (final song in all) {
      if (song.lxnsId == lxnsId) return song;
    }
    return null;
  }

  /// 清除内存与落盘缓存。
  Future<void> clearCache() async {
    _songs = null;
    _skippedCount = 0;
    _divingFishSongCount = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (e) {
      debugPrint('[Portable] 清除曲库缓存失败: $e');
    }
  }

  // ── 数据来源 ─────────────────────────────────────────────────────────────

  Future<List<LuoXueSong>> _loadLuoXueSongs() async {
    try {
      final entity = await LuoXueSongsManager().getLuoXueSongs();
      return entity?.songs ?? const <LuoXueSong>[];
    } catch (e) {
      debugPrint('[Portable] 读取落雪曲库失败: $e');
      return const <LuoXueSong>[];
    }
  }

  /// 水鱼曲库：优先用主流程已经缓存的（`MaimaiMusicDataManager`），
  /// 缓存为空时（用户还没「刷新数据」）临时直连一次 `music_data`。
  ///
  /// 不调 `MaimaiMusicDataManager.fetchAndUpdateMusicData()` 是刻意的：
  /// 那个会顺带触发全量 maidata 刷新等一堆副作用，随身听不该背这个。
  Future<List<Song>> _loadDivingFishSongs() async {
    try {
      final manager = MaimaiMusicDataManager();
      if (await manager.hasCachedData()) {
        final cached = await manager.getCachedSongs();
        if (cached != null && cached.isNotEmpty) return cached;
      }
    } catch (e) {
      debugPrint('[Portable] 读取水鱼缓存曲库失败: $e');
    }

    try {
      debugPrint('[Portable] 水鱼曲库缓存为空，直连 music_data 拉一次');
      final response = await ApiClient.get(Uri.parse(ApiUrls.MusicDataApi));
      if (response.statusCode != 200) {
        debugPrint('[Portable] music_data 返回 ${response.statusCode}');
        return const <Song>[];
      }
      final dynamic decoded = json.decode(_decodeBody(response));
      if (decoded is! List) return const <Song>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(Song.fromJson)
          .toList();
    } catch (e) {
      debugPrint('[Portable] 直连 music_data 失败: $e');
      return const <Song>[];
    }
  }

  /// AWMC NET 曲库：songId 与 Union 全量一致，只作为落雪基础索引的追加来源。
  Future<List<Song>> _loadAwmcSongs() async {
    try {
      final response =
          await ApiClient.get(Uri.parse(ApiUrls.AwmcNetMusicDataApi));
      if (response.statusCode != 200) {
        debugPrint('[Portable] AWMC 曲库返回 ${response.statusCode}');
        return const <Song>[];
      }
      final dynamic decoded = json.decode(_decodeBody(response));
      if (decoded is! List) return const <Song>[];
      final songs = <Song>[];
      for (final item in decoded.whereType<Map<String, dynamic>>()) {
        try {
          songs.add(Song.fromJson(item));
        } catch (e) {
          debugPrint('[Portable] 跳过无法解析的 AWMC 曲目: $e');
        }
      }
      debugPrint('[Portable] AWMC 曲库读取 ${songs.length} 首');
      return songs;
    } catch (e) {
      debugPrint('[Portable] 读取 AWMC 曲库失败: $e');
      return const <Song>[];
    }
  }

  /// Union 全量元数据：用于补齐 AWMC 曲库尚未登记的新歌。
  Future<List<Song>> _loadUnionSongs() async {
    try {
      final response =
          await ApiClient.get(Uri.parse(ApiUrls.UnionMusicDataApi));
      if (response.statusCode != 200) {
        debugPrint('[Portable] Union 曲库返回 ${response.statusCode}');
        return const <Song>[];
      }
      final dynamic decoded = json.decode(_decodeBody(response));
      if (decoded is! List) return const <Song>[];
      final songs = <Song>[];
      for (final item in decoded.whereType<Map<String, dynamic>>()) {
        try {
          songs.add(Song.fromJson(item));
        } catch (e) {
          debugPrint('[Portable] 跳过无法解析的 Union 曲目: $e');
        }
      }
      debugPrint('[Portable] Union 曲库读取 ${songs.length} 首');
      return songs;
    } catch (e) {
      debugPrint('[Portable] 读取 Union 曲库失败: $e');
      return const <Song>[];
    }
  }

  /// 与 `LuoXueSongsManager` 一致：优先 utf8，失败再退回 `response.body`。
  String _decodeBody(http.Response response) {
    try {
      return utf8.decode(response.bodyBytes);
    } catch (_) {
      return response.body;
    }
  }

  // ── 落盘缓存 ─────────────────────────────────────────────────────────────

  Future<PortableLibraryResult?> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return null;
      final parsed = PortableLibraryResult.fromJsonString(raw);
      if (parsed == null) {
        await prefs.remove(_prefsKey);
      }
      return parsed;
    } catch (e) {
      debugPrint('[Portable] 读取落盘曲库失败: $e');
      return null;
    }
  }

  Future<void> _saveToDisk(PortableLibraryResult result) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, json.encode(result.toJson()));
    } catch (e) {
      debugPrint('[Portable] 写入落盘曲库失败: $e');
    }
  }
}

/// `compute` 的入参（必须是可跨 isolate 传递的简单结构）。
class _PortableBuildInput {
  final List<LuoXueSong> lxnsSongs;
  final List<Song> divingFishSongs;
  final List<Song> awmcSongs;
  final List<Song> unionSongs;
  const _PortableBuildInput(
      this.lxnsSongs, this.divingFishSongs, this.awmcSongs, this.unionSongs);
}

PortableLibraryResult _buildInIsolate(_PortableBuildInput input) {
  return buildPortableLibrary(
    lxnsSongs: input.lxnsSongs,
    divingFishSongs: input.divingFishSongs,
    awmcSongs: input.awmcSongs,
    unionSongs: input.unionSongs,
  );
}
