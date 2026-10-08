import 'AnimatedChoiceBar.dart';
import 'package:flutter/material.dart';

import '../service/SyncRouteStore.dart';

/// 「同步成绩」的线路切换器：**线路1 AWMC 网关**（机台二维码 + 用户平台凭据，
/// 开发者令牌由服务端代理注入）/ **线路2 maimai Score Hub**（原有流程，走 maimai.bakapiano.com）。
///
/// 贴在对应的 HubActionTile 下方（`HubActionTile.footer`）：
/// 它自己是一行独立控件，点它**不会**触发 tile 的 onTap（不会误开始同步），
/// 选择结果由调用方通过 [onChanged] 持久化（见 [SyncRouteStore]）。
class SyncRouteSwitcher extends StatelessWidget {
  /// 当前线路：1 = 线路1 AWMC 网关，0 = 线路2 maimai Score Hub。
  /// （整数值沿用历史命名不换，只调换了显示位置：AWMC 放线路1。
  /// 老 prefs 里的值语义不变，详见 [SyncRouteStore] 顶部注释。）
  final int value;

  final ValueChanged<int> onChanged;

  /// 同步进行中时置 false：只禁用切换，不隐藏。
  final bool enabled;

  const SyncRouteSwitcher({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.alt_route, size: 15, color: scheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          '线路',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(width: 8),
        SizedBox(
            width: 112,
            child: AnimatedChoiceBar<int>(
              compact: true,
              values: const [
                SyncRouteStore.routeAwmc,
                SyncRouteStore.routeScoreHub
              ],
              value: value,
              label: (route) =>
                  route == SyncRouteStore.routeAwmc ? '线路1' : '线路2',
              onChanged: enabled ? onChanged : null,
            )),
        const SizedBox(width: 8),
        Expanded(
          child: Transform.translate(
            offset: const Offset(-6, 0),
            child: FadeContent(
              child: Text(
                SyncRouteStore.routeName(value),
                key: ValueKey(value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
