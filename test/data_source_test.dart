import 'dart:io';

import 'package:flutter/material.dart' show Brightness;
import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_flutter_app/manager/AWMC/AwmcNetUserPlayDataManager.dart';
import 'package:my_first_flutter_app/service/RankingList/SongRankingService.dart'
    show parseDataSource;
import 'package:my_first_flutter_app/utils/CurrentDataSourceNotifier.dart';
import 'package:my_first_flutter_app/utils/ImageEncodeUtil.dart';
import 'package:my_first_flutter_app/widgets/DataSourceTag.dart';
import 'package:my_first_flutter_app/widgets/DivingFishAccountSection.dart'
    show DivingFishQqState, resolveDivingFishQqState;

/// AWMC NET.（net.wmc.pub）接入相关：数据源枚举 + records 归一化。
///
/// 这些是纯函数，不需要设备就能验证，所以覆盖掉——它们正是最容易悄悄错的地方：
/// 归一化少过滤一条未游玩谱面，单曲排行榜就会多传一条 0% 成绩；
/// playerId 前缀解析少认一个源，排行榜就会把 AWMC NET 标成落雪。
void main() {
  group('RefreshDataSource 三源枚举', () {
    test('三个源的持久化 key 与显示名', () {
      expect(RefreshDataSource.shuiyu.key, 'shuiyu');
      expect(RefreshDataSource.luoxue.key, 'luoxue');
      expect(RefreshDataSource.awmc.key, 'awmc');

      expect(RefreshDataSource.shuiyu.displayName, '水鱼');
      expect(RefreshDataSource.luoxue.displayName, '落雪');
      expect(RefreshDataSource.awmc.displayName, 'AWMC NET');
    });

    test('fromKey 认得 awmc（切账号要靠它还原数据源）', () {
      expect(RefreshDataSource.fromKey('awmc'), RefreshDataSource.awmc);
      expect(RefreshDataSource.fromKey('luoxue'), RefreshDataSource.luoxue);
      expect(RefreshDataSource.fromKey('shuiyu'), RefreshDataSource.shuiyu);
      // 未知 / 空按老行为兜底成水鱼
      expect(RefreshDataSource.fromKey(''), RefreshDataSource.shuiyu);
      expect(RefreshDataSource.fromKey(null), RefreshDataSource.shuiyu);
    });

    test('displayNameOfKey 对未知 key 返回空串，不误标成水鱼', () {
      expect(RefreshDataSource.displayNameOfKey('awmc'), 'AWMC NET');
      expect(RefreshDataSource.displayNameOfKey('luoxue'), '落雪');
      expect(RefreshDataSource.displayNameOfKey('shuiyu'), '水鱼');
      // 导出图的数据源标签：宁可留空，也不能把未知来源错标成「水鱼」
      expect(RefreshDataSource.displayNameOfKey('nope'), '');
      expect(RefreshDataSource.displayNameOfKey(''), '');
      expect(RefreshDataSource.displayNameOfKey(null), '');
    });

    test('短名：榜单里用户名前的标签 / 排行榜 Tab 用 AWMC', () {
      expect(RefreshDataSource.shuiyu.shortDisplayName, '水鱼');
      expect(RefreshDataSource.luoxue.shortDisplayName, '落雪');
      expect(RefreshDataSource.awmc.shortDisplayName, 'AWMC');
      // 全名不动 —— 账号面板 / 数据源摘要 / 导出图仍然显示 AWMC NET
      expect(RefreshDataSource.awmc.displayName, 'AWMC NET');

      expect(RefreshDataSource.shortDisplayNameOfKey('awmc'), 'AWMC');
      expect(RefreshDataSource.shortDisplayNameOfKey('shuiyu'), '水鱼');
      expect(RefreshDataSource.shortDisplayNameOfKey('nope'), '');
      expect(RefreshDataSource.shortDisplayNameOfKey(null), '');
    });

    test('短名不会比全名更长（标签空间有限）', () {
      for (final source in RefreshDataSource.values) {
        expect(source.shortDisplayName.length,
            lessThanOrEqualTo(source.displayName.length),
            reason: '${source.key} 的短名比全名还长');
      }
    });

    test('只有落雪不是 QQ 制', () {
      expect(RefreshDataSource.shuiyu.idIsQQ, isTrue);
      expect(RefreshDataSource.awmc.idIsQQ, isTrue);
      expect(RefreshDataSource.luoxue.idIsQQ, isFalse);
    });

    test('每个源都有自己的 id 标记键（防串号）', () {
      final keys = {
        for (final s in RefreshDataSource.values) s.userIdCacheKey,
      };
      expect(keys.length, 3, reason: '三个源不能共用 id 标记键');
      expect(RefreshDataSource.awmc.userIdCacheKey, 'awmc_user_id');
    });

    test('parseUserIdMarker 按第一个冒号切，兼容 id 内含冒号', () {
      expect(RefreshDataSource.parseUserIdMarker('awmc:488581724'), '488581724');
      expect(RefreshDataSource.parseUserIdMarker('luoxue:a:b'), 'a:b');
      expect(RefreshDataSource.parseUserIdMarker('shuiyu:'), isNull);
      expect(RefreshDataSource.parseUserIdMarker('no-colon'), isNull);
      expect(RefreshDataSource.parseUserIdMarker(null), isNull);
    });
  });

  group('parseDataSource（排行榜 playerId 前缀）', () {
    test('三个源都要认出来', () {
      expect(parseDataSource('shuiyu:488581724'), 'shuiyu');
      expect(parseDataSource('luoxue:12345'), 'luoxue');
      // 这条是回归点：原来只判断 shuiyu / luoxue，awmc 会被误判成落雪
      expect(parseDataSource('awmc:488581724'), 'awmc');
    });

    test('无前缀 / 未知前缀沿用旧的落雪兜底', () {
      expect(parseDataSource('488581724'), 'luoxue');
      expect(parseDataSource('nope:1'), 'luoxue');
    });
  });

  group('DataSourceTag（榜单里用户名前的标签）', () {
    test('AWMC 用短名，不再显示 AWMC NET', () {
      expect(dataSourceStyleOf('awmc', Brightness.light).label, 'AWMC');
      expect(dataSourceStyleOf('awmc', Brightness.dark).label, 'AWMC');
      expect(dataSourceStyleOf('shuiyu', Brightness.light).label, '水鱼');
      expect(dataSourceStyleOf('luoxue', Brightness.light).label, '落雪');
    });

    test('未知 / 空数据源退回「未知」，不会错标成水鱼', () {
      expect(dataSourceStyleOf('nope', Brightness.light).label, '未知');
      expect(dataSourceStyleOf('', Brightness.light).label, '未知');
      expect(dataSourceStyleOf(null, Brightness.light).label, '未知');
    });

    test('三个源的标签配色互不相同（能一眼区分）', () {
      final colors = {
        for (final key in ['shuiyu', 'luoxue', 'awmc'])
          dataSourceStyleOf(key, Brightness.light).foreground.toARGB32(),
      };
      expect(colors.length, 3);
    });
  });

  group('水鱼账号三态（登录 / 没填 QQ / 正常）', () {
    test('没登录 → notLoggedIn（不管 QQ 有没有值）', () {
      expect(
          resolveDivingFishQqState(loggedIn: false, bindQq: ''),
          DivingFishQqState.notLoggedIn);
      // 没登录时即使 prefs 里残留了 QQ，也不算已绑定
      expect(
          resolveDivingFishQqState(loggedIn: false, bindQq: '488581724'),
          DivingFishQqState.notLoggedIn);
    });

    test('登录了但水鱼账号没填 QQ → noBindQq（要单独引导去官网填）', () {
      expect(resolveDivingFishQqState(loggedIn: true, bindQq: ''),
          DivingFishQqState.noBindQq);
      // 只有空白也算没填 —— /player/profile 可能回空白串
      expect(resolveDivingFishQqState(loggedIn: true, bindQq: '   '),
          DivingFishQqState.noBindQq);
    });

    test('登录了且有 QQ → bound', () {
      expect(resolveDivingFishQqState(loggedIn: true, bindQq: '488581724'),
          DivingFishQqState.bound);
      expect(resolveDivingFishQqState(loggedIn: true, bindQq: ' 488581724 '),
          DivingFishQqState.bound);
    });

    test('三态互斥且覆盖全部输入组合', () {
      // 「登录了但没填 QQ」必须能和「没登录」区分开 ——
      // 这正是原来把两者合并成一个 bool 时丢掉的信息
      final states = <DivingFishQqState>{
        resolveDivingFishQqState(loggedIn: false, bindQq: ''),
        resolveDivingFishQqState(loggedIn: true, bindQq: ''),
        resolveDivingFishQqState(loggedIn: true, bindQq: '1'),
      };
      expect(states.length, 3);
    });
  });

  group('导出截图尺寸保护 safeCapturePixelRatio', () {
    test('正常尺寸不降质（保持 3.0）', () {
      // B50 导出容器 1700 逻辑宽 × ~2500 高：3.0 倍后仍在上限内
      expect(ImageEncodeUtil.safeCapturePixelRatio(1700, 2500), 3.0);
      // 小图更不该被动
      expect(ImageEncodeUtil.safeCapturePixelRatio(360, 640), 3.0);
    });

    test('超过纹理上限时按边长压下 pixelRatio', () {
      // 高 10000 × 3.0 = 30000 > 16000 → 压到 1.6
      final r = ImageEncodeUtil.safeCapturePixelRatio(1200, 10000);
      expect(r, lessThan(3.0));
      expect(1200 * r, lessThanOrEqualTo(kMaxCaptureTextureSize));
      expect(10000 * r, lessThanOrEqualTo(kMaxCaptureTextureSize));

      // 超宽同理
      final rw = ImageEncodeUtil.safeCapturePixelRatio(20000, 100);
      expect(20000 * rw, lessThanOrEqualTo(kMaxCaptureTextureSize));
    });

    test('结果永远不超过上限（取宽高两个约束里更严的那个）', () {
      for (final size in [
        [1700.0, 2500.0],
        [1200.0, 9000.0],
        [3000.0, 3000.0],
        [8000.0, 400.0],
        [100.0, 20000.0],
      ]) {
        final r = ImageEncodeUtil.safeCapturePixelRatio(size[0], size[1]);
        expect(r, lessThanOrEqualTo(3.0));
        expect(r, greaterThanOrEqualTo(kMinCapturePixelRatio));
        // 这条才是保护的本意：算出来的比例必须真的把两边都压进上限内。
        // 之前下限取 1.0 时，[100, 20000] 会被顶回 1.0 → 20000 > 16000，
        // 保护形同虚设（本用例就是为这个回归加的）。
        expect(size[0] * r, lessThanOrEqualTo(kMaxCaptureTextureSize),
            reason: '宽度 ${size[0]} 在 ratio $r 下超出纹理上限');
        expect(size[1] * r, lessThanOrEqualTo(kMaxCaptureTextureSize),
            reason: '高度 ${size[1]} 在 ratio $r 下超出纹理上限');
      }
    });

    test('非法尺寸回退到 preferred，不返回 0/NaN', () {
      expect(ImageEncodeUtil.safeCapturePixelRatio(0, 100), 3.0);
      expect(ImageEncodeUtil.safeCapturePixelRatio(100, 0), 3.0);
      expect(ImageEncodeUtil.safeCapturePixelRatio(-5, -5), 3.0);
    });
  });

  // ---- 源码守卫：这处是纯布局宽度问题，widget test 里搭不出真实卡片宽度 ----
  group('PLAYER OVERVIEW 的「数据源」格子', () {
    test('必须用短名，否则 AWMC NET 会被截成「AWMC N..」', () {
      final src = File('lib/page/HomePage.dart').readAsStringSync();
      // 那一行是三个 Expanded 平分宽度：360dp 屏上每格约 107dp，
      // 再让出右边 14dp 的切换图标，留给文字只有 ~90dp；
      // 'AWMC NET'（15px 粗体 ≈ 79dp）加上机型字体度量差异就会顶出去，
      // 被 _summaryMetric 里的 TextOverflow.ellipsis 截断。
      expect(src, contains('source.shortDisplayName'),
          reason: 'PLAYER OVERVIEW 的「数据源」要用 shortDisplayName（AWMC）');
      expect(src, isNot(contains('source.displayName')),
          reason: 'HomePage 里不该再用全名 displayName —— 那一格宽度放不下');
    });
  });

  group('AWMC NET records 归一化', () {
    Map<String, dynamic> record(int songId, num achievements) => {
          'song_id': songId,
          'title': '曲目 $songId',
          'type': 'DX',
          'level_index': 3,
          'level_label': 'Master',
          'level': '13',
          'ds': 13.0,
          'achievements': achievements,
          'rate': 'sss',
          'fc': 'fc',
          'fs': 'fs',
          'dxScore': 2000,
          'ra': 300,
          'is_new': false,
        };

    test('丢掉未游玩谱面（achievements == 0），保留真打过的', () {
      final normalized = AwmcNetUserPlayDataManager.normalizeRecords({
        'username': 'ChiffonOwO',
        'nickname': 'ChiFFoN',
        'rating': 15579,
        'plate': '',
        'additional_rating': 0,
        'records': [
          record(8, 0.0), // 未游玩：AWMC 会把整个曲库列出来
          record(17, 100.9027),
          record(270, 0.099), // 真打过的最低分，必须保留
        ],
      });

      expect(normalized, isNotNull);
      final records = normalized!['records'] as List;
      expect(records.length, 2);
      expect(records.map((r) => r['song_id']), [17, 270]);
      // records 里的字段名必须与水鱼一致，否则 RecordItem.fromJson 会读空
      expect(records.first.keys, contains('achievements'));
      expect(records.first.keys, contains('song_id'));
      expect(records.first.keys, contains('level_index'));
      expect(records.first.keys, contains('dxScore'));
    });

    test('账号级字段透传，缺失时给兜底默认值', () {
      final normalized = AwmcNetUserPlayDataManager.normalizeRecords({
        'username': 'ChiffonOwO',
        'nickname': 'ChiFFoN',
        'rating': 15579,
        'records': [record(17, 100.5)],
      })!;

      expect(normalized['nickname'], 'ChiFFoN');
      expect(normalized['rating'], 15579);
      // AWMC NET 不提供段位与牌子，下游按水鱼的默认值处理
      expect(normalized['additional_rating'], 0);
      expect(normalized['plate'], '');
    });

    test('外面套一层 data 也能解', () {
      final normalized = AwmcNetUserPlayDataManager.normalizeRecords({
        'data': {
          'nickname': 'X',
          'records': [record(1, 90.0)],
        },
      });
      expect(normalized, isNotNull);
      expect((normalized!['records'] as List).length, 1);
    });

    test('结构无法识别时返回 null（调用方转成中文异常）', () {
      expect(AwmcNetUserPlayDataManager.normalizeRecords(null), isNull);
      expect(AwmcNetUserPlayDataManager.normalizeRecords('oops'), isNull);
      // 没有 records 字段
      expect(AwmcNetUserPlayDataManager.normalizeRecords({'nickname': 'X'}),
          isNull);
      // records 不是数组
      expect(
          AwmcNetUserPlayDataManager.normalizeRecords({'records': 'x'}), isNull);
    });
  });
}
