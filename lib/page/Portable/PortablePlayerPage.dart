/*
 * 随身听 —— 曲库列表页。
 *
 * 列表本身**不碰音源**：每一行只用本地 `assets/cover` + 水鱼元数据渲染。
 * 只有用户**点了某一行**，才为那一首去取音源（见 [PortablePlayerController.playQueue]）。
 * 这是明确的需求：全量批量取音源会把落雪 CDN 打爆，也会让进页面卡住。
 *
 * 通知权限（Android 13+ 的 POST_NOTIFICATIONS）**首次进本页时**申请一次：
 * 用户此刻正在期待播放器，同意率最高。拒绝也不阻断播放，只提示一句
 * 「不会显示通知栏播放器，音乐仍可后台播放」。
 */
import 'dart:async';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constant/CacheKeyConstant.dart';
import '../../entity/Portable/PortableSong.dart';
import '../../service/Portable/PortablePlayerController.dart';
import '../../service/Portable/PortableSongLibrary.dart';
import '../../utils/AppDesignTokens.dart';
import '../../utils/AppTheme.dart';
import '../../utils/CommonWidgetUtil.dart';
import '../../utils/PortablePlayerScope.dart';
import '../../widgets/PageTopBar.dart';
import '../../widgets/PortablePlayerBadge.dart';
import 'PortableNowPlayingPage.dart';

class PortablePlayerPage extends StatefulWidget {
  const PortablePlayerPage({super.key});

  @override
  State<PortablePlayerPage> createState() => _PortablePlayerPageState();
}

class _PortablePlayerPageState extends State<PortablePlayerPage> {
  final PortableSongLibrary _library = PortableSongLibrary();
  final PortablePlayerController _player = PortablePlayerController();
  final TextEditingController _searchController = TextEditingController();

  List<PortableSong> _all = const <PortableSong>[];
  List<PortableSong> _filtered = const <PortableSong>[];
  bool _loading = true;
  String? _error;

  /// 搜索防抖定时器 —— 与乐曲查询页一致（1000ms）。
  ///
  /// 为什么不像原来那样「每敲一个字就过滤一遍」：随身听的匹配要走别名表，
  /// 而 [PortableSongLibrary.search] 每次都要查一遍 `SongAliasManager`，
  /// 逐字符过滤在 1200+ 首上会明显掉帧。乐曲查询页用 1s 防抖，这里照搬。
  Timer? _searchTimer;

  StreamSubscription<PortablePlayerEvent>? _eventSub;
  final List<StreamSubscription<dynamic>> _playerSubs =
      <StreamSubscription<dynamic>>[];

  /// 点了但还没开始响的那一首（用于行内 loading）。
  int? _pendingLxnsId;

  /// 拖动进度条时的临时值（0~1）。拖动期间以它为准，松手 seek 完再交还给
  /// positionStream —— 否则 200ms 一跳的流会把拇指拽回旧位置。
  double? _dragValue;

  /// 曲库列表的滚动控制器：给「定位到正在播放」用。
  final ScrollController _listController = ScrollController();

