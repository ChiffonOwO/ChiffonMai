import 'package:flutter/material.dart';
import 'HubComponents.dart';
import '../utils/FavoriteFeaturesNotifier.dart';
import 'GuessChartGame/GuessChartByInfoPage.dart';
import 'GuessChartGame/GuessChartByAliaPage.dart';
import 'GuessChartGame/GuessChartByCoverPage.dart';
import 'GuessChartGame/GuessChartByBlurredCoverPage.dart';
import 'GuessChartGame/GuessChartBySongExcerptPage.dart';
import 'GuessChartGame/GuessSongByOpenLettersPage.dart';
import 'Multiplayer/MultiplayerLobbyPage.dart';

class GuessHubPage extends StatefulWidget {
  const GuessHubPage({super.key});

  @override
  State<GuessHubPage> createState() => _GuessHubPageState();
}

class _GuessHubPageState extends State<GuessHubPage> {
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
        title: '猜歌游戏',
        subtitle: '凭记忆、线索或片段挑战舞萌曲库',
        icon: Icons.casino_rounded,
        children: [
          HubSection(
            title: '单人猜歌',
            icon: Icons.lightbulb_outline_rounded,
            subtitle: '换个方式熟悉曲库',
            badgeCount: 6,
            children: [
              HubActionTile(
                title: '无提示猜歌',
                subtitle: '凭记忆挑战曲库',
                icon: Icons.visibility_off_outlined,
                isFavorited: _isFavorited('无提示猜歌'),
                onToggleFavorite: () => _toggleFavorite('无提示猜歌'),
                onTap: () => _open(context, const GuessChartByInfoPage()),
              ),
              HubActionTile(
                title: '根据部分曲绘猜歌',
                subtitle: '看一小块曲绘猜出歌曲',
                icon: Icons.image_outlined,
                isFavorited: _isFavorited('根据部分曲绘猜歌'),
                onToggleFavorite: () => _toggleFavorite('根据部分曲绘猜歌'),
                onTap: () => _open(context, const GuessChartByCoverPage()),
              ),
              HubActionTile(
                title: '根据模糊曲绘猜歌',
                subtitle: '根据模糊化处理后的曲绘猜歌',
                icon: Icons.blur_on_outlined,
                isFavorited: _isFavorited('根据模糊曲绘猜歌'),
                onToggleFavorite: () => _toggleFavorite('根据模糊曲绘猜歌'),
                onTap: () => _open(context, const GuessChartByBlurredCoverPage()),
              ),
              HubActionTile(
                title: '根据歌曲片段猜歌',
                subtitle: '截取音源片段猜歌',
                icon: Icons.music_note_outlined,
                isFavorited: _isFavorited('根据歌曲片段猜歌'),
                onToggleFavorite: () => _toggleFavorite('根据歌曲片段猜歌'),
                onTap: () => _open(context, const GuessChartBySongExcerptPage()),
              ),
              HubActionTile(
                title: '根据别名猜歌',
                subtitle: '用别名挑战你的熟悉度',
                icon: Icons.abc_rounded,
                isFavorited: _isFavorited('根据别名猜歌'),
                onToggleFavorite: () => _toggleFavorite('根据别名猜歌'),
                onTap: () => _open(context, const GuessChartByAliaPage()),
              ),
              HubActionTile(
                title: '舞萌开字母',
                subtitle: '看首字母猜歌',
                icon: Icons.text_fields_outlined,
                isFavorited: _isFavorited('舞萌开字母'),
                onToggleFavorite: () => _toggleFavorite('舞萌开字母'),
                onTap: () => _open(context, const GuessSongByOpenLettersPage()),
              ),
            ],
          ),
          const SizedBox(height: 24),
          HubSection(
            title: '多人猜歌',
            icon: Icons.groups_outlined,
            subtitle: '和朋友一起开一局',
            badgeCount: 1,
            children: [
              HubActionTile(
                title: '多人猜歌游戏',
                subtitle: '和朋友一起猜舞萌曲库',
                icon: Icons.groups_rounded,
                isFavorited: _isFavorited('多人猜歌游戏'),
                onToggleFavorite: () => _toggleFavorite('多人猜歌游戏'),
                onTap: () => _open(context, const MultiplayerLobbyPage()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
