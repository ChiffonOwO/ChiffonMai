class KnowledgeEntity {
  List<KnowledgeItem>? knowledgeItems;

  KnowledgeEntity(this.knowledgeItems);

  // 一行解析整个 Pastebin JSON
  factory KnowledgeEntity.fromJson(List<dynamic> jsonList) {
    List<KnowledgeItem> items = jsonList.map((i) => KnowledgeItem.fromJson(i)).toList();
    return KnowledgeEntity(items);
  }
}

class KnowledgeItem {
  static const String tagCategory = '标签';
  static const String knowledgeCategory = '百科';

  String? id;
  String? title;
  String? category;
  String? content;
  List<KnowledgeRecommendSong>? recommendSongs;

  KnowledgeItem({
    this.id,
    this.title,
    this.category,
    this.content,
    this.recommendSongs,
  });

  // 核心：解析单个知识条目
  factory KnowledgeItem.fromJson(Map<String, dynamic> json) {
    List<KnowledgeRecommendSong>? recommendSongs;
    
    if (json['recommendSongs'] is List) {
      recommendSongs = (json['recommendSongs'] as List).map((songJson) {
        if (songJson is Map<String, dynamic>) {
          return KnowledgeRecommendSong.fromJson(songJson);
        }
        return null;
      }).where((song) => song != null).cast<KnowledgeRecommendSong>().toList();
    }
    
    return KnowledgeItem(
      id: json['id'],
      title: json['title'],
      category: json['category'],
      content: json['content'],
      recommendSongs: recommendSongs,
    );
  }
}

class KnowledgeRecommendSong {
  String? id;
  String? levelIndex;

  KnowledgeRecommendSong({
    this.id,
    this.levelIndex,
  });

  factory KnowledgeRecommendSong.fromJson(Map<String, dynamic> json) {
    return KnowledgeRecommendSong(
      id: json['id'],
      levelIndex: json['level_index'],
    );
  }
}