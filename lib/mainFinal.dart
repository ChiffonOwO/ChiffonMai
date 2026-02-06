import 'package:flutter/material.dart';

// 程序入口：启动Flutter应用
void main() {
  runApp(const MyApp());
}

/// 应用根组件（无状态组件）
/// 作用：配置应用的主题、标题、首页等全局属性
class MyApp extends StatelessWidget {
  // 常量构造函数：创建不可变的MyApp实例
  const MyApp({super.key});

  // 构建UI的核心方法：返回应用的根视图
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // 应用标题（会显示在任务栏/应用列表等位置）
      title: 'ChiffonMai',
      // 关闭debug标签
      debugShowCheckedModeBanner: false,
      // 应用全局主题配置：定制化柔和蓝紫色系主题
      theme: ThemeData(
        primarySwatch: Colors.indigo, // 主色调改为柔和的靛蓝色（比纯蓝更舒服）
        scaffoldBackgroundColor: Colors.grey[50], // 页面背景色：浅灰色，避免纯白刺眼
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 2, // 导航栏轻微阴影
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        // 修复：CardTheme → CardThemeData，用shape替代borderRadius
        cardTheme: CardThemeData(
          elevation: 3, // 卡片轻微阴影
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), // 卡片圆角加大
          ),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // 卡片间距优化
        ),
      ),
      // 应用首页：指向MyHomePage组件
      home: MyHomePage(),
    );
  }
}

/// 首页组件（无状态组件）
/// 结构：顶部AppBar + 信息卡片 + 2列8行按钮网格（原有10个+新增6个）
class MyHomePage extends StatelessWidget {
  // 构造函数：移除const避免与非const数据源冲突
  MyHomePage({super.key});

  /// 按钮数据源：存储每个按钮的图标、主标题、副标题
  /// 格式：{'icon': 图标常量, 'title': 主标题文字, 'subtitle': 副标题文字}
  final List<Map<String, dynamic>> buttonData = [
    {'icon': Icons.music_note, 'title': '乐曲查询', 'subtitle': '查询舞萌曲库的乐曲'},
    {'icon': Icons.score, 'title': '成绩查询', 'subtitle': '查看游玩数据'},
    {'icon': Icons.leaderboard, 'title': 'Best50查询', 'subtitle': '查看你的b50'},
    {'icon': Icons.analytics, 'title': '拟合Best50查询', 'subtitle': '我w55怎么拟合才w52？！'},
    {'icon': Icons.grade, 'title': '基于Best50推荐', 'subtitle': '基于你的Best50推荐曲目'},
    {'icon': Icons.category, 'title': '基于流派推荐', 'subtitle': '基于你游玩的曲目流派推荐曲目'},
    {'icon': Icons.label, 'title': '基于标签推荐', 'subtitle': '基于你游玩的谱面标签推荐曲目'},
    {'icon': Icons.shuffle, 'title': '随机乐曲', 'subtitle': '随机选曲1-4首'},
    {'icon': Icons.calculate, 'title': '单曲Rating计算', 'subtitle': '我鸟加这个有分吃吗？'},
    {'icon': Icons.percent, 'title': '达成率计算', 'subtitle': '根据判定详情算出达成率'},
    {'icon': Icons.compare_arrows, 'title': '版本对照', 'subtitle': '舞神要打哪些代的歌？'},
    {'icon': Icons.cloud, 'title': '服务器状态', 'subtitle': '测试舞萌服务器状态（仅供参考）'},
    {'icon': Icons.qr_code, 'title': '绑定二维码', 'subtitle': '关联你的舞萌账号'},
    {'icon': Icons.update, 'title': '检查更新', 'subtitle': '检查应用是否有新版本'},
  ];

