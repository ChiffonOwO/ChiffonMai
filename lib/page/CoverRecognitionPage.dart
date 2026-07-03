import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../service/CoverRecognitionService.dart';
import '../utils/CommonWidgetUtil.dart';
import '../utils/CoverUtil.dart';
import '../utils/AppTheme.dart';
import '../utils/AppConstants.dart';
import 'SongInfoPage.dart';

/// 曲绘识别页面
/// 支持拍照/相册选取 → 手动裁剪 → 识别 → 显示Top10匹配结果
class CoverRecognitionPage extends StatefulWidget {
  const CoverRecognitionPage({super.key});

  @override
  State<CoverRecognitionPage> createState() => _CoverRecognitionPageState();
}

class _CoverRecognitionPageState extends State<CoverRecognitionPage> {
  final ImagePicker _picker = ImagePicker();
  final CoverRecognitionService _service = CoverRecognitionService.instance;

  bool _isInitializing = true;
  bool _isPrecomputing = false;
  int _precomputeCurrent = 0;
  int _precomputeTotal = 0;

  String? _photoPath;
  bool _isRecognizing = false;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _checkHashCache();
  }

  Future<void> _checkHashCache() async {
    final valid = await _service.isHashCacheValid();
    if (mounted) {
      setState(() => _isInitializing = false);
      if (!valid) _startPrecompute();
    }
  }

  Future<void> _startPrecompute() async {
    setState(() {
      _isPrecomputing = true;
      _precomputeCurrent = 0;
      _precomputeTotal = 0;
    });
    try {
      await _service.precomputeHashes(
        onProgress: (current, total) {
          if (mounted) setState(() { _precomputeCurrent = current; _precomputeTotal = total; });
        },
      );
      if (mounted) {
        setState(() => _isPrecomputing = false);
        Fluttertoast.showToast(msg: '曲绘索引建立完成！共处理 $_precomputeTotal 张曲绘');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPrecomputing = false);
        Fluttertoast.showToast(msg: '索引建立失败: $e');
      }
    }
  }

  void _showSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.tableBorder(Theme.of(context).brightness), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('选择图片来源', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, size: 28),
              title: const Text('拍照'),
              subtitle: const Text('使用相机拍摄曲绘'),
              onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, size: 28),
              title: const Text('从相册选择'),
              subtitle: const Text('从相册中选取曲绘截图'),
              onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) { Fluttertoast.showToast(msg: '需要相机权限'); openAppSettings(); }
        return;
      }
    }
    try {
      final photo = await _picker.pickImage(source: source, imageQuality: 95);
      if (photo != null && mounted) {
        // 打开裁剪页面
        final cropped = await Navigator.push<String>(
          context,
          MaterialPageRoute(builder: (_) => _ImageCropPage(imagePath: photo.path)),
        );
        if (cropped != null && mounted) {
          setState(() { _photoPath = cropped; _result = null; });
        } else if (mounted) {
          // 用户取消裁剪，仍然使用原图
          setState(() { _photoPath = photo.path; _result = null; });
        }
      }
    } catch (e) {
      Fluttertoast.showToast(msg: '选取图片失败: $e');
    }
  }

  Future<void> _recognize() async {
    if (_photoPath == null) return;
    setState(() => _isRecognizing = true);
    try {
      final result = await _service.recognizeCover(_photoPath!);
      if (mounted) {
        setState(() { _result = result; _isRecognizing = false; });
        if (result == null) Fluttertoast.showToast(msg: '识别失败，请重试');
      }
    } catch (e) {
      if (mounted) setState(() => _isRecognizing = false);
      Fluttertoast.showToast(msg: '识别出错: $e');
    }
  }

  void _reset() => setState(() { _photoPath = null; _result = null; });

  Future<void> _rebuildIndex() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重建曲绘索引'),
        content: const Text('将清除现有索引并重新为全部曲绘计算哈希。这可能需要数十秒，确定继续吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定重建')),
        ],
      ),
    );
    if (confirmed == true) { await _service.clearCache(); await _startPrecompute(); }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final sw = MediaQuery.of(context).size.width;
    final c = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          CommonWidgetUtil.buildCommonBgWidget(),
          CommonWidgetUtil.buildCommonChiffonBgWidget(context),
          Column(children: [
            _buildTitleBar(sw, c),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [AppConstants.defaultShadow(brightness)],
                ),
                child: ClipRRect(borderRadius: BorderRadius.circular(12), child: _buildContent(sw, c)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildTitleBar(double sw, Color c) => Container(
    padding: const EdgeInsets.fromLTRB(16, 48, 16, 8),
    child: Row(children: [
      IconButton(icon: Icon(Icons.arrow_back, color: c), onPressed: () => Navigator.pop(context)),
      Expanded(child: Center(child: Text('曲绘识别', style: TextStyle(color: c, fontSize: sw * 0.06, fontWeight: FontWeight.bold)))),
      IconButton(icon: const Icon(Icons.arrow_back, color: Colors.transparent), onPressed: null),
    ]),
  );

  Widget _buildContent(double sw, Color c) {
    if (_isPrecomputing) return _buildPrecomputeProgress(sw, c);
    if (_isInitializing) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(), const SizedBox(height: 16),
        Text('正在加载...', style: TextStyle(color: c, fontSize: sw * 0.04)),
      ]));
    }
    return SingleChildScrollView(
      padding: EdgeInsets.all(sw * 0.04),
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        if (_result != null) ...[
          _buildTopMatch(sw, c), const SizedBox(height: 16),
          _buildTop10List(sw, c), const SizedBox(height: 16),
          _buildActionButtons(sw, c),
        ] else if (_photoPath != null) ...[
          _buildPhotoPreview(sw, c), const SizedBox(height: 16),
          _buildActionButtons(sw, c),
        ] else ...[
          _buildPhotoGuide(sw, c), const SizedBox(height: 16),
          _buildActionButtons(sw, c),
        ],
        const SizedBox(height: 12),
        _buildCacheInfo(sw, c),
      ]),
    );
  }

  Widget _buildPrecomputeProgress(double sw, Color c) {
    final p = _precomputeTotal > 0 ? _precomputeCurrent / _precomputeTotal : 0.0;
    return Padding(padding: EdgeInsets.all(sw * 0.06), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.image_search, size: sw * 0.13, color: c.withValues(alpha: 0.6)),
      const SizedBox(height: 24),
      Text('正在建立曲绘索引...', style: TextStyle(color: c, fontSize: sw * 0.045, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text('为 $_precomputeTotal 张曲绘计算特征', style: TextStyle(color: c.withValues(alpha: 0.6), fontSize: sw * 0.032)),
      const SizedBox(height: 16),
      LinearProgressIndicator(value: p, minHeight: 6, borderRadius: BorderRadius.circular(3),
        backgroundColor: Theme.of(context).colorScheme.surface, valueColor: AlwaysStoppedAnimation<Color>(c)),
      const SizedBox(height: 8),
      Text('$_precomputeCurrent / $_precomputeTotal', style: TextStyle(color: c.withValues(alpha: 0.5), fontSize: sw * 0.03)),
      const SizedBox(height: 8),
      Text('仅首次需要，请耐心等待', style: TextStyle(color: c.withValues(alpha: 0.4), fontSize: sw * 0.026)),
    ]));
  }

  Widget _buildPhotoGuide(double sw, Color c) => Column(children: [
    const SizedBox(height: 16),
    Icon(Icons.image_search, size: sw * 0.18, color: c.withValues(alpha: 0.35)),
    const SizedBox(height: 12),
    Text('拍摄或选择一张曲绘图片', style: TextStyle(color: c, fontSize: sw * 0.045, fontWeight: FontWeight.w600)),
    const SizedBox(height: 8),
    Text('选取后可手动框选曲绘区域\n提高识别准确率', textAlign: TextAlign.center,
        style: TextStyle(color: c.withValues(alpha: 0.5), fontSize: sw * 0.03)),
  ]);

  Widget _buildPhotoPreview(double sw, Color c) => Column(children: [
    const SizedBox(height: 8),
    Container(
      width: sw * 0.65, height: sw * 0.65,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.3), width: 2),
        boxShadow: [AppConstants.defaultShadow(Theme.of(context).brightness)]),
      child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(File(_photoPath!), fit: BoxFit.cover)),
    ),
    const SizedBox(height: 10),
    Text('图片已就绪', style: TextStyle(color: c.withValues(alpha: 0.5), fontSize: sw * 0.03)),
  ]);

  Widget _buildTopMatch(double sw, Color c) {
    final songId = _result!['songId'] as String? ?? '';
    final sim = _result!['similarity'] as double? ?? 0;
    final hashSim = _result!['hashSimilarity'] as double? ?? 0;
    final colorSim = _result!['colorSimilarity'] as double? ?? 0;
    final title = _result!['songTitle'] as String? ?? '';
    final artist = _result!['artist'] as String? ?? '';
    final lowConf = _result!['lowConfidence'] as bool? ?? false;
    final brightness = Theme.of(context).brightness;
    final mc = sim >= 80 ? AppColors.successGreen(brightness) : sim >= 60 ? AppColors.warningOrange(brightness) : AppColors.errorRed(brightness);
    return Column(children: [
      const SizedBox(height: 8),

      // 低置信度警告
      if (lowConf)
        Container(
          width: sw * 0.85,
          margin: const EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.all(sw * 0.03),
          decoration: BoxDecoration(
            color: AppColors.errorRed(brightness).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.errorRed(brightness).withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            Icon(Icons.warning_amber, color: AppColors.errorRed(brightness), size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text('匹配度过低，可能不是曲绘照片，请重新框选裁剪区域后再试',
                  style: TextStyle(color: AppColors.errorRed(brightness), fontSize: sw * 0.03)),
            ),
          ]),
        ),

      // 左右对比：用户输入 vs 匹配曲绘
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 左侧：用户输入图片
          _buildSideImage(
            sw: sw,
            c: c,
            label: '输入图片',
            imageProvider: _photoPath != null ? FileImage(File(_photoPath!)) : null,
            borderColor: AppColors.tableBorder(Theme.of(context).brightness),
          ),
          // 中间箭头
          Padding(
            padding: EdgeInsets.symmetric(horizontal: sw * 0.015),
            child: Icon(Icons.arrow_forward, color: mc, size: sw * 0.06),
          ),
          // 右侧：匹配曲绘
          _buildSideImage(
            sw: sw,
            c: c,
            label: '匹配曲绘',
            imageProvider: AssetImage(CoverUtil.buildCoverPath(songId)),
            borderColor: mc,
            isMatch: true,
          ),
        ],
      ),
      const SizedBox(height: 12),
      Container(
        padding: EdgeInsets.all(sw * 0.035),
        decoration: BoxDecoration(color: mc.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: mc.withValues(alpha: 0.3))),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(sim >= 80 ? Icons.check_circle : sim >= 60 ? Icons.help_outline : Icons.warning_amber,
                color: mc, size: sw * 0.045),
            const SizedBox(width: 6),
            Text(lowConf ? '综合匹配 ${sim.toStringAsFixed(2)}%（不可靠）' : '综合匹配 ${sim.toStringAsFixed(2)}%',
                style: TextStyle(color: mc, fontSize: sw * 0.043, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 6),
          // 纹理相似度 + 颜色相似度 分解
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _buildSimBadge(sw, '纹理', hashSim),
            SizedBox(width: sw * 0.04),
            _buildSimBadge(sw, '颜色', colorSim),
          ]),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(color: c, fontSize: sw * 0.048, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(artist, style: TextStyle(color: c.withValues(alpha: 0.65), fontSize: sw * 0.033)),
        ]),
      ),
    ]);
  }

  Widget _buildSimBadge(double sw, String label, double value) {
    final brightness = Theme.of(context).brightness;
    final color = value >= 80 ? AppColors.successGreen(brightness) : value >= 55 ? AppColors.warningOrange(brightness) : AppColors.errorRed(brightness);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: sw * 0.025, vertical: sw * 0.008),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$label ', style: TextStyle(fontSize: sw * 0.026, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Text('${value.toStringAsFixed(2)}%', style: TextStyle(fontSize: sw * 0.028, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }

  Widget _buildSideImage({
    required double sw,
    required Color c,
    required String label,
    required ImageProvider<Object>? imageProvider,
    required Color borderColor,
    bool isMatch = false,
  }) {
    final size = sw * 0.35;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: sw * 0.026, color: c.withValues(alpha: 0.5))),
        const SizedBox(height: 4),
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: isMatch ? 3 : 1.5),
            boxShadow: isMatch
                ? [BoxShadow(color: borderColor.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]
                : [AppConstants.defaultShadow(Theme.of(context).brightness)],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(isMatch ? 7 : 8.5),
            child: imageProvider != null
                ? Image(image: imageProvider, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: Theme.of(context).colorScheme.surface,
                        child: Center(child: Icon(Icons.broken_image, size: sw * 0.08, color: AppColors.greyHint(Theme.of(context).brightness)))))
                : Container(color: Theme.of(context).colorScheme.surface,
                    child: Center(child: Icon(Icons.image, size: sw * 0.08, color: AppColors.greyHint(Theme.of(context).brightness)))),
          ),
        ),
      ],
    );
  }

  Widget _buildTop10List(double sw, Color c) {
    final brightness = Theme.of(context).brightness;
    final matches = (_result!['topMatches'] as List<dynamic>?) ?? [];
    if (matches.isEmpty) return const SizedBox.shrink();

    // 过滤掉无歌名的条目（如"歌曲 #xxx"），让后续顺延
    final namedMatches = matches.where((m) {
      final title = (m as Map<String, dynamic>)['songTitle'] as String? ?? '';
      return title.isNotEmpty && !title.startsWith('歌曲 #');
    }).toList();

    // 去重：同一首歌（DX/ST/UTAGE）共用曲绘，只保留相似度最高的那条
    final seenTitles = <String>{};
    final validMatches = namedMatches.where((m) {
      final title = (m as Map<String, dynamic>)['songTitle'] as String? ?? '';
      return seenTitles.add(title); // add 返回 true 表示首次出现
    }).take(10).toList(); // 截取前10条，确保过滤/去重后始终显示10个
    if (validMatches.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.surface)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: EdgeInsets.fromLTRB(sw * 0.04, sw * 0.03, sw * 0.04, sw * 0.02),
          child: Row(children: [
            Icon(Icons.leaderboard, size: sw * 0.04, color: c), const SizedBox(width: 6),
            Text('识别结果 Top 10', style: TextStyle(color: c, fontSize: sw * 0.038, fontWeight: FontWeight.bold)),
          ]),
        ),
        const Divider(height: 1),
        ...validMatches.asMap().entries.map((e) {
          final i = e.key; final m = e.value as Map<String, dynamic>;
          final sid = m['songId'] as String? ?? '';
          final sim = m['similarity'] as double? ?? 0;
          final title = m['songTitle'] as String? ?? '';
          final artist = m['artist'] as String? ?? '';
          final best = i == 0;
          return Container(
            color: best ? AppColors.successGreen(brightness).withValues(alpha: 0.06) : Theme.of(context).colorScheme.surface,
            child: ListTile(
              dense: true,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SongInfoPage(songId: sid),
                  ),
                );
              },
              leading: Container(
                width: sw * 0.12,
                height: sw * 0.12,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: best ? AppColors.successGreen(brightness) : AppColors.tableBorder(brightness), width: best ? 2 : 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Image.asset(
                    CoverUtil.buildCoverPath(sid),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(Icons.broken_image, size: sw * 0.05, color: AppColors.greyHint(brightness)),
                  ),
                ),
              ),
              title: Text(title.isNotEmpty ? title : '歌曲 #$sid',
                  style: TextStyle(fontSize: sw * 0.032, fontWeight: best ? FontWeight.bold : FontWeight.normal),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: artist.isNotEmpty ? Text(artist, style: TextStyle(fontSize: sw * 0.025, color: AppColors.greyHint(brightness)), maxLines: 1) : null,
              trailing: Container(
                padding: EdgeInsets.symmetric(horizontal: sw * 0.02, vertical: sw * 0.006),
                decoration: BoxDecoration(
                  color: sim >= 80 ? AppColors.successGreen(brightness).withValues(alpha: 0.1) : sim >= 60 ? AppColors.warningOrange(brightness).withValues(alpha: 0.1) : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: sim >= 80 ? AppColors.successGreen(brightness).withValues(alpha: 0.25) : sim >= 60 ? AppColors.warningOrange(brightness).withValues(alpha: 0.25) : AppColors.tableBorder(brightness))),
                child: Text('${sim.toStringAsFixed(2)}%', style: TextStyle(fontSize: sw * 0.026, fontWeight: FontWeight.w600,
                    color: sim >= 80 ? AppColors.successGreen(brightness) : sim >= 60 ? AppColors.warningOrange(brightness) : Theme.of(context).colorScheme.onSurfaceVariant)),
              ),
            ),
          );
        }),
      ]),
    );
  }

  Widget _buildActionButtons(double sw, Color c) => Wrap(
    spacing: sw * 0.03, runSpacing: sw * 0.02, alignment: WrapAlignment.center,
    children: [
      if (_photoPath == null) ...[
        _btn(sw, c, Icons.add_a_photo, '选择图片', _showSourcePicker, true),
      ] else if (_result == null) ...[
        _btn(sw, c, Icons.search, _isRecognizing ? '识别中...' : '开始识别', _isRecognizing ? null : _recognize, true),
        _btn(sw, c, Icons.crop, '重新裁剪', () async {
          if (_photoPath == null) return;
          final cropped = await Navigator.push<String>(context,
            MaterialPageRoute(builder: (_) => _ImageCropPage(imagePath: _photoPath!)));
          if (cropped != null && mounted) setState(() { _photoPath = cropped; _result = null; });
        }, false),
        _btn(sw, c, Icons.refresh, '重选', _reset, false),
      ] else ...[
        _btn(sw, c, Icons.refresh, '重新识别', _reset, true),
        _btn(sw, c, Icons.add_a_photo, '再选一张', _showSourcePicker, false),
      ],
    ],
  );

  Widget _btn(double sw, Color c, IconData icon, String label, VoidCallback? onTap, bool primary) =>
    ElevatedButton.icon(
      onPressed: onTap,
      icon: onTap == null && _isRecognizing
          ? SizedBox(width: sw * 0.035, height: sw * 0.035,
              child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Icon(icon, size: sw * 0.042),
      label: Text(label, style: TextStyle(fontSize: sw * 0.032)),
      style: ElevatedButton.styleFrom(
        backgroundColor: primary ? c : Theme.of(context).colorScheme.surface,
        foregroundColor: primary ? Colors.white : c,
        padding: EdgeInsets.symmetric(horizontal: sw * 0.05, vertical: sw * 0.028),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: primary ? c : c.withValues(alpha: 0.4), width: 1.5)),
        elevation: primary ? 2 : 0,
      ),
    );

  Widget _buildCacheInfo(double sw, Color c) => FutureBuilder<bool>(
    future: _service.isHashCacheValid(),
    builder: (_, snap) {
      final brightness = Theme.of(context).brightness;
      final ok = snap.data ?? false;
      return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(ok ? Icons.check_circle_outline : Icons.info_outline,
            size: sw * 0.032, color: ok ? AppColors.successGreen(brightness) : AppColors.warningOrange(brightness)),
        const SizedBox(width: 4),
        Text(ok ? '曲绘索引就绪' : '索引未建立',
            style: TextStyle(fontSize: sw * 0.026, color: ok ? AppColors.successGreen(brightness) : AppColors.warningOrange(brightness))),
        if (ok) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _rebuildIndex,
            child: Text('重建索引',
                style: TextStyle(fontSize: sw * 0.026, color: c.withValues(alpha: 0.6),
                    decoration: TextDecoration.underline)),
          ),
        ],
      ]);
    },
  );
}

