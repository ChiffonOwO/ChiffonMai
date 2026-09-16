import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constant/CacheKeyConstant.dart';
import '../manager/DivingFish/DivingFishOAuthManager.dart';
import '../manager/LuoXue/LuoXueUserPlayDataManager.dart';
import '../service/ConnectivityService.dart';
import '../utils/AppTheme.dart';
import '../utils/ApiClient.dart';
import '../utils/CacheSourceRegistry.dart';
import 'RefreshDataDialog.dart' show CurrentDataSourceNotifier, RefreshDataRequest, RefreshDataSource;

/// 高级模式"刷新数据"对话框的入口。
///
/// 与旧版 `_RefreshDataDialog` 的差别：
///   - 同样的"当前数据源 / QQ 或授权码 / 排行榜选项"区
///   - 用一组复选框替换"强制完整刷新"，每条对应一个缓存源（来自 [CacheSourceRegistry]）
///   - 每条旁边显示剩余有效期 + 一个测试连通性的按钮
///
/// 返回 [RefreshDataRequest]，其 [RefreshDataRequest.forceSourceIds] 非空（高级模式标识）。
Future<RefreshDataRequest?> showAdvancedRefreshDataDialog(BuildContext context) async {
  await CurrentDataSourceNotifier.load();
  final prefs = await SharedPreferences.getInstance();
  final jwt = prefs.getString(CacheKeyConstant.probeDivingFishToken) ?? '';
  final bindQQ = prefs.getString(CacheKeyConstant.probeDivingFishBindQQ) ?? '';
  final isDivingFishLoggedIn = jwt.isNotEmpty && bindQQ.isNotEmpty;
  final cachedQQ = prefs.getString('cachedQQ') ?? '';

  if (!context.mounted) return null;

  return showDialog<RefreshDataRequest>(
    context: context,
    builder: (_) => _AdvancedRefreshDataDialog(
      isDivingFishLoggedIn: isDivingFishLoggedIn,
      bindQQ: bindQQ,
      cachedQQ: cachedQQ,
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
  final bool isDivingFishLoggedIn;
  final String bindQQ;
  final String cachedQQ;

  const _AdvancedRefreshDataDialog({
    required this.isDivingFishLoggedIn,
    required this.bindQQ,
    required this.cachedQQ,
  });

  @override
  State<_AdvancedRefreshDataDialog> createState() =>
      _AdvancedRefreshDataDialogState();
}

class _AdvancedRefreshDataDialogState
    extends State<_AdvancedRefreshDataDialog> {
  late RefreshDataSource _currentDataSource;
  final TextEditingController _qqController = TextEditingController();
  final TextEditingController _authCodeController = TextEditingController();

  bool? _isAuthorized;
  bool _isCheckingAuth = false;

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
    _currentDataSource = CurrentDataSourceNotifier.instance.value;
    _qqController.text =
        widget.bindQQ.isNotEmpty ? widget.bindQQ : widget.cachedQQ;
    _validities = {for (final s in CacheSourceRegistry.all) s.id: '加载中…'};
    _checkedIds = <String>{}; // 同步初始化，避免 late 在 build 之前未赋值
    _loadRankingSettings();
    _loadAllValidities();
    _loadCheckedIds();
    if (widget.isDivingFishLoggedIn) {
      _isCheckingAuth = true;
      DivingFishOAuthManager().checkAuthorization(widget.bindQQ).then((result) {
        if (!mounted) return;
        setState(() {
          _isAuthorized = result;
          _isCheckingAuth = false;
        });
      });
    }
  }

  @override
  void dispose() {
    _qqController.dispose();
    _authCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadRankingSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _participateRankings =
          prefs.getBool(CacheKeyConstant.participateRankings) ?? false;
      _showNickname = prefs.getBool(CacheKeyConstant.showNickname) ?? false;
    });
  }

  /// 加载上次保存的勾选集合；为空则保持空集（全不勾选）。
  Future<void> _loadCheckedIds() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final saved = prefs.getStringList(CacheKeyConstant.advancedRefreshForceSources);
    if (saved == null) return; // 首次使用，保持空集
    setState(() {
      _checkedIds = saved.toSet();
    });
  }

  Future<void> _saveRankingSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
        CacheKeyConstant.participateRankings, _participateRankings);
    await prefs.setBool(CacheKeyConstant.showNickname, _showNickname);
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
    // 校验：未登录水鱼就不能刷新水鱼
    if (_currentDataSource == RefreshDataSource.shuiyu &&
        !widget.isDivingFishLoggedIn) {
      Fluttertoast.showToast(msg: '请先登录水鱼账号后再刷新数据');
      return;
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

    await _saveRankingSettings();

    // 持久化本次勾选，下次打开对话框时自动恢复
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      CacheKeyConstant.advancedRefreshForceSources,
      _checkedIds.toList(),
    );

    final request = RefreshDataRequest(
      dataSource: _currentDataSource,
      qq: _qqController.text.trim(),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('当前数据源：'),
        const SizedBox(width: 8),
        ToggleButtons(
          constraints:
              const BoxConstraints(minHeight: 28, minWidth: 50),
          isSelected: [
            _currentDataSource == RefreshDataSource.shuiyu,
            _currentDataSource == RefreshDataSource.luoxue,
          ],
          onPressed: (index) {
            // 只选「本次要刷新的数据源」；真正的切换由 executeAdvancedRefreshData
            // 里的 prepareForRefresh 完成，避免活动槽与数据源不一致。
            final newSource = index == 0
                ? RefreshDataSource.shuiyu
                : RefreshDataSource.luoxue;
            setState(() {
              _currentDataSource = newSource;
              _authCodeController.clear();
            });
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
          ],
        ),
      ],
    );
  }

  Widget _buildShuiyuPanel(Brightness brightness) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _qqController,
          keyboardType: TextInputType.number,
          enabled: false,
          decoration: InputDecoration(
            labelText: widget.isDivingFishLoggedIn ? '已绑定QQ号' : '请先登录水鱼账号',
            hintText: widget.isDivingFishLoggedIn ? widget.bindQQ : '登录后自动填充',
            suffixIcon: widget.isDivingFishLoggedIn
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Icon(Icons.warning_amber, color: Colors.orange),
          ),
        ),
        if (!widget.isDivingFishLoggedIn)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '请先在「水鱼数据同步」中登录水鱼账号，再进行数据刷新',
              style: TextStyle(
                  fontSize: 12, color: AppColors.warningOrange(brightness)),
            ),
          ),
        if (widget.isDivingFishLoggedIn)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _isCheckingAuth
                ? Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text('正在检查授权状态...',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.greyHint(brightness))),
                    ],
                  )
                : (_isAuthorized == true
                    ? Row(
                        children: [
                          Icon(Icons.check_circle,
                              size: 16,
                              color: AppColors.successGreen(brightness)),
                          const SizedBox(width: 6),
                          Text('已授权',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.successGreen(brightness))),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: Text(
                              '读取成绩需先授权本应用，未授权时刷新会失败',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.greyHint(brightness)),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final qq = _qqController.text.trim();
                              if (qq.isEmpty) {
                                Fluttertoast.showToast(msg: '未找到 QQ 号');
                                return;
                              }
                              final ok = await DivingFishOAuthManager()
                                  .openBindingLink(qq);
                              if (!mounted) return;
                              Fluttertoast.showToast(
                                  msg: ok
                                      ? '已打开授权链接，请在浏览器中完成授权后重新刷新'
                                      : '发起授权失败，请稍后重试');
                              if (ok) {
                                final authResult = await DivingFishOAuthManager()
                                    .checkAuthorization(qq);
                                if (!mounted) return;
                                setState(() => _isAuthorized = authResult);
                              }
                            },
                            child: const Text('去授权'),
                          ),
                        ],
                      )),
          ),
      ],
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
            style: TextStyle(
                fontSize: 12, color: AppColors.greyHint(brightness))),
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
            _saveRankingSettings();
          },
          controlAffinity: ListTileControlAffinity.leading,
        ),
        if (_participateRankings)
          CheckboxListTile(
            title: const Text('展示昵称（不勾选则显示为匿名用户）'),
            value: _showNickname,
            onChanged: (value) {
              setState(() => _showNickname = value ?? false);
              _saveRankingSettings();
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
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
          .where((s) =>
              s.groupKey == 'union' || s.groupKey == 'maidata')
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

  Widget _buildTestButton(String sourceId, _TestResult? result, bool isTesting) {
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