import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:my_first_flutter_app/utils/CoverUtil.dart';

/// 分块渐显曲绘的绘制组件。
///
/// 曲绘经 [CoverUtil.resolveCoverProvider] 的多级 fallback 异步解析
/// （assets 主路径 → 备用路径 → 网络曲绘），通过 ImageStream 拿到 [ui.Image]
/// 后在 canvas 上按块绘制；块索引 → (row, col) 的映射与揭示顺序（洗牌序列）
/// 解耦，重绘时已揭示的块保持不变。
///
/// 单人「曲绘拼图猜歌」与多人 tileReveal 模式共用这个组件 ——
/// 两边的揭示顺序都由 `GameSeedUtil` 决定（多人是确定性种子，保证所有玩家一致），
/// 组件本身只负责把「已揭示的块」画出来。
class TileRevealImage extends StatefulWidget {
  final String songId;
  final double size;
  final int tileCount;
  final Set<int> revealedTiles;
  final Color emptyColor;

  const TileRevealImage({
    super.key,
    required this.songId,
    required this.size,
    required this.tileCount,
    required this.revealedTiles,
    required this.emptyColor,
  });

  @override
  State<TileRevealImage> createState() => _TileRevealImageState();
}

class _TileRevealImageState extends State<TileRevealImage> {
  ImageStream? _imageStream;
  ImageStreamListener? _listener;
  ui.Image? _image;

  @override
  void didUpdateWidget(covariant TileRevealImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 揭示进度变化时重绘；曲绘 id 变化时重新加载
    if (oldWidget.songId != widget.songId) {
      _loadImage();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  // 通过 CoverUtil.resolveCoverProvider 拿到带多级 fallback 的 ImageProvider
  // （assets 主路径 → 备用路径 → 网络曲绘），再经 ImageStream 转 ui.Image。
  //
  // 注意不能用 assets/cover/{songId}.webp 直读：5/6 位 songId 需要按
  // CoverUtil 的剔除规则换算成真实资源名（如：11312 → 1312.webp），
  // 直读会几乎必失败，表现为拼图全程只剩灰底。
  Future<void> _loadImage() async {
    final String songId = widget.songId;
    final provider = await CoverUtil.resolveCoverProvider(songId);
    if (!mounted || songId != widget.songId) return;

    final stream = provider.resolve(createLocalImageConfiguration(context));
    _listener = ImageStreamListener((ImageInfo info, bool synchronousCall) {
      if (!mounted) return;
      setState(() {
        _image = info.image;
      });
    }, onError: (Object error, StackTrace? stackTrace) {
      // 曲绘加载失败：保持空底色，不阻塞游戏
    });
    _imageStream = stream;
    stream.addListener(_listener!);
  }

  @override
  void dispose() {
    if (_imageStream != null && _listener != null) {
      _imageStream!.removeListener(_listener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(widget.size, widget.size),
      painter: _TileRevealPainter(
        image: _image,
        tileCount: widget.tileCount,
        revealedTiles: widget.revealedTiles,
        emptyColor: widget.emptyColor,
      ),
    );
  }
}

class _TileRevealPainter extends CustomPainter {
  final ui.Image? image;
  final int tileCount;
  final Set<int> revealedTiles;
  final Color emptyColor;

  _TileRevealPainter({
    required this.image,
    required this.tileCount,
    required this.revealedTiles,
    required this.emptyColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 背景：未揭示块的底色
    final Paint bgPaint = Paint()..color = emptyColor;
    canvas.drawRect(Offset.zero & size, bgPaint);

    if (image == null) return;

    final int cols = sqrt(tileCount).round();
    final int rows = (tileCount / cols).ceil();
    final double tileW = size.width / cols;
    final double tileH = size.height / rows;

    final Paint imgPaint = Paint()..filterQuality = FilterQuality.medium;

    for (final int index in revealedTiles) {
      final int row = index ~/ cols;
      final int col = index % cols;
      if (row >= rows) continue;

      final Rect dst = Rect.fromLTWH(
        col * tileW,
        row * tileH,
        tileW,
        tileH,
      );

      // 曲绘按 cover 方式铺满（正方形 → 一一对应）
      final Rect src = Rect.fromLTWH(
        col * image!.width / cols,
        row * image!.height / rows,
        image!.width / cols,
        image!.height / rows,
      );

      canvas.drawImageRect(image!, src, dst, imgPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TileRevealPainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.tileCount != tileCount ||
        oldDelegate.revealedTiles.length != revealedTiles.length ||
        oldDelegate.emptyColor != emptyColor;
  }
}
