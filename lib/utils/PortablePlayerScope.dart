/*
 * 随身听页面是否正在最上层。
 *
 * 为什么不放在 `AppShell` 里用一个 bool + 「push 的 Future 完成时复位」：
 * 那样只有**从首页悬浮球那条导航路径**进来的才算数，从「实用工具」Hub 页进来时
 * 悬浮球会继续浮在随身听页面上，和页面内的播放入口打架。
 *
 * 改由 [PortablePlayerPage] 自己在 `initState` / `dispose` 里置位与复位 ——
 * 不管从哪个入口进来都一致，也不用每个新入口都记得改。
 */
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constant/CacheKeyConstant.dart';

class PortablePlayerScope {
  PortablePlayerScope._();

  /// 随身听（曲库列表）页是否正在显示。
  static final ValueNotifier<bool> isLibraryPageOpen =
      ValueNotifier<bool>(false);

  /// 当前播放是不是从 [SongInfoPage] 的「播放音乐」触发的。
  ///
  /// 为 true 时 [PortablePlayerBall]（悬浮球）隐藏 —— 用户没主动进随身听，
  /// 球突然冒出来会很突兀；但**不**影响播放本身、不影响通知栏、不影响切歌。
  ///
  /// 由 [SongPlayPage] 在 `initState` / `dispose` 里置位与复位。
  static final ValueNotifier<bool> isSongInfoPlayback =
      ValueNotifier<bool>(false);

  /// 用户主动隐藏的悬浮球。继续播放时保留播放器和通知栏，仅隐藏球本身。
  static final ValueNotifier<bool> isBallHidden = ValueNotifier<bool>(false);

  /// 悬浮球正在拖动时，页面返回手势暂不响应，避免拖球误触发返回。
  static final ValueNotifier<bool> isBallDragging = ValueNotifier<bool>(false);

  /// 从随身听页面退出时是否重新显示悬浮球。
  static final ValueNotifier<bool> showBallOnLibraryExit =
      ValueNotifier<bool>(true);
  static Future<void>? _preferencesFuture;
  static int _preferencesRevision = 0;

  static Future<void> loadPreferences() async {
    final current = _preferencesFuture;
    if (current != null) return current;
    final revision = _preferencesRevision;
    final future = _loadPreferences(revision);
    _preferencesFuture = future;
    future.whenComplete(() {
      if (identical(_preferencesFuture, future)) _preferencesFuture = null;
    });
    return future;
  }

  static Future<void> _loadPreferences(int revision) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (revision == _preferencesRevision) {
        showBallOnLibraryExit.value =
            prefs.getBool(CacheKeyConstant.portableShowBallOnLibraryExit) ??
                true;
      }
    } catch (_) {
      // 读取失败时保持默认值，不影响随身听播放。
    }
  }

  static Future<void> setShowBallOnLibraryExit(bool value) async {
    _preferencesRevision++;
    showBallOnLibraryExit.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
          CacheKeyConstant.portableShowBallOnLibraryExit, value);
    } catch (_) {
      // 内存中的设置仍然立即生效。
    }
  }

  static void hideBall() => isBallHidden.value = true;

  static void wakeBall() => isBallHidden.value = false;
}
