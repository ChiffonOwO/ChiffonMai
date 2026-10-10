/*
 * 随身听的全屏播放页（大曲绘 + 进度条 + 上一首/播放/下一首）。
 *
 * 入口：随身听列表顶部的「正在播放」条、悬浮球迷你卡片、以及旧播放页被接管后的跳转。
 *
 * ⚠️ 这一页**不持有播放器状态的所有权**：`leave` 时不动播放器，音乐继续放。
 * 这正是需求里「切出此页面也不会中断音乐」的关键 —— 旧 `SongPlayPage` 在
 * `dispose` 里把播放器 stop + dispose 了，所以退出即静音。
 */
import 'dart:async';

import 'package:flutter/material.dart';
import '../../widgets/ExportSuccessDialog.dart';

import '../../entity/Portable/PortableSong.dart';
import '../../service/Portable/PortablePlayerController.dart';
import '../../service/Portable/PortableSongDownloadService.dart';
import '../../utils/AppDesignTokens.dart';
import '../../utils/CommonWidgetUtil.dart';
import '../../utils/ExportPathUtil.dart';
import '../../widgets/PageTopBar.dart';
import '../../widgets/PortablePlayerBadge.dart';
import '../../widgets/AnimatedChoiceBar.dart';
import '../../widgets/PortablePlaybackModeButton.dart';

class PortableNowPlayingPage extends StatefulWidget {
  const PortableNowPlayingPage({super.key});

  @override
  State<PortableNowPlayingPage> createState() => _PortableNowPlayingPageState();
}

class _PortableNowPlayingPageState extends State<PortableNowPlayingPage> {
  final PortablePlayerController _player = PortablePlayerController();
  final List<StreamSubscription<dynamic>> _subs =
      <StreamSubscription<dynamic>>[];

  double? _dragValue;
  double _coverDrag = 0;
  bool _switching = false;
  double _slideDirection = 1;
  bool _downloading = false;
  double? _downloadProgress;
  double? _downloadSpeedBytesPerSecond;

  @override
  void initState() {
    super.initState();
    _player.addListener(_safeSetState);
    _subs.add(_player.currentIndexStream.listen((_) => _safeSetState()));
    _subs.add(_player.playingStream.listen((_) => _safeSetState()));
    _subs.add(_player.positionStream.listen((_) {
      if (mounted && _dragValue == null) _safeSetState();
    }));
  }

  @override
  void dispose() {
    _player.removeListener(_safeSetState);
    for (final sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }

  void _safeSetState() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final song = _player.currentSong;

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
              PageTopBar(
                title: '正在播放',
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppDesignTokens.maxContentWidth,
                    ),
                    child: song == null
                        ? (_player.isLoading
                            ? _preparing(scheme)
                            : _empty(scheme))
                        : _content(context, scheme, song),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _empty(ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.music_note, size: 64, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            '还没有在放的音乐',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _preparing(ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: scheme.primary),
          const SizedBox(height: 12),
          Text(
            '正在准备音源…',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadSong(PortableSong song) async {
    if (!await ExportPathUtil.prepareForExport(context,
        subDir: '歌曲', title: '选择歌曲保存位置')) {
      return;
    }
    setState(() {
      _downloading = true;
      _downloadProgress = null;
      _downloadSpeedBytesPerSecond = null;
    });
    String? fallbackPath;
    try {
      final file = await PortableSongDownloadService.instance.download(
        song,
        onProgress: (progress) {
          if (mounted) setState(() => _downloadProgress = progress);
        },
        onSpeed: (speed) {
          if (mounted) setState(() => _downloadSpeedBytesPerSecond = speed);
        },
        onFallback: (path) => fallbackPath = path,
      );
      if (mounted) {
        await showExportSuccessDialog(
          context,
          filePath: file.path,
          fileName: song.title,
          title: '下载成功',
          successPrefix: '已下载',
          fallbackPath: fallbackPath,
        );
      }
    } on AudioDownloadSourceException catch (e) {
      if (mounted) _showDownloadHint(e.message);
    } catch (e) {
      if (mounted) _showDownloadHint('下载失败：$e');
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
          _downloadProgress = null;
          _downloadSpeedBytesPerSecond = null;
        });
      }
    }
  }

