// DXDataManager 的缓存与新鲜度策略测试。
//
// 背景（用户反馈）：进入曲目详情页时**每次都重新加载定数历史** —— 因为
// 之前只有内存缓存（`_cached`），冷启动后任何一次 `load()` 都会重下 4MB 的
// dxdata（实测 200s+，慢网下既慢又容易失败）。
//
// 现在三条路：内存 → 磁盘副本 → 网络，且"要不要下"用官方的 **HEAD + ETag**
// 判断（`HEAD /dxdata` 只回头信息、不加载正文；`If-None-Match` 命中回 304）。
// 这个文件把这几条钉住，因为写错了的表现是"又能用了但悄悄变慢/变旧"：
//   * 该省的下载没省掉 → 又变成每次进页面重下 4MB；
//   * 该更新的没更新 → 新曲定数/曲绘索引永远是旧的（12054 那种新曲就没图）。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_flutter_app/manager/DXDataManager.dart';

/// 造一份最小可解析的目录 JSON（字段与真实 dxdata 对齐，
/// 见 `test/dxrating_cover_test.dart` 里更完整的那份）。
Map<String, dynamic> catalogJson({required int songCount}) => {
      'schemaVersion': 1,
      'updatedAt': '2026-09-17T00:00:00Z',
      'categories': <dynamic>[],
      'versions': <dynamic>[],
      'types': <dynamic>[],
      'difficulties': <dynamic>[],
      'servers': <dynamic>[],
      'songs': <dynamic>[
        for (var i = 0; i < songCount; i++)
          {
            'id': 'dsng_$i',
            'category': 'POPS＆アニメ',
            'title': 'song-$i',
            'artist': 'a',
            'bpm': 180,
            'imageName': 'img$i',
            'version': 'maimai',
            'isNew': false,
            'isLocked': false,
            'sheets': <dynamic>[
              {
                'id': 'dsht_$i',
                'type': 'std',
                'difficulty': 'master',
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
                'internalId': 100 + i,
                'releaseDate': '2020-01-01',
              },
            ],
            'searchAcronyms': <String>[],
          },
      ],
      'tagGroups': <dynamic>[],
      'tags': <dynamic>[],
      'tagSongs': <dynamic>[],
      // ⚠️ 少这个字段会让 DXDataEntity.fromJson 抛
      // "type 'Null' is not a subtype of type 'List<dynamic>'"
      'aliases': <dynamic>[],
    };

