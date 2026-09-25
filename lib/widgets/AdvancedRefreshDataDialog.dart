import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constant/CacheKeyConstant.dart';
import '../manager/DivingFishProbeManager.dart';
import '../manager/DivingFish/DivingFishOAuthManager.dart';
import '../manager/LuoXue/LuoXueUserPlayDataManager.dart';
import '../service/ConnectivityService.dart';
import '../service/AccountStore.dart';
import '../utils/AppTheme.dart';
import '../utils/ApiClient.dart';
import '../utils/CacheSourceRegistry.dart';
import 'RefreshDataDialog.dart'
    show CurrentDataSourceNotifier, RefreshDataRequest, RefreshDataSource;
import 'DivingFishAccountSection.dart';

/// 高级模式"刷新数据"对话框的入口。
///
/// 与旧版 `_RefreshDataDialog` 的差别：
///   - 同样的"当前数据源 / QQ 或授权码 / 排行榜选项"区
///   - 用一组复选框替换"强制完整刷新"，每条对应一个缓存源（来自 [CacheSourceRegistry]）
///   - 每条旁边显示剩余有效期 + 一个测试连通性的按钮
///
/// 返回 [RefreshDataRequest]，其 [RefreshDataRequest.forceSourceIds] 非空（高级模式标识）。
Future<RefreshDataRequest?> showAdvancedRefreshDataDialog(
  BuildContext context, {
  RefreshDataSource? initialSource,
}) async {
  await CurrentDataSourceNotifier.load();
  final prefs = await SharedPreferences.getInstance();
  final jwt = prefs.getString(CacheKeyConstant.probeDivingFishToken) ?? '';
  final bindQQ = prefs.getString(CacheKeyConstant.probeDivingFishBindQQ) ?? '';

  // AWMC NET 的 QQ 取自它自己的账号存档，不用共用的 cachedQQ
  // （活动槽里的 cachedQQ 此刻可能是另一个账号的 QQ）。
  final metas = await AccountStore.loadAll();
  final awmcQQ = metas[RefreshDataSource.awmc.key]?.id ?? '';

  if (!context.mounted) return null;

  return showDialog<RefreshDataRequest>(
    context: context,
    builder: (_) => _AdvancedRefreshDataDialog(
      // 只传「有没有登录」：登录了但没填 QQ 要单独提示，见 DivingFishQqState
      hasDivingFishLogin: jwt.isNotEmpty,
      bindQQ: bindQQ,
      awmcQQ: awmcQQ,
      initialSource: initialSource,
    ),
  );
}

/// 单条连通性测试结果。
class _TestResult {
  final bool success;
  final int? statusCode;
  final int latencyMs;
  final String? error;
  const _TestResult({
    required this.success,
    required this.statusCode,
    required this.latencyMs,
    this.error,
  });
}

class _AdvancedRefreshDataDialog extends StatefulWidget {
  /// 只表示「有没有登录水鱼」（JWT 非空）；「登录了但没填 QQ」是另一档，见 [DivingFishQqState]。
  final bool hasDivingFishLogin;

  /// 从水鱼 `/player/profile` 读到的 `bind_qq`（只认可信来源，不使用 `cachedQQ`）。
  final String bindQQ;

  /// AWMC NET 账号存档里的 QQ（按源区分，不会串到别的账号）。
  final String awmcQQ;

  /// 打开对话框时预选的数据源（账号切换面板「去刷新」时传入）。
  final RefreshDataSource? initialSource;

  const _AdvancedRefreshDataDialog({
    required this.hasDivingFishLogin,
    required this.bindQQ,
    required this.awmcQQ,
    this.initialSource,
  });

  @override
  State<_AdvancedRefreshDataDialog> createState() =>
      _AdvancedRefreshDataDialogState();
}

