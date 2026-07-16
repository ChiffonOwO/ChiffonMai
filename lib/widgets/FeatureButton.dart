import 'package:flutter/material.dart';
import '../entity/FeatureModels.dart';
import '../utils/AppTheme.dart';
import '../utils/AppConstants.dart';

/// 功能按钮组件：纯 UI，点击行为由父组件通过 onTap 控制
class FeatureButton extends StatelessWidget {
  final ButtonItem item;
  final VoidCallback onTap;

  const FeatureButton({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final brightness = Theme.of(context).brightness;

    return SizedBox(
      height: screenHeight * 0.12,
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: Colors.transparent,
          side: BorderSide(
            color: AppColors.buttonBorder(brightness),
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
            // 上半部分：原背景色，居中图标
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.buttonBackground(brightness),
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
                      color: Theme.of(context).colorScheme.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        item.icon,
                        color: Theme.of(context).colorScheme.onSurface,
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
                  color: Theme.of(context).colorScheme.surface,
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
                        item.title,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
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
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
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
  }
}
