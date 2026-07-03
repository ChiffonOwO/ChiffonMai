import 'dart:async';
import 'package:flutter/material.dart';
import '../service/ConnectivityService.dart';

/// 离线状态横幅组件
/// 监听 ConnectivityService 的连接变化，在离线时显示提示，在线恢复时给出通知
class OfflineBanner extends StatefulWidget {
  /// 可选：在线恢复时的刷新回调
  final VoidCallback? onRefresh;

  const OfflineBanner({super.key, this.onRefresh});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner>
    with SingleTickerProviderStateMixin {
  final ConnectivityService _connectivity = ConnectivityService();

  /// 是否刚从离线恢复到在线（用于显示「已恢复连接」提示）
  bool _justReconnected = false;
  Timer? _reconnectTimer;

  @override
  void initState() {
    super.initState();
    _connectivity.isOnline.addListener(_onConnectivityChange);
  }

  void _onConnectivityChange() {
    if (_connectivity.isOnline.value) {
      // 从离线恢复
      setState(() => _justReconnected = true);
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() => _justReconnected = false);
        }
      });
    } else {
      // 变离线
      setState(() => _justReconnected = false);
    }
  }

  @override
  void dispose() {
    _connectivity.isOnline.removeListener(_onConnectivityChange);
    _reconnectTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = _connectivity.isOnline.value;

    if (isOnline && !_justReconnected) {
      return const SizedBox.shrink();
    }

    return AnimatedSlide(
      offset: Offset.zero,
      duration: const Duration(milliseconds: 300),
      child: AnimatedOpacity(
        opacity: 1.0,
        duration: const Duration(milliseconds: 300),
        child: MaterialBanner(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          backgroundColor: _justReconnected
              ? Colors.green.shade700
              : Colors.orange.shade800,
          leading: Icon(
            _justReconnected ? Icons.wifi : Icons.wifi_off,
            color: Colors.white,
            size: 24,
          ),
          content: Text(
            _justReconnected ? '已恢复网络连接' : '当前离线 - 显示缓存数据',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: [
            if (_justReconnected && widget.onRefresh != null)
              TextButton(
                onPressed: widget.onRefresh,
                child: const Text(
                  '刷新',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            if (!isOnline)
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                },
                child: const Text(
                  '知道了',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
