import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/CommonWidgetUtil.dart';
import '../utils/AppTheme.dart';

/// 关于本APP页面
///
/// 自上而下的顺序：app 图标 → app 名称 → 版本号 → 简介 → 特别致谢 → 开发者。
/// 其余（核心功能表、安装方式、隐私说明、许可证、免责声明等）已移除。
class AboutAppPage extends StatefulWidget {
  const AboutAppPage({super.key});

  @override
  State<AboutAppPage> createState() => _AboutAppPageState();
}

/// 一条致谢记录
class _Credit {
  /// 名称（有 [url] 时可点击）
  final String name;

  /// 贡献说明
  final String desc;

  /// 可选的跳转链接
  final String? url;

  const _Credit(this.name, this.desc, [this.url]);
}

class _AboutAppPageState extends State<AboutAppPage> {
  // ---------------------------------------------------------------------------
  // 开发者信息
  // ---------------------------------------------------------------------------
  static const String _developerName = 'ChiffonOwO';
  static const String _email = 'chiffonowo@foxmail.com';
  static const String _bilibiliUrl = 'https://space.bilibili.com/442305158';
  static const String _githubUrl = 'https://github.com/ChiffonOwO';

  static const String _intro =
      'ChiffonMai 是一款专为 舞萌DX 2026（maimai DX 2026）玩家打造的一站式移动端工具类应用，'
      '聚合了曲库查询、成绩统计、Rating 计算、曲目推荐等多种实用功能，助力玩家提升游玩体验。';

