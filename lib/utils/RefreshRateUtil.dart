import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 屏幕刷新率控制。
///
/// 背景：**Flutter 引擎从不调用 Android 的 `Surface.setFrameRate()`**
/// （见 [flutter/flutter#160952](https://github.com/flutter/flutter/issues/160952)），
/// 系统因此默认按 60Hz 合成，只在触摸后短暂升到 120Hz 再衰减回去。
/// 表现就是「进播放页先跑几秒 120，然后稳定在 60，一交互又回 120」。
///
/// 这个工具让播放页能主动向系统投票要高刷，退出时再还回去，
/// 不至于让整个 App 一直顶着高刷耗电。
class RefreshRateUtil {
  RefreshRateUtil._();

  static const MethodChannel _channel = MethodChannel('com.example.app/display');

  static bool _active = false;

  /// 当前是否已经请求了高刷。
  static bool get isActive => _active;

  /// 请求按屏幕支持的最高刷新率渲染。
  ///
  /// 返回平台的诊断信息（支持的刷新率列表、实际应用的刷新率等）；
  /// 非 Android 平台或调用失败时返回 null。重复调用是安全的。
  static Future<Map<String, dynamic>?> requestMax() async {
    if (!Platform.isAndroid) return null;
    try {
      final info =
          await _channel.invokeMapMethod<String, dynamic>('setHighRefreshRate');
      _active = info?['ok'] == true;
      debugPrint('[RefreshRate] 请求高刷结果: $info');
      return info;
    } on MissingPluginException {
      debugPrint('[RefreshRate] 平台通道不存在，忽略');
    } catch (e) {
      debugPrint('[RefreshRate] 请求高刷失败: $e');
    }
    return null;
  }

  /// 把刷新率交还给系统（退出播放页时调用）。重复调用是安全的。
  static Future<void> restore() async {
    if (!Platform.isAndroid || !_active) return;
    try {
      await _channel.invokeMethod<void>('restoreRefreshRate');
      debugPrint('[RefreshRate] 已恢复系统默认刷新率');
    } catch (e) {
      debugPrint('[RefreshRate] 恢复刷新率失败: $e');
    } finally {
      _active = false;
    }
  }

  /// 查询屏幕支持 / 当前的刷新率，用于诊断与日志。
  static Future<Map<String, dynamic>?> query() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel
          .invokeMapMethod<String, dynamic>('queryRefreshRate');
    } catch (e) {
      debugPrint('[RefreshRate] 查询刷新率失败: $e');
      return null;
    }
  }
}