void main() {
  late Directory dir;
  late int downloads;
  late int heads;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('dxdata_manager_test');
    downloads = 0;
    heads = 0;
    DXDataManager.debugCacheDirOverride = dir;
    DXDataManager().debugResetForTest();
  });

  tearDown(() async {
    DXDataManager.debugCacheDirOverride = null;
    DXDataManager.debugHeadEtag = null;
    DXDataManager.debugFetchCatalog = null;
    DXDataManager().debugResetForTest();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  /// 模拟服务端：HEAD 回 [etag]，GET 按 [If-None-Match] 决定 200/304。
  void serve({required String etag, required int songCount}) {
    DXDataManager.debugHeadEtag = () async {
      heads++;
      return etag;
    };
    DXDataManager.debugFetchCatalog = (ifNoneMatch) async {
      downloads++;
      if (ifNoneMatch != null && ifNoneMatch == etag) {
        return (status: 304, body: null, etag: ifNoneMatch);
      }
      return (status: 200, body: catalogJson(songCount: songCount), etag: etag);
    };
  }

  test('冷启动命中磁盘副本：不再下载 4MB（修掉"进页面老重新加载定数历史"）',
      () async {
    serve(etag: '"v1"', songCount: 3);

    // 第一次：没有副本 → 下载并落盘
    expect(await DXDataManager().checkForUpdate(force: true), isTrue);
    expect(downloads, 1);

    // 模拟下次冷启动：内存清空、磁盘留着
    DXDataManager().debugResetForTest();
    downloads = 0;
    heads = 0;

    final loaded = await DXDataManager().load();
    expect(loaded?.songs.length, 3, reason: '应当直接用磁盘副本');
    expect(downloads, 0, reason: '有磁盘副本就不该再下正文');

    // 后台那次探测跑完也不该下正文（副本刚存过，TTL 内直接返回）
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(downloads, 0);
  });

  test('副本过期后：ETag 一致 → 只探测不下正文', () async {
    serve(etag: '"v1"', songCount: 2);
    expect(await DXDataManager().checkForUpdate(force: true), isTrue);
    expect(downloads, 1);

    downloads = 0;
    heads = 0;
    // 忽略 TTL 强制探测（模拟基线过期 / 「刷新数据」）
    final changed = await DXDataManager().checkForUpdate(force: true);
    expect(changed, isFalse, reason: '目录没变就不算更新');
    expect(heads, 1, reason: '应当走 HEAD 探测');
    expect(downloads, 0, reason: 'ETag 一致时绝不能下 4MB');
  });

  test('ETag 变了 → 下载一次并落盘；下次冷启动又不用下', () async {
    serve(etag: '"v1"', songCount: 2);
    await DXDataManager().checkForUpdate(force: true);

    // 服务端换了目录
    serve(etag: '"v2"', songCount: 5);
    downloads = 0;
    expect(await DXDataManager().checkForUpdate(force: true), isTrue);
    expect(downloads, 1, reason: '目录真变了才下正文');
    expect(DXDataManager().data?.songs.length, 5);

    // 下次冷启动：磁盘里已经是 v2
    DXDataManager().debugResetForTest();
    downloads = 0;
    heads = 0;
    final loaded = await DXDataManager().load();
    expect(loaded?.songs.length, 5);
    expect(downloads, 0);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(downloads, 0, reason: 'ETag 一致（v2），后台探测也不下正文');
  });

  test('服务端回 304：本地数据保持不变，也不重复落盘', () async {
    serve(etag: '"v1"', songCount: 2);
    await DXDataManager().checkForUpdate(force: true);

    // 直接让 GET 回 304（HEAD 拿不到 ETag 的情形：CDN 把 HEAD 拦了之类）
    DXDataManager.debugHeadEtag = () async => null;
    DXDataManager.debugFetchCatalog = (ifNoneMatch) async {
      downloads++;
      return (status: 304, body: null, etag: ifNoneMatch);
    };
    downloads = 0;
    expect(await DXDataManager().checkForUpdate(force: true), isFalse);
    expect(downloads, 1, reason: 'HEAD 不可用时退回普通请求');
    expect(DXDataManager().data?.songs.length, 2, reason: '304 不能把数据清掉');
  });

  test('没有副本且下载失败：返回 null 而不是抛异常', () async {
    DXDataManager.debugHeadEtag = () async => null;
    DXDataManager.debugFetchCatalog = (ifNoneMatch) async {
      downloads++;
      return (status: 0, body: null, etag: null);
    };

    expect(await DXDataManager().load(), isNull);
    expect(downloads, 1);
  });

  test('TTL 内不探测：force=false 时连 HEAD 都不发', () async {
    serve(etag: '"v1"', songCount: 2);
    await DXDataManager().checkForUpdate(force: true);

    heads = 0;
    downloads = 0;
    expect(await DXDataManager().checkForUpdate(), isFalse);
    expect(heads, 0, reason: '刚探测过就不该再探');
    expect(downloads, 0);
  });

  test('损坏的磁盘副本：当作没有副本，重新下载', () async {
    final body = File('${dir.path}/dxdata_catalog_v1.json');
    await body.writeAsString('{ 这不是 JSON');
    serve(etag: '"v1"', songCount: 4);

    final loaded = await DXDataManager().load();
    expect(loaded?.songs.length, 4, reason: '副本坏了要能自愈');
    expect(downloads, 1);
  });

  test('落盘的是接口原样 JSON + 元信息（ETag 能读回来）', () async {
    serve(etag: '"v1"', songCount: 2);
    await DXDataManager().checkForUpdate(force: true);

    final meta = jsonDecode(
        await File('${dir.path}/dxdata_catalog_v1_meta.json').readAsString());
    expect(meta['etag'], '"v1"');
    expect(meta['count'], 2);

    // 新实例读磁盘时应当把 ETag 一起读回来（否则每次冷启动都要白下一遍）
    DXDataManager().debugResetForTest();
    DXDataManager.debugHeadEtag = () async {
      heads++;
      return '"v1"';
    };
    DXDataManager.debugFetchCatalog = (ifNoneMatch) async {
      downloads++;
      return (status: 200, body: catalogJson(songCount: 2), etag: '"v1"');
    };
    downloads = 0;
    await DXDataManager().load();
    await DXDataManager().checkForUpdate(force: true);
    expect(downloads, 0, reason: '磁盘元信息里的 ETag 要和远端一致才对');
  });
}
