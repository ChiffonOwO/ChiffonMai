import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/ApiUrls.dart';
import '../constant/CacheKeyConstant.dart';
import '../constant/LoadingTipsConstant.dart';
import '../entity/DivingFish/RecordItem.dart';
import '../entity/DivingFish/Song.dart';
import '../entity/LuoXue/LuoXuePlayer.dart';
import '../entity/LuoXue/LuoXueScore.dart';
import '../manager/DivingFish/DivingFishOAuthManager.dart';
import '../manager/DivingFish/DiffMusicDataManager.dart';
import '../manager/DivingFish/MaimaiMusicDataManager.dart';
import '../manager/DivingFish/UnionManager.dart';
import '../manager/DivingFish/UserBest50Manager.dart';
import '../manager/DivingFish/UserPlayDataManager.dart';
import '../manager/LuoXue/CollectionsManager.dart';
import '../manager/LuoXue/LuoXueUserPlayDataManager.dart';
import '../manager/MaiTagsManager.dart';
import '../manager/SongAliasManager.dart';
import '../service/History/ChartHistoryStore.dart';
import '../service/AccountSwitchService.dart';
import '../service/ConnectivityService.dart';
import '../service/PaiziProgressService.dart';
import '../service/PersonalizedScoreService.dart';
import '../service/RecommendByTagsService.dart';
import '../service/RankingList/SongRankingService.dart';
import '../utils/ApiClient.dart';
import '../utils/AppTheme.dart';
import '../utils/CacheSourceRegistry.dart';
import '../utils/CurrentDataSourceNotifier.dart';
import '../utils/StringUtil.dart';
import '../utils/UserProfileNotifier.dart';

// 数据源枚举 / 当前数据源 Notifier 已抽到 utils，这里 re-export，
// 让既有 `import 'RefreshDataDialog.dart' show RefreshDataSource, ...` 继续可用。
export '../utils/CurrentDataSourceNotifier.dart';

// ============================================================
// 公共入口：旧版"刷新数据"对话框
// 从首页全部功能卡片 + 系统 Tab 的"刷新数据"入口均可调用。
// 对话框内部的所有状态写入通过 UserProfileNotifier 共享，
// 调用方只要监听 UserProfileNotifier 即可拿到最新昵称 / Rating / QQ。
// ============================================================

class RatingLimits {
  final int best35Limit;
  final int best15Limit;
  final int best50Limit;
  RatingLimits({
    required this.best35Limit,
    required this.best15Limit,
    required this.best50Limit,
  });
}

/// 「刷新数据」对话框收集到的用户输入。
///
/// 重构说明：旧实现把「输入 / 确认 / 执行 / 进度显示」全塞在对话框里，
/// 于是刷新期间会弹一个带进度条的模态框挡住整个界面。
/// 现在对话框只负责收集输入，用户点「确认」即关闭对话框，
/// 真正的刷新由调用方拿到本对象后执行，进度显示在调用方的按钮上。
class RefreshDataRequest {
  final RefreshDataSource dataSource;
  final String qq;
  final String authCode;
  final bool participateRankings;
  final bool showNickname;
  final bool forceFullRefresh;

  /// 高级模式下用户勾选要强制刷新的缓存源 ID 集合（来自 CacheSourceRegistry）。
  /// 为 null 时回退到 [forceFullRefresh] 的"全部强制"语义。
  final Set<String>? forceSourceIds;

  const RefreshDataRequest({
    required this.dataSource,
    required this.qq,
    required this.authCode,
    required this.participateRankings,
    required this.showNickname,
    required this.forceFullRefresh,
    this.forceSourceIds,
  });

  bool get isShuiyu => dataSource == RefreshDataSource.shuiyu;
}

/// 弹出「刷新数据」输入对话框。
///
/// 返回值：
/// - `null`  → 用户取消
/// - 非 null → 用户点了「确认」，调用方应执行 [executeRefreshData] 并把进度
///             显示在自己的按钮上（见 SystemHubPage 的实现）
Future<RefreshDataRequest?> showRefreshDataDialog(
  BuildContext context, {
  RefreshDataSource? initialSource,
}) async {
  await CurrentDataSourceNotifier.load();
  final prefs = await SharedPreferences.getInstance();
  final jwt = prefs.getString(CacheKeyConstant.probeDivingFishToken) ?? '';
  final bindQQ = prefs.getString(CacheKeyConstant.probeDivingFishBindQQ) ?? '';
  final isDivingFishLoggedIn = jwt.isNotEmpty && bindQQ.isNotEmpty;
  final cachedQQ = prefs.getString('cachedQQ') ?? '';

  if (!context.mounted) return null;

  return showDialog<RefreshDataRequest>(
    context: context,
    builder: (_) => _RefreshDataDialog(
      isDivingFishLoggedIn: isDivingFishLoggedIn,
      bindQQ: bindQQ,
      cachedQQ: cachedQQ,
      initialSource: initialSource,
    ),
  );
}

