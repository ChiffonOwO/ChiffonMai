import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constant/CacheKeyConstant.dart';
import '../utils/CurrentDataSourceNotifier.dart';
import '../utils/LoginStateNotifier.dart';
import '../utils/UserProfileNotifier.dart';
import 'AccountStore.dart';
import 'AWMC/AwmcPlayCountStore.dart';
import 'History/ChartHistoryStore.dart';
import 'PaiziProgressService.dart';
import 'PersonalizedScoreService.dart';

enum SwitchOutcome { switched, noCache, sameSource, busy, failed }

/// 活动槽的唯一协调入口。切换、刷新、清理共享一个锁；刷新锁覆盖整个请求周期。
/// 每次破坏性写入前先保存原账号，失败/进程中断时从存档恢复。
class AccountSwitchService {
  AccountSwitchService._();

  static bool _busy = false;
  static int revision = 0;
  static final Object _refreshScope = Object();
  static Future<void>? _initializing;
  static bool get isBusy => _busy;

  static void requireIdle() {
    if (_busy) throw StateError('账号数据正在更新，请完成后重试');
  }

  static void _invalidateRecords() {
    PersonalizedScoreService().clearRecordsCache();
    PaiziProgressService().clearRecordsCache();
  }

  static Future<void> _publish(RefreshDataSource source) async {
    revision++;
    _invalidateRecords();
    await CurrentDataSourceNotifier.instance.set(source);
    await UserProfileNotifier.load();
    await LoginStateNotifier.load();
  }

  static Future<void> _activate(RefreshDataSource source) async {
    await AccountStore.loadArchiveIntoActiveSlot(source.key);
    await _publish(source);
  }

  static Future<void> _pending(RefreshDataSource restore,
      {RefreshDataSource? target}) async {
    final prefs = await SharedPreferences.getInstance();
    final checkpoint = <String, dynamic>{'restore': restore.key};
    if (target != null) {
      checkpoint['target'] = target.key;
      checkpoint['identity'] = prefs.getString(
          '${CacheKeyConstant.accountArchiveIdentityPrefix}${target.key}');
      checkpoint['play'] = prefs.getString(
          '${CacheKeyConstant.accountArchivePlayPrefix}${target.key}');
      checkpoint['metas'] = prefs.getString(CacheKeyConstant.accountStore);
    }
    if (!await prefs.setString(
        CacheKeyConstant.accountRotationPending, json.encode(checkpoint))) {
      throw StateError('无法保存账号恢复信息');
    }
  }

