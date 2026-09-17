import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// 二维码「快速填入」三件套：读取剪贴板 / 从相册识别 / 扫描二维码。
///
/// 为什么要有这个组件：这套代码原来在 `SyncScoreDialogs`、`HomePage`、
/// `UpdateLuoXueScorePage` 里**各抄了一份**（3 份按钮实现 + 2 份扫码页），
/// 口径还不一致——「同步成绩到落雪」甚至只有剪贴板一个按钮，用户得先
/// 把二维码存到相册再手打。统一到这里之后，任何二维码输入框只要放一个
/// [QrQuickFillButtons] 就三件套齐全。
///
/// 用法（对话框里的输入框）：
/// ```dart
/// QrQuickFillButtons(
///   controller: qrController,
///   onFilled: () => setState(() => error = null), // 可选：填入后清旧的错误提示
/// )
/// ```
///
/// 约定：填入的字符串一律 `trim()`；识别失败/剪贴板为空只弹 toast，
/// 不改动输入框里已有的内容。
class QrQuickFillButtons extends StatelessWidget {
  /// 目标输入框控制器（由调用方持有，组件只负责写值）。
  final TextEditingController controller;

  /// 成功填入后的回调（例如清掉上次提交的红字错误）。
  final VoidCallback? onFilled;

  /// 置 false 时三个按钮都禁用（例如写入请求正在进行中）。
  final bool enabled;

  final double spacing;
  final double runSpacing;

  const QrQuickFillButtons({
    super.key,
    required this.controller,
    this.onFilled,
    this.enabled = true,
    this.spacing = 8,
    this.runSpacing = 8,
  });

  void _fill(String text) {
    controller.text = text.trim();
    onFilled?.call();
  }

  Future<void> _fromClipboard(BuildContext context) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.trim().startsWith('SGWCMAID')) {
      _fill(text);
      Fluttertoast.showToast(msg: '已识别到有效二维码字符串，已自动填入');
      return;
    }
    if (text.trim().isEmpty) {
      Fluttertoast.showToast(msg: '剪贴板为空');
      return;
    }
    // 不是标准二维码串：让用户自己确认，避免把乱七八糟的内容填进去
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('提示'),
        content: const Text('剪贴板内容不是有效的登入二维码，仍要填入吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('填入'),
          ),
        ],
      ),
    );
    if (confirmed == true) _fill(text);
  }

  Future<void> _fromGallery(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );
      if (pickedFile == null) return;

      // 用 mobile_scanner 离线解析图片里的二维码
      final scanner = MobileScannerController();
      try {
        final barcodes = await scanner.analyzeImage(pickedFile.path);
        if (barcodes == null || barcodes.barcodes.isEmpty) {
          Fluttertoast.showToast(msg: '未在图片中检测到二维码');
          return;
        }
        final qrText = barcodes.barcodes.first.rawValue ?? '';
        if (qrText.isEmpty) {
          Fluttertoast.showToast(msg: '未能从图片中识别到二维码内容');
          return;
        }
        _fill(qrText);
        Fluttertoast.showToast(msg: '已识别到二维码，已自动填入');
      } finally {
        scanner.dispose();
      }
    } catch (e) {
      debugPrint('[QrQuickFill] 相册识别失败: $e');
      Fluttertoast.showToast(msg: '识别失败: $e');
    }
  }

  Future<void> _fromCamera(BuildContext context) async {
    try {
      final result = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const QrScannerPage()),
      );
      if (result == null || result.trim().isEmpty) return;
      _fill(result);
      Fluttertoast.showToast(msg: '已识别到二维码，已自动填入');
    } catch (e) {
      debugPrint('[QrQuickFill] 扫码失败: $e');
      Fluttertoast.showToast(msg: '扫描失败: $e');
    }
  }

  Widget _button({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton.icon(
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      onPressed: onPressed,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: [
        _button(
          icon: Icons.paste,
          label: '读取剪贴板',
          onPressed: enabled ? () => _fromClipboard(context) : null,
        ),
        _button(
          icon: Icons.photo_library,
          label: '从相册识别',
          onPressed: enabled ? () => _fromGallery(context) : null,
        ),
        _button(
          icon: Icons.qr_code_scanner,
          label: '扫描二维码',
          onPressed: enabled ? () => _fromCamera(context) : null,
        ),
      ],
    );
  }
}

/// 摄像头扫二维码页面：识别到内容就 pop 回字符串。
class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  bool _hasPopped = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('扫描二维码'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: MobileScanner(
        onDetect: (BarcodeCapture capture) {
          if (_hasPopped) return;
          final barcode = capture.barcodes.firstOrNull;
          if (barcode != null &&
              barcode.rawValue != null &&
              barcode.rawValue!.isNotEmpty) {
            _hasPopped = true;
            Navigator.pop(context, barcode.rawValue);
          }
        },
        errorBuilder: (context, error) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('摄像头错误: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('返回'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
