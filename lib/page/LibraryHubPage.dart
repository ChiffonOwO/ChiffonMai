import 'package:flutter/material.dart';
import 'HubComponents.dart';
import '../utils/FavoriteFeaturesNotifier.dart';
import 'SongSearchPage.dart';
import 'UserScoreSearchPage.dart';
import 'PersonalizedScorePage.dart';
import 'PaiziProgressPage.dart';
import 'Collection/CollectionSearchPage.dart';

class LibraryHubPage extends StatefulWidget {
  const LibraryHubPage({super.key});

  @override
  State<LibraryHubPage> createState() => _LibraryHubPageState();
}

class _LibraryHubPageState extends State<LibraryHubPage> {
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
        title: '曲库与数据',
        subtitle: '查曲、看数据、查牌子与个性化成绩',
        icon: Icons.library_music_rounded,
        children: [
          HubSection(
            title: '曲库入口',
            icon: Icons.search_rounded,
            subtitle: '搜索与浏览舞萌曲库',
            badgeCount: 1,
            children: [
              HubActionTile(
                title: '乐曲查询',
                subtitle: '按歌名、别名、谱师和标签搜索',
                icon: Icons.search_rounded,
                isFavorited: _isFavorited('乐曲查询'),
                onToggleFavorite: () => _toggleFavorite('乐曲查询'),
                onTap: () => _open(context, const SongSearchPage()),
              ),
            ],
          ),
          const SizedBox(height: 24),
          HubSection(
            title: '数据查询',
            icon: Icons.analytics_outlined,
            subtitle: '成绩 · 个性化成绩 · 牌子进度 · 收藏品',
            badgeCount: 4,
            children: [
              HubActionTile(
                title: '成绩查询',
                subtitle: '浏览全部游玩记录与筛选结果',
                icon: Icons.score_outlined,
                isFavorited: _isFavorited('成绩查询'),
                onToggleFavorite: () => _toggleFavorite('成绩查询'),
                onTap: () => _open(context, const UserScoreSearchPage()),
              ),
              HubActionTile(
                title: '个性化成绩查询',
                subtitle: '按等级或谱师查看成绩',
                icon: Icons.tune_rounded,
                isFavorited: _isFavorited('个性化成绩查询'),
                onToggleFavorite: () => _toggleFavorite('个性化成绩查询'),
                onTap: () => _open(context, const PersonalizedScorePage()),
              ),
              HubActionTile(
                title: '牌子进度',
                subtitle: '查看各版本与目标牌子',
                icon: Icons.workspace_premium_outlined,
                isFavorited: _isFavorited('牌子进度'),
                onToggleFavorite: () => _toggleFavorite('牌子进度'),
                onTap: () => _open(context, const PaiziProgressPage()),
              ),
              HubActionTile(
                title: '收藏品查询',
                subtitle: '查看头像、姓名框等收藏品',
                icon: Icons.collections_bookmark_outlined,
                isFavorited: _isFavorited('收藏品查询'),
                onToggleFavorite: () => _toggleFavorite('收藏品查询'),
                onTap: () => _open(context, const CollectionSearchPage()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
