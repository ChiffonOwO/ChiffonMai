import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:media_scanner/media_scanner.dart';

import '../constant/CacheKeyConstant.dart';
import '../manager/DivingFish/MaimaiMusicDataManager.dart';
import '../utils/CurrentDataSourceNotifier.dart';
import '../utils/FavoriteFeaturesNotifier.dart';
import '../utils/LoginStateNotifier.dart';
import '../utils/SyncRouteNotifier.dart';
import '../utils/ThemeManager.dart';
import '../utils/UserProfileNotifier.dart';
import 'Best50/CustomBest50Store.dart';
import 'ChartNoteService.dart';
import 'ChartPackageHistoryStore.dart';
import 'ChartPlaySettingsStore.dart';
import 'CommunityAvatarStore.dart';
import 'FavoriteFolderService.dart';
import 'PaiziProgressService.dart';
import 'PersonalizedScoreService.dart';

/// 数据备份服务
/// 导出/导入所有 SharedPreferences 数据为 JSON 文件
///
/// **可重新拉取的缓存不参与备份**（见 [_cacheExactKeys] / [_cacheKeyPrefixes]）：
/// 它们体积大（cachedSongs / maidata 动辄数 MB），却只是服务端数据的副本；
/// 更麻烦的是恢复后会写回**旧的缓存时间戳**，App 会以为缓存还新鲜，
/// 从而继续用过期数据。排除掉之后备份文件只剩真正的用户数据，
/// 恢复后由各 Manager 按需重新拉取。
class DataBackupService {
  static final DataBackupService _instance = DataBackupService._internal();
  factory DataBackupService() => _instance;
  DataBackupService._internal();

  /// 精确匹配的缓存键（可随时重新拉取，不属于用户数据）
  static const Set<String> _cacheExactKeys = {
    CacheKeyConstant.cachedSongs,
    CacheKeyConstant.cachedSongsTimestamp,
    CacheKeyConstant.maidataFullCache,
    CacheKeyConstant.maidataFullCacheTimestamp,
    CacheKeyConstant.maidataAddedSongs,
    CacheKeyConstant.maidataAddedSongsTimestamp,
    CacheKeyConstant.maidataIndexCache,
    CacheKeyConstant.maidataIndexCacheTimestamp,
    CacheKeyConstant.unionExtraSongIds,
    CacheKeyConstant.unionCache,
    CacheKeyConstant.unionCacheTimestamp,
    CacheKeyConstant.luoxueSongsCache,
    CacheKeyConstant.trophiesCollectionsCacheData,
    CacheKeyConstant.iconsCollectionsCacheData,
    CacheKeyConstant.platesCollectionsCacheData,
    CacheKeyConstant.framesCollectionsCacheData,
    CacheKeyConstant.maiTagsCache,
    CacheKeyConstant.maiTagsCacheTimestamp,
    CacheKeyConstant.userPlayData,
    CacheKeyConstant.accountRotationPending,
    'account_history_identity_migrated_v1',
    'account_history_owners_v1',
    'user_play_data_last_update',
    'awmc_net_user_play_data_last_update',
    CacheKeyConstant.diffMusicData,
    CacheKeyConstant.diffMusicDataTimestamp,
    CacheKeyConstant.recommendationResults,
    CacheKeyConstant.totalRankingsCache,
    CacheKeyConstant.totalRankingsCacheTimestamp,
    CacheKeyConstant.shuiyuRankingsCache,
    CacheKeyConstant.shuiyuRankingsCacheTimestamp,
    CacheKeyConstant.luoxueRankingsCache,
    CacheKeyConstant.luoxueRankingsCacheTimestamp,
    CacheKeyConstant.awmcRankingsCache,
    CacheKeyConstant.awmcRankingsCacheTimestamp,
    CacheKeyConstant.avgRankingsCache,
    CacheKeyConstant.avgRankingsCacheTimestamp,
    CacheKeyConstant.coverHashCache,
    CacheKeyConstant.coverHashCacheTimestamp,
    // AWMC 游玩次数缓存：能从 /v1/user/music 重新拉，而且与具体账号绑定，
    // 跟着备份跑到别的账号上会显示别人的游玩次数。
    // 旧版是单个共享键（Legacy），现在按源分开存（Prefix），两个都要排除。
    CacheKeyConstant.awmcPlayCountsLegacy,
  };

