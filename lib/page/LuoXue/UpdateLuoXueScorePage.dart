import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../manager/DivingFishProbeManager.dart';
import '../../utils/AppTheme.dart';
import '../../constant/CacheKeyConstant.dart';

/// 同步成绩到落雪（对话框形式，与"同步成绩到水鱼"一致）
///
/// 通过输入机台 QR 码（SGWCMAID 开头），使用 Maimai Score Hub 的
/// cabinet-score-jobs API 抓取成绩，然后导出到落雪（LXNS）平台。
class UpdateLuoXueScorePage extends StatefulWidget {
  const UpdateLuoXueScorePage({super.key});

  @override
  State<UpdateLuoXueScorePage> createState() => _UpdateLuoXueScorePageState();

  /// 以对话框形式打开
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const UpdateLuoXueScorePage(),
    );
  }
}

class _UpdateLuoXueScorePageState extends State<UpdateLuoXueScorePage> {
  final TextEditingController _qrController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();
  bool _isSyncing = false;
  String _statusText = '';
  double? _progress;
  SyncStage? _currentStage;
  bool _isDone = false;
  String? _resultMessage;
  Timer? _autoCloseTimer;
  int _countdown = 5;
  bool _hasLxnsToken = false;
  bool _tokenChecked = false;

  @override
  void initState() {
    super.initState();
    _checkLxnsToken();
  }

