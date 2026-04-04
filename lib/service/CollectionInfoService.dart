/**
 * 收藏品详情服务
 * */
import 'package:my_first_flutter_app/manager/CollectionsManager.dart';
import 'package:my_first_flutter_app/entity/Collection.dart';

class CollectionInfoService {
  // 获取收藏品详情
  Future<Collection?> getCollectionById(int collectionId, String collectionType) async {
    try {
      // 根据类型获取相应的收藏品数据
      final collectionsManager = CollectionsManager();
      CollectionData? collectionData;
      
      switch (collectionType) {
        case 'trophies':
          collectionData = await collectionsManager.fetchTrophiesCollections();
          break;
        case 'icons':
          collectionData = await collectionsManager.fetchIconsCollections();
          break;
        case 'plates':
          collectionData = await collectionsManager.fetchPlatesCollections();
          break;
        case 'frames':
          collectionData = await collectionsManager.fetchFramesCollections();
          break;
        default:
          return null;
      }
      
      // 查找指定ID的收藏品
      List<Collection>? collections;
      switch (collectionType) {
        case 'trophies':
          collections = collectionData?.trophies;
          break;
        case 'icons':
          collections = collectionData?.icons;
          break;
        case 'plates':
          collections = collectionData?.plates;
          break;
        case 'frames':
          collections = collectionData?.frames;
          break;
        default:
          return null;
      }
      
      if (collections != null) {
        try {
          return collections.firstWhere((collection) => collection.id == collectionId);
        } catch (e) {
          return null;
        }
      }
      
      return null;
    } catch (e) {
      print('获取收藏品详情时出错: $e');
      return null;
    }
  }
}