import 'package:flutter/material.dart';

// 数据模型不变
class MusicItem {
  final String imageUrl;
  final String name;
  final double constant;
  final String version;
  final String category;

  const MusicItem({
    required this.imageUrl,
    required this.name,
    required this.constant,
    required this.version,
    required this.category,
  });
}

class MusicCardList extends StatelessWidget {
  // 公共图片URL常量
  static const String defaultMusicImageUrl = "https://picsum.photos/200/200?random=1";

  // 10条测试数据
  final List<MusicItem> musicList = const [
    MusicItem(
      imageUrl: defaultMusicImageUrl,
      name: "Bad Apple!!",
      constant: 13.9,
      version: "maimai Pink+",
      category: "其他游戏",
    ),
    MusicItem(
      imageUrl: defaultMusicImageUrl,
      name: "千本桜",
      constant: 12.8,
      version: "maimai MURASAKi",
      category: "Vocaloid",
    ),
    MusicItem(
      imageUrl: defaultMusicImageUrl,
      name: "紅蓮華",
      constant: 14.2,
      version: "maimai DX Splash",
      category: "动漫歌曲",
    ),
    MusicItem(
      imageUrl: defaultMusicImageUrl,
      name: "Butter-Fly",
      constant: 11.7,
      version: "maimai GREEN",
      category: "特摄相关",
    ),
    MusicItem(
      imageUrl: defaultMusicImageUrl,
      name: "Lemon",
      constant: 13.1,
      version: "maimai ORANGE",
      category: "流行音乐",
    ),
    MusicItem(
      imageUrl: defaultMusicImageUrl,
      name: "残酷な天使のテーゼ",
      constant: 12.5,
      version: "maimai WHITE",
      category: "动漫歌曲",
    ),
    MusicItem(
      imageUrl: defaultMusicImageUrl,
      name: "海色",
      constant: 13.5,
      version: "maimai BLUE",
      category: "游戏原声",
    ),
    MusicItem(
      imageUrl: defaultMusicImageUrl,
      name: "桃源恋歌",
      constant: 12.9,
      version: "maimai PURPLE",
      category: "国风音乐",
    ),
    MusicItem(
      imageUrl: defaultMusicImageUrl,
      name: "夜に駆ける",
      constant: 14.0,
      version: "maimai DX UNIVERSE",
      category: "Vocaloid",
    ),
    MusicItem(
      imageUrl: defaultMusicImageUrl,
      name: "コネクト",
      constant: 12.3,
      version: "maimai YELLOW",
      category: "动漫歌曲",
    ),
  ];

  const MusicCardList({super.key});

  @override
  Widget build(BuildContext context) {
    // 关键：确保ListView在有Context的环境下，且上层有Directionality
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: musicList.length,
      itemBuilder: (context, index) {
        final item = musicList[index];
        return _buildMusicCard(item);
      },
    );
  }

  Widget _buildMusicCard(MusicItem item) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 5,
            offset: const Offset(2, 2),
          )
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                item.imageUrl,
                fit: BoxFit.cover,
                height: 80,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.shade200,
                    height: 80,
                    child: const Icon(Icons.music_note, color: Colors.grey),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 17,
            child: SizedBox(
              height: 80,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Text(
                        "定数: ${item.constant}",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        item.version,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        item.category,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 最关键的修复：main函数中确保MaterialApp是顶层Widget
void main() {
  runApp(
    // MaterialApp会自动提供Directionality、Theme等核心上下文
    MaterialApp(
      title: "曲目列表",
      // 关闭debug标签（可选）
      debugShowCheckedModeBanner: false,
      // 定义主题（可选，提升体验）
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey.shade50,
      ),
      // 根页面：Scaffold包裹MusicCardList，确保有完整的Material环境
      home: Scaffold(
        appBar: AppBar(
          title: const Text("maimai曲目列表"),
        ),
        body: const MusicCardList(),
      ),
    ),
  );
}