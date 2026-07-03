import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:my_first_flutter_app/service/DataBackupService.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:my_first_flutter_app/utils/AppConstants.dart';

class DataBackupPage extends StatefulWidget {
  const DataBackupPage({super.key});

  @override
  State<DataBackupPage> createState() => _DataBackupPageState();
}

class _DataBackupPageState extends State<DataBackupPage> {
  final DataBackupService _service = DataBackupService();

  bool _isExporting = false;
  bool _isImporting = false;
  String? _lastExportPath;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textPrimaryColor = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          CommonWidgetUtil.buildCommonBgWidget(),
          CommonWidgetUtil.buildCommonChiffonBgWidget(context),
          Column(
            children: [
              // 标题栏
              Container(
                padding: EdgeInsets.fromLTRB(16, 48, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: textPrimaryColor),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '数据备份',
                          style: TextStyle(
                            color: textPrimaryColor,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 48),
                  ],
                ),
              ),

              // 主内容
              Expanded(
                child: Container(
                  margin: EdgeInsets.fromLTRB(8, 0, 8, 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      AppConstants.defaultShadow(brightness),
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
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
                                  '数据备份功能可以将你的本地数据（收藏夹、谱面笔记、设置偏好等）导出为 JSON 文件，方便换手机或恢复数据时使用。',
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
                          onPressed: _handleExport,
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
                          buttonText: _isImporting ? '导入中...' : '选择备份文件',
                          isLoading: _isImporting,
                          onPressed: _handleImport,
                          color: AppColors.warningOrange(brightness),
                          warningText: '⚠ 导入将覆盖现有数据，请谨慎操作',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonText,
    required bool isLoading,
    required VoidCallback onPressed,
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
        // 显示成功对话框，包含文件路径和操作指引
        final inDownload = path.contains('/Download');
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.successGreen(Theme.of(context).brightness), size: 28),
                SizedBox(width: 8),
                Text('导出成功'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('备份文件已保存' + (inDownload ? '到下载目录：' : '到：')),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(path,
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
                SizedBox(height: 12),
                if (inDownload)
                  Text('可在文件管理器的「下载」文件夹中找到该文件。',
                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('确定'),
              ),
            ],
          ),
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
              Text('即将从备份文件恢复数据，这将覆盖当前所有本地数据。'),
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
                  ],
                ),
              ),
              SizedBox(height: 12),
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
        final count = await _service.restoreData(backup['data']);
        if (mounted) {
          Fluttertoast.showToast(
            msg: '数据恢复成功！共恢复 $count 项数据。\n请重启应用以确保数据完全生效。',
            toastLength: Toast.LENGTH_LONG,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isImporting = false);
        Fluttertoast.showToast(
          msg: '导入失败: ${e.toString().replaceFirst("Exception: ", "")}',
          toastLength: Toast.LENGTH_LONG,
        );
      }
    }
  }
}