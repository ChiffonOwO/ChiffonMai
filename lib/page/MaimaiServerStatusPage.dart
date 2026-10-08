import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/entity/chongxi/MaimaiServerStatusModel.dart';
import 'package:my_first_flutter_app/service/chongxi/MaimaiServerStatusService.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:my_first_flutter_app/utils/ExternalLaunchUtil.dart';
import '../widgets/BackgroundPageScaffold.dart';

/// 舞萌服务器状态页面。
///
/// 数据来自 mai.chongxi.us 的机器人状态接口，页面直接展示接口提供的总览、
/// 各服务状态、延迟和最近上报记录。
class MaimaiServerStatusPage extends StatefulWidget {
  const MaimaiServerStatusPage({super.key});

  @override
  State<MaimaiServerStatusPage> createState() => _MaimaiServerStatusPageState();
}

class _MaimaiServerStatusPageState extends State<MaimaiServerStatusPage> {
  MaimaiServerStatusEntity? _serverStatus;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadServerStatus();
  }

  Future<void> _loadServerStatus() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }

    try {
      final status = await MaimaiServerStatusService.getServerStatus();
      if (!mounted) return;
      if (status == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = '暂时无法获取服务器状态';
        });
        return;
      }
      setState(() {
        _serverStatus = status;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[MaimaiServerStatusPage] 加载失败: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = '加载服务器状态失败';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundPageScaffold(
      title: '服务器状态',
      contentPadding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom + 10,
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? _buildErrorState()
              : _buildServerStatusContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(_errorMessage),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: _loadServerStatus,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildServerStatusContent() {
    final status = _serverStatus;
    if (status == null) return const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: _loadServerStatus,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          TextButton.icon(
            onPressed: () => ExternalLaunchUtil.open(
              Uri.parse('https://mai.chongxi.us/'),
            ),
            icon: const Icon(Icons.open_in_new_rounded, size: 17),
            label: const Text('数据来源于 isMaiDown by Chongxi'),
            style: TextButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            ),
          ),
          _buildOverviewCard(status),
          const SizedBox(height: 16),
          Text(
            '服务状态',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          ...status.services.map(_buildServiceCard),
          if (status.recentLogs.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              '最近上报',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            _buildRecentLogs(status.recentLogs),
          ],
        ],
      ),
    );
  }

  Widget _buildOverviewCard(MaimaiServerStatusEntity status) {
    final color = _statusColor(status.status);
    final latency = status.latency.currentMs;
    final reports = status.reports;
    final statusLabel = status.statusText.isEmpty
        ? (status.isHealthy ? '好' : '坏')
        : status.statusText;

    return Card(
      elevation: 0,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.dns_outlined, color: color, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status.verdictText,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(statusLabel, color),
              ],
            ),
            if (status.summary.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                status.summary,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildMetricChip(
                  Icons.speed_outlined,
                  latency == null ? '延迟 --' : '延迟 $latency ms',
                  _latencyColor(latency),
                ),
                if (status.latency.loadText.isNotEmpty)
                  _buildMetricChip(
                    Icons.swap_vert_rounded,
                    status.latency.loadText,
                    Theme.of(context).colorScheme.primary,
                  ),
                _buildMetricChip(
                  Icons.check_circle_outline,
                  '正常 ${reports.normalCount}',
                  AppColors.successGreen(Theme.of(context).brightness),
                ),
                _buildMetricChip(
                  Icons.warning_amber_rounded,
                  '异常 ${reports.anomalyCount}',
                  AppColors.warningOrange(Theme.of(context).brightness),
                ),
              ],
            ),
            if (status.timestamp.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '更新时间：${status.timestamp}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(MaimaiServiceStatus service) {
    final color = _statusColor(service.state);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: color.withValues(alpha: 0.14),
          child: Icon(Icons.circle, color: color, size: 13),
        ),
        title: Text(service.name.isEmpty ? service.key : service.name),
        subtitle:
            service.durationText.isEmpty ? null : Text(service.durationText),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              service.stateText,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
            if (service.latency != null)
              Text(
                '${service.latency} ms',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentLogs(List<MaimaiRecentLog> logs) {
    return Card(
      elevation: 0,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          for (var i = 0; i < logs.length; i++) ...[
            ListTile(
              dense: true,
              leading: const Icon(Icons.history_rounded, size: 20),
              title: Text(logs[i].type),
              subtitle: Text(logs[i].region),
              trailing: Text(logs[i].timeAgo),
            ),
            if (i != logs.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(String text, Color color) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: color.withValues(alpha: 0.16),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildMetricChip(IconData icon, String text, Color color) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 5),
            Text(text, style: TextStyle(color: color)),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String state) {
    switch (state) {
      case 'ok':
      case 'normal':
      case 'up':
        return AppColors.successGreen(Theme.of(context).brightness);
      case 'warning':
      case 'degraded':
        return AppColors.warningOrange(Theme.of(context).brightness);
      default:
        return AppColors.errorRed(Theme.of(context).brightness);
    }
  }

  Color _latencyColor(int? latency) {
    if (latency == null) return Theme.of(context).colorScheme.onSurfaceVariant;
    if (latency < 50) {
      return AppColors.successGreen(Theme.of(context).brightness);
    }
    if (latency < 100) {
      return AppColors.warningOrange(Theme.of(context).brightness);
    }
    return AppColors.errorRed(Theme.of(context).brightness);
  }
}
