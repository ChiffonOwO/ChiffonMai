import 'package:flutter/material.dart';

import '../service/SyncRouteStore.dart';

/// 「同步成绩」的线路切换器：**线路1 maimai Score Hub**（原有 scorehub 流程） /
/// **线路2 AWMC 网关**（机台二维码 + `gw_` 令牌直连 api.wmc.pub）。
///
/// 贴在对应的 HubActionTile 下方（`HubActionTile.footer`）：
/// 它自己是一行独立控件，点它**不会**触发 tile 的 onTap（不会误开始同步），
/// 选择结果由调用方通过 [onChanged] 持久化（见 [SyncRouteStore]）。
class SyncRouteSwitcher extends StatelessWidget {
  /// 当前线路：0 = 线路1 maimai Score Hub，1 = 线路2 AWMC 网关。
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
        SegmentedButton<int>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            textStyle: const TextStyle(fontSize: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          segments: const [
            ButtonSegment<int>(value: SyncRouteStore.routeScoreHub, label: Text('线路1')),
            ButtonSegment<int>(value: SyncRouteStore.routeAwmc, label: Text('线路2')),
          ],
          selected: {value},
          onSelectionChanged:
              enabled ? (selection) => onChanged(selection.first) : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            SyncRouteStore.routeName(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}
