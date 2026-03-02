import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/page/B50Page.dart';
import 'package:my_first_flutter_app/page/RecommendByBest50.dart';
import 'package:my_first_flutter_app/page/RecommendByTags.dart';
import 'package:my_first_flutter_app/page/SingleRatingCalculator.dart';
import 'package:my_first_flutter_app/page/SongSearchPage.dart';
import 'page/AchievementFullReverseCalculator.dart';
import 'page/versionView.dart';
import 'page/AchievementRateCalculator.dart';

// 应用常量类：集中管理所有硬编码的配置值
class AppConstants {
  // 布局尺寸常量
  static const double targetHeight = 380.0;
  static const double blockSpacing = 160.0;
  static const double textLeft = 185.0;
  static const double textTop = 180.0;
  static const double buttonHeight = 70.0;
  static const double gridHorizontalPadding = 15.0; // 减小GridView左右边距
  static const double buttonPaddingVertical = 6.0;
  static const double buttonPaddingHorizontal = 4.0;

  // 网格布局常量
  static const int crossAxisCount = 2;
  static const double crossAxisSpacing = 8.0; // 减小按钮横向间距
  static const double mainAxisSpacing = 4.0; // 减小按钮纵向间距
  static const double childAspectRatio = 1.2;

  // 圆角常量
  static const double borderRadiusSmall = 8.0;
  static const double borderRadiusLarge = 12.0;

  // 边框常量
  static const double borderWidth = 1.5;

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

// 按钮项数据模型
class ButtonItem {
  final IconData icon;
  final String title;
  final String subtitle;

  const ButtonItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

// 程序入口：运行Flutter应用，根组件为MyApp
void main() {
  runApp(const MyApp());
}

/// 应用根组件：无状态组件，配置MaterialApp基础属性
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // 隐藏右上角调试横幅
      home: const HomePage(), // 应用首页为HomePage组件
    );
  }
}

/// 首页组件：有状态组件，包含所有页面元素和业务数据
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

/// 首页状态类：处理页面状态、存储数据、实现布局构建
class _HomePageState extends State<HomePage> {
  // 按钮数据源：使用类型安全的ButtonItem模型
  final List<ButtonItem> buttonItems = const [
    ButtonItem(icon: Icons.music_note, title: '乐曲查询', subtitle: '查询舞萌曲库的乐曲'),
    ButtonItem(icon: Icons.score, title: '成绩查询', subtitle: '查看游玩数据'),
    ButtonItem(icon: Icons.leaderboard, title: 'Best50查询', subtitle: '我去,龙币!'),
    ButtonItem(icon: Icons.analytics, title: '拟合Best50查询', subtitle: '我w55怎么拟合才w52?!'),
    ButtonItem(icon: Icons.grade, title: '基于Best50推荐', subtitle: '基于你的Best50推荐曲目'),
    ButtonItem(icon: Icons.label, title: '基于标签推荐', subtitle: '基于你游玩的谱面标签推荐曲目'),
    ButtonItem(icon: Icons.shuffle, title: '随机乐曲', subtitle: '随机选曲1-4首'),
    ButtonItem(icon: Icons.calculate, title: '单曲Rating计算', subtitle: '我鸟加这个有分吃吗？'),
    ButtonItem(icon: Icons.percent, title: '达成率计算', subtitle: '根据判定详情算出达成率'),
    ButtonItem(icon: Icons.compare_arrows, title: '版本对照', subtitle: '舞神要打哪些代的歌？'),
    ButtonItem(icon: Icons.replay, title: '达成率反推', subtitle: '根据判定详情推出绝赞详情'),
    ButtonItem(icon: Icons.qr_code, title: '绑定二维码', subtitle: '关联你的舞萌账号'),
    ButtonItem(icon: Icons.update, title: '检查更新', subtitle: '检查应用是否有新版本'),
  ];