// ────────────────────────────────────────────────────────
// 手动裁剪页面
// ────────────────────────────────────────────────────────

/// 裁剪框的拖拽手柄类型
enum _Handle { none, body, topLeft, topRight, bottomLeft, bottomRight }

/// 全屏手动裁剪页面
class _ImageCropPage extends StatefulWidget {
  final String imagePath;
  const _ImageCropPage({required this.imagePath});

  @override
  State<_ImageCropPage> createState() => _ImageCropPageState();
}

class _ImageCropPageState extends State<_ImageCropPage> {
  ui.Image? _image;
  bool _loading = true;

  // 图片在屏幕上的显示区域（BoxFit.contain 后的实际区域）
  Rect _imageRect = Rect.zero;

  // 裁剪框（相对于 _imageRect）
  Rect _cropRect = Rect.zero;

  // 拖拽状态
  _Handle _activeHandle = _Handle.none;
  Offset? _dragStart;
  Rect? _cropRectStart;

  final double _handleSize = 24;
  final double _minCropSize = 50;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final bytes = await File(widget.imagePath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (mounted) setState(() { _image = frame.image; _loading = false; });
  }

  /// 计算 BoxFit.contain 后图片在容器中的实际区域
  Rect _calcImageRect(Size container) {
    if (_image == null) return Rect.zero;
    final iw = _image!.width.toDouble();
    final ih = _image!.height.toDouble();
    final scale = (container.width / iw) < (container.height / ih)
        ? container.width / iw
        : container.height / ih;
    final dw = iw * scale;
    final dh = ih * scale;
    final dx = (container.width - dw) / 2;
    final dy = (container.height - dh) / 2;
    return Rect.fromLTWH(dx, dy, dw, dh);
  }

