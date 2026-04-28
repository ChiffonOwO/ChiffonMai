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
  ];

  // 随机获取一个加载提示
  static String getRandomLoadingTip() {
    return loadingTips[Random().nextInt(loadingTips.length)];
  }

}