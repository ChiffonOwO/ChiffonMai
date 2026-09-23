/*
 * 随身听曲库映射：把**落雪**曲目 id 映射到**水鱼**曲目 id，从而拿到曲绘、歌名、
 * 艺术家；音源则按落雪音频文件命名规则推出来。
 *
 * ============================================================================
 * 三个 id 的关系（2026-09 对着线上全量数据实测，不是推测）
 * ============================================================================
 *
 * 数据量：落雪 `song/list` 1344 首；水鱼 `music_data` 1394 首。
 *
 * 1. **落雪 id → 水鱼 id**：只有两种关系，没有第三种
 *      - `水鱼 id = 落雪 id + 10000`：791 首（都是 DX 曲）。例：落雪 1001
 *        「BLACK ROSE」↔ 水鱼 11001「BLACK ROSE」。
 *      - `水鱼 id = 落雪 id`：544 首（标准曲为主）。例：落雪 8 ↔ 水鱼 8。
 *      - 两边都对不上的只有 **9 首**（落雪比水鱼新的新曲，水鱼还没收录），
 *        这类曲目在随身听里**不列出**（拿不到曲绘/歌名，用户已确认该策略）。
 *
 * 2. **按 id 映射是安全的**：落雪与水鱼共有的 603 个 id 里，**602 个是同一首歌**；
 *    唯一冲突是 `id=383`：落雪「Link」vs 水鱼「Link(CoF)」。
 *    所以匹配时**必须同时校验曲名**，不能只信 id —— 否则 383 会串歌。
 *
 *    对比：旧的 `SongPlayService` 只按曲名匹配，实测 1344 首里只有约 600 首能命中，
 *    且遇到同名异谱（标准/DX）会张冠李戴。
 *
 * 3. **音源文件名**：`assets2.lxns.net/maimai/music/{水鱼id % 10000}.mp3`
 *    - 5 位 DX 曲：水鱼 11466 → `1466.mp3` 命中，`11466.mp3` 404；
 *    - 6 位宴会场（62 首**逐首实测**）：水鱼 100018 → `18.mp3` 命中，
 *      `100018.mp3` 404。
 *    - 所以**一律取余**，实现直接复用 [LuoXueSongUtil.toLxnsMusicId]，
 *      不要自己写一套（成绩 API 的 `toLxnsSongId` 对宴会场**不取余**，别混用）。
 *
 * 4. **曲绘**：
 *    - 本地 `assets/cover/{落雪id}.webp` 优先（1682 张，按落雪 id 命名）；
 *      对 5/6 位曲目来说落雪 id 恰好等于 `水鱼id % 10000`。
 *    - 网络兜底 `diving-fish.com/covers/{水鱼id 左补零到 5 位}.png`。
 *
 * ============================================================================
 * 本文件里的映射函数是**纯函数**（只吃两份 Song 列表），便于单测；
 * 拉数据与缓存交给 [PortableSongLibrary]。
 * ============================================================================
 */
import 'dart:convert';

import '../../entity/DivingFish/Song.dart';
import '../../entity/LuoXue/LuoXueSongEntity.dart';
import '../../entity/Portable/PortableSong.dart';
import '../../utils/LuoXueSongUtil.dart';

/// 水鱼 DX 条目相对落雪 id 的偏移量（实测固定为 10000）。
const int kDivingFishDxIdOffset = 10000;

/// 宴会场曲目的落雪 id 下限。
///
/// 实测（2026-09，落雪全量 1344 首）：`difficulties.utage` 非空的 62 首，
/// 与 `id >= 100000` 的 62 首**完全一致、零分歧**。两种判定都用上，是为了
/// 万一以后落雪补了某首宴会场却没填 utage 难度列表。
const int kUtageIdFloor = 100000;

/// 这首歌是不是宴会场（UTAGE）。
bool isUtageLuoXueSong(LuoXueSong song) {
  if (song.id >= kUtageIdFloor) return true;
  return song.difficulties.utage?.isNotEmpty ?? false;
}

/// 曲名规范化：小写、去掉所有空白（含全角空格）、全角括号转半角。
///
/// 两个库的曲名实测基本一致，但空格/括号写法偶有差异，规范化后比较更稳。
String normalizePortableTitle(String raw) {
  return raw
      .toLowerCase()
      .replaceAll(RegExp(r'[\s\u3000]+'), '')
      .replaceAll('（', '(')
      .replaceAll('）', ')')
      .replaceAll('　', '');
}

/// 水鱼曲库索引：按 id、按规范化曲名两端都能查。
class DivingFishSongIndex {
  final Map<int, Song> byId = <int, Song>{};
  final Map<String, List<Song>> byTitle = <String, List<Song>>{};

