import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/entity/LuoXue/Collection.dart';

import '../widgets/LxnsAssetImage.dart';

/**
 * 收藏品图片工具类
 *
 * 统一走 [LxnsAssetImage]（落雪素材专属磁盘缓存 + 零淡入 + 静态占位 +
 * 按布局宽度限制解码尺寸），不要再退回裸 `CachedNetworkImage`：
 * 默认的 `DefaultCacheManager` 只有 200 个对象且全 App 共用，
 * 收藏品这边头像 1000+ / 姓名框 400 / 背景 350，很容易被挤掉后重新下载。
 * */
class CollectionsImageUtil {
  // 获取头像图片的URL（带缓存）
  static Widget getIconImageURL(Collection collection) {
    return LxnsAssetImage(url: lxnsIconUrl(collection.id));
  }

  // 获取姓名框图片的URL（带缓存）
  static Widget getPlateImageURL(Collection collection) {
    return LxnsAssetImage(url: lxnsPlateUrl(collection.id));
  }

  // 获取背景图片的URL（带缓存）
  static Widget getFrameImageURL(Collection collection) {
    return LxnsAssetImage(url: lxnsFrameUrl(collection.id));
  }
}
