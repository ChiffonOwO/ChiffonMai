import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import '../utils/AppDesignTokens.dart';

/// Hub 页面通用组件库：Section、ActionTile、Scaffold。
/// UI 设计原则：留白克制、卡片浮起感、主题色仅作点缀。

/// 「快捷入口」那种方形小按钮（图标 + 标题 + 副标题）。
///
/// ⚠️ 底色与描边**必须**画在自己这层 [Material] 上，不能用 [Ink]：
/// [Ink] 的 decoration 是交给**最近的 Material**（滚动页里通常是 Scaffold 那层）
/// 的 ink 层去画的，而那一层在 ListView/Scrollable 的滚动（以及 Android 的
/// 拉伸回弹 `StretchingOverscrollIndicator`）变换之外 —— 表现就是
/// 「上下滑动时只有文字被拉伸、按钮不动」。自带一层 Material 后，
/// 底色、描边、水波纹都在列表内部绘制，跟文字一起动。
class HubQuickAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const HubQuickAction({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 15, 10, 13),
          child: Column(children: [
            Icon(icon, color: scheme.primary, size: 25),
            const SizedBox(height: 9),
            Text(title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 12)),
            const SizedBox(height: 3),
            // 副标题统一是四个字（窄屏每格只有 40dp 左右可用宽度，
            // 「Rating 构成」这种会直接变成省略号），省略号只作为兜底
            Text(subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 10)),
          ]),
        ),
      ),
    );
  }
}

class HubSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final List<Widget> children;
  final int? badgeCount;

  const HubSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.subtitle,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ===== Section 标题栏 =====
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 左侧图标徽章（圆角方形 + 主题色半透）
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (badgeCount != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$badgeCount',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        // ===== 内容卡片 =====
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius:
                BorderRadius.circular(AppDesignTokens.radiusMedium),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class HubActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;
  final bool dense;
  /// 是否已收藏（为 null 时不显示星标）
  final bool? isFavorited;
  /// 收藏切换回调
  final VoidCallback? onToggleFavorite;

  /// 是否处于进行中（刷新 / 同步）。为 true 时：
  /// trailing 的箭头换成转圈、标题置灰并禁用点击，避免重复触发。
  final bool loading;

  /// 进行中的状态文案，为空时回落到 [subtitle]。
  /// 例："正在并行刷新数据... 45%"
  final String? loadingText;

  /// 仅禁用（不显示 spinner / 不换文案）。用于「别的按钮在跑、暂时不让点」
  /// 的互斥场景。
  final bool disabled;

  /// 处于「待二次确认」状态：标题 / 图标变 error 色（醒目提示），
  /// 但点击仍生效（onTap 触发父组件的确认逻辑）。5 秒内未再点会自动复位。
  final bool awaitingConfirm;

  /// 进度计数（与 [loading] 配合使用）。非 null 且 >0 时，
  /// subtitle 改为「$current/$total」，下方追加一条 LinearProgressIndicator，
  /// 用于「曲绘索引构建」等长任务的可视化。
  final int? progressCurrent;
  final int? progressTotal;

  /// 可选：贴在 tile 下方的附加内容（例如「同步成绩」的线路切换器）。
  /// 它是独立的一行，点击不会触发本 tile 的 [onTap]。
  final Widget? footer;

  const HubActionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.iconColor,
    this.dense = false,
    this.isFavorited,
    this.onToggleFavorite,
    this.loading = false,
    this.loadingText,
    this.disabled = false,
    this.awaitingConfirm = false,
    this.progressCurrent,
    this.progressTotal,
    this.footer,
  });

  bool get _showStar => isFavorited != null && onToggleFavorite != null;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bool _isInactive = loading || disabled;
    // 二次确认态：用 error 色覆盖默认 primary tint，让按钮视觉上"危险"且醒目
    final Color activeTint =
        awaitingConfirm ? scheme.error : (iconColor ?? scheme.primary);
    // 是否进入「带进度条」模式：loading 状态下若给了 progressTotal，
    // 用 LinearProgressIndicator + 计数替代默认 spinner/loadingText。
    final bool _hasProgress =
        loading && (progressTotal ?? 0) > 0 && progressCurrent != null;
    final tile = ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: dense ? 0 : 8,
      ),
      minVerticalPadding: dense ? 4 : 8,
      visualDensity: dense ? VisualDensity.compact : VisualDensity.standard,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: activeTint.withValues(alpha: _isInactive ? 0.06 : 0.12),
          borderRadius: BorderRadius.circular(11),
        ),
        alignment: Alignment.center,
        child: Icon(icon,
            color: _isInactive
                ? activeTint.withValues(alpha: 0.5)
                : activeTint,
            size: 20),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14.5,
          color: _isInactive
              ? scheme.onSurface.withValues(alpha: 0.6)
              : (awaitingConfirm ? scheme.error : null),
        ),
      ),
      subtitle: _hasProgress
          ? Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${progressCurrent!} / $progressTotal',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: (progressCurrent! /
                              progressTotal!)
                          .clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor:
                          scheme.primary.withValues(alpha: 0.12),
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.only(top: 2),
              child: _MarqueeSubtitle(
                text: loading ? (loadingText ?? subtitle) : subtitle,
                color: loading ? scheme.primary : scheme.onSurfaceVariant,
                fontWeight: loading ? FontWeight.w600 : FontWeight.normal,
                fontSize: 12,
              ),
            ),
      trailing: loading
          ? _hasProgress
              ? const SizedBox(width: 20, height: 20) // 进度条替代 spinner
              : SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: scheme.primary,
                  ),
                )
          : _showStar
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StarToggleButton(
                      isFavorited: isFavorited!,
                      onTap: onToggleFavorite!,
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
                      size: 20,
                    ),
                  ],
                )
              : Icon(
                  Icons.chevron_right,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
                  size: 20,
                ),
      onTap: _isInactive ? null : onTap,
    );

    if (footer == null) return tile;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        tile,
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: footer!,
        ),
      ],
    );
  }
}

