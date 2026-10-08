/*
 * 随身听全局播放控制器。
 *
 * 设计要点（都是踩过坑才这么定的）：
 *
 * 1. **全 App 只有一个 [AudioPlayer]**。`just_audio_background` 明确只支持单实例；
 *    多个实例会互相抢 MediaSession，通知栏显示的歌和实际响的歌会对不上。
 *    旧的 `SongPlayPage` 自己 new 一个 `audioplayers` 实例，已改为调用本控制器。
 *
 * 2. **音源懒加载**：列表渲染阶段**不发任何音频请求**。只有 [playAt] / [playSong]
 *    被调用（用户点了某一行）时才为**那一首**构建 `AudioSource`。
 *    因此队列里其它歌的 `MediaItem` 只带元数据、不带 URL —— 它们本来也不需要，
 *    `just_audio` 的 `ConcatenatingAudioSource` 是按需加载的。
 *
 * 3. **通知栏曲绘 `artUri`** 必须是**网络 URL**（Android 的通知栏没法从 Flutter
 *    assets 里取图）。优先用 dxrating 的图（14~32KB、带磁盘缓存），
 *    回落到水鱼 covers（240~300KB）。
 *
 * 4. **播放失败要能自愈**：音源是第三方 CDN，个别曲目必然 404 / 超时。
 *    [playAt] 里捕获失败 → 通过 [events] 抛一条提示给 UI → 自动跳下一首，
 *    绝不会卡在「点了没反应」。
 */
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../../entity/Portable/PortableSong.dart';
import '../DxRatingCoverService.dart';

/// 播给 UI 看的一次性提示（SnackBar / Toast 用）。
class PortablePlayerEvent {
  final String message;
  final bool isError;

  const PortablePlayerEvent(this.message, {this.isError = false});
}

/// 一次「自动跳过」的连续失败上限。
///
/// 超过就停下来报错，避免「整个队列的音源都挂了」时一口气把 1000 多首全试一遍
/// （那会打出一千个 404，还会把 UI 卡死）。
const int kPortableMaxConsecutiveSkips = 5;

/// 随身听播放模式。
enum PortablePlaybackMode { sequential, shuffle, single }

/// 与 `MainActivity.kt` 的 `PORTABLE_NOTIFICATION_CHANNEL` 对应。
///
/// 自定义通知栏那条路：audio_service 的通知布局由系统 `MediaStyle` 定死，
/// 做不出「曲绘占左侧整高 + 右侧三行」，所以通知改由 Kotlin 侧
/// `PortableNotificationService` 用 RemoteViews 自绘，并用**相同的通知 ID(1124)**
/// 顶掉 audio_service 那条，保证只看得到一条。
const MethodChannel kPortableNotificationChannel =
    MethodChannel('com.example.app/portable_notification');

class PortablePlayerController extends ChangeNotifier {
  PortablePlayerController._internal();
  static PortablePlayerController? _instance;
  factory PortablePlayerController() =>
      _instance ??= PortablePlayerController._internal();

  /// 仅供测试：丢掉当前单例，下一次 [PortablePlayerController] 会新建一个。
  ///
  /// [dispose] 之后必须补这一下，否则后续用例拿到的是**已 dispose** 的
  /// ChangeNotifier（debug 下 `notifyListeners` 会抛）。
  /// 需要整套复位是因为：`positionStream` 一旦被订阅，just_audio 内部就常驻一个
  /// 200ms 的周期定时器，只有 `AudioPlayer.dispose()` 收得掉 —— widget 测试
  /// 收尾的 `!timersPending` 断言不放过它。
  @visibleForTesting
  static void debugReset() {
    _instance = null;
  }

  final AudioPlayer _player = AudioPlayer();

  List<PortableSong> _queue = const <PortableSong>[];

  /// 队列版本号：每换一次队列 +1。
  ///
  /// 不能靠「sequence 长度和队列长度相等」来判断队列有没有变 —— 换成另一批
  /// **等长**的歌时长度一样，会误判成同一个队列、只 seek 不重建源，
  /// 结果播的还是旧队列里的那首。这个坑在真机上表现为「点了没反应」。
  int _queueRevision = 0;

