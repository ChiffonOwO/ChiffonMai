// 临时探针：复现「曲绘拼图猜歌一直转圈」
// 假设：_startNewGame 里 _targetSong == null 时没有 else 分支，
// 页面永远停在 _isGameStarted=false → 永久 CircularProgressIndicator。
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_first_flutter_app/constant/CacheKeyConstant.dart';
import 'package:my_first_flutter_app/service/GuessChartGame/GuessChartByBlurredCoverService.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 用真实曲库结构造数据：ds[3] = MASTER 定数
  String buildSongs({required bool withMasterDs}) {
    final songs = <Map<String, dynamic>>[];
    for (var i = 0; i < 100; i++) {
      songs.add({
        'id': '1$i',
        'title': '曲目$i',
        'type': 'SD',
        'ds': withMasterDs ? [3.0, 8.0, 12.0, 13.5, 14.5] : [3.0, 8.0, 12.0],
        'level': ['3', '8', '12', '13+', '14+'],
        'cids': [1, 1, 1, 1, 1],
        'charts': <dynamic>[],
        'basic_info': {
          'title': '曲目$i',
          'artist': 'a',
          'genre': 'POPS',
          'bpm': 180,
          'release_date': '2020-01-01',
          'from': 'maimai',
          'is_new': false,
        },
      });
    }
    return json.encode(songs);
  }

  test('探针 A：曲库为空（无缓存）时的行为', () async {
    SharedPreferences.setMockInitialValues({});
    final r = await GuessChartByBlurredCoverService.randomSelectSong();
    // ignore: avoid_print
    print('  无缓存 → randomSelectSong = ${r?.title ?? "null"}');
  });

  test('探针 B：正常曲库 + 默认筛选', () async {
    SharedPreferences.setMockInitialValues({
      CacheKeyConstant.cachedSongs: buildSongs(withMasterDs: true),
    });
    final r = await GuessChartByBlurredCoverService.randomSelectSong();
    // ignore: avoid_print
    print('  有缓存(含 MASTER 定数) → ${r?.title ?? "null"}');
  });

  test('探针 C：曲目缺少 ds[3]（MASTER 定数）时会怎样', () async {
    SharedPreferences.setMockInitialValues({
      CacheKeyConstant.cachedSongs: buildSongs(withMasterDs: false),
    });
    final r = await GuessChartByBlurredCoverService.randomSelectSong();
    // ignore: avoid_print
    print('  曲目无 ds[3] → ${r?.title ?? "null"}  ← null 就会永久转圈');
  });

  test('探针 D：筛选条件过严（定数区间无交集）', () async {
    SharedPreferences.setMockInitialValues({
      CacheKeyConstant.cachedSongs: buildSongs(withMasterDs: true),
    });
    final r = await GuessChartByBlurredCoverService.randomSelectSong(
      masterMinDx: 14.9,
      masterMaxDx: 15.0,
    );
    // ignore: avoid_print
    print('  定数 14.9-15.0（曲库只有 13.5） → ${r?.title ?? "null"}');
  });
}
