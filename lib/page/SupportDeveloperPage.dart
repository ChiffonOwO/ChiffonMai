import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/CommonWidgetUtil.dart';
import '../utils/AppTheme.dart';

/// 支持开发者页面：展示赞赏码与爱发电链接。
class SupportDeveloperPage extends StatefulWidget {
  const SupportDeveloperPage({super.key});

  @override
  State<SupportDeveloperPage> createState() => _SupportDeveloperPageState();
}

class _SupportDeveloperPageState extends State<SupportDeveloperPage> {
  static const String _afdianUrl = 'https://ifdian.net/a/chiffonmai/plan';

  Future<void> _openAfdian() async {
    final uri = Uri.parse(_afdianUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
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
    final brightness = Theme.of(context).brightness;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final Color textPrimaryColor = Theme.of(context).colorScheme.onSurface;
    final Color cardBgColor = Theme.of(context).colorScheme.surface.withOpacity(0.9);
    final Color textSecondaryColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.7);
    final BoxShadow defaultShadow = AppColors.defaultShadow(brightness);

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          CommonWidgetUtil.buildCommonBgWidget(),
          CommonWidgetUtil.buildCommonChiffonBgWidget(context),

          Positioned(
            top: screenHeight * 0.06,
            left: 0,
            right: 0,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: textPrimaryColor),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '支持开发者',
                      style: TextStyle(
                        color: textPrimaryColor,
                        fontSize: screenWidth * 0.06,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),

          Positioned(
            left: screenWidth * 0.02,
            right: screenWidth * 0.02,
            top: screenHeight * 0.13,
            bottom: 10 + safeBottom,
            child: Container(
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [defaultShadow],
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
                        boxShadow: [defaultShadow],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        'assets/qrcode/zanshangma.jpg',
                        width: screenWidth * 0.55,
                        fit: BoxFit.contain,
                      ),
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
            ),
          ),
        ],
      ),
    );
  }
}