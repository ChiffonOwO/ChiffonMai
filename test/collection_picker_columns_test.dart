// 收藏品选择弹窗（更换头像 / 姓名框）的头像列数回归测试。
//
// 需求：头像网格默认 **4 列**（原来是写死的 3 列），可以用「每行 − N +」步进器在
// **3~10** 之间调；姓名框 tab 不受影响（6:1 长条 banner，固定一行一个）。
//
// ⚠️ 这里渲染真实弹窗、读 `SliverGridDelegateWithFixedCrossAxisCount` 与真实几何，
// 不靠读源码字符串 —— 列数是「排出来」的，只有量才知道对不对。
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_flutter_app/entity/LuoXue/Collection.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:my_first_flutter_app/widgets/CollectionPickerSheet.dart';

/// 加 / 减按钮的 tooltip（测试用它定位按钮）。
const String kPlusTip = '增加每行头像数';
const String kMinusTip = '减少每行头像数';

void _mockChannel(String name, Future<Object?> Function(MethodCall) handler) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(MethodChannel(name), handler);
}

/// 图片地址是外网（测试里必然取不到）→ 挂在 tester 上的异常清掉，
/// 免得把断言带崩（与 ranking_list_top_gap_test 同一套处理）。
void _drainExceptions(WidgetTester tester) {
  Object? ex;
  while ((ex = tester.takeException()) != null) {
    debugPrint('[渲染异常-已忽略] ${ex.toString().split('\n').first}');
  }
}

List<Collection> _icons(int count) =>
    [for (var i = 1; i <= count; i++) Collection(id: i, name: '头像$i')];

