import 'package:flutter/material.dart';

import '../utils/NavigationPreferences.dart';
import '../utils/ThemeManager.dart';

/// 首页主题弹窗与「主题与交互偏好」共用的控件和状态，所有修改写入同一份缓存。
class ThemePreferenceControls extends StatefulWidget {
  const ThemePreferenceControls({super.key});

  @override
  State<ThemePreferenceControls> createState() =>
      _ThemePreferenceControlsState();
}

class _ThemePreferenceControlsState extends State<ThemePreferenceControls> {
  @override
  void initState() {
    super.initState();
    NavigationPreferences.instance.load();
  }

  @override
  Widget build(BuildContext context) {
    final manager = ThemeManager();
    final navigation = NavigationPreferences.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([
        manager.notifier,
        manager.lightOverlayNotifier,
        manager.pureBlackNotifier,
        navigation,
      ]),
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final dark = Theme.of(context).brightness == Brightness.dark;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Expanded(child: Text('背景透明度')),
                    Text('${(manager.lightOverlayOpacity * 100).round()}%',
                        style: TextStyle(color: scheme.primary)),
                  ]),
                  Slider(
                    value: manager.lightOverlayOpacity,
                    divisions: 20,
                    label: '${(manager.lightOverlayOpacity * 100).round()}%',
                    onChanged: manager.setLightOverlayOpacity,
                  ),
                  Text(
                    dark ? '数值越高背景越暗，0% 为原始背景图' : '数值越高背景越淡，0% 为原始背景图',
                    style:
                        TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const Divider(),
            for (final option in const [
              (ThemeMode.light, Icons.light_mode, '浅色模式', '始终使用浅色主题'),
              (ThemeMode.dark, Icons.dark_mode, '深色模式', '始终使用深色主题'),
              (ThemeMode.system, Icons.settings_suggest, '跟随系统', '根据系统设置自动切换'),
            ])
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(option.$2,
                    color: manager.themeMode == option.$1
                        ? scheme.primary
                        : scheme.onSurface),
                title: Text(option.$3),
                subtitle: Text(option.$4),
                selected: manager.themeMode == option.$1,
                trailing: manager.themeMode == option.$1
                    ? Icon(Icons.check, color: scheme.primary)
                    : null,
                onTap: () => manager.setThemeMode(option.$1),
              ),
            if (dark)
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('纯黑背景'),
                subtitle: const Text('使用真正的纯黑背景，隐藏背景图'),
                value: manager.pureBlackEnabled,
                onChanged: manager.setPureBlackEnabled,
              ),
            const Divider(),
            Text('导航体验',
                style: TextStyle(
                    color: scheme.onSurface, fontWeight: FontWeight.w600)),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: navigation.transitionEnabled,
              onChanged: navigation.setTransitionEnabled,
              title: const Text('导航栏切换动画'),
              subtitle: const Text('切换主界面时使用淡入滑动过渡，并淡化图标状态'),
              secondary: Icon(Icons.animation_outlined, color: scheme.primary),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: navigation.swipeEnabled,
              onChanged: navigation.setSwipeEnabled,
              title: const Text('左右滑动切换主界面'),
              subtitle: const Text('在主界面内容区域左右滑动即可切换底部导航项'),
              secondary: Icon(Icons.swipe_outlined, color: scheme.primary),
            ),
          ],
        );
      },
    );
  }
}