  /// 前缀匹配的缓存键（这些键按歌曲 / 模式 / 难度拼接，数量不固定）
  static const List<String> _cacheKeyPrefixes = [
    CacheKeyConstant.maidataCachePrefix, // maidata_cache_<shortId>
    CacheKeyConstant.fittedRankingsCachePrefix, // fitted_rankings_cache_<mode>
    CacheKeyConstant.fittedRankingsCacheTimestampPrefix,
    CacheKeyConstant.songCommentsCachePrefix, // song_comments_cache_<songId>
    CacheKeyConstant.songCommentsCacheTimestampPrefix,
    // 游玩次数缓存按数据源分键：awmc_play_counts_v1_<source>
    CacheKeyConstant.awmcPlayCountsPrefix,
    // 双账号：成绩存档（可重新拉取）不进备份；
    // 身份存档 account_archive_identity_* 与 account_store 属于用户数据，保留在备份里
    CacheKeyConstant.accountArchivePlayPrefix, // account_archive_play_<source>
  ];

  /// **绝不进备份**的本地敏感状态。
  ///
  /// 这类键既不是「可重新拉取的缓存」，也不该跟着备份文件走：
  /// 备份是**明文 JSON**，用户会随手放到网盘/群里，而 AWMC 网关令牌
  /// 等同于账户操作权限与余额（能改机台数据、能花钱），一旦随备份流出
  /// 后果不可逆。因此导出与导入两端都跳过它。
  ///
  /// 注意这与 `probeDivingFishToken` 等登录凭据的取舍不同：那些是
  /// 「恢复后省一次登录」的便利性凭据，用户自己决定要不要备份；
  /// AWMC 令牌是可直接扣费的凭据，默认不给导出。
  static const Set<String> _neverBackupKeys = {
    CacheKeyConstant.awmcToken,
    CacheKeyConstant.awmcAuditLog,
  };

  /// 该键是否属于「绝不备份」的敏感状态。
  static bool isNeverBackupKey(String key) => _neverBackupKeys.contains(key);

  /// 恢复前的 prefs 快照，仅在 [restoreData] 期间持有；写入中途出错时用它回滚。
  ///
  /// 为什么需要：恢复是「先 `clear()` 再逐键写」。一旦中途抛错，用户会停在
  /// **「原来的数据已经清空、新数据只写了一半」**的状态——那比导入失败难恢复得多。
  Map<String, dynamic>? _rollbackSnapshot;

  /// 是否是「可重新拉取的缓存」——这类键不写进备份
  static bool isCacheKey(String key) {
    if (_cacheExactKeys.contains(key)) return true;
    for (final p in _cacheKeyPrefixes) {
      if (key.startsWith(p)) return true;
    }
    // 兜底：`xxx_timestamp` 若其主体被判定为缓存，则该时间戳也是缓存
    const suffix = '_timestamp';
    if (key.endsWith(suffix)) {
      final base = key.substring(0, key.length - suffix.length);
      if (_cacheExactKeys.contains(base)) return true;
    }
    return false;
  }

