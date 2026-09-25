import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_first_flutter_app/constant/CacheKeyConstant.dart';
import 'package:my_first_flutter_app/service/AccountStore.dart';
import 'package:my_first_flutter_app/service/AccountSwitchService.dart';
import 'package:my_first_flutter_app/service/History/ChartHistoryStore.dart';
import 'package:my_first_flutter_app/service/PersonalizedScoreService.dart';
import 'package:my_first_flutter_app/utils/CurrentDataSourceNotifier.dart';
import 'package:my_first_flutter_app/utils/UserProfileNotifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late Directory history;

  Future<void> seed(RefreshDataSource source, int rating,
      {String id = '12345'}) async {
    await prefs.setString(source.userIdCacheKey, '${source.key}:$id');
    await prefs.setString('cachedQQ', id);
    await prefs.setString('userNickname', source.key);
    await prefs.setInt('best50TotalRA', rating);
    await prefs.setString('last_used_qq', id);
    await prefs.setString('best50_data_$id', jsonEncode({'rating': rating}));
    await prefs.setString(
        CacheKeyConstant.userPlayData,
        jsonEncode({
          'records': [
            {
              'song_id': 8,
              'level_index': 3,
              'achievements': rating / 160,
              'dxScore': 100
            }
          ],
          'rating': rating,
        }));
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    history = Directory.systemTemp.createTempSync('account_isolation_');
    ChartHistoryStore.debugDirectoryOverride = history.path;
    ChartHistoryStore.instance.debugClearCache();
    CurrentDataSourceNotifier.instance.value = RefreshDataSource.shuiyu;
    UserProfileNotifier.replace(UserProfile.defaults);
    await seed(RefreshDataSource.shuiyu, 16000);
    await AccountSwitchService.ensureMigrated();
  });

  tearDown(() {
    expect(AccountSwitchService.isBusy, isFalse);
    ChartHistoryStore.instance.debugClearCache();
    ChartHistoryStore.debugDirectoryOverride = null;
    history.deleteSync(recursive: true);
  });

  for (final source in [RefreshDataSource.luoxue, RefreshDataSource.awmc]) {
    test('首次刷新 ${source.key} 的活动槽为空，原账号与相同 ID 的 Best50 不被覆盖', () async {
      await AccountSwitchService.runRefresh(source, () async {
        expect(CurrentDataSourceNotifier.instance.value, source);
        expect(prefs.getString(CacheKeyConstant.userPlayData), isNull);
        expect(prefs.getString('cachedQQ'), isNull);
        await seed(source, 12000);
      });
      expect(prefs.getInt('best50TotalRA'), 12000);
      expect(await AccountSwitchService.switchTo(RefreshDataSource.shuiyu),
          SwitchOutcome.switched);
      expect(prefs.getInt('best50TotalRA'), 16000);
      expect(
          jsonDecode(prefs.getString('best50_data_12345')!)['rating'], 16000);
      expect(
          await AccountSwitchService.switchTo(source), SwitchOutcome.switched);
      expect(prefs.getInt('best50TotalRA'), 12000);
      expect(prefs.getString(RefreshDataSource.shuiyu.userIdCacheKey), isNull);
    });
  }

  for (final source in RefreshDataSource.values) {
    test('${source.key} 刷新失败恢复原账号，含同源失败', () async {
      await expectLater(
          AccountSwitchService.runRefresh(source, () async {
            await seed(source, 9000);
            throw StateError('模拟网络错误');
          }),
          throwsStateError);
      expect(
          CurrentDataSourceNotifier.instance.value, RefreshDataSource.shuiyu);
      expect(prefs.getInt('best50TotalRA'), 16000);
      expect(prefs.getString(CacheKeyConstant.accountRotationPending), isNull);
    });
  }

  test('被拒绝的第二次刷新不会释放或回滚第一个刷新', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final first =
        AccountSwitchService.runRefresh(RefreshDataSource.awmc, () async {
      started.complete();
      await release.future;
      await seed(RefreshDataSource.awmc, 13000);
    });
    await started.future;
    await expectLater(
        AccountSwitchService.runRefresh(RefreshDataSource.luoxue, () async {}),
        throwsStateError);
    expect(await AccountSwitchService.switchTo(RefreshDataSource.shuiyu),
        SwitchOutcome.busy);
    await expectLater(
        UserProfileNotifier.clearShuiyuAccountCache(), throwsStateError);
    expect(AccountSwitchService.isBusy, isTrue);
    expect(CurrentDataSourceNotifier.instance.value, RefreshDataSource.awmc);
    release.complete();
    await first;
    expect(prefs.getInt('best50TotalRA'), 13000);
  });

  test('登出非活动水鱼仅清水鱼，当前 AWMC 成绩与源指针保留', () async {
    await prefs.setString(CacheKeyConstant.probeDivingFishToken, 'test-token');
    await AccountSwitchService.runRefresh(
        RefreshDataSource.awmc, () => seed(RefreshDataSource.awmc, 14000));
    await UserProfileNotifier.clearShuiyuAccountCache();
    expect(prefs.getString(CacheKeyConstant.probeDivingFishToken), isNull);
    expect(await AccountStore.hasCache('shuiyu'), isFalse);
    expect(CurrentDataSourceNotifier.instance.value, RefreshDataSource.awmc);
    expect(prefs.getString(CacheKeyConstant.lastDataSource), 'awmc');
    expect(prefs.getInt('best50TotalRA'), 14000);
    expect(UserProfileNotifier.instance.value.best50TotalRA, 14000);
  });

  test('中断恢复先清掉未完成的新账号字段，再恢复原账号', () async {
    await prefs.setString(CacheKeyConstant.accountRotationPending,
        jsonEncode({'restore': 'shuiyu'}));
    await seed(RefreshDataSource.awmc, 9000);
    await prefs.setString(CacheKeyConstant.commentNickname, 'incomplete');
    await AccountSwitchService.recoverIfInterrupted();
    expect(prefs.getString(CacheKeyConstant.commentNickname), isNull);
    expect(prefs.getString(RefreshDataSource.awmc.userIdCacheKey), isNull);
    expect(prefs.getInt('best50TotalRA'), 16000);
  });

  test('坏存档切换失败不会删掉当前数据', () async {
    await prefs.setString('${CacheKeyConstant.accountArchivePlayPrefix}awmc',
        jsonEncode({CacheKeyConstant.userPlayData: '{}'}));
    await prefs.setString(
        '${CacheKeyConstant.accountArchiveIdentityPrefix}awmc', '{broken');
    expect(await AccountSwitchService.switchTo(RefreshDataSource.awmc),
        SwitchOutcome.failed);
    expect(prefs.getInt('best50TotalRA'), 16000);
    expect(CurrentDataSourceNotifier.instance.value, RefreshDataSource.shuiyu);
  });

  test('换账号不会复用牌子成绩的内存缓存', () async {
    final service = PersonalizedScoreService();
    service.clearRecordsCache();
    expect(await service.isSongCompleted(8, 3, '将'), isTrue);
    await AccountSwitchService.runRefresh(
        RefreshDataSource.awmc, () => seed(RefreshDataSource.awmc, 10000));
    expect(await service.isSongCompleted(8, 3, '将'), isFalse);
  });

  test('同源换人清除评论与姓名框等旧身份数据', () async {
    await prefs.setString(CacheKeyConstant.commentNickname, 'old');
    await prefs.setInt(CacheKeyConstant.selectedPlateIdCache, 7);
    await AccountSwitchService.runRefresh(RefreshDataSource.shuiyu, () async {
      await AccountSwitchService.bindIdentity(
          RefreshDataSource.shuiyu, '67890');
      expect(prefs.getString(CacheKeyConstant.commentNickname), isNull);
      expect(prefs.get(CacheKeyConstant.selectedPlateIdCache), isNull);
      expect(prefs.getString('cachedQQ'), '67890');
      await seed(RefreshDataSource.shuiyu, 14000, id: '67890');
    });
  });

  test('三个平台相同 ID 与同平台不同 ID 的 Rating 都独立，清缓存重读仍成立', () async {
    final store = ChartHistoryStore.instance;
    var rating = 12000;
    for (final source in RefreshDataSource.values) {
      await store.recordRating(
          rating: rating++, sourceKey: source.key, accountId: '12345');
    }
    await store.recordRating(
        rating: 17000, sourceKey: 'awmc', accountId: '67890');
    store.debugClearCache();
    rating = 12000;
    for (final source in RefreshDataSource.values) {
      expect(
          (await store.ratingSeries(sourceKey: source.key, accountId: '12345'))
              .single
              .rating,
          rating++);
    }
    expect(
        (await store.ratingSeries(sourceKey: 'awmc', accountId: '67890'))
            .single
            .rating,
        17000);
  });

  test('同一历史文件并发记录不会争用临时文件或丢 Rating', () async {
    final store = ChartHistoryStore.instance;
    await Future.wait([
      store.recordRating(
          rating: 16000, sourceKey: 'shuiyu', accountId: '12345'),
      store.recordChartSnapshot({
        'records': [
          {
            'song_id': 8,
            'level_index': 3,
            'achievements': 100.0,
            'dxScore': 200
          }
        ]
      }, sourceKey: 'shuiyu', accountId: '12345'),
    ]);
    store.debugClearCache();
    expect((await store.ratingSeries()).single.rating, 16000);
    expect((await store.summary()).chartCount, 1);
  });

  test('提交目标存档写到一半被杀：恢复目标旧存档和原活动账号', () async {
    final oldMetas = prefs.getString(CacheKeyConstant.accountStore);
    await prefs.setString(
        CacheKeyConstant.accountRotationPending,
        jsonEncode({
          'restore': 'shuiyu',
          'target': 'awmc',
          'identity': null,
          'play': null,
          'metas': oldMetas,
        }));
    await prefs.setString(
        '${CacheKeyConstant.accountArchivePlayPrefix}awmc', '{"partial":true}');
    await seed(RefreshDataSource.awmc, 9000);
    await AccountSwitchService.recoverIfInterrupted();
    expect(prefs.getString('${CacheKeyConstant.accountArchivePlayPrefix}awmc'),
        isNull);
    expect(prefs.getString(CacheKeyConstant.accountStore), oldMetas);
    expect(prefs.getInt('best50TotalRA'), 16000);
  });

  test('旧历史只迁给升级前账号，换人不继承，原文件保留', () async {
    await prefs.remove('account_history_identity_migrated_v1');
    await prefs.remove('account_history_owners_v1');
    await ChartHistoryStore.instance
        .recordRating(rating: 15500, sourceKey: 'shuiyu', accountId: '');
    await AccountSwitchService.ensureMigrated();
    expect(
        (await ChartHistoryStore.instance.ratingSeries(accountId: '12345'))
            .single
            .rating,
        15500);
    expect(await ChartHistoryStore.instance.ratingSeries(accountId: '67890'),
        isEmpty);
    expect(File('${history.path}/shuiyu.json').existsSync(), isTrue);
    await AccountSwitchService.runRefresh(RefreshDataSource.shuiyu,
        () => seed(RefreshDataSource.shuiyu, 11000, id: '67890'));
    await AccountSwitchService.ensureMigrated();
    expect(await ChartHistoryStore.instance.ratingSeries(), isEmpty);
  });

  test('空目标的排行榜开关默认关闭，不继承当前账号选择', () async {
    await prefs.setBool(CacheKeyConstant.participateRankings, true);
    expect(
        (await AccountStore.settingsFor(
            RefreshDataSource.shuiyu))[CacheKeyConstant.participateRankings],
        isTrue);
    expect(
        (await AccountStore.settingsFor(
            RefreshDataSource.awmc))[CacheKeyConstant.participateRankings],
        isNot(true));
  });
  test('三个源同一 ID 六种方向切换都还原各自数据，清除活动源正确回落', () async {
    final ratings = {'shuiyu': 16000, 'luoxue': 13000, 'awmc': 12000};
    for (final source in [RefreshDataSource.luoxue, RefreshDataSource.awmc]) {
      await AccountSwitchService.runRefresh(
          source, () => seed(source, ratings[source.key]!));
    }
    for (final from in RefreshDataSource.values) {
      for (final to in RefreshDataSource.values) {
        if (from == to) continue;
        await AccountSwitchService.switchTo(from);
        expect(await AccountSwitchService.switchTo(to), SwitchOutcome.switched);
        expect(prefs.getString('userNickname'), to.key);
        expect(prefs.getInt('best50TotalRA'), ratings[to.key]);
      }
    }
    await AccountSwitchService.switchTo(RefreshDataSource.awmc);
    await AccountSwitchService.clearAccountData(RefreshDataSource.awmc);
    expect(CurrentDataSourceNotifier.instance.value, RefreshDataSource.shuiyu);
    expect(prefs.getInt('best50TotalRA'), 16000);
    expect(await AccountStore.hasCache('awmc'), isFalse);
    expect(await AccountStore.hasCache('luoxue'), isTrue);
  });
}
