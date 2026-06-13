class KnowledgeEntity {
  List<KnowledgeItem>? knowledgeItems;

  KnowledgeEntity(this.knowledgeItems);

  // 解析服务端 /api/knowledge 返回的 JSON 列表
  factory KnowledgeEntity.fromJson(List<dynamic> jsonList) {
    List<KnowledgeItem> items = jsonList
        .where((i) => i is Map<String, dynamic>)
        .map((i) => KnowledgeItem.fromJson(i as Map<String, dynamic>))
        .toList();
    return KnowledgeEntity(items);
  }
}

class KnowledgeItem {
  static const String tagCategory = '标签';
  static const String knowledgeCategory = '百科';

  int? id;
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

  // 解析单个知识条目（id 来自 MySQL 自增主键，为 int）
  factory KnowledgeItem.fromJson(Map<String, dynamic> json) {
    List<KnowledgeRecommendSong>? recommendSongs;

    final recommendData = json['recommendSongs'];
    if (recommendData is List) {
      recommendSongs = recommendData
          .where((songJson) => songJson is Map<String, dynamic>)
          .map((songJson) =>
              KnowledgeRecommendSong.fromJson(songJson as Map<String, dynamic>))
          .toList();
    }

    int? idValue;
    final rawId = json['id'];
    if (rawId is int) {
      idValue = rawId;
    } else if (rawId is String) {
      idValue = int.tryParse(rawId);
    }

    return KnowledgeItem(
      id: idValue,
      title: json['title']?.toString(),
      category: json['category']?.toString(),
      content: json['content']?.toString(),
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
      id: json['id']?.toString(),
      levelIndex: json['level_index']?.toString(),
    );
  }
}