  static Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(CacheKeyConstant.accountRotationPending);
  }

  static Future<SwitchOutcome> switchTo(RefreshDataSource target) async {
    await ensureMigrated();
    if (_busy) return SwitchOutcome.busy;
    _busy = true;
    revision++;
    final current = CurrentDataSourceNotifier.instance.value;
    try {
      if (current == target) return SwitchOutcome.sameSource;
      if (!await AccountStore.hasCache(target.key)) {
        return SwitchOutcome.noCache;
      }
      await AccountStore.writeActiveSlotToArchive(current.key);
      await _pending(current);
      await _activate(target);
      await _finish();
      return SwitchOutcome.switched;
    } catch (e) {
      debugPrint('切换账号失败: $e');
      try {
        await _restorePending();
      } catch (restoreError) {
        debugPrint('账号恢复未完成，保留恢复标记: $restoreError');
      }
      return SwitchOutcome.failed;
    } finally {
      _busy = false;
    }
  }

  /// 所有成绩刷新入口（含同步后的自动刷新）必须调用此方法。
  /// 锁的获取/释放/回滚由同一个调用持有，拒绝的第二个任务不能回滚第一个任务。
  static Future<T> runRefresh<T>(
      RefreshDataSource source, Future<T> Function() body) async {
    await ensureMigrated();
    requireIdle();
    _busy = true;
    revision++;
    final previous = CurrentDataSourceNotifier.instance.value;
    try {
      await AccountStore.writeActiveSlotToArchive(previous.key);
      await _pending(previous, target: source);
      // 无缓存目标也要清空旧活动槽，再明确切到目标源。
      await _activate(source);
      final result = await runZoned(body, zoneValues: {_refreshScope: source});
      await AccountStore.writeActiveSlotToArchive(source.key);
      await AccountStore.upsert(
          await AccountStore.buildMetaFromActiveSlot(source));
      await _publish(source);
      await _finish();
      return result;
    } catch (_) {
      await _restorePending();
      rethrow;
    } finally {
      _busy = false;
    }
  }

  static void requireRefresh(RefreshDataSource source) {
    if (!_busy ||
        Zone.current[_refreshScope] != source ||
        CurrentDataSourceNotifier.instance.value != source) {
      throw StateError('成绩写入缺少对应账号的刷新事务');
    }
  }

  /// 身份已从本次响应确认后调用。换人时丢弃旧人的派生缓存和评论身份。
  static Future<void> bindIdentity(RefreshDataSource source, String id) async {
    requireRefresh(source);
    if (id.isEmpty) throw StateError('账号 ID 不能为空');
    final prefs = await SharedPreferences.getInstance();
    final oldId = RefreshDataSource.parseUserIdMarker(
            prefs.getString(source.userIdCacheKey)) ??
        prefs.getString(CacheKeyConstant.cachedQQ);
    if (oldId != null && oldId != id) {
      await AccountStore.clearActiveSlot();
      await AwmcPlayCountStore.clear(source: source);
      _invalidateRecords();
    }
    await prefs.setString(source.userIdCacheKey, '${source.key}:$id');
    await prefs.setString(CacheKeyConstant.cachedQQ, id);
  }

  static Future<void> clearAccountData(RefreshDataSource source,
      {Future<void> Function()? clearCredentials}) async {
    await ensureMigrated();
    requireIdle();
    _busy = true;
    revision++;
    try {
      await clearCredentials?.call();
      await AccountStore.remove(source.key);
      await AwmcPlayCountStore.clear(source: source);
      if (CurrentDataSourceNotifier.instance.value == source) {
        var fallback = RefreshDataSource.shuiyu;
        for (final candidate in RefreshDataSource.values) {
          if (candidate != source &&
              await AccountStore.hasCache(candidate.key)) {
            fallback = candidate;
            break;
          }
        }
        await _pending(fallback);
        await _activate(fallback);
        await _finish();
      } else {
        await LoginStateNotifier.load();
      }
    } finally {
      _busy = false;
    }
  }

  static Future<void> onAccountLoggedOut(RefreshDataSource source,
          {Future<void> Function()? clearCredentials}) =>
      clearAccountData(source, clearCredentials: clearCredentials);

  static Future<void> _restorePending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(CacheKeyConstant.accountRotationPending);
    if (raw == null) return;
    String key = raw;
    if (raw.startsWith('{')) {
      final data = json.decode(raw) as Map;
      key = (data['restore'] ?? data['from'] ?? data['to']) as String;
      final target = data['target'];
      if (target is String &&
          RefreshDataSource.values.any((s) => s.key == target)) {
        // 提交分成多个 prefs 写入；即使中途被杀，也先恢复目标存档的完整旧版本。
        for (final entry in {
          '${CacheKeyConstant.accountArchiveIdentityPrefix}$target':
              data['identity'],
          '${CacheKeyConstant.accountArchivePlayPrefix}$target': data['play'],
          CacheKeyConstant.accountStore: data['metas'],
        }.entries) {
          final ok = entry.value == null
              ? await prefs.remove(entry.key)
              : await prefs.setString(entry.key, entry.value as String);
          if (!ok) throw StateError('账号存档回滚失败');
        }
      }
    }
    if (!RefreshDataSource.values.any((s) => s.key == key)) {
      throw StateError('无法识别待恢复的账号');
    }
    await _activate(RefreshDataSource.fromKey(key));
    await _finish();
  }

  static Future<void> recoverIfInterrupted() => ensureMigrated();

  /// 并发启动请求共用同一初始化 Future；运行中的事务标记不当作崩溃恢复。
  static Future<void> ensureMigrated() {
    if (_busy) return Future<void>.value();
    return _initializing ??=
        _initialize().whenComplete(() => _initializing = null);
  }

  static Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    await _restorePending();
    await CurrentDataSourceNotifier.load();
    if (!prefs.containsKey(CacheKeyConstant.accountStore)) {
      final source = CurrentDataSourceNotifier.instance.value;
      await AccountStore.writeActiveSlotToArchive(source.key);
      await AccountStore.upsert(
          await AccountStore.buildMetaFromActiveSlot(source));
    }
    const migration = 'account_history_identity_migrated_v1';
    const ownersKey = 'account_history_owners_v1';
    if (!prefs.containsKey(migration)) {
      // 固定升级前的归属，磁盘失败重试时也不能把旧文件绑定给后来登录的人。
      var rawOwners = prefs.getString(ownersKey);
      if (rawOwners == null) {
        final metas = await AccountStore.loadAll();
        rawOwners =
            json.encode({for (final e in metas.entries) e.key: e.value.id});
        if (!await prefs.setString(ownersKey, rawOwners)) {
          throw StateError('无法保存历史迁移信息');
        }
      }
      final owners = Map<String, dynamic>.from(json.decode(rawOwners) as Map);
      var migrated = true;
      for (final entry in owners.entries) {
        migrated = await ChartHistoryStore.instance
                .migrateLegacy(entry.key, entry.value as String) &&
            migrated;
      }
      if (migrated) await prefs.setBool(migration, true);
    }
    const snapshotMigration = 'account_snapshots_migrated_v1';
    if (!prefs.containsKey(snapshotMigration)) {
      final old = prefs.getString('b50_snapshots');
      if (old != null) {
        final key = 'b50_snapshots_${await AccountStore.accountKey()}';
        if (!prefs.containsKey(key)) await prefs.setString(key, old);
      }
      await prefs.setBool(snapshotMigration, true);
    }
  }
}
