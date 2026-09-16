// 回归测试：首页初始化的「7 天冷却期」不能被空曲库缓存骗过去。
//
// 背景（真实故障）：HomePage._initializeDataInBackground 原先只看
// `lastInitializationTimestamp` 就决定跳过初始化，而这个时间戳**无论
// 初始化成功与否**都会写。于是「首次启动时离线 / 接口 502 / 恢复备份后
// prefs 被清空」会让 App 认下这次初始化，接下来 7 天都不再自动补拉，
// cachedSongs 一直是空的 —— 所有单人猜歌页抽不到曲，永久停在加载转圈。
//
// 修复后：
//   1. 曲库缓存缺失 → 无视冷却期，立刻补拉
//   2. 冷却时间戳只在「曲库真的拉到了」时才写（成功但曲库仍为空 → 不写）
//
// 这里锁住第 1 条依赖的判定契约：缓存空 / 过期 → false，新鲜 → true。
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_first_flutter_app/constant/CacheKeyConstant.dart';
import 'package:my_first_flutter_app/manager/DivingFish/MaimaiMusicDataManager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const thirtyDays = Duration(days: 30);

  test('曲库缓存不存在时 hasValidMusicCache 为 false（会触发补拉）', () async {
    SharedPreferences.setMockInitialValues({});
    final fresh = MaimaiMusicDataManager();
    expect(
      await fresh.hasValidMusicCache(maxAge: thirtyDays),
      isFalse,
      reason: '没有 cachedSongs 时必须判为不可用，否则冷却期会一直挡住补拉',
    );
  });

  test('曲库缓存为空字符串时同样为 false', () async {
    SharedPreferences.setMockInitialValues({
      CacheKeyConstant.cachedSongs: '',
      CacheKeyConstant.cachedSongsTimestamp:
          DateTime.now().millisecondsSinceEpoch,
    });
    expect(
      await MaimaiMusicDataManager().hasValidMusicCache(maxAge: thirtyDays),
      isFalse,
    );
  });

  test('曲库缓存新鲜时为 true（此时才允许走冷却期跳过）', () async {
    SharedPreferences.setMockInitialValues({
      CacheKeyConstant.cachedSongs: '[{"id":"1","title":"t","type":"SD",'
          '"ds":[2.0,7.0,9.5,13.0],"level":["2","7","9+","13"],'
          '"cids":[1,2,3,4],"charts":[],'
          '"basic_info":{"title":"t","artist":"a","genre":"POPS","bpm":180,'
          '"release_date":"","from":"maimai","is_new":false}}]',
      CacheKeyConstant.cachedSongsTimestamp:
          DateTime.now().millisecondsSinceEpoch,
    });
    expect(
      await MaimaiMusicDataManager().hasValidMusicCache(maxAge: thirtyDays),
      isTrue,
    );
  });

  test('曲库缓存过期（超过 maxAge）时为 false', () async {
    SharedPreferences.setMockInitialValues({
      CacheKeyConstant.cachedSongs: '[{"id":"1","title":"t","type":"SD",'
          '"ds":[2.0,7.0,9.5,13.0],"level":["2","7","9+","13"],'
          '"cids":[1,2,3,4],"charts":[],'
          '"basic_info":{"title":"t","artist":"a","genre":"POPS","bpm":180,'
          '"release_date":"","from":"maimai","is_new":false}}]',
      CacheKeyConstant.cachedSongsTimestamp:
          DateTime.now().millisecondsSinceEpoch - const Duration(days: 45).inMilliseconds,
    });
    expect(
      await MaimaiMusicDataManager().hasValidMusicCache(maxAge: thirtyDays),
      isFalse,
      reason: '超过 30 天的旧曲库应触发重新拉取',
    );
  });
}
