import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_scanner/media_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:my_first_flutter_app/constant/VersionListConstant.dart';
import 'package:my_first_flutter_app/utils/StringUtil.dart';
import '../widgets/AnimatedChoiceBar.dart';
import '../widgets/BackgroundPageScaffold.dart';

/// 一个版本在日服与国服中的显示信息。
///
/// 标准版本的 [key] 直接使用 [VersionListConstant] 的值，列表顺序也只从常量类读取，
/// 避免版本筛选、歌曲详情和版本对照页各维护一份不同的世代列表。
class VersionData {
  final String key;
  final String japaneseName;
  final String imagePath;
  final String code;
  final String? chineseImagePath;
  final String? chineseCode;

  const VersionData({
    required this.key,
    required this.japaneseName,
    required this.imagePath,
    required this.code,
    this.chineseImagePath,
    this.chineseCode,
  });

  String get chineseName => StringUtil.formatVersion2(key);

  String imagePathFor(bool japanese) =>
      japanese ? imagePath : (chineseImagePath ?? imagePath);

  String codeFor(bool japanese) => japanese ? code : (chineseCode ?? code);
}

/// 版本图片预览与保存对话框。
class ImagePreviewDialog extends StatelessWidget {
  final String imagePath;
  final String versionName;

  const ImagePreviewDialog({
    super.key,
    required this.imagePath,
    required this.versionName,
  });

  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      final current = await [
        Permission.storage,
        Permission.photos,
        Permission.videos,
      ].request();
      return current.values.any((status) => status.isGranted);
    }
    return (await Permission.storage.request()).isGranted;
  }

  Future<void> _saveImage(BuildContext context) async {
    try {
      if (!await _requestStoragePermission()) {
        if (context.mounted) {
          _showMessage(context, '需要存储权限才能保存版本图，请在设置中开启权限');
        }
        return;
      }

      final data = await rootBundle.load(imagePath);
      final bytes = data.buffer.asUint8List();
      final directory = Platform.isAndroid
          ? Directory('/storage/emulated/0/Pictures')
          : await getApplicationDocumentsDirectory();
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      final safeName = versionName.replaceAll(RegExp(r'[^\w\-一-龥]+'), '_');
      final file = File(
        '${directory.path}/maimai_${safeName}_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);
      if (Platform.isAndroid) {
        await MediaScanner.loadMedia(path: file.path);
      }
      if (context.mounted) _showMessage(context, '图片已保存到相册');
    } catch (error) {
      if (context.mounted) _showMessage(context, '保存失败：$error');
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      versionName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 5,
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Padding(
                      padding: const EdgeInsets.all(32),
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        size: 56,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => _saveImage(context),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('保存图片'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VersionView extends StatefulWidget {
  const VersionView({super.key});

  @override
  State<VersionView> createState() => _VersionViewState();
}

class _VersionViewState extends State<VersionView> {
  bool _isJapaneseVersion = false;

  static const Map<String, VersionData> _catalog = {
    'maimai': VersionData(
      key: 'maimai',
      japaneseName: 'maimai',
      imagePath: 'assets/version/maimai.webp',
      code: '真',
    ),
    'maimai PLUS': VersionData(
      key: 'maimai PLUS',
      japaneseName: 'maimai PLUS',
      imagePath: 'assets/version/maimai_PLUS.webp',
      code: '真',
    ),
    'maimai GreeN': VersionData(
      key: 'maimai GreeN',
      japaneseName: 'GreeN',
      imagePath: 'assets/version/maimai_GreeN.webp',
      code: '超',
    ),
    'maimai GreeN PLUS': VersionData(
      key: 'maimai GreeN PLUS',
      japaneseName: 'GreeN PLUS',
      imagePath: 'assets/version/maimai_GreeN_PLUS.webp',
      code: '檄',
    ),
    'maimai ORANGE': VersionData(
      key: 'maimai ORANGE',
      japaneseName: 'ORANGE',
      imagePath: 'assets/version/maimai_ORANGE.webp',
      code: '橙',
    ),
    'maimai ORANGE PLUS': VersionData(
      key: 'maimai ORANGE PLUS',
      japaneseName: 'ORANGE PLUS',
      imagePath: 'assets/version/maimai_ORANGE_PLUS.webp',
      code: '晓',
    ),
    'maimai PiNK': VersionData(
      key: 'maimai PiNK',
      japaneseName: 'PiNK',
      imagePath: 'assets/version/maimai_PiNK.webp',
      code: '桃',
    ),
    'maimai PiNK PLUS': VersionData(
      key: 'maimai PiNK PLUS',
      japaneseName: 'PiNK PLUS',
      imagePath: 'assets/version/maimai_PiNK_PLUS.webp',
      code: '樱',
    ),
    'maimai MURASAKi': VersionData(
      key: 'maimai MURASAKi',
      japaneseName: 'MURASAKi',
      imagePath: 'assets/version/maimai_MURASAKi.webp',
      code: '紫',
    ),
    'maimai MURASAKi PLUS': VersionData(
      key: 'maimai MURASAKi PLUS',
      japaneseName: 'MURASAKi PLUS',
      imagePath: 'assets/version/maimai_MURASAKi_PLUS.webp',
      code: '堇',
    ),
    'maimai MiLK': VersionData(
      key: 'maimai MiLK',
      japaneseName: 'MiLK',
      imagePath: 'assets/version/maimai_MiLK.webp',
      code: '白',
    ),
    'MiLK PLUS': VersionData(
      key: 'MiLK PLUS',
      japaneseName: 'MiLK PLUS',
      imagePath: 'assets/version/maimai_MiLK_PLUS.webp',
      code: '雪',
    ),
    'maimai FiNALE': VersionData(
      key: 'maimai FiNALE',
      japaneseName: 'FiNALE',
      imagePath: 'assets/version/maimai_FiNALE.webp',
      code: '辉',
    ),
    'maimai でらっくす': VersionData(
      key: 'maimai でらっくす',
      japaneseName: 'DX',
      imagePath: 'assets/version/maimai_DX.webp',
      code: '熊',
      chineseImagePath: 'assets/version/maimai_2020.webp',
      chineseCode: '熊/華',
    ),
    'maimai でらっくす Splash': VersionData(
      key: 'maimai でらっくす Splash',
      japaneseName: 'Splash',
      imagePath: 'assets/version/maimai_DX_Splash.webp',
      code: '爽',
      chineseImagePath: 'assets/version/maimai_2021.webp',
      chineseCode: '爽/煌',
    ),
    'maimai でらっくす UNiVERSE': VersionData(
      key: 'maimai でらっくす UNiVERSE',
      japaneseName: 'UNiVERSE',
      imagePath: 'assets/version/maimai_DX_UNiVERSE.webp',
      code: '宙',
      chineseImagePath: 'assets/version/maimai_2022.webp',
      chineseCode: '宙/星',
    ),
    'maimai でらっくす FESTiVAL': VersionData(
      key: 'maimai でらっくす FESTiVAL',
      japaneseName: 'FESTiVAL',
      imagePath: 'assets/version/maimai_DX_FESTiVAL.webp',
      code: '祭',
      chineseImagePath: 'assets/version/maimai_2023.webp',
      chineseCode: '祭/祝',
    ),
    'maimai でらっくす BUDDiES': VersionData(
      key: 'maimai でらっくす BUDDiES',
      japaneseName: 'BUDDiES',
      imagePath: 'assets/version/maimai_DX_BUDDiES.webp',
      code: '双',
      chineseImagePath: 'assets/version/maimai_2024.webp',
      chineseCode: '双/宴',
    ),
    'maimai でらっくす PRiSM': VersionData(
      key: 'maimai でらっくす PRiSM',
      japaneseName: 'PRiSM',
      imagePath: 'assets/version/maimai_DX_PRiSM.webp',
      code: '镜',
      chineseImagePath: 'assets/version/maimai_2025.webp',
    ),
    'maimai でらっくす PRiSM PLUS': VersionData(
      key: 'maimai でらっくす PRiSM PLUS',
      japaneseName: 'PRiSM PLUS',
      imagePath: 'assets/version/maimai_DX_PRiSM_PLUS.webp',
      code: '彩',
      chineseImagePath: 'assets/version/maimai_2026.webp',
    ),
  };

  static const List<VersionData> _japaneseTail = [
    VersionData(
      key: 'maimai でらっくす CiRCLE',
      japaneseName: 'CiRCLE',
      imagePath: 'assets/version/maimai_DX_CiRCLE.webp',
      code: '丸',
    ),
    VersionData(
      key: 'maimai でらっくす CiRCLE PLUS',
      japaneseName: 'CiRCLE PLUS',
      imagePath: 'assets/version/maimai_DX_CiRCLE_PLUS.webp',
      code: '廻',
    ),
    VersionData(
      key: 'maimai でらっくす MAGiCAL',
      japaneseName: 'MAGiCAL',
      imagePath: 'assets/version/maimai_DX_MAGiCAL.webp',
      code: '—',
    ),
  ];

  List<VersionData> get _standardVersions => [
        for (final key in VersionListConstant.versionOrderList) _catalog[key]!,
      ];

  List<VersionData> get _versions => _isJapaneseVersion
      ? [..._standardVersions, ..._japaneseTail]
      : _standardVersions;

  void _showPreview(VersionData version) {
    final imagePath = version.imagePathFor(_isJapaneseVersion);
    if (imagePath.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (_) => ImagePreviewDialog(
        imagePath: imagePath,
        versionName:
            _isJapaneseVersion ? version.japaneseName : version.chineseName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final versions = _versions;

    return BackgroundPageScaffold(
      title: 'maimai 版本对照',
      contentPadding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom + 10,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 720
              ? 4
              : constraints.maxWidth >= 480
                  ? 3
                  : 2;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              AnimatedChoiceBar<bool>(
                values: const [false, true],
                value: _isJapaneseVersion,
                label: (isJapanese) => isJapanese ? '日服' : '国服',
                onChanged: (value) =>
                    setState(() => _isJapaneseVersion = value),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        color: scheme.primary, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isJapaneseVersion ? '日服版本' : '国服版本',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '共 ${versions.length} 个版本，按发行顺序排列。点击版本图可放大查看或保存。',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -23),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: versions.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: columns == 2 ? 0.86 : 0.9,
                  ),
                  itemBuilder: (context, index) => _buildVersionCard(
                    context,
                    versions[index],
                    index,
                    scheme,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVersionCard(
    BuildContext context,
    VersionData version,
    int index,
    ColorScheme scheme,
  ) {
    final name =
        _isJapaneseVersion ? version.japaneseName : version.chineseName;
    final imagePath = version.imagePathFor(_isJapaneseVersion);
    final code = version.codeFor(_isJapaneseVersion);
    return Semantics(
      button: true,
      label: imagePath.isEmpty ? '$name，版本图待补充' : '$name，点击查看版本图',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: imagePath.isEmpty ? null : () => _showPreview(version),
          child: Ink(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant),
            ),
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${index + 1}'.padLeft(2, '0'),
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        child: Text(
                          code,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            color: scheme.onPrimaryContainer,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Center(
                    child: imagePath.isEmpty
                        ? Text(
                            '图片待补',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          )
                        : Image.asset(
                            imagePath,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.image_not_supported_outlined,
                              size: 48,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  imagePath.isEmpty ? '等待补充版本图' : '点击查看大图',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
