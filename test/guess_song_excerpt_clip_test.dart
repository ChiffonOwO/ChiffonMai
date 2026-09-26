// 歌曲片段猜歌「截哪一段」的回归测试。
//
// 背景（真机反馈）：这个模式每局都像只截了歌曲**前几秒**，而不是从随机位置
// 开始。根因在播放那一侧（audioplayers 的定位竞态，见 _playSongExcerpt 的注释），
// 但「起始秒算得对不对」本身也值得钉住 —— 它是纯逻辑，不需要真机音频就能验。
//
// 这里锁两件事：
//   1. 起始秒 + 播放时长**不越界**：越界会让片段在歌尾被截断、听起来像没截够；
//   2. 起始秒的取值范围覆盖到歌曲后半段，而不是恒等于 0（恒等于 0 正是那个
//      「每次都只截前几秒」的症状）。
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_flutter_app/page/GuessChartGame/GuessChartBySongExcerptPage.dart';

void main() {
  group('pickAudioStartTime', () {
    test('起始秒 + 播放时长不超出歌曲总长', () {
      // 覆盖多种组合，含「刚好放得下」与「余量很大」
      const cases = [
        (total: 180, play: 5),
        (total: 180, play: 30),
        (total: 45, play: 5),
        (total: 6, play: 5),
        (total: 5, play: 5),
      ];
      for (final c in cases) {
        for (var i = 0; i < 300; i++) {
          final start = GuessChartBySongExcerptPage.pickAudioStartTime(
            totalSeconds: c.total,
            playDuration: c.play,
          );
          expect(start, greaterThanOrEqualTo(0),
              reason: 'total=${c.total} play=${c.play}: 起始秒不能为负');
          expect(start + c.play, lessThanOrEqualTo(c.total),
              reason: 'total=${c.total} play=${c.play}: 片段不能越过歌尾'
                  '（越界会在歌尾被截断，听起来像只截了前几秒）');
        }
      }
    });

    test('放不下整段时退回 0（不产生负数起始）', () {
      // 总长比播放时长还短，或刚好相等
      for (final c in [(total: 3, play: 5), (total: 5, play: 5), (total: 0, play: 5)]) {
        final start = GuessChartBySongExcerptPage.pickAudioStartTime(
          totalSeconds: c.total,
          playDuration: c.play,
        );
        expect(start, 0, reason: 'total=${c.total} play=${c.play}: 应退回 0');
      }
    });

    test('取值范围是 [0, total-play)，不是恒为 0', () {
      // 注入固定种子，断言确实能取到 0 以外的值、且上界正确
      final r = Random(12345);
      final seen = <int>{};
      for (var i = 0; i < 500; i++) {
        seen.add(GuessChartBySongExcerptPage.pickAudioStartTime(
          totalSeconds: 180,
          playDuration: 5,
          random: r,
        ));
      }
      expect(seen.length, greaterThan(1), reason: '应随机分布，而不是恒为 0');
      expect(seen.reduce(min), greaterThanOrEqualTo(0));
      // nextInt(175) → 0..174
      expect(seen.reduce(max), lessThan(175),
          reason: '上界必须是 total-play=175（不含），否则片段会越界');
      // 180 秒的歌、6 秒的片段，取值应能覆盖到后半段
      expect(seen.reduce(max), greaterThan(87),
          reason: '应能取到歌曲后半段，否则等于「永远只截前半首」');
    });

    test('长歌取到的位置随播放时长收窄上界', () {
      // playDuration 越大，可用的起始区间越小 —— 保证不会为长片段取到越界的头
      final r = Random(7);
      for (var i = 0; i < 200; i++) {
        final start = GuessChartBySongExcerptPage.pickAudioStartTime(
          totalSeconds: 100,
          playDuration: 30,
          random: r,
        );
        expect(start, lessThan(70), reason: 'play=30 时上界应为 70');
      }
    });
  });
}
