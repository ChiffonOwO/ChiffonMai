import 'package:flutter/material.dart';

import '../manager/DivingFishProbeManager.dart';
import '../utils/AppTheme.dart';
import 'QrQuickFillButtons.dart';

/// 独立的 maimai Score Hub 登录入口。
///
/// 这里只做二维码认证并缓存 maimai Score Hub token，不创建成绩抓取任务。
Future<bool> showMaimaiHubLoginDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _MaimaiHubLoginDialog(),
  );
  return result == true;
}

class _MaimaiHubLoginDialog extends StatefulWidget {
  const _MaimaiHubLoginDialog();

  @override
  State<_MaimaiHubLoginDialog> createState() => _MaimaiHubLoginDialogState();
}

class _MaimaiHubLoginDialogState extends State<_MaimaiHubLoginDialog> {
  final TextEditingController _qrController = TextEditingController();
  bool _loggingIn = false;
  bool _success = false;
  String? _error;
  String? _inputError;

  @override
  void initState() {
    super.initState();
    _qrController.addListener(_validateQr);
  }

  void _validateQr() {
    final value = _qrController.text.trim();
    setState(() {
      _inputError = value.isEmpty
          ? '请粘贴或扫描登入二维码'
          : !value.startsWith('SGWCMAID')
              ? '请使用舞萌|中二公众号生成的登入二维码'
              : null;
      _error = null;
    });
  }

  @override
  void dispose() {
    _qrController.removeListener(_validateQr);
    _qrController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final qrCode = _qrController.text.trim();
    if (qrCode.isEmpty) {
      _validateQr();
      return;
    }
    if (!qrCode.startsWith('SGWCMAID')) {
      _validateQr();
      return;
    }

    setState(() {
      _loggingIn = true;
      _error = null;
    });
    try {
      final result = await DivingFishProbeManager().loginByQr(qrCode);
      if (!mounted) return;
      if (result == null) {
        setState(() {
          _loggingIn = false;
          _error = 'maimai Score Hub 登录失败，二维码可能已过期，请重新生成';
        });
        return;
      }
      setState(() {
        _loggingIn = false;
        _success = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loggingIn = false;
        _error = '登录失败：$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _success ? Icons.check_circle : Icons.qr_code_scanner,
            color:
                _success ? AppColors.successGreen(brightness) : scheme.primary,
            size: 22,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _success ? 'maimai Score Hub 登录成功' : '登录 maimai Score Hub',
              maxLines: 2,
              softWrap: true,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: _success
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle,
                      color: AppColors.successGreen(brightness), size: 52),
                  const SizedBox(height: 12),
                  const Text('登录状态已保存。现在可以直接使用 OCR，\n无需同步成绩。',
                      textAlign: TextAlign.center),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '只进行 maimai Score Hub 认证，不会抓取或同步成绩。',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.greyHint(brightness)),
                  ),
                  const SizedBox(height: 12),
                  QrQuickFillButtons(
                    controller: _qrController,
                    enabled: !_loggingIn,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _qrController,
                    maxLines: 3,
                    enabled: !_loggingIn,
                    decoration: InputDecoration(
                      hintText: '舞萌DX | 中二节奏 登入二维码(SGWCMAID...)',
                      hintStyle: TextStyle(
                          fontSize: 13,
                          color: AppColors.greyHint(brightness, shade: 400)),
                      border: const OutlineInputBorder(),
                      errorText: _inputError,
                      errorMaxLines: 3,
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!,
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.errorRed(brightness))),
                  ],
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed:
              _loggingIn ? null : () => Navigator.of(context).pop(_success),
          child: Text(_success ? '关闭' : '取消'),
        ),
        if (!_success)
          FilledButton.icon(
            onPressed: _loggingIn ? null : _login,
            icon: _loggingIn
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login, size: 18),
            label: Text(_loggingIn ? '登录中...' : '登录'),
          )
        else
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('完成'),
          ),
      ],
    );
  }
}
