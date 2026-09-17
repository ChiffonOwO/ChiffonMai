/// 功能开关。
///
/// 有些功能「代码留着、入口先不给看」，开关集中放这里，避免把入口开关信息
/// 散落在各个页面里（也方便我按你的安排一次性打开 / 关掉）。
class FeatureFlags {
  FeatureFlags._();

  /// 「系统 → AWMC 网关」入口（机台账号查询 / 写入，敏感操作）。
  ///
  /// 当前 **false**：系统 hub 与首页搜索 / 收藏 / 全部功能里都看不到这个入口，
  /// 但代码一行没删，全在本机：
  ///   * 页面 `lib/page/Awmc/`
  ///   * 服务 `lib/service/AWMC/`
  ///   * 实体 `lib/entity/AWMC/AwmcUserMusic.dart`
  ///   * 令牌 `lib/api/AwmcToken.dart`
  /// 上面这些都在 `.gitignore` 里（不进版本库），入口的显示与否只由这个开关决定。
  ///
  /// 要启用时把下面的 `false` 改成 `true` 即可（首页搜索、收藏、
  /// 系统 hub 三处的入口会一起回来）。
  ///
  /// 用 `static final` 而不是 `const`：`const false` 会让
  /// `if (FeatureFlags.awmcGateway)` 里的代码被判定成 dead code 而报警告。
  static final bool awmcGateway = false;
}
