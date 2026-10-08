import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/AppTheme.dart';
import '../utils/ExternalLaunchUtil.dart';
import '../utils/ExportPathUtil.dart';
import '../widgets/BackgroundPageScaffold.dart';

/// 支持开发者页面：展示赞赏码与爱发电链接。
class SupportDeveloperPage extends StatefulWidget {
  const SupportDeveloperPage({super.key});

  @override
  State<SupportDeveloperPage> createState() => _SupportDeveloperPageState();
}

class _SupportDeveloperPageState extends State<SupportDeveloperPage> {
  static const String _afdianUrl = 'https://ifdian.net/a/chiffonmai/plan';
  bool _saving = false;

  Future<void> _downloadCode() async {
    setState(() => _saving = true);
    try {
      final data = await rootBundle.load('assets/qrcode/zanshangma.jpg');
      String? fallback;
      final file = await ExportPathUtil.writeExportFile(
          fileName: 'ChiffonMai_微信赞赏码.jpg',
          bytes:
              data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          subDir: '图片',
          onFallback: (path) => fallback = path);
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: const Text('赞赏码已保存'),
                  content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(file.path),
                        if (fallback != null) ...[
                          const SizedBox(height: 12),
                          Text('公开目录不可写，已保存到应用文档目录。可通过分享或应用文件访问。',
                              style: TextStyle(
                                  color: AppColors.warningOrange(
                                      Theme.of(ctx).brightness)))
                        ],
                      ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('知道了'))
                  ]));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败：$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openAfdian() async {
    final uri = Uri.parse(_afdianUrl);
    try {
      if (await ExternalLaunchUtil.open(uri)) {
        return;
      } else {
        _launchUrlFallback(_afdianUrl);
      }
    } catch (e) {
      debugPrint('打开爱发电链接失败: $e');
      _launchUrlFallback(_afdianUrl);
    }
  }

  void _launchUrlFallback(String url) {
    Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('无法打开浏览器，链接已复制到剪贴板，请手动粘贴到浏览器打开'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: '知道了',
            onPressed: () {},
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final Color textPrimaryColor = Theme.of(context).colorScheme.onSurface;
    final Color textSecondaryColor = Theme.of(
      context,
    ).colorScheme.onSurface.withOpacity(0.7);

    return BackgroundPageScaffold(
      title: '支持开发者',
      resizeToAvoidBottomInset: false,
      contentPadding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom + 10,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(screenWidth * 0.05),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'ChiffonMai 是一款完全免费的开源工具，\n如果它帮到了你，欢迎支持开发者！',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textSecondaryColor,
                fontSize: screenWidth * 0.035,
                height: 1.6,
              ),
            ),
            SizedBox(height: screenWidth * 0.05),
            Text(
              '微信赞赏码',
              style: TextStyle(
                color: textPrimaryColor,
                fontSize: screenWidth * 0.045,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: screenWidth * 0.03),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/qrcode/zanshangma.jpg',
                width: screenWidth * 0.55,
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(height: screenWidth * 0.05),
            OutlinedButton.icon(
              onPressed: _saving ? null : _downloadCode,
              icon: const Icon(Icons.download_outlined),
              label: Text(_saving ? '正在保存…' : '下载赞赏码图片'),
            ),
            SizedBox(height: screenWidth * 0.05),
            Text(
              '或通过爱发电支持我',
              style: TextStyle(
                color: textPrimaryColor,
                fontSize: screenWidth * 0.045,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: screenWidth * 0.03),
            ElevatedButton.icon(
              onPressed: _openAfdian,
              icon: const Icon(Icons.favorite),
              label: const Text('前往爱发电'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.08,
                  vertical: screenWidth * 0.03,
                ),
              ),
            ),
            SizedBox(height: screenWidth * 0.05),
            Text(
              '你的支持是我持续维护与开发的动力，感谢！❤️',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textSecondaryColor,
                fontSize: screenWidth * 0.032,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
