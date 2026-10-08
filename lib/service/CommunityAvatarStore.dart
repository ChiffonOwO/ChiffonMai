import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constant/CacheKeyConstant.dart';
import '../manager/LuoXue/LuoXueOAuthManager.dart';
import '../utils/ApiClient.dart';
import '../utils/CurrentDataSourceNotifier.dart';
import '../utils/SecureCredentialStore.dart';

/// 头像同步的语义级别：UI 按它给状态文案着色，不要靠文案字符串反推。
enum AvatarSyncLevel {
  /// 仅本机保存（缺少账号凭据），需要用户处理
  localOnly,

  /// 同步请求进行中
  syncing,

  /// 社区头像已同步成功
  synced,

  /// 待同步，可点击重试
  pending,

  /// 读取或同步失败，状态异常
  error,
}

class AvatarSyncState {
  final String? playerId;
  final int avatarId;
  final String message;
  final bool pending;
  final AvatarSyncLevel level;
  const AvatarSyncState(
      {this.playerId,
      this.avatarId = 1,
      this.message = '头像仅保存在本机',
      this.pending = false,
      this.level = AvatarSyncLevel.localOnly});
}

/// 每个玩家各自持有一份持久化的待发队列：请求会锁定发起时的玩家与所选头像，
/// 因此切换账号或连续选择都不会把一次写入改投到别处。
class CommunityAvatarStore extends ValueNotifier<AvatarSyncState> {
  CommunityAvatarStore._() : super(const AvatarSyncState());
  static final instance = CommunityAvatarStore._();
  static const _endpoint = 'https://chiffonmai.cloud/api/me/avatar';
  static const _legacyOwner = 'community_avatar_legacy_owner';
  static String _key(String player) => 'community_avatar_v1_$player';
  Future<void> _writes = Future.value();
  final Set<String> _syncing = {};
  final Set<String> _resync = {};
  int _activation = 0;
  Future<void>? _activationFuture;
  String? _lastActivatedPlayer;

  Future<T> _queue<T>(Future<T> Function() action) {
    final operation = _writes.then((_) => action());
    _writes =
        operation.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return operation;
  }

  Map<String, dynamic> _entry(SharedPreferences prefs, String player) {
    try {
      return Map<String, dynamic>.from(
          jsonDecode(prefs.getString(_key(player)) ?? '{}'));
    } catch (_) {
      return {};
    }
  }

  Future<void> _persist(SharedPreferences prefs, String player,
      Map<String, dynamic> entry) async {
    if (!await prefs.setString(_key(player), jsonEncode(entry))) {
      throw StateError('无法保存头像');
    }
  }

  Future<String?> _activePlayer(SharedPreferences prefs) async {
    final source = RefreshDataSource.fromKey(
        prefs.getString(CacheKeyConstant.lastDataSource));
    final marker = prefs.getString(source.userIdCacheKey);
    if (marker != null &&
        marker.startsWith('${source.key}:') &&
        RefreshDataSource.parseUserIdMarker(marker) != null) {
      return marker;
    }
    // 登录已确认的绑定 QQ 不依赖成绩刷新生成的排行榜身份标记。
    // 不用共享 cachedQQ，避免把其它来源或查询对象当作当前水鱼账号。
    final hasDivingFishToken = source == RefreshDataSource.shuiyu &&
        ((await SecureCredentialStore.read(
                    CacheKeyConstant.probeDivingFishToken)) ??
                '')
            .isNotEmpty;
    if (hasDivingFishToken) {
      final qq =
          prefs.getString(CacheKeyConstant.probeDivingFishBindQQ)?.trim();
      if (qq != null && RegExp(r'^[1-9]\d{4,11}$').hasMatch(qq)) {
        return 'shuiyu:$qq';
      }
    }
    return null;
  }

  String _localOnlyMessage(SharedPreferences prefs, bool hasDivingFishToken) {
    final source = RefreshDataSource.fromKey(
        prefs.getString(CacheKeyConstant.lastDataSource));
    if (source == RefreshDataSource.shuiyu) {
      return !hasDivingFishToken ? '仅本机保存 · 登录水鱼后自动同步' : '仅本机保存 · 请先绑定水鱼 QQ';
    }
    return source == RefreshDataSource.awmc
        ? '仅本机保存 · 请先设置 AWMC QQ'
        : '仅本机保存 · 请先刷新落雪账号资料';
  }

  void _publish(String player, Map<String, dynamic> entry, String message,
      AvatarSyncLevel level) {
    if (value.playerId != player) return;
    if (value.pending && value.avatarId != entry['avatarId']) return;
    value = AvatarSyncState(
        playerId: player,
        avatarId: (entry['avatarId'] as int?) ?? 1,
        pending: entry['pending'] == true,
        message: message,
        level: level);
  }

