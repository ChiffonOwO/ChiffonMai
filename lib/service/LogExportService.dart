import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../utils/ExportPathUtil.dart';

/// 轻量日志环形缓存。只保留最近 2000 行，用户主动点击时写到公开目录。
class LogExportService {
  LogExportService._();
  static final instance = LogExportService._();
  static const _maxLines = 2000;
  final List<String> _lines = [];
  bool _installed = false;

  void install() {
    if (_installed) return;
    // 必须在替换全局回调之前捕获原始实现。late 延迟读取会在第一次日志
    // 到来时再次读到包装器本身，形成递归，debug 模式下很快就会堆栈溢出。
    final original = debugPrint;
    _installed = true;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null && message.isNotEmpty) {
        _lines.add('${DateTime.now().toIso8601String()} $message');
        if (_lines.length > _maxLines)
          _lines.removeRange(0, _lines.length - _maxLines);
      }
      original(message, wrapWidth: wrapWidth);
    };
  }

  Future<File> export({void Function(String path)? onFallback}) async {
    final info = await PackageInfo.fromPlatform();
    final report = StringBuffer()
      ..writeln('ChiffonMai 日志导出')
      ..writeln('时间: ${DateTime.now().toIso8601String()}')
      ..writeln('版本: ${info.version}+${info.buildNumber}')
      ..writeln(
          '平台: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}')
      ..writeln('--- 最近日志 ---')
      ..writeln(_lines.join('\n'));
    return ExportPathUtil.writeExportTextFile(
        fileName: 'chiffonmai-log-${DateTime.now().millisecondsSinceEpoch}.txt',
        content: report.toString(),
        subDir: '日志',
        onFallback: onFallback,
        allowPrivateFallback: false);
  }
}
