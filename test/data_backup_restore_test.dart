// 数据备份恢复的回归测试。
//
// 背景（真机反馈方向）：恢复是「先 prefs.clear() 再逐键写回」，用户最怕两件事：
//   1. 导入之后 App「卡死」—— 恢复期间页面完全没有 loading，几百个键要写好久；
//   2. 恢复完之后，随手改一下笔记 / 收藏夹 / 星标，刚导入的数据就被旧的内存副本
//      整体覆盖回去（这些 Store 的保存都是「写整个列表」）。
//
// 这里锁住第 2 件事依赖的契约：restoreData 能正确往返 + clearFirst 的覆盖语义，
// 以及 reloadAfterRestore 确实把内存里的单例重新读了一遍。
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_first_flutter_app/constant/CacheKeyConstant.dart';
import 'package:my_first_flutter_app/service/DataBackupService.dart';
import 'package:my_first_flutter_app/utils/FavoriteFeaturesNotifier.dart';
import 'package:my_first_flutter_app/utils/UserProfileNotifier.dart';

/// 构造一条与导出格式一致的备份项。
Map<String, dynamic> _entry(String type, Object? value) =>
    {'type': type, 'value': value};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = DataBackupService();

  group('restoreData', () {
    test('四种基本类型 + List<String> 都能原样往返', () async {
      SharedPreferences.setMockInitialValues({});

      final backup = {
        'a_string': _entry('String', '落雪'),
        'a_int': _entry('int', 15234),
        'a_double': _entry('double', 0.8),
        'a_bool': _entry('bool', true),
        'a_list': _entry('List<String>', <String>['音乐', '收藏的功能']),
      };

      final count = await service.restoreData(backup);
      expect(count, 5);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('a_string'), '落雪');
      expect(prefs.getInt('a_int'), 15234);
      expect(prefs.getDouble('a_double'), 0.8);
      expect(prefs.getBool('a_bool'), isTrue);
      expect(prefs.getStringList('a_list'), ['音乐', '收藏的功能']);
    });

    test('clearFirst：备份里没有的键会被一并抹掉', () async {
      SharedPreferences.setMockInitialValues({
        'only_in_backup': '新值',
        'stale_key': '恢复后不该还在',
      });

      await service.restoreData({'only_in_backup': _entry('String', '新值')});

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('only_in_backup'), '新值');
      expect(prefs.containsKey('stale_key'), isFalse,
          reason: '覆盖恢复的语义就是「备份里没有的都不留」');
    });

    test('敏感键既不导出也不还原（别人分享的备份塞不进 AWMC 令牌）', () async {
      SharedPreferences.setMockInitialValues({
        CacheKeyConstant.awmcToken: 'gw_用户自己的令牌',
      });

      final count = await service.restoreData({
        'normal': _entry('String', 'ok'),
        CacheKeyConstant.awmcToken: _entry('String', 'gw_别人塞进来的'),
      });

      // 敏感键被跳过，所以只算 1 个
      expect(count, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(CacheKeyConstant.awmcToken), isFalse,
          reason: '恢复不该把陌生人备份里的令牌写进本机');
    });

    test('类型对不上的坏数据只跳过那一条，不影响其余键', () async {
      SharedPreferences.setMockInitialValues({});

      final count = await service.restoreData({
        'good': _entry('String', 'ok'),
        'bad': _entry('int', '这不是数字'),
        'also_good': _entry('bool', false),
      });

      expect(count, 2);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('good'), 'ok');
      expect(prefs.getBool('also_good'), isFalse);
    });
  });

  group('reloadAfterRestore', () {
    test('星标（收藏的功能）与昵称会按恢复后的 prefs 重读', () async {
      SharedPreferences.setMockInitialValues({
        CacheKeyConstant.favoriteFeatures: <String>['旧收藏'],
        'userNickname': '旧昵称',
      });
      // 先把内存状态建立成「恢复前」的样子
      await FavoriteFeaturesNotifier.load();
      await UserProfileNotifier.load();
      expect(FavoriteFeaturesNotifier.titles, {'旧收藏'});
      expect(UserProfileNotifier.instance.value.nickname, '旧昵称');

      // 模拟恢复：prefs 被整体改写成备份里的内容
      await service.restoreData({
        CacheKeyConstant.favoriteFeatures: _entry('List<String>', <String>['新收藏']),
        'userNickname': _entry('String', '新昵称'),
      });

      await service.reloadAfterRestore();

      expect(FavoriteFeaturesNotifier.titles, {'新收藏'},
          reason: '不重读的话，用户下一次点星标就会用旧集合整体覆盖恢复结果');
      expect(UserProfileNotifier.instance.value.nickname, '新昵称');
    });
  });
}
