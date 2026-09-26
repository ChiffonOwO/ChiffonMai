// 回归：「弹窗关闭时 controller 被提前释放」导致的红屏。
//
// 症状（用户实测，最早出现在成绩 / Rating 历史的弹窗）：
//   点「取消」关掉带输入框的弹窗 →
//   A TextEditingController was used after being disposed.
//   '_dependents.isEmpty': is not true.
//   Tried to build dirty widget in the wrong build scope.
//
// 原因：`showDialog` 返回的 future 是 **`Route.popped`** —— pop 那一刻就完成，
// 而弹窗此时还在**退场动画**里（真机上键盘收起会让它重建，`TextField` 会再读一次
// controller）。在 future 完成时释放 controller 必炸；只推迟一帧
// （`addPostFrameCallback`）同样还在动画里。异常又发生在卸载/重建途中，元素树被
// 撕成半死状态，于是接着刷出后面那两条断言，用户看到的就是红屏。
//
// 本文件钉的是「成绩 / Rating 历史弹窗之外」的两处：
//   * `SearchPickerDialog`（个性化成绩查询的谱师 / 曲师选择，原来是 `.whenComplete(dispose)`）；
//   * 收藏夹的「新建 / 重命名」弹窗（原来是 `addPostFrameCallback` 里 dispose）。
// 它们与 `lib/widgets/SyncScoreDialogs.dart`（等 `Route.completed`）是同一个坑。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_first_flutter_app/constant/CacheKeyConstant.dart';
import 'package:my_first_flutter_app/page/FavoriteFolderPage.dart';
import 'package:my_first_flutter_app/page/PersonalizedScorePage.dart';
import 'package:my_first_flutter_app/service/FavoriteFolderService.dart';
import 'package:my_first_flutter_app/utils/CurrentDataSourceNotifier.dart';
import 'package:my_first_flutter_app/widgets/SearchPickerDialog.dart';

/// pop 的瞬间 + 退场动画全程（含真机键盘收起触发的重建）都不能有异常。
///
/// 刻意**不用 `pumpAndSettle`**：这些页面加载 / 筛选时会转圈，无限动画会让
/// settle 直接超时；固定抽帧反而检查得更密。
Future<void> expectCleanDialogExit(WidgetTester tester) async {
  await tester.pump();
  expect(tester.takeException(), isNull,
      reason: 'pop 的瞬间不该读已释放的 controller');

  tester.view.viewInsets = const FakeViewPadding(bottom: 0);
  addTearDown(tester.view.reset);
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull,
        reason: '退场动画期间弹窗重建，同样不该读已释放的 controller');
  }
}

