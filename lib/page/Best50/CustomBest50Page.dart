import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../entity/DivingFish/Song.dart';
import '../../manager/DivingFish/MaimaiMusicDataManager.dart';
import '../../service/Best50/CustomBest50Store.dart';
import '../../service/Best50/DiffBest50Service.dart';
import '../../service/Best50/PersonalizedBest50ConvertToImgService.dart';
import '../../service/SongSearchService.dart';
import '../../utils/AppTheme.dart';
import '../../utils/ColorUtil.dart';
import '../../utils/CommonWidgetUtil.dart';
import '../../utils/CoverUtil.dart';
import '../../utils/ExportQualitySelector.dart';
import '../../utils/ImageEncodeUtil.dart';
import '../../utils/SongFilterUtil.dart';
import '../../utils/StringUtil.dart';
import '../../widgets/B50GameCardWidget.dart';
import '../../widgets/PageTopBar.dart';

/// 自定义 Best50 的一键排序方式。
enum _SortMode { raDesc, raAsc, dsDesc, dsAsc }

/// 自定义 Best50：手动录入最多 50 张成绩卡片（谱面可重复）。
///
/// 定数 / RA / 评级图 / 星数均由所选谱面与达成率自动计算。
/// 达成率可超过 101%、DX 分数可超过谱面上限（硬上限分别为 999.9999 / 9999），
/// 超上限的条目视为非法数据，在统计区与导出图片中以红字告警。
class CustomBest50Page extends StatefulWidget {
  const CustomBest50Page({super.key});

  @override
  State<CustomBest50Page> createState() => _CustomBest50PageState();
}

class _CustomBest50PageState extends State<CustomBest50Page> {
  static const double _achievementHardMax = 999.9999;
  static const int _dxScoreHardMax = 9999;

  final CustomBest50Store _store = CustomBest50Store();

  List<CustomBest50Entry?> _entries =
      List<CustomBest50Entry?>.filled(CustomBest50Store.slotCount, null);
  List<Song> _songs = [];
  List<dynamic> _maimaiMusicData = [];
  bool _isLoading = true;

