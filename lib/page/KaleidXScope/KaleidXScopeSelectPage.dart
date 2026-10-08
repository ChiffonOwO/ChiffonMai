import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/page/KaleidXScope/KaleidXScopeInfoPageBLACK.dart';
import 'package:my_first_flutter_app/page/KaleidXScope/KaleidXScopeInfoPageBLUE.dart';
import 'package:my_first_flutter_app/page/KaleidXScope/KaleidXScopeInfoPageWHITE.dart';
import 'package:my_first_flutter_app/page/KaleidXScope/KaleidXScopeInfoPagePURPLE.dart';
import 'package:my_first_flutter_app/page/KaleidXScope/KaleidXScopeInfoPageYELLOW.dart';
import 'package:my_first_flutter_app/page/KaleidXScope/KaleidXScopeInfoPageRED.dart';
import '../../widgets/BackgroundPageScaffold.dart';
import '../../service/KaleidXScope/KaleidXScopeGateService.dart';
import 'KaleidXScopeGatePage.dart';

class KaleidXScopeSelectPage extends StatefulWidget {
  const KaleidXScopeSelectPage({super.key});

  @override
  State<KaleidXScopeSelectPage> createState() => _KaleidXScopeSelectPageState();
}

class _KaleidXScopeSelectPageState extends State<KaleidXScopeSelectPage> {
  // 图片和对应的副标题
  final List<Map<String, String?>> _scopeData = [
    {
      'image': 'assets/kaleidxscope/blue.webp',
      'title': '青の扉（蓝色之门）',
      'type': 'blue'
    },
    {
      'image': 'assets/kaleidxscope/white.webp',
      'title': '白の扉（白色之门）',
      'type': 'white'
    },
    {
      'image': 'assets/kaleidxscope/purple.webp',
      'title': '紫の扉（紫色之门）',
      'type': 'purple'
    },
    {
      'image': 'assets/kaleidxscope/black.webp',
      'title': '黑の扉（黑色之门）',
      'type': 'black'
    },
    {
      'image': 'assets/kaleidxscope/yellow.webp',
      'title': '黄の扉（黄色之门）',
      'type': 'yellow'
    },
    {
      'image': 'assets/kaleidxscope/red.webp',
      'title': '赤の扉（红色之门）',
      'type': 'red'
    },
  ];

  String? _listError;

  @override
  void initState() {
    super.initState();
    _loadGates();
  }

  Future<void> _loadGates() async {
    try {
      final gates = await KaleidXScopeGateService().fetchGates();
      if (!mounted) return;
      setState(() {
        _listError = null;
        _scopeData.removeWhere((item) => item['image'] == null);
        for (final gate in gates) {
          if (!_scopeData.any((item) => item['type'] == gate.color)) {
            _scopeData.add({
              'title': gate.displayName ?? gate.name,
              'type': gate.color,
              'image': gate.color == 'prism'
                  ? 'assets/kaleidxscope/prism.png'
                  : gate.color == 'hope'
                      ? 'assets/kaleidxscope/hope.png'
                      : gate.color == 'final'
                          ? 'assets/kaleidxscope/final.png'
                          : null,
            });
          }
        }
      });
    } catch (_) {
      if (mounted) setState(() => _listError = '新增门列表加载失败，请点击右上角刷新');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 获取设备尺寸
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // 响应式尺寸计算（与黑门页面一致）
    final double scaleFactor = screenWidth / 375.0;
    final double _paddingS = 4.0 * scaleFactor;

    // 自定义常量

    // 计算图片宽度，留出边距
    final imageWidth = screenWidth - (_paddingS * 4); // 左右各2*_paddingS的边距
    // 计算图片高度，确保在屏幕内可以完全显示
    // 减去标题栏、边距和间隔，平均分配给4张图片
    final availableHeight = screenHeight - 120; // 减去标题栏和底部边距
    final imageHeight = (availableHeight / 4) - 12; // 减去图片间隔

    return BackgroundPageScaffold(
      title: 'KALEIDXSCOPE',
      actions: [
                IconButton(
                    onPressed: _loadGates,
                    icon: const Icon(Icons.refresh),
                    tooltip: '刷新门列表')
              ],
      contentPadding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 10),
      child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_listError != null)
                        Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(_listError!)),
                      ..._scopeData
                          .map((item) => GestureDetector(
                                onTap: () {
                                  if (item['type'] == 'blue') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            KaleidXScopeInfoPageBLUE(),
                                      ),
                                    );
                                  } else if (item['type'] == 'white') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            KaleidXScopeInfoPageWHITE(),
                                      ),
                                    );
                                  } else if (item['type'] == 'purple') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            KaleidXScopeInfoPagePURPLE(),
                                      ),
                                    );
                                  } else if (item['type'] == 'black') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            KaleidXScopeInfoPageBLACK(),
                                      ),
                                    );
                                  } else if (item['type'] == 'yellow') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            KaleidXScopeInfoPageYELLOW(),
                                      ),
                                    );
                                  } else if (item['type'] == 'red') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            KaleidXScopeInfoPageRED(),
                                      ),
                                    );
                                  } else {
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                KaleidXScopeGatePage(
                                                    color: item['type']!,
                                                    title: item['title']!)));
                                  }
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Stack(
                                    children: [
                                      if (item['image'] != null)
                                        Image.asset(
                                          item['image']!,
                                          width: imageWidth,
                                          height: imageHeight,
                                          fit: BoxFit.contain,
                                        ),
                                      if (item['image'] == null)
                                        Container(
                                          width: imageWidth,
                                          height: imageHeight,
                                          margin: const EdgeInsets.symmetric(
                                              vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .surfaceContainer,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .outlineVariant),
                                          ),
                                          // 乱码之门没有立绘资源，用 ERROR 图标标识
                                          child: Icon(
                                              item['type'] == 'error'
                                                  ? Icons.error_outline
                                                  : Icons
                                                      .door_back_door_outlined,
                                              size: 64,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary),
                                        ),
                                      Positioned(
                                        bottom: 12,
                                        left: 0,
                                        right: 0,
                                        child: Center(
                                          child: Text(
                                            item['title']!,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ))
                          .toList(),
                    ],
                  ),
                ),
    );
  }
}