class _AdvancedRefreshDataDialogState
    extends State<_AdvancedRefreshDataDialog> {
  late RefreshDataSource _currentDataSource;
  final TextEditingController _authCodeController = TextEditingController();

  /// AWMC NET 单独一个 QQ 输入框（不复用水鱼那个只读的「已绑定 QQ」框）。
  final TextEditingController _awmcQqController = TextEditingController();

  /// 当前生效的水鱼 QQ（「我已填好，重新读取」后可变）。
  late String _bindQQ = widget.bindQQ;

  /// 正在重新读取水鱼账号里的「绑定 QQ 号」。
  bool _reloadingQq = false;

  bool? _isAuthorized;
  bool _isCheckingAuth = false;

  /// 已经把用户送去授权页、正等他回来点「重新检测」。
  bool _consentPending = false;

  /// 正在手动重新检测授权状态。
  bool _recheckingAuth = false;

  bool _participateRankings = false;
  bool _showNickname = false;

  /// 用户勾选要强制刷新的缓存源 ID 集合。默认空集（全不勾选）；在 initState
  /// 里异步加载上次保存的勾选，被持久化到 SharedPreferences（key 见
  /// CacheKeyConstant.advancedRefreshForceSources）。
  late Set<String> _checkedIds;

  /// 每个缓存源当前显示的剩余有效期文案（异步加载）
  late Map<String, String> _validities;

  /// 正在测试的缓存源 ID（同一时刻只允许一个）
  String? _testingId;

  /// 每个缓存源最近的连通性测试结果
  final Map<String, _TestResult> _testResults = {};

  @override
  void initState() {
    super.initState();
    _currentDataSource =
        widget.initialSource ?? CurrentDataSourceNotifier.instance.value;
    _awmcQqController.text = widget.awmcQQ;
    _validities = {for (final s in CacheSourceRegistry.all) s.id: '加载中…'};
    _checkedIds = <String>{}; // 同步初始化，避免 late 在 build 之前未赋值
    _loadRankingSettings();
    _loadAllValidities();
    _loadCheckedIds();
    if (_bindQQ.isNotEmpty) {
      _checkAuthorization();
    }
  }

  @override
  void dispose() {
    _authCodeController.dispose();
    _awmcQqController.dispose();
    super.dispose();
  }

  /// 本次选中的数据源要用的 QQ（水鱼取水鱼的绑定 QQ，AWMC NET 取它自己的输入框）。
  String get _activeQq => _currentDataSource == RefreshDataSource.awmc
      ? _awmcQqController.text.trim()
      : _bindQQ;

  Future<void> _checkAuthorization() async {
    final qq = _bindQQ;
    if (qq.isEmpty) return;
    setState(() => _isCheckingAuth = true);
    final result = await DivingFishOAuthManager().checkAuthorization(qq);
    if (!mounted) return;
    setState(() {
      _isAuthorized = result;
      _isCheckingAuth = false;
    });
  }

  /// 「我已填好，重新读取」：重新读一次水鱼账号上的 `bind_qq`（见 RefreshDataDialog 同名方法）。
  Future<void> _reloadBindQq() async {
    setState(() => _reloadingQq = true);
    String? qq;
    try {
      qq = await DivingFishProbeManager().fetchBindQQ();
    } catch (e) {
      debugPrint('重新读取水鱼绑定 QQ 失败: $e');
    }
    if (!mounted) return;
    setState(() {
      _reloadingQq = false;
      if (qq != null && qq.isNotEmpty) _bindQQ = qq;
    });

    if (qq == null || qq.isEmpty) {
      Fluttertoast.showToast(msg: '还是没读到 QQ 号。请确认已在水鱼官网保存，或重新登录一次水鱼账号');
      return;
    }
    Fluttertoast.showToast(msg: '已读到绑定 QQ：$qq');
    await _checkAuthorization();
  }

  /// 「去授权」：发起设备码绑定并打开授权页（不自动重查，见下方注释）。
  Future<void> _startAuthorization() async {
    final qq = _bindQQ;
    if (qq.isEmpty) {
      Fluttertoast.showToast(msg: '未找到 QQ 号');
      return;
    }
    setState(() => _recheckingAuth = true);
    final ok = await DivingFishOAuthManager().openBindingLink(qq);
    if (!mounted) return;
    setState(() {
      _recheckingAuth = false;
      if (ok) _consentPending = true;
    });
    Fluttertoast.showToast(
      msg: ok ? '已打开授权页，完成授权后回到这里点「我已授权，重新检测」' : '发起授权失败，请稍后重试',
    );
  }

  /// 「我已授权，重新检测」：显式重查一次授权状态。
  Future<void> _recheckAuthorization() async {
    final qq = _bindQQ;
    if (qq.isEmpty) {
      Fluttertoast.showToast(msg: '未找到 QQ 号');
      return;
    }
    setState(() => _recheckingAuth = true);
    final result = await DivingFishOAuthManager().checkAuthorization(qq);
    if (!mounted) return;
    setState(() {
      _recheckingAuth = false;
      _isAuthorized = result;
      if (result == true) _consentPending = false;
    });
    if (result == true) {
      Fluttertoast.showToast(msg: '授权成功，现在可以刷新数据了');
    } else if (result == false) {
      Fluttertoast.showToast(msg: '还没检测到授权，请确认在浏览器里点了「同意」');
    } else {
      Fluttertoast.showToast(msg: '检测失败，请检查网络后重试');
    }
  }

  Future<void> _loadRankingSettings() async {
    final source = _currentDataSource;
    final settings = await AccountStore.settingsFor(source);
    if (!mounted || source != _currentDataSource) return;
    setState(() {
      _participateRankings =
          settings[CacheKeyConstant.participateRankings] == true;
      _showNickname = settings[CacheKeyConstant.showNickname] == true;
    });
  }

  /// 加载上次保存的勾选集合；为空则保持空集（全不勾选）。
  Future<void> _loadCheckedIds() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final saved =
        prefs.getStringList(CacheKeyConstant.advancedRefreshForceSources);
    if (saved == null) return; // 首次使用，保持空集
    setState(() {
      _checkedIds = saved.toSet();
    });
  }

  Future<void> _loadAllValidities() async {
    // 并行预取所有缓存源的剩余有效期
    final futures = <Future<void>>[];
    for (final source in CacheSourceRegistry.all) {
      futures.add(() async {
        final v = await formatRemainingValidity(source);
        if (!mounted) return;
        setState(() => _validities[source.id] = v);
      }());
    }
    await Future.wait(futures);
  }

  /// 测试 [sourceId] 对应 API 的连通性：发 GET、测延迟、显示 ✓/✗ + 状态码/延迟。
  Future<void> _testSource(String sourceId) async {
    final source = CacheSourceRegistry.all.firstWhere((s) => s.id == sourceId);
    setState(() => _testingId = sourceId);
    final sw = Stopwatch()..start();
    try {
      final response = await ApiClient.get(
        Uri.parse(source.apiUrl),
        timeout: const Duration(seconds: 8),
      );
      sw.stop();
      if (!mounted) return;
      final ok = response.statusCode >= 200 && response.statusCode < 400;
      setState(() {
        _testResults[sourceId] = _TestResult(
          success: ok,
          statusCode: response.statusCode,
          latencyMs: sw.elapsedMilliseconds,
          error: ok ? null : 'HTTP ${response.statusCode}',
        );
        _testingId = null;
      });
    } catch (e) {
      sw.stop();
      if (!mounted) return;
      setState(() {
        _testResults[sourceId] = _TestResult(
          success: false,
          statusCode: null,
          latencyMs: sw.elapsedMilliseconds,
          error: e.toString().split('\n').first,
        );
        _testingId = null;
      });
    }
  }

  Future<void> _onConfirm() async {
    // 水鱼：三态分别给不同交代（同 RefreshDataDialog）
    if (_currentDataSource == RefreshDataSource.shuiyu) {
      switch (resolveDivingFishQqState(
        loggedIn: widget.hasDivingFishLogin,
        bindQq: _bindQQ,
      )) {
        case DivingFishQqState.notLoggedIn:
          Fluttertoast.showToast(msg: '请先在「系统 → 登录水鱼」登录水鱼账号');
          return;
        case DivingFishQqState.noBindQq:
          Fluttertoast.showToast(msg: '你的水鱼账号还没绑定 QQ 号，请先到水鱼官网「编辑个人资料」里填上');
          return;
        case DivingFishQqState.bound:
          break;
      }
    }
    // 落雪：没填授权码就点确认，原来会静默地「什么都不做但报成功」
    if (_currentDataSource == RefreshDataSource.luoxue &&
        _authCodeController.text.trim().isEmpty) {
      Fluttertoast.showToast(msg: '请先填写落雪授权码');
      return;
    }
    // AWMC NET 无需登录，但必须有 QQ 号才查得到
    if (_currentDataSource == RefreshDataSource.awmc) {
      final qq = _awmcQqController.text.trim();
      if (qq.isEmpty) {
        Fluttertoast.showToast(msg: '请输入 AWMC NET 的 QQ 号');
        return;
      }
      if (!RegExp(r'^\d{5,12}$').hasMatch(qq)) {
        Fluttertoast.showToast(msg: 'QQ 号格式不对（应为 5–12 位数字）');
        return;
      }
    }
    // 离线检查
    final isOnline = await ConnectivityService().hasConnection();
    if (!isOnline) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('当前无网络连接，无法刷新数据。请联网后重试。'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    if (!mounted) return;

    // 持久化本次勾选，下次打开对话框时自动恢复
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      CacheKeyConstant.advancedRefreshForceSources,
      _checkedIds.toList(),
    );

    final request = RefreshDataRequest(
      dataSource: _currentDataSource,
      qq: _activeQq,
      authCode: _authCodeController.text.trim(),
      participateRankings: _participateRankings,
      showNickname: _showNickname,
      forceFullRefresh: false, // 高级模式不依赖此字段
      forceSourceIds: Set<String>.from(_checkedIds),
    );
    if (mounted) Navigator.of(context).pop(request);
  }

  // ====================================================================
  // UI 构建
  // ====================================================================

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return AlertDialog(
      title: const Text('刷新数据（高级）'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDataSourceRow(),
              const SizedBox(height: 12),
              if (_currentDataSource == RefreshDataSource.shuiyu)
                _buildShuiyuPanel(brightness),
              if (_currentDataSource == RefreshDataSource.luoxue)
                _buildLuoXuePanel(brightness),
              if (_currentDataSource == RefreshDataSource.awmc)
                _buildAwmcPanel(brightness),
              _buildRankingOptions(brightness),
              const SizedBox(height: 16),
              _buildCacheSourceSection(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: _onConfirm,
          child: const Text('确认'),
        ),
      ],
    );
  }

  Widget _buildDataSourceRow() {
    // 三个选项在窄屏一行放不下（还有「当前数据源：」标题），
    // 所以标题单独一行，避免 RenderFlex overflow。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('当前数据源：'),
        const SizedBox(height: 6),
        ToggleButtons(
          constraints: const BoxConstraints(minHeight: 30, minWidth: 54),
          isSelected: [
            for (final source in RefreshDataSource.values)
              _currentDataSource == source,
          ],
          onPressed: (index) {
            // 只选「本次要刷新的数据源」；真正的切换由 executeAdvancedRefreshData
            // 里的 prepareForRefresh 完成，避免活动槽与数据源不一致。
            setState(() {
              _currentDataSource = RefreshDataSource.values[index];
              _authCodeController.clear();
            });
            _loadRankingSettings();
          },
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              child: Text('水鱼'),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              child: Text('落雪'),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              child: Text('AWMC NET'),
            ),
          ],
        ),
      ],
    );
  }

  /// AWMC NET.（net.wmc.pub）面板 —— 无需登录，只填 QQ 号。
  Widget _buildAwmcPanel(Brightness brightness) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _awmcQqController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'QQ 号',
            hintText: '输入已在 AWMC NET 绑定过的 QQ 号',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'AWMC NET 按 QQ 号公开查询成绩，无需登录或授权。\n'
          '前提是该 QQ 已在 net.wmc.pub 绑定并上传过成绩。',
          style: TextStyle(fontSize: 12, color: AppColors.greyHint(brightness)),
        ),
      ],
    );
  }

  /// 水鱼面板：整个委托给共享的 [DivingFishAccountSection]（同 RefreshDataDialog）。
  Widget _buildShuiyuPanel(Brightness brightness) {
    return DivingFishAccountSection(
      state: resolveDivingFishQqState(
        loggedIn: widget.hasDivingFishLogin,
        bindQq: _bindQQ,
      ),
      qq: _bindQQ,
      authorized: _isAuthorized,
      checkingAuth: _isCheckingAuth,
      consentPending: _consentPending,
      recheckingAuth: _recheckingAuth,
      reloadingQq: _reloadingQq,
      onStartAuthorization: _startAuthorization,
      onRecheckAuthorization: _recheckAuthorization,
      onReloadQq: _reloadBindQq,
    );
  }

  Widget _buildLuoXuePanel(Brightness brightness) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton(
          onPressed: () async {
            final url = LuoXueUserPlayDataManager().getAuthorizationUrl();
            try {
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(Uri.parse(url),
                    mode: LaunchMode.externalApplication);
              } else if (mounted) {
                _launchUrlFallback(url);
              }
            } catch (e) {
              debugPrint('打开落雪授权链接失败: $e');
              if (mounted) _launchUrlFallback(url);
            }
          },
          child: const Text('点击授权'),
        ),
        const SizedBox(height: 8),
        Text('授权后复制页面上显示的授权码，粘贴到下方输入框',
            style:
                TextStyle(fontSize: 12, color: AppColors.greyHint(brightness))),
        const SizedBox(height: 8),
        TextField(
          controller: _authCodeController,
          decoration: const InputDecoration(
            labelText: '请输入授权码',
            hintText: '粘贴授权码',
          ),
        ),
      ],
    );
  }

  void _launchUrlFallback(String url) {
    Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('无法打开浏览器，链接已复制到剪贴板，请手动粘贴到浏览器打开'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  Widget _buildRankingOptions(Brightness brightness) {
    return Column(
      children: [
        const SizedBox(height: 16),
        CheckboxListTile(
          title: const Text('参与排行榜'),
          value: _participateRankings,
          onChanged: (value) {
            setState(() {
              _participateRankings = value ?? false;
              if (!_participateRankings) _showNickname = false;
            });
          },
          controlAffinity: ListTileControlAffinity.leading,
        ),
        if (_participateRankings)
          CheckboxListTile(
            title: const Text('展示昵称（不勾选则显示为匿名用户）'),
            value: _showNickname,
            onChanged: (value) {
              setState(() => _showNickname = value ?? false);
            },
            controlAffinity: ListTileControlAffinity.leading,
          ),
      ],
    );
  }

  /// 新增：13 行"强制刷新缓存数据"列表。
  Widget _buildCacheSourceSection() {
    final brightness = Theme.of(context).brightness;
    final mutedColor = AppColors.greyHint(brightness);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('强制刷新缓存数据',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const Spacer(),
            TextButton(
              onPressed: () {
                setState(() {
                  if (_checkedIds.length == CacheSourceRegistry.all.length) {
                    _checkedIds.clear();
                  } else {
                    _checkedIds
                      ..clear()
                      ..addAll(CacheSourceRegistry.all.map((s) => s.id));
                  }
                });
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _checkedIds.length == CacheSourceRegistry.all.length
                    ? '全不选'
                    : '全选',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '勾选 = 在本次刷新中忽略该缓存，强制走网络；未勾选 = 命中缓存则跳过。',
          style: TextStyle(fontSize: 11, color: mutedColor),
        ),
        const SizedBox(height: 8),
        // 分隔小标题：曲目 / 标签 / 别名 / 收藏品 / 元数据 / maidata
        ..._groupedSources().entries.map(
              (entry) => _buildGroup(entry.key, entry.value),
            ),
      ],
    );
  }

  /// 按语义分组（用于在对话框里加小标题），但实际 force-refresh 按 groupKey。
  Map<String, List<CacheSourceInfo>> _groupedSources() {
    return {
      '歌曲与谱面': CacheSourceRegistry.all
          .where((s) => s.groupKey == 'songs' || s.groupKey == 'diff')
          .toList(),
      '标签与别名': CacheSourceRegistry.all
          .where((s) => s.groupKey == 'tags' || s.groupKey == 'aliases')
          .toList(),
      '收藏品': CacheSourceRegistry.all
          .where((s) => s.groupKey == 'collections')
          .toList(),
      '元数据与辅助': CacheSourceRegistry.all
          .where((s) => s.groupKey == 'union' || s.groupKey == 'maidata')
          .toList(),
    };
  }

  Widget _buildGroup(String title, List<CacheSourceInfo> sources) {
    final brightness = Theme.of(context).brightness;
    final mutedColor = AppColors.greyHint(brightness);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(title,
              style: TextStyle(
                fontSize: 12,
                color: mutedColor,
                fontWeight: FontWeight.w600,
              )),
        ),
        ...sources.map((s) => _buildSourceRow(s)),
      ],
    );
  }

  Widget _buildSourceRow(CacheSourceInfo source) {
    final brightness = Theme.of(context).brightness;
    final mutedColor = AppColors.greyHint(brightness);
    final result = _testResults[source.id];
    final isTesting = _testingId == source.id;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 复选框
          Checkbox(
            value: _checkedIds.contains(source.id),
            onChanged: (v) {
              setState(() {
                if (v == true) {
                  _checkedIds.add(source.id);
                } else {
                  _checkedIds.remove(source.id);
                }
              });
            },
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 4),
          // 名称 + 描述 + 有效期（独立一行）+ 测试按钮
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source.displayName,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  _validities[source.id] ?? '加载中…',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: (_validities[source.id] ?? '').startsWith('已过期')
                        ? Colors.orange
                        : mutedColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${source.description}${result != null ? " · ${_formatTestResult(result)}" : ""}',
                  style: TextStyle(fontSize: 11, color: mutedColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 测试按钮
          _buildTestButton(source.id, result, isTesting),
        ],
      ),
    );
  }

  String _formatTestResult(_TestResult r) {
    if (r.success) {
      return '✓ ${r.statusCode} ${r.latencyMs}ms';
    }
    return '✗ ${r.error ?? '失败'} (${r.latencyMs}ms)';
  }

  Widget _buildTestButton(
      String sourceId, _TestResult? result, bool isTesting) {
    if (isTesting) {
      return const SizedBox(
        width: 28,
        height: 28,
        child: Padding(
          padding: EdgeInsets.all(6),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (result != null && result.success) {
      // 成功：✓ 在上，延迟在下（点击重测）
      return InkWell(
        onTap: () => _testSource(sourceId),
        borderRadius: BorderRadius.circular(6),
        child: Tooltip(
          message: '连通：${result.statusCode} · ${result.latencyMs}ms',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 16),
                const SizedBox(height: 2),
                Text(
                  '${result.latencyMs}ms',
                  style: const TextStyle(fontSize: 11, color: Colors.green),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (result != null) {
      // 失败：保留错误图标（点击重测），延迟 tooltip 中可见
      return IconButton(
        tooltip: '失败：${result.error ?? '未知错误'} (${result.latencyMs}ms)',
        icon: const Icon(Icons.error, color: Colors.red, size: 20),
        onPressed: () => _testSource(sourceId),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      );
    }
    return TextButton(
      onPressed: () => _testSource(sourceId),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        minimumSize: const Size(0, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: const Text('测试', style: TextStyle(fontSize: 12)),
    );
  }
}