  void _showDownloadHint(String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
    );
  }

  Widget _content(
    BuildContext context,
    ColorScheme scheme,
    PortableSong song,
  ) {
    final theme = Theme.of(context);
    final duration = _player.duration ?? Duration.zero;
    final totalMs = duration.inMilliseconds;
    final value = _dragValue ??
        (totalMs > 0
            ? (_player.position.inMilliseconds / totalMs).clamp(0.0, 1.0)
            : 0.0);
    final side = MediaQuery.of(context).size.width * 0.62;
    final coverSize = side.clamp(160.0, 320.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      child: Column(
        children: [
          const SizedBox(height: 8),
          _coverCarousel(song, coverSize),
          const SizedBox(height: 26),
          Text(
            song.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            song.artist.isEmpty ? '未知艺术家' : song.artist,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 22),
          // 进度条
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: value,
              onChanged:
                  totalMs <= 0 ? null : (v) => setState(() => _dragValue = v),
              onChangeEnd: (v) async {
                final target = Duration(milliseconds: (v * totalMs).round());
                setState(() => _dragValue = null);
                await _player.seek(target);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _fmt(Duration(milliseconds: (value * totalMs).round())),
                  style:
                      TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                Text(
                  _fmt(duration),
                  style:
                      TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // 控制区
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 40,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                tooltip: '上一首',
                icon: Icon(Icons.skip_previous,
                    color: theme.colorScheme.onSurface),
                onPressed:
                    _player.hasPrevious ? () => _changeSong(false) : null,
              ),
              const SizedBox(width: 18),
              _playButton(theme),
              const SizedBox(width: 18),
              IconButton(
                iconSize: 40,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                tooltip: '下一首',
                icon: Icon(Icons.skip_next, color: theme.colorScheme.onSurface),
                onPressed: _player.hasNext ? () => _changeSong(true) : null,
              ),
              if (song != null) ...[
                const SizedBox(width: 8),
                _downloadControl(scheme, song),
                const SizedBox(width: 4),
                const PortablePlaybackModeButton(
                    density: VisualDensity.compact, iconSize: 20),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _changeSong(bool next) async {
    if (_switching ||
        _player.isLoading ||
        (next ? !_player.hasNext : !_player.hasPrevious)) return;
    setState(() {
      _switching = true;
      _slideDirection = next ? 1 : -1;
      _coverDrag = 0;
    });
    try {
      await (next ? _player.next() : _player.previous());
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  Widget _coverCarousel(PortableSong song, double size) {
    final queue = _player.queue;
    final index = queue.indexOf(song);
    final previews = _player.playbackMode != PortablePlaybackMode.shuffle;
    return LayoutBuilder(builder: (context, constraints) {
      final mainSize = size.clamp(0.0, constraints.maxWidth * .76);
      final neighborSize = mainSize * .64;
      Widget neighbor(PortableSong neighbor, bool next) => GestureDetector(
          onTap: () => _changeSong(next),
          child: Opacity(
              opacity: .5,
              child: PortableCover(
                  song: neighbor, size: neighborSize, radius: 16)));
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) {
          if (!_switching)
            setState(() => _coverDrag = (_coverDrag + details.delta.dx)
                .clamp(-mainSize / 3, mainSize / 3));
        },
        onHorizontalDragCancel: () => setState(() => _coverDrag = 0),
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (_coverDrag.abs() > 40 || velocity.abs() > 300) {
            final next = velocity.abs() > 300 ? velocity < 0 : _coverDrag < 0;
            _changeSong(next);
          }
          setState(() => _coverDrag = 0);
        },
        child: SizedBox(
            height: mainSize + 20,
            child: ClipRect(
                child: Stack(alignment: Alignment.center, children: [
              if (previews && index > 0 && _player.hasPrevious)
                Positioned(
                    left: -neighborSize * .35,
                    child: neighbor(queue[index - 1], false)),
              if (previews &&
                  index >= 0 &&
                  index + 1 < queue.length &&
                  _player.hasNext)
                Positioned(
                    right: -neighborSize * .35,
                    child: neighbor(queue[index + 1], true)),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                transform: Matrix4.translationValues(_coverDrag, 0, 0),
                child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                            position: Tween<Offset>(
                                    begin: Offset(_slideDirection * .18, 0),
                                    end: Offset.zero)
                                .animate(CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.easeOutCubic)),
                            child: child)),
                    child: Container(
                        key: ValueKey(song.portableKey),
                        width: mainSize,
                        height: mainSize,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .shadow
                                      .withValues(alpha: .2),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6))
                            ]),
                        child: PortableCover(
                            song: song, size: mainSize, radius: 20))),
              ),
            ]))),
      );
    });
  }

  Widget _playButton(ThemeData theme) {
    final scheme = theme.colorScheme;
    final radius = BorderRadius.circular(_player.isPlaying ? 12 : 34);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOutCubic,
      width: 60,
      height: 60,
      decoration: BoxDecoration(color: scheme.primary, borderRadius: radius),
      child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            splashFactory: NoSplash.splashFactory,
            highlightColor: Colors.transparent,
            onTap: _player.isLoading ? null : () => _player.togglePlayPause(),
            child: Center(
                child: FadeContent(
                    child: _player.isLoading
                        ? SizedBox(
                            key: const ValueKey('loading'),
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.6, color: scheme.onPrimary))
                        : Icon(
                            _player.isPlaying ? Icons.pause : Icons.play_arrow,
                            key: ValueKey(_player.isPlaying),
                            size: 36,
                            color: scheme.onPrimary))),
          )),
    );
  }

  Widget _downloadControl(ColorScheme scheme, PortableSong song) {
    if (!_downloading) {
      return IconButton(
        tooltip: '下载歌曲',
        icon: const Icon(Icons.download_outlined),
        onPressed: () => _downloadSong(song),
      );
    }
    return SizedBox(
      width: 42,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: _downloadProgress,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _formatDownloadSpeed(_downloadSpeedBytesPerSecond),
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  static String _formatDownloadSpeed(double? bytesPerSecond) {
    if (bytesPerSecond == null || bytesPerSecond <= 0) return '计算中';
    if (bytesPerSecond >= 1024 * 1024) {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
    return '${(bytesPerSecond / 1024).toStringAsFixed(0)} KB/s';
  }

  static String _fmt(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