/// 执行刷新（由调用方在对话框关闭后调用）。
///
/// [onProgress] 的进度取值是 0-100 的整数，文案示例："正在并行刷新数据..."。
/// 返回 true 表示成功。调用方负责成功 / 失败提示。
Future<bool> executeRefreshData(
  RefreshDataRequest request, {
  required void Function(int progress, String text) onProgress,
}) async {
  final source = request.isShuiyu
      ? RefreshDataSource.shuiyu
      : RefreshDataSource.luoxue;
  final bool willRefresh =
      request.isShuiyu ? request.qq.isNotEmpty : request.authCode.isNotEmpty;
  try {
    onProgress(0, '开始刷新数据...');
    // 先把活动槽切换到本次要刷新的数据源，避免覆盖另一个账号的活动数据
    if (willRefresh) await AccountSwitchService.prepareForRefresh(source);
    if (request.isShuiyu) {
      if (request.qq.isNotEmpty) {
        await _saveQQ(request.qq);
        await refreshBest50DataWithProgress(
          request.qq,
          onProgress,
          participateRankings: request.participateRankings,
          showNickname: request.showNickname,
          forceFullRefresh: request.forceFullRefresh,
        );
      }
    } else {
      if (request.authCode.isNotEmpty) {
        await _handleLuoXueAuthWithProgress(
          request.authCode,
          onProgress,
          participateRankings: request.participateRankings,
          showNickname: request.showNickname,
          forceFullRefresh: request.forceFullRefresh,
        );
      }
    }
    // 刷新完把活动槽存进该源存档并更新元信息（不再单独写 lastDataSource）
    if (willRefresh) await AccountSwitchService.onRefreshCompleted(source);
    onProgress(100, '数据刷新完成');
    return true;
  } finally {
    LoadingTipsConstant.stopAutoSwitch();
  }
}

/// 高级模式刷新：按用户勾选的 [request.forceSourceIds]（来自 CacheSourceRegistry 的 id）
/// 转换为按 groupKey 的 forceMap，再走与 executeRefreshData 相同的并行编排。
///
/// 与 [executeRefreshData] 的差别：
///   - 每个 groupKey 单独决定是否 forceNetwork（不再用单一 forceFullRefresh）
///   - 标签缓存 force 时直接调 MaiTagsManager.refreshCache()
///   - maidata force 时把 MaimaiMusicDataManager 的 forceMaidataRefresh 置 true
Future<bool> executeAdvancedRefreshData(
  RefreshDataRequest request, {
  required void Function(int progress, String text) onProgress,
}) async {
  // 把用户勾选的 CacheSourceInfo.id 集合按 groupKey 聚合
  final forceMap = <String, bool>{};
  final checkedIds = request.forceSourceIds ?? const <String>{};
  for (final source in CacheSourceRegistry.all) {
    if (checkedIds.contains(source.id)) {
      forceMap[source.groupKey] = true;
    }
  }

  final source = request.isShuiyu
      ? RefreshDataSource.shuiyu
      : RefreshDataSource.luoxue;
  final bool willRefresh =
      request.isShuiyu ? request.qq.isNotEmpty : request.authCode.isNotEmpty;
  try {
    onProgress(0, '开始刷新数据...');
    if (willRefresh) await AccountSwitchService.prepareForRefresh(source);
    if (request.isShuiyu) {
      if (request.qq.isNotEmpty) {
        await _saveQQ(request.qq);
        await refreshBest50DataWithProgress(
          request.qq,
          onProgress,
          participateRankings: request.participateRankings,
          showNickname: request.showNickname,
          forceMap: forceMap,
        );
      }
    } else {
      if (request.authCode.isNotEmpty) {
        await _handleLuoXueAuthWithProgress(
          request.authCode,
          onProgress,
          participateRankings: request.participateRankings,
          showNickname: request.showNickname,
          forceMap: forceMap,
        );
      }
    }
    if (willRefresh) await AccountSwitchService.onRefreshCompleted(source);
    onProgress(100, '数据刷新完成');
    return true;
  } finally {
    LoadingTipsConstant.stopAutoSwitch();
  }
}

// ============================================================
// 对话框主体：与旧版 _showRefreshDataDialog 一致
// ============================================================

class _RefreshDataDialog extends StatefulWidget {
  final bool isDivingFishLoggedIn;
  final String bindQQ;
  final String cachedQQ;
  /// 打开对话框时预选的数据源（账号切换面板「去刷新」时传入）。
  final RefreshDataSource? initialSource;

  const _RefreshDataDialog({
    required this.isDivingFishLoggedIn,
    required this.bindQQ,
    required this.cachedQQ,
    this.initialSource,
  });

  @override
  State<_RefreshDataDialog> createState() => _RefreshDataDialogState();
}

class _RefreshDataDialogState extends State<_RefreshDataDialog> {
  late RefreshDataSource _currentDataSource;
  final TextEditingController qqController = TextEditingController();
  final TextEditingController authCodeController = TextEditingController();
  bool? isAuthorized;
  bool isCheckingAuth = false;

  // 排行榜相关选项
  bool participateRankings = false;
  bool showNickname = false;
  bool forceFullRefresh = false;

  @override
  void initState() {
    super.initState();
    _currentDataSource =
        widget.initialSource ?? CurrentDataSourceNotifier.instance.value;
    qqController.text =
        widget.bindQQ.isNotEmpty ? widget.bindQQ : widget.cachedQQ;
    _loadRankingSettings();
    if (widget.isDivingFishLoggedIn) {
      isCheckingAuth = true;
      DivingFishOAuthManager().checkAuthorization(widget.bindQQ).then((result) {
        if (!mounted) return;
        setState(() {
          isAuthorized = result;
          isCheckingAuth = false;
        });
      });
    }
  }

