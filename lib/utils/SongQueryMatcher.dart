/*
 * 歌名搜索的**唯一**匹配规则。
 *
 * 由来：随身听搜索要求「照搬乐曲查询页（SongSearchPage）的逻辑」，而那份逻辑原本
 * 写死在 `SongSearchService.searchSongs` 里，只吃水鱼的 `Song`。
 * 与其在随身听里再抄一份（两份迟早会漂移），这里抽成一份**纯函数**，
 * 两个调用点都走它：
 *   * `SongSearchService.searchSongs` —— 乐曲查询页（水鱼 Song）
 *   * `PortableSongLibrary.search` —— 随身听（随身听条目）
 *
 * 匹配字段（与乐曲查询页逐条对齐）：id 精确 / 曲名 / 艺术家 / BPM 精确 /
 * 谱师 / 流派 / 版本 / 别名，任一命中即算匹配；全部大小写不敏感。
 */
import '../entity/DivingFish/Song.dart';
import '../entity/Portable/PortableSong.dart';

/// 查询串规范化：去首尾空白 + 转小写。
///
/// 只 trim 不删中间空格 —— 乐曲查询页原来就是 `query.toLowerCase()`，
/// 保留中间空格能让「Link CoF」这类带空格的搜索按预期工作。
String normalizeSongQuery(String query) => query.trim().toLowerCase();

/// 水鱼 [Song] 是否命中查询（乐曲查询页用）。
///
/// [aliases] 传该曲的别名列表（`SongAliasManager.instance.aliases[song.title]`）。
bool matchesDivingFishSongQuery(
  Song song,
  String normalizedQuery, {
  List<String> aliases = const <String>[],
}) {
  // 歌曲 ID（精确匹配，和乐曲查询页一致：`song.id.toString() == query`）
  if (song.id.trim() == normalizedQuery) return true;
  // 曲名
  if (song.basicInfo.title.toLowerCase().contains(normalizedQuery)) return true;
  // 艺术家
  if (song.basicInfo.artist.toLowerCase().contains(normalizedQuery)) {
    return true;
  }
  // BPM（精确匹配）
  if (song.basicInfo.bpm.toString() == normalizedQuery) return true;
  // 谱师
  for (final chart in song.charts) {
    if (chart.charter.toLowerCase().contains(normalizedQuery)) return true;
  }
  // 流派
  if (song.basicInfo.genre.toLowerCase().contains(normalizedQuery)) return true;
  // 版本
  if (song.basicInfo.from.toLowerCase().contains(normalizedQuery)) return true;
  // 别名
  for (final alias in aliases) {
    if (alias.toLowerCase().contains(normalizedQuery)) return true;
  }
  return false;
}

/// 随身听条目是否命中查询。
///
/// 字段集合与 [matchesDivingFishSongQuery] 一一对应：
///   * id 精确 → 两个 id 都比（水鱼 id 和落雪 id，用户看到的编号是哪个都不奇怪，
///     但**落雪 id 不参与 contains**：像 `1` 这种短数字会命中一大片）
///   * 曲名 / 艺术家 / 流派 → 普通 contains
///   * BPM 精确 / 别名 contains
///   * 谱师、版本 → 随身听条目里**没有**这两个字段（不为了搜索把整个水鱼
///     `Song` 塞进库缓存，那会让条目体积涨好几倍）。因此这两项在随身听里搜不到，
///     这是刻意的取舍。
bool matchesPortableSongQuery(
  PortableSong song,
  String normalizedQuery, {
  List<String> aliases = const <String>[],
}) {
  if (normalizedQuery.isEmpty) return true;
  final dfId = song.divingFishId.trim();
  if (dfId == normalizedQuery) return true;
  if ('${song.lxnsId}' == normalizedQuery) return true;
  if (song.title.toLowerCase().contains(normalizedQuery)) return true;
  if (song.artist.toLowerCase().contains(normalizedQuery)) return true;
  if (song.bpm.toString() == normalizedQuery) return true;
  if (song.genre.toLowerCase().contains(normalizedQuery)) return true;
  for (final alias in aliases) {
    if (alias.toLowerCase().contains(normalizedQuery)) return true;
  }
  return false;
}
