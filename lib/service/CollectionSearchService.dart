import '../manager/CollectionsManager.dart';
import '../entity/Collection.dart';

class CollectionSearchService {
  // 单例模式
  static final CollectionSearchService _instance = CollectionSearchService._internal();
  factory CollectionSearchService() => _instance;
  CollectionSearchService._internal();

  // 搜索收藏品
  Future<List<Collection>> searchCollections(String keyword, String collectionType) async {
    // 获取对应类型的收藏品数据
    CollectionData? collectionData;
    
    switch (collectionType) {
      case 'trophies':
        collectionData = await CollectionsManager().fetchTrophiesCollections();
        break;
      case 'icons':
        collectionData = await CollectionsManager().fetchIconsCollections();
        break;
      case 'plates':
        collectionData = await CollectionsManager().fetchPlatesCollections();
        break;
      case 'frames':
        collectionData = await CollectionsManager().fetchFramesCollections();
        break;
    }

    if (collectionData == null) {
      return [];
    }

    // 获取对应类型的收藏品列表
    List<Collection>? collections;
    switch (collectionType) {
      case 'trophies':
        collections = collectionData.trophies;
        break;
      case 'icons':
        collections = collectionData.icons;
        break;
      case 'plates':
        collections = collectionData.plates;
        break;
      case 'frames':
        collections = collectionData.frames;
        break;
    }

    if (collections == null || collections.isEmpty) {
      return [];
    }

    // 如果关键词为空，返回全部收藏品
    if (keyword.isEmpty) {
      return collections;
    }

    // 搜索逻辑
    final List<Collection> results = [];
    final String lowerKeyword = keyword.toLowerCase();

    for (var collection in collections) {
      // 搜索名称
      try {
        if (collection.name.toLowerCase().contains(lowerKeyword)) {
          results.add(collection);
          continue;
        }
      } catch (e) {
        print('搜索名称时出错: $e');
      }

      // 搜索描述
      try {
        if (collection.description != null && collection.description!.toLowerCase().contains(lowerKeyword)) {
          results.add(collection);
          continue;
        }
      } catch (e) {
        print('搜索描述时出错: $e');
      }

      // 搜索达成条件
      if (collection.required != null) {
        for (var req in collection.required!) {
          // 搜索评级类型
          try {
            if (req.rate != null && req.rate!.toLowerCase().contains(lowerKeyword)) {
              results.add(collection);
              break;
            }
          } catch (e) {
            print('搜索评级类型时出错: $e');
          }

          // 搜索 FC 类型
          try {
            if (req.fc != null && req.fc!.toLowerCase().contains(lowerKeyword)) {
              results.add(collection);
              break;
            }
          } catch (e) {
            print('搜索 FC 类型时出错: $e');
          }

          // 搜索 FS 类型
          try {
            if (req.fs != null && req.fs!.toLowerCase().contains(lowerKeyword)) {
              results.add(collection);
              break;
            }
          } catch (e) {
            print('搜索 FS 类型时出错: $e');
          }

          // 搜索曲目
          try {
            if (req.songs != null) {
              for (var song in req.songs!) {
                if (song.title.toLowerCase().contains(lowerKeyword)) {
                  results.add(collection);
                  break;
                }
              }
            }
          } catch (e) {
            print('搜索曲目时出错: $e');
          }
        }
      }
    }

    // 去重
    final Set<Collection> uniqueResults = Set.from(results);
    final List<Collection> finalResults = uniqueResults.toList();
    
    // 打印搜索结果的名称，检查是否有乱码
    print('搜索结果数量: ${finalResults.length}');
    for (int i = 0; i < finalResults.length && i < 5; i++) {
      print('搜索结果 $i: ${finalResults[i].name}');
    }
    
    return finalResults;
  }
}