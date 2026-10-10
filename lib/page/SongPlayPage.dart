/*
 * 歌曲详情页的「播放音乐」页 —— **已经接管到随身听**。
 *
 * 历史：这里原本自己 new 一个 `audioplayers` 的 `AudioPlayer`，在 `dispose()` 里
 * `stop + dispose`，所以「退出这个页面 = 音乐停」，也不会有通知栏控制。
 *
 * 现在这一页只做三件事：
 *   1. 把 songId 解析成随身听条目（[PortableSongLibrary.resolveForPlayback]，含落雪基础、
 *      AWMC 追加，以及目录未及时收录时的原始 songId 兜底）；
 *   2. 交给全局的 [PortablePlayerController] 播放（不持有播放器所有权）；
 *   3. 渲染随身听的全屏播放界面。
 *
 * 因此退出这一页**不会**中断音乐，悬浮球和通知栏也照常工作。
 *
 * 保留原来的构造签名（songId / songTitle / songType），这样 `SongInfoPage`
 * 等调用点的改动最小。
 */
import 'package:flutter/material.dart';

import '../entity/Portable/PortableSong.dart';
import '../service/Portable/PortablePlayerController.dart';
import '../service/Portable/PortableSongLibrary.dart';
import '../utils/CommonWidgetUtil.dart';
import '../utils/PortablePlayerScope.dart';
import '../widgets/PageTopBar.dart';
import 'Portable/PortableNowPlayingPage.dart';

class SongPlayPage extends StatefulWidget {
  final String songId;
  final String songTitle;
  final String songType;
  final String? songArtist;

  const SongPlayPage({
    super.key,
    required this.songId,
    required this.songTitle,
    required this.songType,
    this.songArtist,
  });

  @override
  State<SongPlayPage> createState() => _SongPlayPageState();
}

class _SongPlayPageState extends State<SongPlayPage> {
  final PortableSongLibrary _library = PortableSongLibrary();
  final PortablePlayerController _player = PortablePlayerController();

  /// 是否已经把播放权交给全局播放器。
  ///
  /// 这一页可能在音乐已经在放的时候被打开（比如从随身听列表再点进来），
  /// 那种情况下不该打断当前播放去重播这首歌 —— 只有当这首**不是**当前曲目时
  /// 才真的切过去。
  bool _handedOff = false;
  String? _message;
  PortableSong? _resolved;

  @override
  void initState() {
    super.initState();
    // 从 SongInfoPage 点「播放音乐」进来的：把随身听悬浮球压住，避免它突然冒出来。
    // 不影响播放、不影响通知栏、不影响切歌；页面一 pop 这层就撤掉，球回来。
    PortablePlayerScope.isSongInfoPlayback.value = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveAndPlay());
  }

  @override
  void dispose() {
    // 撤掉悬浮球抑制：球按 `_player.currentSong != null` 自然显示（如果还在放）
    PortablePlayerScope.isSongInfoPlayback.value = false;
    super.dispose();
  }

  Future<void> _resolveAndPlay() async {
    try {
      // 曲库可能还没构建过（用户没进过随身听页），先确保加载
      await _library.load();
      final song = _library.resolveForPlayback(
        songId: widget.songId,
        title: widget.songTitle,
        type: widget.songType,
        artist: widget.songArtist,
      );
      if (!mounted) return;

      if (song == null) {
        setState(() {
          _message = '这首歌暂时没有可用的音源';
        });
        return;
      }
      setState(() => _resolved = song);

      final current = _player.currentSong;
      if (current != null && current.lxnsId == song.lxnsId) {
        // 已经就是当前曲目：不动播放状态，只把界面换过来
        setState(() => _handedOff = true);
        return;
      }

      // 播放器需要先下载/读取音频并建立 AudioSource。不能在这里提前切到
      // PortableNowPlayingPage，否则它会在 currentSong 还是 null 时显示「还没有
      // 在放的音乐」，随后页面退出了，后台下载完成后才真正开始播放。
      await _player.playSong(song);
      if (!mounted) return;
      if (_player.currentSong == null) {
        setState(() => _message = '音源加载失败，请稍后重试');
        return;
      }
      setState(() => _handedOff = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = '打开播放器失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 解析成功就直接用随身听的全屏播放页（同一套 UI，不维护两份）
    if (_resolved != null && _handedOff) {
      return const PortableNowPlayingPage();
    }

    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: scheme.surface)),
          CommonWidgetUtil.buildCommonBgWidget(),
          CommonWidgetUtil.buildCommonChiffonBgWidget(context),
          Column(
            children: [
              const PageTopBar(title: '播放音乐'),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_message == null) ...[
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          '正在准备音源…',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ] else ...[
                        Icon(
                          Icons.music_off,
                          size: 64,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            _message!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
