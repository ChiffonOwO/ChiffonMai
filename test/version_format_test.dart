import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_flutter_app/utils/StringUtil.dart';

/// 版本格式化的**全表**回归测试。
///
/// 这张表是照着四个 API 的实测数据（水鱼 `basic_info.from`、union `basic_info.from`、
/// 落雪 `versions`、dxrating `versions` + `songs[].version`）逐一核对出来的，
/// 四个函数对同一个输入必须给出**一致粒度**的结果：
///   * 短名（`formatVersion` / `formatVersionWithFlag`）；
///   * 详名（`formatVersion2` / `formatVersion2WithFlag`）。
///
/// 同时钉住本次修掉的问题：
///   1. `maimai でらっくす PLUS` 曾在 extra 路径下变成裸 `PLUS`；
///   2. DX 各代的 PLUS 细分曾原样吐出日文全名；
///   3. `CiRCLE`/`CiRCLE PLUS` 曾只在 `...WithFlag` 里有分支，`MAGiCAL` 完全没有；
///   4. `maimaiでらっくす`（dxrating 无空格写法）只有 `formatVersion` 处理过；
///   5. `maimai DX X` 前缀曾返回短名而非详名；
///   6. extra 路径下旧代不去前缀（`maimai GreeN`）而 DX 代去（`Splash`）；
///   7. 尾随空格曾让 extra 路径返回空串。
void main() {
  /// 断言四个函数 + isExtra 两种取值。
  ///
  /// [extraShort] / [extraDetailed] 不给时默认都是 [extra]（多数版本 extra
  /// 只做去前缀，短名与详名相同）；DX 基础两代不同（DX / DX 熊、DX+ / DX+ 華）。
  void expectAll(
    String input, {
    required String short,
    required String detailed,
    required String extra,
    String? extraShort,
    String? extraDetailed,
  }) {
    expect(StringUtil.formatVersion(input), short, reason: 'formatVersion($input)');
    expect(StringUtil.formatVersionWithFlag(input, false), short,
        reason: 'formatVersionWithFlag($input,false)');
    expect(StringUtil.formatVersion2(input), detailed,
        reason: 'formatVersion2($input)');
    expect(StringUtil.formatVersion2WithFlag(input, false), detailed,
        reason: 'formatVersion2WithFlag($input,false)');
    // isExtra=true：extra 曲目不进国服世代年表（去前缀 + 不带年号）
    expect(StringUtil.formatVersionWithFlag(input, true),
        extraShort ?? extra,
        reason: 'formatVersionWithFlag($input,true)');
    expect(StringUtil.formatVersion2WithFlag(input, true),
        extraDetailed ?? extra,
        reason: 'formatVersion2WithFlag($input,true)');
  }

  group('旧代（13 个）', () {
    const cases = <String, List<String>>{
      // 输入: [短名, 详名, extra]
      'maimai': ['maimai', 'maimai 真', 'maimai'],
      'maimai PLUS': ['maimai+', 'maimai+ 真', 'maimai+'],
      'maimai GreeN': ['GreeN', 'GreeN 超', 'GreeN'],
      'maimai GreeN PLUS': ['GreeN+', 'GreeN+ 檄', 'GreeN+'],
      'maimai ORANGE': ['ORANGE', 'ORANGE 橙', 'ORANGE'],
      'maimai ORANGE PLUS': ['ORANGE+', 'ORANGE+ 暁', 'ORANGE+'],
      'maimai PiNK': ['PiNK', 'PiNK 桃', 'PiNK'],
      'maimai PiNK PLUS': ['PiNK+', 'PiNK+ 櫻', 'PiNK+'],
      'maimai MURASAKi': ['MURASAKi', 'MURASAKi 紫', 'MURASAKi'],
      'maimai MURASAKi PLUS': ['MURASAKi+', 'MURASAKi+ 菫', 'MURASAKi+'],
      'maimai MiLK': ['MiLK', 'MiLK 白', 'MiLK'],
      'MiLK PLUS': ['MiLK+', 'MiLK+ 雪', 'MiLK+'],
      'maimai FiNALE': ['FiNALE', 'FiNALE 輝', 'FiNALE'],
    };
    cases.forEach((input, want) {
      test(input, () {
        // 旧代没有年号：extra 的详名与 extra=false 完全相同（都带一文字），
        // 只有短名会去掉 maimai 前缀。
        expectAll(input,
            short: want[0],
            detailed: want[1],
            extra: want[2],
            extraShort: want[2],
            extraDetailed: want[1]);
      });
    });
  });

  group('DX 代（含 PLUS 细分与新世代）', () {
    // [短名, 详名, extra 短名, extra 详名]
    const cases = <String, List<String>>{
      // DX 基础两代：extra 短名 DX / DX+（不带年号），详名带一文字
      'maimai でらっくす': ['DX 2020', 'DX 2020 熊/華', 'DX', 'DX 熊'],
      'maimai でらっくす PLUS': ['でらっくす+', 'でらっくす+ 華', 'DX+', 'DX+ 華'],
      'maimai でらっくす Splash': ['DX 2021', 'DX 2021 爽/煌', 'Splash', 'Splash 爽'],
      'maimai でらっくす Splash PLUS': [
        'Splash+',
        'Splash+ 煌',
        'Splash+',
        'Splash+ 煌',
      ],
      'maimai でらっくす UNiVERSE': [
        'DX 2022',
        'DX 2022 宙/星',
        'UNiVERSE',
        'UNiVERSE 宙',
      ],
      'maimai でらっくす UNiVERSE PLUS': [
        'UNiVERSE+',
        'UNiVERSE+ 星',
        'UNiVERSE+',
        'UNiVERSE+ 星',
      ],
      'maimai でらっくす FESTiVAL': [
        'DX 2023',
        'DX 2023 祭/祝',
        'FESTiVAL',
        'FESTiVAL 祭',
      ],
      'maimai でらっくす FESTiVAL PLUS': [
        'FESTiVAL+',
        'FESTiVAL+ 祝',
        'FESTiVAL+',
        'FESTiVAL+ 祝',
      ],
      'maimai でらっくす BUDDiES': [
        'DX 2024',
        'DX 2024 双/宴',
        'BUDDiES',
        'BUDDiES 双',
      ],
      'maimai でらっくす BUDDiES PLUS': [
        'BUDDiES+',
        'BUDDiES+ 宴',
        'BUDDiES+',
        'BUDDiES+ 宴',
      ],
      'maimai でらっくす PRiSM': ['DX 2025', 'DX 2025 鏡', 'PRiSM', 'PRiSM 鏡'],
      'maimai でらっくす PRiSM PLUS': [
        'DX 2026',
        'DX 2026 彩',
        'PRiSM+',
        'PRiSM+ 彩',
      ],
      // 国服未上线：没有年号，直接用世代名 + 一文字
      'maimai でらっくす CiRCLE': ['CiRCLE', 'CiRCLE 丸', 'CiRCLE', 'CiRCLE 丸'],
      'maimai でらっくす CiRCLE PLUS': [
        'CiRCLE+',
        'CiRCLE+',
        'CiRCLE+',
        'CiRCLE+ 廻',
      ],
      // MAGiCAL 一文字待确认：extra 详名暂时与短名一致
      'maimai でらっくす MAGiCAL': ['MAGiCAL', 'MAGiCAL', 'MAGiCAL', 'MAGiCAL'],
    };
    cases.forEach((input, want) {
      test(input, () {
        expectAll(input,
            short: want[0],
            detailed: want[1],
            extra: want[2],
            extraShort: want[2],
            extraDetailed: want[3]);
      });
    });
  });

  group('本次修掉的问题', () {
    test('#1 extra 路径不再产出裸 PLUS', () {
      expect(StringUtil.formatVersion2WithFlag('maimai でらっくす PLUS', true),
          'DX+ 華');
      expect(StringUtil.formatVersionWithFlag('maimai でらっくす PLUS', true),
          'DX+');
    });

    test('#1b extra 的 DX 基础两代用 DX / DX+，且不出现年号', () {
      expect(StringUtil.formatVersionWithFlag('maimai でらっくす', true), 'DX');
      expect(StringUtil.formatVersion2WithFlag('maimai でらっくす', true),
          'DX 熊');
      expect(StringUtil.formatVersionWithFlag('maimaiでらっくす', true), 'DX');
      expect(StringUtil.formatVersionWithFlag('maimai DX', true), 'DX');
      expect(StringUtil.formatVersion2WithFlag('maimai DX PLUS', true),
          'DX+ 華');
      // 年号只属于 extra=false
      for (final v in [
        'maimai でらっくす',
        'maimai でらっくす PLUS',
        'maimai でらっくす Splash',
        'maimai でらっくす BUDDiES PLUS',
      ]) {
        expect(StringUtil.formatVersionWithFlag(v, true), isNot(contains('DX 20')),
            reason: '$v 的 extra 显示不该带年号');
        expect(StringUtil.formatVersion2WithFlag(v, true),
            isNot(contains('DX 20')),
            reason: '$v 的 extra 详名不该带年号');
      }
    });

    test('#2 DX 各代 PLUS 细分不再原样吐出日文全名', () {
      for (final v in [
        'maimai でらっくす PLUS',
        'maimai でらっくす Splash PLUS',
        'maimai でらっくす UNiVERSE PLUS',
        'maimai でらっくす FESTiVAL PLUS',
        'maimai でらっくす BUDDiES PLUS',
      ]) {
        final detailed = StringUtil.formatVersion2(v);
        expect(detailed, isNot(v), reason: '$v 应当有详名，而不是原样');
        expect(detailed, isNot(startsWith('maimai')),
            reason: '$v 的详名不该还带着 maimai 前缀');
      }
    });

    test('#3 CiRCLE 四个函数一致、MAGiCAL 已收录', () {
      expect(StringUtil.formatVersion2('maimai でらっくす CiRCLE'), 'CiRCLE 丸');
      expect(StringUtil.formatVersion('maimai でらっくす CiRCLE'), 'CiRCLE');
      expect(StringUtil.formatVersion2WithFlag('maimai でらっくす CiRCLE', false),
          'CiRCLE 丸');
      expect(StringUtil.formatVersion('maimai でらっくす MAGiCAL'), 'MAGiCAL');
      expect(StringUtil.formatVersion2('maimai でらっくす MAGiCAL'), 'MAGiCAL');
      expect(StringUtil.formatVersion2WithFlag('maimai でらっくす MAGiCAL', false),
          'MAGiCAL');
    });

    test('#3b MEGiCAL 按笔误归一成官方写法 MAGiCAL（含 extra 路径）', () {
      // 官方拼写见 SEGA 公告「maimai でらっくす MAGiCAL」稼働日決定
      expect(StringUtil.formatVersion('maimai でらっくす MEGiCAL'), 'MAGiCAL');
      expect(StringUtil.formatVersion2('maimai でらっくす MEGiCAL'), 'MAGiCAL');
      expect(StringUtil.formatVersion2WithFlag('maimai でらっくす MEGiCAL', true),
          'MAGiCAL');
    });

    test('#4 dxrating 无空格写法四个函数都能识别', () {
      expect(StringUtil.formatVersion('maimaiでらっくす'), 'DX 2020');
      expect(StringUtil.formatVersion2('maimaiでらっくす'), 'DX 2020 熊/華');
      expect(StringUtil.formatVersionWithFlag('maimaiでらっくす', false),
          'DX 2020');
      expect(StringUtil.formatVersion2WithFlag('maimaiでらっくす', false),
          'DX 2020 熊/華');
      expect(StringUtil.formatVersion2('maimaiでらっくす PLUS'),
          'でらっくす+ 華');
    });

    test('#5 maimai DX 前缀与日文前缀粒度一致（都返回详名）', () {
      expect(StringUtil.formatVersion2('maimai DX PRiSM'), 'DX 2025 鏡');
      expect(StringUtil.formatVersion2WithFlag('maimai DX PRiSM', false),
          'DX 2025 鏡');
      expect(StringUtil.formatVersion('maimai DX PRiSM'), 'DX 2025');
      expect(StringUtil.formatVersion('maimai DX FESTiVAL PLUS'), 'FESTiVAL+');
      // 裸 'maimai DX' 视为基础世代
      expect(StringUtil.formatVersion('maimai DX'), 'DX 2020');
    });

    test('#6 extra 路径下旧代与 DX 代都去掉前缀（详名再带一文字）', () {
      // 短名：只去前缀
      expect(StringUtil.formatVersionWithFlag('maimai GreeN', true), 'GreeN');
      expect(StringUtil.formatVersionWithFlag('maimai でらっくす Splash', true),
          'Splash');
      expect(StringUtil.formatVersionWithFlag('maimai FiNALE', true), 'FiNALE');
      // 详名：去前缀 + 一文字（旧代与 extra=false 的一致，DX 代去掉年号）
      expect(StringUtil.formatVersion2WithFlag('maimai GreeN', true), 'GreeN 超');
      expect(StringUtil.formatVersion2WithFlag('maimai でらっくす Splash', true),
          'Splash 爽');
      expect(StringUtil.formatVersion2WithFlag('maimai FiNALE', true),
          'FiNALE 輝');
    });

    test('#7 首尾空白不再产生空串', () {
      expect(StringUtil.formatVersion('maimai でらっくす '), 'DX 2020');
      expect(StringUtil.formatVersion2(' maimai でらっくす Splash '),
          'DX 2021 爽/煌');
      expect(
          StringUtil.formatVersion2WithFlag('maimai でらっくす ', true), 'DX 熊');
    });

    test('未知/空输入保持原样，不抛异常', () {
      expect(StringUtil.formatVersion('unknown'), 'unknown');
      expect(StringUtil.formatVersion2('unknown'), 'unknown');
      expect(StringUtil.formatVersion2WithFlag('', false), '');
      expect(StringUtil.formatVersion2WithFlag('', true), '');
      expect(StringUtil.formatVersion2('Mai2Link自制谱'), 'Mai2Link自制谱');
    });

    test('国服 20 个世代（白名单）全部能被详名识别', () {
      const standard = {
        'maimai': 'maimai 真',
        'maimai PLUS': 'maimai+ 真',
        'maimai GreeN': 'GreeN 超',
        'maimai GreeN PLUS': 'GreeN+ 檄',
        'maimai ORANGE': 'ORANGE 橙',
        'maimai ORANGE PLUS': 'ORANGE+ 暁',
        'maimai PiNK': 'PiNK 桃',
        'maimai PiNK PLUS': 'PiNK+ 櫻',
        'maimai MURASAKi': 'MURASAKi 紫',
        'maimai MURASAKi PLUS': 'MURASAKi+ 菫',
        'maimai MiLK': 'MiLK 白',
        'MiLK PLUS': 'MiLK+ 雪',
        'maimai FiNALE': 'FiNALE 輝',
        'maimai でらっくす': 'DX 2020 熊/華',
        'maimai でらっくす Splash': 'DX 2021 爽/煌',
        'maimai でらっくす UNiVERSE': 'DX 2022 宙/星',
        'maimai でらっくす FESTiVAL': 'DX 2023 祭/祝',
        'maimai でらっくす BUDDiES': 'DX 2024 双/宴',
        'maimai でらっくす PRiSM': 'DX 2025 鏡',
        'maimai でらっくす PRiSM PLUS': 'DX 2026 彩',
      };
      expect(standard.length, 20);
      standard.forEach((raw, detailed) {
        expect(StringUtil.formatVersion2(raw), detailed, reason: raw);
        // 短名必须与详名不同（详名带汉字），且不为空
        expect(StringUtil.formatVersion(raw), isNotEmpty);
      });
    });
  });
}
