import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// 弹出取色器选自定义主题色。
  ///
  /// 这里**换掉了 `flutter_colorpicker` 的 `ColorPicker`**：那个组件的取色区
  /// 宽度写死 `colorPickerWidth: 300`（见 colorpicker.dart 的 build），
  /// 而 AlertDialog 在手机上给 content 的宽度只有 280-40 ≈ 240dp ——
  /// 于是取色区**横向溢出**，右边一大块被裁掉/摸不到，用户只能在少数几个
  /// 恰好落在可见区域的位置取到色，表现就是「取色器用不了，只能用预设色」。
  ///
  /// 现在的实现见 `_ColorPickerDialog` / `_ColorPickerArea`：宽度自适应，
  /// 颜色存在 dialog 自己的 state 里（不依赖外层闭包变量），拖动即刷新预览。
  Future<void> _pickCustomColor() async {
    final picked = await showDialog<Color?>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => _ColorPickerDialog(
        initial: ThemeManager().seedColor ?? AppTheme.defaultLightSeed,
      ),
    );
    if (picked != null) {
      await ThemeManager().setSeedColor(picked);
      if (mounted) Fluttertoast.showToast(msg: '主题色已更新');
    }
  }

  /// 恢复默认主题色。
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

  /// 导出说明。
  ///
  /// 这里**曾经**是「收藏夹导出后缀」的输入框，现已取消自定义：
  /// 用户把后缀改成 `.json` / `.zip` 这类常见后缀后，系统会把本 App 记成
  /// 该类型文件的默认/首要打开方式，等于劫持了这些后缀（见 ExportSettings 注释）。
  /// 后缀固定为 `.cmf`，所以这里只剩一段只读说明，告诉用户文件落在哪。
  Widget _buildExportSection(double sw, Color c) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.15)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description_outlined, size: 18, color: c),
              const SizedBox(width: 6),
              Text('收藏夹导出后缀',
                  style: TextStyle(
                      color: c, fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              // 固定值，只读展示（不让改，避免劫持常见后缀的打开方式）
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  ExportSettings.favoriteExtensionWithDot,
                  style: TextStyle(
                    color: scheme.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '导出收藏夹会生成 <名字>${ExportSettings.favoriteExtensionWithDot} 文件，'
            '放在 Download/ChiffonMai/收藏夹/ 下，文件管理器可以直接找到。\n'
            '后缀已固定：自定义后缀会把常见格式的默认打开方式抢过来，所以不再开放。\n'
            '导入按文件内容识别、与后缀无关，以前用别的后缀导出的备份照样能导回来。',
            style: TextStyle(
                color: c.withValues(alpha: 0.55), fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }
}

// ============ 自定义取色器 ============
//
// 为什么不用 `flutter_colorpicker`：见 `_SettingsPageState._pickCustomColor` 的注释
// —— 它的取色区宽度写死 300，在手机 AlertDialog（content ≈ 240dp）里横向溢出，
// 溢出部分摸不到，于是「取色器用不了，只能用预设色」。
//
// 这里的实现只依赖 Flutter 自带的 `HSVColor` + `Gradient`，宽度完全交给父约束，
// 不引入任何硬编码尺寸。

/// `Color` → `#RRGGBB`（不含 alpha；主题 seed 一直是全不透明的）。
String _colorToHex(Color color) {
  final argb = color.toARGB32();
  final rgb = argb & 0x00FFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// `#RGB` / `#RRGGBB` / `#AARRGGBB` → `Color`；非法返回 null。
Color? _parseHexColor(String raw) {
  var hex = raw.trim();
  if (hex.startsWith('#')) hex = hex.substring(1);
  if (hex.length == 3) {
    // #abc → #aabbcc
    hex = hex.split('').map((ch) => '$ch$ch').join();
  }
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length != 8) return null;
  final value = int.tryParse(hex, radix: 16);
  return value == null ? null : Color(value);
}

/// 十六进制颜色输入框（设置页的"输入十六进制"和取色器弹窗共用）。
///
/// 输入非法时不关弹窗、就地显示错误，避免"点了确定没反应"。
Future<Color?> _showHexInputDialog(BuildContext context, Color fallback) {
  final controller = TextEditingController(text: _colorToHex(fallback));
  var error = '';
  return showDialog<Color?>(
    context: context,
    builder: (dctx) => StatefulBuilder(
      builder: (dctx, setLocal) {
        void submit() {
          final value = _parseHexColor(controller.text);
          if (value == null) {
            setLocal(() => error = '格式应为 #RRGGBB 或 #AARRGGBB');
            return;
          }
          Navigator.pop(dctx, value);
        }

        return AlertDialog(
          title: const Text('输入十六进制颜色'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: '#RRGGBB 或 #AARRGGBB',
              errorText: error.isEmpty ? null : error,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[#0-9a-fA-F]')),
              LengthLimitingTextInputFormatter(9),
            ],
            onSubmitted: (_) => submit(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dctx),
              child: const Text('取消'),
            ),
            TextButton(onPressed: submit, child: const Text('确定')),
          ],
        );
      },
    ),
  );
}

/// 自定义主题色弹窗：取色区 + 色相滑条 + 实时预览 + 十六进制输入。
class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.initial});

  final Color initial;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initial);

  Color get _color => _hsv.toColor();

  Future<void> _openHexInput() async {
    final picked = await _showHexInputDialog(context, _color);
    if (picked == null || !mounted) return;
    setState(() => _hsv = HSVColor.fromColor(picked));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: scheme.surface,
      title: const Text('自定义主题色'),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      content: SizedBox(
        // 让取色区在窄屏上也不会被撑爆；宽度跟着 dialog 走
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _ColorPickerArea(
                    // 测试用的稳定锚点（能直接量尺寸 / 点坐标）
                    key: const ValueKey('color-picker-area'),
                    hsv: _hsv,
                    onChanged: (hsv) => setState(() => _hsv = hsv),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('色相',
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              _HueSlider(
                key: const ValueKey('color-hue-slider'),
                hue: _hsv.hue,
                onChanged: (hue) => setState(
                    () => _hsv = _hsv.withHue(hue.clamp(0.0, 359.999))),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    key: const ValueKey('color-picker-preview'),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _color,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _colorToHex(_color),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '拖动上方方块选色，或直接输入十六进制',
                          style: TextStyle(
                              fontSize: 11, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: _openHexInput,
          child: const Text('输入十六进制'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _color),
          child: const Text('确定'),
        ),
      ],
    );
  }
}

/// 取色方块：横轴 = 饱和度，纵轴 = 明度。
///
/// 用两个渐变叠加（白→纯色相 铺满，透明→黑 垂直压暗）得到标准的 SV 面板，
/// 不需要任何自定义 `CustomPainter`。
class _ColorPickerArea extends StatelessWidget {
  const _ColorPickerArea({
    super.key,
    required this.hsv,
    required this.onChanged,
  });

  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;

  void _handle(Offset local, Size size) {
    final s = size.width <= 0 ? 0.0 : (local.dx / size.width).clamp(0.0, 1.0);
    final v = size.height <= 0
        ? 0.0
        : (1.0 - local.dy / size.height).clamp(0.0, 1.0);
    onChanged(hsv.withSaturation(s).withValue(v));
  }

  @override
  Widget build(BuildContext context) {
    final hueOnly = HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor();
    final thumbColor = hsv.toColor();
    final thumbBrightness =
        ThemeData.estimateBrightnessForColor(thumbColor);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final thumbLeft = (hsv.saturation * size.width).clamp(0.0, size.width);
        final thumbTop =
            ((1 - hsv.value) * size.height).clamp(0.0, size.height);
        return Listener(
          // ⚠️ 取色必须用 `Listener`（原始指针）而不是 `GestureDetector`：
          // 这个取色区在 `SingleChildScrollView` 里，`onTapDown` / `onPanDown`
          // 要等手势竞技场判定（最长 kPressTimeout = 100ms）才会触发 ——
          // 用户"点一下就走"根本取不到色，表现还是"取色器用不了"。
          // 原始指针事件没有竞技场，按下即生效。
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) => _handle(e.localPosition, size),
          onPointerMove: (e) => _handle(e.localPosition, size),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.white, hueOnly],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Positioned(
                left: thumbLeft - 11,
                top: thumbTop - 11,
                child: IgnorePointer(
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: thumbColor,
                      border: Border.all(
                        color: thumbBrightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87,
                        width: 2,
                      ),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 1)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 色相滑条（0-360）。
class _HueSlider extends StatelessWidget {
  const _HueSlider({
    super.key,
    required this.hue,
    required this.onChanged,
  });

  final double hue;
  final ValueChanged<double> onChanged;

  static const double _trackHeight = 22;
  static const double _thumbWidth = 14;

  /// 把全局坐标换算成 0-1 的横向比例。
  ///
  /// ⚠️ 同样用 `Listener`（原始指针）而不是 `GestureDetector`：滑条在
  /// `SingleChildScrollView` 里，`onTapDown` 要等竞技场判定才触发，
  /// 用户点一下松手是**取不到色**的（实测：点滑条中点颜色完全不变）。
  ///
  /// 这里用一个 `Builder` 的目的不是省代码：指针事件只给全局坐标，
  /// 要换算成本地比例就得拿到轨道自己的 `RenderBox` —— `LayoutBuilder`
  /// 的 builder context 与轨道 widget 不是同一个节点，量出来的宽度是错的。
  void _handle(BuildContext trackCtx, Offset globalPosition) {
    final box = trackCtx.findRenderObject() as RenderBox?;
    final width = box?.size.width ?? 0;
    if (box == null || width <= 0) return;
    final local = box.globalToLocal(globalPosition);
    onChanged((local.dx / width).clamp(0.0, 1.0) * 360);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _trackHeight,
      width: double.infinity,
      child: Builder(
        builder: (trackCtx) => Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) => _handle(trackCtx, e.position),
          onPointerMove: (e) => _handle(trackCtx, e.position),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final thumbLeft = (hue / 360 * width - _thumbWidth / 2)
                  .clamp(0.0, (width - _thumbWidth).clamp(0.0, width));
              return Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(_trackHeight / 2),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFF0000),
                            Color(0xFFFFFF00),
                            Color(0xFF00FF00),
                            Color(0xFF00FFFF),
                            Color(0xFF0000FF),
                            Color(0xFFFF00FF),
                            Color(0xFFFF0000),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: thumbLeft,
                    top: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Container(
                        width: _thumbWidth,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(color: Colors.black38, blurRadius: 3),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}