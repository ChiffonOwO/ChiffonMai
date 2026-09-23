// 本轮四项改造的回归测试。
//
// 1. 收藏夹导出后缀固定 `.cmf`，**不再提供自定义**（自定义后缀会把常见格式的
//    默认打开方式抢过来 —— 这是本次要修的核心问题）；
// 2. 设置页的自定义取色器必须真的能取色（以前 `flutter_colorpicker` 的取色区
//    宽度写死 300，在手机上溢出，只有预设色可用）；
// 3+4. 页面结构：AppBar 字体统一走 PageTopBar；成绩趋势是独立板块、位于
//    「玩家最佳成绩」**下方**。
//
// 纯结构/常量可断言的部分放这里；需要渲染的部分在
// `test/settings_page_picker_test.dart` / `test/song_info_section_order_test.dart`。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:my_first_flutter_app/utils/ExportSettings.dart';
import 'package:my_first_flutter_app/widgets/PageTopBar.dart';

String _read(String path) => File(path).readAsStringSync();

/// 去掉 `//` 行注释后再匹配。
///
/// 必须去注释：本次改造在多个文件里**故意写了** `// 这里原来是 appBar: AppBar(...)`
/// 这样的说明注释，不去掉就会把"解释为什么改"的注释当成"还没改"。
String _stripLineComments(String src) => src
    .split('\n')
    .map((line) {
      final idx = line.indexOf('//');
      return idx < 0 ? line : line.substring(0, idx);
    })
    .join('\n');

final RegExp _bareAppBar = RegExp(r'appBar:\s*AppBar\s*\(');

void main() {
  group('1. 收藏夹导出后缀固定为 .cmf', () {
    test('常量就是 cmf / .cmf，且没有任何"可写"的入口', () {
      expect(ExportSettings.favoriteExtension, 'cmf');
      expect(ExportSettings.favoriteExtensionWithDot, '.cmf');
    });

    test('ExportSettings 不再暴露 ValueNotifier / normalize / setFavoriteExtension', () {
      final src = _read('lib/utils/ExportSettings.dart');
      // 曾经这些是"自定义后缀"的 API；留着就说明口子没堵上
      expect(src.contains('ValueNotifier'), isFalse,
          reason: '后缀不再是可变的用户设置');
      expect(src.contains('setFavoriteExtension'), isFalse,
          reason: '不该再有写入后缀的入口');
      expect(src.contains('maxExtensionLength'), isFalse);
      expect(src.contains('normalize('), isFalse);
      // 但旧 key 必须在启动时被清掉，否则会留一份永远不生效的幽灵配置
      expect(src.contains('export_favorite_extension'), isTrue,
          reason: '要能识别并清理历史遗留 key');
      expect(src.contains('remove('), isTrue);
    });

    test('导出走固定后缀（不再读任何可变量）', () {
      final src = _read('lib/service/FavoriteTransferService.dart');
      expect(src.contains(r'${ExportSettings.favoriteExtensionWithDot}'), isTrue,
          reason: '文件名后缀必须来自固定常量');
      expect(src.contains('favoriteExtension.value'), isFalse,
          reason: '不能再去读用户设置');
    });

    test('导入仍然按内容识别、不按后缀过滤（老备份要能导回来）', () {
      final transfer = _read('lib/service/FavoriteTransferService.dart');
      expect(transfer.contains('FileType.any'), isTrue,
          reason: '限定后缀会让用户以前的自定义后缀备份选不中');
      expect(transfer.contains('chiffonmai.favorites'), isTrue,
          reason: '识别靠内容里的 format 字段');
    });

    test('设置页不再提供后缀输入框，只展示固定值', () {
      final src = _read('lib/page/SettingsPage.dart');
      expect(src.contains('_favExtController'), isFalse,
          reason: '输入框已移除');
      expect(src.contains('_saveFavExtension'), isFalse);
      expect(src.contains('ExportSettings.favoriteExtensionWithDot'), isTrue,
          reason: '改成只读展示');
    });
  });

  group('3. AppBar 字体统一（规格与 Best50/PageTopBar 同口径）', () {
    test('PageTopBar 与 appBarTheme 的两处字号不能漂移', () {
      for (final theme in [
        AppTheme.lightTheme(),
        AppTheme.darkTheme(),
        AppTheme.pureBlackTheme(),
      ]) {
        expect(PageTopBar.titleFontSize,
            theme.appBarTheme.titleTextStyle?.fontSize,
            reason: '两套标题规格必须一致，否则标准 AppBar 与 PageTopBar 又不一样了');
        expect(theme.appBarTheme.titleTextStyle?.fontWeight, FontWeight.bold);
        expect(theme.appBarTheme.titleTextStyle?.color, theme.colorScheme.primary);
      }
    });

    test('项目里没有裸 AppBar 页面了（含 FittedBox 包标题那种）', () {
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final src = _stripLineComments(entity.readAsStringSync());
        // Scaffold.appBar: AppBar(  —— 这正是标题退回系统 Roboto 的写法
        if (_bareAppBar.hasMatch(src)) {
          offenders.add(entity.path);
        }
      }
      expect(offenders, isEmpty,
          reason: '裸 AppBar 的 title 会被 AppBar 自己的 DefaultTextStyle 接管，'
              '字体退回系统 Roboto（见 AppTheme.font 注释）');
    });

    test('歌曲详情页的标题也不再单独放大', () {
      final src = _read('lib/page/SongInfoPage.dart');
      final idx = src.indexOf("PageTopBar(\n                title: '歌曲详情'");
      expect(idx, greaterThan(0), reason: '找不到歌曲详情页的标题栏');
      // 标题栏参数区里不该再有 fontSize: 24
      final region = src.substring(idx, idx + 220);
      expect(region.contains('fontSize'), isFalse,
          reason: '全 App 标题统一 20/bold/primary，这一页不该是 24');
    });

    test('曾经用裸 AppBar 的三个排行榜页改走 PageTopBar', () {
      for (final path in [
        'lib/page/RankingList/RatingRankListPage.dart',
        'lib/page/RankingList/FittedRatingRankingListPage.dart',
        'lib/page/RankingList/AvgScoreRankingListPage.dart',
      ]) {
        final src = _read(path);
        expect(src.contains("import '../../widgets/PageTopBar.dart';"), isTrue,
            reason: '$path 没引 PageTopBar');
        expect(src.contains('PageTopBar('), isTrue, reason: '$path 没用上');
        expect(_bareAppBar.hasMatch(_stripLineComments(src)), isFalse,
            reason: '$path 还留着裸 AppBar');
      }
    });

    test('AWMC 四个页面也改走 PageTopBar（含 bottom 进度条那两个）', () {
      for (final path in [
        'lib/page/Awmc/AwmcConsolePage.dart',
        'lib/page/Awmc/AwmcScoreWritePage.dart',
        'lib/page/Awmc/AwmcAuditLogPage.dart',
        'lib/page/Awmc/AwmcUi.dart',
      ]) {
        final src = _read(path);
        expect(src.contains('PageTopBar('), isTrue, reason: '$path 没用上');
        expect(_bareAppBar.hasMatch(_stripLineComments(src)), isFalse,
            reason: '$path 还留着裸 AppBar');
      }
    });
  });
}