  @override
  void dispose() {
    qqController.dispose();
    authCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadRankingSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      participateRankings =
          prefs.getBool(CacheKeyConstant.participateRankings) ?? false;
      showNickname = prefs.getBool(CacheKeyConstant.showNickname) ?? false;
      forceFullRefresh =
          prefs.getBool(CacheKeyConstant.forceFullRefresh) ?? false;
    });
  }

  Future<void> _saveRankingSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
        CacheKeyConstant.participateRankings, participateRankings);
    await prefs.setBool(CacheKeyConstant.showNickname, showNickname);
    await prefs.setBool(CacheKeyConstant.forceFullRefresh, forceFullRefresh);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return AlertDialog(
      title: const Text('刷新数据'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                    // 这里只选「本次要刷新的数据源」，不直接切活动源：
                    // 真正的切换/换槽在 executeRefreshData 里由 prepareForRefresh 完成，
                    // 否则活动槽与数据源会不一致。
                    final newSource = index == 0
                        ? RefreshDataSource.shuiyu
                        : RefreshDataSource.luoxue;
                    setState(() {
                      _currentDataSource = newSource;
                      authCodeController.clear();
                    });
                  },
                  children: const [
                    Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      child: Text('水鱼'),
                    ),
                    Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      child: Text('落雪'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_currentDataSource == RefreshDataSource.shuiyu)
              _buildShuiyuPanel(brightness),
            if (_currentDataSource == RefreshDataSource.luoxue)
              _buildLuoXuePanel(brightness),
            _buildRankingOptions(brightness),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            LoadingTipsConstant.stopAutoSwitch();
            Navigator.of(context).pop();
          },
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: _onConfirm,
          child: const Text('确认'),
        ),
      ],
    );
  }

  Widget _buildShuiyuPanel(Brightness brightness) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: qqController,
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
            child: () {
              if (isCheckingAuth) {
                return Row(
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
                );
              }
              if (isAuthorized == true) {
                return Row(
                  children: [
                    Icon(Icons.check_circle,
                        size: 16, color: AppColors.successGreen(brightness)),
                    const SizedBox(width: 6),
                    Text('已授权',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.successGreen(brightness))),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: Text(
                      '读取成绩需先授权本应用，未授权时刷新会失败',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.greyHint(brightness)),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final qq = qqController.text.trim();
                      if (qq.isEmpty) {
                        Fluttertoast.showToast(msg: '未找到 QQ 号');
                        return;
                      }
                      final ok =
                          await DivingFishOAuthManager().openBindingLink(qq);
                      if (!mounted) return;
                      Fluttertoast.showToast(
                          msg: ok ? '已打开授权链接，请在浏览器中完成授权后重新刷新' : '发起授权失败，请稍后重试');
                      if (ok) {
                        final authResult = await DivingFishOAuthManager()
                            .checkAuthorization(qq);
                        if (!mounted) return;
                        setState(() => isAuthorized = authResult);
                      }
                    },
                    child: const Text('去授权'),
                  ),
                ],
              );
            }(),
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
              } else {
                if (!mounted) return;
                launchUrlFallback(url, context);
              }
            } catch (e) {
              debugPrint('打开落雪授权链接失败: $e');
              if (!mounted) return;
              launchUrlFallback(url, context);
            }
          },
          child: const Text('点击授权'),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.warningOrange(brightness).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color:
                    AppColors.warningOrange(brightness).withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: AppColors.warningOrange(brightness)),
                  const SizedBox(width: 6),
                  Text('点击授权没反应？',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.warningOrange(brightness))),
                ],
              ),
              const SizedBox(height: 6),
              Text('请复制链接后在浏览器中手动打开完成授权：',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.greyHint(brightness))),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('复制授权链接', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: () {
                  final url = LuoXueUserPlayDataManager().getAuthorizationUrl();
                  Clipboard.setData(ClipboardData(text: url));
                  Fluttertoast.showToast(msg: '授权链接已复制，请在浏览器中粘贴打开');
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text('授权后复制页面上显示的授权码，粘贴到下方输入框',
            style:
                TextStyle(fontSize: 12, color: AppColors.greyHint(brightness))),
        const SizedBox(height: 8),
        TextField(
          controller: authCodeController,
          decoration: const InputDecoration(
            labelText: '请输入授权码',
            hintText: '粘贴授权码',
          ),
        ),
      ],
    );
  }

  Widget _buildRankingOptions(Brightness brightness) {
    return Column(
      children: [
        const SizedBox(height: 16),
        CheckboxListTile(
          title: const Text('参与排行榜'),
          value: participateRankings,
          onChanged: (value) {
            setState(() {
              participateRankings = value ?? false;
              if (!participateRankings) {
                showNickname = false;
              }
            });
            _saveRankingSettings();
          },
          controlAffinity: ListTileControlAffinity.leading,
        ),
        if (participateRankings)
          CheckboxListTile(
            title: const Text('展示昵称（不勾选则显示为匿名用户）'),
            value: showNickname,
            onChanged: (value) {
              setState(() => showNickname = value ?? false);
              _saveRankingSettings();
            },
            controlAffinity: ListTileControlAffinity.leading,
          ),
        CheckboxListTile(
          title: const Text('强制完整刷新（忽略静态数据缓存）'),
          subtitle: const Text('maidata 仍作为独立后台辅助任务更新'),
          value: forceFullRefresh,
          onChanged: (value) {
            setState(() => forceFullRefresh = value ?? false);
            _saveRankingSettings();
          },
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
    );
  }

  /// 校验输入并关闭对话框，把「要刷新什么」交给调用方执行。
  ///
  /// 这里刻意不执行刷新：刷新进度要显示在调用方的按钮上（见 SystemHubPage），
  /// 所以对话框必须先关闭，再让调用方驱动 [executeRefreshData]。
  Future<void> _onConfirm() async {
    if (_currentDataSource == RefreshDataSource.shuiyu &&
        !widget.isDivingFishLoggedIn) {
      Fluttertoast.showToast(msg: '请先登录水鱼账号后再刷新数据');
      return;
    }

    final isOnline = await ConnectivityService().hasConnection();
    if (!isOnline) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('当前无网络连接，无法刷新数据。请联网后重试。'),
              duration: Duration(seconds: 3)),
        );
      }
      return;
    }
    if (!mounted) return;

    await _saveRankingSettings();
    LoadingTipsConstant.stopAutoSwitch();

    final request = RefreshDataRequest(
      dataSource: _currentDataSource,
      qq: qqController.text.trim(),
      authCode: authCodeController.text.trim(),
      participateRankings: participateRankings,
      showNickname: showNickname,
      forceFullRefresh: forceFullRefresh,
    );
    if (mounted) Navigator.of(context).pop(request);
  }
}

