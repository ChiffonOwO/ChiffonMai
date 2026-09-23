import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';
import 'HubComponents.dart';
import '../service/CoverRecognitionService.dart';
import '../utils/FavoriteFeaturesNotifier.dart';
import 'DailyRecommendPage.dart';
import 'RandomChartPage.dart';
import 'RecommendByTagsPage.dart';
import 'RatingRecommendPage.dart';
import 'DsRangeRecommendPage.dart';
import 'SingleRatingCalculatorPage.dart';
import 'AchievementRateCalculatorPage.dart';
import 'AchievementFullReverseCalculatorPage.dart';
import 'VersionViewPage.dart';
import 'RankTable/RankTablePage.dart';
import 'FavoriteFolderPage.dart';
import 'CoverRecognitionPage.dart';
import 'ScoreOcrPage.dart';
import 'DifficultyDistributionPage.dart';
import 'FriendComparePage.dart';
import 'GlobalArcadeMapPage.dart';
import 'KaleidXScope/KaleidXScopeSelectPage.dart';
import 'PersonalizedChartPlayConfigure.dart';
import 'Portable/PortablePlayerPage.dart';

class ToolsHubPage extends StatefulWidget {
  const ToolsHubPage({super.key});

  @override
  State<ToolsHubPage> createState() => _ToolsHubPageState();
}

