import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_flutter_app/entity/DXRating/DXDataEntity.dart';
import 'package:my_first_flutter_app/service/DxRatingCoverService.dart';

/// dxrating（shama）曲绘兜底的核心逻辑测试。
///
/// 这条兜底链的实测结论（见 `DxRatingCoverService` 顶部注释）：
/// dxdata 每首歌的 `imageName` → `shama.dxrating.net/images/cover/v2/<imageName>.jpg`，
/// 水鱼 1394 首里能覆盖 99.8%。
///
/// 这里钉住三件事，都是「写错了会悄悄变糟」的地方：
///   1. **id 归一化**：dxdata 里 DX 谱面的 internalId = 10000 + 基础 id
///      （君の知らない物語 std=181 / dx=10181），水鱼的 DX 条目同理；
///      不归一化就有一半歌查不到（实测那样只有 600/1394 命中）。
///   2. **查不到就别拼 URL**：不能拿注定 404 的地址去敲 shama。
///   3. **别反复拉 dxdata**：4MB / 实测 100s，只有缓存缺失或过期
///      （7 天）才重建，而且每个会话最多重建一次；fresh 缓存必须完全不联网。
void main() {
  // 随包基线索引是用 rootBundle 读的，普通 test() 里需要先初始化绑定
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> sheetJson({
    required String type,
    required String difficulty,
    required int internalId,
  }) =>
      {
        'id': 'dsht_$type$difficulty',
        'type': type,
        'difficulty': difficulty,
        'level': '12',
        'internalLevelValue': 12.0,
        'multiverInternalLevelValue': <String, double>{},
        'noteDesigner': '-',
        'noteCounts': {
          'tap': 100,
          'hold': 10,
          'slide': 10,
          'break': 2,
          'total': 122,
        },
        'serverIds': <String>[],
        'isSpecial': false,
        'version': 'maimai',
        'internalId': internalId,
        'releaseDate': '2020-01-01',
      };

  Map<String, dynamic> songJson({
    required String title,
    required String imageName,
    required List<Map<String, dynamic>> sheets,
  }) =>
      {
        'id': 'dsng_x',
        'category': 'POPS＆アニメ',
        'title': title,
        'artist': 'a',
        'bpm': 180,
        'imageName': imageName,
        'version': 'maimai',
        'isNew': false,
        'isLocked': false,
        'sheets': sheets,
        'searchAcronyms': <String>[],
      };

  /// 造一份最小的 dxdata：3 首普通歌（含 std/dx 成对）+ 1 首宴会场
  DXDataEntity buildEntity() => DXDataEntity.fromJson({
        'schemaVersion': 1,
        'updatedAt': '2026-09-17T00:00:00Z',
        'categories': <dynamic>[],
        'versions': <dynamic>[],
        'types': <dynamic>[],
        'difficulties': <dynamic>[],
        'servers': <dynamic>[],
        'songs': <dynamic>[
          songJson(
            title: '君の知らない物語',
            imageName: 'b9d06643',
            sheets: [
              sheetJson(type: 'dx', difficulty: 'master', internalId: 10181),
              sheetJson(type: 'std', difficulty: 'master', internalId: 181),
            ],
          ),
          songJson(
            title: 'ネコ日和。',
            imageName: '4de60720',
            sheets: [
              // 这首歌 dxdata 里 std/dx 都是基础 id
              sheetJson(type: 'dx', difficulty: 'master', internalId: 30),
              sheetJson(type: 'std', difficulty: 'master', internalId: 30),
            ],
          ),
          songJson(title: '没有 internalId 的歌', imageName: 'deadbeef', sheets: [
            sheetJson(type: 'std', difficulty: 'basic', internalId: 0),
          ]),
          songJson(
            title: '[協]Love You',
            imageName: '96141297',
            sheets: [
              sheetJson(type: 'dx', difficulty: 'master', internalId: 100018),
            ],
          ),
        ],
        'tagGroups': <dynamic>[],
        'tags': <dynamic>[],
        'tagSongs': <dynamic>[],
        'aliases': <dynamic>[],
      });

  group('songId 归一化', () {
    test('DX 条目（1xxxx）减 10000，其余原样', () {
      // 水鱼的 DX 条目 id = 10000 + 基础 id：
      // 11663「系ぎて」的实际基础 id 是 1663（dxdata 里 internalId 也是 1663）
      expect(DxRatingCoverService.normalizeSongId('11663'), '1663');
      expect(DxRatingCoverService.normalizeSongId('10030'), '30');
      expect(DxRatingCoverService.normalizeSongId('10181'), '181');
      // 基础 id 原样
      expect(DxRatingCoverService.normalizeSongId('1663'), '1663');
      expect(DxRatingCoverService.normalizeSongId('181'), '181');
      // 6 位是宴会场 id（100000+），不能被当成 DX 别名
      expect(DxRatingCoverService.normalizeSongId('100018'), '100018');
      expect(DxRatingCoverService.normalizeSongId('121634'), '121634');
      expect(DxRatingCoverService.normalizeSongId(' 10030 '), '30');
    });

    test('归一化结果与本地曲绘的 5 位 id 规则一致', () {
      // CoverUtil.getLocalCoverPath 对 5 位 id 是「去掉开头的 1 和连续的 0」，
      // 归一化用整数减法，两者必须给出同一个基础 id，否则本地/网络会各查一套
      for (final raw in ['10030', '10125', '10025', '11312', '11663']) {
        final expected = raw
            .substring(1)
            .replaceAll(RegExp(r'^0+'), '')
            .replaceAll(RegExp(r'^$'), '0');
        expect(DxRatingCoverService.normalizeSongId(raw), expected,
            reason: 'raw=$raw');
      }
    });

    test('非数字原样返回（不抛异常）', () {
      expect(DxRatingCoverService.normalizeSongId(''), '');
      expect(DxRatingCoverService.normalizeSongId('abc'), 'abc');
    });
  });

  group('从 dxdata 建索引', () {
    test('同一首歌的 std/dx 谱面都指向同一个 imageName', () {
      final index = DxRatingCoverService.buildIndex(buildEntity());

      expect(index['181'], 'b9d06643');
      expect(index['30'], '4de60720');
      expect(index['100018'], '96141297');
      expect(index.length, 3, reason: 'internalId<=0 的谱面不参与建索引');
    });
  });

  group('URL 构造', () {
    setUp(() => DxRatingCoverService.instance.debugResetForTest());
    tearDown(() => DxRatingCoverService.instance.debugResetForTest());

    test('索引没就绪时不返回 URL（避免无脑请求）', () {
      expect(DxRatingCoverService.instance.coverUrlFor('11663'), isNull);
      expect(DxRatingCoverService.instance.isLoaded, isFalse);
    });

    test('命中时拼出 shama 的 v2 曲绘地址', () {
      DxRatingCoverService.instance.debugSetIndex({'1663': '3a914643'});

      // 基础 id 直接命中
      expect(
        DxRatingCoverService.instance.coverUrlFor('1663'),
        'https://shama.dxrating.net/images/cover/v2/3a914643.jpg',
      );
      // 水鱼的 DX 条目（10000+基础 id）也要能查到同一张图
      expect(
        DxRatingCoverService.instance.coverUrlFor('11663'),
        'https://shama.dxrating.net/images/cover/v2/3a914643.jpg',
      );
      expect(DxRatingCoverService.instance.coverUrlFor('999999'), isNull);
    });
  });

  group('索引缓存（别反复拉 4MB 的 dxdata）', () {
    late Directory tempDir;

    setUp(() {
      DxRatingCoverService.instance.debugResetForTest();
      tempDir = Directory.systemTemp.createTempSync('dxcover_test');
      DxRatingCoverService.debugCacheDirOverride = tempDir;
    });

    tearDown(() {
      DxRatingCoverService.instance.debugResetForTest();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    Future<File> writeCache({required DateTime savedAt, int version = 1}) async {
      final file = await DxRatingCoverService.cacheFile();
      // 缓存里存的是**归一化后的基础 id**（'1663' = 水鱼 DX 条目 11663 的那首歌）
      await file.writeAsString(jsonEncode({
        'v': version,
        'savedAt': savedAt.millisecondsSinceEpoch,
        'count': 2,
        'images': {'1663': '3a914643', '30': '4de60720'},
      }));
      return file;
    }

    test('fresh 本地缓存：只读本地文件，绝不联网（且优先于随包基线）', () async {
      await writeCache(savedAt: DateTime.now());
      var loaderCalls = 0;
      DxRatingCoverService.debugDxDataLoader = () async {
        loaderCalls++;
        return buildEntity();
      };

      await DxRatingCoverService.instance.ensureLoaded();

      expect(loaderCalls, 0, reason: '7 天内的缓存不该再去拉 dxdata（4MB / 200s+）');
      expect(DxRatingCoverService.instance.indexSize, 2,
          reason: '本地更新比随包基线新，应该用本地那份');
      expect(
        DxRatingCoverService.instance.coverUrlFor('10030'),
        'https://shama.dxrating.net/images/cover/v2/4de60720.jpg',
      );
      expect(
        DxRatingCoverService.instance.coverUrlFor('11663'),
        'https://shama.dxrating.net/images/cover/v2/3a914643.jpg',
      );
    });

    test('没有本地缓存：直接用随包基线，同样不联网', () async {
      var loaderCalls = 0;
      DxRatingCoverService.debugDxDataLoader = () async {
        loaderCalls++;
        return buildEntity();
      };

      await DxRatingCoverService.instance.ensureLoaded();

      expect(loaderCalls, 0, reason: '随包基线还在有效期内，不该联网更新');
      expect(DxRatingCoverService.instance.isLoaded, isTrue);
      expect(DxRatingCoverService.instance.indexSize, greaterThan(1500),
          reason: '基线是构建期由真实 dxdata 生成的（1677 条）');

      // 真实数据抽查：普通 id / DX 条目（10000+基础 id）/ 宴会场都要能查到
      for (final songId in ['383', '8', '10030', '11663', '100018']) {
        final url = DxRatingCoverService.instance.coverUrlFor(songId);
        expect(url, isNotNull, reason: 'songId=$songId 应该能查到曲绘');
        expect(url, startsWith(DxRatingCoverService.baseUrl));
        expect(url, endsWith('.jpg'));
      }
    });

    test('过期缓存：先用基线顶上，再尝试更新一次并落盘', () async {
      await writeCache(savedAt: DateTime.now().subtract(const Duration(days: 8)));
      // 随包基线是构建期生成的（很新），把它也算成过期，才走得到更新分支
      DxRatingCoverService.debugCacheTtlOverride = Duration.zero;
      var loaderCalls = 0;
      DxRatingCoverService.debugDxDataLoader = () async {
        loaderCalls++;
        // 更新期间也要能出图（这里断言基线已经在内存里了）
        expect(DxRatingCoverService.instance.isLoaded, isTrue);
        return buildEntity();
      };

      await DxRatingCoverService.instance.ensureLoaded();
      expect(loaderCalls, 1);
      expect(DxRatingCoverService.instance.indexSize, 3, reason: '换成 dxdata 更新的索引');

      // 落盘了：savedAt 是新的
      final file = await DxRatingCoverService.cacheFile();
      final decoded = jsonDecode(await file.readAsString()) as Map;
      expect(decoded['v'], DxRatingCoverService.cacheVersion);
      expect(
        (decoded['savedAt'] as num).toInt(),
        greaterThan(DateTime.now()
            .subtract(const Duration(minutes: 1))
            .millisecondsSinceEpoch),
      );

      await DxRatingCoverService.instance.ensureLoaded();
      expect(loaderCalls, 1, reason: '一个会话只更新一次');
    });

    test('更新失败：不崩、不反复重试，仍有基线可用', () async {
      DxRatingCoverService.debugCacheTtlOverride = Duration.zero;
      var loaderCalls = 0;
      DxRatingCoverService.debugDxDataLoader = () async {
        loaderCalls++;
        return null;
      };

      await DxRatingCoverService.instance.ensureLoaded();
      await DxRatingCoverService.instance.ensureLoaded();

      expect(loaderCalls, 1, reason: '失败也不该在会话里反复敲 dxdata');
      expect(DxRatingCoverService.instance.coverUrlFor('11663'), isNotNull,
          reason: '更新失败也要能靠随包基线出图');
    });

    test('缓存版本不匹配 → 当作没有缓存', () async {
      await writeCache(savedAt: DateTime.now(), version: 999);
      DxRatingCoverService.debugCacheTtlOverride = Duration.zero;
      var loaderCalls = 0;
      DxRatingCoverService.debugDxDataLoader = () async {
        loaderCalls++;
        return buildEntity();
      };

      await DxRatingCoverService.instance.ensureLoaded();

      expect(loaderCalls, 1);
      expect(DxRatingCoverService.instance.indexSize, 3);
    });

    test('并发调用只加载一次（单飞）', () async {
      DxRatingCoverService.debugCacheTtlOverride = Duration.zero;
      var loaderCalls = 0;
      DxRatingCoverService.debugDxDataLoader = () async {
        loaderCalls++;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return buildEntity();
      };

      await Future.wait([
        DxRatingCoverService.instance.ensureLoaded(),
        DxRatingCoverService.instance.ensureLoaded(),
        DxRatingCoverService.instance.ensureLoaded(),
      ]);

      expect(loaderCalls, 1);
      expect(DxRatingCoverService.instance.indexSize, 3);
    });
  });

  group('选哪份索引 / 要不要更新', () {
    final now = DateTime(2026, 9, 17, 12);
    CoverIndexSource source(String tag, DateTime? at) =>
        (index: {'1': tag}, at: at);

    test('两份都有：用新的那份', () {
      final cached = source('cached', now.subtract(const Duration(days: 1)));
      final bundled = source('bundled', now.subtract(const Duration(days: 30)));

      final pick = DxRatingCoverService.chooseIndex(
          cached: cached, bundled: bundled, now: now, ttl: const Duration(days: 7));
      expect(pick.useCached, isTrue);
      expect(pick.picked!.index['1'], 'cached');
      expect(pick.needsUpdate, isFalse, reason: '本地更新才 1 天，不用联网');

      final pick2 = DxRatingCoverService.chooseIndex(
          cached: bundled, bundled: cached, now: now, ttl: const Duration(days: 7));
      expect(pick2.useCached, isFalse);
      expect(pick2.picked!.index['1'], 'cached');
      expect(pick2.needsUpdate, isFalse);
    });

    test('只有基线：有效期内不联网，过期才联网', () {
      final fresh = DxRatingCoverService.chooseIndex(
        cached: null,
        bundled: source('bundled', now.subtract(const Duration(days: 1))),
        now: now,
        ttl: const Duration(days: 7),
      );
      expect(fresh.useCached, isFalse);
      expect(fresh.needsUpdate, isFalse);

      final stale = DxRatingCoverService.chooseIndex(
        cached: null,
        bundled: source('bundled', now.subtract(const Duration(days: 30))),
        now: now,
        ttl: const Duration(days: 7),
      );
      expect(stale.needsUpdate, isTrue);
    });

    test('两份都没有 → 需要联网；没有时间戳也当作要更新', () {
      final none = DxRatingCoverService.chooseIndex(
          cached: null, bundled: null, now: now);
      expect(none.picked, isNull);
      expect(none.needsUpdate, isTrue);

      final noTime = DxRatingCoverService.chooseIndex(
          cached: source('cached', null), bundled: null, now: now);
      expect(noTime.useCached, isTrue);
      expect(noTime.needsUpdate, isTrue);
    });
  });
}
