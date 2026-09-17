// 探针：个性化 Best50 → PC50 出图。
//
// 两个用例：
//   * `pc50_grid`   —— 有游玩次数：卡片上带 `PC xxx` 徽标，按次数降序；
//   * `pc50_empty`  —— 没有游玩次数缓存（没同步过线路2）：空态提示文案。
//
// 数据全部来自本地缓存，正是 PC50 的真实数据链路：
//   * `user_play_data`      —— 用户成绩记录（水鱼/落雪同步写入）
//   * `awmc_play_counts_v1` —— (musicId, level) → playCount（线路2 同步成绩写入）
//   * `cached_songs`        —— 曲库
//
// 运行：flutter test tool/probe_pc50_test.dart --update-goldens
//
// 探针本来就在 test 之外，`@visibleForTesting` / mock 这些本就是测试用法
// ignore_for_file: avoid_print, invalid_use_of_visible_for_testing_member
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_first_flutter_app/constant/CacheKeyConstant.dart';
import 'package:my_first_flutter_app/page/Best50/PersonalizedBest50Page.dart';
import 'package:my_first_flutter_app/service/AWMC/AwmcPlayCountStore.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';

Future<void> loadFonts() async {
  // 走本地族名旁路：测试环境没有网络字体（详见 AppTheme.font）
  AppTheme.debugLocalFontFamily = true;

  Future<void> load(String family, List<String> candidates) async {
    for (final path in candidates) {
      final f = File(path);
      if (!f.existsSync()) continue;
      try {
        final bytes = await f.readAsBytes();
        final loader = FontLoader(family);
        loader.addFont(Future.value(ByteData.view(bytes.buffer)));
        await loader.load();
        print('[RENDER] 字体 $family ← $path');
        return;
      } catch (e) {
        print('[RENDER] 字体加载失败 $path: $e');
      }
    }
  }

  for (final family in [
    'Roboto',
    'NotoSansSC_regular',
    'NotoSansSC_500',
    'NotoSansSC_700',
  ]) {
    await load(family, [
      r'C:\Windows\Fonts\msyh.ttc',
      r'C:\Windows\Fonts\simhei.ttf',
    ]);
  }
  await load('MaterialIcons', [
    r'D:\flutter\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf',
  ]);
}

/// 曲库条目（字段与 `music_data` 一致；`ds` 必须是 double，否则 `as double` 会抛）。
Map<String, dynamic> song(String id, String title, String type) => {
      'id': id,
      'title': title,
      'type': type,
      'ds': <double>[2.0, 7.0, 9.5, 13.6, 14.2],
      'level': <String>['2', '7', '9+', '13+', '14'],
      'cids': <int>[1, 2, 3, 4],
      'charts': <Map<String, dynamic>>[
        for (var i = 0; i < 5; i++)
          {'notes': <int>[263, 14, 19, 6], 'charter': '譜面-$i'},
      ],
      'basic_info': {
        'title': title,
        'artist': 'probe',
        'genre': '舞萌',
        'bpm': 150,
        'release_date': '',
        'from': 'maimai',
        'is_new': false,
      },
    };

Map<String, dynamic> record(String songId, int levelIndex, double ach, int ra,
        String rate, String fc, String fs, int dxScore) =>
    {
      'song_id': int.parse(songId),
      'level_index': levelIndex,
      'achievements': ach,
      'ra': ra,
      'rate': rate,
      'fc': fc,
      'fs': fs,
      'dxScore': dxScore,
    };

final List<Map<String, dynamic>> _songs = [
  song('8', 'True Love Song', 'SD'),
  song('10', 'Garakuta Doll Play', 'SD'),
  song('100', 'Oshama Scramble!', 'SD'),
  song('803', 'Schwarzschild', 'SD'),
  song('833', 'the EmpErroR', 'SD'),
  song('1000', 'Falsum Atlantis.', 'DX'),
  song('1001', 'Grievous Lady', 'DX'),
  song('1002', 'Λzure Vixen', 'DX'),
];

