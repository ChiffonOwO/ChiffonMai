import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 一条「最近解析过的谱面包」记录
@immutable
class ChartPackageHistoryEntry {
  /// 应用目录下这份谱面包副本的路径。
  ///
  /// **不是**用户当初选中的那个原始路径：file_picker 在 Android 上返回的
  /// 多数是 `/data/user/0/<包名>/cache/file_picker/...`，系统会清；
  /// iOS 上更是临时沙箱路径，重启就没了。只存原始路径的话过几天点回去
  /// 就是「文件不存在」，所以这里存的是复制进应用目录的稳定副本。
  final String archivedPath;

  /// 显示用的文件名（原始文件名）
  final String displayName;

  final DateTime importedAt;

  const ChartPackageHistoryEntry({
    required this.archivedPath,
    required this.displayName,
    required this.importedAt,
  });

  Map<String, dynamic> toJson() => {
        'archivedPath': archivedPath,
        'displayName': displayName,
        'importedAt': importedAt.millisecondsSinceEpoch,
      };

  static ChartPackageHistoryEntry? fromJson(Map<String, dynamic> json) {
    final path = json['archivedPath']?.toString() ?? '';
    if (path.isEmpty) return null;
    return ChartPackageHistoryEntry(
      archivedPath: path,
      displayName: json['displayName']?.toString() ?? '未命名谱面包',
      importedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['importedAt'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

/// 「自定义谱面播放」最近解析过的谱面包记录。
///
/// - 最多保留 [maxEntries] 条，超出时删掉最旧的**并同时删除它的归档文件**，
///   所以存储占用不会无限增长。
/// - 同一份原始文件重复导入不会产生多条：按 [displayName] + 文件大小去重太脆，
///   这里改为「同名的旧记录被顶掉」，符合用户「最近 10 首」的直觉。
class ChartPackageHistoryStore {
  static final ChartPackageHistoryStore _instance =
      ChartPackageHistoryStore._internal();
  factory ChartPackageHistoryStore() => _instance;
  ChartPackageHistoryStore._internal();

  static const int maxEntries = 10;
  static const String _prefsKey = 'custom_chart_package_history_v1';

  /// 归档目录名（相对于应用文档目录）
  static const String _archiveDirName = 'custom_chart_play/archives';

  List<ChartPackageHistoryEntry> _entries = [];
  bool _loaded = false;

  /// 内存中的当前列表（未 [load] 时为空）
  List<ChartPackageHistoryEntry> get entries => List.unmodifiable(_entries);

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = json.decode(raw);
        if (decoded is List) {
          final list = <ChartPackageHistoryEntry>[];
          for (final e in decoded) {
            if (e is Map) {
              final entry = ChartPackageHistoryEntry.fromJson(
                  Map<String, dynamic>.from(e));
              if (entry != null) list.add(entry);
            }
          }
          _entries = list;
        }
      }
    } catch (e) {
      debugPrint('ChartPackageHistory: 读取历史失败: $e');
      _entries = [];
    }
    _loaded = true;
  }

  /// 归档目录（懒创建）
  Future<Directory> _archiveDir() async {
    final docDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docDir.path}/$_archiveDirName');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  /// 把一份谱面包归档并记入历史。
  ///
  /// [bytes] 是压缩包内容，[displayName] 是用户看到的文件名。
  /// 返回归档后的记录；写盘失败时抛异常，由调用方决定是否继续走后续流程。
  Future<ChartPackageHistoryEntry> archive(
    List<int> bytes,
    String displayName,
  ) async {
    await load();
    final dir = await _archiveDir();

    // 归档文件名：时间戳 + 原名，既保证唯一又能从文件名看出是哪首
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = _sanitize(displayName);
    final archived = File('${dir.path}/${stamp}_$safeName');
    await archived.writeAsBytes(bytes, flush: true);

    final entry = ChartPackageHistoryEntry(
      archivedPath: archived.path,
      displayName: displayName,
      importedAt: DateTime.now(),
    );

    // 同名旧记录先移除（含它的归档文件），避免列表里出现两条一样的名字
    final stale = _entries.where((e) => e.displayName == displayName).toList();
    for (final s in stale) {
      _entries.remove(s);
      await _deleteArchiveFile(s.archivedPath);
    }

    _entries.insert(0, entry);

    // 超出上限：从尾部（最旧）开始裁剪并删文件
    while (_entries.length > maxEntries) {
      final removed = _entries.removeLast();
      await _deleteArchiveFile(removed.archivedPath);
    }

    await _persist();
    return entry;
  }

  /// 从历史里移除一条（同时删除归档文件）
  Future<void> remove(ChartPackageHistoryEntry entry) async {
    await load();
    _entries.removeWhere((e) => e.archivedPath == entry.archivedPath);
    await _deleteArchiveFile(entry.archivedPath);
    await _persist();
  }

  /// 清空历史（同时删除所有归档文件）
  Future<void> clear() async {
    await load();
    final paths = _entries.map((e) => e.archivedPath).toList();
    _entries = [];
    for (final p in paths) {
      await _deleteArchiveFile(p);
    }
    await _persist();
  }

  /// 归档文件是否还在（用户在文件管理器里删过，或被系统清理过）
  bool exists(ChartPackageHistoryEntry entry) =>
      File(entry.archivedPath).existsSync();

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        json.encode(_entries.map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('ChartPackageHistory: 写入历史失败: $e');
    }
  }

  Future<void> _deleteArchiveFile(String path) async {
    try {
      final f = File(path);
      if (f.existsSync()) await f.delete();
    } catch (e) {
      debugPrint('ChartPackageHistory: 删除归档失败 $path: $e');
    }
  }

  /// 文件名里剔除路径分隔符等不安全字符
  static String _sanitize(String raw) {
    var name = raw.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_').trim();
    if (name.isEmpty) name = 'chart.adx';
    if (name.length > 80) name = name.substring(0, 80);
    return name;
  }
}