/// 抽几帧（弹窗开 / 关的动画约 150ms，10 帧足够）。
Future<void> pumpFrames(WidgetTester tester, {int frames = 10}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

// ===========================================================================
// SearchPickerDialog（直接驱动弹窗本身）
// ===========================================================================

const _pickerEntries = <MapEntry<String, int>>[
  MapEntry('はるな。', 214),
  MapEntry('小鳥遊さん', 96),
  MapEntry('Jack', 7),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SearchPickerDialog：关窗全程不报错', () {
    Future<BuildContext> pumpHost(WidgetTester tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (c) {
          ctx = c;
          return const Scaffold(body: SizedBox.expand());
        }),
      ));
      return ctx;
    }

    testWidgets('取消关闭：退场全程不报错，返回 null', (tester) async {
      final ctx = await pumpHost(tester);

      final future = showSearchPickerDialog(
        ctx,
        title: '选择谱师',
        hintText: '搜索谱师',
        emptyText: '没有匹配的谱师',
        entries: _pickerEntries,
        countSuffix: '谱面',
      );
      await pumpFrames(tester);
      expect(find.text('はるな。 (214谱面)'), findsOneWidget);

      await tester.tap(find.text('取消'));
      await expectCleanDialogExit(tester);

      expect(await future, isNull);
      expect(find.text('选择谱师'), findsNothing, reason: '弹窗要真的关掉');
    });

    testWidgets('搜索过滤仍然有效，选中后返回值是条目名', (tester) async {
      final ctx = await pumpHost(tester);

      final future = showSearchPickerDialog(
        ctx,
        title: '选择曲师',
        hintText: '搜索曲师',
        emptyText: '没有匹配的曲师',
        entries: _pickerEntries,
        countSuffix: '首',
        selected: 'Jack',
      );
      await pumpFrames(tester);

      await tester.enterText(find.byType(TextField), 'jack');
      await tester.pump();
      expect(find.text('Jack (7首)'), findsOneWidget);
      expect(find.text('はるな。 (214谱面)'), findsNothing);

      // 搜不到时要给出空态文案，而不是一片空白
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(find.text('没有匹配的曲师'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'jack');
      await tester.pump();
      await tester.tap(find.text('Jack (7首)'));
      await expectCleanDialogExit(tester);

      expect(await future, 'Jack');
    });
  });

  // =========================================================================
  // 收藏夹「新建 / 重命名」弹窗（走页面真实入口）
  // =========================================================================

  group('收藏夹弹窗：关窗全程不报错', () {
    Future<void> pumpFolderPage(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1260, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: FavoriteFolderPage()));
      await pumpFrames(tester, frames: 4);
    }

    testWidgets('「新建收藏夹」：取消关闭全程不报错', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpFolderPage(tester);

      await tester.tap(find.text('新建收藏夹'));
      await pumpFrames(tester);
      expect(find.text('请输入收藏夹名称'), findsOneWidget);

      await tester.tap(find.text('取消'));
      await expectCleanDialogExit(tester);
      expect(find.text('请输入收藏夹名称'), findsNothing);
    });

    testWidgets('「重命名」：输入框带出原名，取消关闭全程不报错', (tester) async {
      SharedPreferences.setMockInitialValues({});
      // 直接落一个新收藏夹，不依赖上一个用例留下的单例状态
      await FavoriteFolderService().createFolder('待重命名收藏夹');
      await pumpFolderPage(tester);
      expect(find.text('待重命名收藏夹'), findsOneWidget);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await pumpFrames(tester);
      await tester.tap(find.text('重命名'));
      await pumpFrames(tester);

      expect(find.widgetWithText(TextField, '待重命名收藏夹'), findsOneWidget,
          reason: '重命名要把原名带进输入框');

      await tester.tap(find.text('取消'));
      await expectCleanDialogExit(tester);
      expect(find.widgetWithText(TextField, '待重命名收藏夹'), findsNothing);
    });
  });

  // =========================================================================
  // 个性化成绩查询：曲师选择（走页面真实入口，钉住「选中后回填」的接线）
  // =========================================================================

  group('个性化成绩查询的曲师选择弹窗', () {
    Map<String, dynamic> song(String id, String title, String artist) => {
          'id': id,
          'title': title,
          'type': 'DX',
          'ds': <double>[2.0, 7.0, 9.5, 13.6, 14.2],
          'level': <String>['2', '7', '9+', '13+', '14'],
          'cids': <int>[1, 2, 3, 4],
          'charts': <Map<String, dynamic>>[
            for (var i = 0; i < 5; i++)
              {'notes': <int>[263, 14, 19, 6], 'charter': '譜面-$i'},
          ],
          'basic_info': {
            'title': title,
            'artist': artist,
            'genre': '舞萌',
            'bpm': 150,
            'release_date': '',
            'from': 'maimai',
            'is_new': false,
          },
        };

    Future<void> pumpPage(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1260, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      CurrentDataSourceNotifier.instance.value = RefreshDataSource.shuiyu;
      SharedPreferences.setMockInitialValues({
        CacheKeyConstant.cachedSongs: json.encode([
          song('8', 'A', 'アーティストA'),
          song('10', 'B', 'アーティストB'),
        ]),
        CacheKeyConstant.userPlayData: json.encode({
          'records': [
            {
              'song_id': 8,
              'level_index': 3,
              'achievements': 100.0,
              'ra': 335,
              'rate': 'sssp',
              'fc': 'app',
              'fs': 'sync',
              'dxScore': 3000,
            },
          ],
          'additional_rating': 0,
        }),
      });

      await tester.pumpWidget(const MaterialApp(home: PersonalizedScorePage()));
      // 曲库缓存 / maidata 解码是**真实文件 I/O**，fake async 里永远不会完成
      // （页面会一直转圈），所以要用 runAsync 放行几轮真实事件循环。
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 200)));
      }
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing,
          reason: '页面要先真的加载出来，否则后面找不到按钮');
    }

    /// 切到「曲师」模式：种类按钮「等级」→ 弹窗里选「曲师」。
    Future<void> switchToArtistMode(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(ElevatedButton, '等级'));
      await pumpFrames(tester);
      await tester.tap(find.text('曲师'));
      await pumpFrames(tester);
    }

    testWidgets('取消关闭：退场全程不报错，且不改动当前曲师', (tester) async {
      await pumpPage(tester);
      await switchToArtistMode(tester);

      // 初始化时曲师会自动落到第一个，按钮上显示的就是它
      await tester.tap(find.widgetWithText(ElevatedButton, 'アーティストA'));
      await pumpFrames(tester);
      expect(find.text('アーティストA (1首)'), findsOneWidget);

      await tester.tap(find.text('取消'));
      await expectCleanDialogExit(tester);

      expect(find.widgetWithText(ElevatedButton, 'アーティストA'), findsOneWidget,
          reason: '取消不该改掉当前选择');
    });

    testWidgets('选中曲师后按钮要显示它（弹窗返回值真的回填了）', (tester) async {
      await pumpPage(tester);
      await switchToArtistMode(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'アーティストA'));
      await pumpFrames(tester);
      await tester.tap(find.text('アーティストB (1首)'));
      await expectCleanDialogExit(tester);

      expect(find.widgetWithText(ElevatedButton, 'アーティストB'), findsOneWidget,
          reason: '选中项要回填到「选择曲师」按钮上');
    });
  });
}
