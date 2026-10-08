/*
 * 随身听曲库页的交互回归 —— 对应用户报的三条：
 *
 *   A. 「已经开始播了，歌曲行右侧还显示 Loading」：根因是 `playAt` 里
 *      `await _player.play()`。just_audio 0.9.46 的 `play()` 返回的 future
 *      要等到**暂停 / 播完**才完成（`await playCompleter.future`），于是
 *      `finally` 里的 `_setLoading(false)` 被拖满整首歌。
 *      这里让 fake 复刻真机的语义（play 挂起、pause 才 resolve），否则
 *      这个 bug 根本复现不出来。
 *   B. 底部固定的「正在播放」条要有可拖动的进度条 + 时间；
 *   D. 拖进度条时只预演、松手才 seek。
 *   C. 顶部栏的定位按钮要把「正在播放」那一行滚进视野。
 *   E. 底部那条上的播放类型切换按钮：点一下**先切一次模式**并弹出选择框，
 *      选择框要整个落在按钮上方（不能压住按钮），且 110ms 内就完全出现
 *      （原来 `PopupMenuButton` 固定 300ms）。
 *   H. 选择框开着时再点切换按钮：模式继续往下切、**选择框不关**，
 *      框里的勾选平滑地移过去；点旁边才收起。
 *   F. 「循环次数」走抽屉页：两个选项 + +/- 步进器（最低 2 次、不用输入框），
 *      选「不设置次数」时步进器不可用。
 *   G. 抽屉页选「不设置次数」= 不设上限（一直循环）。
 *   I. 悬浮球的迷你卡片上也有同一个播放模式按钮，和曲库页共享控制器单例。
 *
 * 「指定次数的单曲循环」的数遍数逻辑在单独的文件里测
 * （`portable_single_loop_test.dart`）。
 *
 * 曲库不从网络拉：直接喂 `PortableSongLibrary` 的落盘缓存（key 带版本号，
 * 见 [PortableSongLibrary.cacheVersion]）—— 否则用例要等落雪 + 水鱼两份曲库，
 * 又慢又看天气。曲目只挑**本地曲绘 assets 存在**的 id，免得 `PortableCover`
 * 回落到网络图（widget 测试里网络图会往 errorBuilder 里灌异常）。
 */
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_first_flutter_app/entity/Portable/PortableSong.dart';
import 'package:my_first_flutter_app/page/Portable/PortablePlayerPage.dart';
import 'package:my_first_flutter_app/page/Portable/PortableNowPlayingPage.dart';
import 'package:my_first_flutter_app/widgets/PortablePlayerBadge.dart';
import 'package:my_first_flutter_app/service/Portable/PortablePlayerController.dart';
import 'package:my_first_flutter_app/service/Portable/PortableSongLibrary.dart';
import 'package:my_first_flutter_app/service/Portable/PortableSongMapService.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:my_first_flutter_app/utils/PortablePlayerScope.dart';

/// 曲库 id：**本地 `assets/cover/{id}.webp` 必须存在**（否则封面会走网络）。
const List<int> _songIds = <int>[
  8,
  9,
  10,
  11,
  15,
  17,
  18,
  20,
  21,
  22,
  23,
  24,
  25,
  27,
  29,
  30,
  31,
  34,
  35,
  38,
  40,
  1466,
  906,
  907,
];

List<PortableSong> _buildSongs() => <PortableSong>[
      for (final id in _songIds)
        PortableSong(
          lxnsId: id,
          divingFishId: '$id',
          audioId: id,
          title: 'テスト曲 $id',
          artist: 'テスト',
          genre: 'POPS＆ANIME',
          bpm: 180,
        ),
    ];