  DivingFishSongIndex(Iterable<Song> songs) {
    for (final song in songs) {
      final id = int.tryParse(song.id.trim());
      if (id != null) {
        // 同 id 重复时保留第一个（水鱼不该出现重复 id，防御性处理）
        byId.putIfAbsent(id, () => song);
      }
      final key = normalizePortableTitle(song.title);
      if (key.isEmpty) continue;
      byTitle.putIfAbsent(key, () => <Song>[]).add(song);
    }
  }

  bool get isEmpty => byId.isEmpty;

  /// [id] 处是否有一首**曲名一致**的歌。
  ///
  /// 必须校验曲名：`id=383` 在落雪是「Link」、在水鱼是「Link(CoF)」，只信 id 会串歌。
  Song? matchByIdAndTitle(int id, String lxnsTitle) {
    final song = byId[id];
    if (song == null) return null;
    if (normalizePortableTitle(song.title) == normalizePortableTitle(lxnsTitle)) {
      return song;
    }
    return null;
  }

  /// 只按曲名找（兜底：id 体系有偏差时仍尽量把歌列出来）。
  ///
  /// 同名多条时优先返回 id 较小的那条（标准谱条目 id 更小）。
  Song? matchByTitleOnly(String lxnsTitle) {
    final list = byTitle[normalizePortableTitle(lxnsTitle)];
    if (list == null || list.isEmpty) return null;
    final sorted = List<Song>.from(list)
      ..sort((a, b) => (int.tryParse(a.id) ?? 1 << 30)
          .compareTo(int.tryParse(b.id) ?? 1 << 30));
    return sorted.first;
  }
}

/// 单首曲目的映射结果。
class PortableMapResult {
  final PortableSong? song;

  /// 未命中时的原因（用于调试与列表底部的统计提示）。
  final String? skipReason;

  const PortableMapResult({
    this.song,
    this.skipReason,
  });

  bool get playable => song != null;
}

/// 把一首落雪曲目映射成随身听条目，返回 `null` 表示不可播放（水鱼查无此曲）。
///
/// 规则见文件头。这里**只看 id**，不做模糊匹配。
PortableMapResult mapOneLuoXueSong(
  LuoXueSong lxnsSong,
  DivingFishSongIndex index,
) {
  final lxnsId = lxnsSong.id;

  // ① 水鱼 id = 落雪 id（标准曲为主）
  var dfSong = index.matchByIdAndTitle(lxnsId, lxnsSong.title);
  var divingFishId = lxnsId;

  // ② 水鱼 id = 落雪 id + 10000（DX 曲）
  if (dfSong == null) {
    final dxCandidate = lxnsId + kDivingFishDxIdOffset;
    final matched = index.matchByIdAndTitle(dxCandidate, lxnsSong.title);
    if (matched != null) {
      dfSong = matched;
      divingFishId = dxCandidate;
    }
  }

  // ③ 兜底：只按曲名找（id 体系若有偏差，至少别把歌丢掉）
  if (dfSong == null) {
    dfSong = index.matchByTitleOnly(lxnsSong.title);
    if (dfSong != null) {
      final parsed = int.tryParse(dfSong.id.trim());
      if (parsed != null) divingFishId = parsed;
    }
  }

  if (dfSong == null) {
    return const PortableMapResult(skipReason: '水鱼曲库无此曲');
  }

  // 音源 id 一律取余（6 位宴会场也取余），复用已有实现避免两套规则打架。
  final audioId = LuoXueSongUtil.toLxnsMusicId('$divingFishId');
  if (audioId <= 0) {
    return const PortableMapResult(skipReason: '音源 id 非法');
  }

  // 是否存在 DX 谱面：落雪难度数据里 dx 非空，或水鱼那边另有 +10000 的 DX 条目。
  //
  // ⚠️ 这个标记必须在**构造 PortableSong 时**就写进去：PortableSong 是不可变的，
  // 早先的写法是把 hasDx 放在 PortableMapResult 上再由 buildPortableLibrary 取
  // result.song，结果标记一路被丢掉（单测直接抓到了）。
  final hasDx = (lxnsSong.difficulties.dx?.isNotEmpty ?? false) ||
      index.matchByIdAndTitle(
            lxnsId + kDivingFishDxIdOffset,
            lxnsSong.title,
          ) !=
          null;

  return PortableMapResult(
    song: PortableSong(
      lxnsId: lxnsId,
      divingFishId: dfSong.id,
      audioId: audioId,
      // 歌名/艺术家以水鱼为准（用户要求），落雪只在为空时兜底
      title: dfSong.title.trim().isNotEmpty
          ? dfSong.title.trim()
          : lxnsSong.title.trim(),
      artist: dfSong.basicInfo.artist.trim().isNotEmpty
          ? dfSong.basicInfo.artist.trim()
          : lxnsSong.artist.trim(),
      genre: dfSong.basicInfo.genre.trim().isNotEmpty
          ? dfSong.basicInfo.genre.trim()
          : lxnsSong.genre.trim(),
      bpm: dfSong.basicInfo.bpm > 0 ? dfSong.basicInfo.bpm : lxnsSong.bpm,
      hasDx: hasDx,
    ),
  );
}

