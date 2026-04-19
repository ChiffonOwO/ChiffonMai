import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/page/Best50Page.dart';
import 'package:my_first_flutter_app/page/CollectionSearchPage.dart';
import 'package:my_first_flutter_app/page/DiffBest50Page.dart';
import 'package:my_first_flutter_app/page/GuessChartByAliaPage.dart';
import 'package:my_first_flutter_app/page/GuessChartByBlurredCoverPage.dart';
import 'package:my_first_flutter_app/page/GuessChartByCoverPage.dart';
import 'package:my_first_flutter_app/page/GuessChartByInfoPage.dart';
import 'package:my_first_flutter_app/page/GuessChartBySongExcerptPage.dart';
import 'package:my_first_flutter_app/page/GuessSongByOpenLettersPage.dart';
import 'package:my_first_flutter_app/page/MaimaiServerStatusPage.dart';
import 'package:my_first_flutter_app/page/PersonalizedBest50Page.dart';
import 'package:my_first_flutter_app/page/RandomChartPage.dart';
import 'package:my_first_flutter_app/page/RecommendByTagsPage.dart';
import 'package:my_first_flutter_app/page/SingleRatingCalculatorPage.dart';
import 'package:my_first_flutter_app/page/SongSearchPage.dart';
import 'package:my_first_flutter_app/manager/UserBest50Manager.dart';
import 'package:my_first_flutter_app/manager/MaimaiMusicDataManager.dart';
import 'package:my_first_flutter_app/manager/UserPlayDataManager.dart';
import 'package:my_first_flutter_app/manager/DiffMusicDataManager.dart';
import 'package:my_first_flutter_app/manager/LZYCheckUpdateManager.dart';
import 'package:my_first_flutter_app/page/UserScoreSearchPage.dart';
import 'package:my_first_flutter_app/service/RecommendByTagsService.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'AchievementFullReverseCalculatorPage.dart';
import 'VersionViewPage.dart';
import 'AchievementRateCalculatorPage.dart';

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

/// 首页组件：有状态组件，包含所有页面元素和业务数据
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

/// 首页状态类：处理页面状态、存储数据、实现布局构建
class _HomePageState extends State<HomePage> {
  // 加载状态
  bool _isLoading = false;
  
  // 用户数据
  String _userNickname = "U+5E78";
  int _best50TotalRA = 15049;
  int _best35TotalRA = 10670;
  int _best15TotalRA = 4379;
  
  // 初始化方法，用于从本地存储加载数据
  @override
  void initState() {
    super.initState();
    _loadUserData();
    _autoCheckUpdate();
  }
  
  // 自动检查更新
  Future<void> _autoCheckUpdate() async {
    print("首页加载时自动检查更新");
    final updateManager = LZYCheckUpdateManager();
    try {
      // 检查是否应该显示更新提示
      if (await updateManager.shouldShowUpdateDialog()) {
        var updateInfo = await updateManager.checkUpdate();
        if (updateInfo['hasUpdate'] && mounted) {
          updateManager.showUpdateDialog(context);
        }
      }
    } catch (e) {
      print("自动检查更新失败：$e");
    }
  }
  
