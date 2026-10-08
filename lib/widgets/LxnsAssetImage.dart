import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// 落雪（`assets2.lxns.net/maimai/**`）静态素材的**专属磁盘缓存**。
///
/// 为什么要单开一个（与 `dxRatingCoverCacheManager` 是同一套理由）：
/// `CachedNetworkImage` 默认走 `DefaultCacheManager`，它只有 **200 个对象**的
/// 容量，而且**全 App 共用** —— 排行榜头像、收藏品图、通知栏曲绘等都在同一个
/// 池子里。落雪这边光头像就有 1000+、姓名框 400、背景 350，随便滚一遍就超过
/// 上限；超限且**超过一天没被访问**的对象会被清理（见 flutter_cache_manager
/// 的 `CacheObjectProvider.getObjectsOverCapacity`），于是下次打开又变成
/// 「真·重新下载」。
///
/// 关于「缓存时间」有一个容易误解的点：`stalePeriod` **不是**回源的判据，
/// 它只用于磁盘清理。真正决定要不要联网的是响应头算出来的 `validTill` ——
/// 落雪给的是 `cache-control: max-age=3600`，也就是**一小时**。一小时后会发
/// 一次条件请求（`If-None-Match`），服务端命中 ETag 时回 304、不下发图片字节。
/// 这里按 30 天保留磁盘副本，就是为了让那次条件请求永远能在本地拿到文件。
final CacheManager lxnsAssetCacheManager = CacheManager(
  Config(
    'lxns_assets_v1',
    stalePeriod: const Duration(days: 30),
    maxNrOfCacheObjects: 2000,
  ),
);

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
