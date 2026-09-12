import 'package:flutter/material.dart';

import '../service/FavoriteTransferService.dart';
import 'ExportSettings.dart';

/// 导入方式
enum FavoriteImportMode { merge, replace }

/// 「导入收藏夹」的完整交互流程。
///
/// 抽成独立函数是因为它有两个入口：
///   1. 收藏夹列表页的「导入收藏夹」按钮（走系统文件选择器）
///   2. 在系统文件管理器里点开收藏夹文件、或「分享 → ChiffonMai」，
///      由 Android intent 唤起 App（此时路径已知，[presetPath] 非空）
///
/// [context] 必须是 **Navigator 之下** 的 context（例如 `navigatorKey.currentState.overlay.context`），
/// 因为 `showDialog` 是靠「向上找 Navigator」来定位的；传 Navigator 自身的 context 会找不到。
///
/// 返回 true 表示确实导入了数据。
Future<bool> runFavoriteImportFlow(
  BuildContext context, {
  String? presetPath,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final service = FavoriteTransferService();

  // ---- 1. 取得文件并解析 ----
  FavoriteImportBundle? bundle;
  try {
    bundle = presetPath != null
        ? await service.parseFile(presetPath)
        : await service.pickAndParse();
  } on FormatException catch (e) {
    if (context.mounted) {
      await _showMessageDialog(context, title: '无法导入', message: e.message);
    }
    return false;
  } catch (e) {
    if (context.mounted) {
      await _showMessageDialog(context, title: '无法导入', message: '$e');
    }
    return false;
  }

  // 用户取消选择
  if (bundle == null) return false;
  if (!context.mounted) return false;

  // ---- 2. 确认对话框（选合并 / 覆盖） ----
  final mode = await _showConfirmDialog(context, bundle);
  if (mode == null) return false;

  // ---- 3. 执行导入 ----
  try {
    final stats = await service.apply(
      bundle,
      replaceAll: mode == FavoriteImportMode.replace,
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text('导入完成：${stats.describe()}'),
        duration: const Duration(seconds: 4),
      ),
    );
    return true;
  } catch (e) {
    if (context.mounted) {
      await _showMessageDialog(context, title: '导入失败', message: '$e');
    }
    return false;
  }
}

Future<FavoriteImportMode?> _showConfirmDialog(
  BuildContext context,
  FavoriteImportBundle bundle,
) {
  return showDialog<FavoriteImportMode>(
    context: context,
    builder: (ctx) {
      var mode = FavoriteImportMode.merge;
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          final scheme = Theme.of(ctx).colorScheme;
          return AlertDialog(
            title: const Text('导入收藏夹'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '共 ${bundle.folders.length} 个收藏夹、${bundle.chartCount} 个谱面',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  // 逐条列出收藏夹，让用户确认导入的确实是想要的内容
                  ...bundle.folders.take(8).map(
                        (f) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: Text(
                            '· ${f.name}（${f.charts.length} 个谱面）',
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                  if (bundle.folders.length > 8)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        '· 其余 ${bundle.folders.length - 8} 个收藏夹…',
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const Divider(height: 24),
                  RadioListTile<FavoriteImportMode>(
                    value: FavoriteImportMode.merge,
                    groupValue: mode,
                    onChanged: (v) => setLocal(() => mode = v!),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('合并到现有收藏夹'),
                    subtitle: const Text(
                      '同名收藏夹会合并，重复谱面自动跳过',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  RadioListTile<FavoriteImportMode>(
                    value: FavoriteImportMode.replace,
                    groupValue: mode,
                    onChanged: (v) => setLocal(() => mode = v!),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('覆盖导入'),
                    subtitle: Text(
                      '先清空当前所有收藏夹，再导入文件内容',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(mode),
                child: const Text('导入'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _showMessageDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(child: Text(message)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('知道了'),
        ),
      ],
    ),
  );
}

/// 导入按钮的文字提示，带上当前自定义后缀，让用户知道要选什么文件。
String favoriteImportHint() =>
    '支持 ${ExportSettings.favoriteExtensionWithDot} 等 ChiffonMai 收藏夹文件';

/// 导出文件名前缀，集中在这里方便以后调整。
const String favoriteExportPrefix = 'ChiffonMai_favorites';
