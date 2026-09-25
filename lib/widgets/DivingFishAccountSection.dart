import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/ApiUrls.dart';
import '../utils/AppTheme.dart';

/// 水鱼账号在 App 里的「身份标识」状态。
///
/// App 用 **QQ** 当水鱼账号的标识（后端换票时 `subject = ref:sha256(client_id:qq)`），
/// 而这个 QQ **只能**从水鱼的 `/player/profile` 的 `bind_qq` 读出来：
///   * `/player/profile` 只接受登录验证，**不接受 Bearer**；
///   * OAuth 的 `/oauth/userinfo` 只返回 `sub` / `preferred_username` /
///     `name` / `nickname`，**没有 QQ**。
///
/// 所以「登录了水鱼、但账号里没填 QQ」是一个真实存在、且必须单独引导的状态 ——
/// 用户的账号本身完全正常，只是缺了一个字段，App 却因此完全读不到成绩。
/// 它也是迁移文档 §2.1 点名的三种「存量授权没被补齐」情形之一。
enum DivingFishQqState {
  /// 没登录水鱼：连 `/player/profile` 都读不到。
  notLoggedIn,

  /// 登录了，但水鱼账号的「绑定 QQ 号」是空的。
  noBindQq,

  /// 正常：拿到了 QQ。
  bound,
}

/// 由「有没有登录」+「读到的 QQ」推出三态。纯函数，便于测试。
DivingFishQqState resolveDivingFishQqState({
  required bool loggedIn,
  required String bindQq,
}) {
  if (!loggedIn) return DivingFishQqState.notLoggedIn;
  return bindQq.trim().isEmpty
      ? DivingFishQqState.noBindQq
      : DivingFishQqState.bound;
}

/// 「刷新数据」对话框里的水鱼面板：身份标识 + 授权状态。
///
/// 抽成共享 Widget 是因为**两个对话框（普通 / 高级）用的是同一块面板**，
/// 各抄一份必然漂移（历史上就是这么分叉出「一个改了另一个没改」的）。
/// 状态由调用方持有，这里只负责渲染与回调。
class DivingFishAccountSection extends StatelessWidget {
  /// 当前处于三态里的哪一种。
  final DivingFishQqState state;

  /// 实际使用的 QQ（仅 [DivingFishQqState.bound] 时展示）。
  final String qq;

  /// 授权状态：`true` 已授权 / `false` 未授权 / `null` 未知。
  final bool? authorized;

  /// 打开对话框时的首次授权检测中。
  final bool checkingAuth;

  /// 已把用户送去授权页，正等他回来点「重新检测」。
  final bool consentPending;

  /// 正在手动重新检测授权状态。
  final bool recheckingAuth;

  /// 正在重新读取水鱼账号里的「绑定 QQ 号」。
  final bool reloadingQq;

  /// 「去授权」：发起设备码绑定并打开授权页。
  final VoidCallback onStartAuthorization;

  /// 「我已授权，重新检测」。
  final VoidCallback onRecheckAuthorization;

  /// 「我已填好，重新读取」：重新读一次 `/player/profile` 的 `bind_qq`。
  final VoidCallback onReloadQq;

