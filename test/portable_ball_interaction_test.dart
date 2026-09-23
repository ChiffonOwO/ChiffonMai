/*
 * 随身听悬浮球的交互回归测试。
 *
 * 这里复刻 `main.dart` 里球的挂法（`MaterialApp.builder` → Stack → 球），
 * 因为**挂法本身就是坑**：builder 的 context 处在 Navigator **之上**，
 * 用它去 `showModalBottomSheet` / `Navigator.of` 会抛
 * 「Navigator operation requested with a context that does not include a Navigator」，
 * 而且这条异常在 release 下被手势回调吞掉 —— 真机表现就是「点球没反应」。
 *
 * 覆盖：
 *   A. 点球 → 迷你卡片弹出；
 *   B. 卡片「播放列表」→ 收起卡片并打开随身听曲库页；
 *   C. 拖动球 → 新位置写进 SharedPreferences；
 *   D. 卡片点标题 → 全屏播放页。
 */
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_first_flutter_app/constant/CacheKeyConstant.dart';
import 'package:my_first_flutter_app/entity/Portable/PortableSong.dart';
import 'package:my_first_flutter_app/page/AppShell.dart';
import 'package:my_first_flutter_app/page/Portable/PortableNowPlayingPage.dart';
import 'package:my_first_flutter_app/page/Portable/PortablePlayerPage.dart';
import 'package:my_first_flutter_app/service/Portable/PortablePlayerController.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:my_first_flutter_app/utils/PortablePlayerScope.dart';
import 'package:my_first_flutter_app/widgets/PortablePlayerBadge.dart';

/// 曲绘 assets 存在的一首（免得测试里走网络兜底）
const _song = PortableSong(
  lxnsId: 1466,
  divingFishId: '1466',
  audioId: 1466,
  title: 'テスト曲',
  artist: 'テスト',
  genre: 'POPS＆ANIME',
  bpm: 180,
);

/// 单实例：`PortablePlayerController` 是全局单例，跨用例复用同一份播放器
final _fakeJustAudio = _FakeJustAudio();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    JustAudioPlatform.instance = _fakeJustAudio;
    // 曲库页顶部栏走 AppTheme.font；不打开这条旁路的话，google_fonts 会在测试里
    // 联网拉 NotoSansSC，失败后把用例判失败（见 utils/AppTheme.dart）
    AppTheme.debugLocalFontFamily = true;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // audio_session：just_audio 在 Android 路径上会读它，缺插件会抛
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.audio_session'),
      (call) async => null,
    );
    // path_provider：通知栏曲绘缓存要用；不 mock 会等到 6s 超时才放弃
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => Directory.systemTemp.path,
    );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('com.ryanheise.audio_session'), null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'), null);
    });
  });

  /// 按 `main.dart` 的方式挂球：`MaterialApp.builder` 里、Navigator 之上。
  Future<GlobalKey<NavigatorState>> pumpBall(
    WidgetTester tester, {
    Future<void> Function()? onOpenLibrary,
  }) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Center(child: Text('首页'))),
        builder: (context, child) => Stack(
          children: [
            if (child != null) child,
            Positioned.fill(
              child: PortablePlayerBall(
                navigatorKey: navigatorKey,
                onOpenLibrary: onOpenLibrary,
              ),
            ),
          ],
        ),
      ),
    );
    await pumpFrames(tester, frames: 10);
    return navigatorKey;
  }

  /// 起播一首。
  ///
  /// ⚠️ 必须走 `tester.runAsync`：`testWidgets` 默认是**假时钟**，
  /// 光 `await` 不会让 just_audio / cache manager 的真实异步跑完（会直接卡死）。
  Future<void> startPlayback(WidgetTester tester) async {
    await tester.runAsync(() async {
      await PortablePlayerController()
          .playQueue(const <PortableSong>[_song], 0)
          .timeout(const Duration(seconds: 20));
    });
  }

  /// 球的中心点（球默认贴右边、约 62% 高度处）。
  Offset ballCenter(WidgetTester tester) {
    final cover = find.byType(PortableCover).first;
    return tester.getCenter(cover);
  }

  testWidgets('A. 点球弹出迷你卡片', (tester) async {
    await pumpBall(tester);
    await startPlayback(tester);
    await pumpFrames(tester);

    expect(PortablePlayerController().currentSong, isNotNull,
        reason: '有当前曲目时球才显示');
    expect(find.byType(PortableCover), findsWidgets, reason: '球应该画出来了');

    await tester.tapAt(ballCenter(tester));
    await pumpFrames(tester);

    expect(find.byType(PortableMiniCard), findsOneWidget,
        reason: '点球应该弹出迷你卡片（这里曾是「点球没反应」）');
    expect(find.textContaining('随身听 ·'), findsOneWidget);

    // 卡片上的播放/暂停要真的落到控制器上
    expect(PortablePlayerController().isPlaying, isTrue);
    await tester.tap(find.byIcon(Icons.pause_circle));
    await pumpFrames(tester);
    expect(PortablePlayerController().isPlaying, isFalse);
  });

  testWidgets('B. 迷你卡片的「播放列表」进曲库页', (tester) async {
    var popped = 0;
    // 复刻 main.dart 的做法：用根 Navigator 的 overlay context 打开曲库页
    late GlobalKey<NavigatorState> navigatorKey;
    navigatorKey = await pumpBall(
      tester,
      onOpenLibrary: () {
        popped++;
        return AppShell.openPortablePlayerPage(
          navigatorKey.currentState!.overlay!.context,
        );
      },
    );
    addTearDown(() => PortablePlayerScope.isLibraryPageOpen.value = false);
    await startPlayback(tester);
    await pumpFrames(tester);

    await tester.tapAt(ballCenter(tester));
    await pumpFrames(tester);
    await tester.tap(find.text('播放列表'));
    await tester.pump();
    await pumpFrames(tester);

    expect(popped, 1);
    expect(find.byType(PortableMiniCard), findsNothing, reason: '卡片要收起来');
    expect(find.byType(PortablePlayerPage), findsOneWidget,
        reason: '应该 push 出随身听曲库页');
  });

  testWidgets('C. 拖球后位置落盘', (tester) async {
    await pumpBall(tester);
    await startPlayback(tester);
    await pumpFrames(tester);

    final start = ballCenter(tester);
    await tester.dragFrom(start, const Offset(-40, -120));
    await pumpFrames(tester);

    final moved = ballCenter(tester);
    expect(moved.dx, lessThan(start.dx));
    expect(moved.dy, lessThan(start.dy));
    expect(find.byType(PortableMiniCard), findsNothing,
        reason: '拖动不该顺手弹出卡片');

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(CacheKeyConstant.portableBallOffset);
    expect(saved, isNotNull, reason: '松开手要把位置存下来');
    final parts = saved!.split(',');
    // 落盘的是球**左上角**的偏移：曲绘中心点 = 偏移 + 半径
    const half = PortablePlayerBall.ballSize / 2;
    expect(double.parse(parts[0]), closeTo(moved.dx - half, 1.0));
    expect(double.parse(parts[1]), closeTo(moved.dy - half, 1.0));
  });

  testWidgets('D. 迷你卡片点标题/曲绘进全屏播放页', (tester) async {
    await pumpBall(tester);
    await startPlayback(tester);
    await pumpFrames(tester);

    await tester.tapAt(ballCenter(tester));
    await pumpFrames(tester);
    expect(find.byType(PortableMiniCard), findsOneWidget);

    await tester.tap(find.text(_song.title));
    await tester.pump();
    await pumpFrames(tester);

    expect(find.byType(PortableMiniCard), findsNothing, reason: '卡片要收起来');
    expect(find.byType(PortableNowPlayingPage), findsOneWidget);
  });
}