/// 星标按钮：仅 UI，点击行为由父组件通过 onTap 控制
class _StarToggleButton extends StatelessWidget {
  final bool isFavorited;
  final VoidCallback onTap;

  const _StarToggleButton({
    required this.isFavorited,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            isFavorited ? Icons.star : Icons.star_border,
            size: 24,
            color: isFavorited ? Colors.amber : Colors.grey,
          ),
        ),
      ),
    );
  }
}

/// 副标题：宽度够就静态显示；超长才走 marquee 自动横向滚动，
/// 短文本不会被无意义的循环动画干扰。
class _MarqueeSubtitle extends StatelessWidget {
  final String text;
  final Color color;
  final FontWeight fontWeight;
  final double fontSize;

  const _MarqueeSubtitle({
    required this.text,
    required this.color,
    required this.fontWeight,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // 量一下文本宽度，判断是否真需要滚动
        final tp = TextPainter(
          text: TextSpan(text: text, style: textStyle),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout(maxWidth: double.infinity);
        final overflows = tp.size.width > constraints.maxWidth;

        if (!overflows) {
          // 短文本：纯静态，没有任何动画
          return SizedBox(
            height: fontSize * 1.35,
            child: Text(
              text,
              style: textStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }

        // 溢出：marquee 自动横向滚动（无文本时仍会创建 controller，但不动画）
        return SizedBox(
          height: fontSize * 1.35,
          child: Marquee(
            text: text,
            style: textStyle,
            scrollAxis: Axis.horizontal,
            blankSpace: 40,
            velocity: 30,
            pauseAfterRound: const Duration(milliseconds: 1500),
            // startPadding 必须为 0：跟主标题左对齐；非 0 的话滚动起来左侧有
            // 间隙，副标题起始位置和主标题错开。
            startPadding: 0,
          ),
        );
      },
    );
  }
}

/// Hub 页面顶层 Scaffold：标题 + 副标题 + 可选 hero + 区块列表
class HubPageScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;
  final Widget? hero;

  const HubPageScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
    this.hero,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: AppDesignTokens.pagePadding,
          children: [
            // ===== 顶部标题栏 =====
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: scheme.onPrimaryContainer, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (hero != null) ...[
              const SizedBox(height: 20),
              hero!,
            ],
            const SizedBox(height: AppDesignTokens.sectionGap),
            ...children,
          ],
        ),
      ),
    );
  }
}
