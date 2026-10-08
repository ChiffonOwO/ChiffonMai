import 'AnimatedChoiceBar.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/ApiUrls.dart';
import '../constant/CacheKeyConstant.dart';
import '../service/AccountStore.dart';
import '../service/SyncStatsService.dart';
import '../service/SyncRouteStore.dart';
import '../utils/SyncRouteNotifier.dart';
import '../utils/ExternalLaunchUtil.dart';
import '../utils/SecureCredentialStore.dart';
import 'ErrorMessageDialog.dart';
import 'QrQuickFillButtons.dart';

/// 已确认具备凭据的同步目标；顺序由执行器固定为水鱼 → 落雪 → AWMC NET。
class MultiScoreSyncInput {
  final String qrCode;
  final Set<SyncPlatform> platforms;
  final Map<SyncPlatform, int> routes;

  MultiScoreSyncInput({
    required this.qrCode,
    required Set<SyncPlatform> platforms,
    Map<SyncPlatform, int> routes = const {},
  })  : platforms = Set.unmodifiable(platforms),
        routes = Map.unmodifiable(routes);

  /// 旧调用未传线路时沿用原来的线路2行为。
  int routeOf(SyncPlatform platform) =>
      routes[platform] ?? SyncRouteStore.routeScoreHub;
}

Future<MultiScoreSyncInput?> showMultiScoreSyncInputDialog(
        BuildContext context) =>
    showDialog<MultiScoreSyncInput>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const MultiScoreSyncDialog(),
    );

/// 输入和保存凭据在对话框内完成，网络同步由调用方在弹窗关闭后串行执行。
class MultiScoreSyncDialog extends StatefulWidget {
  const MultiScoreSyncDialog({super.key});

  @override
  State<MultiScoreSyncDialog> createState() => _MultiScoreSyncDialogState();
}

class _MultiScoreSyncDialogState extends State<MultiScoreSyncDialog> {
  static const _keys = {
    SyncPlatform.divingFish: CacheKeyConstant.probeDivingFishImportToken,
    SyncPlatform.luoXue: CacheKeyConstant.probeLxnsImportToken,
    SyncPlatform.awmc: CacheKeyConstant.awmcNetImportToken,
  };
  static final _qqPattern = RegExp(r'^\d{5,12}$');
  final _qrController = TextEditingController();
  final _qqController = TextEditingController();
  final _tokenControllers = {
    for (final platform in SyncPlatform.values)
      platform: TextEditingController(),
  };
  final _tokens = <SyncPlatform, String>{};
  final _selected = <SyncPlatform>{};
  final _expanded = <SyncPlatform>{};
  final _errors = <SyncPlatform, String>{};
  final _routes = <SyncPlatform, int>{
    SyncPlatform.divingFish: SyncRouteStore.routeScoreHub,
    SyncPlatform.luoXue: SyncRouteStore.routeScoreHub,
  };
  String _qq = '';
  String? _qrError;
  String? _selectionError;
  String? _loadError;
  bool _loading = true;
  SyncPlatform? _saving;

  @override
  void initState() {
    super.initState();
    _loadCredentials();
  }

