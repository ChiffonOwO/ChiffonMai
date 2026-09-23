import 'package:flutter/material.dart';
import '../entity/FeatureModels.dart';
import '../utils/AppConstants.dart';

/// 功能按钮组件：纯 UI，点击行为由父组件通过 onTap 控制
class FeatureButton extends StatelessWidget {
  final ButtonItem item;
  final VoidCallback onTap;
  /// 是否已收藏（为 null 时不显示星标）
  final bool? isFavorited;
  /// 收藏切换回调
  final VoidCallback? onToggleFavorite;

  /// 可选：替换标题（「检查更新」在检测到新版本时显示为「发现新版本」）。
  final String? titleOverride;

  /// 可选：替换标题颜色。
  final Color? titleColor;

  /// 可选：替换中间那枚图标。
  ///
  /// 只换图标本身，不动它外面那层白色圆形底 —— 所以「绿色向上箭头」会落在白圆里，
  /// 而不是又套一个圆环（那会变成双环）。
  final Widget? iconOverride;

  const FeatureButton({
    super.key,
    required this.item,
    required this.onTap,
    this.isFavorited,
    this.onToggleFavorite,
    this.titleOverride,
    this.titleColor,
    this.iconOverride,
  });

  bool get _showStar => isFavorited != null && onToggleFavorite != null;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final scheme = Theme.of(context).colorScheme;

    final button = SizedBox(
      height: screenHeight * 0.12,
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: Colors.transparent,
          side: BorderSide(
            color: scheme.outlineVariant,
            width: AppConstants.borderWidth,
          ),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
          ),
          elevation: 0,
        ),
        onPressed: onTap,
        child: Column(
          children: [
            // 上半部分：主题色淡色背景，居中图标
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.15),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppConstants.borderRadiusLarge),
                    topRight: Radius.circular(AppConstants.borderRadiusLarge),
                  ),
                ),
                child: Center(
                  child: Container(
                    width: screenWidth * 0.09,
                    height: screenWidth * 0.09,
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: iconOverride ??
                          Icon(
                            item.icon,
                            color: scheme.primary,
                            size: screenWidth * 0.05,
                          ),
                    ),
                  ),
                ),
              ),
            ),
            // 下半部分：白色背景，居中标题和副标题
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(AppConstants.borderRadiusLarge),
                    bottomRight: Radius.circular(AppConstants.borderRadiusLarge),
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        titleOverride ?? item.title,
                        style: TextStyle(
                          color: titleColor ?? scheme.onSurface,
                          fontSize: screenWidth * 0.035,
                          fontWeight: FontWeight.bold,
                          fontStyle: FontStyle.normal,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: screenHeight * 0.005),
                      Text(
                        item.subtitle,
                        style: TextStyle(
                          color: scheme.onSurface.withValues(alpha: 0.8),
                          fontSize: screenWidth * 0.025,
                          fontWeight: FontWeight.w300,
                        ),
                        textAlign: TextAlign.center,
                        softWrap: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // 无星标模式：直接返回按钮
    if (!_showStar) return button;

    // 有星标模式：叠加星标按钮
    return SizedBox(
      height: screenHeight * 0.12,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: button),
          Positioned(
            top: 2,
            right: 2,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: onToggleFavorite,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isFavorited!
                        ? Colors.amber.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isFavorited! ? Icons.star : Icons.star_border,
                    size: 24,
                    color: isFavorited! ? Colors.amber : Colors.grey,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
