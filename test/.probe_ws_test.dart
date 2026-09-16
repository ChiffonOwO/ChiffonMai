// 探针：flutter test 环境里 WebSocket 能否真连本地测试服（3999）
import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

Future<bool> tryConnect(String label) async {
  try {
    final ws = await WebSocket.connect('ws://127.0.0.1:3999')
        .timeout(const Duration(seconds: 8));
    final done = Completer<void>();
    late StreamSubscription sub;
    sub = ws.listen((msg) {
      print('[PROBE][$label] RECV: $msg');
      if (!done.isCompleted) done.complete();
    }, onError: (e) => print('[PROBE][$label] ERR: $e'),
       onDone: () => print('[PROBE][$label] DONE'));
    ws.add('{"action":"initialize","payload":{"nickname":"探针"}}');
    await done.future.timeout(const Duration(seconds: 8));
    await sub.cancel();
    await ws.close();
    print('[PROBE][$label] OK 真实收到服务端响应');
    return true;
  } catch (e) {
    print('[PROBE][$label] FAIL: $e');
    return false;
  }
}

void main() {
  test('plain test() 下的 WS', () async {
    final ok = await tryConnect('plain');
    print('[PROBE] plain result = $ok');
  });

  testWidgets('testWidgets() 下的 WS（清掉 HttpOverrides）', (tester) async {
    HttpOverrides.global = null;
    final ok = await tryConnect('widgets-cleared');
    print('[PROBE] cleared result = $ok');
  });
}