import 'package:my_first_flutter_app/entity/Song.dart';

class KnowledgeEntity {
  static const String tagCategory = '标签';
  static const String knowledgeCategory = '百科';

  String? id;
  String? title;
  String? category;
  String? content;
  List<Song>? basicRecommendSongs;
  List<Song>? advancedRecommendSongs;
  List<Song>? masterRecommendSongs;
  DateTime? createdAt;
  DateTime? updatedAt;

  KnowledgeEntity(
    this.id,
    this.title,
    this.category,
    this.content,
    this.basicRecommendSongs,
    this.advancedRecommendSongs,
    this.masterRecommendSongs,
    this.createdAt,
    this.updatedAt,
  );
}