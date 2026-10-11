import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'HubComponents.dart';
import 'SettingsPage.dart';
import 'DataBackupPage.dart';
import 'MaimaiServerStatusPage.dart';
import 'RecentCommentsPage.dart';
import 'RecentRatingsPage.dart';
import 'AboutAppPage.dart';
import 'Awmc/AwmcConsolePage.dart';
import 'SupportDeveloperPage.dart';
import 'FriendLinksPage.dart';
import 'LoadingTipsPage.dart';
import '../manager/LZYCheckUpdateManager.dart';
import '../manager/MaidataManager.dart';
import '../manager/DivingFishProbeManager.dart';
import '../manager/DivingFish/ProberException.dart';
import '../manager/LuoXue/CollectionsManager.dart';
import '../entity/LuoXue/Collection.dart';
import '../service/ConnectivityService.dart';
import '../service/SyncStatsService.dart';
import '../utils/SyncRouteNotifier.dart';
import '../utils/HomeRefreshNotifier.dart';
import '../utils/RefreshErrorPresenter.dart';
import '../utils/UpdateNotifier.dart';
import '../widgets/SyncRouteFooter.dart';
import '../widgets/SyncStatsFooter.dart';
import '../widgets/SyncFlowMixin.dart';
import '../widgets/SyncScoreDialogs.dart' show SyncScoreDialogs, SyncCallbacks;
import '../widgets/CollectionPickerSheet.dart';
import '../service/LogExportService.dart';
import '../widgets/LxnsAssetImage.dart';
import '../widgets/RefreshDataDialog.dart'
    show
        showRefreshDataDialog,
        executeRefreshData,
        refreshBest50DataWithProgress,
        executeAdvancedRefreshData,
        launchUrlFallback;
import '../widgets/AdvancedRefreshDataDialog.dart'
    show showAdvancedRefreshDataDialog;
import '../widgets/MaimaiHubLoginDialog.dart' show showMaimaiHubLoginDialog;
import '../constant/CacheKeyConstant.dart';
import '../constant/AppLinks.dart';
import '../utils/FavoriteFeaturesNotifier.dart';
import '../utils/FeatureFlags.dart';
import '../utils/LoginStateNotifier.dart';
import '../utils/UserProfileNotifier.dart';
import '../utils/AppTheme.dart';
import '../utils/ExternalLaunchUtil.dart';
import '../utils/ExportPathUtil.dart';
import '../service/CommunityAvatarStore.dart';
import '../widgets/ErrorMessageDialog.dart';
import '../entity/FeatureModels.dart';

class SystemHubPage extends StatefulWidget {
  final VoidCallback onAccountManageTap;

  const SystemHubPage({super.key, required this.onAccountManageTap});

  @override
  State<SystemHubPage> createState() => SystemHubPageState();
}

/// 「maidata 管理」对话框的返回值：用户选了哪个动作。
///
/// 只有「重新拉取全集」需要跳出对话框继续跑（进度打在按钮上）；
/// 「清除兜底缓存」是瞬时操作，留在对话框内完成，不产生返回值。
enum _MaidataManageAction { startRefresh }

class SystemHubPageState extends State<SystemHubPage> with SyncFlowMixin {
  /// 首页搜索调用系统 Hub 的原有入口，沿用同一份进度与互斥状态。
  Future<void> openFeature(ButtonItem item) async {
    if (anyBusy) {
      Fluttertoast.showToast(msg: '正在处理其它任务，请稍候');
      return;
    }
    if (item.title == '登录 maimai Score Hub') {
      await _loginMaimaiHub();
      return;
    }
    if (item.title == '打印日志') {
      await _exportLogs();
      return;
    }
    if (item.title == 'maidata 管理') {
      await _showMaidataManageDialog();
      return;
    }
    if (item.title == '刷新数据（高级）') {
      await _advancedRefreshData();
    }
  }

  // ===== 账号 / 用户信息（昵称 / QQ 来自 UserProfileNotifier） =====
  String _userNickname = '';

  // 同步成绩的线路与统计都由 SyncRouteNotifier 统一持有：
  // 首页「收藏的功能」区里的同名入口读的是同一份状态，两边永远不会显示不一致。
  // 线路落盘仍走 SyncRouteStore（同一套 prefs 键）。

  // ===== 登出水鱼确认 + 进度 =====
  bool _loggingOut = false;
  String _logoutText = '';
  bool _maimaiHubLoggedIn = false;

  // ===== 头像 / 姓名框（用于 Best50 图片导出） =====
  int _selectedAvatarId = 1;
  int? _selectedPlateId;
  List<Collection> _avatarIcons = [];
  List<Collection> _avatarPlates = [];

  // ===== 长任务的进行状态（显示在对应按钮上，替代原来的进度对话框） =====
  bool _refreshing = false;
  String _refreshText = '';
  double _refreshProgress = 0;
  bool _refreshingAdvanced = false;
  String _refreshAdvancedText = '';
  double _refreshAdvancedProgress = 0;
  bool _refreshingMaidata = false;
  int _maidataProgressCompleted = 0;
  int _maidataProgressTotal = 0;
  String _maidataProgressText = '';

  // 三个同步入口的进行状态由 SyncFlowMixin 持有（同步按钮上进度 + 互斥）。

