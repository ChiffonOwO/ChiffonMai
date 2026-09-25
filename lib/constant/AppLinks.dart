/// 项目的对外链接与联系方式。
///
/// **只在这里定义一次**：这些值会散落在 UI（系统 hub 的按钮）、导出的图片
/// （Best50 底部的交流群）、个人主页信息栏等好几个地方，各写一份字面量迟早会
/// 改漏一处 —— 之前群号 `291826702` 就在两处各写了一遍。
class AppLinks {
  AppLinks._();

  /// 官网。
  static const String officialSite = 'https://chiffonmai.cloud/';

  /// 官方交流 QQ 群号（跳转失败时复制这个给用户手动搜索）。
  static const String qqGroupNumber = '291826702';

  /// 一键加群链接（`qm.qq.com` 的分享链接）。
  ///
  /// 装了 QQ 会直接拉起加群页；没装 / 打不开时**不要**把这个链接复制给用户
  /// （在浏览器里打开只有一个空壳中转页），要复制 [qqGroupNumber]。
  static const String qqGroupJoinUrl = 'https://qm.qq.com/q/bNUUN3aiaI';

  /// 问卷。
  static const String surveyUrl = 'https://wj.qq.com/s2/26540572/7828/';
}
