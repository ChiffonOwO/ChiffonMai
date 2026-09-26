// 谱面片段猜歌：播放区**只保留谱面**，抹掉四角参数与中间达成率。
//
// 四角（BPM / 时间 / COMBO / BREAK / 物量）与中间达成率都会剧透：
// BPM、BREAK 数量、总物量都能反推曲目。
//
// 这里直接对真实的 SimaiPlayerController 断言开关已关——这些是包暴露的
// 可写属性，关掉后对应组件在 render() 里会提前 return（谱面渲染层不受影响）。
import 'package:flutter_test/flutter_test.dart';
import 'package:simai_flutter/simai_flutter.dart';

import 'package:my_first_flutter_app/page/GuessChartGame/GuessChartByChartPeekPage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 一份最小谱面：(180){1}1,2,3,4,
  MaiChart buildChart() {
    return SimaiConvert.deserialize('(180){1}1,2,3,4,');
  }

  test('对局用控制器：四角与中间信息都已关闭', () {
    final controller = GuessChartByChartPeekPage.buildChartOnlyController(
      chart: buildChart(),
      initialChartTime: 0.0,
    );

    expect(controller.showCornerInfo, isFalse,
        reason: '四角参数（BPM/时间/COMBO/BREAK）必须关闭，否则剧透');
    expect(controller.showAchievementRate, isFalse,
        reason: '中间达成率必须关闭，否则剧透');
    expect(controller.highlightExNotes, isTrue,
        reason: '谱面片段必须始终开启高亮保护套');

    controller.dispose();
  });

  test('答案模式（带音频）同样只保留谱面', () {
    final controller = GuessChartByChartPeekPage.buildChartOnlyController(
      chart: buildChart(),
      initialChartTime: 0.0,
      audioFilePath: '/nonexistent/audio.mp3',
    );

    expect(controller.showCornerInfo, isFalse);
    expect(controller.showAchievementRate, isFalse);
    expect(controller.highlightExNotes, isTrue);

    controller.dispose();
  });

  test('不会误关谱面本身（走的是叠加层开关，不是隐藏画面）', () {
    final controller = GuessChartByChartPeekPage.buildChartOnlyController(
      chart: buildChart(),
      initialChartTime: 0.0,
    );

    // 谱面数据仍在，且可正常定位/播放（隐藏画面会表现为这些不可用）
    expect(controller.chart.noteCollections, isNotEmpty,
        reason: '谱面内容必须保留');
    expect(controller.totalDurationSnapshot, greaterThan(0));
    // 判定点/判定线属于「谱面呈现」的一部分，不应被关掉
    expect(controller.backgroundMode, isNot(SimaiBackgroundMode.none));

    controller.dispose();
  });
}
