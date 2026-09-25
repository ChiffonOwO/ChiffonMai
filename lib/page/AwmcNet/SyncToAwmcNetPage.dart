import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/ApiUrls.dart';
import '../../constant/CacheKeyConstant.dart';
import '../../service/SyncStatsService.dart';
import '../../utils/AppTheme.dart';
import '../../widgets/QrQuickFillButtons.dart';
import '../../widgets/SyncStatsFooter.dart';

/// 用户在「同步成绩到 AWMC NET」对话框里填的两样东西。
class AwmcNetSyncInput {
  /// `SGWCMAID` 开头的机台登入二维码。
  final String qr;

  /// 用户在 net.wmc.pub 设置页生成的成绩导入 Token。
  final String importToken;

  const AwmcNetSyncInput({required this.qr, required this.importToken});
}

/// 打开「同步成绩到 AWMC NET」的**输入对话框**，返回用户填的内容（取消 = null）。
///
/// ⚠️ 这个对话框**只收集输入、点「开始同步」立刻关闭**：真正的导入由
/// `AwmcNetSyncFlow.run` 在对话框关掉之后跑，30 多秒的等待进度显示在
/// **按钮上**（与「同步成绩到水鱼 / 落雪」的交互完全一致）。
///
/// 早先它自己在对话框里转圈 + 数秒（`已等待 N 秒`），用户只能盯着一个模态框
/// 干等，而且和另外两个同步入口的交互不一样 —— 这次统一成按钮进度。
Future<AwmcNetSyncInput?> showAwmcNetSyncInputDialog(BuildContext context) {
  return showDialog<AwmcNetSyncInput>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const SyncToAwmcNetPage(),
  );
}

/// 「同步成绩到 AWMC NET」的输入对话框：机台二维码 + 成绩导入 Token。
///
/// 与「同步成绩到落雪」(`UpdateLuoXueScorePage`) 同构：粘贴/扫描机台登入二维码 +
/// 一个需要用户先在官网生成的凭据，然后提交。
///
/// AWMC NET 特有的两点（都只是**说明**，进度已经不在这里显示了）：
///   1. 导入要等约 36 秒（对方要登机台拉一整套成绩），所以按钮上的进度文案
///      会逐秒递增 —— 只转圈的话 30 多秒不动会被当成卡死；
///   2. 结果是**覆盖式**的（以机台为准重写已有成绩），所以警告放在**操作前**。
class SyncToAwmcNetPage extends StatefulWidget {
  const SyncToAwmcNetPage({super.key});

  @override
  State<SyncToAwmcNetPage> createState() => _SyncToAwmcNetPageState();
}

class _SyncToAwmcNetPageState extends State<SyncToAwmcNetPage> {
  final TextEditingController _qrController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();

  /// 已保存的导入 Token（null = 还没设置）。
  String? _savedToken;
  bool _tokenChecked = false;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  @override
  void dispose() {
    _qrController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(CacheKeyConstant.awmcNetImportToken);
    if (!mounted) return;
    setState(() {
      _savedToken = (token != null && token.isNotEmpty) ? token : null;
      _tokenChecked = true;
    });
  }

