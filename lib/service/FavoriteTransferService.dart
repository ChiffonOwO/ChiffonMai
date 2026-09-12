import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../entity/FavoriteFolder.dart';
import '../utils/ExportPathUtil.dart';
import '../utils/ExportSettings.dart';
import 'FavoriteFolderService.dart';

/// 解析出来的导入包。
class FavoriteImportBundle {
  final List<FavoriteFolder> folders;
  final String? appName;
  final String? exportedAt;
  final int formatVersion;
  final String sourcePath;

  FavoriteImportBundle({
    required this.folders,
    required this.sourcePath,
    this.appName,
    this.exportedAt,
    this.formatVersion = 1,
  });

  int get chartCount =>
      folders.fold<int>(0, (sum, f) => sum + f.charts.length);
}

/// 收藏夹自定义格式的导入/导出服务。
///
/// 文件格式为 JSON，自描述、带版本号：
/// ```json
/// {
///   "format": "chiffonmai.favorites",
///   "formatVersion": 1,
///   "appName": "ChiffonMai",
///   "exportedAt": "2026-01-01T00:00:00.000",
///   "folders": [ { "id": "...", "name": "...", "charts": [ ... ] } ]
/// }
/// ```
///
/// 后缀由 [ExportSettings] 决定（默认 `.cmf`，用户可在设置页改）。
/// 导入按「内容」校验而非按后缀校验，因此无论用户把后缀改成什么都能导回来。
class FavoriteTransferService {
  static final FavoriteTransferService _instance =
      FavoriteTransferService._internal();
  factory FavoriteTransferService() => _instance;
  FavoriteTransferService._internal();

  /// 格式标识，用于识别本应用导出的文件。
  static const String formatTag = 'chiffonmai.favorites';

  /// 当前格式版本。
  static const int formatVersion = 1;

  // ---------------------------------------------------------------------------
  // 导出
  // ---------------------------------------------------------------------------

  /// 构造导出用的 JSON 文本。
  Future<String> buildPayload(List<FavoriteFolder> folders) async {
    String appVersion = '';
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {
      // 拿不到版本号不影响导出
    }

    final now = DateTime.now();
    final payload = <String, dynamic>{
      'format': formatTag,
      'formatVersion': formatVersion,
      'appName': 'ChiffonMai',
      if (appVersion.isNotEmpty) 'appVersion': appVersion,
      'exportedAt': now.toIso8601String(),
      'exportedAtTimestamp': now.millisecondsSinceEpoch,
      'folderCount': folders.length,
      'chartCount': folders.fold<int>(0, (s, f) => s + f.charts.length),
      'folders': folders.map((f) => f.toJson()).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// 导出若干收藏夹到公开目录，返回落盘文件。
  ///
  /// [fileBaseName] 为空时用 `favorites_<时间戳>`。
  Future<File> exportFolders(
    List<FavoriteFolder> folders, {
    String? fileBaseName,
    void Function(String fallbackPath)? onFallback,
  }) async {
    if (folders.isEmpty) {
      throw StateError('没有可导出的收藏夹');
    }

    final content = await buildPayload(folders);
    final ext = ExportSettings.favoriteExtension.value;
    final base = ExportPathUtil.sanitizeFileName(
      fileBaseName ??
          'favorites_${DateTime.now().millisecondsSinceEpoch.toString()}',
      fallback: 'favorites',
    );

    return ExportPathUtil.writeExportTextFile(
      fileName: '$base.$ext',
      content: content,
      subDir: '收藏夹',
      onFallback: onFallback,
    );
  }

  // ---------------------------------------------------------------------------
  // 导入
  // ---------------------------------------------------------------------------

  /// 弹出系统文件选择器并解析。
  ///
  /// 返回 null 表示用户取消。解析失败会抛出带中文说明的 [FormatException]。
  Future<FavoriteImportBundle?> pickAndParse() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.pickFiles(
        dialogTitle: '选择 ChiffonMai 收藏夹文件',
        // 自定义后缀无法映射成 MIME，用 any 才能保证任何后缀都选得中
        type: FileType.any,
        allowMultiple: false,
        withData: false,
      );
    } catch (e) {
      // 部分机型在 custom 类型下会直接抛错，降级重试一次
      debugPrint('[FavoriteTransfer] 文件选择失败，降级重试: $e');
      result = await FilePicker.pickFiles(
        dialogTitle: '选择 ChiffonMai 收藏夹文件',
        type: FileType.any,
        allowMultiple: false,
        withData: false,
      );
    }

    if (result == null || result.files.isEmpty) return null;
    final path = result.files.single.path;
    if (path == null || path.isEmpty) {
      throw const FormatException('无法读取所选文件');
    }
    return parseFile(path);
  }

