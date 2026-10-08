import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// 统一处理外部链接跳转。
///
/// 不使用 [canLaunchUrl] 作为前置门槛：Android 11 及以上的包可见性规则、
/// 浏览器实现差异，以及部分厂商 ROM 都可能让它出现假阴性。直接调用
/// [launchUrl] 才能得到实际结果，再按不同模式重试。
class ExternalLaunchUtil {
  ExternalLaunchUtil._();

  static const _allowedSchemes = <String>{
    'https',
    'http',
    'mailto',
    'bilibili',
  };

  /// 尝试打开 URI，成功返回 true。
  ///
  /// 第一优先级是系统外部应用（浏览器、邮件客户端或对应 App），
  /// 失败后交给 url_launcher 的平台默认策略再尝试一次。
  static Future<bool> open(Uri uri) async {
    final scheme = uri.scheme.toLowerCase();
    if (uri.scheme.isEmpty || !_allowedSchemes.contains(scheme)) {
      return false;
    }
    if ((scheme == 'https' || scheme == 'http') && uri.host.isEmpty) {
      return false;
    }

    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return true;
      }
    } catch (_) {
      // 继续尝试平台默认模式，部分 ROM 只支持其中一种实现。
    }

    try {
      return await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (_) {
      return false;
    }
  }

  /// 解析并打开字符串形式的 URI。
  static Future<bool> openString(String value) async {
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return false;
    return open(uri);
  }

  /// 跳转失败时复制链接并给出明确提示，避免用户只能看到无响应。
  static Future<void> copyFallback(
    BuildContext context,
    String value, {
    String message = '无法打开链接，链接已复制到剪贴板，请手动粘贴到浏览器打开',
  }) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
