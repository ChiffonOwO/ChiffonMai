import '../entity/DivingFish/Song.dart';
import '../constant/VersionListConstant.dart';

/// 猜歌设置对话框里「可选的版本 / 可选的流派」。
class SongFilterOptions {
  /// 只含官方世代（[VersionListConstant.standardVersions]），已按发布顺序排序。
  final List<String> versions;

  /// 已剔除「宴会场」。
  final List<String> genres;

  const SongFilterOptions({required this.versions, required this.genres});
}

/// 歌曲「非正曲」判定工具。
///
/// maimai 曲库里有一批不应参与 Best50 / 推荐 / 流派统计 / 排行榜 等正式计算的曲目，
/// 集中放在这里统一判定，避免各 service / page 重复写 if 链。
///
/// 命中以下任意一条即视为 extra（不算正曲）：
///   1) songId 为 6 位数（宴会场谱面）
///   2) cids 全为 0（从 maidata 解析追加的谱面）
///   3) isExtra == true（union API 独有、不参与推荐系统的额外曲目）
class SongFilterUtil {
  SongFilterUtil._();

  /// 判断 [song] 是否为 extra（非正曲）。
  static bool isExtra(Song song) => isExtraRaw(
        songId: song.id,
        isExtraFlag: song.isExtra,
        cids: song.cids,
      );

  /// 与 [isExtra] 同一套规则，但接收**原始字段**。
  ///
  /// 给只有裸数据（`_songData['is_extra']` / `cids` / songId 字符串）的页面用：
  /// 排行榜这类页面拿不到 `Song` 实体，若各自手写 if 链，早晚会与 [isExtra] 走偏
  /// ——版本显示就是例子：漏判 extra 时，追加曲会显示成 `DX 2026 彩` 这种
  /// 官方世代年号名。
  static bool isExtraRaw({
    required String songId,
    bool? isExtraFlag,
    List<dynamic>? cids,
  }) {
    if (songId.length == 6) return true;
    if (cids != null && cids.isNotEmpty) {
      if (cids.every((cid) => (cid as num?)?.toInt() == 0)) return true;
    }
    if (isExtraFlag == true) return true;
    return false;
  }

  /// 统计猜歌设置里的「可选版本 / 可选流派」。
  ///
  /// 口径必须与抽曲池（各 `randomSelectSong`）一致，否则设置里会出现
  /// **勾了也永远抽不到** 的选项 —— 用户看到的是「当前筛选条件抽不到曲目」，
  /// 却完全不知道是选项本身没意义：
  ///   1) 先剔除非正曲（[isExtra]：宴会场 / maidata 追加 / union 独有）；
  ///   2) 「宴会场」流派再单独挡一次（有的宴会场曲 ID 不是 6 位，
  ///      但猜歌池同样不含它们）；
  ///   3) 版本还要过 [VersionListConstant.standardVersions] 白名单并按世代排序：
  ///      maidata 的 `&version` 是资源作者的自由文本，既不在官方世代里、
  ///      也没有「第几世代」可供 `versionOrderMap` 排序。
  ///
  /// 流派的先后顺序沿用原实现（按曲库遍历顺序），不做排序。
  static SongFilterOptions selectableFilters(Iterable<Song> songs) {
    final versions = <String>{};
    final genres = <String>{};

    for (final song in songs) {
      if (isExtra(song)) continue;
      if (song.basicInfo.genre == '宴会场') continue;
      versions.add(song.basicInfo.from);
      genres.add(song.basicInfo.genre);
    }

    final orderedVersions = versions
        .where((v) => VersionListConstant.standardVersions.contains(v))
        .toList()
      ..sort((a, b) {
        final int orderA = VersionListConstant.versionOrderMap[a] ?? 999;
        final int orderB = VersionListConstant.versionOrderMap[b] ?? 999;
        return orderA.compareTo(orderB);
      });

    return SongFilterOptions(
      versions: orderedVersions,
      genres: genres.toList(),
    );
  }
}