  /// 一键排序后的排序状态标注；卡片发生变动时清除。
  String? _sortLabel;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _store.load();
    final songs = await MaimaiMusicDataManager().getCachedSongs() ?? <Song>[];
    if (!mounted) return;
    setState(() {
      _entries = List<CustomBest50Entry?>.of(_store.entries);
      _songs = songs;
      _maimaiMusicData = songs.map((s) => s.toJson()).toList();
      _isLoading = false;
    });
  }

  // ───────────────────────── 数据工具 ─────────────────────────

  Song? _findSong(int songId) {
    for (final s in _songs) {
      if (s.id == songId.toString()) return s;
    }
    return null;
  }

  List<CustomBest50Entry> get _filledEntries =>
      _entries.whereType<CustomBest50Entry>().toList();

  double _effectiveDs(CustomBest50Entry e) {
    final song = _findSong(e.songId);
    if (song != null && e.levelIndex >= 0 && e.levelIndex < song.ds.length) {
      return song.ds[e.levelIndex];
    }
    return e.ds;
  }

  String _effectiveLevel(CustomBest50Entry e) {
    final song = _findSong(e.songId);
    if (song != null && e.levelIndex >= 0 && e.levelIndex < song.level.length) {
      return song.level[e.levelIndex];
    }
    return e.level;
  }

  String _effectiveType(CustomBest50Entry e) {
    final song = _findSong(e.songId);
    return song?.type ?? e.type;
  }

  String _effectiveTitle(CustomBest50Entry e) {
    final song = _findSong(e.songId);
    return song?.basicInfo.title ?? e.title;
  }

  int _singleMaxScore(Song? song, int levelIndex) {
    if (song == null) return 0;
    if (levelIndex < 0 || levelIndex >= song.charts.length) return 0;
    final notes = song.charts[levelIndex].notes;
    return notes.fold<int>(0, (sum, n) => sum + n) * 3;
  }

  /// 卡片显示用的当前难度满分（与 PersonalizedBest50Page 一致）。
  int _cardMaxScore(CustomBest50Entry e) =>
      _singleMaxScore(_findSong(e.songId), e.levelIndex);

  /// 判定/星数用的 DX 满分：宴会场（ds 长度 2）取两个难度之和。
  int _maxDxScore(CustomBest50Entry e) {
    final song = _findSong(e.songId);
    if (song == null) return 0;
    if (song.ds.length == 2) {
      return _singleMaxScore(song, 0) + _singleMaxScore(song, 1);
    }
    return _singleMaxScore(song, e.levelIndex);
  }

  int _raOf(CustomBest50Entry e) =>
      DiffBest50Service().calculateSingleRating(_effectiveDs(e), e.achievements);

  /// 达成率上限：普通曲 101%；宴会场（6 位 id）内部多张子谱相加，
  /// 上限 = 101 × 谱面数（2 个谱面即 202%），与 SongInfoPage 的口径一致。
  double _maxAchievementFor(Song? song) {
    if (song == null || song.id.length != 6) return 101.0;
    final count = song.ds.length;
    return count <= 1 ? 101.0 : 101.0 * count;
  }

  /// 非法数据：达成率超过谱面上限，或 DX 分数超过谱面上限。
  bool _isIllegal(CustomBest50Entry e) {
    if (e.achievements > _maxAchievementFor(_findSong(e.songId))) return true;
    final maxDx = _maxDxScore(e);
    return maxDx > 0 && e.dxScore > maxDx;
  }

  int get _illegalCount => _filledEntries.where(_isIllegal).length;

  String? get _warningText {
    final count = _illegalCount;
    if (count <= 0) return null;
    return '⚠ 存在 $count 条非法数据（达成率或 DX 分数超过谱面上限）';
  }

  // ───────────────────────── 编辑弹窗 ─────────────────────────

  /// 选曲底部面板：搜索逻辑复用 SongSearchPage（歌名/ID/曲师/谱师/流派/版本/别名/BPM）。
  Future<Song?> _showSongPicker() async {
    var query = '';
    var results = <Song>[];
    var searching = false;
    Timer? debounce;

    try {
      return await showModalBottomSheet<Song>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetCtx) => StatefulBuilder(
          builder: (ctx, setSheetState) {
            final brightness = Theme.of(ctx).brightness;
            final scheme = Theme.of(ctx).colorScheme;
            final q = query.trim();
            final filtered = q.isEmpty ? _songs : results;

            Future<void> runSearch(String value) async {
              final r = await SongSearchService.searchSongs(value);
              if (!ctx.mounted || value != query) return;
              setSheetState(() {
                results = r;
                searching = false;
              });
            }

            return SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.82,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: TextField(
                      autofocus: false,
                      decoration: const InputDecoration(
                        hintText: '歌名/BPM/谱师/曲师/别名/歌曲ID/...',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) {
                        debounce?.cancel();
                        setSheetState(() {
                          query = v;
                          searching = v.trim().isNotEmpty;
                          if (v.trim().isEmpty) results = [];
                        });
                        if (v.trim().isEmpty) return;
                        debounce = Timer(
                          const Duration(milliseconds: 500),
                          () => runSearch(v),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: searching
                        ? const Center(child: CircularProgressIndicator())
                        : filtered.isEmpty
                            ? Center(
                                child: Text(
                                  q.isEmpty ? '暂无歌曲数据' : '未找到匹配的歌曲',
                                  style:
                                      TextStyle(color: scheme.onSurfaceVariant),
                                ),
                              )
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (_, i) =>
                                    _buildPickerRow(ctx, filtered[i], brightness),
                              ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    } finally {
      debounce?.cancel();
    }
  }

  Widget _buildPickerRow(BuildContext ctx, Song song, Brightness brightness) {
    final bool isUtage = song.id.length == 6;
    final String typeLabel =
        isUtage ? 'UTAGE' : (song.type == 'SD' ? 'ST' : 'DX');
    final Color typeColor = isUtage
        ? const Color(0xFFFF6B8B)
        : (song.type == 'SD'
            ? AppColors.linkBlue(brightness)
            : AppColors.warningOrange(brightness));

    const double nameFontSize = 16.0;

    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: CoverUtil.buildCoverWidget(song.id, 44),
      ),
      title: Row(
        children: [
          Text(
            typeLabel,
            style: TextStyle(
              fontSize: nameFontSize,
              fontWeight: FontWeight.bold,
              color: typeColor,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              song.basicInfo.title,
              style: const TextStyle(fontSize: nameFontSize),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      subtitle: Text(
        // extra 曲目（宴会场 / maidata 追加 / union 独有）没有国服世代年号
        '${song.basicInfo.artist} · '
        '${StringUtil.formatVersion2WithFlag(song.basicInfo.from, SongFilterUtil.isExtra(song))}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => Navigator.pop(ctx, song),
    );
  }

  Future<void> _showEditSheet(int index) async {
    final existing = _entries[index];

    Song? song = existing != null ? _findSong(existing.songId) : null;
    int levelIndex = existing?.levelIndex ?? 3;
    double? achievements = existing?.achievements;
    int? dxScore = existing?.dxScore;
    String fc = existing?.fc ?? '';
    String fs = existing?.fs ?? '';
    // 谱面在曲库中找不到时，用已保存的快照兜底
    final String snapshotTitle = existing?.title ?? '';
    final double snapshotDs = existing?.ds ?? 0.0;
    final String snapshotLevel = existing?.level ?? '';
    final String snapshotType = existing?.type ?? '';

    String effectiveTitle() => song?.basicInfo.title ?? snapshotTitle;

    String effectiveLevel() {
      if (song != null && levelIndex < song!.level.length) {
        return song!.level[levelIndex];
      }
      return snapshotLevel;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final scheme = Theme.of(ctx).colorScheme;
          final ds = song != null
              ? (levelIndex < song!.ds.length ? song!.ds[levelIndex] : 0.0)
              : snapshotDs;
          final int maxDx = (song != null && song!.ds.length == 2)
              ? _singleMaxScore(song, 0) + _singleMaxScore(song, 1)
              : _singleMaxScore(song, levelIndex);
          final double maxAchievement = _maxAchievementFor(song);
          final achievementIllegal =
              achievements != null && achievements! > maxAchievement;
          final dxIllegal = dxScore != null && maxDx > 0 && dxScore! > maxDx;

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 4,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '第 ${index + 1} 格',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 歌曲
                  InkWell(
                    onTap: () async {
                      final picked = await _showSongPicker();
                      if (picked == null || !sheetCtx.mounted) return;
                      setSheetState(() {
                        song = picked;
                        // 新曲目默认 Master（第 4 个难度），不足则取最高难度
                        levelIndex = picked.charts.length > 3 ? 3 : 0;
                        if (levelIndex >= picked.ds.length) levelIndex = 0;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: scheme.outline),
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12.0, vertical: 8.0),
                      child: Row(
                        children: [
                          // 已选歌曲曲绘
                          if (song != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4.0),
                              child: CoverUtil.buildCoverWidget(song!.id, 40),
                            )
                          else
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                              child: Icon(Icons.music_note,
                                  size: 22, color: scheme.onSurfaceVariant),
                            ),
                          const SizedBox(width: 10.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('歌曲',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: scheme.onSurfaceVariant)),
                                Text(
                                  effectiveTitle().isEmpty
                                      ? '未选择'
                                      : effectiveTitle(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 16, color: scheme.onSurface),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              color: scheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 难度
                  if (song != null) ...[
                    Text('难度',
                        style: TextStyle(
                            fontSize: 13, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (var i = 0; i < song!.charts.length; i++)
                          ChoiceChip(
                            label: Text(_difficultyName(i)),
                            selected: levelIndex == i,
                            onSelected: (_) =>
                                setSheetState(() => levelIndex = i),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_difficultyName(levelIndex)} · '
                      '${effectiveLevel().isEmpty ? '?' : effectiveLevel()} · '
                      '定数 ${ds.toStringAsFixed(1)}',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    Text('请先选择歌曲',
                        style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 12),
                  ],

                  // 达成率 / DX 分数
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _NumberInputField(
                          label: '达成率 (%)',
                          hint: '如 100.5',
                          initial: existing?.achievements.toString(),
                          hardMax: _achievementHardMax,
                          helperText: '上限 ${maxAchievement.toStringAsFixed(0)}%',
                          onChanged: (v) => setSheetState(() => achievements = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _NumberInputField(
                          label: 'DX 分数',
                          hint: '如 3000',
                          initial: existing?.dxScore.toString(),
                          hardMax: _dxScoreHardMax.toDouble(),
                          helperText: maxDx > 0 ? '上限 $maxDx' : null,
                          onChanged: (v) => setSheetState(
                              () => dxScore = v?.round()),
                        ),
                      ),
                    ],
                  ),
                  if (achievementIllegal)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '非法数据：达成率超过 ${maxAchievement.toStringAsFixed(0)}%',
                        style: TextStyle(
                            fontSize: 12,
                            color: scheme.error,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  if (dxIllegal)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '非法数据：DX 分数超过谱面上限 $maxDx',
                        style: TextStyle(
                            fontSize: 12,
                            color: scheme.error,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  const SizedBox(height: 12),

                  // FC / FS
                  _buildChoiceRow(
                    ctx,
                    label: '连击',
                    options: const ['', 'fc', 'fcp', 'ap', 'app'],
                    current: fc,
                    labelOf: (v) => v.isEmpty ? '无' : StringUtil.formatFC(v),
                    onPick: (v) => setSheetState(() => fc = v),
                  ),
                  const SizedBox(height: 8),
                  _buildChoiceRow(
                    ctx,
                    label: '同步',
                    options: const ['', 'fs', 'fsp', 'fsd', 'fsdp', 'sync'],
                    current: fs,
                    labelOf: (v) => v.isEmpty
                        ? '无'
                        : (v == 'sync' ? 'SYNC' : StringUtil.formatFS(v)),
                    onPick: (v) => setSheetState(() => fs = v),
                  ),
                  const SizedBox(height: 12),

                  // RA 预览
                  if (achievements != null && ds > 0)
                    Text(
                      'RA：${DiffBest50Service().calculateSingleRating(ds, achievements!)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurface,
                      ),
                    ),
                  const SizedBox(height: 12),

                  // 动作按钮
                  Row(
                    children: [
                      if (existing != null)
                        TextButton(
                          onPressed: () async {
                            await _store.setEntry(index, null);
                            if (!mounted) return;
                            setState(() {
                              _entries = List<CustomBest50Entry?>.of(_store.entries);
                              _sortLabel = null;
                            });
                            if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                          },
                          child: Text('清空本卡',
                              style: TextStyle(color: scheme.error)),
                        ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(sheetCtx),
                        child: const Text('取消'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () async {
                          if (song == null && snapshotTitle.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('请先选择歌曲')),
                            );
                            return;
                          }
                          if (achievements == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('请输入达成率')),
                            );
                            return;
                          }
                          final entry = CustomBest50Entry(
                            songId: song != null
                                ? int.tryParse(song!.id) ?? 0
                                : existing?.songId ?? 0,
                            title: effectiveTitle(),
                            type: song?.type ?? snapshotType,
                            levelIndex: levelIndex,
                            level: effectiveLevel(),
                            ds: ds,
                            achievements: achievements!,
                            dxScore: dxScore ?? 0,
                            fc: fc,
                            fs: fs,
                          );
                          await _store.setEntry(index, entry);
                          if (!mounted) return;
                          setState(() {
                            _entries = List<CustomBest50Entry?>.of(_store.entries);
                            _sortLabel = null;
                          });
                          if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                        },
                        child: const Text('保存'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChoiceRow(
    BuildContext ctx, {
    required String label,
    required List<String> options,
    required String current,
    required String Function(String) labelOf,
    required ValueChanged<String> onPick,
  }) {
    final scheme = Theme.of(ctx).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 36,
          child: Text(label,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
        ),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final v in options)
                ChoiceChip(
                  label: Text(labelOf(v)),
                  selected: current == v,
                  onSelected: (_) => onPick(v),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static String _difficultyName(int index) {
    const names = ['BASIC', 'ADVANCED', 'EXPERT', 'MASTER', 'Re:MASTER'];
    if (index < 0 || index >= names.length) return '难度$index';
    return names[index];
  }

  // ───────────────────────── 一键排序 ─────────────────────────

  static String _sortLabelOf(_SortMode mode) {
    switch (mode) {
      case _SortMode.raDesc:
        return 'RA 降序';
      case _SortMode.raAsc:
        return 'RA 升序';
      case _SortMode.dsDesc:
        return '定数 降序';
      case _SortMode.dsAsc:
        return '定数 升序';
    }
  }

  static IconData _sortIconOf(_SortMode mode) {
    switch (mode) {
      case _SortMode.raDesc:
      case _SortMode.dsDesc:
        return Icons.arrow_downward_rounded;
      case _SortMode.raAsc:
      case _SortMode.dsAsc:
        return Icons.arrow_upward_rounded;
    }
  }

  Future<void> _showSortDialog() async {
    if (_filledEntries.isEmpty) {
      _showMessage('提示', '还没有填写任何卡片');
      return;
    }
    final mode = await showModalBottomSheet<_SortMode>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final m in _SortMode.values)
              ListTile(
                leading: Icon(_sortIconOf(m)),
                title: Text('按${_sortLabelOf(m)}'),
                onTap: () => Navigator.pop(ctx, m),
              ),
          ],
        ),
      ),
    );
    if (mode == null) return;
    await _applySort(mode);
  }

  Future<void> _applySort(_SortMode mode) async {
    final filled = _filledEntries;
    if (filled.isEmpty) return;

    int compare(CustomBest50Entry a, CustomBest50Entry b) {
      switch (mode) {
        case _SortMode.raDesc:
          final c = _raOf(b).compareTo(_raOf(a));
          return c != 0 ? c : _effectiveDs(b).compareTo(_effectiveDs(a));
        case _SortMode.raAsc:
          final c = _raOf(a).compareTo(_raOf(b));
          return c != 0 ? c : _effectiveDs(a).compareTo(_effectiveDs(b));
        case _SortMode.dsDesc:
          final c = _effectiveDs(b).compareTo(_effectiveDs(a));
          return c != 0 ? c : _raOf(b).compareTo(_raOf(a));
        case _SortMode.dsAsc:
          final c = _effectiveDs(a).compareTo(_effectiveDs(b));
          return c != 0 ? c : _raOf(a).compareTo(_raOf(b));
      }
    }

    filled.sort(compare);

    final newEntries =
        List<CustomBest50Entry?>.filled(CustomBest50Store.slotCount, null);
    for (int i = 0; i < filled.length; i++) {
      newEntries[i] = filled[i];
    }
    await _store.setEntries(newEntries);
    if (!mounted) return;
    setState(() {
      _entries = List<CustomBest50Entry?>.of(_store.entries);
      _sortLabel = _sortLabelOf(mode);
    });
  }

  // ───────────────────────── 导出 ─────────────────────────

  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      final storage = await Permission.storage.status;
      final photos = await Permission.photos.status;
      final videos = await Permission.videos.status;
      if (storage.isGranted || photos.isGranted || videos.isGranted) {
        return true;
      }
      final statuses = await [
        Permission.storage,
        Permission.photos,
        Permission.videos,
      ].request();
      return (statuses[Permission.storage]?.isGranted ?? false) ||
          (statuses[Permission.photos]?.isGranted ?? false) ||
          (statuses[Permission.videos]?.isGranted ?? false);
    }
    final status = await Permission.storage.request();
    return status.isGranted;
  }

  List<Map<String, dynamic>> _buildExportMaps() {
    final maps = <Map<String, dynamic>>[];
    for (final e in _filledEntries) {
      final ds = _effectiveDs(e);
      maps.add({
        'song_id': e.songId,
        'title': _effectiveTitle(e),
        'type': _effectiveType(e),
        'level_index': e.levelIndex,
        'level': _effectiveLevel(e),
        'ds': ds,
        'achievements': e.achievements,
        'dxScore': e.dxScore,
        'fc': e.fc,
        'fs': e.fs,
        'rate': StringUtil.rateCodeFromAchievement(e.achievements),
        'ra': _raOf(e),
      });
    }
    return maps;
  }

  Future<void> _exportToImage() async {
    if (_filledEntries.isEmpty) {
      _showMessage('提示', '没有数据可导出');
      return;
    }

    final hasPermission = await _requestStoragePermission();
    if (!mounted) return;
    if (!hasPermission) {
      _showMessage('权限不足', '需要存储权限才能导出图片到相册，请在设置中开启权限');
      return;
    }

    final quality = await ExportQualitySelector.show(
      context,
      estimatedPngSize: ImageEncodeUtil.estimatePngSize(
        songCount: _filledEntries.length,
      ),
    );
    if (!mounted || quality == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text('导出中'),
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16.0),
            Text('正在生成图片...'),
          ],
        ),
      ),
    );

    try {
      final file = await PersonalizedB50ConvertToImg.convertToImage(
        context,
        '自定义 Best50',
        _buildExportMaps(),
        _maimaiMusicData,
        jpegQuality: quality.jpegQuality,
        warningText: _warningText,
        sortLabel: _sortLabel,
      );

      if (!mounted) return;
      Navigator.pop(context); // 关闭进度弹窗

      if (file != null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('导出成功'),
            content: Text('图片已保存到：\n${file.path}'),
            actions: [
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: file.path));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('路径已复制到剪贴板')),
                    );
                  }
                },
                child: const Text('复制路径'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      } else {
        _showMessage('导出失败', '图片导出失败，请重试');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showMessage('导出失败', '导出过程中出现错误：\n$e');
      }
    }
  }

  void _showMessage(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearAll() async {
    if (_filledEntries.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空全部'),
        content: const Text('确定要清空全部 50 个卡位吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('清空',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _store.clearAll();
    if (!mounted) return;
    setState(() {
      _entries = List<CustomBest50Entry?>.of(_store.entries);
      _sortLabel = null;
    });
  }

  // ───────────────────────── 构建 ─────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final brightness = Theme.of(context).brightness;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    const borderRadiusSmall = 8.0;

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
                title: '自定义 Best50',
              ),
              Expanded(
                child: Container(
                  margin: EdgeInsets.fromLTRB(4, 0, 4, 10 + safeBottom),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surface
                        .withOpacity(0.9),
                    borderRadius: BorderRadius.circular(borderRadiusSmall),
                    boxShadow: [AppColors.defaultShadow(brightness)],
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(
                        MediaQuery.of(context).size.width * 0.03),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildStatsSection(),
                        const SizedBox(height: 12.0),
                        _buildActionButtons(),
                        const SizedBox(height: 12.0),
                        _buildGrid(),
                      ],
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

  Widget _buildStatsSection() {
    final filled = _filledEntries;
    final int totalSongs = filled.length;
    final int totalRa =
        filled.fold<int>(0, (sum, e) => sum + _raOf(e));
    final double averageRa = totalSongs > 0 ? totalRa / totalSongs : 0.0;
    final double totalAchievement =
        filled.fold<double>(0.0, (sum, e) => sum + e.achievements);
    final double averageAchievement =
        totalSongs > 0 ? totalAchievement / totalSongs : 0.0;
    final warning = _warningText;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
            color: Theme.of(context).colorScheme.onSurface, width: 2.0),
        borderRadius: BorderRadius.circular(8.0),
      ),
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '自定义 Best50 统计',
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.width * 0.045,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8.0),
          Row(
            children: [
              _statColumn('已填写', '$totalSongs / ${CustomBest50Store.slotCount}'),
              _statColumn('总RA值', '$totalRa'),
              _statColumn('平均RA值', averageRa.toStringAsFixed(1)),
              _statColumn('平均达成率', '${averageAchievement.toStringAsFixed(2)}%'),
            ],
          ),
          if (_sortLabel != null) ...[
            const SizedBox(height: 8.0),
            Text(
              '当前排序：$_sortLabel（卡片变动后自动清除）',
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width * 0.034,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
          if (warning != null) ...[
            const SizedBox(height: 10.0),
            Text(
              warning,
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width * 0.034,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statColumn(String label, String value) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: MediaQuery.of(context).size.width * 0.033,
                  color: onSurface)),
          Text(value,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: MediaQuery.of(context).size.width * 0.037,
                  fontWeight: FontWeight.bold,
                  color: onSurface)),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final brightness = Theme.of(context).brightness;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _exportToImage,
                icon: const Icon(Icons.image_outlined, color: Colors.white),
                label: const Text('导出为图片',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.linkBlue(brightness),
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _confirmClearAll,
                icon: Icon(Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error),
                label: Text('清空全部',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8.0),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showSortDialog,
            icon: const Icon(Icons.sort_rounded),
            label: const Text('一键排序'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGrid() {
    final int maxIdLength = _entries
        .whereType<CustomBest50Entry>()
        .map((e) => e.songId.toString().length)
        .fold<int>(5, (a, b) => a > b ? a : b);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: MediaQuery.of(context).size.width * 0.01,
        mainAxisSpacing: MediaQuery.of(context).size.width * 0.01,
        childAspectRatio: B50GameCardWidget.designAspectRatio,
      ),
      itemCount: CustomBest50Store.slotCount,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        if (entry == null) {
          return _buildEmptySlot(index);
        }
        return GestureDetector(
          onTap: () => _showEditSheet(index),
          child: _buildEntryCard(entry, maxIdLength),
        );
      },
    );
  }

  Widget _buildEmptySlot(int index) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(8.0),
      onTap: () => _showEditSheet(index),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant, width: 2.0),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline,
                size: 28, color: scheme.onSurfaceVariant),
            const SizedBox(height: 4),
            Text('点击填写',
                style: TextStyle(
                    fontSize: 13, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryCard(CustomBest50Entry entry, int maxIdLength) {
    final songId = entry.songId;
    final isUtage = songId.toString().length == 6;
    final cardColor =
        isUtage ? AppColors.utageCard() : ColorUtil.getCardColor(entry.levelIndex);
    final maxScore = _cardMaxScore(entry);
    final maxDx = _maxDxScore(entry);
    final scoreRate = maxDx > 0 ? entry.dxScore / maxDx : 0.0;
    final stars = StringUtil.formatStars(scoreRate);
    final starsColor = ColorUtil.getStarsColor(stars);
    final isIllegal = _isIllegal(entry);

    final card = B50GameCardWidget(
      cardColor: cardColor,
      songName: _effectiveTitle(entry),
      achievementRate: entry.achievements,
      difficulty: _effectiveDs(entry),
      dxMode: _effectiveType(entry) == 'DX',
      isUtage: isUtage,
      score: entry.dxScore,
      maxScore: maxScore,
      rating: _raOf(entry),
      stars: stars,
      fc: entry.fc,
      fs: entry.fs,
      rate: StringUtil.rateCodeFromAchievement(entry.achievements),
      songId: songId,
      starsColor: starsColor,
      maxIdLength: maxIdLength,
      // 字号按卡片**实际**宽度自适应：别拿屏幕宽度估（容器 padding /
      // 网格间距都会从可用宽里扣掉）。
      scale: B50GameCardWidget.autoScale,
    );

    if (!isIllegal) return card;

    // 非法条目：加红色描边便于定位（统计区/导出图另有红字告警）
    return Stack(
      fit: StackFit.expand,
      children: [
        card,
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                  color: Theme.of(context).colorScheme.error, width: 3.0),
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ),
      ],
    );
  }
}

