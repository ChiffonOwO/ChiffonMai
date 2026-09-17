import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_flutter_app/utils/FeatureFlags.dart';
import 'package:my_first_flutter_app/utils/FeatureRegistry.dart';

/// 「AWMC 网关」入口的隐藏开关（`FeatureFlags.awmcGateway`）。
///
/// 需求：代码全部保留，但「系统」hub 的入口先不给看 ——
/// 等所有者说了再启用。入口一共有三处定义，其中首页搜索 / 收藏 / 全部功能
/// 都是从 [FeatureRegistry] 渲染的，所以这里钉住「入口是否出现 == 开关的值」：
/// 谁把入口写死回来，这条就会红。
///
/// 另外两处（`SystemHubPage` 的 tile、`HomePage` 的点击分支）属于 UI，
/// 同样是 `if (FeatureFlags.awmcGateway)` 包起来的，改开关一起生效。
void main() {
  List<String> allTitles({required bool loggedIn}) => FeatureRegistry
      .allCategories(loggedIn)
      .expand((c) => c.items)
      .map((i) => i.title)
      .toList();

  test('AWMC 网关入口是否出现，跟 FeatureFlags.awmcGateway 完全一致', () {
    for (final loggedIn in [true, false]) {
      expect(
        allTitles(loggedIn: loggedIn).contains('AWMC 网关'),
        FeatureFlags.awmcGateway,
        reason: '开关关掉时，首页搜索 / 收藏 / 全部功能里都不该再出现这个入口',
      );
    }
  });

  test('系统分类的其它入口不受影响', () {
    final system = FeatureRegistry.allCategories(true)
        .firstWhere((c) => c.name == '系统');
    final titles = system.items.map((i) => i.title).toList();

    expect(titles, contains('同步成绩到水鱼'));
    expect(titles, contains('同步成绩到落雪'));
    expect(titles, contains('数据备份'));
    expect(titles, contains('主题与背景'));
    // 15 个公开入口 + 开关打开时多一个「AWMC 网关」
    expect(titles.length, FeatureFlags.awmcGateway ? 16 : 15);
  });
}