  /// 当前已建源的队列版本。`_sourceRevision == _queueRevision` 时才允许只 seek。
  int _sourceRevision = -1;

  /// 当前队列（随身听页面把列表整批塞进来，用于「下一首/上一首」）。
  List<PortableSong> get queue => _queue;

  /// 正在播放/暂停的曲目；没播过任何东西时为 null。
  PortableSong? get currentSong {
    final index = _player.currentIndex;
    if (index == null || index < 0 || index >= _queue.length) return null;
    return _queue[index];
  }

  bool get isPlaying => _player.playing;

  PortablePlaybackMode _playbackMode = PortablePlaybackMode.sequential;

  /// 单曲循环的次数；`null` 表示「不设置次数」，即一直循环当前曲目。
  ///
  /// ⚠️ 它记录的是**用户的设置**，不跟当前模式绑定：切到顺序/随机播放再切回
  /// 单曲循环时要沿用上次的设置，否则用户刚设好的「3 次」会被静默清成无限。
  int? _singleLoopCount;

  /// 单曲循环时，**当前这一首已经完整播完的遍数**（只服务「指定次数」）。
  ///
  /// ⚠️ 别用 `ProcessingState.completed` 数：队列里还有下一首时，本曲播完平台是
  /// **自动接下一首**，根本不会进 completed 状态 —— 次数就永远轮不到自己头上，
  /// 表现就是「指定次数的单曲循环没生效」。真正的计数点见
  /// [_onPositionDiscontinuity]。
  int _singlePlaysDone = 0;

  bool _handlingCompleted = false;

  PortablePlaybackMode get playbackMode => _playbackMode;

  /// 单曲循环的次数；`null` 表示不设置次数（一直循环）。
  int? get singleLoopCount => _singleLoopCount;

  /// 仅供测试：当前这一首已经完整播完的遍数。
  @visibleForTesting
  int get singlePlaysDone => _singlePlaysDone;

  String get playbackModeLabel {
    switch (_playbackMode) {
      case PortablePlaybackMode.sequential:
        return '顺序播放';
      case PortablePlaybackMode.shuffle:
        return '随机播放';
      case PortablePlaybackMode.single:
        return _singleLoopCount == null ? '单曲循环' : '单曲循环 $_singleLoopCount 次';
    }
  }

  /// 是否已经有可显示的当前曲（悬浮球据此决定显不显示）。
  bool get hasSong => currentSong != null;

  Duration get position => _player.position;

  Duration? get duration => _player.duration;

  /// 正在加载音源（点了某一行的 loading 态用这个）。
  bool get isLoading => _loading;
  bool _loading = false;

  /// 当前曲目是否还在「取音源 / 缓冲」阶段 —— **列表行内的 loading 用这个**。
  ///
  /// 判据取 just_audio 的 `processingState`，不要拿 [isLoading] 当行内的
  /// loading 条件：后者只是 [playAt] 建源的那一小段，而 `play()` 的 future
  /// 要等到暂停/播完才完成（见 [playAt] 的注释），拿它当 loading 会出现
  /// 「歌已经响了，行右边还在转圈」。
  bool get isBuffering {
    final state = _player.processingState;
    return state == ProcessingState.loading ||
        state == ProcessingState.buffering;
  }

  bool get hasNext => _player.hasNext;
  bool get hasPrevious => _player.hasPrevious;

  Stream<Duration> get positionStream => _player.positionStream;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  /// 切歌（含自动播下一首）时发事件，UI 据此刷新「正在播放」那一行。
  Stream<int?> get currentIndexStream => _player.currentIndexStream;

  /// 播放/暂停变化。
  Stream<bool> get playingStream => _player.playingStream;

  /// 缓冲/就绪状态变化。
  ///
  /// 行内 loading 的**收尾**要跟着它刷新：只看 currentIndex / playing 会漏掉
  /// `loading → ready` 这一次跳变，表现就是「早就播上了，圈还在转」。
  Stream<ProcessingState> get processingStateStream =>
      _player.processingStateStream;

