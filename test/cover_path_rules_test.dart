import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_flutter_app/utils/CoverUtil.dart';

/// 曲绘「资源名规则」的测试。
///
/// 背景（真实 bug）：曲绘识别页的「匹配曲绘」和「识别结果 Top10」缩略图
/// 原来直接用 `CoverUtil.buildCoverPath(songId)`（= `assets/cover/{原始 id}.webp`）
/// 直读资源。但 5 位（DX 条目，如 11312 / 10030）与 6 位（宴会场，如 121634）
/// 的曲绘资源名是**剔除后**的 id（1312.webp / 30.webp / 1634.webp），
/// 原始 id 的路径根本不存在 —— 表现就是「识别结果和 Top10 里部分曲绘不显示」。
///
/// 这里用**真实打包资源**把规则钉死：凡是要显示曲绘的地方都必须走
/// `CoverUtil.getLocalCoverPath` / `buildCoverWidget` 这套（带剔除规则 + 网络兜底），
/// 不能自己拼 `assets/cover/{songId}.webp`。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<bool> assetExists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  group('曲绘资源名规则（真实 assets 核对）', () {
    // (songId, 剔除后的资源名)——这几个 id 都是 App 里真实会出现的口径
    const cases = <(String, String)>[
      ('11312', '1312'), // 5 位：去掉开头的 1（DX 条目）
      ('10030', '30'), // 5 位：去掉 1 和前导 0
      ('121634', '1634'), // 6 位：去掉前两位（宴会场）
      ('100018', '18'), // 6 位：去掉前两位
      ('383', '383'), // 普通 id：原样
    ];

    test('原始 id 的路径不存在，剔除后的才存在', () async {
      for (final (songId, stripped) in cases) {
        if (songId != stripped) {
          // 普通 id（383）原始路径就是规则路径，本来就存在；
          // 只有 5/6 位 id 才会「原始路径不存在」
          expect(await assetExists(CoverUtil.buildCoverPath(songId)), isFalse,
              reason: '$songId：原始 id 的曲绘资源不该存在（它就是 bug 的根源）');
        }
        expect(
          await assetExists(CoverUtil.getLocalCoverPath(songId)),
          isTrue,
          reason: '$songId：应该能通过剔除规则找到 $stripped.webp',
        );
      }
    });

    test('getLocalCoverPath 落到预期的资源名上', () {
      for (final (songId, stripped) in cases) {
        expect(CoverUtil.getLocalCoverPath(songId),
            'assets/cover/$stripped.webp',
            reason: 'songId=$songId');
      }
    });

    test('显示链（buildCoverWidget）对这类 id 也能拿到图', () async {
      // 兜底链的第一步就是原始 id，随后是规则路径；只要规则路径在，
      // 显示链就不会退化成裂图（这里逐级核对它用到的候选）
      for (final (songId, _) in cases) {
        final candidates = <String>[
          CoverUtil.buildCoverPath(songId),
          CoverUtil.getLocalCoverPath(songId),
          CoverUtil.getLocalCoverPathRetry1(songId),
          CoverUtil.getLocalCoverPathRetry2(songId),
        ];
        var hit = false;
        for (final path in candidates) {
          if (await assetExists(path)) {
            hit = true;
            break;
          }
        }
        expect(hit, isTrue, reason: '$songId 在本地资源里应当至少有一级候选命中');
      }
    });
  });

  group('防回归：别再往 Image/AssetImage 里塞原始 id 的路径', () {
    test('lib/ 下不该出现 Image.asset/AssetImage/Image.network(buildCoverPath(...))', () {
      // 曲绘识别页就是这个写法：Image.asset(CoverUtil.buildCoverPath(sid))
      // → 5/6 位 id 直接裂图。显示一律用 CoverUtil 的多级兜底组件。
      final pattern = RegExp(
        r'(Image\.asset|Image\.network|AssetImage)\(\s*CoverUtil\.buildCoverPath',
      );
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        // 注释里会引用这个反面写法，逐行跳过注释再匹配
        final code = entity
            .readAsLinesSync()
            .where((line) => !line.trimLeft().startsWith('//'))
            .join('\n');
        if (pattern.hasMatch(code)) offenders.add(entity.path);
      }
      expect(offenders, isEmpty,
          reason: '这些文件把「原始 id 路径」直接拿去显示了（应改用 buildCoverWidget）：$offenders');
    });
  });
}
