import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:media_scanner/media_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 统一的「公开导出目录」工具。
///
/// 目标：导出产物必须能被系统自带的文件管理器直接搜到，
/// 而不是丢在 Android/data/<包名>/files 这类私有沙箱里。
///
/// 目录策略（按优先级）：
///   1. 外部存储 `Download/ChiffonMai`（Android 最常见、最好找）
///   2. 外部存储 `Documents/ChiffonMai`
///   3. 桌面端系统下载目录 `Downloads/ChiffonMai`
///   4. 兜底：应用文档目录 `ChiffonMai`（iOS / 权限全部失败时）
class ExportPathUtil {
  ExportPathUtil._();

  /// 所有导出产物统一收纳在这个名字的文件夹下，避免污染用户 Download 根目录。
  static const String appFolderName = 'ChiffonMai';

  /// 探测用临时文件名，写完即删。
  static const String _probeFileName = '.chiffonmai_write_probe';
  static const String _customRootKey = 'export_custom_root';

  static Directory? _cachedRoot;
  static String? _customRoot;
  static bool _customRootLoaded = false;

  /// 清缓存：目录探测结果在应用生命周期内复用，权限变化后可手动重置。
  static void resetCache() => _cachedRoot = null;

  static Future<void> _loadCustomRoot() async {
    if (_customRootLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    _customRoot = prefs.getString(_customRootKey);
    _customRootLoaded = true;
  }

  static Future<void> _saveCustomRoot(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    _customRoot = path;
    _customRootLoaded = true;
    if (path == null || path.isEmpty) {
      await prefs.remove(_customRootKey);
    } else {
      await prefs.setString(_customRootKey, path);
    }
    resetCache();
  }

  /// 在一次下载/导出前让用户确认保存位置。
  ///
  /// 默认位置仍是应用的公开目录；用户选择的目录会记住，下一次打开时可以
  /// 直接继续使用，也可以在这里恢复为应用默认目录。
  static Future<bool> prepareForExport(
    BuildContext context, {
    String? subDir,
    String title = '选择保存位置',
  }) async {
    await _loadCustomRoot();
    if (!context.mounted) return false;
    final defaultRoot = await _resolvePublicRoot();
    final docs = await getApplicationDocumentsDirectory();
    final currentRoot = _customRoot == null
        ? '${(defaultRoot ?? docs).path}${Platform.pathSeparator}$appFolderName'
        : _customRoot!;
    final suffix = subDir == null || subDir.isEmpty
        ? ''
        : '${Platform.pathSeparator}$subDir';
    final currentPath = '$currentRoot$suffix';
    final choice = await showDialog<_ExportPathChoice>(
      context: context,
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '当前保存位置：',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.maxFinite,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: SelectableText(
                  currentPath,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    height: 1.4,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '可以使用应用默认公开目录，或选择一个自定义文件夹。',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                try {
                  final selected = await FilePicker.getDirectoryPath(
                    dialogTitle: title,
                  );
                  if (selected != null &&
                      selected.trim().isNotEmpty &&
                      dialogContext.mounted) {
                    Navigator.of(dialogContext)
                        .pop(_ExportPathChoice.custom(selected.trim()));
                  }
                } catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text('选择保存目录失败：$e')),
                    );
                  }
                }
              },
              child: const Text('选择其他目录'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext)
                  .pop(const _ExportPathChoice.defaultPath()),
              child: const Text('使用默认路径'),
            ),
          ],
        );
      },
    );
    if (choice == null) return false;
    if (choice.path != null) {
      final dir = Directory(choice.path!);
      if (!await _isWritable(dir)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('这个目录不可写，请换一个文件夹。')),
          );
        }
        return false;
      }
      await _saveCustomRoot(choice.path);
    } else {
      await _saveCustomRoot(null);
    }
    return true;
  }

  /// 返回可写的「公开根目录」（尚未拼接 ChiffonMai 子目录）。
  ///
  /// 注意这里**不包含** `getExternalStorageDirectory()`：它在 Android 上返回的是
  /// `Android/data/<包名>/files`，属于应用私有沙箱，恰恰是本次要摆脱的位置。
  /// 把它当公开目录用会让 [resolveExportDir] 以为成功了，从而吞掉给用户的提示。
  static Future<Directory?> _resolvePublicRoot() async {
    // 1) Android 外部存储固定路径：文件管理器里最直观的位置
    if (Platform.isAndroid) {
      for (final candidate in const [
        '/storage/emulated/0/Download',
        '/sdcard/Download',
        '/storage/emulated/0/Documents',
      ]) {
        final dir = Directory(candidate);
        // 只复用已存在的目录，绝不凭空创建外部存储根目录
        if (!await dir.exists()) continue;
        if (await _isWritable(dir)) return dir;
      }
    }

    // 2) 桌面端 / 其他平台：交给 path_provider 决定系统下载目录
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null && await _isWritable(downloads)) return downloads;
    } catch (e) {
      debugPrint('[ExportPathUtil] getDownloadsDirectory 不可用: $e');
    }

    return null;
  }

  /// 实际写入一个探针文件来判断目录是否真的可写。
  ///
  /// Android 11+ 的分区存储会让「目录存在」和「可写」变成两回事，
  /// 只靠 exists() 判断会得到一个随后写入失败的目录。
  static Future<bool> _isWritable(Directory dir) async {
    try {
      final probe = File('${dir.path}${Platform.pathSeparator}$_probeFileName');
      await probe.writeAsString('probe', flush: true);
      await probe.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 返回导出目录（`<公开根>/ChiffonMai[/subDir]`），保证已创建。
  ///
  /// [subDir] 用于再分一层，例如 `谱面` / `收藏夹`。
  /// 公开目录全部不可写时退化为应用文档目录，并通过 [onFallback] 告知调用方，
  /// 以便在 UI 上提示用户「这个路径可能需要在文件管理器里手动找」。
  static Future<Directory> resolveExportDir({
    String? subDir,
    void Function(String fallbackPath)? onFallback,
    bool allowPrivateFallback = true,
  }) async {
    Directory build(Directory root) {
      final parts = <String>[
        root.path,
        appFolderName,
        if (subDir != null && subDir.isNotEmpty) subDir,
      ];
      return Directory(parts.join(Platform.pathSeparator));
    }

    await _loadCustomRoot();
    if (_customRoot != null) {
      final custom = Directory(_customRoot!);
      final dir = subDir == null || subDir.isEmpty
          ? custom
          : Directory('${custom.path}${Platform.pathSeparator}$subDir');
      try {
        if (!await dir.exists()) await dir.create(recursive: true);
        if (await _isWritable(dir)) return dir;
      } catch (e) {
        debugPrint('[ExportPathUtil] 自定义目录不可写，恢复应用默认目录: $e');
      }
      await _saveCustomRoot(null);
    }

    _cachedRoot ??= await _resolvePublicRoot();

    if (_cachedRoot != null) {
      final dir = build(_cachedRoot!);
      try {
        if (!await dir.exists()) await dir.create(recursive: true);
        if (await _isWritable(dir)) return dir;
      } catch (e) {
        debugPrint('[ExportPathUtil] 公开目录创建/写入失败，回退私有目录: $e');
      }
      // 缓存失效（权限被回收等），下次重新探测
      _cachedRoot = null;
    }

    if (!allowPrivateFallback) {
      throw StateError('公开导出目录不可写，已拒绝写入应用私有目录');
    }
    final docs = await getApplicationDocumentsDirectory();
    final fallback = build(docs);
    if (!await fallback.exists()) await fallback.create(recursive: true);
    // Android 的应用文档目录位于 Android/data/<包名>/files 下，文件管理器一般看不到，
    // 所以必须提示用户；iOS 的 Documents 本身就能通过「文件」App 访问，不算异常。
    if (Platform.isAndroid) onFallback?.call(fallback.path);
    return fallback;
  }

  /// 把字节写进公开导出目录，并通知系统媒体库刷新。
  ///
  /// 返回落盘后的 [File]。文件名冲突时直接覆盖（导出语义通常是「重新导出一次」）。
  static Future<File> writeExportFile({
    required String fileName,
    required List<int> bytes,
    String? subDir,
    void Function(String fallbackPath)? onFallback,
  }) async {
    final dir = await resolveExportDir(subDir: subDir, onFallback: onFallback);
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes, flush: true);
    await notifyMediaScanner(file);
    debugPrint('[ExportPathUtil] 导出成功 → ${file.path}');
    return file;
  }

  /// 同 [writeExportFile]，但写入文本。
  /// 按流导出大文件，失败时删除临时文件，完整写入后才发布最终文件。
  static Future<File> writeExportStream({
    required String fileName,
    required Stream<List<int>> stream,
    String? subDir,
    void Function(String fallbackPath)? onFallback,
    bool allowPrivateFallback = true,
  }) async {
    final dir = await resolveExportDir(
      subDir: subDir,
      onFallback: onFallback,
      allowPrivateFallback: allowPrivateFallback,
    );
    final target = File('${dir.path}${Platform.pathSeparator}$fileName');
    final temporary =
        File('${target.path}.${DateTime.now().microsecondsSinceEpoch}.part');
    final sink = temporary.openWrite();
    // 立即监听文件系统错误，防止流尚在下载时出现未处理的异步异常。
    final sinkDone = sink.done.then<Object?>((_) => null,
        onError: (Object error, StackTrace _) => error);
    try {
      await sink.addStream(stream);
      await sink.flush();
      await sink.close();
      final writeError = await sinkDone;
      if (writeError != null) throw writeError;
      final file = await temporary.rename(target.path);
      await notifyMediaScanner(file);
      return file;
    } catch (_) {
      try {
        await sink.close();
      } catch (_) {}
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
  }

  /// 同 [writeExportFile]，但写入文本。
  static Future<File> writeExportTextFile({
    required String fileName,
    required String content,
    String? subDir,
    void Function(String fallbackPath)? onFallback,
    bool allowPrivateFallback = true,
  }) async {
    final dir = await resolveExportDir(
        subDir: subDir,
        onFallback: onFallback,
        allowPrivateFallback: allowPrivateFallback);
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsString(content, flush: true);
    await notifyMediaScanner(file);
    debugPrint('[ExportPathUtil] 导出成功 → ${file.path}');
    return file;
  }

  /// 通知系统扫描新文件，否则部分文件管理器要等重启才能看到。
  static Future<void> notifyMediaScanner(File file) async {
    if (!Platform.isAndroid) return;
    try {
      await MediaScanner.loadMedia(path: file.path);
    } catch (e) {
      debugPrint('[ExportPathUtil] 媒体扫描通知失败（不影响文件已落盘）: $e');
    }
  }

  /// 清理文件名中的非法字符。
  static String sanitizeFileName(String raw, {String fallback = 'export'}) {
    final cleaned = raw
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    // Windows/部分文件系统不允许结尾的点或空格
    final trimmed = cleaned.replaceAll(RegExp(r'[. ]+$'), '');
    if (trimmed.isEmpty) return fallback;
    // 防御超长文件名（多数文件系统上限 255 字节）
    return trimmed.length > 80 ? trimmed.substring(0, 80) : trimmed;
  }
}

class _ExportPathChoice {
  final String? path;
  const _ExportPathChoice.defaultPath() : path = null;
  const _ExportPathChoice.custom(this.path);
}
