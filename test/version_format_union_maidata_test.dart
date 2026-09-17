import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_flutter_app/utils/StringUtil.dart';

/// **union 曲库 + maidata 追加曲目**的版本列表 → 格式化结果。
///
/// 这两类在本 App 里是 `isExtra == true`（走 WithFlag 的 true 路径），
/// 所以断言以 `formatVersionWithFlag(v, true)`（短名）与
/// `formatVersion2WithFlag(v, true)`（详名）为准；同时把 `false` 路径也钉住，
/// 便于对照「同一版本在有/无 extra 标记时的显示差异」。
///
/// **显示口径（用户指定）**：
///   * extra=true 的 **短名**：去前缀的世代名，**不带年号**（`DX`、`DX+`、`Splash`、
///     `BUDDiES+`…）；带年号的 `DX 2020` 系列是 **extra=false 专属**；
///   * extra=true 的 **详名**：短名 + 该世代的一文字（`DX 熊`、`DX+ 華`、`Splash 爽`、
///     `CiRCLE+ 廻`…）——与 extra=false 的详名只差年号，汉字口径一致。
///
/// 数据来源（实测于本次修改当天）：
///   * union `GET https://union.godserver.cn//api/union/musics`
///     —— 1861 首、**27 个版本**，下面的 count 是当时的分布；
///   * maidata（`https://chiffonmai.cloud/<流派>/<目录>/maidata.txt`）
///     —— 7 个流派各抽 30 个目录、共 **101 个文件**解析 `&version`，
///     得到 **14 种取值**。maidata 写的是英文前缀 **`maimai DX X`**，
///     这正是 `StringUtil` 里那条 `maimai DX ` 归一化规则服务的数据。
///
/// dxrating（`/api/v1/dxdata`）不参与曲库，只用于可用地区，故不在此测试。
void main() {
  /// union 实测：[版本原文, 曲目数, extra 短名, extra 详名, 非 extra 详名]
  const unionRows = <List<Object>>[
    ['maimai', 61, 'maimai', 'maimai 真', 'maimai 真'],
    ['maimai PLUS', 51, 'maimai+', 'maimai+ 真', 'maimai+ 真'],
    ['maimai GreeN', 70, 'GreeN', 'GreeN 超', 'GreeN 超'],
    ['maimai GreeN PLUS', 63, 'GreeN+', 'GreeN+ 檄', 'GreeN+ 檄'],
    ['maimai ORANGE', 37, 'ORANGE', 'ORANGE 橙', 'ORANGE 橙'],
    ['maimai ORANGE PLUS', 49, 'ORANGE+', 'ORANGE+ 暁', 'ORANGE+ 暁'],
    ['maimai PiNK', 48, 'PiNK', 'PiNK 桃', 'PiNK 桃'],
    ['maimai PiNK PLUS', 45, 'PiNK+', 'PiNK+ 櫻', 'PiNK+ 櫻'],
    ['maimai MURASAKi', 57, 'MURASAKi', 'MURASAKi 紫', 'MURASAKi 紫'],
    ['maimai MURASAKi PLUS', 50, 'MURASAKi+', 'MURASAKi+ 菫', 'MURASAKi+ 菫'],
    ['maimai MiLK', 55, 'MiLK', 'MiLK 白', 'MiLK 白'],
    ['maimai MiLK PLUS', 55, 'MiLK+', 'MiLK+ 雪', 'MiLK+ 雪'],
    ['maimai FiNALE', 63, 'FiNALE', 'FiNALE 輝', 'FiNALE 輝'],
    ['maimai でらっくす', 97, 'DX', 'DX 熊', 'DX 2020 熊/華'],
    ['maimai でらっくす PLUS', 67, 'DX+', 'DX+ 華', 'でらっくす+ 華'],
    ['maimai でらっくす Splash', 67, 'Splash', 'Splash 爽', 'DX 2021 爽/煌'],
    ['maimai でらっくす Splash PLUS', 72, 'Splash+', 'Splash+ 煌', 'Splash+ 煌'],
    ['maimai でらっくす UNiVERSE', 76, 'UNiVERSE', 'UNiVERSE 宙', 'DX 2022 宙/星'],
    ['maimai でらっくす UNiVERSE PLUS', 76, 'UNiVERSE+', 'UNiVERSE+ 星',
      'UNiVERSE+ 星'],
    ['maimai でらっくす FESTiVAL', 79, 'FESTiVAL', 'FESTiVAL 祭', 'DX 2023 祭/祝'],
    ['maimai でらっくす FESTiVAL PLUS', 73, 'FESTiVAL+', 'FESTiVAL+ 祝',
      'FESTiVAL+ 祝'],
    ['maimai でらっくす BUDDiES', 106, 'BUDDiES', 'BUDDiES 双', 'DX 2024 双/宴'],
    ['maimai でらっくす BUDDiES PLUS', 84, 'BUDDiES+', 'BUDDiES+ 宴',
      'BUDDiES+ 宴'],
    ['maimai でらっくす PRiSM', 83, 'PRiSM', 'PRiSM 鏡', 'DX 2025 鏡'],
    ['maimai でらっくす PRiSM PLUS', 99, 'PRiSM+', 'PRiSM+ 彩', 'DX 2026 彩'],
    ['maimai でらっくす CiRCLE', 89, 'CiRCLE', 'CiRCLE 丸', 'CiRCLE 丸'],
    ['maimai でらっくす CiRCLE PLUS', 89, 'CiRCLE+', 'CiRCLE+ 廻', 'CiRCLE+'],
  ];

  /// maidata 抽样实测：[`&version` 原文, 样本数, extra 短名, extra 详名]
  const maidataRows = <List<Object>>[
    ['maimai DX', 34, 'DX', 'DX 熊'],
    ['maimai DX PLUS', 17, 'DX+', 'DX+ 華'],
    ['maimai DX Splash', 10, 'Splash', 'Splash 爽'],
    ['maimai DX Splash PLUS', 3, 'Splash+', 'Splash+ 煌'],
    ['maimai DX UNiVERSE', 3, 'UNiVERSE', 'UNiVERSE 宙'],
    ['maimai DX UNiVERSE PLUS', 3, 'UNiVERSE+', 'UNiVERSE+ 星'],
    ['maimai DX FESTiVAL', 2, 'FESTiVAL', 'FESTiVAL 祭'],
    ['maimai DX FESTiVAL PLUS', 2, 'FESTiVAL+', 'FESTiVAL+ 祝'],
    ['maimai DX BUDDiES', 13, 'BUDDiES', 'BUDDiES 双'],
    ['maimai DX BUDDiES PLUS', 1, 'BUDDiES+', 'BUDDiES+ 宴'],
    ['maimai DX PRiSM', 3, 'PRiSM', 'PRiSM 鏡'],
    ['maimai DX PRiSM PLUS', 3, 'PRiSM+', 'PRiSM+ 彩'],
    ['maimai DX CiRCLE', 2, 'CiRCLE', 'CiRCLE 丸'],
    ['maimai PLUS', 5, 'maimai+', 'maimai+ 真'],
  ];

  group('union 曲库 27 个版本（extra 路径）', () {
    for (final row in unionRows) {
      final raw = row[0] as String;
      test('$raw → ${row[2]} / ${row[3]}', () {
        expect(StringUtil.formatVersionWithFlag(raw, true), row[2]);
        expect(StringUtil.formatVersion2WithFlag(raw, true), row[3]);
      });
    }

    test('非 extra 路径同样有详名（对照用）', () {
      for (final row in unionRows) {
        expect(StringUtil.formatVersion2WithFlag(row[0] as String, false),
            row[4],
            reason: row[0] as String);
      }
    });

    test('数量与曲目总数与实测一致（1861 首 / 27 版本）', () {
      expect(unionRows.length, 27);
      final total = unionRows.fold<int>(0, (sum, r) => sum + (r[1] as int));
      expect(total, 1861);
    });

    test('extra 短名里不残留 maimai / でらっくす 前缀，也没有裸 PLUS', () {
      for (final row in unionRows) {
        final raw = row[0] as String;
        // 短名是「去前缀」的形态，这里查残留最合适
        // （详名会带上最初代的一文字 'maimai 真'，那是正常的）
        final short = StringUtil.formatVersionWithFlag(raw, true);
        expect(short, isNot(contains('maimai ')), reason: '$raw 残留 maimai 前缀');
        expect(short, isNot(contains('でらっくす ')), reason: raw);
        expect(short, isNot('PLUS'), reason: '$raw 剥出了裸 PLUS');
        expect(short.trim(), isNotEmpty);
      }
    });

    test('extra 显示一律不带年号（DX 20xx 是 extra=false 专属）', () {
      for (final row in unionRows) {
        final raw = row[0] as String;
        expect(StringUtil.formatVersionWithFlag(raw, true), isNot(contains('DX 20')),
            reason: '$raw 的 extra 短名不该带年号');
        expect(StringUtil.formatVersion2WithFlag(raw, true),
            isNot(contains('DX 20')),
            reason: '$raw 的 extra 详名不该带年号');
        // 反过来：有国服年号的 DX 基础世代（不含 PLUS 细分与国服未上线的 CiRCLE）
        // 在非 extra 路径必须带年号
        const withYear = {
          'maimai でらっくす',
          'maimai でらっくす Splash',
          'maimai でらっくす UNiVERSE',
          'maimai でらっくす FESTiVAL',
          'maimai でらっくす BUDDiES',
          'maimai でらっくす PRiSM',
          'maimai でらっくす PRiSM PLUS',
        };
        if (withYear.contains(raw)) {
          expect(StringUtil.formatVersionWithFlag(raw, false),
              contains('DX 20'),
              reason: '$raw 的非 extra 短名应带年号');
        }
      }
    });

    test('extra 的详名都带一文字（与短名不同）', () {
      // 用户口径：extra=true 的**详名**必须带上该世代的一文字；
      // 短名保持不带字（去前缀的世代名）。
      const withoutKanji = {
        // MAGiCAL 的一文字暂无可靠来源，先只要求它不为空
        'maimai でらっくす MAGiCAL',
      };
      for (final row in unionRows) {
        final raw = row[0] as String;
        final short = StringUtil.formatVersionWithFlag(raw, true);
        final detailed = StringUtil.formatVersion2WithFlag(raw, true);
        expect(detailed.trim(), isNotEmpty, reason: raw);
        if (withoutKanji.contains(raw)) continue;
        expect(detailed, isNot(short),
            reason: '$raw 的 extra 详名应带一文字，现在与短名相同');
        expect(detailed, startsWith(short),
            reason: '$raw 的 extra 详名应是「短名 + 一文字」');
        expect(detailed.substring(short.length).trim().length, 1,
            reason: '$raw 的一文字应当正好一个字：$detailed');
      }
      for (final row in maidataRows) {
        final raw = row[0] as String;
        final short = StringUtil.formatVersionWithFlag(raw, true);
        final detailed = StringUtil.formatVersion2WithFlag(raw, true);
        expect(detailed, isNot(short), reason: '$raw 的 extra 详名应带一文字');
        expect(detailed.substring(short.length).trim().length, 1,
            reason: '$raw 的一文字应当正好一个字：$detailed');
      }
    });

    test('CiRCLE / CiRCLE+ 的一文字是 丸 / 廻', () {
      expect(StringUtil.formatVersion2WithFlag('maimai でらっくす CiRCLE', true),
          'CiRCLE 丸');
      expect(
          StringUtil.formatVersion2WithFlag('maimai でらっくす CiRCLE PLUS', true),
          'CiRCLE+ 廻');
      expect(StringUtil.formatVersionWithFlag('maimai でらっくす CiRCLE PLUS', true),
          'CiRCLE+');
    });

    test('DX 基础两代：extra 用 DX / DX+，非 extra 用 DX 2020 系列', () {
      expect(StringUtil.formatVersionWithFlag('maimai でらっくす', true), 'DX');
      expect(StringUtil.formatVersion2WithFlag('maimai でらっくす', true),
          'DX 熊');
      expect(StringUtil.formatVersionWithFlag('maimai でらっくす PLUS', true),
          'DX+');
      expect(StringUtil.formatVersion2WithFlag('maimai でらっくす PLUS', true),
          'DX+ 華');
      expect(StringUtil.formatVersion('maimai でらっくす'), 'DX 2020');
      expect(StringUtil.formatVersion2('maimai でらっくす'), 'DX 2020 熊/華');
    });

    test('union 独有的 PLUS 细分与 CiRCLE 都有显示', () {
      expect(StringUtil.formatVersion2('maimai でらっくす Splash PLUS'),
          'Splash+ 煌');
      expect(StringUtil.formatVersion2('maimai でらっくす CiRCLE'), 'CiRCLE 丸');
      expect(StringUtil.formatVersion2('maimai でらっくす CiRCLE PLUS'),
          'CiRCLE+');
      // union 写 'maimai MiLK PLUS'（带前缀），水鱼写 'MiLK PLUS'，两种都要收
      expect(StringUtil.formatVersion2('maimai MiLK PLUS'), 'MiLK+ 雪');
      expect(
          StringUtil.formatVersionWithFlag('maimai MiLK PLUS', false), 'MiLK+');
    });
  });

  group('maidata 追加曲目 14 种 &version（一律 extra）', () {
    for (final row in maidataRows) {
      final raw = row[0] as String;
      test('$raw → ${row[2]} / ${row[3]}', () {
        expect(StringUtil.formatVersionWithFlag(raw, true), row[2]);
        expect(StringUtil.formatVersion2WithFlag(raw, true), row[3]);
      });
    }

    test('样本数与取值数与实测一致（101 个文件 / 14 种）', () {
      expect(maidataRows.length, 14);
      final total = maidataRows.fold<int>(0, (sum, r) => sum + (r[1] as int));
      expect(total, 101);
    });

    test('maimai DX 前缀被正确归一（这是 maidata 的主要写法）', () {
      for (final row in maidataRows) {
        final raw = row[0] as String;
        final asJp = raw.replaceFirst('maimai DX', 'maimai でらっくす');
        expect(StringUtil.formatVersion2WithFlag(asJp, true),
            StringUtil.formatVersion2WithFlag(raw, true),
            reason: '$raw 与 $asJp 应显示一致');
        expect(StringUtil.formatVersionWithFlag(asJp, true),
            StringUtil.formatVersionWithFlag(raw, true),
            reason: '$raw 与 $asJp 应显示一致');
      }
    });

    test('maidata 的 extra 显示也不带年号', () {
      for (final row in maidataRows) {
        expect(StringUtil.formatVersionWithFlag(row[0] as String, true),
            isNot(contains('DX 20')),
            reason: row[0] as String);
      }
    });

    test('maidata 里没有出现 CiRCLE+ / MAGiCAL（抽样结论）', () {
      final raws = maidataRows.map((r) => r[0] as String).toList();
      expect(raws, isNot(contains('maimai DX CiRCLE PLUS')));
      expect(raws, isNot(contains('maimai DX MAGiCAL')));
    });
  });
}