  /// 导出所有数据到 JSON 文件
  /// 返回保存的文件路径，null 表示用户取消或失败
  Future<String?> exportToFile() async {
    try {
      // 1. 读取所有 SharedPreferences 数据（跳过可重新拉取的缓存）
      //
      // ⚠️ **必须先 reload**：legacy `SharedPreferences` 的值是 `getInstance()`
      // 那一刻的**内存快照**，之后只跟着自己的 setter 更新。而本项目里
      // 猜歌设置（`GuessChartSettingsStore`）走的是 `SharedPreferencesAsync`
      // 的 `apply()` 通道 —— 它写的是同一个 `FlutterSharedPreferences` 文件，
      // 但不会更新这份 legacy 快照。不 reload 的话：本次启动后改过的猜歌设置
      // 会导出成**旧值**，本次首次写入的键甚至整条不出现在备份里。
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final keys = prefs.getKeys();
      final data = <String, dynamic>{};
      var skipped = 0;
      var secretSkipped = 0;

      for (final key in keys) {
        // 敏感凭据（AWMC 网关令牌等）永远不进备份文件
        if (isNeverBackupKey(key)) {
          secretSkipped++;
          continue;
        }
        if (isCacheKey(key)) {
          skipped++;
          continue;
        }
        final value = prefs.get(key);
        if (value is String) {
          data[key] = {'type': 'String', 'value': value};
        } else if (value is int) {
          data[key] = {'type': 'int', 'value': value};
        } else if (value is double) {
          data[key] = {'type': 'double', 'value': value};
        } else if (value is bool) {
          data[key] = {'type': 'bool', 'value': value};
        } else if (value is List<String>) {
          data[key] = {'type': 'List<String>', 'value': value};
        }
      }

      debugPrint(
          'DataBackup: 导出 ${data.length} 个用户数据键，跳过 $skipped 个缓存键、'
          '$secretSkipped 个敏感凭据键');

      // 2. 构建备份元数据
      final backup = {
        'version': 2,
        'appName': 'ChiffonMai',
        'exportedAt': DateTime.now().toIso8601String(),
        'exportedAtTimestamp': DateTime.now().millisecondsSinceEpoch,
        'keyCount': data.length,
        'skippedCacheKeys': skipped,
        'skippedSecretKeys': secretSkipped,
        'data': data,
      };

      // 3. 序列化为 JSON
      final jsonStr = const JsonEncoder.withIndent('  ').convert(backup);
      final bytes = utf8.encode(jsonStr);

      // 4. 让用户选择保存路径
      //    文件名带时分秒：同一天导出多次不再互相覆盖（旧实现只到日期）
      final now = DateTime.now();
      final dateStr = '${now.year}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}'
          '${now.second.toString().padLeft(2, '0')}';
      final suggestedName = 'ChiffonMai_backup_$dateStr.json';

      // 优先保存到公共目录（用户可访问）
      Directory? saveDir;

      // 1) 尝试 Download 目录（最容易被用户找到）
      if (Platform.isAndroid) {
        try {
          final downloadDir = Directory('/storage/emulated/0/Download');
          if (!downloadDir.existsSync()) {
            downloadDir.createSync(recursive: true);
          }
          final testFile = File('${downloadDir.path}/.test_write');
          await testFile.writeAsString('test');
          await testFile.delete();
          saveDir = downloadDir;
        } catch (_) {
          debugPrint('DataBackup: Download 目录不可写，尝试 Pictures');
        }
      }

      // 2) 尝试 Pictures 目录
      if (saveDir == null && Platform.isAndroid) {
        try {
          final picsDir = Directory('/storage/emulated/0/Pictures');
          if (!picsDir.existsSync()) {
            picsDir.createSync(recursive: true);
          }
          final testFile = File('${picsDir.path}/.test_write');
          await testFile.writeAsString('test');
          await testFile.delete();
          saveDir = picsDir;
        } catch (_) {
          debugPrint('DataBackup: Pictures 目录不可写');
        }
      }

      // 3) 回退到应用私有目录
      if (saveDir == null) {
        final docDir = await getApplicationDocumentsDirectory();
        saveDir = Directory('${docDir.path}/backups');
        if (!saveDir.existsSync()) {
          saveDir.createSync(recursive: true);
        }
      }

      final file = File('${saveDir.path}/$suggestedName');
      await file.writeAsBytes(bytes);

      // 通知系统扫描新文件（让它在文件管理器中可见）
      if (Platform.isAndroid) {
        try {
          await MediaScanner.loadMedia(path: file.path);
        } catch (_) {}
      }

      debugPrint('DataBackup: 导出成功 → ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('DataBackup: 导出失败: $e');
      rethrow;
    }
  }

  /// 从 JSON 文件导入数据
  /// 返回解析后的备份数据供调用者确认，null 表示用户取消或失败
  Future<Map<String, dynamic>?> importFromFile() async {
    try {
      // 1. 让用户选择文件
      final result = await FilePicker.pickFiles(
        dialogTitle: '选择备份文件',
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        debugPrint('DataBackup: 用户取消了导入');
        return null;
      }

      // 2. 读取文件
      final file = File(result.files.single.path!);
      final jsonStr = await file.readAsString();

      // 3. 解析 JSON
      final backup = json.decode(jsonStr) as Map<String, dynamic>;

      // 4. 验证结构
      if (!backup.containsKey('data')) {
        throw Exception('无效的备份文件：缺少 data 字段');
      }
      if (!backup.containsKey('version')) {
        throw Exception('无效的备份文件：缺少 version 字段');
      }

      final data = backup['data'] as Map<String, dynamic>;
      if (data.isEmpty) {
        throw Exception('备份文件为空，无数据可恢复');
      }

      debugPrint(
          'DataBackup: 导入解析成功，${data.length} 个键，版本 ${backup['version']}');

      return backup;
    } catch (e) {
      debugPrint('DataBackup: 导入失败: $e');
      rethrow;
    }
  }

  /// 将备份数据恢复到 SharedPreferences。
  ///
  /// **先清空再写入**（[clearFirst] 默认 true）：备份里没有的键会被一并抹掉，
  /// 这才是「覆盖恢复」应有的语义——否则用户从旧备份恢复后，
  /// 比备份更新的那些键还留着，新旧数据混在一起。
  ///
  /// ── 为什么要先抓一份快照 ──
  ///
  /// `clear()` 之后逐条写入，中途一旦抛错就会退化成
  /// **「原数据已清空 + 只还原了一半」**，这比「导入失败」难恢复得多。
  /// 所以清空之前先把当前所有键读进 [_rollbackSnapshot]，失败时原样写回。
  ///
  /// 注意写入仍然走 legacy 的 `SharedPreferences`（不能用
  /// `SharedPreferencesAsync` 图快）：后者在 Android 上不带文件名时会落到
  /// `PreferenceManager.getDefaultSharedPreferences` 的**另一个文件**里，
  /// 而全 App 的读取方都看 legacy 那个 `FlutterSharedPreferences` ——
  /// 图快写错文件，等于恢复没生效。
  ///
  /// 注意随之而来的三个后果（都属于预期行为，不是 bug）：
  /// 1. 缓存键（cachedSongs / maidata / 各排行榜缓存等）会被清掉，
  ///    恢复后首次进相关页面会重新拉取，会慢一点。
  /// 2. 若备份里不含登录凭据，恢复后需要重新登录对应账号。
  ///    本项目的凭据键（probeDivingFishToken / probeLxnsImportToken /
  ///    luoxue_* 等）都**不在** [_cacheExactKeys] 里，会被正常备份与还原。
  /// 3. [_neverBackupKeys]（AWMC 网关令牌与调用日志）**既不导出也不还原**，
  ///    恢复后需要在「系统 → AWMC 网关」里重新设置令牌。
  ///
  /// 返回成功恢复的键数量。
  Future<int> restoreData(
    Map<String, dynamic> backupData, {
    bool clearFirst = true,
  }) async {
    // 服务是单例，先清掉上一次可能残留的快照。
    _rollbackSnapshot = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      // 与导出同理：先让 legacy 快照与磁盘一致，否则回滚会丢掉
      // 「本会话里用 async 通道新写的猜歌设置」。
      await prefs.reload();
      final data = backupData;

      if (clearFirst) {
        final previous = <String, dynamic>{};
        for (final key in prefs.getKeys()) {
          previous[key] = prefs.get(key);
        }
        _rollbackSnapshot = previous;

        final before = prefs.getKeys().length;
        await prefs.clear();
        debugPrint('DataBackup: 已清空原有 $before 个键');
      }

      var restoredCount = 0;
      for (final entry in data.entries) {
        final key = entry.key;
        final value = entry.value;

        // 敏感凭据不允许由备份写入（防止别人分享的备份里塞一个令牌进来）
        if (isNeverBackupKey(key)) {
          debugPrint('DataBackup: 跳过敏感键 $key（不随备份恢复）');
          continue;
        }
        if (value is! Map<String, dynamic> || !value.containsKey('type')) {
          continue;
        }

        final type = value['type'] as String;
        final rawValue = value['value'];
        try {
          final ok = await _writeOne(prefs, key, type, rawValue);
          if (ok) restoredCount++;
        } catch (e) {
          // 单条坏数据（类型对不上等）不该拖垮整次恢复，记日志继续。
          debugPrint('DataBackup: 恢复 $key 失败: $e');
        }
      }

      _rollbackSnapshot = null;
      debugPrint('DataBackup: 成功恢复 $restoredCount / ${data.length} 个键');
      return restoredCount;
    } catch (e) {
      debugPrint('DataBackup: 恢复失败: $e');
      if (clearFirst) await _rollbackToSnapshot();
      rethrow;
    }
  }

