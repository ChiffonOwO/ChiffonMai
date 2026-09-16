import 'package:flutter/foundation.dart';

/// 谱面播放页（ChartPlayPage）存活期间，强制整棵 Navigator 使用深色主题。
///
/// 背景：`simai_flutter` 的游玩设置 / 游玩 / 结算 / 视频导出页的 Scaffold
/// 都没有设置 `backgroundColor`，会继承 App 主题的 `scaffoldBackgroundColor`。
/// 浅色模式下从侧边栏进入这些页面时，会先闪一帧浅色再被黑色画面盖住。
/// 播放器本身是纯黑全屏体验（其设置抽屉也自带深色），所以这里在播放页存活
/// 期间把整棵树切到深色主题，从根上消除闪色。
class PlayerThemeScope {
  PlayerThemeScope._();

  /// 由 ChartPlayPage 在 initState / dispose 中置位与复位。
  static final ValueNotifier<bool> forceDarkTheme = ValueNotifier<bool>(false);
}
