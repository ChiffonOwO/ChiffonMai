import '../manager/KnowledgeManager.dart';
import '../entity/KnowledgeEntity.dart';

class KnowledgeSearchService {
  final KnowledgeManager _knowledgeManager = KnowledgeManager();

  // 搜索知识条目
  Future<List<KnowledgeItem>> searchKnowledge(String keyword) async {
    // 获取所有知识数据
    final knowledgeData = await _knowledgeManager.getKnowledgeData();
    if (knowledgeData == null || knowledgeData.knowledgeItems == null) {
      return [];
    }

    final allItems = knowledgeData.knowledgeItems!;
    
    // 如果关键词为空，返回所有条目
    if (keyword.isEmpty) {
      return allItems;
    }

    // 模糊匹配搜索
    final lowerKeyword = keyword.toLowerCase();
    return allItems.where((item) {
      // 搜索title、category、content字段
      final titleMatch = item.title?.toLowerCase().contains(lowerKeyword) ?? false;
      final categoryMatch = item.category?.toLowerCase().contains(lowerKeyword) ?? false;
      final contentMatch = item.content?.toLowerCase().contains(lowerKeyword) ?? false;
      
      return titleMatch || categoryMatch || contentMatch;
    }).toList();
  }

  // 获取所有知识条目
  Future<List<KnowledgeItem>> getAllKnowledge() async {
    final knowledgeData = await _knowledgeManager.getKnowledgeData();
    return knowledgeData?.knowledgeItems ?? [];
  }

  // 根据分类获取知识条目
  Future<List<KnowledgeItem>> getKnowledgeByCategory(String category) async {
    final knowledgeData = await _knowledgeManager.getKnowledgeData();
    if (knowledgeData == null || knowledgeData.knowledgeItems == null) {
      return [];
    }

    return knowledgeData.knowledgeItems!.where((item) {
      return item.category == category;
    }).toList();
  }

  // 清除缓存
  Future<void> clearCache() async {
    await _knowledgeManager.clearCache();
  }
}