  const DivingFishAccountSection({
    super.key,
    required this.state,
    required this.qq,
    required this.authorized,
    required this.checkingAuth,
    required this.consentPending,
    required this.recheckingAuth,
    required this.reloadingQq,
    required this.onStartAuthorization,
    required this.onRecheckAuthorization,
    required this.onReloadQq,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    switch (state) {
      case DivingFishQqState.notLoggedIn:
        return _notLoggedIn(brightness);
      case DivingFishQqState.noBindQq:
        return _noBindQq(context, brightness);
      case DivingFishQqState.bound:
        return _bound(context, brightness);
    }
  }

  // ───────────────────────── 未登录 ─────────────────────────

  Widget _notLoggedIn(Brightness brightness) {
    return _box(
      brightness: brightness,
      color: AppColors.warningOrange(brightness),
      icon: Icons.info_outline,
      title: '还没登录水鱼账号',
      children: [
        _body(
          '读取水鱼成绩前，App 要先从水鱼读出你账号上绑定的 QQ 号。\n'
          '请到「系统 → 登录水鱼」完成登录后再回来刷新。',
          brightness,
        ),
      ],
    );
  }

  // ─────────────────── 登录了但没绑 QQ（新增） ───────────────────

  Widget _noBindQq(BuildContext context, Brightness brightness) {
    final accent = AppColors.warningOrange(brightness);
    return _box(
      brightness: brightness,
      color: accent,
      icon: Icons.link_off,
      title: '你的水鱼账号还没绑定 QQ 号',
      children: [
        _body(
          'App 用 QQ 号来识别你的水鱼账号，而你账号里的「绑定 QQ 号」是空的，\n'
          '所以现在读不到成绩。这不是登录出了问题，只是少填了一个字段。',
          brightness,
        ),
        const SizedBox(height: 10),
        _step('① 打开水鱼查分器官网并登录', brightness),
        _step('② 进入「编辑个人资料」→ 填上「绑定 QQ 号」并保存', brightness),
        _step('③ 回到这里点「我已填好，重新读取」', brightness),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('去水鱼官网绑定', style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: () => _openProberHome(context),
            ),
            if (reloadingQq)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              FilledButton.tonalIcon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('我已填好，重新读取', style: TextStyle(fontSize: 13)),
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: onReloadQq,
              ),
          ],
        ),
      ],
    );
  }

  // ───────────────────────── 正常：已绑定 ─────────────────────────

  Widget _bound(BuildContext context, Brightness brightness) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 只读展示。刻意**不用** `enabled: false` 的 TextField ——
        // 那是拿输入控件当标签用，会让人以为"这里本该能填、只是被禁了"。
        // QQ 必须来自水鱼（见 [DivingFishQqState] 的注释），本来就不给填。
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            // 描边统一走主题的 outlineVariant（见 AGENTS.md §7），
            // 不要用写死的中性灰
            border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(Icons.badge_outlined,
                  size: 18, color: AppColors.greyHint(brightness)),
              const SizedBox(width: 10),
              Text('账号',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.greyHint(brightness))),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'QQ $qq',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryText(brightness),
                  ),
                ),
              ),
              Icon(Icons.lock_outline,
                  size: 14, color: AppColors.greyHint(brightness)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _authRow(brightness),
      ],
    );
  }

  /// 授权状态行（已绑定才有意义）。
  Widget _authRow(Brightness brightness) {
    final muted = AppColors.greyHint(brightness);
    final green = AppColors.successGreen(brightness);

    if (checkingAuth || recheckingAuth) {
      return Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text('正在检查授权状态...', style: TextStyle(fontSize: 12, color: muted)),
        ],
      );
    }

    if (authorized == true) {
      return Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: green),
          const SizedBox(width: 6),
          Text('已授权', style: TextStyle(fontSize: 13, color: green)),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            consentPending
                ? '已打开授权页，请在浏览器中完成授权后点右侧重新检测'
                : '读取成绩需先授权本应用，未授权时刷新会失败',
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ),
        TextButton(
          onPressed:
              consentPending ? onRecheckAuthorization : onStartAuthorization,
          child: Text(consentPending ? '我已授权，重新检测' : '去授权'),
        ),
      ],
    );
  }

  // ───────────────────────── 小组件 ─────────────────────────

  Widget _box({
    required Brightness brightness,
    required Color color,
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }

  Widget _body(String text, Brightness brightness) => Text(
        text,
        style:
            TextStyle(fontSize: 12, color: AppColors.greyHint(brightness)),
      );

  Widget _step(String text, Brightness brightness) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          text,
          style: TextStyle(fontSize: 12, color: AppColors.greyHint(brightness)),
        ),
      );

  Future<void> _openProberHome(BuildContext context) async {
    const url = ApiUrls.DivingFishProberHomeUrl;
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        return;
      }
    } catch (e) {
      debugPrint('打开水鱼查分器官网失败: $e');
    }
    // 打不开浏览器就把链接放剪贴板，别让用户卡在这一步
    await Clipboard.setData(const ClipboardData(text: url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('无法打开浏览器，链接已复制到剪贴板，请手动粘贴打开'),
        duration: Duration(seconds: 3),
      ),
    );
  }
}
