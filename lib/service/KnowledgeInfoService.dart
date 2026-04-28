import '../manager/KnowledgeManager.dart';
import '../entity/KnowledgeEntity.dart';

class KnowledgeInfoService {
  final KnowledgeManager _knowledgeManager = KnowledgeManager();

  // 根据ID获取知识详情
  Future<KnowledgeItem?> getKnowledgeById(String id) async {
    final knowledgeData = await _knowledgeManager.getKnowledgeData();
    if (knowledgeData == null || knowledgeData.knowledgeItems == null) {
      return null;
    }

    return knowledgeData.knowledgeItems!.firstWhere(
      (item) => item.id == id,
    );
  }

  // 根据标题获取知识详情
  Future<KnowledgeItem?> getKnowledgeByTitle(String title) async {
    final knowledgeData = await _knowledgeManager.getKnowledgeData();
    if (knowledgeData == null || knowledgeData.knowledgeItems == null) {
      return null;
    }

    return knowledgeData.knowledgeItems!.firstWhere(
      (item) => item.title == title,
    );
  }
}