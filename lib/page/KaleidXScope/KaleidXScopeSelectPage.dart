import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/page/KaleidXScope/KaleidXScopeInfoPageBLACK.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:my_first_flutter_app/page/KaleidXScope/KaleidXScopeInfoPageBLUE.dart';
import 'package:my_first_flutter_app/page/KaleidXScope/KaleidXScopeInfoPageWHITE.dart';
import 'package:my_first_flutter_app/page/KaleidXScope/KaleidXScopeInfoPagePURPLE.dart';

class KaleidXScopeSelectPage extends StatefulWidget {
  const KaleidXScopeSelectPage({super.key});

  @override
  State<KaleidXScopeSelectPage> createState() => _KaleidXScopeSelectPageState();
}

class _KaleidXScopeSelectPageState extends State<KaleidXScopeSelectPage> {
  // 图片和对应的副标题
  final List<Map<String, String>> _scopeData = [
    {'image': 'assets/kaleidxscope/blue.webp', 'title': '青の扉（蓝色之门）', 'type': 'blue'},
    {'image': 'assets/kaleidxscope/white.webp', 'title': '白の扉（白色之门）', 'type': 'white'},
    {'image': 'assets/kaleidxscope/purple.webp', 'title': '紫の扉（紫色之门）', 'type': 'purple'},
    {'image': 'assets/kaleidxscope/black.webp', 'title': '黑の扉（黑色之门）', 'type': 'black'},
  ];

  @override
  Widget build(BuildContext context) {
    // 获取设备尺寸
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // 响应式尺寸计算（与黑门页面一致）
    final double scaleFactor = screenWidth / 375.0;
    final double _paddingS = 8.0 * scaleFactor;
    final double _paddingL = 16.0 * scaleFactor;
    final double borderRadiusSmall = 8.0 * scaleFactor;
    final double shadowBlurRadius = 5.0 * scaleFactor;
    final double shadowOffset = 2.0 * scaleFactor;

    // 自定义常量
    final Color textPrimaryColor = Color.fromARGB(255, 84, 97, 97);
    final BoxShadow defaultShadow = BoxShadow(
      color: Colors.black12,
      blurRadius: shadowBlurRadius,
      offset: Offset(shadowOffset, shadowOffset),
    );

    // 计算图片宽度，留出边距
    final imageWidth = screenWidth - (_paddingS * 4); // 左右各2*_paddingS的边距
    // 计算图片高度，确保在屏幕内可以完全显示
    // 减去标题栏、边距和间隔，平均分配给4张图片
    final availableHeight = screenHeight - 120; // 减去标题栏和底部边距
    final imageHeight = (availableHeight / 4) - 12; // 减去图片间隔

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 背景
          CommonWidgetUtil.buildCommonBgWidget(),
          CommonWidgetUtil.buildCommonChiffonBgWidget(context),

          // 页面内容
          Column(
            children: [
              // 标题栏
              Container(
                padding: EdgeInsets.fromLTRB(16, 48, 16, 8),
                child: Row(
                  children: [
                    // 返回按钮
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: textPrimaryColor),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    // 标题
                    Expanded(
                      child: Center(
                        child: Text(
                          'KALEIDXSCOPE',
                          style: TextStyle(
                            color: textPrimaryColor,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // 占位，保持标题居中
                    SizedBox(width: 48),
                  ],
                ),
              ),

              // 主内容区域
              Expanded(
                child: Container(
                  margin: EdgeInsets.fromLTRB(_paddingS, 0, _paddingS, _paddingL),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(borderRadiusSmall),
                    boxShadow: [defaultShadow],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: _scopeData
                          .map((item) => GestureDetector(
                                onTap: () {
                                  if (item['type'] == 'blue') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => KaleidXScopeInfoPageBLUE(),
                                      ),
                                    );
                                  } else if (item['type'] == 'white') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => KaleidXScopeInfoPageWHITE(),
                                      ),
                                    );
                                  } else if (item['type'] == 'purple') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => KaleidXScopeInfoPagePURPLE(),
                                      ),
                                    );
                                  } else if (item['type'] == 'black') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => KaleidXScopeInfoPageBLACK(),
                                      ),
                                    );
                                  } else {
                                    // 其他门暂未开放
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('${item['title']}暂未开放'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Stack(
                                    children: [
                                      Image.asset(
                                        item['image']!,
                                        width: imageWidth,
                                        height: imageHeight,
                                        fit: BoxFit.contain,
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
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ),
              ),
            ]
          ),
        ],
      ),
    );
  }
}