  /// 初始化裁剪框（正方形，取较长边的70%）
  void _initCropRect() {
    final size = math.min(_imageRect.width, _imageRect.height) * 0.7;
    setState(() {
      _cropRect = Rect.fromLTWH(
        _imageRect.left + (_imageRect.width - size) / 2,
        _imageRect.top + (_imageRect.height - size) / 2,
        size, size,
      );
    });
  }

  /// 获取指定手柄的光标样式
  MouseCursor _cursorForHandle(_Handle h) => switch (h) {
    _Handle.topLeft || _Handle.bottomRight => SystemMouseCursors.resizeUpLeftDownRight,
    _Handle.topRight || _Handle.bottomLeft => SystemMouseCursors.resizeUpRightDownLeft,
    _Handle.body => SystemMouseCursors.move,
    _ => SystemMouseCursors.basic,
  };

  _Handle _hitTest(Offset p) {
    const r = 20.0; // 触摸容差
    if ((p - _cropRect.topLeft).distance < r) return _Handle.topLeft;
    if ((p - _cropRect.topRight).distance < r) return _Handle.topRight;
    if ((p - _cropRect.bottomLeft).distance < r) return _Handle.bottomLeft;
    if ((p - _cropRect.bottomRight).distance < r) return _Handle.bottomRight;
    if (_cropRect.contains(p)) return _Handle.body;
    return _Handle.none;
  }