/// 带硬上限校验的数字输入框。
///
/// 超过 [hardMax] 直接拒绝输入并提示；解析成功的值通过 [onChanged] 回传。
/// 是否属于"非法数据"（如达成率 > 101%）由调用方判断并另行提示。
class _NumberInputField extends StatefulWidget {
  final String label;
  final String hint;
  final String? initial;
  final double hardMax;
  final String? helperText;
  final ValueChanged<double?> onChanged;

  const _NumberInputField({
    required this.label,
    required this.hint,
    required this.initial,
    required this.hardMax,
    required this.onChanged,
    this.helperText,
  });

  @override
  State<_NumberInputField> createState() => _NumberInputFieldState();
}

class _NumberInputFieldState extends State<_NumberInputField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial ?? '');
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleChanged(String raw) {
    final t = raw.trim();
    if (t.isEmpty) {
      setState(() => _error = null);
      widget.onChanged(null);
      return;
    }
    final v = double.tryParse(t);
    if (v == null) {
      setState(() => _error = '请输入数字');
      return;
    }
    if (v < 0) {
      setState(() => _error = '不能为负数');
      return;
    }
    if (v > widget.hardMax) {
      setState(() => _error = '不得超过 ${_formatMax(widget.hardMax)}');
      return;
    }
    setState(() => _error = null);
    widget.onChanged(v);
  }

  static String _formatMax(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        helperText: widget.helperText,
        helperStyle: TextStyle(
          fontSize: 11,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        errorText: _error,
        errorStyle: const TextStyle(fontSize: 11),
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      onChanged: _handleChanged,
    );
  }
}
