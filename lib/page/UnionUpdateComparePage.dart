import 'package:flutter/material.dart';

import '../entity/DivingFish/Song.dart';
import '../manager/DivingFish/MaimaiMusicDataManager.dart';
import '../service/Union/UnionUpdateCompareService.dart';
import '../utils/AppTheme.dart';
import '../utils/CommonWidgetUtil.dart';
import '../utils/CoverUtil.dart';
import '../utils/SongFilterUtil.dart';
import '../utils/StringUtil.dart';
import '../widgets/PageTopBar.dart';
import 'SongInfoPage.dart';

/// 「国服更新对照」页：把本地曲库按**国服（水鱼）更新前沿**摆开，
/// 让用户一眼看到「日服已上、国服还没上」的歌 = 下次更新最可能补上的曲目。
///
/// 为什么需要这个页面：曲目详情页的「首次上线」是**日服**首发时间，
/// 国服玩家光看这个日期判断不出这首歌自己这边上了没有。本页先按筛选后的
/// 国服常规曲首发日期确定前沿，再用 id 区间整理 union 独有候选。
///
/// 口径与取舍全部写在 [UnionUpdateCompareService] 的类注释里；页面只负责展示，
/// 并在页内用「口径说明」弹窗把不确定性如实讲清楚（首发日期来自曲库元数据，
/// 不代表国服实际开放日期）。
///
/// 数据完全来自本地已合并曲库（`MaimaiMusicDataManager.getCachedSongs()`），
/// **不需要额外网络**：union 独有曲在合并时已经打了 `Song.isExtra` 标记。
class UnionUpdateComparePage extends StatefulWidget {
  const UnionUpdateComparePage({super.key, this.songsLoader});

  /// 仅供测试：替换曲库读取（widget 测试里没有真实缓存）。
  @visibleForTesting
  final Future<List<Song>?> Function()? songsLoader;

  @override
  State<UnionUpdateComparePage> createState() => _UnionUpdateComparePageState();
}

/// 列表分段：待上线 / 国服未收录的旧曲 / 宴会场 / 国服已上（含前沿）/ 超前上线。
enum _Section { upcoming, skipped, utage, cn, early }