final List<Map<String, dynamic>> _records = [
  record('8', 3, 100.5678, 335, 'sssp', 'app', 'fsd', 3000),
  record('10', 3, 100.1234, 330, 'sssp', 'ap', 'fs', 2900),
  record('100', 3, 99.8765, 320, 'sss', 'fc', 'sync', 2800),
  record('803', 3, 99.5000, 315, 'sss', 'fc', 'sync', 2750),
  record('833', 3, 99.1000, 310, 'ss', 'fcp', 'sync', 2600),
  record('1000', 3, 98.7000, 300, 'ss', '', 'sync', 2500),
  record('1001', 3, 98.2000, 295, 's', '', '', 2400),
  record('1002', 3, 97.8000, 290, 's', '', '', 2300),
];

/// 渲染页面 → 切到 PC50 → 出图。
Future<void> shootPC50(WidgetTester tester, String name) async {
  await tester.runAsync(loadFonts);

  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.darkTheme(),
    home: const PersonalizedBest50Page(),
  ));
  // 页面里的异步加载（prefs / 曲库解析）在 fake async 下不会推进，
  // 必须借助 runAsync 让真实事件循环跑一会儿
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump(const Duration(milliseconds: 60));
  }

  // 打开类型选择 → 选 PC50（列表最后一项，先滚到可见）
  await tester.tap(find.textContaining('选择类型:'));
  await tester.pumpAndSettle();
  await tester.dragUntilVisible(
    find.text('PC50'),
    find.byType(Scrollable).last,
    const Offset(0, -80),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('PC50'));
  await tester.pumpAndSettle();
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump(const Duration(milliseconds: 60));
  }

  debugPrint('[RENDER] $name 屏幕文字：'
      '${tester.allWidgets.whereType<Text>().map((t) => t.data ?? '').where((s) => s.isNotEmpty).join(' | ')}');

  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final image = (element.widget as Image).image;
      try {
        await precacheImage(image, element);
      } catch (_) {}
    }
  });
  await tester.pump();

  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('shots/$name.png'),
  );
  print('[RENDER] 已出图: tool/shots/$name.png');
}

void main() {
  testWidgets('PC50 有次数：卡片带 PC 徽标、按次数降序', (tester) async {
    AwmcPlayCountStore.debugResetForTest();
    SharedPreferences.setMockInitialValues({
      CacheKeyConstant.cachedSongs: json.encode(_songs),
      CacheKeyConstant.userPlayData:
          json.encode({'records': _records, 'additional_rating': 0}),
      CacheKeyConstant.awmcPlayCounts: json.encode({
        'version': 1,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'userId': 1,
        // 只有前 3 首有次数 —— 其余 5 首必须被 PC50 过滤掉
        'counts': {'8/3': 1234, '10/3': 987, '100/3': 512},
      }),
    });

    await shootPC50(tester, 'pc50_grid');

    expect(find.textContaining('PC 1234'), findsOneWidget,
        reason: '次数徽标应出现在卡片上');
    expect(find.text('3'), findsOneWidget, reason: '统计里只有 3 张有次数');
    expect(find.textContaining('暂无PC50数据'), findsNothing);
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('PC50 无次数缓存：空态提示去同步成绩', (tester) async {
    // 上一条用例把次数读进了内存缓存，这里先复位（不动 prefs）
    AwmcPlayCountStore.debugResetForTest();
    SharedPreferences.setMockInitialValues({
      CacheKeyConstant.cachedSongs: json.encode(_songs),
      CacheKeyConstant.userPlayData:
          json.encode({'records': _records, 'additional_rating': 0}),
      // 没有 awmc_play_counts_v1 —— 从没同步过线路2
    });

    await shootPC50(tester, 'pc50_empty');

    expect(find.textContaining('暂无PC50数据'), findsOneWidget);
    expect(find.textContaining('线路2'), findsOneWidget,
        reason: '空态必须说清楚次数从哪来');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
