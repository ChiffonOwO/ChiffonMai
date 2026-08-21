/// 水鱼 OAuth 代理（/api/prober）返回的错误，用于区分「未授权需绑定」等场景。
class ProberException implements Exception {
  /// 错误码：CONSENT_REQUIRED / UNAUTHORIZED / FORBIDDEN / QUOTA_EXCEEDED / BIND_FAILED / UNKNOWN
  final String code;
  final String message;

  /// 需引导绑定时的授权链接（仅 CONSENT_REQUIRED 场景会携带）
  final String? bindingUrl;

  ProberException(this.code, this.message, {this.bindingUrl});

  static ProberException consentRequired({String? bindingUrl}) => ProberException(
        'CONSENT_REQUIRED',
        '该用户尚未授权本应用，请先完成绑定后再试',
        bindingUrl: bindingUrl,
      );

  static ProberException unauthorized() =>
      ProberException('UNAUTHORIZED', '鉴权失败，请重试');

  static ProberException forbidden() =>
      ProberException('FORBIDDEN', '无权限访问该用户数据');

  static ProberException quotaExceeded() =>
      ProberException('QUOTA_EXCEEDED', '今日查询次数已达上限，请明天再试');

  static ProberException unknown(int statusCode) =>
      ProberException('UNKNOWN', '请求失败（状态码 $statusCode）');

  @override
  String toString() => message;
}
