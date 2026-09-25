import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constant/CacheKeyConstant.dart';
import '../manager/DivingFishProbeManager.dart';
import '../widgets/ThemeAwareBackground.dart';
import '../utils/UserProfileNotifier.dart';
import 'HubComponents.dart';

class AccountSyncPage extends StatefulWidget {
  const AccountSyncPage({super.key});

  @override
  State<AccountSyncPage> createState() => _AccountSyncPageState();
}

class _AccountSyncPageState extends State<AccountSyncPage> {
  bool _loggedIn = false;
  String _cachedQQ = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAccountState();
  }

  Future<void> _loadAccountState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _loggedIn = (prefs.getString(CacheKeyConstant.probeDivingFishToken) ?? '')
          .isNotEmpty;
      _cachedQQ = prefs.getString(CacheKeyConstant.probeDivingFishBindQQ) ??
          '';
      _loading = false;
    });
  }

  Future<void> _login() async {
    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (dialogContext) => _LoginDialog(
        onSubmit: (username, password) => Navigator.pop(dialogContext, {
          'username': username,
          'password': password,
        }),
      ),
    );

    if (result == null ||
        result['username']!.isEmpty ||
        result['password']!.isEmpty) {
      return;
    }
    if (!mounted) return;
    setState(() => _loading = true);
    final response = await DivingFishProbeManager().loginDivingFishDirect(
      result['username']!,
      result['password']!,
    );
    if (!mounted) return;
    if (response == null) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('登录失败，请检查用户名和密码')),
      );
      return;
    }
    await _loadAccountState();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('水鱼账号登录成功')),
      );
    }
  }

  Future<void> _logout() async {
    try {
      await UserProfileNotifier.clearShuiyuAccountCache();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('登出失败：$e')));
      return;
    }
    await _loadAccountState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ThemeAwareBackground(
        child: HubPageScaffold(
          title: '账号与同步',
          subtitle: '管理账号、授权状态与成绩同步',
          icon: Icons.manage_accounts,
          children: [
            HubSection(
              title: '水鱼账号',
              subtitle: _loading ? '正在读取账号状态' : (_loggedIn ? '已登录' : '未登录'),
              icon: Icons.account_circle_outlined,
              children: [
                HubActionTile(
                  title: _loggedIn ? '重新登录水鱼' : '登录水鱼',
                  subtitle: '使用水鱼账号获取 ImportToken',
                  icon: Icons.login,
                  onTap: _login,
                ),
                if (_loggedIn)
                  HubActionTile(
                    title: '登出账号',
                    subtitle:
                        _cachedQQ.isEmpty ? '清除当前登录状态' : '当前绑定 QQ：$_cachedQQ',
                    icon: Icons.logout,
                    iconColor: Theme.of(context).colorScheme.error,
                    onTap: _logout,
                  ),
              ],
            ),
            const SizedBox(height: 24),
            HubSection(
              title: '成绩同步',
              subtitle: '从舞萌数据源同步到第三方服务',
              icon: Icons.sync,
              children: [
                HubActionTile(
                  title: '同步成绩到水鱼',
                  subtitle: '扫码抓取并同步最新成绩',
                  icon: Icons.cloud_upload_outlined,
                  onTap: () => _showUnavailableMessage('请从首页的同步入口开始扫码同步'),
                ),
                HubActionTile(
                  title: '同步成绩到落雪',
                  subtitle: '将本地成绩同步到落雪咖啡屋',
                  icon: Icons.cloud_sync_outlined,
                  onTap: () => _showUnavailableMessage('请从首页的同步入口开始同步'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showUnavailableMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _LoginDialog extends StatefulWidget {
  final void Function(String username, String password) onSubmit;

  const _LoginDialog({required this.onSubmit});

  @override
  State<_LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<_LoginDialog> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('登录水鱼'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(labelText: '用户名'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: '密码'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => widget.onSubmit(
            _usernameController.text.trim(),
            _passwordController.text.trim(),
          ),
          child: const Text('登录'),
        ),
      ],
    );
  }
}
