import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:my_first_flutter_app/page/AwmcNet/AwmcNetSyncFlow.dart';
import 'package:my_first_flutter_app/service/AwmcNetScoreUploadService.dart';

/// AWMC NET「同步成绩到 AWMC NET」的响应解析与错误映射。
///
/// **所有响应体都是 2026-09-24 对 net.wmc.pub 实测抓到的原文**，
/// 所以这些用例同时是「服务端文案变了要回来改代码」的回归守卫。
void main() {
  http.Response res(int status, String body) =>
      http.Response.bytes(utf8.encode(body), status);

  group('成功响应解析（实测原文）', () {
    // 真实的一次导入响应（省略了 sgwcmaid 与 profile —— 我们刻意不解析它们）
    const successBody = '''
{
  "total_records": 1708,
  "imported": 9,
  "updated": 1106,
  "skipped": 593,
  "errors": [
    "#0 id=0: 找不到歌曲，跳过",
    "#360 id=510: 找不到歌曲，跳过",
    "#1074 id=11321: 找不到歌曲，跳过"
  ]
}''';

    test('统计字段解析正确', () {
      final r = AwmcNetScoreUploadService.parseResponse(res(200, successBody), 36200);
      expect(r.ok, isTrue);
      expect(r.totalRecords, 1708);
      expect(r.imported, 9);
      expect(r.updated, 1106);
      expect(r.skipped, 593);
      expect(r.elapsedMs, 36200);
      expect(r.errorMessage, isNull);
    });

    test('errors 非空**不代表失败** —— HTTP 200 就是成功', () {
      // 这是接入时最容易写错的一条：把 errors 非空当成同步失败
      final r = AwmcNetScoreUploadService.parseResponse(res(200, successBody), 1);
      expect(r.ok, isTrue, reason: '实测有 20 条逐条失败时 HTTP 仍是 200');
      expect(r.errors.length, 3);
      expect(r.errors.first, contains('找不到歌曲'));
    });

    test('summary 把三项统计都带上', () {
      final r = AwmcNetScoreUploadService.parseResponse(res(200, successBody), 1);
      expect(r.summary, contains('新增 9'));
      expect(r.summary, contains('更新 1106'));
      expect(r.summary, contains('跳过 593'));
    });

    test('缺字段 / 非 JSON / 非法结构都不崩', () {
      final a = AwmcNetScoreUploadService.parseResponse(res(200, '{}'), 0);
      expect(a.ok, isTrue);
      expect(a.imported, 0);

      final b = AwmcNetScoreUploadService.parseResponse(res(200, 'not json'), 0);
      expect(b.ok, isFalse);

      final c = AwmcNetScoreUploadService.parseResponse(res(200, '[1,2]'), 0);
      expect(c.ok, isFalse, reason: '顶层不是对象要判失败，不能当成空统计');
    });
  });

  group('错误映射（实测服务端文案）', () {
    test('401 未带 Token → 提示缺少，且不判定为「Token 无效」', () {
      final r = AwmcNetScoreUploadService.parseResponse(
        res(401, '{"status":"error","message":"程序上传需要提供 Import-Token"}'),
        0,
      );
      expect(r.ok, isFalse);
      expect(r.tokenInvalid, isFalse,
          reason: '没带 Token 时不该让用户去重新复制');
      expect(r.errorMessage, contains('缺少'));
    });

    test('401 Token 无效 → 标记 tokenInvalid，让 UI 清掉本地存的那份', () {
      final r = AwmcNetScoreUploadService.parseResponse(
        res(401, '{"status":"error","message":"Import-Token 无效"}'),
        0,
      );
      expect(r.ok, isFalse);
      expect(r.tokenInvalid, isTrue);
      expect(r.errorMessage, contains('无效'));
    });

    test('400 二维码缺失/无效 → 提示重新获取，不牵扯 Token', () {
      final r = AwmcNetScoreUploadService.parseResponse(
        res(400, '{"message":"需要提供 sgwcmaid 或二维码图片"}'),
        0,
      );
      expect(r.ok, isFalse);
      expect(r.tokenInvalid, isFalse);
      expect(r.errorMessage, contains('二维码'));
    });

    test('429 / 5xx / 未知状态码都有中文文案，不裸奔英文', () {
      final tooMany = AwmcNetScoreUploadService.parseResponse(res(429, '{}'), 0);
      expect(tooMany.errorMessage, contains('频繁'));

      final server = AwmcNetScoreUploadService.parseResponse(res(502, 'bad gateway'), 0);
      expect(server.errorMessage, contains('服务端异常'));

      final odd = AwmcNetScoreUploadService.parseResponse(res(418, 'teapot'), 0);
      expect(odd.errorMessage, contains('418'));
    });
  });

  group('入参校验（不联网就该拦下）', () {
    test('空 Token / 空二维码直接失败，不发请求', () async {
      final svc = AwmcNetScoreUploadService.instance;
      final noToken = await svc.importByQr(importToken: '  ', sgwcmaid: 'SGWCMAID1');
      expect(noToken.ok, isFalse);
      expect(noToken.errorMessage, contains('Token'));

      final noQr = await svc.importByQr(importToken: 't', sgwcmaid: '');
      expect(noQr.ok, isFalse);
      expect(noQr.errorMessage, contains('二维码'));
    });
  });

  // 等待进度现在显示在按钮上，结果只给一个 toast —— 文案口径在这里钉住。
  group('结果 toast（按钮进度跑完之后）', () {
    AwmcNetQrImportResult okResult({
      int imported = 9,
      int updated = 1106,
      int skipped = 593,
      List<String> errors = const [],
      int elapsedMs = 36200,
    }) =>
        AwmcNetQrImportResult(
          ok: true,
          totalRecords: 1708,
          imported: imported,
          updated: updated,
          skipped: skipped,
          errors: errors,
          elapsedMs: elapsedMs,
        );

    test('三项计数 + 耗时都报出来', () {
      final msg = AwmcNetSyncFlow.toastFor(
          AwmcNetSyncOutcome(ok: true, result: okResult()));
      expect(msg, contains('导入完成'));
      expect(msg, contains('新增 9'));
      expect(msg, contains('更新 1106'));
      expect(msg, contains('跳过 593'));
      expect(msg, contains('36.2'));
    });

    test('skipped 为 0 时不啰嗦', () {
      final msg = AwmcNetSyncFlow.toastFor(AwmcNetSyncOutcome(
          ok: true, result: okResult(imported: 3, updated: 0, skipped: 0)));
      expect(msg, contains('新增 3'));
      expect(msg, isNot(contains('跳过')));
    });

    test('逐条失败非空要说一句（否则用户以为成绩丢了）', () {
      final msg = AwmcNetSyncFlow.toastFor(AwmcNetSyncOutcome(
        ok: true,
        result: okResult(errors: const ['a', 'b']),
      ));
      expect(msg, contains('2 条谱面 AWMC NET 暂未收录'));
    });

    test('失败时直接把原因给出来', () {
      final msg = AwmcNetSyncFlow.toastFor(AwmcNetSyncOutcome(
        result: AwmcNetQrImportResult.failure('AWMC NET 导入 Token 无效'),
      ));
      expect(msg, 'AWMC NET 导入 Token 无效');
    });

    test('用户取消（没发请求）不该被说成失败', () {
      expect(AwmcNetSyncOutcome.userCancelled.cancelled, isTrue);
      expect(AwmcNetSyncOutcome.userCancelled.result, isNull);
    });
  });
}
