import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';

// 应用常量类：集中管理所有硬编码的配置值
class AppConstants {
  // 阴影常量
  static const BoxShadow defaultShadow = BoxShadow(
    color: Colors.black12,
    blurRadius: 5.0,
    offset: Offset(2.0, 2.0),
  );

  // 颜色常量
  static const Color buttonBackgroundColor = Color.fromARGB(210, 227, 232, 125);
  static const Color buttonBorderColor = Color.fromARGB(199, 192, 133, 100);
  static const Color textPrimaryColor = Color.fromARGB(255, 84, 97, 97);
  static const Color textSecondaryColor = Color.fromARGB(255, 109, 125, 125);
}

// 版本数据模型
class VersionData {
  final String name;
  final String imagePath;
  final String code;

  VersionData({
    required this.name,
    required this.imagePath,
    required this.code,
  });
}

// 图片预览对话框
class ImagePreviewDialog extends StatelessWidget {
  final String imagePath;
  final String versionName;

  const ImagePreviewDialog({
    super.key,
    required this.imagePath,
    required this.versionName,
  });

  // 保存图片到本地
  Future<void> _saveImage(BuildContext context) async {
    try {
      // 请求存储权限
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (status != PermissionStatus.granted) {
          _showSnackBar(context, '需要存储权限才能保存图片');
          return;
        }
      }

      // 加载图片
      final ByteData imageData = await rootBundle.load(imagePath);
      final Uint8List bytes = imageData.buffer.asUint8List();

      // 获取保存目录
      final Directory directory = await getApplicationDocumentsDirectory();
      final String fileName = 'maimai_${versionName.replaceAll(' ', '_')}.png';
      final File file = File('${directory.path}/$fileName');

      // 写入文件
      await file.writeAsBytes(bytes);

      _showSnackBar(context, '图片已保存到相册');
    } catch (e) {
      _showSnackBar(context, '保存失败：$e');
    }
  }

  // 显示提示信息
  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 获取屏幕高度并计算对话框高度为屏幕高度的0.3倍
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogHeight = screenHeight * 0.3;
    
    return Dialog(
      backgroundColor: Colors.white.withOpacity(0.9),
      child: SizedBox(
        height: dialogHeight,
        child: Stack(
          children: [
            // 放大图片
            Center(
              child: InteractiveViewer(
                maxScale: 5.0,
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                  height: dialogHeight,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Text(
                        '图片加载失败',
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  },
                ),
              ),
            ),

            // 保存按钮
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton(
                onPressed: () => _saveImage(context),
                backgroundColor: Colors.blue,
                child: const Icon(Icons.save_alt),
              ),
            ),

            // 关闭按钮
            Positioned(
              top: 20,
              right: 20,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.black, size: 30),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 版本对照表页面
class VersionView extends StatelessWidget {
  // 具体版本数据
  final List<VersionData> versionList = [
    VersionData(name: "maimai PLUS", imagePath: "assets/version/maimai_PLUS.png", code: "真"),
    VersionData(name: "GreeN", imagePath: "assets/version/maimai_GreeN.png", code: "超"),
    VersionData(name: "GreeN PLUS", imagePath: "assets/version/maimai_GreeN_PLUS.png", code: "檄"),
    VersionData(name: "ORANGE", imagePath: "assets/version/maimai_ORANGE.png", code: "橙"),
    VersionData(name: "ORANGE PLUS", imagePath: "assets/version/maimai_ORANGE_PLUS.png", code: "晓"),
    VersionData(name: "PiNK", imagePath: "assets/version/maimai_PiNK.png", code: "桃"),
    VersionData(name: "PiNK PLUS", imagePath: "assets/version/maimai_PiNK_PLUS.png", code: "樱"),
    VersionData(name: "MURASAKi", imagePath: "assets/version/maimai_MURASAKi.png", code: "紫"),
    VersionData(name: "MURASAKi PLUS", imagePath: "assets/version/maimai_MURASAKi_PLUS.png", code: "堇"),
    VersionData(name: "MiLK", imagePath: "assets/version/maimai_MiLK.png", code: "白"),
    VersionData(name: "MiLK PLUS", imagePath: "assets/version/maimai_MiLK_PLUS.png", code: "雪"),
    VersionData(name: "FiNALE", imagePath: "assets/version/maimai_FiNALE.png", code: "辉"),
    VersionData(name: "ALL FiNALE", imagePath: "assets/version/WuShen.png", code: "舞"),
    VersionData(name: "DX", imagePath: "assets/version/maimai_DX.png", code: "熊"),
    VersionData(name: "DX PLUS", imagePath: "assets/version/maimai_DX_PLUS.png", code: "華"),
    VersionData(name: "Splash", imagePath: "assets/version/maimai_DX_Splash.png", code: "爽"),
    VersionData(name: "Splash PLUS", imagePath: "assets/version/maimai_DX_Splash_PLUS.png", code: "煌"),
    VersionData(name: "UNiVERSE", imagePath: "assets/version/maimai_DX_UNiVERSE.png", code: "宙"),
    VersionData(name: "UNiVERSE PLUS", imagePath: "assets/version/maimai_DX_UNiVERSE_PLUS.png", code: "星"),
    VersionData(name: "FESTiVAL", imagePath: "assets/version/maimai_DX_FESTiVAL.png", code: "祭"),
    VersionData(name: "FESTiVAL PLUS", imagePath: "assets/version/maimai_DX_FESTiVAL_PLUS.png", code: "祝"),
    VersionData(name: "BUDDiES", imagePath: "assets/version/maimai_DX_BUDDiES.png", code: "双"),
    VersionData(name: "BUDDiES PLUS", imagePath: "assets/version/maimai_DX_BUDDiES_PLUS.png", code: "宴"),
    VersionData(name: "PRiSM", imagePath: "assets/version/maimai_DX_PRiSM.png", code: "镜"),
    VersionData(name: "PRiSM PLUS", imagePath: "assets/version/maimai_DX_PRiSM_PLUS.png", code: "彩"),
    VersionData(name: "CiRCLE", imagePath: "assets/version/maimai_DX_CiRCLE.png", code: "丸"),
  ];
  VersionView({super.key});

  @override
  Widget build(BuildContext context) {
    // 获取屏幕尺寸
    final screenWidth = MediaQuery.of(context).size.width;
    
    // 字体大小
    final titleFontSize = screenWidth * 0.06; // 标题字体大小为屏幕宽度的6%
    final tableHeaderFontSize = screenWidth * 0.035; // 表头字体大小为屏幕宽度的3.5%
    final tableContentFontSize = screenWidth * 0.03; // 表格内容字体大小为屏幕宽度的3%
    
    // 图片大小
    final imageContainerSize = screenWidth * 0.15; // 图片容器大小为屏幕宽度的15%
    final imageSize = screenWidth * 0.12; // 图片大小为屏幕宽度的12%
    
    // 自定义常量
    final Color textPrimaryColor = AppConstants.textPrimaryColor;
    final double borderRadiusSmall = 8.0;
    final BoxShadow defaultShadow = AppConstants.defaultShadow;

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
                          'maimai版本对照表',
                          style: TextStyle(
                            color: textPrimaryColor,
                            fontSize: titleFontSize,
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
                  margin: EdgeInsets.fromLTRB(8, 0, 8, 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(borderRadiusSmall),
                    boxShadow: [defaultShadow],
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final tableWidth = constraints.maxWidth;
                      final column1Width = tableWidth * 0.3;
                      final column2Width = tableWidth * 0.35;
                      final column3Width = tableWidth * 0.35;
                      
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: DataTable(
                          columnSpacing: 0, // 清除默认列间距， ourselves控制宽度
                          columns: [
                            DataColumn(
                              label: SizedBox(
                                width: column1Width,
                                child: Center(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '版本名称',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                        fontSize: tableHeaderFontSize,
                                      ),
                                    ),
                                  )
                                ),
                              ),
                            ),
                            DataColumn(
                              label: SizedBox(
                                width: column2Width,
                                child: Center(
                                  child: Text(
                                    '版本图',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: tableHeaderFontSize,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            DataColumn(
                              label: SizedBox(
                                width: column3Width,
                                child: Center(
                                  child: Text(
                                    '版本代号',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: tableHeaderFontSize,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                      rows: versionList.map((version) {
                        return DataRow(cells: [
                          DataCell(
                            SizedBox(
                              width: column1Width,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(version.name, style: TextStyle(fontSize: tableContentFontSize)),
                              )
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: column2Width,
                              child: Center(
                                child: Container(
                                  width: imageContainerSize,
                                  height: imageContainerSize,
                                  alignment: Alignment.center,
                                  child: GestureDetector(
                                    onTap: () {
                                      if (version.imagePath.isNotEmpty) {
                                        showDialog(
                                          context: context,
                                          builder: (context) => ImagePreviewDialog(
                                            imagePath: version.imagePath,
                                            versionName: version.name,
                                          ),
                                        );
                                      }
                                    },
                                    child: Image.asset(
                                      version.imagePath,
                                      width: imageSize,
                                      height: imageSize,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          width: imageSize,
                                          height: imageSize,
                                          color: Colors.grey[200],
                                          child: Center(child: Text('图片缺失', style: TextStyle(fontSize: tableContentFontSize))),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: column3Width,
                              child: Center(child: Text(version.code, style: TextStyle(fontSize: tableContentFontSize))),
                            ),
                          ),
                        ]);
                      }).toList(),
                    ),
                  );
                },
              ),
                ),
              )
            ],
          ),
        ],
      ),
    );
  }
}