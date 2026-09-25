import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_first_flutter_app/constant/CacheKeyConstant.dart';
import 'package:my_first_flutter_app/service/AWMC/AwmcPlayCountStore.dart';
import 'package:my_first_flutter_app/utils/CurrentDataSourceNotifier.dart';

/// 游玩次数（playCount）在**三类账号之间必须隔离**。
///
/// 需求来源：水鱼 / 落雪 / AWMC NET 在账号系统里是三类互不相干的账号
/// （可以绑不同的 QQ、不同的机台账号），游玩次数自然各算各的。
/// 旧版只有一个共享键 `awmc_play_counts_v1`，换账号后谱面详情与 PC50
/// 会显示**上一个账号**的次数。
///
/// 现在按源分键：`awmc_play_counts_v1_<source>`；写入时显式指定归属，
/// 读取时取当前活动账号那一份。
void main() {
  /// 造一份 `/v1/user/music` 的 businessData（字段名与实测响应一致：
  /// `userMusicList` → `userMusicDetailList`）。
  Map<String, dynamic> payload(int musicId, int level, int playCount) => {
        'userId': 11728057,
        'nextIndex': 0,
        'userMusicList': [
          {
            'userMusicDetailList': [
              {
                'musicId': musicId,
                'level': level,
                'playCount': playCount,
                'achievement': 1005000,
                'deluxscoreMax': 2000,
                'comboStatus': 0,
                'syncStatus': 0,
              },
            ],
          },
        ],
      };

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AwmcPlayCountStore.debugResetForTest();
    CurrentDataSourceNotifier.instance.value = RefreshDataSource.shuiyu;
  });

  test('三个账号各存一份：写了水鱼不影响落雪 / AWMC NET', () async {
    await AwmcPlayCountStore.saveFromBusinessData(
      payload(11663, 3, 51),
      source: RefreshDataSource.shuiyu,
    );
    await AwmcPlayCountStore.saveFromBusinessData(
      payload(11663, 3, 999),
      source: RefreshDataSource.awmc,
    );

    final prefs = await SharedPreferences.getInstance();
    final shuiyuKey =
        '${CacheKeyConstant.awmcPlayCountsPrefix}${RefreshDataSource.shuiyu.key}';
    final luoxueKey =
        '${CacheKeyConstant.awmcPlayCountsPrefix}${RefreshDataSource.luoxue.key}';
    final awmcKey =
        '${CacheKeyConstant.awmcPlayCountsPrefix}${RefreshDataSource.awmc.key}';

    expect(prefs.getString(shuiyuKey), isNotNull);
    expect(prefs.getString(awmcKey), isNotNull);
    expect(prefs.getString(luoxueKey), isNull, reason: '没写过落雪的，就不该有它的键');

    // 两份数据互不影响
    final shuiyu = json.decode(prefs.getString(shuiyuKey)!) as Map;
    final awmc = json.decode(prefs.getString(awmcKey)!) as Map;
    expect((shuiyu['counts'] as Map)['11663/3'], 51);
    expect((awmc['counts'] as Map)['11663/3'], 999);
  });

  test('读取跟随当前活动账号（换账号就换一份次数）', () async {
    await AwmcPlayCountStore.saveFromBusinessData(
      payload(11663, 3, 51),
      source: RefreshDataSource.shuiyu,
    );
    await AwmcPlayCountStore.saveFromBusinessData(
      payload(11663, 3, 999),
      source: RefreshDataSource.awmc,
    );
    await AwmcPlayCountStore.saveFromBusinessData(
      payload(11663, 3, 7),
      source: RefreshDataSource.luoxue,
    );

    CurrentDataSourceNotifier.instance.value = RefreshDataSource.shuiyu;
    expect(AwmcPlayCountStore.playCountOfDiffIndex(11663, 3), 51);

    CurrentDataSourceNotifier.instance.value = RefreshDataSource.luoxue;
    expect(AwmcPlayCountStore.playCountOfDiffIndex(11663, 3), 7);

    CurrentDataSourceNotifier.instance.value = RefreshDataSource.awmc;
    expect(AwmcPlayCountStore.playCountOfDiffIndex(11663, 3), 999);
  });

  test('只同步过水鱼的账号：切到 AWMC 后是「没有次数」而不是别人的次数', () async {
    await AwmcPlayCountStore.saveFromBusinessData(
      payload(11663, 3, 51),
      source: RefreshDataSource.shuiyu,
    );

    CurrentDataSourceNotifier.instance.value = RefreshDataSource.awmc;
    expect(AwmcPlayCountStore.hasData, isFalse);
    expect(AwmcPlayCountStore.playCountOfDiffIndex(11663, 3), isNull,
        reason: '宁可显示没有，也不能把水鱼的次数当成 AWMC 账号的');
  });

  test('重启后按源读回（prefs 往返）', () async {
    await AwmcPlayCountStore.saveFromBusinessData(
      payload(11663, 3, 51),
      source: RefreshDataSource.shuiyu,
    );
    await AwmcPlayCountStore.saveFromBusinessData(
      payload(11663, 3, 999),
      source: RefreshDataSource.awmc,
    );

    // 模拟重启：清掉内存，从 prefs 重新加载
    AwmcPlayCountStore.debugResetForTest();
    await AwmcPlayCountStore.ensureLoaded();

    CurrentDataSourceNotifier.instance.value = RefreshDataSource.shuiyu;
    expect(AwmcPlayCountStore.playCountOfDiffIndex(11663, 3), 51);
    CurrentDataSourceNotifier.instance.value = RefreshDataSource.awmc;
    expect(AwmcPlayCountStore.playCountOfDiffIndex(11663, 3), 999);
  });

  test('旧版的共享键会迁到「当时那个账号」名下并删除', () async {
    SharedPreferences.setMockInitialValues({
      CacheKeyConstant.awmcPlayCountsLegacy: json.encode({
        'version': 1,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'userId': 1,
        'counts': {'11663/3': 51},
      }),
      CacheKeyConstant.lastDataSource: RefreshDataSource.luoxue.key,
    });
    AwmcPlayCountStore.debugResetForTest();

    await AwmcPlayCountStore.ensureLoaded();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(CacheKeyConstant.awmcPlayCountsLegacy), isNull,
        reason: '迁移完就该把它删掉，免得下次又迁一遍');
    expect(
      prefs.getString(
          '${CacheKeyConstant.awmcPlayCountsPrefix}${RefreshDataSource.luoxue.key}'),
      isNotNull,
    );
    // 归属正确：算在落雪名下，不是水鱼
    CurrentDataSourceNotifier.instance.value = RefreshDataSource.luoxue;
    expect(AwmcPlayCountStore.playCountOfDiffIndex(11663, 3), 51);
    CurrentDataSourceNotifier.instance.value = RefreshDataSource.shuiyu;
    expect(AwmcPlayCountStore.playCountOfDiffIndex(11663, 3), isNull);
  });

  test('迁移不会覆盖目标账号已有的数据', () async {
    SharedPreferences.setMockInitialValues({
      CacheKeyConstant.awmcPlayCountsLegacy: json.encode({
        'version': 1,
        'updatedAt': 1,
        'userId': 1,
        'counts': {'11663/3': 51},
      }),
      '${CacheKeyConstant.awmcPlayCountsPrefix}${RefreshDataSource.shuiyu.key}':
          json.encode({
        'version': 1,
        'updatedAt': 2,
        'userId': 2,
        'counts': {'11663/3': 999},
      }),
      CacheKeyConstant.lastDataSource: RefreshDataSource.shuiyu.key,
    });
    AwmcPlayCountStore.debugResetForTest();

    await AwmcPlayCountStore.ensureLoaded();

    CurrentDataSourceNotifier.instance.value = RefreshDataSource.shuiyu;
    expect(AwmcPlayCountStore.playCountOfDiffIndex(11663, 3), 999,
        reason: '新键已经有数据时，旧共享键只删不覆盖');
  });

  test('clear 只清指定账号，clearAll 清三个', () async {
    for (final s in RefreshDataSource.values) {
      await AwmcPlayCountStore.saveFromBusinessData(
        payload(11663, 3, 51),
        source: s,
      );
    }

    await AwmcPlayCountStore.clear(source: RefreshDataSource.luoxue);
    CurrentDataSourceNotifier.instance.value = RefreshDataSource.luoxue;
    expect(AwmcPlayCountStore.hasData, isFalse);
    CurrentDataSourceNotifier.instance.value = RefreshDataSource.shuiyu;
    expect(AwmcPlayCountStore.hasData, isTrue, reason: '清落雪不能连水鱼一起清');

    await AwmcPlayCountStore.clearAll();
    for (final s in RefreshDataSource.values) {
      CurrentDataSourceNotifier.instance.value = s;
      expect(AwmcPlayCountStore.hasData, isFalse, reason: '${s.key} 没清干净');
    }
  });
}
