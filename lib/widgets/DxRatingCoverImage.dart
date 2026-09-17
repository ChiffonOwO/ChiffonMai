import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../service/DxRatingCoverService.dart';

/// dxrating（shama）曲绘图专用的磁盘缓存。
///
/// 为什么要单独一个：`CachedNetworkImage` 默认用的 `DefaultCacheManager` 只有
/// **200 个对象**且与头像等图片共用，曲绘一多就会互相驱逐、反复回源。
/// 这里单开一个库，因为 shama 的响应头是
/// `cache-control: public, max-age=31356000, immutable`（一年），
/// 服务端明确希望客户端长期缓存 —— 我们按 30 天 / 1000 张来存，
/// 既不用反复请求，也不会无限占空间（单张 14~32 KB，最坏约 30MB）。
final CacheManager dxRatingCoverCacheManager = CacheManager(
  Config(
    'dxrating_covers_v1',
    stalePeriod: const Duration(days: 30),
    maxNrOfCacheObjects: 1000,
  ),
);

/// 曲绘的**最后一道网络兜底**：dxrating（shama）曲绘图。
///
/// 用在 `CoverUtil` 的多级 fallback 链末端（本地 assets → diving-fish → 这里
/// → 默认曲绘）：
///   * [songId] 在 [DxRatingCoverService] 的索引里有映射 → 用带磁盘缓存的
///     [CachedNetworkImage] 加载（同一张图一个周期内只下载一次）；
///   * 没有映射（索引还没建好 / 这首歌 dxrating 也没有）→ 显示默认曲绘，
///     顺带触发一次索引加载，下次就能命中。
///
/// 用 StatefulWidget 是为了「索引后到」的情况：一开始没有映射就先显示默认曲绘，
/// 索引就绪后自动换成真曲绘，调用方不用关心加载时机。
class DxRatingCoverImage extends StatefulWidget {
  /// 歌曲 id（水鱼 / union / 落雪口径都可以，内部会归一化）。
  final String songId;

  /// 与其它曲绘一致的填充方式。
  final BoxFit fit;

  const DxRatingCoverImage({
    super.key,
    required this.songId,
    this.fit = BoxFit.cover,
  });

  /// 与 `CoverUtil.buildCoverPath('0')` 一致（不 import 它，避免循环依赖）。
  static const String defaultCoverAsset = 'assets/cover/0.webp';

  @override
  State<DxRatingCoverImage> createState() => _DxRatingCoverImageState();
}

class _DxRatingCoverImageState extends State<DxRatingCoverImage> {
  String? _url;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant DxRatingCoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.songId != widget.songId) {
      _url = null;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final service = DxRatingCoverService.instance;
    // 先看内存索引（通常已经有），没有再等加载（磁盘缓存优先，联网最多一次/会话）
    var url = service.coverUrlFor(widget.songId);
    if (url == null) {
      await service.ensureLoaded();
      url = service.coverUrlFor(widget.songId);
    }
    if (!mounted || url == _url) return;
    setState(() => _url = url);
  }

  @override
  Widget build(BuildContext context) {
    final url = _url;
    if (url == null) {
      // 没有映射：显示默认曲绘；_resolve 拿到映射后会自动换成真曲绘
      return Image.asset(
        DxRatingCoverImage.defaultCoverAsset,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      cacheManager: dxRatingCoverCacheManager,
      fit: widget.fit,
      fadeInDuration: const Duration(milliseconds: 120),
      placeholder: (context, _) => Image.asset(
        DxRatingCoverImage.defaultCoverAsset,
        fit: widget.fit,
      ),
      errorWidget: (context, _, __) => Image.asset(
        DxRatingCoverImage.defaultCoverAsset,
        fit: widget.fit,
      ),
    );
  }
}