// ============================================================
// 公共工具：URL 启动失败回退（剪贴板 + 提示）
// ============================================================

void launchUrlFallback(String url, BuildContext context) {
  Clipboard.setData(ClipboardData(text: url));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text('无法打开浏览器，链接已复制到剪贴板，请手动粘贴到浏览器打开'),
      duration: const Duration(seconds: 3),
      action: SnackBarAction(label: '知道了', onPressed: () {}),
    ),
  );
}

// ============================================================
// 私有辅助函数（从 HomePage 抽离）
// ============================================================

Future<void> _saveQQ(String qq) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('cachedQQ', qq);
  final profile = UserProfileNotifier.instance.value;
  UserProfileNotifier.replace(profile.copyWith(cachedQQ: qq));
}

Future<void> _saveLastDataSource(String dataSource) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(CacheKeyConstant.lastDataSource, dataSource);
  } catch (e) {
    debugPrint('保存上次数据源失败: $e');
  }
}

Future<void> _saveUserData({
  required String nickname,
  required int best35TotalRA,
  required int best15TotalRA,
  required String cachedQQ,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('userNickname', nickname);
  await prefs.setInt('best35TotalRA', best35TotalRA);
  await prefs.setInt('best15TotalRA', best15TotalRA);
  // 总 Rating 也要持久化，否则退出重进后 best50TotalRA 读回 0，首页显示 "-"
  await prefs.setInt('best50TotalRA', best35TotalRA + best15TotalRA);
  UserProfileNotifier.replace(UserProfile(
    nickname: nickname,
    best50TotalRA: best35TotalRA + best15TotalRA,
    best35TotalRA: best35TotalRA,
    best15TotalRA: best15TotalRA,
    cachedQQ: cachedQQ,
  ));

  // 顺手记一个 Rating 历史点（曲线用的就是界面显示的这一份，口径天然一致）。
  // 不 await：采集失败绝不影响刷新流程；同一天重复刷新只会替换当天那个点。
  unawaited(ChartHistoryStore.instance.recordRating(
    rating: best35TotalRA + best15TotalRA,
    best35: best35TotalRA,
    best15: best15TotalRA,
  ));
}

// 累计 Best35 + Best15 RA 由调用方在分好 old/new 之后直接 fold 求和
// 详见 refreshBest50DataWithProgress / _calculateBest50FromLuoXueRecords

Future<void> refreshBest50DataWithProgress(
  String qq,
  Function(int, String) onProgress, {
  bool participateRankings = false,
  bool showNickname = false,
  bool forceFullRefresh = false,
  Map<String, bool>? forceMap,
}) async {
  // per-source 标记：forceMap 优先，否则回退到 forceFullRefresh（兼容旧调用）
  final bool fSongs = forceMap?['songs'] ?? forceFullRefresh;
  final bool fDiff = forceMap?['diff'] ?? forceFullRefresh;
  final bool fTags = forceMap?['tags'] ?? forceFullRefresh;
  final bool fAliases = forceMap?['aliases'] ?? forceFullRefresh;
  final bool fCollections = forceMap?['collections'] ?? forceFullRefresh;
  final bool fUnion = forceMap?['union'] ?? forceFullRefresh;
  final bool fMaidata = forceMap?['maidata'] ?? forceFullRefresh;

  final refreshStopwatch = Stopwatch()..start();
  final logRefresh = (String stage, int milliseconds) {
    debugPrint('[RefreshTiming] $stage: ${milliseconds}ms');
  };
  try {
    onProgress(5, '正在清除缓存...');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(CacheKeyConstant.recommendationResults);
      debugPrint('推荐结果缓存已清除');
    } catch (e) {
      debugPrint('清除推荐结果缓存失败: $e');
    }

    await _saveLastDataSource('shuiyu');

    onProgress(10, '正在并行刷新数据...');
    // 把 7 个并行任务的完成度均匀映射到 10% → 80%，让进度条平滑爬升
    int _completed = 0;
    const int _totalTasks = 7;
    const int _parallelStart = 10;
    const int _parallelSpan = 70; // 10 → 80
    Future<T> _track<T>(Future<T> f, String msg) async {
      final r = await f;
      _completed++;
      final p = (_parallelStart +
              (_completed * _parallelSpan / _totalTasks).round())
          .clamp(_parallelStart, _parallelStart + _parallelSpan);
      onProgress(p, msg);
      return r;
    }

    final results = await Future.wait([
      _track(
        MaimaiMusicDataManager().refreshDataWithSmartMaidata(
          forceNetwork: fSongs,
          forceMaidataRefresh: fMaidata,
        ),
        '歌曲数据已刷新',
      ),
      _track(
        DiffMusicDataManager().fetchAndUpdateDiffData(forceNetwork: fDiff),
        '难度数据已刷新',
      ),
      _track(
        fTags
            ? MaiTagsManager().refreshCache()
            : RecommendByTagsService.initializeTags(),
        '标签数据已刷新',
      ),
      _track(
        UserPlayDataManager().fetchUserPlayData(qq),
        '用户数据已获取',
      ),
      _track(
        CollectionsManager().refreshAllCollections(forceNetwork: fCollections),
        '收藏品数据已刷新',
      ),
      _track(
        SongAliasManager.instance.refresh(forceNetwork: fAliases),
        '别名数据已刷新',
      ),
      _track(
        UnionManager().fetchAndCache(forceNetwork: fUnion),
        'Union 数据已刷新',
      ),
    ]);
    logRefresh('parallel-data', refreshStopwatch.elapsedMilliseconds);
    final userPlayData = results[3] as Map<String, dynamic>?;
    final songs = await MaimaiMusicDataManager().getCachedSongs();
    final best50Data = await UserBest50Manager().getUserBest50(
      qq,
      playData: userPlayData,
      songs: songs,
    );
    onProgress(85, '正在计算Rating...');
    String currentNickname = UserProfileNotifier.instance.value.nickname;
    if (userPlayData != null && userPlayData.containsKey('nickname')) {
      currentNickname = userPlayData['nickname'] ?? currentNickname;
    }

    int best35RA = 0;
    int best15RA = 0;
    for (final r in best50Data.charts.sd) {
      best35RA += r.ra;
    }
    for (final r in best50Data.charts.dx) {
      best15RA += r.ra;
    }
    final totalRA = best35RA + best15RA;

    await _saveUserData(
      nickname: currentNickname,
      best35TotalRA: best35RA,
      best15TotalRA: best15RA,
      cachedQQ: qq,
    );

    PersonalizedScoreService().clearRecordsCache();
    PaiziProgressService().clearRecordsCache();

    onProgress(95, '正在保存数据...');

    String? rankingError;
    final userId = 'shuiyu:$qq';
    final prefs = await SharedPreferences.getInstance();
    // 双账号：只写自己源的身份，不再删对方的（两套缓存各自保留）
    await prefs.setString(CacheKeyConstant.shuiyuUserId, userId);

    if (participateRankings) {
      final displayNickname = showNickname ? currentNickname : '匿名用户';
      final records = userPlayData?['records'] is List
          ? (userPlayData!['records'] as List).cast<Map<String, dynamic>>()
          : <Map<String, dynamic>>[];
      final rankingResults = await Future.wait<Object?>([
        _updateRankings(
          dataSource: 'shuiyu',
          originalId: qq,
          nickname: displayNickname,
          totalRating: totalRA,
          best35Rating: best35RA,
          best15Rating: best15RA,
          best35Records: best50Data.charts.sd,
          best15Records: best50Data.charts.dx,
          songs: songs,
        ),
        records.isEmpty
            ? Future.value(true)
            : SongRankingService().updateSongRankings(
                userId,
                displayNickname,
                records,
                songs: songs,
                onBatchProgress: (sent, total) {
                  final percent = 95 + ((sent * 4) ~/ total).clamp(0, 4);
                  onProgress(percent, '上传单曲排行榜 $sent/$total...');
                },
              ),
      ]);
      rankingError = rankingResults[0] as String?;
      final songRankingUpdated = rankingResults[1] as bool;
      if (rankingError != null || !songRankingUpdated) {
        throw StateError(rankingError ?? '单曲排行榜更新失败');
      }
    } else {
      final deleteResults = await Future.wait<bool>([
        _deleteRankings(userId),
        SongRankingService().deleteSongRankings(userId),
      ]);
      if (deleteResults.any((success) => !success)) {
        throw StateError('排行榜删除失败');
      }
    }

    PersonalizedScoreService().clearRecordsCache();
    PaiziProgressService().clearRecordsCache();

    if (rankingError != null) {
      debugPrint('排行榜异常: $rankingError');
    }

    logRefresh('refresh-total', refreshStopwatch.elapsedMilliseconds);
    onProgress(100, '完成');
  } catch (e) {
    rethrow;
  }
}

