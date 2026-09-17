import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_flutter_app/entity/DivingFish/Song.dart';
import 'package:my_first_flutter_app/utils/SongFilterUtil.dart';
import 'package:my_first_flutter_app/utils/StringUtil.dart';

/// 「extra 判定」与「版本显示」必须成对使用。
///
/// 真实问题：达成率排行榜 / DX分数排行榜（`SongRankingPage`）显示版本时用的是
/// **不带 extra 标记**的 `formatVersion2`，于是追加曲（宴会场 / maidata / union 独有）
/// 被显示成 `DX 2026 彩` 这种官方世代年号名 —— 而 extra 曲目根本没有国服年号。
///
/// 这里把两件事钉住：
///   1. [SongFilterUtil.isExtraRaw]（裸字段版）与 [SongFilterUtil.isExtra]（Song 版）
///      判定一致，页面拿不到 Song 时也不会走偏；
///   2. 版本显示必须用 `...WithFlag(from, isExtra)`：同一个版本名在 extra 前后
///      得到的是两套结果，用错就会露出年号。
void main() {
  Song song({
    required String id,
    List<int> cids = const [1, 2, 3, 4, 5],
    bool isExtra = false,
  }) =>
      Song.fromJson({
        'id': id,
        'title': 'T$id',
        'type': 'DX',
        'ds': const [1.0, 2.0, 3.0, 4.0, 5.0],
        'level': const ['1', '2', '3', '4', '5'],
        'cids': cids,
        'charts': const [],
        'basic_info': const {
          'title': 'T',
          'artist': 'A',
          'genre': 'G',
          'bpm': 120,
          'from': 'maimai でらっくす PRiSM PLUS',
        },
        if (isExtra) 'is_extra': true,
      });

  group('extra 判定：裸字段版与 Song 版一致', () {
    test('普通曲都不算 extra', () {
      expect(SongFilterUtil.isExtra(song(id: '1000')), isFalse);
      expect(
        SongFilterUtil.isExtraRaw(songId: '1000', isExtraFlag: false, cids: const [1, 2]),
        isFalse,
      );
    });

    test('6 位 id（宴会场）算 extra —— 两条路径都认', () {
      expect(SongFilterUtil.isExtra(song(id: '100018')), isTrue);
      expect(SongFilterUtil.isExtraRaw(songId: '100018'), isTrue);
    });

    test('cids 全 0（maidata 追加）算 extra', () {
      expect(SongFilterUtil.isExtra(song(id: '1000', cids: const [0, 0, 0])), isTrue);
      expect(
        SongFilterUtil.isExtraRaw(songId: '1000', cids: const [0, 0, 0]),
        isTrue,
      );
      // 只有一个 0 不算
      expect(
        SongFilterUtil.isExtraRaw(songId: '1000', cids: const [0, 7]),
        isFalse,
      );
    });

    test('is_extra 标记（union 独有）算 extra', () {
      expect(SongFilterUtil.isExtra(song(id: '1000', isExtra: true)), isTrue);
      expect(
        SongFilterUtil.isExtraRaw(songId: '1000', isExtraFlag: true),
        isTrue,
      );
    });

    test('空 cids / null 不会误判', () {
      expect(SongFilterUtil.isExtraRaw(songId: '1000', cids: const []), isFalse);
      expect(SongFilterUtil.isExtraRaw(songId: '1000'), isFalse);
      expect(SongFilterUtil.isExtraRaw(songId: '1000', cids: null), isFalse);
    });
  });

  group('版本显示：用错 flag 就会露出年号', () {
    const from = 'maimai でらっくす PRiSM PLUS';

    test('extra 曲目不能出现 DX 20xx', () {
      expect(StringUtil.formatVersion2(from), 'DX 2026 彩'); // 非 extra
      expect(StringUtil.formatVersion2WithFlag(from, true), 'PRiSM+ 彩'); // extra
      expect(StringUtil.formatVersion2WithFlag(from, true),
          isNot(contains('DX 20')));
    });

    test('排行榜那种「只有裸数据」的页面也能算出正确的 flag', () {
      // SongRankingPage 拿到的是 songId + _songData，没有 Song 实体
      final bool extra = SongFilterUtil.isExtraRaw(
        songId: '100018',
        isExtraFlag: false,
        cids: const [1, 2, 3],
      );
      expect(extra, isTrue);
      expect(StringUtil.formatVersion2WithFlag(from, extra), 'PRiSM+ 彩');
    });
  });
}
