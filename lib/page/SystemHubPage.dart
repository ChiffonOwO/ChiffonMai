import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'HubComponents.dart';
import 'SettingsPage.dart';
import 'DataBackupPage.dart';
import 'MaimaiServerStatusPage.dart';
import 'RecentCommentsPage.dart';
import 'RecentRatingsPage.dart';
import 'AboutAppPage.dart';
import 'Awmc/AwmcConsolePage.dart';
import 'AwmcNet/AwmcNetSyncFlow.dart';
import 'Awmc/AwmcSyncFlow.dart';
import 'SupportDeveloperPage.dart';
import 'FriendLinksPage.dart';
import '../manager/LZYCheckUpdateManager.dart';
import '../manager/MaidataManager.dart';
import '../manager/DivingFish/ProberException.dart';
import '../manager/LuoXue/CollectionsManager.dart';
import '../entity/LuoXue/Collection.dart';
import '../service/ConnectivityService.dart';
import '../service/SyncRouteStore.dart';
import '../service/SyncStatsService.dart';
import '../utils/SyncRouteNotifier.dart';
import '../utils/RefreshErrorPresenter.dart';
import '../utils/UpdateNotifier.dart';
import '../widgets/SyncRouteFooter.dart';
import '../widgets/SyncStatsFooter.dart';
import '../widgets/SyncScoreDialogs.dart'
    show
        SyncScoreDialogs,
        SyncCallbacks,
        SyncFlowException,
        showDivingFishSyncInputDialog,
        executeDivingFishSync,
        showLuoXueSyncInputDialog,
        executeLuoXueSync;
import '../widgets/CollectionPickerSheet.dart';
import '../service/AccountStore.dart';
import '../widgets/RefreshDataDialog.dart'
    show
        showRefreshDataDialog,
        executeRefreshData,
        refreshBest50DataWithProgress,
        executeAdvancedRefreshData,
        launchUrlFallback;
import '../widgets/AdvancedRefreshDataDialog.dart' show showAdvancedRefreshDataDialog;
import '../constant/CacheKeyConstant.dart';
import '../constant/AppLinks.dart';
import '../utils/FavoriteFeaturesNotifier.dart';
import '../utils/FeatureFlags.dart';
import '../utils/LoginStateNotifier.dart';
import '../utils/UserProfileNotifier.dart';

class SystemHubPage extends StatefulWidget {
  final VoidCallback onAccountManageTap;

  const SystemHubPage({super.key, required this.onAccountManageTap});

  @override
  State<SystemHubPage> createState() => _SystemHubPageState();
}

class _SystemHubPageState extends State<SystemHubPage> {
  // ===== 账号 / 用户信息（昵称 / QQ 来自 UserProfileNotifier） =====
  String _userNickname = '';

  // 同步成绩的线路与统计都由 SyncRouteNotifier 统一持有：
  // 首页「收藏的功能」区里的同名入口读的是同一份状态，两边永远不会显示不一致。
  // 线路落盘仍走 SyncRouteStore（同一套 prefs 键）。

  // ===== 登出水鱼二次确认 + 进度 =====
  bool _logoutConfirming = false;
  bool _loggingOut = false;
  String _logoutText = '';

  // ===== 头像 / 姓名框（用于 Best50 图片导出） =====
  int _selectedAvatarId = 1;
  int? _selectedPlateId;
  List<Collection> _avatarIcons = [];
  List<Collection> _avatarPlates = [];

  // ===== 长任务的进行状态（显示在对应按钮上，替代原来的进度对话框） =====
  bool _refreshing = false;
  String _refreshText = '';
  bool _refreshingAdvanced = false;
  String _refreshAdvancedText = '';
  bool _syncingDivingFish = false;
  String _syncText = '';
  bool _syncingLuoXue = false;
  String _luoXueText = '';
  bool _syncingAwmcNet = false;
  String _awmcNetText = '';
  bool _refreshingMaidata = false;
  String _maidataText = '';