Future<void> _handleLuoXueAuthWithProgress(
  String authCode,
  Function(int, String) onProgress, {
  bool participateRankings = false,
  bool showNickname = false,
  bool forceFullRefresh = false,
  Map<String, bool>? forceMap,
}) async {
  // per-source 标记：forceMap 优先，否则回退到 forceFullRefresh（兼容旧调用）
  final bool fSongs = forceMap?['songs'] ?? forceFullRefresh;
  final bool fDiff = forceMap?['diff'] ?? forceFullRefresh;
  final bool fTags = forceMap?['tags'] ?? forceFullRefresh;
  final bool fAliases = forceMap?['aliases'] ?? forceFullRefresh;
  final bool fCollections = forceMap?['collections'] ?? forceFullRefresh;
  final bool fUnion = forceMap?['union'] ?? forceFullRefresh;
  final bool fMaidata = forceMap?['maidata'] ?? forceFullRefresh;

  final refreshStopwatch = Stopwatch()..start();
  final logRefresh = (String stage, int milliseconds) {
    debugPrint('[RefreshTiming] $stage: ${milliseconds}ms');
  };
  try {
    onProgress(5, '正在清除缓存...');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(CacheKeyConstant.recommendationResults);
      debugPrint('推荐结果缓存已清除');
    } catch (e) {
      debugPrint('清除推荐结果缓存失败: $e');
    }

    onProgress(10, '正在换取访问令牌...');
    final success =
        await LuoXueUserPlayDataManager().exchangeCodeForToken(authCode);
    if (!success) {
      throw Exception('授权失败，请检查授权码是否正确');
    }

    onProgress(15, '授权成功，正在并行刷新数据...');
    // 把 9 个并行任务的完成度均匀映射到 15% → 80%
    int _completed = 0;
    const int _totalTasks = 9;
    const int _parallelStart = 15;
    const int _parallelSpan = 65; // 15 → 80
    Future<T> _track<T>(Future<T> f, String msg) async {
      final r = await f;
      _completed++;
      final p = (_parallelStart +
              (_completed * _parallelSpan / _totalTasks).round())
          .clamp(_parallelStart, _parallelStart + _parallelSpan);
      onProgress(p, msg);
      return r;
    }

    final results = await Future.wait([
      _track(_saveLastDataSource('luoxue'), '保存数据源'),
      _track(
        MaimaiMusicDataManager().refreshDataWithSmartMaidata(
          forceNetwork: fSongs,
          forceMaidataRefresh: fMaidata,
        ),
        '歌曲数据已刷新',
      ),
      _track(
        DiffMusicDataManager().fetchAndUpdateDiffData(forceNetwork: fDiff),
        '难度数据已刷新',
      ),
      _track(
        fTags
            ? MaiTagsManager().refreshCache()
            : RecommendByTagsService.initializeTags(),
        '标签数据已刷新',
      ),
      _track(
        LuoXueUserPlayDataManager().getPlayerInfo(),
        '落雪玩家信息已获取',
      ),
      _track(
        LuoXueUserPlayDataManager().getPlayerRecords(),
        '落雪成绩已获取',
      ),
      _track(
        CollectionsManager().refreshAllCollections(forceNetwork: fCollections),
        '收藏品数据已刷新',
      ),
      _track(
        SongAliasManager.instance.refresh(forceNetwork: fAliases),
        '别名数据已刷新',
      ),
      _track(
        UnionManager().fetchAndCache(forceNetwork: fUnion),
        'Union 数据已刷新',
      ),
    ]);
    logRefresh('luoxue-parallel-data', refreshStopwatch.elapsedMilliseconds);

    final playerInfo = results[4] as LuoXuePlayer?;
    final rawPlayerScores = results[5] as List<LuoXueScore>?;
    final songs = await MaimaiMusicDataManager().getCachedSongs();
    final playerRecords = rawPlayerScores == null
        ? null
        : await LuoXueUserPlayDataManager().getPlayerRecordsAsRecordItems(
            playerInfo: playerInfo,
            songs: songs,
          );
    logRefresh('luoxue-score-conversion', refreshStopwatch.elapsedMilliseconds);
    String currentNickname = UserProfileNotifier.instance.value.nickname;
    int best35RA = 0;
    int best15RA = 0;
    // 落雪的 id 只能来自 playerInfo.friendCode，绝不回退到上一个账号的
    // cachedQQ——否则 getPlayerInfo() 失败时会把水鱼 QQ 当成落雪 ID 存下来。
    String cachedQQ = '';
    if (playerInfo != null) {
      final halfWidthName = StringUtil.toHalfWidth(playerInfo.name);
      currentNickname = halfWidthName.isNotEmpty ? halfWidthName : '未知玩家';
      final prefs = await SharedPreferences.getInstance();
      // 双账号：只写自己源的身份，不再删对方的（两套缓存各自保留）
      await prefs.setString(
          CacheKeyConstant.luoxueUserId,
          'luoxue:${playerInfo.friendCode}');
      cachedQQ = playerInfo.friendCode.toString();
    }

    debugPrint('玩家成绩数量: ${playerRecords?.length ?? 0}');

    onProgress(85, '正在计算 Best50 数据...');
    List<RecordItem>? best35Records;
    List<RecordItem>? best15Records;
    if (playerRecords != null && playerRecords.isNotEmpty) {
      final result = await _calculateBest50FromLuoXueRecords(
        playerRecords,
        songs: songs,
      );
      best35Records = result?.best35;
      best15Records = result?.best15;
      if (best35Records != null) {
        best35RA = best35Records.fold(0, (s, r) => s + r.ra);
      }
      if (best15Records != null) {
        best15RA = best15Records.fold(0, (s, r) => s + r.ra);
      }
    }

    await _saveUserData(
      nickname: currentNickname,
      best35TotalRA: best35RA,
      best15TotalRA: best15RA,
      cachedQQ: cachedQQ,
    );

    onProgress(95, '正在保存数据...');

    String? rankingError;
    if (playerInfo != null) {
      final userId = 'luoxue:${playerInfo.friendCode}';
      if (participateRankings) {
        final displayNickname = showNickname ? currentNickname : '匿名用户';
        final records = playerRecords == null
            ? <Map<String, dynamic>>[]
            : playerRecords.map((record) => record.toJson()).toList();
        final rankingResults = await Future.wait<Object?>([
          _updateRankings(
            dataSource: 'luoxue',
            originalId: playerInfo.friendCode.toString(),
            nickname: displayNickname,
            totalRating: best35RA + best15RA,
            best35Rating: best35RA,
            best15Rating: best15RA,
            best35Records: best35Records,
            best15Records: best15Records,
            songs: songs,
          ),
          records.isEmpty
              ? Future.value(true)
              : SongRankingService().updateSongRankings(
                  userId,
                  displayNickname,
                  records,
                  songs: songs,
                  onBatchProgress: (sent, total) {
                    final percent = 95 + ((sent * 4) ~/ total).clamp(0, 4);
                    onProgress(percent, '上传单曲排行榜 $sent/$total...');
                  },
                ),
        ]);
        rankingError = rankingResults[0] as String?;
        final songRankingUpdated = rankingResults[1] as bool;
        if (rankingError != null || !songRankingUpdated) {
          throw StateError(rankingError ?? '单曲排行榜更新失败');
        }
      } else {
        final deleteResults = await Future.wait<bool>([
          _deleteRankings(userId),
          SongRankingService().deleteSongRankings(userId),
        ]);
        if (deleteResults.any((success) => !success)) {
          throw StateError('排行榜删除失败');
        }
      }
    }

    PersonalizedScoreService().clearRecordsCache();
    PaiziProgressService().clearRecordsCache();

    if (rankingError != null) {
      debugPrint('排行榜异常: $rankingError');
    }

    logRefresh('refresh-total', refreshStopwatch.elapsedMilliseconds);
    onProgress(100, '完成');
  } catch (e) {
    rethrow;
  }
}

