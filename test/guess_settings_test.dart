// 单人猜歌「设置」的持久化与重置契约测试。
//
// 这些不变量之前全被违反过，且**静态检查发现不了**（字段名写错、页面自己
// 硬编码默认值都属于「能编译、跑起来才丢数据」的问题）：
//   1. 歌曲片段页的「播放时长」根本没进 saveSettings，重启即回默认 5 秒
//   2. 各页「重置所有设置」各自硬编码默认值，歌曲片段页那份漏了播放时长
//   3. 难度编号的合法集合两边不一致（服务侧曾含不存在的 '1'）
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_first_flutter_app/constant/CacheKeyConstant.dart';
import 'package:my_first_flutter_app/service/GuessChartGame/GuessChartCommonSettingsService.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = GuessChartCommonSettingsService();

  group('播放时长持久化（回归：原先重启即丢）', () {
    test('saveSettings 写入后能 loadSettings 读回', () async {
      SharedPreferences.setMockInitialValues({});

      await service.saveSettings(
        selectedVersions: const [],
        masterMinDx: 1.0,
        masterMaxDx: 15.0,
        selectedGenres: const [],
        maxGuesses: 10,
        timeLimit: 0,
        playDurationSeconds: 23,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(CacheKeyConstant.guessChartPlayDuration), 23,
          reason: '必须真的落盘到 guessChart_playDuration');

      final loaded = await service.loadSettings();
      expect(loaded['playDurationSeconds'], 23);
    });

    test('未设置过时回落默认 5 秒', () async {
      SharedPreferences.setMockInitialValues({});
      final loaded = await service.loadSettings();
      expect(loaded['playDurationSeconds'], 5);
    });

    test('不传该参数时不会误清掉已存的值', () async {
      SharedPreferences.setMockInitialValues({
        CacheKeyConstant.guessChartPlayDuration: 17,
      });
      // 其它页面保存设置时不会带 playDurationSeconds
      await service.saveSettings(
        selectedVersions: const [],
        masterMinDx: 1.0,
        masterMaxDx: 15.0,
        selectedGenres: const [],
        maxGuesses: 8,
        timeLimit: 30,
      );
      final loaded = await service.loadSettings();
      expect(loaded['playDurationSeconds'], 17,
          reason: '未传该参数应保持不变，而不是被重置');
      expect(loaded['maxGuesses'], 8);
    });
  });

  group('默认值单一真源（回归：各页硬编码导致漏项）', () {
    test('defaultSettings() 与 resetToDefault() 后的 loadSettings 完全一致', () async {
      SharedPreferences.setMockInitialValues({
        // 先塞一堆非默认值
        CacheKeyConstant.guessChartSelectedVersions: ['maimai'],
        CacheKeyConstant.guessChartMasterMinDx: 13.0,
        CacheKeyConstant.guessChartMasterMaxDx: 14.0,
        CacheKeyConstant.guessChartSelectedGenres: ['POPS'],
        CacheKeyConstant.guessChartMaxGuesses: 5,
        CacheKeyConstant.guessChartTimeLimit: 60,
        CacheKeyConstant.guessChartBlurLevel: 77,
        CacheKeyConstant.guessChartSongCount: 7,
        CacheKeyConstant.guessChartNonEnglishCharThreshold: 33,
        CacheKeyConstant.guessChartFlashDuration: 900,
        CacheKeyConstant.guessChartTileCount: 2500,
        CacheKeyConstant.guessTileRevealInterval: 900,
        CacheKeyConstant.guessChartPeekDuration: 20,
        CacheKeyConstant.guessChartPeekDifficulties: ['3', '4'],
        CacheKeyConstant.guessChartPlayDuration: 25,
      });

      await service.resetToDefault();
      final loaded = await service.loadSettings();
      final defaults = service.defaultSettings();

      expect(loaded.keys.toSet(), defaults.keys.toSet(),
          reason: '两个 map 的 key 必须一一对应，新增设置项时不会漏');
      defaults.forEach((k, v) {
        expect(loaded[k], v, reason: '字段 $k 的默认值不一致');
      });
    });

    test('defaultSettings 覆盖全部已持久化的设置键', () async {
      SharedPreferences.setMockInitialValues({});
      // 存一份「全字段」的配置，落盘的键应与 defaultSettings 的字段同集合
      await service.saveSettings(
        selectedVersions: const ['x'],
        masterMinDx: 1.0,
        masterMaxDx: 15.0,
        selectedGenres: const ['y'],
        maxGuesses: 1,
        timeLimit: 1,
        blurLevel: 1,
        songCount: 1,
        nonEnglishCharThreshold: 1,
        flashDurationMs: 100,
        tileCount: 100,
        tileRevealIntervalMs: 100,
        peekDurationSeconds: 3,
        peekDifficulties: const ['4'],
        playDurationSeconds: 1,
      );
      final prefs = await SharedPreferences.getInstance();
      final loaded = await service.loadSettings();
      expect(prefs.getKeys().length, loaded.length,
          reason: '落盘的设置键数量应与 loadSettings 返回的字段数一致');
    });
  });

  group('难度编号合法集合（回归：服务侧曾含不存在的 1）', () {
    test('允许 2..6，不含 1', () {
      expect(GuessChartCommonSettingsService.allowedDifficultyInotes,
          {'2', '3', '4', '5', '6'});
    });

    test('与页面可选项一致（BASIC 是 2，没有 1）', () {
      // 页面 GuessChartByChartPeekPage._difficultyNames 的键
      const pageInotes = {'2', '3', '4', '5', '6'};
      expect(GuessChartCommonSettingsService.allowedDifficultyInotes,
          pageInotes);
    });
  });

  group('validateSettings 边界', () {
    test('默认设置合法', () {
      expect(service.validateSettings(service.defaultSettings()), isTrue);
    });

    test('min > max 判为非法', () {
      expect(
          service.validateSettings({'masterMinDx': 14.0, 'masterMaxDx': 13.0}),
          isFalse);
    });

    test('0 表示无限制，属合法', () {
      expect(service.validateSettings({'maxGuesses': 0}), isTrue);
      expect(service.validateSettings({'timeLimit': 0}), isTrue);
    });

    test('越界的模式专属参数判为非法', () {
      expect(service.validateSettings({'blurLevel': 150}), isFalse);
      expect(service.validateSettings({'songCount': 99}), isFalse);
      expect(service.validateSettings({'nonEnglishCharThreshold': 200}),
          isFalse);
      expect(service.validateSettings({'playDurationSeconds': 31}), isFalse);
      expect(service.validateSettings({'playDurationSeconds': 0}), isFalse);
    });

    test('难度池为空或含非法编号判为非法', () {
      expect(service.validateSettings({'peekDifficulties': <String>[]}),
          isFalse);
      expect(service.validateSettings({'peekDifficulties': ['9']}), isFalse);
      expect(service.validateSettings({'peekDifficulties': ['1']}), isFalse,
          reason: "'1' 在页面里不是可选难度");
    });
  });
}