  /// 特别致谢（排名不分先后）
  ///
  /// 文案规则：统一用「提供 xxx」，不写「提供的 xxx」——「提供」在这里是动词，
  /// 加「的」会把它变成定语，读起来像名词短语，跟后半句的动词不顺。
  static const List<_Credit> _credits = [
    _Credit('Xn1xUfguF1GiNg', '为本 APP 提供背景图和戚风小狐狸（真的非常可爱）',
        'https://huajia.163.com/main/profile/RrwM5xQB'),
    _Credit('Takanashi Rikkkkkkka', '为本 APP 的个性化谱面推荐功能提供宝贵设计思路'),
    _Credit('三由yyyh', '为本 APP 的页面设计提供宝贵意见'),
    _Credit('MYD', '提供用于测试开发的个人游玩数据'),
    _Credit('乐观的熊猫', '提议开发 ChiffonMai，为本项目诞生提供最初契机',
        'https://space.bilibili.com/438391224'),
    _Credit('水鱼查分器', '提供曲目数据库和玩家游玩记录数据库',
        'https://www.diving-fish.com/maimaidx/prober/'),
    _Credit('DXRating.net', '提供谱面标签数据库和别名数据库', 'https://dxrating.net'),
    _Credit('Yuri-YuzuChaN', '提供别名数据库',
        'https://github.com/Yuri-YuzuChaN/maimaiDX'),
    _Credit('落雪咖啡屋', '提供收藏品数据库、歌曲音源支持、曲目数据库和玩家游玩记录数据库',
        'https://maimai.lxns.net'),
    _Credit('Neskol', '提供谱面转换支持',
        'https://github.com/Neskol/Maichart-Converts/tree/master'),
    _Credit('status.awmc.cc', '提供舞萌服务器状态查询支持',
        'https://status.awmc.cc/status/maimai'),
    _Credit('AWMC NET.', '提供水鱼查分器同步支持、落雪查分器同步支持和对本项目开发的经济支持',
        'https://net.wmc.pub/'),
    _Credit('Bakapiano', '提供水鱼查分器和落雪查分器成绩同步支持',
        'https://github.com/bakapiano/maimai-score-hub'),
    _Credit('k4641321', '提供落雪查分器成绩同步支持',
        'https://github.com/k4641321/chusearchsong_flutter/tree/main'),
    _Credit('Union', '提供曲目数据库', 'https://union.godserver.cn/'),
  ];

  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _version = info.buildNumber.isEmpty
            ? 'v${info.version}'
            : 'v${info.version}+${info.buildNumber}';
      });
    } catch (e) {
      debugPrint('[AboutAppPage] 读取版本号失败: $e');
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (e) {
      debugPrint('[AboutAppPage] 打开链接失败: $e');
    }
    Fluttertoast.showToast(msg: '无法打开链接：$url');
  }

  /// 邮箱优先走邮件客户端；没有可用客户端时退回「复制到剪贴板」，
  /// 保证用户在任何设备上都能拿到地址。
  Future<void> _openEmail() async {
    final uri = Uri(scheme: 'mailto', path: _email);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (e) {
      debugPrint('[AboutAppPage] 打开邮件客户端失败: $e');
    }
    await Clipboard.setData(const ClipboardData(text: _email));
    Fluttertoast.showToast(msg: '邮箱已复制到剪贴板');
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final screenWidth = MediaQuery.of(context).size.width;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final Color textPrimaryColor = Theme.of(context).colorScheme.onSurface;
    final Color cardBgColor =
        Theme.of(context).colorScheme.surface.withValues(alpha: 0.9);
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
                      onPressed: () => Navigator.of(context).pop(),
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
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.transparent),
                      onPressed: null,
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Container(
                  margin: EdgeInsets.fromLTRB(4, 0, 4, 10 + safeBottom),
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
                        children: [
                          // 自上而下：app 图标 → app 名称 → 版本号 → 简介
                          //           → 特别致谢 → 开发者
                          _buildAppIconAndName(screenWidth, textPrimaryColor),
                          SizedBox(height: screenWidth * 0.02),
                          _buildVersionLine(textPrimaryColor),
                          SizedBox(height: screenWidth * 0.06),

                          _buildIntroSection(screenWidth, textPrimaryColor),
                          SizedBox(height: screenWidth * 0.06),

                          _buildCreditsSection(screenWidth, textPrimaryColor),
                          SizedBox(height: screenWidth * 0.06),

                          _buildDeveloperSection(screenWidth, textPrimaryColor),
                        ],
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

  // ---------------------------------------------------------------------------
  // 各区块
  // ---------------------------------------------------------------------------

  Widget _buildSectionTitle(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// 致谢名单
  Widget _buildCreditsSection(double screenWidth, Color color) {
    final subtitleColor = color.withValues(alpha: 0.55);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('🎉 特别致谢', color),
        Text(
          '排名不分先后',
          style: TextStyle(fontSize: 12, color: subtitleColor),
        ),
        const SizedBox(height: 12),
        ...List.generate(_credits.length, (i) {
          final credit = _credits[i];
          final tappable = credit.url != null;
          return Padding(
            padding: EdgeInsets.only(bottom: i == _credits.length - 1 ? 0 : 14),
            child: InkWell(
              onTap: tappable ? () => _openUrl(credit.url!) : null,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            credit.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: tappable
                                  ? Theme.of(context).colorScheme.primary
                                  : color,
                              decoration: tappable
                                  ? TextDecoration.underline
                                  : TextDecoration.none,
                              decorationColor:
                                  Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        if (tappable) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.open_in_new,
                            size: 12,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      credit.desc,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  /// App 图标 + 名称（居中，页面最顶部）
  Widget _buildAppIconAndName(double screenWidth, Color color) {
    final iconSize = screenWidth * 0.22;
    return Center(
      child: Column(
        children: [
          _AndroidLauncherIcon(size: iconSize),
          const SizedBox(height: 12),
          Text(
            'ChiffonMai',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// 版本号（紧随 app 名称）
  Widget _buildVersionLine(Color color) {
    return Center(
      child: Text(
        _version.isEmpty ? '版本读取中…' : '当前版本 $_version',
        style: TextStyle(fontSize: 13, color: color.withValues(alpha: 0.6)),
      ),
    );
  }

  /// 简介
  Widget _buildIntroSection(double screenWidth, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('简介', color),
        Text(
          _intro,
          style: TextStyle(fontSize: 13, height: 1.6, color: color),
        ),
      ],
    );
  }

  /// 开发者 + B站 / GitHub / 邮箱
  Widget _buildDeveloperSection(double screenWidth, Color color) {
    final subtitleColor = color.withValues(alpha: 0.6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('开发者', color),
        Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
              child: Icon(
                Icons.person,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _developerName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildContactTile(
          icon: Icons.play_circle_fill,
          label: 'B 站',
          value: '@ChiffonOwO',
          onTap: () => _openUrl(_bilibiliUrl),
          color: color,
          subtitleColor: subtitleColor,
        ),
        _buildContactTile(
          icon: Icons.code,
          label: 'GitHub',
          value: 'ChiffonOwO',
          onTap: () => _openUrl(_githubUrl),
          color: color,
          subtitleColor: subtitleColor,
        ),
        _buildContactTile(
          icon: Icons.email_outlined,
          label: '邮箱',
          value: _email,
          onTap: _openEmail,
          color: color,
          subtitleColor: subtitleColor,
        ),
      ],
    );
  }

  Widget _buildContactTile({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
    required Color color,
    required Color subtitleColor,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Icon(icon, size: 20, color: primary),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(fontSize: 14, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: subtitleColor,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, size: 18, color: subtitleColor),
            ],
          ),
        ),
      ),
    );
  }
}

/// 按 Android 自适应图标的裁剪尺寸显示 App 图标。
///
/// Android 自适应图标的画布是 108×108 dp，但启动器遮罩只显示中间
/// 72×72 dp（外圈每边 18dp 会被裁掉）。
///
/// 本项目的 `assets/icon.png` 是一张通版插画，`flutter_launcher_icons`
/// 把它铺满了整个 108dp 画布（见 `android/.../drawable-*/ic_launcher_foreground.png`，
/// 内容确实是贴边的），所以桌面上实际看到的只有**中间 2/3**。
/// 直接把原图整张贴出来会比桌面图标"多出一圈"，看起来对不上；
/// 这里按 108/72 = 1.5 倍放大后居中裁切，还原启动器的观感。
class _AndroidLauncherIcon extends StatelessWidget {
  final double size;

  const _AndroidLauncherIcon({required this.size});

  /// 自适应图标可见区与画布之比：72 / 108
  static const double _safeZoneRatio = 72 / 108;

  @override
  Widget build(BuildContext context) {
    final scaledSize = size / _safeZoneRatio;
    // 原图是 2048²，不限制解码尺寸的话一张图就要占 16MB 内存
    final cacheWidth =
        (scaledSize * MediaQuery.of(context).devicePixelRatio).round();

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        // 与多数启动器的圆角遮罩接近
        borderRadius: BorderRadius.circular(size * 0.24),
        child: Transform.scale(
          scale: 1 / _safeZoneRatio,
          child: Image.asset(
            'assets/icon.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
            cacheWidth: cacheWidth,
            gaplessPlayback: true,
            errorBuilder: (context, error, stack) => ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.image_not_supported_outlined,
                size: size * 0.4,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