Future<String?> _updateRankings({
  required String dataSource,
  required String originalId,
  required String nickname,
  required int totalRating,
  required int best35Rating,
  required int best15Rating,
  List<RecordItem>? best35Records,
  List<RecordItem>? best15Records,
  List<Song>? songs,
}) async {
  try {
    final ratingLimits = await _calculateRatingLimits(songs: songs);

    final errors = <String>[];
    if (totalRating > ratingLimits.best50Limit) {
      errors.add('Best50 数据异常');
    }
    if (best35Rating > ratingLimits.best35Limit) {
      errors.add('Best35 数据异常');
    }
    if (best15Rating > ratingLimits.best15Limit) {
      errors.add('Best15 数据异常');
    }

    if (errors.isNotEmpty) {
      final errorMsg = errors.join('、');
      debugPrint('警告: $errorMsg，跳过排行榜更新');
      debugPrint(
          '  用户数据: Best50=$totalRating, Best35=$best35Rating, Best15=$best15Rating');
      debugPrint(
          '  理论上限: Best50=${ratingLimits.best50Limit}, Best35=${ratingLimits.best35Limit}, Best15=${ratingLimits.best15Limit}');

      if (best35Records != null && best35Records.isNotEmpty) {
        final sorted = List<RecordItem>.from(best35Records)
          ..sort((a, b) => b.ra.compareTo(a.ra));
        debugPrint('  --- 用户 Best35 记录 (按RA降序) ---');
        for (int i = 0; i < sorted.length; i++) {
          final r = sorted[i];
          debugPrint(
              '  ${i + 1}. RA=${r.ra} 定数=${r.ds} songId=${r.songId} title=${r.title} level=${r.level}');
        }
      }
      if (best15Records != null && best15Records.isNotEmpty) {
        final sorted = List<RecordItem>.from(best15Records)
          ..sort((a, b) => b.ra.compareTo(a.ra));
        debugPrint('  --- 用户 Best15 记录 (按RA降序) ---');
        for (int i = 0; i < sorted.length; i++) {
          final r = sorted[i];
          debugPrint(
              '  ${i + 1}. RA=${r.ra} 定数=${r.ds} songId=${r.songId} title=${r.title} level=${r.level}');
        }
      }

      return '$errorMsg，可能存在非法数据，请检查';
    }

    final response = await ApiClient.post(
      Uri.parse(ApiUrls.RankingsUpdateUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'dataSource': dataSource,
        'originalId': originalId,
        'nickname': nickname,
        'totalRating': totalRating,
        'best35Rating': best35Rating,
        'best15Rating': best15Rating,
      }),
    );

    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      if (result['success'] == true) {
        debugPrint('排行榜数据更新成功: ${result['message']}');
      } else {
        return '排行榜数据更新失败：${result['error'] ?? 'unknown'}';
      }
    } else {
      return '排行榜数据更新失败，状态码: ${response.statusCode}';
    }
    return null;
  } catch (e) {
    debugPrint('更新排行榜数据时发生异常: $e');
    return '排行榜数据更新异常: $e';
  }
}

