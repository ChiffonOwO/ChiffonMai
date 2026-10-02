import 'dart:convert';

import '../utils/ApiClient.dart';
import 'CommunityAvatarStore.dart';

/// Only submit names obtained from a fresh upstream response. Loading cached
/// profiles on startup must never overwrite a newer server nickname.
class CommunityNicknameSyncService {
  static const _endpoint = 'https://chiffonmai.cloud/api/me/nickname';
  static Future<void> _writes = Future.value();

  static Future<bool> syncFreshNickname({
    required String playerId,
    required String nickname,
  }) async {
    final name = nickname.trim();
    if (name.isEmpty ||
        name.runes.length > 100 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(name) ||
        const {'匿名用户', '匿名', 'Anonymous', 'anonymous'}.contains(name)) {
      return false;
    }
    // Capture credentials immediately; a later account switch cannot redirect
    // this request to another player. The backend also verifies exact ownership.
    try {
      final captured = CommunityAvatarStore.authorizationHeaders(playerId)
          .catchError((Object _) => null);
      final operation = _writes.then((_) async {
        final headers = await captured;
        if (headers == null) return false;
        return _sync(playerId, name, headers);
      });
      _writes =
          operation.then<void>((_) {}, onError: (Object _, StackTrace __) {});
      return await operation;
    } catch (_) {
      // A nickname sync failure must not fail the score refresh. The next fresh
      // score refresh submits it again, even if rating and player ID are equal.
      return false;
    }
  }

  static Future<bool> _sync(
      String player, String name, Map<String, String> headers) async {
    final response = await ApiClient.get(
        Uri.parse(_endpoint).replace(queryParameters: {'playerId': player}),
        headers: headers);
    if (response.statusCode != 200) return false;
    var remote = (jsonDecode(response.body) as Map<String, dynamic>)['data'];
    for (var attempt = 0; attempt < 3; attempt++) {
      if (remote is! Map || remote['playerId'] != player) return false;
      if (remote['nickname'] == name) return true;
      final result = await ApiClient.put(Uri.parse(_endpoint),
          headers: headers,
          timeout: const Duration(seconds: 25),
          body: jsonEncode({
            'playerId': player,
            'nickname': name,
            'expectedProfileRevision': remote['profileRevision'].toString(),
          }));
      final body = jsonDecode(result.body) as Map<String, dynamic>;
      remote = body['data'];
      if (result.statusCode == 409 && body['code'] == 'PROFILE_CONFLICT') {
        continue;
      }
      return result.statusCode == 200 &&
          body['success'] == true &&
          remote is Map &&
          remote['playerId'] == player &&
          remote['nickname'] == name;
    }
    return false;
  }
}