  /// 任意长任务进行中：用于禁用其它入口，避免并发刷新互相踩缓存
  @override
  bool get anyBusy =>
      _refreshing ||
      _refreshingAdvanced ||
      !syncFlowsIdle ||
      _refreshingMaidata ||
      HomeRefreshNotifier.isBusy.value;

  @override
  void initState() {
    super.initState();
    // 监听共享状态：首页登出水鱼账号 / 同步成功后此处也会自动刷新昵称 / QQ
    UserProfileNotifier.instance.addListener(_onUserProfileChanged);
    _onUserProfileChanged();
    _selectedAvatarId = CommunityAvatarStore.instance.value.avatarId;
    CommunityAvatarStore.instance.addListener(_onAvatarChanged);
    LoginStateNotifier.instance.addListener(_onAvatarLoginChanged);
    unawaited(CommunityAvatarStore.instance.activate());
    _fetchAvatarIcons();
    _loadCachedPlateId();
    _fetchAvatarPlates();
    unawaited(_refreshMaimaiHubLoginState());
    // 线路 + 统计（与首页收藏区共享同一份状态；重复调用幂等）
    SyncRouteNotifier.instance.addListener(_onSyncRouteChanged);
    SyncRouteNotifier.instance.ensureLoaded();
    HomeRefreshNotifier.isBusy.addListener(_onHomeRefreshBusyChanged);
  }

  Future<void> _refreshMaimaiHubLoginState() async {
    final token = await DivingFishProbeManager().ensureAuthToken();
    if (mounted) setState(() => _maimaiHubLoggedIn = token != null);
  }

