import 'dart:async';
import 'dart:math';

class LoadingTipsConstant {
  static const List<String> loadingTips = [
    '我发现吃饭可以缓解饥饿',
    'gsd,wyllg!',
    '该死的,我赢了两个!',
    '已完成今日舞萌大学习',
    '()()(),()()()()()!',
    '要开始了哟',
    '欢迎来到舞立方的世界',
    '我和你拼了!(指拼机)',
    '小心地滑(slide carefully)',
    'cookiebot说:(   ˶◝◡ ◜|◝◡ ◜˶   )',
    '小鸟游喵说:（temptation…）',
  ];

  static int _currentIndex = 0;
  static Timer? _timer;
  static final StreamController<String> _tipStreamController = StreamController.broadcast();

  // 随机获取一个加载提示
  static String getRandomLoadingTip() {
    return loadingTips[Random().nextInt(loadingTips.length)];
  }

  // 获取当前提示
  static String get currentTip => loadingTips[_currentIndex];

  // 获取提示数量
  static int get tipCount => loadingTips.length;

  // 启动定时切换（每3秒切换一次）
  static void startAutoSwitch([int intervalSeconds = 3]) {
    stopAutoSwitch();
    
    _currentIndex = Random().nextInt(loadingTips.length);
    _tipStreamController.add(loadingTips[_currentIndex]);
    
    _timer = Timer.periodic(Duration(seconds: intervalSeconds), (timer) {
      _currentIndex = Random().nextInt(loadingTips.length);
      _tipStreamController.add(loadingTips[_currentIndex]);
    });
  }

  // 停止定时切换
  static void stopAutoSwitch() {
    _timer?.cancel();
    _timer = null;
  }

  // 获取提示切换流
  static Stream<String> get tipStream => _tipStreamController.stream;

  // 手动切换到下一条
  static String nextTip() {
    _currentIndex = Random().nextInt(loadingTips.length);
    _tipStreamController.add(loadingTips[_currentIndex]);
    return loadingTips[_currentIndex];
  }

  // 释放资源
  static void dispose() {
    stopAutoSwitch();
    _tipStreamController.close();
  }
}