  @override
  Widget build(BuildContext context) {

    // 页面根布局：Scaffold + Stack 实现多层级叠加布局
    // Stack子组件按书写顺序从上到下叠加，越靠后层级越高
    return Scaffold(
      backgroundColor: Colors.transparent, // 透明背景，显示底层图片
      body: Stack(
        children: [
          // 层级1：基础背景图 - 占满整个屏幕，作为页面最底层背景
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background.png'), // 背景图资源
                fit: BoxFit.cover, // 覆盖整个容器，拉伸/裁剪适配
                opacity: 1.0, // 不透明
              ),
            ),
          ),

          // 层级2：第一张虚化装饰图 - 居中显示，轻微向上偏移
          Center(
            child: Transform.translate(
              offset: const Offset(0, -20), // 垂直向上偏移20px
              child: Transform.scale(
                scale: 1, // 不缩放
                child: Image.asset(
                  'assets/chiffon2.png',
                  fit: BoxFit.cover,
                  opacity: const AlwaysStoppedAnimation(1), // 固定不透明
                ),
              ),
            ),
          ),

          // 层级3：第二张虚化装饰图 - 居中显示，与层级2重叠，增强视觉效果
          Center(
            child: Transform.translate(
              offset: const Offset(0, -20),
              child: Transform.scale(
                scale: 1,
                child: Image.asset(
                  'assets/userinfobg.png',
                  fit: BoxFit.cover,
                  opacity: const AlwaysStoppedAnimation(1),
                ),
              ),
            ),
          ),

          // 层级3.5：页面标题
            const Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Text(
                    "ChiffonMai",
                    style: TextStyle(
                      color: AppConstants.textPrimaryColor,
                      fontSize: 24, // 减小字号
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: 8), // 添加间距
                  Text(
                    "基本信息",
                    style: TextStyle(
                      color: AppConstants.textPrimaryColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          // 层级4：个人信息静态文本
            Positioned(
              left: AppConstants.textLeft,
              top: AppConstants.textTop,
              child: _buildUserInfo(),
            ),

          
          // 功能中心标题
          const Positioned(
            left: AppConstants.gridHorizontalPadding,
            right: AppConstants.gridHorizontalPadding,
            bottom: 500, // 在GridView上方定位
            child: Center(
              child: Text(
                "功能中心",
                style: TextStyle(
                  color: AppConstants.textPrimaryColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // 层级5：核心功能区 - 直接使用Positioned定位GridView
          Positioned(
            left: AppConstants.gridHorizontalPadding / 2,
            right: AppConstants.gridHorizontalPadding / 2,
            bottom: 40, // 距离底部减小，为版权信息留出空间
            height: 450.0, // 增加GridView高度到450px
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                boxShadow: const [AppConstants.defaultShadow],
              ),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: GridView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: AppConstants.crossAxisCount,
                    crossAxisSpacing: AppConstants.crossAxisSpacing,
                    mainAxisSpacing: AppConstants.mainAxisSpacing,
                    childAspectRatio: AppConstants.childAspectRatio,
                  ),
                  itemCount: buttonItems.length,
                  itemBuilder: (context, index) {
                    final item = buttonItems[index];
                    return _buildCustomButton(item);
                  },
                ),
              ),
            ),
          ),
          
          // 层级6：底部版权信息
          const Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "ChiffonMai by ChiFFoN 2026",
                style: TextStyle(
                  color: AppConstants.textPrimaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }


  // 构建用户信息文本
  Widget _buildUserInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: const [
        Text(
          "U+5E78",
          style: TextStyle(
            color: AppConstants.textPrimaryColor,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            height: 0.6,
          ),
        ),
        Text(
          "Rating",
          style: TextStyle(
            color: AppConstants.textSecondaryColor,
            fontSize: 14,
            fontWeight: FontWeight.normal,
          ),
        ),
        Text(
          "15049",
          style: TextStyle(
            color: AppConstants.textSecondaryColor,
            fontSize: 24,
            fontWeight: FontWeight.w600,
            height: 0.8,
          ),
        ),
        Text(
          "10670+4379",
          style: TextStyle(
            color: AppConstants.textSecondaryColor,
            fontSize: 14,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }

  // 构建自定义功能按钮
  Widget _buildCustomButton(ButtonItem item) {
    return SizedBox(
      height: AppConstants.buttonHeight,
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: Colors.transparent, // 按钮整体背景设为透明
          side: const BorderSide(
            color: AppConstants.buttonBorderColor,
            width: AppConstants.borderWidth,
          ),
          padding: EdgeInsets.zero, // 移除默认内边距
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
          ),
          elevation: 0,
        ),
        onPressed: () {
          debugPrint("点击了：${item.title}");
          // 版本对照按钮点击事件
          if (item.title == '版本对照') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => VersionView()),
            );
          }
          if (item.title == '达成率计算') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AchievementRateCalculator()),
            );
          }
          if (item.title == '达成率反推') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AchievementFullReverseCalculator()),
            );
          }
          if (item.title == 'Best50查询') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => B50Page()),
            );
          }
          if (item.title == '单曲Rating计算') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SingleRatingCalculator()),
            );
          }
          if (item.title == '基于标签推荐') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => RecommendByTags()),
            );
          }
          if (item.title == '乐曲查询') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SongSearchPage()),
            );
          }
        },
        child: Column(
          children: [
            // 上半部分：原背景色，居中图标
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppConstants.buttonBackgroundColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppConstants.borderRadiusLarge),
                    topRight: Radius.circular(AppConstants.borderRadiusLarge),
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 36, // 圆形背景的宽度
                    height: 36, // 圆形背景的高度
                    decoration: const BoxDecoration(
                      color: Colors.white, // 白色背景
                      shape: BoxShape.circle, // 圆形形状
                    ),
                    child: Center(
                      child: Icon(
                        item.icon,
                        color: AppConstants.textPrimaryColor,
                        size: 20, // 图标尺寸稍微减小一点
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // 下半部分：白色背景，居中标题和副标题
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(AppConstants.borderRadiusLarge),
                    bottomRight: Radius.circular(AppConstants.borderRadiusLarge),
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          color: AppConstants.textPrimaryColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontStyle: FontStyle.normal,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        style: TextStyle(
                          color: AppConstants.textPrimaryColor.withOpacity(0.8),
                          fontSize: 10,
                          fontWeight: FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                        softWrap: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}