  Future<void> activate() {
    final current = _activationFuture;
    if (current != null) return current;

    final future = _runActivation();
    _activationFuture = future;
    future.whenComplete(() {
      if (identical(_activationFuture, future)) _activationFuture = null;
    });
    return future;
  }

  Future<void> _runActivation() async {
    try {
      await _queue(_activate);
    } catch (_) {
      value = const AvatarSyncState(
          message: '头像未能读取，请重新打开此页', level: AvatarSyncLevel.error);
    }
  }

  Future<void> _activate() async {
    final activation = ++_activation;
    final prefs = await SharedPreferences.getInstance();
    final player = await _activePlayer(prefs);
    final hasDivingFishToken = (await SecureCredentialStore.read(
                CacheKeyConstant.probeDivingFishToken))
            ?.isNotEmpty ==
        true;
    if (activation != _activation) return;
    if (player == null) {
      _lastActivatedPlayer = null;
      value = AvatarSyncState(
          avatarId: prefs.getInt('selectedAvatarId') ?? 1,
          message: _localOnlyMessage(prefs, hasDivingFishToken),
          level: AvatarSyncLevel.localOnly);
      return;
    }
    var entry = _entry(prefs, player);
    if (entry.isEmpty &&
        prefs.getString(_legacyOwner) == null &&
        prefs.containsKey('selectedAvatarId')) {
      // Attribute the global legacy choice once; never copy it to every account.
      entry = {
        'avatarId': prefs.getInt('selectedAvatarId') ?? 1,
        'pending': true,
        'generation': 1
      };
      await _persist(prefs, player, entry);
    }
    // Even when there was no legacy preference, finish migration before a new
    // account choice populates the export compatibility key.
    if (prefs.getString(_legacyOwner) == null) {
      await prefs.setString(_legacyOwner, player);
    }
    if (activation != _activation) return;
    if (_lastActivatedPlayer == player && value.playerId == player) return;
    _lastActivatedPlayer = player;
    final waitSync = entry['pending'] == true;
    value = AvatarSyncState(
        playerId: player,
        avatarId: (entry['avatarId'] as int?) ?? 1,
        pending: waitSync,
        message: waitSync ? '头像待同步' : '正在读取社区头像',
        // 读取动作本身尚未失败，「正在读取」用中性色，待同步才用提醒色。
        level: waitSync ? AvatarSyncLevel.pending : AvatarSyncLevel.syncing);
    await prefs.setInt('selectedAvatarId', value.avatarId);
    unawaited(sync(player));
  }

  Future<void> select(int avatarId) {
    final player = value.playerId;
    value = AvatarSyncState(
        playerId: player,
        avatarId: avatarId,
        pending: player != null,
        message: player == null ? value.message : '头像待同步',
        level: player == null ? value.level : AvatarSyncLevel.pending);
    return _queue(() async {
      final prefs = await SharedPreferences.getInstance();
      if (player == null) {
        if (value.playerId == null) {
          await prefs.setInt('selectedAvatarId', avatarId);
        }
        return;
      }
      final entry = _entry(prefs, player);
      entry.addAll({
        'avatarId': avatarId,
        'pending': true,
        'generation': ((entry['generation'] as int?) ?? 0) + 1
      });
      await _persist(prefs, player, entry);
      if (value.playerId == player) {
        await prefs.setInt('selectedAvatarId', avatarId);
      }
      unawaited(sync(player));
    });
  }

  /// Shared ownership credentials for appearance and fresh nickname updates.
  static Future<Map<String, String>?> authorizationHeaders(
      String player) async {
    final source = player.split(':').first;
    final prefs = await SharedPreferences.getInstance();
    if (source == 'awmc') {
      final qq = player.substring('awmc:'.length);
      if (!RegExp(r'^[1-9]\d{4,11}$').hasMatch(qq)) return null;
      return {
        'X-Profile-Source': 'awmc',
        'X-Profile-QQ': qq,
        'Content-Type': 'application/json'
      };
    }
    final String? token;
    if (source == 'shuiyu') {
      token = await SecureCredentialStore.read(
          CacheKeyConstant.probeDivingFishToken);
    } else if (source == 'luoxue') {
      token = await LuoXueOAuthManager().getAccessToken();
    } else {
      return null;
    }
    if (token == null || token.isEmpty) return null;
    return {
      'Authorization': 'Bearer $token',
      'X-Profile-Source': source,
      'Content-Type': 'application/json'
    };
  }

  Future<void> retry() async {
    final player = value.playerId;
    if (player != null) await sync(player);
  }