class _UnionUpdateComparePageState extends State<UnionUpdateComparePage> {
  bool _loading = true;
  UnionUpdateCompare? _compare;
  _Section _section = _Section.upcoming;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loader =
        widget.songsLoader ?? () => MaimaiMusicDataManager().getCachedSongs();
    List<Song>? songs;
    try {
      songs = await loader();
    } catch (e) {
      debugPrint('[UnionUpdateCompare] 读取曲库失败: $e');
    }
    if (!mounted) return;
    setState(() {
      _compare = UnionUpdateCompareService.compare(songs ?? const []);
      _loading = false;
    });
  }

  List<Song> get _currentSongs {
    final compare = _compare;
    if (compare == null) return const [];
    switch (_section) {
      case _Section.upcoming:
        return compare.upcoming;
      case _Section.skipped:
        return compare.skipped;
      case _Section.utage:
        return compare.utage;
      case _Section.cn:
        return compare.cnSongs;
      case _Section.early:
        return compare.earlyReleases;
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          CommonWidgetUtil.buildCommonBgWidget(),
          CommonWidgetUtil.buildCommonChiffonBgWidget(context),
          Column(
            children: [
              PageTopBar(
                title: '国服更新对照',
                actions: [
                  IconButton(
                    tooltip: '口径说明',
                    icon: const Icon(Icons.info_outline),
                    onPressed: _showNotes,
                  ),
                ],
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : !(_compare?.hasData ?? false)
                        ? _buildEmpty(brightness)
                        : _buildBody(brightness),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 版本显示：**必须与曲目详情页同一个口径**。
  ///
  /// 详情页用的是 `formatVersion2WithFlag(from, isExtra)`；union 独有曲的
  /// `from` 是日服写法（`maimai でらっくす PRiSM PLUS`），而 `formatVersion`
  /// 不带 extra 标记时会把这类版本串判成"未知"、落到官方世代年号那一档 ——
  /// 表现就是同一个 id 在对照页显示 `DX 2026彩`、详情页显示 `PRiSM+ 彩`。
  static String _versionLabel(Song song) => StringUtil.formatVersion2WithFlag(
        song.basicInfo.from,
        SongFilterUtil.isExtra(song),
      );

  Widget _buildBody(Brightness brightness) {
    final compare = _compare!;
    final songs = _currentSongs;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildFrontierCard(brightness, compare),
                const SizedBox(height: 10),
                _buildSectionChips(brightness, compare),
                const SizedBox(height: 8),
                _buildSectionHint(brightness, compare),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
        if (songs.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  '这一段里没有曲目',
                  style: TextStyle(
                      fontSize: 12.5, color: AppColors.secondaryText(brightness)),
                ),
              ),
            ),
          )
        else
          SliverList.builder(
            itemCount: songs.length,
            itemBuilder: (context, index) =>
                _buildSongRow(brightness, songs[index], index + 1),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  /// 前沿卡片：国服（水鱼）当前最新曲 + 三方计数 + 一句话口径。
  Widget _buildFrontierCard(Brightness brightness, UnionUpdateCompare compare) {
    final frontier = compare.frontier;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_rounded,
                  size: 15, color: AppColors.warningOrange(brightness)),
              const SizedBox(width: 6),
              Text(
                '国服（水鱼）更新前沿',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryText(brightness),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (frontier != null)
            Text(
              '#${frontier.id}  ${frontier.basicInfo.title}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryText(brightness),
              ),
            ),
          if (frontier != null) ...[
            const SizedBox(height: 2),
            Text(
              '日服首发 ${_formatDate(frontier.basicInfo.releaseDate)}'
              ' · ${_versionLabel(frontier)}',
              style: TextStyle(
                  fontSize: 11.5, color: AppColors.secondaryText(brightness)),
            ),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                _countCell(brightness, 'union 全量', '${compare.unionSongCount}'),
                _countCell(brightness, '国服已上', '${compare.cnSongCount}'),
                _countCell(
                  brightness,
                  '待上线',
                  '${compare.upcoming.length}',
                  highlight: true,
                ),
                _countCell(brightness, '未收录',
                    '${compare.skipped.length}'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '「首次上线」显示的是**日服**首发时间，不是国服上线时间。'
            '前沿按国服常规曲中首发日期最新的一首确定；在此基础上，id 更大、'
            '又不在国服曲库里的，就是下次更新最可能补上的曲目。',
            style: TextStyle(
                fontSize: 11, height: 1.5, color: AppColors.secondaryText(brightness)),
          ),
          if (compare.earlyReleases.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '已排除 ${compare.earlyReleases.length} 首国服超前上线曲目'
              '（${compare.earlyReleases.map((s) => '#${s.id}').join(' ')}）'
              '—— 它们会把前沿顶高，让真正待补的曲子排不进候选。',
              style: TextStyle(
                  fontSize: 11,
                  height: 1.5,
                  color: AppColors.warningOrange(brightness)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _countCell(Brightness brightness, String label, String value,
      {bool highlight = false}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: highlight
                  ? AppColors.warningOrange(brightness)
                  : AppColors.primaryText(brightness),
            ),
          ),
          const SizedBox(height: 1),
          Text(label,
              style: TextStyle(
                  fontSize: 10.5, color: AppColors.secondaryText(brightness))),
        ],
      ),
    );
  }

  Widget _buildSectionChips(Brightness brightness, UnionUpdateCompare compare) {
    final chips = <(_Section, String, int)>[
      (_Section.upcoming, '下次更新候选', compare.upcoming.length),
      (_Section.skipped, '国服未收录旧曲', compare.skipped.length),
      (_Section.utage, '宴会场', compare.utage.length),
      // 注意标签与顶部计数不同名：顶部「国服已上」含水鱼宴会（1394），
      // 这一段只有常规曲（不含宴会），同名会让人以为数字对不上。
      (_Section.cn, '国服常规曲', compare.cnSongs.length),
      (_Section.early, '国服超前上线', compare.earlyReleases.length),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (section, label, count) in chips)
          ChoiceChip(
            label: Text('$label $count', style: const TextStyle(fontSize: 12)),
            selected: _section == section,
            onSelected: (_) => setState(() => _section = section),
          ),
      ],
    );
  }

  Widget _buildSectionHint(Brightness brightness, UnionUpdateCompare compare) {
    final String hint;
    switch (_section) {
      case _Section.upcoming:
        hint = compare.upcoming.isEmpty
            ? '国服已经追到日服最新曲了，暂时没有待上线的常规曲。'
            : '按 id 升序：越靠前表示日服上得越早，越可能先补进国服。'
                '${_versionSummary(compare)}';
      case _Section.skipped:
        hint = '这些曲 id 比国服最新曲还小、却不在国服曲库里，多半是区域限定或'
            '联动独占（也可能只是 id 顺序与上线顺序不完全一致）。';
      case _Section.utage:
        hint = '宴会场不随版本更新，列在这里仅供参考。';
      case _Section.cn:
        hint = '水鱼（国服）的常规曲，按首发日期从新到旧排列 —— 第一首就是本页的「更新前沿」。';
      case _Section.early:
        hint = '这些是**国服先于日服**上线的曲子：国服已经有了，id 却排在最新。'
            '它们不能当前沿（会把真正待补的那批顶出候选），所以单独列在这里。';
    }
    return Text(
      hint,
      style: TextStyle(
          fontSize: 11, height: 1.45, color: AppColors.secondaryText(brightness)),
    );
  }

  String _versionSummary(UnionUpdateCompare compare) {
    final parts = compare.upcomingByVersion;
    if (parts.length <= 1) return '';
    return '\n涉及版本：${parts.map((e) => '${StringUtil.formatVersion2WithFlag(e.version, true)} ${e.count} 首').join(' · ')}';
  }

  Widget _buildSongRow(Brightness brightness, Song song, int order) {
    final scheme = Theme.of(context).colorScheme;
    final isUpcoming = _section == _Section.upcoming;
    // 「国服已上」段按首发日期降序，第一行就是前沿 —— 这就是「在 union 全量源里
    // 标注出水鱼最新歌曲」的那一处标注。
    final isFrontierRow =
        _section == _Section.cn && order == 1 && song.id == _compare?.frontier?.id;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => SongInfoPage(songId: song.id),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isUpcoming
                  ? scheme.outlineVariant
                  : scheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            children: [
              if (isUpcoming || isFrontierRow)
                SizedBox(
                  width: 24,
                  child: isFrontierRow
                      ? Icon(Icons.flag_rounded,
                          size: 15,
                          color: AppColors.warningOrange(brightness))
                      : Text(
                          '$order',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondaryText(brightness),
                          ),
                        ),
                ),
              CoverUtil.buildCoverWidgetWithContextRRect(context, song.id, 44),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.basicInfo.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryText(brightness),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '#${song.id} · ${_versionLabel(song)}'
                      ' · 日服 ${_formatDate(song.basicInfo.releaseDate)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.secondaryText(brightness)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 18, color: AppColors.greyHint(brightness)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(Brightness brightness) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_rounded,
                size: 42, color: AppColors.greyHint(brightness)),
            const SizedBox(height: 12),
            Text(
              '曲库还没有缓存',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryText(brightness),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '本页的数据来自本地曲库（水鱼 + union）。\n'
              '请先在首页执行一次「刷新数据」，把曲库拉下来后再回来查看。',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12.5, color: AppColors.secondaryText(brightness)),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotes() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('这个页面的口径'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text('1. 数据来源', style: TextStyle(fontWeight: FontWeight.w700)),
              SizedBox(height: 4),
              Text(
                '本地曲库 = 水鱼（国服全量歌曲）+ union（全量歌曲）。'
                '合并时 union 独有的那批会打上 isExtra 标记，本页用的就是它。'
                '所以整个页面离线可用，与网络无关。',
                style: TextStyle(fontSize: 12.5, height: 1.5),
              ),
              SizedBox(height: 12),
              Text('2. 更新前沿怎么定', style: TextStyle(fontWeight: FontWeight.w700)),
              SizedBox(height: 4),
              Text(
                '先筛出水鱼曲库里的国服常规曲，再按首发日期从新到旧排列，第一首作为「国服最新」。'
                '日期缺失或格式异常时才回退到 id，所以这条前沿近似等于「国服已经追到哪」。\n'
                '宴会场（6 位 id）与 maidata 追加曲不参与判定。\n'
                '国服**超前上线**的曲目（国服先于日服上，id 却排最新）也不参与 —— '
                '它们会把前沿顶高，让真正待补的曲子排不进候选。',
                style: TextStyle(fontSize: 12.5, height: 1.5),
              ),
              SizedBox(height: 12),
              Text('3. 已知偏差', style: TextStyle(fontWeight: FontWeight.w700)),
              SizedBox(height: 4),
              Text(
                '「首发日期」来自曲库元数据，不代表国服实际开放日期：\n'
                '· union 独有但 id 更小的曲子会归到「国服未收录旧曲」，'
                '其中多数是区域限定/联动独占，也可能只是 id 顺序与上线顺序不一致；\n'
                '· 国服也可能一次补上多首，实际更新以官方公告为准。',
                style: TextStyle(fontSize: 12.5, height: 1.5),
              ),
              SizedBox(height: 12),
              Text('4. 「首次上线」是什么时间', style: TextStyle(fontWeight: FontWeight.w700)),
              SizedBox(height: 4),
              Text(
                '水鱼与 union 提供的首发日期都是**日服**时间，不是国服上线时间 —— '
                '这也是「曲目详情页显示首次上线、却看不出国服上没上」的原因。',
                style: TextStyle(fontSize: 12.5, height: 1.5),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  /// "20260220" → "2026-02-20"；拿不到就显示 '-'（不猜）。
  static String _formatDate(String raw) {
    if (raw.isEmpty) return '-';
    if (raw.length == 8) {
      return '${raw.substring(0, 4)}-${raw.substring(4, 6)}-${raw.substring(6, 8)}';
    }
    return raw;
  }
}
