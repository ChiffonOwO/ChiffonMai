import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../utils/CommunityProfileUtil.dart';
import 'DataSourceTag.dart';

/// 只根据社区接口返回的头像 ID 渲染，不读取当前设备的头像偏好。
class CommunityAvatar extends StatelessWidget {
  /// 默认边长（dp）。需要「头像跟着文字高走」的场合由调用方传实际值，见
  /// [CommunityPlayerIdentity.avatarMatchesTextHeight]。
  static const double defaultSize = 32;

  final int avatarId;
  final double size;

  const CommunityAvatar({
    super.key,
    required this.avatarId,
    this.size = defaultSize,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final id = CommunityProfileUtil.normalizeAvatarId(avatarId);
    final pixels =
        (size * MediaQuery.devicePixelRatioOf(context)).round().clamp(1, 512);
    Widget fallback() => ColoredBox(
          color: scheme.surfaceContainerHighest,
          child: Center(
            child: Icon(Icons.person_rounded,
                color: scheme.onSurfaceVariant, size: size * 0.6),
          ),
        );

    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          // 与系统 Hub 的 72px 头像、12px 圆角保持相同比例。
          borderRadius: BorderRadius.circular(size / 6),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: CachedNetworkImage(
          imageUrl: 'https://assets2.lxns.net/maimai/icon/$id.png',
          fit: BoxFit.cover,
          memCacheWidth: pixels,
          memCacheHeight: pixels,
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          placeholder: (context, url) => fallback(),
          errorWidget: (context, url, error) => fallback(),
        ),
      ),
    );
  }
}

/// 将来源标签放在昵称下面，为头像与长昵称留出空间。
class CommunityPlayerIdentity extends StatelessWidget {
  /// 「玩家名」那一行与「数据源标签」那一行之间的间距（唯一的来源，
  /// [avatarMatchesTextHeight] 量总高时也用它）。
  static const double nameTagGap = 3;

  final int avatarId;
  final String name;
  final String dataSource;
  final TextStyle? nameStyle;

  /// 头像高度是否对齐右侧两行文字的**总高**（玩家名 + [nameTagGap] + 数据源标签）。
  ///
  /// 打开后头像尺寸是**量出来**的，不是写死的 dp：系统字号（`textScaler`）或主题
  /// 行高变了它跟着变。排行榜列表都打开它 —— Best50 枢纽里除了「特殊排行榜」之外
  /// 的那 4 个排行榜（Rating / 拟合总 Rating / 平均达成率 / 平均 DX 达成率），
  /// 以及单曲排行榜 / DX 分数排行榜（`SongRankingPage`）：
  /// 这些行原来固定 32dp，比旁边两行文字矮一截，看着不齐。
  ///
  /// 默认关闭只是保留「固定 [CommunityAvatar.defaultSize]」这条老行为；
  /// 排行榜里的玩家身份块一律显式打开，别让调用点靠猜。
  final bool avatarMatchesTextHeight;

  const CommunityPlayerIdentity({
    super.key,
    required this.avatarId,
    required this.name,
    required this.dataSource,
    this.nameStyle,
    this.avatarMatchesTextHeight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CommunityAvatar(
          avatarId: avatarId,
          size: avatarMatchesTextHeight
              ? _textBlockHeight(context)
              : CommunityAvatar.defaultSize,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name,
                  style: nameStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: nameTagGap),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: DataSourceTag(dataSource: dataSource),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 「玩家名（一行）+ 间距 + 数据源标签」真实渲染出来的总高。
  ///
  /// 用 `TextPainter` 量而不是估一个 40 之类的数字：名字与标签都跟着系统字号缩放、
  /// 行高继承自主题，写死的值在用户把字体调大以后立刻错位（与 `MarqueeText`
  /// 量文本宽度是同一个理由，那两处「必须带」在这里同样适用：
  /// `DefaultTextStyle` 与 `MediaQuery.textScalerOf`）。
  double _textBlockHeight(BuildContext context) {
    final defaultStyle = DefaultTextStyle.of(context);
    final painter = TextPainter(
      text: TextSpan(text: name, style: defaultStyle.style.merge(nameStyle)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      textHeightBehavior: defaultStyle.textHeightBehavior ??
          DefaultTextHeightBehavior.maybeOf(context),
      // 与渲染一致：名字那一行是 maxLines: 1 + 省略号，高度恒为一行。
      maxLines: 1,
    )..layout();
    final nameHeight = painter.height;
    painter.dispose();

    // 标签量的是**实际会显示的那串字**（水鱼 / 落雪 / AWMC / 未知），
    // 中文与拉丁字母的回退字体度量可能不同。
    final label =
        dataSourceStyleOf(dataSource, Theme.of(context).brightness).label;
    return nameHeight + nameTagGap + DataSourceTag.heightFor(context, label);
  }
}
