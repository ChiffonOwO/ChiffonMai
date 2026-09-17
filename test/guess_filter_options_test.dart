// 回归：猜歌设置里的「可选版本 / 可选流派」只统计抽曲池真正会用到的曲。
//
// 起因（真实反馈）：版本列表走 standardVersions 白名单，maidata 追加曲的
// &version 是作者自由文本、不在其中，所以看不到；而流派列表原先只做
// `genres.remove('宴会场')`，于是 maidata 追加曲 / union 独有曲的流派会出现在
// 列表里 —— 勾了却永远抽不到（用户看到的是「当前筛选条件抽不到曲目」）。
//
// 现在统一到 SongFilterUtil.selectableFilters，口径与抽曲池一致：
//   1) 先剔除非正曲（isExtra：宴会场 / maidata 追加 / union 独有）
//   2) 「宴会场」流派再单独挡一次
//   3) 版本过官方世代白名单并按世代排序
import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_flutter_app/entity/DivingFish/Song.dart';
import 'package:my_first_flutter_app/utils/SongFilterUtil.dart';

Song _song({
  required String id,
  required String title,
  required String genre,
  required String from,
  List<int> cids = const [1, 1, 1, 1],
  bool isExtra = false,
}) =>
    Song(
      id: id,
      title: title,
      type: 'SD',
      ds: const [2.0, 7.0, 10.0, 13.0, 14.0],
      level: const ['2', '7', '10', '13', '14'],
      cids: cids,
      charts: const [],
      basicInfo: BasicInfo(
        title: title,
        artist: 'a',
        genre: genre,
        bpm: 180,
        releaseDate: '',
        from: from,
        isNew: false,
      ),
      isExtra: isExtra,
    );

void main() {
  test('只统计抽曲池会用到的曲：非正曲与宴会场都不进选项', () {
    final options = SongFilterUtil.selectableFilters([
      // 正曲：其版本 / 流派必须留下
      _song(
          id: '1001',
          title: '正曲A',
          genre: '流行&动漫',
          from: 'maimai でらっくす BUDDiES'),
      _song(id: '1002', title: '正曲B', genre: '舞萌', from: 'maimai'),
      // 6 位 ID → 宴会场（isExtra 第 1 条）
      _song(
          id: '100001',
          title: '宴会曲',
          genre: '宴会场',
          from: 'maimai でらっくす BUDDiES'),
      // 流派就是「宴会场」，但 ID 不是 6 位 → 靠第 2 条单独挡
      _song(
          id: '2001',
          title: '宴会曲2',
          genre: '宴会场',
          from: 'maimai でらっくす BUDDiES'),
      // maidata 追加（cids 全 0）：版本是作者自由文本
      _song(
          id: '9001',
          title: '追加曲',
          genre: '野流派X',
          from: '舞萌DX 2024',
          cids: const [0, 0, 0, 0]),
      // union 独有：版本恰好是标准世代，也不能因此把它带进列表
      _song(
          id: '9002',
          title: '独有曲',
          genre: '野流派Y',
          from: 'maimai でらっくす PRiSM',
          isExtra: true),
    ]);

    // 版本：只剩正曲贡献的标准世代，且按发布顺序排（maimai → BUDDiES）
    expect(options.versions, ['maimai', 'maimai でらっくす BUDDiES']);
    expect(options.versions, isNot(contains('舞萌DX 2024')),
        reason: 'maidata 的 &version 不是官方世代，不该出现在版本列表里');
    expect(options.versions, isNot(contains('maimai でらっくす PRiSM')),
        reason: '只有 union 独有曲用到的版本也不该出现（那首曲抽不到）');

    // 流派：只留正曲贡献的，顺序沿用曲库遍历顺序
    expect(options.genres, ['流行&动漫', '舞萌']);
    expect(options.genres, isNot(contains('宴会场')));
    expect(options.genres, isNot(contains('野流派X')));
    expect(options.genres, isNot(contains('野流派Y')));
  });

  test('全部都是非正曲时两个列表都为空（不会给出抽不到的选项）', () {
    final options = SongFilterUtil.selectableFilters([
      _song(id: '9001', title: '追加曲', genre: '野流派X', from: '舞萌DX 2024', cids: const [0, 0, 0, 0]),
      _song(id: '9002', title: '独有曲', genre: '野流派Y', from: 'maimai', isExtra: true),
    ]);
    expect(options.versions, isEmpty);
    expect(options.genres, isEmpty);
  });

  test('空曲库不炸', () {
    final options = SongFilterUtil.selectableFilters(const []);
    expect(options.versions, isEmpty);
    expect(options.genres, isEmpty);
  });
}