final _fakeJustAudio = _FakeJustAudio();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    JustAudioPlatform.instance = _fakeJustAudio;
    // 顶部栏走 AppTheme.font；不打开这条旁路，google_fonts 会在测试里联网拉
    // NotoSansSC，失败后把用例判失败（见 utils/AppTheme.dart）。
    AppTheme.debugLocalFontFamily = true;
  });

  setUp(() {
    final songs = _buildSongs();
    final result = PortableLibraryResult(
      songs: songs,
      skippedCount: 0,
      divingFishSongCount: songs.length,
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      CacheKeyForTest.library: json.encode(result.toJson()),
    });
    // audio_session：just_audio 会读它，缺插件会抛
    _mockChannel('com.ryanheise.audio_session', (call) async => null);
    // path_provider：通知栏曲绘缓存要用；不 mock 会等到 6s 超时才放弃
    _mockChannel('plugins.flutter.io/path_provider',
        (call) async => Directory.systemTemp.path);
    addTearDown(() {
      _mockChannel('com.ryanheise.audio_session', null);
      _mockChannel('plugins.flutter.io/path_provider', null);
      PortablePlayerScope.isLibraryPageOpen.value = false;
    });
  });

  testWidgets('A. 播放开始后，行内不要一直转 loading', (tester) async {
    await pumpPage(tester);

    final songs = _buildSongs();
    await tester.tap(find.text(songs.first.title));
    await settleArtPreload(tester);
    await pumpFrames(tester);

    final controller = PortablePlayerController();
    expect(controller.currentSong?.lxnsId, songs.first.lxnsId);
    expect(controller.isPlaying, isTrue, reason: '点了行就该开始播');
    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
      reason: '已经在播了，行里不该还挂着 loading（这里是「await play()」的坑）',
    );
    expect(
      find.byIcon(Icons.graphic_eq),
      findsOneWidget,
      reason: '正在播放的那一行显示播放中的标记',
    );

    await quietDown(tester);
  });

  testWidgets('B. 底部正在播放条有可拖动的进度条与时间', (tester) async {
    await pumpPage(tester);
    final songs = _buildSongs();
    unawaited(PortablePlayerController().playQueue(songs, 3));
    await settleArtPreload(tester);
    await pumpFrames(tester);

    // 一开始是 0:00 / 3:00（fake 的时长就是 3 分钟）
    expect(find.textContaining('/ 3:00'), findsOneWidget);
    final slider = find.byType(Slider);
    expect(tester.widget<Slider>(slider).value, closeTo(0.0, 0.02),
        reason: '刚开始播，进度条贴着头（时间在走，允许一点点零头）');

    // 「固定在下方」：进度条要落在列表下面，别再压着列表
    final listRect = tester.getRect(find.byType(ListView));
    final sliderRect = tester.getRect(slider);
    expect(sliderRect.top, greaterThanOrEqualTo(listRect.bottom),
        reason: '「正在播放」条应该在列表下方固定，不是在顶上');

    // 封面按右侧三行（曲名 / 状态 / 播放条）的总高放大：顶边贴第一行、
    // 底边贴第三行。列表里也有 PortableCover，按元素顺序最后那个才是这一条的。
    final coverRect = tester.getRect(find.byType(PortableCover).last);
    final titleRect = tester.getRect(find.text(songs[3].title).last);
    expect(coverRect.height, greaterThan(52), reason: '封面要按三行总高放大（原来只有 36）');
    expect(coverRect.top, closeTo(titleRect.top, 1.5), reason: '封面顶边对齐第一行（曲名）');
    expect(coverRect.bottom,
        closeTo(tester.getRect(find.textContaining('/ 3:00')).bottom, 3),
        reason: '封面底边对齐第三行（进度条那行的时间文本）');

    // 跳到 45s → 进度条要到 25%
    unawaited(PortablePlayerController().seek(const Duration(seconds: 45)));
    // positionStream 是 200ms 的周期流，要推够时间才会发新值
    await pumpFrames(tester, frames: 20);

    expect(tester.widget<Slider>(slider).value, closeTo(45 / 180, 0.01));
    expect(find.textContaining('/ 3:00'), findsOneWidget);

    // 搜索键盘弹起也要把整块内容顶上去（本页 `resizeToAvoidBottomInset: false`，
    // 底边距自己把键盘高度加了进去），否则正在播放条会被键盘盖住
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    addTearDown(tester.view.resetViewInsets);
    await pumpFrames(tester, frames: 4);
    expect(tester.getRect(slider).top, lessThan(sliderRect.top - 100),
        reason: '键盘弹起后，底部的正在播放条要跟着顶上去');

    await quietDown(tester);
  });

  testWidgets('D. 拖进度条：拖动中只预演，松手才 seek', (tester) async {
    await pumpPage(tester);
    final controller = PortablePlayerController();
    unawaited(controller.playQueue(_buildSongs(), 3));
    await settleArtPreload(tester);
    await pumpFrames(tester);
    expect(controller.position, lessThan(const Duration(seconds: 5)));

    // 从轨道靠左的地方按下去，拖到 60% 处
    final sliderRect = tester.getRect(find.byType(Slider));
    final from =
        Offset(sliderRect.left + sliderRect.width * 0.1, sliderRect.center.dy);
    final to =
        Offset(sliderRect.left + sliderRect.width * 0.6, sliderRect.center.dy);
    final gesture = await tester.startGesture(from);
    await tester.pump();
    await gesture.moveTo(to);
    await pumpFrames(tester, frames: 5);

    expect(controller.position, lessThan(const Duration(seconds: 5)),
        reason: '还没松手，别偷偷 seek');
    final shown = tester.widgetList<Text>(find.textContaining('/ 3:00')).single;
    expect(shown.data, isNot(startsWith('0:00')), reason: '拖动时时间要跟着手指预演');

    await gesture.up();
    await pumpFrames(tester, frames: 20);

    // 落点 = 轨道 60% 处 ≈ 108s（左右各 6px 的 padding，给足余量）
    expect(controller.position, greaterThan(const Duration(seconds: 90)));
    expect(controller.position, lessThan(const Duration(seconds: 130)));
    expect(controller.isPlaying, isTrue, reason: 'seek 不该打断播放');
    expect(find.byType(PortableNowPlayingPage), findsNothing,
        reason: '在进度条上拖，不该被外面的「点一下进全屏」抢走');

    await quietDown(tester);
  });

  testWidgets('C. 定位按钮把正在播放那一行滚进视野', (tester) async {
    final songs = _buildSongs();
    // 让第 16 首成为「正在播放」：它在视口外，不定位根本看不到
    const targetIndex = 15;
    await pumpPage(tester);
    unawaited(PortablePlayerController().playQueue(songs, targetIndex));
    await settleArtPreload(tester);
    await pumpFrames(tester);

    final listFinder = find.byType(ListView);
    final scrollable = tester.widget<ListView>(listFinder).controller!;
    expect(scrollable.offset, 0.0, reason: '刚进页面时列表在顶部');

    await tester.tap(find.byTooltip('定位到正在播放'));
    await pumpFrames(tester, frames: 40);

    expect(scrollable.offset, greaterThan(0), reason: '应该滚下去找那一行');
    final listRect = tester.getRect(listFinder);
    final rowRect = tester.getRect(
      find.descendant(
          of: listFinder, matching: find.text(songs[targetIndex].title)),
    );
    expect(rowRect.top, greaterThanOrEqualTo(listRect.top - 1));
    expect(rowRect.bottom, lessThanOrEqualTo(listRect.bottom + 1));

    await quietDown(tester);
  });

  testWidgets('E. 点切换按钮：先切一次模式，并在按钮上方快速弹出 4 项选择框', (tester) async {
    await pumpPage(tester);
    final controller = PortablePlayerController();
    unawaited(controller.playQueue(_buildSongs(), 3));
    await settleArtPreload(tester);
    await pumpFrames(tester);
    expect(controller.playbackMode, PortablePlaybackMode.sequential,
        reason: '默认顺序播放');

    await tester.tap(find.byKey(const Key('portablePlaybackModeButton')));
    // 只推 120ms：淡入是 110ms，这里顺便证明它比 PopupMenuButton 的 300ms 快
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(controller.playbackMode, PortablePlaybackMode.shuffle,
        reason: '点一下按钮就要先切一次模式');
    for (final label in <String>['顺序播放', '随机播放', '单曲循环', '循环次数']) {
      expect(find.text(label), findsOneWidget, reason: '选择框里要有「$label」');
    }
    final fade = tester.widget<FadeTransition>(
      find.byKey(const Key('playbackModeMenuFade')),
    );
    expect(fade.opacity.value, 1.0, reason: '120ms 内就要完全出现，别像原来那样拖 300ms');

    // 选择框整体在按钮上方（需求：不能盖住按钮），而且不出屏幕
    final menuRect = tester.getRect(find.byKey(const Key('playbackModeMenu')));
    final buttonRect = tester.getRect(
      find.byKey(const Key('portablePlaybackModeButton')),
    );
    expect(menuRect.bottom, lessThanOrEqualTo(buttonRect.top),
        reason: '选择框要整个落在按钮上方，不能压住按钮');
    expect(menuRect.left, greaterThanOrEqualTo(0.0));
    expect(
        menuRect.right,
        lessThanOrEqualTo(
            tester.view.physicalSize.width / tester.view.devicePixelRatio));

    // 选一个模式：立刻生效并收起
    await tester.tap(find.text('顺序播放'));
    await pumpFrames(tester, frames: 10);
    expect(controller.playbackMode, PortablePlaybackMode.sequential);
    expect(find.byKey(const Key('playbackModeMenu')), findsNothing);

    await quietDown(tester);
  });

  testWidgets('H. 选择框开着时再点切换按钮：模式继续切、选择框不关、勾选平滑地移过去', (tester) async {
    await pumpPage(tester);
    final controller = PortablePlayerController();
    unawaited(controller.playQueue(_buildSongs(), 3));
    await settleArtPreload(tester);
    await pumpFrames(tester);

    final button = find.byKey(const Key('portablePlaybackModeButton'));
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(controller.playbackMode, PortablePlaybackMode.shuffle);
    expect(find.byKey(const Key('playbackModeMenu')), findsOneWidget);

    double targetCheck(PortablePlaybackMode mode) => tester
        .widget<AnimatedOpacity>(
          find.byKey(Key('playbackModeCheck_${mode.name}')),
        )
        .opacity;
    // 勾选当前渲染到哪了（AnimatedOpacity 内部就是一个 FadeTransition）
    double renderedCheck(PortablePlaybackMode mode) => tester
        .widget<FadeTransition>(
          find
              .descendant(
                of: find.byKey(Key('playbackModeCheck_${mode.name}')),
                matching: find.byType(FadeTransition),
              )
              .first,
        )
        .opacity
        .value;

    expect(targetCheck(PortablePlaybackMode.shuffle), 1.0);
    expect(renderedCheck(PortablePlaybackMode.shuffle), 1.0);
    expect(targetCheck(PortablePlaybackMode.single), 0.0,
        reason: '没选中时勾选只是透明度 0 占位');

    // 再点一次按钮：遮罩给按钮留了洞，这一下真的落到 IconButton 上
    await tester.tap(button);
    // 推几帧：160ms 的切换动画才走了一小截 —— 正好能看出「还在过渡」
    await pumpFrames(tester, frames: 3);

    expect(controller.playbackMode, PortablePlaybackMode.single,
        reason: '再点按钮要接着切下一个模式');
    expect(find.byKey(const Key('playbackModeMenu')), findsOneWidget,
        reason: '点按钮切模式时选择框不能关');
    expect(targetCheck(PortablePlaybackMode.single), 1.0,
        reason: '勾选的目标已经换到「单曲循环」');
    expect(renderedCheck(PortablePlaybackMode.single), lessThan(1.0),
        reason: '刚切完还在淡入 —— 说明是平滑动画，不是硬切');
    expect(renderedCheck(PortablePlaybackMode.shuffle), greaterThan(0.0),
        reason: '旧的勾选还在淡出，不是瞬间消失');

    // 动画走完：只剩「单曲循环」那一行有勾
    await pumpFrames(tester, frames: 15);
    expect(renderedCheck(PortablePlaybackMode.single), 1.0);
    expect(renderedCheck(PortablePlaybackMode.shuffle), 0.0);
    expect(find.byKey(const Key('playbackModeMenu')), findsOneWidget);

    // 点选择框旁边（遮罩上）→ 只收起，不改模式
    await tester.tapAt(const Offset(20, 200));
    await pumpFrames(tester, frames: 15);
    expect(find.byKey(const Key('playbackModeMenu')), findsNothing,
        reason: '点旁边要能收起选择框');
    expect(controller.playbackMode, PortablePlaybackMode.single,
        reason: '点旁边只是收起，不该改模式');

    await quietDown(tester);
  });

  testWidgets('F. 循环次数抽屉页：不设置次数时 +/- 不可用，最低 2 次', (tester) async {
    await pumpPage(tester);
    final controller = PortablePlayerController();
    unawaited(controller.playQueue(_buildSongs(), 3));
    await settleArtPreload(tester);
    await pumpFrames(tester);

    await tester.tap(find.byKey(const Key('portablePlaybackModeButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(find.text('循环次数'));
    await pumpFrames(tester, frames: 30); // 抽屉页滑上来

    expect(find.text('不设置次数'), findsOneWidget);
    expect(find.text('设置次数'), findsOneWidget);
    expect(find.text('2 次'), findsOneWidget, reason: '步进器默认停在最低值 2');

    IconButton stepper(String key) =>
        tester.widget<IconButton>(find.byKey(Key(key)));
    // 「不可用」是靠 IgnorePointer 整块吃掉手势（同时压暗），不是把两个按钮都置灰
    IgnorePointer stepperGate() => tester.widget<IgnorePointer>(
          find.byKey(const Key('loopCountStepper')),
        );
    expect(stepperGate().ignoring, isTrue, reason: '选中「不设置次数」时，设置次数组件不可用');
    expect(stepper('loopCountMinus').onPressed, isNull, reason: '最低 2 次');

    // 选「设置次数」→ 步进器可用，但仍停在最低值
    await tester.tap(find.text('设置次数'));
    await pumpFrames(tester, frames: 4);
    expect(stepperGate().ignoring, isFalse, reason: '选了「设置次数」就要能用');
    expect(stepper('loopCountMinus').onPressed, isNull, reason: '2 次已经是最低');
    expect(stepper('loopCountPlus').onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('loopCountPlus')));
    await pumpFrames(tester, frames: 4);
    expect(find.text('3 次'), findsOneWidget);
    await tester.tap(find.byKey(const Key('loopCountMinus')));
    await pumpFrames(tester, frames: 4);
    expect(find.text('2 次'), findsOneWidget);
    expect(stepper('loopCountMinus').onPressed, isNull,
        reason: '最低就是 2 次，不能再往下减');

    await tester.tap(find.text('确定'));
    await pumpFrames(tester, frames: 30);
    expect(controller.playbackMode, PortablePlaybackMode.single,
        reason: '设置了次数就应该落在单曲循环上');
    expect(controller.singleLoopCount, 2);

    await quietDown(tester);
  });

  testWidgets('G. 循环次数抽屉页：选「不设置次数」= 不设上限', (tester) async {
    await pumpPage(tester);
    final controller = PortablePlayerController();
    unawaited(controller.playQueue(_buildSongs(), 3));
    await settleArtPreload(tester);
    await pumpFrames(tester);

    await tester.tap(find.byKey(const Key('portablePlaybackModeButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(find.text('循环次数'));
    await pumpFrames(tester, frames: 30);

    // 默认就停在「不设置次数」，直接确定
    await tester.tap(find.text('确定'));
    await pumpFrames(tester, frames: 30);
    expect(controller.playbackMode, PortablePlaybackMode.single);
    expect(controller.singleLoopCount, isNull, reason: '「不设置次数」= 不设上限（一直循环）');

    await quietDown(tester);
  });

  testWidgets('J. 单曲页滑动切歌、随机隐藏相邻曲绘，播放按钮圆方过渡', (tester) async {
    await pumpPage(tester);
    final controller = PortablePlayerController();
    final songs = _buildSongs();
    unawaited(controller.playQueue(songs, 1));
    await settleArtPreload(tester);
    await pumpFrames(tester);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme(), home: const PortableNowPlayingPage()));
    await pumpFrames(tester);
    expect(find.byType(PortableCover), findsNWidgets(3));
    final playButton = find.byWidgetPredicate((widget) =>
        widget is AnimatedContainer && widget.constraints?.maxWidth == 68);
    expect(
        (tester.widget<AnimatedContainer>(playButton).decoration
                as BoxDecoration)
            .borderRadius,
        BorderRadius.circular(12));
    unawaited(controller.togglePlayPause());
    await pumpFrames(tester);
    expect(
        (tester.widget<AnimatedContainer>(playButton).decoration
                as BoxDecoration)
            .borderRadius,
        BorderRadius.circular(34));
    // 暂停时切歌也必须返回，不能等待 play Future 到播放结束。
    expect(controller.hasNext, true);
    expect(controller.isLoading, false);
    await tester.timedDrag(
        find.byWidgetPredicate((widget) =>
            widget is GestureDetector && widget.onHorizontalDragEnd != null),
        const Offset(-160, 0),
        const Duration(milliseconds: 300));
    // 暂停后的平台重新激活包含真实异步工作，先放行再推进测试帧。
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await pumpFrames(tester, frames: 25);
    expect(controller.currentSong?.lxnsId, songs[2].lxnsId);
    expect(controller.isPlaying, true);
    unawaited(controller.setPlaybackMode(PortablePlaybackMode.shuffle));
    await pumpFrames(tester, frames: 20);
    expect(find.byType(PortableCover), findsOneWidget);
    expect(tester.takeException(), isNull);
    await quietDown(tester);
  });

  testWidgets('I. 悬浮球迷你卡片上也能切模式，和曲库页共享同一份状态', (tester) async {
    final controller = PortablePlayerController();
    unawaited(controller.playQueue(_buildSongs(), 3));
    await settleArtPreload(tester);
    await pumpFrames(tester);

    // 迷你卡片就是「其他页面点悬浮球」弹出的那一页
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme(),
      home: const Scaffold(body: PortableMiniCard()),
    ));
    await pumpFrames(tester, frames: 5);

    final cardButton =
        find.byKey(const Key('portableMiniCardPlaybackModeButton'));
    expect(cardButton, findsOneWidget, reason: '迷你卡片上要有播放模式按钮');

    await tester.tap(cardButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(controller.playbackMode, PortablePlaybackMode.shuffle,
        reason: '在迷你卡片上点一下也要切模式');
    for (final label in <String>['顺序播放', '随机播放', '单曲循环', '循环次数']) {
      expect(find.text(label), findsOneWidget, reason: '迷你卡片上也弹同一个选择框');
    }
    // 点旁边收起
    await tester.tapAt(const Offset(20, 200));
    await pumpFrames(tester, frames: 15);
    expect(find.byKey(const Key('playbackModeMenu')), findsNothing);

    // 进曲库页：它读的是同一个控制器单例，接着往下切就该到「单曲循环」
    await pumpPage(tester);
    await tester.tap(find.byKey(const Key('portablePlaybackModeButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(controller.playbackMode, PortablePlaybackMode.single,
        reason: '曲库页要接着迷你卡片切过的模式继续（不是从头开始）');
    expect(
      tester
          .widget<AnimatedOpacity>(
              find.byKey(const Key('playbackModeCheck_single')))
          .opacity,
      1.0,
      reason: '曲库页给同一个单例画勾选',
    );

    await quietDown(tester);
  });
}

/// `PortableSongLibrary` 的落盘缓存 key（那边是私有的，这里按同一规则拼）。
class CacheKeyForTest {
  static final String library = 'portable_song_library_v'
      '${PortableSongLibrary.cacheVersion}';
}

void _mockChannel(String name, Future<Object?> Function(MethodCall)? handler) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(MethodChannel(name), handler);
}

/// 手推几帧。随身听页在播放中一直有 positionStream 的周期事件，
/// 用 `pumpAndSettle` 会等不完。
Future<void> pumpFrames(WidgetTester tester, {int frames = 20}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

/// 推过 `preloadNotificationArt` 的 6s 超时。
///
/// 测试环境里 HTTP 全返回 400，曲绘一定下载失败，`getSingleFile(...).timeout(6s)`
/// 要**满 6 秒**（假时钟，所以推一下就好）才放行，之后才会 setAudioSource → 起播。
/// 不等它的话，点完行只是「pending」，`currentSong` 还是 null。
Future<void> settleArtPreload(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 7));
}

/// 收尾（每条用例末尾必调），两步都是为了让 `!timersPending` 断言过：
///
/// 1. 推完 `_pushNotification` 留下的 6s 曲绘超时定时器；两轮是因为第一轮
///    7s 里可能又排出一个新的 6s。
/// 2. **dispose 播放器**：`positionStream` 一旦被订阅（页面的进度条订阅了），
///    just_audio 内部就常驻一个 200ms 的 `Timer.periodic`，暂停/断订阅都收不掉
///    它，只有 `AudioPlayer.dispose()` 才行。dispose 后再推 300ms，让它
///    自己走完最后一下就取消。单例要顺手复位，否则下一条用例拿到的是
///    **已 dispose** 的 ChangeNotifier。
Future<void> quietDown(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 7));
  await tester.pump(const Duration(seconds: 7));
  PortablePlayerController().dispose();
  PortablePlayerController.debugReset();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> pumpPage(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme(),
    home: const PortablePlayerPage(),
  ));
  await pumpFrames(tester, frames: 12);
}

