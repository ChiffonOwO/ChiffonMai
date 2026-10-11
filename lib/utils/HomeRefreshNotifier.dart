import 'package:flutter/foundation.dart';

/// 首页普通/高级刷新进行状态。
///
/// 首页和系统 Hub 同时存在于主壳的 IndexedStack 中，需要用共享状态让系统页
/// 在首页刷新期间禁用会读写同一批缓存的入口。
class HomeRefreshNotifier {
  HomeRefreshNotifier._();

  static final ValueNotifier<bool> isBusy = ValueNotifier<bool>(false);

  static void setBusy(bool value) {
    if (isBusy.value != value) isBusy.value = value;
  }
}
