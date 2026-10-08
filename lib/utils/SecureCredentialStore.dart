import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constant/CacheKeyConstant.dart';

/// 保存会话令牌和导入密钥。旧版本使用 SharedPreferences，首次启动时会自动迁移。
class SecureCredentialStore {
  SecureCredentialStore._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _keys = <String>{
    CacheKeyConstant.luoxueAccessToken,
    CacheKeyConstant.luoxueRefreshToken,
    CacheKeyConstant.probeAuthToken,
    CacheKeyConstant.probeDivingFishToken,
    CacheKeyConstant.probeDivingFishImportToken,
    CacheKeyConstant.probeLxnsImportToken,
    CacheKeyConstant.awmcToken,
    CacheKeyConstant.awmcNetImportToken,
  };

  static Future<String?> read(String key) => _storage.read(key: key);

  static Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  static Future<void> delete(String key) => _storage.delete(key: key);

  /// 将旧版明文偏好迁移到系统安全存储；重复执行是安全的。
  static Future<void> migrateLegacy() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in _keys) {
        final existing = await read(key);
        var migrated = existing != null && existing.isNotEmpty;
        if (!migrated) {
          final legacy = prefs.getString(key);
          if (legacy != null && legacy.isNotEmpty) {
            await write(key, legacy);
            migrated = true;
          }
        }
        // 只有确认安全存储已有值，才删除旧的明文副本。
        if (migrated && prefs.containsKey(key)) await prefs.remove(key);
      }
    } catch (e) {
      // 安全存储不可用时保留旧值，让应用仍能启动；下次启动继续迁移。
      debugPrint('安全凭据迁移失败，将在下次启动重试: $e');
    }
  }

  static bool isCredentialKey(String key) => _keys.contains(key);
}