  @override
  void dispose() {
    _qrController.dispose();
    _tokenController.dispose();
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkLxnsToken() async {
    final has = await DivingFishProbeManager().hasLxnsImportToken();
    if (mounted) {
      setState(() {
        _hasLxnsToken = has == true;
        _tokenChecked = true;
      });
    }
  }

  Future<void> _saveLxnsToken() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      Fluttertoast.showToast(msg: '请输入落雪个人 API 密钥');
      return;
    }
    final ok = await DivingFishProbeManager().setLxnsImportToken(token);
    if (mounted) {
      if (ok) {
        setState(() {
          _hasLxnsToken = true;
          _tokenController.clear();
        });
        Fluttertoast.showToast(msg: '落雪 API 密钥已保存');
      } else {
        Fluttertoast.showToast(msg: '保存失败，请检查网络后重试');
      }
    }
  }

  Future<void> _startSync() async {
    final qrCode = _qrController.text.trim();
    if (qrCode.isEmpty) {
      Fluttertoast.showToast(msg: '请先粘贴机台上的QR码字符串');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final cachedToken = prefs.getString(CacheKeyConstant.probeAuthToken);

    if (cachedToken == null || cachedToken.isEmpty) {
      Fluttertoast.showToast(msg: '请先使用「同步成绩到水鱼」功能完成一次同步，以建立认证');
      return;
    }

    if (!_hasLxnsToken) {
      final inputToken = _tokenController.text.trim();
      if (inputToken.isNotEmpty) {
        final ok = await DivingFishProbeManager().setLxnsImportToken(inputToken);
        if (ok) {
          setState(() {
            _hasLxnsToken = true;
            _tokenController.clear();
          });
        } else {
          Fluttertoast.showToast(msg: '保存落雪 API 密钥失败');
          return;
        }
      } else {
        Fluttertoast.showToast(msg: '请先设置落雪个人 API 密钥');
        return;
      }
    }

    setState(() {
      _isSyncing = true;
      _statusText = '准备同步...';
      _currentStage = SyncStage.authenticating;
      _isDone = false;
      _resultMessage = null;
    });

    final result = await DivingFishProbeManager().syncByCabinetQrToLxns(
      qrCode,
      onProgress: (p) {
        if (!mounted) return;
        setState(() {
          _currentStage = p.stage;
          _statusText = p.message;
          _progress = _stageProgress(p);
        });
      },
    );

    if (!mounted) return;

    if (result.isSuccess) {
      setState(() {
        _currentStage = SyncStage.completed;
        _isDone = true;
        _resultMessage = '同步完成！共同步 ${result.exportedCount} 条成绩到落雪';
        _statusText = _resultMessage!;
        _progress = 1.0;
      });
    } else if (result.errorMessage == '用户取消同步') {
      setState(() {
        _currentStage = SyncStage.cancelled;
        _isDone = true;
        _statusText = '同步已取消';
      });
    } else {
      setState(() {
        _currentStage = SyncStage.failed;
        _isDone = true;
        _statusText = result.errorMessage ?? '同步失败';
      });
    }

    if (_isDone) {
      _startAutoClose();
    }
  }

  void _cancelSync() {
    DivingFishProbeManager().cancelSync();
    setState(() {
      _currentStage = SyncStage.cancelled;
      _isDone = true;
      _statusText = '同步已取消';
    });
    _startAutoClose();
  }

  void _startAutoClose() {
    _autoCloseTimer?.cancel();
    _countdown = 5;
    _autoCloseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdown <= 0) {
        timer.cancel();
        Navigator.of(context).pop();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  double _stageProgress(SyncProgress p) {
    switch (p.stage) {
      case SyncStage.authenticating:
        return 0.05;
      case SyncStage.requesting:
        return 0.12;
      case SyncStage.scraping:
        return 0.15 + (p.progress ?? 0) * 0.55;
      case SyncStage.exporting:
        return 0.72;
      case SyncStage.completed:
        return 1.0;
      default:
        return 0.0;
    }
  }

  // ---------------------------------------------------------------------------
  // QR 码导入按钮
  // ---------------------------------------------------------------------------

  Widget _buildClipboardButton() {
    return OutlinedButton.icon(
      icon: const Icon(Icons.paste, size: 16),
      label: const Text('读取剪贴板', style: TextStyle(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      onPressed: () async {
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        final text = data?.text ?? '';
        if (text.trim().startsWith('SGWCMAID')) {
          setState(() => _qrController.text = text.trim());
          Fluttertoast.showToast(msg: '已识别到有效二维码字符串，已自动填入');
        } else if (text.isNotEmpty) {
          if (!mounted) return;
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('提示'),
              content: const Text('剪贴板内容未以 SGWCMAID 开头，仍要填入吗？'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('填入')),
              ],
            ),
          );
          if (confirmed == true) {
            setState(() => _qrController.text = text.trim());
          }
        }
      },
    );
  }

  Widget _buildGalleryQrButton() {
    return OutlinedButton.icon(
      icon: const Icon(Icons.photo_library, size: 16),
      label: const Text('从相册识别', style: TextStyle(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      onPressed: () async {
        try {
          final picker = ImagePicker();
          final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
          if (pickedFile == null) return;

          final controller = MobileScannerController();
          try {
            final barcodes = await controller.analyzeImage(pickedFile.path);
            if (barcodes != null && barcodes.barcodes.isNotEmpty) {
              final qrText = barcodes.barcodes.first.rawValue ?? '';
              if (qrText.isNotEmpty) {
                setState(() => _qrController.text = qrText);
                Fluttertoast.showToast(msg: '已识别到二维码，已自动填入');
              } else {
                Fluttertoast.showToast(msg: '未能从图片中识别到二维码内容');
              }
            } else {
              Fluttertoast.showToast(msg: '未在图片中检测到二维码');
            }
          } finally {
            controller.dispose();
          }
        } catch (e) {
          Fluttertoast.showToast(msg: '识别失败: $e');
        }
      },
    );
  }

  Widget _buildCameraScanButton() {
    return OutlinedButton.icon(
      icon: const Icon(Icons.qr_code_scanner, size: 16),
      label: const Text('扫描二维码', style: TextStyle(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      onPressed: () async {
        try {
          final result = await Navigator.of(context).push<String>(
            MaterialPageRoute(builder: (_) => const _QrScannerPage()),
          );
          if (result != null && result.isNotEmpty) {
            setState(() => _qrController.text = result);
            Fluttertoast.showToast(msg: '已扫描到二维码，已自动填入');
          }
        } catch (e) {
          Fluttertoast.showToast(msg: '扫码失败: $e');
        }
      },
    );
  }

  Widget _buildStageIcon(SyncStage? stage, Brightness brightness) {
    if (stage == null) return const SizedBox.shrink();
    switch (stage) {
      case SyncStage.completed:
        return Icon(Icons.check_circle, color: AppColors.successGreen(brightness), size: 36);
      case SyncStage.failed:
        return Icon(Icons.error, color: AppColors.errorRed(brightness), size: 36);
      case SyncStage.cancelled:
        return Icon(Icons.cancel, color: AppColors.greyHint(brightness), size: 36);
      default:
        return Icon(Icons.sync, color: AppColors.linkBlue(brightness), size: 36);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.cloud_sync, color: Theme.of(context).colorScheme.onSurface, size: 22),
          const SizedBox(width: 8),
          const Text('同步成绩到落雪'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ===== 阶段 1：输入 QR 码 =====
            if (!_isSyncing || _isDone) ...[
              Text(
                '在舞萌|中二公众号请求并打开二维码，扫描后将字符串粘贴到下方：',
                style: TextStyle(fontSize: 13, color: AppColors.greyHint(brightness)),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildClipboardButton(),
                  _buildGalleryQrButton(),
                  _buildCameraScanButton(),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _qrController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'SGWCMAID...',
                  hintStyle: TextStyle(fontSize: 13, color: AppColors.greyHint(brightness, shade: 400)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ],

            // ===== 落雪 API 密钥 =====
            if (_tokenChecked && !_isSyncing || _isDone) ...[
              const SizedBox(height: 16),
              // 获取 API 密钥的指引（未设置时显示）
              if (!_hasLxnsToken)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppColors.linkBlue(brightness).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.linkBlue(brightness).withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: AppColors.linkBlue(brightness)),
                          const SizedBox(width: 6),
                          Text('如何获取？',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                              color: AppColors.linkBlue(brightness))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () async {
                          final uri = Uri.parse('https://maimai.lxns.net/user/profile?tab=thirdparty');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        child: Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(text: '访问 ', style: TextStyle(fontSize: 12)),
                              TextSpan(
                                text: 'https://maimai.lxns.net/user/profile?tab=thirdparty',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                                  color: AppColors.linkBlue(brightness), decoration: TextDecoration.underline),
                              ),
                              const TextSpan(text: '，滑到页面最底部即可找到个人 API 密钥。',
                                style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _hasLxnsToken
                      ? AppColors.successGreen(brightness).withValues(alpha: 0.08)
                      : AppColors.warningOrange(brightness).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _hasLxnsToken
                        ? AppColors.successGreen(brightness).withValues(alpha: 0.2)
                        : AppColors.warningOrange(brightness).withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _hasLxnsToken ? Icons.check_circle : Icons.vpn_key,
                          size: 18,
                          color: _hasLxnsToken
                              ? AppColors.successGreen(brightness)
                              : AppColors.warningOrange(brightness),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _hasLxnsToken ? '落雪 API 密钥已设置' : '设置落雪个人 API 密钥',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    if (!_hasLxnsToken) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _tokenController,
                              obscureText: true,
                              decoration: InputDecoration(
                                hintText: '在此粘贴落雪个人 API 密钥...',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                isDense: true,
                              ),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _saveLxnsToken,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.linkBlue(brightness),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            child: const Text('保存', style: TextStyle(fontSize: 13)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // ===== 同步进度 =====
            if (_isSyncing) ...[
              Center(child: _buildStageIcon(_currentStage, brightness)),
              const SizedBox(height: 16),

              if (!_isDone) ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                ),
              ],

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _statusText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: _currentStage == SyncStage.failed || _currentStage == SyncStage.cancelled
                        ? AppColors.errorRed(brightness)
                        : _currentStage == SyncStage.completed
                            ? AppColors.successGreen(brightness)
                            : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),

              if (!_isDone) ...[
                const SizedBox(height: 10),
                if (_progress != null)
                  LinearProgressIndicator(value: _progress, color: AppColors.linkBlue(brightness))
                else
                  LinearProgressIndicator(color: AppColors.linkBlue(brightness)),
              ],

              if (_isDone && _resultMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    '${_resultMessage!}\n${_countdown > 0 ? "${_countdown}s 后自动关闭" : ""}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.greyHint(brightness)),
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        // 初始状态：关闭 + 开始同步
        if (!_isSyncing && !_isDone) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.cloud_sync, size: 18),
            label: const Text('开始同步'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.linkBlue(brightness),
              foregroundColor: Colors.white,
            ),
            onPressed: _startSync,
          ),
        ],

        // 同步中：取消按钮
        if (_isSyncing && !_isDone)
          TextButton(
            onPressed: _cancelSync,
            child: Text('取消同步', style: TextStyle(color: AppColors.errorRed(brightness))),
          ),

        // 完成/失败/取消：确定按钮
        if (_isDone)
          TextButton(
            onPressed: () {
              _autoCloseTimer?.cancel();
              Navigator.of(context).pop();
            },
            child: Text(_countdown > 0 ? '确定 ($_countdown)' : '确定'),
          ),
      ],
    );
  }
}

// =============================================================================
// 摄像头扫二维码页面
// =============================================================================

class _QrScannerPage extends StatefulWidget {
  const _QrScannerPage();

  @override
  State<_QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<_QrScannerPage> {
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
          if (barcode != null && barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
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