  @override
  void initState() {
    super.initState();
    // 告诉 AppShell 收掉悬浮球：这一页自己就是播放入口，不用球再来一个
    PortablePlayerScope.isLibraryPageOpen.value = true;
    _eventSub = _player.events.listen(_onPlayerEvent);
    // 播放状态变化（切歌/暂停）要刷新「正在播放」那一行的样子
    _playerSubs.add(_player.currentIndexStream.listen((_) => _safeSetState()));
    _playerSubs.add(_player.playingStream.listen((_) => _safeSetState()));
    // 缓冲状态（loading / buffering → ready）也要刷：行内的 loading 靠它收尾
    _playerSubs.add(_player.processingStateStream.listen((_) => _safeSetState()));
    _loadLibrary();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAskNotification());
  }

  @override
  void dispose() {
    PortablePlayerScope.isLibraryPageOpen.value = false;
    _searchTimer?.cancel();
    _eventSub?.cancel();
    for (final sub in _playerSubs) {
      sub.cancel();
    }
    _listController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _safeSetState() {
    if (mounted) setState(() {});
  }

  // ── 数据 ────────────────────────────────────────────────────────────────

  Future<void> _loadLibrary({bool force = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (force) await _library.clearCache();
      final songs = await _library.load();
      if (!mounted) return;
      setState(() {
        _all = songs;
        _filtered = _applyFilter(songs);
        _loading = false;
        if (songs.isEmpty) {
          _error = '曲库还没准备好。请先回首页「刷新数据」，或检查网络后重试。';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '加载曲库失败：$e';
      });
    }
  }

  /// 按当前输入框内容过滤（规则见 `PortableSongLibrary.search`）。
  List<PortableSong> _applyFilter(List<PortableSong> source) {
    return _library.search(_searchController.text);
  }

  /// 搜索防抖：与乐曲查询页同款 1000ms。
  void _onSearchChanged(String query) {
    // 先刷一次「清除」按钮的显示状态（这个不涉及过滤，代价可忽略），
    // 真正的结果过滤走下面的防抖 —— 否则输了字、清除按钮要等 1 秒才出现。
    _safeSetState();
    _searchTimer?.cancel();
    if (query.trim().isEmpty) {
      // 清空输入框时立刻恢复完整列表，别让用户等 1 秒
      _applySearchNow();
      return;
    }
    _searchTimer = Timer(const Duration(milliseconds: 1000), _applySearchNow);
  }

  void _applySearchNow() {
    if (!mounted) return;
    setState(() {
      _filtered = _applyFilter(_all);
    });
  }

  // ── 通知权限 ────────────────────────────────────────────────────────────

  Future<void> _maybeAskNotification() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(CacheKeyConstant.portableNotificationAsked) == true) {
        return;
      }
      // Android 13 以下没有这个权限，request() 会直接返回 granted，无副作用
      var status = await Permission.notification.status;
      if (status.isDenied) {
        status = await Permission.notification.request();
      }
      await prefs.setBool(CacheKeyConstant.portableNotificationAsked, true);
      if (!mounted) return;
      // 用 !isGranted 而不是 isDenied：request() 的 Future 若在用户操作前就完成，
      // 返回的是「还没问」的初始状态（isDenied/isPermanentlyDenied 都为 false），
      // 那种情况下用户其实没有拒绝，不该报提示。
      if (!status.isGranted) {
        _showHint('未授予通知权限：音乐仍可后台播放，但不会显示通知栏播放器');
      }
    } catch (e) {
      debugPrint('[Portable] 申请通知权限失败: $e');
    }
  }

  // ── 交互 ────────────────────────────────────────────────────────────────

  Future<void> _onTapSong(PortableSong song) async {
    final index = _filtered.indexWhere((s) => s.lxnsId == song.lxnsId);
    if (index < 0) return;
    setState(() => _pendingLxnsId = song.lxnsId);
    try {
      // 音源就在这一步才被请求
      await _player.playQueue(_filtered, index);
    } finally {
      if (mounted) setState(() => _pendingLxnsId = null);
    }
  }

  void _onPlayerEvent(PortablePlayerEvent event) {
    if (!mounted) return;
    if (event.isError) {
      _showHint(event.message);
    }
  }

  void _showHint(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _openNowPlaying() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PortableNowPlayingPage()),
    );
  }

  /// 把「正在播放」那一行滚进视野（顶部栏的小定位按钮）。
  ///
  /// 定位用「行高估算 × 下标」：每行的内容是固定的（封面 44 + 上下 padding
  /// 8×2 + 分隔线 1），[_rowExtentOf] 按当前字体缩放算出同一个值。比
  /// `Scrollable.ensureVisible` 稳 —— 后者要求目标行**已经**被 build 出来，
  /// 而 1200 首的列表里目标行通常还在屏幕外。
  void _locateCurrentSong() {
    final current = _player.currentSong;
    if (current == null) return;
    var index = _filtered.indexWhere((s) => s.lxnsId == current.lxnsId);
    if (index < 0 && _searchController.text.isNotEmpty) {
      // 当前曲目被搜索过滤掉了：先清搜索，否则怎么找都找不到那一行
      _searchController.clear();
      _applySearchNow(); // 同步 setState 重建 _filtered
      index = _filtered.indexWhere((s) => s.lxnsId == current.lxnsId);
    }
    if (index < 0) {
      if (!_loading) _showHint('当前播放的曲目不在列表里');
      return;
    }
    if (!_listController.hasClients) return;
    final extent = _rowExtentOf(context);
    final position = _listController.position;
    // 让目标行落在视口上方 1/4 处，别贴着顶边
    final target = (index * extent - position.viewportDimension * 0.25)
        .clamp(0.0, position.maxScrollExtent);
    _listController.animateTo(
      target.toDouble(),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  /// 列表行的估算高度（= 定位时的步长）。
  ///
  /// 行高 = max(封面 44, 两行文字) + 上下 padding 8×2 + 分隔线 1。
  /// 默认字号下两行文字约 38 < 44，所以恒为 61，与列表里的实际行高一致；
  /// 系统字体放大后按缩放后的行高算，定位照样对得上（缩放会让默认字号那档
  /// 失效，所以才要跟着 [MediaQuery.textScalerOf] 走）。
  double _rowExtentOf(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final textHeight =
        scaler.scale(14.5) * 1.35 + 2 + scaler.scale(12) * 1.35;
    return math.max(44.0, textHeight) + 17;
  }

  // ── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    // 正在播放条改到底部之后，键盘（搜索时）会正好盖住它，所以底边距要把
    // 键盘高度也算进去一起顶起来（本页 `resizeToAvoidBottomInset: false`）。
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          CommonWidgetUtil.buildCommonBgWidget(),
          CommonWidgetUtil.buildCommonChiffonBgWidget(context),
          Column(
            children: [
              PageTopBar(
                title: '随身听',
                actions: [
                  IconButton(
                    icon: const Icon(Icons.my_location),
                    tooltip: '定位到正在播放',
                    onPressed: _player.hasSong ? _locateCurrentSong : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: '重建曲库',
                    onPressed: _loading ? null : () => _loadLibrary(force: true),
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppDesignTokens.maxContentWidth,
                    ),
                    child: Container(
                      margin: EdgeInsets.fromLTRB(
                        4,
                        0,
                        4,
                        10 + safeBottom + keyboard,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [AppColors.defaultShadow(theme.brightness)],
                      ),
                      child: Column(
                        children: [
                          _buildSearchBar(scheme),
                          Divider(
                            height: 1,
                            color: scheme.outlineVariant.withValues(alpha: 0.6),
                          ),
                          Expanded(child: _buildBody(scheme)),
                          // 「正在播放」钉在**最下面**：单手够得着进度条，
                          // 而且不再压着列表（原来贴顶要吃掉约 110px 的滚动高度）
                          if (_player.hasSong) ...[
                            Divider(
                              height: 1,
                              color:
                                  scheme.outlineVariant.withValues(alpha: 0.6),
                            ),
                            _buildCurrentBar(scheme),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          isDense: true,
          hintText: '搜索曲名 / 艺术家 / 流派 / 别名 / BPM / id',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    _searchTimer?.cancel();
                    _applySearchNow();
                  },
                ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
        ),
      ),
    );
  }

  /// 底部固定的「正在播放」条：点一下进全屏播放页，进度条可拖动。
  Widget _buildCurrentBar(ColorScheme scheme) {
    final song = _player.currentSong;
    if (song == null) return const SizedBox.shrink();
    return StreamBuilder<Duration>(
      // 进度条要跟着播放走（positionStream 约 200ms 一次）。
      // 只重建这一条，列表不受影响。
      stream: _player.positionStream,
      initialData: _player.position,
      builder: (context, snapshot) {
        final duration = _player.duration;
        final totalMs = duration?.inMilliseconds ?? 0;
        // 拖动中显示手指的位置，其余时候显示真实播放位置
        final shown = _dragValue != null && totalMs > 0
            ? Duration(milliseconds: (_dragValue! * totalMs).round())
            : (snapshot.data ?? Duration.zero);
        final value = totalMs > 0
            ? (shown.inMilliseconds / totalMs).clamp(0.0, 1.0)
            : 0.0;
        // 封面边长 = 右侧「曲名 + 状态 + 播放条」三行的总高。
        // 1.5 是这两档字号的行高比上限（实测本机字体 13→19.0 / 11→16.0，
        // 即 ≈1.46，取 1.5 留余量，免得字大的机型把列撑爆）；
        // 第三行（进度条 + 时间）固定 20；最后 6 由 spaceBetween 平分成两段行距。
        final scaler = MediaQuery.textScalerOf(context);
        final coverSide = math.max(
          52.0,
          scaler.scale(13) * 1.5 + scaler.scale(11) * 1.5 + 20 + 6,
        );
        return InkWell(
          onTap: _openNowPlaying,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: Row(
              children: [
                // 封面撑满右侧三行的高度；右边那一列被钉成同一个高度，
                // 用 `spaceBetween` 把三行铺开 —— 字号缩放时也对得上。
                SizedBox(
                  width: coverSide,
                  height: coverSide,
                  child: PortableCover(
                    song: song,
                    size: coverSide,
                    radius: 8,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: coverSide,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                        Text(
                          _player.isPlaying ? '正在播放' : '已暂停',
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.primary,
                          ),
                        ),
                        // 第三行：进度条 + 时间（高度定成 20，见 coverSide 的注释）
                        SizedBox(
                          height: 20,
                          child: Row(
                            children: [
                              Expanded(
                                child: SliderTheme(
                                  // 用主题里现成的配色，只把尺寸压扁到
                                  // 「进度条」的量级；padding 收紧是为了
                                  // 别把这一条撑成 48 高（拖拽命中区仍由
                                  // overlay 保证）。
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 3,
                                    thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 6,
                                    ),
                                    overlayShape:
                                        const RoundSliderOverlayShape(
                                      overlayRadius: 12,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                  ),
                                  child: Slider(
                                    value: value,
                                    onChanged: totalMs <= 0
                                        ? null
                                        : (v) =>
                                            setState(() => _dragValue = v),
                                    onChangeStart: totalMs <= 0
                                        ? null
                                        : (v) =>
                                            setState(() => _dragValue = v),
                                    onChangeEnd: totalMs <= 0
                                        ? null
                                        : (v) =>
                                            unawaited(_seekToFraction(v)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_fmtClock(shown)} / ${_fmtClock(duration)}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: scheme.onSurfaceVariant,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _player.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: scheme.primary,
                  ),
                  onPressed: () => _player.togglePlayPause(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 进度条松手 → 真正 seek。
  ///
  /// 顺序有讲究：松手时 `_dragValue` 还留着，先按它显示（防拇指闪回旧位置），
  /// 等 seek 落地再清掉、把显示权交还给 positionStream。
  Future<void> _seekToFraction(double fraction) async {
    final totalMs = _player.duration?.inMilliseconds ?? 0;
    if (totalMs <= 0) return;
    await _player.seek(Duration(milliseconds: (fraction * totalMs).round()));
    if (mounted) setState(() => _dragValue = null);
  }

  Widget _buildBody(ColorScheme scheme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _buildMessage(scheme, Icons.music_off, _error!);
    }
    if (_filtered.isEmpty) {
      return _buildMessage(
        scheme,
        Icons.search_off,
        _all.isEmpty ? '没有可播放的歌曲' : '没有匹配的歌曲',
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            controller: _listController,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: _filtered.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              indent: 68,
              color: scheme.outlineVariant.withValues(alpha: 0.4),
            ),
            itemBuilder: (context, index) => _buildRow(_filtered[index], scheme),
          ),
        ),
        _buildFooter(scheme),
      ],
    );
  }

  Widget _buildMessage(ColorScheme scheme, IconData icon, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(ColorScheme scheme) {
    final skipped = _library.skippedCount;
    final utage = _library.excludedUtageCount;
    final buffer = StringBuffer('共 ${_filtered.length} 首可播放');
    final notes = <String>[
      if (utage > 0) '已排除宴会场 $utage 首',
      if (skipped > 0) '水鱼无对应条目 $skipped 首',
    ];
    if (notes.isNotEmpty) {
      buffer.write(' · ${notes.join(' · ')}');
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Text(
        buffer.toString(),
        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
      ),
    );
  }

  Widget _buildRow(PortableSong song, ColorScheme scheme) {
    final current = _player.currentSong;
    final isCurrent = current != null && current.lxnsId == song.lxnsId;
    final isPending = _pendingLxnsId == song.lxnsId;

    return InkWell(
      onTap: () => _onTapSong(song),
      child: Container(
        color: isCurrent ? scheme.primary.withValues(alpha: 0.08) : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            PortableCover(song: song, size: 44, radius: 6),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight:
                                isCurrent ? FontWeight.w700 : FontWeight.w500,
                            color: isCurrent ? scheme.primary : scheme.onSurface,
                          ),
                        ),
                      ),
                      if (song.hasDx) ...[
                        const SizedBox(width: 6),
                        _badge('DX', scheme),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artist.isEmpty ? '未知艺术家' : song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 行内 loading：只在这一首「还在建源 / 还在缓冲」时转。
            // 别只看 `_player.isLoading` —— 见 playAt 的注释：`play()` 的
            // future 挂满整首歌，用它会出现「已经播了，右边还在转圈」。
            if (isPending ||
                (isCurrent && (_player.isLoading || _player.isBuffering)))
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
            else if (isCurrent && _player.isPlaying)
              Icon(Icons.graphic_eq, size: 22, color: scheme.primary)
            else
              Icon(
                Icons.play_circle_outline,
                size: 24,
                color: scheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  /// mm:ss。时长还不知道时给 `--:--`。
  static String _fmtClock(Duration? d) {
    if (d == null) return '--:--';
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
