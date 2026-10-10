import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// 收藏品专属缓存：Flutter ImageCache 复用内存中的解码结果，磁盘副本用于
/// 进程重启或内存淘汰后的读取。文件在应用缓存目录，卸载时随应用清除。
/// 保留旧缓存标识以复用已下载的素材；只在本地文件缺失时联网。
final LxnsAssetCacheManager lxnsAssetCacheManager = LxnsAssetCacheManager();

class LxnsAssetCacheManager extends CacheManager {
  LxnsAssetCacheManager()
      : super(Config(
          'lxns_assets_v1',
          stalePeriod: const Duration(days: 3650),
          maxNrOfCacheObjects: 10000,
        ));

  final Map<String, Future<FileInfo>> _downloads = {};

  Future<Uint8List> readBytes(String url) async {
    final result = await getFileStream(url).first;
    return (result as FileInfo).file.readAsBytes();
  }

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) async* {
    final cacheKey = key ?? url;
    final cached = await getFileFromCache(cacheKey);
    // 不按服务端的 max-age 重复回源：收藏品本地命中即返回。
    if (cached != null && await cached.file.exists()) {
      yield cached;
      return;
    }

    final download = _downloads.putIfAbsent(
      cacheKey,
      () => downloadFile(url, key: cacheKey, authHeaders: headers),
    );
    try {
      yield await download;
    } finally {
      if (identical(_downloads[cacheKey], download)) {
        _downloads.remove(cacheKey);
      }
    }
  }
}

/// 落雪静态素材的 URL 前缀（头像 / 姓名框 / 背景）。
const String lxnsAssetBaseUrl = 'https://assets2.lxns.net/maimai';

/// 头像图：`icon/<收藏品 id>.png`（128×128）。
String lxnsIconUrl(int id) => '$lxnsAssetBaseUrl/icon/$id.png';

/// 姓名框图：`plate/<收藏品 id>.png`（约 720×116 的长条）。
String lxnsPlateUrl(int id) => '$lxnsAssetBaseUrl/plate/$id.png';

/// 背景图：`frame/<收藏品 id>.png`。
String lxnsFrameUrl(int id) => '$lxnsAssetBaseUrl/frame/$id.png';

/// 落雪静态素材图片：统一磁盘缓存 + **零淡入** + 静态占位 + 自动解码尺寸。
///
/// 为什么不用裸 `CachedNetworkImage`：
///
/// 1. **默认的 500ms 淡入会让「本地已命中」看起来像「正在联网」。** 磁盘缓存的
///    读取是异步的（sqflite 查询 + 读文件），所以每次拉起网格时第一帧必然是
///    `frame == null`，于是先出 placeholder、再花 500ms 淡入 —— 哪怕这张图早
///    就躺在本地、一个字节都不用下。头像 / 姓名框这类**每次打开都重新建一遍
///    Widget 树**的场景（如 `CollectionPickerSheet`）尤其明显。
/// 2. **placeholder 不能是转圈。** 转圈在观感上就等于「正在上网」，而绝大多数
///    情况下读的是本地磁盘。这里统一用主题浅底 + 失败时一个小图标。
/// 3. **不传解码尺寸会白白占内存。** `memCacheWidth` 让引擎按实际显示尺寸解码
///    （`allowUpscaling = false`，小图不会被放大），密集网格 / 小头像时能省下
///    大半的 `ImageCache` 占用 —— `ImageCache` 一旦被挤爆，解码结果要重新从
///    磁盘做一次，又会重新触发第 1 点的「像是在加载」。
///
/// 顺带一提：这里**只传宽度**。`ResizeImage` 默认 `ResizeImagePolicy.exact`，
/// 宽高都给会把非等比的原图（姓名框 720×116）拉伸变形；只给一维时引擎会按
/// 原图宽高比推算另一维。
class LxnsAssetImage extends StatelessWidget {
  /// 图片地址，用 [lxnsIconUrl] / [lxnsPlateUrl] / [lxnsFrameUrl] 拼。
  final String url;

  final BoxFit fit;

  /// 与 `CachedNetworkImage.alignment` 一致：这里只能是 [Alignment]
  /// （`AlignmentGeometry` 不能传给它，例如 `AlignmentDirectional` 会被
  /// 框架拒绝）。
  final Alignment alignment;

  /// 显式尺寸（dp）。父级给的是无界约束时必须传（如放进 `Row` 的裸子项，
  /// 那些位置 `LayoutBuilder` 拿不到可用的宽度，会自动退回不限制解码尺寸）。
  final double? width;
  final double? height;

  /// 加载中的静态占位（**不要传 `CircularProgressIndicator`**）。
  /// 不传则用主题浅底。
  final Widget? placeholder;

  /// 加载失败的静态占位。不传则用主题浅底 + 一个提示图标。
  ///
  /// 它也保持「静态」，不做任何动画 —— 导出截图 / 长列表滚动时动画会带来
  /// 不确定的帧。
  final Widget? errorWidget;

  const LxnsAssetImage({
    super.key,
    required this.url,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final neutral = ColoredBox(color: scheme.surfaceContainerHighest);

    return LayoutBuilder(
      builder: (context, constraints) {
        // 解码尺寸：优先用显式 width；否则取布局给的实际宽度。两者都没有
        // （无界约束）时不限制，行为与改动前一致。
        //
        // 只给一维是刻意的：`ResizeImage` 默认 `ResizeImagePolicy.exact`，
        // 宽高都给会把非等比的原图（姓名框 720×116）拉伸变形；只给宽度时
        // 引擎按原图宽高比推算高度。
        final logicalWidth = width ??
            (constraints.hasBoundedWidth && constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : null);
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final cacheWidth = logicalWidth != null && logicalWidth > 0
            ? math.max(1, (logicalWidth * dpr).round())
            : null;

        return CachedNetworkImage(
          imageUrl: url,
          // 专属磁盘缓存：不再和排行榜头像 / 曲绘挤那 200 个名额。
          cacheManager: lxnsAssetCacheManager,
          width: width,
          height: height,
          fit: fit,
          alignment: alignment,
          memCacheWidth: cacheWidth,
          // 零淡入零淡出：本地命中也要经过一次异步读，但不需要动画来「掩饰」它。
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          placeholder: (_, __) => placeholder ?? neutral,
          errorWidget: (_, __, ___) =>
              errorWidget ??
              ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: Center(
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
        );
      },
    );
  }
}