  void _onSyncRouteChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    CommunityAvatarStore.instance.removeListener(_onAvatarChanged);
    LoginStateNotifier.instance.removeListener(_onAvatarLoginChanged);
    UserProfileNotifier.instance.removeListener(_onUserProfileChanged);
    SyncRouteNotifier.instance.removeListener(_onSyncRouteChanged);
    HomeRefreshNotifier.isBusy.removeListener(_onHomeRefreshBusyChanged);
    super.dispose();
  }

  void _onHomeRefreshBusyChanged() {
    if (mounted) setState(() {});
  }

  /// 共享用户档案变更回调：把 notifier 中的值同步到本地字段，
  /// 我的页头像区昵称等区域立刻更新。
  void _onUserProfileChanged() {
    if (!mounted) return;
    final p = UserProfileNotifier.instance.value;
    setState(() {
      _userNickname = p.nickname;
    });
  }

  /// 共享收藏列表：当前是否已收藏（来自 FavoriteFeaturesNotifier，跨页面实时同步）
  bool _isFavorited(String title) =>
      FavoriteFeaturesNotifier.titles.contains(title);

  /// 切换收藏：写入共享 notifier，所有监听者自动重建
  Future<void> _toggleFavorite(String title) =>
      FavoriteFeaturesNotifier.toggle(title);

  Future<void> _loadProfile() => UserProfileNotifier.load();

  // ===== 头像 / 姓名框读写 =====

  void _onAvatarChanged() {
    if (mounted) {
      setState(() =>
          _selectedAvatarId = CommunityAvatarStore.instance.value.avatarId);
    }
  }

  void _onAvatarLoginChanged() {
    if (mounted) unawaited(CommunityAvatarStore.instance.activate());
  }

  Future<void> _saveAvatarId(int id) async {
    try {
      await CommunityAvatarStore.instance.select(id);
    } catch (_) {
      Fluttertoast.showToast(msg: '头像未能保存，请重新选择');
    }
  }

  Future<void> _fetchAvatarIcons() async {
    try {
      final collectionData = await CollectionsManager().fetchIconsCollections();
      if (collectionData?.icons != null && mounted) {
        setState(() => _avatarIcons = collectionData!.icons!);
      }
    } catch (e) {
      debugPrint('获取头像列表失败: $e');
    }
  }

  Future<void> _loadCachedPlateId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getInt(CacheKeyConstant.selectedPlateIdCache);
      if (mounted) setState(() => _selectedPlateId = cached);
    } catch (e) {
      debugPrint('加载姓名框ID失败: $e');
    }
  }

  Future<void> _savePlateId(int? id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (id == null) {
        await prefs.remove(CacheKeyConstant.selectedPlateIdCache);
      } else {
        await prefs.setInt(CacheKeyConstant.selectedPlateIdCache, id);
      }
    } catch (e) {
      debugPrint('保存姓名框ID失败: $e');
    }
  }

  Future<void> _fetchAvatarPlates() async {
    try {
      final collectionData =
          await CollectionsManager().fetchPlatesCollections();
      if (collectionData?.plates != null && mounted) {
        setState(() => _avatarPlates = collectionData!.plates!);
      }
    } catch (e) {
      debugPrint('获取姓名框列表失败: $e');
    }
  }

  void _showCollectionPicker() {
    if (_avatarIcons.isEmpty && _avatarPlates.isEmpty) {
      Fluttertoast.showToast(msg: '收藏品数据尚未加载，请先刷新数据');
      return;
    }

    final searchController = TextEditingController();
    final avatarPlayer = CommunityAvatarStore.instance.value.playerId;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CollectionPickerSheet(
        searchController: searchController,
        avatarIcons: _avatarIcons,
        avatarPlates: _avatarPlates,
        selectedAvatarId: _selectedAvatarId,
        selectedPlateId: _selectedPlateId,
        onAvatarPicked: (id) {
          if (CommunityAvatarStore.instance.value.playerId != avatarPlayer) {
            if (ctx.mounted) Navigator.of(ctx).pop();
            Fluttertoast.showToast(msg: '账号已切换，请重新选择头像');
            return;
          }
          final changed = id != _selectedAvatarId;
          if (mounted && changed) setState(() => _selectedAvatarId = id);
          if (ctx.mounted) Navigator.of(ctx).pop();
          // 先反馈选择，落盘在后台继续，避免等待 Android commit()。
          if (changed) {
            unawaited(_saveAvatarId(id));
          } else if (CommunityAvatarStore.instance.value.pending) {
            unawaited(CommunityAvatarStore.instance.retry());
          }
        },
        onPlatePicked: (id) {
          final changed = id != _selectedPlateId;
          if (mounted && changed) setState(() => _selectedPlateId = id);
          if (ctx.mounted) Navigator.of(ctx).pop();
          if (changed) unawaited(_savePlateId(id));
        },
      ),
    ).then((_) => searchController.dispose());
  }

  // ===== 通用 =====

  void _open(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page))
          .then((_) => _loadProfile());

  Future<void> _exportLogs() async {
    if (!await ExportPathUtil.prepareForExport(context,
        subDir: '日志', title: '选择日志保存位置')) {
      return;
    }
    try {
      final file = await LogExportService.instance.export();
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
                title: const Text('日志已导出'),
                content: SelectableText(file.path),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('知道了'))
                ],
              ));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导出日志失败：$e')));
    }
  }

  /// 打开外链；**打不开就把内容复制到剪贴板并提示**（不会静默失败）。
  ///
  /// [copyText] 默认复制 [url]。加群链接那种「复制链接没用」的情况要显式换成群号；
  /// [failMessage] 用来说明复制到的是什么、接下来怎么办。两个都不给时用通用文案。
  Future<void> _launchExternal(
    BuildContext context,
    String url,
    String label, {
    String? copyText,
    String? failMessage,
  }) async {
    final uri = Uri.parse(url);
    try {
      if (await ExternalLaunchUtil.open(uri)) {
        return;
      }
    } catch (e) {
      debugPrint('打开 $url 失败: $e');
    }
    if (!context.mounted) return;
    // 统一走公共兜底：复制剪贴板 + SnackBar（各写一遍很容易漏掉复制那一步）
    launchUrlFallback(
      url,
      context,
      copyText: copyText,
      message: failMessage ?? '无法打开浏览器，$label已复制到剪贴板，请手动粘贴打开',
    );
  }

  /// 刷新数据：对话框只收集输入，进度显示在「刷新数据」这个按钮上。
  Future<void> _refreshData() async {
    if (anyBusy) return;
    final request = await showRefreshDataDialog(context);
    if (request == null || !mounted) return;

    setState(() {
      _refreshing = true;
      _refreshText = '正在刷新数据...';
      _refreshProgress = 0;
    });
    try {
      await executeRefreshData(request, onProgress: (p, t) {
        if (!mounted) return;
        setState(() {
          _refreshText = '$t $p%';
          _refreshProgress = p / 100;
        });
      });
      if (!mounted) return;
      Fluttertoast.showToast(msg: '数据刷新成功!');
    } on ProberException catch (e) {
      // 未授权 → 直接拉起授权页；其余按统一文案提示。
      // 与首页刷新入口共用 presentRefreshError，避免两边行为不一致。
      if (mounted) await presentRefreshError(context, e, qq: request.qq.trim());
    } catch (e) {
      if (mounted) await presentRefreshError(context, e, qq: request.qq.trim());
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
          _refreshText = '';
        });
      }
    }
  }

  /// 高级模式刷新数据：弹新对话框，让用户按缓存源勾选强制刷新，并测试 API 连通性。
  /// 进度同样显示在按钮上（不再弹转圈对话框）。
  Future<void> _advancedRefreshData() async {
    if (anyBusy) return;
    final request = await showAdvancedRefreshDataDialog(context);
    if (request == null || !mounted) return;

    setState(() {
      _refreshingAdvanced = true;
      _refreshAdvancedText = '正在刷新数据...';
      _refreshAdvancedProgress = 0;
    });
    try {
      await executeAdvancedRefreshData(
        request,
        onProgress: (p, t) {
          if (!mounted) return;
          setState(() {
            _refreshAdvancedText = '$t $p%';
            _refreshAdvancedProgress = p / 100;
          });
        },
      );
      if (!mounted) return;
      Fluttertoast.showToast(msg: '数据刷新成功!');
    } on ProberException catch (e) {
      // 未授权 → 直接拉起授权页；其余按统一文案提示。
      // 与首页刷新入口共用 presentRefreshError，避免两边行为不一致。
      if (mounted) await presentRefreshError(context, e, qq: request.qq.trim());
    } catch (e) {
      if (mounted) await presentRefreshError(context, e, qq: request.qq.trim());
    } finally {
      if (mounted) {
        setState(() {
          _refreshingAdvanced = false;
          _refreshAdvancedText = '';
        });
      }
    }
  }

  /// maidata 管理对话框：重新拉取 chiffonmai.cloud 全集 + 清除 wmc.pub 兜底缓存。
  ///
  /// 对话框**只负责收集意图**并列出当前两块缓存的用量；用户选了「重新拉取」
  /// 之后它立刻关闭，进度改由 [_refreshMaidata] 打在「maidata 管理」按钮上
  /// —— 与同页的 `_refreshData` / `_advancedRefreshData` 同一套约定。
  /// 「清除兜底缓存」是瞬时操作，仍留在对话框里（也就还能在弹窗内提示结果）。
  Future<void> _showMaidataManageDialog() async {
    if (anyBusy) return;
    final manager = MaidataManager();
    await manager.initialize();
    if (!mounted) return;

    final isOnline = await ConnectivityService().hasConnection();
    if (!mounted) return;
    if (!isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前无网络连接，请联网后重试')),
      );
      return;
    }

    final action = await showDialog<_MaidataManageAction>(
      context: context,
      builder: (ctx) {
        final cachedCount = manager.cachedCount;
        final wmcCount = manager.wmcFallbackCacheCount;

        return AlertDialog(
          title: const Text('maidata 管理'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _maidataStatRow(
                label: '全量缓存（chiffonmai.cloud）',
                value: '$cachedCount 首',
              ),
              const SizedBox(height: 4),
              _maidataStatRow(
                label: 'wmc.pub 兜底缓存（内存）',
                value: '$wmcCount 首',
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.cloud_download_outlined),
                label: const Text('从 chiffonmai.cloud 重新拉取全集'),
                onPressed: () => Navigator.of(ctx).pop(
                  _MaidataManageAction.startRefresh,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.cleaning_services_outlined),
                label: const Text('清除 wmc.pub 兜底缓存'),
                onPressed: wmcCount == 0
                    ? null
                    : () {
                        manager.clearWmcFallbackCache();
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('已清除 wmc.pub 兜底缓存'),
                          ),
                        );
                      },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );

    if (action != _MaidataManageAction.startRefresh || !mounted) return;
    await _refreshMaidata(manager);
  }

  /// 重新拉取全量 maidata，进度显示在「maidata 管理」按钮上（含 `current / total`）。
  Future<void> _refreshMaidata(MaidataManager manager) async {
    setState(() {
      _refreshingMaidata = true;
      _maidataProgressCompleted = 0;
      _maidataProgressTotal = 0;
      _maidataProgressText = '正在从 chiffonmai.cloud 拉取...';
    });
    try {
      await manager.fetchAndCacheFullMaidata(
        onProgress: (current, total) {
          if (!mounted) return;
          setState(() {
            _maidataProgressCompleted = current;
            _maidataProgressTotal = total;
            // 总数未定时（各流派文件夹列表还没回齐）只报已发现数量。
            _maidataProgressText =
                total > 0 ? '$current / $total' : '已发现 $current 首，正在统计总量...';
          });
        },
      );
      if (!mounted) return;
      Fluttertoast.showToast(msg: 'maidata 刷新完成');
    } catch (e) {
      debugPrint('刷新 maidata 失败：$e');
      if (!mounted) return;
      await showErrorMessageDialog(context, message: '刷新失败：$e');
    } finally {
      if (mounted) {
        setState(() {
          _refreshingMaidata = false;
          _maidataProgressCompleted = 0;
          _maidataProgressTotal = 0;
          _maidataProgressText = '';
        });
      }
    }
  }

  Widget _maidataStatRow({required String label, required String value}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Future<void> _checkUpdate() async {
    final isOnline = await ConnectivityService().hasConnection();
    if (!mounted) return;
    if (!isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前无网络连接，请联网后重试')),
      );
      return;
    }
    final updateManager = LZYCheckUpdateManager();
    updateManager.showUpdateDialog(context, force: true);
  }

  // ===== 同步成绩 =====

  /// SyncFlowMixin 需要一个按本页刷新逻辑实现的回调集。
  @override
  SyncCallbacks get syncCallbacks => SyncCallbacks(
        onSaveQQ: (qq) async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(CacheKeyConstant.probeDivingFishBindQQ, qq);
        },
        onRefreshAfterSync: _refreshAfterSync,
        onLoginStateChanged: () async {
          await _loadProfile();
          // 登录成功后通知共享 LoginStateNotifier：
          // 本页与监听此 notifier 的其他页面（首页分类页等）会即时把
          // "登录水鱼" 按钮切换为 "登出账号"。
          LoginStateNotifier.setLoggedIn(true);
        },
      );

  Future<void> _refreshAfterSync({
    required String qq,
    required void Function(double progress, String text) onProgress,
    required bool participateRankings,
    required bool showNickname,
  }) async {
    await refreshBest50DataWithProgress(
        qq, (p, text) => onProgress(0.70 + p / 100 * 0.30, text),
        participateRankings: participateRankings, showNickname: showNickname);
    await _loadProfile();
  }

  // 五个同步流程（水鱼线路1/线路2、落雪线路1/线路2、AWMC NET）原来在这里各写了一份，
  // 与首页「收藏的功能」区的那份逐渐走歪。现在统一由 SyncFlowMixin 提供：
  //   syncToDivingFishByCurrentRoute / syncToLuoXueByCurrentRoute / syncToAwmcNetWithButton
  // 按钮上的进度文案从 syncingDivingFish / luoXueText 等 getter 读。
  // 线路1 = AWMC 网关、线路2 = maimai Score Hub（详见 SyncRouteStore）。

  void _loginDivingFish() {
    SyncScoreDialogs.showDivingFishLoginDialog(context, syncCallbacks);
  }

  Future<void> _loginMaimaiHub() async {
    if (anyBusy) return;
    final loggedIn = await showMaimaiHubLoginDialog(context);
    if (!mounted) return;
    if (loggedIn) {
      setState(() => _maimaiHubLoggedIn = true);
      Fluttertoast.showToast(msg: 'maimai Score Hub 登录状态已保存，现在可以使用 OCR 了');
    }
  }

  Future<bool> _confirmLogout() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认登出水鱼账号'),
        content: const Text('登出后将清除缓存的登录信息和 ImportToken，确定要登出吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('登出'),
          ),
        ],
      ),
    );
    return result == true;
  }

  /// 登出水鱼账号：先弹出确认对话框，再清除账号相关缓存。
  Future<void> _logoutDivingFish() async {
    if (_loggingOut) return;
    if (!await _confirmLogout() || !mounted) return;
    setState(() {
      _loggingOut = true;
      _logoutText = '正在登出水鱼账号...';
    });
    try {
      await UserProfileNotifier.clearShuiyuAccountCache();
      if (!mounted) return;
      LoginStateNotifier.setLoggedIn(false);
      Fluttertoast.showToast(msg: '已登出水鱼账号');
    } catch (e) {
      debugPrint('登出水鱼账号失败：$e');
      if (mounted) {
        await showErrorMessageDialog(context, message: '登出水鱼账号失败：$e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _loggingOut = false;
          _logoutText = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 监听共享收藏列表 + 共享登录态：
    //   本页点星标 / 其他页点星标 / 收藏管理页删除收藏 → 整页重建；
    //   任意页面登录 / 登出水鱼账号 → "登录水鱼" / "登出账号" 按钮即时切换。
    return ValueListenableBuilder<FavoritesPayload>(
      valueListenable: FavoriteFeaturesNotifier.instance,
      builder: (context, payload, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: LoginStateNotifier.instance,
          builder: (context, loggedIn, __) => HubPageScaffold(
            title: '系统',
            subtitle: '账号、同步、备份与应用偏好',
            icon: Icons.settings_rounded,
            hero: _MeProfileBanner(
              selectedAvatarId: _selectedAvatarId,
              nickname: _userNickname,
              avatarStatus: CommunityAvatarStore.instance.value.message,
              avatarStatusLevel: CommunityAvatarStore.instance.value.level,
              onRetryAvatar: CommunityAvatarStore.instance.value.pending
                  ? () => unawaited(CommunityAvatarStore.instance.retry())
                  : null,
              onPickTap: _showCollectionPicker,
            ),
            children: [
              HubSection(
                title: '数据与账号',
                icon: Icons.sync_rounded,
                subtitle: 'maimai Score Hub 登录 · 登录水鱼 · 同步账号 · 数据备份 · 刷新缓存',
                // 10 个入口里「AWMC 网关」默认隐藏（FeatureFlags.awmcGateway）
                badgeCount: 11 + (FeatureFlags.awmcGateway ? 1 : 0),
                children: [
                  HubActionTile(
                    title: '登录 maimai Score Hub',
                    titleFontSize: 13,
                    subtitle: _maimaiHubLoggedIn
                        ? '已登录，可直接使用 OCR；点击可重新登录'
                        : '仅登录，不同步成绩；用于 OCR 与 maimai Score Hub 功能',
                    icon: _maimaiHubLoggedIn
                        ? Icons.verified_user_outlined
                        : Icons.login_rounded,
                    isFavorited: _isFavorited('登录 maimai Score Hub'),
                    onToggleFavorite: () =>
                        _toggleFavorite('登录 maimai Score Hub'),
                    onTap: _loginMaimaiHub,
                    disabled: anyBusy,
                  ),
                  HubActionTile(
                    title: loggedIn ? '登出水鱼账号' : '登录水鱼',
                    subtitle: loggedIn ? '清除水鱼登录状态' : '获取 ImportToken 以使用同步功能',
                    icon: loggedIn ? Icons.logout_rounded : Icons.login_rounded,
                    isFavorited: _isFavorited(loggedIn ? '登出水鱼账号' : '登录水鱼'),
                    onToggleFavorite: () =>
                        _toggleFavorite(loggedIn ? '登出水鱼账号' : '登录水鱼'),
                    onTap: loggedIn ? _logoutDivingFish : _loginDivingFish,
                    loading: _loggingOut,
                    loadingText: _logoutText,
                    disabled: anySyncBusy,
                  ),
                  HubActionTile(
                    title: '同步成绩到水鱼',
                    subtitle: '扫码抓取并同步最新成绩',
                    icon: Icons.cloud_upload_outlined,
                    isFavorited: _isFavorited('同步成绩到水鱼'),
                    onToggleFavorite: () => _toggleFavorite('同步成绩到水鱼'),
                    onTap: syncToDivingFishByCurrentRoute,
                    loading: syncingDivingFish,
                    loadingText: syncText,
                    showProgress: true,
                    progressValue: divingFishProgress,
                    disabled: HomeRefreshNotifier.isBusy.value ||
                        syncingLuoXue ||
                        syncingAwmcNet ||
                        syncingMulti,
                    // 线路切换 + 统计：与首页「收藏的功能」区共用同一份状态
                    footer: SyncRouteFooter(
                      platform: SyncPlatform.divingFish,
                      enabled: !anyBusy,
                    ),
                  ),
                  HubActionTile(
                    title: '同步成绩到落雪',
                    subtitle: '将本地成绩同步到落雪咖啡屋',
                    icon: Icons.cloud_sync_outlined,
                    isFavorited: _isFavorited('同步成绩到落雪'),
                    onToggleFavorite: () => _toggleFavorite('同步成绩到落雪'),
                    onTap: syncToLuoXueByCurrentRoute,
                    loading: syncingLuoXue,
                    loadingText: luoXueText,
                    showProgress: true,
                    progressValue: luoXueProgress,
                    disabled: HomeRefreshNotifier.isBusy.value ||
                        syncingDivingFish ||
                        syncingAwmcNet ||
                        syncingMulti,
                    footer: SyncRouteFooter(
                      platform: SyncPlatform.luoXue,
                      enabled: !anyBusy,
                    ),
                  ),
                  HubActionTile(
                    title: '同步成绩到 AWMC NET',
                    subtitle: '用机台二维码导入成绩到 AWMC NET',
                    icon: Icons.cloud_upload_outlined,
                    isFavorited: _isFavorited('同步成绩到 AWMC NET'),
                    onToggleFavorite: () => _toggleFavorite('同步成绩到 AWMC NET'),
                    // AWMC NET 只有「机台二维码」这一条写入路径（读成绩的 AWMC 数据源
                    // 不需要登录），所以**没有线路切换器**，只有一行近 100 次统计
                    // —— 也就是 SyncStatsFooter 而不是 SyncRouteFooter。
                    // 等待进度与另外两个同步入口一样显示在这个按钮上。
                    onTap: syncToAwmcNetWithButton,
                    loading: syncingAwmcNet,
                    loadingText: awmcNetText,
                    showProgress: true,
                    progressValue: awmcNetProgress,
                    disabled: HomeRefreshNotifier.isBusy.value ||
                        syncingDivingFish ||
                        syncingLuoXue ||
                        syncingMulti,
                    // 统计行上提一点贴紧按钮：tile 底部本来就空着约 23px，
                    // 一行小字挂在那里会显得离按钮太远（见 SyncStatsFooter.footerLift）
                    footerLift: SyncStatsFooter.footerLift,
                    footer: const SyncStatsFooter(
                      slot: (SyncLine.direct, SyncPlatform.awmc),
                    ),
                  ),
                  HubActionTile(
                    title: '同步成绩到多端',
                    subtitle: '一份成绩同步到多个查分器',
                    icon: Icons.devices_other_outlined,
                    isFavorited: _isFavorited('同步成绩到多端'),
                    onToggleFavorite: () => _toggleFavorite('同步成绩到多端'),
                    onTap: syncToMultiplePlatforms,
                    loading: syncingMulti,
                    loadingText: multiSyncText,
                    showProgress: true,
                    progressValue: multiSyncProgress,
                    disabled: HomeRefreshNotifier.isBusy.value ||
                        syncingDivingFish ||
                        syncingLuoXue ||
                        syncingAwmcNet,
                  ),
                  HubActionTile(
                    title: '账号管理',
                    subtitle: '查看已绑定的水鱼账号信息',
                    icon: Icons.manage_accounts_outlined,
                    isFavorited: _isFavorited('账号管理'),
                    onToggleFavorite: () => _toggleFavorite('账号管理'),
                    onTap: widget.onAccountManageTap,
                  ),
                  HubActionTile(
                    title: '数据备份',
                    subtitle: '导入或导出本地数据',
                    icon: Icons.backup_outlined,
                    isFavorited: _isFavorited('数据备份'),
                    onToggleFavorite: () => _toggleFavorite('数据备份'),
                    onTap: () => _open(context, const DataBackupPage()),
                  ),
                  HubActionTile(
                    title: '刷新数据',
                    subtitle: '重新拉取并初始化所有本地缓存',
                    icon: Icons.file_upload_sharp,
                    isFavorited: _isFavorited('刷新数据'),
                    onToggleFavorite: () => _toggleFavorite('刷新数据'),
                    onTap: _refreshData,
                    loading: _refreshing,
                    loadingText: _refreshText,
                    showProgress: true,
                    progressValue: _refreshProgress,
                    disabled: HomeRefreshNotifier.isBusy.value ||
                        _refreshingAdvanced ||
                        anySyncBusy,
                  ),
                  HubActionTile(
                    title: '刷新数据（高级）',
                    subtitle: '按缓存源勾选强制刷新，并测试各 API 连通性',
                    icon: Icons.tune_rounded,
                    isFavorited: _isFavorited('刷新数据（高级）'),
                    onToggleFavorite: () => _toggleFavorite('刷新数据（高级）'),
                    onTap: _advancedRefreshData,
                    loading: _refreshingAdvanced,
                    loadingText: _refreshAdvancedText,
                    showProgress: true,
                    progressValue: _refreshAdvancedProgress,
                    disabled: HomeRefreshNotifier.isBusy.value ||
                        _refreshing ||
                        anySyncBusy,
                  ),
                  HubActionTile(
                    title: 'maidata 管理',
                    subtitle: '重新拉取 chiffonmai.cloud 集 · 清除 wmc.pub 兜底缓存',
                    icon: Icons.tune_rounded,
                    isFavorited: _isFavorited('maidata管理'),
                    onToggleFavorite: () => _toggleFavorite('maidata管理'),
                    onTap: _showMaidataManageDialog,
                    // 拉取进度打在按钮上（对话框选完即关，不再在里面显示进度）。
                    // 总数要等各流派文件夹列表回齐才确定，在那之前只有转圈。
                    loading: _refreshingMaidata,
                    loadingText: _maidataProgressText,
                    progressCurrent:
                        _refreshingMaidata && _maidataProgressTotal > 0
                            ? _maidataProgressCompleted
                            : null,
                    progressTotal:
                        _refreshingMaidata && _maidataProgressTotal > 0
                            ? _maidataProgressTotal
                            : null,
                    disabled: anyBusy && !_refreshingMaidata,
                  ),
                  // 「AWMC 网关」入口：默认隐藏（FeatureFlags.awmcGateway），
                  // 代码一行没删；要启用时改那个开关即可。
                  if (FeatureFlags.awmcGateway)
                    HubActionTile(
                      title: 'AWMC 网关',
                      subtitle: '查询/写入机台账号数据（敏感操作）',
                      icon: Icons.shield_outlined,
                      isFavorited: _isFavorited('AWMC 网关'),
                      onToggleFavorite: () => _toggleFavorite('AWMC 网关'),
                      onTap: () => _open(context, const AwmcConsolePage()),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              HubSection(
                title: '应用',
                icon: Icons.tune_rounded,
                subtitle: '主题 · 检查更新 · 服务器 · 社区',
                badgeCount: 6,
                children: [
                  HubActionTile(
                    title: '主题与交互偏好',
                    subtitle: '调整主题色、模式、背景图和交互偏好',
                    icon: Icons.palette_outlined,
                    isFavorited: _isFavorited('主题与交互偏好'),
                    onToggleFavorite: () => _toggleFavorite('主题与交互偏好'),
                    onTap: () => _open(context, const SettingsPage()),
                  ),
                  HubActionTile(
                    title: '加载语录管理',
                    subtitle: '选择加载时展示的语录',
                    icon: Icons.format_quote,
                    isFavorited: _isFavorited('加载语录管理'),
                    onToggleFavorite: () => _toggleFavorite('加载语录管理'),
                    onTap: () => _open(context, const LoadingTipsPage()),
                  ),
                  HubActionTile(
                    title: '打印日志',
                    subtitle: '导出最近运行日志，方便排查问题',
                    icon: Icons.receipt_long_outlined,
                    isFavorited: _isFavorited('打印日志'),
                    onToggleFavorite: () => _toggleFavorite('打印日志'),
                    onTap: _exportLogs,
                  ),
                  // 「检查更新」在检测到新版本时会变成「发现新版本」+
                  // 绿色圆环箭头（见 UpdateAvailableIcon）。
                  // 点击逻辑两者完全一致，都是 _checkUpdate。
                  ValueListenableBuilder<UpdateAvailability?>(
                    valueListenable: UpdateNotifier.available,
                    builder: (context, update, _) {
                      if (update == null) {
                        return HubActionTile(
                          title: UpdateNotifier.idleTitle,
                          subtitle: UpdateNotifier.idleSubtitle,
                          icon: Icons.system_update_alt_outlined,
                          isFavorited: _isFavorited(UpdateNotifier.idleTitle),
                          onToggleFavorite: () =>
                              _toggleFavorite(UpdateNotifier.idleTitle),
                          onTap: _checkUpdate,
                        );
                      }
                      return HubActionTile(
                        title: UpdateNotifier.titleFor(update),
                        subtitle: UpdateNotifier.subtitleFor(
                            update, UpdateNotifier.idleSubtitle),
                        icon: Icons.arrow_upward_rounded,
                        titleColor: UpdateAvailableIcon.green,
                        leading: const UpdateAvailableIcon(),
                        isFavorited: _isFavorited(UpdateNotifier.idleTitle),
                        onToggleFavorite: () =>
                            _toggleFavorite(UpdateNotifier.idleTitle),
                        onTap: _checkUpdate,
                      );
                    },
                  ),
                  HubActionTile(
                    title: '服务器状态',
                    subtitle: '查看舞萌服务状态',
                    icon: Icons.cloud_outlined,
                    isFavorited: _isFavorited('服务器状态'),
                    onToggleFavorite: () => _toggleFavorite('服务器状态'),
                    onTap: () => _open(context, const MaimaiServerStatusPage()),
                  ),
                  HubActionTile(
                    title: '最近评论',
                    subtitle: '查看社区最近评论',
                    icon: Icons.comment_outlined,
                    isFavorited: _isFavorited('最近评论'),
                    onToggleFavorite: () => _toggleFavorite('最近评论'),
                    onTap: () => _open(context, const RecentCommentsPage()),
                  ),
                  HubActionTile(
                    title: '最近评分',
                    subtitle: '查看社区最近评分',
                    icon: Icons.star_outline_rounded,
                    isFavorited: _isFavorited('最近评分'),
                    onToggleFavorite: () => _toggleFavorite('最近评分'),
                    onTap: () => _open(context, const RecentRatingsPage()),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              HubSection(
                title: '关于 ChiffonMai',
                icon: Icons.info_outline_rounded,
                subtitle: '官网/交流群/应用信息/开发者/友情链接/问卷',
                badgeCount: 6,
                children: [
                  HubActionTile(
                    title: '访问官方网站',
                    subtitle: '前往 chiffonmai.cloud 查看项目主页',
                    icon: Icons.public,
                    isFavorited: _isFavorited('访问官方网站'),
                    onToggleFavorite: () => _toggleFavorite('访问官方网站'),
                    onTap: () => _launchExternal(
                      context,
                      AppLinks.officialSite,
                      '官网链接',
                      failMessage: '无法打开浏览器，官网链接已复制到剪贴板，'
                          '请粘贴到浏览器访问 ${AppLinks.officialSite}',
                    ),
                  ),
                  HubActionTile(
                    title: '加入 QQ 群',
                    subtitle: '一键跳转官方交流群（${AppLinks.qqGroupNumber}）',
                    icon: Icons.groups_outlined,
                    isFavorited: _isFavorited('加入 QQ 群'),
                    onToggleFavorite: () => _toggleFavorite('加入 QQ 群'),
                    onTap: () => _launchExternal(
                      context,
                      AppLinks.qqGroupJoinUrl,
                      '群号',
                      // 加群链接在浏览器里只是个空壳中转页，所以要复制**群号**
                      copyText: AppLinks.qqGroupNumber,
                      failMessage: '没能跳转到 QQ，群号 ${AppLinks.qqGroupNumber} '
                          '已复制到剪贴板，可在 QQ 里搜索加入',
                    ),
                  ),
                  HubActionTile(
                    title: '关于 APP',
                    subtitle: '了解项目与版本信息',
                    icon: Icons.info_outline_rounded,
                    isFavorited: _isFavorited('关于 APP'),
                    onToggleFavorite: () => _toggleFavorite('关于 APP'),
                    onTap: () => _open(context, const AboutAppPage()),
                  ),
                  HubActionTile(
                    title: '支持开发者',
                    subtitle: '支持项目持续更新',
                    icon: Icons.volunteer_activism_outlined,
                    isFavorited: _isFavorited('支持开发者'),
                    onToggleFavorite: () => _toggleFavorite('支持开发者'),
                    onTap: () => _open(context, const SupportDeveloperPage()),
                  ),
                  HubActionTile(
                    title: '查看友情链接',
                    subtitle: '发现同好项目',
                    icon: Icons.link_rounded,
                    isFavorited: _isFavorited('查看友情链接'),
                    onToggleFavorite: () => _toggleFavorite('查看友情链接'),
                    onTap: () => _open(context, const FriendLinksPage()),
                  ),
                  HubActionTile(
                    title: '问卷调查',
                    subtitle: '助力 ChiffonMai 更上一层楼',
                    icon: Icons.poll_outlined,
                    isFavorited: _isFavorited('问卷调查'),
                    onToggleFavorite: () => _toggleFavorite('问卷调查'),
                    onTap: () =>
                        _launchExternal(context, AppLinks.surveyUrl, '问卷链接'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 顶部 Profile Banner：头像（原图方形）+ 用户昵称
class _MeProfileBanner extends StatelessWidget {
  final int selectedAvatarId;
  final String nickname;
  final VoidCallback onPickTap;
  final String avatarStatus;
  final AvatarSyncLevel avatarStatusLevel;
  final VoidCallback? onRetryAvatar;

  const _MeProfileBanner({
    required this.selectedAvatarId,
    required this.nickname,
    required this.onPickTap,
    required this.avatarStatus,
    this.avatarStatusLevel = AvatarSyncLevel.localOnly,
    this.onRetryAvatar,
  });

  /// 头像同步状态的主色：绿=已同步正常，蓝=正在同步，
  /// 黄=仅本机/待同步（需用户处理），红=同步异常。
  Color _statusColor(Brightness brightness) {
    switch (avatarStatusLevel) {
      case AvatarSyncLevel.synced:
        return AppColors.successGreen(brightness);
      case AvatarSyncLevel.syncing:
        return AppColors.linkBlue(brightness);
      case AvatarSyncLevel.pending:
      case AvatarSyncLevel.localOnly:
        return AppColors.warningOrange(brightness);
      case AvatarSyncLevel.error:
        return AppColors.errorRed(brightness);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final displayName = nickname.isNotEmpty ? nickname : kUnsetNicknameLabel;
    final statusColor = _statusColor(brightness);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPickTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: .72),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              // 头像（原图方形，封面模式自适应）
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: LxnsAssetImage(
                      url: lxnsIconUrl(selectedAvatarId),
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      placeholder: Container(
                        width: 72,
                        height: 72,
                        color: scheme.primaryContainer,
                        child: Icon(
                          Icons.person,
                          color: scheme.onPrimaryContainer,
                          size: 36,
                        ),
                      ),
                      errorWidget: Container(
                        width: 72,
                        height: 72,
                        color: scheme.primaryContainer,
                        child: Icon(
                          Icons.person,
                          color: scheme.onPrimaryContainer,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.surface, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.edit,
                        size: 11,
                        color: scheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '点击更换头像 / 姓名框',
                      style: TextStyle(
                        color: scheme.primary,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    GestureDetector(
                      onTap: onRetryAvatar,
                      child: Text(avatarStatus,
                          style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight:
                                  avatarStatusLevel == AvatarSyncLevel.synced
                                      ? FontWeight.w600
                                      : FontWeight.normal)),
                    ),
                    Text(
                      '可按需在下方获取/同步成绩数据',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
