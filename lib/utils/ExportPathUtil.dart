import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:media_scanner/media_scanner.dart';
import 'package:path_provider/path_provider.dart';

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

  static Directory? _cachedRoot;

  /// 清缓存：目录探测结果在应用生命周期内复用，权限变化后可手动重置。
  static void resetCache() => _cachedRoot = null;

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
  }) async {
    Directory build(Directory root) {
      final parts = <String>[
        root.path,
        appFolderName,
        if (subDir != null && subDir.isNotEmpty) subDir,
      ];
      return Directory(parts.join(Platform.pathSeparator));
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
  static Future<File> writeExportTextFile({
    required String fileName,
    required String content,
    String? subDir,
    void Function(String fallbackPath)? onFallback,
  }) async {
    final dir = await resolveExportDir(subDir: subDir, onFallback: onFallback);
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
