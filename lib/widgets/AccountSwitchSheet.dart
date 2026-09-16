import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../service/AccountStore.dart';
import '../service/AccountSwitchService.dart';
import '../utils/CurrentDataSourceNotifier.dart';
import 'FishIcon.dart';

/// 弹出「切换账号」底部面板。
///
/// 两个数据源（水鱼 / 落雪）各占一行；点击即用**缓存**切换数据源与玩家信息，
/// 不联网。目标账号没有缓存时提示并回调 [onNeedRefresh] 引导去刷新。
Future<void> showAccountSwitchSheet(
  BuildContext context, {
  required Future<void> Function(RefreshDataSource source) onNeedRefresh,
}) async {
  final metas = await AccountStore.loadAll();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => _AccountSwitchSheet(
      initialMetas: metas,
      onNeedRefresh: onNeedRefresh,
    ),
  );
}

class _AccountSwitchSheet extends StatefulWidget {
  final Map<String, AccountMeta> initialMetas;
  final Future<void> Function(RefreshDataSource source) onNeedRefresh;

  const _AccountSwitchSheet({
    required this.initialMetas,
    required this.onNeedRefresh,
  });

  @override
  State<_AccountSwitchSheet> createState() => _AccountSwitchSheetState();
}

class _AccountSwitchSheetState extends State<_AccountSwitchSheet> {
  late final Map<String, AccountMeta> _metas = widget.initialMetas;
  bool _busy = false;

  /// 正在切换到哪个源（用于在对应行上显示转圈）
  RefreshDataSource? _switchingTo;

  /// 正在清除哪个源的数据
  RefreshDataSource? _clearing;

  /// 清除某个账号的缓存数据（保留登录状态）
  Future<void> _onClearAccount(RefreshDataSource source) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('清除${source.displayName}账号数据'),
        content: Text('将删除 ${source.displayName} 账号的本地缓存'
            '（成绩、Best50、玩家信息、推荐结果等），不影响登录状态。\n\n'
            '下次使用该账号需要重新刷新数据，确定清除？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text('清除',
                style: TextStyle(color: Theme.of(dialogCtx).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _clearing = source;
    });
    await AccountSwitchService.clearAccountData(source);
    final loaded = await AccountStore.loadAll();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _clearing = null;
      _metas
        ..clear()
        ..addAll(loaded);
    });
    Fluttertoast.showToast(msg: '已清除${source.displayName}账号数据');
  }

  Future<void> _onTapAccount(RefreshDataSource source) async {
    if (_busy) return;
    final current = CurrentDataSourceNotifier.instance.value;
    if (source == current) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    setState(() {
      _busy = true;
      _switchingTo = source;
    });
    final outcome = await AccountSwitchService.switchTo(source);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _switchingTo = null;
    });

    switch (outcome) {
      case SwitchOutcome.switched:
        Navigator.of(context).pop();
        Fluttertoast.showToast(msg: '已切换到${source.displayName}账号');
        break;
      case SwitchOutcome.sameSource:
        Navigator.of(context).pop();
        break;
      case SwitchOutcome.busy:
        Fluttertoast.showToast(msg: '正在切换，请稍候');
        break;
      case SwitchOutcome.noCache:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: const Text('该账号暂无缓存'),
            content: Text('${source.displayName}账号还没有缓存过数据，去刷新数据？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(true),
                child: const Text('去刷新'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          if (!mounted) return;
          Navigator.of(context).pop();
          await widget.onNeedRefresh(source);
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('切换账号',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface)),
            const SizedBox(height: 4),
            // 切换中：在标题下方显示状态，避免点完没有任何反馈
            if (_busy)
              Row(children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '正在切换到${_switchingTo?.displayName ?? ''}账号…',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.primary),
                ),
              ])
            else
              Text('点击账号即可切换数据源与玩家信息（使用本地缓存，不联网）',
                  style:
                      TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            _buildAccountTile(RefreshDataSource.shuiyu),
            const SizedBox(height: 8),
            _buildAccountTile(RefreshDataSource.luoxue),
            const SizedBox(height: 12),
            Text('刷新数据可更新当前账号；两个账号的登录状态相互独立。',
                style:
                    TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountTile(RefreshDataSource source) {
    final scheme = Theme.of(context).colorScheme;
    final bool isCurrent = CurrentDataSourceNotifier.instance.value == source;
    final meta = _metas[source.key];
    final bool hasData = meta?.hasData ?? false;
    final String nickname =
        (meta?.nickname.isNotEmpty ?? false) ? meta!.nickname : '${source.displayName}账号';
    final String idLine = (meta?.id.isNotEmpty ?? false)
        ? (source == RefreshDataSource.shuiyu
            ? 'QQ ${meta!.id}'
            : 'ID ${meta!.id}')
        : '未绑定';
    final int ra = meta?.best50TotalRA ?? 0;
    final bool isSwitching = _switchingTo == source;
    final bool isClearing = _clearing == source;

    final tile = InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _onTapAccount(source),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrent ? scheme.primary : scheme.outlineVariant,
            width: isCurrent ? 1.6 : 1,
          ),
          color: isCurrent
              ? scheme.primary.withValues(alpha: 0.06)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            if (source == RefreshDataSource.shuiyu)
              FishIcon(
                size: 24,
                color: isCurrent ? scheme.primary : scheme.onSurfaceVariant,
              )
            else
              Icon(
                Icons.ac_unit_outlined,
                color: isCurrent ? scheme.primary : scheme.onSurfaceVariant,
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface)),
                  const SizedBox(height: 2),
                  Text(
                    ra > 0 ? '$idLine · RA $ra' : idLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isSwitching || isClearing)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.primary,
                ),
              )
            else ...[
              if (isCurrent)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('当前',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: scheme.primary)),
                )
              else if (!hasData)
                Text('暂无缓存',
                    style: TextStyle(
                        fontSize: 11, color: scheme.onSurfaceVariant))
              else
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              // 只有缓存过数据才显示「清除」入口
              if (hasData)
                IconButton(
                  onPressed: () => _onClearAccount(source),
                  tooltip: '清除${source.displayName}账号数据',
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  icon: Icon(
                    Icons.cleaning_services_outlined,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ],
        ),
      ),
    );

    // 切换/清除中把其他行压暗，突出正在处理的那一行
    if (_busy && !isSwitching && !isClearing) {
      return Opacity(opacity: 0.45, child: tile);
    }
    return tile;
  }
}