  /// 任意长任务进行中：用于禁用其它入口，避免并发刷新互相踩缓存
  bool get _anyBusy =>
      _refreshing ||
      _refreshingAdvanced ||
      _syncingDivingFish ||
      _syncingLuoXue ||
      _syncingAwmcNet ||
      _refreshingMaidata;

  @override
  void initState() {
    super.initState();
    // 监听共享状态：首页登出水鱼账号 / 同步成功后此处也会自动刷新昵称 / QQ
    UserProfileNotifier.instance.addListener(_onUserProfileChanged);
    _onUserProfileChanged();
    _loadCachedAvatarId();
    _fetchAvatarIcons();
    _loadCachedPlateId();
    _fetchAvatarPlates();
    // 线路 + 统计（与首页收藏区共享同一份状态；重复调用幂等）
    SyncRouteNotifier.instance.addListener(_onSyncRouteChanged);
    SyncRouteNotifier.instance.ensureLoaded();
  }

  void _onSyncRouteChanged() {
    if (mounted) setState(() {});
  }

  /// 当前的同步线路（来自共享状态）。
  int _routeOf(SyncPlatform platform) =>
      SyncRouteNotifier.instance.routeOf(platform);

  @override
  void dispose() {
    UserProfileNotifier.instance.removeListener(_onUserProfileChanged);
    SyncRouteNotifier.instance.removeListener(_onSyncRouteChanged);
    super.dispose();
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

  Future<void> _loadCachedAvatarId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedId = prefs.getInt('selectedAvatarId');
      if (cachedId != null && mounted) {
        setState(() => _selectedAvatarId = cachedId);
      }
    } catch (e) {
      debugPrint('加载缓存头像ID失败: $e');
    }
  }

  Future<void> _saveAvatarId(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('selectedAvatarId', id);
    } catch (e) {
      debugPrint('保存头像ID失败: $e');
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
        onAvatarPicked: (id) async {
          await _saveAvatarId(id);
          if (mounted) setState(() => _selectedAvatarId = id);
          if (ctx.mounted) Navigator.of(ctx).pop();
        },
        onPlatePicked: (id) async {
          await _savePlateId(id);
          if (mounted) setState(() => _selectedPlateId = id);
          if (ctx.mounted) Navigator.of(ctx).pop();
        },
      ),
    ).then((_) => searchController.dispose());
  }

  // ===== 通用 =====

  void _open(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page))
          .then((_) => _loadProfile());

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
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
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
    if (_anyBusy) return;
    final request = await showRefreshDataDialog(context);
    if (request == null || !mounted) return;

    setState(() {
      _refreshing = true;
      _refreshText = '正在刷新数据...';
    });
    try {
      await executeRefreshData(request, onProgress: (p, t) {
        if (!mounted) return;
        setState(() => _refreshText = '$t $p%');
      });
      if (!mounted) return;
      Fluttertoast.showToast(msg: '数据刷新成功!');
    } on ProberException catch (e) {
      // 未授权 → 直接拉起授权页；其余按统一文案提示。
      // 与首页刷新入口共用 presentRefreshError，避免两边行为不一致。
      if (mounted) await presentRefreshError(e, qq: request.qq.trim());
    } catch (e) {
      if (mounted) await presentRefreshError(e, qq: request.qq.trim());
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
    if (_anyBusy) return;
    final request = await showAdvancedRefreshDataDialog(context);
    if (request == null || !mounted) return;

    setState(() {
      _refreshingAdvanced = true;
      _refreshAdvancedText = '正在刷新数据...';
    });
    try {
      await executeAdvancedRefreshData(
        request,
        onProgress: (p, t) {
          if (!mounted) return;
          setState(() => _refreshAdvancedText = '$t $p%');
        },
      );
      if (!mounted) return;
      Fluttertoast.showToast(msg: '数据刷新成功!');
    } on ProberException catch (e) {
      // 未授权 → 直接拉起授权页；其余按统一文案提示。
      // 与首页刷新入口共用 presentRefreshError，避免两边行为不一致。
      if (mounted) await presentRefreshError(e, qq: request.qq.trim());
    } catch (e) {
      if (mounted) await presentRefreshError(e, qq: request.qq.trim());
    } finally {
      if (mounted) {
        setState(() {
          _refreshingAdvanced = false;
          _refreshAdvancedText = '';
        });
      }
    }
  }

  /// 刷新 maidata：确认后进度直接显示在按钮上（不再弹转圈对话框）。
  Future<void> _refreshMaidata() async {
    if (_anyBusy) return;
    final isOnline = await ConnectivityService().hasConnection();
    if (!mounted) return;
    if (!isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前无网络连接，请联网后重试')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认刷新 maidata'),
        content: const Text('将清除所有 maidata 缓存并从服务器重新拉取全部数据，耗时可能较长。\n\n确定要刷新吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认刷新'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _refreshingMaidata = true;
      _maidataText = '正在刷新 maidata...';
    });
    try {
      await MaidataManager().fetchAndCacheFullMaidata();
      if (!mounted) return;
      Fluttertoast.showToast(msg: 'maidata 刷新完成');
    } catch (e) {
      debugPrint('刷新 maidata 失败：$e');
      if (mounted) Fluttertoast.showToast(msg: 'maidata 刷新失败：$e');
    } finally {
      if (mounted) {
        setState(() {
          _refreshingMaidata = false;
          _maidataText = '';
        });
      }
    }
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

  SyncCallbacks get _syncCallbacks => SyncCallbacks(
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
    await refreshBest50DataWithProgress(qq,
        (p, text) => onProgress(0.70 + p / 100 * 0.30, text),
        participateRankings: participateRankings, showNickname: showNickname);
    await _loadProfile();
  }

  /// 同步成绩到水鱼：输入（二维码 / 排行榜选项）在对话框完成，
  /// 点「开始同步」后对话框立即关闭，抓取 → 推送 → 刷新本地数据的进度
  /// 全部显示在「同步成绩到水鱼」这个按钮上。
  Future<void> _syncToDivingFishWithButton() async {
    if (_anyBusy) return;

    final prefs = await SharedPreferences.getInstance();
    final hasJwt =
        (prefs.getString(CacheKeyConstant.probeDivingFishToken) ?? '')
            .isNotEmpty;

    if (!hasJwt) {
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('提示'),
          content: const Text('请先登录你的水鱼账号，再使用同步功能。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('去登录'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      await SyncScoreDialogs.showDivingFishLoginDialog(context, _syncCallbacks);
      final prefs2 = await SharedPreferences.getInstance();
      final hasJwt2 =
          (prefs2.getString(CacheKeyConstant.probeDivingFishToken) ?? '')
              .isNotEmpty;
      if (!hasJwt2 || !mounted) return;
    }

    final bindQQ =
        prefs.getString(CacheKeyConstant.probeDivingFishBindQQ) ?? '';
    final cachedQQ = (await AccountStore.loadAll())['shuiyu']?.id;
    if (bindQQ.isNotEmpty && cachedQQ != null && bindQQ != cachedQQ) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('账号不匹配'),
          content: Text(
            '当前登录水鱼账号绑定的 QQ（$bindQQ）与本机缓存的 QQ（$cachedQQ）不一致。\n\n请先登出当前水鱼账号，登录正确的账号后再同步。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('确定'),
            ),
          ],
        ),
      );
      return;
    }

    if (!mounted) return;
    final input = await showDivingFishSyncInputDialog(context);
    if (input == null || !mounted) return;

    setState(() {
      _syncingDivingFish = true;
      _syncText = '正在同步成绩...';
    });
    // 记录本次同步耗时 / 成败（Redis，尽力而为）
    final stopwatch = Stopwatch()..start();
    var syncOk = false;
    // 缺 ImportToken 时会转交给对话框再走一遍完整流程（那一次由对话框上报），
    // 这里就不再记一条，免得同一次用户操作算成两条样本
    var handedOffToDialog = false;
    try {
      final outcome = await executeDivingFishSync(
        _syncCallbacks,
        input,
        onProgress: (p, t) {
          if (!mounted) return;
          setState(() => _syncText = '$t ${(p * 100).round()}%');
        },
      );
      syncOk = true;
      if (!mounted) return;
      Fluttertoast.showToast(
          msg: outcome.localDataRefreshed
              ? '同步完成！${outcome.exportedCount} 条成绩已同步，本地数据已刷新'
              : '同步完成！${outcome.exportedCount} 条成绩已推送到水鱼');
    } on SyncFlowException catch (e) {
      if (!mounted) return;
      Fluttertoast.showToast(msg: e.message);
      // 需要 ImportToken 时按钮上没法输入账号密码，回到原有的对话框完成绑定；
      // 二维码已经抓过一次，直接复用，避免让用户重新粘贴。
      if (e.message.contains('ImportToken')) {
        handedOffToDialog = true;
        await SyncScoreDialogs.showDivingFishSyncDialog(
          context,
          _syncCallbacks,
          presetQrCode: input.qrCode,
        );
      }
    } catch (e) {
      if (mounted) Fluttertoast.showToast(msg: '同步失败：$e');
    } finally {
      stopwatch.stop();
      if (!handedOffToDialog) {
        unawaited(SyncStatsService.record(
          line: SyncLine.scoreHub,
          platform: SyncPlatform.divingFish,
          durationMs: stopwatch.elapsedMilliseconds,
          ok: syncOk,
        ));
        SyncRouteNotifier.instance.refreshStatsSoon();
      }
      if (mounted) {
        setState(() {
          _syncingDivingFish = false;
          _syncText = '';
        });
      }
    }
  }

  /// 同步成绩到落雪：输入在对话框完成，进度显示在按钮上。
  Future<void> _syncToLuoXueWithButton() async {
    if (_anyBusy) return;
    final input = await showLuoXueSyncInputDialog(context);
    if (input == null || !mounted) return;

    setState(() {
      _syncingLuoXue = true;
      _luoXueText = '正在同步成绩...';
    });
    final stopwatch = Stopwatch()..start();
    var syncOk = false;
    try {
      final count = await executeLuoXueSync(input, onProgress: (p, t) {
        if (!mounted) return;
        setState(() => _luoXueText = '$t ${(p * 100).round()}%');
      });
      syncOk = true;
      if (!mounted) return;
      Fluttertoast.showToast(msg: '同步完成！共 $count 条成绩已导出到落雪');
    } on SyncFlowException catch (e) {
      if (mounted) Fluttertoast.showToast(msg: e.message);
    } catch (e) {
      if (mounted) Fluttertoast.showToast(msg: '同步失败：$e');
    } finally {
      stopwatch.stop();
      unawaited(SyncStatsService.record(
        line: SyncLine.scoreHub,
        platform: SyncPlatform.luoXue,
        durationMs: stopwatch.elapsedMilliseconds,
        ok: syncOk,
      ));
      SyncRouteNotifier.instance.refreshStatsSoon();
      if (mounted) {
        setState(() {
          _syncingLuoXue = false;
          _luoXueText = '';
        });
      }
    }
  }

  /// 同步成绩到 AWMC NET：**输入在对话框完成，等待进度显示在按钮上**
  /// ——与上面两个同步入口完全一致（早先是对话框里转圈等 30 多秒）。
  Future<void> _syncToAwmcNetWithButton() async {
    if (_anyBusy) return;
    final outcome = await AwmcNetSyncFlow.run(
      context,
      onBusy: (label) {
        if (!mounted) return;
        setState(() {
          _syncingAwmcNet = true;
          _awmcNetText = label;
        });
      },
      onIdle: () {
        if (!mounted) return;
        setState(() {
          _syncingAwmcNet = false;
          _awmcNetText = '';
        });
      },
    );
    if (!mounted || outcome.cancelled) return;
    Fluttertoast.showToast(msg: AwmcNetSyncFlow.toastFor(outcome));
  }

  void _loginDivingFish() {
    SyncScoreDialogs.showDivingFishLoginDialog(context, _syncCallbacks);
  }

  // ===== 线路2：通过 AWMC 网关同步 =====

  /// 线路2 同步到水鱼：二维码 + 网关令牌 → `/v1/user/music` + `/v1/update-fish`。
  Future<void> _syncToDivingFishViaAwmc() async {
    if (_anyBusy) return;
    final outcome = await AwmcSyncFlow.run(
      context,
      target: AwmcSyncTarget.divingFish,
      onBusy: (label) {
        if (!mounted) return;
        setState(() {
          _syncingDivingFish = true;
          _syncText = label;
        });
      },
      onIdle: () {
        if (!mounted) return;
        setState(() {
          _syncingDivingFish = false;
          _syncText = '';
        });
      },
    );
    if (!mounted || outcome.cancelled) return;
    if (outcome.ok) {
      Fluttertoast.showToast(
          msg: AwmcSyncFlow.successToast(AwmcSyncTarget.divingFish, outcome));
    } else if (outcome.message != null) {
      Fluttertoast.showToast(msg: outcome.message!);
    }
    // 统计是异步写进 Redis 的，稍等一下再刷新，让这一行尽快反映本次结果
    SyncRouteNotifier.instance.refreshStatsSoon();
  }

  /// 线路2 同步到落雪：二维码 + 网关令牌 → `/v1/user/music` + `/v1/update-lx`。
  Future<void> _syncToLuoXueViaAwmc() async {
    if (_anyBusy) return;
    final outcome = await AwmcSyncFlow.run(
      context,
      target: AwmcSyncTarget.luoXue,
      onBusy: (label) {
        if (!mounted) return;
        setState(() {
          _syncingLuoXue = true;
          _luoXueText = label;
        });
      },
      onIdle: () {
        if (!mounted) return;
        setState(() {
          _syncingLuoXue = false;
          _luoXueText = '';
        });
      },
    );
    if (!mounted || outcome.cancelled) return;
    if (outcome.ok) {
      Fluttertoast.showToast(
          msg: AwmcSyncFlow.successToast(AwmcSyncTarget.luoXue, outcome));
    } else if (outcome.message != null) {
      Fluttertoast.showToast(msg: outcome.message!);
    }
    SyncRouteNotifier.instance.refreshStatsSoon();
  }

  /// 登出水鱼账号：第一次点击进入「再次确认」态，第二次点击才真正执行；
  /// 清除水鱼账号相关的所有成绩 / 缓存（保留歌曲 / 收藏品等静态数据），
  /// 并通知共享 LoginStateNotifier 让监听者（"登录水鱼"按钮等）即时刷新。
  /// 进度显示在按钮上，不再弹模态对话框。
  Future<void> _logoutDivingFish() async {
    if (_loggingOut) return;
    if (!_logoutConfirming) {
      // 第一次点击：进入二次确认态；5 秒内未再点自动复位
      setState(() => _logoutConfirming = true);
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && _logoutConfirming && !_loggingOut) {
          setState(() => _logoutConfirming = false);
        }
      });
      return;
    }
    // 第二次点击：执行实际登出
    setState(() {
      _logoutConfirming = false;
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
      if (mounted) Fluttertoast.showToast(msg: '登出水鱼账号失败：$e');
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
              onPickTap: _showCollectionPicker,
            ),
            children: [
              HubSection(
                title: '数据与账号',
                icon: Icons.sync_rounded,
                subtitle: '登录水鱼 · 同步账号 · 数据备份 · 刷新缓存',
                // 10 个入口里「AWMC 网关」默认隐藏（FeatureFlags.awmcGateway）
                badgeCount: 9 + (FeatureFlags.awmcGateway ? 1 : 0),
                children: [
                  HubActionTile(
                    title: loggedIn ? '登出水鱼账号' : '登录水鱼',
                    subtitle: _logoutConfirming
                        ? '再次点击以确认登出'
                        : (loggedIn
                            ? '清除水鱼登录状态'
                            : '获取 ImportToken 以使用同步功能'),
                    icon: loggedIn ? Icons.logout_rounded : Icons.login_rounded,
                    isFavorited: _isFavorited(loggedIn ? '登出水鱼账号' : '登录水鱼'),
                    onToggleFavorite: () =>
                        _toggleFavorite(loggedIn ? '登出水鱼账号' : '登录水鱼'),
                    onTap: loggedIn ? _logoutDivingFish : _loginDivingFish,
                    loading: _loggingOut,
                    loadingText: _logoutText,
                    awaitingConfirm: _logoutConfirming,
                  ),
                  HubActionTile(
                    title: '同步成绩到水鱼',
                    subtitle: '扫码抓取并同步最新成绩',
                    icon: Icons.cloud_upload_outlined,
                    isFavorited: _isFavorited('同步成绩到水鱼'),
                    onToggleFavorite: () => _toggleFavorite('同步成绩到水鱼'),
                    onTap: _routeOf(SyncPlatform.divingFish) ==
                            SyncRouteStore.routeAwmc
                        ? _syncToDivingFishViaAwmc
                        : _syncToDivingFishWithButton,
                    loading: _syncingDivingFish,
                    loadingText: _syncText,
                    // 线路切换 + 统计：与首页「收藏的功能」区共用同一份状态
                    footer: SyncRouteFooter(
                      platform: SyncPlatform.divingFish,
                      enabled: !_anyBusy,
                    ),
                  ),
                  HubActionTile(
                    title: '同步成绩到落雪',
                    subtitle: '将本地成绩同步到落雪咖啡屋',
                    icon: Icons.cloud_sync_outlined,
                    isFavorited: _isFavorited('同步成绩到落雪'),
                    onToggleFavorite: () => _toggleFavorite('同步成绩到落雪'),
                    onTap: _routeOf(SyncPlatform.luoXue) ==
                            SyncRouteStore.routeAwmc
                        ? _syncToLuoXueViaAwmc
                        : _syncToLuoXueWithButton,
                    loading: _syncingLuoXue,
                    loadingText: _luoXueText,
                    footer: SyncRouteFooter(
                      platform: SyncPlatform.luoXue,
                      enabled: !_anyBusy,
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
                    onTap: _syncToAwmcNetWithButton,
                    loading: _syncingAwmcNet,
                    loadingText: _awmcNetText,
                    // 统计行上提一点贴紧按钮：tile 底部本来就空着约 23px，
                    // 一行小字挂在那里会显得离按钮太远（见 SyncStatsFooter.footerLift）
                    footerLift: SyncStatsFooter.footerLift,
                    footer: const SyncStatsFooter(
                      slot: (SyncLine.direct, SyncPlatform.awmc),
                    ),
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
                    disabled: _refreshingAdvanced,
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
                    disabled: _refreshing,
                  ),
                  HubActionTile(
                    title: '刷新 maidata',
                    subtitle: '手动刷新所有 maidata 缓存',
                    icon: Icons.cleaning_services_outlined,
                    isFavorited: _isFavorited('刷新 maidata'),
                    onToggleFavorite: () => _toggleFavorite('刷新 maidata'),
                    onTap: _refreshMaidata,
                    loading: _refreshingMaidata,
                    loadingText: _maidataText,
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
                badgeCount: 5,
                children: [
                  HubActionTile(
                    title: '主题与背景',
                    subtitle: '调整主题色、模式和背景图',
                    icon: Icons.palette_outlined,
                    isFavorited: _isFavorited('主题与背景'),
                    onToggleFavorite: () => _toggleFavorite('主题与背景'),
                    onTap: () => _open(context, const SettingsPage()),
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
                    onTap: () => _launchExternal(
                        context, AppLinks.surveyUrl, '问卷链接'),
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

  const _MeProfileBanner({
    required this.selectedAvatarId,
    required this.nickname,
    required this.onPickTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final displayName = nickname.isNotEmpty ? nickname : kUnsetNicknameLabel;

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
                    child: CachedNetworkImage(
                      imageUrl:
                          'https://assets2.lxns.net/maimai/icon/$selectedAvatarId.png',
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 72,
                        height: 72,
                        color: scheme.primaryContainer,
                        child: Icon(
                          Icons.person,
                          color: scheme.onPrimaryContainer,
                          size: 36,
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
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
                    Text(
                      '登录水鱼后同步你的成绩数据',
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
