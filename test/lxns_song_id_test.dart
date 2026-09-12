// 验证落雪 id 体系转换 —— 这是最容易"静默写错歌"的一步：
// 传错 id 服务端可能照样返回 200，但成绩记到别的曲目上。
//
// 依据：落雪文档开头「同一首曲目的标准、DX 谱面的曲目 ID 一致，不存在大于
// 10000 的曲目 ID（如有，请在请求前对 10000 取余处理）。宴会场曲目为例外，
// 不分标准、DX 谱面，曲目 ID 大于 100000」。
import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_flutter_app/service/LuoXueScoreUploadService.dart';

void main() {
  group('toLxnsSongId', () {
    test('DX 谱面：对 10000 取余', () {
      // 文档示例里「群青シグナル」是水鱼 id 11466、落雪 id 1466
      expect(LuoXueScoreUploadService.toLxnsSongId(11466), 1466);
      expect(LuoXueScoreUploadService.toLxnsSongId(11001), 1001);
    });

    test('标准与 DX 落到同一个落雪 id（文档明确要求）', () {
      // 水鱼 1001（标准）与 11001（DX）是同一首曲目的两个谱面
      expect(LuoXueScoreUploadService.toLxnsSongId(1001),
          LuoXueScoreUploadService.toLxnsSongId(11001));
    });

    test('四位数及以下：取余后不变', () {
      expect(LuoXueScoreUploadService.toLxnsSongId(834), 834);
      expect(LuoXueScoreUploadService.toLxnsSongId(1466), 1466);
    });

    test('宴会场（>=100000）：原样返回，绝不取余', () {
      // 取余会得到一个完全不相干的曲目 id
      expect(LuoXueScoreUploadService.toLxnsSongId(11740), 1740);
      expect(LuoXueScoreUploadService.toLxnsSongId(100018), 100018);
      expect(LuoXueScoreUploadService.toLxnsSongId(118009), 118009);
    });
  });

  group('toLxnsSongType', () {
    test('普通曲：DX / SD 映射为 dx / standard', () {
      expect(
          LuoXueScoreUploadService.toLxnsSongType(
              divingFishId: 11466, type: 'DX'),
          'dx');
      expect(
          LuoXueScoreUploadService.toLxnsSongType(
              divingFishId: 1466, type: 'SD'),
          'standard');
    });

    test('宴会场：靠 id 区间判定，无视 type', () {
      expect(
          LuoXueScoreUploadService.toLxnsSongType(
              divingFishId: 118009, type: 'DX'),
          'utage');
      expect(
          LuoXueScoreUploadService.toLxnsSongType(
              divingFishId: 118009, type: 'SD'),
          'utage');
    });
  });
}