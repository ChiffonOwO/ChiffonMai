import 'package:flutter/widgets.dart';

/// 排行榜列表的**行高实测器**：让「定位到我的排名」精确落在自己的那一行上。
///
/// ## 它修的是什么
///
/// Rating 榜 / 拟合总 Rating 榜 / 平均（DX）达成率榜这三页的定位按钮，原来都是
/// `animateTo(index * 72)`（拟合榜写的是 84）——**行高是估的**：
///
///   * 真实行高 = 上下 padding（各 12）+ 内容高，而内容高由字体度量决定
///     （昵称 14 / 名次 16 / 数值 11~18，思源黑体与系统字号缩放都会变）；
///   * widget 测试实测（360×800 逻辑尺寸）：Rating 榜 65、拟合榜 67、平均榜 64。
///
/// 估值比真值大 7~17dp，而误差是**按行号累加**的：第 40 名就偏出 280dp
/// （拟合榜 680dp）——表现就是点定位后画面滑过头，自己的那一行跑到屏幕上方，
/// 看到的全是比自己低的名次。
///
/// ## 做法
///
/// 把 [key] 挂到传进 `ListView.prototypeItem` 的那一行上：列表会用**与真实行完全
/// 相同的约束**先把这一行排一遍（字体 / 系统字号缩放都在内），再让每一行都用它的
/// 高度。于是：
///
///   * 行高是当前环境下量出来的真值，不再猜；
///   * 每行严格等高，`index * 行高` 就是第 index 行的**精确**偏移
///     （列表必须 `padding: EdgeInsets.zero`，否则要再减去 padding）。
///
/// ⚠️ 原型行必须是**内容最全**的那一行（该有的可选文本都在、名次用第 1 名好拿到
/// 28dp 的奖杯徽章），否则真实行会被这个高度压扁成 RenderFlex 溢出。
class RankingRowExtent {
  /// 挂到 `prototypeItem` 那一行上的 key（外层套一层 [KeyedSubtree] 也行，
  /// 量到的是它子树的尺寸）。
  final GlobalKey key = GlobalKey();

  /// 实测行高；列表还没完成过一次布局时为 null。
  double? get rowHeight {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.size.height;
  }

  /// 把第 [index] 行滚到列表顶部。
  ///
  /// 行高还没量到时**什么都不做**：宁可不动，也不要退回估算值——估错就是这次要修的
  /// bug（调用方只在数据已加载、列表已排版后才会调到这里，所以正常路径量得到）。
  Future<void> scrollRowToTop(
    ScrollController controller,
    int index, {
    Duration duration = const Duration(milliseconds: 500),
    Curve curve = Curves.easeInOut,
  }) async {
    final height = rowHeight;
    if (height == null || height <= 0 || index < 0) return;
    if (!controller.hasClients) return;

    final position = controller.position;
    // 目标行靠近末尾时滚不到「行顶对齐视口顶」，夹到可滚范围即可（此时行仍在视野内）
    final target = (index * height)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((position.pixels - target).abs() < 0.5) return;

    await controller.animateTo(target, duration: duration, curve: curve);
  }
}
