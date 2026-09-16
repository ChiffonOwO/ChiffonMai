import '../../entity/DivingFish/RecordItem.dart';
import '../../entity/DivingFish/Song.dart';
import '../../manager/DivingFish/MaimaiMusicDataManager.dart';
import '../../manager/DivingFish/UserPlayDataManager.dart';
import '../../utils/StringUtil.dart';
import 'DiffBest50Service.dart';

/// 理想 Best50：对全部游玩记录做「非 SSS+ 升一档」（升到上一档的下限），
/// 重算 RA 后重新取 B35 + B15，并给出相对原榜的新进榜歌曲。
class IdealBest50Service {
  static final IdealBest50Service _instance = IdealBest50Service._internal();
  factory IdealBest50Service() => _instance;
  IdealBest50Service._internal();

  /// 非 SSS+ 达成率升到上一档的下限；SSS+（>= 100.5）原样保留。
  static double bumpTier(double achievement) {
    if (achievement >= 100.5) return achievement; // SSS+
    if (achievement >= 100.0) return 100.5; // SSS -> SSS+
    if (achievement >= 99.5) return 100.0; // SS+ -> SSS
    if (achievement >= 99.0) return 99.5; // SS -> SS+
    if (achievement >= 98.0) return 99.0; // S+ -> SS
    if (achievement >= 97.0) return 98.0; // S -> S+
    if (achievement >= 94.0) return 97.0; // AAA -> S
    if (achievement >= 90.0) return 94.0; // AA -> AAA
    if (achievement >= 80.0) return 90.0; // A -> AA
    if (achievement >= 75.0) return 80.0; // BBB -> A
    if (achievement >= 70.0) return 75.0; // BB -> BBB
    if (achievement >= 60.0) return 70.0; // B -> BB
    if (achievement >= 50.0) return 60.0; // C -> B
    return 50.0; // D -> C
  }

  /// 计算理想 Best50。无游玩数据缓存时返回 null。
  Future<Map<String, dynamic>?> calculate() async {
    final raw = await UserPlayDataManager().getCachedUserPlayData();
    if (raw == null || raw['records'] is! List) return null;

    final records = (raw['records'] as List)
        .whereType<Map<String, dynamic>>()
        .map(RecordItem.fromJson)
        .toList();
    if (records.isEmpty) return null;

    final songs = await MaimaiMusicDataManager().getCachedSongs() ?? <Song>[];
    final Map<String, bool> isNewById = {
      for (final s in songs) s.id: s.basicInfo.isNew,
    };

    final calc = DiffBest50Service();

    final idealOld = <Map<String, dynamic>>[];
    final idealNew = <Map<String, dynamic>>[];
    final origOld = <Map<String, dynamic>>[];
    final origNew = <Map<String, dynamic>>[];
    final origRaByKey = <String, int>{};

    for (final r in records) {
      final isNew = isNewById[r.songId.toString()] ?? false;
      final idealAch = bumpTier(r.achievements.toDouble());
      final idealRa = calc.calculateSingleRating(r.ds, idealAch);
      final key = '${r.songId}_${r.levelIndex}';

      final idealMap = {
        ...r.toJson(),
        'achievements': idealAch,
        'ra': idealRa,
        'rate': StringUtil.rateCodeFromAchievement(idealAch),
        'is_new': isNew,
      };
      final origMap = {
        ...r.toJson(),
        'is_new': isNew,
      };

      if (isNew) {
        idealNew.add(idealMap);
        origNew.add(origMap);
      } else {
        idealOld.add(idealMap);
        origOld.add(origMap);
      }
      origRaByKey[key] = r.ra;
    }

    int byRaDesc(Map<String, dynamic> a, Map<String, dynamic> b) =>
        (b['ra'] as int).compareTo(a['ra'] as int);
    idealOld.sort(byRaDesc);
    idealNew.sort(byRaDesc);
    origOld.sort(byRaDesc);
    origNew.sort(byRaDesc);

    final idealSd = idealOld.take(35).toList();
    final idealDx = idealNew.take(15).toList();
    final origSd = origOld.take(35).toList();
    final origDx = origNew.take(15).toList();

    final idealRating = _sumRa([...idealSd, ...idealDx]);
    final originalRating = _sumRa([...origSd, ...origDx]);

    final origKeys = <String>{
      for (final m in [...origSd, ...origDx])
        '${m['song_id']}_${m['level_index']}',
    };
    final newEntries = <Map<String, dynamic>>[];
    for (final m in [...idealSd, ...idealDx]) {
      final key = '${m['song_id']}_${m['level_index']}';
      if (origKeys.contains(key)) continue;
      newEntries.add({
        'title': m['title'] ?? '未知歌曲',
        'ds': m['ds'] ?? 0,
        'level_index': m['level_index'] ?? 0,
        'oldRa': origRaByKey[key] ?? 0,
        'newRa': m['ra'] ?? 0,
      });
    }
    newEntries.sort((a, b) => (b['newRa'] as int).compareTo(a['newRa'] as int));

    return {
      'sd': idealSd,
      'dx': idealDx,
      'rating': idealRating,
      'originalRating': originalRating,
      'newEntries': newEntries,
    };
  }

  static int _sumRa(List<Map<String, dynamic>> songs) =>
      songs.fold<int>(0, (sum, m) => sum + ((m['ra'] ?? 0) as int));
}
