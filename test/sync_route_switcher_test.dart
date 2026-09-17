import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_first_flutter_app/page/HubComponents.dart';
import 'package:my_first_flutter_app/service/SyncRouteStore.dart';
import 'package:my_first_flutter_app/widgets/SyncRouteSwitcher.dart';

/// 同步线路切换器 + HubActionTile.footer 的行为测试。
///
/// 关键保证：**点线路切换不能触发 tile 的 onTap**——否则用户在切线路的
/// 一瞬间就把同步跑起来了（还会花 Token）。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('切换器显示两条线路与当前线路名', (tester) async {
    await tester.pumpWidget(host(SyncRouteSwitcher(
      value: SyncRouteStore.routeScoreHub,
      onChanged: (_) {},
    )));

    expect(find.text('线路'), findsOneWidget);
    expect(find.text('线路1'), findsOneWidget);
    expect(find.text('线路2'), findsOneWidget);
    expect(find.text('maimai Score Hub'), findsOneWidget);

    await tester.pumpWidget(host(SyncRouteSwitcher(
      value: SyncRouteStore.routeAwmc,
      onChanged: (_) {},
    )));
    await tester.pumpAndSettle();
    expect(find.text('AWMC 网关'), findsOneWidget);
  });

  testWidgets('点线路2 回调 1；enabled=false 时点不动', (tester) async {
    final picked = <int>[];
    await tester.pumpWidget(host(SyncRouteSwitcher(
      value: SyncRouteStore.routeScoreHub,
      onChanged: picked.add,
    )));

    await tester.tap(find.text('线路2'));
    await tester.pumpAndSettle();
    expect(picked, [SyncRouteStore.routeAwmc]);

    await tester.pumpWidget(host(SyncRouteSwitcher(
      value: SyncRouteStore.routeScoreHub,
      onChanged: picked.add,
      enabled: false,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('线路2'));
    await tester.pumpAndSettle();
    expect(picked.length, 1, reason: '禁用时不应再触发回调');
  });

  testWidgets('HubActionTile.footer：渲染在 tile 下方，点它不触发 onTap', (tester) async {
    var tileTaps = 0;
    var route = SyncRouteStore.routeScoreHub;

    await tester.pumpWidget(host(StatefulBuilder(
      builder: (context, setState) => HubActionTile(
        title: '同步成绩到水鱼',
        subtitle: '扫码抓取并同步最新成绩',
        icon: Icons.cloud_upload_outlined,
        onTap: () => tileTaps++,
        footer: SyncRouteSwitcher(
          value: route,
          onChanged: (v) => setState(() => route = v),
        ),
      ),
    )));

    expect(find.text('线路1'), findsOneWidget);
    expect(find.text('maimai Score Hub'), findsOneWidget);

    // 切线路：只改线路，不触发 tile
    await tester.tap(find.text('线路2'));
    await tester.pumpAndSettle();
    expect(route, SyncRouteStore.routeAwmc);
    expect(find.text('AWMC 网关'), findsOneWidget);
    expect(tileTaps, 0, reason: '切线路绝不能顺手把同步跑起来');

    // 点标题：走 tile 自己的 onTap
    await tester.tap(find.text('同步成绩到水鱼'));
    await tester.pumpAndSettle();
    expect(tileTaps, 1);
  });

  testWidgets('HubActionTile 没有 footer 时布局与原来一致', (tester) async {
    await tester.pumpWidget(host(HubActionTile(
      title: '数据备份',
      subtitle: '导入或导出本地数据',
      icon: Icons.backup_outlined,
      onTap: () {},
    )));

    expect(find.byType(ListTile), findsOneWidget);
    expect(find.text('线路1'), findsNothing);
  });
}
