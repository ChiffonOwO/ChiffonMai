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

import '../../entity/Portable/PortableSong.dart';
import '../../service/Portable/PortablePlayerController.dart';
import '../../utils/AppDesignTokens.dart';
import '../../utils/CommonWidgetUtil.dart';
import '../../widgets/PageTopBar.dart';
import '../../widgets/PortablePlayerBadge.dart';

class PortableNowPlayingPage extends StatefulWidget {
  const PortableNowPlayingPage({super.key});

  @override
  State<PortableNowPlayingPage> createState() => _PortableNowPlayingPageState();
}

class _PortableNowPlayingPageState extends State<PortableNowPlayingPage> {
  final PortablePlayerController _player = PortablePlayerController();
  final List<StreamSubscription<dynamic>> _subs = <StreamSubscription<dynamic>>[];

  double? _dragValue;

  @override
  void initState() {
    super.initState();
    _subs.add(_player.currentIndexStream.listen((_) => _safeSetState()));
    _subs.add(_player.playingStream.listen((_) => _safeSetState()));
    _subs.add(_player.positionStream.listen((_) {
      if (mounted && _dragValue == null) _safeSetState();
    }));
  }

  @override
  void dispose() {
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
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          CommonWidgetUtil.buildCommonBgWidget(),
          CommonWidgetUtil.buildCommonChiffonBgWidget(context),
          Column(
            children: [
              const PageTopBar(title: '正在播放'),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppDesignTokens.maxContentWidth,
                    ),
                    child: song == null
                        ? _empty(scheme)
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
          // 曲绘
          Container(
            width: coverSize,
            height: coverSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: PortableCover(
              song: song,
              size: coverSize,
              radius: 18,
            ),
          ),
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
              onChanged: totalMs <= 0
                  ? null
                  : (v) => setState(() => _dragValue = v),
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
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                Text(
                  _fmt(duration),
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
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
                tooltip: '上一首',
                icon: Icon(Icons.skip_previous, color: theme.colorScheme.onSurface),
                onPressed: _player.hasPrevious ? () => _player.previous() : null,
              ),
              const SizedBox(width: 18),
              _playButton(theme),
              const SizedBox(width: 18),
              IconButton(
                iconSize: 40,
                tooltip: '下一首',
                icon: Icon(Icons.skip_next, color: theme.colorScheme.onSurface),
                onPressed: _player.hasNext ? () => _player.next() : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _playButton(ThemeData theme) {
    final scheme = theme.colorScheme;
    final loading = _player.isLoading;
    return SizedBox(
      width: 68,
      height: 68,
      child: Material(
        color: scheme.primary,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: loading ? null : () => _player.togglePlayPause(),
          child: Center(
            child: loading
                ? SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.6,
                      valueColor: AlwaysStoppedAnimation<Color>(scheme.onPrimary),
                    ),
                  )
                : Icon(
                    _player.isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 36,
                    color: scheme.onPrimary,
                  ),
          ),
        ),
      ),
    );
  }

  static String _fmt(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
