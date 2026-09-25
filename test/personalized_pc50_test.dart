// PC50（个性化 Best50 → 游玩次数前 50）的服务测试。
//
// 数据链路：成绩记录（`user_play_data`，水鱼/落雪同步）× 游玩次数
// （`awmc_play_counts_v1`，**同步成绩的线路2 · AWMC 网关**写入）。
// 这里钉的是口径：次数从哪来、缺次数怎么办、extra 怎么办、并列怎么排。
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_first_flutter_app/constant/CacheKeyConstant.dart';
import 'package:my_first_flutter_app/service/AWMC/AwmcPlayCountStore.dart';
import 'package:my_first_flutter_app/service/Best50/PersonalizedBest50Service.dart';
import 'package:my_first_flutter_app/utils/CurrentDataSourceNotifier.dart';

Map<String, dynamic> song(String id, String title, {List<int>? cids}) => {
      'id': id,
      'title': title,
      'type': 'DX',
      'ds': <double>[2.0, 7.0, 9.5, 13.6, 14.2],
      'level': <String>['2', '7', '9+', '13+', '14'],
      'cids': cids ?? <int>[1, 2, 3, 4],
      'charts': <Map<String, dynamic>>[
        for (var i = 0; i < 5; i++)
          {'notes': <int>[263, 14, 19, 6], 'charter': '譜面-$i'},
      ],
      'basic_info': {
        'title': title,
        'artist': 'test',
        'genre': '舞萌',
        'bpm': 150,
        'release_date': '',
        'from': 'maimai',
        'is_new': false,
      },
    };

Map<String, dynamic> record(String songId, int levelIndex, int ra) => {
      'song_id': int.parse(songId),
      'level_index': levelIndex,
      'achievements': 100.0,
      'ra': ra,
      'rate': 'sssp',
      'fc': 'app',
      'fs': 'sync',
      'dxScore': 3000,
    };

/// 写入曲库 / 成绩 / 游玩次数三个缓存；[counts] 为 null 表示没同步过线路2。
void seed({
  required List<Map<String, dynamic>> songs,
  required List<Map<String, dynamic>> records,
  Map<String, int>? counts,
}) {
  AwmcPlayCountStore.debugResetForTest();
  // 游玩次数按账号分开存：这里写的是「当前活动账号」那一份（默认水鱼）
  CurrentDataSourceNotifier.instance.value = RefreshDataSource.shuiyu;
  SharedPreferences.setMockInitialValues({
    CacheKeyConstant.cachedSongs: json.encode(songs),
    CacheKeyConstant.userPlayData:
        json.encode({'records': records, 'additional_rating': 0}),
    if (counts != null)
      '${CacheKeyConstant.awmcPlayCountsPrefix}${RefreshDataSource.shuiyu.key}':
          json.encode({
        'version': 1,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'userId': 1,
        'counts': counts,
      }),
  });
}