class _ToolsHubPageState extends State<ToolsHubPage> {
  void _open(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  /// 打开随身听。
  ///
  /// 单独写一个方法而不是塞进 `_open`：随身听页面要感知「自己是不是在最上层」，
  /// 好让 [PortablePlayerBall] 让位（`AppShell` 里靠 push 的 Future 判断）。
  /// 从首页进来时由 `AppShell._openPortablePlayer` 走同一条路，
  /// 这里从 Hub 页进来时用 `await` 只是为了让导航栈语义一致。
  Future<void> _openPortablePlayer(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PortablePlayerPage()),
    );
  }

  // ===== 曲绘索引构建状态 =====
  bool _coverIndexReady = false;
  bool _coverIndexBuilding = false;
  int _coverProgressCurrent = 0;
  int _coverProgressTotal = 0;

  @override
  void initState() {
    super.initState();
    _checkCoverIndexStatus();
  }

  Future<void> _checkCoverIndexStatus() async {
    final valid = await CoverRecognitionService.instance.isHashCacheValid();
    if (mounted) setState(() => _coverIndexReady = valid);
  }

  /// 点曲绘识别：索引已就绪 → 直接打开；未就绪 → 在按钮上构建索引，
  /// 构建完后再导航（按钮在构建期间显示进度且不可重复点）。
  Future<void> _openCoverRecognition() async {
    if (_coverIndexBuilding) return;
    if (!_coverIndexReady) {
      setState(() {
        _coverIndexBuilding = true;
        _coverProgressCurrent = 0;
        _coverProgressTotal = 0;
      });
      try {
        await CoverRecognitionService.instance.precomputeHashes(
          onProgress: (current, total) {
            if (mounted) {
              setState(() {
                _coverProgressCurrent = current;
                _coverProgressTotal = total;
              });
            }
          },
        );
        if (!mounted) return;
        setState(() {
          _coverIndexReady = true;
          _coverIndexBuilding = false;
          _coverProgressCurrent = 0;
          _coverProgressTotal = 0;
        });
      } catch (e) {
        if (mounted) {
          setState(() {
            _coverIndexBuilding = false;
          });
          Fluttertoast.showToast(msg: '曲绘索引构建失败: $e');
        }
        return;
      }
    }
    if (!mounted) return;
    _open(context, const CoverRecognitionPage());
  }

  bool _isFavorited(String title) =>
      FavoriteFeaturesNotifier.titles.contains(title);

  Future<void> _toggleFavorite(String title) =>
      FavoriteFeaturesNotifier.toggle(title);

  Future<void> _launchExternal(
      BuildContext context, String url, String fallbackHint) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法打开链接：$fallbackHint')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('打开失败：$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<FavoritesPayload>(
      valueListenable: FavoriteFeaturesNotifier.instance,
      builder: (context, payload, _) => HubPageScaffold(
        title: '实用工具',
        subtitle: '选曲 · 计算 · 识别 · 自定义玩法',
        icon: Icons.handyman_rounded,
        children: [
          HubSection(
            title: '选曲推荐',
            icon: Icons.explore_outlined,
            subtitle: '每日 · 随机 · 标签 · Rating · 定数',
            badgeCount: 5,
            children: [
              HubActionTile(
                title: '每日推荐',
                subtitle: '今天打什么？交给推荐',
                icon: Icons.today_rounded,
                isFavorited: _isFavorited('每日推荐'),
                onToggleFavorite: () => _toggleFavorite('每日推荐'),
                onTap: () => _open(context, const DailyRecommendPage()),
              ),
              HubActionTile(
                title: '随机乐曲',
                subtitle: '随机抽取 1-4 首歌曲',
                icon: Icons.shuffle_rounded,
                isFavorited: _isFavorited('随机乐曲'),
                onToggleFavorite: () => _toggleFavorite('随机乐曲'),
                onTap: () => _open(context, const RandomChartPage()),
              ),
              HubActionTile(
                title: '基于标签推荐',
                subtitle: '基于你的游玩谱面标签推荐曲目',
                icon: Icons.label_outline_rounded,
                isFavorited: _isFavorited('基于标签推荐'),
                onToggleFavorite: () => _toggleFavorite('基于标签推荐'),
                onTap: () => _open(context, const RecommendByTags()),
              ),
              HubActionTile(
                title: '基于目标 Rating 推荐',
                subtitle: '寻找适合上分的谱面',
                icon: Icons.trending_up_rounded,
                isFavorited: _isFavorited('基于目标 Rating 推荐'),
                onToggleFavorite: () => _toggleFavorite('基于目标 Rating 推荐'),
                onTap: () => _open(context, const RatingRecommendPage()),
              ),
              HubActionTile(
                title: '基于定数区间推荐',
                subtitle: '按定数范围挑选谱面',
                icon: Icons.tune_rounded,
                isFavorited: _isFavorited('基于定数区间推荐'),
                onToggleFavorite: () => _toggleFavorite('基于定数区间推荐'),
                onTap: () => _open(context, const DsRangeRecommendPage()),
              ),
            ],
          ),
          const SizedBox(height: 24),
          HubSection(
            title: '计算与段位',
            icon: Icons.calculate_outlined,
            subtitle: 'Rating · 达成率 · 段位 · 版本对照',
            badgeCount: 5,
            children: [
              HubActionTile(
                title: '单曲 Rating 计算',
                subtitle: '根据达成率计算单首 rating',
                icon: Icons.calculate_outlined,
                isFavorited: _isFavorited('单曲 Rating 计算'),
                onToggleFavorite: () => _toggleFavorite('单曲 Rating 计算'),
                onTap: () => _open(context, const SingleRatingCalculator()),
              ),
              HubActionTile(
                title: '达成率计算',
                subtitle: '根据判定详情算出达成率',
                icon: Icons.percent_rounded,
                isFavorited: _isFavorited('达成率计算'),
                onToggleFavorite: () => _toggleFavorite('达成率计算'),
                onTap: () => _open(context, const AchievementRateCalculator()),
              ),
              HubActionTile(
                title: '达成率反推',
                subtitle: '根据判定详情推出绝赞详情',
                icon: Icons.replay_rounded,
                isFavorited: _isFavorited('达成率反推'),
                onToggleFavorite: () => _toggleFavorite('达成率反推'),
                onTap: () =>
                    _open(context, const AchievementFullReverseCalculator()),
              ),
              HubActionTile(
                title: '段位表',
                subtitle: '挑战你的下一段位',
                icon: Icons.arrow_circle_up_rounded,
                isFavorited: _isFavorited('段位表'),
                onToggleFavorite: () => _toggleFavorite('段位表'),
                onTap: () => _open(context, const RankListPage()),
              ),
              HubActionTile(
                title: '版本对照',
                subtitle: '按版本整理可游玩曲目',
                icon: Icons.compare_arrows_rounded,
                isFavorited: _isFavorited('版本对照'),
                onToggleFavorite: () => _toggleFavorite('版本对照'),
                onTap: () => _open(context, VersionView()),
              ),
            ],
          ),
          const SizedBox(height: 24),
          HubSection(
            title: '识别与收藏',
            icon: Icons.auto_awesome_outlined,
            subtitle: '拍照 · OCR · 定数分布 · 收藏夹',
            badgeCount: 4,
            children: [
              HubActionTile(
                title: '曲绘识别',
                subtitle: '用相机或图片快速找歌',
                icon: Icons.image_search_outlined,
                isFavorited: _isFavorited('曲绘识别'),
                onToggleFavorite: () => _toggleFavorite('曲绘识别'),
                onTap: _openCoverRecognition,
                loading: _coverIndexBuilding,
                loadingText:
                    _coverIndexBuilding ? '正在构建曲绘索引…' : null,
                progressCurrent: _coverIndexBuilding
                    ? _coverProgressCurrent
                    : null,
                progressTotal:
                    _coverIndexBuilding ? _coverProgressTotal : null,
              ),
              HubActionTile(
                title: '结算画面识别',
                subtitle: '拍摄机台结算画面，自动识别成绩',
                icon: Icons.document_scanner_outlined,
                isFavorited: _isFavorited('结算画面识别'),
                onToggleFavorite: () => _toggleFavorite('结算画面识别'),
                onTap: () => _open(context, const ScoreOcrPage()),
              ),
              HubActionTile(
                title: '定数分布',
                subtitle: '查看谱面定数分布',
                icon: Icons.bar_chart_rounded,
                isFavorited: _isFavorited('定数分布'),
                onToggleFavorite: () => _toggleFavorite('定数分布'),
                onTap: () => _open(context, const DifficultyDistributionPage()),
              ),
              HubActionTile(
                title: '收藏夹',
                subtitle: '管理你收藏的谱面',
                icon: Icons.favorite_outline_rounded,
                isFavorited: _isFavorited('收藏夹'),
                onToggleFavorite: () => _toggleFavorite('收藏夹'),
                onTap: () => _open(context, const FavoriteFolderPage()),
              ),
            ],
          ),
          const SizedBox(height: 24),
          HubSection(
            title: '玩法与社区',
            icon: Icons.public_outlined,
            subtitle: '随身听 · 自定义谱面 · KALEIDXSCOPE · 好友 · 地图',
            badgeCount: 6,
            children: [
              HubActionTile(
                title: '随身听',
                subtitle: '后台播放舞萌曲库，带通知栏播放器',
                icon: Icons.headphones_rounded,
                isFavorited: _isFavorited('随身听'),
                onToggleFavorite: () => _toggleFavorite('随身听'),
                onTap: () => _openPortablePlayer(context),
              ),
              HubActionTile(
                title: '自定义谱面播放',
                subtitle: '播放本地自定义谱面',
                icon: Icons.play_circle_outline_rounded,
                isFavorited: _isFavorited('自定义谱面播放'),
                onToggleFavorite: () => _toggleFavorite('自定义谱面播放'),
                onTap: () => _open(context, const PersonalizedChartPlayConfigure()),
              ),
              HubActionTile(
                title: 'KALEIDXSCOPE',
                subtitle: '探索独特的舞萌玩法',
                icon: Icons.color_lens_outlined,
                isFavorited: _isFavorited('KALEIDXSCOPE'),
                onToggleFavorite: () => _toggleFavorite('KALEIDXSCOPE'),
                onTap: () => _open(context, const KaleidXScopeSelectPage()),
              ),
              HubActionTile(
                title: '好友对比',
                subtitle: '看看你和好友的成绩差异',
                icon: Icons.people_outline_rounded,
                isFavorited: _isFavorited('好友对比'),
                onToggleFavorite: () => _toggleFavorite('好友对比'),
                onTap: () => _open(context, const FriendComparePage()),
              ),
              HubActionTile(
                title: '全国音游地图',
                subtitle: '看看哪里有你想玩的机台',
                icon: Icons.map_rounded,
                isFavorited: _isFavorited('全国音游地图'),
                onToggleFavorite: () => _toggleFavorite('全国音游地图'),
                onTap: () => _launchExternal(
                    context, 'https://map.bemanicn.com/', '全国音游地图'),
              ),
              HubActionTile(
                title: '全球音游街机地图',
                subtitle: '查看 NearCade 全球街机店铺',
                icon: Icons.public_rounded,
                isFavorited: _isFavorited('全球音游街机地图'),
                onToggleFavorite: () => _toggleFavorite('全球音游街机地图'),
                onTap: () => _open(context, const GlobalArcadeMapPage()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
