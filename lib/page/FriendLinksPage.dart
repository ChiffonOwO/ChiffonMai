import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:marquee/marquee.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../utils/AppTheme.dart';
import '../widgets/BackgroundPageScaffold.dart';

/// 友情链接页面：以卡片形式展示推广同行的项目，点击通过外部浏览器打开。
class FriendLinksPage extends StatefulWidget {
  const FriendLinksPage({super.key});

  @override
  State<FriendLinksPage> createState() => _FriendLinksPageState();
}

class _FriendLinksPageState extends State<FriendLinksPage> {
  /// 友链数据。
  ///
  /// 字段说明：
  /// - [name]      友链项目名称
  /// - [desc]      一句话简介
  /// - [url]       跳转链接（点击卡片打开外部浏览器）
  /// - [iconType]  图标类型（从预定义范围内选择，避免依赖外部图片）
  /// - [iconBg]    图标主题色（背景底色 + 图标前景色）
  static const List<_FriendLink> _friendLinks = [
    _FriendLink(
      name: '中二查歌',
      desc: '这是ChiffonChu，一站式中二工具()',
      url: 'https://github.com/k4641321/chusearchsong_flutter',
      iconType: FriendLinkIconType.github,
      iconBg: Color(0xFF7E57C2),
    ),
    _FriendLink(
      name: '你画我猜',
      desc: '来自AWMC社区出品的网页小游戏，持续迭代中！',
      url: 'https://v.wmc.pub/draw-guess',
      iconType: FriendLinkIconType.game,
      iconBg: Color(0xFF26A69A),
    ),
    _FriendLink(
      name: '溯光的个人主页',
      desc: '此人正开发原创音游中...',
      url: 'https://su-guang.rth1.xyz/',
      iconType: FriendLinkIconType.music,
      iconBg: Color(0xFF5C6BC0),
    ),
    _FriendLink(
      name: 'MaiScan Rev',
      desc: '一个通过封面快速查询的离线本地maimai曲库',
      url: 'https://github.com/PojavAnge/MaiScan-Rev',
      iconType: FriendLinkIconType.github,
      iconBg: Color(0xFFEF6C00),
    ),
  ];

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      Fluttertoast.showToast(msg: '链接无效');
      return;
    }
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _copyFallback(url);
      }
    } catch (e) {
      debugPrint('打开友链失败: $e');
      _copyFallback(url);
    }
  }

  void _copyFallback(String url) {
    Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('无法打开浏览器，链接已复制到剪贴板'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final Color textSecondaryColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);
    return BackgroundPageScaffold(
      title: '友情链接',
      resizeToAvoidBottomInset: false,
      contentPadding: EdgeInsets.only(bottom: safeBottom + 10),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          screenWidth * 0.04,
          16,
          screenWidth * 0.04,
          20,
        ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 顶部说明
                          Text(
                            '这里收录了同好/同行项目的友情链接，'
                            '点击卡片即可在浏览器中打开。',
                            style: TextStyle(
                              color: textSecondaryColor,
                              fontSize: screenWidth * 0.032,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // 友链列表（1列N行）
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            itemCount: _friendLinks.length,
                            separatorBuilder: (_, __) =>
                                SizedBox(height: screenWidth * 0.025),
                            itemBuilder: (ctx, i) => _FriendLinkCard(
                              link: _friendLinks[i],
                              onOpen: _open,
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}

/// 友链卡片：图标区 + 名称 + 简介 + 跳转按钮
class _FriendLinkCard extends StatelessWidget {
  final _FriendLink link;
  final Future<void> Function(String url) onOpen;

  const _FriendLinkCard({required this.link, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final screenWidth = MediaQuery.of(context).size.width;
    final Color textPrimaryColor = Theme.of(context).colorScheme.onSurface;
    final Color textSecondaryColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);

    return Container(
      decoration: BoxDecoration(
        // 用透明外框划分链接条目，点击效果仍由内部 Material 承载。
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onOpen(link.url),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.03,
              vertical: screenWidth * 0.015,
            ),
            child: Row(
              children: [
                // 左侧：图标
                Container(
                  width: screenWidth * 0.13,
                  height: screenWidth * 0.13,
                  decoration: BoxDecoration(
                    color: link.iconBg.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    _iconForType(link.iconType),
                    color: link.iconBg,
                    size: screenWidth * 0.07,
                  ),
                ),
                SizedBox(width: screenWidth * 0.035),
                // 中间：项目名称 + 简介
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        link.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textPrimaryColor,
                          fontSize: screenWidth * 0.04,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: screenWidth * 0.008),
                      // 参考 SongInfoPage：先用 LayoutBuilder + TextPainter 测量文本宽度
                      // 当文本能完整显示时不滚动（直接省略号），溢出时才用 Marquee
                      // 同时移除 startPadding，避免每轮滚动开头出现空白
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final descStyle = TextStyle(
                            color: textSecondaryColor,
                            fontSize: screenWidth * 0.03,
                          );
                          final textPainter = TextPainter(
                            text: TextSpan(
                              text: link.desc,
                              style: descStyle,
                            ),
                            maxLines: 1,
                            textDirection: TextDirection.ltr,
                          )..layout(
                              minWidth: 0,
                              maxWidth: double.infinity,
                            );
                          final textWidth = textPainter.width;
                          final safeWidth = constraints.maxWidth;
                          if (textWidth <= safeWidth) {
                            return Text(
                              link.desc,
                              style: descStyle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          }
                          return SizedBox(
                            height: screenWidth * 0.04,
                            child: Marquee(
                              text: link.desc,
                              style: descStyle,
                              velocity: 30.0,
                              blankSpace: 30.0,
                              pauseAfterRound: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(width: screenWidth * 0.02),
                // 右侧：前往图标
                Icon(
                  Icons.open_in_new,
                  size: screenWidth * 0.045,
                  color: AppColors.greyHint(brightness),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 友链可用的图标类型枚举
///
/// 限定友链图标的可选范围，避免依赖外部图片资源。
/// 新增友链时从此枚举中选择一个最贴合的类型。
enum FriendLinkIconType {
  /// GitHub 开源项目（仓库 / 工具 / CLI）
  github,
  /// 网页应用 / Web 服务
  web,
  /// App / 移动端应用
  app,
  /// 游戏 / 互动娱乐
  game,
  /// 音乐相关
  music,
  /// 工具 / 计算 / 实用程序
  tool,
  /// 文档 / Wiki / 百科
  docs,
  /// 视频 / 直播 / 流媒体
  video,
  /// 社区 / 论坛 / 群组
  community,
}

/// 图标类型 → Material IconData 映射
IconData _iconForType(FriendLinkIconType type) {
  switch (type) {
    case FriendLinkIconType.github:
      return FontAwesomeIcons.github;
    case FriendLinkIconType.web:
      return Icons.language;
    case FriendLinkIconType.app:
      return Icons.phone_android;
    case FriendLinkIconType.game:
      return Icons.sports_esports;
    case FriendLinkIconType.music:
      return Icons.music_note;
    case FriendLinkIconType.tool:
      return Icons.build;
    case FriendLinkIconType.docs:
      return Icons.menu_book;
    case FriendLinkIconType.video:
      return Icons.play_circle_outline;
    case FriendLinkIconType.community:
      return Icons.forum;
  }
}

class _FriendLink {
  final String name;
  final String desc;
  final String url;
  final FriendLinkIconType iconType;
  final Color iconBg;

  const _FriendLink({
    required this.name,
    required this.desc,
    required this.url,
    required this.iconType,
    required this.iconBg,
  });
}