List<Collection> _plates(int count) =>
    [for (var i = 1; i <= count; i++) Collection(id: 1000 + i, name: '姓名框$i')];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // 不打开这条旁路，google_fonts 会在测试里联网拉 NotoSansSC，失败后会把用例判失败
    //（见 utils/AppTheme.dart 的 debugLocalFontFamily）。
    AppTheme.debugLocalFontFamily = true;
  });

  setUp(() {
    // CachedNetworkImage 走 flutter_cache_manager，要用 path_provider；
    // 不 mock 会一直等到超时才放弃。
    _mockChannel('plugins.flutter.io/path_provider',
        (call) async => Directory.systemTemp.path);
  });

  tearDown(() {
    _mockChannel('plugins.flutter.io/path_provider', (call) async => null);
  });

  /// 打开真实弹窗（与 SystemHubPage._showCollectionPicker 同一套参数）。
  Future<void> openSheet(
    WidgetTester tester, {
    int iconCount = 40,
    int plateCount = 6,
    int? selectedAvatarId,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final searchController = TextEditingController();
    addTearDown(searchController.dispose);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme(),
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: TextButton(
              onPressed: () => showModalBottomSheet(
                context: ctx,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => CollectionPickerSheet(
                  searchController: searchController,
                  avatarIcons: _icons(iconCount),
                  avatarPlates: _plates(plateCount),
                  selectedAvatarId: selectedAvatarId,
                  selectedPlateId: null,
                  onAvatarPicked: (_) {},
                  onPlatePicked: (_) {},
                ),
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('打开'));
    // ⚠️ 不能用 pumpAndSettle：图片在测试里必然取不到（HTTP 一律 400），
    // `CachedNetworkImage` 的 placeholder 是个**一直转**的进度圈，
    // 永远等不到「没有待处理帧」，pumpAndSettle 只会超时。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // 走完 sheet 弹入动画
    _drainExceptions(tester);
  }

  /// 网格列数（直接从 gridDelegate 上读，不猜）。
  int columns(WidgetTester tester) {
    final grid = tester.widget<GridView>(find.byType(GridView));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    return delegate.crossAxisCount;
  }

  Future<void> tapPlus(WidgetTester tester, {int times = 1}) async {
    for (var i = 0; i < times; i++) {
      await tester.tap(find.byTooltip(kPlusTip));
      await tester.pump();
    }
    _drainExceptions(tester);
  }

  Future<void> tapMinus(WidgetTester tester, {int times = 1}) async {
    for (var i = 0; i < times; i++) {
      await tester.tap(find.byTooltip(kMinusTip));
      await tester.pump();
    }
    _drainExceptions(tester);
  }

  IconButton buttonWith(WidgetTester tester, IconData icon) =>
      tester.widget<IconButton>(find.widgetWithIcon(IconButton, icon));

  testWidgets('头像网格默认 4 列（原来是写死的 3 列）', (tester) async {
    await openSheet(tester);

    expect(columns(tester), 4);
    expect(find.byTooltip(kMinusTip), findsOneWidget);
    expect(find.byTooltip(kPlusTip), findsOneWidget);
    expect(find.text('4'), findsOneWidget, reason: '中间要显示当前列数');
  });

  testWidgets('4 列时确实是「一行 4 个」：前 4 个顶边齐平，第 5 个换行', (tester) async {
    await openSheet(tester);

    final images = find.byType(CachedNetworkImage);
    final rects = [
      for (var i = 0; i < 5; i++) tester.getRect(images.at(i)),
    ];
    for (var i = 1; i < 4; i++) {
      expect(rects[i].top, closeTo(rects[0].top, 0.5),
          reason: '第 ${i + 1} 个应该和第一个同一行');
    }
    expect(rects[4].top, greaterThan(rects[0].top + 1),
        reason: '第 5 个必须换到第二行');
  });

  testWidgets('点 + 增加列数（4 → 6）', (tester) async {
    await openSheet(tester);
    await tapPlus(tester, times: 2);

    expect(columns(tester), 6);
    expect(find.text('6'), findsOneWidget);
  });

  testWidgets('列数上限 10：到顶后 + 变灰点不动', (tester) async {
    await openSheet(tester);
    await tapPlus(tester, times: 12);

    expect(columns(tester), 10);
    expect(buttonWith(tester, Icons.add).onPressed, isNull,
        reason: '到上限后 + 必须禁用');
    expect(buttonWith(tester, Icons.remove).onPressed, isNotNull);
  });

  testWidgets('列数下限 3：到底后 − 变灰点不动', (tester) async {
    await openSheet(tester);
    await tapMinus(tester, times: 6);

    expect(columns(tester), 3);
    expect(buttonWith(tester, Icons.remove).onPressed, isNull,
        reason: '到下限后 − 必须禁用');
    expect(buttonWith(tester, Icons.add).onPressed, isNotNull);
  });

  testWidgets('列数在 3~10 之间来回调不会越界', (tester) async {
    await openSheet(tester);
    await tapPlus(tester, times: 20); // 顶到 10
    await tapMinus(tester, times: 20); // 落回 3
    expect(columns(tester), 3);
    await tapPlus(tester, times: 1);
    expect(columns(tester), 4);
  });

  testWidgets('姓名框 tab：固定 1 列，且不显示列数步进器', (tester) async {
    await openSheet(tester);
    await tapPlus(tester, times: 3); // 头像先调成 7 列
    expect(columns(tester), 7);

    await tester.tap(find.text('姓名框'));
    await tester.pump();
    _drainExceptions(tester);

    expect(columns(tester), 1, reason: '姓名框是 6:1 长条 banner，必须一行一个');
    expect(find.byTooltip(kPlusTip), findsNothing);
    expect(find.byTooltip(kMinusTip), findsNothing);

    // 切回头像：列数还是刚才那个（同一实例内保留）
    await tester.tap(find.text('头像'));
    await tester.pump();
    _drainExceptions(tester);
    expect(columns(tester), 7);
  });

  testWidgets('列数步进器在标题右边同一行（不再单独占网格上方一行）', (tester) async {
    await openSheet(tester);

    final title = tester.getRect(find.text('选择收藏品'));
    final minus = tester.getRect(find.byTooltip(kMinusTip));
    final plus = tester.getRect(find.byTooltip(kPlusTip));

    expect((minus.center.dy - title.center.dy).abs(), lessThan(2),
        reason: '步进器要和标题在同一行');
    expect(minus.left, greaterThan(title.right), reason: '要在标题右侧');
    expect(plus.left, greaterThan(minus.right));

    // 搜索框下方只剩 padding(8) + 分割线(1)：多出来的那一行确实搬走了
    //（搬回去的话这里会多出 ~40dp）
    final searchBottom = tester.getRect(find.byType(TextField)).bottom;
    final gridTop = tester.getRect(find.byType(GridView)).top;
    expect(gridTop - searchBottom, lessThan(20),
        reason: '网格上方不该再压着一行步进器');
  });

  testWidgets('标题要完整显示，不能被压成「选择…」', (tester) async {
    await openSheet(tester);

    // 根因：标题用 Flexible、右侧用 Spacer 时**两者都为 flex 子项**，
    // 自由宽度按 flex 对半分 —— 标题只拿到约 27dp（360dp 屏），
    // 于是明明右边还空着却被省略成「选择…」。必须是 Expanded（唯一的 flex 子项）。
    final rp = tester.renderObject<RenderParagraph>(find.text('选择收藏品'));
    expect(rp.didExceedMaxLines, isFalse, reason: '默认字号下标题必须完整显示');
    expect(rp.size.width, greaterThan(80),
        reason: '标题可用宽度被对半分了（应独占剩余宽度）');
  });

  testWidgets('搜索计数行只在搜索时出现（平时不占高度）', (tester) async {
    await openSheet(tester);
    expect(find.textContaining('找到'), findsNothing);

    await tester.enterText(find.byType(TextField), '头像1');
    await tester.pump();
    _drainExceptions(tester);

    expect(find.text('找到 11 个头像'), findsOneWidget,
        reason: '1~40 里名字含「头像1」的是 1、10~19，共 11 个');
    expect(columns(tester), 4, reason: '搜索不该改变列数');
    await tapPlus(tester, times: 1);
    expect(columns(tester), 5);
  });
}