  /// 构建按钮列表
  /// 作用：遍历buttonData，生成带图标+主标题+副标题的ElevatedButton
  /// 返回值：Widget列表，供GridView展示
  List<Widget> _buildButtons() {
    // 初始化空列表存储按钮组件
    List<Widget> buttons = [];

    // 遍历数据源，逐个生成按钮
    for (int i = 0; i < buttonData.length; i++) {
      // 取出当前按钮的数据源
      final buttonItem = buttonData[i];

      // 构建单个按钮并添加到列表
      buttons.add(
        // 让按钮在网格单元格中居中显示
        Center(
          child: Container(
            // 按钮外层容器：添加渐变背景+阴影，提升质感
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey[200]!,
                  blurRadius: 4,
                  offset: const Offset(2, 2), // 右下轻微阴影
                  spreadRadius: 1,
                ),
              ],
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.indigo[50]!, // 浅靛蓝
                  Colors.indigo[100]!, // 稍深靛蓝
                ],
              ),
            ),
            child: ElevatedButton(
              // 按钮点击事件：打印点击的按钮标题（方便调试）
              onPressed: () => print('点击了${buttonItem['title']}按钮'),
              // 按钮样式配置（最终修复overlayColor类型错误）
              style: ElevatedButton.styleFrom(
                // 按钮固定尺寸：宽200，高120（适配长副标题）
                fixedSize: const Size(200, 120),
                // 按钮内边距：水平8px，垂直4px（避免内容贴边）
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                // 按钮形状：圆角矩形，圆角半径12px（和外层容器一致）
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                // 按钮背景透明（显示外层渐变）
                backgroundColor: Colors.transparent,
                // 去除按钮默认阴影
                elevation: 0,
                // 最终修复：直接传Color类型，移除MaterialStateProperty包装
                overlayColor: Colors.indigo[200]!.withOpacity(0.5),
              ),
              // 按钮内部内容：垂直排列（图标+主标题+副标题）
              child: Column(
                // 垂直方向居中对齐
                mainAxisAlignment: MainAxisAlignment.center,
                // 水平方向居中对齐
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ========== 图标组件 ==========
                  // 处理空白按钮的空图标：显示占位符或隐藏
                  buttonItem['icon'] != null
                      ? Icon(
                          buttonItem['icon'], // 图标类型（从数据源读取）
                          size: 28, // 图标尺寸加大，更醒目
                          color: Colors.indigo[700], // 图标颜色：深靛蓝，统一色调
                        )
                      : const SizedBox(height: 28), // 空按钮时占位，保持布局一致

                  // 图标与主标题的间距（加大，更透气）
                  const SizedBox(height: 4),

                  // ========== 主标题文字 ==========
                  Text(
                    buttonItem['title'], // 主标题文字（从数据源读取）
                    style: TextStyle(
                      fontSize: 15, // 字号加大
                      color: Colors.indigo[900], // 文字颜色：深靛蓝
                      fontWeight: FontWeight.w600, // 加粗，增强视觉层次
                      height: 1.2, // 行高，避免文字拥挤
                    ),
                    textAlign: TextAlign.center, // 居中对齐，避免文字溢出
                    maxLines: 1, // 限制1行，防止标题过长
                    overflow: TextOverflow.ellipsis, // 超出省略
                  ),

                  // 主标题与副标题间距
                  const SizedBox(height: 2),

                  // ========== 副标题文字（灰色小字） ==========
                  Text(
                    buttonItem['subtitle'], // 副标题文字（从数据源读取）
                    style: TextStyle(
                      fontSize: 9, // 字号微调
                      color: Colors.indigo[600]!.withOpacity(0.8), // 半透明靛蓝，区分主次
                      fontWeight: FontWeight.w400, // 字体粗细：常规
                      height: 1.2, // 行高优化
                    ),
                    textAlign: TextAlign.center, // 居中对齐，适配长文本换行
                    maxLines: 2, // 限制2行，防止副标题过长
                    overflow: TextOverflow.ellipsis, // 超出省略
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // 返回生成的按钮列表
    return buttons;
  }

  // 构建首页UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ========== 顶部导航栏 ==========
      appBar: AppBar(
        title: const Text(
          "ChiffonMai",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5, // 字间距，更美观
          ),
        ),
        centerTitle: true, // 标题居中显示
        backgroundColor: Colors.indigo[600], // 导航栏背景色：深靛蓝
      ),
      // ========== 页面主体内容 ==========
      body: Column(
        children: [
          // ========== 信息卡片组件 ==========
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), // 内边距优化
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center, // 垂直居中对齐
                children: [
                  // 左侧圆形头像（美化）
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(
                        color: Colors.indigo[200]!,
                        width: 3, // 头像边框，提升质感
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.indigo[100]!,
                          blurRadius: 6,
                          offset: const Offset(1, 1),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 40, // 头像半径：40px（直径80px）
                      backgroundColor: Colors.indigo[50], // 头像背景色
                      backgroundImage: NetworkImage(''), // 头像网络URL（你自行填写）
                      child: Icon(
                        Icons.person,
                        size: 40,
                        color: Colors.indigo[600], // 占位图标颜色统一
                      ),
                    ),
                  ),
                  // 头像与文字的间距（加大）
                  const SizedBox(width: 20),
                  // 右侧用户信息文字（三行）
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start, // 文字左对齐
                    children: [
                      Text(
                        'ID:ChiFFoN',
                        style: TextStyle(
                          fontSize: 18, // 字号加大
                          fontWeight: FontWeight.w700,
                          color: Colors.indigo[900], // 文字颜色统一
                        ),
                      ),
                      const SizedBox(height: 6), // 行间距加大
                      Text(
                        'Rating:16541',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.indigo[700]!.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6), // 行间距加大
                      Text(
                        'B35：11451 B15：1145',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.indigo[700]!.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // ========== 按钮网格组件 ==========
          Expanded(
            // 让网格占满剩余屏幕空间，避免布局溢出
            child: GridView.count(
              crossAxisCount: 2, // 网格列数：2列
              mainAxisSpacing: 5.0, // 行间距加大，更透气
              crossAxisSpacing: 5.0, // 列间距加大，更透气
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // 网格内边距优化
              childAspectRatio: 1.4, // 单元格宽高比微调，适配按钮
              shrinkWrap: true, // 适配父容器大小
              children: _buildButtons(), // 网格子组件：生成的按钮列表
            ),
          ),
        ],
      ),
    );
  }
}