  Future<void> _saveToken() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      Fluttertoast.showToast(msg: '请输入 AWMC NET 成绩导入 Token');
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(CacheKeyConstant.awmcNetImportToken, token);
    if (!mounted) return;
    setState(() {
      _savedToken = token;
      _tokenController.clear();
    });
    Fluttertoast.showToast(msg: '导入 Token 已保存');
  }

  Future<void> _clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(CacheKeyConstant.awmcNetImportToken);
    if (!mounted) return;
    setState(() => _savedToken = null);
  }

  /// 校验 + 落盘 Token，然后**把输入交回调用方并关闭对话框**。
  ///
  /// 这里刻意不发请求：等待进度要显示在按钮上，所以真正的导入由
  /// `AwmcNetSyncFlow.run` 在对话框关闭后跑。
  Future<void> _submit() async {
    final qr = _qrController.text.trim();
    if (qr.isEmpty) {
      Fluttertoast.showToast(msg: '请先粘贴或扫描机台登入二维码（SGWCMAID 开头）');
      return;
    }
    final token = _savedToken ?? _tokenController.text.trim();
    if (token.isEmpty) {
      Fluttertoast.showToast(msg: '请先设置 AWMC NET 成绩导入 Token');
      return;
    }
    // 用户是直接在输入框里填的（没点保存）：顺手存下来，下次不用再填
    if (_savedToken == null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(CacheKeyConstant.awmcNetImportToken, token);
    }
    if (!mounted) return;
    Navigator.of(context).pop(AwmcNetSyncInput(qr: qr, importToken: token));
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.cloud_upload_outlined, color: scheme.onSurface, size: 22),
          const SizedBox(width: 8),
          // ⚠️ 必须 Expanded：AlertDialog 标题区在 360dp 屏上只剩 232dp，
          // 而「同步成绩到 AWMC NET」+ 图标要约 266dp，裸 Text 会直接
          // RenderFlex 溢出（真机实测 45px，测试里 134px；320dp 屏更大，
          // 系统字体调到 1.5 倍时到 286px）。Expanded 让它换行而不是溢出 ——
          // 落雪那条标题只有 6 个汉字，所以一直没暴露这个坑。
          const Expanded(child: Text('同步成绩到 AWMC NET')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 二维码 ──
            Text(
              '在「舞萌|中二」公众号请求登入二维码并打开，再粘贴到下方；'
              '也可直接用「扫描」或「从图片识别」。',
              style: TextStyle(fontSize: 13, color: AppColors.greyHint(brightness)),
            ),
            const SizedBox(height: 12),
            QrQuickFillButtons(controller: _qrController),
            const SizedBox(height: 12),
            TextField(
              controller: _qrController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: '舞萌DX | 中二节奏 登入二维码（SGWCMAID...）',
                hintStyle: TextStyle(
                    fontSize: 13, color: AppColors.greyHint(brightness, shade: 400)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 16),

            // ── 导入 Token ──
            if (_tokenChecked) _buildTokenSection(brightness, scheme),

            const SizedBox(height: 12),
            // 覆盖式写入这件事必须**在点开始之前**说：等导入完了再提醒就晚了
            _buildOverwriteWarning(brightness),

            // ── 近 100 次统计（所有使用者共享；点开看详情）──
            // 二维码直传没有线路可选，所以这里只有统计、没有线路切换器。
            const SizedBox(height: 10),
            const SyncStatsFooter(slot: (SyncLine.direct, SyncPlatform.awmc)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.send, size: 18),
          label: const Text('开始同步'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.linkBlue(brightness),
            foregroundColor: Colors.white,
          ),
          onPressed: _submit,
        ),
      ],
    );
  }

  Widget _buildTokenSection(Brightness brightness, ColorScheme scheme) {
    final hasToken = _savedToken != null;
    final accent = hasToken
        ? AppColors.successGreen(brightness)
        : AppColors.warningOrange(brightness);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(hasToken ? Icons.check_circle : Icons.vpn_key,
                  size: 18, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasToken ? '成绩导入 Token 已设置' : '设置 AWMC NET 成绩导入 Token',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              if (hasToken)
                TextButton(
                  onPressed: _clearToken,
                  child: const Text('更换', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          if (!hasToken) ...[
            const SizedBox(height: 8),
            _howToGetToken(brightness),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tokenController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: '在此粘贴成绩导入 Token…',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saveToken,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.linkBlue(brightness),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  child: const Text('保存', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _howToGetToken(Brightness brightness) {
    final hintStyle = TextStyle(fontSize: 12, color: AppColors.greyHint(brightness));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '导入需要在 AWMC NET 官网生成一次 Token（项目自带的密钥在这里用不了）：',
          style: hintStyle,
        ),
        const SizedBox(height: 4),
        Text('① 点击下面的链接打开 AWMC NET 设置页', style: hintStyle),
        Text('② 滑到页面最底部，点「生成/轮换Token」', style: hintStyle),
        Text('③ 复制生成的 Token，然后粘贴到此处', style: hintStyle),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => _openSettingsPage(),
          child: Text(
            ApiUrls.AwmcNetSettingsUrl,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.linkBlue(brightness),
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOverwriteWarning(Brightness brightness) {
    final warn = AppColors.warningOrange(brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: warn.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: warn.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: warn),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '导入约需 30 秒，进度显示在按钮上；以机台为准，'
              '会覆盖 AWMC NET 上已存在的对应成绩。',
              style: TextStyle(fontSize: 12, color: warn),
            ),
          ),
        ],
      ),
    );
  }

  /// 打开设置页（Token 在页面最底部生成）。
  ///
  /// 失败时给个 toast —— 之前这里是**静默** return 的，用户点了链接没反应
  /// 只会以为是 App 卡了。顺带兜一句路径，免得浏览器没打开时用户不知道去哪。
  Future<void> _openSettingsPage() async {
    final uri = Uri.parse(ApiUrls.AwmcNetSettingsUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (e) {
      debugPrint('打开 AWMC NET 设置页失败: $e');
    }
    if (!mounted) return;
    Fluttertoast.showToast(msg: '打不开浏览器，请手动访问 ${ApiUrls.AwmcNetSettingsUrl}');
  }
}