  @override
  void dispose() {
    _qrController.dispose();
    _qqController.dispose();
    for (final controller in _tokenControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _ready(SyncPlatform platform) =>
      (_tokens[platform]?.isNotEmpty ?? false) &&
      (platform != SyncPlatform.awmc || _qqPattern.hasMatch(_qq));

  Future<void> _loadCredentials() async {
    try {
      final tokens = <SyncPlatform, String>{};
      for (final platform in SyncPlatform.values) {
        tokens[platform] =
            (await SecureCredentialStore.read(_keys[platform]!) ?? '').trim();
      }
      final accounts = await AccountStore.loadAll();
      final prefs = await SharedPreferences.getInstance();
      final routes = {
        SyncPlatform.divingFish: await SyncRouteStore.load(isDivingFish: true),
        SyncPlatform.luoXue: await SyncRouteStore.load(isDivingFish: false),
      };
      final marker = prefs.getString(CacheKeyConstant.awmcUserId) ?? '';
      // 只读取 AWMC 自己的 QQ，不能用活动槽 cachedQQ（可能属于水鱼或落雪）。
      final qqCandidates = [
        accounts['awmc']?.id ?? '',
        marker.startsWith('awmc:') ? marker.substring(5) : '',
        prefs.getString(CacheKeyConstant.awmcNetSyncQQ) ?? '',
      ];
      if (!mounted) return;
      setState(() {
        _tokens.addAll(tokens);
        _routes.addAll(routes);
        _qq = qqCandidates.map((value) => value.trim()).firstWhere(
              _qqPattern.hasMatch,
              orElse: () => '',
            );
        _selected.addAll(SyncPlatform.values.where(_ready));
        _loading = false;
        _loadError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = '无法读取已保存的凭据，请重试。';
      });
    }
  }

  Future<void> _saveCredential(SyncPlatform platform) async {
    if (_saving != null) return;
    final needsToken = _tokens[platform]?.isNotEmpty != true;
    final token = needsToken
        ? _tokenControllers[platform]!.text.trim()
        : _tokens[platform]!;
    final needsQQ = platform == SyncPlatform.awmc && !_qqPattern.hasMatch(_qq);
    final qq = needsQQ ? _qqController.text.trim() : _qq;
    if (token.isEmpty || (needsQQ && !_qqPattern.hasMatch(qq))) {
      setState(() => _errors[platform] = token.isEmpty
          ? '请填写${platform == SyncPlatform.luoXue ? '个人 API 密钥' : 'ImportToken'}'
          : '请填写 5～12 位 QQ 号');
      return;
    }
    setState(() {
      _saving = platform;
      _errors.remove(platform);
    });
    try {
      if (needsToken)
        await SecureCredentialStore.write(_keys[platform]!, token);
      if (needsQQ) {
        final prefs = await SharedPreferences.getInstance();
        if (!await prefs.setString(CacheKeyConstant.awmcNetSyncQQ, qq)) {
          throw StateError('保存 QQ 失败');
        }
      }
      if (!mounted) return;
      setState(() {
        _tokens[platform] = token;
        if (needsQQ) _qq = qq;
        _selected.add(platform);
        _expanded.remove(platform);
        _selectionError = null;
        _tokenControllers[platform]!.clear();
        if (needsQQ) _qqController.clear();
      });
    } catch (_) {
      // 存储插件的异常可能包含传入参数，不向 UI 回显任何密钥。
      if (mounted) {
        await showErrorMessageDialog(context, message: '凭据保存失败，请重试。');
      }
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  Future<void> _openSource(SyncPlatform platform) async {
    final url = switch (platform) {
      SyncPlatform.divingFish => ApiUrls.DivingFishProberHomeUrl,
      SyncPlatform.luoXue => ApiUrls.LuoXueBaseUrl,
      SyncPlatform.awmc => ApiUrls.AwmcNetSettingsUrl,
    };
    try {
      if (await ExternalLaunchUtil.open(Uri.parse(url))) return;
    } catch (_) {}
    if (mounted) {
      await showErrorMessageDialog(context, message: '无法打开网站，请在浏览器中访问：$url');
    }
  }

  void _submit() {
    final qr = _qrController.text.trim();
    final targets = _selected.where(_ready).toSet();
    setState(() {
      _qrError = qr.startsWith('SGWCMAID') ? null : '请填写 SGWCMAID 开头的机台登入二维码';
      _selectionError = targets.isEmpty ? '请至少选择一个已具备凭据的数据源' : null;
    });
    if (_qrError != null || _selectionError != null) return;
    Navigator.pop(
        context,
        MultiScoreSyncInput(
          qrCode: qr,
          platforms: targets,
          routes: _routes,
        ));
  }

  Widget _buildRouteSelector(SyncPlatform platform) {
    final scheme = Theme.of(context).colorScheme;
    final route = _routes[platform]!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedChoiceBar<int>(
            values: const [
              SyncRouteStore.routeAwmc,
              SyncRouteStore.routeScoreHub
            ],
            value: route,
            label: (value) => value == SyncRouteStore.routeAwmc ? '线路1' : '线路2',
            onChanged: _saving == null
                ? (next) {
                    setState(() => _routes[platform] = next);
                    unawaited(
                        SyncRouteNotifier.instance.setRoute(platform, next));
                  }
                : null,
          ),
          const SizedBox(height: 6),
          FadeContent(
              child: Text(
            key: ValueKey(route),
            '当前：${route == SyncRouteStore.routeAwmc ? '线路1' : '线路2'} · ${SyncRouteStore.routeName(route)}',
            style: TextStyle(fontSize: 12, color: scheme.primary),
          )),
        ],
      ),
    );
  }

  Widget _status(String label, bool exists) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(children: [
          Icon(exists ? Icons.check_circle : Icons.error_outline,
              size: 16,
              color: exists
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
              semanticLabel: exists ? '已存在' : '未填写'),
          const SizedBox(width: 6),
          Expanded(
              child: Text('$label：${exists ? '已存在' : '未填写'}',
                  style: const TextStyle(fontSize: 13))),
        ]),
      );

