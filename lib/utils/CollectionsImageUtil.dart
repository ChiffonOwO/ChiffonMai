import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:my_first_flutter_app/entity/Collection.dart';

/**
 * 收藏品图片工具类
 * */
 class CollectionsImageUtil {

  static final String _imageBaseUrl = 'https://assets2.lxns.net/maimai';
  // 获取头像图片的URL（带缓存）
  static Widget getIconImageURL(Collection collection) {
    return CachedNetworkImage(
      imageUrl: '$_imageBaseUrl/icon/${collection.id}.png',
      placeholder: (context, url) => Center(child: CircularProgressIndicator()),
      errorWidget: (context, url, error) => Center(child: Icon(Icons.error)),
      fit: BoxFit.contain,
    );
  }
  // 获取姓名框图片的URL（带缓存）
  static Widget getPlateImageURL(Collection collection) {
    return CachedNetworkImage(
      imageUrl: '$_imageBaseUrl/plate/${collection.id}.png',
      placeholder: (context, url) => Center(child: CircularProgressIndicator()),
      errorWidget: (context, url, error) => Center(child: Icon(Icons.error)),
      fit: BoxFit.contain,
    );
  }
  // 获取背景图片的URL（带缓存）
  static Widget getFrameImageURL(Collection collection) {
    return CachedNetworkImage(
      imageUrl: '$_imageBaseUrl/frame/${collection.id}.png',
      placeholder: (context, url) => Center(child: CircularProgressIndicator()),
      errorWidget: (context, url, error) => Center(child: Icon(Icons.error)),
      fit: BoxFit.contain,
    );
  }
 }