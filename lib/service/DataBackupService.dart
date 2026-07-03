import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:media_scanner/media_scanner.dart';

/// 数据备份服务
/// 导出/导入所有 SharedPreferences 数据为 JSON 文件
class DataBackupService {
  static final DataBackupService _instance = DataBackupService._internal();
  factory DataBackupService() => _instance;
  DataBackupService._internal();

  /// 导出所有数据到 JSON 文件
  /// 返回保存的文件路径，null 表示用户取消或失败
  Future<String?> exportToFile() async {
    try {
      // 1. 读取所有 SharedPreferences 数据
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final data = <String, dynamic>{};

      for (final key in keys) {
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

      // 2. 构建备份元数据
      final backup = {
        'version': 1,
        'appName': 'ChiffonMai',
        'exportedAt': DateTime.now().toIso8601String(),
        'exportedAtTimestamp': DateTime.now().millisecondsSinceEpoch,
        'keyCount': keys.length,
        'data': data,
      };

      // 3. 序列化为 JSON
      final jsonStr = const JsonEncoder.withIndent('  ').convert(backup);
      final bytes = utf8.encode(jsonStr);

      // 4. 让用户选择保存路径
      final dateStr =
          '${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}';
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

  /// 将备份数据恢复到 SharedPreferences
  /// 返回成功恢复的键数量
  Future<int> restoreData(Map<String, dynamic> backupData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = backupData;
      int restoredCount = 0;

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
