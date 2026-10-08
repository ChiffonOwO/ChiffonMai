// ignore_for_file: constant_identifier_names

// 开发者凭据模板。实际构建请通过 --dart-define-from-file 注入，
// 不要把密钥写进 Dart 源码或提交到版本库。
class DeveloperTokenShow {
  static const String TencentSecretId = '';
  static const String TencentSecretKey = '';

  // 落雪 OAuth Client Secret
  static const String LuoXueClientSecret = '';

  // AWMC NET.（https://net.wmc.pub）查分器开发者密钥。
  //
  // 用途：App 直连 `GET /dev/player/records?qq=<QQ>` 查成绩，请求头 `Developer-Token`。
  // 申请：登录 net.wmc.pub 后在开发者页面申请，密钥形如 `awmc_sk_...`，
  //       需要 `bot + developer` 权限（只读查分；不限频率最好）。
  // 留空 / 用占位符会导致「刷新数据 → AWMC NET」提示密钥无效（HTTP 401）。
  static const String AwmcNetDeveloperKey = '';

  // MySQL数据库配置
  static const String MySQLHost = '';
  static const int MySQLPort = 3306;
  static const String MySQLDatabase = 'user_maimai_rankings';
  static const String MySQLUsername = '';
  static const String MySQLPassword = '';

  // Redis配置
  static const String RedisHost = '';
  static const int RedisPort = 6379;
  static const String RedisPassword = '';
  static const int RedisDatabase = 0;
}