  String _failureMessage(String player, int status, {String? code}) {
    if (player.startsWith('awmc:') && status == 403) {
      return code == 'VERIFIED_PROFILE_PROTECTED'
          ? '此头像受认证保护，QQ 方式无法修改'
          : '头像待同步 · 请确认当前 AWMC QQ';
    }
    return [401, 403].contains(status) ? '头像待同步 · 请登录对应账号后重试' : '头像待同步 · 点击重试';
  }

  Future<void> sync(String player) async {
    if (!_syncing.add(player)) {
      _resync.add(player);
      return;
    }
    var rerun = false;
    try {
      await _writes;
      final prefs = await SharedPreferences.getInstance();
      final headers = await authorizationHeaders(player);
      var entry = _entry(prefs, player);
      if (headers == null) {
        _publish(
            player,
            entry,
            player.startsWith('awmc:')
                ? '仅本机保存 · 请先设置有效的 AWMC QQ'
                : '仅本机保存 · 请先登录对应查分器',
            AvatarSyncLevel.localOnly);
        return;
      }
      _publish(player, entry, '正在同步社区头像', AvatarSyncLevel.syncing);
      final response = await ApiClient.get(
          Uri.parse(_endpoint).replace(queryParameters: {'playerId': player}),
          headers: headers);
      if (response.statusCode != 200) {
        _publish(player, entry, _failureMessage(player, response.statusCode),
            AvatarSyncLevel.error);
        return;
      }
      final remote = (jsonDecode(response.body) as Map<String, dynamic>)['data']
          as Map<String, dynamic>;
      if (remote['playerId'] != player) throw StateError('头像账号不匹配');
      await _writes;
      entry = _entry(prefs, player);
      if (entry['pending'] != true) {
        entry.addAll({
          'avatarId': remote['avatarId'],
          'revision': remote['profileRevision']
        });
        final applied = await _queue(() async {
          final latest = _entry(prefs, player);
          if (latest['pending'] == true) return false;
          await _persist(prefs, player, entry);
          _publish(player, entry, '社区头像已同步', AvatarSyncLevel.synced);
          return true;
        });
        if (!applied) {
          // A choice arrived while this GET was completing. Its durable outbox
          // takes priority; retry after releasing this request's guard.
          rerun = true;
          return;
        }
      } else {
        // Coalesce rapid selections; conflicts re-read revision and keep choice.
        for (var attempt = 0; attempt < 3; attempt++) {
          final generation = entry['generation'];
          final result = await ApiClient.put(Uri.parse(_endpoint),
              headers: headers,
              timeout: const Duration(seconds: 25),
              body: jsonEncode({
                'playerId': player,
                'avatarId': entry['avatarId'],
                'expectedProfileRevision': remote['profileRevision'].toString()
              }));
          final body = jsonDecode(result.body) as Map<String, dynamic>;
          await _writes;
          final latest = _entry(prefs, player);
          if (result.statusCode == 409 && body['data'] is Map) {
            remote['profileRevision'] = body['data']['profileRevision'];
            entry = latest;
            continue;
          }
          if (result.statusCode != 200 ||
              body['success'] != true ||
              body['data']?['playerId'] != player) {
            _publish(
                player,
                latest,
                _failureMessage(player, result.statusCode,
                    code: body['code'] as String?),
                AvatarSyncLevel.error);
            return;
          }
          remote['profileRevision'] = body['data']['profileRevision'];
          if (latest['generation'] != generation) {
            entry = latest;
            continue;
          }
          final saved = await _queue(() async {
            final current = _entry(prefs, player);
            if (current['generation'] != generation) return false;
            current.addAll(
                {'pending': false, 'revision': remote['profileRevision']});
            await _persist(prefs, player, current);
            _publish(player, current, '社区头像已同步', AvatarSyncLevel.synced);
            return true;
          });
          if (!saved) {
            entry = _entry(prefs, player);
            continue;
          }
          // Refresh comment caches, whose stored avatar may belong to this player.
          for (final key in prefs
              .getKeys()
              .where((key) => key.startsWith(
                  CacheKeyConstant.songCommentsCacheTimestampPrefix))
              .toList()) {
            await prefs.remove(key);
          }
          break;
        }
        entry = _entry(prefs, player);
        if (entry['pending'] == true) {
          _publish(player, entry, '头像待同步 · 点击重试', AvatarSyncLevel.pending);
        }
      }
      if (value.playerId == player) {
        await prefs.setInt('selectedAvatarId', value.avatarId);
      }
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      _publish(
          player, _entry(prefs, player), '头像待同步 · 点击重试', AvatarSyncLevel.error);
    } finally {
      await _writes;
      final prefs = await SharedPreferences.getInstance();
      final pending = _entry(prefs, player)['pending'] == true;
      _syncing.remove(player);
      final requested = _resync.remove(player);
      if (pending && (rerun || requested)) unawaited(sync(player));
    }
  }
}