  void _onPanStart(DragStartDetails d) {
    _activeHandle = _hitTest(d.localPosition);
    _dragStart = d.localPosition;
    _cropRectStart = _cropRect;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_activeHandle == _Handle.none || _cropRectStart == null || _dragStart == null) return;

    final delta = d.localPosition - _dragStart!;
    final r = _cropRectStart!;
    Rect newRect;

    switch (_activeHandle) {
      case _Handle.body:
        var dx = r.left + delta.dx;
        var dy = r.top + delta.dy;
        if (dx < _imageRect.left) dx = _imageRect.left;
        if (dy < _imageRect.top) dy = _imageRect.top;
        if (dx + r.width > _imageRect.right) dx = _imageRect.right - r.width;
        if (dy + r.height > _imageRect.bottom) dy = _imageRect.bottom - r.height;
        newRect = Rect.fromLTWH(dx, dy, r.width, r.height);

      case _Handle.topLeft:
        // 锚点：右下角；正方形缩放
        final maxDelta = math.max(r.width - delta.dx, r.height - delta.dy).toDouble();
        final size = maxDelta.clamp(_minCropSize, math.min(r.right - _imageRect.left, r.bottom - _imageRect.top).toDouble());
        newRect = Rect.fromLTWH(
          (r.right - size).clamp(_imageRect.left, _imageRect.right - _minCropSize),
          (r.bottom - size).clamp(_imageRect.top, _imageRect.bottom - _minCropSize),
          size, size,
        );

      case _Handle.topRight:
        final maxDelta = math.max(r.width + delta.dx, r.height - delta.dy).toDouble();
        final size = maxDelta.clamp(_minCropSize, math.min(_imageRect.right - r.left, r.bottom - _imageRect.top).toDouble());
        newRect = Rect.fromLTWH(
          r.left.clamp(_imageRect.left, _imageRect.right - _minCropSize),
          (r.bottom - size).clamp(_imageRect.top, _imageRect.bottom - _minCropSize),
          size, size,
        );

      case _Handle.bottomLeft:
        final maxDelta = math.max(r.width - delta.dx, r.height + delta.dy).toDouble();
        final size = maxDelta.clamp(_minCropSize, math.min(r.right - _imageRect.left, _imageRect.bottom - r.top).toDouble());
        newRect = Rect.fromLTWH(
          (r.right - size).clamp(_imageRect.left, _imageRect.right - _minCropSize),
          r.top.clamp(_imageRect.top, _imageRect.bottom - _minCropSize),
          size, size,
        );

      case _Handle.bottomRight:
        final maxDelta = math.max(r.width + delta.dx, r.height + delta.dy).toDouble();
        final size = maxDelta.clamp(_minCropSize, math.min(_imageRect.right - r.left, _imageRect.bottom - r.top).toDouble());
        newRect = Rect.fromLTWH(
          r.left.clamp(_imageRect.left, _imageRect.right - _minCropSize),
          r.top.clamp(_imageRect.top, _imageRect.bottom - _minCropSize),
          size, size,
        );

      case _Handle.none:
        return;
    }