/// 批量映射：落雪全量 → 随身听曲库。
///
/// **宴会场（UTAGE）不收录**：随身听是听歌用的，宴会场是活动/联动的特殊谱面
/// （62 首，实测），列表里混进去只会干扰。判定见 [isUtageLuoXueSong]。
///
/// 按落雪 id **去重**（已确认「一首歌一行、不区分 SD/DX」）：
/// 同一首曲的标准与 DX 在水鱼是两条记录（1001 / 11001），但落雪只有一条曲目 id，
/// 所以走落雪列表天然就是一首一行，不会出现重复曲名。
///
/// 返回结果按曲名排序（用 [normalizePortableTitle] 作为排序键，中日文混排也稳定）。
PortableLibraryResult buildPortableLibrary({
  required List<LuoXueSong> lxnsSongs,
  required List<Song> divingFishSongs,
  bool excludeUtage = true,
}) {
  final index = DivingFishSongIndex(divingFishSongs);
  final songs = <PortableSong>[];
  var skipped = 0;
  var excludedUtage = 0;

  for (final lxnsSong in lxnsSongs) {
    if (excludeUtage && isUtageLuoXueSong(lxnsSong)) {
      excludedUtage++;
      continue;
    }
    final result = mapOneLuoXueSong(lxnsSong, index);
    if (result.song == null) {
      skipped++;
      continue;
    }
    songs.add(result.song!);
  }

  songs.sort((a, b) {
    final byTitle = normalizePortableTitle(a.title)
        .compareTo(normalizePortableTitle(b.title));
    if (byTitle != 0) return byTitle;
    return a.lxnsId.compareTo(b.lxnsId);
  });

  return PortableLibraryResult(
    songs: songs,
    skippedCount: skipped,
    divingFishSongCount: divingFishSongs.length,
    excludedUtageCount: excludedUtage,
  );
}

class PortableLibraryResult {
  final List<PortableSong> songs;

  /// 落雪有、水鱼查无对应条目而跳过的曲目数。
  final int skippedCount;

  /// 因为「是宴会场」被排除的曲目数（实测 62）。
  final int excludedUtageCount;

  final int divingFishSongCount;

  const PortableLibraryResult({
    required this.songs,
    required this.skippedCount,
    required this.divingFishSongCount,
    this.excludedUtageCount = 0,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'version': 1,
        'skippedCount': skippedCount,
        'excludedUtageCount': excludedUtageCount,
        'divingFishSongCount': divingFishSongCount,
        'songs': songs
            .map((s) => <String, dynamic>{
                  'lxnsId': s.lxnsId,
                  'divingFishId': s.divingFishId,
                  'audioId': s.audioId,
                  'title': s.title,
                  'artist': s.artist,
                  'genre': s.genre,
                  'bpm': s.bpm,
                  'hasDx': s.hasDx,
                })
            .toList(),
      };

  static PortableLibraryResult? fromJsonString(String raw) {
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final list = decoded['songs'];
      if (list is! List) return null;
      final songs = <PortableSong>[];
      for (final item in list) {
        if (item is! Map) continue;
        final lxnsId = item['lxnsId'];
        final audioId = item['audioId'];
        final title = item['title'];
        if (lxnsId is! int || audioId is! int || title is! String) continue;
        songs.add(PortableSong(
          lxnsId: lxnsId,
          divingFishId: '${item['divingFishId'] ?? audioId}',
          audioId: audioId,
          title: title,
          artist: '${item['artist'] ?? ''}',
          genre: '${item['genre'] ?? ''}',
          bpm: item['bpm'] is int ? item['bpm'] as int : 0,
          hasDx: item['hasDx'] == true,
        ));
      }
      if (songs.isEmpty) return null;
      return PortableLibraryResult(
        songs: songs,
        skippedCount:
            decoded['skippedCount'] is int ? decoded['skippedCount'] as int : 0,
        excludedUtageCount: decoded['excludedUtageCount'] is int
            ? decoded['excludedUtageCount'] as int
            : 0,
        divingFishSongCount: decoded['divingFishSongCount'] is int
            ? decoded['divingFishSongCount'] as int
            : 0,
      );
    } catch (_) {
      return null;
    }
  }
}
