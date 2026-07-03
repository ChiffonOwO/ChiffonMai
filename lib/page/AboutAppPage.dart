import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../utils/CommonWidgetUtil.dart';
import '../utils/AppTheme.dart';

/// 关于本APP页面
class AboutAppPage extends StatefulWidget {
  const AboutAppPage({super.key});

  @override
  State<AboutAppPage> createState() => _AboutAppPageState();
}

class _AboutAppPageState extends State<AboutAppPage> {
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final screenWidth = MediaQuery.of(context).size.width;
    final Color textPrimaryColor = Theme.of(context).colorScheme.onSurface;
    final Color cardBgColor = Theme.of(context).colorScheme.surface.withOpacity(0.9);
    final BoxShadow defaultShadow = AppColors.defaultShadow(brightness);

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          CommonWidgetUtil.buildCommonBgWidget(),
          CommonWidgetUtil.buildCommonChiffonBgWidget(context),

          Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 48, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: textPrimaryColor),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '关于本APP',
                          style: TextStyle(
                            color: textPrimaryColor,
                            fontSize: screenWidth * 0.06,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.transparent),
                      onPressed: null,
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [defaultShadow],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(screenWidth * 0.04),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: MarkdownGenerator().buildWidgets(
                          _getAboutContent(),
                          config: MarkdownConfig(
                            configs: [
                              LinkConfig(
                                onTap: (url) async {
                                  debugPrint('Link tapped: $url');
                                  final uri = Uri.tryParse(url);
                                  if (uri != null && await canLaunchUrl(uri)) {
                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  } else {
                                    Fluttertoast.showToast(msg: '无法打开链接: $url');
                                  }
                                },
                              ),
                              CodeConfig(
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontSize: screenWidth * 0.03,
                                ),
                              ),
                              H1Config(
                                style: TextStyle(
                                  fontSize: screenWidth * 0.055,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimaryColor,
                                ),
                              ),
                              H2Config(
                                style: TextStyle(
                                  fontSize: screenWidth * 0.048,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimaryColor,
                                ),
                              ),
                              H3Config(
                                style: TextStyle(
                                  fontSize: screenWidth * 0.042,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimaryColor,
                                ),
                              ),
                              PConfig(
                                textStyle: TextStyle(
                                  fontSize: screenWidth * 0.035,
                                  color: textPrimaryColor,
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 获取关于内容的Markdown文本
  String _getAboutContent() {
    return '''
# ChiffonMai

> **ChiffonMai** 是一款专为 **舞萌DX 2026(maimai DX 2026)** 玩家打造的一站式移动端工具类应用，聚合了曲库查询、成绩统计、Rating计算、曲目推荐等多种实用功能，助力玩家提升游玩体验。

---

## 📱 适配说明

- 支持 Android / iOS 双平台（iOS端暂未发布）

## 🛠️ 技术栈

- **开发框架**：Flutter
- **编程语言**：Dart

---

## 📥 安装方式

### 安卓端

1. 下载最新版APK文件：[服务器下载](https://wward.lanzouw.com/chiffonmai)
2. 允许安装未知来源应用
3. 安装并打开应用

### iOS端

> 目前正在尽力协调iOS端的发布，敬请期待

---

## 🔗 开源仓库

- [GitHub - ChiffonMai](https://github.com/ChiffonOwO/ChiffonMai)
- [Gitee - ChiffonMai](https://gitee.com/lyjChiFFoN/ChiffonMai)

---

## ✨ 核心功能一览

- **🎶 乐曲查询**：全面检索舞萌DX曲库，展示所有乐曲的完整信息
- **🎶 乐曲详情**：查看谱面代码、播放谱面，支持自定义谱面播放
- **📊 成绩查询**：快速查看个人游玩数据和历史成绩记录
- **🎯 牌子进度**：查看当前牌子进度，支持导出图片分享
- **🏆 Best50查询**：自动计算个人Best50成绩，支持拟合/个性化查询
- **📈 排行榜**：总Rating、水鱼、洛雪等多维排行榜
- **🎮 猜歌游戏**：支持多种模式的猜歌游戏和多人实时对战
- **🔍 标签推荐**：根据谱面难度、音乐风格匹配推荐曲目
- **🧮 实用工具**：Rating计算、达成率计算/反推、版本对照等

> 更多精彩功能等你探索！

---

## 🎉 特别致谢

感谢以下朋友和项目对本APP的支持与帮助：

- 感谢 [Xn1xUfguF1GiNg](https://huajia.163.com/main/profile/RrwM5xQB) 为本APP提供的背景图和戚风小狐狸（真的非常可爱）
- 感谢 **Takanashi Rikkkkkkka** 为本APP的个性化谱面推荐功能提供的宝贵的设计思路
- 感谢 **三由yyyh** 为本APP的页面设计提供的宝贵意见
- 感谢 **MYD** 提供的用于测试开发的个人游玩数据
- 感谢 [乐观的熊猫](https://space.bilibili.com/438391224) 提议开发ChiffonMai，为本项目诞生提供最初契机
- 感谢 [Diving-Fish](https://www.diving-fish.com/maimaidx/prober/) 提供的曲目数据库和玩家游玩记录数据库
- 感谢 [DXRating.net](https://dxrating.net) 提供的谱面标签数据库和别名数据库
- 感谢 [Yuri-YuzuChaN](https://github.com/Yuri-YuzuChaN/maimaiDX) 提供的别名数据库
- 感谢 [落雪咖啡屋](https://maimai.lxns.net) 提供的收藏品数据库、歌曲音源支持、曲目数据库和玩家游玩记录数据库
- 感谢 [Neskol](https://github.com/Neskol/Maichart-Converts/tree/master) 提供的谱面转换支持
- 感谢 [status.awmc.cc](https://status.awmc.cc/status/maimai) 提供的舞萌服务器状态查询支持

---

## ✨ 设计思路借鉴

- [舞萌猜猜呗之潘一把](https://github.com/yukineko2233/v0-maimai-wordle)
- [EasyMai](https://github.com/Lista233/EasyMai)

---

## 📄 隐私说明

- 应用仅在本地存储你的游戏数据，不会上传至第三方服务器
- 账号绑定仅用于同步官方数据，不会收集敏感信息
- 所有计算逻辑均在本地完成，保障数据安全

## 📝 许可证

本项目采用 [MIT License](https://github.com/ChiffonOwO/ChiffonMai/blob/main/LICENSE) 开源许可证。

## 💡 免责声明

- ChiffonMai 是第三方工具，非SEGA官方出品
- 本应用仅用于学习和娱乐，请勿用于商业用途
- 数据来源均为公开信息，如有侵权请联系删除

---

## 📞 反馈与建议

- 邮箱：chiffonowo@foxmail.com
''';
  }
}