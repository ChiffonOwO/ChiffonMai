/// 成绩录入（达成率 / DX 分数 / Rating / Best35 / Best15）的**上限口径与校验**。
///
/// 为什么单独一层：同一份成绩在多个入口被录入 —— 自定义 Best50、曲目详情页的
/// 成绩历史、Rating 历史 —— 三处各写一套阈值，迟早会出现「同一个数在一个入口
/// 合法、在另一个入口非法」这种最难查的问题。规则只写一份，改也只改这里。
///
/// 口径来源：`lib/page/Best50/CustomBest50Page.dart`（自定义 Best50 的
/// `_NumberInputField` 与 `_maxAchievementFor`），这里原样搬过来供它和新代码共用。
library;

/// 达成率硬上限：游戏里不存在更高的成绩，输入框直接拒绝。
const double achievementHardMax = 999.9999;

/// DX 分数硬上限（同上）。
const int dxScoreHardMax = 9999;

/// Rating / Best35 / Best15 的兜底硬上限。
///
/// 拿得到理论值时以理论值为准（见 [RatingLimits]）；这一档只在**没有歌曲缓存**
/// （新装、从没刷新过数据）时兜底，防的是 163530 这种手滑。
const int ratingHardMax = 99999;

/// 达成率上限。
///
/// 普通曲 101%；宴会场（6 位 songId）一个曲目里有多张子谱、达成率相加，
/// 上限 = 101 × 子谱数（2 个子谱即 202%）。
/// 与「自定义 Best50」的 `_maxAchievementFor` 同口径（那份现在直接调这里）。
double maxAchievementFor({required bool isUtage, required int chartCount}) =>
    !isUtage ? 101.0 : (chartCount <= 1 ? 101.0 : 101.0 * chartCount);

/// 理论 Rating 的三个数（全部谱面 SSS+ 时的 Best35 / Best15 / 总和）。
typedef RatingLimits = ({int best35, int best15, int total});

/// 拿不到歌曲缓存时的占位值：三档全为 0，校验退化成硬上限。
const RatingLimits unknownRatingLimits = (best35: 0, best15: 0, total: 0);

/// 一个数值输入的校验结果。
///
/// `value: null, error: null` = **还没填**（要不要提示"请输入"由调用方决定）；
/// `error != null` = 这一格不能保存，[error] 直接当 `InputDecoration.errorText` 用。
typedef NumberCheck = ({double? value, String? error});

/// 校验一个带上下限的数值输入。
///
/// 判定顺序与自定义 Best50 的 `_NumberInputField` 一致：
/// 非数字 → 负数 → 0（不允许时）→ 超硬上限 → 超语义上限（[limit]）。
NumberCheck checkNumberInput(
  String raw, {
  required num hardMax,
  num? limit,
  String limitLabel = '',
  bool allowZero = false,
}) {
  final text = raw.trim();
  if (text.isEmpty) return (value: null, error: null);
  final value = double.tryParse(text);
  if (value == null) return (value: null, error: '请输入数字');
  if (value < 0) return (value: null, error: '不能为负数');
  if (!allowZero && value == 0) return (value: null, error: '必须大于 0');
  if (value > hardMax) {
    return (value: null, error: '不得超过 ${formatLimit(hardMax)}');
  }
  if (limit != null && limit > 0 && value > limit) {
    return (
      value: null,
      error: '不得超过 ${formatLimit(limit)}'
          '${limitLabel.isEmpty ? '' : '（$limitLabel）'}',
    );
  }
  return (value: value, error: null);
}

/// 上限文案：整数不拖小数点（9999 而不是 9999.0）。
String formatLimit(num value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();

/// 输入框下方的上限说明。
///
/// 刻意写成"上限 X"而不是"不得超过 X"：**这是信息，不是错误** ——
/// 与 [checkNumberInput] 给出的 errorText 用同一句话，用户会分不清
/// 是在提示还是在拒绝。拿不到上限（[limit] <= 0）时返回 null。
String? limitHelperText(num limit, String label) =>
    limit > 0 ? '上限 ${formatLimit(limit)}（$label）' : null;
