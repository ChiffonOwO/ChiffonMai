/**
 * 随身听曲库条目。
 *
 * 一条 = 一首**可播放**的歌，把两个数据源拼在一起：
 *   - 落雪（`maimai.lxns.net/api/v0/maimai/song/list`）：提供**音源文件**命名依据，
 *     以及本地曲绘 assets 的命名依据；
 *   - 水鱼（`diving-fish.com/.../music_data`）：提供歌名、艺术家、流派、bpm。
 *
 * 三个 id 的关系是**实测**出来的，不是推测，详见
 * [PortableSongMapService] 顶部注释与 `test/portable_song_map_test.dart`。
 */
class PortableSong {
  /// 落雪曲目 id（`song/list` 里的 `id`）。
  ///
  /// 同时是**本地曲绘 assets 的文件名**：`assets/cover/{lxnsId}.webp`
  /// （已核实：`1466.webp` 存在、`11466.webp` 不存在）。
  final int lxnsId;

  /// 水鱼曲目 id（`music_data` 里的 `id`，字符串形式，因为 `Song.id` 是 String）。
  ///
  /// 用于**曲绘、歌名、艺术家**。注意水鱼把同一首曲的标准/DX 谱面拆成了两条
  /// 记录（如 `1001` 标准 / `11001` DX），这里存的是**非取余的那条规范 id**。
  final String divingFishId;

  /// 音源文件 id：`assets2.lxns.net/maimai/music/{audioId}.mp3`。
  ///
  /// 等于 `int(divingFishId) % 10000`，**必须**走
  /// [LuoXueSongUtil.toLxnsMusicId]（6 位宴会场也要取余，与成绩 API 规则相反）。
  final int audioId;

  final String title;
  final String artist;
  final String genre;
  final int bpm;

  /// 该曲在水鱼曲库里是否有 DX 谱面条目（只用于列表上的一个小标记）。
  final bool hasDx;

  const PortableSong({
    required this.lxnsId,
    required this.divingFishId,
    required this.audioId,
    required this.title,
    required this.artist,
    required this.genre,
    required this.bpm,
    this.hasDx = false,
  });

  /// 音源 URL（**点击歌曲行时才使用**，不要在列表渲染阶段请求它）。
  String get audioUrl =>
      'https://assets2.lxns.net/maimai/music/$audioId.mp3';

  /// 本地曲绘 assets 用的 id（= [audioId]，因为本地 assets 按落雪 id 命名）。
  int get coverAssetId => audioId;

  /// 网络曲绘用的 id：水鱼 covers 目录的命名规则是**水鱼曲目 id 左补零到 5 位**。
  ///
  /// ⚠️ 这里用的是 [divingFishId]（**不取余**），不是 [audioId]。
  /// 两者只对宴会场不同，而宴会场恰好是最容易搞错的一批：
  /// 实测 `covers/100018.png` = 200、`covers/00018.png` = 404；
  /// 反过来音源是 `music/18.mp3` = 200、`music/100018.mp3` = 404 —— 曲绘和音源
  /// 的命名规则**不一样**，别互相套用。
  ///
  /// 其余实测样本：`covers/11466.png` 200、`covers/00008.png` 200、
  /// `covers/01113.png` 404、`covers/01466.png` 404。抽样 31 首命中 30，
  /// 唯一失败的 `110121` 是宴会场，由 `DxRatingCoverImage` 兜底。
  String get coverNetworkId {
    final id = int.tryParse(divingFishId.trim());
    if (id == null || id <= 0) return audioId.toString().padLeft(5, '0');
    return id.toString().padLeft(5, '0');
  }

  /// 网络曲绘 URL（diving-fish）。作为通知栏 `artUri` 的兜底。
  String get coverNetworkUrl =>
      'https://www.diving-fish.com/covers/$coverNetworkId.png';

  /// 本地曲绘 assets 的完整路径。
  ///
  /// 本地 `assets/cover/*.webp`（1682 张）是按**落雪 id** 命名的，
  /// 而落雪 id 恰好等于 `水鱼id % 10000`，所以这里用 [coverAssetId]。
  String get coverAssetPath => 'assets/cover/$coverAssetId.webp';

  /// 通知栏/列表用的稳定唯一键。
  String get portableKey => 'lxns:$lxnsId';

  @override
  String toString() =>
      'PortableSong(lxns=$lxnsId, df=$divingFishId, audio=$audioId, $title)';
}