  Widget _buildSource(SyncPlatform platform) {
    final scheme = Theme.of(context).colorScheme;
    final hasToken = _tokens[platform]?.isNotEmpty ?? false;
    final ready = _ready(platform);
    final tokenLabel =
        platform == SyncPlatform.luoXue ? '个人 API 密钥' : 'ImportToken';
    final saving = _saving == platform;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CheckboxListTile(
          value: _selected.contains(platform),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          title: Text(platform.label,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          subtitle:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _status(tokenLabel, hasToken),
            if (platform == SyncPlatform.awmc)
              _status('QQ 号', _qqPattern.hasMatch(_qq)),
          ]),
          onChanged: ready && _saving == null
              ? (value) => setState(() {
                    value == true
                        ? _selected.add(platform)
                        : _selected.remove(platform);
                    _selectionError = null;
                  })
              : null,
        ),
        if (platform != SyncPlatform.awmc) _buildRouteSelector(platform),
        if (!ready)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('补齐凭据后即可勾选',
                  style:
                      TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              TextButton.icon(
                onPressed: _saving == null
                    ? () => setState(() => _expanded.contains(platform)
                        ? _expanded.remove(platform)
                        : _expanded.add(platform))
                    : null,
                icon: Icon(
                    _expanded.contains(platform)
                        ? Icons.expand_less
                        : Icons.edit_outlined,
                    size: 18),
                label: Text(_expanded.contains(platform) ? '收起' : '填写缺少的凭据'),
              ),
              if (_expanded.contains(platform)) ...[
                Text(
                    switch (platform) {
                      SyncPlatform.divingFish =>
                        '在水鱼官网登录后获取 ImportToken；通过 App 的「登录水鱼」保存过的凭据也会自动识别。',
                      SyncPlatform.luoXue => '登录落雪咖啡屋，在账号设置中获取个人 API 密钥。',
                      SyncPlatform.awmc =>
                        '填写 AWMC NET 账号绑定的 QQ；导入还需在官网设置页底部生成的 Import-Token。',
                    },
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant)),
                TextButton(
                    onPressed: () => _openSource(platform),
                    child: const Text('打开官网')),
                if (platform == SyncPlatform.awmc &&
                    !_qqPattern.hasMatch(_qq)) ...[
                  TextField(
                    key: const ValueKey('multi-sync-qq'),
                    controller: _qqController,
                    enabled: _saving == null,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                        labelText: 'AWMC NET QQ 号',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                ],
                if (!hasToken)
                  TextField(
                    key: ValueKey('multi-sync-token-${platform.key}'),
                    controller: _tokenControllers[platform],
                    enabled: _saving == null,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                        labelText: tokenLabel,
                        border: const OutlineInputBorder()),
                  ),
                if (_errors[platform] != null)
                  Text(_errors[platform]!,
                      style: TextStyle(color: scheme.error)),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed:
                      _saving == null ? () => _saveCredential(platform) : null,
                  child: Text(saving ? '正在保存…' : '保存并选中'),
                ),
              ],
            ]),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.devices_other_outlined, size: 22),
          SizedBox(width: 8),
          Expanded(child: Text('同步成绩到多端')),
        ]),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('输入一次机台二维码，选择要同步的数据源。'),
                  const SizedBox(height: 12),
                  QrQuickFillButtons(
                      controller: _qrController, enabled: _saving == null),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('multi-sync-qr'),
                    controller: _qrController,
                    enabled: _saving == null,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: '舞萌DX | 中二节奏 登入二维码（SGWCMAID...）',
                      errorText: _qrError,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('同步数据源',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const Text('凭据存在的端默认勾选；水鱼 → 落雪 → AWMC NET 依次同步。',
                      style: TextStyle(fontSize: 12)),
                  if (_loading)
                    const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()))
                  else if (_loadError != null) ...[
                    Text(_loadError!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                    TextButton(
                        onPressed: () {
                          setState(() => _loading = true);
                          _loadCredentials();
                        },
                        child: const Text('重新读取凭据')),
                  ] else
                    ...SyncPlatform.values.map(_buildSource),
                  if (_selectionError != null)
                    Text(_selectionError!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  if (_selected.contains(SyncPlatform.awmc)) ...[
                    const SizedBox(height: 12),
                    Text('AWMC NET 将以机台成绩为准覆盖已有对应成绩。',
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ],
                ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: _saving == null ? () => Navigator.pop(context) : null,
              child: const Text('取消')),
          FilledButton(
              onPressed: _loading || _loadError != null || _saving != null
                  ? null
                  : _submit,
              child: Text('开始同步（${_selected.length}）')),
        ],
      );
}
