import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:media_scanner/media_scanner.dart';

import '../constant/CacheKeyConstant.dart';

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
    CacheKeyConstant.knowledgeData,
    CacheKeyConstant.knowledgeTimestamp,
    CacheKeyConstant.luoxueSongsCache,
    CacheKeyConstant.trophiesCollectionsCacheData,
    CacheKeyConstant.iconsCollectionsCacheData,
    CacheKeyConstant.platesCollectionsCacheData,
    CacheKeyConstant.framesCollectionsCacheData,
    CacheKeyConstant.maiTagsCache,
    CacheKeyConstant.maiTagsCacheTimestamp,
    CacheKeyConstant.userPlayData,
    CacheKeyConstant.diffMusicData,
    CacheKeyConstant.diffMusicDataTimestamp,
    CacheKeyConstant.recommendationResults,
    CacheKeyConstant.totalRankingsCache,
    CacheKeyConstant.totalRankingsCacheTimestamp,
    CacheKeyConstant.shuiyuRankingsCache,
    CacheKeyConstant.shuiyuRankingsCacheTimestamp,
    CacheKeyConstant.luoxueRankingsCache,
    CacheKeyConstant.luoxueRankingsCacheTimestamp,
    CacheKeyConstant.avgRankingsCache,
    CacheKeyConstant.avgRankingsCacheTimestamp,
    CacheKeyConstant.coverHashCache,
    CacheKeyConstant.coverHashCacheTimestamp,
  };

  /// 前缀匹配的缓存键（这些键按歌曲 / 模式 / 难度拼接，数量不固定）
  static const List<String> _cacheKeyPrefixes = [
    CacheKeyConstant.maidataCachePrefix, // maidata_cache_<shortId>
    CacheKeyConstant.fittedRankingsCachePrefix, // fitted_rankings_cache_<mode>
    CacheKeyConstant.fittedRankingsCacheTimestampPrefix,
    CacheKeyConstant.songCommentsCachePrefix, // song_comments_cache_<songId>
    CacheKeyConstant.songCommentsCacheTimestampPrefix,
    // 双账号：成绩存档（可重新拉取）不进备份；
    // 身份存档 account_archive_identity_* 与 account_store 属于用户数据，保留在备份里
    CacheKeyConstant.accountArchivePlayPrefix, // account_archive_play_<source>
  ];

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
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final data = <String, dynamic>{};
      var skipped = 0;

      for (final key in keys) {
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
          'DataBackup: 导出 ${data.length} 个用户数据键，跳过 $skipped 个缓存键');

      // 2. 构建备份元数据
      final backup = {
        'version': 2,
        'appName': 'ChiffonMai',
        'exportedAt': DateTime.now().toIso8601String(),
        'exportedAtTimestamp': DateTime.now().millisecondsSinceEpoch,
        'keyCount': data.length,
        'skippedCacheKeys': skipped,
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
  /// 注意随之而来的两个后果（都属于预期行为，不是 bug）：
  /// 1. 缓存键（cachedSongs / maidata / 各排行榜缓存等）会被清掉，
  ///    恢复后首次进相关页面会重新拉取，会慢一点。
  /// 2. 若备份里不含登录凭据，恢复后需要重新登录对应账号。
  ///    本项目的凭据键（probeDivingFishToken / probeLxnsImportToken /
  ///    luoxue_* 等）都**不在** [_cacheExactKeys] 里，会被正常备份与还原。
  ///
  /// 返回成功恢复的键数量。
  Future<int> restoreData(
    Map<String, dynamic> backupData, {
    bool clearFirst = true,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = backupData;
      int restoredCount = 0;

      if (clearFirst) {
        final before = prefs.getKeys().length;
        await prefs.clear();
        debugPrint('DataBackup: 已清空原有 $before 个键');
      }

      for (final entry in data.entries) {
        final key = entry.key;
        final value = entry.value;

        if (value is Map<String, dynamic> && value.containsKey('type')) {
          final type = value['type'] as String;
          final rawValue = value['value'];

          try {
            switch (type) {
              case 'String':
                await prefs.setString(key, rawValue as String);
                restoredCount++;
                break;
              case 'int':
                await prefs.setInt(key, rawValue as int);
                restoredCount++;
                break;
              case 'double':
                await prefs.setDouble(key, (rawValue as num).toDouble());
                restoredCount++;
                break;
              case 'bool':
                await prefs.setBool(key, rawValue as bool);
                restoredCount++;
                break;
              case 'List<String>':
                final list = (rawValue as List<dynamic>)
                    .map((e) => e as String)
                    .toList();
                await prefs.setStringList(key, list);
                restoredCount++;
                break;
              default:
                debugPrint('DataBackup: 未知类型 $type for key $key');
            }
          } catch (e) {
            debugPrint('DataBackup: 恢复 $key 失败: $e');
          }
        }
      }

      debugPrint('DataBackup: 成功恢复 $restoredCount / ${data.length} 个键');
      return restoredCount;
    } catch (e) {
      debugPrint('DataBackup: 恢复失败: $e');
      rethrow;
    }
  }
}
