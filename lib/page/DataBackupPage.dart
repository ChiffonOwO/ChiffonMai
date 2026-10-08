import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:my_first_flutter_app/service/DataBackupService.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';
import '../widgets/BackgroundPageScaffold.dart';
import '../widgets/ExportSuccessDialog.dart';

class DataBackupPage extends StatefulWidget {
  const DataBackupPage({super.key});

  @override
  State<DataBackupPage> createState() => _DataBackupPageState();
}

class _DataBackupPageState extends State<DataBackupPage> {
  final DataBackupService _service = DataBackupService();

  bool _isExporting = false;
  bool _isImporting = false;

  /// 已经确认、正在往 prefs 里写的那一段。
  ///
  /// 恢复是「先清空再逐键写入」，几百个键会明显卡一下。**这一段必须一直挂着
  /// loading 且禁用按钮**：既不给用户「点了没反应、是不是卡死了」的错觉，
  /// 也避免他连点两次、让两轮写入交错在同一份 prefs 上。
  bool _isRestoring = false;
  String? _lastExportPath;

  /// 任一导入/导出在进行中：两个按钮都要禁用，避免互相踩。
  bool get _busy => _isExporting || _isImporting;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return BackgroundPageScaffold(
      title: '数据备份',
      resizeToAvoidBottomInset: false,
      contentPadding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom + 10,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 说明
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.tableBorder(brightness)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: AppColors.linkBlue(brightness), size: 24),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '数据备份功能可以将你的本地数据（收藏夹、谱面笔记、账号凭据、设置偏好等）导出为 JSON 文件，方便换手机或恢复数据时使用。\n\n'
                                  '可重新拉取的缓存（曲库、maidata、排行榜等）不会写进备份文件，恢复后首次进入相关页面会自动重新拉取。',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 24),

                        // 导出区域
                        _buildSectionCard(
                          icon: Icons.file_upload,
                          title: '导出备份',
                          subtitle: '将当前所有本地数据导出为 JSON 文件',
                          buttonText: _isExporting ? '导出中...' : '导出备份文件',
                          isLoading: _isExporting,
                          onPressed: _busy ? null : _handleExport,
                          color: AppColors.successGreen(brightness),
                        ),

                        // 上次导出路径
                        if (_lastExportPath != null) ...[
                          SizedBox(height: 8),
                          Container(
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle,
                                    size: 18, color: AppColors.successGreen(brightness)),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '已导出到: $_lastExportPath',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        SizedBox(height: 24),
                        Divider(),
                        SizedBox(height: 24),

                        // 导入区域
                        _buildSectionCard(
                          icon: Icons.file_download,
                          title: '导入备份',
                          subtitle: '从 JSON 文件恢复之前备份的数据',
                          buttonText: _isRestoring
                              ? '正在恢复数据...'
                              : (_isImporting ? '导入中...' : '选择备份文件'),
                          isLoading: _isImporting || _isRestoring,
                          onPressed: _busy ? null : _handleImport,
                          color: AppColors.warningOrange(brightness),
                          warningText:
                              '⚠ 导入会先清空当前所有本地数据，再写入备份内容；\n'
                              '　 备份里没有的项目（含各类缓存）会被一并抹掉。\n'
                              '　 恢复过程中请不要退出页面。',
                        ),
                      ],
                    ),
                  ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonText,
    required bool isLoading,
    required VoidCallback? onPressed,
    required Color color,
    String? warningText,
  }) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.tableBorder(Theme.of(context).brightness)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 32, color: color),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : onPressed,
              icon: isLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(
                      icon == Icons.file_upload
                          ? Icons.file_upload
                          : Icons.file_download,
                      color: Colors.white,
                    ),
              label: Text(buttonText),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          if (warningText != null) ...[
            SizedBox(height: 12),
            Text(
              warningText,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.errorRed(Theme.of(context).brightness),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleExport() async {
    setState(() => _isExporting = true);

    try {
      final path = await _service.exportToFile();
      if (path != null && mounted) {
        setState(() {
          _lastExportPath = path;
          _isExporting = false;
        });
        await showExportSuccessDialog(
          context,
          filePath: path,
          fileName: '备份文件',
          warning: path.contains('/Download')
              ? '可在文件管理器的「下载」文件夹中找到该文件。'
              : null,
        );
      } else {
        if (mounted) {
          setState(() => _isExporting = false);
          Fluttertoast.showToast(
            msg: '导出已取消',
            toastLength: Toast.LENGTH_SHORT,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        Fluttertoast.showToast(
          msg: '导出失败: ${e.toString().replaceFirst("Exception: ", "")}',
          toastLength: Toast.LENGTH_LONG,
        );
      }
    }
  }

  Future<void> _handleImport() async {
    setState(() => _isImporting = true);

    try {
      final backup = await _service.importFromFile();

      if (!mounted) return;
      setState(() => _isImporting = false);

      if (backup == null) {
        return; // 用户取消
      }

      // 显示确认对话框
      final exportedAt = backup['exportedAt'] ?? '未知';
      final keyCount = backup['keyCount'] ?? 0;
      final version = backup['version'] ?? '?';
      final skippedCacheKeys = backup['skippedCacheKeys'];

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.warningOrange(Theme.of(context).brightness), size: 28),
              SizedBox(width: 8),
              Text('确认恢复数据'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('即将恢复数据。恢复前会先清空当前所有本地数据，然后写入备份内容——'
                  '备份里没有的项目都会被抹掉。'),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('备份版本: v$version',
                        style: TextStyle(fontSize: 13)),
                    Text('导出时间: $exportedAt',
                        style: TextStyle(fontSize: 13)),
                    Text('包含 $keyCount 个数据项',
                        style: TextStyle(fontSize: 13)),
                    if (skippedCacheKeys != null)
                      Text('已排除 $skippedCacheKeys 个缓存项',
                          style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              SizedBox(height: 12),
              Text(
                '缓存（曲库、maidata、排行榜等）会被清空，恢复后首次进入相关页面会自动重新拉取，可能稍慢。',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '此操作不可撤销，确定要继续吗？',
                style: TextStyle(
                  color: AppColors.errorRed(Theme.of(context).brightness),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warningOrange(Theme.of(context).brightness),
                foregroundColor: Colors.white,
              ),
              child: Text('确认恢复'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        // 恢复期间一直挂 loading 并禁用按钮：这一段要逐键写 prefs，会明显卡一下，
        // 不给反馈的话用户会以为「导入卡死」，还可能连点触发第二轮写入。
        if (mounted) setState(() => _isRestoring = true);
        try {
          final count = await _service.restoreData(backup['data']);
          // 把恢复到内存的各个单例重新读一遍：这些 Store 的保存都是整体写回，
          // 不重载的话用户恢复后随手改一下，就会用旧值把刚导入的数据盖掉。
          await _service.reloadAfterRestore();
          if (mounted) {
            Fluttertoast.showToast(
              msg: '数据恢复成功！共恢复 $count 项数据。\n建议重启应用以确保完全生效。',
              toastLength: Toast.LENGTH_LONG,
            );
          }
        } finally {
          if (mounted) setState(() => _isRestoring = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isImporting = false;
          _isRestoring = false;
        });
        Fluttertoast.showToast(
          msg: '导入失败: ${e.toString().replaceFirst("Exception: ", "")}',
          toastLength: Toast.LENGTH_LONG,
        );
      }
    }
  }
}
