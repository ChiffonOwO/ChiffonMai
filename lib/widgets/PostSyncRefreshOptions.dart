import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constant/CacheKeyConstant.dart';
import '../service/AccountStore.dart';
import '../utils/SecureCredentialStore.dart';
import 'AdvancedRefreshDataDialog.dart';
import 'RefreshDataDialog.dart' show RefreshDataRequest, RefreshDataSource;

/// 同步表单中的「顺手刷新数据」选项。
/// 勾选后直接展开与高级刷新对话框相同的完整缓存选择内容，避免两套设置逐渐不一致。
class PostSyncRefreshOptions extends StatefulWidget {
  final RefreshDataSource source;

  const PostSyncRefreshOptions({
    super.key,
    required this.source,
  });

  @override
  State<PostSyncRefreshOptions> createState() => PostSyncRefreshOptionsState();
}

class PostSyncRefreshOptionsState extends State<PostSyncRefreshOptions> {
  bool enabled = false;
  late Future<_RefreshCredentials> _credentials;
  final _panelKey = GlobalKey<AdvancedRefreshDataPanelState>();

  @override
  void initState() {
    super.initState();
    _credentials = _loadCredentials();
  }

  Future<_RefreshCredentials> _loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final jwt = await SecureCredentialStore.read(
            CacheKeyConstant.probeDivingFishToken) ??
        '';
    final bindQQ =
        prefs.getString(CacheKeyConstant.probeDivingFishBindQQ) ?? '';
    final metas = await AccountStore.loadAll();
    return _RefreshCredentials(
      hasDivingFishLogin: jwt.isNotEmpty,
      bindQQ: bindQQ,
      awmcQQ: metas[RefreshDataSource.awmc.key]?.id ?? '',
    );
  }

  Future<RefreshDataRequest?> collectRequest() async {
    if (!enabled) return null;
    return _panelKey.currentState?.collectRequest();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('同步完成后刷新数据'),
          value: enabled,
          onChanged: (value) => setState(() => enabled = value ?? false),
        ),
        if (enabled)
          FutureBuilder<_RefreshCredentials>(
            future: _credentials,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final c = snapshot.data!;
              return AdvancedRefreshDataPanel(
                key: _panelKey,
                embedded: true,
                initialSource: widget.source,
                hasDivingFishLogin: c.hasDivingFishLogin,
                bindQQ: c.bindQQ,
                awmcQQ: c.awmcQQ,
              );
            },
          ),
      ],
    );
  }
}

class _RefreshCredentials {
  final bool hasDivingFishLogin;
  final String bindQQ;
  final String awmcQQ;

  const _RefreshCredentials({
    required this.hasDivingFishLogin,
    required this.bindQQ,
    required this.awmcQQ,
  });
}