    setState(() => _cropRect = newRect);
  }

  void _onPanEnd(DragEndDetails d) {
    _activeHandle = _Handle.none;
    _dragStart = null;
    _cropRectStart = null;
  }

  /// 执行裁剪
  Future<String?> _doCrop() async {
    if (_image == null) return widget.imagePath;

    // 把屏幕裁剪框坐标映射到原图像素坐标
    final scaleX = _image!.width / _imageRect.width;
    final scaleY = _image!.height / _imageRect.height;

    final x = ((_cropRect.left - _imageRect.left) * scaleX).round().clamp(0, _image!.width);
    final y = ((_cropRect.top - _imageRect.top) * scaleY).round().clamp(0, _image!.height);
    final w = (_cropRect.width * scaleX).round().clamp(1, _image!.width - x);
    final h = (_cropRect.height * scaleY).round().clamp(1, _image!.height - y);

    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return widget.imagePath;

      final cropped = img.copyCrop(decoded, x: x, y: y, width: w, height: h);
      final outPath = '${Directory.systemTemp.path}/crop_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(outPath).writeAsBytes(img.encodeJpg(cropped, quality: 92));
      return outPath;
    } catch (e) {
      debugPrint('裁剪出错: $e');
      return widget.imagePath;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _image == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(children: [
          // 顶部工具栏
          Container(
            height: kToolbarHeight,
            color: Colors.black87,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                label: const Text('取消', style: TextStyle(color: Colors.white)),
              ),
              const Spacer(),
              const Text('拖动角点框选曲绘区域', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  final result = await _doCrop();
                  if (mounted) navigator.pop(result);
                },
                icon: const Icon(Icons.check, color: Colors.green, size: 20),
                label: const Text('确认', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ),
            ]),
          ),

          // 图片 + 裁剪框（用 LayoutBuilder 取实际尺寸）
          Expanded(
            child: LayoutBuilder(builder: (ctx, imageConstraints) {
              final actualSize = Size(imageConstraints.maxWidth, imageConstraints.maxHeight);
              _imageRect = _calcImageRect(actualSize);
              if (_cropRect.isEmpty || _cropRect == Rect.zero) {
                WidgetsBinding.instance.addPostFrameCallback((_) => _initCropRect());
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              }

              return GestureDetector(
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: MouseRegion(
                  cursor: _activeHandle != _Handle.none
                      ? _cursorForHandle(_activeHandle)
                      : SystemMouseCursors.basic,
                  child: Stack(children: [
                    Positioned.fill(
                      child: RawImage(image: _image, fit: BoxFit.contain),
                    ),
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _CropOverlayPainter(
                          imageRect: _imageRect,
                          cropRect: _cropRect,
                          handleSize: _handleSize,
                          handleBorderColor: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ]),
                ),
              );
            }),
          ),

          // 底部提示
          Container(
            height: 48,
            color: Colors.black87,
            alignment: Alignment.center,
            child: Text(
              '拖拽四角调整范围  |  拖拽框内移动位置',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
            ),
          ),
        ]),
      ),
    );
  }
}

