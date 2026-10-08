import 'dart:async';
import '../service/LoadingTipsStore.dart';

/// 兼容旧调用点的加载语录门面。内容来自服务端，显示偏好由 [LoadingTipsStore] 管理。
class LoadingTipsConstant {
  static final _store = LoadingTipsStore.instance;
  static Timer? _timer;
  static final StreamController<String> _tips =
      StreamController<String>.broadcast();

  static List<String> get loadingTips => _store.enabledTexts;
  static String getRandomLoadingTip() => _store.randomText();
  static String get currentTip => _store.randomText();
  static int get tipCount => _store.enabledTexts.length;
  static Stream<String> get tipStream => _tips.stream;

  static void startAutoSwitch([int intervalSeconds = 3]) {
    stopAutoSwitch();
    unawaited(_store.ensureLoaded().then((_) => _emit()));
    _timer = Timer.periodic(Duration(seconds: intervalSeconds), (_) => _emit());
  }

  static void _emit() {
    final text = _store.randomText();
    if (text.isNotEmpty && !_tips.isClosed) _tips.add(text);
  }

  static void stopAutoSwitch() {
    _timer?.cancel();
    _timer = null;
  }

  static String nextTip() {
    final text = _store.randomText();
    if (text.isNotEmpty && !_tips.isClosed) _tips.add(text);
    return text;
  }

  static void dispose() {
    stopAutoSwitch();
    _tips.close();
  }
}
