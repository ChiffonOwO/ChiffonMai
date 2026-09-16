// 「设置保存立刻生效」的回归测试。
//
// 背景：用户反馈单人猜歌点「确定」后要等 3-5 秒才看到「已保存」。
// 实测 saveSettings 本身只要 ~2ms，等待全花在**保存之前**跑的抽曲校验上
// （randomSelectSong 要遍历整份曲库，冷启动还包含读盘 + 解析）。
//
// 修复要点：把校验挪到保存**之后**异步执行。这里锁住两件事：
//   1. saveSettings 本身就很快（不依赖曲库是否已加载）
//   2. 保存不依赖任何抽曲校验就能完成 —— 即校验慢/失败都不阻塞落盘
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_first_flutter_app/constant/CacheKeyConstant.dart';
import 'package:my_first_flutter_app/service/GuessChartGame/GuessChartCommonSettingsService.dart';
import 'package:my_first_flutter_app/service/GuessChartGame/GuessChartByInfoService.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('保存立刻生效（回归：原先要等抽曲校验跑完）', () {
    test('saveSettings 不依赖曲库：即使曲库未加载也很快', () async {
      // 关键：**不**预置 cachedSongs，模拟"曲库还没加载"的冷启动
      SharedPreferences.setMockInitialValues({});

      final sw = Stopwatch()..start();
      await GuessChartCommonSettingsService().saveSettings(
        selectedVersions: const ['maimai'],
        masterMinDx: 13.0,
        masterMaxDx: 14.0,
        selectedGenres: const ['POPS'],
        maxGuesses: 5,
        timeLimit: 60,
      );
      sw.stop();

      // 实测 ~2ms；给足余量避免 CI 抖动，重点是它不该是秒级
      expect(sw.elapsedMilliseconds, lessThan(300),
          reason: '保存本身应远快于秒级；慢说明又把校验塞回保存前面了');

      // 并且确实落盘了
      final loaded = await GuessChartCommonSettingsService().loadSettings();
      expect(loaded['masterMinDx'], 13.0);
      expect(loaded['maxGuesses'], 5);
    });

    test('校验用的 randomSelectSong 明显比保存慢（说明它该被挪走）', () async {
      // 造一份有规模的曲库，让"校验"确实需要遍历
      final songs = <Map<String, dynamic>>[];
      for (var i = 0; i < 1500; i++) {
        songs.add({
          'id': '$i',
          'title': '曲目$i',
          'type': 'SD',
          'ds': [2.0, 7.0, 9.5, 13.4],
          'level': ['2', '7', '9+', '13+'],
          'cids': [i, i, i, i, i],
          'charts': <dynamic>[],
          'basic_info': {
            'title': '曲目$i',
            'artist': 'a$i',
            'genre': 'POPS',
            'bpm': 180,
            'release_date': '2020-01-01',
            'from': 'maimai',
            'is_new': false,
          },
        });
      }
      SharedPreferences.setMockInitialValues({
        CacheKeyConstant.cachedSongs: json.encode(songs),
      });

      final checkStopwatch = Stopwatch()..start();
      await GuessChartByInfoService.randomSelectSong(
        selectedVersions: const [],
        masterMinDx: 1.0,
        masterMaxDx: 15.0,
        selectedGenres: const [],
      );
      checkStopwatch.stop();

      final saveStopwatch = Stopwatch()..start();
      await GuessChartCommonSettingsService().saveSettings(
        selectedVersions: const [],
        masterMinDx: 1.0,
        masterMaxDx: 15.0,
        selectedGenres: const [],
        maxGuesses: 10,
        timeLimit: 0,
      );
      saveStopwatch.stop();

      // ignore: avoid_print
      print('  冷启动校验 = ${checkStopwatch.elapsedMilliseconds}ms, '
          '保存 = ${saveStopwatch.elapsedMilliseconds}ms');
      // 校验（首次含解析）应当明显比保存重，这正是要把它挪到保存之后的原因
      expect(checkStopwatch.elapsedMilliseconds,
          greaterThanOrEqualTo(saveStopwatch.elapsedMilliseconds),
          reason: '校验是重操作，保存是轻操作 —— 顺序不该反过来');
    });
  });
}