/// 裁剪遮罩绘制器
class _CropOverlayPainter extends CustomPainter {
  final Rect imageRect;
  final Rect cropRect;
  final double handleSize;
  final Color handleBorderColor;

  _CropOverlayPainter({
    required this.imageRect,
    required this.cropRect,
    required this.handleSize,
    required this.handleBorderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 半透明遮罩
    final mask = Paint()..color = Colors.black.withValues(alpha: 0.55);
    // 上
    canvas.drawRect(Rect.fromLTRB(imageRect.left, imageRect.top, imageRect.right, cropRect.top), mask);
    // 下
    canvas.drawRect(Rect.fromLTRB(imageRect.left, cropRect.bottom, imageRect.right, imageRect.bottom), mask);
    // 左
    canvas.drawRect(Rect.fromLTRB(imageRect.left, cropRect.top, cropRect.left, cropRect.bottom), mask);
    // 右
    canvas.drawRect(Rect.fromLTRB(cropRect.right, cropRect.top, imageRect.right, cropRect.bottom), mask);

    // 裁剪框边框
    final border = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2;
    canvas.drawRect(cropRect, border);

    // 九宫格辅助线
    final grid = Paint()..color = Colors.white.withValues(alpha: 0.35)..style = PaintingStyle.stroke..strokeWidth = 0.5;
    final thirdW = cropRect.width / 3;
    final thirdH = cropRect.height / 3;
    for (int i = 1; i < 3; i++) {
      canvas.drawLine(Offset(cropRect.left + thirdW * i, cropRect.top), Offset(cropRect.left + thirdW * i, cropRect.bottom), grid);
      canvas.drawLine(Offset(cropRect.left, cropRect.top + thirdH * i), Offset(cropRect.right, cropRect.top + thirdH * i), grid);
    }

    // 四角手柄
    final handle = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final handleBorder = Paint()..color = handleBorderColor..style = PaintingStyle.stroke..strokeWidth = 1.5;
    for (final corner in [
      cropRect.topLeft, cropRect.topRight, cropRect.bottomLeft, cropRect.bottomRight,
    ]) {
      final r = Rect.fromCenter(center: corner, width: handleSize, height: handleSize);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)), handle);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)), handleBorder);
    }
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter old) => cropRect != old.cropRect || imageRect != old.imageRect;
}