/// 手动推几帧代替 `pumpAndSettle`。
///
/// 球在「播放中」会靠 `AnimationController.repeat` 一直脉冲 —— 永远有待处理帧，
/// `pumpAndSettle` 在这里就是死等（默认 10 分钟才超时）。
Future<void> pumpFrames(WidgetTester tester, {int frames = 30}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

// ===========================================================================
// just_audio 的平台 fake
// ===========================================================================

class _FakeJustAudio extends JustAudioPlatform {
  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async =>
      _FakeAudioPlayer(request.id);

  @override
  Future<DisposePlayerResponse> disposePlayer(DisposePlayerRequest request) async =>
      DisposePlayerResponse();

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(
          DisposeAllPlayersRequest request) async =>
      DisposeAllPlayersResponse();
}

/// 只实现随身听用到的那几个调用：加载即「就绪、第 0 首」。
class _FakeAudioPlayer extends AudioPlayerPlatform {
  _FakeAudioPlayer(super.id);

  final StreamController<PlaybackEventMessage> _events =
      StreamController<PlaybackEventMessage>.broadcast();

  static const Duration _duration = Duration(minutes: 3);

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => _events.stream;

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    _emit(processingState: ProcessingStateMessage.ready, currentIndex: 0);
    return LoadResponse(duration: _duration);
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async {
    _emit(processingState: ProcessingStateMessage.ready, currentIndex: 0);
    return PlayResponse();
  }

  @override
  Future<PauseResponse> pause(PauseRequest request) async => PauseResponse();

  @override
  Future<SeekResponse> seek(SeekRequest request) async {
    _emit(
      processingState: ProcessingStateMessage.ready,
      currentIndex: request.index ?? 0,
      position: request.position ?? Duration.zero,
    );
    return SeekResponse();
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

  void _emit({
    required ProcessingStateMessage processingState,
    int? currentIndex,
    Duration position = Duration.zero,
  }) {
    if (_events.isClosed) return;
    _events.add(PlaybackEventMessage(
      processingState: processingState,
      updateTime: DateTime.now(),
      updatePosition: position,
      bufferedPosition: _duration,
      duration: processingState == ProcessingStateMessage.idle ? null : _duration,
      icyMetadata: null,
      currentIndex: currentIndex,
      androidAudioSessionId: null,
    ));
  }
}