  /// 写单个键；成功返回 true，类型不认识返回 false。
  Future<bool> _writeOne(
    SharedPreferences prefs,
    String key,
    String type,
    Object? rawValue,
  ) async {
    switch (type) {
      case 'String':
        return prefs.setString(key, rawValue as String);
      case 'int':
        return prefs.setInt(key, rawValue as int);
      case 'double':
        return prefs.setDouble(key, (rawValue as num).toDouble());
      case 'bool':
        return prefs.setBool(key, rawValue as bool);
      case 'List<String>':
        final list =
            (rawValue as List<dynamic>).map((e) => e as String).toList();
        return prefs.setStringList(key, list);
      default:
        debugPrint('DataBackup: 未知类型 $type for key $key');
        return false;
    }
  }

  /// 把 [_rollbackSnapshot] 原样写回；快照里没有的键删掉。
  ///
  /// 「尽力而为」：任何一条失败都只记日志，不影响把其余数据放回去——
  /// 这是给恢复中途出错兜底的路径，本身不该再引入新的抛错。
  Future<void> _rollbackToSnapshot() async {
    final snapshot = _rollbackSnapshot;
    _rollbackSnapshot = null;
    if (snapshot == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      // 清掉「恢复过程中新写进去、而快照里本来没有」的键。
      for (final key in prefs.getKeys()) {
        if (!snapshot.containsKey(key)) {
          await prefs.remove(key);
        }
      }
      var restored = 0;
      for (final entry in snapshot.entries) {
        final wrapped = _encodePreferenceValue(entry.value);
        if (wrapped == null) continue;
        try {
          if (await _writeOne(prefs, entry.key, wrapped['type'] as String,
              wrapped['value'])) {
            restored++;
          }
        } catch (e) {
          debugPrint('DataBackup: 回滚 ${entry.key} 失败: $e');
        }
      }
      debugPrint('DataBackup: 已回滚清空前的 $restored / ${snapshot.length} 个键');
    } catch (e) {
      debugPrint('DataBackup: 回滚失败（数据可能不完整）: $e');
    }
  }