// ===========================================================================
// just_audio 的平台 fake
// ===========================================================================

class _FakeJustAudio extends JustAudioPlatform {
  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async =>
      _FakeAudioPlayer(request.id);

  @override
  Future<DisposePlayerResponse> disposePlayer(
          DisposePlayerRequest request) async =>
      DisposePlayerResponse();

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(
          DisposeAllPlayersRequest request) async =>
      DisposeAllPlayersResponse();
}

/// 只实现随身听用到的那几个调用。
///
/// 关键在 [play]：**它一直挂着，直到收到 pause** —— 这正是真机（ExoPlayer
/// 实现）的语义，just_audio 的 `play()` future 就是等这一次 resolve。
class _FakeAudioPlayer extends AudioPlayerPlatform {
  _FakeAudioPlayer(super.id);

  static const Duration _duration = Duration(minutes: 3);

  final StreamController<PlaybackEventMessage> _events =
      StreamController<PlaybackEventMessage>.broadcast();

  int _index = 0;
  Duration _position = Duration.zero;
  Completer<void>? _playGate;

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => _events.stream;

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    _index = request.initialIndex ?? 0;
    _position = Duration.zero;
    _emit(ProcessingStateMessage.ready);
    return LoadResponse(duration: _duration);
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async {
    _emit(ProcessingStateMessage.ready);
    final gate = Completer<void>();
    _playGate = gate;
    await gate.future;
    return PlayResponse();
  }

