// 成绩录入的合法值校验（达成率 / DX / Rating / B35 / B15）。
//
// 规则本体在 `lib/utils/ScoreInputValidator.dart`，**三个入口共用一份**：
// 自定义 Best50、曲目详情页的成绩历史、Rating 历史。这里把口径钉死，
// 免得哪天一个入口放宽、另一个没跟上（同一个数在一处合法、另一处非法最难查）。
import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_flutter_app/utils/ScoreInputValidator.dart';

void main() {
  group('数值输入校验', () {
    test('还没填：不算错，由调用方决定要不要提示"请输入"', () {
      final empty = checkNumberInput('   ', hardMax: 9999);
      expect(empty.value, isNull);
      expect(empty.error, isNull);
    });

    test('非数字 / 负数 / 0', () {
      expect(checkNumberInput('abc', hardMax: 9999).error, '请输入数字');
      expect(checkNumberInput('12a', hardMax: 9999).error, '请输入数字');
      expect(checkNumberInput('-1', hardMax: 9999).error, '不能为负数');
      expect(checkNumberInput('0', hardMax: 9999).error, '必须大于 0');
      expect(checkNumberInput('0', hardMax: 9999, allowZero: true).error, isNull,
          reason: 'B35 / B15 / DX 允许为 0');
    });

    test('硬上限：整数不拖小数点', () {
      expect(checkNumberInput('10000', hardMax: dxScoreHardMax).error,
          '不得超过 9999');
      expect(checkNumberInput('9999', hardMax: dxScoreHardMax).value, 9999);
      expect(checkNumberInput('1000', hardMax: achievementHardMax).error,
          '不得超过 999.9999');
      expect(checkNumberInput('999.9999', hardMax: achievementHardMax).error,
          isNull);
    });

    test('语义上限：带说明；上限未知（0）时不卡', () {
      final over = checkNumberInput('101.5',
          hardMax: achievementHardMax, limit: 101, limitLabel: '谱面上限');
      expect(over.error, '不得超过 101（谱面上限）');
      expect(over.value, isNull);

      expect(
        checkNumberInput('101',
                hardMax: achievementHardMax, limit: 101, limitLabel: '谱面上限')
            .error,
        isNull,
        reason: '正好等于上限是合法的',
      );

      expect(checkNumberInput('9999', hardMax: 9999, limit: 0).error, isNull,
          reason: '拿不到上限时退化成只校验硬上限，不能把人挡在录入外面');
    });

    test('达成率上限：普通曲 101%，宴会场按子谱数', () {
      expect(maxAchievementFor(isUtage: false, chartCount: 4), 101.0);
      expect(maxAchievementFor(isUtage: false, chartCount: 0), 101.0);
      expect(maxAchievementFor(isUtage: true, chartCount: 2), 202.0);
      expect(maxAchievementFor(isUtage: true, chartCount: 1), 101.0);
      expect(maxAchievementFor(isUtage: true, chartCount: 0), 101.0);
    });

    test('上限说明是"信息"，与拒绝输入的 errorText 不是同一句话', () {
      expect(limitHelperText(17000, '当前理论 Rating'), '上限 17000（当前理论 Rating）');
      expect(limitHelperText(0, '当前理论 Rating'), isNull);
      expect(formatLimit(101.0), '101');
      expect(formatLimit(999.9999), '999.9999');
      expect(formatLimit(3375), '3375');
    });
  });
}
