// ===========================================================================
// dxrating 曲绘兜底的真实数据探针
//
// 用真实 dxdata（%TEMP%\dxdata_probe.json，4MB，1769 首歌）走一遍完整链路：
//   真实 dxdata → DXDataEntity.fromJson → DxRatingCoverService.buildIndex
//   → songId 查 imageName → 拼 URL → 真的 GET 一张图回来
//
// 覆盖「水鱼的 DX 条目 id = 10000 + 基础 id」等口径问题：
// 383 / 8 是普通 id，10030 与 11663 是 DX 条目，100018 是宴会场。
//
// 用法（先确保 %TEMP%\dxdata_probe.json 在，否则跳过）：
//   flutter test tool/probe_dxrating_cover_test.dart
// tool/ 不在 analyzer 的测试目录白名单里，这两条 lint 在这里是误报：
// ignore_for_file: avoid_print, invalid_use_of_visible_for_testing_member
// ===========================================================================
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_flutter_app/entity/DXRating/DXDataEntity.dart';
import 'package:my_first_flutter_app/service/DxRatingCoverService.dart';
import 'package:my_first_flutter_app/utils/ApiClient.dart';

/// 期望能出图的 songId（都是 App 里会出现的水鱼口径 id）
const Map<String, String> kExpectTitles = {
  '383': 'Link',
  '8': 'True Love Song',
  '10030': 'ネコ日和。', // DX 条目：10000 + 30
  '11663': '系ぎて', // DX 条目：10000 + 1663
  '100018': '[協]Love You', // 宴会场
};

void main() {
  test('真实 dxdata → 索引 → shama 曲绘 URL → HTTP 200', () async {
    final path = '${Platform.environment['TEMP']}\\dxdata_probe.json';
    final file = File(path);
    if (!file.existsSync()) {
      print('[SKIP] 找不到 $path（先下载 dxdata 再跑）');
      return;
    }

    final data = DXDataEntity.fromJson(
        jsonDecode(await file.readAsString()) as Map<String, dynamic>);
    final index = DxRatingCoverService.buildIndex(data);
    print('[PROBE] dxdata 歌曲 ${data.songs.length} 首 → 索引 ${index.length} 条');
    expect(index.length, greaterThan(1500));

    DxRatingCoverService.instance.debugResetForTest();
    DxRatingCoverService.instance.debugSetIndex(index);

    var ok = 0;
    var missing = 0;
    for (final entry in kExpectTitles.entries) {
      final songId = entry.key;
      final url = DxRatingCoverService.instance.coverUrlFor(songId);
      if (url == null) {
        print('[PROBE] $songId (${entry.value}) → 索引里没有');
        missing++;
        continue;
      }
      final res = await ApiClient.get(Uri.parse(url),
          timeout: const Duration(seconds: 30));
      final bytes = res.bodyBytes;
      final isJpeg = bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8;
      print('[PROBE] $songId (${entry.value}) → HTTP ${res.statusCode} '
          '${bytes.length}B jpeg=$isJpeg');
      expect(res.statusCode, 200, reason: '$songId ($url)');
      expect(isJpeg, isTrue, reason: '$songId 返回的不是 JPEG');
      ok++;
    }
    print('[PROBE] 出图 $ok 首，索引未命中 $missing 首');

    // 索引里没有的 songId 不该拼出 URL（避免拿注定 404 的地址敲服务器）
    expect(DxRatingCoverService.instance.coverUrlFor('999999999'), isNull);

    DxRatingCoverService.instance.debugResetForTest();
  }, timeout: const Timeout(Duration(minutes: 3)));
}
