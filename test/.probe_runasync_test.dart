// 探针：testWidgets + tester.runAsync 里能否真连本地测试服（决定渲染测试能不能用真实数据）
import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

Future<String> connect() async {
  final ws = await WebSocket.connect('ws://127.0.0.1:3999')
      .timeout(const Duration(seconds: 8));
  final done = Completer<String>();
  final sub = ws.listen((msg) {
    if (!done.isCompleted) done.complete(msg.toString());
  }, onError: (e) { if (!done.isCompleted) done.completeError(e); });
  ws.add('{"action":"initialize","payload":{"nickname":"runasync-probe"}}');
  final res = await done.future.timeout(const Duration(seconds: 8));
  await sub.cancel();
  await ws.close();
  return res;
}

void main() {
  testWidgets('runAsync + 真实 WebSocket', (tester) async {
    HttpOverrides.global = null;
    String? got;
    Object? err;
    await tester.runAsync(() async {
      try { got = await connect(); } catch (e) { err = e; }
    });
    print('[PROBE] err=$err');
    print('[PROBE] got=$got');
  });
}