  @override
  Future<PauseResponse> pause(PauseRequest request) async {
    _playGate?.complete();
    _playGate = null;
    return PauseResponse();
  }

  @override
  Future<SeekResponse> seek(SeekRequest request) async {
    _index = request.index ?? _index;
    _position = request.position ?? _position;
    _emit(ProcessingStateMessage.ready);
    return SeekResponse();
  }

  /// 模拟「平台把本曲从头又接了一遍」（`LoopMode.one` 的真实表现）：
  /// 先报到接近结尾，再跳回 0。just_audio 会据此发出 `autoAdvance` 的
  /// positionDiscontinuity —— 控制器就是靠它数「指定次数」的遍数。
  ///
  /// ⚠️ 两次 `_emit` 之间不能夹别的 playback event，否则 `pairwise()` 里
  /// 「前一条接近结尾」的条件就不成立了。
  ///
  /// 本文件里暂时用不到（次数那套逻辑在 `portable_single_loop_test.dart` 里测，
  /// 那边因为假时钟跑不完平台激活，走的是控制器的测试直通口子），留着是因为
  /// 这个 fake 是「真机语义」的参考实现。
  // ignore: unused_element
  void simulateLoopBack() {
    _position = _duration - const Duration(milliseconds: 500);
    _emit(ProcessingStateMessage.ready);
    _position = Duration.zero;
    _emit(ProcessingStateMessage.ready);
  }

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async =>
      SetVolumeResponse();

  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async =>
      SetSpeedResponse();

  @override
  Future<SetPitchResponse> setPitch(SetPitchRequest request) async =>
      SetPitchResponse();

  @override
  Future<SetSkipSilenceResponse> setSkipSilence(
          SetSkipSilenceRequest request) async =>
      SetSkipSilenceResponse();

  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async =>
      SetLoopModeResponse();

  @override
  Future<SetShuffleModeResponse> setShuffleMode(
          SetShuffleModeRequest request) async =>
      SetShuffleModeResponse();

  @override
  Future<SetShuffleOrderResponse> setShuffleOrder(
          SetShuffleOrderRequest request) async =>
      SetShuffleOrderResponse();

  void _emit(ProcessingStateMessage processingState) {
    if (_events.isClosed) return;
    _events.add(PlaybackEventMessage(
      processingState: processingState,
      updateTime: DateTime.now(),
      updatePosition: _position,
      bufferedPosition: _duration,
      duration:
          processingState == ProcessingStateMessage.idle ? null : _duration,
      icyMetadata: null,
      currentIndex: _index,
      androidAudioSessionId: null,
    ));
  }
}