  // 从本地存储加载用户数据
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userNickname = prefs.getString('userNickname') ?? "U+5E78";
      _best50TotalRA = prefs.getInt('best50TotalRA') ?? 15049;
      _best35TotalRA = prefs.getInt('best35TotalRA') ?? 10670;
      _best15TotalRA = prefs.getInt('best15TotalRA') ?? 4379;
    });
  }
  
  // 保存用户数据到本地存储
  Future<void> _saveUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userNickname', _userNickname);
    await prefs.setInt('best50TotalRA', _best50TotalRA);
    await prefs.setInt('best35TotalRA', _best35TotalRA);
    await prefs.setInt('best15TotalRA', _best15TotalRA);
  }
  
  // 按钮数据源：使用类型安全的ButtonItem模型
  final List<ButtonItem> buttonItems = const [
    ButtonItem(icon: Icons.music_note, title: '乐曲查询', subtitle: '查询舞萌曲库的乐曲'),
    ButtonItem(icon: Icons.score, title: '成绩查询', subtitle: '查看游玩数据'),
    ButtonItem(icon: Icons.collections_bookmark, title: '收藏品查询', subtitle: '查看收藏品查询'),
    ButtonItem(icon: Icons.leaderboard, title: 'Best50查询', subtitle: '我去,龙币!'),
    ButtonItem(icon: Icons.analytics, title: '拟合Best50查询', subtitle: '我w55怎么拟合才w52?!'),
    ButtonItem(icon: Icons.person_search_outlined, title: '个性化Best50查询', subtitle: '我超，名刀50!'),
    ButtonItem(icon: Icons.label, title: '基于标签推荐', subtitle: '基于你游玩的谱面标签推荐曲目'),
    ButtonItem(icon: Icons.shuffle, title: '随机乐曲', subtitle: '随机选曲1-4首'),
    ButtonItem(icon: Icons.calculate, title: '单曲Rating计算', subtitle: '我鸟加这个有分吃吗？'),
    ButtonItem(icon: Icons.percent, title: '达成率计算', subtitle: '根据判定详情算出达成率'),
    ButtonItem(icon: Icons.compare_arrows, title: '版本对照', subtitle: '舞神要打哪些代的歌？'),
    ButtonItem(icon: Icons.replay, title: '达成率反推', subtitle: '根据判定详情推出绝赞详情'),
    ButtonItem(icon: Icons.gamepad, title: '无提示猜歌', subtitle: '舞萌笑传之猜猜呗1'),
    ButtonItem(icon: Icons.gamepad, title: '根据部分曲绘猜歌', subtitle: '舞萌笑传之猜猜呗2'),
    ButtonItem(icon: Icons.gamepad, title: '根据模糊曲绘猜歌', subtitle: '舞萌笑传之猜猜呗3'),
    ButtonItem(icon: Icons.gamepad, title: '根据歌曲片段猜歌', subtitle: '舞萌笑传之猜猜呗4'),
    ButtonItem(icon: Icons.gamepad, title: '根据别名猜歌', subtitle: '舞萌笑传之猜猜呗5'),
    ButtonItem(icon: Icons.gamepad, title: '舞萌开字母', subtitle: '舞萌笑传之猜猜呗6'),
    ButtonItem(icon: Icons.file_upload_sharp, title: '刷新数据', subtitle: '刷新你的舞萌数据'),
    ButtonItem(icon: Icons.network_check, title: '服务器状态', subtitle: '查看舞萌服务器状态'),
    ButtonItem(icon: Icons.update, title: '检查更新', subtitle: '检查应用是否有新版本'),
  ];

  @override
  Widget build(BuildContext context) {
    // 获取屏幕尺寸
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // 页面根布局：Scaffold + Stack 实现多层级叠加布局
    // Stack子组件按书写顺序从上到下叠加，越靠后层级越高
    return Scaffold(
      backgroundColor: Colors.transparent, // 透明背景，显示底层图片
      resizeToAvoidBottomInset: false, // 防止输入法弹出时重新布局导致卡顿
      body: Stack(
        children: [
          // 层级1：基础背景图 - 使用通用背景Widget
          CommonWidgetUtil.buildCommonBgWidget(),

          // 层级2：第一张虚化装饰图 - 使用通用装饰背景Widget
          CommonWidgetUtil.buildCommonChiffonBgWidget(context),

          // 层级3：第二张虚化装饰图 - 居中显示，与层级2重叠，增强视觉效果
          Center(
            child: Transform.translate(
              offset: Offset(0, -screenHeight * 0.03),
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
            Positioned(
              top: screenHeight * 0.08,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Text(
                    "ChiffonMai",
                    style: TextStyle(
                      color: AppConstants.textPrimaryColor,
                      fontSize: screenWidth * 0.06, // 根据屏幕宽度调整字号
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.01), // 添加间距
                  Text(
                    "基本信息",
                    style: TextStyle(
                      color: AppConstants.textPrimaryColor,
                      fontSize: screenWidth * 0.045,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          // 层级4：个人信息静态文本
            Positioned(
              left: screenWidth * 0.5,
              top: screenHeight * 0.21,
              child: _buildUserInfo(context),
            ),

          
          // 功能中心标题
          Positioned(
            left: screenWidth * 0.04,
            right: screenWidth * 0.04,
            bottom: screenHeight * 0.62, // 在GridView上方定位
            child: Center(
              child: Text(
                "功能中心",
                style: TextStyle(
                  color: AppConstants.textPrimaryColor,
                  fontSize: screenWidth * 0.045,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // 层级5：核心功能区 - 直接使用Positioned定位GridView
          Positioned(
            left: screenWidth * 0.02,
            right: screenWidth * 0.02,
            bottom: screenHeight * 0.06, // 距离底部减小，为版权信息留出空间
            height: screenHeight * 0.55, // 根据屏幕高度调整
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                boxShadow: const [AppConstants.defaultShadow],
              ),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.03, vertical: screenHeight * 0.015),
                child: GridView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: AppConstants.crossAxisCount,
                    crossAxisSpacing: screenWidth * 0.02,
                    mainAxisSpacing: screenHeight * 0.01,
                    childAspectRatio: screenWidth > 600 ? 1.3 : 1.2,
                  ),
                  itemCount: buttonItems.length,
                  itemBuilder: (context, index) {
                    final item = buttonItems[index];
                    return _buildCustomButton(item, context);
                  },
                ),
              ),
            ),
          ),
          
          // 层级6：底部版权信息
          Positioned(
            bottom: screenHeight * 0.015,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "ChiffonMai by ChiFFoN 2026",
                style: TextStyle(
                  color: AppConstants.textPrimaryColor,
                  fontSize: screenWidth * 0.03,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
          ),
          
          // 加载中提示
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 10),
                      Text('正在刷新数据,这需要一些时间,请稍后...'),
                    ],
                  ),
                ),
              ),
            )
        ],
      ),
    );
  }


  // 构建用户信息文本
  Widget _buildUserInfo(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // 检查是否有缓存数据（通过检查用户昵称为默认值判断）
    bool hasNoCachedData = _userNickname == "U+5E78";
    
    if (hasNoCachedData) {
      // 没有缓存数据时显示提示信息
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "请点击",
            style: TextStyle(
              color: AppConstants.textPrimaryColor,
              fontSize: screenWidth * 0.05,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              height: 1.2,
            ),
          ),
          Text(
            "刷新数据",
            style: TextStyle(
              color: AppConstants.textPrimaryColor,
              fontSize: screenWidth * 0.05,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              height: 1.2,
            ),
          ),
          Text(
            "刷新成绩",
            style: TextStyle(
              color: AppConstants.textPrimaryColor,
              fontSize: screenWidth * 0.05,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              height: 1.2,
            ),
          ),
        ],
      );
    } else {
      // 有缓存数据时显示正常信息
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: screenWidth * 0.4, // 设置一个最大宽度，例如屏幕宽度的40%
            child: Text(
              _userNickname,
              style: TextStyle(
                color: AppConstants.textPrimaryColor,
                fontSize: screenWidth * 0.07,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                height: 0.6,
              ),
              overflow: TextOverflow.ellipsis, // 超出显示省略号
              maxLines: 1, // 只显示一行
            ),
          ),
          SizedBox(height: screenHeight * 0.005), // 在玩家名和Rating中间添加SizedBox
          Text(
            "Rating",
            style: TextStyle(
              color: AppConstants.textSecondaryColor,
              fontSize: screenWidth * 0.045,
              fontWeight: FontWeight.normal,
            ),
          ),
          Text(
            "$_best50TotalRA",
            style: TextStyle(
              color: AppConstants.textSecondaryColor,
              fontSize: screenWidth * 0.07,
              fontWeight: FontWeight.w600,
              height: 0.8,
            ),
          ),
          Text(
            "$_best35TotalRA+$_best15TotalRA",
            style: TextStyle(
              color: AppConstants.textSecondaryColor,
              fontSize: screenWidth * 0.04,
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      );
    }
  }

  // 显示刷新数据对话框
  void _showRefreshDataDialog(BuildContext context) {
    final TextEditingController qqController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('刷新数据'),
          content: SingleChildScrollView(
            child: TextField(
              controller: qqController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '请输入QQ号',
                hintText: '例如:1919810',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                if (qqController.text.isNotEmpty) {
                  await _refreshBest50Data(qqController.text);
                }
              },
              child: Text('确认'),
            ),
          ],
        );
      },
    );
  }
  
  // 刷新Best50数据
  Future<void> _refreshBest50Data(String qq) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // 清除推荐结果缓存
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(RecommendByTagsService.RECOMMENDATION_CACHE_KEY);
        print('推荐结果缓存已清除');
      } catch (e) {
        print('清除推荐结果缓存失败: $e');
      }
      
      // 从API获取并更新音乐数据
      await MaimaiMusicDataManager().fetchAndUpdateMusicData();
      
      // 从API获取并更新难度数据
      await DiffMusicDataManager().fetchAndUpdateDiffData();
      
      // 刷新标签数据
      await RecommendByTagsService.initializeTags();
      
      // 从API获取并更新用户游玩数据
      final userPlayDataManager = UserPlayDataManager();
      final userPlayData = await userPlayDataManager.fetchUserPlayData(qq);
      
      final best50Manager = UserBest50Manager();
      final best50Data = await best50Manager.getUserBest50(qq);
      print(best50Data);
      
      // 更新用户昵称
      if (userPlayData != null && userPlayData.containsKey('nickname')) {
        setState(() {
          _userNickname = userPlayData['nickname'];
        });
      }
      
      // 计算Best50、Best35、Best15总RA
      int totalRA = 0;
      int best35RA = 0;
      int best15RA = 0;
      
      // 计算Best35总RA (sd charts)
      for (var record in best50Data.charts.sd) {
        best35RA += record.ra;
      }
      
      // 计算Best15总RA (dx charts)
      for (var record in best50Data.charts.dx) {
        best15RA += record.ra;
      }
      
      // 计算Best50总RA (sd + dx)
      totalRA = best35RA + best15RA;
      
      // 更新状态
      setState(() {
        _best50TotalRA = totalRA;
        _best35TotalRA = best35RA;
        _best15TotalRA = best15RA;
      });
      
      // 保存数据到本地存储
      await _saveUserData();
      
      // 转换数据格式为B50Page需要的格式
      final b50DataMap = {
        'additional_rating': best50Data.additionalRating,
        'charts': {
          'dx': best50Data.charts.dx.map((item) => item.toJson()).toList(),
          'sd': best50Data.charts.sd.map((item) => item.toJson()).toList(),
        },
        'rating': best50Data.charts.dx.fold(0, (sum, item) => sum + item.ra) + 
                  best50Data.charts.sd.fold(0, (sum, item) => sum + item.ra),
      };
      
      // 显示成功提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('数据刷新成功!为您跳转到Best50页面'),
          duration: Duration(seconds: 2),
        ),
      );
      
      // 导航到B50Page并传递新数据
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => B50Page(b50Data: b50DataMap)),
      );
    } catch (e) {
      // 显示错误提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('刷新数据失败：$e'),
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // 构建自定义功能按钮
  Widget _buildCustomButton(ButtonItem item, BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return SizedBox(
      height: screenHeight * 0.12,
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
          if (item.title == '刷新数据') {
            _showRefreshDataDialog(context);
          }
          if (item.title == '成绩查询') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => UserScoreSearchPage()),
            );
          }
          if (item.title == '拟合Best50查询'){
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => DiffBest50Page()),
            );
          }
          if (item.title == '随机乐曲'){
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => RandomChartPage()),
            );
          }
          if (item.title == '无提示猜歌'){
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => GuessChartByInfoPage()),
            );
          }
          if (item.title == '根据部分曲绘猜歌'){
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => GuessChartByCoverPage()),
            );
          }
          if (item.title == '收藏品查询'){
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => CollectionSearchPage()),
            );
          }
          if (item.title == '根据模糊曲绘猜歌'){
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => GuessChartByBlurredCoverPage()),
            );
          }
          if (item.title == '根据歌曲片段猜歌'){
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => GuessChartBySongExcerptPage()),
            );
          }
          if (item.title == '根据别名猜歌'){
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => GuessChartByAliaPage()),
            );
          }
          if (item.title == '舞萌开字母'){
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => GuessSongByOpenLettersPage()),
            );
          }
          if (item.title == '服务器状态'){
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => MaimaiServerStatusPage()),
            );
          }
          if (item.title == '个性化Best50查询'){
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PersonalizedBest50Page()),
            );
          }
          if (item.title == '检查更新'){
            // 显示加载对话框
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text('检查更新'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('正在检查更新...'),
                    ],
                  ),
                );
              },
            );
            
            // 检查更新
            final updateManager = LZYCheckUpdateManager();
            updateManager.checkUpdate().then((updateInfo) {
              Navigator.of(context).pop(); // 关闭加载对话框
              if (updateInfo['hasUpdate']) {
                // 显示更新提示
                if (context.mounted) {
                  updateManager.showUpdateDialog(context);
                }
              } else {
                // 显示没有更新的提示
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text('检查更新'),
                        content: Text('当前已是最新版本'),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: Text('确定'),
                          ),
                        ],
                      );
                    },
                  );
                }
              }
            }).catchError((error) {
              Navigator.of(context).pop(); // 关闭加载对话框
              // 显示错误提示
              if (context.mounted) {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text('检查更新失败'),
                      content: Text('请检查网络连接后重试'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text('确定'),
                        ),
                      ],
                    );
                  },
                );
              }
            });
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
                    width: screenWidth * 0.09, // 圆形背景的宽度
                    height: screenWidth * 0.09, // 圆形背景的高度
                    decoration: const BoxDecoration(
                      color: Colors.white, // 白色背景
                      shape: BoxShape.circle, // 圆形形状
                    ),
                    child: Center(
                      child: Icon(
                        item.icon,
                        color: AppConstants.textPrimaryColor,
                        size: screenWidth * 0.05, // 图标尺寸
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
                        style: TextStyle(
                          color: AppConstants.textPrimaryColor,
                          fontSize: screenWidth * 0.035,
                          fontWeight: FontWeight.bold,
                          fontStyle: FontStyle.normal,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: screenHeight * 0.005),
                      Text(
                        item.subtitle,
                        style: TextStyle(
                          color: AppConstants.textPrimaryColor.withOpacity(0.8),
                          fontSize: screenWidth * 0.025,
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