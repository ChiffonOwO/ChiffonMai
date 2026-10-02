// 理论 Rating 强制排除名单（#11879）的回归测试。
//
// 口径来源：`SongFilterUtil.theoreticalRatingExcludedIds`。
// 理论 Rating 在**两个地方**各算一遍：
//   1) `SongInfoService.getTheoreticalRatingParts()`（录入校验 / 历史曲线用的上限）；
//   2) `Best50Page._calculateTheoreticalBest50()`（Best50 页切到「理论Rating」模式）。
// 两处都必须吃同一份白名单，否则同一份曲库会算出两个上限。
//
// 这里用 `ds` 造出「不排除就一定会顶高上限」的 #11879：
//   * 公式 `ds × 0.224 × 100.5` 向下取整；
//   * #11879 ds 15.0 → 337；#11878 ds 13.6 → 306。
// 排除生效时总和必须是 306（而不是 643）。
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_first_flutter_app/constant/CacheKeyConstant.dart';
import 'package:my_first_flutter_app/manager/DivingFish/MaimaiMusicDataManager.dart';
import 'package:my_first_flutter_app/service/SongInfoService.dart';
import 'package:my_first_flutter_app/utils/SongFilterUtil.dart';

/// 造一首能被 `Song` 解析、且会参与理论 Rating 的常规曲。
Map<String, dynamic> song(String id, {required double ds, bool isNew = false}) => {
      'id': id,
      'title': 'song-$id',
      'type': 'DX',
      'ds': <double>[ds, ds, ds, ds, ds],
      'level': <String>['1', '2', '3', '4', '5'],
      'cids': <int>[1, 2, 3, 4],
      'charts': <Map<String, dynamic>>[
        for (var i = 0; i < 5; i++)
          {'notes': <int>[263, 14, 19, 6], 'charter': '譜面-$i'},
      ],
      'basic_info': {
        'title': 'song-$id',
        'artist': 'test',
        'genre': '舞萌',
        'bpm': 150,
        'release_date': '',
        'from': 'maimai',
        'is_new': isNew,
      },
    };

/// 公式：`ds × 0.224 × 100.5` 向下取整。
int theoreticalRa(double ds) => (ds * 0.224 * 100.5).floor();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // 曲库在内存里缓一份（只读一次 prefs），每个用例都要让它失效，
    // 否则第一个用例的曲库会一直顶到后面几个用例。
    MaimaiMusicDataManager().invalidateCache();
  });

  test('白名单里确实有 #11879', () {
    expect(SongFilterUtil.isTheoreticalRatingExcluded('11879'), isTrue);
    // 相邻 id 不能被顺手吃掉。
    expect(SongFilterUtil.isTheoreticalRatingExcluded('11878'), isFalse);
    expect(SongFilterUtil.isTheoreticalRatingExcluded('11880'), isFalse);
  });

  test('理论 Rating 计算排除 #11879（其余曲目照常参与）', () async {
    SharedPreferences.setMockInitialValues({
      CacheKeyConstant.cachedSongs: json.encode([
        song('11878', ds: 13.6),
        song('11879', ds: 15.0), // 不排除时会把总和顶到 643
        song('11900', ds: 12.0, isNew: true),
      ]),
    });

    final limits = await SongInfoService.getTheoreticalRatingParts();

    expect(limits.best35, theoreticalRa(13.6),
        reason: '#11879 不得进入旧曲池');
    expect(limits.best15, theoreticalRa(12.0),
        reason: '新曲池不受影响');
    expect(limits.total, theoreticalRa(13.6) + theoreticalRa(12.0));
    expect(limits.total, isNot(theoreticalRa(13.6) + theoreticalRa(15.0) + theoreticalRa(12.0)),
        reason: '把 #11879 算进来就是回归');
  });
}
