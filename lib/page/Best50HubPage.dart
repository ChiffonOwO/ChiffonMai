import 'package:flutter/material.dart';
import 'HubComponents.dart';
import '../utils/FavoriteFeaturesNotifier.dart';
import 'Best50/Best50Page.dart';
import 'Best50/DiffBest50Page.dart';
import 'Best50/PersonalizedBest50Page.dart';
import 'Best50/PersonalizedDiffBest50Page.dart';
import 'Best50/CustomBest50Page.dart';
import 'Best50/IdealBest50Page.dart';
import 'RankingList/AvgScoreRankingListPage.dart';
import 'RankingList/FittedRatingRankingListPage.dart';
import 'RankingList/RatingRankListPage.dart';
import 'RankingList/SpecialRankingListPage.dart';
import 'History/RatingHistoryPage.dart';
import '../service/RankingList/AvgRankingListService.dart';

class Best50HubPage extends StatefulWidget {
  const Best50HubPage({super.key});

  @override
  State<Best50HubPage> createState() => _Best50HubPageState();
}

class _Best50HubPageState extends State<Best50HubPage> {
  void _open(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  bool _isFavorited(String title) =>
      FavoriteFeaturesNotifier.titles.contains(title);

  Future<void> _toggleFavorite(String title) =>
      FavoriteFeaturesNotifier.toggle(title);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<FavoritesPayload>(
      valueListenable: FavoriteFeaturesNotifier.instance,
      builder: (context, payload, _) => HubPageScaffold(
        title: 'Best50 与排行榜',
        subtitle: '查看你的 Rating 上限与全站排行',
        icon: Icons.emoji_events_rounded,
        children: [
          HubSection(
            title: 'Best50 分析',
            icon: Icons.leaderboard_outlined,
            subtitle: '多维度 Best50 综合分析',
            badgeCount: 7,
            children: [
              HubActionTile(
                title: 'Best50',
                subtitle: '查看当前 Best35 与 Best15',
                icon: Icons.leaderboard_rounded,
                isFavorited: _isFavorited('Best50'),
                onToggleFavorite: () => _toggleFavorite('Best50'),
                onTap: () => _open(context, const B50Page()),
              ),
              HubActionTile(
                title: '拟合 Best50',
                subtitle: '分析潜在 Rating 上限',
                icon: Icons.auto_graph_rounded,
                isFavorited: _isFavorited('拟合 Best50'),
                onToggleFavorite: () => _toggleFavorite('拟合 Best50'),
                onTap: () => _open(context, const DiffBest50Page()),
              ),
              HubActionTile(
                title: 'Rating 历史',
                subtitle: '看 Rating 随时间的变化',
                icon: Icons.timeline_rounded,
                isFavorited: _isFavorited('Rating 历史'),
                onToggleFavorite: () => _toggleFavorite('Rating 历史'),
                onTap: () => _open(context, const RatingHistoryPage()),
              ),
              HubActionTile(
                title: '个性化 Best50',
                subtitle: '按标签筛选 Best50',
                icon: Icons.filter_alt_outlined,
                isFavorited: _isFavorited('个性化 Best50'),
                onToggleFavorite: () => _toggleFavorite('个性化 Best50'),
                onTap: () => _open(context, const PersonalizedBest50Page()),
              ),
              HubActionTile(
                title: '个性化拟合 Best50',
                subtitle: '按标签查看拟合 Rating 上限',
                icon: Icons.analytics_outlined,
                isFavorited: _isFavorited('个性化拟合 Best50'),
                onToggleFavorite: () => _toggleFavorite('个性化拟合 Best50'),
                onTap: () => _open(context, const PersonalizedDiffBest50Page()),
              ),
              HubActionTile(
                title: '自定义 Best50',
                subtitle: '手动填写 50 张成绩卡片',
                icon: Icons.edit_note_rounded,
                isFavorited: _isFavorited('自定义 Best50'),
                onToggleFavorite: () => _toggleFavorite('自定义 Best50'),
                onTap: () => _open(context, const CustomBest50Page()),
              ),
              HubActionTile(
                title: '理想 Best50',
                subtitle: '全员升一档后的 Best50 模拟',
                icon: Icons.auto_fix_high_rounded,
                isFavorited: _isFavorited('理想 Best50'),
                onToggleFavorite: () => _toggleFavorite('理想 Best50'),
                onTap: () => _open(context, const IdealBest50Page()),
              ),
            ],
          ),
          const SizedBox(height: 24),
          HubSection(
            title: '排行榜',
            icon: Icons.emoji_events_outlined,
            subtitle: '全站玩家排行与特殊榜单',
            badgeCount: 5,
            children: [
              HubActionTile(
                title: 'Rating 排行榜',
                subtitle: '查看玩家 Rating 排行',
                icon: Icons.public_rounded,
                isFavorited: _isFavorited('Rating 排行榜'),
                onToggleFavorite: () => _toggleFavorite('Rating 排行榜'),
                onTap: () => _open(context, const RatingRankListPage()),
              ),
              HubActionTile(
                title: '拟合总Rating排行榜',
                subtitle: '拟合总 Rating 站内排行',
                icon: Icons.auto_graph_rounded,
                isFavorited: _isFavorited('拟合总Rating排行榜'),
                onToggleFavorite: () => _toggleFavorite('拟合总Rating排行榜'),
                onTap: () => _open(context, const FittedRatingRankingListPage()),
              ),
              HubActionTile(
                title: '平均达成率排行榜',
                subtitle: '按全量成绩的平均达成率排名',
                icon: Icons.percent_rounded,
                isFavorited: _isFavorited('平均达成率排行榜'),
                onToggleFavorite: () => _toggleFavorite('平均达成率排行榜'),
                onTap: () => _open(context,
                    const AvgScoreRankingListPage(initialMetric: AvgMetric.achievement)),
              ),
              HubActionTile(
                title: '平均DX分数达成率排行榜',
                subtitle: '按全量成绩的平均DX得分达成率排名',
                icon: Icons.score_outlined,
                isFavorited: _isFavorited('平均DX分数达成率排行榜'),
                onToggleFavorite: () => _toggleFavorite('平均DX分数达成率排行榜'),
                onTap: () => _open(context,
                    const AvgScoreRankingListPage(initialMetric: AvgMetric.dx)),
              ),
              HubActionTile(
                title: '特殊排行榜',
                subtitle: 'BPM 55？BPM 339？！',
                icon: Icons.workspace_premium_outlined,
                isFavorited: _isFavorited('特殊排行榜'),
                onToggleFavorite: () => _toggleFavorite('特殊排行榜'),
                onTap: () => _open(context, const SpecialRankingListPage()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
