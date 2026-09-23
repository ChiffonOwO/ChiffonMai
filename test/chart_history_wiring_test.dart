// 成绩历史的**采集接线**测试。
//
// M1 的采集层逻辑由 `test/chart_history_test.dart` 覆盖；这里只钉"线接对了没"：
//   1. 拿到自己成绩的那个方法里，顺手采集一次，而且**不 await**（不能拖慢刷新）；
//   2. Rating 落盘的地方记一个点，同样不 await；
//   3. **好友对比必须被挡住**——它借用同一个 fetch 拉好友成绩，
//      不挡就会把好友的成绩记进你自己的历史曲线。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('拉自己成绩后顺手采集：出现在 fetchUserPlayData 里，且不 await', () {
    final src = _read('lib/manager/DivingFish/UserPlayDataManager.dart');
    expect(src, contains('ChartHistoryStore.instance'),
        reason: '刷新成绩是历史的主要来源，必须接线');
    expect(src, contains('recordChartSnapshot'), reason: '采集入口');

    // 不能 await：采集是"能记就赚"，绝不该拖慢或打断刷新成绩
    final callLine = src
        .split('\n')
        .firstWhere((l) => l.contains('recordChartSnapshot'));
    expect(callLine.contains('await'), isFalse,
        reason: 'await 会把刷新流程拖在本地落盘后面');
  });

  test('Rating 落盘处记一个点，且用的是界面同一份数值', () {
    final src = _read('lib/widgets/RefreshDataDialog.dart');
    expect(src, contains('recordRating'), reason: 'Rating 曲线要有数据来源');

    final callIdx = src.indexOf('recordRating(');
    final snippet = src.substring(callIdx, callIdx + 400);
    expect(snippet.contains('best35TotalRA + best15TotalRA'), isTrue,
        reason: '曲线用的总 Rating 必须与界面/persist 的同一口径');
    expect(snippet.contains('await'), isFalse, reason: '同样不该 await');
  });

  test('好友对比：拉好友成绩的那一下被 runWithoutRecording 包住', () {
    final src = _read('lib/service/FriendCompareService.dart');
    expect(src, contains('runWithoutRecording'),
        reason: '不挡住的话，好友的成绩会被记进你的历史');
    expect(src, contains('fetchUserPlayData(friendQQ)'),
        reason: '好友数据仍然要拉，只是不采集');

    final scopeIdx = src.indexOf('runWithoutRecording');
    final friendIdx = src.indexOf('fetchUserPlayData(friendQQ)');
    expect(scopeIdx, greaterThan(0));
    expect(friendIdx, greaterThan(scopeIdx),
        reason: '好友 fetch 必须在抑制作用域之内');
    expect(friendIdx - scopeIdx, lessThan(300),
        reason: '同一个作用域，而不是别处的另一个 runWithoutRecording');
  });

  test('恢复缓存不会采集（否则好友数据会经由 restoreCache 漏进来）', () {
    final src = _read('lib/manager/DivingFish/UserPlayDataManager.dart');
    // 采集点在 fetchUserPlayData 里（_saveToCache 之后），
    // 而 restoreCache 只走 _saveToCache —— 所以恢复动作天然不采集。
    final restoreIdx = src.indexOf('Future<void> restoreCache');
    expect(restoreIdx, greaterThan(0));
    final restoreBody = src.substring(restoreIdx, restoreIdx + 200);
    expect(restoreBody.contains('recordChartSnapshot'), isFalse);
    expect(restoreBody.contains('ChartHistoryStore'), isFalse);
  });
}
