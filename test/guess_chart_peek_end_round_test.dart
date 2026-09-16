// 谱面片段猜歌：**结束对局的每一条路径都必须进入答案模式**（准备音频）。
//
// 回归背景：原先「结束对局」的代码散在多处，各自只写 `_isGameOver = true`
// 和记成绩，**只有「猜对 / 用完猜测次数」那条调了 `_enterAnswerMode()`**。
// 于是
//   - 点「投降」结束
//   - 倒计时归零超时结束
// 都不会去准备音频 → 答案模式的复播**只有谱面、没有声音**。
// 现在统一走 `_endRound()`。
//
// 说明（不要误读这个测试的强度）：
// 这是**源码级不变量检查**，不是端到端行为测试。之所以不做行为测试，
// 是因为该页初始化依赖 MaidataManager 的 `compute()`（真实 isolate）
// 与磁盘缓存，在 flutter_test 的 fake async 下无法稳定跑通整个开局流程。
// 它能拦住的是「新增一条结束路径却忘了走 _endRound」这类回归 ——
// 也正是当初出问题的方式；音频是否真的响起来仍需真机验证。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const path = 'lib/page/GuessChartGame/GuessChartByChartPeekPage.dart';
  final source = File(path).readAsStringSync();
  final lines = source.split('\n');

  /// 取出某个方法体的行号区间（按顶层缩进找配对结尾）。
  ({int start, int end}) bodyOf(String signature) {
    final start = lines.indexWhere((l) => l.contains(signature));
    expect(start, isNonNegative, reason: '找不到 $signature');
    // 从签名往下找第一条缩进为 2 空格、且是 "}" 的行作为方法结尾
    for (var i = start + 1; i < lines.length; i++) {
      if (RegExp(r'^  \}\s*$').hasMatch(lines[i])) {
        return (start: start, end: i);
      }
    }
    fail('找不到 $signature 的方法结尾');
  }

  test('所有 _isGameOver = true 都发生在 _endRound 内', () {
    final endRound = bodyOf('Future<void> _endRound(');
    final assignments = <int>[];
    for (var i = 0; i < lines.length; i++) {
      final t = lines[i].trim();
      // 只看真正的赋值语句，跳过注释里提到的
      if (t.startsWith('//')) continue;
      if (t == '_isGameOver = true;') assignments.add(i);
    }

    expect(assignments, isNotEmpty, reason: '_endRound 里应当置 _isGameOver');
    for (final line in assignments) {
      expect(
        line > endRound.start && line < endRound.end,
        isTrue,
        reason: '第 ${line + 1} 行直接置 _isGameOver，绕过了 _endRound —— '
            '这会让该结束路径漏掉答案模式（复播无声）。'
            '请改为调用 _endRound(isWon: ...)',
      );
    }
  });

  test('_endRound 会进入答案模式（准备音频）', () {
    final endRound = bodyOf('Future<void> _endRound(');
    final body = lines.sublist(endRound.start, endRound.end + 1).join('\n');
    expect(body.contains('_enterAnswerMode()'), isTrue,
        reason: '_endRound 必须调用 _enterAnswerMode()，否则复播没有声音');
    expect(body.contains('_recordGameResult('), isTrue,
        reason: '_endRound 应负责记成绩');
  });

  test('投降与超时都走 _endRound', () {
    // 投降按钮的 onPressed
    final surrenderIdx = lines.indexWhere((l) => l.contains("Text('投降')"));
    expect(surrenderIdx, isNonNegative);
    final surrenderBlock =
        lines.sublist(surrenderIdx - 20, surrenderIdx + 1).join('\n');
    expect(surrenderBlock.contains('_endRound('), isTrue,
        reason: '投降必须走 _endRound，否则复播无声（本次修的 bug）');

    // 倒计时超时分支
    final countdown = bodyOf('void _startCountdown()');
    final countdownBody =
        lines.sublist(countdown.start, countdown.end + 1).join('\n');
    expect(countdownBody.contains('_endRound('), isTrue,
        reason: '超时必须走 _endRound，否则复播无声（本次修的 bug）');
  });
}