/// 曲库：**每个用例都塞同一份完整列表**。
///
/// `MaimaiMusicDataManager` 会把曲库缓存在内存里（只在第一次读 prefs），
/// 而 `SecretPreferences` 的 mock 每个用例都会重置 —— 所以每个用例都必须给出
/// 同一份「包含所有用到的 id」的曲库，否则先跑的用例决定了后面用例能查到哪些曲。
List<Map<String, dynamic>> allSongs() => [
      song('8', 'A'),
      song('10', 'B'),
      song('100', 'C'),
      song('100018', '宴会场'), // 6 位 id → extra
      song('200', '追加曲', cids: [0, 0, 0, 0]), // cids 全 0 → extra
      for (var i = 0; i < 60; i++) song('${2000 + i}', 'song$i'), // 测 50 条上限
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('按游玩次数降序，并把 playCount 写回记录', () async {
    seed(
      songs: allSongs(),
      records: [
        record('8', 3, 335),
        record('10', 3, 300),
        record('100', 3, 320),
      ],
      counts: {'8/3': 100, '10/3': 300, '100/3': 200},
    );

    final data = await PersonalizedBest50Service().getPC50Data();

    expect(data, isNotNull);
    expect(data!['type'], 'pc_50');
    expect(data['total'], 3);
    final records = data['records'] as List;
    expect(records.map((r) => r['song_id']).toList(), [10, 100, 8],
        reason: '次数 300 > 200 > 100');
    expect(records.map((r) => r['playCount']).toList(), [300, 200, 100],
        reason: '次数要写回记录，卡片才能显示');
  });

  test('次数相同的按 ra 降序（顺序稳定，不会每次刷新乱跳）', () async {
    seed(
      songs: allSongs(),
      records: [record('8', 3, 300), record('10', 3, 335)],
      counts: {'8/3': 50, '10/3': 50},
    );

    final records =
        (await PersonalizedBest50Service().getPC50Data())!['records'] as List;
    expect(records.map((r) => r['song_id']).toList(), [10, 8],
        reason: '同次数时 ra 高的在前');
  });

  test('没有次数缓存的记录被剔除（只保留机台有次数的谱面）', () async {
    seed(
      songs: allSongs(),
      records: [
        record('8', 3, 335),
        record('10', 3, 300),
        record('100', 3, 320),
      ],
      counts: {'8/3': 100},
    );

    final records =
        (await PersonalizedBest50Service().getPC50Data())!['records'] as List;
    expect(records.length, 1);
    expect(records.single['song_id'], 8);
  });

  test('extra 曲目（6 位 id / cids 全 0）不参与', () async {
    seed(
      songs: allSongs(),
      records: [
        record('8', 3, 300),
        record('100018', 3, 300),
        record('200', 3, 300),
      ],
      counts: {'8/3': 100, '100018/3': 999, '200/3': 888},
    );

    final records =
        (await PersonalizedBest50Service().getPC50Data())!['records'] as List;
    expect(records.length, 1);
    expect(records.single['song_id'], 8,
        reason: '宴会场与 maidata 追加曲都不算正曲');
  });

  test('曲库查不到的记录跳过（不炸）', () async {
    seed(
      songs: allSongs(),
      records: [record('8', 3, 300), record('999', 3, 300)],
      counts: {'8/3': 10, '999/3': 99},
    );

    final records =
        (await PersonalizedBest50Service().getPC50Data())!['records'] as List;
    expect(records.length, 1);
    expect(records.single['song_id'], 8);
  });

  test('从未同步过线路2（没有次数缓存）时返回 null', () async {
    seed(
      songs: allSongs(),
      records: [record('8', 3, 300)],
      counts: null,
    );

    expect(await PersonalizedBest50Service().getPC50Data(), isNull,
        reason: '没有游玩次数就没有 PC50，页面据此显示空态提示');
  });

  test('次数缓存有、成绩记录没有时返回 null', () async {
    seed(songs: allSongs(), records: [], counts: {'8/3': 100});

    expect(await PersonalizedBest50Service().getPC50Data(), isNull);
  });

  test('最多 50 条', () async {
    final records = <Map<String, dynamic>>[];
    final counts = <String, int>{};
    for (var i = 0; i < 60; i++) {
      final id = '${2000 + i}';
      records.add(record(id, 3, 300));
      counts['$id/3'] = 1000 - i; // 1000, 999, ...
    }
    seed(songs: allSongs(), records: records, counts: counts);

    final data = await PersonalizedBest50Service().getPC50Data();
    final list = data!['records'] as List;
    expect(list.length, 50);
    expect(data['total'], 50);
    expect(list.first['playCount'], 1000);
    expect(list.last['playCount'], 951, reason: '第 50 条是第 50 大的次数');
  });

  test('只统计对应难度：Master 的次数不会算到 Expert 上', () async {
    seed(
      songs: allSongs(),
      records: [record('8', 2, 300), record('8', 3, 320)],
      counts: {'8/3': 500}, // 只有 Master 有次数
    );

    final records =
        (await PersonalizedBest50Service().getPC50Data())!['records'] as List;
    expect(records.length, 1);
    expect(records.single['level_index'], 3);
    expect(records.single['playCount'], 500);
  });
}
