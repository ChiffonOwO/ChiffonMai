import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/AppTheme.dart';
import '../utils/CommonWidgetUtil.dart';
import '../utils/ExportSettings.dart';
import '../utils/ThemeManager.dart';
import '../widgets/PageTopBar.dart';

/// 设置页（独立页面，从首页主题弹窗"更多设置"进入）
///
/// 提供：
///   - 主题色：8 个预设色 + 自定义 ColorPicker；通过 `ColorScheme.fromSeed`
///     派生整套配色，主色变化时 60+ 页面同步更新
///   - 背景图：从相册选图，复制到应用文档目录持久化；可恢复默认 asset
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final ImagePicker _picker = ImagePicker();
  bool _pickingImage = false;

  /// 收藏夹导出后缀输入框
  final TextEditingController _favExtController = TextEditingController();
  String? _favExtError;

  @override
  void initState() {
    super.initState();
    _favExtController.text = ExportSettings.favoriteExtension.value;
  }

  @override
  void dispose() {
    _favExtController.dispose();
    super.dispose();
  }

  /// 预设色板（覆盖常见色调；保留原默认灰青作为第一位）
  static const List<Color> _presetColors = [
    Color(0xFF546161), // 默认灰青
    Color(0xFF1976D2), // 蓝
    Color(0xFF388E3C), // 绿
    Color(0xFF7B1FA2), // 紫
    Color(0xFFE65100), // 橙
    Color(0xFFC2185B), // 粉
    Color(0xFFD32F2F), // 红
    Color(0xFF00796B), // 青
  ];

  // ============ 图片操作 ============

  /// 清空 custom_bg 目录下所有 background.* 文件
  /// 避免旧文件残留 + Flutter ImageCache 命中同一 path 时的解码陈旧
  Future<void> _clearOldBackgroundFiles(Directory dir) async {
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      if (entity is File &&
          p.basename(entity.path).toLowerCase().startsWith('background.')) {
        try {
          // 同步 evict Flutter 解码缓存
          PaintingBinding.instance.imageCache
              .evict(FileImage(entity), includeLive: true);
          await entity.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> _pickBackground() async {
    if (_pickingImage) return;
    setState(() => _pickingImage = true);
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );
      if (photo == null) return;

      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(docs.path, 'custom_bg'));
      if (!await dir.exists()) await dir.create(recursive: true);

      // 先清空目录下所有旧 background.* 文件（包括当前生效的）
      // 原因 1：File.copy 在目标已存在时会抛异常；
      // 原因 2：Flutter ImageCache 按 path 缓存解码图，必须 evict 才能显示新内容
      final oldPath = ThemeManager().customBackgroundPath;
      if (oldPath != null) {
        PaintingBinding.instance.imageCache
            .evict(FileImage(File(oldPath)), includeLive: true);
      }
      await _clearOldBackgroundFiles(dir);

      final ext = p.extension(photo.path).isNotEmpty
          ? p.extension(photo.path)
          : '.jpg';
      final destPath = p.join(dir.path, 'background$ext');
      final destFile = File(destPath);

      // 先 writeAsBytes（覆盖写）而非 copy，避免同 path 残留时静默失败
      final bytes = await File(photo.path).readAsBytes();
      await destFile.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      await ThemeManager().setCustomBackgroundPath(destPath);
      if (mounted) {
        Fluttertoast.showToast(msg: '背景图已设置');
      }
    } catch (e) {
      if (mounted) Fluttertoast.showToast(msg: '选择图片失败: $e');
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  Future<void> _resetBackground() async {
    final current = ThemeManager().customBackgroundPath;
    await ThemeManager().setCustomBackgroundPath(null);
    // 删除已选文件 + evict 缓存
    if (current != null) {
      try {
        PaintingBinding.instance.imageCache
            .evict(FileImage(File(current)), includeLive: true);
        final f = File(current);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    // 同时清理目录下其他残留 background.*
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(docs.path, 'custom_bg'));
      await _clearOldBackgroundFiles(dir);
    } catch (_) {}
    if (mounted) Fluttertoast.showToast(msg: '已恢复默认背景');
  }

  // ============ 主题色操作 ============

  Future<void> _pickCustomColor() async {
    Color working = ThemeManager().seedColor ?? AppTheme.defaultLightSeed;
    final picked = await showDialog<Color?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text('自定义主题色'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: working,
              onColorChanged: (c) => working = c,
              enableAlpha: false,
              displayThumbColor: true,
              paletteType: PaletteType.hsvWithSaturation,
              labelTypes: const [],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                final input = await _promptHexInput(ctx, working);
                if (input != null && ctx.mounted) {
                  Navigator.pop(ctx, input);
                }
              },
              child: const Text('输入十六进制'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, working),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
    if (picked != null) {
      await ThemeManager().setSeedColor(picked);
      if (mounted) Fluttertoast.showToast(msg: '主题色已更新');
    }
  }

  /// 弹出输入十六进制颜色码的小框
  Future<Color?> _promptHexInput(BuildContext ctx, Color fallback) async {
    final controller = TextEditingController(
      text: '#${fallback.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}',
    );
    return showDialog<Color?>(
      context: ctx,
      builder: (dctx) => AlertDialog(
        title: const Text('输入十六进制颜色'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '#RRGGBB 或 #AARRGGBB',
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[#0-9a-fA-F]')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, null),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final raw = controller.text.trim();
              var hex = raw.startsWith('#') ? raw.substring(1) : raw;
              if (hex.length == 6) hex = 'FF$hex';
              if (hex.length != 8) return;
              final value = int.tryParse(hex, radix: 16);
              if (value == null) return;
              Navigator.pop(dctx, Color(value));
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetSeed() async {
    await ThemeManager().setSeedColor(null);
    if (mounted) Fluttertoast.showToast(msg: '已恢复默认主题色');
  }

  // ============ UI ============

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final sw = MediaQuery.of(context).size.width;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final c = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          CommonWidgetUtil.buildCommonBgWidget(),
          CommonWidgetUtil.buildCommonChiffonBgWidget(context),
          Column(
            children: [
              _buildTitleBar(sw, c),
              Expanded(
                child: ListenableBuilder(
                  listenable: Listenable.merge([
                    ThemeManager().seedColorNotifier,
                    ThemeManager().customBackgroundPathNotifier,
                    ThemeManager().chiffonOpacityNotifier,
                    ThemeManager().notifier,
                  ]),
                  builder: (context, _) {
                    return ListView(
                      padding: EdgeInsets.fromLTRB(
                          sw * 0.04, 8, sw * 0.04, 16 + safeBottom),
                      children: [
                        _buildPreviewCard(sw, brightness),
                        const SizedBox(height: 16),
                        _buildSectionTitle('主题色', c),
                        const SizedBox(height: 8),
                        _buildColorPalette(sw, c),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _pickCustomColor,
                                icon: const Icon(Icons.colorize),
                                label: const Text('自定义颜色'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _resetSeed,
                                icon: const Icon(Icons.refresh),
                                label: const Text('恢复默认'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildSectionTitle('背景图', c),
                        const SizedBox(height: 8),
                        _buildBackgroundSection(sw, c),
                        const SizedBox(height: 24),
                        _buildSectionTitle('装饰图透明度', c),
                        const SizedBox(height: 8),
                        _buildChiffonSection(sw, c),
                        const SizedBox(height: 24),
                        _buildSectionTitle('导出', c),
                        const SizedBox(height: 8),
                        _buildExportSection(sw, c),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 顶部栏统一走公共组件（标题样式对齐 Rating 排行榜页的 AppBar）
  Widget _buildTitleBar(double sw, Color c) =>
      const PageTopBar(title: '设置');

  Widget _buildSectionTitle(String title, Color c) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          title,
          style: TextStyle(
              color: c.withValues(alpha: 0.7),
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5),
        ),
      );

  Widget _buildPreviewCard(double sw, Brightness brightness) {
    final scheme = Theme.of(context).colorScheme;
    final bgPath = ThemeManager().customBackgroundPath;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 顶部"实时背景"缩略图
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(
              height: sw * 0.4,
              width: double.infinity,
              color: scheme.surfaceContainerHighest,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (bgPath != null)
                    Image.file(File(bgPath), fit: BoxFit.cover, gaplessPlayback: true)
                  else
                    Image.asset('assets/background.png',
                        fit: BoxFit.cover, gaplessPlayback: true),
                  // 主题色覆层
                  Container(color: scheme.primary.withValues(alpha: 0.18)),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '预览效果',
                        style: TextStyle(
                          color: scheme.onPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 底部色块组
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _previewSwatch('primary', scheme.primary, sw),
                const SizedBox(width: 8),
                _previewSwatch('secondary', scheme.secondary, sw),
                const SizedBox(width: 8),
                _previewSwatch('tertiary', scheme.tertiary, sw),
                const SizedBox(width: 8),
                _previewSwatch('surface', scheme.surface, sw),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewSwatch(String label, Color color, double sw) {
    final isLight = ThemeData.estimateBrightnessForColor(color) ==
        Brightness.light;
    final txtColor = isLight ? Colors.black87 : Colors.white;
    return Expanded(
      child: Container(
        height: sw * 0.16,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: txtColor,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildColorPalette(double sw, Color c) {
    final current = ThemeManager().seedColor;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _presetColors.map((color) {
        final isSelected = current != null &&
            current.toARGB32() == color.toARGB32();
        return GestureDetector(
          onTap: () async {
            await ThemeManager().setSeedColor(color);
            if (mounted) Fluttertoast.showToast(msg: '主题色已更新');
          },
          child: Container(
            width: sw * 0.13,
            height: sw * 0.13,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? c : Colors.black12,
                width: isSelected ? 3 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 22)
                : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBackgroundSection(double sw, Color c) {
    final bgPath = ThemeManager().customBackgroundPath;
    final brightness = Theme.of(context).brightness;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.15)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickingImage ? null : _pickBackground,
                  icon: _pickingImage
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.image),
                  label: Text(_pickingImage ? '处理中…' : '从相册选择'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: bgPath == null ? null : _resetBackground,
                  icon: const Icon(Icons.restore),
                  label: const Text('恢复默认'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: sw * 0.5,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (bgPath != null)
                    Image.file(File(bgPath), fit: BoxFit.cover, gaplessPlayback: true)
                  else
                    Image.asset('assets/background.png',
                        fit: BoxFit.cover, gaplessPlayback: true),
                  // 浅色模式洗白 / 深色模式压暗
                  Container(
                    color: brightness == Brightness.dark
                        ? Colors.black.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.55),
                  ),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        bgPath == null ? '当前：内置背景' : '当前：自定义图片',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '提示：自定义背景图会覆盖内置 background.png；浅色模式越接近纯白覆层，图片越淡。',
            style: TextStyle(
                color: c.withValues(alpha: 0.55), fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildChiffonSection(double sw, Color c) {
    final brightness = Theme.of(context).brightness;
    final opacity = ThemeManager().chiffonOpacity;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.15)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 预览：当前透明度下 chiffon 装饰图的效果
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: sw * 0.4,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset('assets/background.png',
                      fit: BoxFit.cover, gaplessPlayback: true),
                  Container(
                    color: brightness == Brightness.dark
                        ? Colors.black.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.55),
                  ),
                  Center(
                    child: Transform.translate(
                      offset: Offset(0, -sw * 0.4 * 0.03),
                      child: Image.asset(
                        'assets/chiffon2.png',
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        opacity: AlwaysStoppedAnimation(opacity),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('chiffon 装饰图透明度',
                  style: TextStyle(
                      color: c, fontSize: 14, fontWeight: FontWeight.w600)),
              Text('${(opacity * 100).round()}%',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: opacity,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            label: '${(opacity * 100).round()}%',
            onChanged: (value) {
              ThemeManager().setChiffonOpacity(value);
            },
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: opacity == 0.0
                      ? null
                      : () => ThemeManager().setChiffonOpacity(0.0),
                  icon: const Icon(Icons.visibility_off),
                  label: const Text('隐藏'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => ThemeManager().setChiffonOpacity(0.40),
                  icon: const Icon(Icons.refresh),
                  label: const Text('恢复默认 (40%)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '提示：纯黑模式下自动隐藏；深浅模式共用同一透明度。',
            style: TextStyle(
                color: c.withValues(alpha: 0.55), fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }

  /// 导出设置：收藏夹自定义后缀
  Widget _buildExportSection(double sw, Color c) {
    final current = ExportSettings.favoriteExtension.value;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.15)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('收藏夹导出后缀',
              style: TextStyle(
                  color: c, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _favExtController,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(
                        ExportSettings.maxExtensionLength + 1),
                  ],
                  decoration: InputDecoration(
                    prefixText: '.',
                    hintText: ExportSettings.defaultFavoriteExtension,
                    errorText: _favExtError,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _saveFavExtension(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _saveFavExtension,
                child: const Text('保存'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '导出收藏夹会生成 <名字>.$current 文件，'
            '放在 Download/ChiffonMai/收藏夹/ 下，文件管理器可以直接找到。\n'
            '导入按文件内容识别，与后缀无关，所以改成任意后缀都还能导回来。',
            style: TextStyle(
                color: c.withValues(alpha: 0.55), fontSize: 11, height: 1.4),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                _favExtController.text =
                    ExportSettings.defaultFavoriteExtension;
                _saveFavExtension();
              },
              icon: const Icon(Icons.refresh),
              label: Text(
                  '恢复默认 (.${ExportSettings.defaultFavoriteExtension})'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveFavExtension() async {
    final normalized = ExportSettings.normalize(_favExtController.text);
    if (normalized == null) {
      setState(() => _favExtError =
          '只能填 1-${ExportSettings.maxExtensionLength} 位字母、数字、下划线或连字符');
      return;
    }
    final ok = await ExportSettings.setFavoriteExtension(normalized);
    if (!mounted) return;
    setState(() {
      _favExtError = ok ? null : '保存失败，请重试';
      _favExtController.text = normalized;
    });
    if (ok) {
      Fluttertoast.showToast(msg: '收藏夹导出后缀已改为 .$normalized');
    }
  }
}