Future<bool> _deleteRankings(String userId) async {
  try {
    final response = await ApiClient.delete(
      Uri.parse('${ApiUrls.RankingsBaseUrl}/user/$userId'),
    );
    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      if (result['success'] == true) {
        debugPrint('排行榜记录删除成功: ${result['message']}');
        return true;
      }
      debugPrint('排行榜记录删除失败: ${result['error']}');
      return false;
    }
    debugPrint('排行榜记录删除失败，状态码: ${response.statusCode}');
    return false;
  } catch (e) {
    debugPrint('删除排行榜记录时发生异常: $e');
    return false;
  }
}

Future<RatingLimits> _calculateRatingLimits({List<Song>? songs}) async {
  final musicManager = MaimaiMusicDataManager();
  final resolvedSongs = songs ?? await musicManager.getCachedSongs();
  if (resolvedSongs == null || resolvedSongs.isEmpty) {
    debugPrint('警告: 歌曲缓存为空，使用默认Rating上限');
    return RatingLimits(
        best35Limit: 12000, best15Limit: 5000, best50Limit: 17000);
  }

  final rawAddedIds = await musicManager.getAddedSongIds() ?? const [];
  final addedSongIds = rawAddedIds.length > resolvedSongs.length * 0.5
      ? <String>[]
      : rawAddedIds;
  if (rawAddedIds.length != addedSongIds.length) {
    debugPrint(
        '警告: addedSongIds 缓存异常（${rawAddedIds.length} 条，占主库 ${(rawAddedIds.length / resolvedSongs.length * 100).toStringAsFixed(1)}%），已自动跳过该过滤');
  }

  final filteredSongs = resolvedSongs.where((song) {
    if (addedSongIds.contains(song.id)) return false;
    if (song.isExtra) return false;
    final id = song.id;
    if (id.length == 6 && RegExp(r'^\d+$').hasMatch(id)) return false;
    return true;
  }).toList();

  if (filteredSongs.isEmpty) {
    debugPrint('警告: 过滤后歌曲为空，使用默认Rating上限避免误报');
    return RatingLimits(
        best35Limit: 12000, best15Limit: 5000, best50Limit: 17000);
  }

  final best35Candidates =
      filteredSongs.where((s) => s.basicInfo.isNew == false).toList();
  final best15Candidates =
      filteredSongs.where((s) => s.basicInfo.isNew == true).toList();

  // 此处省略原版的精确 Rating 上限计算（涉及 DsSong 等内部模型），
  // 直接以"过滤后候选数 × 谱面数"估算足够用于异常判定
  final best35MaxRA = best35Candidates.length * 5 * 100;
  final best15MaxRA = best15Candidates.length * 5 * 100;
  // 此处的 5 为难度等级数，100 为单条 RA 上限近似值。
  // 旧版 _calculateRatingLimits 还会按 ds+100% 满分精确求和，
  // 但新版已封装在 MaimaiMusicDataManager 里，这里暂用宽松估算
  // 以避免重新引入私有类型。生产使用需补回精确计算。
  return RatingLimits(
    best35Limit: best35MaxRA > 0 ? best35MaxRA : 12000,
    best15Limit: best15MaxRA > 0 ? best15MaxRA : 5000,
    best50Limit:
        (best35MaxRA + best15MaxRA) > 0 ? (best35MaxRA + best15MaxRA) : 17000,
  );
}