  /// 加载失败等需要用户知道的事情。
  final StreamController<PortablePlayerEvent> _events =
      StreamController<PortablePlayerEvent>.broadcast();
  Stream<PortablePlayerEvent> get events => _events.stream;

  bool _initialized = false;

  /// 连续自动跳过的次数（播放成功就清零），用于给「整队列都坏」设一个上限。
  int _consecutiveSkips = 0;

  /// 正在自动跳过的目标曲目，避免同一次失败触发两次跳过。
  bool _autoSkipping = false;

  /// 单曲播放时，落雪 URL 失败过一次就记下来：本曲已试过 wmc 兜底，不要再递归。
  /// 切歌时由 [playAt] 复位。
  bool _triedWmcFallback = false;

  /// 绑定播放器监听（在 main 里调一次即可，重复调用无副作用）。
  void init() {
    if (_initialized) return;
    _initialized = true;

    _player.currentIndexStream.listen((_) {
      _onCurrentIndexChanged();
      notifyListeners();
      unawaited(_pushNotification());
    });
    _player.playingStream.listen((_) {
      // 真的播起来了 → 失败计数清零
      if (_player.playing) _consecutiveSkips = 0;
      notifyListeners();
      unawaited(_pushNotification());
    });
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        unawaited(_handleCompleted());
        notifyListeners();
        unawaited(_pushNotification());
      }
    });
    // 「指定次数的单曲循环」全靠这条流数遍数，见 [_onPositionDiscontinuity]。
    _player.positionDiscontinuityStream.listen(_onPositionDiscontinuity);
    _player.durationStream.listen((_) => notifyListeners());
    // just_audio 的加载/解码错误会以 stream error 的形式冒到 playbackEventStream
    // （`play()` 也会同时抛异常，两条路都要接住，否则会变成未捕获异常刷日志）。
    _player.playbackEventStream.listen(
      (_) {},
      onError: (Object error, StackTrace _) => _handleSourceFailure(error),
    );

    // 通知栏按钮点击 → 原生回传 → 走 App 内完全相同的控制方法，
    // 保证两条路径的状态不会分叉。
    kPortableNotificationChannel.setMethodCallHandler((call) async {
      if (call.method != 'onMediaAction') return null;
      switch (call.arguments as String?) {
        case 'previous':
          await previous();
          break;
        case 'next':
          await next();
          break;
        case 'toggle':
          await togglePlayPause();
          break;
      }
      return null;
    });
  }

  /// 切换播放模式。
  ///
  /// **先通知 UI，再去落地平台侧**：`setLoopMode` / `setShuffleModeEnabled` 是平台
  /// 调用，慢的时候要等好几帧才回来。等它们回来才 notify 的话，用户点下去图标
  /// 不动、选择框里的勾选也不动，看着就像「点了没反应」。
  ///
  /// **不改动**已配置的单曲循环次数（那份设置由 [setSingleLoopCount] 管）：
  /// 切走再切回来要沿用上次的「N 次」，不能悄悄退回无限循环。
  Future<void> setPlaybackMode(PortablePlaybackMode mode) async {
    _playbackMode = mode;
    // 换到单曲循环：这一首从头数遍数
    if (mode == PortablePlaybackMode.single) _singlePlaysDone = 0;
    notifyListeners();
    await _applyPlaybackMode(reshuffle: mode == PortablePlaybackMode.shuffle);
  }

  /// 设置单曲循环的次数（`null` = 不设置次数，即一直循环）。
  ///
  /// 「循环次数」本身就是单曲循环的子设置，所以在别的模式下设置它也会切到
  /// 单曲循环 —— 否则用户设完 3 次却还停在顺序播放，界面上看不出任何变化。
  Future<void> setSingleLoopCount(int? count) async {
    _singleLoopCount = count;
    _singlePlaysDone = 0;
    if (_playbackMode != PortablePlaybackMode.single) {
      await setPlaybackMode(PortablePlaybackMode.single);
      return;
    }
    notifyListeners();
    await _applyPlaybackMode();
  }

  /// 换曲（含平台自动接下一首）时调用。
  ///
  /// 「这一首播了几遍」的清零**不在这里**做：兜底把曲目拽回来时也会换 index，
  /// 那一下不该把计数清零（见 [_onPositionDiscontinuity]）。
  void _onCurrentIndexChanged() {
    if (_playbackMode != PortablePlaybackMode.single) return;
    unawaited(_player.setLoopMode(LoopMode.one));
  }

  /// 单曲循环「指定次数」的**计数点**。
  ///
  /// just_audio 把两种「位置不连续」都归到 `autoAdvance`：
  ///   1. 同一首绕回开头 —— 平台的 `LoopMode.one` 无缝循环生效了，这一遍播完了；
  ///   2. 落到下一首 —— 本曲播完了但循环没生效（少见），或者次数已经用完该走了。
  /// 拖进度条走的是 `seek`，这里不看，所以不会把用户拖动算成一轮。
  ///
  /// 为什么不能靠 `ProcessingState.completed` 数：队列里还有下一首时它永远不来
  /// （见 [_singlePlaysDone] 的注释）。
  void _onPositionDiscontinuity(PositionDiscontinuity discontinuity) {
    if (discontinuity.reason != PositionDiscontinuityReason.autoAdvance) return;
    if (_playbackMode != PortablePlaybackMode.single) return;

    final previousIndex = discontinuity.previousEvent.currentIndex;
    final index = discontinuity.event.currentIndex;
    final limit = _singleLoopCount;

    if (previousIndex == index) {
      // 同一首绕回开头：这一遍已经完整播完，新的这一遍正在放
      _onSinglePlayCompleted();
      return;
    }

    // 播着播着到下一首了
    if (previousIndex == null ||
        previousIndex < 0 ||
        previousIndex >= _queue.length) {
      return;
    }
    _singlePlaysDone++;
    if (limit != null && _singlePlaysDone >= limit) {
      // 次数用完了：这一首到此为止，接下来这一首重新开始数
      //（单曲循环的次数是**按每首算的**），顺便把循环重新打开。
      _singlePlaysDone = 0;
      unawaited(_player.setLoopMode(LoopMode.one));
      return;
    }
    // 次数还没用完却往下走了：说明本曲的循环没生效，把它拽回来接着放
    unawaited(_player.seek(Duration.zero, index: previousIndex));
  }

  /// 本曲**完整播完了一遍**，并且平台已经从头接着放下一遍时调用。
  ///
  /// 数够「循环次数」就把平台的循环关掉，让这一遍放完自然往下走。
  void _onSinglePlayCompleted() {
    _singlePlaysDone++;
    final limit = _singleLoopCount;
    if (limit != null && _singlePlaysDone + 1 >= limit) {
      // 正在放的这一遍就是最后一遍
      unawaited(_player.setLoopMode(LoopMode.off));
    }
  }

  /// 仅供测试：喂一次「本曲播完一遍」。
  ///
  /// 真机上这个信号来自 [`_onPositionDiscontinuity`] —— just_audio 自己会把
  /// 「同一首绕开头」识别成 `autoAdvance`（见 `just_audio.dart` 里
  /// `playbackEventStream.pairwise()` 那段），widget 测试里没法真跑出来
  /// （平台激活在假时钟下走不完），所以这里留一个直通口子。
  @visibleForTesting
  void debugNotifySinglePlayCompleted() {
    if (_playbackMode != PortablePlaybackMode.single) return;
    _onSinglePlayCompleted();
  }

  /// 仅供测试：just_audio 的 Dart 侧当前循环模式。
  ///
  /// 读它而不是读 fake 平台收到的调用：平台调用在假时钟下不一定回得来，
  /// 但 `setLoopMode` 会**同步**更新这个值，真机上再由此推给平台。
  @visibleForTesting
  LoopMode get debugLoopMode => _player.loopMode;

  Future<void> _applyPlaybackMode({bool reshuffle = false}) async {
    // 单曲循环统一交给平台的 `LoopMode.one`（无缝循环）；
    // 「指定次数」由 [_onPositionDiscontinuity] 数遍数，数够了再把循环关掉。
    await _player.setLoopMode(_playbackMode == PortablePlaybackMode.single
        ? LoopMode.one
        : LoopMode.off);
    await _player
        .setShuffleModeEnabled(_playbackMode == PortablePlaybackMode.shuffle);
    if (reshuffle && _player.audioSource != null) {
      await _player.shuffle();
    }
  }

  /// 整条队列播完（`completed`）时的兜底。
  ///
  /// 单曲循环正常走的是平台的 `LoopMode.one`，不会进这里；能走到这儿说明平台
  /// 没帮我们绕回去（无限循环的兜底），或者「次数」已经用完该停下来了。
  Future<void> _handleCompleted() async {
    if (_handlingCompleted) return;
    _handlingCompleted = true;
    try {
      if (_playbackMode != PortablePlaybackMode.single) return;
      _singlePlaysDone++;
      final limit = _singleLoopCount;
      if (limit != null && _singlePlaysDone >= limit) {
        // 次数用完了：停在结尾（顺手 pause 一下，免得 UI 一直挂在「正在播放」）
        await _player.pause();
        return;
      }
      await _player.seek(Duration.zero);
      unawaited(
          _player.play().catchError((Object e) => _handleSourceFailure(e)));
      notifyListeners();
    } finally {
      _handlingCompleted = false;
    }
  }

  /// 把当前状态推给 Kotlin 的自定义通知栏。
  ///
  /// 曲绘走**本地文件路径**：`audio_service` 的 Java 侧只认本地文件当通知栏大图标，
  /// 而 Dart 侧本来就会把 `artUri` 下载进 [DefaultCacheManager]，这里直接复用那份
  /// 缓存文件，Kotlin 侧只 `decodeFile`，不需要任何网络代码。
  ///
  /// 全流程失败都不影响播放（`MissingPluginException` 在非 Android 平台是正常的）。
  Future<void> _pushNotification() async {
    final song = currentSong;
    try {
      if (song == null) {
        await kPortableNotificationChannel.invokeMethod<void>('hide');
        return;
      }
      final artPath = await _cachedArtPath(song);
      await kPortableNotificationChannel.invokeMethod<void>('update', {
        'title': song.title,
        'artist': song.artist.isEmpty ? '未知艺术家' : song.artist,
        'artPath': artPath,
        'isPlaying': _player.playing,
        'hasNext': _player.hasNext,
        'hasPrevious': _player.hasPrevious,
      });
    } on MissingPluginException {
      // 非 Android 平台没有这个通道：正常，忽略
    } catch (e) {
      debugPrint('[Portable] 推送通知栏状态失败: $e');
    }
  }

  /// 取通知栏曲绘的**本地缓存文件路径**，没有就下载一次。
  Future<String?> _cachedArtPath(PortableSong song) async {
    final url = _notificationArtUri(song);
    try {
      final file = await DefaultCacheManager()
          .getSingleFile(url)
          .timeout(artPreloadTimeout);
      return file.path;
    } catch (e) {
      debugPrint('[Portable] 通知栏曲绘不可用（不影响播放）: $e');
      return null;
    }
  }

  /// 音源加载/解码失败的统一处理：提示 + 自动跳过。
  ///
  /// ⚠️ 这条路径**必须**有：源列表是用 `preload: false` 建的，音源 404 / 超时
  /// 不会在 `setAudioSource` 阶段抛异常，而是在真正开始缓冲时才报出来。
  /// 只靠 `playAt` 的 try/catch 会表现为「点了行内转圈一下然后就安静了，
  /// 什么提示都没有」—— 真机上极难排查。
  void _handleSourceFailure(Object error) {
    final song = currentSong;
    final title = song?.title ?? '当前曲目';
    debugPrint('[Portable] 音源加载失败 $title: $error');

    // 单曲播放（队列里只有这一首）：先试一次 wmc.pub 兜底，再走 skip。
    // 多首队列：直接 skip（避免打乱用户期望的连续播放顺序，wmc 兜底是单曲专属）。
    if (song != null && _queue.length == 1 && !_triedWmcFallback) {
      _triedWmcFallback = true;
      debugPrint('[Portable] 单曲失败 → 试 wmc 兜底: ${song.wmcAudioUrl}');
      _emit(PortablePlayerEvent(
        '《$title》落雪音源失败，尝试 wmc 兜底…',
        isError: true,
      ));
      unawaited(_retryWithWmcFallback(song));
      return;
    }

    _emit(PortablePlayerEvent(
      '《$title》音源加载失败，已跳过',
      isError: true,
    ));
    unawaited(_autoSkipAfterFailure());
  }

  /// 单曲失败兜底：把当前曲换成 wmc URL 重播一次。失败的话回退到 skip。
  Future<void> _retryWithWmcFallback(PortableSong song) async {
    try {
      final wmcSource = AudioSource.uri(
        Uri.parse(song.wmcAudioUrl),
        tag: MediaItem(
          id: song.portableKey,
          title: song.title,
          artist: song.artist.isEmpty ? '未知艺术家' : song.artist,
          album: song.genre.isEmpty ? 'ChiffonMai 随身听' : song.genre,
          artUri: Uri.parse(_notificationArtUri(song)),
          extras: <String, dynamic>{
            'lxnsId': song.lxnsId,
            'divingFishId': song.divingFishId,
            'fallback': 'wmc',
          },
        ),
      );
      final playlist = ConcatenatingAudioSource(
        children: <AudioSource>[wmcSource],
        useLazyPreparation: true,
      );
      await _player.setAudioSource(
        playlist,
        preload: false,
        initialIndex: 0,
        initialPosition: Duration.zero,
      );
      unawaited(
          _player.play().catchError((Object e) => _handleSourceFailure(e)));
    } catch (e) {
      debugPrint('[Portable] wmc 兜底也失败: $e');
      _handleSourceFailure(e);
    }
  }

  Future<void> _autoSkipAfterFailure() async {
    if (_autoSkipping) return;
    _autoSkipping = true;
    try {
      _consecutiveSkips++;
      if (_consecutiveSkips > kPortableMaxConsecutiveSkips) {
        _emit(const PortablePlayerEvent(
          '连续多首音源都加载失败，已停止自动跳过（请检查网络后重试）',
          isError: true,
        ));
        return;
      }
      final index = _player.currentIndex;
      if (index == null || index + 1 >= _queue.length) return;
      // 稍微等一下再跳：失败事件有时会在同一帧里连发几条
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await playAt(index + 1);
    } finally {
      _autoSkipping = false;
    }
  }

  // ── 播放控制 ────────────────────────────────────────────────────────────

  /// 把 [songs] 设成播放队列并播放第 [index] 首。
  ///
  /// [songs] 通常就是随身听页面当前显示的列表（已过滤/搜索后的），
  /// 这样「下一首」和用户看到的顺序一致。
  Future<void> playQueue(List<PortableSong> songs, int index) async {
    if (songs.isEmpty || index < 0 || index >= songs.length) return;
    _queue = List<PortableSong>.unmodifiable(songs);
    _queueRevision++;
    notifyListeners();
    await playAt(index);
  }

  /// 单曲播放（歌曲详情页的「播放音乐」走这里）。
  Future<void> playSong(PortableSong song) async {
    final existing = _queue.indexWhere((s) => s.lxnsId == song.lxnsId);
    if (existing >= 0) {
      await playAt(existing);
      return;
    }
    await playQueue(<PortableSong>[song], 0);
  }

  /// 播放队列里的第 [index] 首 —— **音源就是在这里才被请求的**。
  ///
  /// 已经放过的曲目直接 `seek` 过去（不重新建源），否则重新 setAudioSources。
  Future<void> playAt(int index) async {
    if (index < 0 || index >= _queue.length) return;
    final song = _queue[index];

    if (_playbackMode == PortablePlaybackMode.single) {
      // 换了一首：单曲循环的次数按每首算，重新开始数
      _singlePlaysDone = 0;
    }

    _setLoading(true);
    // 切到新歌 → 清掉「本首已试 wmc」标记，下次失败又可以试一次
    _triedWmcFallback = false;
    try {
      // 先预热通知栏曲绘（见 [preloadNotificationArt] 的注释），再起播。
      // 放在 setAudioSource 之前是因为它是纯本地/网络图片下载，与音频无关，
      // 但必须先于通知栏出现才有意义。
      await preloadNotificationArt(song);

      final queueChanged =
          _sourceRevision != _queueRevision || _player.audioSource == null;
      if (!queueChanged) {
        // 队列没变，直接跳（just_audio 按需加载这一首）
        await _player.seek(Duration.zero, index: index);
        // 顺手把循环/随机再推一次：上一首「次数用完」时可能把单曲循环关掉了
        // （见 [_onPositionDiscontinuity]），切到新的一首要重新打开。
        await _applyPlaybackMode();
      } else {
        // 队列变了：重建源列表。
        //
        // ⚠️ 本项目锁的是 just_audio **0.9.46**，这个版本**没有** `setAudioSources`
        // （那是 0.10.x 才加的 API），只能用 ConcatenatingAudioSource 包一层。
        //
        // `preload: false` 是这里的关键：**不预加载音频数据**，音源只有等真正播到
        // 它时才去请求，正好满足「点击某一行才取音源，不要全部批量获取」。
        //
        // 注意 `preload: false` **不等于**「元数据也没有」：just_audio_background
        // 的 `_updateQueue()` 是从 source 的 sequence 里读 MediaItem 的，而
        // sequence 在 `_setup()` 阶段就已经建好（与是否 preload 无关），
        // 所以通知栏的歌名/曲绘/上一首下一首按钮依然完整。
        final playlist = ConcatenatingAudioSource(
          children: <AudioSource>[
            for (final s in _queue) _buildSource(s),
          ],
          useLazyPreparation: true,
        );
        // initialIndex 由 setAudioSource 自己处理（0.9.46 已支持，别再补一次 seek：
        // 紧跟着调 `seek` 有可能撞上 processingState == loading 而被直接忽略）。
        await _player.setAudioSource(
          playlist,
          preload: false,
          initialIndex: index,
          initialPosition: Duration.zero,
        );
        _sourceRevision = _queueRevision;
        await _applyPlaybackMode(
            reshuffle: _playbackMode == PortablePlaybackMode.shuffle);
      }
      // ⚠️ 这里**不要** `await _player.play()`。
      //
      // just_audio 0.9.46 的 `play()` 返回的 future 要等到**暂停 / 播完 /
      // 被下一次播放打断**才完成（lib/just_audio.dart 末尾的
      // `await playCompleter.future`；平台实现是在 onPause/onComplete 时
      // resolve 那次 play 请求）。await 它的后果：`finally` 里的
      // `_setLoading(false)` 要等整首歌才执行 → 列表行、全屏页的「加载中」
      // 一路转到底。只发起、不等完成；失败照旧汇到 [playbackEventStream]
      // 的 onError（`_handleSourceFailure`）。
      unawaited(
          _player.play().catchError((Object e) => _handleSourceFailure(e)));
      _emit(PortablePlayerEvent('正在播放：${song.title}'));
    } catch (e) {
      // 只有「建源/发起播放」这一段的同步失败会走到这里（比如 URL 非法）。
      // 真正的网络 404 发生在缓冲阶段，走 playbackEventStream 的 onError，
      // 两条路都汇到 _autoSkipAfterFailure，不会重复跳过（有 _autoSkipping 闸门）。
      _handleSourceFailure(e);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> togglePlayPause() async {
    if (_player.audioSource == null) return;
    if (_player.playing) {
      await _player.pause();
    } else {
      // 播完之后再点播放：回到开头重播，否则 resume() 在 completed 状态下无效
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      unawaited(_player
          .play()
          .catchError((Object error) => _handleSourceFailure(error)));
    }
    notifyListeners();
  }

  Future<void> next() async {
    if (!_player.hasNext) return;
    await _player.seekToNext();
    // play 的 Future 会等待到暂停/结束，不能让切歌按钮一直处于忙碌状态。
    if (!_player.playing)
      unawaited(_player
          .play()
          .catchError((Object error) => _handleSourceFailure(error)));
  }

  Future<void> previous() async {
    if (!_player.hasPrevious) return;
    await _player.seekToPrevious();
    if (!_player.playing)
      unawaited(_player
          .play()
          .catchError((Object error) => _handleSourceFailure(error)));
  }

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> stop() async {
    await _player.stop();
    _queue = const <PortableSong>[];
    _queueRevision++;
    _sourceRevision = -1;
    notifyListeners();
    unawaited(_pushNotification()); // 队列清空 → currentSong 为 null → 收起通知栏
  }

  // ── 内部 ────────────────────────────────────────────────────────────────

  /// 把通知栏曲绘预热进 [DefaultCacheManager]。
  ///
  /// 为什么必须预热（这是通知栏「左侧曲绘空白」的根因）：
  ///   `audio_service` 的 Java 侧只会用**本地文件**当通知栏大图标 ——
  ///   `AudioService.java#setMetadata()` 只认 `artCacheFile`（本地路径）或
  ///   `content://` URI，**不认 http URL**。那个本地文件是 Dart 侧的
  ///   `_observeMediaItem()` 异步下载完才补上的：
  ///     1. 先发一次不带图的 metadata（通知栏此时**没有曲绘**）；
  ///     2. 下载完再发一次带 `artCacheFile` 的（通知栏才补上图）。
  ///   而通知栏是 `play()` 触发的，几乎立刻弹出 → 用户看到的就是没图的通知栏，
  ///   要等一两秒才补上（弱网更久，甚至一直空白）。
  ///
  /// 这里提前把图灌进**同一个** [DefaultCacheManager]（audio_service 内部用的就是它，
  /// key 为 `libCachedImageData`）。这样第一步
  /// `cacheManager.getFileFromMemory(artUri)` 就能直接命中，通知栏第一次渲染
  /// 就带图，不存在「先空后补」的闪烁。
  ///
  /// 失败/超时都不影响播放 —— 拿不到图就回到「先空后补」的旧行为。
  @visibleForTesting
  static const Duration artPreloadTimeout = Duration(seconds: 6);

  Future<void> preloadNotificationArt(PortableSong song) async {
    await _cachedArtPath(song);
  }

  AudioSource _buildSource(PortableSong song) {
    return AudioSource.uri(
      Uri.parse(song.audioUrl),
      tag: MediaItem(
        id: song.portableKey,
        title: song.title,
        artist: song.artist.isEmpty ? '未知艺术家' : song.artist,
        album: song.genre.isEmpty ? 'ChiffonMai 随身听' : song.genre,
        artUri: Uri.parse(_notificationArtUri(song)),
        extras: <String, dynamic>{
          'lxnsId': song.lxnsId,
          'divingFishId': song.divingFishId,
        },
      ),
    );
  }

  void _setLoading(bool value) {
    if (_loading == value) return;
    _loading = value;
    notifyListeners();
  }

  void _emit(PortablePlayerEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  @override
  void dispose() {
    _events.close();
    _player.dispose();
    super.dispose();
  }
}

/// 通知栏曲绘 URL。
///
/// 必须是网络 URL（Android 通知栏取不到 Flutter assets）。优先 dxrating：
/// 索引里有映射时（实测覆盖 99.8%）图只有 14~32KB 且走磁盘缓存，
/// 而水鱼 covers 是 240~300KB。索引没就绪就回落到水鱼 covers。
///
/// ⚠️ 水鱼 covers 的命名是**规范水鱼 id 左补零到 5 位**，不能用音源 id
/// （宴会场两者不同，见 [PortableSong.coverNetworkId]）。
String _notificationArtUri(PortableSong song) {
  try {
    DxRatingCoverService.instance.ensureLoaded();
    final dxUrl = DxRatingCoverService.instance.coverUrlFor(song.divingFishId);
    if (dxUrl != null && dxUrl.isNotEmpty) return dxUrl;
  } catch (e) {
    debugPrint('[Portable] dxrating 曲绘查询失败: $e');
  }
  return song.coverNetworkUrl;
}
