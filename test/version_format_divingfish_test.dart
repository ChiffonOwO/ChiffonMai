import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_flutter_app/constant/VersionListConstant.dart';
import 'package:my_first_flutter_app/utils/StringUtil.dart';

/// **水鱼（Diving-Fish）曲库实测版本 → 格式化结果**的回归测试。
///
/// 数据来源：`GET https://www.diving-fish.com/api/maimaidxprober/music_data`
/// （实测于本次修改当天：1394 首、20 个版本，下面的 count 就是当时的分布）。
/// 水鱼曲目在本 App 里一律 `isExtra == false`，所以这里走 **WithFlag(false)** 路径。
///
/// 这张表的意义：水鱼是国服数据源，它的 20 个版本必须
///   1) 全部能格式化（`formatVersion2` 不能原样返回），
///   2) 格式化结果与界面上的国服口径一致（旧代带 真/超/檄…，DX 代带 DX 20xx 年号），
///   3) 全部落在 [VersionListConstant.standardVersions] 白名单里（猜歌/筛选用它过滤）。
void main() {
  /// 水鱼实测：[版本原文, 曲目数, 短名, 详名]
  const rows = <List<Object>>[
    ['maimai', 43, 'maimai', 'maimai 真'],
    ['maimai PLUS', 45, 'maimai+', 'maimai+ 真'],
    ['maimai GreeN', 58, 'GreeN', 'GreeN 超'],
    ['maimai GreeN PLUS', 50, 'GreeN+', 'GreeN+ 檄'],
    ['maimai ORANGE', 30, 'ORANGE', 'ORANGE 橙'],
    ['maimai ORANGE PLUS', 28, 'ORANGE+', 'ORANGE+ 暁'],
    ['maimai PiNK', 33, 'PiNK', 'PiNK 桃'],
    ['maimai PiNK PLUS', 33, 'PiNK+', 'PiNK+ 櫻'],
    ['maimai MURASAKi', 42, 'MURASAKi', 'MURASAKi 紫'],
    ['maimai MURASAKi PLUS', 40, 'MURASAKi+', 'MURASAKi+ 菫'],
    ['maimai MiLK', 44, 'MiLK', 'MiLK 白'],
    ['MiLK PLUS', 42, 'MiLK+', 'MiLK+ 雪'],
    ['maimai FiNALE', 46, 'FiNALE', 'FiNALE 輝'],
    ['maimai でらっくす', 88, 'DX 2020', 'DX 2020 熊/華'],
    ['maimai でらっくす Splash', 95, 'DX 2021', 'DX 2021 爽/煌'],
    ['maimai でらっくす UNiVERSE', 125, 'DX 2022', 'DX 2022 宙/星'],
    ['maimai でらっくす FESTiVAL', 147, 'DX 2023', 'DX 2023 祭/祝'],
    ['maimai でらっくす BUDDiES', 168, 'DX 2024', 'DX 2024 双/宴'],
    ['maimai でらっくす PRiSM', 165, 'DX 2025', 'DX 2025 鏡'],
    ['maimai でらっくす PRiSM PLUS', 72, 'DX 2026', 'DX 2026 彩'],
  ];

  group('水鱼 20 个版本逐一格式化', () {
    for (final row in rows) {
      final raw = row[0] as String;
      final short = row[2] as String;
      final detailed = row[3] as String;
      test('$raw → $short / $detailed', () {
        expect(StringUtil.formatVersion(raw), short);
        expect(StringUtil.formatVersionWithFlag(raw, false), short,
            reason: '水鱼曲目 isExtra=false，WithFlag 应与 formatVersion 一致');
        expect(StringUtil.formatVersion2(raw), detailed);
        expect(StringUtil.formatVersion2WithFlag(raw, false), detailed);
      });
    }
  });

  group('水鱼版本集合的整体约束', () {
    final rawVersions = rows.map((r) => r[0] as String).toList();

    test('数量与曲目总数与实测一致（1394 首 / 20 版本）', () {
      expect(rawVersions.length, 20);
      final total = rows.fold<int>(0, (sum, r) => sum + (r[1] as int));
      expect(total, 1394);
      // 版本名不重复
      expect(rawVersions.toSet().length, 20);
    });

    test('每一个版本都有详名（不允许原样返回）', () {
      for (final v in rawVersions) {
        expect(StringUtil.formatVersion2(v), isNot(v),
            reason: '$v 没有被格式化，说明表里缺这一条');
        expect(StringUtil.formatVersion2(v).trim(), isNotEmpty);
      }
    });

    test('旧代与 DX 代的详名风格各自统一', () {
      for (final row in rows) {
        final raw = row[0] as String;
        final detailed = StringUtil.formatVersion2(raw);
        if (raw.startsWith('maimai でらっくす')) {
          // DX 代：'DX 20xx 汉字'（PRiSM PLUS 也有自己的年号）
          expect(detailed, startsWith('DX 20'), reason: raw);
        } else {
          // 旧代：'名 汉字'
          expect(detailed, isNot(startsWith('DX')), reason: raw);
          expect(detailed.contains(' '), isTrue, reason: '$raw 的详名应带汉字');
        }
      }
    });

    test('全部落在标准世代白名单里（猜歌/筛选用它过滤）', () {
      for (final v in rawVersions) {
        expect(VersionListConstant.standardVersions, contains(v),
            reason: '$v 不在 VersionListConstant.standardVersions 里');
        expect(VersionListConstant.versionOrderMap.containsKey(v), isTrue,
            reason: '$v 缺少世代顺序');
        expect(VersionListConstant.versionOrderList, contains(v));
      }
    });

    test('白名单里没有水鱼不存在的版本（PLUS 细分 / CiRCLE / MAGiCAL）', () {
      // 水鱼（国服）没有这些；它们只在 union / dxrating 出现。
      // 这也说明本轮为它们补的格式化只影响 union/dxrating 数据，不影响水鱼显示。
      for (final absent in [
        'maimai でらっくす PLUS',
        'maimai でらっくす Splash PLUS',
        'maimai でらっくす UNiVERSE PLUS',
        'maimai でらっくす FESTiVAL PLUS',
        'maimai でらっくす BUDDiES PLUS',
        'maimai でらっくす CiRCLE',
        'maimai でらっくす CiRCLE PLUS',
        'maimai でらっくす MAGiCAL',
      ]) {
        expect(rawVersions, isNot(contains(absent)));
        expect(VersionListConstant.standardVersions, isNot(contains(absent)));
      }
    });

    test('DX 代短名里没有重复（定数历史表按短名做表头）', () {
      final shortNames = rows
          .map((r) => StringUtil.formatVersion(r[0] as String))
          .toList();
      expect(shortNames.toSet().length, shortNames.length,
          reason: '短名重复会让两个版本在表头里显示成同一列');
    });
  });
}
