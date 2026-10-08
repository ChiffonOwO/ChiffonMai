import 'package:flutter/material.dart';
import '../../utils/KaleidDateUtil.dart';

import 'package:my_first_flutter_app/entity/DivingFish/Song.dart';
import 'package:my_first_flutter_app/entity/KaleidXScope/KaleidXScopeGate.dart';
import 'package:my_first_flutter_app/manager/DivingFish/MaimaiMusicDataManager.dart';
import 'package:my_first_flutter_app/page/SongInfoPage.dart';
import 'package:my_first_flutter_app/service/KaleidXScope/KaleidXScopeGateService.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:my_first_flutter_app/utils/CoverUtil.dart';
import 'package:my_first_flutter_app/utils/StringUtil.dart';
import 'package:my_first_flutter_app/widgets/BackgroundPageScaffold.dart';
import 'package:my_first_flutter_app/widgets/KaleidXScopeSourceNotice.dart';

/// 新增门页。布局与青门至红门的攻略页保持一致，数据由门接口提供。
class KaleidXScopeGatePage extends StatefulWidget {
  final String color;
  final String title;

  const KaleidXScopeGatePage({
    super.key,
    required this.color,
    required this.title,
  });

  @override
  State<KaleidXScopeGatePage> createState() => _KaleidXScopeGatePageState();
}

class _KaleidXScopeGatePageState extends State<KaleidXScopeGatePage> {
  KaleidXScopeGate? _gateData;
  Map<int, Song> _songMap = {};
  bool _isLoading = true;
  String? _error;

  late double _borderRadiusSmall;

  late double _paddingXS;
  late double _paddingS;
  late double _paddingM;
  late double _paddingL;
  late double _textSizeXS;
  late double _textSizeS;
  late double _textSizeM;
  late double _textSizeL;
  late double _textSizeXL;
  late double _coverSize;
  late double _progressBarHeight;

