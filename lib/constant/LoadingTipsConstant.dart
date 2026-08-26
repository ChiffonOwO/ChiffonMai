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
    '我的天哪是24分大人',
    '舞萌DX达成率最高可达101%，需要在BREAK音符上全部打出CRITICAL PERFECT判定',
    '判定调整A/B可分别影响音符到达时机和判定时机',
    'EX-NOTE在可判定区间内任意时刻击打都会取得CRITICAL PERFECT，EX-HOLD除外',
    '不小心松开HOLD音符会变灰，可重新按住挽救判定，最终判定取决于初始点击和按住时长',
    '在设置中开启"旋转滑动"，星星头会在下落时旋转，速度代表星星快慢',
    '在乐曲选择界面，同时按下2号键和7号键可在标准谱面和DX谱面之间切换',
    '每日首次游玩可盖1个章，拼机游玩可额外盖1个章',
    '扇形 SLIDE（WiFi 星星）：引导星星前往三个方向，需触碰更大范围判定区',
    '如果你想为Tips添砖加瓦，可以滑到底部填写问卷!',
    'CRH380AL说：小朋友，今天去哪🎹🎹?',
    'wander说：你的星星被迪拉熊吃掉啦哈哈',
    'CRH2A说：ふ、普通とか当たり前ってなんだろう',
    'CRH2A说：X X XXX',
    '水母念波说：(/≧▽≦/)',
    'Andy说：ChiFFoN在上机的时候接到了网站备案的审核电话',
    '同时按2号键和7号键可以切换标准谱和DX谱',
    '没打好怎么办？按住2367键三秒可以跳过（设置中要打开这个哦）',
    '匿名用户_100.4999说：噎死那个羊！！！',
    '匿名用户_100.4999说：我售卖东北玉米~',
    '匿名用户_100.4999说：你醒啦？今天机厅新进了叫舞萌的新游戏！',
    '匿名用户_100.4999说：恭喜你，走完了整个区域哟！',
    '匿名用户_100.4999说：出现了新的完美挑战曲！',
    '匿名用户_100.4999说：注意注意！',
    '匿名用户_100.4999说：完美挑战曲，通关！',
    '匿名用户_100.4999说：鸡公煲，鸡公煲，经过我的胃~',
    'kuizbeat说：哟哟哟加内！',
    'kuizbeat说：想不到要玩什么的时候不如来把宴谱',
    'kuizbeat说：是舞舞舞大人，我们有救了！',
    'kuizbeat说：不可以打我哟～',
    'kuizbeat说：大佬借我蹭歌QAQ',
    'kuizbeat说：想推歌就要提前做准备哦',
    'kuizbeat说：rice～',
    'M薯条说：练错位时遇到问题不妨试试把星星调成0.6以上试试吧',
    'M薯条说：看不清星星的话就把星星延时调成-0.3吧',
    'M薯条说：有时候歌曲开始前敲的拍子对应的是滑星星的时机',
    'M薯条说：星星是世界上最好玩的东西',
    'CR450AF说：我喜欢你',
    '"“你好！我是一条Tips！"说：不可以拆机哦"',
    '天苍苍！野茫茫！风吹草低见牛羊！',
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