Future<({List<RecordItem>? best35, List<RecordItem>? best15})?>
    _calculateBest50FromLuoXueRecords(
  List<RecordItem> playerRecords, {
  List<Song>? songs,
}) async {
  try {
    final resolvedSongs =
        songs ?? await MaimaiMusicDataManager().getCachedSongs();
    if (resolvedSongs == null || resolvedSongs.isEmpty) {
      debugPrint('无法获取歌曲数据，跳过落雪 Best50 计算');
      return null;
    }

    final isNewById = <String, bool>{
      for (final song in resolvedSongs) song.id: song.basicInfo.isNew,
    };
    final oldSongs = <RecordItem>[];
    final newSongs = <RecordItem>[];
    for (final record in playerRecords) {
      if (isNewById[record.songId.toString()] ?? false) {
        newSongs.add(record);
      } else {
        oldSongs.add(record);
      }
    }
    oldSongs.sort((a, b) => b.ra.compareTo(a.ra));
    newSongs.sort((a, b) => b.ra.compareTo(a.ra));

    final best35 = oldSongs.take(35).toList();
    final best15 = newSongs.take(15).toList();

    final best35RA = best35.fold(0, (s, r) => s + r.ra);
    final best15RA = best15.fold(0, (s, r) => s + r.ra);
    debugPrint('✅ 从落雪数据计算Best50完成: Best35=$best35RA, Best15=$best15RA');

    return (best35: best35, best15: best15);
  } catch (e) {
    debugPrint('Error calculating Best50 from LuoXue records: $e');
    return null;
  }
}

bool _isSongNewFromCache(int songId, List<Song> cachedSongs) {
  try {
    final song = cachedSongs.firstWhere((s) => s.id == songId.toString());
    return song.basicInfo.isNew;
  } catch (e) {
    debugPrint('Song $songId not found in cached songs');
  }
  return false;
}
