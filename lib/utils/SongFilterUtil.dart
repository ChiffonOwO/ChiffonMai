import '../entity/DivingFish/Song.dart';

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
  static bool isExtra(Song song) {
    if (song.id.length == 6) return true;
    if (song.cids.isNotEmpty && song.cids.every((cid) => cid == 0)) return true;
    if (song.isExtra) return true;
    return false;
  }
}