  Color get _accent {
    switch (widget.color) {
      case 'prism':
        return const Color(0xFF0891B2);
      case 'error':
        return const Color(0xFF8B5CF6);
      case 'hope':
        return const Color(0xFFD97706);
      case 'final':
        return const Color(0xFF7C3AED);
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  String get _asset {
    switch (widget.color) {
      case 'prism':
        return 'assets/kaleidxscope/prism.png';
      case 'hope':
        return 'assets/kaleidxscope/hope.png';
      case 'final':
        return 'assets/kaleidxscope/final.png';
      default:
        return 'assets/kaleidxscope/black.webp';
    }
  }

  String _getGateTitle() {
    switch (widget.color) {
      case 'prism':
        return '棱镜塔详情';
      case 'error':
        return '乱码之门详情';
      case 'hope':
        return '希望之门详情';
      case 'final':
        return '最终相详情';
      default:
        return widget.title;
    }
  }

  void _initSizeParams(BuildContext context) {
    final scaleFactor = MediaQuery.of(context).size.width / 375.0;
    _borderRadiusSmall = 8.0 * scaleFactor;

    _paddingXS = 4.0 * scaleFactor;
    _paddingS = 4.0 * scaleFactor;
    _paddingM = 12.0 * scaleFactor;
    _paddingL = 10.0 * scaleFactor;
    _textSizeXS = 9.0 * scaleFactor;
    _textSizeS = 11.0 * scaleFactor;
    _textSizeM = 12.0 * scaleFactor;
    _textSizeL = 14.0 * scaleFactor;
    _textSizeXL = 16.0 * scaleFactor;
    _coverSize = 40.0 * scaleFactor;
    _progressBarHeight = 24.0 * scaleFactor;
  }


  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final gate = await KaleidXScopeGateService().fetchGate(widget.color);
      final catalog = await MaimaiMusicDataManager().getCachedSongs();
      if (!mounted) return;
      setState(() {
        _gateData = gate;
        _songMap = {
          for (final song in catalog ?? <Song>[])
            if (int.tryParse(song.id) != null) int.parse(song.id): song,
        };
      });
    } catch (e) {
      if (mounted) setState(() => _error = '攻略加载失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<int> _trackIds(String key) => _gateData?.songs[key] ?? const <int>[];

  List<int> get _allIds => {
        ..._trackIds('track1'),
        ..._trackIds('track2'),
        ..._trackIds('track3'),
      }.toList();

  String _getTypeDisplay(String type) {
    switch (type.toLowerCase()) {
      case 'dx':
        return 'DX';
      case 'standard':
      case 'sd':
        return 'ST';
      default:
        return type;
    }
  }

  String _getDsDisplay(List<double> ds) {
    String valueAt(int index) =>
        ds.length > index ? ds[index].toStringAsFixed(1) : '-';
    return '${valueAt(2)} / ${valueAt(3)} / ${valueAt(4)}';
  }

  Color _getDifficultyColor(String type) {
    switch (type.toUpperCase()) {
      case 'BASIC':
        return Colors.green;
      case 'ADVANCED':
        return Colors.blue;
      case 'EXPERT':
        return Colors.red;
      case 'MASTER':
      case 'RE:MASTER':
        return Colors.purple;
      default:
        return _accent;
    }
  }

  Widget _buildUnlockSection() {
    final brightness = Theme.of(context).brightness;
    final muted = AppColors.greyHint(brightness);
    final gate = _gateData!;
    final bodyStyle = TextStyle(fontSize: _textSizeS, color: muted);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(_borderRadiusSmall),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      padding: EdgeInsets.all(_paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('解锁方法',
              style:
                  TextStyle(fontSize: _textSizeL, fontWeight: FontWeight.bold)),
          SizedBox(height: _paddingS),
          Text(gate.doorName ?? gate.displayName ?? widget.title,
              style: TextStyle(
                  fontSize: _textSizeM,
                  fontWeight: FontWeight.bold,
                  color: _accent)),
          RichText(
            text: TextSpan(
              style: bodyStyle,
              children: [
                TextSpan(
                    text: gate.prerequisite ?? '（未设置）',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const TextSpan(text: '（门扉必要条件）'),
              ],
            ),
          ),
          SizedBox(height: _paddingS),
          Text('钥匙（挑战所需的物品）',
              style: TextStyle(
                  fontSize: _textSizeM,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[700])),
          if (gate.keyRequirement?.isNotEmpty == true)
            Text(gate.keyRequirement!, style: bodyStyle),
          if (gate.guideNote?.isNotEmpty == true)
            Text(gate.guideNote!, style: bodyStyle),
          SizedBox(height: _paddingS),
          Text('KALEIDXSCOPE模式',
              style: TextStyle(
                  fontSize: _textSizeM,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple[700])),
          Text('第一首：${gate.track1Desc ?? "（未设置）"}', style: bodyStyle),
          if (gate.track2Desc != null)
            Text('第二首：${gate.track2Desc}', style: bodyStyle),
          if (gate.track3Desc != null)
            Text('第三首：${gate.track3Desc}', style: bodyStyle),
          for (final special in gate.specialSongs) ...[
            SizedBox(height: _paddingS),
            Text(
                '${special.role == 'perfect' ? '完美挑战曲' : special.role == 'reward' ? '通关解锁歌曲' : '隐藏歌曲'}为',
                style: TextStyle(
                    fontSize: _textSizeM, fontWeight: FontWeight.bold)),
            if (_songMap[special.songId] != null)
              _buildSpecialSongCard(_songMap[special.songId]!),
          ],
        ],
      ),
    );
  }

  Widget _buildChallengeProgress() {
    final brightness = Theme.of(context).brightness;
    final challenges = _gateData!.challenges;
    if (challenges.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KaleidDateUtil.currentHeader(context, challenges),
        ...challenges.map((challenge) {
          final fontSize = 10.0 * MediaQuery.of(context).size.width / 375.0;
          return Padding(
            padding: EdgeInsets.only(bottom: _paddingL),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(_borderRadiusSmall),
                border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant),
              ),
              padding: EdgeInsets.all(_paddingM),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(challenge.name,
                        style: TextStyle(
                            fontSize: _textSizeL, fontWeight: FontWeight.bold)),
                    SizedBox(height: _paddingS),
                    _buildChallengeBar(challenge.phases, fontSize),
                    SizedBox(height: _paddingXS),
                    for (final phase in challenge.phases)
                      _buildChallengePhase(
                        phase,
                        showFinalPhaseDetails: challenge.name == '里门',
                        brightness: brightness,
                      ),
                  ]),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildChallengePhase(
    ChallengePhase phase, {
    required bool showFinalPhaseDetails,
    required Brightness brightness,
  }) {
    final dateText = KaleidDateUtil.range(phase.startDate, phase.endDate);

    if (!showFinalPhaseDetails) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: _paddingXS * .5),
        child: Row(
          children: [
            Text('$dateText:',
                style: TextStyle(
                    fontSize: _textSizeS,
                    color: AppColors.greyHint(brightness))),
            SizedBox(width: _paddingXS),
            Text(phase.difficulty,
                style: TextStyle(
                    fontSize: _textSizeS,
                    fontWeight: FontWeight.bold,
                    color: _getDifficultyColor(phase.difficulty))),
            SizedBox(width: _paddingXS),
            Text('LIFE ${phase.lifeTarget}',
                style: TextStyle(
                    fontSize: _textSizeS, fontWeight: FontWeight.bold)),
            if (phase.target != null) ...[
              SizedBox(width: _paddingXS),
              Text('目标 ${phase.target}',
                  style: TextStyle(
                      fontSize: _textSizeS,
                      color: AppColors.greyHint(brightness))),
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: _paddingXS * .5),
      child: Container(
        width: double.infinity,
        padding:
            EdgeInsets.symmetric(horizontal: _paddingS, vertical: _paddingXS),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: .45),
          borderRadius: BorderRadius.circular(_borderRadiusSmall),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: _paddingS,
              runSpacing: _paddingXS,
              children: [
                Text(dateText,
                    style: TextStyle(
                        fontSize: _textSizeS,
                        color: AppColors.greyHint(brightness))),
                Text(phase.difficulty,
                    style: TextStyle(
                        fontSize: _textSizeS,
                        fontWeight: FontWeight.bold,
                        color: _getDifficultyColor(phase.difficulty))),
              ],
            ),
            SizedBox(height: _paddingXS),
            Wrap(
              spacing: _paddingS,
              runSpacing: _paddingXS,
              children: [
                Text('一阶段 ${phase.lifeTarget}',
                    style: TextStyle(
                        fontSize: _textSizeS, fontWeight: FontWeight.bold)),
                Text('二阶段 ${phase.target ?? '-'}',
                    style: TextStyle(
                        fontSize: _textSizeS, fontWeight: FontWeight.bold)),
                if (phase.penalties != null &&
                    phase.penalties!.trim().isNotEmpty)
                  ...phase.penalties!
                      .split('|')
                      .where((item) => item.trim().isNotEmpty)
                      .map((item) => Text(
                            item.trim(),
                            style: TextStyle(
                                fontSize: _textSizeS,
                                color: AppColors.greyHint(brightness)),
                          )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 难度时间条（最终相等「挑战条件」页共用）。
  ///
  /// 原来是一条 24dp 高的胶囊里硬塞 [challenge.phases.length] 个等宽格：格子数
  /// 由放宽表的阶段数决定，最终相有 9 段，其中 `Re:MASTER` / `MASTER` / `EXPERT`
  /// 这些全名在窄屏上一格根本排不下，于是**标签在自己格子里换行**（还被
  /// `ClipRRect` 切掉半截），整条反而更难看。
  ///
  /// 做法：不再按「阶段数」等分，而是**按标签实际量出来的宽度分配**（最宽的那一格
  /// 决定其它格子的宽度下限），把放不下的格子折到下一行；一个阶段永远不跨行。
  /// 标签用 `FittedBox.scaleDown` 兜底：极端窄屏（或系统大字号）下宁可整格等比缩一点，
  /// 也不换行、不省略、不丢难度名。放得下时仍然是单行一条，和改动前观感一致。
  Widget _buildChallengeBar(List<ChallengePhase> phases, double fontSize) {
    final brightness = Theme.of(context).brightness;
    final textColor =
        brightness == Brightness.dark ? Colors.white : Colors.black87;
    if (phases.isEmpty) return const SizedBox.shrink();

    // 标签量宽度必须带 textScaler（与 MarqueeText 是同一个理由）：用户把系统
    // 字体调大后真实宽度是放大过的，不带上就会「算得下、画出来却换行」。
    final scaler = MediaQuery.textScalerOf(context);
    final maxLabelWidth = phases.map((phase) {
      final painter = TextPainter(
        text: TextSpan(
          text: phase.difficulty,
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
        ),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }).reduce((a, b) => a > b ? a : b);

    // 每格再留一点左右内边距，避免最长那格贴着格边。
    final minCellWidth = maxLabelWidth + _paddingXS * 2;
    const separator = 2.0; // 相邻格之间露出的底色细缝

    return LayoutBuilder(builder: (context, constraints) {
      final available = constraints.maxWidth;
      final maxPerRow =
          available <= 0 ? 1 : (available / minCellWidth).floor().clamp(1, 32);

      // 贪心装箱：同一行放不下就换行，保证每个阶段完整落在一行内。
      // 行内等分，所以行宽仍然整齐；每格的最小宽度由 minCellWidth 兜住。
      final rows = <List<ChallengePhase>>[];
      var current = <ChallengePhase>[];
      var currentWidth = 0.0;
      for (final phase in phases) {
        final added = current.isEmpty ? minCellWidth : minCellWidth + separator;
        if (current.isNotEmpty &&
            (current.length >= maxPerRow || currentWidth + added > available)) {
          rows.add(current);
          current = <ChallengePhase>[];
          currentWidth = 0;
        }
        currentWidth +=
            current.isEmpty ? minCellWidth : minCellWidth + separator;
        current.add(phase);
      }
      if (current.isNotEmpty) rows.add(current);

      return Column(
        children: [
          for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) ...[
            if (rowIndex > 0) SizedBox(height: separator),
            ClipRRect(
              borderRadius: BorderRadius.circular(_progressBarHeight / 2),
              child: SizedBox(
                height: _progressBarHeight,
                child: Row(children: [
                  for (var i = 0; i < rows[rowIndex].length; i++) ...[
                    if (i > 0) SizedBox(width: separator),
                    Expanded(
                      child: Container(
                        color:
                            _getDifficultyColor(rows[rowIndex][i].difficulty),
                        alignment: Alignment.center,
                        padding:
                            EdgeInsets.symmetric(horizontal: _paddingXS * .5),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            rows[rowIndex][i].difficulty,
                            maxLines: 1,
                            style: TextStyle(
                                fontSize: fontSize,
                                fontWeight: FontWeight.bold,
                                color: textColor),
                          ),
                        ),
                      ),
                    ),
                  ],
                ]),
              ),
            ),
          ],
        ],
      );
    });
  }

  Widget _buildSpecialSongCard(Song song) {
    final brightness = Theme.of(context).brightness;
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  SongInfoPage(songId: song.id, initialLevelIndex: 3))),
      child: Container(
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(_borderRadiusSmall),
            border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant)),
        padding: EdgeInsets.all(_paddingXS),
        child: Row(children: [
          SizedBox(
              width: _coverSize,
              height: _coverSize,
              child: CoverUtil.buildCoverWidgetWithContext(
                  context, song.id, _coverSize)),
          SizedBox(width: _paddingXS * 1.5),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(song.title,
                    style: TextStyle(
                        fontSize: _textSizeS, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                SizedBox(height: _paddingXS * .25),
                Text(
                    '${_getTypeDisplay(song.type)} | ${StringUtil.formatVersion2WithFlag(song.basicInfo.from, song.isExtra)}',
                    style: TextStyle(
                        fontSize: _textSizeXS,
                        color: AppColors.greyHint(brightness)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                SizedBox(height: _paddingXS * .25),
                Text(_getDsDisplay(song.ds),
                    style: TextStyle(
                        fontSize: _textSizeXS,
                        color: AppColors.greyHint(brightness))),
              ])),
        ]),
      ),
    );
  }

  Widget _buildSongCard(int id) {
    final brightness = Theme.of(context).brightness;
    final song = _songMap[id];
    return GestureDetector(
      onTap: () {
        if (song != null) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      SongInfoPage(songId: song.id, initialLevelIndex: 3)));
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(_borderRadiusSmall),
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        padding: EdgeInsets.all(_paddingXS),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          SizedBox(
              width: _coverSize,
              height: _coverSize,
              child: CoverUtil.buildCoverWidgetWithContext(
                  context, '$id', _coverSize)),
          SizedBox(width: _paddingXS * 1.5),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                Text(song?.title ?? '歌曲 ID $id',
                    style: TextStyle(
                        fontSize: _textSizeS, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                SizedBox(height: _paddingXS * .25),
                Text(
                    song == null
                        ? '刷新曲库后显示歌曲信息'
                        : '${_getTypeDisplay(song.type)} | ${StringUtil.formatVersion2WithFlag(song.basicInfo.from, song.isExtra)}',
                    style: TextStyle(
                        fontSize: _textSizeXS,
                        color: AppColors.greyHint(brightness)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (song != null) ...[
                  SizedBox(height: _paddingXS * .25),
                  Text(_getDsDisplay(song.ds),
                      style: TextStyle(
                          fontSize: _textSizeXS,
                          color: AppColors.greyHint(brightness)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ])),
        ]),
      ),
    );
  }

  Widget _buildSongGrid(List<int> ids) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: _paddingXS,
            mainAxisSpacing: _paddingXS,
            childAspectRatio: 2.0),
        itemCount: ids.length,
        itemBuilder: (_, index) => _buildSongCard(ids[index]),
      );

  Widget _buildTrackSection(String title, List<int> ids) {
    if (ids.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border:
                Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(_borderRadiusSmall)),
        padding: EdgeInsets.symmetric(
            horizontal: _paddingS, vertical: _paddingXS * .5),
        child: Center(
            child: Text('$title | 总计 ${ids.length} 首歌曲',
                style: TextStyle(
                    fontSize: _textSizeL,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurfaceVariant))),
      ),
      SizedBox(height: _paddingS),
      _buildSongGrid(ids),
    ]);
  }

  Widget _buildSongList() {
    // 原来这里有个 `final gate = _gateData!;`，只有底部那条来源链在用；
    // 链接删掉后就没用了（正文其余部分各自取 `_gateData!`）。
    final allIds = _allIds;
    final imageWidth = MediaQuery.of(context).size.width - 64;
    return Column(children: [
      Center(
        child: widget.color == 'error'
            ? Container(
                width: imageWidth,
                height: imageWidth * .46,
                color: _accent.withValues(alpha: .08),
                alignment: Alignment.center,
                child: Icon(Icons.door_back_door_outlined,
                    size: imageWidth * .25, color: _accent))
            : Image.asset(_asset, width: imageWidth, fit: BoxFit.contain),
      ),
      SizedBox(height: _paddingS),
      _buildUnlockSection(),
      SizedBox(height: _paddingL),
      _buildChallengeProgress(),
      if (allIds.isNotEmpty) ...[
        Container(
          decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(_borderRadiusSmall)),
          padding: EdgeInsets.symmetric(
              horizontal: _paddingS, vertical: _paddingXS * .5),
          child: Center(
              child: Text('曲目池 | 总计 ${allIds.length} 首歌曲',
                  style: TextStyle(
                      fontSize: _textSizeL,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurfaceVariant))),
        ),
        SizedBox(height: _paddingS),
        SizedBox(height: _paddingS),
        _buildSongGrid(allIds),
      ],
      SizedBox(height: _paddingS),
      Divider(
          color: Theme.of(context).colorScheme.outlineVariant, thickness: 1),
      SizedBox(height: _paddingS),
      Align(
          alignment: Alignment.centerLeft,
          child: Text('Track随机曲目',
              style: TextStyle(
                  fontSize: _textSizeXL, fontWeight: FontWeight.bold))),
      SizedBox(height: _paddingXS),
      _buildTrackSection('Track 1', _trackIds('track1')),
      SizedBox(height: _paddingS),
      _buildTrackSection('Track 2', _trackIds('track2')),
      SizedBox(height: _paddingS),
      _buildTrackSection('Track 3', _trackIds('track3')),
      // 底部那个「打开来源」文字按钮已删除：数据来源链接只保留顶部那一条
      // （`PageTopBar.bottom` 里的 [KaleidXScopeSourceNotice]）。
      SizedBox(height: _paddingS),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    _initSizeParams(context);
    return BackgroundPageScaffold(
      title: _getGateTitle(),
      bottom: const KaleidXScopeSourceNotice(),
      contentPadding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 10),
      child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(_error!),
                          TextButton(onPressed: _load, child: const Text('重试'))
                        ]))
                      : SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                              horizontal: _paddingL, vertical: _paddingS),
                          child: _buildSongList()),
    );
  }
}
