import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../entity/DivingFish/Song.dart';
import '../../manager/DivingFish/MaimaiMusicDataManager.dart';
import '../../service/Best50/Best50ConvertToImgService.dart';
import '../../service/Best50/IdealBest50Service.dart';
import '../../utils/AppTheme.dart';
import '../../utils/ColorUtil.dart';
import '../../utils/CommonWidgetUtil.dart';
import '../../utils/ExportQualitySelector.dart';
import '../../utils/ImageEncodeUtil.dart';
import '../../utils/StringUtil.dart';
import '../../widgets/B50GameCardWidget.dart';
import '../SongInfoPage.dart';
import '../../widgets/PageTopBar.dart';

/// 理想 Best50：把全部游玩记录里非 SSS+ 的成绩升一档（100.4 → 100.5），
/// 重算 RA 后重新取 B35 + B15，并列出相对原榜的新进榜歌曲。
class IdealBest50Page extends StatefulWidget {
  const IdealBest50Page({super.key});

  @override
  State<IdealBest50Page> createState() => _IdealBest50PageState();
}

class _IdealBest50PageState extends State<IdealBest50Page> {
  Map<String, dynamic>? _data;
  List<Map<String, dynamic>> _sdSongs = [];
  List<Map<String, dynamic>> _dxSongs = [];
  List<Map<String, dynamic>> _newEntries = [];
  Map<String, Song> _songIndex = {};
  List<dynamic> _maimaiMusicData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await IdealBest50Service().calculate();
    final songs = await MaimaiMusicDataManager().getCachedSongs() ?? <Song>[];
    if (!mounted) return;
    setState(() {
      _data = data;
      _sdSongs = data == null
          ? []
          : List<Map<String, dynamic>>.from(data['sd'] as List);
      _dxSongs = data == null
          ? []
          : List<Map<String, dynamic>>.from(data['dx'] as List);
      _newEntries = data == null
          ? []
          : List<Map<String, dynamic>>.from(data['newEntries'] as List);
      _songIndex = {for (final s in songs) s.id: s};
      _maimaiMusicData = songs.map((s) => s.toJson()).toList();
      _isLoading = false;
    });
  }

  // ───────────────────────── 卡片计算 ─────────────────────────

  Song? _songOf(Map<String, dynamic> m) =>
      _songIndex[(m['song_id'] ?? 0).toString()];

  int _singleMaxScore(Song? song, int levelIndex) {
    if (song == null) return 0;
    if (levelIndex < 0 || levelIndex >= song.charts.length) return 0;
    final notes = song.charts[levelIndex].notes;
    return notes.fold<int>(0, (sum, n) => sum + n) * 3;
  }

  int _cardMaxScore(Map<String, dynamic> m) =>
      _singleMaxScore(_songOf(m), (m['level_index'] ?? 0) as int);

  int _maxDxScore(Map<String, dynamic> m) {
    final song = _songOf(m);
    if (song == null) return 0;
    if (song.ds.length == 2) {
      return _singleMaxScore(song, 0) + _singleMaxScore(song, 1);
    }
    return _singleMaxScore(song, (m['level_index'] ?? 0) as int);
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

  Future<void> _exportToImage() async {
    if (_data == null || _sdSongs.isEmpty && _dxSongs.isEmpty) {
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
        songCount: _sdSongs.length + _dxSongs.length,
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
      final b50Data = {
        'rating': _data!['rating'],
        'additional_rating': 0,
        'charts': {'sd': _sdSongs, 'dx': _dxSongs},
      };
      final file = await B50ConvertToImg.convertToImage(
        context,
        b50Data,
        _sdSongs,
        _dxSongs,
        _maimaiMusicData,
        jpegQuality: quality.jpegQuality,
      );

      if (!mounted) return;
      Navigator.pop(context);

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
                title: '理想 Best50',
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
                  child: _data == null ? _buildEmptyState() : _buildContent(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.insights_outlined, size: 64, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              '暂无游玩数据缓存',
              style: TextStyle(fontSize: 18, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              '请返回首页点击"刷新数据"按钮获取',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.03),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStatsSection(),
          const SizedBox(height: 12.0),
          _buildNewEntriesSection(),
          const SizedBox(height: 12.0),
          _buildExportButton(),
          const SizedBox(height: 12.0),
          _buildSectionTitle('Best35 | 非当前版本'),
          const SizedBox(height: 8.0),
          _buildGrid(_sdSongs),
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
          _buildSectionTitle('Best15 | 当前版本'),
          const SizedBox(height: 8.0),
          _buildGrid(_dxSongs),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final originalRating = (_data!['originalRating'] ?? 0) as int;
    final idealRating = (_data!['rating'] ?? 0) as int;
    final delta = idealRating - originalRating;
    final all = [..._sdSongs, ..._dxSongs];
    final avgAchievement = all.isEmpty
        ? 0.0
        : all.fold<double>(
                0.0,
                (sum, m) =>
                    sum + (double.tryParse(m['achievements'].toString()) ?? 0.0)) /
            all.length;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: onSurface, width: 2.0),
        borderRadius: BorderRadius.circular(8.0),
      ),
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '理想 Best50 统计',
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.width * 0.045,
              fontWeight: FontWeight.bold,
              color: onSurface,
            ),
          ),
          const SizedBox(height: 4.0),
          Text(
            '规则：非 SSS+ 成绩升到上一档的下限',
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.width * 0.031,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8.0),
          Row(
            children: [
              _statColumn('原 Rating', '$originalRating'),
              _statColumn('理想 Rating', '$idealRating'),
              _statColumn('提升', delta >= 0 ? '+$delta' : '$delta'),
              _statColumn('新进榜', '${_newEntries.length}'),
            ],
          ),
          const SizedBox(height: 6.0),
          Text(
            '平均达成率 ${avgAchievement.toStringAsFixed(2)}%',
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.width * 0.033,
              color: onSurface,
            ),
          ),
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
                  fontSize: MediaQuery.of(context).size.width * 0.04,
                  fontWeight: FontWeight.bold,
                  color: onSurface)),
        ],
      ),
    );
  }

  Widget _buildNewEntriesSection() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant, width: 1.5),
        borderRadius: BorderRadius.circular(8.0),
      ),
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '本次新进榜（${_newEntries.length} 首）',
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.width * 0.04,
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6.0),
          if (_newEntries.isEmpty)
            Text(
              '无新歌进榜（升档后榜单成员不变）',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            )
          else
            for (final e in _newEntries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Text(
                  '· ${e['title']}  · 定数 ${(e['ds'] as num).toStringAsFixed(1)}  · RA ${e['oldRa']} → ${e['newRa']}',
                  style: TextStyle(fontSize: 13, color: scheme.onSurface),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildExportButton() {
    final brightness = Theme.of(context).brightness;
    return ElevatedButton.icon(
      onPressed: _exportToImage,
      icon: const Icon(Icons.image_outlined, color: Colors.white),
      label: const Text('导出为图片', style: TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.linkBlue(brightness),
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
            color: Theme.of(context).colorScheme.onSurface, width: 2.0),
        borderRadius: BorderRadius.circular(8.0),
      ),
      padding: const EdgeInsets.all(10.0),
      child: Center(
        child: Text(
          title,
          style: TextStyle(
            fontSize: MediaQuery.of(context).size.width * 0.042,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(List<Map<String, dynamic>> songs) {
    if (songs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Text('无数据',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      );
    }
    final int maxIdLength = songs
        .map((m) => (m['song_id'] ?? 0).toString().length)
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
      itemCount: songs.length,
      itemBuilder: (context, index) =>
          _buildDataGameCard(songs[index], maxIdLength),
    );
  }

  Widget _buildDataGameCard(Map<String, dynamic> m, int maxIdLength) {
    final songId = (m['song_id'] ?? 0) as int;
    final levelIndex = (m['level_index'] ?? 0) as int;
    final isUtage = songId.toString().length == 6;
    final cardColor =
        isUtage ? AppColors.utageCard() : ColorUtil.getCardColor(levelIndex);
    final maxScore = _cardMaxScore(m);
    final maxDx = _maxDxScore(m);
    final score = (m['dxScore'] ?? 0) as int;
    final scoreRate = maxDx > 0 ? score / maxDx : 0.0;
    final stars = StringUtil.formatStars(scoreRate);
    final starsColor = ColorUtil.getStarsColor(stars);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SongInfoPage(
              songId: songId.toString(),
              initialLevelIndex: levelIndex,
              isDefaultLevelIndex: false,
            ),
          ),
        );
      },
      child: _buildGameCard(
        cardColor: cardColor,
        songName: m['title'] ?? '未知歌曲',
        achievementRate: double.tryParse(m['achievements'].toString()) ?? 0.0,
        difficulty: double.tryParse(m['ds'].toString()) ?? 0.0,
        dxMode: m['type'] == 'DX',
        isUtage: isUtage,
        score: score,
        maxScore: maxScore,
        rating: (m['ra'] ?? 0) as int,
        stars: stars,
        fc: m['fc'] ?? '',
        fs: m['fs'] ?? '',
        rate: m['rate'] ?? '',
        songId: songId,
        starsColor: starsColor,
        maxIdLength: maxIdLength,
      ),
    );
  }

  Widget _buildGameCard({
    required Color cardColor,
    String songName = '未知歌曲',
    double achievementRate = 0.0,
    double difficulty = 0.0,
    bool dxMode = false,
    bool isUtage = false,
    int score = 0,
    int maxScore = 0,
    int rating = 0,
    String stars = '',
    String fc = '',
    String fs = '',
    String rate = '',
    int? songId,
    Color starsColor = Colors.white,
    int maxIdLength = 5,
  }) {

    return B50GameCardWidget(
      cardColor: cardColor,
      songName: songName,
      achievementRate: achievementRate,
      difficulty: difficulty,
      dxMode: dxMode,
      isUtage: isUtage,
      score: score,
      maxScore: maxScore,
      rating: rating,
      stars: stars,
      fc: fc,
      fs: fs,
      rate: rate,
      songId: songId ?? 0,
      starsColor: starsColor,
      maxIdLength: maxIdLength,
      // 字号按卡片**实际**宽度自适应：别拿屏幕宽度估（容器 padding /
      // 网格间距都会从可用宽里扣掉）。
      scale: B50GameCardWidget.autoScale,
    );
  }
}