  /// 把 prefs 的原始值包成与备份文件一致的 `{type, value}`；不认识返回 null。
  static Map<String, dynamic>? _encodePreferenceValue(Object? value) {
    if (value is String) return {'type': 'String', 'value': value};
    if (value is int) return {'type': 'int', 'value': value};
    if (value is double) return {'type': 'double', 'value': value};
    if (value is bool) return {'type': 'bool', 'value': value};
    if (value is List<String>) return {'type': 'List<String>', 'value': value};
    return null;
  }

  /// 清空之后、把恢复到内存的各个单例重新读一遍。
  ///
  /// 不重载的话：这些 Store 的保存都是**整体写回**（写整个列表 / 整份设置），
  /// 用户在恢复后随手改一下，就会用内存里的旧值把刚导入的数据整体覆盖掉。
  /// 恢复流程结束时调用；[DataBackupPage] 仍会提示「建议重启」。
  Future<void> reloadAfterRestore() async {
    // 各 Store 先失效内存副本（失败也不阻断后续刷新）。
    ChartNoteService().invalidateCache();
    FavoriteFolderService().invalidateCache();
    CustomBest50Store().invalidateCache();
    ChartPackageHistoryStore().invalidateCache();
    await ChartPlaySettingsStore().reload();

    // 账号身份 / 主题 / 星标 / 昵称 / 线路。
    await ThemeManager().loadThemePreference();
    await FavoriteFeaturesNotifier.load();
    await LoginStateNotifier.load();
    await UserProfileNotifier.load();
    await CurrentDataSourceNotifier.load();
    await CommunityAvatarStore.instance.activate();

    // 曲库：内存里可能还留着恢复前的旧列表，必须先丢。
    MaimaiMusicDataManager().invalidateCache();

    // 筛选条件等「按整份缓存」的服务，让它们下次访问重读。
    PaiziProgressService().clearRecordsCache();
    PersonalizedScoreService().clearRecordsCache();

    // 同步线路：内存标志复位，下次进页面重读 prefs。
    await SyncRouteNotifier.instance.reloadRoutes();
  }
}
