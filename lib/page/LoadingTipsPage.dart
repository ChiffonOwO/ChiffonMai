import 'package:flutter/material.dart';
import '../service/LoadingTipsStore.dart';
import '../utils/CommonWidgetUtil.dart';
import '../widgets/PageTopBar.dart';
import '../widgets/AnimatedChoiceBar.dart';
import '../widgets/EmptyState.dart';

class LoadingTipsPage extends StatefulWidget {
  const LoadingTipsPage({super.key});
  @override
  State<LoadingTipsPage> createState() => _LoadingTipsPageState();
}

class _LoadingTipsPageState extends State<LoadingTipsPage> {
  final _store = LoadingTipsStore.instance;
  bool _busy = true;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _store.addListener(_changed);
    _load();
  }

  Future<void> _load() async {
    await _store.ensureLoaded();
    if (mounted) setState(() => _busy = false);
  }

  @override
  void dispose() {
    _store.removeListener(_changed);
    super.dispose();
  }

  void _changed() => mounted ? setState(() {}) : null;

  Future<void> _addTip({required bool cloud}) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _LoadingTipInputDialog(
        title: cloud ? '上传语录到云端' : '本地新增语录',
      ),
    );
    final value = text?.trim() ?? '';
    if (value.isEmpty || !mounted) return;
    if (cloud) {
      final id = await _store.submitCloudTip(value);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(id == null ? '上传失败，请稍后重试' : '已提交审核（$id），审核通过后才会展示')));
    } else {
      await _store.addLocalTip(value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('本地语录添加成功')),
        );
      }
    }
  }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    final ok = await _store.refresh();
    if (mounted) {
      setState(() => _busy = false);
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('获取加载语录失败，已保留本地缓存')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tips = _store.catalogue;
    final localTips = _store.localTips;
    return DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // 图片首帧尚未解码时先铺主题表面，避免透明 Scaffold 露出黑底闪烁。
              ColoredBox(color: Theme.of(context).colorScheme.surface),
              CommonWidgetUtil.buildCommonBgWidget(),
              CommonWidgetUtil.buildCommonChiffonBgWidget(context),
              Column(
                children: [
                  PageTopBar(title: '加载语录管理', actions: [
                    IconButton(
                        onPressed: _busy ? null : _refresh,
                        icon: const Icon(Icons.refresh),
                        tooltip: '刷新语录'),
                  ]),
                  TabBar(
                    tabs: const [Tab(text: '本地语录'), Tab(text: '云端语录')],
                    onTap: (index) => setState(() => _tab = index),
                  ),
                  Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                      child: Wrap(spacing: 8, runSpacing: 4, children: [
                        OutlinedButton.icon(
                            onPressed: () => _addTip(cloud: false),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('本地新增语录')),
                        FilledButton.tonalIcon(
                            onPressed: () => _addTip(cloud: true),
                            icon: const Icon(Icons.cloud_upload_outlined,
                                size: 18),
                            label: const Text('上传到云端')),
                      ])),
                  if (_store.totalCount > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                      child: Row(children: [
                        Expanded(
                            child: Text(
                                '已启用 ${_store.enabledCount} / ${_store.totalCount} 条')),
                        TextButton(
                            onPressed: () => _store.setAllEnabled(true),
                            child: const Text('全选')),
                        TextButton(
                            onPressed: () => _store.setAllEnabled(false),
                            child: const Text('全不选')),
                      ]),
                    ),
                  Expanded(
                    child: _busy && tips.isEmpty && _store.localTips.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : FadeContent(
                            child: (_tab == 0 ? localTips : tips).isEmpty
                                ? EmptyState(key: ValueKey('empty-$_tab'))
                                : ListView(
                                    key: ValueKey(_tab),
                                    padding: EdgeInsets.zero,
                                    children: [
                                      if (_tab == 0 &&
                                          localTips.isNotEmpty) ...[
                                        const Padding(
                                            padding: EdgeInsets.fromLTRB(
                                                16, 0, 16, 4),
                                            child: Text('本地新增语录',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.w600))),
                                        for (final tip in localTips)
                                          _tipTile(tip),
                                      ],
                                      if (_tab == 1 && tips.isNotEmpty) ...[
                                        const Padding(
                                            padding: EdgeInsets.fromLTRB(
                                                16, 0, 16, 4),
                                            child: Text('云端语录',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.w600))),
                                        for (final tip in tips) _tipTile(tip),
                                      ],
                                    ],
                                  )),
                  ),
                ],
              ),
            ],
          ),
        ));
  }

  Widget _tipTile(LoadingTip tip) => CheckboxListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        value: !_store.disabledIds.contains(tip.id),
        title: Text(tip.text),
        secondary: tip.id.startsWith('local_')
            ? IconButton(
                tooltip: '删除本地语录',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _store.removeLocalTip(tip.id),
              )
            : null,
        onChanged: (value) => _store.setEnabled(tip.id, value ?? false),
      );
}

/// 输入框控制器必须归属于对话框自身的 State。
///
/// 对话框取消时，路由仍可能在执行退出动画；在 showDialog 返回后立刻释放
/// 外部 controller 会让 TextField 仍持有它的依赖，触发 `_dependents.isEmpty`。
class _LoadingTipInputDialog extends StatefulWidget {
  final String title;

  const _LoadingTipInputDialog({required this.title});

  @override
  State<_LoadingTipInputDialog> createState() => _LoadingTipInputDialogState();
}

class _LoadingTipInputDialogState extends State<_LoadingTipInputDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: TextField(
          controller: _controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(hintText: '输入加载语录'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_controller.text),
            child: const Text('保存'),
          ),
        ],
      );
}