  /// 解析指定路径的收藏夹文件。
  Future<FavoriteImportBundle> parseFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw FormatException('文件不存在：$path');
    }

    final raw = await _readAsText(file);
    final trimmed = raw.trimLeft();

    // 旧版导出的是人读的纯文本清单，不含 songId，无法还原成收藏夹
    if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) {
      throw const FormatException(
        '这个文件不是 ChiffonMai 收藏夹格式。\n'
        '（旧版导出的 .txt 纯文本清单不含歌曲 ID，无法还原成收藏夹，请重新导出一次）',
      );
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw const FormatException('文件内容不是合法的 JSON，可能已损坏');
    }

    final List<FavoriteFolder> folders;
    String? appName;
    String? exportedAt;
    var version = formatVersion;

    if (decoded is List) {
      // 容忍「根就是收藏夹数组」的写法
      folders = _foldersFromList(decoded);
    } else if (decoded is Map<String, dynamic>) {
      final tag = decoded['format'];
      if (tag != null && tag != formatTag) {
        throw FormatException('文件格式标识为 "$tag"，不是 ChiffonMai 收藏夹文件');
      }
      folders = _foldersFromMap(decoded);
      appName = decoded['appName'] as String?;
      exportedAt = decoded['exportedAt'] as String?;
      version = (decoded['formatVersion'] as num?)?.toInt() ?? formatVersion;
    } else {
      throw const FormatException('文件内容无法识别');
    }

    if (folders.isEmpty) {
      throw const FormatException('文件里没有任何收藏夹数据');
    }

    return FavoriteImportBundle(
      folders: folders,
      sourcePath: path,
      appName: appName,
      exportedAt: exportedAt,
      formatVersion: version,
    );
  }

  /// 从 `{folders: [...]}` / `{data: [...]}` / `{folder: {...}}` 中取出收藏夹。
  List<FavoriteFolder> _foldersFromMap(Map<String, dynamic> json) {
    final raw = json['folders'] ?? json['data'] ?? json['folder'];
    if (raw is List) return _foldersFromList(raw);
    if (raw is Map<String, dynamic>) return _foldersFromList([raw]);
    throw const FormatException('文件缺少 folders 字段');
  }

  List<FavoriteFolder> _foldersFromList(List<dynamic> list) {
    final folders = <FavoriteFolder>[];
    for (final item in list) {
      if (item is! Map<String, dynamic>) continue;
      try {
        final folder = FavoriteFolder.fromJson(item);
        // 丢弃既没名字也没谱面的空壳，避免导入出一堆空收藏夹
        if (folder.charts.isEmpty && folder.name.trim().isEmpty) continue;
        folders.add(folder);
      } catch (e) {
        debugPrint('[FavoriteTransfer] 跳过无法解析的收藏夹: $e');
      }
    }
    return folders;
  }

  /// 兼容 UTF-8 BOM 与旧编码，尽量把文件读成文本。
  Future<String> _readAsText(File file) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw const FormatException('文件是空的');
    }
    var text = utf8.decode(bytes, allowMalformed: true);
    // 去掉 BOM
    if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
      text = text.substring(1);
    }
    return text;
  }

  /// 应用导入。[replaceAll] 为 true 时先清空现有收藏夹。
  Future<FavoriteImportStats> apply(
    FavoriteImportBundle bundle, {
    bool replaceAll = false,
  }) {
    return FavoriteFolderService().importFolders(
      bundle.folders,
      replaceAll: replaceAll,
    );
  }
}
