// MASTER 定数范围输入框的行为测试。
//
// 回归背景：该输入框原先直接建在 build 函数里，每次外层 setState 都会新建
// TextEditingController，且只在 onEditingComplete（回车）时提交。实测后果：
//   - 输入后直接点「确定」→ 改动静默丢失（commit 回调根本没被调用）
//   - 输入到一半去勾选版本触发重建 → 输入内容被重置回旧值
// 现在改为 StatefulWidget 自持 controller，失焦与回车都提交。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';

void main() {
  /// 挂载共享的猜歌设置组件，返回一个可读的提交记录。
  Future<List<List<double>>> pumpSettings(
    WidgetTester tester, {
    required ValueNotifier<List<double>> committed,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) {
            return CommonWidgetUtil.buildGuessChartSettingsWidget(
              context,
              const ['maimai'], // allVersions
              const ['POPS'], // allGenres
              const <String>[], // selectedVersions
              committed.value.isNotEmpty ? committed.value.first : 1.0,
              committed.value.length > 1 ? committed.value[1] : 15.0,
              const <String>[], // selectedGenres
              10, // maxGuesses
              0, // timeLimit
              (_) {
                setState(() {}); // 模拟真实页面：改版本会触发整块重建
              },
              (min, max) {
                setState(() {});
                committed.value = [min, max];
              },
              (_) {},
              (_) {},
              (_) {},
            );
          },
        ),
      ),
    ));
    return const [];
  }

  testWidgets('输入后失焦（不按回车）也会提交', (tester) async {
    final committed = ValueNotifier<List<double>>(const [1.0, 15.0]);
    await pumpSettings(tester, committed: committed);

    final minField = find.byType(TextField).first;
    await tester.enterText(minField, '14.5');
    await tester.pumpAndSettle();

    // 点击别处使其失焦
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(committed.value.first, 14.5,
        reason: '失焦应提交，而不是把改动丢掉（原先只有回车才提交）');
  });

  testWidgets('按回车也会提交', (tester) async {
    final committed = ValueNotifier<List<double>>(const [1.0, 15.0]);
    await pumpSettings(tester, committed: committed);

    await tester.enterText(find.byType(TextField).first, '12.5');
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(committed.value.first, 12.5);
  });

  testWidgets('外层重建不会清掉输入到一半的内容', (tester) async {
    final committed = ValueNotifier<List<double>>(const [1.0, 15.0]);
    await pumpSettings(tester, committed: committed);

    await tester.enterText(find.byType(TextField).first, '12.0');
    await tester.pumpAndSettle();

    // 勾选一个版本 → 触发外层 setState → 整块设置区重建
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pumpAndSettle();

    final text = tester
        .widget<TextField>(find.byType(TextField).first)
        .controller
        ?.text;
    expect(text, '12.0',
        reason: '重建不应重置用户正在输入的内容（原先把 controller 建在 build 里）');
  });

  testWidgets('最小值填得比最大值大时被归一化，不会留下 min>max', (tester) async {
    final committed = ValueNotifier<List<double>>(const [1.0, 15.0]);
    await pumpSettings(tester, committed: committed);

    // 先把最大值设小
    await tester.enterText(find.byType(TextField).at(1), '10.0');
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(committed.value, [1.0, 10.0]);

    // 再把最小值填成比它还大
    await tester.enterText(find.byType(TextField).first, '13.0');
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(committed.value.first <= committed.value[1], isTrue,
        reason: '归一化后必须满足 min <= max，否则抽曲会永远抽不到');
    expect(committed.value, [13.0, 13.0]);
  });

  testWidgets('非法输入回滚成当前值，不产生越界的设置', (tester) async {
    final committed = ValueNotifier<List<double>>(const [1.0, 15.0]);
    await pumpSettings(tester, committed: committed);

    // 超出 1.0-15.0 的范围
    await tester.enterText(find.byType(TextField).first, '99');
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(committed.value.first, 1.0, reason: '越界输入应回滚，而不是写进设置');
    final text = tester
        .widget<TextField>(find.byType(TextField).first)
        .controller
        ?.text;
    expect(text, '1.0', reason: '输入框也要回滚，避免显示与生效值不一致');
  });
}
