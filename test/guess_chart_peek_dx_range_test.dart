// 谱面片段猜歌（ChartPeek）的定数范围回归测试。
//
// 背景：这一页是按「难度随机池」抽谱的，但设置里的定数范围原先
// **完全没参与筛选**（曲池只看 版本∩流派∩难度池内存在谱面），
// 界面上却写着「MASTER定数范围」，与实际行为不符。
//
// 修复后：定数范围作用于池内各难度自己的定数，ds 下标 = inote - 2。
// 这里通过页面暴露的静态判定函数直接验证映射与筛选口径。
import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_flutter_app/entity/DivingFish/Song.dart';
import 'package:my_first_flutter_app/page/GuessChartGame/GuessChartByChartPeekPage.dart';

/// 造一首歌：ds 下标 0..4 依次对应 inote 2..6。
Song buildSong({
  required String id,
  required String title,
  required List<double> ds,
}) {
  return Song(
    id: id,
    title: title,
    type: 'SD',
    ds: ds,
    level: List<String>.filled(ds.length, '13'),
    cids: List<int>.filled(ds.length, 1),
    charts: const [],
    basicInfo: BasicInfo(
      title: title,
      artist: 'a',
      genre: 'POPS',
      bpm: 180,
      releaseDate: '2020-01-01',
      from: 'maimai',
      isNew: false,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('定数范围按「难度池内各难度」筛选', () {
    // ds 下标: 0=BASIC 1=ADVANCED 2=EXPERT 3=MASTER 4=Re:MASTER
    // 造一首 EXPERT=13.0、MASTER=14.5 的歌
    final song = buildSong(
      id: '1001',
      title: '测试曲',
      ds: [3.0, 8.0, 13.0, 14.5, 15.0],
    );

    test('只选 EXPERT 时，用 EXPERT 的定数判定（不看 MASTER）', () {
      // EXPERT=13.0 落在 [12.5, 13.5] 内 → 命中；
      // 若错误地按 MASTER(14.5) 判，这个区间会判不中
      final hit = GuessChartByChartPeekPage.eligibleInotesFor(
        song: song,
        pool: const ['4'],
        masterMinDx: 12.5,
        masterMaxDx: 13.5,
        hasInote: (inote) => true,
      );
      expect(hit, ['4'], reason: 'EXPERT 应看自己的定数 13.0');
    });

    test('只选 EXPERT 时，MASTER 的定数区间不应命中', () {
      // MASTER=14.5 落在 [14.0, 15.0]，但池里没有 MASTER → 不该命中
      final hit = GuessChartByChartPeekPage.eligibleInotesFor(
        song: song,
        pool: const ['4'],
        masterMinDx: 14.0,
        masterMaxDx: 15.0,
        hasInote: (inote) => true,
      );
      expect(hit, isEmpty, reason: '池里没有 MASTER，就不该按 MASTER 定数命中');
    });

    test('池里有多个难度时，任一落在范围内即可', () {
      final hit = GuessChartByChartPeekPage.eligibleInotesFor(
        song: song,
        pool: const ['4', '5'],
        masterMinDx: 14.0,
        masterMaxDx: 15.0,
        hasInote: (inote) => true,
      );
      expect(hit, ['5'], reason: 'EXPERT 13.0 不在范围，MASTER 14.5 在范围');
    });

    test('没有谱面的难度被排除（避免播出空难度）', () {
      final hit = GuessChartByChartPeekPage.eligibleInotesFor(
        song: song,
        pool: const ['4', '5'],
        masterMinDx: 1.0,
        masterMaxDx: 15.0,
        hasInote: (inote) => inote == '4', // 只有 EXPERT 有谱面
      );
      expect(hit, ['4']);
    });

    test('定数下标越界（歌曲缺该难度）时安全跳过', () {
      // 只有 EXPERT 及以下，池里却包含 Re:MASTER
      final short = buildSong(
        id: '1002',
        title: '短曲',
        ds: [3.0, 8.0, 13.0],
      );
      final hit = GuessChartByChartPeekPage.eligibleInotesFor(
        song: short,
        pool: const ['6'],
        masterMinDx: 1.0,
        masterMaxDx: 15.0,
        hasInote: (inote) => true,
      );
      expect(hit, isEmpty, reason: 'ds 没有下标 4，不应崩溃也不应命中');
    });

    test('ds 下标映射：inote 2..6 → ds 0..4', () {
      for (var inote = 2; inote <= 6; inote++) {
        final idx = inote - 2;
        final only = List<double>.filled(5, 0.0)..[idx] = 13.0;
        final s = buildSong(id: '$inote', title: 't$inote', ds: only);
        final hit = GuessChartByChartPeekPage.eligibleInotesFor(
          song: s,
          pool: ['$inote'],
          masterMinDx: 12.0,
          masterMaxDx: 14.0,
          hasInote: (x) => true,
        );
        expect(hit, ['$inote'],
            reason: 'inote $inote 应读 ds[$idx]');
      }
    });
  });
}
